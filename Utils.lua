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
        table.insert(parts, source.bossName)
    end
    if source.instance and source.instance ~= "" then
        table.insert(parts, source.instance)
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
StaticPopupDialogs["MLT_CONFIRM"] = {
    text = "%s",
    button1 = "OK",
    button2 = "Cancel",
    OnAccept = function() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function MLT:ShowConfirmDialog(text, onAccept)
    StaticPopupDialogs["MLT_CONFIRM"].text = text
    StaticPopupDialogs["MLT_CONFIRM"].OnAccept = onAccept
    StaticPopup_Show("MLT_CONFIRM")
end

----------------------------------------------
-- Input Dialog
----------------------------------------------
StaticPopupDialogs["MLT_INPUT"] = {
    text = "%s",
    button1 = "OK",
    button2 = "Cancel",
    hasEditBox = true,
    editBoxWidth = 250,
    OnAccept = function(self)
        local text = self.editBox:GetText()
        if self.data and self.data.callback then
            self.data.callback(text)
        end
    end,
    OnShow = function(self)
        if self.data and self.data.default then
            self.editBox:SetText(self.data.default)
        end
        self.editBox:HighlightText()
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
    local dialog = StaticPopup_Show("MLT_INPUT")
    if dialog then
        dialog.data = {callback = callback, default = default}
    end
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
