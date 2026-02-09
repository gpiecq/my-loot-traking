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
        trackerPoint = nil,    -- saved position {point, relPoint, x, y}
        alertPoint = nil,
        showObtained = false,
        minimapPos = 220,      -- minimap button angle
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
function MLT:DetectItemSource(itemID)
    -- Try to detect source from tooltip scanning
    local source = {
        type = "unknown",
        bossName = nil,
        instance = nil,
        dropRate = nil,
    }

    -- Create a hidden tooltip for scanning
    if not self.scanTooltip then
        self.scanTooltip = CreateFrame("GameTooltip", "MLTScanTooltip", nil, "GameTooltipTemplate")
        self.scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    end

    self.scanTooltip:ClearLines()
    self.scanTooltip:SetHyperlink("item:" .. itemID)

    local numLines = self.scanTooltip:NumLines()
    for i = 1, numLines do
        local textLeft = _G["MLTScanTooltipTextLeft" .. i]
        if textLeft then
            local text = textLeft:GetText()
            if text then
                -- Try to detect source type from tooltip text
                if text:find("Drop") or text:find("Butin") then
                    source.type = "boss"
                elseif text:find("Quest") or text:find("Quête") then
                    source.type = "quest"
                elseif text:find("Vendor") or text:find("Marchand") then
                    source.type = "vendor"
                elseif text:find("Crafted") or text:find("Fabriqué") then
                    source.type = "crafted"
                end
            end
        end
    end

    return source
end

----------------------------------------------
-- Progress Calculation
----------------------------------------------
function MLT:GetListProgress(listID)
    local list = self.db.lists[listID]
    if not list then return 0, 0, 0 end

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
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local itemID = GetContainerItemID(bag, slot)
            if itemID then
                found[itemID] = true
            end
        end
    end
    return found
end

----------------------------------------------
-- Refresh all UI elements
----------------------------------------------
function MLT:RefreshAllUI()
    if self.RefreshMiniTracker then
        self:RefreshMiniTracker()
    end
    if self.RefreshMainFrame then
        self:RefreshMainFrame()
    end
end
