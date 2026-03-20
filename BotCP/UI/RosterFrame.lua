-- Получение ссылки на namespace аддона
local addonName, addon = ...

-- Локальные ссылки на часто используемые API (для производительности)
local CreateFrame = CreateFrame
local pairs = pairs
local ipairs = ipairs
local table_sort = table.sort
local table_insert = table.insert
local GameTooltip = GameTooltip
local getglobal = getglobal

-- Локальные переменные модуля
local rosterFrame = nil       -- main RosterFrame
local scrollChild = nil       -- scroll child frame
local statusText = nil        -- status bar FontString
local botRowPool = {}         -- object pool: { [1] = { frame, classIcon, nameText, ... }, ... }
local activeBotRows = {}      -- currently visible rows: { [1] = { frame, botName, ... }, ... }
local selectedBotName = nil   -- currently selected bot name

-- Layout constants (from section 4.1 / 4.2)
local ROSTER_WIDTH = 260
local ROSTER_HEIGHT = 400
local SCROLL_WIDTH = 236
local SCROLL_HEIGHT = 310
local SCROLL_CHILD_WIDTH = 218
local BOT_ROW_WIDTH = 218
local BOT_ROW_HEIGHT = 36
local BOT_ROW_SPACING = 2     -- gap between rows (38 - 36 = 2 from the -(index-1)*38 formula)
local BOT_ROW_STRIDE = 38     -- total vertical stride per row

-- Backdrop definition
local ROSTER_BACKDROP = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 },
}

-- Row highlight colors
local ROW_BG_NORMAL = { r = 0.1, g = 0.1, b = 0.1, a = 0.3 }
local ROW_BG_SELECTED = { r = 0.2, g = 0.4, b = 0.8, a = 0.4 }
local ROW_BG_HOVER = { r = 0.2, g = 0.2, b = 0.3, a = 0.4 }

-- Class icon atlas texture
local CLASS_ICON_TEXTURE = "Interface\\GLUES\\CHARACTERCREATE\\UI-CharacterCreate-Classes"

-- Локальные функции модуля

--- Create a single BotRow frame from the object pool (or a new one).
-- @param index number - row index (used for global naming)
-- @return table - { frame, classIcon, nameText, statusDot, loginBtn, inviteBtn, bg }
local function createBotRow(index)
    local rowName = "BotCP_BotRow_" .. index
    local row = CreateFrame("Frame", rowName, scrollChild)
    row:SetSize(BOT_ROW_WIDTH, BOT_ROW_HEIGHT)
    row:EnableMouse(true)

    -- Background texture for highlighting
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(row)
    bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    bg:SetVertexColor(ROW_BG_NORMAL.r, ROW_BG_NORMAL.g, ROW_BG_NORMAL.b, ROW_BG_NORMAL.a)

    -- Class icon (24x24, LEFT of row)
    local classIcon = row:CreateTexture(nil, "ARTWORK")
    classIcon:SetSize(24, 24)
    classIcon:SetPoint("LEFT", row, "LEFT", 6, 0)
    classIcon:SetTexture(CLASS_ICON_TEXTURE)

    -- Name text (LEFT of classIcon)
    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetPoint("LEFT", classIcon, "RIGHT", 4, 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetWidth(80)

    -- Status indicator dot (10x10)
    local statusDot = row:CreateTexture(nil, "ARTWORK")
    statusDot:SetSize(10, 10)
    statusDot:SetPoint("RIGHT", row, "RIGHT", -90, 0)
    statusDot:SetTexture("Interface\\Buttons\\WHITE8x8")

    -- Invite button (40x18, RIGHT side)
    local inviteBtn = CreateFrame("Button", rowName .. "_Invite", row, "UIPanelButtonTemplate")
    inviteBtn:SetSize(40, 18)
    inviteBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    inviteBtn:SetText("Invite")
    -- Reduce font size
    local inviteFontStr = inviteBtn:GetFontString()
    if inviteFontStr then
        local fontPath, _, fontFlags = inviteFontStr:GetFont()
        if fontPath then
            inviteFontStr:SetFont(fontPath, 10, fontFlags)
        end
    end

    -- Login button (40x18, to the left of inviteBtn)
    local loginBtn = CreateFrame("Button", rowName .. "_Login", row, "UIPanelButtonTemplate")
    loginBtn:SetSize(40, 18)
    loginBtn:SetPoint("RIGHT", row, "RIGHT", -46, 0)
    loginBtn:SetText("Login")
    -- Reduce font size
    local loginFontStr = loginBtn:GetFontString()
    if loginFontStr then
        local fontPath, _, fontFlags = loginFontStr:GetFont()
        if fontPath then
            loginFontStr:SetFont(fontPath, 10, fontFlags)
        end
    end

    local rowData = {
        frame = row,
        classIcon = classIcon,
        nameText = nameText,
        statusDot = statusDot,
        loginBtn = loginBtn,
        inviteBtn = inviteBtn,
        bg = bg,
        botName = nil,
    }

    -- Row click: select bot (only when not clicking a button)
    row:SetScript("OnMouseDown", function(self)
        if rowData.botName then
            addon:SelectBot(rowData.botName)
        end
    end)

    -- Hover highlight
    row:SetScript("OnEnter", function(self)
        if rowData.botName ~= selectedBotName then
            bg:SetVertexColor(ROW_BG_HOVER.r, ROW_BG_HOVER.g, ROW_BG_HOVER.b, ROW_BG_HOVER.a)
        end
    end)

    row:SetScript("OnLeave", function(self)
        if rowData.botName ~= selectedBotName then
            bg:SetVertexColor(ROW_BG_NORMAL.r, ROW_BG_NORMAL.g, ROW_BG_NORMAL.b, ROW_BG_NORMAL.a)
        end
    end)

    return rowData
end

--- Get a BotRow from the pool, creating one if needed.
-- @param index number
-- @return table - row data table
local function acquireBotRow(index)
    if botRowPool[index] then
        return botRowPool[index]
    end
    local row = createBotRow(index)
    botRowPool[index] = row
    return row
end

--- Configure a BotRow to display a specific bot's data.
-- @param rowData table - the row data table from the pool
-- @param botName string
-- @param botInfo table - { class = "WARRIOR", online = true/false }
-- @param index number - row index (0-based for positioning)
local function configureBotRow(rowData, botName, botInfo, index)
    rowData.botName = botName
    local row = rowData.frame

    -- Position in the scroll child
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -(index * BOT_ROW_STRIDE))

    -- Class icon texcoords
    local class = botInfo.class or "UNKNOWN"
    if class ~= "UNKNOWN" then
        local left, right, top, bottom = addon.ClassIconCoords(class)
        rowData.classIcon:SetTexCoord(left, right, top, bottom)
        rowData.classIcon:SetTexture(CLASS_ICON_TEXTURE)
        rowData.classIcon:Show()
    else
        rowData.classIcon:Hide()
    end

    -- Name text with class color
    local r, g, b = addon.ClassColor(class)
    rowData.nameText:SetText(botName)
    rowData.nameText:SetTextColor(r, g, b)

    -- Status dot color: green = online, red = offline
    local online = botInfo.online
    if online then
        rowData.statusDot:SetVertexColor(0, 1, 0, 1)
    else
        rowData.statusDot:SetVertexColor(1, 0, 0, 1)
    end

    -- Login/Logout button text
    if online then
        rowData.loginBtn:SetText("Logout")
    else
        rowData.loginBtn:SetText("Login")
    end

    -- Login button handler
    rowData.loginBtn:SetScript("OnClick", function(self)
        if online then
            addon:LogoutBot(botName)
        else
            addon:LoginBot(botName)
        end
    end)

    -- Invite/Leave button text
    local inGroup = addon:IsBotInGroup(botName)
    if inGroup then
        rowData.inviteBtn:SetText("Leave")
    else
        rowData.inviteBtn:SetText("Invite")
    end

    -- Invite button handler
    rowData.inviteBtn:SetScript("OnClick", function(self)
        if addon:IsBotInGroup(botName) then
            addon:LeaveBot(botName)
        else
            addon:InviteBot(botName)
        end
    end)

    -- Highlight if selected
    if botName == selectedBotName then
        rowData.bg:SetVertexColor(ROW_BG_SELECTED.r, ROW_BG_SELECTED.g, ROW_BG_SELECTED.b, ROW_BG_SELECTED.a)
    else
        rowData.bg:SetVertexColor(ROW_BG_NORMAL.r, ROW_BG_NORMAL.g, ROW_BG_NORMAL.b, ROW_BG_NORMAL.a)
    end

    row:Show()
end

--- Build a sorted array of bot names from the roster.
-- Online bots sort first, then alphabetically within each group.
-- @return table - array of { name, info } pairs
local function getSortedBotList()
    local list = {}
    for botName, info in pairs(addon.botRoster) do
        table_insert(list, { name = botName, info = info })
    end

    table_sort(list, function(a, b)
        -- Online bots first
        if a.info.online ~= b.info.online then
            return a.info.online
        end
        -- Then alphabetical
        return a.name < b.name
    end)

    return list
end

--- Update the status bar text with online/total count.
local function updateStatusBar()
    local total = 0
    local online = 0
    for _, info in pairs(addon.botRoster) do
        total = total + 1
        if info.online then
            online = online + 1
        end
    end
    if statusText then
        statusText:SetText(online .. "/" .. total .. " online")
    end
end

--- Rebuild the scroll child content from current roster data.
local function refreshRosterUI()
    -- Hide all currently active rows
    for i = 1, #activeBotRows do
        local rowData = activeBotRows[i]
        if rowData and rowData.frame then
            rowData.frame:Hide()
        end
    end
    activeBotRows = {}

    -- Get sorted bot list
    local sortedBots = getSortedBotList()

    if #sortedBots == 0 then
        -- Show empty message
        local emptyRow = acquireBotRow(1)
        emptyRow.classIcon:Hide()
        emptyRow.statusDot:Hide()
        emptyRow.loginBtn:Hide()
        emptyRow.inviteBtn:Hide()
        emptyRow.nameText:SetText("No bots found.\nUse /botcp add <name>\nor click Refresh.")
        emptyRow.nameText:SetTextColor(0.6, 0.6, 0.6)
        emptyRow.nameText:SetWidth(BOT_ROW_WIDTH - 12)
        emptyRow.frame:ClearAllPoints()
        emptyRow.frame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, 0)
        emptyRow.frame:SetSize(BOT_ROW_WIDTH, BOT_ROW_HEIGHT * 2)
        emptyRow.bg:SetVertexColor(0, 0, 0, 0)
        emptyRow.frame:SetScript("OnMouseDown", nil)
        emptyRow.botName = nil
        emptyRow.frame:Show()
        activeBotRows[1] = emptyRow

        scrollChild:SetHeight(BOT_ROW_HEIGHT * 2)
        updateStatusBar()
        return
    end

    -- Create/configure rows for each bot
    for i, entry in ipairs(sortedBots) do
        local rowData = acquireBotRow(i)
        configureBotRow(rowData, entry.name, entry.info, i - 1)
        activeBotRows[i] = rowData

        -- Restore proper row settings (in case this row was the "empty" placeholder)
        rowData.frame:SetSize(BOT_ROW_WIDTH, BOT_ROW_HEIGHT)
        rowData.classIcon:Show()
        rowData.statusDot:Show()
        rowData.loginBtn:Show()
        rowData.inviteBtn:Show()
        rowData.nameText:SetWidth(80)

        -- Restore click handler
        local capturedRow = rowData
        rowData.frame:SetScript("OnMouseDown", function(self)
            if capturedRow.botName then
                addon:SelectBot(capturedRow.botName)
            end
        end)
    end

    -- Hide excess pool rows
    for i = #sortedBots + 1, #botRowPool do
        if botRowPool[i] and botRowPool[i].frame then
            botRowPool[i].frame:Hide()
        end
    end

    -- Update scroll child height
    local contentHeight = #sortedBots * BOT_ROW_STRIDE
    if contentHeight < 1 then
        contentHeight = 1
    end
    scrollChild:SetHeight(contentHeight)

    updateStatusBar()
end

--- Create the main RosterFrame and all child elements.
local function createRosterFrame()
    -- -----------------------------------------------------------------------
    -- Main frame
    -- -----------------------------------------------------------------------
    rosterFrame = CreateFrame("Frame", "BotCP_RosterFrame", UIParent)
    rosterFrame:SetSize(ROSTER_WIDTH, ROSTER_HEIGHT)
    rosterFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    rosterFrame:SetBackdrop(ROSTER_BACKDROP)
    rosterFrame:SetBackdropColor(0, 0, 0, 0.9)
    rosterFrame:SetFrameStrata("MEDIUM")
    rosterFrame:SetMovable(true)
    rosterFrame:EnableMouse(true)
    rosterFrame:SetClampedToScreen(true)
    rosterFrame:RegisterForDrag("LeftButton")
    rosterFrame:Hide()

    -- Drag handling with position persistence
    rosterFrame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)

    rosterFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Save position
        local point, _, _, x, y = self:GetPoint(1)
        if addon.db then
            addon.db.rosterPosition = { point = point, x = x, y = y }
        end
    end)

    -- -----------------------------------------------------------------------
    -- Header texture
    -- -----------------------------------------------------------------------
    local header = rosterFrame:CreateTexture(nil, "ARTWORK")
    header:SetSize(256, 64)
    header:SetPoint("TOP", rosterFrame, "TOP", 0, 12)
    header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")

    -- -----------------------------------------------------------------------
    -- Title FontString
    -- -----------------------------------------------------------------------
    local title = rosterFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("CENTER", header, "CENTER", 0, 12)
    title:SetText("BotCP - Bot Roster")

    -- -----------------------------------------------------------------------
    -- Close button
    -- -----------------------------------------------------------------------
    local closeBtn = CreateFrame("Button", "BotCP_RosterCloseBtn", rosterFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", rosterFrame, "TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function(self)
        addon:HideRoster()
    end)

    -- -----------------------------------------------------------------------
    -- Mass action buttons frame
    -- -----------------------------------------------------------------------
    local massActions = CreateFrame("Frame", nil, rosterFrame)
    massActions:SetSize(240, 26)
    massActions:SetPoint("TOPLEFT", rosterFrame, "TOPLEFT", 10, -32)

    -- Login All
    local loginAllBtn = CreateFrame("Button", "BotCP_LoginAllBtn", massActions, "UIPanelButtonTemplate")
    loginAllBtn:SetSize(55, 22)
    loginAllBtn:SetPoint("TOPLEFT", massActions, "TOPLEFT", 0, 0)
    loginAllBtn:SetText("Login All")
    local loginAllFont = loginAllBtn:GetFontString()
    if loginAllFont then
        local fontPath, _, fontFlags = loginAllFont:GetFont()
        if fontPath then
            loginAllFont:SetFont(fontPath, 10, fontFlags)
        end
    end
    loginAllBtn:SetScript("OnClick", function(self)
        addon:LoginAllBots()
    end)

    -- Logout All
    local logoutAllBtn = CreateFrame("Button", "BotCP_LogoutAllBtn", massActions, "UIPanelButtonTemplate")
    logoutAllBtn:SetSize(55, 22)
    logoutAllBtn:SetPoint("LEFT", loginAllBtn, "RIGHT", 4, 0)
    logoutAllBtn:SetText("Logout All")
    local logoutAllFont = logoutAllBtn:GetFontString()
    if logoutAllFont then
        local fontPath, _, fontFlags = logoutAllFont:GetFont()
        if fontPath then
            logoutAllFont:SetFont(fontPath, 10, fontFlags)
        end
    end
    logoutAllBtn:SetScript("OnClick", function(self)
        addon:LogoutAllBots()
    end)

    -- Invite All
    local inviteAllBtn = CreateFrame("Button", "BotCP_InviteAllBtn", massActions, "UIPanelButtonTemplate")
    inviteAllBtn:SetSize(55, 22)
    inviteAllBtn:SetPoint("LEFT", logoutAllBtn, "RIGHT", 4, 0)
    inviteAllBtn:SetText("Invite All")
    local inviteAllFont = inviteAllBtn:GetFontString()
    if inviteAllFont then
        local fontPath, _, fontFlags = inviteAllFont:GetFont()
        if fontPath then
            inviteAllFont:SetFont(fontPath, 10, fontFlags)
        end
    end
    inviteAllBtn:SetScript("OnClick", function(self)
        addon:InviteAllBots()
    end)

    -- Refresh
    local refreshBtn = CreateFrame("Button", "BotCP_RefreshBtn", massActions, "UIPanelButtonTemplate")
    refreshBtn:SetSize(55, 22)
    refreshBtn:SetPoint("LEFT", inviteAllBtn, "RIGHT", 4, 0)
    refreshBtn:SetText("Refresh")
    local refreshFont = refreshBtn:GetFontString()
    if refreshFont then
        local fontPath, _, fontFlags = refreshFont:GetFont()
        if fontPath then
            refreshFont:SetFont(fontPath, 10, fontFlags)
        end
    end
    refreshBtn:SetScript("OnClick", function(self)
        addon:RefreshRoster()
    end)

    -- -----------------------------------------------------------------------
    -- Scroll frame
    -- -----------------------------------------------------------------------
    local scrollFrame = CreateFrame("ScrollFrame", "BotCP_RosterScrollFrame", rosterFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(SCROLL_WIDTH, SCROLL_HEIGHT)
    scrollFrame:SetPoint("TOPLEFT", rosterFrame, "TOPLEFT", 12, -62)

    -- Scroll child
    scrollChild = CreateFrame("Frame", "BotCP_RosterScrollChild", scrollFrame)
    scrollChild:SetSize(SCROLL_CHILD_WIDTH, 1)  -- height is dynamic
    scrollFrame:SetScrollChild(scrollChild)

    -- -----------------------------------------------------------------------
    -- Status bar
    -- -----------------------------------------------------------------------
    local statusBar = CreateFrame("Frame", nil, rosterFrame)
    statusBar:SetSize(240, 20)
    statusBar:SetPoint("BOTTOMLEFT", rosterFrame, "BOTTOMLEFT", 10, 10)

    statusText = statusBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText:SetPoint("LEFT", statusBar, "LEFT", 0, 0)
    statusText:SetText("0/0 online")
    statusText:SetJustifyH("LEFT")

    -- -----------------------------------------------------------------------
    -- Restore saved position if available
    -- -----------------------------------------------------------------------
    if addon.db and addon.db.rosterPosition then
        local pos = addon.db.rosterPosition
        if pos.point and pos.x and pos.y then
            rosterFrame:ClearAllPoints()
            rosterFrame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
        end
    end
end

-- ============================================================================
-- Публичные функции (через namespace аддона)
-- ============================================================================

--- Toggle the roster panel visibility.
function addon:ToggleRoster()
    if rosterFrame and rosterFrame:IsShown() then
        addon:HideRoster()
    else
        addon:ShowRoster()
    end
end

--- Show the roster panel.
function addon:ShowRoster()
    if rosterFrame then
        rosterFrame:Show()
        refreshRosterUI()
        -- Persist visibility
        if addon.charDb then
            addon.charDb.rosterVisible = true
        end
    end
end

--- Hide the roster panel (and optionally ControlFrame via callback).
function addon:HideRoster()
    if rosterFrame then
        rosterFrame:Hide()
        -- Persist visibility
        if addon.charDb then
            addon.charDb.rosterVisible = false
        end
    end
end

--- Rebuild the scroll child rows from botRoster data.
function addon:RefreshRosterUI()
    refreshRosterUI()
end

--- Select a bot: highlight its row, optionally open ControlFrame, and query state.
-- @param botName string
function addon:SelectBot(botName)
    selectedBotName = botName

    -- Persist selection
    if addon.charDb then
        addon.charDb.lastSelectedBot = botName
    end

    -- Update all row highlights
    for _, rowData in ipairs(activeBotRows) do
        if rowData.botName == botName then
            rowData.bg:SetVertexColor(ROW_BG_SELECTED.r, ROW_BG_SELECTED.g, ROW_BG_SELECTED.b, ROW_BG_SELECTED.a)
        else
            rowData.bg:SetVertexColor(ROW_BG_NORMAL.r, ROW_BG_NORMAL.g, ROW_BG_NORMAL.b, ROW_BG_NORMAL.a)
        end
    end

    -- Open the ControlFrame for this bot (if the function is available)
    if addon.ShowControlFrame then
        addon:ShowControlFrame(botName)
    end
end

-- ============================================================================
-- Инициализация модуля
-- ============================================================================
addon:RegisterCallback("BOTCP_LOADED", function()
    createRosterFrame()

    -- Register callback: roster data changed -> refresh UI
    addon:RegisterCallback("BOTCP_ROSTER_CHANGED", function()
        if rosterFrame and rosterFrame:IsShown() then
            refreshRosterUI()
        end
    end)

    -- Register callback: toggle/show/hide roster via slash commands or minimap button
    addon:RegisterCallback("BOTCP_TOGGLE_ROSTER", function()
        addon:ToggleRoster()
    end)

    addon:RegisterCallback("BOTCP_SHOW_ROSTER", function()
        addon:ShowRoster()
    end)

    addon:RegisterCallback("BOTCP_HIDE_ALL", function()
        addon:HideRoster()
    end)

    -- Register callback: bot targeted -> auto-select if enabled
    addon:RegisterCallback("BOTCP_BOT_TARGETED", function(botName)
        if addon.db and addon.db.autoQueryOnTarget then
            -- Show roster if hidden
            if rosterFrame and not rosterFrame:IsShown() then
                addon:ShowRoster()
            end
            addon:SelectBot(botName)
        end
    end)

    -- Register callbacks for slash command bot management
    addon:RegisterCallback("BOTCP_ADD_BOT", function(botName)
        addon:AddKnownBot(botName)
    end)

    addon:RegisterCallback("BOTCP_REMOVE_BOT", function(botName)
        addon:RemoveKnownBot(botName)
    end)

    addon:RegisterCallback("BOTCP_LOGIN_BOT", function(botName)
        addon:LoginBot(botName)
    end)

    addon:RegisterCallback("BOTCP_LOGOUT_BOT", function(botName)
        addon:LogoutBot(botName)
    end)

    -- Restore last selected bot from CharDB
    if addon.charDb and addon.charDb.lastSelectedBot then
        selectedBotName = addon.charDb.lastSelectedBot
    end
end)

-- On PLAYER_LOGIN, restore roster visibility if it was open before
addon:RegisterCallback("BOTCP_PLAYER_LOGIN", function()
    if addon.charDb and addon.charDb.rosterVisible then
        addon:ShowRoster()
        -- Auto-refresh roster on login
        addon:RefreshRoster()
    end
end)
