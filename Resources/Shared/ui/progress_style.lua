-- Draw shared progress indicators
local UI = require("Resources/Shared/ui/components")

local ProgressStyle = {
    GROUP_HEIGHT = 32,
    GROUP_GAP = 8,
    GROUP_BACKGROUND = 0x2A231BFF,
    GROUP_DIVIDER = 0x3B3228FF,
    GROUP_BORDER = 0x5A4934FF,
    ROW_ODD = 0x13110EFF,
    ROW_EVEN = 0x181510FF,
    ROW_DIVIDER = 0x252019FF,
    TEXT_NORMAL = 0xEADFC9FF,
    TEXT_COMPLETE = 0xCFC5B3FF,
    PROGRESS_ACTIVE = 0xD5AA51FF,
    PROGRESS_COMPLETE = 0x9A907FFF,
    COMPLETE_WEDGE = 0x4F9E67FF,
    COMPLETE_WEDGE_WIDTH = 5,
    COMPLETION_MARK_SIZE = 24,
    greenLogEnabled = false,
    GREEN_BACKGROUND = 0x1A3826FF,
    GREEN_HEADER = 0x20432EFF,
    GREEN_BORDER = 0x1A3826FF,
    GREEN_TEXT = 0x71E69AFF,
}

function ProgressStyle.Green(complete, normal, green)
    if ProgressStyle.greenLogEnabled and complete == true then
        return green or ProgressStyle.GREEN_TEXT
    end
    return normal
end

local COMPLETION_MARK_OFFSET = 5

-- Choose a progress row colour
function ProgressStyle.RowColour(index)
    return index % 2 == 0 and ProgressStyle.ROW_EVEN or ProgressStyle.ROW_ODD
end

-- Draw a completion mark
function ProgressStyle.CompletionMark(parent, x, y, complete)
    local mark = ui.Sprite.new(parent)
    ProgressStyle.PositionCompletionMark(mark, x, y)
    mark.clickthrough = true
    ProgressStyle.SetCompletionMark(mark, complete)
    return mark
end

function ProgressStyle.PositionCompletionMark(mark, x, y)
    mark:SetPos(x - COMPLETION_MARK_OFFSET, y - COMPLETION_MARK_OFFSET)
    mark:SetSize(ProgressStyle.COMPLETION_MARK_SIZE, ProgressStyle.COMPLETION_MARK_SIZE)
    return mark
end

function ProgressStyle.SetCompletionMark(mark, complete)
    mark.spriteID = id.Sprite.MAD_MAY_16_ICON_CASE_COMPLETE
    mark.hidden = complete ~= true
    return mark
end

-- Draw a progress wedge
function ProgressStyle.Wedge(parent, x, y, height)
    return UI.Rectangle(
        parent,
        x,
        y,
        ProgressStyle.COMPLETE_WEDGE_WIDTH,
        height,
        ProgressStyle.COMPLETE_WEDGE
    )
end

-- Create a progress frame
function ProgressStyle.Frame(parent, x, y, width, height)
    return UI.Frame(parent, x, y, width, height, {
        colour = ProgressStyle.GROUP_BORDER,
    })
end

return ProgressStyle
