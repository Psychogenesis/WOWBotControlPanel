-- Получение ссылки на namespace аддона
local addonName, addon = ...

-- Локальные ссылки на часто используемые API (для производительности)
local CreateFrame = CreateFrame
local pairs = pairs
local ipairs = ipairs
local type = type
local table_insert = table.insert
local table_remove = table.remove
local GetTime = GetTime
local DEFAULT_CHAT_FRAME = DEFAULT_CHAT_FRAME

-- ============================================================================
-- Addon metadata
-- ============================================================================
addon.version = "1.0.0"
addon.name = "BotCP"

-- ============================================================================
-- Event bus: internal pub/sub for module communication (NOT WoW events)
-- ============================================================================
local callbacks = {}  -- { [eventName] = { handler1, handler2, ... } }

function addon:RegisterCallback(eventName, handler)
    if type(eventName) ~= "string" or type(handler) ~= "function" then
        return
    end
    if not callbacks[eventName] then
        callbacks[eventName] = {}
    end
    table_insert(callbacks[eventName], handler)
end

function addon:UnregisterCallback(eventName, handler)
    if type(eventName) ~= "string" or not callbacks[eventName] then
        return
    end
    for i = #callbacks[eventName], 1, -1 do
        if callbacks[eventName][i] == handler then
            table_remove(callbacks[eventName], i)
            break
        end
    end
end

function addon:FireCallback(eventName, ...)
    if type(eventName) ~= "string" or not callbacks[eventName] then
        return
    end
    for _, handler in ipairs(callbacks[eventName]) do
        handler(...)
    end
end

-- ============================================================================
-- Print helper
-- ============================================================================
local function printMessage(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00CCFFBotCP:|r " .. (msg or ""))
    end
end

addon.Print = printMessage

-- ============================================================================
-- SavedVariables defaults
-- ============================================================================
local DB_DEFAULTS = {
    minimapButton = { position = 195 },
    rosterPosition = nil,
    controlPosition = nil,
    knownBots = {},
    commandThrottle = 0.3,
    pendingTimeout = 3.0,
}

local CHARDB_DEFAULTS = {
    rosterVisible = false,
    controlVisible = false,
    lastSelectedBot = nil,
}

-- ============================================================================
-- SavedVariables initialization
-- ============================================================================
local function initializeSavedVariables()
    if not BotCP_DB then
        BotCP_DB = {}
    end
    addon.MergeDefaults(BotCP_DB, DB_DEFAULTS)

    if not BotCP_CharDB then
        BotCP_CharDB = {}
    end
    addon.MergeDefaults(BotCP_CharDB, CHARDB_DEFAULTS)

    addon.db = BotCP_DB
    addon.charDb = BotCP_CharDB
end

-- ============================================================================
-- Slash command handler
-- ============================================================================
function addon:HandleSlashCommand(msg)
    local input = addon.TrimString(msg or "")
    local cmd, rest = input:match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()
    rest = addon.TrimString(rest or "")

    if cmd == "" then
        -- Toggle roster panel
        addon:FireCallback("BOTCP_TOGGLE_ROSTER")
        return
    end

    if cmd == "show" then
        addon:FireCallback("BOTCP_SHOW_ROSTER")
        return
    end

    if cmd == "hide" then
        addon:FireCallback("BOTCP_HIDE_ALL")
        return
    end

    if cmd == "add" then
        if rest == "" then
            printMessage("Usage: /botcp add <name>")
            return
        end
        local botName = addon.FormatBotName(rest)
        addon:FireCallback("BOTCP_ADD_BOT", botName)
        printMessage("Added bot: " .. botName)
        return
    end

    if cmd == "remove" then
        if rest == "" then
            printMessage("Usage: /botcp remove <name>")
            return
        end
        local botName = addon.FormatBotName(rest)
        addon:FireCallback("BOTCP_REMOVE_BOT", botName)
        printMessage("Removed bot: " .. botName)
        return
    end

    if cmd == "login" then
        if rest == "" then
            printMessage("Usage: /botcp login <name>")
            return
        end
        local botName = addon.FormatBotName(rest)
        addon:FireCallback("BOTCP_LOGIN_BOT", botName)
        printMessage("Logging in bot: " .. botName)
        return
    end

    if cmd == "logout" then
        if rest == "" then
            printMessage("Usage: /botcp logout <name>")
            return
        end
        local botName = addon.FormatBotName(rest)
        addon:FireCallback("BOTCP_LOGOUT_BOT", botName)
        printMessage("Logging out bot: " .. botName)
        return
    end

    if cmd == "help" then
        printMessage("Commands:")
        printMessage("  /botcp              - Toggle roster panel")
        printMessage("  /botcp show         - Show roster panel")
        printMessage("  /botcp hide         - Hide all panels")
        printMessage("  /botcp add <name>   - Add bot to known list")
        printMessage("  /botcp remove <name> - Remove bot from known list")
        printMessage("  /botcp login <name> - Login specific bot")
        printMessage("  /botcp logout <name> - Logout specific bot")
        printMessage("  /botcp help         - Show this help")
        return
    end

    printMessage("Unknown command: " .. cmd .. ". Type /botcp help for a list of commands.")
end

-- ============================================================================
-- Slash command registration
-- ============================================================================
SLASH_BOTCP1 = "/botcp"
SLASH_BOTCP2 = "/bcp"
SlashCmdList["BOTCP"] = function(msg)
    addon:HandleSlashCommand(msg)
end

-- ============================================================================
-- WoW event handling
-- ============================================================================
local eventFrame = CreateFrame("Frame", "BotCP_EventFrame", UIParent)

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_LOGOUT")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == addonName then
            initializeSavedVariables()
            printMessage("v" .. addon.version .. " loaded. Type /botcp help for commands.")
            addon:FireCallback("BOTCP_LOADED")
        end
    elseif event == "PLAYER_LOGIN" then
        addon:FireCallback("BOTCP_PLAYER_LOGIN")
    elseif event == "PLAYER_LOGOUT" then
        addon:FireCallback("BOTCP_PLAYER_LOGOUT")
    end
end)
