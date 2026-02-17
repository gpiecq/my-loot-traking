-- MyLootTraking Tooltip Hook
-- Adds tracked item info to tooltips and "Add to MLT" button

local _, MLT = ...

----------------------------------------------
-- Initialize Tooltip Hooks
----------------------------------------------
function MLT:InitTooltipHooks()
    self.currentTooltipItemID = nil

    -- Hook the main game tooltip
    GameTooltip:HookScript("OnTooltipSetItem", function(tooltip)
        local ok, err = pcall(MLT.OnTooltipSetItem, MLT, tooltip)
        if not ok then MLT:Print("|cffff0000Tooltip error:|r " .. tostring(err)) end
    end)

    -- Hook ItemRefTooltip (shift-clicked items in chat)
    ItemRefTooltip:HookScript("OnTooltipSetItem", function(tooltip)
        local ok, err = pcall(MLT.OnTooltipSetItem, MLT, tooltip)
        if not ok then MLT:Print("|cffff0000Tooltip error:|r " .. tostring(err)) end
    end)

    -- Clear tracked item when tooltips hide
    GameTooltip:HookScript("OnHide", function()
        MLT.currentTooltipItemID = nil
    end)
    ItemRefTooltip:HookScript("OnHide", function()
        MLT.currentTooltipItemID = nil
    end)
end

----------------------------------------------
-- Tooltip Handler
----------------------------------------------
function MLT:OnTooltipSetItem(tooltip)
    local _, itemLink = tooltip:GetItem()
    if not itemLink then return end

    local itemID = self:ExtractItemID(itemLink)
    if not itemID then return end

    -- Store for Ctrl+RightClick detection on any frame
    self.currentTooltipItemID = itemID

    -- Hook the tooltip owner for Ctrl+RightClick (once per frame)
    -- Skip for ItemRefTooltip: Ctrl+RightClick is already handled in SetItemRef override,
    -- and hooking OnMouseDown on its owner (UIParent/chat frame) can block WoW input
    if tooltip ~= ItemRefTooltip then
        local owner = tooltip:GetOwner()
        if owner and owner ~= UIParent and not owner.mltCtrlClickHooked then
            owner.mltCtrlClickHooked = true
            owner:HookScript("OnMouseDown", function(_, button)
                if button == "RightButton" and IsControlKeyDown() and MLT.currentTooltipItemID then
                    local id = MLT.currentTooltipItemID
                    MLT.currentTooltipItemID = nil
                    local source = MLT.GetAtlasLootContext and MLT:GetAtlasLootContext() or nil
                    C_Timer.After(0, function()
                        MLT:ShowAddToListMenu(id, source)
                    end)
                end
            end)
        end
    end

    -- Check if item is in any tracked list
    local tracked = self.trackedItemCache[itemID]
    if tracked then
        tooltip:AddLine(" ")
        tooltip:AddLine(self.ADDON_COLOR .. "[MyLootTraking]|r", 1, 1, 1)

        for _, entry in ipairs(tracked) do
            local listText = "  • " .. entry.listName
            if entry.listType == "farm" and entry.targetQty then
                local cur = entry.currentQty or 0
                local tgt = entry.targetQty or 1
                local farmColor = cur >= tgt and "|cff00ff00" or "|cffffff00"
                listText = listText .. " " .. farmColor .. format(self.L["FARM_PROGRESS"], cur, tgt) .. "|r"
            elseif entry.assignedTo then
                listText = listText .. " (" .. entry.assignedTo .. ")"
            end
            tooltip:AddLine(listText, 0, 0.8, 1)
        end

        tooltip:Show()
    end

    -- Add the "Add to MLT" hint at the bottom
    tooltip:AddLine(" ")
    tooltip:AddDoubleLine(
        self.ADDON_COLOR .. "Ctrl+Right-Click|r",
        self.ADDON_COLOR .. self.L["ADD_ITEM"] .. "|r"
    )
    tooltip:Show()
end

----------------------------------------------
-- Ctrl+Right-Click to add item (chat links)
-- Use hooksecurefunc to avoid overriding the global and breaking WoW internal state
----------------------------------------------
hooksecurefunc("SetItemRef", function(link, text, button, chatFrame)
    if button == "RightButton" and IsControlKeyDown() then
        local itemID = MLT:ExtractItemID(link)
        if itemID then
            -- Hide the tooltip that just opened, show our menu instead
            ItemRefTooltip:Hide()
            MLT:ShowAddToListMenu(itemID)
        end
    end
end)

----------------------------------------------
-- Show "Add to List" Menu
----------------------------------------------
function MLT:ShowAddToListMenu(itemID, source)
    local L = self.L

    -- Create dropdown menu if not exists
    if not self.addToListMenu then
        self.addToListMenu = CreateFrame("Frame", "MLTAddToListMenu", UIParent, "UIDropDownMenuTemplate")
    end

    local function InitMenu(self, level, menuList)
        -- Only show lists for current character + objective lists
        local allLists = MLT:GetLists()
        local lists = {}
        local currentChar = MLT.playerFullName
        for _, list in ipairs(allLists) do
            if list.listType ~= "character" or list.character == currentChar then
                table.insert(lists, list)
            end
        end

        if #lists == 0 then
            -- No lists, offer to create one for current character
            local info = UIDropDownMenu_CreateInfo()
            info.text = L["NEW_LIST"]
            info.notCheckable = true
            info.func = function()
                MLT:ShowInputDialog(L["ENTER_LIST_NAME"], function(name)
                    local listID = MLT:CreateList(name, "character", MLT.playerFullName)
                    if listID then
                        MLT:AddItem(listID, itemID, source)
                    end
                end, MLT.playerName .. " - BiS")
            end
            UIDropDownMenu_AddButton(info, level)
        else
            -- List existing lists
            for _, list in ipairs(lists) do
                local info = UIDropDownMenu_CreateInfo()
                if list.listType == "farm" then
                    info.text = "|cff44cc44" .. list.name .. "|r"
                else
                    info.text = list.name
                end
                info.notCheckable = true
                info.func = function()
                    if list.listType == "farm" then
                        MLT:ShowInputDialog(L["ENTER_TARGET_QTY"], function(qtyInput)
                            local qty = tonumber(qtyInput) or 1
                            if qty < 1 then qty = 1 end
                            MLT:AddFarmItem(list.id, itemID, qty)
                        end, "20")
                    else
                        MLT:AddItem(list.id, itemID, source)
                    end
                end
                UIDropDownMenu_AddButton(info, level)
            end

            -- Separator
            local sep = UIDropDownMenu_CreateInfo()
            sep.disabled = true
            sep.notCheckable = true
            UIDropDownMenu_AddButton(sep, level)

            -- New list option
            local newInfo = UIDropDownMenu_CreateInfo()
            newInfo.text = "|cff00ff00+ " .. L["NEW_LIST"] .. "|r"
            newInfo.notCheckable = true
            newInfo.func = function()
                MLT:ShowInputDialog(L["ENTER_LIST_NAME"], function(name)
                    local listID = MLT:CreateList(name, "character", MLT.playerFullName)
                    if listID then
                        MLT:AddItem(listID, itemID, source)
                    end
                end, MLT.playerName .. " - BiS")
            end
            UIDropDownMenu_AddButton(newInfo, level)
        end
    end

    UIDropDownMenu_Initialize(self.addToListMenu, InitMenu, "MENU")
    ToggleDropDownMenu(1, nil, self.addToListMenu, "cursor", 0, 0)
end
