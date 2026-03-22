-- Получение ссылки на namespace аддона
local addonName, addon = ...

-- Локальные ссылки на часто используемые API (для производительности)
local CreateFrame = CreateFrame
local pairs = pairs
local tremove = tremove

--- Strip WoW color codes (|cffXXXXXX and |r) from a string
-- @param str string
-- @return string - cleaned text
local function stripColorCodes(str)
    if not str then return str end
    str = str:gsub("|c%x%x%x%x%x%x%x%x", "")
    str = str:gsub("|r", "")
    return str
end

-- Локальные переменные модуля
local handlers = {}           -- { [id] = { pattern = string, handler = func }, ... }
local nextHandlerId = 1
local eventFrame = nil        -- registered for CHAT_MSG_SYSTEM, CHAT_MSG_WHISPER

-- Локальные функции модуля

--- Check if a whisper sender is a known bot
-- @param sender string - character name from CHAT_MSG_WHISPER
-- @return boolean
local function isKnownBot(sender)
    if not addon.botRoster then
        return false
    end
    -- Direct check
    if addon.botRoster[sender] then
        return true
    end
    -- Try formatted name for case-insensitive matching
    if addon.FormatBotName then
        local formatted = addon.FormatBotName(sender)
        if addon.botRoster[formatted] then
            return true
        end
    end
    return false
end

--- Process a message against all registered response handlers
-- @param message string - the chat message text
-- @param sender string - the sender name (bot name for whisper, empty for system)
local function processMessage(message, sender)
    for id, entry in pairs(handlers) do
        local captures = { message:match(entry.pattern) }
        if #captures > 0 then
            -- Call handler with message, sender, and all captures
            local success, err = pcall(entry.handler, message, sender, unpack(captures))
            if not success then
                -- Silently handle errors to prevent addon crashes
                -- In debug mode one could print: print("BotCP ResponseParser error: " .. tostring(err))
            end
        end
    end
end

--- Handle CHAT_MSG_SYSTEM events
-- Server responses to dot-commands (roster list, errors)
-- In 3.3.5a, CHAT_MSG_SYSTEM fires with (message) as the only arg
local function onSystemMessage(message)
    if not message or message == "" then
        return
    end

    -- Check for roster response patterns

    -- Format 1: "Bot added: BotName" (single bot added confirmation)
    local addedName = message:match("^Bot added: (%S+)")
    if addedName then
        addon:FireCallback("BOTCP_ROSTER_RECEIVED", {
            { name = addedName, status = "+", class = nil, action = "added" }
        })
        return
    end

    -- Format 2: "Bot removed: BotName" (single bot removed confirmation)
    local removedName = message:match("^Bot removed: (%S+)")
    if removedName then
        addon:FireCallback("BOTCP_ROSTER_RECEIVED", {
            { name = removedName, status = "-", class = nil, action = "removed" }
        })
        return
    end

    -- Check for error responses
    if message:match("not found") or message:match("does not exist") then
        addon:FireCallback("BOTCP_COMMAND_ERROR", message)
        return
    end

    -- Format 3: Roster list "+Name Class, -Name Class, ..."
    -- Try to parse as a roster listing with status indicators
    local rosterData = {}
    local foundRosterEntry = false
    for status, name, class in message:gmatch("([%+%-])(%S+)%s+(%a[%a%s]*)") do
        -- Trim trailing whitespace/comma from class
        class = class:match("^%s*(.-)%s*$")
        -- Remove trailing comma if present
        if class:sub(-1) == "," then
            class = class:sub(1, -2)
        end
        local entry = {
            name = name,
            status = status,
            class = class,
        }
        rosterData[#rosterData + 1] = entry
        foundRosterEntry = true
    end

    if foundRosterEntry then
        addon:FireCallback("BOTCP_ROSTER_RECEIVED", rosterData)
        return
    end

    -- Run registered custom handlers against system messages
    processMessage(message, "")
end

--- Parse a comma-separated strategy list into a set table
-- @param str string - e.g. "tank, melee, dps"
-- @return table - { ["tank"] = true, ["melee"] = true, ["dps"] = true }
local function parseStrategiesList(str)
    local list = {}
    for s in str:gmatch("[^,]+") do
        local trimmed = s:match("^%s*(.-)%s*$")
        if trimmed and trimmed ~= "" then
            list[trimmed] = true
        end
    end
    return list
end

--- Handle CHAT_MSG_WHISPER events
-- Bot responses to whisper commands (strategy queries, etc.)
-- In 3.3.5a: (message, sender, language, channelString, target, flags, ...)
local function onWhisperMessage(message, sender)
    if not message or not sender then
        return
    end

    -- Only process whispers from known bots
    if not isKnownBot(sender) then
        return
    end

    -- Normalize sender name for consistent lookups
    local normalizedSender = sender
    if addon.FormatBotName then
        normalizedSender = addon.FormatBotName(sender)
    end

    -- -----------------------------------------------------------------------
    -- Strategy responses (multiple format support)
    -- -----------------------------------------------------------------------

    -- "Combat strategies: tank, melee, ..." → explicit co channel
    local coStrategies = message:match("^[Cc]ombat%s+[Ss]trategies:?%s*(.+)$")
    if coStrategies then
        addon:FireCallback("BOTCP_STRATEGIES_RECEIVED", normalizedSender, parseStrategiesList(coStrategies), "co")
        return
    end

    -- "Non-combat strategies: food, drink, ..." → explicit nc channel
    local ncStrategies = message:match("^[Nn]on%-?[Cc]ombat%s+[Ss]trategies:?%s*(.+)$")
    if ncStrategies then
        addon:FireCallback("BOTCP_STRATEGIES_RECEIVED", normalizedSender, parseStrategiesList(ncStrategies), "nc")
        return
    end

    -- Generic "Strategies: tank, dps, ..." (channel determined by StateManager query tracking)
    local strategies = message:match("^[Ss]trategies:?%s*(.+)$")
    if strategies then
        addon:FireCallback("BOTCP_STRATEGIES_RECEIVED", normalizedSender, parseStrategiesList(strategies))
        return
    end

    -- -----------------------------------------------------------------------
    -- Movement response: "Following", "Staying", "Grinding", "Fleeing", etc.
    -- -----------------------------------------------------------------------
    local MOVEMENT_RESPONSES = {
        ["Following"]            = "follow",
        ["Staying"]              = "stay",
        ["Guarding"]             = "guard",
        ["Grinding"]             = "grind",
        ["Fleeing"]              = "flee",
        ["Moving away from group"] = "passive",
    }
    local movementId = MOVEMENT_RESPONSES[message]
    if movementId then
        addon:FireCallback("BOTCP_MOVEMENT_RECEIVED", normalizedSender, movementId)
        return
    end

    -- -----------------------------------------------------------------------
    -- Formation response: "Formation: near", "formation near", etc.
    -- -----------------------------------------------------------------------
    local formation = message:match("^[Ff]ormation:?%s+(%S+)")
    if formation then
        addon:FireCallback("BOTCP_FORMATION_RECEIVED", normalizedSender, stripColorCodes(formation):lower())
        return
    end

    -- -----------------------------------------------------------------------
    -- Loot strategy response: "Loot strategy: normal", "ll: normal", etc.
    -- -----------------------------------------------------------------------
    local loot = message:match("^[Ll]oot%s+[Ss]trategy:?%s+(%S+)")
    if not loot then
        loot = message:match("^ll:?%s+(%S+)")
    end
    if loot then
        addon:FireCallback("BOTCP_LOOT_RECEIVED", normalizedSender, loot:lower())
        return
    end

    -- -----------------------------------------------------------------------
    -- RTI response: "RTI: skull", "rti skull", etc.
    -- -----------------------------------------------------------------------
    local rti = message:match("^[Rr][Tt][Ii]:?%s+(%S+)")
    if rti then
        addon:FireCallback("BOTCP_RTI_RECEIVED", normalizedSender, rti:lower())
        return
    end

    -- Run registered custom handlers against whisper messages
    processMessage(message, normalizedSender)
end

--- WoW event dispatcher
local function onEvent(self, event, ...)
    if event == "CHAT_MSG_SYSTEM" then
        local message = ...
        onSystemMessage(message)
    elseif event == "CHAT_MSG_WHISPER" then
        local message, sender = ...
        onWhisperMessage(message, sender)
    end
end

-- Публичные функции (через namespace аддона)

--- Register a handler for a specific response pattern.
-- @param pattern string - Lua pattern to match against message text
-- @param handler function(message, sender, captures...) - called on match
-- @return number - handlerId for unregistration
function addon:RegisterResponseHandler(pattern, handler)
    local id = nextHandlerId
    nextHandlerId = nextHandlerId + 1
    handlers[id] = {
        pattern = pattern,
        handler = handler,
    }
    return id
end

--- Remove a response handler.
-- @param handlerId number - the ID returned by RegisterResponseHandler
function addon:UnregisterResponseHandler(handlerId)
    handlers[handlerId] = nil
end

-- Инициализация модуля
addon:RegisterCallback("BOTCP_LOADED", function()
    -- Create event frame and register for chat events
    eventFrame = CreateFrame("Frame", "BotCP_ResponseParserFrame", UIParent)
    eventFrame:RegisterEvent("CHAT_MSG_SYSTEM")
    eventFrame:RegisterEvent("CHAT_MSG_WHISPER")
    eventFrame:SetScript("OnEvent", onEvent)
end)
