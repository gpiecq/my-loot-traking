-- MyLootTraking Loot Detection
-- Monitors loot events to detect tracked items (group drop and personal loot)

local _, MLT = ...

----------------------------------------------
-- Initialize Loot Detection
----------------------------------------------
function MLT:InitLootDetection()
    -- Register loot-related events
    self.frame:RegisterEvent("CHAT_MSG_LOOT")
    self.frame:RegisterEvent("LOOT_OPENED")
    self.frame:RegisterEvent("LOOT_CLOSED")
    self.frame:RegisterEvent("BOSS_KILL")
    self.frame:RegisterEvent("ENCOUNTER_END")

    -- Cache tracked items for fast lookup
    self.trackedItemCache = {}
    self:RebuildTrackedItemCache()
end

----------------------------------------------
-- Rebuild Tracked Item Cache
----------------------------------------------
function MLT:RebuildTrackedItemCache()
    self.trackedItemCache = self:GetAllTrackedItemIDs()
end

----------------------------------------------
-- Event Handlers
----------------------------------------------

-- Fires when loot window opens (group loot visible)
function MLT:LOOT_OPENED()
    -- Scan the loot window for tracked items
    local numLootItems = GetNumLootItems()
    for i = 1, numLootItems do
        local lootIcon, lootName, lootQuantity, currencyID, lootQuality = GetLootSlotInfo(i)
        if lootName then
            local lootLink = GetLootSlotLink(i)
            if lootLink then
                local itemID = self:ExtractItemID(lootLink)
                if itemID and self.trackedItemCache[itemID] then
                    -- Tracked item found in loot window! (Group drop)
                    self:OnTrackedItemDropped(itemID, lootLink, false)
                end
            end
        end
    end
end

function MLT:LOOT_CLOSED()
    -- Nothing specific needed here
end

-- Fires when any player loots an item (chat message)
function MLT:CHAT_MSG_LOOT(msg, ...)
    if not msg then return end

    -- Extract item link from loot message
    local itemLink = msg:match("|c%x+|Hitem:.-|h%[.-%]|h|r")
    if not itemLink then return end

    local itemID = self:ExtractItemID(itemLink)
    if not itemID then return end

    -- Check if this item is tracked
    if not self.trackedItemCache[itemID] then return end

    -- Determine if it was us who looted it
    local playerName = UnitName("player")
    local isPersonalLoot = false

    -- Check for "You receive loot:" pattern (varies by locale)
    -- English: "You receive loot: [Item]"
    -- French: "Vous recevez le butin : [Item]"
    if msg:find(playerName) or msg:find(LOOT_ITEM_SELF:gsub("%%s", "")) then
        isPersonalLoot = true
    end

    if isPersonalLoot then
        self:OnTrackedItemLooted(itemID, itemLink)
    end
end

-- Boss kill tracking
function MLT:BOSS_KILL(encounterID, encounterName)
    if encounterName then
        self:RecordBossKill(encounterName)
    end
end

function MLT:ENCOUNTER_END(encounterID, encounterName, difficultyID, groupSize, success)
    if success == 1 and encounterName then
        self:RecordBossKill(encounterName)

        -- Also record dungeon/raid run
        local zoneName = GetRealZoneText()
        if zoneName then
            self:RecordDungeonRun(zoneName)
        end
    end
end

----------------------------------------------
-- Tracked Item Handlers
----------------------------------------------

-- Called when a tracked item appears in group loot
function MLT:OnTrackedItemDropped(itemID, itemLink, isPersonal)
    if isPersonal then return end -- personal loot handled separately

    local entries = self.trackedItemCache[itemID]
    if not entries then return end

    -- Show group drop alert
    if self.db.config.enablePopup then
        self:ShowGroupDropAlert(itemLink, entries)
    end

    -- Play group drop sound
    if self.db.config.enableSound then
        PlaySoundFile(self.SOUNDS.GROUP_DROP, "Master")
    end
end

-- Called when the player personally loots a tracked item
function MLT:OnTrackedItemLooted(itemID, itemLink)
    local entries = self.trackedItemCache[itemID]
    if not entries then return end

    -- Show personal loot alert
    if self.db.config.enablePopup then
        self:ShowPersonalLootAlert(itemLink, entries)
    end

    -- Play personal loot sound
    if self.db.config.enableSound then
        PlaySoundFile(self.SOUNDS.PERSONAL_LOOT, "Master")
    end

    -- Auto-mark as obtained in all lists
    for _, entry in ipairs(entries) do
        for listID, list in pairs(self.db.lists) do
            if list.name == entry.listName then
                self:MarkItemObtained(listID, itemID, true)
            end
        end
    end

    -- Rebuild cache since item is now obtained
    self:RebuildTrackedItemCache()
end

----------------------------------------------
-- Statistics Recording
----------------------------------------------
function MLT:RecordBossKill(bossName)
    if not bossName then return end
    self.db.statistics.bossKills[bossName] = (self.db.statistics.bossKills[bossName] or 0) + 1
end

function MLT:RecordDungeonRun(instanceName)
    if not instanceName then return end
    self.db.statistics.dungeonRuns[instanceName] = (self.db.statistics.dungeonRuns[instanceName] or 0) + 1
end

function MLT:GetBossKills(bossName)
    return self.db.statistics.bossKills[bossName] or 0
end

function MLT:GetDungeonRuns(instanceName)
    return self.db.statistics.dungeonRuns[instanceName] or 0
end
