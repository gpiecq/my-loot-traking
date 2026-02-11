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
    -- Capture target mob name (the mob we're looting)
    local targetName = UnitName("target")
    if not targetName or targetName == "" then
        -- Fallback: check if we can get the loot source name
        targetName = UnitName("npc") or nil
    end
    if targetName then
        self.lastLootTarget = {
            name = targetName,
            zone = GetRealZoneText() or GetSubZoneText() or "",
            time = GetTime(),
        }
    end

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
    -- Use prefix before %s so the item link in the middle doesn't break matching
    local selfPrefix = LOOT_ITEM_SELF:gsub("%%s.*", "")
    if msg:find(selfPrefix, 1, true) or msg:find(playerName, 1, true) then
        isPersonalLoot = true
    end

    if isPersonalLoot then
        -- Extract quantity from loot message (e.g. "x5" or "x20")
        local qty = 1
        local qtyStr = msg:match("x(%d+)")
        if qtyStr then
            qty = tonumber(qtyStr) or 1
        end
        self:OnTrackedItemLooted(itemID, itemLink, qty)
    end
end

-- Boss kill tracking
-- Both BOSS_KILL and ENCOUNTER_END may fire; dedup via lastRecordedKill
function MLT:BOSS_KILL(encounterID, encounterName)
    if not encounterName then return end

    local zoneName = GetRealZoneText()
    if not zoneName or zoneName == "" then
        zoneName = GetSubZoneText() or ""
    end

    -- Store context for source detection
    self.lastKillContext = {
        bossName = encounterName,
        zone = zoneName,
        time = GetTime(),
    }

    -- Delayed record: wait 2s for ENCOUNTER_END to handle it first
    C_Timer.After(2, function()
        local key = encounterName .. (zoneName or "")
        if self.lastRecordedKill == key then return end
        self.lastRecordedKill = key
        self:RecordBossKill(encounterName)
        if zoneName ~= "" then
            self:RecordDungeonRun(zoneName)
        end
    end)
end

function MLT:ENCOUNTER_END(encounterID, encounterName, difficultyID, groupSize, success)
    if success ~= 1 or not encounterName then return end

    local zoneName = GetRealZoneText()
    if not zoneName or zoneName == "" then
        zoneName = GetSubZoneText() or ""
    end

    -- Mark as recorded so BOSS_KILL timer won't double-count
    local key = encounterName .. (zoneName or "")
    self.lastRecordedKill = key

    self:RecordBossKill(encounterName)
    if zoneName ~= "" then
        self:RecordDungeonRun(zoneName)
    end

    -- Store context for source detection on looted items
    self.lastKillContext = {
        bossName = encounterName,
        zone = zoneName,
        time = GetTime(),
    }
end

----------------------------------------------
-- Get current loot source from game context
----------------------------------------------
function MLT:GetCurrentLootSource()
    local source = {type = "boss"}

    -- Use last boss kill if recent (< 120 seconds)
    if self.lastKillContext and (GetTime() - self.lastKillContext.time) < 120 then
        source.bossName = self.lastKillContext.bossName
        source.instance = self.lastKillContext.zone
        return source
    end

    -- Use last loot target (mob name) if recent (< 30 seconds)
    if self.lastLootTarget and (GetTime() - self.lastLootTarget.time) < 30 then
        source.type = "mob"
        source.bossName = self.lastLootTarget.name
        source.instance = self.lastLootTarget.zone
        return source
    end

    -- Otherwise use current zone/subzone as context
    local zoneName = GetRealZoneText()
    if not zoneName or zoneName == "" then
        zoneName = GetSubZoneText() or ""
    end

    local _, instanceType = IsInInstance()
    if instanceType == "party" then
        source.type = "dungeon"
        source.instance = zoneName
    elseif instanceType == "raid" then
        source.type = "raid"
        source.instance = zoneName
    elseif zoneName ~= "" then
        source.type = "mob"
        source.instance = zoneName
    end

    -- Add subzone as boss name for outdoor/dungeon mobs
    local subZone = GetSubZoneText()
    if subZone and subZone ~= "" and subZone ~= zoneName then
        source.bossName = subZone
    end

    if source.instance or source.bossName then
        return source
    end
    return nil
end

----------------------------------------------
-- Update item source if missing
----------------------------------------------
function MLT:FillItemSourceIfEmpty(itemID)
    local lootSource = self:GetCurrentLootSource()
    if not lootSource then return end

    for _, list in pairs(self.db.lists) do
        for _, item in ipairs(list.items) do
            if item.itemID == itemID then
                local needsUpdate = not item.source
                    or not next(item.source)
                    or (not item.source.bossName and not item.source.instance)
                if needsUpdate then
                    item.source = lootSource
                end
            end
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

    -- Fill source from game context if missing
    self:FillItemSourceIfEmpty(itemID)

    -- Show group drop alert
    if self.db.config.enablePopup then
        self:ShowGroupDropAlert(itemLink, entries)
    end

    -- Play group drop sound
    if self.db.config.enableSound then
        PlaySound(self.SOUNDS.GROUP_DROP, "Master")
    end
end

-- Called when the player personally loots a tracked item
function MLT:OnTrackedItemLooted(itemID, itemLink, qty)
    qty = qty or 1
    local entries = self.trackedItemCache[itemID]
    if not entries then return end

    -- Fill source from game context if missing
    self:FillItemSourceIfEmpty(itemID)

    -- Show personal loot alert
    if self.db.config.enablePopup then
        self:ShowPersonalLootAlert(itemLink, entries)
    end

    -- Play personal loot sound
    if self.db.config.enableSound then
        PlaySound(self.SOUNDS.PERSONAL_LOOT, "Master")
    end

    -- Auto-mark as obtained / increment farm count
    for _, entry in ipairs(entries) do
        for listID, list in pairs(self.db.lists) do
            if list.name == entry.listName then
                if list.listType == "farm" then
                    self:IncrementFarmItemCount(listID, itemID, qty)
                else
                    self:MarkItemObtained(listID, itemID, true)
                end
            end
        end
    end

    -- Rebuild cache since item state changed
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
    local count = self.db.statistics.bossKills[bossName] or 0
    -- Game events store kills under localized names, items use English names
    -- Try the translated name if direct lookup returns 0
    if count == 0 and self.BossLocale and self.BossLocale[bossName] then
        count = self.db.statistics.bossKills[self.BossLocale[bossName]] or 0
    end
    return count
end

function MLT:GetDungeonRuns(instanceName)
    local count = self.db.statistics.dungeonRuns[instanceName] or 0
    if count == 0 and self.InstanceLocale and self.InstanceLocale[instanceName] then
        count = self.db.statistics.dungeonRuns[self.InstanceLocale[instanceName]] or 0
    end
    return count
end
