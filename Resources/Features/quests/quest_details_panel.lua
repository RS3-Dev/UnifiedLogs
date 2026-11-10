-- Render the quest details panel
local QuestDetailsPanel = {}
QuestDetailsPanel.__index = QuestDetailsPanel

local SkillIcons = require("Resources/Shared/skills/skill_icons")
local UI = require("Resources/Shared/ui/components")
local SidebarList = require("Resources/Shared/ui/sidebar_list")
local ProgressStyle = require("Resources/Shared/ui/progress_style")
local CollectionGroupPanel = require("Resources/Shared/ui/collection_group_panel")

local LIST_TOP = 34
local ROW_HEIGHT = SidebarList.ROW_HEIGHT

local rectangle = UI.Rectangle

-- Create detail panel text
local function text(parent, value, x, y, width, height, options)
    options = options or {}
    if options.font == nil then options.font = id.Font.MUSEO_SANS_13PT_REGULAR end
    return UI.Text(parent, value, x, y, width, height, options)
end

function QuestDetailsPanel.new(parent, options)
    local self = setmetatable({}, QuestDetailsPanel)
    self.options = options
    self.root = ui.Layer.new(parent)
    self.root:SetPos(self.options.x or 0, self.options.y or 0)
    self.root:SetSize(self.options.width, self.options.height)
    self.root.clickthrough = true
    self.elements = {}
    return self
end

function QuestDetailsPanel:Clear()
    self.helperButton = nil
    self.orderEntries = {}
    if self.skillScroll ~= nil then self.skillScroll:Destroy() end
    if self.orderScroll ~= nil then self.orderScroll:Destroy() end
    self.skillScroll = nil
    self.orderScroll = nil
    for _, element in ipairs(self.elements) do
        element:Destroy()
    end
    self.elements = {}
end

function QuestDetailsPanel:RenderEmpty(message)
    self:Clear()
    if self.requirementCombo ~= nil then self.requirementCombo.root.hidden = true end
    self.elements[1] =
        text(self.root, message, 14, 14, self.root.width - 28, 32, { colour = 0xC9BEA4FF })
end

-- Track a created component
local function remember(self, component)
    self.elements[#self.elements + 1] = component
    return component
end

function QuestDetailsPanel:RenderTitle(state, options)
    local quest = state.quest
    local supported = options.helperQuests ~= nil and options.helperQuests[quest.id] ~= nil
    local titleWidth = self.root.width - 184
    if supported then
        titleWidth = math.max(1, titleWidth - 30)
        self.helperButton = remember(self, prettyui.SimpleButton.new(
            self.root, id.Sprite.RS3_ICON_MENU_TAB_QUEST_LIST_0, function()
                if self.options.onOpenQuestHelper ~= nil then self.options.onOpenQuestHelper(quest.id) end
            end, {
                x = self.root.width - 198, y = 4, width = 24, height = 24,
                tooltip = "Open in QuestHelper",
            }
        ))
    end
    remember(
        self,
        text(self.root, string.upper(quest.name), 12, 2, titleWidth, 30, {
            font = id.Font.CINZEL_18PT_BOLD,
            colour = 0xF2C66DFF,
        })
    )
    -- Keep the dropdown mounted while its callback rebuilds the requirement rows.
    if self.requirementCombo == nil then
        local RequirementCombo = prettyui.OrderedComboBox or prettyui.ComboBox
        self.requirementCombo = RequirementCombo.new(self.root, {
            x = self.root.width - 168, y = 2, width = 156, height = 28,
            entries = {
                { id = 1, label = "Show all" },
                { id = 2, label = "Show incomplete" },
            },
            selectedID = state.requirementFilter == "incomplete" and 2 or 1,
            onChange = function(_, entryID, _, eventType)
                if eventType ~= nil and ui.SelectionChangeEvent ~= nil
                    and eventType ~= ui.SelectionChangeEvent.SELECTED then return end
                if self.options.onRequirementFilterChange ~= nil then
                    self.options.onRequirementFilterChange(tonumber(entryID) == 2 and "incomplete" or "all")
                end
            end,
        })
    end
    self.requirementCombo.root.hidden = false
    self.requirementCombo:Select(state.requirementFilter == "incomplete" and 2 or 1, false)

    local previousQuest = options.previousQuest
    if previousQuest ~= nil then
        remember(
            self,
            UI.ClickableText(
                self.root,
                "<lt> Back to " .. previousQuest.name,
                12,
                LIST_TOP,
                self.root.width - 24,
                24,
                {
                    font = id.Font.MUSEO_SANS_11PT_REGULAR,
                    colour = 0xD6CCB5FF,
                    action = self.options.onBack,
                }
            )
        )
    end
end

function QuestDetailsPanel:RenderHeaders(state, columnTop, skillWidth, questX, questWidth)
    -- Create a detail section header
    local function header(x, width, title, complete, total)
        local components = CollectionGroupPanel.Header(self.root, {
            x = x,
            y = columnTop,
            width = width,
            title = title,
            titleWidth = width - 114,
            countLabel = tostring(complete) .. " / " .. tostring(total),
            countInset = 96,
            countWidth = 64,
            complete = total > 0 and complete == total,
            showWedge = false,
        })
        for _, component in ipairs(components) do
            remember(self, component)
        end
    end
    header(0, skillWidth, "MINIMUM LEVELS", state.completedSkills, state.totalSkills or #state.skills)
    remember(
        self,
        rectangle(self.root, questX - 8, columnTop, 1, self.root.height - columnTop, 0x5A4934FF)
    )
    header(
        questX,
        questWidth,
        state.orderView == "tree" and "QUEST TREE" or "QUEST ORDER",
        state.completedQuests,
        #state.chain
    )
end

function QuestDetailsPanel:RenderSkills(state, skillWidth, scrollTop, scrollHeight)
    local skills = state.skills
    self.skillScroll = prettyui.SimpleView.new(self.root, {
        x = 0,
        y = scrollTop,
        width = skillWidth,
        height = scrollHeight,
        contentHeight = math.max(scrollHeight, math.max(1, #skills) * ROW_HEIGHT),
        scrollStep = ROW_HEIGHT,
    })
    local skillRowWidth = math.max(120, self.skillScroll.content.width)
    if #skills == 0 then
        rectangle(self.skillScroll.content, 0, 0, skillRowWidth, ROW_HEIGHT, ProgressStyle.ROW_ODD)
        text(
            self.skillScroll.content,
            state.requirementFilter == "incomplete" and (state.totalSkills or 0) > 0
                and "All skill levels met." or "No skill levels required.",
            12,
            0,
            skillRowWidth - 24,
            ROW_HEIGHT,
            { colour = 0xB9AE98FF }
        )
    end
    local skillY = 0
    for index, requirement in ipairs(skills) do
        rectangle(
            self.skillScroll.content,
            0,
            skillY,
            skillRowWidth,
            ROW_HEIGHT,
            ProgressStyle.RowColour(index)
        )
        local spriteID = SkillIcons.SpriteID(requirement.id)
        local labelX = 12
        if spriteID ~= nil then
            local icon = ui.Sprite.new(self.skillScroll.content)
            icon:SetPos(8, skillY + 4)
            icon:SetSize(24, 24)
            icon.spriteID = spriteID
            icon.clickthrough = true
            labelX = 40
        end
        local requirementMet = state.skillStates[index] == true
        local requirementColour = requirementMet and ProgressStyle.TEXT_COMPLETE
            or ProgressStyle.TEXT_NORMAL
        text(
            self.skillScroll.content,
            requirement.name,
            labelX,
            skillY,
            skillRowWidth - labelX - 86,
            ROW_HEIGHT,
            {
                font = id.Font.MUSEO_SANS_13PT_BOLD,
                colour = requirementColour,
            }
        )
        text(
            self.skillScroll.content,
            tostring(requirement.level),
            skillRowWidth - 76,
            skillY,
            40,
            ROW_HEIGHT,
            {
                font = id.Font.MUSEO_SANS_13PT_BOLD,
                colour = requirementColour,
                alignHorizontal = ui.AlignMode.BOTTOMRIGHT,
            }
        )
        ProgressStyle.CompletionMark(
            self.skillScroll.content,
            skillRowWidth - 26,
            skillY + math.floor((ROW_HEIGHT - 14) / 2),
            requirementMet
        )
        if requirementMet then
            ProgressStyle.Wedge(self.skillScroll.content, 1, skillY + 1, ROW_HEIGHT - 2)
                :MoveToFront()
        end
        rectangle(
            self.skillScroll.content,
            0,
            skillY + ROW_HEIGHT - 1,
            skillRowWidth,
            1,
            ProgressStyle.ROW_DIVIDER
        )
        skillY = skillY + ROW_HEIGHT
    end
    local skillContentHeight = #skills == 0 and ROW_HEIGHT or skillY
    rectangle(self.skillScroll.content, 0, 0, 1, skillContentHeight, ProgressStyle.GROUP_BORDER):MoveToFront()
    rectangle(
        self.skillScroll.content,
        skillRowWidth - 1,
        0,
        1,
        skillContentHeight,
        ProgressStyle.GROUP_BORDER
    ):MoveToFront()
    rectangle(
        self.skillScroll.content,
        0,
        skillContentHeight - 1,
        skillRowWidth,
        1,
        ProgressStyle.GROUP_BORDER
    ):MoveToFront()
    self.skillScroll:SetContentHeight(math.max(scrollHeight, skillY))
end

function QuestDetailsPanel:RenderOrder(state, options, questX, questWidth, scrollTop, scrollHeight)
    local orderRows = state.orderRows
    self.orderScroll = prettyui.SimpleView.new(self.root, {
        x = questX,
        y = scrollTop,
        width = questWidth,
        height = scrollHeight,
        contentHeight = math.max(scrollHeight, #orderRows * ROW_HEIGHT),
        scrollStep = ROW_HEIGHT,
    })
    local rowWidth = math.max(240, self.orderScroll.content.width)
    local y = 0
    if #orderRows == 0 and state.requirementFilter == "incomplete" then
        text(self.orderScroll.content, "All quests complete.", 12, 0, rowWidth - 24, ROW_HEIGHT,
            { colour = 0xB9AE98FF })
    end
    for index, orderRow in ipairs(orderRows) do
        local linkedQuest = orderRow.quest
        local complete = state.chainStates[linkedQuest.id] == true
        rectangle(
            self.orderScroll.content,
            0,
            y,
            rowWidth,
            ROW_HEIGHT,
            ProgressStyle.RowColour(index)
        )
        local labelX = 50
        if state.orderView == "tree" then
            local depth = math.max(0, tonumber(orderRow.depth) or 0)
            local branchGap = 16
            for level = 1, depth - 1 do
                if orderRow.continuations[level] == true then
                    rectangle(
                        self.orderScroll.content,
                        16 + (level - 1) * branchGap,
                        y,
                        1,
                        ROW_HEIGHT,
                        ProgressStyle.GROUP_BORDER
                    )
                end
            end
            if depth > 0 then
                local branchX = 16 + (depth - 1) * branchGap
                local centreY = y + math.floor(ROW_HEIGHT / 2)
                rectangle(
                    self.orderScroll.content,
                    branchX,
                    y,
                    1,
                    orderRow.isLast and math.floor(ROW_HEIGHT / 2) + 1 or ROW_HEIGHT,
                    ProgressStyle.GROUP_BORDER
                )
                rectangle(
                    self.orderScroll.content,
                    branchX,
                    centreY,
                    10,
                    1,
                    ProgressStyle.GROUP_BORDER
                )
            end
            labelX = 12 + depth * branchGap
        else
            text(self.orderScroll.content, tostring(orderRow.index), 10, y, 34, ROW_HEIGHT, {
                font = id.Font.MUSEO_SANS_13PT_BOLD,
                colour = 0xF2C66DFF,
                alignHorizontal = ui.AlignMode.CENTRE,
            })
        end
        local supported = options.helperQuests ~= nil and options.helperQuests[linkedQuest.id] ~= nil
        local labelWidth = rowWidth - labelX - 36
        local icon
        if supported then
            local ok, measured = pcall(function()
                return config.Font.MUSEO_SANS_13PT_BOLD:GetStringWidth(linkedQuest.name, false)
            end)
            labelWidth = math.max(1, math.min(ok and measured or #linkedQuest.name * 7,
                rowWidth - labelX - 58))
            icon = ui.Sprite.new(self.orderScroll.content)
            icon:SetPos(labelX + labelWidth + 6, y + 8)
            icon:SetSize(16, 16)
            icon.spriteID = id.Sprite.RS3_ICON_MENU_TAB_QUEST_LIST_0
            icon.clickthrough = true
            UI.ForwardScrollWheel(icon, self.orderScroll)
        end
        local label = UI.ClickableText(
            self.orderScroll.content,
            linkedQuest.name,
            labelX,
            y,
            labelWidth,
            ROW_HEIGHT,
            {
                font = id.Font.MUSEO_SANS_13PT_BOLD,
                colour = linkedQuest.id == options.selectedID and 0xF2C66DFF
                    or (complete and ProgressStyle.TEXT_COMPLETE or ProgressStyle.TEXT_NORMAL),
                onScrollWheel = self.orderScroll._onScrollWheel,
                action = function()
                    if self.options.onSelect ~= nil then self.options.onSelect(linkedQuest.id) end
                end,
            }
        )
        self.orderEntries[#self.orderEntries + 1] = { questID = linkedQuest.id, root = label, icon = icon }
        ProgressStyle.CompletionMark(
            self.orderScroll.content,
            rowWidth - 26,
            y + math.floor((ROW_HEIGHT - 14) / 2),
            complete
        )
        if complete then
            ProgressStyle.Wedge(self.orderScroll.content, 1, y + 1, ROW_HEIGHT - 2):MoveToFront()
        end
        rectangle(
            self.orderScroll.content,
            0,
            y + ROW_HEIGHT - 1,
            rowWidth,
            1,
            ProgressStyle.ROW_DIVIDER
        )
        y = y + ROW_HEIGHT
    end
    if y > 0 then
        rectangle(self.orderScroll.content, 0, 0, 1, y, ProgressStyle.GROUP_BORDER):MoveToFront()
        rectangle(self.orderScroll.content, rowWidth - 1, 0, 1, y, ProgressStyle.GROUP_BORDER):MoveToFront()
        rectangle(self.orderScroll.content, 0, y - 1, rowWidth, 1, ProgressStyle.GROUP_BORDER):MoveToFront()
    end
    self.orderScroll:SetContentHeight(math.max(scrollHeight, y))
end

function QuestDetailsPanel:Render(state, options)
    self:Clear()
    options = options or {}
    self:RenderTitle(state, options)
    local columnTop = options.previousQuest ~= nil and LIST_TOP + 26 or LIST_TOP
    local scrollTop = columnTop + ProgressStyle.GROUP_HEIGHT
    local scrollHeight = math.max(90, self.root.height - scrollTop)
    local skillWidth = math.max(220, math.floor(self.root.width * 0.38))
    local questX = skillWidth + 12
    local questWidth = math.max(260, self.root.width - questX)
    self:RenderHeaders(state, columnTop, skillWidth, questX, questWidth)
    self:RenderSkills(state, skillWidth, scrollTop, scrollHeight)
    self:RenderOrder(state, options, questX, questWidth, scrollTop, scrollHeight)
end

function QuestDetailsPanel:Destroy()
    self:Clear()
    if self.requirementCombo ~= nil then self.requirementCombo:Destroy() end
    self.requirementCombo = nil
    if self.root ~= nil then self.root:Destroy() end
    self.root = nil
end

return QuestDetailsPanel
