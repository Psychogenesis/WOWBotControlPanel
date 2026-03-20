-- Получение ссылки на namespace аддона
local addonName, addon = ...

-- Локальные ссылки на часто используемые API (для производительности)
local CreateFrame = CreateFrame
local GetNumPartyMembers = GetNumPartyMembers
local UnitName = UnitName
local UnitClass = UnitClass
local InviteUnit = InviteUnit
local SendChatMessage = SendChatMessage
local pairs = pairs

-- Локальные переменные модуля
local eventFrame = nil        -- registered for PARTY_MEMBERS_CHANGED, PLAYER_TARGET_CHANGED

-- Initialize the live roster table on the addon namespace
-- { ["BotName"] = { class = "WARRIOR", online = true/false }, ... }
addon.botRoster = {}

-- Локальные функции модуля

--- Build a set of bot names currently in the party/raid
-- @return table - { ["BotName"] = true, ... }
local function getPartyBotNames()
    local partyBots = {}
    local numParty = GetNumPartyMembers()
    for i = 1, numParty do
        local name = UnitName("party" .. i)
        if name and addon.botRoster[name] then
            partyBots[name] = true
        end
    end
    return partyBots
end

--- Update the roster from parsed roster data
-- @param rosterData table - array of { name, status, class, action }
local function updateRosterFromData(rosterData)
    for _, entry in pairs(rosterData) do
        local botName = entry.name
        if addon.FormatBotName then
            botName = addon.FormatBotName(botName)
        end

        if entry.action == "removed" then
            -- Bot was logged out
            if addon.botRoster[botName] then
                addon.botRoster[botName].online = false
            end
        elseif entry.action == "added" then
            -- Bot was logged in
            if addon.botRoster[botName] then
                addon.botRoster[botName].online = true
            else
                -- New bot, try to detect class
                local class = entry.class
                if class and addon.CLASS_NAMES then
                    class = addon.CLASS_NAMES[class] or class
                end
                addon.botRoster[botName] = {
                    class = class or "UNKNOWN",
                    online = true,
                }
            end
        else
            -- Roster listing entry (format 3)
            local online = (entry.status == "+")
            local class = entry.class
            if class and addon.CLASS_NAMES then
                class = addon.CLASS_NAMES[class] or class
            end

            if addon.botRoster[botName] then
                addon.botRoster[botName].online = online
                if class then
                    addon.botRoster[botName].class = class
                end
            else
                addon.botRoster[botName] = {
                    class = class or "UNKNOWN",
                    online = online,
                }
            end
        end

        -- Persist to knownBots SavedVariables
        if BotCP_DB and BotCP_DB.knownBots then
            if not BotCP_DB.knownBots[botName] then
                BotCP_DB.knownBots[botName] = {}
            end
            if addon.botRoster[botName] and addon.botRoster[botName].class ~= "UNKNOWN" then
                BotCP_DB.knownBots[botName].class = addon.botRoster[botName].class
            end
        end
    end

    addon:FireCallback("BOTCP_ROSTER_CHANGED")
end

--- Handle PARTY_MEMBERS_CHANGED event
-- Re-check which bots are in the group
local function onPartyMembersChanged()
    addon:FireCallback("BOTCP_ROSTER_CHANGED")
end

--- Handle PLAYER_TARGET_CHANGED event
-- If target is a bot, fire BOTCP_BOT_TARGETED
local function onPlayerTargetChanged()
    local targetName = UnitName("target")
    if not targetName then
        return
    end

    -- Check if target is a known bot
    if addon.botRoster[targetName] then
        -- Also try to detect class if unknown
        if addon.botRoster[targetName].class == "UNKNOWN" then
            local _, englishClass = UnitClass("target")
            if englishClass then
                addon.botRoster[targetName].class = englishClass
                -- Persist
                if BotCP_DB and BotCP_DB.knownBots and BotCP_DB.knownBots[targetName] then
                    BotCP_DB.knownBots[targetName].class = englishClass
                end
            end
        end
        addon:FireCallback("BOTCP_BOT_TARGETED", targetName)
        return
    end

    -- Try formatted name
    if addon.FormatBotName then
        local formatted = addon.FormatBotName(targetName)
        if addon.botRoster[formatted] then
            if addon.botRoster[formatted].class == "UNKNOWN" then
                local _, englishClass = UnitClass("target")
                if englishClass then
                    addon.botRoster[formatted].class = englishClass
                    if BotCP_DB and BotCP_DB.knownBots and BotCP_DB.knownBots[formatted] then
                        BotCP_DB.knownBots[formatted].class = englishClass
                    end
                end
            end
            addon:FireCallback("BOTCP_BOT_TARGETED", formatted)
        end
    end
end

--- WoW event dispatcher
local function onEvent(self, event, ...)
    if event == "PARTY_MEMBERS_CHANGED" then
        onPartyMembersChanged()
    elseif event == "PLAYER_TARGET_CHANGED" then
        onPlayerTargetChanged()
    end
end

-- Публичные функции (через namespace аддона)

--- Send ".playerbots bot list" command to refresh the roster.
function addon:RefreshRoster()
    addon:SendServerCommand(".playerbots bot list")
end

--- Login a specific bot
-- @param botName string
function addon:LoginBot(botName)
    local name = botName
    if addon.FormatBotName then
        name = addon.FormatBotName(botName)
    end
    addon:SendServerCommand(".playerbots bot add " .. name)
end

--- Logout a specific bot
-- @param botName string
function addon:LogoutBot(botName)
    local name = botName
    if addon.FormatBotName then
        name = addon.FormatBotName(botName)
    end
    addon:SendServerCommand(".playerbots bot rm " .. name)
end

--- Login all known bots that are offline.
-- Builds comma-separated list for single command.
function addon:LoginAllBots()
    local names = {}
    for botName, info in pairs(addon.botRoster) do
        if not info.online then
            names[#names + 1] = botName
        end
    end

    if #names == 0 then
        return
    end

    -- Build comma-separated list
    local nameList = names[1]
    for i = 2, #names do
        nameList = nameList .. "," .. names[i]
    end

    addon:SendServerCommand(".playerbots bot add " .. nameList)
end

--- Logout all online bots.
function addon:LogoutAllBots()
    local names = {}
    for botName, info in pairs(addon.botRoster) do
        if info.online then
            names[#names + 1] = botName
        end
    end

    if #names == 0 then
        return
    end

    -- Build comma-separated list
    local nameList = names[1]
    for i = 2, #names do
        nameList = nameList .. "," .. names[i]
    end

    addon:SendServerCommand(".playerbots bot rm " .. nameList)
end

--- Invite a bot to the party
-- @param botName string
function addon:InviteBot(botName)
    local name = botName
    if addon.FormatBotName then
        name = addon.FormatBotName(botName)
    end
    InviteUnit(name)
end

--- Command a bot to leave the group
-- @param botName string
function addon:LeaveBot(botName)
    local name = botName
    if addon.FormatBotName then
        name = addon.FormatBotName(botName)
    end
    addon:SendBotCommand(name, "leave")
end

--- Invite all online bots to the party
function addon:InviteAllBots()
    for botName, info in pairs(addon.botRoster) do
        if info.online then
            InviteUnit(botName)
        end
    end
end

--- Command all bots to leave the group
function addon:LeaveAllBots()
    for botName, info in pairs(addon.botRoster) do
        if info.online and addon:IsBotInGroup(botName) then
            addon:SendBotCommand(botName, "leave")
        end
    end
end

--- Check if a bot is in the current party/raid.
-- Uses GetNumPartyMembers() and UnitName("partyN")
-- @param botName string
-- @return boolean
function addon:IsBotInGroup(botName)
    local numParty = GetNumPartyMembers()
    for i = 1, numParty do
        local name = UnitName("party" .. i)
        if name and name == botName then
            return true
        end
        -- Also check formatted name
        if name and addon.FormatBotName then
            if addon.FormatBotName(name) == addon.FormatBotName(botName) then
                return true
            end
        end
    end
    return false
end

--- Get a table of online bots
-- @return table - array of { name = string, class = string }
function addon:GetOnlineBots()
    local result = {}
    for botName, info in pairs(addon.botRoster) do
        if info.online then
            result[#result + 1] = {
                name = botName,
                class = info.class,
            }
        end
    end
    return result
end

--- Get the English class name for a bot
-- First checks botRoster, then falls back to UnitClass if targetable
-- @param botName string
-- @return string or nil
function addon:GetBotClass(botName)
    -- Check roster first
    if addon.botRoster[botName] then
        local class = addon.botRoster[botName].class
        if class and class ~= "UNKNOWN" then
            return class
        end
    end

    -- Fallback: check if bot is currently targeted
    local targetName = UnitName("target")
    if targetName then
        local checkName = botName
        if addon.FormatBotName then
            checkName = addon.FormatBotName(botName)
            targetName = addon.FormatBotName(targetName)
        end
        if targetName == checkName then
            local _, englishClass = UnitClass("target")
            if englishClass then
                -- Cache the class in the roster
                if addon.botRoster[botName] then
                    addon.botRoster[botName].class = englishClass
                end
                return englishClass
            end
        end
    end

    -- Fallback: check party members
    local numParty = GetNumPartyMembers()
    for i = 1, numParty do
        local name = UnitName("party" .. i)
        if name then
            local checkBotName = botName
            local checkName = name
            if addon.FormatBotName then
                checkBotName = addon.FormatBotName(botName)
                checkName = addon.FormatBotName(name)
            end
            if checkName == checkBotName then
                local _, englishClass = UnitClass("party" .. i)
                if englishClass then
                    -- Cache the class in the roster
                    if addon.botRoster[botName] then
                        addon.botRoster[botName].class = englishClass
                    end
                    return englishClass
                end
            end
        end
    end

    return nil
end

--- Manually add a bot to the known list (persisted in SavedVariables).
-- @param botName string
-- @param class string - English class name (e.g. "WARRIOR")
function addon:AddKnownBot(botName, class)
    local name = botName
    if addon.FormatBotName then
        name = addon.FormatBotName(botName)
    end

    addon.botRoster[name] = {
        class = class or "UNKNOWN",
        online = false,
    }

    -- Persist
    if BotCP_DB and BotCP_DB.knownBots then
        BotCP_DB.knownBots[name] = { class = class or "UNKNOWN" }
    end

    addon:FireCallback("BOTCP_ROSTER_CHANGED")
end

--- Remove a bot from the known list.
-- @param botName string
function addon:RemoveKnownBot(botName)
    local name = botName
    if addon.FormatBotName then
        name = addon.FormatBotName(botName)
    end

    addon.botRoster[name] = nil

    -- Remove from persistence
    if BotCP_DB and BotCP_DB.knownBots then
        BotCP_DB.knownBots[name] = nil
    end

    addon:FireCallback("BOTCP_ROSTER_CHANGED")
end

-- Инициализация модуля
addon:RegisterCallback("BOTCP_LOADED", function()
    -- Load known bots from SavedVariables into the live roster
    if BotCP_DB and BotCP_DB.knownBots then
        for botName, info in pairs(BotCP_DB.knownBots) do
            if not addon.botRoster[botName] then
                addon.botRoster[botName] = {
                    class = info.class or "UNKNOWN",
                    online = false,  -- default to offline until roster refresh confirms
                }
            end
        end
    end

    -- Create event frame for WoW events
    eventFrame = CreateFrame("Frame", "BotCP_BotRosterFrame", UIParent)
    eventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
    eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    eventFrame:SetScript("OnEvent", onEvent)

    -- Register callback for roster data from ResponseParser
    addon:RegisterCallback("BOTCP_ROSTER_RECEIVED", function(rosterData)
        updateRosterFromData(rosterData)
    end)
end)
