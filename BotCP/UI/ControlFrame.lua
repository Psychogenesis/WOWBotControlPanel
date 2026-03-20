-- Получение ссылки на namespace аддона
local addonName, addon = ...

-- Локальные ссылки на часто используемые API (для производительности)
local CreateFrame = CreateFrame
local pairs = pairs
local ipairs = ipairs
local type = type
local getglobal = getglobal
local table_concat = table.concat

-- Локальные переменные модуля
local controlFrame = nil         -- the main control frame
local scrollFrame = nil          -- the scroll frame inside controlFrame
local scrollChild = nil          -- the scroll child content frame
local titleText = nil            -- the title FontString
local classIconTexture = nil     -- the class icon Texture
local partyModeCheckbox = nil    -- the party mode checkbox
local selectedBot = nil          -- currently selected bot name (string or nil)
local partyMode = false          -- whether party mode is active
local toolbarGroups = {}         -- { [toolbarId] = ToolbarGroup frame, ... }
local toolbarOrder = {}          -- ordered list of toolbar IDs for layout

-- Backdrop table for the control frame
local CONTROL_BACKDROP = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 },
}

-- ============================================================================
-- Forward declarations for local functions with circular references
-- ============================================================================
local updateScrollChildHeight
local relayoutToolbars

-- ============================================================================
-- Helper: Send a command respecting party mode
-- ============================================================================
local function sendCommand(botName, command)
    if partyMode then
        return addon:SendPartyCommand(command)
    else
        if botName then
            return addon:SendBotCommand(botName, command)
        end
    end
    return nil
end

-- ============================================================================
-- Button click handler: strategy toggle (co/nc strategy)
-- ============================================================================
local function onStrategyButtonClick(button, botName)
    if not botName then return end
    local config = button.config
    if not config or not config.stateKey then return end

    local stateKey = config.stateKey
    local channel = config.channel
    local strategyName = config.strategyName
    local currentState = addon:GetButtonState(botName, stateKey)

    local prefix
    if currentState == "ACTIVE" then
        prefix = "-"
    else
        prefix = "+"
    end

    local command = channel .. " " .. prefix .. strategyName .. ",?"
    local requestId = sendCommand(botName, command)

    if requestId and not partyMode then
        local prevValue = (currentState == "ACTIVE")
        addon:SetPendingState(botName, stateKey, requestId, prevValue)
        button:SetState("PENDING")
    end
end

-- ============================================================================
-- Button click handler: formation (exclusive)
-- ============================================================================
local function onFormationButtonClick(button, botName)
    if not botName then return end
    local config = button.config
    if not config then return end

    local command = config.command
    local requestId = sendCommand(botName, command)

    -- Also query formation state after setting
    sendCommand(botName, "formation ?")

    if requestId and not partyMode then
        local botState = addon:GetBotState(botName)
        local prevFormation = botState and botState.formation or nil
        addon:SetPendingState(botName, "formation", requestId, prevFormation)

        -- Set all formation buttons to INACTIVE except the clicked one
        local toolbar = toolbarGroups["formation"]
        if toolbar then
            local buttons = toolbar:GetButtons()
            for _, btn in ipairs(buttons) do
                if btn == button then
                    btn:SetState("PENDING")
                else
                    btn:SetState("INACTIVE")
                end
            end
        end
    end
end

-- ============================================================================
-- Button click handler: loot strategy (exclusive)
-- ============================================================================
local function onLootButtonClick(button, botName)
    if not botName then return end
    local config = button.config
    if not config then return end

    local command = config.command
    local requestId = sendCommand(botName, command)

    -- Query loot state after setting
    sendCommand(botName, "ll ?")

    if requestId and not partyMode then
        local botState = addon:GetBotState(botName)
        local prevLoot = botState and botState.lootStrategy or nil
        addon:SetPendingState(botName, "loot", requestId, prevLoot)

        -- Set all loot buttons to INACTIVE except the clicked one
        local toolbar = toolbarGroups["loot"]
        if toolbar then
            local buttons = toolbar:GetButtons()
            for _, btn in ipairs(buttons) do
                if btn == button then
                    btn:SetState("PENDING")
                else
                    btn:SetState("INACTIVE")
                end
            end
        end
    end
end

-- ============================================================================
-- Button click handler: RTI (exclusive)
-- ============================================================================
local function onRtiButtonClick(button, botName)
    if not botName then return end
    local config = button.config
    if not config then return end

    local command = config.command
    local requestId = sendCommand(botName, command)

    -- Query RTI state after setting
    sendCommand(botName, "rti ?")

    if requestId and not partyMode then
        local botState = addon:GetBotState(botName)
        local prevRti = botState and botState.rti or nil
        addon:SetPendingState(botName, "rti", requestId, prevRti)

        -- Set all RTI buttons to INACTIVE except the clicked one
        local toolbar = toolbarGroups["rti"]
        if toolbar then
            local buttons = toolbar:GetButtons()
            for _, btn in ipairs(buttons) do
                if btn == button then
                    btn:SetState("PENDING")
                else
                    btn:SetState("INACTIVE")
                end
            end
        end
    end
end

-- ============================================================================
-- Button click handler: action (fire-and-forget with visual flash)
-- ============================================================================
local function onActionButtonClick(button, botName)
    if not botName then return end
    local config = button.config
    if not config then return end

    sendCommand(botName, config.command)

    -- Brief visual flash to confirm command was sent
    button:SetState("ACTIVE")
    button._isFlashing = true
    local flashElapsed = 0
    button:SetScript("OnUpdate", function(self, dt)
        flashElapsed = flashElapsed + dt
        if flashElapsed >= 1.5 then
            self._isFlashing = nil
            self:SetScript("OnUpdate", nil)
            self:SetState("INACTIVE")
        end
    end)
end

-- ============================================================================
-- Button click handler: save mana (exclusive strategy)
-- When activating one save mana level, deactivate all others first
-- ============================================================================
local function onSaveManaButtonClick(button, botName)
    if not botName then return end
    local config = button.config
    if not config or not config.stateKey then return end

    local currentState = addon:GetButtonState(botName, config.stateKey)

    if currentState == "ACTIVE" then
        -- Just deactivate this one
        local command = config.channel .. " -" .. config.strategyName .. ",?"
        local requestId = sendCommand(botName, command)
        if requestId and not partyMode then
            addon:SetPendingState(botName, config.stateKey, requestId, true)
            button:SetState("PENDING")
        end
    else
        -- Deactivate all save mana levels, activate this one
        local parts = {}
        local toolbar = toolbarGroups["save_mana"]
        if toolbar then
            local buttons = toolbar:GetButtons()
            for _, btn in ipairs(buttons) do
                if btn.config and btn.config.strategyName and btn ~= button then
                    local btnState = addon:GetButtonState(botName, btn.config.stateKey)
                    if btnState == "ACTIVE" then
                        parts[#parts + 1] = "-" .. btn.config.strategyName
                    end
                end
            end
        end
        parts[#parts + 1] = "+" .. config.strategyName
        parts[#parts + 1] = "?"

        local command = config.channel .. " " .. table_concat(parts, ",")
        local requestId = sendCommand(botName, command)

        if requestId and not partyMode then
            addon:SetPendingState(botName, config.stateKey, requestId, false)

            -- Update button visuals for the exclusive group
            if toolbar then
                local buttons = toolbar:GetButtons()
                for _, btn in ipairs(buttons) do
                    if btn == button then
                        btn:SetState("PENDING")
                    else
                        btn:SetState("INACTIVE")
                    end
                end
            end
        end
    end
end

-- ============================================================================
-- Dispatch click based on commandType
-- ============================================================================
local function onButtonClick(button)
    local bot = selectedBot
    if not bot then return end
    local config = button.config
    if not config then return end

    local cmdType = config.commandType

    if cmdType == "action" then
        onActionButtonClick(button, bot)
    elseif cmdType == "strategy" then
        -- Check if this button belongs to the save_mana exclusive group
        if config.stateKey and config.stateKey:match("^co:save mana") then
            onSaveManaButtonClick(button, bot)
        else
            onStrategyButtonClick(button, bot)
        end
    elseif cmdType == "formation" then
        onFormationButtonClick(button, bot)
    elseif cmdType == "loot" then
        onLootButtonClick(button, bot)
    elseif cmdType == "rti" then
        onRtiButtonClick(button, bot)
    end
end

-- ============================================================================
-- Reset button handler for strategy toolbars
-- Sends co/nc -strategy1,-strategy2,...,?
-- ============================================================================
local function onResetClick(toolbarId)
    local bot = selectedBot
    if not bot then return end

    -- For formation toolbar, send "formation reset" and query
    if toolbarId == "formation" then
        sendCommand(bot, "formation reset")
        sendCommand(bot, "formation ?")
        local toolbar = toolbarGroups["formation"]
        if toolbar then
            local buttons = toolbar:GetButtons()
            for _, btn in ipairs(buttons) do
                btn:SetState("INACTIVE")
            end
        end
        return
    end

    -- For strategy-based toolbars, collect strategies and send remove commands
    local toolbar = toolbarGroups[toolbarId]
    if not toolbar then return end

    local buttons = toolbar:GetButtons()
    if not buttons or #buttons == 0 then return end

    -- Group strategies by channel
    local coStrategies = {}
    local ncStrategies = {}

    for _, btn in ipairs(buttons) do
        local config = btn.config
        if config and config.commandType == "strategy" and config.strategyName then
            if config.channel == "co" then
                coStrategies[#coStrategies + 1] = config.strategyName
            elseif config.channel == "nc" then
                ncStrategies[#ncStrategies + 1] = config.strategyName
            end
        end
    end

    -- Build and send reset commands
    if #coStrategies > 0 then
        local parts = {}
        for _, name in ipairs(coStrategies) do
            parts[#parts + 1] = "-" .. name
        end
        parts[#parts + 1] = "?"
        local command = "co " .. table_concat(parts, ",")
        sendCommand(bot, command)
    end

    if #ncStrategies > 0 then
        local parts = {}
        for _, name in ipairs(ncStrategies) do
            parts[#parts + 1] = "-" .. name
        end
        parts[#parts + 1] = "?"
        local command = "nc " .. table_concat(parts, ",")
        sendCommand(bot, command)
    end

    -- Set all buttons to INACTIVE visually
    for _, btn in ipairs(buttons) do
        btn:SetState("INACTIVE")
    end
end

-- ============================================================================
-- Update scroll child height to fit all visible toolbars
-- ============================================================================
updateScrollChildHeight = function()
    if not scrollChild then return end
    local totalHeight = 8  -- initial top padding
    for _, toolbarId in ipairs(toolbarOrder) do
        local toolbar = toolbarGroups[toolbarId]
        if toolbar and toolbar:IsShown() then
            totalHeight = totalHeight + toolbar:GetHeight() + 8
        end
    end
    totalHeight = totalHeight + 8  -- bottom padding
    if totalHeight < 440 then
        totalHeight = 440
    end
    scrollChild:SetHeight(totalHeight)
end

-- ============================================================================
-- Re-layout all visible toolbars (after hiding/showing dynamic ones)
-- ============================================================================
relayoutToolbars = function()
    local previousToolbar = nil
    for _, toolbarId in ipairs(toolbarOrder) do
        local toolbar = toolbarGroups[toolbarId]
        if toolbar and toolbar:IsShown() then
            toolbar:ClearAllPoints()
            if previousToolbar then
                toolbar:SetPoint("TOPLEFT", previousToolbar, "BOTTOMLEFT", 0, -8)
            else
                toolbar:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 8, -8)
            end
            previousToolbar = toolbar
        end
    end
    updateScrollChildHeight()
end

-- ============================================================================
-- Wire up click handlers and reset handler for a toolbar
-- ============================================================================
local function wireToolbarHandlers(toolbar, def)
    -- Store config references on each button for click handlers
    local toolbarButtons = toolbar:GetButtons()
    for j, btn in ipairs(toolbarButtons) do
        if def.buttons[j] then
            btn.config = def.buttons[j]
            btn:SetOnClick(onButtonClick)
        end
    end

    -- Set up reset button handler
    if def.hasReset then
        local toolbarId = def.id
        toolbar:SetResetHandler(function()
            onResetClick(toolbarId)
        end)
    end
end

-- ============================================================================
-- Create all toolbars inside the scroll child
-- ============================================================================
local function createToolbars()
    local defs = addon.TOOLBAR_DEFS
    if not defs then return end

    local previousToolbar = nil
    toolbarOrder = {}

    for _, def in ipairs(defs) do
        local toolbarConfig = {
            name = "BotCP_Toolbar_" .. def.id,
            label = def.label,
            buttons = {},
            columns = def.columns,
            buttonSize = def.buttonSize,
            spacing = 4,
            hasReset = def.hasReset,
        }

        -- Build button configs from the def buttons
        -- (For the dynamic class_specific toolbar, buttons starts empty)
        for _, btnDef in ipairs(def.buttons) do
            toolbarConfig.buttons[#toolbarConfig.buttons + 1] = {
                name = "BotCP_Btn_" .. def.id .. "_" .. (btnDef.id or ""):gsub(" ", "_"),
                size = def.buttonSize,
                icon = btnDef.icon,
                label = btnDef.label,
                tooltip = btnDef.tooltip,
                stateKey = btnDef.stateKey,
            }
        end

        -- Create the toolbar group via Widgets API
        local toolbar = addon.CreateToolbarGroup(scrollChild, toolbarConfig)

        -- Position it
        if previousToolbar then
            toolbar:SetPoint("TOPLEFT", previousToolbar, "BOTTOMLEFT", 0, -8)
        else
            toolbar:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 8, -8)
        end

        -- Wire click handlers and reset handler
        wireToolbarHandlers(toolbar, def)

        -- For dynamic toolbar (class_specific), hide by default since it has no buttons yet
        if def.dynamic then
            toolbar:Hide()
        end

        toolbarGroups[def.id] = toolbar
        toolbarOrder[#toolbarOrder + 1] = def.id
        previousToolbar = toolbar
    end

    -- Update scroll child height based on toolbar layout
    updateScrollChildHeight()
end

-- ============================================================================
-- Populate the dynamic class toolbar for a given class.
-- Uses ToolbarGroup:SetButtons() and :SetLabel() to reconfigure at runtime.
-- ============================================================================
local function populateClassToolbar(className)
    local toolbar = toolbarGroups["class_specific"]
    if not toolbar then return end

    -- Build class button definitions from ToolbarDefs
    local classButtons = addon.BuildClassButtons(className)

    if #classButtons == 0 then
        toolbar:Hide()
        toolbar:SetLabel("Class")
        relayoutToolbars()
        return
    end

    -- Update the label with class name
    local displayName = className:sub(1, 1) .. className:sub(2):lower()
    toolbar:SetLabel("Class (" .. displayName .. ")")

    -- Build button configs for the ToolbarGroup:SetButtons() API
    local buttonConfigs = {}
    for _, btnDef in ipairs(classButtons) do
        buttonConfigs[#buttonConfigs + 1] = {
            name = "BotCP_Btn_class_" .. (btnDef.id or ""):gsub(" ", "_"),
            size = { 32, 32 },
            icon = btnDef.icon,
            label = btnDef.label,
            tooltip = btnDef.tooltip,
            stateKey = btnDef.stateKey,
        }
    end

    -- Reconfigure the toolbar with new buttons via Widgets API
    toolbar:SetButtons(buttonConfigs)

    -- Wire click handlers and reset handler on the new buttons
    local classDef = {
        id = "class_specific",
        hasReset = true,
        buttons = classButtons,
    }
    wireToolbarHandlers(toolbar, classDef)

    toolbar:Show()
    relayoutToolbars()
end

-- ============================================================================
-- Refresh all button states from StateManager for the selected bot
-- ============================================================================
local function refreshAllButtons(botName)
    if not botName then return end

    for _, toolbarId in ipairs(toolbarOrder) do
        local toolbar = toolbarGroups[toolbarId]
        if toolbar and toolbar:IsShown() then
            toolbar:UpdateAllButtons(botName)
        end
    end
end

-- ============================================================================
-- Update title and class icon for the selected bot
-- ============================================================================
local function updateHeader(botName)
    if not titleText then return end

    if not botName then
        titleText:SetText("BotCP - No Bot Selected")
        if classIconTexture then
            classIconTexture:Hide()
        end
        return
    end

    if partyMode then
        titleText:SetText("BotCP - Party Mode")
        if classIconTexture then
            classIconTexture:Hide()
        end
        return
    end

    titleText:SetText("BotCP - " .. botName)

    local className = addon:GetBotClass(botName)
    if className and className ~= "UNKNOWN" and classIconTexture then
        local left, right, top, bottom = addon.ClassIconCoords(className)
        classIconTexture:SetTexCoord(left, right, top, bottom)
        classIconTexture:Show()
    elseif classIconTexture then
        classIconTexture:Hide()
    end
end

-- ============================================================================
-- Create the main ControlFrame UI
-- ============================================================================
local function createControlFrame()
    -- Main frame
    controlFrame = CreateFrame("Frame", "BotCP_ControlFrame", UIParent)
    controlFrame:SetSize(380, 520)
    controlFrame:SetPoint("TOPLEFT", BotCP_RosterFrame or UIParent, "TOPRIGHT", 4, 0)
    controlFrame:SetBackdrop(CONTROL_BACKDROP)
    controlFrame:SetBackdropColor(0, 0, 0, 0.85)
    controlFrame:SetFrameStrata("MEDIUM")
    controlFrame:EnableMouse(true)
    controlFrame:SetMovable(true)
    controlFrame:SetClampedToScreen(true)
    controlFrame:RegisterForDrag("LeftButton")
    controlFrame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    controlFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Save position
        local point, _, _, x, y = self:GetPoint(1)
        if addon.db then
            addon.db.controlPosition = { point = point, x = x, y = y }
        end
    end)
    controlFrame:Hide()

    -- Header texture
    local header = controlFrame:CreateTexture(nil, "ARTWORK")
    header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    header:SetSize(256, 64)
    header:SetPoint("TOP", controlFrame, "TOP", 0, 12)

    -- Class icon (left of title)
    classIconTexture = controlFrame:CreateTexture(nil, "ARTWORK")
    classIconTexture:SetSize(20, 20)
    classIconTexture:SetPoint("TOPLEFT", controlFrame, "TOPLEFT", 14, -8)
    classIconTexture:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CharacterCreate-Classes")
    classIconTexture:Hide()

    -- Title text
    titleText = controlFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("LEFT", classIconTexture, "RIGHT", 4, 0)
    titleText:SetText("BotCP - No Bot Selected")

    -- Close button
    local closeBtn = CreateFrame("Button", "BotCP_ControlFrameCloseBtn", controlFrame, "UIPanelCloseButton")
    closeBtn:SetSize(32, 32)
    closeBtn:SetPoint("TOPRIGHT", controlFrame, "TOPRIGHT", -2, -2)

    -- Party mode checkbox
    partyModeCheckbox = CreateFrame("CheckButton", "BotCP_PartyModeCheck", controlFrame, "UICheckButtonTemplate")
    partyModeCheckbox:SetSize(26, 26)
    partyModeCheckbox:SetPoint("TOPLEFT", controlFrame, "TOPLEFT", 10, -32)
    local partyModeLabel = getglobal(partyModeCheckbox:GetName() .. "Text")
    if partyModeLabel then
        partyModeLabel:SetText("Party Mode (send to all)")
    end
    partyModeCheckbox:SetScript("OnClick", function(self)
        partyMode = self:GetChecked() and true or false
        updateHeader(selectedBot)
    end)

    -- Scroll frame
    scrollFrame = CreateFrame("ScrollFrame", "BotCP_ControlScrollFrame", controlFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(356, 440)
    scrollFrame:SetPoint("TOPLEFT", controlFrame, "TOPLEFT", 12, -60)

    -- Scroll child
    scrollChild = CreateFrame("Frame", "BotCP_ControlScrollChild", scrollFrame)
    scrollChild:SetSize(340, 440)
    scrollFrame:SetScrollChild(scrollChild)

    -- Create all toolbars
    createToolbars()

    -- Restore position from SavedVariables
    if addon.db and addon.db.controlPosition then
        local pos = addon.db.controlPosition
        controlFrame:ClearAllPoints()
        controlFrame:SetPoint(pos.point or "CENTER", UIParent, pos.point or "CENTER", pos.x or 200, pos.y or 0)
    end
end

-- ============================================================================
-- Callback: BOTCP_STATE_CHANGED
-- Update buttons when a bot's state changes
-- ============================================================================
local function onStateChanged(botName, stateKey, newValue)
    if not controlFrame or not controlFrame:IsShown() then return end
    if botName ~= selectedBot then return end

    -- Refresh all buttons for this bot
    refreshAllButtons(botName)
end

-- ============================================================================
-- Callback: BOTCP_BOT_TARGETED
-- Auto-select the targeted bot if auto-query is enabled
-- ============================================================================
local function onBotTargeted(botName)
    if not addon.db or not addon.db.autoQueryOnTarget then return end
    if not botName then return end

    addon:ShowControlFrame(botName)
end

-- ============================================================================
-- Callback: BOTCP_ROSTER_CHANGED
-- Check if the selected bot went offline
-- ============================================================================
local function onRosterChanged()
    if not controlFrame or not controlFrame:IsShown() then return end
    if not selectedBot then return end

    -- Check if the selected bot is still online
    local rosterEntry = addon.botRoster[selectedBot]
    if rosterEntry and not rosterEntry.online then
        -- Bot went offline, update the title to indicate this
        if titleText then
            titleText:SetText("BotCP - " .. selectedBot .. " (Offline)")
        end
    end
end

-- ============================================================================
-- Public API: ShowControlFrame
-- Show the control panel for the given bot.
-- Populates class toolbar, updates title, queries state.
-- ============================================================================
function addon:ShowControlFrame(botName)
    if not controlFrame then
        createControlFrame()
    end

    selectedBot = botName
    partyMode = false
    if partyModeCheckbox then
        partyModeCheckbox:SetChecked(false)
    end

    -- Update header with bot info
    updateHeader(botName)

    -- Populate class-specific toolbar
    if botName then
        local className = addon:GetBotClass(botName)
        populateClassToolbar(className)
    end

    -- Show the frame
    controlFrame:Show()

    -- Query bot state to get current strategies/formation/loot/rti
    if botName then
        addon:QueryBotState(botName)
    end

    -- Save to character DB
    if addon.charDb then
        addon.charDb.controlVisible = true
        addon.charDb.lastSelectedBot = botName
    end
end

-- ============================================================================
-- Public API: HideControlFrame
-- ============================================================================
function addon:HideControlFrame()
    if controlFrame then
        controlFrame:Hide()
    end

    if addon.charDb then
        addon.charDb.controlVisible = false
    end
end

-- ============================================================================
-- Public API: RefreshControlFrame
-- Re-read all button states from StateManager and update visuals.
-- ============================================================================
function addon:RefreshControlFrame()
    if not controlFrame or not controlFrame:IsShown() then return end
    if not selectedBot then return end

    refreshAllButtons(selectedBot)
end

-- ============================================================================
-- Public API: GetSelectedBot
-- Returns the currently selected bot name.
-- ============================================================================
function addon:GetSelectedBot()
    return selectedBot
end

-- ============================================================================
-- Callback: BOTCP_HIDE_ALL
-- Hide all panels including control frame
-- ============================================================================
local function onHideAll()
    addon:HideControlFrame()
end

-- ============================================================================
-- Module initialization
-- ============================================================================
addon:RegisterCallback("BOTCP_LOADED", function()
    -- Register callbacks for state changes and events
    addon:RegisterCallback("BOTCP_STATE_CHANGED", onStateChanged)
    addon:RegisterCallback("BOTCP_BOT_TARGETED", onBotTargeted)
    addon:RegisterCallback("BOTCP_ROSTER_CHANGED", onRosterChanged)
    addon:RegisterCallback("BOTCP_HIDE_ALL", onHideAll)

    -- Restore control frame visibility from CharDB if it was visible
    if addon.charDb and addon.charDb.controlVisible and addon.charDb.lastSelectedBot then
        -- Delay the show slightly to let all modules initialize and
        -- roster data to be loaded from SavedVariables
        local delayFrame = CreateFrame("Frame")
        local delayElapsed = 0
        delayFrame:SetScript("OnUpdate", function(self, dt)
            delayElapsed = delayElapsed + dt
            if delayElapsed >= 0.5 then
                self:SetScript("OnUpdate", nil)
                local lastBot = addon.charDb.lastSelectedBot
                if lastBot and addon.botRoster[lastBot] then
                    addon:ShowControlFrame(lastBot)
                end
            end
        end)
    end
end)
