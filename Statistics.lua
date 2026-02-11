-- MyLootTraking Statistics
-- Boss kill counts, dungeon runs, and progress tracking

local _, MLT = ...

----------------------------------------------
-- Get formatted statistics for an item
----------------------------------------------
function MLT:GetItemStatistics(item)
    local stats = {}
    local L = self.L

    if item.source then
        -- Boss kills
        if item.source.bossName and item.source.bossName ~= "" then
            local kills = self:GetBossKills(item.source.bossName)
            stats.bossKills = kills
            stats.bossKillsText = format(L["BOSS_KILLS"], kills)
        end

        -- Dungeon/raid runs
        if item.source.instance and item.source.instance ~= "" then
            local runs = self:GetDungeonRuns(item.source.instance)
            stats.dungeonRuns = runs
            stats.dungeonRunsText = format(L["DUNGEON_RUNS"], runs)
        end

        -- Drop rate
        if item.source.dropRate then
            stats.dropRate = item.source.dropRate
            stats.dropRateText = format(L["DROP_RATE"], item.source.dropRate)
        end
    end

    return stats
end

----------------------------------------------
-- Get overall statistics for all lists
----------------------------------------------
function MLT:GetOverallStatistics()
    local totalItems = 0
    local totalObtained = 0
    local totalLists = 0

    for _, list in pairs(self.db.lists) do
        totalLists = totalLists + 1
        for _, item in ipairs(list.items) do
            totalItems = totalItems + 1
            if item.obtained then
                totalObtained = totalObtained + 1
            end
        end
    end

    local percent = totalItems > 0 and math.floor((totalObtained / totalItems) * 100) or 0

    return {
        totalLists = totalLists,
        totalItems = totalItems,
        totalObtained = totalObtained,
        percent = percent,
        progressText = format(self.L["PROGRESS"], totalObtained, totalItems, percent),
    }
end

----------------------------------------------
-- Get statistics for a specific character
-- Includes character lists matching charKey + all objective lists
----------------------------------------------
function MLT:GetCharacterStatistics(charKey)
    local totalItems = 0
    local totalObtained = 0
    local totalLists = 0

    for _, list in pairs(self.db.lists) do
        local include = false
        if list.listType == "character" then
            include = (list.character == charKey)
        else
            include = true
        end

        if include then
            totalLists = totalLists + 1
            for _, item in ipairs(list.items) do
                totalItems = totalItems + 1
                if item.obtained then
                    totalObtained = totalObtained + 1
                end
            end
        end
    end

    local percent = totalItems > 0 and math.floor((totalObtained / totalItems) * 100) or 0

    return {
        totalLists = totalLists,
        totalItems = totalItems,
        totalObtained = totalObtained,
        percent = percent,
        progressText = format(self.L["PROGRESS"], totalObtained, totalItems, percent),
    }
end
