-- MyLootTraking Database
-- Handles SavedVariables, list management, and item CRUD operations

local _, MLT = ...

----------------------------------------------
-- Default Database Structure
----------------------------------------------
local DB_DEFAULTS = {
    lists = {},          -- All lists (account-wide)
    characters = {},     -- Known characters on account
    statistics = {       -- Boss kill counts, dungeon runs
        bossKills = {},  -- [bossName] = count
        dungeonRuns = {},-- [instanceName] = count
    },
    config = {
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
        trackerCollapsed = false,
        trackerPoint = nil,    -- saved position {point, relPoint, x, y}
        alertPoint = nil,
        showObtained = false,
        minimapPos = 220,      -- minimap button angle
        trackerCollapsedLists = {},  -- [listID] = true/false
    },
    nextListID = 1,
}

----------------------------------------------
-- Initialize Database
----------------------------------------------
function MLT:InitDB()
    if not MyLootTrakingDB then
        MyLootTrakingDB = self:DeepCopy(DB_DEFAULTS)
    end
    self.db = MyLootTrakingDB

    -- Ensure all default keys exist (for version upgrades)
    for key, value in pairs(DB_DEFAULTS) do
        if self.db[key] == nil then
            self.db[key] = self:DeepCopy(value)
        end
    end
    for key, value in pairs(DB_DEFAULTS.config) do
        if self.db.config[key] == nil then
            self.db.config[key] = value
        end
    end
    if not self.db.statistics.bossKills then
        self.db.statistics.bossKills = {}
    end
    if not self.db.statistics.dungeonRuns then
        self.db.statistics.dungeonRuns = {}
    end
end

----------------------------------------------
-- Deep Copy Utility
----------------------------------------------
function MLT:DeepCopy(orig)
    local copy
    if type(orig) == "table" then
        copy = {}
        for k, v in pairs(orig) do
            copy[k] = self:DeepCopy(v)
        end
    else
        copy = orig
    end
    return copy
end

----------------------------------------------
-- List Management
----------------------------------------------

-- Create a new list
-- @param name: string - list name
-- @param listType: "character"|"objective"
-- @param character: string|nil - character name (for character lists)
function MLT:CreateList(name, listType, character)
    local L = self.L
    if not name or name == "" then return false end

    local listID = "list_" .. self.db.nextListID
    self.db.nextListID = self.db.nextListID + 1

    self.db.lists[listID] = {
        id = listID,
        name = name,
        listType = listType or "objective",
        character = character,
        items = {},
        createdAt = time(),
        sortOrder = self:GetListCount(),
    }

    self:Print(format(L["LIST_CREATED"], name))
    self:RefreshAllUI()
    return listID
end

-- Delete a list
function MLT:DeleteList(listID)
    local L = self.L
    if not self.db.lists[listID] then return false end

    local name = self.db.lists[listID].name
    self.db.lists[listID] = nil
    self:Print(format(L["LIST_DELETED"], name))
    self:RefreshAllUI()
    return true
end

-- Rename a list
function MLT:RenameList(listID, newName)
    local L = self.L
    if not self.db.lists[listID] or not newName or newName == "" then return false end

    self.db.lists[listID].name = newName
    self:Print(format(L["LIST_RENAMED"], newName))
    self:RefreshAllUI()
    return true
end

-- Get all lists
function MLT:GetLists(filterType, filterCharacter)
    local results = {}
    for id, list in pairs(self.db.lists) do
        local match = true
        if filterType and list.listType ~= filterType then
            match = false
        end
        if filterCharacter and list.character ~= filterCharacter then
            match = false
        end
        if match then
            table.insert(results, list)
        end
    end
    table.sort(results, function(a, b)
        return (a.sortOrder or 0) < (b.sortOrder or 0)
    end)
    return results
end

-- Get list count
function MLT:GetListCount()
    local count = 0
    for _ in pairs(self.db.lists) do
        count = count + 1
    end
    return count
end

----------------------------------------------
-- Item Management
----------------------------------------------

-- Add an item to a list
-- @param listID: string
-- @param itemID: number
-- @param source: table|nil - {type, bossName, instance, dropRate}
function MLT:AddItem(listID, itemID, source)
    local L = self.L
    local list = self.db.lists[listID]
    if not list then return false end

    itemID = tonumber(itemID)
    if not itemID then return false end

    -- Check for duplicates
    for _, item in ipairs(list.items) do
        if item.itemID == itemID then
            local itemName = GetItemInfo(itemID) or tostring(itemID)
            self:Print(format(L["ITEM_ALREADY_IN_LIST"], itemName))
            return false
        end
    end

    -- Get item info
    local itemName, itemLink, itemQuality, _, _, _, _, _, _, itemTexture = GetItemInfo(itemID)

    -- If item info not cached yet, query server
    if not itemName then
        -- Item might not be cached; request it
        local item = Item:CreateFromItemID(itemID)
        item:ContinueOnItemLoad(function()
            self:AddItem(listID, itemID, source)
        end)
        return false, "loading"
    end

    -- Auto-detect source if not provided
    if not source then
        source = self:DetectItemSource(itemID)
    end

    local newItem = {
        itemID = itemID,
        itemName = itemName,
        itemLink = itemLink,
        itemQuality = itemQuality or 0,
        itemTexture = itemTexture,
        source = source or {},
        obtained = false,
        obtainedDate = nil,
        assignedTo = nil,
        note = "",
        addedAt = time(),
        sortOrder = #list.items,
    }

    table.insert(list.items, newItem)
    self:Print(format(L["ITEM_ADDED"], itemLink or itemName, list.name))
    self:RefreshAllUI()
    return true
end

-- Remove an item from a list
function MLT:RemoveItem(listID, itemID)
    local L = self.L
    local list = self.db.lists[listID]
    if not list then return false end

    for i, item in ipairs(list.items) do
        if item.itemID == itemID then
            local name = item.itemLink or item.itemName
            table.remove(list.items, i)
            self:Print(format(L["ITEM_REMOVED"], name, list.name))
            self:RefreshAllUI()
            return true
        end
    end
    return false
end

-- Mark item as obtained
function MLT:MarkItemObtained(listID, itemID, obtained)
    local list = self.db.lists[listID]
    if not list then return false end

    for _, item in ipairs(list.items) do
        if item.itemID == itemID then
            item.obtained = obtained
            item.obtainedDate = obtained and time() or nil
            self:RefreshAllUI()
            return true
        end
    end
    return false
end

-- Set item note
function MLT:SetItemNote(listID, itemID, note)
    local list = self.db.lists[listID]
    if not list then return false end

    for _, item in ipairs(list.items) do
        if item.itemID == itemID then
            item.note = note
            return true
        end
    end
    return false
end

-- Assign item to character
function MLT:AssignItemToCharacter(listID, itemID, characterName)
    local list = self.db.lists[listID]
    if not list then return false end

    for _, item in ipairs(list.items) do
        if item.itemID == itemID then
            item.assignedTo = characterName
            self:RefreshAllUI()
            return true
        end
    end
    return false
end

-- Update item source
function MLT:UpdateItemSource(listID, itemID, source)
    local list = self.db.lists[listID]
    if not list then return false end

    for _, item in ipairs(list.items) do
        if item.itemID == itemID then
            item.source = source
            self:RefreshAllUI()
            return true
        end
    end
    return false
end

-- Reorder items (drag and drop)
function MLT:ReorderItem(listID, fromIndex, toIndex)
    local list = self.db.lists[listID]
    if not list then return false end
    if fromIndex < 1 or fromIndex > #list.items then return false end
    if toIndex < 1 or toIndex > #list.items then return false end

    local item = table.remove(list.items, fromIndex)
    table.insert(list.items, toIndex, item)

    -- Update sort orders
    for i, itm in ipairs(list.items) do
        itm.sortOrder = i - 1
    end

    self:RefreshAllUI()
    return true
end

----------------------------------------------
-- Source Detection
----------------------------------------------
----------------------------------------------
-- Detect Item Source (uses cached DB first)
----------------------------------------------
function MLT:DetectItemSource(itemID)
    -- 1. Check pre-built source DB (EJ + AtlasLoot cache)
    if self.itemSourceDB and self.itemSourceDB[itemID] then
        -- Return a copy so callers can't corrupt the cache
        local cached = self.itemSourceDB[itemID]
        return {
            type = cached.type or "boss",
            bossName = cached.bossName,
            instance = cached.instance,
            difficulty = cached.difficulty,  -- "N", "H", or nil
        }
    end

    -- 2. Tooltip scan fallback (detects type only, not boss/instance)
    local source = {type = "unknown", bossName = nil, instance = nil}

    if not self.scanTooltip then
        self.scanTooltip = CreateFrame("GameTooltip", "MLTScanTooltip", nil, "GameTooltipTemplate")
        self.scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    end

    self.scanTooltip:ClearLines()
    self.scanTooltip:SetHyperlink("item:" .. itemID)

    for i = 1, self.scanTooltip:NumLines() do
        local textLeft = _G["MLTScanTooltipTextLeft" .. i]
        if textLeft then
            local text = textLeft:GetText()
            if text then
                if text:find("Drop") or text:find("Butin") then
                    source.type = "boss"
                elseif text:find("Quest") or text:find("Qu%eête") then
                    source.type = "quest"
                elseif text:find("Vendor") or text:find("Marchand") then
                    source.type = "vendor"
                elseif text:find("Crafted") or text:find("Fabriqu%e9") then
                    source.type = "crafted"
                end
            end
        end
    end

    -- 3. If still unknown, use current game context (zone/instance)
    if source.type == "unknown" then
        local contextSource = self:GetCurrentLootSource()
        if contextSource then
            return contextSource
        end
    end

    return source
end

----------------------------------------------
-- Build Item Source Database (called at login)
----------------------------------------------
function MLT:BuildItemSourceDB()
    self.itemSourceDB = self.itemSourceDB or {}

    -- 1. Load static item source data (from ItemSources.lua)
    if self.ItemSourceData then
        for itemID, data in pairs(self.ItemSourceData) do
            if not self.itemSourceDB[itemID] then
                self.itemSourceDB[itemID] = {
                    type = "boss",
                    bossName = data[1],
                    instance = data[2],
                    difficulty = data[3],  -- "N", "H", or nil
                }
            end
        end
    end

    -- 2. Try Encounter Journal API (may not exist in Classic)
    pcall(function() self:ScanEncounterJournal() end)

    -- 3. Scan AtlasLoot data (if installed)
    pcall(function() self:ScanAtlasLootData() end)

    local count = 0
    for _ in pairs(self.itemSourceDB) do count = count + 1 end
    if count > 0 then
        -- Retroactively update existing items that have no source
        self:UpdateExistingItemSources()
    end
end

----------------------------------------------
-- Strip WoW color codes from a string
----------------------------------------------
local function StripColorCodes(text)
    if type(text) ~= "string" then return nil end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:match("^%s*(.-)%s*$")
    if text == "" then return nil end
    return text
end

----------------------------------------------
-- Scan AtlasLoot data (name-field only)
----------------------------------------------
function MLT:ScanAtlasLootData()
    local visited = {}

    -- Collect ALL global tables that start with "AtlasLoot"
    for key, value in pairs(_G) do
        if type(key) == "string" and type(value) == "table" and key:find("AtlasLoot") then
            pcall(function()
                self:ScanTableForItems(value, visited, nil, nil, 0)
            end)
        end
    end
end

-- Recursively scan tables, using ONLY name fields for context (never key names)
function MLT:ScanTableForItems(tbl, visited, instanceName, bossName, depth)
    if depth > 10 or visited[tbl] then return end
    visited[tbl] = true

    -- Only use explicit name/Name fields as context
    local tblName = rawget(tbl, "name") or rawget(tbl, "Name")
                    or rawget(tbl, "mapname") or rawget(tbl, "instanceName")
    if tblName then
        tblName = StripColorCodes(tblName)
        if tblName then
            if not instanceName then
                instanceName = tblName
            elseif instanceName ~= tblName then
                bossName = tblName
            end
        end
    end

    for k, v in pairs(tbl) do
        if type(v) == "table" and not visited[v] then
            -- Check for loot entry: {number, itemID(>1000), ...}
            local v1, v2 = rawget(v, 1), rawget(v, 2)
            if type(v1) == "number" and type(v2) == "number" and v2 > 1000 and v2 < 200000 then
                if instanceName and not self.itemSourceDB[v2] then
                    self.itemSourceDB[v2] = {
                        type = "boss",
                        bossName = bossName or instanceName,
                        instance = instanceName,
                    }
                end
            else
                self:ScanTableForItems(v, visited, instanceName, bossName, depth + 1)
            end
        end
    end
end

----------------------------------------------
-- Scan Encounter Journal for loot sources
----------------------------------------------
function MLT:ScanEncounterJournal()
    if not EJ_GetNumTiers then return end
    if EncounterJournal_LoadUI then pcall(EncounterJournal_LoadUI) end

    local numTiers = EJ_GetNumTiers()
    if not numTiers or numTiers == 0 then return end

    for tier = 1, numTiers do
        EJ_SelectTier(tier)
        for _, isRaid in ipairs({false, true}) do
            local instIdx = 1
            local instID, instName = EJ_GetInstanceByIndex(instIdx, isRaid)
            while instID do
                EJ_SelectInstance(instID)
                local encIdx = 1
                local encName, _, encID = EJ_GetEncounterInfoByIndex(encIdx)
                while encName do
                    EJ_SelectEncounter(encID)
                    local numLoot = EJ_GetNumLoot and EJ_GetNumLoot() or 0
                    for li = 1, numLoot do
                        local values = {EJ_GetLootInfoByIndex(li)}
                        local foundID
                        for _, v in ipairs(values) do
                            if type(v) == "number" and v > 1000 then
                                foundID = v; break
                            elseif type(v) == "string" and v:find("|Hitem:") then
                                foundID = self:ExtractItemID(v); break
                            end
                        end
                        if foundID then
                            self.itemSourceDB[foundID] = {type = "boss", bossName = encName, instance = instName}
                        end
                    end
                    encIdx = encIdx + 1
                    encName, _, encID = EJ_GetEncounterInfoByIndex(encIdx)
                end
                instIdx = instIdx + 1
                instID, instName = EJ_GetInstanceByIndex(instIdx, isRaid)
            end
        end
    end
end


----------------------------------------------
-- Update sources for existing items in lists
----------------------------------------------
-- Names that were incorrectly saved by the old recursive scanner
local BAD_SOURCE_NAMES = {
    ItemDB = true, Storage = true, Data = true, Loader = true, GUI = true,
    Button = true, Options = true, Module = true, Addons = true, Slots = true,
    db = true, defaults = true, profile = true, callbacks = true, items = true,
}

function MLT:UpdateExistingItemSources()
    if not self.itemSourceDB or not next(self.itemSourceDB) then return end

    local updated = 0
    for _, list in pairs(self.db.lists) do
        for _, item in ipairs(list.items) do
            -- Clean up bad names from old recursive scanner
            if item.source then
                if item.source.instance and BAD_SOURCE_NAMES[item.source.instance] then
                    item.source.instance = nil
                end
                if item.source.bossName and BAD_SOURCE_NAMES[item.source.bossName] then
                    item.source.bossName = nil
                end
            end

            local cached = self.itemSourceDB[item.itemID]
            if cached then
                local needsFullUpdate = not item.source
                    or not next(item.source)
                    or (not item.source.bossName and not item.source.instance)
                if needsFullUpdate then
                    item.source = {
                        type = cached.type or "boss",
                        bossName = cached.bossName,
                        instance = cached.instance,
                        difficulty = cached.difficulty,
                    }
                    updated = updated + 1
                elseif item.source and not item.source.difficulty and cached.difficulty then
                    -- Add missing difficulty to existing source
                    item.source.difficulty = cached.difficulty
                    updated = updated + 1
                end
            end
        end
    end

    if updated > 0 then
        self:Print(updated .. " existing item source(s) updated.")
        self:RefreshAllUI()
    end
end

----------------------------------------------
-- Debug: dump AtlasLoot structure info
----------------------------------------------
function MLT:DebugSourceInfo()
    self:Print("=== Source Debug ===")

    -- Item source DB size
    local count = 0
    if self.itemSourceDB then
        for _ in pairs(self.itemSourceDB) do count = count + 1 end
    end
    self:Print("itemSourceDB: " .. count .. " entries")

    -- EJ API
    self:Print("EJ_GetNumTiers: " .. tostring(EJ_GetNumTiers ~= nil))

    -- AtlasLoot globals
    local alGlobals = {}
    for key, value in pairs(_G) do
        if type(key) == "string" and key:find("AtlasLoot") and type(value) == "table" then
            table.insert(alGlobals, key)
        end
    end
    self:Print("AtlasLoot globals: " .. (#alGlobals > 0 and table.concat(alGlobals, ", ") or "none"))

    -- Show 5 sample entries from itemSourceDB
    if self.itemSourceDB then
        local shown = 0
        for itemID, src in pairs(self.itemSourceDB) do
            if shown < 5 then
                local itemName = GetItemInfo(itemID) or tostring(itemID)
                self:Print("  " .. itemName .. ": " .. (src.bossName or "?") .. " - " .. (src.instance or "?"))
                shown = shown + 1
            else
                break
            end
        end
    end

    -- Show all items from user's lists with their sources
    self:Print("--- Your items ---")
    if self.db and self.db.lists then
        for _, list in pairs(self.db.lists) do
            for _, item in ipairs(list.items) do
                local src = self.itemSourceDB and self.itemSourceDB[item.itemID]
                local srcText = src and ((src.bossName or "?") .. " - " .. (src.instance or "?")) or "NOT IN DB"
                local saved = item.source and ((item.source.bossName or "") .. " - " .. (item.source.instance or ""))
                self:Print("  " .. (item.itemName or item.itemID) .. ": db=" .. srcText .. " | saved=" .. (saved or "nil"))
            end
        end
    end
end

----------------------------------------------
-- Set Item Source
----------------------------------------------
function MLT:SetItemSource(listID, itemID, source)
    local list = self.db.lists[listID]
    if not list then return false end

    for _, item in ipairs(list.items) do
        if item.itemID == itemID then
            item.source = source
            self:RefreshAllUI()
            return true
        end
    end
    return false
end

----------------------------------------------
-- Progress Calculation
----------------------------------------------
function MLT:GetListProgress(listID)
    local list = self.db.lists[listID]
    if not list then return 0, 0, 0 end

    if list.listType == "farm" then
        -- Farm list: sum currentQty / sum targetQty
        local totalQty = 0
        local currentQty = 0
        for _, item in ipairs(list.items) do
            totalQty = totalQty + (item.targetQty or 1)
            currentQty = currentQty + math.min(item.currentQty or 0, item.targetQty or 1)
        end
        local percent = totalQty > 0 and math.floor((currentQty / totalQty) * 100) or 0
        return currentQty, totalQty, percent
    end

    local total = #list.items
    local obtained = 0
    for _, item in ipairs(list.items) do
        if item.obtained then
            obtained = obtained + 1
        end
    end

    local percent = total > 0 and math.floor((obtained / total) * 100) or 0
    return obtained, total, percent
end

----------------------------------------------
-- Auto-detect obtained items (scan bags)
----------------------------------------------
function MLT:ScanBagsForItems()
    local found = {}
    local _GetContainerNumSlots = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
    local _GetContainerItemID = C_Container and C_Container.GetContainerItemID or GetContainerItemID
    local _GetContainerItemInfo = C_Container and C_Container.GetContainerItemInfo or GetContainerItemInfo

    for bag = 0, 4 do
        local numSlots = _GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local itemID = _GetContainerItemID(bag, slot)
            if itemID then
                local info = _GetContainerItemInfo(bag, slot)
                local itemCount = 1
                if type(info) == "table" then
                    itemCount = info.stackCount or 1
                elseif type(info) == "number" then
                    -- Old API: returns texture, itemCount, ...
                    local _, count = _GetContainerItemInfo(bag, slot)
                    itemCount = count or 1
                end
                found[itemID] = (found[itemID] or 0) + itemCount
            end
        end
    end
    return found
end

----------------------------------------------
-- Farm Item Management
----------------------------------------------

-- Add item to a farm list with target quantity
function MLT:AddFarmItem(listID, itemID, targetQty)
    local L = self.L
    local list = self.db.lists[listID]
    if not list then return false end

    itemID = tonumber(itemID)
    if not itemID then return false end
    targetQty = tonumber(targetQty) or 1

    -- Check for duplicates
    for _, item in ipairs(list.items) do
        if item.itemID == itemID then
            local itemName = GetItemInfo(itemID) or tostring(itemID)
            self:Print(format(L["ITEM_ALREADY_IN_LIST"], itemName))
            return false
        end
    end

    local itemName, itemLink, itemQuality, _, _, _, _, _, _, itemTexture = GetItemInfo(itemID)
    if not itemName then
        local item = Item:CreateFromItemID(itemID)
        item:ContinueOnItemLoad(function()
            self:AddFarmItem(listID, itemID, targetQty)
        end)
        return false, "loading"
    end

    -- Check bags for current count
    local bagItems = self:ScanBagsForItems()
    local currentQty = bagItems[itemID] or 0

    local newItem = {
        itemID = itemID,
        itemName = itemName,
        itemLink = itemLink,
        itemQuality = itemQuality or 0,
        itemTexture = itemTexture,
        source = {},
        obtained = false,
        targetQty = targetQty,
        currentQty = currentQty,
        note = "",
        addedAt = time(),
        sortOrder = #list.items,
    }

    table.insert(list.items, newItem)
    self:Print(format(L["ITEM_ADDED"], itemLink or itemName, list.name))
    self:RefreshAllUI()
    return true
end

-- Increment farm item count
function MLT:IncrementFarmItemCount(listID, itemID, amount)
    local list = self.db.lists[listID]
    if not list then return false end

    for _, item in ipairs(list.items) do
        if item.itemID == itemID then
            item.currentQty = (item.currentQty or 0) + (amount or 1)
            if item.targetQty and item.currentQty >= item.targetQty then
                item.obtained = true
                item.obtainedDate = time()
            end
            self:RefreshAllUI()
            return true
        end
    end
    return false
end

-- Set farm item count directly
function MLT:SetFarmItemCount(listID, itemID, count)
    local list = self.db.lists[listID]
    if not list then return false end

    for _, item in ipairs(list.items) do
        if item.itemID == itemID then
            item.currentQty = count or 0
            if item.targetQty and item.currentQty >= item.targetQty then
                item.obtained = true
                item.obtainedDate = time()
            else
                item.obtained = false
                item.obtainedDate = nil
            end
            self:RefreshAllUI()
            return true
        end
    end
    return false
end

-- Set farm item target quantity
function MLT:SetFarmItemTargetQty(listID, itemID, targetQty)
    local list = self.db.lists[listID]
    if not list then return false end

    for _, item in ipairs(list.items) do
        if item.itemID == itemID then
            item.targetQty = targetQty or 1
            if item.currentQty and item.currentQty >= item.targetQty then
                item.obtained = true
                item.obtainedDate = time()
            else
                item.obtained = false
                item.obtainedDate = nil
            end
            self:RefreshAllUI()
            return true
        end
    end
    return false
end

-- Sync all farm items' currentQty from bags
function MLT:SyncFarmItemsFromBags()
    local bagItems = self:ScanBagsForItems()
    local changed = false

    for _, list in pairs(self.db.lists) do
        if list.listType == "farm" then
            for _, item in ipairs(list.items) do
                local bagCount = bagItems[item.itemID] or 0
                if (item.currentQty or 0) ~= bagCount then
                    item.currentQty = bagCount
                    if item.targetQty and bagCount >= item.targetQty then
                        item.obtained = true
                        item.obtainedDate = item.obtainedDate or time()
                    else
                        item.obtained = false
                        item.obtainedDate = nil
                    end
                    changed = true
                end
            end
        end
    end

    if changed then
        self:RefreshAllUI()
    end
end

----------------------------------------------
-- Refresh all UI elements
----------------------------------------------
function MLT:RefreshAllUI()
    if self.RebuildTrackedItemCache then
        self:RebuildTrackedItemCache()
    end
    if self.RefreshMiniTracker then
        self:RefreshMiniTracker()
    end
    if self.RefreshMainFrame then
        self:RefreshMainFrame()
    end
end
