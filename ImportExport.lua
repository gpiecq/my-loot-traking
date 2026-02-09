-- MyLootTraking Import/Export
-- Share lists via encoded strings and save/load to text files

local _, MLT = ...

local IE_WIDTH = 450
local IE_HEIGHT = 350

----------------------------------------------
-- Show Import/Export Frame
----------------------------------------------
function MLT:ShowImportExportFrame(listID)
    if not self.ieFrame then
        self:CreateImportExportFrame()
    end

    self.ieFrame.currentListID = listID
    self.ieFrame:Show()

    -- If a list is selected, show export by default
    if listID and self.db.lists[listID] then
        self:ShowExportView(listID)
    else
        self:ShowImportView()
    end
end

----------------------------------------------
-- Create Import/Export Frame
----------------------------------------------
function MLT:CreateImportExportFrame()
    local L = self.L

    local frame = CreateFrame("Frame", "MLTImportExportFrame", UIParent)
    frame:SetSize(IE_WIDTH, IE_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    tinsert(UISpecialFrames, "MLTImportExportFrame")
    self:CreateBackdrop(frame, 0.92)

    -- Title
    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetPoint("TOPLEFT")
    titleBar:SetPoint("TOPRIGHT")
    titleBar:SetHeight(28)
    local titleBg = titleBar:CreateTexture(nil, "BACKGROUND")
    titleBg:SetAllPoints()
    titleBg:SetColorTexture(0.08, 0.08, 0.08, 1)

    frame.titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.titleText:SetPoint("LEFT", 12, 0)
    frame.titleText:SetText(self.ADDON_COLOR .. L["IMPORT_EXPORT"] .. "|r")

    local closeBtn = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    closeBtn:SetPoint("RIGHT", -2, 0)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    -- Tab buttons
    local exportTab = self:CreateCleanButton(frame, L["EXPORT"], 80, 24)
    exportTab:SetPoint("TOPLEFT", 10, -34)
    exportTab:SetScript("OnClick", function()
        if frame.currentListID then
            self:ShowExportView(frame.currentListID)
        end
    end)
    frame.exportTab = exportTab

    local importTab = self:CreateCleanButton(frame, L["IMPORT"], 80, 24)
    importTab:SetPoint("LEFT", exportTab, "RIGHT", 6, 0)
    importTab:SetScript("OnClick", function()
        self:ShowImportView()
    end)
    frame.importTab = importTab

    -- Text area (multiline edit box for copy/paste)
    local scrollFrame = CreateFrame("ScrollFrame", "MLTIEScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -66)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 50)

    local editBox = CreateFrame("EditBox", "MLTIEEditBox", scrollFrame)
    editBox:SetSize(IE_WIDTH - 50, IE_HEIGHT - 120)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetTextInsets(8, 8, 8, 8)
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    local editBg = editBox:CreateTexture(nil, "BACKGROUND")
    editBg:SetAllPoints()
    editBg:SetColorTexture(0.05, 0.05, 0.05, 0.8)

    scrollFrame:SetScrollChild(editBox)
    frame.editBox = editBox

    -- Status text
    frame.statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.statusText:SetPoint("BOTTOMLEFT", 12, 32)
    frame.statusText:SetTextColor(0.5, 0.8, 0.5)

    -- Action button (Import/Select All)
    local actionBtn = self:CreateCleanButton(frame, L["IMPORT"], 120, 28)
    actionBtn:SetPoint("BOTTOM", 0, 8)
    frame.actionBtn = actionBtn

    self.ieFrame = frame
end

----------------------------------------------
-- Show Export View
----------------------------------------------
function MLT:ShowExportView(listID)
    local L = self.L
    local frame = self.ieFrame
    local list = self.db.lists[listID]
    if not list then return end

    frame.titleText:SetText(self.ADDON_COLOR .. L["EXPORT"] .. " - " .. list.name .. "|r")

    -- Generate export string
    local exportData = self:GenerateExportString(listID)
    frame.editBox:SetText(exportData)
    frame.editBox:HighlightText()
    frame.editBox:SetFocus()

    frame.statusText:SetText(#list.items .. " item(s)")

    frame.actionBtn.text:SetText("Select All")
    frame.actionBtn:SetScript("OnClick", function()
        frame.editBox:HighlightText()
        frame.editBox:SetFocus()
    end)
end

----------------------------------------------
-- Show Import View
----------------------------------------------
function MLT:ShowImportView()
    local L = self.L
    local frame = self.ieFrame

    frame.titleText:SetText(self.ADDON_COLOR .. L["IMPORT"] .. "|r")
    frame.editBox:SetText("")
    frame.editBox:SetFocus()
    frame.statusText:SetText(L["IMPORT_STRING"])

    frame.actionBtn.text:SetText(L["IMPORT"])
    frame.actionBtn:SetScript("OnClick", function()
        local text = frame.editBox:GetText()
        self:ImportFromString(text)
    end)
end

----------------------------------------------
-- Generate Export String
----------------------------------------------
function MLT:GenerateExportString(listID)
    local list = self.db.lists[listID]
    if not list then return "" end

    -- Format: MLT:listName:itemID1,itemID2,itemID3,...
    local itemIDs = {}
    for _, item in ipairs(list.items) do
        table.insert(itemIDs, tostring(item.itemID))
    end

    return "MLT:" .. list.name .. ":" .. table.concat(itemIDs, ",")
end

----------------------------------------------
-- Import from String
----------------------------------------------
function MLT:ImportFromString(str)
    local L = self.L
    if not str or str == "" then return end

    str = self:Trim(str)

    -- Parse format: MLT:listName:itemID1,itemID2,...
    local prefix, listName, itemStr = str:match("^(MLT):([^:]+):(.+)$")

    if not prefix then
        -- Try simple format: just comma-separated IDs
        local items = {}
        for id in str:gmatch("(%d+)") do
            table.insert(items, tonumber(id))
        end
        if #items > 0 then
            self:ShowInputDialog(L["ENTER_LIST_NAME"], function(name)
                if name and name ~= "" then
                    local newListID = self:CreateList(name, "objective")
                    if newListID then
                        for _, itemID in ipairs(items) do
                            self:AddItem(newListID, itemID)
                        end
                        self:Print(format(L["IMPORT_SUCCESS"], #items))
                        self:RebuildTrackedItemCache()
                    end
                end
            end, "Imported List")
        else
            self:Print(L["IMPORT_FAILED"])
        end
        return
    end

    -- Parse item IDs
    local items = {}
    for id in itemStr:gmatch("(%d+)") do
        table.insert(items, tonumber(id))
    end

    if #items == 0 then
        self:Print(L["IMPORT_FAILED"])
        return
    end

    -- Create list and add items
    local newListID = self:CreateList(listName, "objective")
    if newListID then
        for _, itemID in ipairs(items) do
            self:AddItem(newListID, itemID)
        end
        self:Print(format(L["IMPORT_SUCCESS"], #items))
        self:RebuildTrackedItemCache()
        self:RefreshMainFrame()

        -- Update status
        if self.ieFrame then
            self.ieFrame.statusText:SetText(format(L["IMPORT_SUCCESS"], #items))
        end
    end
end
