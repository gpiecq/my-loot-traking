-- MyLootTraking Tooltip Hook
-- Adds tracked item info to tooltips and "Add to MLT" button

local _, MLT = ...

----------------------------------------------
-- Initialize Tooltip Hooks
----------------------------------------------
function MLT:InitTooltipHooks()
    -- Hook the main game tooltip
    GameTooltip:HookScript("OnTooltipSetItem", function(tooltip)
        MLT:OnTooltipSetItem(tooltip)
    end)

    -- Hook ItemRefTooltip (shift-clicked items in chat)
    ItemRefTooltip:HookScript("OnTooltipSetItem", function(tooltip)
        MLT:OnTooltipSetItem(tooltip)
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

    -- Check if item is in any tracked list
    local tracked = self.trackedItemCache[itemID]
    if tracked then
        tooltip:AddLine(" ")
        tooltip:AddLine(self.ADDON_COLOR .. "[MyLootTraking]|r", 1, 1, 1)

        for _, entry in ipairs(tracked) do
            local listText = "  • " .. entry.listName
            if entry.assignedTo then
                listText = listText .. " (" .. entry.assignedTo .. ")"
            end
            tooltip:AddLine(listText, 0, 0.8, 1)
        end

        tooltip:Show()
    end

    -- Add the "Add to MLT" button info at the bottom
    if not tracked or #tracked == 0 then
        -- Only show hint if not already tracked
        tooltip:AddLine(" ")
        tooltip:AddDoubleLine(
            self.ADDON_COLOR .. "Shift+Right-Click|r",
            self.ADDON_COLOR .. self.L["ADD_ITEM"] .. "|r"
        )
        tooltip:Show()
    end
end

----------------------------------------------
-- Shift+Right-Click to add item
----------------------------------------------
-- Hook WorldFrame for click detection on items
local origSetItemRef = SetItemRef
function SetItemRef(link, text, button, chatFrame)
    if button == "RightButton" and IsShiftKeyDown() then
        local itemID = MLT:ExtractItemID(link)
        if itemID then
            MLT:ShowAddToListMenu(itemID)
            return
        end
    end
    origSetItemRef(link, text, button, chatFrame)
end

----------------------------------------------
-- Show "Add to List" Menu
----------------------------------------------
function MLT:ShowAddToListMenu(itemID)
    local L = self.L

    -- Create dropdown menu if not exists
    if not self.addToListMenu then
        self.addToListMenu = CreateFrame("Frame", "MLTAddToListMenu", UIParent, "UIDropDownMenuTemplate")
    end

    local function InitMenu(self, level, menuList)
        local lists = MLT:GetLists()

        if #lists == 0 then
            -- No lists, offer to create one
            local info = UIDropDownMenu_CreateInfo()
            info.text = L["NEW_LIST"]
            info.notCheckable = true
            info.func = function()
                MLT:ShowInputDialog(L["ENTER_LIST_NAME"], function(name)
                    local listID = MLT:CreateList(name, "objective")
                    if listID then
                        MLT:AddItem(listID, itemID)
                    end
                end)
            end
            UIDropDownMenu_AddButton(info, level)
        else
            -- List existing lists
            for _, list in ipairs(lists) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = list.name
                info.notCheckable = true
                info.func = function()
                    MLT:AddItem(list.id, itemID)
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
                    local listID = MLT:CreateList(name, "objective")
                    if listID then
                        MLT:AddItem(listID, itemID)
                    end
                end)
            end
            UIDropDownMenu_AddButton(newInfo, level)
        end
    end

    UIDropDownMenu_Initialize(self.addToListMenu, InitMenu, "MENU")
    ToggleDropDownMenu(1, nil, self.addToListMenu, "cursor", 0, 0)
end
