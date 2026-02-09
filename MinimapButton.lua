-- MyLootTraking Minimap Button
-- Draggable minimap button with left-click, right-click, and hover actions

local _, MLT = ...

----------------------------------------------
-- Initialize Minimap Button
----------------------------------------------
function MLT:InitMinimapButton()
    local button = CreateFrame("Button", "MLTMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:SetMovable(true)
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    -- Icon
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_10_Blue")
    button.icon = icon

    -- Border (ring)
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(54, 54)
    border:SetPoint("CENTER")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button.border = border

    -- Background
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(24, 24)
    bg:SetPoint("CENTER")
    bg:SetColorTexture(0, 0, 0, 0.6)
    button.bg = bg

    -- Dragging on minimap
    button:RegisterForDrag("LeftButton")
    button.dragging = false

    button:SetScript("OnDragStart", function(self)
        self.dragging = true
    end)

    button:SetScript("OnDragStop", function(self)
        self.dragging = false
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        cx, cy = cx / scale, cy / scale
        local angle = math.atan2(cy - my, cx - mx)
        MLT.db.config.minimapPos = math.deg(angle)
        MLT:UpdateMinimapButtonPosition()
    end)

    button:SetScript("OnUpdate", function(self)
        if self.dragging then
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            local angle = math.atan2(cy - my, cx - mx)
            MLT.db.config.minimapPos = math.deg(angle)
            MLT:UpdateMinimapButtonPosition()
        end
    end)

    -- Click handlers
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnClick", function(self, btn)
        if btn == "LeftButton" then
            MLT:ToggleMainFrame()
        elseif btn == "RightButton" then
            MLT:ToggleConfigFrame()
        end
    end)

    -- Hover tooltip
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:ClearLines()

        local L = MLT.L
        GameTooltip:AddLine(MLT.ADDON_COLOR .. L["MINIMAP_TOOLTIP_TITLE"] .. "|r")
        GameTooltip:AddLine(" ")

        -- Count items to collect
        local totalNeeded = 0
        if MLT.db and MLT.db.lists then
            for _, list in pairs(MLT.db.lists) do
                for _, item in ipairs(list.items) do
                    if not item.obtained then
                        totalNeeded = totalNeeded + 1
                    end
                end
            end
        end

        GameTooltip:AddLine(format(L["MINIMAP_TOOLTIP_ITEMS"], totalNeeded), 1, 1, 1)

        -- Overall progress
        local stats = MLT:GetOverallStatistics()
        if stats.totalItems > 0 then
            GameTooltip:AddLine(stats.progressText, 0.5, 0.8, 1)
        end

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["MINIMAP_TOOLTIP_LEFT"], 0, 1, 0)
        GameTooltip:AddLine(L["MINIMAP_TOOLTIP_RIGHT"], 0, 1, 0)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    self.minimapButton = button
    self:UpdateMinimapButtonPosition()
end

----------------------------------------------
-- Update Button Position on Minimap
----------------------------------------------
function MLT:UpdateMinimapButtonPosition()
    local angle = math.rad(self.db.config.minimapPos or 220)
    local radius = 80
    local x = math.cos(angle) * radius
    local y = math.sin(angle) * radius
    self.minimapButton:ClearAllPoints()
    self.minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end
