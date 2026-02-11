-- MyLootTraking Mini Tracker
-- Compact, always-visible overlay showing tracked items grouped by list

local _, MLT = ...

local ITEM_ROW_HEIGHT = 32
local HEADER_HEIGHT = 18
local TRACKER_WIDTH = 240

----------------------------------------------
-- Initialize Mini Tracker
----------------------------------------------
function MLT:InitMiniTracker()
    self:CreateMiniTrackerFrame()
    C_Timer.After(2, function()
        self:RefreshMiniTracker()
    end)
end

----------------------------------------------
-- Create the Tracker Frame
----------------------------------------------
function MLT:CreateMiniTrackerFrame()
    local frame = CreateFrame("Frame", "MLTMiniTracker", UIParent)
    frame:SetSize(TRACKER_WIDTH, 30)
    frame:SetPoint("RIGHT", UIParent, "RIGHT", -20, 0)
    frame:SetFrameStrata("MEDIUM")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)

    -- Title button (clickable to collapse/expand all)
    frame.titleBtn = CreateFrame("Button", nil, frame)
    frame.titleBtn:SetSize(TRACKER_WIDTH, 16)
    frame.titleBtn:SetPoint("TOPLEFT", 0, 0)

    frame.titleBtn.text = frame.titleBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.titleBtn.text:SetPoint("LEFT", 2, 0)
    frame.titleBtn.text:SetAlpha(0.7)

    -- Progress text on the right of title
    frame.progress = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.progress:SetPoint("TOPRIGHT", -2, 0)
    frame.progress:SetTextColor(0.5, 0.8, 1)

    -- Click title to collapse/expand all
    frame.titleBtn:SetScript("OnClick", function()
        MLT.db.config.trackerCollapsed = not MLT.db.config.trackerCollapsed
        MLT:RefreshMiniTracker()
    end)

    -- Drag to move (on the title bar, only when not locked)
    frame.titleBtn:RegisterForDrag("LeftButton")
    frame.titleBtn:SetScript("OnDragStart", function()
        if not MLT.db.config.trackerLocked then
            frame:StartMoving()
        end
    end)
    frame.titleBtn:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        local point, _, relPoint, x, y = frame:GetPoint()
        MLT.db.config.trackerPoint = {point, relPoint, x, y}
    end)

    -- Drag on frame body too
    frame:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and not MLT.db.config.trackerLocked then
            self:StartMoving()
        end
    end)
    frame:SetScript("OnMouseUp", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        MLT.db.config.trackerPoint = {point, relPoint, x, y}
    end)

    -- Pools
    frame.rows = {}
    frame.headers = {}

    -- Restore saved position
    if self.db and self.db.config.trackerPoint then
        local p = self.db.config.trackerPoint
        frame:ClearAllPoints()
        frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    end

    -- Apply settings
    self:ApplyTrackerSettings(frame)

    self.miniTracker = frame
end

----------------------------------------------
-- Apply Settings (transparency, scale)
----------------------------------------------
function MLT:ApplyTrackerSettings(frame)
    if not frame then frame = self.miniTracker end
    if not frame then return end

    local alpha = self.db.config.trackerAlpha or 0.8
    local scale = self.db.config.trackerScale or 1.0

    frame:SetAlpha(alpha)
    frame:SetScale(scale)
end

----------------------------------------------
-- Create a list section header (pooled)
----------------------------------------------
function MLT:AcquireTrackerHeader(parent, index)
    local frame = self.miniTracker
    if not frame.headers[index] then
        local header = CreateFrame("Button", nil, parent)
        header:SetSize(TRACKER_WIDTH, HEADER_HEIGHT)
        header:EnableMouse(true)

        header.text = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        header.text:SetPoint("LEFT", 2, 0)

        header.progress = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        header.progress:SetPoint("RIGHT", -2, 0)
        header.progress:SetTextColor(0.5, 0.8, 1)
        header.progress:SetScale(0.9)

        header.line = header:CreateTexture(nil, "ARTWORK")
        header.line:SetPoint("BOTTOMLEFT", 2, 0)
        header.line:SetPoint("BOTTOMRIGHT", -2, 0)
        header.line:SetHeight(1)
        header.line:SetColorTexture(0.3, 0.3, 0.3, 0.4)

        frame.headers[index] = header
    end
    return frame.headers[index]
end

----------------------------------------------
-- Create a single item row (pooled)
----------------------------------------------
function MLT:CreateTrackerRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(TRACKER_WIDTH, ITEM_ROW_HEIGHT)
    row:EnableMouse(true)

    -- Item icon
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(20, 20)
    row.icon:SetPoint("LEFT", 8, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Item name (top line)
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 4, 0)
    row.name:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    -- Source/progress text (bottom line, smaller)
    row.sourceText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightExtraSmall")
    row.sourceText:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -1)
    row.sourceText:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.sourceText:SetJustifyH("LEFT")
    row.sourceText:SetWordWrap(false)
    row.sourceText:SetTextColor(0.6, 0.6, 0.6)

    -- Tooltip on hover
    row:SetScript("OnEnter", function(self)
        if self.itemLink then
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:SetHyperlink(self.itemLink)
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Right-click for options
    row:SetScript("OnMouseDown", function(self, button)
        if button == "RightButton" and self.itemID and self.listID then
            MLT:ShowItemContextMenu(self.listID, self.itemID)
        end
    end)

    row:Hide()
    return row
end

----------------------------------------------
-- Refresh Mini Tracker
----------------------------------------------
function MLT:RefreshMiniTracker()
    local frame = self.miniTracker
    if not frame then return end

    local currentChar = self.playerFullName

    -- Collect lists and their items for current character
    local listGroups = {}  -- ordered list of {listID, listName, listType, items}
    local listOrder = {}

    if self.db and self.db.lists then
        for listID, list in pairs(self.db.lists) do
            local showList = false
            if list.listType == "character" then
                showList = (list.character == currentChar)
            else
                showList = true -- objective/farm lists are shared
            end

            if showList then
                local items = {}
                for _, item in ipairs(list.items) do
                    -- For farm lists, show all items (even completed); for others, only non-obtained
                    local showItem = false
                    if list.listType == "farm" then
                        showItem = true
                    else
                        showItem = not item.obtained
                    end

                    if showItem then
                        table.insert(items, {
                            itemID = item.itemID,
                            itemName = item.itemName,
                            itemLink = item.itemLink,
                            itemQuality = item.itemQuality,
                            itemTexture = item.itemTexture,
                            source = item.source,
                            listID = listID,
                            listName = list.name,
                            listType = list.listType,
                            sortOrder = item.sortOrder or 0,
                            targetQty = item.targetQty,
                            currentQty = item.currentQty,
                            obtained = item.obtained,
                        })
                    end
                end

                if #items > 0 then
                    table.sort(items, function(a, b)
                        return a.sortOrder < b.sortOrder
                    end)
                    table.insert(listOrder, {
                        listID = listID,
                        listName = list.name,
                        listType = list.listType,
                        sortOrder = list.sortOrder or 0,
                        items = items,
                    })
                end
            end
        end
    end

    -- Sort list groups
    table.sort(listOrder, function(a, b)
        return (a.sortOrder or 0) < (b.sortOrder or 0)
    end)

    -- Update progress text
    local stats = self:GetCharacterStatistics(currentChar)
    if stats.totalItems > 0 then
        frame.progress:SetText(stats.progressText)
    else
        frame.progress:SetText("")
    end

    -- Global collapsed state
    local collapsed = self.db.config.trackerCollapsed
    local arrow = collapsed and "|cffaaaaaa+|r " or "|cffaaaaaa-|r "
    frame.titleBtn.text:SetText(arrow .. MLT.ADDON_COLOR .. "MyLootTraking|r")

    -- Hide everything first
    for _, h in ipairs(frame.headers) do h:Hide() end
    for _, r in ipairs(frame.rows) do r:Hide() end
    if frame.emptyText then frame.emptyText:Hide() end

    if collapsed then
        frame:SetSize(TRACKER_WIDTH, 18)
        return
    end

    -- Layout: title (16px) + per-list headers and items
    local yOffset = 18  -- start below title
    local rowIndex = 0
    local headerIndex = 0
    local totalItems = 0

    for _, group in ipairs(listOrder) do
        headerIndex = headerIndex + 1
        local header = self:AcquireTrackerHeader(frame, headerIndex)

        local listCollapsed = self.db.config.trackerCollapsedLists[group.listID]
        local listArrow = listCollapsed and "|cffaaaaaa+|r " or "|cffaaaaaa-|r "

        -- List name with type indicator
        local headerText = listArrow
        if group.listType == "farm" then
            headerText = headerText .. "|cff44cc44" .. group.listName .. "|r"
        else
            headerText = headerText .. "|cff88aacc" .. group.listName .. "|r"
        end
        header.text:SetText(headerText)

        -- List progress
        local obtained, total, percent = self:GetListProgress(group.listID)
        header.progress:SetText(format(self.L["PROGRESS"], obtained, total, percent))

        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", 0, -yOffset)

        -- Click to toggle collapse per list
        header.listID = group.listID
        header:SetScript("OnClick", function()
            MLT.db.config.trackerCollapsedLists[group.listID] = not MLT.db.config.trackerCollapsedLists[group.listID]
            MLT:RefreshMiniTracker()
        end)

        header:Show()
        yOffset = yOffset + HEADER_HEIGHT

        -- Show items if not collapsed
        if not listCollapsed then
            for _, item in ipairs(group.items) do
                rowIndex = rowIndex + 1
                totalItems = totalItems + 1

                if not frame.rows[rowIndex] then
                    frame.rows[rowIndex] = self:CreateTrackerRow(frame, rowIndex)
                end

                local row = frame.rows[rowIndex]

                row.icon:SetTexture(item.itemTexture or "Interface\\Icons\\INV_Misc_QuestionMark")

                -- Name display
                local nameText = self:FormatItemWithColor(item.itemName, item.itemQuality)
                if item.obtained then
                    nameText = "|cff666666" .. (item.itemName or "?") .. "|r"
                    row.icon:SetDesaturated(true)
                    row.icon:SetAlpha(0.5)
                else
                    row.icon:SetDesaturated(false)
                    row.icon:SetAlpha(1)
                end
                row.name:SetText(nameText)

                -- Source/progress line
                if item.listType == "farm" then
                    local cur = item.currentQty or 0
                    local tgt = item.targetQty or 1
                    local farmColor = cur >= tgt and "|cff00ff00" or "|cffffff00"
                    row.sourceText:SetText(farmColor .. format(self.L["FARM_PROGRESS"], cur, tgt) .. "|r")
                else
                    row.sourceText:SetText(self:GetSourceText(item.source))
                end

                row.itemLink = item.itemLink
                row.itemID = item.itemID
                row.listID = item.listID

                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", 0, -yOffset)
                row:Show()
                yOffset = yOffset + ITEM_ROW_HEIGHT
            end
        end
    end

    -- Resize frame
    frame:SetSize(TRACKER_WIDTH, math.max(yOffset, 30))

    -- Show empty message if no items
    if totalItems == 0 and headerIndex == 0 then
        if not frame.emptyText then
            frame.emptyText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            frame.emptyText:SetPoint("TOPLEFT", 2, -18)
            frame.emptyText:SetTextColor(0.5, 0.5, 0.5)
        end
        frame.emptyText:SetText(self.L["NO_ITEMS_TRACKED"])
        frame.emptyText:Show()
    end
end

----------------------------------------------
-- Toggle Mini Tracker
----------------------------------------------
function MLT:ToggleMiniTracker()
    local L = self.L
    if self.miniTracker:IsShown() then
        self.miniTracker:Hide()
        self:Print(L["TRACKER_HIDDEN"])
    else
        self.miniTracker:Show()
        self:RefreshMiniTracker()
        self:Print(L["TRACKER_SHOWN"])
    end
end

----------------------------------------------
-- Item Context Menu (right-click in tracker)
----------------------------------------------
function MLT:ShowItemContextMenu(listID, itemID)
    local L = self.L

    if not self.itemContextMenu then
        self.itemContextMenu = CreateFrame("Frame", "MLTItemContextMenu", UIParent, "UIDropDownMenuTemplate")
    end

    -- Determine if this is a farm list
    local list = self.db.lists[listID]
    local isFarm = list and list.listType == "farm"

    local function InitMenu(self, level)
        local info

        if isFarm then
            -- Set target quantity
            info = UIDropDownMenu_CreateInfo()
            info.text = L["SET_TARGET_QTY"]
            info.notCheckable = true
            info.func = function()
                -- Find current target
                local currentTarget = 1
                if list then
                    for _, item in ipairs(list.items) do
                        if item.itemID == itemID then
                            currentTarget = item.targetQty or 1
                            break
                        end
                    end
                end
                MLT:ShowInputDialog(L["ENTER_TARGET_QTY"], function(input)
                    local qty = tonumber(input)
                    if qty and qty > 0 then
                        MLT:SetFarmItemTargetQty(listID, itemID, qty)
                    end
                end, tostring(currentTarget))
            end
            UIDropDownMenu_AddButton(info, level)

            -- Reset count
            info = UIDropDownMenu_CreateInfo()
            info.text = L["RESET_COUNT"]
            info.notCheckable = true
            info.func = function()
                MLT:SetFarmItemCount(listID, itemID, 0)
                MLT:RebuildTrackedItemCache()
            end
            UIDropDownMenu_AddButton(info, level)
        else
            -- Mark as obtained
            info = UIDropDownMenu_CreateInfo()
            info.text = L["MARK_OBTAINED"]
            info.notCheckable = true
            info.func = function()
                MLT:MarkItemObtained(listID, itemID, true)
                MLT:RebuildTrackedItemCache()
            end
            UIDropDownMenu_AddButton(info, level)
        end

        -- Edit note
        info = UIDropDownMenu_CreateInfo()
        info.text = L["EDIT_NOTE"]
        info.notCheckable = true
        info.func = function()
            MLT:ShowInputDialog(L["NOTE_PLACEHOLDER"], function(note)
                MLT:SetItemNote(listID, itemID, note)
            end)
        end
        UIDropDownMenu_AddButton(info, level)

        -- Edit source (only for non-farm)
        if not isFarm then
            info = UIDropDownMenu_CreateInfo()
            info.text = L["EDIT_SOURCE"]
            info.notCheckable = true
            info.func = function()
                local currentSource = ""
                if list then
                    for _, item in ipairs(list.items) do
                        if item.itemID == itemID then
                            local parts = {}
                            if item.source and item.source.bossName and item.source.bossName ~= "" then
                                table.insert(parts, item.source.bossName)
                            end
                            if item.source and item.source.instance and item.source.instance ~= "" then
                                table.insert(parts, item.source.instance)
                            end
                            currentSource = table.concat(parts, " - ")
                            break
                        end
                    end
                end
                MLT:ShowInputDialog(L["ENTER_SOURCE"], function(text)
                    if text and text ~= "" then
                        local bossName, instance
                        if text:find(" - ") then
                            bossName, instance = text:match("^(.+) %- (.+)$")
                        else
                            bossName = text
                        end
                        MLT:SetItemSource(listID, itemID, {
                            type = "boss",
                            bossName = (bossName and bossName ~= "") and bossName or nil,
                            instance = (instance and instance ~= "") and instance or nil,
                        })
                    end
                end, currentSource)
            end
            UIDropDownMenu_AddButton(info, level)
        end

        -- Link to chat
        info = UIDropDownMenu_CreateInfo()
        info.text = L["LINK_TO_CHAT"]
        info.notCheckable = true
        info.func = function()
            if list then
                for _, item in ipairs(list.items) do
                    if item.itemID == itemID and item.itemLink then
                        ChatFrame_OpenChat(item.itemLink)
                        break
                    end
                end
            end
        end
        UIDropDownMenu_AddButton(info, level)

        -- Wowhead lookup
        info = UIDropDownMenu_CreateInfo()
        info.text = L["WOWHEAD_LINK"]
        info.notCheckable = true
        info.func = function()
            local url = MLT:GetWowheadURL(itemID)
            MLT:ShowCopyDialog(L["WOWHEAD_URL_TITLE"], url)
        end
        UIDropDownMenu_AddButton(info, level)

        -- Separator
        info = UIDropDownMenu_CreateInfo()
        info.disabled = true
        info.notCheckable = true
        UIDropDownMenu_AddButton(info, level)

        -- Remove item
        info = UIDropDownMenu_CreateInfo()
        info.text = "|cffff4444" .. L["REMOVE_ITEM"] .. "|r"
        info.notCheckable = true
        info.func = function()
            MLT:RemoveItem(listID, itemID)
            MLT:RebuildTrackedItemCache()
        end
        UIDropDownMenu_AddButton(info, level)
    end

    UIDropDownMenu_Initialize(self.itemContextMenu, InitMenu, "MENU")
    ToggleDropDownMenu(1, nil, self.itemContextMenu, "cursor", 0, 0)
end
