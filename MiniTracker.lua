-- MyLootTraking Mini Tracker
-- Compact, always-visible overlay showing tracked items

local _, MLT = ...

local ITEM_ROW_HEIGHT = 22
local TRACKER_WIDTH = 220

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

    -- NO background (transparent, clean look)

    -- Title bar (minimal)
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.title:SetPoint("TOPLEFT", 2, 0)
    frame.title:SetText(MLT.ADDON_COLOR .. "MyLootTraking|r")
    frame.title:SetAlpha(0.7)

    -- Progress text on the right of title
    frame.progress = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.progress:SetPoint("TOPRIGHT", -2, 0)
    frame.progress:SetTextColor(0.5, 0.8, 1)

    -- Drag to move (only when not locked)
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

    -- Item rows container
    frame.rows = {}

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
-- Create a single item row
----------------------------------------------
function MLT:CreateTrackerRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(TRACKER_WIDTH, ITEM_ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -(16 + (index - 1) * ITEM_ROW_HEIGHT))
    row:EnableMouse(true)

    -- Item icon
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.icon:SetPoint("LEFT", 2, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Item name
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
    row.name:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

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

    -- Collect all needed items across all lists
    local allItems = {}
    if self.db and self.db.lists then
        for listID, list in pairs(self.db.lists) do
            for _, item in ipairs(list.items) do
                if not item.obtained then
                    table.insert(allItems, {
                        itemID = item.itemID,
                        itemName = item.itemName,
                        itemLink = item.itemLink,
                        itemQuality = item.itemQuality,
                        itemTexture = item.itemTexture,
                        source = item.source,
                        listID = listID,
                        listName = list.name,
                        sortOrder = item.sortOrder or 0,
                    })
                end
            end
        end
    end

    -- Sort by list then sortOrder
    table.sort(allItems, function(a, b)
        if a.listName == b.listName then
            return a.sortOrder < b.sortOrder
        end
        return a.listName < b.listName
    end)

    -- Limit to max items
    local maxItems = self.db.config.trackerMaxItems or 10
    local displayCount = math.min(#allItems, maxItems)

    -- Update progress text
    local stats = self:GetOverallStatistics()
    if stats.totalItems > 0 then
        frame.progress:SetText(stats.progressText)
    else
        frame.progress:SetText("")
    end

    -- Create/update rows
    for i = 1, displayCount do
        if not frame.rows[i] then
            frame.rows[i] = self:CreateTrackerRow(frame, i)
        end

        local row = frame.rows[i]
        local item = allItems[i]

        row.icon:SetTexture(item.itemTexture or "Interface\\Icons\\INV_Misc_QuestionMark")
        row.name:SetText(self:FormatItemWithColor(item.itemName, item.itemQuality))
        row.itemLink = item.itemLink
        row.itemID = item.itemID
        row.listID = item.listID
        row:Show()
    end

    -- Hide extra rows
    for i = displayCount + 1, #frame.rows do
        frame.rows[i]:Hide()
    end

    -- Resize frame
    local totalHeight = 18 + displayCount * ITEM_ROW_HEIGHT
    frame:SetSize(TRACKER_WIDTH, math.max(totalHeight, 30))

    -- Show empty message if no items
    if displayCount == 0 then
        if not frame.emptyText then
            frame.emptyText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            frame.emptyText:SetPoint("TOPLEFT", 2, -16)
            frame.emptyText:SetTextColor(0.5, 0.5, 0.5)
        end
        frame.emptyText:SetText(self.L["NO_ITEMS_TRACKED"])
        frame.emptyText:Show()
    else
        if frame.emptyText then
            frame.emptyText:Hide()
        end
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

    local function InitMenu(self, level)
        local info

        -- Mark as obtained
        info = UIDropDownMenu_CreateInfo()
        info.text = L["MARK_OBTAINED"]
        info.notCheckable = true
        info.func = function()
            MLT:MarkItemObtained(listID, itemID, true)
            MLT:RebuildTrackedItemCache()
        end
        UIDropDownMenu_AddButton(info, level)

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

        -- Link to chat
        info = UIDropDownMenu_CreateInfo()
        info.text = L["LINK_TO_CHAT"]
        info.notCheckable = true
        info.func = function()
            local list = MLT.db.lists[listID]
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
