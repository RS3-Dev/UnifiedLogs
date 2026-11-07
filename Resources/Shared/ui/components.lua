-- Build shared raw UI components
local UI = {}

-- Preserve PrettyUI cursor defaults with one sentinel
UI.NO_CURSOR = {}

-- Dynamic descendants share the static parent's category/ID allocation space.
-- Prefer category zero's larger ID range for lists; other categories are small.
function UI.RootLayer(parent)
    local collection = parent.parentStatic or parent
    local used, visited, pending, nextID = {}, {}, { collection }, 0
    -- Iterators may expose only direct children, so inspect dynamic descendants too.
    while #pending > 0 do
        local current = table.remove(pending)
        local ok, iterate = pcall(function() return current.IterateDynamicComponents end)
        if ok and type(iterate) == "function" then
            iterate(current, function(component)
                local category = component.categoryID
                local key = tostring(category) .. ":" .. tostring(component.dynamicID)
                used[category] = true
                if category == 0 then nextID = math.max(nextID, component.dynamicID + 1) end
                if not visited[key] then
                    visited[key] = true
                    pending[#pending + 1] = component
                end
                return false
            end)
        end
    end
    local category = nextID < 4096 and 0 or nil
    if category == nil then
        for candidate = 1, 235 do
            if not used[candidate] then category = candidate; break end
        end
    end
    assert(category ~= nil, "Unified Logs could not find a free UI category")
    local root = ui.Layer.new(parent, category, category == 0 and nextID or 0)
    root:SetSize(0, 0, 1, 1)
    root.clickthrough = true
    return root
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
    return UI.BindRectangle(ui.Rectangle.new(parent), x, y, width, height, colour)
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
    return UI.BindText(ui.Text.new(parent), value, x, y, width, height, options)
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
