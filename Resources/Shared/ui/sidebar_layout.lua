-- Build shared sidebar layouts
local UI = require("Resources/Shared/ui/components")

local SidebarLayout = {
    SIDEBAR_WIDTH = 220,
    WORKSPACE_X = 228,
}

-- Attach a sidebar or create a standalone section
function SidebarLayout.Attach(root, options)
    options = options or {}
    local width = options.sidebarWidth or SidebarLayout.SIDEBAR_WIDTH
    local y = options.sidebarY or 0
    local background =
        UI.Rectangle(root, 0, y, width, root.height - y, options.sidebarColour or 0x15120ECC)
    local divider =
        UI.Rectangle(root, width, y, 1, root.height - y, options.dividerColour or 0x5A4934FF)
    local title
    if options.showTitle ~= false then
        title = UI.Text(
            root,
            options.sidebarTitle or "",
            10,
            options.titleY or y + 8,
            width - 20,
            options.titleHeight or 24,
            {
                font = id.Font.MUSEO_SANS_13PT_BOLD,
                colour = options.titleColour or 0xF2C66DFF,
            }
        )
    end
    local workspace
    if options.createWorkspace ~= false then
        local x = width + (options.gap or 8)
        workspace = ui.Layer.new(root)
        workspace:SetPos(x, 0)
        workspace:SetSize(root.width - x, root.height)
        workspace.clickthrough = true
    end
    return {
        root = root,
        sidebarBackground = background,
        sidebarDivider = divider,
        sidebarTitle = title,
        workspace = workspace,
    }
end

function SidebarLayout.Create(parent, options)
    options = options or {}
    local root = ui.Layer.new(parent)
    root:SetPos(options.x or 0, options.y or 0)
    root:SetSize(options.width, options.height)
    root.clickthrough = true
    return SidebarLayout.Attach(root, options)
end

-- Create a sidebar layout with a workspace heading and an optional summary
function SidebarLayout.CreateHeaded(parent, options, sidebarTitle, summary)
    local shell = SidebarLayout.Create(parent, {
        x = options.x,
        y = options.y,
        width = options.width,
        height = options.height,
        sidebarTitle = sidebarTitle,
    })
    local workspace = shell.workspace
    shell.heading = UI.Text(workspace, "", 12, 10, workspace.width - 120, 30, {
        font = id.Font.CINZEL_18PT_BOLD,
        colour = 0xF2C66DFF,
    })
    if summary ~= nil then
        shell.summary = UI.Text(workspace, summary, workspace.width - 106, 10, 90, 30, {
            colour = 0xC9BEA4FF,
            alignHorizontal = ui.AlignMode.BOTTOMRIGHT,
        })
    end
    return shell
end

return SidebarLayout
