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
end

function MLT:ToggleMainFrame()
    if self.mainFrame and self.mainFrame:IsShown() then
        self.mainFrame:Hide()
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
-- Show New List Dialog
----------------------------------------------
function MLT:ShowNewListDialog()
    local L = self.L

    -- First ask for list type
    if not self.newListTypeMenu then
        self.newListTypeMenu = CreateFrame("Frame", "MLTNewListTypeMenu", UIParent, "UIDropDownMenuTemplate")
    end

    local function InitMenu(self, level)
        -- Character list
        local info = UIDropDownMenu_CreateInfo()
        info.text = L["LIST_TYPE_CHARACTER"]
        info.notCheckable = true
        info.func = function()
            -- Show character selection, then name input
            MLT:ShowCharacterSelectForNewList()
        end
        UIDropDownMenu_AddButton(info, level)

        -- Objective list
        info = UIDropDownMenu_CreateInfo()
        info.text = L["LIST_TYPE_OBJECTIVE"]
        info.notCheckable = true
        info.func = function()
            MLT:ShowInputDialog(L["ENTER_LIST_NAME"], function(name)
                if name and name ~= "" then
                    MLT:CreateList(name, "objective")
                    MLT:RefreshMainFrame()
                end
            end)
        end
        UIDropDownMenu_AddButton(info, level)
    end

    UIDropDownMenu_Initialize(self.newListTypeMenu, InitMenu, "MENU")
    ToggleDropDownMenu(1, nil, self.newListTypeMenu, "cursor", 0, 0)
end

----------------------------------------------
-- Character Select for New List
----------------------------------------------
function MLT:ShowCharacterSelectForNewList()
    local L = self.L

    if not self.charSelectMenu then
        self.charSelectMenu = CreateFrame("Frame", "MLTCharSelectMenu", UIParent, "UIDropDownMenuTemplate")
    end

    local function InitMenu(self, level)
        for fullName, charData in pairs(MLT.db.characters) do
            local info = UIDropDownMenu_CreateInfo()
            local color = MLT:GetClassColor(charData.class)
            info.text = format("|cff%02x%02x%02x%s|r", color.r * 255, color.g * 255, color.b * 255, fullName)
            info.notCheckable = true
            info.func = function()
                MLT:ShowInputDialog(L["ENTER_LIST_NAME"], function(name)
                    if name and name ~= "" then
                        MLT:CreateList(name, "character", fullName)
                        MLT:RefreshMainFrame()
                    end
                end, charData.name .. " - BiS")
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end

    UIDropDownMenu_Initialize(self.charSelectMenu, InitMenu, "MENU")
    ToggleDropDownMenu(1, nil, self.charSelectMenu, "cursor", 0, 0)
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

    -- Clear old buttons
    for _, btn in ipairs(frame.listButtons) do
        btn:Hide()
    end
    frame.listButtons = {}

    local lists = self:GetLists()
    local yOffset = 0

    for i, list in ipairs(lists) do
        local btn = self:CreateListButton(scrollChild, list, i)
        btn:SetPoint("TOPLEFT", 4, -yOffset)
        btn:SetPoint("RIGHT", scrollChild, "RIGHT", -4, 0)

        -- Highlight selected
        if frame.selectedListID == list.id then
            btn.bg:SetColorTexture(0.15, 0.3, 0.5, 0.6)
        end

        table.insert(frame.listButtons, btn)
        yOffset = yOffset + 32
    end

    scrollChild:SetHeight(math.max(yOffset, 1))

    -- Auto-select first list if none selected
    if not frame.selectedListID and lists[1] then
        frame.selectedListID = lists[1].id
        self:RefreshMainFrame()
    end
end

----------------------------------------------
-- Create a List Button
----------------------------------------------
function MLT:CreateListButton(parent, list, index)
    local L = self.L
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(LIST_PANEL_WIDTH - 8, 30)
    btn:EnableMouse(true)

    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints()
    btn.bg:SetColorTexture(0.08, 0.08, 0.08, 0.8)

    -- List type icon
    local typeIcon = btn:CreateTexture(nil, "ARTWORK")
    typeIcon:SetSize(14, 14)
    typeIcon:SetPoint("LEFT", 4, 0)
    if list.listType == "character" then
        typeIcon:SetTexture("Interface\\GLUES\\CharacterCreate\\UI-CharacterCreate-Classes")
        -- Default warrior icon for simplicity
        typeIcon:SetTexCoord(0, 0.25, 0, 0.25)
    else
        typeIcon:SetTexture("Interface\\Icons\\INV_Scroll_03")
        typeIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end

    -- List name
    local name = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    name:SetPoint("LEFT", typeIcon, "RIGHT", 4, 2)
    name:SetPoint("RIGHT", -4, 2)
    name:SetJustifyH("LEFT")
    name:SetText(list.name)
    name:SetWordWrap(false)

    -- Progress
    local obtained, total, percent = self:GetListProgress(list.id)
    local prog = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    prog:SetPoint("BOTTOMLEFT", typeIcon, "BOTTOMRIGHT", 4, -2)
    prog:SetTextColor(0.5, 0.7, 0.9)
    prog:SetText(format(L["PROGRESS"], obtained, total, percent))
    prog:SetScale(0.85)

    -- Click to select
    btn:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            MLT.mainFrame.selectedListID = list.id
            MLT:RefreshMainFrame()
        elseif button == "RightButton" then
            MLT:ShowListContextMenu(list.id)
        end
    end)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    btn:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(0.12, 0.12, 0.12, 0.9)
    end)
    btn:SetScript("OnLeave", function(self)
        if MLT.mainFrame.selectedListID ~= list.id then
            self.bg:SetColorTexture(0.08, 0.08, 0.08, 0.8)
        end
    end)

    return btn
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

        -- Import/Export
        info = UIDropDownMenu_CreateInfo()
        info.text = L["IMPORT_EXPORT"]
        info.notCheckable = true
        info.func = function()
            MLT:ShowImportExportFrame(listID)
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

    -- Clear old rows
    for _, row in ipairs(frame.itemRows) do
        row:Hide()
    end
    frame.itemRows = {}

    local listID = frame.selectedListID
    if not listID or not self.db.lists[listID] then
        return
    end

    local list = self.db.lists[listID]
    local items = {}

    -- Separate into needed and obtained
    local neededItems = {}
    local obtainedItems = {}

    for _, item in ipairs(list.items) do
        if item.obtained then
            table.insert(obtainedItems, item)
        else
            table.insert(neededItems, item)
        end
    end

    -- Sort items
    local sortFunc = self:GetSortFunction(frame.currentSort)
    table.sort(neededItems, sortFunc)
    table.sort(obtainedItems, sortFunc)

    local yOffset = 0

    -- Category header: Needed
    local neededHeader = self:CreateCategoryHeader(scrollChild, L["CATEGORY_NEEDED"] .. " (" .. #neededItems .. ")")
    neededHeader:SetPoint("TOPLEFT", 8, -yOffset)
    table.insert(frame.itemRows, neededHeader)
    yOffset = yOffset + 24

    -- Needed items
    for i, item in ipairs(neededItems) do
        local row = self:CreateItemRow(scrollChild, item, listID, i)
        row:SetPoint("TOPLEFT", 4, -yOffset)
        table.insert(frame.itemRows, row)
        yOffset = yOffset + ITEM_ROW_HEIGHT
    end

    -- Category header: Obtained (if showing)
    if self.db.config.showObtained and #obtainedItems > 0 then
        yOffset = yOffset + 8
        local obtainedHeader = self:CreateCategoryHeader(scrollChild, L["CATEGORY_OBTAINED"] .. " (" .. #obtainedItems .. ")")
        obtainedHeader:SetPoint("TOPLEFT", 8, -yOffset)
        table.insert(frame.itemRows, obtainedHeader)
        yOffset = yOffset + 24

        for i, item in ipairs(obtainedItems) do
            local row = self:CreateItemRow(scrollChild, item, listID, i, true)
            row:SetPoint("TOPLEFT", 4, -yOffset)
            table.insert(frame.itemRows, row)
            yOffset = yOffset + ITEM_ROW_HEIGHT
        end
    end

    scrollChild:SetHeight(math.max(yOffset + 10, 1))
end

----------------------------------------------
-- Create Category Header
----------------------------------------------
function MLT:CreateCategoryHeader(parent, text)
    local header = CreateFrame("Frame", nil, parent)
    header:SetSize(FRAME_WIDTH - LIST_PANEL_WIDTH - 30, 22)

    local label = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT")
    label:SetText(self.ADDON_COLOR .. text .. "|r")

    local line = header:CreateTexture(nil, "ARTWORK")
    line:SetPoint("LEFT", label, "RIGHT", 8, 0)
    line:SetPoint("RIGHT")
    line:SetHeight(1)
    line:SetColorTexture(0.2, 0.2, 0.2, 1)

    return header
end

----------------------------------------------
-- Create Item Row
----------------------------------------------
function MLT:CreateItemRow(parent, item, listID, index, isObtained)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(FRAME_WIDTH - LIST_PANEL_WIDTH - 30, ITEM_ROW_HEIGHT)
    row:EnableMouse(true)

    -- Background (subtle hover)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(0.08, 0.08, 0.08, 0)

    -- Icon
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(28, 28)
    icon:SetPoint("LEFT", 6, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetTexture(item.itemTexture or "Interface\\Icons\\INV_Misc_QuestionMark")
    if isObtained then
        icon:SetDesaturated(true)
        icon:SetAlpha(0.5)
    end

    -- Item name (colored by quality)
    local name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    name:SetPoint("LEFT", icon, "RIGHT", 8, 4)
    name:SetWidth(200)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    local nameText = self:FormatItemWithColor(item.itemName, item.itemQuality)
    if isObtained then
        nameText = "|cff666666" .. (item.itemName or "?") .. "|r"
    end
    name:SetText(nameText)

    -- Source
    local source = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    source:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 8, -4)
    source:SetTextColor(0.6, 0.6, 0.6)
    source:SetText(self:GetSourceText(item.source))

    -- Stats (boss kills)
    local stats = self:GetItemStatistics(item)
    if stats.bossKillsText then
        local statText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        statText:SetPoint("RIGHT", -8, 6)
        statText:SetTextColor(0.5, 0.5, 0.5)
        statText:SetText(stats.bossKillsText)
    end

    -- Assigned character
    if item.assignedTo then
        local charData = self.db.characters[item.assignedTo]
        local assignText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        assignText:SetPoint("RIGHT", -8, -6)
        if charData then
            assignText:SetText(self:ColorByClass(charData.name, charData.class))
        else
            assignText:SetText(item.assignedTo)
            assignText:SetTextColor(0.7, 0.7, 0.7)
        end
    end

    -- Note indicator
    if item.note and item.note ~= "" then
        local noteIcon = row:CreateTexture(nil, "OVERLAY")
        noteIcon:SetSize(12, 12)
        noteIcon:SetPoint("RIGHT", -120, 0)
        noteIcon:SetTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
    end

    -- Tooltip on hover
    row:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(0.15, 0.15, 0.15, 0.5)
        if item.itemLink or item.itemID then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if item.itemLink then
                GameTooltip:SetHyperlink(item.itemLink)
            else
                GameTooltip:SetHyperlink("item:" .. item.itemID)
            end
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(0.08, 0.08, 0.08, 0)
        GameTooltip:Hide()
    end)

    -- Right-click context menu
    row:SetScript("OnMouseDown", function(self, button)
        if button == "RightButton" then
            MLT:ShowItemContextMenu(listID, item.itemID)
        end
    end)

    -- Drag and drop for reordering
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

    return row
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

    local function InitMenu(self, level)
        local info

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

        -- By Character
        info = UIDropDownMenu_CreateInfo()
        info.text = L["FILTER_BY_CHARACTER"]
        info.notCheckable = true
        info.hasArrow = true
        info.menuList = "character"
        UIDropDownMenu_AddButton(info, level)

        -- By Source Type
        info = UIDropDownMenu_CreateInfo()
        info.text = L["FILTER_BY_SOURCE"]
        info.notCheckable = true
        info.hasArrow = true
        info.menuList = "source"
        UIDropDownMenu_AddButton(info, level)
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
