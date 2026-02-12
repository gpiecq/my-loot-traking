-- MyLootTraking Core
-- Main addon initialization, event handling, and global namespace

local ADDON_NAME, MLT = ...
_G["MyLootTraking"] = MLT

MLT.version = "1.0.0"
MLT.L = MLT.L or {}

-- Color constants (WoW item quality colors)
MLT.COLORS = {
    [0] = {r = 0.62, g = 0.62, b = 0.62}, -- Poor (grey)
    [1] = {r = 1.00, g = 1.00, b = 1.00}, -- Common (white)
    [2] = {r = 0.12, g = 1.00, b = 0.00}, -- Uncommon (green)
    [3] = {r = 0.00, g = 0.44, b = 0.87}, -- Rare (blue)
    [4] = {r = 0.64, g = 0.21, b = 0.93}, -- Epic (purple)
    [5] = {r = 1.00, g = 0.50, b = 0.00}, -- Legendary (orange)
}

MLT.QUALITY_HEX = {
    [0] = "|cff9d9d9d",
    [1] = "|cffffffff",
    [2] = "|cff1eff00",
    [3] = "|cff0070dd",
    [4] = "|cffa335ee",
    [5] = "|cffff8000",
}

-- Addon accent color
MLT.ADDON_COLOR = "|cff00ccff"
MLT.ADDON_COLOR_RGB = {r = 0, g = 0.8, b = 1}

-- Sound Kit IDs (more reliable than file paths in Classic)
MLT.SOUNDS = {
    GROUP_DROP = 8959,    -- RaidWarning
    PERSONAL_LOOT = 888,  -- LevelUp
    DUNGEON_ENTER = 3175, -- MapPing
}

----------------------------------------------
-- Core Frame and Event System
----------------------------------------------
MLT.frame = CreateFrame("Frame", "MyLootTrakingFrame", UIParent)
MLT.frame:RegisterEvent("ADDON_LOADED")
MLT.frame:RegisterEvent("PLAYER_LOGIN")
MLT.frame:RegisterEvent("PLAYER_LOGOUT")

local function OnEvent(self, event, ...)
    if MLT[event] then
        MLT[event](MLT, ...)
    end
end
MLT.frame:SetScript("OnEvent", OnEvent)

----------------------------------------------
-- Initialization
----------------------------------------------
function MLT:ADDON_LOADED(addonName)
    if addonName ~= ADDON_NAME then return end

    -- Initialize database
    self:InitDB()

    -- Store current character info
    self.playerName = UnitName("player")
    self.playerRealm = GetRealmName()
    self.playerClass = select(2, UnitClass("player"))
    self.playerFullName = self.playerName .. " - " .. self.playerRealm

    -- Record character in account-wide list
    self.db.characters[self.playerFullName] = {
        name = self.playerName,
        realm = self.playerRealm,
        class = self.playerClass,
    }

    self.frame:UnregisterEvent("ADDON_LOADED")
end

function MLT:PLAYER_LOGIN()
    -- Initialize all modules
    self:InitLootDetection()
    self:InitAlerts()
    self:InitTooltipHooks()
    self:InitMinimapButton()
    self:InitMiniTracker()
    self:InitSlashCommands()
    self:InitAtlasLootIntegration()

    -- Register additional events
    self.frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    self.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.frame:RegisterEvent("BAG_UPDATE")
    self.frame:RegisterEvent("BANKFRAME_OPENED")
    self.frame:RegisterEvent("BANKFRAME_CLOSED")
    self.frame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
    self.frame:RegisterEvent("PLAYERBANKBAGSLOTS_CHANGED")

    -- Initialize lastBagCount for existing farm items (migration from old data)
    C_Timer.After(1, function()
        self:InitFarmItemBaselines()
    end)

    -- Build item source database (EJ + AtlasLoot data) after a short delay
    C_Timer.After(5, function()
        self:BuildItemSourceDB()
    end)

    -- Print loaded message
    local L = self.L
    self:Print(format(L["ADDON_LOADED"], self.version))
end

function MLT:PLAYER_LOGOUT()
    -- Save any pending data
end

function MLT:ZONE_CHANGED_NEW_AREA()
    -- Check if we entered a dungeon/raid with tracked items
    C_Timer.After(1, function()
        self:CheckDungeonEntry()
    end)
end

function MLT:PLAYER_ENTERING_WORLD()
    C_Timer.After(2, function()
        self:CheckDungeonEntry()
    end)
end

----------------------------------------------
-- BAG_UPDATE: Sync farm items from bags (debounced)
----------------------------------------------
function MLT:BAG_UPDATE()
    -- Debounce: only sync once per second
    if self.bagUpdateTimer then return end
    self.bagUpdateTimer = C_Timer.After(1, function()
        self.bagUpdateTimer = nil
        if self.SyncFarmItemsFromBags then
            self:SyncFarmItemsFromBags()
        end
    end)
end

----------------------------------------------
-- Bank events: cache bank contents for farm tracking
----------------------------------------------
function MLT:BANKFRAME_OPENED()
    self.bankOpen = true
    if self.UpdateBankCache then
        self:UpdateBankCache()
    end
    -- Resync baselines without false increments
    if self.OnBankCacheUpdated then
        self:OnBankCacheUpdated()
    end
end

function MLT:BANKFRAME_CLOSED()
    self.bankOpen = false
end

function MLT:PLAYERBANKSLOTS_CHANGED()
    if not self.bankOpen then return end
    -- Debounce bank updates
    if self.bankUpdateTimer then return end
    self.bankUpdateTimer = C_Timer.After(0.5, function()
        self.bankUpdateTimer = nil
        if self.UpdateBankCache then
            self:UpdateBankCache()
        end
        if self.OnBankCacheUpdated then
            self:OnBankCacheUpdated()
        end
    end)
end

MLT.PLAYERBANKBAGSLOTS_CHANGED = MLT.PLAYERBANKSLOTS_CHANGED

----------------------------------------------
-- Utility: Print
----------------------------------------------
function MLT:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(self.ADDON_COLOR .. "[MLT]|r " .. tostring(msg))
end

----------------------------------------------
-- Utility: Get all tracked item IDs (for fast lookups)
----------------------------------------------
function MLT:GetAllTrackedItemIDs()
    local tracked = {}
    if not self.db or not self.db.lists then return tracked end

    for listID, list in pairs(self.db.lists) do
        for _, item in ipairs(list.items) do
            if not item.obtained then
                tracked[item.itemID] = tracked[item.itemID] or {}
                table.insert(tracked[item.itemID], {
                    listID = listID,
                    listName = list.name,
                    listType = list.listType,
                    assignedTo = item.assignedTo,
                    note = item.note,
                    targetQty = item.targetQty,
                    currentQty = item.currentQty,
                })
            end
        end
    end
    return tracked
end

----------------------------------------------
-- Utility: Get items for current zone
----------------------------------------------
function MLT:GetItemsForZone(zoneName)
    local items = {}
    if not self.db or not self.db.lists then return items end

    for _, list in pairs(self.db.lists) do
        for _, item in ipairs(list.items) do
            if not item.obtained then
                local source = item.source or {}
                if source.instance and source.instance == zoneName then
                    table.insert(items, {
                        itemID = item.itemID,
                        itemName = item.itemName,
                        source = source,
                        listName = list.name,
                    })
                end
            end
        end
    end
    return items
end

----------------------------------------------
-- Check dungeon entry for alerts
----------------------------------------------
function MLT:CheckDungeonEntry()
    if not self.db.config.dungeonEnterAlert then return end

    local _, instanceType = IsInInstance()
    if instanceType ~= "party" and instanceType ~= "raid" then return end

    local zoneName = GetRealZoneText()
    if not zoneName or zoneName == "" then
        zoneName = GetSubZoneText() or ""
    end
    if zoneName == "" then return end

    -- Avoid repeating alert for same zone
    if self.lastAlertZone == zoneName then return end
    self.lastAlertZone = zoneName

    local items = self:GetItemsForZone(zoneName)
    if #items > 0 then
        self:ShowDungeonEntryAlert(items, zoneName)
    end
end

----------------------------------------------
-- Compatibility check (ElvUI)
----------------------------------------------
function MLT:IsElvUILoaded()
    return _G["ElvUI"] ~= nil
end

function MLT:GetElvUIScale()
    if self:IsElvUILoaded() then
        local E = _G["ElvUI"][1]
        if E and E.mult then
            return E.mult
        end
    end
    return 1
end
