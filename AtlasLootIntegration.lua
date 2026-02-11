-- MyLootTraking AtlasLoot Integration
-- Adds "Add to MyLootTraking" button in AtlasLoot item frames

local _, MLT = ...

--Compat: IsAddOnLoaded was moved to C_AddOns in newer clients
local IsAddOnLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded

----------------------------------------------
-- Initialize AtlasLoot Integration
----------------------------------------------
function MLT:InitAtlasLootIntegration()
    -- Check if AtlasLoot is loaded
    if not IsAddOnLoaded("AtlasLoot") and not IsAddOnLoaded("AtlasLootClassic") then
        -- Try to hook when it loads later
        local hookFrame = CreateFrame("Frame")
        hookFrame:RegisterEvent("ADDON_LOADED")
        hookFrame:SetScript("OnEvent", function(self, event, addonName)
            if addonName == "AtlasLoot" or addonName == "AtlasLootClassic" then
                MLT:HookAtlasLoot()
                self:UnregisterEvent("ADDON_LOADED")
            end
        end)
        return
    end

    self:HookAtlasLoot()
end

----------------------------------------------
-- Hook AtlasLoot
----------------------------------------------
function MLT:HookAtlasLoot()
    -- Wait a moment for AtlasLoot to fully initialize
    C_Timer.After(2, function()
        self:HookAtlasLootFrames()
    end)
end

----------------------------------------------
-- Hook AtlasLoot Item Frames
----------------------------------------------
----------------------------------------------
-- Try to extract boss/instance context from AtlasLoot
----------------------------------------------
function MLT:GetAtlasLootContext(itemButton)
    if not AtlasLoot then return nil end

    local source = {type = "boss"}

    -- Try to read data from the specific item button
    if itemButton then
        pcall(function()
            if itemButton.boss and type(itemButton.boss) == "string" then
                source.bossName = itemButton.boss
            end
            if itemButton.instance and type(itemButton.instance) == "string" then
                source.instance = itemButton.instance
            end
        end)
    end

    -- Try AtlasLoot GUI module state
    if not source.bossName and not source.instance then
        pcall(function()
            if AtlasLoot.GUI then
                local gui = AtlasLoot.GUI
                -- Try common state properties
                if gui.boss and type(gui.boss) == "string" then
                    source.bossName = gui.boss
                elseif gui.selectedBoss and type(gui.selectedBoss) == "string" then
                    source.bossName = gui.selectedBoss
                end
                if gui.instance and type(gui.instance) == "string" then
                    source.instance = gui.instance
                elseif gui.selectedInstance and type(gui.selectedInstance) == "string" then
                    source.instance = gui.selectedInstance
                end
            end
        end)
    end

    -- Try to read from AtlasLoot frame title / visible FontStrings
    if not source.bossName and not source.instance then
        pcall(function()
            for _, name in ipairs({"AtlasLoot-Frame", "AtlasLootDefaultFrame"}) do
                local f = _G[name]
                if f and f:IsShown() then
                    -- Direct title properties
                    if f.TitleText and f.TitleText.GetText then
                        local t = f.TitleText:GetText()
                        if t and t ~= "" then source.instance = t end
                    end
                    if f.BossName and f.BossName.GetText then
                        local t = f.BossName:GetText()
                        if t and t ~= "" then source.bossName = t end
                    end
                    -- Scan child frames for title-like FontStrings
                    if not source.instance then
                        for i = 1, f:GetNumChildren() do
                            local child = select(i, f:GetChildren())
                            if child:IsShown() then
                                for j = 1, child:GetNumRegions() do
                                    local r = select(j, child:GetRegions())
                                    if r:GetObjectType() == "FontString" and r:IsShown() then
                                        local t = r:GetText()
                                        if t and t ~= "" and t:len() > 3 then
                                            if not source.instance then
                                                source.instance = t
                                            elseif not source.bossName then
                                                source.bossName = t
                                            end
                                        end
                                    end
                                end
                                -- Only check the first visible child (title area)
                                if source.instance then break end
                            end
                        end
                    end
                    break
                end
            end
        end)
    end

    if source.bossName or source.instance then
        return source
    end
    return nil
end

----------------------------------------------
-- Cache all visible AtlasLoot items with source
----------------------------------------------
function MLT:CacheAtlasLootPage()
    local context = self:GetAtlasLootContext()
    if not context then return end

    self.itemSourceDB = self.itemSourceDB or {}

    for i = 1, 30 do
        for _, prefix in ipairs({"AtlasLootItem_", "AtlasLoot_Item_", "ALItem_"}) do
            local button = _G[prefix .. i]
            if button and button:IsShown() then
                local itemID = button.itemID
                if not itemID and button.itemstring then
                    itemID = self:ExtractItemID(button.itemstring)
                end
                if not itemID and button.item then
                    itemID = tonumber(button.item) or self:ExtractItemID(tostring(button.item))
                end
                if itemID then
                    self.itemSourceDB[itemID] = context
                end
            end
        end
    end
end

----------------------------------------------
-- Hook AtlasLoot Item Frames
----------------------------------------------
function MLT:HookAtlasLootFrames()
    local L = self.L

    local function TryHookButton(buttonName)
        local button = _G[buttonName]
        if button and not button.mltHooked then
            local addBtn = CreateFrame("Button", nil, button)
            addBtn:SetSize(18, 18)
            addBtn:SetPoint("TOPRIGHT", -2, -2)
            addBtn:SetFrameLevel(button:GetFrameLevel() + 5)

            local addBg = addBtn:CreateTexture(nil, "BACKGROUND")
            addBg:SetAllPoints()
            addBg:SetColorTexture(0, 0.6, 0.8, 0.8)

            local addText = addBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            addText:SetPoint("CENTER")
            addText:SetText("+")
            addText:SetTextColor(1, 1, 1)

            addBtn:SetScript("OnClick", function()
                local itemID = nil

                if button.itemID then
                    itemID = button.itemID
                elseif button.itemstring then
                    itemID = MLT:ExtractItemID(button.itemstring)
                elseif button.item then
                    itemID = tonumber(button.item) or MLT:ExtractItemID(tostring(button.item))
                end

                if not itemID then
                    local _, link = GameTooltip:GetItem()
                    if link then
                        itemID = MLT:ExtractItemID(link)
                    end
                end

                if itemID then
                    local source = MLT:GetAtlasLootContext(button)
                    MLT:ShowAddToListMenu(itemID, source)
                end
            end)

            addBtn:SetScript("OnEnter", function(self)
                addBg:SetColorTexture(0, 0.8, 1, 1)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine(L["ADD_ITEM"])
                GameTooltip:Show()
            end)

            addBtn:SetScript("OnLeave", function(self)
                addBg:SetColorTexture(0, 0.6, 0.8, 0.8)
                GameTooltip:Hide()
            end)

            button.mltAddBtn = addBtn
            button.mltHooked = true
            return true
        end
        return false
    end

    local hooked = 0
    for i = 1, 30 do
        if TryHookButton("AtlasLootItem_" .. i) then hooked = hooked + 1 end
        if TryHookButton("AtlasLoot_Item_" .. i) then hooked = hooked + 1 end
        if TryHookButton("ALItem_" .. i) then hooked = hooked + 1 end
    end

    -- Hook via AtlasLoot's API if available (only once to avoid recursion)
    if AtlasLoot and AtlasLoot.ItemFrame and not self.atlasLootUpdateHooked then
        self.atlasLootUpdateHooked = true
        local origUpdate = AtlasLoot.ItemFrame.Update
        if origUpdate then
            AtlasLoot.ItemFrame.Update = function(...)
                origUpdate(...)
                C_Timer.After(0.1, function()
                    MLT:HookAtlasLootFrames()
                    MLT:CacheAtlasLootPage()
                end)
            end
        end
    end

    if hooked > 0 then
        MLT:Print("AtlasLoot integration active (" .. hooked .. " buttons hooked)")
    end
end
