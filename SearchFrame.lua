-- MyLootTraking Search Frame
-- Interface for searching items by name or ID

local _, MLT = ...

local SEARCH_WIDTH = 450
local SEARCH_HEIGHT = 400
local RESULT_ROW_HEIGHT = 32

----------------------------------------------
-- Show Search Frame
----------------------------------------------
function MLT:ShowSearchFrame(initialQuery)
    if not self.searchFrame then
        self:CreateSearchFrame()
    end
    self.searchFrame:Show()
    if initialQuery then
        self.searchFrame.searchBox:SetText(initialQuery)
        self:PerformSearch(initialQuery)
    else
        self.searchFrame.searchBox:SetText("")
        self.searchFrame.searchBox:SetFocus()
    end
end

----------------------------------------------
-- Create Search Frame
----------------------------------------------
function MLT:CreateSearchFrame()
    local L = self.L

    local frame = CreateFrame("Frame", "MLTSearchFrame", UIParent)
    frame:SetSize(SEARCH_WIDTH, SEARCH_HEIGHT)
    frame:SetPoint("CENTER", 0, 50)
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    tinsert(UISpecialFrames, "MLTSearchFrame")
    self:CreateBackdrop(frame, 0.92)

    -- Title
    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetPoint("TOPLEFT")
    titleBar:SetPoint("TOPRIGHT")
    titleBar:SetHeight(28)
    local titleBg = titleBar:CreateTexture(nil, "BACKGROUND")
    titleBg:SetAllPoints()
    titleBg:SetColorTexture(0.08, 0.08, 0.08, 1)

    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", 12, 0)
    title:SetText(self.ADDON_COLOR .. L["SEARCH"] .. "|r")

    local closeBtn = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    closeBtn:SetPoint("RIGHT", -2, 0)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    -- Search box
    local searchBox = self:CreateEditBox(frame, SEARCH_WIDTH - 24, 28)
    searchBox:SetPoint("TOP", 0, -36)

    -- Placeholder text
    searchBox.placeholder = searchBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    searchBox.placeholder:SetPoint("LEFT", 8, 0)
    searchBox.placeholder:SetText(L["SEARCH_PLACEHOLDER"])
    searchBox.placeholder:SetTextColor(0.4, 0.4, 0.4)

    searchBox:SetScript("OnTextChanged", function(self)
        local text = self:GetText()
        self.placeholder:SetShown(text == "")
        if #text >= 2 then
            MLT:PerformSearch(text)
        elseif text == "" then
            MLT:ClearSearchResults()
        end
    end)
    searchBox:SetScript("OnEnterPressed", function(self)
        MLT:PerformSearch(self:GetText())
    end)

    frame.searchBox = searchBox

    -- Results area
    local resultScroll, resultScrollChild = self:CreateScrollFrame(frame, SEARCH_WIDTH - 12, SEARCH_HEIGHT - 80)
    resultScroll:SetPoint("TOP", searchBox, "BOTTOM", 0, -8)

    frame.resultScroll = resultScroll
    frame.resultScrollChild = resultScrollChild
    frame.resultRows = {}

    -- No results text
    frame.noResults = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.noResults:SetPoint("CENTER", resultScroll, "CENTER")
    frame.noResults:SetText(L["NO_RESULTS"])
    frame.noResults:SetTextColor(0.5, 0.5, 0.5)
    frame.noResults:Hide()

    self.searchFrame = frame
end

----------------------------------------------
-- Perform Search
----------------------------------------------
function MLT:PerformSearch(query)
    if not query or query == "" then
        self:ClearSearchResults()
        return
    end

    query = query:lower()
    local results = {}

    -- Search by item ID
    local searchID = tonumber(query)
    if searchID then
        local itemName = GetItemInfo(searchID)
        if itemName then
            table.insert(results, {itemID = searchID})
        else
            -- Request item data
            local item = Item:CreateFromItemID(searchID)
            item:ContinueOnItemLoad(function()
                self:PerformSearch(query)
            end)
        end
    end

    -- Search through tracked items
    if self.db and self.db.lists then
        for _, list in pairs(self.db.lists) do
            for _, item in ipairs(list.items) do
                if item.itemName and item.itemName:lower():find(query, 1, true) then
                    -- Avoid duplicates
                    local found = false
                    for _, r in ipairs(results) do
                        if r.itemID == item.itemID then
                            found = true
                            break
                        end
                    end
                    if not found then
                        table.insert(results, item)
                    end
                end
            end
        end
    end

    self:DisplaySearchResults(results)
end

----------------------------------------------
-- Display Search Results
----------------------------------------------
function MLT:DisplaySearchResults(results)
    local frame = self.searchFrame
    local scrollChild = frame.resultScrollChild

    -- Hide all existing rows
    for _, row in ipairs(frame.resultRows) do
        row:Hide()
    end

    if #results == 0 then
        frame.noResults:Show()
        return
    end
    frame.noResults:Hide()

    local yOffset = 0
    local rowIndex = 0
    for i, item in ipairs(results) do
        local itemID = item.itemID
        local itemName, itemLink, itemQuality, _, _, _, _, _, _, itemTexture = GetItemInfo(itemID)

        if itemName then
            rowIndex = rowIndex + 1
            local row = frame.resultRows[rowIndex]

            if not row then
                -- Create new row only if needed
                row = CreateFrame("Frame", nil, scrollChild)
                row:SetSize(SEARCH_WIDTH - 40, RESULT_ROW_HEIGHT)
                row:EnableMouse(true)

                row.bg = row:CreateTexture(nil, "BACKGROUND")
                row.bg:SetAllPoints()
                row.bg:SetColorTexture(0.08, 0.08, 0.08, 0)

                row.icon = row:CreateTexture(nil, "ARTWORK")
                row.icon:SetSize(24, 24)
                row.icon:SetPoint("LEFT", 4, 0)
                row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

                row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                row.nameText:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)

                row.addBtn = self:CreateCleanButton(row, "+", 24, 24)
                row.addBtn:SetPoint("RIGHT", -4, 0)

                row:SetScript("OnEnter", function(self)
                    self.bg:SetColorTexture(0.12, 0.12, 0.12, 0.5)
                    if self.currentLink then
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:SetHyperlink(self.currentLink)
                        GameTooltip:Show()
                    end
                end)
                row:SetScript("OnLeave", function(self)
                    self.bg:SetColorTexture(0.08, 0.08, 0.08, 0)
                    GameTooltip:Hide()
                end)

                frame.resultRows[rowIndex] = row
            end

            -- Update content
            row.icon:SetTexture(itemTexture)
            row.nameText:SetText(self:FormatItemWithColor(itemName, itemQuality))
            row.currentLink = itemLink or ("item:" .. itemID)
            row.addBtn:SetScript("OnClick", function()
                self:ShowAddToListMenu(itemID)
            end)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 4, -yOffset)
            row:Show()

            yOffset = yOffset + RESULT_ROW_HEIGHT
        end
    end

    -- Hide extra rows
    for i = rowIndex + 1, #frame.resultRows do
        frame.resultRows[i]:Hide()
    end

    scrollChild:SetHeight(math.max(yOffset, 1))
end

----------------------------------------------
-- Clear Search Results
----------------------------------------------
function MLT:ClearSearchResults()
    if not self.searchFrame then return end
    for _, row in ipairs(self.searchFrame.resultRows) do
        row:Hide()
    end
    self.searchFrame.resultRows = {}
    self.searchFrame.noResults:Hide()
end
