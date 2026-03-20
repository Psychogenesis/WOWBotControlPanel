-- Получение ссылки на namespace аддона
local addonName, addon = ...

-- Локальные ссылки на часто используемые API (для производительности)
local CreateFrame = CreateFrame
local math_rad = math.rad
local math_cos = math.cos
local math_sin = math.sin
local math_atan2 = math.atan2
local math_deg = math.deg
local Minimap = Minimap
local GameTooltip = GameTooltip
local GetCursorPosition = GetCursorPosition

-- Локальные переменные модуля
local MINIMAP_RADIUS = 80  -- distance from minimap center to button center
local BUTTON_SIZE = 31
local minimapButton = nil  -- the button frame
local isDragging = false   -- drag state flag

-- Локальные функции модуля

--- Position the minimap button at a given angle (degrees).
-- @param angle number - angle in degrees
local function positionButton(angle)
    local rad = math_rad(angle)
    local x = math_cos(rad) * MINIMAP_RADIUS
    local y = math_sin(rad) * MINIMAP_RADIUS
    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

--- Calculate the angle from the minimap center to the current cursor position.
-- @return number - angle in degrees
local function getAngleFromCursor()
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    local mx, my = Minimap:GetCenter()
    local dx = cx / scale - mx
    local dy = cy / scale - my
    return math_deg(math_atan2(dy, dx))
end

--- Create the minimap button frame and all its children.
local function createMinimapButton()
    minimapButton = CreateFrame("Button", "BotCP_MinimapButton", Minimap)
    minimapButton:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    minimapButton:SetFrameStrata("MEDIUM")
    minimapButton:SetFrameLevel(8)

    minimapButton:EnableMouse(true)
    minimapButton:SetMovable(true)
    minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    minimapButton:RegisterForDrag("LeftButton")

    minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    -- -----------------------------------------------------------------------
    -- Icon texture
    -- -----------------------------------------------------------------------
    local icon = minimapButton:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", minimapButton, "CENTER", 0, 0)
    icon:SetTexture("Interface\\Icons\\Ability_Warrior_BattleShout")
    minimapButton.icon = icon

    -- -----------------------------------------------------------------------
    -- Border texture (minimap tracking style)
    -- -----------------------------------------------------------------------
    local border = minimapButton:CreateTexture(nil, "OVERLAY")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT", minimapButton, "TOPLEFT", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    minimapButton.border = border

    -- -----------------------------------------------------------------------
    -- OnClick: toggle roster panel
    -- -----------------------------------------------------------------------
    minimapButton:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            addon:FireCallback("BOTCP_TOGGLE_ROSTER")
        elseif button == "RightButton" then
            addon:FireCallback("BOTCP_HIDE_ALL")
        end
    end)

    -- -----------------------------------------------------------------------
    -- Drag handling: drag around the minimap edge
    -- -----------------------------------------------------------------------
    minimapButton:SetScript("OnDragStart", function(self)
        isDragging = true
        self:SetScript("OnUpdate", function(selfFrame, dt)
            if not isDragging then
                return
            end
            local angle = getAngleFromCursor()
            positionButton(angle)
            -- Save the angle to SavedVariables
            if addon.db and addon.db.minimapButton then
                addon.db.minimapButton.position = angle
            end
        end)
    end)

    minimapButton:SetScript("OnDragStop", function(self)
        isDragging = false
        self:SetScript("OnUpdate", nil)
    end)

    -- -----------------------------------------------------------------------
    -- Tooltip
    -- -----------------------------------------------------------------------
    minimapButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("BotCP - Bot Control Panel", 1, 1, 1)
        GameTooltip:AddLine("Click to toggle roster", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Right-click to hide all", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Drag to move", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)

    minimapButton:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
end

-- ============================================================================
-- Инициализация модуля
-- ============================================================================
addon:RegisterCallback("BOTCP_LOADED", function()
    createMinimapButton()

    -- Position from saved variables
    local angle = 195
    if addon.db and addon.db.minimapButton and addon.db.minimapButton.position then
        angle = addon.db.minimapButton.position
    end
    positionButton(angle)
end)
