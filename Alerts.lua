-- MyLootTraking Alerts
-- Popup notifications and sound alerts

local _, MLT = ...

local ALERT_DURATION = 5  -- seconds
local ALERT_FADE = 1      -- fade out duration

----------------------------------------------
-- Initialize Alerts
----------------------------------------------
function MLT:InitAlerts()
    self:CreateAlertFrame()
    self:CreateDungeonEntryFrame()
end

----------------------------------------------
-- Main Alert Frame (for item drops/loots)
----------------------------------------------
function MLT:CreateAlertFrame()
    local frame = CreateFrame("Frame", "MLTAlertFrame", UIParent)
    frame:SetSize(350, 80)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -120)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:Hide()

    -- Allow repositioning when alerts aren't locked
    frame:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and not MLT.db.config.alertsLocked then
            self:StartMoving()
        end
    end)
    frame:SetScript("OnMouseUp", function(self, button)
        self:StopMovingOrSizing()
        -- Save position
        local point, _, relPoint, x, y = self:GetPoint()
        MLT.db.config.alertPoint = {point, relPoint, x, y}
    end)

    -- Background
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetColorTexture(0, 0, 0, 0.85)

    -- Colored border (changes based on alert type)
    frame.topBorder = frame:CreateTexture(nil, "BORDER")
    frame.topBorder:SetPoint("TOPLEFT")
    frame.topBorder:SetPoint("TOPRIGHT")
    frame.topBorder:SetHeight(2)
    frame.topBorder:SetColorTexture(0, 0.8, 1, 1)

    -- Icon
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetSize(48, 48)
    frame.icon:SetPoint("LEFT", 12, 0)
    frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Title (alert type)
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.title:SetPoint("TOPLEFT", frame.icon, "TOPRIGHT", 10, -2)
    frame.title:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
    frame.title:SetJustifyH("LEFT")
    frame.title:SetTextColor(1, 0.82, 0)

    -- Item name
    frame.itemName = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    frame.itemName:SetPoint("LEFT", frame.icon, "RIGHT", 10, 0)
    frame.itemName:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
    frame.itemName:SetJustifyH("LEFT")

    -- Subtitle (list name)
    frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.subtitle:SetPoint("BOTTOMLEFT", frame.icon, "BOTTOMRIGHT", 10, 2)
    frame.subtitle:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
    frame.subtitle:SetJustifyH("LEFT")
    frame.subtitle:SetTextColor(0.7, 0.7, 0.7)

    -- Animation group for fade out
    frame.fadeAnim = frame:CreateAnimationGroup()
    local fade = frame.fadeAnim:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0)
    fade:SetDuration(ALERT_FADE)
    fade:SetStartDelay(ALERT_DURATION)
    frame.fadeAnim:SetScript("OnFinished", function()
        frame:Hide()
        frame:SetAlpha(1)
    end)

    -- Restore saved position
    if self.db and self.db.config.alertPoint then
        local p = self.db.config.alertPoint
        frame:ClearAllPoints()
        frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    end

    self.alertFrame = frame
end

----------------------------------------------
-- Show Group Drop Alert
----------------------------------------------
function MLT:ShowGroupDropAlert(itemLink, entries)
    local L = self.L
    local frame = self.alertFrame
    if not frame then return end

    local itemID = self:ExtractItemID(itemLink)
    local itemName, _, itemQuality, _, _, _, _, _, _, itemTexture = GetItemInfo(itemID)

    frame.icon:SetTexture(itemTexture)

    -- Orange border for group drop
    frame.topBorder:SetColorTexture(1, 0.6, 0, 1)

    frame.title:SetText("⚡ " .. L["ALERT_GROUP_DROP"])
    frame.title:SetTextColor(1, 0.6, 0)

    frame.itemName:SetText(self:FormatItemWithColor(itemName, itemQuality))

    -- Show which list(s) the item is in
    local listNames = {}
    for _, entry in ipairs(entries) do
        table.insert(listNames, entry.listName)
    end
    frame.subtitle:SetText(table.concat(listNames, ", "))

    frame:SetAlpha(1)
    frame:Show()
    frame.fadeAnim:Stop()
    frame.fadeAnim:Play()
end

----------------------------------------------
-- Show Personal Loot Alert
----------------------------------------------
function MLT:ShowPersonalLootAlert(itemLink, entries)
    local L = self.L
    local frame = self.alertFrame
    if not frame then return end

    local itemID = self:ExtractItemID(itemLink)
    local itemName, _, itemQuality, _, _, _, _, _, _, itemTexture = GetItemInfo(itemID)

    frame.icon:SetTexture(itemTexture)

    -- Green border for personal loot
    frame.topBorder:SetColorTexture(0, 1, 0.3, 1)

    frame.title:SetText("✅ " .. L["ALERT_PERSONAL_LOOT"])
    frame.title:SetTextColor(0, 1, 0.3)

    frame.itemName:SetText(self:FormatItemWithColor(itemName, itemQuality))

    local listNames = {}
    for _, entry in ipairs(entries) do
        table.insert(listNames, entry.listName)
    end
    frame.subtitle:SetText(table.concat(listNames, ", "))

    frame:SetAlpha(1)
    frame:Show()
    frame.fadeAnim:Stop()
    frame.fadeAnim:Play()
end

----------------------------------------------
-- Dungeon Entry Alert Frame
----------------------------------------------
function MLT:CreateDungeonEntryFrame()
    local frame = CreateFrame("Frame", "MLTDungeonEntryFrame", UIParent)
    frame:SetSize(320, 50)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -200)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:EnableMouse(true)
    frame:Hide()

    -- Background
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetColorTexture(0, 0, 0, 0.85)

    -- Blue border
    frame.topBorder = frame:CreateTexture(nil, "BORDER")
    frame.topBorder:SetPoint("TOPLEFT")
    frame.topBorder:SetPoint("TOPRIGHT")
    frame.topBorder:SetHeight(2)
    frame.topBorder:SetColorTexture(0, 0.6, 1, 1)

    -- Text
    frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.text:SetPoint("CENTER", 0, 6)
    frame.text:SetTextColor(0, 0.8, 1)

    -- Subtitle
    frame.hint = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.hint:SetPoint("CENTER", 0, -8)
    frame.hint:SetTextColor(0.6, 0.6, 0.6)

    -- Click to see details
    frame:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            if MLT.ShowMainFrame then
                MLT:ShowMainFrame()
            end
            self:Hide()
        end
    end)

    -- Auto-hide after duration
    frame.fadeAnim = frame:CreateAnimationGroup()
    local fade = frame.fadeAnim:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0)
    fade:SetDuration(ALERT_FADE)
    fade:SetStartDelay(8) -- longer duration for dungeon entry
    frame.fadeAnim:SetScript("OnFinished", function()
        frame:Hide()
        frame:SetAlpha(1)
    end)

    self.dungeonEntryFrame = frame
end

----------------------------------------------
-- Show Dungeon Entry Alert
----------------------------------------------
function MLT:ShowDungeonEntryAlert(items, zoneName)
    local L = self.L
    local frame = self.dungeonEntryFrame
    if not frame then return end

    frame.text:SetText(format(L["ALERT_DUNGEON_ENTER"], #items))
    frame.hint:SetText(L["ALERT_CLICK_DETAILS"])

    -- Store items for detail view
    frame.items = items
    frame.zoneName = zoneName

    -- Play dungeon entry sound
    if self.db.config.enableSound then
        PlaySoundFile(self.SOUNDS.DUNGEON_ENTER, "Master")
    end

    frame:SetAlpha(1)
    frame:Show()
    frame.fadeAnim:Stop()
    frame.fadeAnim:Play()
end
