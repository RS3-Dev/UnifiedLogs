-- Build shared raw UI components
local UI = {}

-- Preserve PrettyUI cursor defaults with one sentinel
UI.NO_CURSOR = {}

-- Keep structural hosts in category zero so they can contain PrettyUI views,
-- windows, tabs and tooltips. Their managed descendants use automatic allocation.
-- Check the shared static namespace before calling the native constructor.
function UI.ContentLayer(parent)
    -- A static client layer may have a static ancestor of its own.
    local collection = parent.categoryID == -1 and parent or (parent.parentStatic or parent)
    assert(parent == collection or parent.categoryID == 0,
        "Unified Logs content layers require a static or category-zero parent")
    -- Resolve IDs directly instead of walking the entire UI for every pooled row.
    local interfaces = ui.Interfaces
    if interfaces and interfaces.GetComponent and interfaces.GetInterface
        and type(collection.interfaceID) == "number" and type(collection.staticID) == "number"
        and interfaces:GetInterface(collection.interfaceID) ~= nil
        and (parent == collection or interfaces:GetComponent(collection.interfaceID,
            collection.staticID, parent.categoryID, parent.dynamicID) == parent) then
        local nextID = parent == collection and 0 or parent.dynamicID + 1
        while nextID < 4096 and interfaces:GetComponent(collection.interfaceID,
            collection.staticID, 0, nextID) ~= nil do nextID = nextID + 1 end
        assert(nextID < 4096, "Unified Logs could not find a free category-zero UI ID")
        if parent == collection then return ui.Layer.new(parent) end
        return ui.Layer.new(parent, 0, nextID)
    end
    assert(type(collection.IterateDynamicComponents) == "function",
        "Unified Logs could not inspect the UI allocation namespace")
    local used, visited, pending = {}, {}, { collection }
    while #pending > 0 do
        local current = table.remove(pending)
        current:IterateDynamicComponents(function(component)
            if component.categoryID == 0 then used[component.dynamicID] = true end
            -- Native text and sprite leaves occupy IDs without exposing children.
            if not visited[component] and type(component.IterateDynamicComponents) == "function" then
                visited[component] = true
                pending[#pending + 1] = component
            end
            return false
        end)
    end
    local nextID = parent == collection and 0 or parent.dynamicID + 1
    while used[nextID] do nextID = nextID + 1 end
    assert(nextID < 4096, "Unified Logs could not find a free category-zero UI ID")
    if parent == collection then return ui.Layer.new(parent) end
    return ui.Layer.new(parent, 0, nextID)
end

-- Drop stale PrettyUI occupancy snapshots before rebuilding pooled controls.
function UI.RefreshComponentIDs(parent)
    if prettyui.RefreshComponentIDs ~= nil then prettyui.RefreshComponentIDs(parent) end
end

-- Preserve the full-size, clickthrough ownership root used by pages and windows.
function UI.RootLayer(parent)
    local root = UI.ContentLayer(parent)
    root:SetSize(0, 0, 1, 1)
    root.clickthrough = true
    return root
end

-- Explicitly opt custom controls into PrettyUI 1.3's guarded allocator, including
-- controls mounted beneath raw client-owned or category-zero content layers.
function UI.NewComponent(nativeType, parent)
    assert(prettyui ~= nil and type(prettyui.NewComponent) == "function",
        "Unified Logs requires PrettyUI 1.3.0 or newer. Update PrettyUI and reload the plugin.")
    return prettyui.NewComponent(nativeType, parent, { categoryID = "auto" })
end

-- Remove a component cursor
function UI.RemoveCursor(component)
    if component == nil then return end
    if component.opConfig ~= nil and component.opConfig.ClearOpCursors ~= nil then
        component.opConfig:ClearOpCursors()
    end
    if component.cursorConfig ~= nil then component.cursorConfig.mouseOverCursor = -1 end
end

-- Bind a rectangle to a component
function UI.BindRectangle(result, x, y, width, height, colour)
    result:SetPos(x, y)
    result:SetSize(width, height)
    result.fill = true
    result.rgba = colour
    result.clickthrough = true
    result.hidden = false
    return result
end

-- Create a rectangle
function UI.Rectangle(parent, x, y, width, height, colour)
    return UI.BindRectangle(UI.NewComponent(ui.Rectangle, parent), x, y, width, height, colour)
end

-- Bind text to a component
function UI.BindText(result, value, x, y, width, height, options)
    options = options or {}
    result:SetPos(x, y)
    result:SetSize(width, height)
    result.content = tostring(value or "")
    result.font = options.font or id.Font.MUSEO_SANS_15PT_REGULAR
    result.rgba = options.colour or 0xE7D7B0FF
    result.isShadowed = options.shadowed ~= false
    result.maxLines = options.maxLines or 1
    result.alignVertical = options.alignVertical or ui.AlignMode.CENTRE
    if options.alignHorizontal ~= nil then result.alignHorizontal = options.alignHorizontal end
    result.clickthrough = true
    result.hidden = false
    return result
end

-- Create text
function UI.Text(parent, value, x, y, width, height, options)
    return UI.BindText(UI.NewComponent(ui.Text, parent), value, x, y, width, height, options)
end

-- Create a frame
function UI.Frame(parent, x, y, width, height, options)
    options = type(options) == "table" and options or { colour = options }
    local thickness = math.max(1, math.floor(tonumber(options.thickness) or 1))
    local colour = options.colour or 0x5A4934FF
    local bottomColour = options.bottomColour or colour
    local edges = {
        UI.Rectangle(parent, x, y, width, thickness, colour),
        UI.Rectangle(parent, x, y + height - thickness, width, thickness, bottomColour),
        UI.Rectangle(parent, x, y, thickness, height, colour),
        UI.Rectangle(parent, x + width - thickness, y, thickness, height, colour),
    }
    if options.moveToFront ~= false then
        for _, edge in ipairs(edges) do
            edge:MoveToFront()
        end
    end
    return edges
end

-- Create clickable text
function UI.ClickableText(parent, value, x, y, width, height, options)
    options = options or {}
    local normal = options.colour or 0xD6CCB5FF
    local result = UI.Text(parent, value, x, y, width, height, options)
    result.font = options.font or id.Font.MUSEO_SANS_13PT_REGULAR
    result.rgba = normal
    result.alignHorizontal = options.alignHorizontal or ui.AlignMode.TOPLEFT
    result.clickthrough = false
    result:Subscribe(ui.Hook.ONMOUSEOVER, function()
        result.rgba = options.hoverColour or 0xFFFFFFFF
        return true
    end)
    result:Subscribe(ui.Hook.ONMOUSELEAVE, function()
        result.rgba = normal
        return true
    end)
    result:Subscribe(ui.Hook.ONCLICK, function()
        if type(options.action) == "function" then options.action() end
        return false
    end)
    if type(options.onScrollWheel) == "function" then
        result:Subscribe(
            ui.Hook.ONSCROLLWHEEL,
            function(component, delta) return options.onScrollWheel(component, delta) end
        )
    end
    return result
end

-- Forward child wheel events to their scrollable view
function UI.ForwardScrollWheel(component, view)
    if
        component == nil
        or view == nil
        or type(view._onScrollWheel) ~= "function"
        or ui.Hook.ONSCROLLWHEEL == nil
    then
        return false
    end
    component:Subscribe(ui.Hook.ONSCROLLWHEEL, function(source, delta)
        return view._onScrollWheel(source, delta)
    end)
    return true
end

-- Build full-size feature tabs
function UI.Tabs(parent, modes, activeMode, onChange)
    local entries, indexByID = {}, {}
    for index, mode in ipairs(modes) do
        entries[index] = {
            kind = "text",
            text = mode.label,
            value = mode.id,
            hoverCursor = UI.NO_CURSOR,
        }
        indexByID[mode.id] = index
    end
    return prettyui.Tabs.new(parent, entries, {
        categoryID = "auto",
        x = 0,
        y = 0,
        width = parent.width,
        height = parent.height,
        activeIndex = indexByID[activeMode] or 1,
        scrollable = false,
        tabInset = 8,
        onChange = onChange,
    }),
        indexByID
end

function UI.Lower(value) return string.lower(tostring(value or "")) end

return UI
