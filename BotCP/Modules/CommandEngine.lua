-- Получение ссылки на namespace аддона
local addonName, addon = ...

-- Локальные ссылки на часто используемые API (для производительности)
local CreateFrame = CreateFrame
local SendChatMessage = SendChatMessage
local GetTime = GetTime
local tremove = tremove
local tinsert = tinsert

-- Локальные переменные модуля
local commandQueue = {}       -- { { type, target, text, requestId, timestamp }, ... }
local nextRequestId = 1       -- auto-incrementing ID
local lastSendTime = 0        -- GetTime() of last sent command
local THROTTLE_INTERVAL = 0.3 -- from addon settings, default 0.3s
local timerFrame = nil         -- OnUpdate frame for queue processing
local elapsed = 0              -- OnUpdate throttle accumulator

-- Command types
local CMD_WHISPER = "WHISPER"
local CMD_PARTY = "PARTY"
local CMD_SERVER = "SAY"

-- Локальные функции модуля

--- Generate a unique request ID for command tracking
local function getNextRequestId()
    local id = nextRequestId
    nextRequestId = nextRequestId + 1
    return id
end

--- Enqueue a command into the FIFO queue
-- @param cmdType string - "WHISPER", "PARTY", or "SAY"
-- @param target string or nil - bot name for whisper, nil for party/server
-- @param text string - the command text
-- @return number - requestId for this command
local function enqueueCommand(cmdType, target, text)
    local requestId = getNextRequestId()
    local entry = {
        type = cmdType,
        target = target,
        text = text,
        requestId = requestId,
        timestamp = GetTime(),
    }
    tinsert(commandQueue, entry)

    -- Determine bot name for callback (target for whisper, "PARTY" for party, "SERVER" for server)
    local callbackName = target or (cmdType == CMD_PARTY and "PARTY" or "SERVER")
    addon:FireCallback("BOTCP_COMMAND_QUEUED", requestId, callbackName, text)

    return requestId
end

--- Send a single command entry via the appropriate chat channel
-- @param entry table - command queue entry
local function sendCommand(entry)
    if entry.type == CMD_WHISPER then
        SendChatMessage(entry.text, "WHISPER", nil, entry.target)
    elseif entry.type == CMD_PARTY then
        SendChatMessage(entry.text, "PARTY")
    elseif entry.type == CMD_SERVER then
        SendChatMessage(entry.text, "SAY")
    end

    lastSendTime = GetTime()

    -- Determine bot name for callback
    local callbackName = entry.target or (entry.type == CMD_PARTY and "PARTY" or "SERVER")
    addon:FireCallback("BOTCP_COMMAND_SENT", entry.requestId, callbackName, entry.text)
end

--- Process the command queue (called from OnUpdate)
-- Sends the next command if enough time has passed since the last send
local function processQueue()
    if #commandQueue == 0 then
        return
    end

    local now = GetTime()
    if now - lastSendTime < THROTTLE_INTERVAL then
        return
    end

    -- Pop the first command from the queue (FIFO)
    local entry = tremove(commandQueue, 1)
    if entry then
        sendCommand(entry)
    end
end

--- OnUpdate handler for the timer frame
-- Throttled to run logic no faster than every 0.05 seconds
local function onUpdate(self, dt)
    elapsed = elapsed + dt
    if elapsed < 0.05 then
        return
    end
    elapsed = 0
    processQueue()
end

-- Публичные функции (через namespace аддона)

--- Send a whisper command to a specific bot.
-- @param botName string - name of the bot
-- @param command string - the command text, e.g. "co +tank", "formation near"
-- @param queryAfter boolean (optional) - if true, automatically append a query
-- @return number - requestId for tracking this command
function addon:SendBotCommand(botName, command, queryAfter)
    local formattedName = botName
    if addon.FormatBotName then
        formattedName = addon.FormatBotName(botName)
    end

    local text = command
    if queryAfter then
        -- Append query suffix: "co +tank" -> "co +tank,?"
        text = command .. ",?"
    end

    return enqueueCommand(CMD_WHISPER, formattedName, text)
end

--- Send a command to all bots via PARTY chat.
-- @param command string - e.g. "follow", "co +tank"
-- @return number - requestId
function addon:SendPartyCommand(command)
    return enqueueCommand(CMD_PARTY, nil, command)
end

--- Send a dot-command to the server via SAY chat.
-- @param command string - e.g. ".playerbots bot add BotName"
-- @return number - requestId
function addon:SendServerCommand(command)
    return enqueueCommand(CMD_SERVER, nil, command)
end

--- Remove a command from the pending queue (e.g., on timeout).
-- @param requestId number - the ID of the command to cancel
function addon:CancelPending(requestId)
    for i = #commandQueue, 1, -1 do
        if commandQueue[i].requestId == requestId then
            tremove(commandQueue, i)
            return
        end
    end
end

-- Инициализация модуля
addon:RegisterCallback("BOTCP_LOADED", function()
    -- Read throttle interval from saved settings
    if BotCP_DB and BotCP_DB.commandThrottle then
        THROTTLE_INTERVAL = BotCP_DB.commandThrottle
    end

    -- Create the OnUpdate timer frame for queue processing
    timerFrame = CreateFrame("Frame", "BotCP_CommandEngineTimer", UIParent)
    timerFrame:SetScript("OnUpdate", onUpdate)
end)
