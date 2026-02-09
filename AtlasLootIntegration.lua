-- MyLootTraking AtlasLoot Integration
-- Adds "Add to MyLootTraking" button in AtlasLoot item frames

local _, MLT = ...

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
function MLT:HookAtlasLootFrames()
    local L = self.L

    -- AtlasLoot uses various frame naming conventions depending on version
    -- Try to hook the item buttons

    -- Method 1: Hook AtlasLoot item buttons directly
    local function TryHookButton(buttonName)
        local button = _G[buttonName]
        if button and not button.mltHooked then
            -- Add a small "+" button overlay
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
                -- Try to get the item ID from the AtlasLoot button
                local itemID = nil

                -- AtlasLoot stores item data differently across versions
                if button.itemID then
                    itemID = button.itemID
                elseif button.itemstring then
                    itemID = MLT:ExtractItemID(button.itemstring)
                elseif button.item then
                    itemID = tonumber(button.item) or MLT:ExtractItemID(tostring(button.item))
                end

                -- Try tooltip scanning as fallback
                if not itemID then
                    local _, link = GameTooltip:GetItem()
                    if link then
                        itemID = MLT:ExtractItemID(link)
                    end
                end

                if itemID then
                    MLT:ShowAddToListMenu(itemID)
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

    -- Try common AtlasLoot button name patterns
    local hooked = 0
    for i = 1, 30 do
        -- AtlasLoot Classic patterns
        if TryHookButton("AtlasLootItem_" .. i) then hooked = hooked + 1 end
        if TryHookButton("AtlasLoot_Item_" .. i) then hooked = hooked + 1 end
        if TryHookButton("ALItem_" .. i) then hooked = hooked + 1 end
    end

    -- Method 2: Hook via AtlasLoot's API if available
    if AtlasLoot and AtlasLoot.ItemFrame then
        -- Try to hook the item frame update function
        local origUpdate = AtlasLoot.ItemFrame.Update
        if origUpdate then
            AtlasLoot.ItemFrame.Update = function(...)
                origUpdate(...)
                -- Re-hook buttons after update
                C_Timer.After(0.1, function()
                    MLT:HookAtlasLootFrames()
                end)
            end
        end
    end

    if hooked > 0 then
        MLT:Print("AtlasLoot integration active (" .. hooked .. " buttons hooked)")
    end
end
