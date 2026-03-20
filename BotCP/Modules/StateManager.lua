-- Получение ссылки на namespace аддона
local addonName, addon = ...

-- Локальные ссылки на часто используемые API (для производительности)
local CreateFrame = CreateFrame
local GetTime = GetTime
local pairs = pairs
local tremove = tremove

-- Локальные переменные модуля
local botStates = {}          -- { ["BotName"] = { coStrategies={}, ncStrategies={}, formation, lootStrategy, rti, pending={} }, ... }
local PENDING_TIMEOUT = 3.0   -- from addon settings, default 3.0s
local timeoutFrame = nil      -- OnUpdate frame to check for expired pending states
local timeoutElapsed = 0      -- OnUpdate throttle accumulator for timeout checker
local TIMEOUT_CHECK_INTERVAL = 0.5  -- seconds between timeout checks

-- Per-bot query tracking for co/nc disambiguation
local lastQueryType = {}      -- { ["BotName"] = "co" or "nc" }
local queryQueue = {}         -- { ["BotName"] = { "co ?", "nc ?", "formation ?", "ll ?", "rti ?" } }
local queryTimestamp = {}     -- { ["BotName"] = GetTime() when last query was sent }
local QUERY_TIMEOUT = 5.0    -- seconds to wait for a query response before advancing

-- Query commands list for full state refresh
local QUERY_COMMANDS = { "co ?", "nc ?", "formation ?", "ll ?", "rti ?" }

-- Локальные функции модуля

--- Ensure a bot state table exists for the given bot name
-- @param botName string
-- @return table - the bot's state table
local function ensureBotState(botName)
    if not botStates[botName] then
        botStates[botName] = {
            coStrategies = {},
            ncStrategies = {},
            formation = nil,
            lootStrategy = nil,
            rti = nil,
            pending = {},
        }
    end
    return botStates[botName]
end

--- Send the next query command from the per-bot query queue
-- @param botName string
local function sendNextQuery(botName)
    local queue = queryQueue[botName]
    if not queue or #queue == 0 then
        queryQueue[botName] = nil
        lastQueryType[botName] = nil
        return
    end

    local nextCmd = queue[1]

    -- Track which query type we're sending for disambiguation
    if nextCmd == "co ?" then
        lastQueryType[botName] = "co"
    elseif nextCmd == "nc ?" then
        lastQueryType[botName] = "nc"
    else
        -- For formation/ll/rti queries, clear the strategy query type tracker
        lastQueryType[botName] = nil
    end

    queryTimestamp[botName] = GetTime()
    addon:SendBotCommand(botName, nextCmd)
end

--- Pop the current query from the per-bot queue and send the next one
-- @param botName string
local function advanceQueryQueue(botName)
    local queue = queryQueue[botName]
    if not queue or #queue == 0 then
        queryQueue[botName] = nil
        lastQueryType[botName] = nil
        return
    end

    tremove(queue, 1)

    if #queue > 0 then
        sendNextQuery(botName)
    else
        queryQueue[botName] = nil
        lastQueryType[botName] = nil
        queryTimestamp[botName] = nil
    end
end

--- Check all bots for expired pending states and clean them up
local function checkPendingTimeouts()
    local now = GetTime()

    -- Check for query queue timeouts (response never came back)
    -- Collect timed-out bots first to avoid modifying queryTimestamp during iteration
    local timedOutBots = {}
    for botName, timestamp in pairs(queryTimestamp) do
        if now - timestamp > QUERY_TIMEOUT then
            timedOutBots[#timedOutBots + 1] = botName
        end
    end
    for _, botName in ipairs(timedOutBots) do
        advanceQueryQueue(botName)
    end

    for botName, state in pairs(botStates) do
        local pendingToRemove = {}
        for stateKey, pendingInfo in pairs(state.pending) do
            if now - pendingInfo.timestamp > PENDING_TIMEOUT then
                pendingToRemove[#pendingToRemove + 1] = stateKey
            end
        end

        for _, stateKey in pairs(pendingToRemove) do
            local pendingInfo = state.pending[stateKey]
            local previousValue = pendingInfo.previousValue

            -- Restore previous value based on state key type
            local channel, stratName = stateKey:match("^(co):(.+)$")
            if not channel then
                channel, stratName = stateKey:match("^(nc):(.+)$")
            end

            if channel and stratName then
                -- Strategy state key (co:tank or nc:food)
                local stratTable = (channel == "co") and state.coStrategies or state.ncStrategies
                if previousValue then
                    stratTable[stratName] = true
                else
                    stratTable[stratName] = nil
                end
            elseif stateKey == "formation" then
                state.formation = previousValue
            elseif stateKey == "loot" then
                state.lootStrategy = previousValue
            elseif stateKey == "rti" then
                state.rti = previousValue
            elseif stateKey:match("^formation:") then
                state.formation = previousValue
            elseif stateKey:match("^loot:") then
                state.lootStrategy = previousValue
            elseif stateKey:match("^rti:") then
                state.rti = previousValue
            end

            -- Clear the pending state
            state.pending[stateKey] = nil

            -- Fire state changed so UI can update
            addon:FireCallback("BOTCP_STATE_CHANGED", botName, stateKey, previousValue)
        end
    end
end

--- OnUpdate handler for timeout checking
local function onTimeoutUpdate(self, dt)
    timeoutElapsed = timeoutElapsed + dt
    if timeoutElapsed < TIMEOUT_CHECK_INTERVAL then
        return
    end
    timeoutElapsed = 0
    checkPendingTimeouts()
end

--- Handle strategies received callback
-- Determine co vs nc from per-bot query tracking and update state
-- @param botName string
-- @param strategiesList table - { ["strategyName"] = true, ... }
-- @param channelHint string or nil - "co"/"nc" if determined from response prefix
local function onStrategiesReceived(botName, strategiesList, channelHint)
    local state = ensureBotState(botName)
    -- Use explicit channel hint from response format, fall back to query tracking
    local channel = channelHint or lastQueryType[botName]

    -- If we don't have a tracked query type, try to determine from context
    -- Default to "co" if unknown (edge case: untracked response)
    if not channel then
        channel = "co"
    end

    -- Mark channel as queried so IsStrategyActive returns true/false instead of nil
    if not state._queriedChannels then
        state._queriedChannels = {}
    end
    state._queriedChannels[channel] = true

    if channel == "co" then
        state.coStrategies = strategiesList

        -- Clear any pending states for co strategies (safe: collect keys first)
        local toRemove = {}
        for stateKey, _ in pairs(state.pending) do
            if stateKey:match("^co:") then
                toRemove[#toRemove + 1] = stateKey
            end
        end
        for _, key in ipairs(toRemove) do
            state.pending[key] = nil
        end

        addon:FireCallback("BOTCP_STATE_CHANGED", botName, "co", strategiesList)
    elseif channel == "nc" then
        state.ncStrategies = strategiesList

        -- Clear any pending states for nc strategies (safe: collect keys first)
        local toRemoveNc = {}
        for stateKey, _ in pairs(state.pending) do
            if stateKey:match("^nc:") then
                toRemoveNc[#toRemoveNc + 1] = stateKey
            end
        end
        for _, key in ipairs(toRemoveNc) do
            state.pending[key] = nil
        end

        addon:FireCallback("BOTCP_STATE_CHANGED", botName, "nc", strategiesList)
    end

    -- Advance the query queue to send the next query
    advanceQueryQueue(botName)
end

--- Handle formation received callback
-- @param botName string
-- @param formation string
local function onFormationReceived(botName, formation)
    local state = ensureBotState(botName)
    state.formation = formation

    -- Clear formation pending states (safe: collect keys first)
    local toRemoveFmt = {}
    for stateKey, _ in pairs(state.pending) do
        if stateKey == "formation" or stateKey:match("^formation:") then
            toRemoveFmt[#toRemoveFmt + 1] = stateKey
        end
    end
    for _, key in ipairs(toRemoveFmt) do
        state.pending[key] = nil
    end

    addon:FireCallback("BOTCP_STATE_CHANGED", botName, "formation", formation)

    -- Advance query queue if this was from a query
    advanceQueryQueue(botName)
end

--- Handle loot strategy received callback
-- @param botName string
-- @param lootStrategy string
local function onLootReceived(botName, lootStrategy)
    local state = ensureBotState(botName)
    state.lootStrategy = lootStrategy

    -- Clear loot pending states (safe: collect keys first)
    local toRemoveLoot = {}
    for stateKey, _ in pairs(state.pending) do
        if stateKey == "loot" or stateKey:match("^loot:") then
            toRemoveLoot[#toRemoveLoot + 1] = stateKey
        end
    end
    for _, key in ipairs(toRemoveLoot) do
        state.pending[key] = nil
    end

    addon:FireCallback("BOTCP_STATE_CHANGED", botName, "loot", lootStrategy)

    -- Advance query queue if this was from a query
    advanceQueryQueue(botName)
end

--- Handle RTI received callback
-- @param botName string
-- @param rti string
local function onRtiReceived(botName, rti)
    local state = ensureBotState(botName)
    state.rti = rti

    -- Clear rti pending states (safe: collect keys first)
    local toRemoveRti = {}
    for stateKey, _ in pairs(state.pending) do
        if stateKey == "rti" or stateKey:match("^rti:") then
            toRemoveRti[#toRemoveRti + 1] = stateKey
        end
    end
    for _, key in ipairs(toRemoveRti) do
        state.pending[key] = nil
    end

    addon:FireCallback("BOTCP_STATE_CHANGED", botName, "rti", rti)

    -- Advance query queue if this was from a query
    advanceQueryQueue(botName)
end

-- Публичные функции (через namespace аддона)

--- Get the full state table for a bot
-- @param botName string
-- @return table or nil
function addon:GetBotState(botName)
    return botStates[botName]
end

--- Mark a state key as pending (waiting for server response).
-- @param botName string
-- @param stateKey string - e.g. "co:tank", "formation", "loot", "rti"
-- @param requestId number - from CommandEngine
-- @param previousValue any - value before the command was sent
function addon:SetPendingState(botName, stateKey, requestId, previousValue)
    local state = ensureBotState(botName)
    state.pending[stateKey] = {
        requestId = requestId,
        timestamp = GetTime(),
        previousValue = previousValue,
    }
end

--- Remove pending state (called when response received or timeout).
-- @param botName string
-- @param stateKey string
function addon:ClearPendingState(botName, stateKey)
    local state = botStates[botName]
    if state and state.pending then
        state.pending[stateKey] = nil
    end
end

--- Check if a state key is pending for a bot
-- @param botName string
-- @param stateKey string
-- @return boolean
function addon:IsPending(botName, stateKey)
    local state = botStates[botName]
    if not state or not state.pending then
        return false
    end
    return state.pending[stateKey] ~= nil
end

--- Check if a specific strategy is active for a bot
-- @param botName string
-- @param channel string - "co" or "nc"
-- @param strategyName string
-- @return boolean or nil (nil if state unknown/never queried)
function addon:IsStrategyActive(botName, channel, strategyName)
    local state = botStates[botName]
    if not state then
        return nil
    end

    local stratTable
    if channel == "co" then
        stratTable = state.coStrategies
    elseif channel == "nc" then
        stratTable = state.ncStrategies
    else
        return nil
    end

    -- If this channel was never queried, state is unknown (return nil)
    if not state._queriedChannels or not state._queriedChannels[channel] then
        return nil
    end

    return stratTable[strategyName] == true
end

--- Check if the bot's current formation matches
-- @param botName string
-- @param formationId string
-- @return boolean or nil
function addon:IsFormation(botName, formationId)
    local state = botStates[botName]
    if not state then
        return nil
    end
    if state.formation == nil then
        return nil
    end
    return state.formation == formationId
end

--- Check if the bot's current loot strategy matches
-- @param botName string
-- @param lootId string
-- @return boolean or nil
function addon:IsLootStrategy(botName, lootId)
    local state = botStates[botName]
    if not state then
        return nil
    end
    if state.lootStrategy == nil then
        return nil
    end
    return state.lootStrategy == lootId
end

--- Get the bot's current RTI target
-- @param botName string
-- @return string or nil
function addon:GetRTI(botName)
    local state = botStates[botName]
    if not state then
        return nil
    end
    return state.rti
end

--- Send all query commands to refresh a bot's state.
-- Uses per-bot query queue to ensure sequential sending and co/nc disambiguation.
-- @param botName string
function addon:QueryBotState(botName)
    -- Initialize or reset the query queue for this bot
    queryQueue[botName] = {}
    for i = 1, #QUERY_COMMANDS do
        queryQueue[botName][i] = QUERY_COMMANDS[i]
    end

    -- Initialize queried channels tracker
    local state = ensureBotState(botName)
    if not state._queriedChannels then
        state._queriedChannels = {}
    end
    state._queriedChannels["co"] = true
    state._queriedChannels["nc"] = true

    -- Send the first query
    sendNextQuery(botName)
end

--- Call QueryBotState for each online bot.
function addon:QueryAllBotsState()
    if not addon.botRoster then
        return
    end
    for botName, info in pairs(addon.botRoster) do
        if info.online then
            addon:QueryBotState(botName)
        end
    end
end

--- Convenience function for UI to get the visual state of a button.
-- @param botName string
-- @param stateKey string - e.g. "co:tank", "nc:food", "formation:near", "loot:normal", "rti:skull"
-- @return string - "ACTIVE", "INACTIVE", "PENDING", or "UNKNOWN"
function addon:GetButtonState(botName, stateKey)
    -- Check pending first
    if addon:IsPending(botName, stateKey) then
        return "PENDING"
    end

    local state = botStates[botName]
    if not state then
        return "UNKNOWN"
    end

    -- Parse the state key to determine what to check
    local channel, stratName = stateKey:match("^(co):(.+)$")
    if not channel then
        channel, stratName = stateKey:match("^(nc):(.+)$")
    end

    if channel and stratName then
        -- Strategy state key
        local result = addon:IsStrategyActive(botName, channel, stratName)
        if result == nil then
            return "UNKNOWN"
        elseif result then
            return "ACTIVE"
        else
            return "INACTIVE"
        end
    end

    -- Formation state key: "formation:near"
    local formationId = stateKey:match("^formation:(.+)$")
    if formationId then
        local result = addon:IsFormation(botName, formationId)
        if result == nil then
            return "UNKNOWN"
        elseif result then
            return "ACTIVE"
        else
            return "INACTIVE"
        end
    end

    -- Loot state key: "loot:normal"
    local lootId = stateKey:match("^loot:(.+)$")
    if lootId then
        local result = addon:IsLootStrategy(botName, lootId)
        if result == nil then
            return "UNKNOWN"
        elseif result then
            return "ACTIVE"
        else
            return "INACTIVE"
        end
    end

    -- RTI state key: "rti:skull"
    local rtiId = stateKey:match("^rti:(.+)$")
    if rtiId then
        if state.rti == nil then
            return "UNKNOWN"
        elseif state.rti == rtiId then
            return "ACTIVE"
        else
            return "INACTIVE"
        end
    end

    return "UNKNOWN"
end

-- Инициализация модуля
addon:RegisterCallback("BOTCP_LOADED", function()
    -- Read pending timeout from saved settings
    if BotCP_DB and BotCP_DB.pendingTimeout then
        PENDING_TIMEOUT = BotCP_DB.pendingTimeout
    end

    -- Create the OnUpdate frame for pending timeout checking
    timeoutFrame = CreateFrame("Frame", "BotCP_StateManagerTimer", UIParent)
    timeoutFrame:SetScript("OnUpdate", onTimeoutUpdate)

    -- Register callbacks for response events from ResponseParser
    addon:RegisterCallback("BOTCP_STRATEGIES_RECEIVED", function(botName, strategiesList, channelHint)
        onStrategiesReceived(botName, strategiesList, channelHint)
    end)

    addon:RegisterCallback("BOTCP_FORMATION_RECEIVED", function(botName, formation)
        onFormationReceived(botName, formation)
    end)

    addon:RegisterCallback("BOTCP_LOOT_RECEIVED", function(botName, lootStrategy)
        onLootReceived(botName, lootStrategy)
    end)

    addon:RegisterCallback("BOTCP_RTI_RECEIVED", function(botName, rti)
        onRtiReceived(botName, rti)
    end)
end)
