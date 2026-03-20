-- Получение ссылки на namespace аддона
local addonName, addon = ...

-- Локальные ссылки на часто используемые API (для производительности)
local CreateFrame = CreateFrame
local math_sin = math.sin
local math_ceil = math.ceil
local pairs = pairs
local ipairs = ipairs
local GameTooltip = GameTooltip
local getglobal = getglobal

-- ============================================================================
-- State color constants
-- ============================================================================
local STATE_COLORS = {
    ACTIVE   = { r = 0,   g = 0.8, b = 0,   a = 0.8 },
    INACTIVE = { r = 0.4, g = 0.4, b = 0.4, a = 0.5 },
    PENDING  = { r = 1,   g = 0.8, b = 0,   a = 0.8 },
    UNKNOWN  = { r = 0.3, g = 0.3, b = 0.3, a = 0.3 },
}

-- Pending animation parameters
local PENDING_ALPHA_MIN = 0.3
local PENDING_ALPHA_MAX = 1.0
local PENDING_SPEED = 4  -- radians per second for sin oscillation

-- ============================================================================
-- 3.8.1 ToggleButton
-- ============================================================================

--- Create a ToggleButton widget.
-- @param parent Frame - the parent frame
-- @param config table - { name, size, icon, label, tooltip, stateKey }
-- @return Frame - the toggle button frame
function addon.CreateToggleButton(parent, config)
    local btnWidth = config.size and config.size[1] or 32
    local btnHeight = config.size and config.size[2] or 32
    local hasIcon = config.icon and config.icon ~= ""
    local isTextOnly = not hasIcon

    -- For text-only buttons, use wider size
    if isTextOnly then
        btnWidth = 48
        btnHeight = 24
    end

    local button = CreateFrame("Frame", config.name, parent)
    button:SetSize(btnWidth, btnHeight)
    button:EnableMouse(true)

    -- Store config and state
    button.config = config
    button.stateKey = config.stateKey
    button.currentState = "UNKNOWN"

    -- -----------------------------------------------------------------------
    -- Icon texture (main visual)
    -- -----------------------------------------------------------------------
    local iconSize = btnWidth - 4
    local iconHeight = btnHeight - 4
    if isTextOnly then
        iconSize = 0
        iconHeight = 0
    end

    button.icon = button:CreateTexture(nil, "ARTWORK")
    if hasIcon then
        button.icon:SetSize(iconSize, iconHeight)
        button.icon:SetPoint("CENTER", button, "CENTER", 0, 0)
        button.icon:SetTexture(config.icon)
    else
        button.icon:SetSize(0, 0)
        button.icon:Hide()
    end

    -- -----------------------------------------------------------------------
    -- Border texture (state-colored overlay)
    -- -----------------------------------------------------------------------
    button.border = button:CreateTexture(nil, "OVERLAY")
    button.border:SetSize(btnWidth, btnHeight)
    button.border:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    button.border:SetBlendMode("ADD")
    button.border:SetVertexColor(0.3, 0.3, 0.3, 0.3)

    -- -----------------------------------------------------------------------
    -- Highlight texture (mouseover)
    -- -----------------------------------------------------------------------
    button.highlight = button:CreateTexture(nil, "HIGHLIGHT")
    button.highlight:SetSize(btnWidth, btnHeight)
    button.highlight:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    button.highlight:SetBlendMode("ADD")
    button.highlight:SetAlpha(0.3)

    -- -----------------------------------------------------------------------
    -- Pending overlay texture (pulsing yellow)
    -- -----------------------------------------------------------------------
    button.pending = button:CreateTexture(nil, "OVERLAY")
    button.pending:SetSize(btnWidth, btnHeight)
    button.pending:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.pending:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    button.pending:SetBlendMode("ADD")
    button.pending:SetVertexColor(1, 0.8, 0, 0.8)
    button.pending:Hide()

    -- -----------------------------------------------------------------------
    -- Label FontString (text label, shown on button for text-only mode,
    -- or below the icon for icon mode)
    -- -----------------------------------------------------------------------
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    if isTextOnly then
        button.label:SetPoint("CENTER", button, "CENTER", 0, 0)
        button.label:SetText(config.label or "")
    else
        button.label:SetPoint("TOP", button, "BOTTOM", 0, -1)
        -- In icon mode, label is optional: only shown if explicitly requested
        button.label:SetText("")
        button.label:Hide()
    end

    -- -----------------------------------------------------------------------
    -- Pending animation state
    -- -----------------------------------------------------------------------
    local pendingElapsed = 0

    -- -----------------------------------------------------------------------
    -- Methods
    -- -----------------------------------------------------------------------

    --- Start the pending alpha pulse animation via OnUpdate.
    function button:StartPendingAnimation()
        pendingElapsed = 0
        self.pending:Show()
        self:SetScript("OnUpdate", function(selfFrame, dt)
            pendingElapsed = pendingElapsed + dt
            -- Oscillate alpha between PENDING_ALPHA_MIN and PENDING_ALPHA_MAX
            local sinVal = math_sin(pendingElapsed * PENDING_SPEED)
            -- Map sin [-1,1] to [PENDING_ALPHA_MIN, PENDING_ALPHA_MAX]
            local alpha = PENDING_ALPHA_MIN + (PENDING_ALPHA_MAX - PENDING_ALPHA_MIN) * (sinVal + 1) / 2
            selfFrame.pending:SetAlpha(alpha)
        end)
    end

    --- Stop the pending animation and hide the overlay.
    function button:StopPendingAnimation()
        -- Don't kill OnUpdate if the button is in a flash animation from action click
        if not self._isFlashing then
            self:SetScript("OnUpdate", nil)
        end
        self.pending:Hide()
    end

    --- Set the visual state of the button.
    -- @param state string - "ACTIVE", "INACTIVE", "PENDING", or "UNKNOWN"
    function button:SetState(state)
        self.currentState = state
        local colors = STATE_COLORS[state] or STATE_COLORS.UNKNOWN

        -- Border color
        self.border:SetVertexColor(colors.r, colors.g, colors.b, colors.a)

        if state == "ACTIVE" then
            if hasIcon then
                self.icon:SetDesaturated(false)
            end
            self:StopPendingAnimation()
        elseif state == "INACTIVE" then
            if hasIcon then
                self.icon:SetDesaturated(true)
            end
            self:StopPendingAnimation()
        elseif state == "PENDING" then
            if hasIcon then
                self.icon:SetDesaturated(false)
            end
            self:StartPendingAnimation()
        elseif state == "UNKNOWN" then
            if hasIcon then
                self.icon:SetDesaturated(true)
            end
            self:StopPendingAnimation()
        end
    end

    --- Get the current state string.
    -- @return string
    function button:GetState()
        return self.currentState
    end

    --- Set the click handler.
    -- @param handler function(self, state) - called on click
    function button:SetOnClick(handler)
        self.onClickHandler = handler
    end

    --- Update button state from StateManager for the given bot.
    -- @param botName string
    function button:UpdateFromStateManager(botName)
        -- Don't override flash animation on action buttons
        if self._isFlashing then
            return
        end
        if not self.stateKey then
            -- Action buttons without a stateKey stay in a neutral state
            self:SetState("INACTIVE")
            return
        end
        local state = addon:GetButtonState(botName, self.stateKey)
        self:SetState(state)
    end

    -- -----------------------------------------------------------------------
    -- Event scripts
    -- -----------------------------------------------------------------------

    -- OnMouseDown / OnMouseUp for click behavior
    button:SetScript("OnMouseDown", function(self)
        if self.onClickHandler then
            self.onClickHandler(self, self.currentState)
        end
    end)

    -- OnEnter: show tooltip
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local tooltipText = self.config.tooltip or self.config.label or ""
        GameTooltip:SetText(tooltipText, 1, 1, 1)

        -- Show description if available
        if self.config.description then
            GameTooltip:AddLine(self.config.description, 0.7, 0.7, 0.7, true)
        end

        -- Show current state as next line
        local stateText = self.currentState or "UNKNOWN"
        if stateText == "ACTIVE" then
            GameTooltip:AddLine("Status: Active", 0, 1, 0)
        elseif stateText == "INACTIVE" then
            GameTooltip:AddLine("Status: Inactive", 0.6, 0.6, 0.6)
        elseif stateText == "PENDING" then
            GameTooltip:AddLine("Status: Pending...", 1, 0.8, 0)
        else
            GameTooltip:AddLine("Status: Unknown", 0.5, 0.5, 0.5)
        end

        GameTooltip:Show()
    end)

    -- OnLeave: hide tooltip
    button:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    -- Initialize visual state
    button:SetState("UNKNOWN")

    return button
end


-- ============================================================================
-- 3.8.2 ToolbarGroup
-- ============================================================================

--- Create a ToolbarGroup widget — a labeled group of ToggleButtons.
-- @param parent Frame - the parent frame
-- @param config table - { name, label, buttons, columns, buttonSize, spacing, hasReset }
-- @return Frame - the toolbar group frame
function addon.CreateToolbarGroup(parent, config)
    local columns = config.columns or 8
    local buttonSize = config.buttonSize or { 32, 32 }
    local spacing = config.spacing or 4
    local hasReset = config.hasReset or false
    local btnWidth = buttonSize[1]
    local btnHeight = buttonSize[2]

    local group = CreateFrame("Frame", config.name, parent)
    group.config = config
    group.toggleButtons = {}

    -- -----------------------------------------------------------------------
    -- Title label
    -- -----------------------------------------------------------------------
    local TITLE_HEIGHT = 14
    local TITLE_GAP = 2

    group.titleLabel = group:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    group.titleLabel:SetPoint("TOPLEFT", group, "TOPLEFT", 0, 0)
    group.titleLabel:SetText(config.label or "")
    group.titleLabel:SetJustifyH("LEFT")

    -- -----------------------------------------------------------------------
    -- Button container
    -- -----------------------------------------------------------------------
    group.buttonContainer = CreateFrame("Frame", nil, group)
    group.buttonContainer:SetPoint("TOPLEFT", group.titleLabel, "BOTTOMLEFT", 0, -TITLE_GAP)

    -- -----------------------------------------------------------------------
    -- Create toggle buttons from the config.buttons array
    -- -----------------------------------------------------------------------
    local buttons = config.buttons or {}
    local numButtons = #buttons

    local prevButton = nil
    local firstInRow = nil
    local col = 0

    for i = 1, numButtons do
        local btnConfig = buttons[i]
        -- Inherit button size from toolbar config
        btnConfig.size = btnConfig.size or { btnWidth, btnHeight }

        local toggleBtn = addon.CreateToggleButton(group.buttonContainer, btnConfig)
        group.toggleButtons[i] = toggleBtn

        if col == 0 then
            -- First button in a row
            if not firstInRow then
                -- Very first button
                toggleBtn:SetPoint("TOPLEFT", group.buttonContainer, "TOPLEFT", 0, 0)
            else
                -- First button of a new row (wrap)
                toggleBtn:SetPoint("TOPLEFT", firstInRow, "BOTTOMLEFT", 0, -spacing)
            end
            firstInRow = toggleBtn
        else
            -- Subsequent button in the same row
            toggleBtn:SetPoint("LEFT", prevButton, "RIGHT", spacing, 0)
        end

        prevButton = toggleBtn
        col = col + 1

        -- Wrap to next row if we hit the column limit
        if col >= columns then
            col = 0
        end
    end

    -- -----------------------------------------------------------------------
    -- Reset button (optional)
    -- -----------------------------------------------------------------------
    group.resetBtn = nil
    if hasReset then
        group.resetBtn = CreateFrame("Button", config.name and (config.name .. "_Reset") or nil, group.buttonContainer, "UIPanelButtonTemplate")
        group.resetBtn:SetSize(20, 20)
        group.resetBtn:SetText("R")

        -- Position after the last toggle button
        if prevButton then
            group.resetBtn:SetPoint("LEFT", prevButton, "RIGHT", spacing, 0)
        else
            group.resetBtn:SetPoint("TOPLEFT", group.buttonContainer, "TOPLEFT", 0, 0)
        end

        -- Reduce font size for the small button
        local resetFontString = group.resetBtn:GetFontString()
        if resetFontString then
            local fontPath, _, fontFlags = resetFontString:GetFont()
            if fontPath then
                resetFontString:SetFont(fontPath, 10, fontFlags)
            end
        end
    end

    -- -----------------------------------------------------------------------
    -- Calculate and set group height
    -- -----------------------------------------------------------------------
    local function recalculateHeight()
        local totalButtons = #group.toggleButtons
        if totalButtons == 0 then
            group.buttonContainer:SetSize(1, 1)
            group:SetSize(config.width or 340, TITLE_HEIGHT + TITLE_GAP)
            return
        end

        local buttonRows = math_ceil(totalButtons / columns)
        local containerHeight = buttonRows * (btnHeight + spacing) - spacing
        local containerWidth = config.width or 340

        group.buttonContainer:SetSize(containerWidth, containerHeight)

        local totalHeight = TITLE_HEIGHT + TITLE_GAP + containerHeight
        group:SetSize(containerWidth, totalHeight)
    end

    recalculateHeight()

    -- -----------------------------------------------------------------------
    -- Methods
    -- -----------------------------------------------------------------------

    --- Update all toggle buttons from StateManager for the given bot.
    -- @param botName string
    function group:UpdateAllButtons(botName)
        for _, toggleBtn in ipairs(self.toggleButtons) do
            toggleBtn:UpdateFromStateManager(botName)
        end
    end

    --- Get the array of toggle button references.
    -- @return table
    function group:GetButtons()
        return self.toggleButtons
    end

    --- Set the toolbar title label text.
    -- @param text string
    function group:SetLabel(text)
        self.titleLabel:SetText(text or "")
    end

    --- Set the click handler for the reset button.
    -- @param handler function(self)
    function group:SetResetHandler(handler)
        if self.resetBtn then
            self.resetBtn:SetScript("OnClick", handler)
        end
    end

    --- Clear and repopulate toggle buttons (for dynamic toolbars like class-specific).
    -- @param newButtonConfigs table - array of button config tables
    function group:SetButtons(newButtonConfigs)
        -- Hide all existing toggle buttons
        for _, toggleBtn in ipairs(self.toggleButtons) do
            toggleBtn:Hide()
            toggleBtn:SetScript("OnUpdate", nil)
        end

        -- Reuse existing button frames or create new ones
        local prevBtn = nil
        local firstInRowBtn = nil
        local currentCol = 0

        for i = 1, #newButtonConfigs do
            local btnConfig = newButtonConfigs[i]
            btnConfig.size = btnConfig.size or { btnWidth, btnHeight }

            local toggleBtn = self.toggleButtons[i]
            if not toggleBtn then
                -- Create new button frame
                toggleBtn = addon.CreateToggleButton(self.buttonContainer, btnConfig)
                self.toggleButtons[i] = toggleBtn
            else
                -- Reconfigure existing button
                toggleBtn.config = btnConfig
                toggleBtn.stateKey = btnConfig.stateKey
                toggleBtn:ClearAllPoints()

                -- Update icon
                if btnConfig.icon and btnConfig.icon ~= "" then
                    toggleBtn.icon:SetTexture(btnConfig.icon)
                    toggleBtn.icon:SetSize(btnWidth - 4, btnHeight - 4)
                    toggleBtn.icon:Show()
                    toggleBtn.label:Hide()
                else
                    toggleBtn.icon:Hide()
                    toggleBtn.label:SetText(btnConfig.label or "")
                    toggleBtn.label:SetPoint("CENTER", toggleBtn, "CENTER", 0, 0)
                    toggleBtn.label:Show()
                end

                toggleBtn:SetState("UNKNOWN")
                toggleBtn:Show()
            end

            -- Layout
            if currentCol == 0 then
                if not firstInRowBtn then
                    toggleBtn:SetPoint("TOPLEFT", self.buttonContainer, "TOPLEFT", 0, 0)
                else
                    toggleBtn:SetPoint("TOPLEFT", firstInRowBtn, "BOTTOMLEFT", 0, -spacing)
                end
                firstInRowBtn = toggleBtn
            else
                toggleBtn:SetPoint("LEFT", prevBtn, "RIGHT", spacing, 0)
            end

            prevBtn = toggleBtn
            currentCol = currentCol + 1
            if currentCol >= columns then
                currentCol = 0
            end
        end

        -- Hide remaining old buttons beyond the new count
        for i = #newButtonConfigs + 1, #self.toggleButtons do
            self.toggleButtons[i]:Hide()
            self.toggleButtons[i]:SetScript("OnUpdate", nil)
        end

        -- Reposition reset button
        if self.resetBtn then
            self.resetBtn:ClearAllPoints()
            if prevBtn then
                self.resetBtn:SetPoint("LEFT", prevBtn, "RIGHT", spacing, 0)
            else
                self.resetBtn:SetPoint("TOPLEFT", self.buttonContainer, "TOPLEFT", 0, 0)
            end
        end

        -- Recalculate height based on new button count
        local totalButtons = #newButtonConfigs
        if totalButtons == 0 then
            self.buttonContainer:SetSize(1, 1)
            self:SetSize(config.width or 340, TITLE_HEIGHT + TITLE_GAP)
            return
        end

        local buttonRows = math_ceil(totalButtons / columns)
        local containerHeight = buttonRows * (btnHeight + spacing) - spacing
        local containerWidth = config.width or 340

        self.buttonContainer:SetSize(containerWidth, containerHeight)

        local totalHeight = TITLE_HEIGHT + TITLE_GAP + containerHeight
        self:SetSize(containerWidth, totalHeight)
    end

    return group
end
