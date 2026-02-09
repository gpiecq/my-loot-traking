-- MyLootTraking Config Frame
-- Settings panel accessible via /mlt config, minimap right-click, and Interface Options

local _, MLT = ...

local CONFIG_WIDTH = 420
local CONFIG_HEIGHT = 480

----------------------------------------------
-- Show / Toggle Config Frame
----------------------------------------------
function MLT:ShowConfigFrame()
    if not self.configFrame then
        self:CreateConfigFrame()
    end
    self.configFrame:Show()
end

function MLT:ToggleConfigFrame()
    if self.configFrame and self.configFrame:IsShown() then
        self.configFrame:Hide()
    else
        self:ShowConfigFrame()
    end
end

----------------------------------------------
-- Create Config Frame
----------------------------------------------
function MLT:CreateConfigFrame()
    local L = self.L

    local frame = CreateFrame("Frame", "MLTConfigFrame", UIParent)
    frame:SetSize(CONFIG_WIDTH, CONFIG_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    tinsert(UISpecialFrames, "MLTConfigFrame")
    self:CreateBackdrop(frame, 0.92)

    -- Title bar
    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetPoint("TOPLEFT")
    titleBar:SetPoint("TOPRIGHT")
    titleBar:SetHeight(28)
    local titleBg = titleBar:CreateTexture(nil, "BACKGROUND")
    titleBg:SetAllPoints()
    titleBg:SetColorTexture(0.08, 0.08, 0.08, 1)

    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", 12, 0)
    title:SetText(self.ADDON_COLOR .. L["SETTINGS"] .. "|r")

    local closeBtn = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    closeBtn:SetPoint("RIGHT", -2, 0)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    -- Scroll content
    local scrollFrame, scrollChild = self:CreateScrollFrame(frame, CONFIG_WIDTH - 12, CONFIG_HEIGHT - 40)
    scrollFrame:SetPoint("TOP", 0, -32)

    local yOffset = -10

    -- ============================================
    -- SECTION: Alerts
    -- ============================================
    yOffset = self:CreateSectionHeader(scrollChild, L["ALERTS_SETTINGS"], yOffset)

    -- Enable popups
    yOffset = self:CreateCheckbox(scrollChild, L["ENABLE_POPUP"], yOffset, function(checked)
        self.db.config.enablePopup = checked
    end, self.db.config.enablePopup)

    -- Enable sounds
    yOffset = self:CreateCheckbox(scrollChild, L["ENABLE_SOUND"], yOffset, function(checked)
        self.db.config.enableSound = checked
    end, self.db.config.enableSound)

    -- Dungeon entry alert
    yOffset = self:CreateCheckbox(scrollChild, L["DUNGEON_ENTER_ALERT"], yOffset, function(checked)
        self.db.config.dungeonEnterAlert = checked
    end, self.db.config.dungeonEnterAlert)

    -- Lock alerts position
    yOffset = self:CreateCheckbox(scrollChild, L["LOCK_ALERTS"], yOffset, function(checked)
        self.db.config.alertsLocked = checked
    end, self.db.config.alertsLocked)

    yOffset = yOffset - 10

    -- ============================================
    -- SECTION: Tracker
    -- ============================================
    yOffset = self:CreateSectionHeader(scrollChild, L["TRACKER_SETTINGS"], yOffset)

    -- Max items
    yOffset = self:CreateSlider(scrollChild, L["TRACKER_MAX_ITEMS"], yOffset, 1, 30, 1,
        self.db.config.trackerMaxItems, function(value)
            self.db.config.trackerMaxItems = value
            self:RefreshMiniTracker()
        end)

    -- Transparency
    yOffset = self:CreateSlider(scrollChild, L["TRACKER_TRANSPARENCY"], yOffset, 0.1, 1.0, 0.05,
        self.db.config.trackerAlpha, function(value)
            self.db.config.trackerAlpha = value
            self:ApplyTrackerSettings()
        end)

    -- Scale
    yOffset = self:CreateSlider(scrollChild, L["TRACKER_SCALE"], yOffset, 0.5, 2.0, 0.1,
        self.db.config.trackerScale, function(value)
            self.db.config.trackerScale = value
            self:ApplyTrackerSettings()
        end)

    -- Lock tracker
    yOffset = self:CreateCheckbox(scrollChild, L["LOCK_TRACKER"], yOffset, function(checked)
        self.db.config.trackerLocked = checked
    end, self.db.config.trackerLocked)

    yOffset = yOffset - 10

    -- ============================================
    -- SECTION: General
    -- ============================================
    yOffset = self:CreateSectionHeader(scrollChild, L["GENERAL"], yOffset)

    -- Show obtained items
    yOffset = self:CreateCheckbox(scrollChild, L["SHOW_OBTAINED"], yOffset, function(checked)
        self.db.config.showObtained = checked
        self:RefreshMainFrame()
    end, self.db.config.showObtained)

    -- Reset button
    yOffset = yOffset - 15
    local resetBtn = self:CreateCleanButton(scrollChild, L["RESET"] .. " " .. L["SETTINGS"], 150, 26)
    resetBtn:SetPoint("TOPLEFT", 16, yOffset)
    resetBtn:SetScript("OnClick", function()
        self:ShowConfirmDialog("Reset all settings to defaults?", function()
            -- Reset config to defaults
            self.db.config = {
                enablePopup = true,
                enableSound = true,
                groupDropSound = "RaidWarning",
                personalLootSound = "LevelUp",
                dungeonEnterAlert = true,
                trackerMaxItems = 10,
                trackerAlpha = 0.8,
                trackerScale = 1.0,
                trackerLocked = false,
                alertsLocked = false,
                showObtained = false,
                minimapPos = 220,
            }
            self:ApplyTrackerSettings()
            self:RefreshAllUI()
            -- Recreate config frame
            self.configFrame:Hide()
            self.configFrame = nil
            self:ShowConfigFrame()
        end)
    end)

    scrollChild:SetHeight(math.abs(yOffset) + 60)
    self.configFrame = frame

    -- ============================================
    -- Register with Interface Options (Blizzard)
    -- ============================================
    self:RegisterInterfaceOptions()
end

----------------------------------------------
-- UI Builder Helpers
----------------------------------------------
function MLT:CreateSectionHeader(parent, text, yOffset)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", 12, yOffset)
    header:SetText(self.ADDON_COLOR .. text .. "|r")

    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", 12, yOffset - 14)
    line:SetPoint("RIGHT", parent, "RIGHT", -12, 0)
    line:SetHeight(1)
    line:SetColorTexture(0.25, 0.25, 0.25, 1)

    return yOffset - 24
end

function MLT:CreateCheckbox(parent, label, yOffset, onChange, defaultValue)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 12, yOffset)
    cb:SetSize(24, 24)
    cb:SetChecked(defaultValue)

    local text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    text:SetText(label)
    text:SetTextColor(1, 1, 1)

    cb:SetScript("OnClick", function(self)
        local checked = self:GetChecked()
        if onChange then onChange(checked) end
    end)

    return yOffset - 28
end

function MLT:CreateSlider(parent, label, yOffset, minVal, maxVal, step, defaultValue, onChange)
    local labelText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    labelText:SetPoint("TOPLEFT", 16, yOffset)
    labelText:SetText(label)
    labelText:SetTextColor(1, 1, 1)

    local valueText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    valueText:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -16, yOffset)
    valueText:SetTextColor(0.5, 0.8, 1)

    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", 16, yOffset - 18)
    slider:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    slider:SetHeight(16)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(defaultValue or minVal)

    -- Hide default labels
    slider.Low:SetText("")
    slider.High:SetText("")
    slider.Text:SetText("")

    local function UpdateValue(val)
        if step >= 1 then
            valueText:SetText(tostring(math.floor(val)))
        else
            valueText:SetText(format("%.2f", val))
        end
    end
    UpdateValue(defaultValue or minVal)

    slider:SetScript("OnValueChanged", function(self, value)
        UpdateValue(value)
        if onChange then onChange(value) end
    end)

    return yOffset - 48
end

----------------------------------------------
-- Register with Blizzard Interface Options
----------------------------------------------
function MLT:RegisterInterfaceOptions()
    local panel = CreateFrame("Frame")
    panel.name = "MyLootTraking"

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(self.ADDON_COLOR .. "MyLootTraking|r")

    local desc = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetText("v" .. self.version .. " - Loot Wishlist Tracker")
    desc:SetTextColor(0.7, 0.7, 0.7)

    local openBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    openBtn:SetSize(200, 30)
    openBtn:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -20)
    openBtn:SetText("Open Settings")
    openBtn:SetScript("OnClick", function()
        MLT:ShowConfigFrame()
    end)

    InterfaceOptions_AddCategory(panel)
    self.blizzPanel = panel
end
