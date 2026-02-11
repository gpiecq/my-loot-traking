-- MyLootTraking Main Frame
-- Full detailed window with list management, filtering, sorting, and item display

local _, MLT = ...

local FRAME_WIDTH = 650
local FRAME_HEIGHT = 550
local ITEM_ROW_HEIGHT = 36
local LIST_PANEL_WIDTH = 180

----------------------------------------------
-- Show / Toggle Main Frame
----------------------------------------------
function MLT:ShowMainFrame()
    if not self.mainFrame then
        self:CreateMainFrame()
    end
    self.mainFrame:Show()
    self:RefreshMainFrame()
    -- Hide MiniTracker to avoid overlap
    if self.miniTracker then
        self.miniTrackerWasShown = self.miniTracker:IsShown()
        self.miniTracker:Hide()
    end
end

function MLT:ToggleMainFrame()
    if self.mainFrame and self.mainFrame:IsShown() then
        self.mainFrame:Hide()
        -- Restore MiniTracker if it was visible before
        if self.miniTracker and self.miniTrackerWasShown then
            self.miniTracker:Show()
        end
    else
        self:ShowMainFrame()
    end
end

----------------------------------------------
-- Create Main Frame
----------------------------------------------
function MLT:CreateMainFrame()
    local L = self.L

    local frame = CreateFrame("Frame", "MLTMainFrame", UIParent)
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:SetToplevel(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    -- Restore MiniTracker when closed (ESC, close button, etc.)
    frame:SetScript("OnHide", function()
        if MLT.miniTracker and MLT.miniTrackerWasShown then
            MLT.miniTracker:Show()
        end
    end)

    -- ESC to close
    tinsert(UISpecialFrames, "MLTMainFrame")

    -- Background
    self:CreateBackdrop(frame, 0.92)

    -- Title bar
    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetSize(FRAME_WIDTH, 30)
    titleBar:SetPoint("TOP")
    local titleBg = titleBar:CreateTexture(nil, "BACKGROUND")
    titleBg:SetAllPoints()
    titleBg:SetColorTexture(0.08, 0.08, 0.08, 1)

    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", 12, 0)
    title:SetText(self.ADDON_COLOR .. "MyLootTraking|r")

    -- Close button
    local closeBtn = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    closeBtn:SetPoint("RIGHT", -2, 0)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    -- Overall progress
    frame.overallProgress = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.overallProgress:SetPoint("RIGHT", closeBtn, "LEFT", -10, 0)
    frame.overallProgress:SetTextColor(0.5, 0.8, 1)

    -- ============================================
    -- LEFT PANEL: List Browser
    -- ============================================
    local listPanel = CreateFrame("Frame", nil, frame)
    listPanel:SetPoint("TOPLEFT", 0, -30)
    listPanel:SetPoint("BOTTOMLEFT", 0, 0)
    listPanel:SetWidth(LIST_PANEL_WIDTH)
    local listBg = listPanel:CreateTexture(nil, "BACKGROUND")
    listBg:SetAllPoints()
    listBg:SetColorTexture(0.04, 0.04, 0.04, 0.95)

    -- "New List" button
    local newListBtn = self:CreateCleanButton(listPanel, "+ " .. L["NEW_LIST"], LIST_PANEL_WIDTH - 10, 22)
    newListBtn:SetPoint("TOP", 0, -8)
    newListBtn:SetScript("OnClick", function()
        self:ShowNewListDialog()
    end)

    -- List scroll area
    local listScroll, listScrollChild = self:CreateScrollFrame(listPanel, LIST_PANEL_WIDTH, FRAME_HEIGHT - 70)
    listScroll:SetPoint("TOPLEFT", 0, -38)

    frame.listPanel = listPanel
    frame.listScroll = listScroll
    frame.listScrollChild = listScrollChild
    frame.listButtons = {}

    -- ============================================
    -- RIGHT PANEL: Item Display
    -- ============================================
    local itemPanel = CreateFrame("Frame", nil, frame)
    itemPanel:SetPoint("TOPLEFT", LIST_PANEL_WIDTH, -30)
    itemPanel:SetPoint("BOTTOMRIGHT", 0, 0)

    -- Toolbar (filter/sort bar)
    local toolbar = CreateFrame("Frame", nil, itemPanel)
    toolbar:SetPoint("TOPLEFT", 0, 0)
    toolbar:SetPoint("TOPRIGHT", 0, 0)
    toolbar:SetHeight(32)
    local toolbarBg = toolbar:CreateTexture(nil, "BACKGROUND")
    toolbarBg:SetAllPoints()
    toolbarBg:SetColorTexture(0.06, 0.06, 0.06, 1)

    -- Filter dropdown
    local filterBtn = self:CreateCleanButton(toolbar, L["FILTER_ALL"], 90, 22)
    filterBtn:SetPoint("LEFT", 8, 0)
    filterBtn:SetScript("OnClick", function()
        self:ShowFilterMenu()
    end)
    frame.filterBtn = filterBtn

    -- Sort dropdown
    local sortBtn = self:CreateCleanButton(toolbar, L["SORT_BY"] .. ": " .. L["SORT_NAME"], 120, 22)
    sortBtn:SetPoint("LEFT", filterBtn, "RIGHT", 6, 0)
    sortBtn:SetScript("OnClick", function()
        self:ShowSortMenu()
    end)
    frame.sortBtn = sortBtn

    -- Add item by ID
    local addItemBtn = self:CreateCleanButton(toolbar, "+ " .. L["ADD_ITEM_BY_ID"], 80, 22)
    addItemBtn:SetPoint("LEFT", sortBtn, "RIGHT", 6, 0)
    addItemBtn:SetScript("OnClick", function()
        local listID = frame.selectedListID
        if not listID then
            self:Print(L["NO_LIST_SELECTED"])
            return
        end
        local list = self.db.lists[listID]
        local isFarm = list and list.listType == "farm"

        self:ShowInputDialog(L["ENTER_ITEM_ID"], function(input)
            if not input or input == "" then return end
            local itemID = tonumber(input) or self:ExtractItemID(input)
            if itemID then
                if isFarm then
                    -- Ask for target quantity
                    self:ShowInputDialog(L["ENTER_TARGET_QTY"], function(qtyInput)
                        local qty = tonumber(qtyInput) or 1
                        if qty < 1 then qty = 1 end
                        self:AddFarmItem(listID, itemID, qty)
                    end, "20")
                else
                    self:AddItem(listID, itemID)
                end
            else
                self:Print(format(L["ITEM_NOT_FOUND"], input))
            end
        end)
    end)
    frame.addItemBtn = addItemBtn

    -- Toggle obtained category
    local obtainedBtn = self:CreateCleanButton(toolbar, L["SHOW_OBTAINED"], 120, 22)
    obtainedBtn:SetPoint("RIGHT", -8, 0)
    obtainedBtn:SetScript("OnClick", function()
        self.db.config.showObtained = not self.db.config.showObtained
        obtainedBtn.text:SetText(self.db.config.showObtained and L["HIDE_OBTAINED"] or L["SHOW_OBTAINED"])
        self:RefreshMainFrame()
    end)
    frame.obtainedBtn = obtainedBtn

    -- Item scroll area
    local itemScroll, itemScrollChild = self:CreateScrollFrame(itemPanel, FRAME_WIDTH - LIST_PANEL_WIDTH, FRAME_HEIGHT - 64)
    itemScroll:SetPoint("TOPLEFT", 0, -32)
    itemScroll:SetPoint("BOTTOMRIGHT", 0, 0)

    frame.itemPanel = itemPanel
    frame.itemScroll = itemScroll
    frame.itemScrollChild = itemScrollChild
    frame.itemRows = {}

    -- State
    frame.selectedListID = nil
    frame.currentFilter = nil
    frame.currentSort = "sortOrder"
    frame.dragIndex = nil

    self.mainFrame = frame
end

----------------------------------------------
-- Show New List Dialog (dropdown: Character BiS / Farm)
----------------------------------------------
function MLT:ShowNewListDialog()
    local L = self.L

    if not self.newListTypeMenu then
        self.newListTypeMenu = CreateFrame("Frame", "MLTNewListTypeMenu", UIParent, "UIDropDownMenuTemplate")
    end

    local function InitMenu(self, level)
        -- Character BiS list
        local info = UIDropDownMenu_CreateInfo()
        info.text = L["LIST_TYPE_CHARACTER_SHORT"]
        info.notCheckable = true
        info.func = function()
            local defaultName = MLT.playerName .. " - BiS"
            MLT:ShowInputDialog(L["ENTER_LIST_NAME"], function(name)
                if name and name ~= "" then
                    MLT:CreateList(name, "character", MLT.playerFullName)
                    MLT:RefreshMainFrame()
                end
            end, defaultName)
        end
        UIDropDownMenu_AddButton(info, level)

        -- Farm list
        info = UIDropDownMenu_CreateInfo()
        info.text = "|cff44cc44" .. L["LIST_TYPE_FARM_SHORT"] .. "|r"
        info.notCheckable = true
        info.func = function()
            local defaultName = "Farm"
            MLT:ShowInputDialog(L["ENTER_LIST_NAME"], function(name)
                if name and name ~= "" then
                    MLT:CreateList(name, "farm")
                    MLT:RefreshMainFrame()
                end
            end, defaultName)
        end
        UIDropDownMenu_AddButton(info, level)
    end

    UIDropDownMenu_Initialize(self.newListTypeMenu, InitMenu, "MENU")
    ToggleDropDownMenu(1, nil, self.newListTypeMenu, "cursor", 0, 0)
end

----------------------------------------------
-- Refresh Main Frame
----------------------------------------------
function MLT:RefreshMainFrame()
    if not self.mainFrame or not self.mainFrame:IsShown() then return end
    self:RefreshListPanel()
    self:RefreshItemPanel()

    -- Update overall progress
    local stats = self:GetOverallStatistics()
    self.mainFrame.overallProgress:SetText(stats.progressText)
end

----------------------------------------------
-- Refresh List Panel (left side)
----------------------------------------------
function MLT:RefreshListPanel()
    local frame = self.mainFrame
    local scrollChild = frame.listScrollChild
    local currentChar = self.playerFullName

    -- Separate lists into: current character + objective, vs other characters
    local allLists = self:GetLists()
    local myLists = {}
    local otherLists = {}

    for _, list in ipairs(allLists) do
        if list.listType == "character" and list.character ~= currentChar then
            table.insert(otherLists, list)
        else
            table.insert(myLists, list)
        end
    end

    -- Hide all existing section headers
    frame.listHeaders = frame.listHeaders or {}
    for _, h in ipairs(frame.listHeaders) do
        h:Hide()
    end

    local yOffset = 0
    local btnIndex = 0

    -- Helper: create or reuse a section header
    local function ShowSectionHeader(text, headerIndex)
        if not frame.listHeaders[headerIndex] then
            local header = CreateFrame("Frame", nil, scrollChild)
            header:SetSize(LIST_PANEL_WIDTH - 8, 18)
            header.text = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            header.text:SetPoint("LEFT", 6, 0)
            header.text:SetTextColor(0.9, 0.8, 0.5)
            header.line = header:CreateTexture(nil, "ARTWORK")
            header.line:SetPoint("BOTTOMLEFT", 4, 0)
            header.line:SetPoint("BOTTOMRIGHT", -4, 0)
            header.line:SetHeight(1)
            header.line:SetColorTexture(0.3, 0.25, 0.15, 0.6)
            frame.listHeaders[headerIndex] = header
        end
        local header = frame.listHeaders[headerIndex]
        header.text:SetText(text)
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", 4, -yOffset)
        header:SetPoint("RIGHT", scrollChild, "RIGHT", -4, 0)
        header:Show()
        yOffset = yOffset + 20
    end

    -- Helper: render a list of buttons
    local function RenderLists(lists)
        for _, list in ipairs(lists) do
            btnIndex = btnIndex + 1
            local btn = frame.listButtons[btnIndex]
            if not btn then
                btn = self:CreateListButton(scrollChild)
                frame.listButtons[btnIndex] = btn
            end

            self:SetupListButton(btn, list)
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", 4, -yOffset)
            btn:SetPoint("RIGHT", scrollChild, "RIGHT", -4, 0)

            if frame.selectedListID == list.id then
                btn.bg:SetColorTexture(0.15, 0.3, 0.5, 0.6)
            else
                btn.bg:SetColorTexture(0.08, 0.08, 0.08, 0.8)
            end

            btn:Show()
            yOffset = yOffset + 32
        end
    end

    -- Section 1: Current character + objectives
    local charData = self.db.characters[currentChar]
    local myTitle = self.L["MY_LISTS"]
    if charData then
        myTitle = self:ColorByClass(charData.name, charData.class)
    end
    ShowSectionHeader(myTitle, 1)
    RenderLists(myLists)

    -- Section 2: Other characters (only if any)
    if #otherLists > 0 then
        yOffset = yOffset + 6
        ShowSectionHeader(self.L["OTHER_CHARACTERS"], 2)
        RenderLists(otherLists)
    end

    -- Hide extra buttons
    for i = btnIndex + 1, #frame.listButtons do
        frame.listButtons[i]:Hide()
    end

    scrollChild:SetHeight(math.max(yOffset, 1))

    -- Auto-select first list if none selected
    if not frame.selectedListID and myLists[1] then
        frame.selectedListID = myLists[1].id
        self:RefreshMainFrame()
    end
end

----------------------------------------------
-- Create a List Button (frame only, no content)
----------------------------------------------
function MLT:CreateListButton(parent)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(LIST_PANEL_WIDTH - 8, 30)
    btn:EnableMouse(true)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints()
    btn.bg:SetColorTexture(0.08, 0.08, 0.08, 0.8)

    btn.typeIcon = btn:CreateTexture(nil, "ARTWORK")
    btn.typeIcon:SetSize(14, 14)
    btn.typeIcon:SetPoint("LEFT", 4, 0)

    btn.nameText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.nameText:SetPoint("LEFT", btn.typeIcon, "RIGHT", 4, 6)
    btn.nameText:SetPoint("RIGHT", btn, "RIGHT", -4, 6)
    btn.nameText:SetJustifyH("LEFT")
    btn.nameText:SetWordWrap(false)

    btn.progText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.progText:SetPoint("LEFT", btn.typeIcon, "RIGHT", 4, -6)
    btn.progText:SetPoint("RIGHT", btn, "RIGHT", -4, -6)
    btn.progText:SetJustifyH("LEFT")
    btn.progText:SetTextColor(0.5, 0.7, 0.9)
    btn.progText:SetScale(0.85)

    btn:SetScript("OnEnter", function(self)
        if MLT.mainFrame.selectedListID ~= self.listID then
            self.bg:SetColorTexture(0.12, 0.12, 0.12, 0.9)
        end
    end)
    btn:SetScript("OnLeave", function(self)
        if MLT.mainFrame.selectedListID ~= self.listID then
            self.bg:SetColorTexture(0.08, 0.08, 0.08, 0.8)
        end
    end)

    return btn
end

----------------------------------------------
-- Setup List Button content (reusable)
----------------------------------------------
function MLT:SetupListButton(btn, list)
    local L = self.L
    btn.listID = list.id

    if list.listType == "character" and list.character then
        local charData = self.db.characters[list.character]
        if charData then
            -- Class icon from the standard class icon atlas
            btn.typeIcon:SetTexture("Interface\\WorldStateFrame\\Icons-Classes")
            local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[charData.class]
            if coords then
                btn.typeIcon:SetTexCoord(unpack(coords))
            else
                btn.typeIcon:SetTexCoord(0, 1, 0, 1)
            end
            -- Class-colored character name + list name
            local coloredName = self:ColorByClass(charData.name, charData.class)
            btn.nameText:SetText(coloredName .. " |cff888888-|r " .. list.name)
        else
            btn.typeIcon:SetTexture("Interface\\GLUES\\CharacterCreate\\UI-CharacterCreate-Classes")
            btn.typeIcon:SetTexCoord(0, 0.25, 0, 0.25)
            btn.nameText:SetText(list.name)
        end
    elseif list.listType == "farm" then
        btn.typeIcon:SetTexture("Interface\\Icons\\INV_Misc_Bag_10")
        btn.typeIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        btn.nameText:SetText("|cff44cc44" .. list.name .. "|r")
    else
        btn.typeIcon:SetTexture("Interface\\Icons\\INV_Scroll_03")
        btn.typeIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        btn.nameText:SetText(list.name)
    end

    local obtained, total, percent = self:GetListProgress(list.id)
    btn.progText:SetText(format(L["PROGRESS"], obtained, total, percent))

    btn:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            MLT.mainFrame.selectedListID = list.id
            MLT:RefreshMainFrame()
        elseif button == "RightButton" then
            MLT:ShowListContextMenu(list.id)
        end
    end)
end

----------------------------------------------
-- List Context Menu
----------------------------------------------
function MLT:ShowListContextMenu(listID)
    local L = self.L

    if not self.listContextMenu then
        self.listContextMenu = CreateFrame("Frame", "MLTListContextMenu", UIParent, "UIDropDownMenuTemplate")
    end

    local list = self.db.lists[listID]
    if not list then return end

    local function InitMenu(self, level)
        -- Rename
        local info = UIDropDownMenu_CreateInfo()
        info.text = L["RENAME_LIST"]
        info.notCheckable = true
        info.func = function()
            MLT:ShowInputDialog(L["ENTER_LIST_NAME"], function(name)
                if name and name ~= "" then
                    MLT:RenameList(listID, name)
                end
            end, list.name)
        end
        UIDropDownMenu_AddButton(info, level)

        -- Separator
        info = UIDropDownMenu_CreateInfo()
        info.disabled = true
        info.notCheckable = true
        UIDropDownMenu_AddButton(info, level)

        -- Delete
        info = UIDropDownMenu_CreateInfo()
        info.text = "|cffff4444" .. L["DELETE_LIST"] .. "|r"
        info.notCheckable = true
        info.func = function()
            MLT:ShowConfirmDialog(format(L["CONFIRM_DELETE_LIST"], list.name), function()
                MLT:DeleteList(listID)
                MLT.mainFrame.selectedListID = nil
                MLT:RefreshMainFrame()
            end)
        end
        UIDropDownMenu_AddButton(info, level)
    end

    UIDropDownMenu_Initialize(self.listContextMenu, InitMenu, "MENU")
    ToggleDropDownMenu(1, nil, self.listContextMenu, "cursor", 0, 0)
end

----------------------------------------------
-- Refresh Item Panel (right side)
----------------------------------------------
function MLT:RefreshItemPanel()
    local frame = self.mainFrame
    local scrollChild = frame.itemScrollChild
    local L = self.L

    -- Hide all existing rows
    for _, row in ipairs(frame.itemRows) do
        row:Hide()
    end

    -- Hide all existing headers
    frame.headerPool = frame.headerPool or {}
    for _, h in ipairs(frame.headerPool) do
        h:Hide()
    end

    local listID = frame.selectedListID
    if not listID or not self.db.lists[listID] then
        return
    end

    local list = self.db.lists[listID]
    local filter = frame.currentFilter

    -- Separate into needed and obtained, applying active filter
    local neededItems = {}
    local obtainedItems = {}

    for _, item in ipairs(list.items) do
        local passesFilter = true
        if filter then
            if filter.type == "character" then
                passesFilter = (item.assignedTo == filter.value)
            elseif filter.type == "instance" then
                local inst = item.source and item.source.instance
                if filter.value == nil then
                    -- "No source" filter: items without an instance
                    passesFilter = not inst or inst == ""
                else
                    passesFilter = (inst == filter.value)
                end
            end
        end

        if passesFilter then
            if item.obtained then
                table.insert(obtainedItems, item)
            else
                table.insert(neededItems, item)
            end
        end
    end

    -- Sort items
    local sortFunc = self:GetSortFunction(frame.currentSort)
    table.sort(neededItems, sortFunc)
    table.sort(obtainedItems, sortFunc)

    local yOffset = 0
    local rowIndex = 0

    -- Category header: Needed
    local neededHeader = self:AcquireHeader(scrollChild, 1)
    neededHeader.label:SetText(self.ADDON_COLOR .. L["CATEGORY_NEEDED"] .. " (" .. #neededItems .. ")|r")
    neededHeader:ClearAllPoints()
    neededHeader:SetPoint("TOPLEFT", 8, -yOffset)
    neededHeader:Show()
    yOffset = yOffset + 24

    -- Needed items
    for i, item in ipairs(neededItems) do
        rowIndex = rowIndex + 1
        local row = frame.itemRows[rowIndex]
        if not row then
            row = self:CreateItemRow(scrollChild)
            frame.itemRows[rowIndex] = row
        end
        self:SetupItemRow(row, item, listID, i, false)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 4, -yOffset)
        row:Show()
        yOffset = yOffset + ITEM_ROW_HEIGHT
    end

    -- Category header: Obtained (if showing)
    if self.db.config.showObtained and #obtainedItems > 0 then
        yOffset = yOffset + 8
        local obtainedHeader = self:AcquireHeader(scrollChild, 2)
        obtainedHeader.label:SetText(self.ADDON_COLOR .. L["CATEGORY_OBTAINED"] .. " (" .. #obtainedItems .. ")|r")
        obtainedHeader:ClearAllPoints()
        obtainedHeader:SetPoint("TOPLEFT", 8, -yOffset)
        obtainedHeader:Show()
        yOffset = yOffset + 24

        for i, item in ipairs(obtainedItems) do
            rowIndex = rowIndex + 1
            local row = frame.itemRows[rowIndex]
            if not row then
                row = self:CreateItemRow(scrollChild)
                frame.itemRows[rowIndex] = row
            end
            self:SetupItemRow(row, item, listID, i, true)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 4, -yOffset)
            row:Show()
            yOffset = yOffset + ITEM_ROW_HEIGHT
        end
    end

    -- Hide extra rows
    for i = rowIndex + 1, #frame.itemRows do
        frame.itemRows[i]:Hide()
    end

    scrollChild:SetHeight(math.max(yOffset + 10, 1))
end

----------------------------------------------
-- Acquire Category Header (pooled)
----------------------------------------------
function MLT:AcquireHeader(parent, index)
    local frame = self.mainFrame
    frame.headerPool = frame.headerPool or {}

    if not frame.headerPool[index] then
        local header = CreateFrame("Frame", nil, parent)
        header:SetSize(FRAME_WIDTH - LIST_PANEL_WIDTH - 30, 22)

        header.label = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        header.label:SetPoint("LEFT")

        header.line = header:CreateTexture(nil, "ARTWORK")
        header.line:SetPoint("LEFT", header.label, "RIGHT", 8, 0)
        header.line:SetPoint("RIGHT")
        header.line:SetHeight(1)
        header.line:SetColorTexture(0.2, 0.2, 0.2, 1)

        frame.headerPool[index] = header
    end

    return frame.headerPool[index]
end

----------------------------------------------
-- Create Item Row (frame structure only, no content)
----------------------------------------------
function MLT:CreateItemRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(FRAME_WIDTH - LIST_PANEL_WIDTH - 30, ITEM_ROW_HEIGHT)
    row:EnableMouse(true)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(0.08, 0.08, 0.08, 0)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(28, 28)
    row.icon:SetPoint("LEFT", 6, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.nameText:SetPoint("LEFT", row.icon, "RIGHT", 8, 4)
    row.nameText:SetWidth(200)
    row.nameText:SetJustifyH("LEFT")
    row.nameText:SetWordWrap(false)

    row.sourceText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.sourceText:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8, -4)
    row.sourceText:SetTextColor(0.6, 0.6, 0.6)

    row.statText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.statText:SetPoint("RIGHT", -8, 6)
    row.statText:SetTextColor(0.5, 0.5, 0.5)

    row.assignText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.assignText:SetPoint("RIGHT", -8, -6)

    row.noteIcon = row:CreateTexture(nil, "OVERLAY")
    row.noteIcon:SetSize(12, 12)
    row.noteIcon:SetPoint("RIGHT", -120, 0)
    row.noteIcon:SetTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")

    row:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(0.15, 0.15, 0.15, 0.5)
        if self.currentItemLink or self.currentItemID then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if self.currentItemLink then
                GameTooltip:SetHyperlink(self.currentItemLink)
            else
                GameTooltip:SetHyperlink("item:" .. self.currentItemID)
            end
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(0.08, 0.08, 0.08, 0)
        GameTooltip:Hide()
    end)

    return row
end

----------------------------------------------
-- Setup Item Row content (reusable)
----------------------------------------------
function MLT:SetupItemRow(row, item, listID, index, isObtained)
    row.currentItemLink = item.itemLink
    row.currentItemID = item.itemID

    row.icon:SetTexture(item.itemTexture or "Interface\\Icons\\INV_Misc_QuestionMark")
    row.icon:SetDesaturated(isObtained or false)
    row.icon:SetAlpha(isObtained and 0.5 or 1)

    if isObtained then
        row.nameText:SetText("|cff666666" .. (item.itemName or "?") .. "|r")
    else
        row.nameText:SetText(self:FormatItemWithColor(item.itemName, item.itemQuality))
    end

    -- Check if this is a farm list item
    local list = self.db.lists[listID]
    local isFarmItem = list and list.listType == "farm"

    if isFarmItem then
        local cur = item.currentQty or 0
        local tgt = item.targetQty or 1
        local farmColor = cur >= tgt and "|cff00ff00" or "|cffffff00"
        row.sourceText:SetText(farmColor .. format(self.L["FARM_PROGRESS"], cur, tgt) .. "|r")
        row.sourceIsUnknown = false
    else
        local sourceDisplay = self:GetSourceText(item.source)
        row.sourceIsUnknown = false
        if sourceDisplay == self.L["SOURCE_UNKNOWN"] then
            sourceDisplay = "|cff4488cc[Wowhead]|r"
            row.sourceIsUnknown = true
        end
        row.sourceText:SetText(sourceDisplay)
    end

    -- Stats
    local stats = self:GetItemStatistics(item)
    if stats.bossKillsText and not isFarmItem then
        row.statText:SetText(stats.bossKillsText)
        row.statText:Show()
    else
        row.statText:SetText("")
        row.statText:Hide()
    end

    -- Assigned character
    if item.assignedTo then
        local charData = self.db.characters[item.assignedTo]
        if charData then
            row.assignText:SetText(self:ColorByClass(charData.name, charData.class))
        else
            row.assignText:SetText(item.assignedTo)
            row.assignText:SetTextColor(0.7, 0.7, 0.7)
        end
        row.assignText:Show()
    else
        row.assignText:SetText("")
        row.assignText:Hide()
    end

    -- Note indicator
    row.noteIcon:SetShown(item.note and item.note ~= "")

    -- Mouse click handlers
    row:SetScript("OnMouseDown", function(self, button)
        if button == "RightButton" then
            MLT:ShowItemContextMenu(listID, item.itemID)
        elseif button == "LeftButton" and self.sourceIsUnknown then
            local url = MLT:GetWowheadURL(item.itemID)
            MLT:ShowCopyDialog(MLT.L["WOWHEAD_URL_TITLE"], url)
        end
    end)

    -- Drag and drop
    row:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and MLT.mainFrame.dragIndex then
            local targetIndex = index
            local fromIndex = MLT.mainFrame.dragIndex
            MLT.mainFrame.dragIndex = nil
            if fromIndex ~= targetIndex then
                MLT:ReorderItem(listID, fromIndex, targetIndex)
            end
        end
    end)
end

----------------------------------------------
-- Sort Functions
----------------------------------------------
function MLT:GetSortFunction(sortType)
    if sortType == "name" then
        return function(a, b)
            return (a.itemName or "") < (b.itemName or "")
        end
    elseif sortType == "source" then
        return function(a, b)
            local sa = self:GetSourceText(a.source)
            local sb = self:GetSourceText(b.source)
            return sa < sb
        end
    elseif sortType == "status" then
        return function(a, b)
            if a.obtained ~= b.obtained then
                return not a.obtained
            end
            return (a.itemName or "") < (b.itemName or "")
        end
    elseif sortType == "instance" then
        return function(a, b)
            local ia = (a.source and a.source.instance) or ""
            local ib = (b.source and b.source.instance) or ""
            return ia < ib
        end
    else -- sortOrder (default, manual order)
        return function(a, b)
            return (a.sortOrder or 0) < (b.sortOrder or 0)
        end
    end
end

----------------------------------------------
-- Filter Menu
----------------------------------------------
function MLT:ShowFilterMenu()
    local L = self.L

    if not self.filterMenu then
        self.filterMenu = CreateFrame("Frame", "MLTFilterMenu", UIParent, "UIDropDownMenuTemplate")
    end

    local function InitMenu(frame, level, menuList)
        local info

        if level == 1 then
            -- All
            info = UIDropDownMenu_CreateInfo()
            info.text = L["FILTER_ALL"]
            info.notCheckable = true
            info.func = function()
                MLT.mainFrame.currentFilter = nil
                MLT.mainFrame.filterBtn.text:SetText(L["FILTER_ALL"])
                MLT:RefreshMainFrame()
            end
            UIDropDownMenu_AddButton(info, level)

            -- By Instance
            info = UIDropDownMenu_CreateInfo()
            info.text = L["FILTER_BY_INSTANCE"]
            info.notCheckable = true
            info.hasArrow = true
            info.menuList = "instance"
            UIDropDownMenu_AddButton(info, level)

        elseif level == 2 and menuList == "instance" then
            -- Collect unique instances from the current list's items
            local listID = MLT.mainFrame.selectedListID
            local instances = {}
            local seen = {}
            if listID and MLT.db.lists[listID] then
                for _, item in ipairs(MLT.db.lists[listID].items) do
                    local inst = item.source and item.source.instance
                    if inst and inst ~= "" and not seen[inst] then
                        seen[inst] = true
                        -- Translate for display
                        local displayName = inst
                        if MLT.InstanceLocale and MLT.InstanceLocale[inst] then
                            displayName = MLT.InstanceLocale[inst]
                        end
                        table.insert(instances, {raw = inst, display = displayName})
                    end
                end
            end
            table.sort(instances, function(a, b) return a.display < b.display end)

            -- No source
            info = UIDropDownMenu_CreateInfo()
            info.text = L["SOURCE_UNKNOWN"]
            info.notCheckable = true
            info.func = function()
                MLT.mainFrame.currentFilter = {type = "instance", value = nil}
                MLT.mainFrame.filterBtn.text:SetText(L["SOURCE_UNKNOWN"])
                MLT:RefreshMainFrame()
                CloseDropDownMenus()
            end
            UIDropDownMenu_AddButton(info, level)

            for _, inst in ipairs(instances) do
                info = UIDropDownMenu_CreateInfo()
                info.text = inst.display
                info.notCheckable = true
                info.func = function()
                    MLT.mainFrame.currentFilter = {type = "instance", value = inst.raw}
                    MLT.mainFrame.filterBtn.text:SetText(inst.display)
                    MLT:RefreshMainFrame()
                    CloseDropDownMenus()
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end
    end

    UIDropDownMenu_Initialize(self.filterMenu, InitMenu, "MENU")
    ToggleDropDownMenu(1, nil, self.filterMenu, "cursor", 0, 0)
end

----------------------------------------------
-- Sort Menu
----------------------------------------------
function MLT:ShowSortMenu()
    local L = self.L

    if not self.sortMenu then
        self.sortMenu = CreateFrame("Frame", "MLTSortMenu", UIParent, "UIDropDownMenuTemplate")
    end

    local sortOptions = {
        {key = "sortOrder", label = L["DRAG_TO_REORDER"]},
        {key = "name", label = L["SORT_NAME"]},
        {key = "source", label = L["SORT_SOURCE"]},
        {key = "status", label = L["SORT_STATUS"]},
        {key = "instance", label = L["SORT_INSTANCE"]},
    }

    local function InitMenu(self, level)
        for _, opt in ipairs(sortOptions) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = opt.label
            info.checked = MLT.mainFrame.currentSort == opt.key
            info.func = function()
                MLT.mainFrame.currentSort = opt.key
                MLT.mainFrame.sortBtn.text:SetText(L["SORT_BY"] .. ": " .. opt.label)
                MLT:RefreshMainFrame()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end

    UIDropDownMenu_Initialize(self.sortMenu, InitMenu, "MENU")
    ToggleDropDownMenu(1, nil, self.sortMenu, "cursor", 0, 0)
end
