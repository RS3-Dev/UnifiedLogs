-- Render the collection group panel
local UI = require("Resources/Shared/ui/components")
local ProgressStyle = require("Resources/Shared/ui/progress_style")

-- Draw stateless framed ledger groups
local CollectionGroupPanel = {}

-- Track a created component
local function remember(components, component)
    components[#components + 1] = component
    return component
end

-- Create a collection group header
function CollectionGroupPanel.Header(parent, options)
    options = options or {}
    local components = {}
    local x = options.x or 0
    local y = options.y or 0
    local width = options.width or 300
    local height = options.height or ProgressStyle.GROUP_HEIGHT
    local complete = options.complete == true
    local showProgress = options.showProgress ~= false
    local showCompletionMark = options.showCompletionMark ~= false and showProgress
    local rightInset = showCompletionMark and 42 or 12

    remember(components, UI.Rectangle(parent, x, y, width, height,
        ProgressStyle.Green(complete, ProgressStyle.GROUP_BACKGROUND, ProgressStyle.GREEN_HEADER)))

    remember(
        components,
        UI.Text(
            parent,
            tostring(options.title or ""),
            x + 12,
            y,
            options.titleWidth or math.max(40, width - 182),
            height,
            {
                font = id.Font.MUSEO_SANS_13PT_BOLD,
                colour = ProgressStyle.Green(complete, options.titleColour or 0xF2C66DFF, 0xF2C66DFF),
            }
        )
    )

    local countLabel = options.countLabel
    if countLabel == nil and options.total ~= nil then
        if showProgress then
            countLabel = tostring(options.collected or 0) .. "/" .. tostring(options.total or 0)
        else
            countLabel = tostring(options.total or 0) .. " items"
        end
    end
    if countLabel ~= nil and countLabel ~= "" then
        remember(
            components,
            UI.Text(
                parent,
                countLabel,
                x + width - (options.countInset or 154),
                y,
                options.countWidth or 142 - rightInset + 12,
                height,
                {
                    font = id.Font.MUSEO_SANS_13PT_BOLD,
                    colour = ProgressStyle.Green(complete, complete and ProgressStyle.PROGRESS_COMPLETE
                        or ProgressStyle.PROGRESS_ACTIVE, 0xF2C66DFF),
                    alignHorizontal = ui.AlignMode.BOTTOMRIGHT,
                }
            )
        )
    end

    if showCompletionMark then
        remember(
            components,
            ProgressStyle.CompletionMark(
                parent,
                x + width - 26,
                y + math.floor((height - 14) / 2),
                complete
            )
        )
    end

    if complete and options.showWedge ~= false then
        local wedge = remember(components, ProgressStyle.Wedge(parent, x + 1, y + 1, height - 2))
        wedge.rgba = ProgressStyle.Green(complete, wedge.rgba, ProgressStyle.GREEN_HEADER)
        wedge:MoveToFront()
    end

    local border = ProgressStyle.Green(complete, ProgressStyle.GROUP_BORDER, ProgressStyle.GREEN_HEADER)
    remember(components, UI.Rectangle(parent, x, y, width, 1, border)):MoveToFront()
    remember(components, UI.Rectangle(parent, x, y, 1, height, border)):MoveToFront()
    remember(
        components,
        UI.Rectangle(parent, x + width - 1, y, 1, height, border)
    ):MoveToFront()
    remember(
        components,
        UI.Rectangle(
            parent,
            x,
            y + height - 1,
            width,
            1,
            ProgressStyle.Green(complete, options.groupEnd and ProgressStyle.GROUP_BORDER
                or ProgressStyle.GROUP_DIVIDER, ProgressStyle.GREEN_HEADER)
        )
    ):MoveToFront()
    return components
end

-- Create a collection group frame
function CollectionGroupPanel.Frame(parent, options)
    local components = {}
    local x, y = options.x or 0, options.y or 0
    local width, height = options.width or 300, options.height or 48
    local border = ProgressStyle.Green(options.complete, ProgressStyle.GROUP_BORDER, ProgressStyle.GREEN_BORDER)
    remember(components, UI.Rectangle(parent, x, y, 1, height, border)):MoveToFront()
    remember(
        components,
        UI.Rectangle(parent, x + width - 1, y, 1, height, border)
    ):MoveToFront()
    if options.groupStart == true then
        remember(components, UI.Rectangle(parent, x, y, width, 1, border)):MoveToFront()
    end
    remember(
        components,
        UI.Rectangle(
            parent,
            x,
            y + height - 1,
            width,
            1,
            ProgressStyle.Green(options.complete, options.groupEnd and ProgressStyle.GROUP_BORDER
                or ProgressStyle.ROW_DIVIDER, ProgressStyle.GREEN_BORDER)
        )
    ):MoveToFront()
    return components
end

-- Create a collection group body
function CollectionGroupPanel.Body(parent, options)
    options = options or {}
    local components = {}
    local x = options.x or 0
    local y = options.y or 0
    local width = options.width or 300
    local height = options.height or 48

    remember(
        components,
        UI.Rectangle(parent, x, y, width, height,
            ProgressStyle.Green(options.complete, options.colour or ProgressStyle.ROW_ODD, ProgressStyle.GREEN_BACKGROUND))
    )
    if options.complete == true and options.showWedge ~= false then
        local wedge = remember(components, ProgressStyle.Wedge(parent, x + 1, y, height))
        wedge.rgba = ProgressStyle.Green(options.complete, wedge.rgba, ProgressStyle.GREEN_BACKGROUND)
        wedge:MoveToFront()
    end
    for _, edge in ipairs(CollectionGroupPanel.Frame(parent, options)) do
        remember(components, edge)
    end
    return components
end

return CollectionGroupPanel
