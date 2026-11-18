-- Reuse native sidebar rows inside PrettyUI's clipped viewport.
local UI = require("Resources/Shared/ui/components")
local VirtualSidebar = {}

function VirtualSidebar.new(parent, options)
    local view = prettyui.SimpleView.new(parent, {
        categoryID = "auto", width = options.width, height = options.height,
        contentHeight = #options.entries * options.entryHeight, scrollStep = options.entryHeight,
    })
    view.entries, view.rows, view.entryHeight = options.entries, {}, options.entryHeight
    UI.Frame(view.root, 0, 0, options.width, options.height, options.borderColour)
    local entriesByID = {}
    for _, entry in ipairs(view.entries) do
        entry.visible = true
        entriesByID[entry.id] = entry
    end
    local function paint(row)
        local entry = row.entry
        row.background.rgba = entry.selected and entry.selectedColour or entry.backgroundColour
        row.label.rgba = entry.enabled and entry.textColour or 0x8B8882FF
    end
    local function createRow()
        local row = { root = UI.ContentLayer(view.content), height = view.entryHeight }
        row.root:SetSize(view.content.width, view.entryHeight)
        row.background = UI.Rectangle(row.root, 0, 0, row.root.width, view.entryHeight, 0)
        row.background:MoveToBack()
        row.label = UI.Text(row.root, "", 8, 0, row.root.width - 14, view.entryHeight, {
            font = options.font, alignVertical = ui.AlignMode.CENTRE,
        })
        row.icon = UI.NewComponent(ui.Sprite, row.root)
        row.icon:SetSize(16, 16)
        row.icon.clickthrough, row.icon.hidden = true, true
        UI.ForwardScrollWheel(row.root, view)
        row.root:Subscribe(ui.Hook.ONMOUSEOVER, function()
            if row.entry and row.entry.enabled then
                row.background.rgba = row.entry.selected and row.entry.selectedColour or row.entry.hoverColour
            end
            return true
        end)
        row.root:Subscribe(ui.Hook.ONMOUSELEAVE, function()
            if row.entry then paint(row) end
            return true
        end)
        row.root:Subscribe(ui.Hook.ONCLICK, function()
            if row.entry and row.entry.enabled then view:SetSelected(row.entry.id, true, true) end
            return false
        end)
        view.rows[#view.rows + 1] = row
    end
    local function refresh()
        local first = math.max(1, math.floor(view.scrollY / view.entryHeight))
        local last = math.min(#view.entries, math.ceil((view.scrollY + view.height) / view.entryHeight) + 1)
        local needed = math.max(0, last - first + 1)
        if #view.rows < needed then UI.RefreshComponentIDs(view.content) end
        while #view.rows < needed do createRow() end
        for index, row in ipairs(view.rows) do
            local entryIndex = first + index - 1
            local entry = index <= needed and view.entries[entryIndex] or nil
            row.root.hidden = entry == nil
            if entry and row.entry ~= entry then
                row.entry = entry
                row.root:SetPos(0, (entryIndex - 1) * view.entryHeight)
                row.root.clickthrough = not entry.enabled
                local leading = entry.icon ~= nil
                local icon = entry.trailingIcon or entry.icon
                local iconSize = leading and math.max(1, math.floor(16 * (options.entryIconScale or 100) / 100)) or 16
                row.icon.hidden = icon == nil
                if icon ~= nil then
                    row.icon.spriteID = icon
                    row.icon:SetSize(iconSize, iconSize)
                    row.icon:SetPos(leading and 8 or row.root.width - 23, math.floor((view.entryHeight - iconSize) / 2))
                end
                local left = leading and 14 + iconSize or 8
                row.label:SetPos(left, 0)
                row.label:SetSize(row.root.width - left - (entry.trailingIcon and 29 or 6), view.entryHeight)
                row.label.content = entry.label
                paint(row)
            elseif not entry then
                row.entry = nil
            end
        end
        if options.onRowsChanged then options.onRowsChanged() end
    end
    function view:_ViewportHeight() return self.height end
    function view:RefreshStyles()
        for _, row in ipairs(self.rows) do if row.entry then paint(row) end end
        if options.onRowsChanged then options.onRowsChanged() end
    end
    function view:SetSelected(entryID, selected, notify)
        local entry = entriesByID[entryID]
        if entry == nil or entry.selected == selected then return end
        if selected then
            for _, candidate in ipairs(self.entries) do candidate.selected = candidate == entry end
        else
            entry.selected = false
        end
        for _, row in ipairs(self.rows) do if row.entry then paint(row) end end
        if options.onRowsChanged then options.onRowsChanged() end
        if notify and options._onEntryClick then options._onEntryClick(self, entryID, selected) end
    end
    view.onLayout = refresh
    view:SetContentHeight(#view.entries * view.entryHeight)
    refresh()
    return view
end

return VirtualSidebar
