-- MyLootTraking Alerts
-- Popup notifications and sound alerts with queue system

local _, MLT = ...

local ALERT_DURATION = 4  -- seconds
local ALERT_FADE = 1      -- fade out duration

----------------------------------------------
-- Initialize Alerts
----------------------------------------------
function MLT:InitAlerts()
    self.alertQueue = {}
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
        -- Show next alert in queue
        MLT:ProcessAlertQueue()
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
-- Alert Queue System
----------------------------------------------
function MLT:QueueAlert(alertData)
    table.insert(self.alertQueue, alertData)
    -- If no alert is currently showing, display immediately
    if not self.alertFrame:IsShown() then
        self:ProcessAlertQueue()
    end
end

function MLT:ProcessAlertQueue()
    if #self.alertQueue == 0 then return end

    local alert = table.remove(self.alertQueue, 1)
    local frame = self.alertFrame

    frame.icon:SetTexture(alert.texture)
    frame.topBorder:SetColorTexture(alert.borderR, alert.borderG, alert.borderB, 1)
    frame.title:SetText(alert.titleText)
    frame.title:SetTextColor(alert.borderR, alert.borderG, alert.borderB)
    frame.itemName:SetText(alert.itemText)
    frame.subtitle:SetText(alert.subtitleText)

    frame:SetAlpha(1)
    frame:Show()
    frame.fadeAnim:Stop()
    frame.fadeAnim:Play()
end

----------------------------------------------
-- Show Group Drop Alert
----------------------------------------------
function MLT:ShowGroupDropAlert(itemLink, entries)
    local L = self.L

    local itemID = self:ExtractItemID(itemLink)
    local itemName, _, itemQuality, _, _, _, _, _, _, itemTexture = GetItemInfo(itemID)

    local listNames = {}
    for _, entry in ipairs(entries) do
        table.insert(listNames, entry.listName)
    end

    self:QueueAlert({
        texture = itemTexture,
        borderR = 1, borderG = 0.6, borderB = 0,
        titleText = "|cffff9900!|r " .. L["ALERT_GROUP_DROP"],
        itemText = self:FormatItemWithColor(itemName, itemQuality),
        subtitleText = table.concat(listNames, ", "),
    })
end

----------------------------------------------
-- Show Personal Loot Alert
----------------------------------------------
function MLT:ShowPersonalLootAlert(itemLink, entries)
    local L = self.L

    local itemID = self:ExtractItemID(itemLink)
    local itemName, _, itemQuality, _, _, _, _, _, _, itemTexture = GetItemInfo(itemID)

    local listNames = {}
    for _, entry in ipairs(entries) do
        table.insert(listNames, entry.listName)
    end

    self:QueueAlert({
        texture = itemTexture,
        borderR = 0, borderG = 1, borderB = 0.3,
        titleText = "|cff00ff4c+|r " .. L["ALERT_PERSONAL_LOOT"],
        itemText = self:FormatItemWithColor(itemName, itemQuality),
        subtitleText = table.concat(listNames, ", "),
    })
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
        PlaySound(self.SOUNDS.DUNGEON_ENTER, "Master")
    end

    frame:SetAlpha(1)
    frame:Show()
    frame.fadeAnim:Stop()
    frame.fadeAnim:Play()
end
