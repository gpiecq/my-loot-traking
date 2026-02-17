-- MyLootTraking Utils
-- Helper functions used throughout the addon

local _, MLT = ...

----------------------------------------------
-- String Utilities
----------------------------------------------
function MLT:Trim(str)
    if not str then return "" end
    return str:match("^%s*(.-)%s*$")
end

function MLT:Split(str, sep)
    local parts = {}
    for part in str:gmatch("[^" .. sep .. "]+") do
        table.insert(parts, part)
    end
    return parts
end

----------------------------------------------
-- Item Link Parsing
----------------------------------------------
function MLT:ExtractItemID(input)
    if not input then return nil end

    -- Try as number first
    local id = tonumber(input)
    if id then return id end

    -- Try to extract from item link: |cff...|Hitem:12345:...|h[Name]|h|r
    id = tonumber(input:match("item:(%d+)"))
    if id then return id end

    return nil
end

----------------------------------------------
-- Formatting
----------------------------------------------
function MLT:FormatItemWithColor(itemName, itemQuality)
    local hex = self.QUALITY_HEX[itemQuality] or self.QUALITY_HEX[1]
    return hex .. (itemName or "?") .. "|r"
end

function MLT:GetSourceText(source)
    if not source then return self.L["SOURCE_UNKNOWN"] end
    local L = self.L

    local parts = {}
    if source.bossName and source.bossName ~= "" then
        local bossText = source.bossName
        -- Translate boss name if locale table exists
        if self.BossLocale and self.BossLocale[bossText] then
            bossText = self.BossLocale[bossText]
        end
        table.insert(parts, bossText)
    end
    if source.instance and source.instance ~= "" then
        local instText = source.instance
        -- Translate instance name if locale table exists
        if self.InstanceLocale and self.InstanceLocale[instText] then
            instText = self.InstanceLocale[instText]
        end
        -- Add difficulty indicator: (N) Normal, (H) Heroic
        if source.difficulty == "H" then
            instText = instText .. " |cffff6600(H)|r"
        elseif source.difficulty == "N" then
            instText = instText .. " |cff00ff00(N)|r"
        end
        table.insert(parts, instText)
    end

    if #parts > 0 then
        return table.concat(parts, " - ")
    end

    -- Fallback to type
    local typeLabels = {
        boss = L["SOURCE_BOSS"],
        dungeon = L["SOURCE_DUNGEON"],
        raid = L["SOURCE_RAID"],
        quest = L["SOURCE_QUEST"],
        mob = L["SOURCE_MOB"],
        vendor = L["SOURCE_VENDOR"],
        crafted = L["SOURCE_CRAFTED"],
        pvp = L["SOURCE_PVP"],
    }
    return typeLabels[source.type] or L["SOURCE_UNKNOWN"]
end

function MLT:GetSourceTypeText(sourceType)
    local L = self.L
    local typeLabels = {
        boss = L["SOURCE_BOSS"],
        dungeon = L["SOURCE_DUNGEON"],
        raid = L["SOURCE_RAID"],
        quest = L["SOURCE_QUEST"],
        mob = L["SOURCE_MOB"],
        vendor = L["SOURCE_VENDOR"],
        crafted = L["SOURCE_CRAFTED"],
        pvp = L["SOURCE_PVP"],
        unknown = L["SOURCE_UNKNOWN"],
    }
    return typeLabels[sourceType] or L["SOURCE_UNKNOWN"]
end

----------------------------------------------
-- Class Colors
----------------------------------------------
local CLASS_COLORS = {
    WARRIOR = {r = 0.78, g = 0.61, b = 0.43},
    PALADIN = {r = 0.96, g = 0.55, b = 0.73},
    HUNTER = {r = 0.67, g = 0.83, b = 0.45},
    ROGUE = {r = 1.00, g = 0.96, b = 0.41},
    PRIEST = {r = 1.00, g = 1.00, b = 1.00},
    SHAMAN = {r = 0.00, g = 0.44, b = 0.87},
    MAGE = {r = 0.25, g = 0.78, b = 0.92},
    WARLOCK = {r = 0.53, g = 0.53, b = 0.93},
    DRUID = {r = 1.00, g = 0.49, b = 0.04},
}

function MLT:GetClassColor(class)
    return CLASS_COLORS[class] or {r = 1, g = 1, b = 1}
end

function MLT:ColorByClass(text, class)
    local c = self:GetClassColor(class)
    return format("|cff%02x%02x%02x%s|r", c.r * 255, c.g * 255, c.b * 255, text)
end

----------------------------------------------
-- Frame Utilities
----------------------------------------------
function MLT:CreateBackdrop(frame, alpha)
    alpha = alpha or 0.85
    -- Apply BackdropTemplate mixin if SetBackdrop is not available natively
    if not frame.SetBackdrop and BackdropTemplateMixin then
        Mixin(frame, BackdropTemplateMixin)
    end
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.06, 0.06, 0.06, alpha)
    frame:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
end

function MLT:CreateCleanButton(parent, text, width, height)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(width or 100, height or 24)

    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints()
    btn.bg:SetColorTexture(0.15, 0.15, 0.15, 0.9)

    btn.border = btn:CreateTexture(nil, "BORDER")
    btn.border:SetPoint("TOPLEFT", -1, 1)
    btn.border:SetPoint("BOTTOMRIGHT", 1, -1)
    btn.border:SetColorTexture(0.3, 0.3, 0.3, 1)

    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.text:SetPoint("CENTER")
    btn.text:SetText(text or "")
    btn.text:SetTextColor(1, 1, 1, 1)

    btn:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(0.25, 0.25, 0.25, 0.9)
    end)
    btn:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(0.15, 0.15, 0.15, 0.9)
    end)

    return btn
end

function MLT:CreateEditBox(parent, width, height, multiLine)
    local eb = CreateFrame("EditBox", nil, parent)
    eb:SetSize(width or 200, height or 24)
    eb:SetFontObject(ChatFontNormal)
    eb:SetAutoFocus(false)
    eb:SetTextInsets(6, 6, 4, 4)

    if multiLine then
        eb:SetMultiLine(true)
    end

    local bg = eb:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)

    local border = eb:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetColorTexture(0.3, 0.3, 0.3, 1)

    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    return eb
end

----------------------------------------------
-- Scroll Frame Utility
----------------------------------------------
function MLT:CreateScrollFrame(parent, width, height)
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(width, height)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(width - 20, 1) -- height will grow
    scrollFrame:SetScrollChild(scrollChild)

    -- Style scrollbar
    local scrollBar = scrollFrame.ScrollBar
    if scrollBar then
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", -2, -18)
        scrollBar:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", -2, 18)
    end

    return scrollFrame, scrollChild
end

----------------------------------------------
-- Confirmation Dialog
----------------------------------------------
local confirmDialogID = 0

function MLT:ShowConfirmDialog(text, onAccept)
    confirmDialogID = confirmDialogID + 1
    local dialogName = "MLT_CONFIRM_" .. confirmDialogID

    StaticPopupDialogs[dialogName] = {
        text = text,
        button1 = "OK",
        button2 = "Cancel",
        OnAccept = onAccept or function() end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show(dialogName)
end

----------------------------------------------
-- Input Dialog
----------------------------------------------
-- Compat: find editBox on dialog (lowercase in old clients, uppercase in Anniversary)
local function GetPopupEditBox(dialog)
    return dialog.EditBox or dialog.editBox or _G[dialog:GetName() .. "EditBox"]
end

StaticPopupDialogs["MLT_INPUT"] = {
    text = "%s",
    button1 = "OK",
    button2 = "Cancel",
    hasEditBox = true,
    editBoxWidth = 250,
    OnAccept = function(self)
        local eb = GetPopupEditBox(self)
        if eb then
            local text = eb:GetText()
            if self.data and self.data.callback then
                self.data.callback(text)
            end
        end
    end,
    OnShow = function(self)
        local eb = GetPopupEditBox(self)
        if eb then
            if self.data and self.data.default then
                eb:SetText(self.data.default)
            end
            eb:HighlightText()
        end
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        local text = self:GetText()
        if parent.data and parent.data.callback then
            parent.data.callback(text)
        end
        parent:Hide()
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function MLT:ShowInputDialog(text, callback, default)
    StaticPopupDialogs["MLT_INPUT"].text = text
    StaticPopup_Show("MLT_INPUT", nil, nil, {callback = callback, default = default})
end

----------------------------------------------
-- Copy Dialog (read-only editbox for URL copy)
----------------------------------------------
StaticPopupDialogs["MLT_COPY"] = {
    text = "%s",
    button1 = "OK",
    hasEditBox = true,
    editBoxWidth = 300,
    OnShow = function(self)
        local eb = GetPopupEditBox(self)
        if eb and self.data and self.data.url then
            eb:SetText(self.data.url)
            eb:HighlightText()
            eb:SetFocus()
        end
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function MLT:ShowCopyDialog(title, url)
    StaticPopupDialogs["MLT_COPY"].text = title
    StaticPopup_Show("MLT_COPY", nil, nil, {url = url})
end

----------------------------------------------
-- Build Wowhead URL with locale
----------------------------------------------
function MLT:GetWowheadURL(itemID)
    local locale = GetLocale()
    local lang = ""
    if locale == "frFR" then
        lang = "fr/"
    elseif locale == "deDE" then
        lang = "de/"
    elseif locale == "esES" or locale == "esMX" then
        lang = "es/"
    elseif locale == "ruRU" then
        lang = "ru/"
    elseif locale == "ptBR" then
        lang = "pt/"
    elseif locale == "koKR" then
        lang = "ko/"
    end
    return "https://www.wowhead.com/tbc/" .. lang .. "item=" .. itemID
end


----------------------------------------------
-- Encode/Decode for import/export
----------------------------------------------
-- Simple base64-like encoding for sharing
local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

function MLT:Encode(data)
    local str = ""
    -- Simple serialization: comma-separated itemIDs
    if type(data) == "table" then
        local parts = {}
        for _, item in ipairs(data) do
            table.insert(parts, tostring(item.itemID))
        end
        str = table.concat(parts, ",")
    else
        str = tostring(data)
    end
    return "MLT:" .. str
end

function MLT:Decode(encoded)
    if not encoded or not encoded:find("^MLT:") then
        return nil
    end
    local str = encoded:sub(5)
    local items = {}
    for id in str:gmatch("(%d+)") do
        table.insert(items, tonumber(id))
    end
    return items
end

----------------------------------------------
-- Debug UI Freeze (scan all frames for blockers)
----------------------------------------------
function MLT:DebugUIFreeze()
    self:Print("=== MLT UI Debug ===")

    -- 1. Check UIParent mouse state
    self:Print("UIParent mouse: " .. tostring(UIParent:IsMouseEnabled()))

    -- 2. Check mouse focus
    if GetMouseFoci then
        local foci = GetMouseFoci()
        if foci then
            for i, f in ipairs(foci) do
                self:Print("MouseFocus " .. i .. ": " .. (f:GetName() or "unnamed") .. " strata=" .. f:GetFrameStrata())
            end
        end
    elseif GetMouseFocus then
        local f = GetMouseFocus()
        if f then
            self:Print("MouseFocus: " .. (f:GetName() or "unnamed") .. " strata=" .. f:GetFrameStrata())
        end
    end

    -- 3. Check known MLT frames
    local mltFrames = {
        {"MLTMainFrame", self.mainFrame},
        {"MLTSearchFrame", self.searchFrame},
        {"MLTAlertFrame", self.alertFrame},
        {"MLTDungeonEntry", self.dungeonEntryFrame},
        {"MLTMiniTracker", self.miniTracker},
        {"MLTConfigFrame", self.configFrame},
    }
    for _, info in ipairs(mltFrames) do
        local name, frame = info[1], info[2]
        if frame and frame:IsShown() then
            self:Print("|cffff0000SHOWN:|r " .. name .. " strata=" .. frame:GetFrameStrata() .. " mouse=" .. tostring(frame:IsMouseEnabled()))
        end
    end

    -- 4. Check ItemRefTooltip
    if ItemRefTooltip and ItemRefTooltip:IsShown() then
        self:Print("|cffff0000SHOWN:|r ItemRefTooltip strata=" .. ItemRefTooltip:GetFrameStrata())
    end

    -- 5. Check DropDownLists
    for i = 1, 5 do
        local dd = _G["DropDownList" .. i]
        if dd and dd:IsShown() then
            self:Print("|cffff0000SHOWN:|r DropDownList" .. i .. " w=" .. math.floor(dd:GetWidth()) .. " h=" .. math.floor(dd:GetHeight()))
        end
    end

    -- 6. Check StaticPopups
    for i = 1, 4 do
        local popup = _G["StaticPopup" .. i]
        if popup and popup:IsShown() then
            self:Print("|cffff0000SHOWN:|r StaticPopup" .. i .. " text=" .. tostring(popup.text and popup.text:GetText()))
        end
    end

    -- 7. Scan ALL visible frames at high strata with mouse enabled
    self:Print("-- High strata mouse frames --")
    local found = 0
    local f = EnumerateFrames()
    while f do
        if f:IsVisible() and f:IsMouseEnabled() then
            local s = f:GetFrameStrata()
            if s == "FULLSCREEN" or s == "FULLSCREEN_DIALOG" or s == "TOOLTIP" or s == "DIALOG" then
                local w, h = f:GetWidth(), f:GetHeight()
                if w > 200 or h > 200 then
                    local name = f:GetName() or "unnamed"
                    self:Print("  " .. name .. " strata=" .. s .. " size=" .. math.floor(w) .. "x" .. math.floor(h) .. " alpha=" .. string.format("%.2f", f:GetAlpha()))
                    found = found + 1
                end
            end
        end
        f = EnumerateFrames(f)
    end
    if found == 0 then
        self:Print("  (none)")
    end

    -- 8. Try to fix
    self:Print("-- Attempting fix --")
    CloseDropDownMenus()
    if ItemRefTooltip then ItemRefTooltip:Hide() end
    UIParent:EnableMouse(false)
    self:Print("Done. Can you click now?")
end
