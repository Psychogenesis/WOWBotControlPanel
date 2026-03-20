# BotCP -- Architecture Specification

## 1. General Description

**BotCP** (Bot Control Panel) is a WoW 3.3.5a addon providing a graphical UI for managing PlayerBots (mod-playerbots for AzerothCore). Instead of typing chat commands manually, the player uses a visual panel to:

- View a roster of their bots with online/offline status
- Select a bot and control it through toolbar buttons (strategies, formations, loot, movement, etc.)
- Send mass commands to all bots in the party at once
- See real-time visual feedback on every button: what is currently active, what is pending, what is inactive

The critical differentiator of BotCP is its **feedback loop**: after every command, the addon queries the bot's actual state and reflects it on toggle buttons with three visual states (INACTIVE / ACTIVE / PENDING). The player always knows what is happening.

---

## 2. File Structure

```
BotCP/
|-- BotCP.toc                       -- Addon manifest
|-- Core.lua                        -- Addon namespace, event bus, initialization
|-- Libs/
|   |-- Util.lua                    -- Generic utility functions (deep copy, class colors, etc.)
|-- Modules/
|   |-- Constants.lua               -- All constant tables (class strategies, formations, commands, etc.)
|   |-- CommandEngine.lua           -- Send commands to bots, queue, throttle
|   |-- ResponseParser.lua          -- Parse server responses, route to StateManager
|   |-- StateManager.lua            -- Maintain runtime state of each bot (strategies, formation, etc.)
|   |-- BotRoster.lua               -- Manage the list of known bots, online/offline status
|-- UI/
|   |-- Widgets.lua                 -- Reusable UI widget constructors (ToggleButton, ToolbarGroup)
|   |-- MinimapButton.lua           -- Minimap icon to toggle the main panel
|   |-- RosterFrame.lua             -- Bot Roster Panel (list of bots)
|   |-- ControlFrame.lua            -- Bot Control Panel (toolbars for selected bot)
|   |-- ToolbarDefs.lua             -- Toolbar definitions (which buttons go in which toolbar)
|-- images/                         -- Custom .tga icons (class icons, strategy icons, etc.)
```

### .toc File (load order)

```toc
## Interface: 30300
## Title: BotCP - Bot Control Panel
## Notes: UI panel for controlling PlayerBots (mod-playerbots)
## Author: BotCP Team
## Version: 1.0.0
## SavedVariables: BotCP_DB
## SavedVariablesPerCharacter: BotCP_CharDB

# Utilities
Libs\Util.lua

# Core
Core.lua

# Data
Modules\Constants.lua

# Engine
Modules\CommandEngine.lua
Modules\ResponseParser.lua
Modules\StateManager.lua
Modules\BotRoster.lua

# UI
UI\Widgets.lua
UI\MinimapButton.lua
UI\RosterFrame.lua
UI\ToolbarDefs.lua
UI\ControlFrame.lua
```

**Rationale for load order:**
1. `Util.lua` first -- pure utility functions, no dependencies
2. `Core.lua` second -- creates the addon namespace table, event frame, registers events
3. `Constants.lua` -- static data tables, depends only on namespace
4. `CommandEngine.lua` -- depends on Core (event system)
5. `ResponseParser.lua` -- depends on Core and Constants (pattern matching against known strategies)
6. `StateManager.lua` -- depends on Core, Constants
7. `BotRoster.lua` -- depends on Core, CommandEngine, ResponseParser
8. `Widgets.lua` -- UI primitives, depends on Core
9. `MinimapButton.lua` -- depends on Core, Widgets
10. `RosterFrame.lua` -- depends on Core, BotRoster, Widgets
11. `ToolbarDefs.lua` -- toolbar layout data, depends on Constants
12. `ControlFrame.lua` -- depends on everything above

---

## 3. Modules and Components

### 3.1 Core.lua

**Purpose:** Bootstrap the addon. Create the namespace table, provide a simple event bus for inter-module communication, handle `ADDON_LOADED` for SavedVariables initialization, register slash commands.

**Public API (on `addon` table):**

```
addon.version = "1.0.0"
addon.name = "BotCP"

-- Event bus: internal pub/sub for module communication (NOT WoW events)
function addon:RegisterCallback(eventName, handler)
  -- handler: function(self, ...) called when event fires
  -- Returns: nothing

function addon:UnregisterCallback(eventName, handler)
  -- Remove a previously registered handler

function addon:FireCallback(eventName, ...)
  -- Invoke all handlers registered for eventName with given args

-- Slash command handler
function addon:HandleSlashCommand(msg)
  -- Parse msg, dispatch: "show", "hide", "toggle", "roster", "help"
```

**Internal State:**

```lua
local callbacks = {}     -- { [eventName] = { handler1, handler2, ... } }
local eventFrame         -- Frame registered for WoW events
```

**WoW Events Registered:**
- `ADDON_LOADED` -- initialize SavedVariables, fire `"BOTCP_LOADED"` callback
- `PLAYER_LOGIN` -- fire `"BOTCP_PLAYER_LOGIN"` callback
- `PLAYER_LOGOUT` -- fire `"BOTCP_PLAYER_LOGOUT"` callback

**Callback Events (internal bus):**
- `"BOTCP_LOADED"` -- addon is fully loaded, saved vars available
- `"BOTCP_PLAYER_LOGIN"` -- player logged in, safe to use all APIs
- `"BOTCP_PLAYER_LOGOUT"` -- player logging out

**SavedVariables Initialization:**

```lua
-- Defaults:
local DB_DEFAULTS = {
    minimapButton = { position = 195 },   -- angle on minimap
    rosterPosition = nil,                  -- { point, x, y } or nil for default
    controlPosition = nil,                 -- { point, x, y } or nil for default
    knownBots = {},                        -- { ["BotName"] = { class = "WARRIOR" }, ... }
    autoQueryOnTarget = true,              -- auto-query bot state on target change
    commandThrottle = 0.3,                 -- seconds between commands
    pendingTimeout = 3.0,                  -- seconds before pending state resets
}

local CHARDB_DEFAULTS = {
    rosterVisible = false,
    controlVisible = false,
    lastSelectedBot = nil,
}
```

**Slash Commands:**
- `/botcp` or `/bcp` -- toggle roster panel
- `/botcp show` -- show roster
- `/botcp hide` -- hide all panels
- `/botcp help` -- print usage

**Dependencies:** None (first module loaded after Util).

---

### 3.2 Libs/Util.lua

**Purpose:** Pure utility functions with no addon-specific logic.

**Public API (on `addon` table):**

```
function addon.DeepCopy(src)
  -- Deep copy table. Returns: new table.

function addon.MergeDefaults(target, defaults)
  -- For each key in defaults, if target[key] is nil, set target[key] = defaults[key]
  -- Recurse into sub-tables. Returns: target (modified in place).

function addon.ClassColor(englishClass)
  -- Returns r, g, b (0-1 floats) for the given class name ("WARRIOR", "PALADIN", etc.)
  -- Uses RAID_CLASS_COLORS global table available in 3.3.5a.

function addon.ClassIconCoords(englishClass)
  -- Returns left, right, top, bottom texcoords for class icon in
  -- "Interface\\GLUES\\CHARACTERCREATE\\UI-CharacterCreate-Classes"
  -- Uses CLASS_ICON_TCOORDS global.

function addon.TrimString(s)
  -- Remove leading/trailing whitespace. Returns: trimmed string.

function addon.SplitString(s, delimiter)
  -- Split string by delimiter. Returns: table of substrings.

function addon.TableContains(tbl, value)
  -- Returns: boolean.

function addon.FormatBotName(name)
  -- Capitalize first letter, lowercase rest. Returns: formatted string.
```

**Dependencies:** None.

---

### 3.3 Modules/Constants.lua

**Purpose:** All static data tables. Class strategy mappings, formation options, loot options, RTI options, command templates. No logic, only data.

**Public API (on `addon` table):**

```lua
addon.CLASS_STRATEGIES = {
    DRUID   = { "bear", "cat", "caster", "heal" },
    HUNTER  = { "dps", "bspeed", "bmana", "bdps" },
    MAGE    = { "arcane", "fire", "fire aoe", "frost", "frost aoe", "bmana", "bdps" },
    PALADIN = { "dps", "tank", "bmana", "bhealth", "bdps", "barmor", "bspeed", "bthreat" },
    PRIEST  = { "heal", "holy", "shadow", "shadow debuff", "shadow aoe" },
    ROGUE   = { "dps", "behind" },
    SHAMAN  = { "heal", "caster", "caster aoe", "bmana", "bdps", "totems" },
    WARLOCK = { "shadow", "shadow debuff", "shadow aoe", "pet", "rshadow" },
    WARRIOR = { "tank", "tank aoe", "dps", "aoe" },
    DEATHKNIGHT = { "blood", "frost", "unholy" },
}

addon.FORMATIONS = {
    -- { id = "near", label = "Near", icon = "images\\formation_near" },
    { id = "near",   label = "Near" },
    { id = "melee",  label = "Melee" },
    { id = "line",   label = "Line" },
    { id = "circle", label = "Circle" },
    { id = "arrow",  label = "Arrow" },
    { id = "far",    label = "Far" },
    { id = "chaos",  label = "Chaos" },
}

addon.LOOT_STRATEGIES = {
    { id = "normal",      label = "Normal" },
    { id = "all",         label = "All" },
    { id = "gray",        label = "Gray" },
    { id = "disenchant",  label = "Disenchant" },
    { id = "skill",       label = "Skill" },
}

addon.RTI_TARGETS = {
    { id = "skull",    label = "Skull",    icon = "Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_8" },
    { id = "cross",    label = "Cross",    icon = "Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_7" },
    { id = "circle",   label = "Circle",   icon = "Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_2" },
    { id = "star",     label = "Star",     icon = "Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_1" },
    { id = "square",   label = "Square",   icon = "Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_6" },
    { id = "triangle", label = "Triangle", icon = "Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_3" },
    { id = "diamond",  label = "Diamond",  icon = "Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_4" },
    { id = "moon",     label = "Moon",     icon = "Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_5" },
}

addon.MOVEMENT_COMMANDS = {
    { id = "follow",  label = "Follow",  isAction = true },
    { id = "stay",    label = "Stay",    isAction = true },
    { id = "guard",   label = "Guard",   isAction = true },
    { id = "grind",   label = "Grind",   isAction = true },
    { id = "passive", label = "Passive", isStrategy = true, channel = "nc" },
    { id = "flee",    label = "Flee",    isAction = true },
}

addon.ACTION_COMMANDS = {
    { id = "attack",      label = "Attack",      isAction = true },
    { id = "tank attack", label = "Tank Attack",  isAction = true },
    { id = "stats",       label = "Stats",        isAction = true },
    { id = "revive",      label = "Revive",       isAction = true },
    { id = "release",     label = "Release",      isAction = true },
    { id = "summon",      label = "Summon",       isAction = true },
}

addon.GENERIC_STRATEGIES = {
    { id = "potions",       label = "Potions",       channel = "nc" },
    { id = "food",          label = "Food",          channel = "nc" },
    { id = "cast time",     label = "Cast Time",     channel = "co" },
    { id = "conserve mana", label = "Conserve Mana", channel = "co" },
    { id = "buff",          label = "Buff",          channel = "nc" },
    { id = "attack weak",   label = "Attack Weak",   channel = "co" },
    { id = "threat",        label = "Threat",        channel = "co" },
}

addon.ATTACK_TYPE_STRATEGIES = {
    { id = "tank aoe",    label = "Tank AOE",    channel = "co" },
    { id = "tank assist", label = "Tank Assist",  channel = "co" },
    { id = "dps assist",  label = "DPS Assist",   channel = "co" },
    { id = "caster aoe",  label = "Caster AOE",   channel = "co" },
}

addon.SAVE_MANA_LEVELS = { 1, 2, 3, 4, 5 }

-- Class name to English class constant mapping (for UnitClass second return)
addon.CLASS_NAMES = {
    ["Warrior"]      = "WARRIOR",
    ["Paladin"]      = "PALADIN",
    ["Hunter"]       = "HUNTER",
    ["Rogue"]        = "ROGUE",
    ["Priest"]       = "PRIEST",
    ["Death Knight"] = "DEATHKNIGHT",
    ["Shaman"]       = "SHAMAN",
    ["Mage"]         = "MAGE",
    ["Warlock"]      = "WARLOCK",
    ["Druid"]        = "DRUID",
}
```

**Dependencies:** Core.lua (for addon namespace).

---

### 3.4 Modules/CommandEngine.lua

**Purpose:** Send chat commands to the server. Implements a command queue with throttling to avoid flooding. Tracks pending commands and fires callbacks when a command is sent.

**Public API:**

```
function addon:SendBotCommand(botName, command, queryAfter)
  -- Send a whisper command to a specific bot.
  -- botName: string -- name of the bot
  -- command: string -- the command text, e.g. "co +tank", "formation near"
  -- queryAfter: boolean (optional) -- if true, automatically append a query
  --   e.g., if command is "co +tank", sends "co +tank,?" to get state back
  -- Returns: requestId (number) -- unique ID for tracking this command

function addon:SendPartyCommand(command)
  -- Send a command to all bots via PARTY chat.
  -- command: string -- e.g. "follow", "co +tank"
  -- Returns: requestId (number)

function addon:SendServerCommand(command)
  -- Send a dot-command to the server via SAY chat.
  -- command: string -- e.g. ".playerbots bot add BotName"
  -- Returns: requestId (number)

function addon:CancelPending(requestId)
  -- Remove a command from the pending queue (e.g., on timeout).
```

**Internal State:**

```lua
local commandQueue = {}       -- { { type, target, text, requestId, timestamp }, ... }
local nextRequestId = 1       -- auto-incrementing ID
local lastSendTime = 0        -- GetTime() of last sent command
local THROTTLE_INTERVAL       -- from addon settings, default 0.3s
local timerFrame              -- OnUpdate frame for queue processing
```

**Callback Events Fired:**
- `"BOTCP_COMMAND_SENT"` (requestId, botName, command) -- command was sent
- `"BOTCP_COMMAND_QUEUED"` (requestId, botName, command) -- command is waiting in queue

**OnUpdate Logic:**
- Every frame, check if `GetTime() - lastSendTime >= THROTTLE_INTERVAL`
- If yes and queue not empty, pop first command, send it via appropriate `SendChatMessage`, fire `"BOTCP_COMMAND_SENT"`

**Dependencies:** Core.lua

---

### 3.5 Modules/ResponseParser.lua

**Purpose:** Listen to `CHAT_MSG_SYSTEM` and `CHAT_MSG_WHISPER`, match responses against known patterns, extract structured data, and fire callbacks.

**Public API:**

```
function addon:RegisterResponseHandler(pattern, handler)
  -- Register a handler for a specific response pattern.
  -- pattern: string -- Lua pattern to match against message text
  -- handler: function(message, sender, captures...) -- called on match
  -- Returns: handlerId (number)

function addon:UnregisterResponseHandler(handlerId)
  -- Remove a response handler.
```

**Internal State:**

```lua
local handlers = {}           -- { [id] = { pattern, handler }, ... }
local nextHandlerId = 1
local eventFrame              -- registered for CHAT_MSG_SYSTEM, CHAT_MSG_WHISPER
```

**WoW Events Registered:**
- `CHAT_MSG_SYSTEM` -- server responses to dot-commands (roster list, errors)
- `CHAT_MSG_WHISPER` -- bot responses to whisper commands (strategy queries, etc.)

**CHAT_MSG_WHISPER handler detail:**
In WoW 3.3.5a, `CHAT_MSG_WHISPER` fires as `(message, sender, language, channelString, target, flags, ...)`. The `sender` is the bot's name. The parser checks if `sender` is a known bot (via BotRoster) and then matches `message` against registered patterns.

**Predefined patterns registered during init (by StateManager, see below).**

**Callback Events Fired:**
- `"BOTCP_ROSTER_RECEIVED"` (rosterData) -- parsed bot roster
- `"BOTCP_STRATEGIES_RECEIVED"` (botName, channel, strategiesList) -- parsed strategy list
- `"BOTCP_FORMATION_RECEIVED"` (botName, formation) -- parsed formation
- `"BOTCP_LOOT_RECEIVED"` (botName, lootStrategy) -- parsed loot strategy
- `"BOTCP_RTI_RECEIVED"` (botName, rtiTarget) -- parsed RTI

**Dependencies:** Core.lua, BotRoster.lua (to check if sender is a known bot).

Note on dependency: ResponseParser needs to know if a whisper sender is a bot. To avoid a circular dependency, ResponseParser checks `addon.botRoster` (a table populated by BotRoster module). ResponseParser does NOT call any BotRoster functions during init -- it only reads `addon.botRoster` at runtime. This means BotRoster must populate `addon.botRoster` before any whispers are processed (which is guaranteed since roster must be fetched before commands).

---

### 3.6 Modules/StateManager.lua

**Purpose:** Maintain the runtime state of each bot -- which strategies are active, current formation, loot strategy, RTI, pending states for buttons. This is the single source of truth for the UI.

**Public API:**

```
function addon:GetBotState(botName)
  -- Returns: table or nil
  -- {
  --   coStrategies = { ["tank"] = true, ["dps"] = true, ... },    -- combat strategies
  --   ncStrategies = { ["food"] = true, ["potions"] = true, ... }, -- non-combat strategies
  --   formation = "near",                                          -- current formation string
  --   lootStrategy = "normal",                                     -- current loot strategy
  --   rti = "skull",                                               -- current RTI
  --   pending = {                                                  -- pending states by category
  --     ["co:tank"] = { requestId = 5, timestamp = 123.4, previousValue = false },
  --     ["formation"] = { requestId = 7, timestamp = 125.0, previousValue = "melee" },
  --   },
  -- }

function addon:SetPendingState(botName, stateKey, requestId, previousValue)
  -- Mark a state key as pending (waiting for server response).
  -- stateKey: string -- e.g. "co:tank", "formation", "loot", "rti"
  -- requestId: number -- from CommandEngine
  -- previousValue: any -- value before the command was sent

function addon:ClearPendingState(botName, stateKey)
  -- Remove pending state (called when response received or timeout).

function addon:IsPending(botName, stateKey)
  -- Returns: boolean

function addon:IsStrategyActive(botName, channel, strategyName)
  -- channel: "co" or "nc"
  -- Returns: boolean or nil (nil if state unknown/never queried)

function addon:IsFormation(botName, formationId)
  -- Returns: boolean or nil

function addon:IsLootStrategy(botName, lootId)
  -- Returns: boolean or nil

function addon:GetRTI(botName)
  -- Returns: string or nil

function addon:QueryBotState(botName)
  -- Send all query commands to refresh bot state.
  -- Sends: "co ?", "nc ?", "formation ?", "ll ?", "rti ?"
  -- Each via addon:SendBotCommand(botName, cmd)

function addon:QueryAllBotsState()
  -- Call QueryBotState for each online bot.

function addon:GetButtonState(botName, stateKey)
  -- Convenience function for UI.
  -- Returns: "ACTIVE", "INACTIVE", "PENDING", or "UNKNOWN"
  -- Logic:
  --   if IsPending(botName, stateKey) then return "PENDING"
  --   if state is true/matches then return "ACTIVE"
  --   if state is false/doesn't match then return "INACTIVE"
  --   if state is nil (never queried) then return "UNKNOWN"
```

**Internal State:**

```lua
local botStates = {}          -- { ["BotName"] = { coStrategies={}, ncStrategies={}, ... }, ... }
local PENDING_TIMEOUT         -- from addon settings, default 3.0s
local timeoutFrame            -- OnUpdate frame to check for expired pending states
```

**OnUpdate Logic (timeout checker):**
- Every 0.5 seconds (throttled), iterate all bots' pending states
- If `GetTime() - pending.timestamp > PENDING_TIMEOUT`, clear pending, restore `previousValue`, fire `"BOTCP_STATE_CHANGED"`

**Callback Events Listened To:**
- `"BOTCP_STRATEGIES_RECEIVED"` (botName, channel, strategies) -- update coStrategies or ncStrategies, clear relevant pending, fire `"BOTCP_STATE_CHANGED"`
- `"BOTCP_FORMATION_RECEIVED"` (botName, formation) -- update formation, clear pending
- `"BOTCP_LOOT_RECEIVED"` (botName, loot) -- update lootStrategy, clear pending
- `"BOTCP_RTI_RECEIVED"` (botName, rti) -- update rti, clear pending

**Callback Events Fired:**
- `"BOTCP_STATE_CHANGED"` (botName, stateKey, newValue) -- UI listens to this to refresh buttons

**Response pattern registration:**
StateManager registers patterns with ResponseParser during init:

| Pattern (Lua) | Matches | Callback |
|---|---|---|
| `"^Strategies: (.+)$"` | "Strategies: tank, dps, ..." | Determine co/nc from context (last query sent) |
| `"^Formation: (%w+)$"` | "Formation: near" | `BOTCP_FORMATION_RECEIVED` |
| `"^Loot strategy: (%w+)$"` | "Loot strategy: normal" | `BOTCP_LOOT_RECEIVED` |
| `"^RTI: (%w+)$"` | "RTI: skull" | `BOTCP_RTI_RECEIVED` |

**Strategy response disambiguation:**
The response "Strategies: ..." is the same for both `co ?` and `nc ?`. To disambiguate, StateManager tracks which query was last sent to each bot:

```lua
local lastQueryType = {}  -- { ["BotName"] = "co" or "nc" }
```

Before sending `co ?`, set `lastQueryType[botName] = "co"`. When the response arrives from that bot, use `lastQueryType[botName]` to determine which set to update. Then shift to the next query type. To ensure reliability, StateManager sends `co ?` first, then `nc ?` sequentially (not simultaneously), using a per-bot query queue.

**Per-bot query queue:**

```lua
local queryQueue = {}  -- { ["BotName"] = { "co ?", "nc ?", "formation ?", "ll ?", "rti ?" } }
```

When `QueryBotState(botName)` is called:
1. Populate `queryQueue[botName]` with all 5 query commands
2. Send the first one
3. When response is received and processed, pop it and send the next one
4. This ensures disambiguation of "Strategies:" responses and prevents flooding

**Dependencies:** Core.lua, Constants.lua, CommandEngine.lua, ResponseParser.lua

---

### 3.7 Modules/BotRoster.lua

**Purpose:** Manage the list of known bots, their class, online/offline status. Provide functions to add/remove/login/logout bots.

**Public API:**

```
addon.botRoster = {}  -- { ["BotName"] = { class = "WARRIOR", online = true/false }, ... }

function addon:RefreshRoster()
  -- Send ".playerbots bot list" command.
  -- Response will be parsed by ResponseParser and update botRoster.

function addon:LoginBot(botName)
  -- Send ".playerbots bot add <botName>"

function addon:LogoutBot(botName)
  -- Send ".playerbots bot rm <botName>"

function addon:LoginAllBots()
  -- Login all known bots that are offline.
  -- Builds comma-separated list: ".playerbots bot add name1,name2,name3"

function addon:LogoutAllBots()
  -- Logout all online bots.

function addon:InviteBot(botName)
  -- Send "/invite BotName" via SendChatMessage or InviteUnit(botName)
  -- Note: InviteUnit() exists in 3.3.5a and is the proper API.

function addon:LeaveBot(botName)
  -- Send "leave" whisper command to the bot.

function addon:InviteAllBots()
  -- Invite all online bots.

function addon:LeaveAllBots()
  -- Command all bots to leave group.

function addon:IsBotInGroup(botName)
  -- Check if botName is in the current party/raid.
  -- Uses GetNumPartyMembers(), UnitName("party"..i)
  -- Returns: boolean

function addon:GetOnlineBots()
  -- Returns: table of { name, class } for online bots.

function addon:GetBotClass(botName)
  -- Returns: string (English class name) or nil.
  -- First checks botRoster table, then falls back to UnitClass if bot is targetable.

function addon:AddKnownBot(botName, class)
  -- Manually add a bot to the known list (persisted in SavedVariables).

function addon:RemoveKnownBot(botName)
  -- Remove a bot from the known list.
```

**Internal State:**

```lua
-- addon.botRoster is the live roster (see above)
-- BotCP_DB.knownBots is the persisted list (populated from SavedVariables)
```

**Roster Response Parsing:**
The `.playerbots bot list` response format from CHAT_MSG_SYSTEM:
```
Bot added: +BotName1 Warrior, +BotName2 Paladin
```
or
```
Bot removed: -BotName1
```
or a roster listing (depends on server version):
```
+BotName1 Warrior, -BotName2 Paladin
```

Pattern: Iterate through comma-separated segments, each matching `([%+%-])(%S+)%s+(%S+)`:
- `+` = online, `-` = offline
- Second capture = bot name
- Third capture = class name (localized)

If the server response format differs, the parser should also handle:
- `"Bot added: (.+)"` -- single bot added confirmation
- `"Bot removed: (.+)"` -- single bot removed confirmation

**Callback Events Listened To:**
- `"BOTCP_ROSTER_RECEIVED"` (rosterData) -- update botRoster table
- `"BOTCP_LOADED"` -- merge knownBots from SavedVariables into botRoster

**Callback Events Fired:**
- `"BOTCP_ROSTER_CHANGED"` () -- roster updated, UI should refresh

**WoW Events Registered:**
- `PARTY_MEMBERS_CHANGED` -- re-check which bots are in the group
- `PLAYER_TARGET_CHANGED` -- if target is a bot, fire `"BOTCP_BOT_TARGETED"` (botName)

**Dependencies:** Core.lua, CommandEngine.lua

---

### 3.8 UI/Widgets.lua

**Purpose:** Reusable widget constructors. The addon uses two custom widget types: **ToggleButton** (for strategy/formation/loot toggles with 3-state feedback) and **ToolbarGroup** (a horizontal strip of ToggleButtons with a label).

#### 3.8.1 ToggleButton

**Constructor:**
```
function addon.CreateToggleButton(parent, config)
  -- config = {
  --   name     = "BotCP_CoTank",          -- global frame name (optional)
  --   size     = { 32, 32 },              -- width, height
  --   icon     = "Interface\\Icons\\...", -- icon texture path (optional, text if nil)
  --   label    = "Tank",                  -- text label (shown if no icon, also tooltip)
  --   tooltip  = "Toggle tank strategy",  -- tooltip text
  --   stateKey = "co:tank",               -- key for StateManager lookup
  -- }
  -- Returns: Frame (the toggle button)
```

**Visual Structure of a ToggleButton:**

```
Frame "BotCP_CoTank" (32x32)
  |-- Texture "icon"       -- the main icon (32x32, centered)
  |-- Texture "border"     -- colored border overlay indicating state
  |-- Texture "highlight"  -- mouseover highlight
  |-- Texture "pending"    -- pulsing yellow overlay for PENDING state
  |-- FontString "label"   -- text label (below the icon, optional)
```

**State Rendering:**

| State | Border Color | Icon Desaturation | Pending Overlay |
|-------|-------------|-------------------|-----------------|
| ACTIVE | Green (0, 0.8, 0, 0.8) | false (full color) | hidden |
| INACTIVE | Gray (0.4, 0.4, 0.4, 0.5) | true (desaturated) | hidden |
| PENDING | Yellow (1, 0.8, 0, 0.8) | false | shown + alpha pulse |
| UNKNOWN | Dark (0.3, 0.3, 0.3, 0.3) | true | hidden |

**Methods on ToggleButton:**

```
button:SetState(state)
  -- state: "ACTIVE", "INACTIVE", "PENDING", "UNKNOWN"
  -- Updates visuals accordingly.

button:GetState()
  -- Returns: current state string.

button:SetOnClick(handler)
  -- handler: function(self, state) called on click.

button:UpdateFromStateManager(botName)
  -- Read state from addon:GetButtonState(botName, self.stateKey) and call SetState.

button:StartPendingAnimation()
  -- Start alpha pulse on pending overlay using OnUpdate.

button:StopPendingAnimation()
  -- Stop the pulse, hide overlay.
```

**Pending Animation:** Uses an OnUpdate script on the `pending` texture frame. Oscillates alpha between 0.3 and 1.0 over 0.8 seconds using `sin(elapsed * 4)`.

**Behavior:**
- `OnClick`: Call the registered handler. The handler (set by ControlFrame) will send the command and set pending state.
- `OnEnter`: Show GameTooltip with `config.tooltip` and current state info.
- `OnLeave`: Hide GameTooltip.

#### 3.8.2 ToolbarGroup

**Constructor:**
```
function addon.CreateToolbarGroup(parent, config)
  -- config = {
  --   name       = "BotCP_CombatToolbar",
  --   label      = "Combat Strategies",
  --   buttons    = { ... },              -- array of ToggleButton configs
  --   columns    = 8,                    -- max buttons per row before wrapping
  --   buttonSize = { 32, 32 },           -- size for each button
  --   spacing    = 4,                    -- gap between buttons
  --   hasReset   = true,                 -- show a "Reset" button at the end
  -- }
  -- Returns: Frame (the toolbar group)
```

**Visual Structure:**

```
Frame "BotCP_CombatToolbar"
  |-- FontString "title"              -- toolbar label, top-left
  |-- Frame "buttonContainer"         -- holds all toggle buttons
  |   |-- ToggleButton 1
  |   |-- ToggleButton 2
  |   |-- ...
  |   |-- Button "reset" (UIPanelButtonTemplate, text "R", 20x20) -- if hasReset
```

**Layout:** Buttons are arranged left-to-right, wrapping to the next row after `columns` buttons. Each button is positioned relative to the previous one:
- First button: `SetPoint("TOPLEFT", buttonContainer, "TOPLEFT", 0, 0)`
- Subsequent: `SetPoint("LEFT", previousButton, "RIGHT", spacing, 0)`
- After wrapping: `SetPoint("TOPLEFT", firstButtonInPrevRow, "BOTTOMLEFT", 0, -spacing)`

The group frame auto-sizes its height based on the number of rows.

**Methods:**

```
toolbar:UpdateAllButtons(botName)
  -- Call UpdateFromStateManager on each ToggleButton.

toolbar:GetButtons()
  -- Returns: table of ToggleButton references.
```

**Dependencies:** Core.lua

---

### 3.9 UI/MinimapButton.lua

**Purpose:** Draggable button on the minimap to toggle the Roster panel.

**Visual Structure:**

```
Button "BotCP_MinimapButton" (31x31)
  parent: Minimap
  |-- Texture "icon"     -- "Interface\\Icons\\Ability_Warrior_BattleShout" (or custom)
  |-- Texture "border"   -- "Interface\\Minimap\\MiniMap-TrackingBorder"
  |-- Texture "highlight" -- "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight"
```

**Positioning:** Circle-locked to the Minimap edge using the stored angle from `BotCP_DB.minimapButton.position`. Classic minimap button math:
```lua
local angle = math.rad(BotCP_DB.minimapButton.position)
local x = math.cos(angle) * 80  -- 80 = minimap radius
local y = math.sin(angle) * 80
button:SetPoint("CENTER", Minimap, "CENTER", x, y)
```

**Behavior:**
- `OnClick`: Call `addon:ToggleRoster()`
- `OnDragStart/OnDragStop`: Allow dragging around the minimap edge; update angle in SavedVariables.
- `OnEnter`: Tooltip "BotCP - Bot Control Panel\nClick to toggle\nDrag to move"
- `OnLeave`: Hide tooltip

**Dependencies:** Core.lua

---

### 3.10 UI/RosterFrame.lua

**Purpose:** The main bot list panel. Shows all known bots with their status and provides mass action buttons.

**Visual Structure:**

```
Frame "BotCP_RosterFrame" (260 x 400)
  parent: UIParent
  frameStrata: "MEDIUM"
  backdrop: UI-DialogBox-Background + UI-DialogBox-Border
  movable: true (OnDragStart/Stop, save position to BotCP_DB.rosterPosition)
  |
  |-- Texture "header"    -- "Interface\\DialogFrame\\UI-DialogBox-Header" (centered top)
  |-- FontString "title"  -- "BotCP - Bot Roster" on the header
  |-- Button "closeBtn"   -- "UIPanelCloseButton", TOPRIGHT corner
  |
  |-- Frame "massActions" (anchored TOPLEFT, below header, 240 x 30)
  |   |-- Button "loginAll"   (UIPanelButtonTemplate, 55x22, "Login All")
  |   |-- Button "logoutAll"  (UIPanelButtonTemplate, 55x22, "Logout All")
  |   |-- Button "inviteAll"  (UIPanelButtonTemplate, 55x22, "Invite All")
  |   |-- Button "refreshBtn" (UIPanelButtonTemplate, 55x22, "Refresh")
  |
  |-- ScrollFrame "scrollFrame" (UIPanelScrollFrameTemplate)
  |   anchored: TOPLEFT of frame, below massActions, with insets
  |   size: 240 x 310
  |   |-- Frame "scrollChild" (240 x dynamic)
  |       |-- BotRow 1 (see below)
  |       |-- BotRow 2
  |       |-- ...
  |
  |-- Frame "statusBar" (anchored BOTTOMLEFT, 240 x 20)
  |   |-- FontString "statusText" -- "3/5 online"
```

**BotRow (per-bot entry in the scroll list):**

```
Frame "BotCP_BotRow_<Name>" (232 x 36)
  backdrop: slight background tint
  |
  |-- Texture "classIcon" (24x24, TOPLEFT+6,0)
  |   texcoords from addon.ClassIconCoords, texture "Interface\\GLUES\\CHARACTERCREATE\\UI-CharacterCreate-Classes"
  |
  |-- FontString "nameText" (LEFT of classIcon+4, 0)
  |   text: bot name
  |   color: class color from RAID_CLASS_COLORS
  |
  |-- Texture "statusIndicator" (10x10, RIGHT-6, 0)
  |   color: green = online, red = offline
  |
  |-- Button "loginBtn"  (small, 40x18, text "Login"/"Logout", RIGHT-side)
  |-- Button "inviteBtn" (small, 40x18, text "Invite"/"Leave", RIGHT of loginBtn)
```

**Behavior:**
- Clicking a BotRow (not on buttons) selects that bot and opens the ControlFrame for it.
- Selected row gets a highlighted background.
- `loginBtn` text changes based on online status: "Login" if offline, "Logout" if online.
- `inviteBtn` text changes: "Invite" if not in group, "Leave" if in group.
- Mass buttons operate on all known bots.
- `refreshBtn` calls `addon:RefreshRoster()`.

**Public API:**

```
function addon:ToggleRoster()
function addon:ShowRoster()
function addon:HideRoster()
function addon:RefreshRosterUI()   -- rebuild scroll child rows from botRoster data
function addon:SelectBot(botName)  -- highlight row, open ControlFrame, query state
```

**Callback Events Listened To:**
- `"BOTCP_ROSTER_CHANGED"` -- rebuild the list
- `"BOTCP_BOT_TARGETED"` (botName) -- auto-select if autoQueryOnTarget is true

**Dependencies:** Core.lua, Widgets.lua, BotRoster.lua, StateManager.lua

---

### 3.11 UI/ToolbarDefs.lua

**Purpose:** Define the toolbar layouts -- which buttons appear in which toolbar, their stateKeys, commands, and labels. This is pure data consumed by ControlFrame.

**Public API:**

```lua
addon.TOOLBAR_DEFS = {
    {
        id = "movement",
        label = "Movement",
        columns = 8,
        buttonSize = { 32, 32 },
        hasReset = false,
        buttons = {
            {
                id = "follow",
                label = "Follow",
                tooltip = "Bot follows you",
                stateKey = nil,  -- action commands don't have toggle state
                commandType = "action",  -- sends as direct whisper, not a strategy toggle
                command = "follow",
                icon = "Interface\\Icons\\Ability_Tracking",
            },
            {
                id = "stay",
                label = "Stay",
                tooltip = "Bot stays in place",
                stateKey = nil,
                commandType = "action",
                command = "stay",
                icon = "Interface\\Icons\\Spell_Nature_TimeStop",
            },
            {
                id = "guard",
                label = "Guard",
                tooltip = "Bot guards current position",
                stateKey = nil,
                commandType = "action",
                command = "guard",
                icon = "Interface\\Icons\\Ability_Defend",
            },
            {
                id = "grind",
                label = "Grind",
                tooltip = "Bot grinds nearby mobs",
                stateKey = nil,
                commandType = "action",
                command = "grind",
                icon = "Interface\\Icons\\Ability_DualWield",
            },
            {
                id = "flee",
                label = "Flee",
                tooltip = "Bot flees from combat",
                stateKey = nil,
                commandType = "action",
                command = "flee",
                icon = "Interface\\Icons\\Ability_Rogue_Sprint",
            },
            {
                id = "passive",
                label = "Passive",
                tooltip = "Toggle passive mode (non-combat strategy)",
                stateKey = "nc:passive",
                commandType = "strategy",
                channel = "nc",
                strategyName = "passive",
                icon = "Interface\\Icons\\Spell_Nature_Sentinal",
            },
        },
    },
    {
        id = "actions",
        label = "Actions",
        columns = 8,
        buttonSize = { 32, 32 },
        hasReset = false,
        buttons = {
            {
                id = "attack", label = "Attack", tooltip = "Attack your target",
                commandType = "action", command = "attack",
                icon = "Interface\\Icons\\Ability_SteelMelee",
            },
            {
                id = "tank_attack", label = "Tank Attack", tooltip = "Tank attacks your target",
                commandType = "action", command = "tank attack",
                icon = "Interface\\Icons\\Ability_Warrior_DefensiveStance",
            },
            {
                id = "stats", label = "Stats", tooltip = "Show bot statistics",
                commandType = "action", command = "stats",
                icon = "Interface\\Icons\\INV_Misc_Note_01",
            },
            {
                id = "summon", label = "Summon", tooltip = "Summon bot to you",
                commandType = "action", command = "summon",
                icon = "Interface\\Icons\\Spell_Shadow_Twilight",
            },
            {
                id = "revive", label = "Revive", tooltip = "Resurrect at Spirit Healer",
                commandType = "action", command = "revive",
                icon = "Interface\\Icons\\Spell_Holy_Resurrection",
            },
            {
                id = "release", label = "Release", tooltip = "Release spirit",
                commandType = "action", command = "release",
                icon = "Interface\\Icons\\Spell_Holy_GuardianSpirit",
            },
        },
    },
    {
        id = "formation",
        label = "Formation",
        columns = 8,
        buttonSize = { 32, 32 },
        hasReset = true,
        exclusive = true,  -- only one can be active at a time
        buttons = {
            -- Generated from addon.FORMATIONS
            -- Each button:
            -- {
            --   id = "near", label = "Near", tooltip = "Formation: Near",
            --   stateKey = "formation:near",
            --   commandType = "formation",
            --   command = "formation near",
            --   icon = (custom or default)
            -- }
        },
    },
    {
        id = "loot",
        label = "Loot Strategy",
        columns = 8,
        buttonSize = { 32, 32 },
        hasReset = false,
        exclusive = true,
        buttons = {
            -- Generated from addon.LOOT_STRATEGIES
            -- stateKey = "loot:normal", command = "ll normal", etc.
        },
    },
    {
        id = "rti",
        label = "RTI Target",
        columns = 8,
        buttonSize = { 32, 32 },
        hasReset = false,
        exclusive = true,
        buttons = {
            -- Generated from addon.RTI_TARGETS
            -- stateKey = "rti:skull", command = "rti skull", etc.
            -- icon from RTI_TARGETS[i].icon
        },
    },
    {
        id = "attack_type",
        label = "Attack Type",
        columns = 8,
        buttonSize = { 32, 32 },
        hasReset = true,
        buttons = {
            -- Generated from addon.ATTACK_TYPE_STRATEGIES
            -- stateKey = "co:tank aoe", commandType = "strategy", channel = "co"
        },
    },
    {
        id = "generic",
        label = "Generic",
        columns = 8,
        buttonSize = { 32, 32 },
        hasReset = true,
        buttons = {
            -- Generated from addon.GENERIC_STRATEGIES
            -- Each has its own channel (co or nc)
        },
    },
    {
        id = "save_mana",
        label = "Save Mana",
        columns = 5,
        buttonSize = { 32, 32 },
        hasReset = true,
        exclusive = true,  -- only one level active
        buttons = {
            -- { id = "save_mana_1", label = "1", stateKey = "co:save mana 1", ... }
            -- through level 5
        },
    },
    {
        id = "class_specific",
        label = "Class",  -- dynamically updated to "Class (Warrior)" etc.
        columns = 8,
        buttonSize = { 32, 32 },
        hasReset = true,
        dynamic = true,  -- buttons are populated based on selected bot's class
        buttons = {},    -- filled at runtime
    },
}
```

Note: Toolbars marked with `exclusive = true` have radio-button behavior -- activating one deactivates others in the same group. The UI handles this by checking the `exclusive` flag and sending the appropriate command (formation/loot/rti commands inherently replace the previous value; for exclusive strategy groups, the UI sends `-oldStrategy,+newStrategy`).

**Dependencies:** Constants.lua

---

### 3.12 UI/ControlFrame.lua

**Purpose:** The main bot control panel. Shows toolbars of toggle buttons for the currently selected bot. Responds to state changes and updates button visuals.

**Visual Structure:**

```
Frame "BotCP_ControlFrame" (380 x 520)
  parent: UIParent
  frameStrata: "MEDIUM"
  backdrop: UI-DialogBox-Background + UI-DialogBox-Border
  movable: true
  |
  |-- Texture "header"
  |-- FontString "title"  -- "BotCP - <BotName>" (dynamically updated)
  |-- Button "closeBtn"   -- UIPanelCloseButton
  |
  |-- Texture "classIcon" (24x24, LEFT of title) -- class icon of selected bot
  |
  |-- CheckButton "partyMode" (UICheckButtonTemplate, below header)
  |   text: "Party Mode (send to all)"
  |   When checked, all commands are sent via PARTY chat instead of WHISPER.
  |
  |-- ScrollFrame "scrollFrame" (UIPanelScrollFrameTemplate, 360 x 440)
  |   |-- Frame "scrollChild" (360 x dynamic)
  |       |-- ToolbarGroup "movement"      (TOPLEFT, 0, 0)
  |       |-- ToolbarGroup "actions"       (below movement, gap 8px)
  |       |-- ToolbarGroup "formation"     (below actions, gap 8px)
  |       |-- ToolbarGroup "loot"          (below formation, gap 8px)
  |       |-- ToolbarGroup "rti"           (below loot, gap 8px)
  |       |-- ToolbarGroup "attack_type"   (below rti, gap 8px)
  |       |-- ToolbarGroup "generic"       (below attack_type, gap 8px)
  |       |-- ToolbarGroup "save_mana"     (below generic, gap 8px)
  |       |-- ToolbarGroup "class_specific" (below save_mana, gap 8px)
```

**Toolbar vertical layout:**
Each ToolbarGroup is anchored below the previous one:
```lua
toolbar1:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 8, -8)
toolbar2:SetPoint("TOPLEFT", toolbar1, "BOTTOMLEFT", 0, -8)
-- etc.
```

**Dynamic class toolbar:**
When a bot is selected, ControlFrame:
1. Gets the bot's class from `addon:GetBotClass(botName)`
2. Looks up `addon.CLASS_STRATEGIES[class]`
3. Populates the `class_specific` toolbar with buttons for each class strategy
4. Updates the toolbar label to `"Class (ClassName)"`
5. Hides the toolbar if the class has no specific strategies

**Party Mode checkbox:**
When checked, the `sendCommand` function routes through `addon:SendPartyCommand()` instead of `addon:SendBotCommand()`. The title updates to "BotCP - Party Mode".

**Button click handling (the core feedback loop):**

For **strategy toggle** buttons (commandType = "strategy"):
```lua
function onStrategyButtonClick(button, botName)
    local stateKey = button.config.stateKey
    local channel = button.config.channel
    local strategyName = button.config.strategyName
    local currentState = addon:GetButtonState(botName, stateKey)

    local prefix
    if currentState == "ACTIVE" then
        prefix = "-"   -- deactivate
    else
        prefix = "+"   -- activate
    end

    local command = channel .. " " .. prefix .. strategyName .. ",?"
    -- e.g., "co +tank,?" or "nc -food,?"

    local requestId = addon:SendBotCommand(botName, command)
    local prevValue = (currentState == "ACTIVE")
    addon:SetPendingState(botName, stateKey, requestId, prevValue)
    button:SetState("PENDING")
end
```

For **formation** buttons (commandType = "formation"):
```lua
function onFormationButtonClick(button, botName)
    local command = button.config.command  -- "formation near"
    local requestId = addon:SendBotCommand(botName, command)
    -- Query after setting
    addon:SendBotCommand(botName, "formation ?")
    addon:SetPendingState(botName, "formation", requestId, addon:GetBotState(botName).formation)
    button:SetState("PENDING")
end
```

For **action** buttons (commandType = "action"):
```lua
function onActionButtonClick(button, botName)
    addon:SendBotCommand(botName, button.config.command)
    -- No pending state needed -- actions are fire-and-forget
    -- Optional: brief flash on the button to confirm click
end
```

For **exclusive groups** (formation, loot, rti):
When a button is clicked, all other buttons in the same toolbar are set to INACTIVE, and the clicked one goes to PENDING.

**Reset button behavior:**
For strategy toolbars, the Reset button sends `co -strategy1,-strategy2,...` for all strategies in that toolbar group, then queries. For formation, sends `formation reset`. etc.

**Public API:**

```
function addon:ShowControlFrame(botName)
  -- Show the control panel for the given bot.
  -- Populates class toolbar, updates title, queries state.

function addon:HideControlFrame()

function addon:RefreshControlFrame()
  -- Re-read all button states from StateManager and update visuals.
```

**Callback Events Listened To:**
- `"BOTCP_STATE_CHANGED"` (botName, stateKey) -- update the affected button
- `"BOTCP_BOT_TARGETED"` (botName) -- if auto-query enabled, show control frame for this bot
- `"BOTCP_ROSTER_CHANGED"` -- if selected bot went offline, update UI accordingly

**Dependencies:** Core.lua, Widgets.lua, ToolbarDefs.lua, StateManager.lua, CommandEngine.lua, BotRoster.lua

---

## 4. UI Schema -- Detailed Measurements and Positions

### 4.1 RosterFrame Dimensions

| Element | Type | Size (WxH) | Anchor | Offset (x, y) |
|---------|------|------------|--------|----------------|
| RosterFrame | Frame+Backdrop | 260 x 400 | CENTER, UIParent | 0, 0 (default; saved position overrides) |
| header | Texture | 256 x 64 | TOP, RosterFrame | 0, 12 |
| title | FontString (GameFontNormal) | auto | CENTER, header | 0, 12 |
| closeBtn | Button (UIPanelCloseButton) | 32 x 32 | TOPRIGHT, RosterFrame | -2, -2 |
| massActions | Frame | 240 x 26 | TOPLEFT, RosterFrame | 10, -32 |
| loginAllBtn | Button (UIPanelButtonTemplate) | 55 x 22 | TOPLEFT, massActions | 0, 0 |
| logoutAllBtn | Button (UIPanelButtonTemplate) | 55 x 22 | LEFT, loginAllBtn, RIGHT | 4, 0 |
| inviteAllBtn | Button (UIPanelButtonTemplate) | 55 x 22 | LEFT, logoutAllBtn, RIGHT | 4, 0 |
| refreshBtn | Button (UIPanelButtonTemplate) | 55 x 22 | LEFT, inviteAllBtn, RIGHT | 4, 0 |
| scrollFrame | ScrollFrame (UIPanelScrollFrameTemplate) | 236 x 310 | TOPLEFT, RosterFrame | 12, -62 |
| scrollChild | Frame | 218 x (dynamic) | TOPLEFT, scrollFrame | 0, 0 |
| statusBar | Frame | 240 x 20 | BOTTOMLEFT, RosterFrame | 10, 10 |
| statusText | FontString (GameFontNormalSmall) | auto | LEFT, statusBar | 0, 0 |

### 4.2 BotRow Dimensions

| Element | Type | Size | Anchor | Offset |
|---------|------|------|--------|--------|
| BotRow | Frame | 218 x 36 | TOPLEFT, scrollChild | 0, -(index-1)*38 |
| classIcon | Texture | 24 x 24 | LEFT, BotRow | 6, 0 |
| nameText | FontString (GameFontNormal) | auto | LEFT, classIcon, RIGHT | 4, 0 |
| statusDot | Texture | 10 x 10 | RIGHT, BotRow | -90, 0 |
| loginBtn | Button (UIPanelButtonTemplate) | 40 x 18 | RIGHT, BotRow | -46, 0 |
| inviteBtn | Button (UIPanelButtonTemplate) | 40 x 18 | RIGHT, BotRow | -4, 0 |

Font size for `loginBtn` and `inviteBtn`: set `btn:GetFontString():SetFont(font, 10)` to fit text.

### 4.3 ControlFrame Dimensions

| Element | Type | Size | Anchor | Offset |
|---------|------|------|--------|--------|
| ControlFrame | Frame+Backdrop | 380 x 520 | TOPLEFT, RosterFrame, TOPRIGHT | 4, 0 (anchored to right of roster) |
| header | Texture | 256 x 64 | TOP, ControlFrame | 0, 12 |
| classIcon | Texture | 20 x 20 | TOPLEFT, ControlFrame | 14, -8 |
| title | FontString (GameFontNormal) | auto | LEFT, classIcon, RIGHT | 4, 0 |
| closeBtn | Button (UIPanelCloseButton) | 32 x 32 | TOPRIGHT, ControlFrame | -2, -2 |
| partyModeCheck | CheckButton (UICheckButtonTemplate) | 26 x 26 | TOPLEFT, ControlFrame | 10, -32 |
| partyModeText | FontString | auto | LEFT, partyModeCheck, RIGHT | 2, 0 |
| scrollFrame | ScrollFrame (UIPanelScrollFrameTemplate) | 356 x 440 | TOPLEFT, ControlFrame | 12, -60 |
| scrollChild | Frame | 340 x (dynamic) | TOPLEFT, scrollFrame | 0, 0 |

### 4.4 ToolbarGroup Dimensions

| Element | Type | Size | Anchor | Offset |
|---------|------|------|--------|--------|
| ToolbarGroup | Frame | 340 x (dynamic) | TOPLEFT, previous toolbar, BOTTOMLEFT | 0, -8 |
| titleLabel | FontString (GameFontNormalSmall) | auto | TOPLEFT, ToolbarGroup | 0, 0 |
| buttonContainer | Frame | 340 x (dynamic) | TOPLEFT, titleLabel, BOTTOMLEFT | 0, -2 |
| ToggleButton N | Frame | 32 x 32 | (calculated, see layout algorithm) | spacing = 4 |
| resetBtn | Button (UIPanelButtonTemplate) | 20 x 20 | (after last toggle button) | 4, 0 |

**Height calculation:**
```
titleHeight = 14
buttonRows = ceil(numButtons / columns)
containerHeight = buttonRows * (buttonSize[2] + spacing) - spacing
totalHeight = titleHeight + 2 + containerHeight
```

### 4.5 ToggleButton Visual Details

| Element | Type | Size | Anchor | Details |
|---------|------|------|--------|---------|
| button frame | Frame | 32 x 32 | (set by toolbar layout) | EnableMouse(true) |
| icon | Texture | 28 x 28 | CENTER, button | 0, 0 | SetTexture(config.icon) |
| border | Texture | 32 x 32 | CENTER, button | 0, 0 | "Interface\\Buttons\\UI-ActionButton-Border", BlendMode "ADD" |
| highlight | Texture | 32 x 32 | CENTER, button | 0, 0 | "Interface\\Buttons\\ButtonHilight-Square", BlendMode "ADD", alpha 0.3 |
| pending | Texture | 32 x 32 | CENTER, button | 0, 0 | solid yellow texture, alpha-animated |
| label | FontString (GameFontNormalSmall) | auto | TOP, button, BOTTOM | 0, -1 | optional, only shown if no icon |

For buttons without custom icons (text-only mode), increase button size to 48x24, show label ON the button instead of icon.

**Border coloring:** Use `border:SetVertexColor(r, g, b, a)` to tint the border texture.

**Icon desaturation:** Use `icon:SetDesaturated(true/false)` to toggle grayscale. Available in 3.3.5a.

---

## 5. Data Flows

### 5.1 Flow: Player Opens Roster

```
Player types /botcp
  --> Core.HandleSlashCommand("")
    --> addon:ToggleRoster()
      --> RosterFrame:Show()
      --> addon:RefreshRoster()
        --> CommandEngine:SendServerCommand(".playerbots bot list")
          --> SendChatMessage(".playerbots bot list", "SAY")
          --> [Server processes, sends response via system message]
          --> CHAT_MSG_SYSTEM fires
            --> ResponseParser matches roster pattern
              --> Builds rosterData table
              --> addon:FireCallback("BOTCP_ROSTER_RECEIVED", rosterData)
                --> BotRoster handler updates addon.botRoster
                --> Merges with BotCP_DB.knownBots (persists new bots)
                --> addon:FireCallback("BOTCP_ROSTER_CHANGED")
                  --> RosterFrame handler calls RefreshRosterUI()
                    --> Rebuilds BotRow entries in scrollChild
```

### 5.2 Flow: Player Selects a Bot

```
Player clicks BotRow for "Tankbot"
  --> addon:SelectBot("Tankbot")
    --> Highlight row in RosterFrame
    --> addon:ShowControlFrame("Tankbot")
      --> ControlFrame updates title to "BotCP - Tankbot"
      --> Gets class: addon:GetBotClass("Tankbot") --> "WARRIOR"
      --> Populates class_specific toolbar with WARRIOR strategies
      --> addon:QueryBotState("Tankbot")
        --> StateManager populates queryQueue["Tankbot"] = {"co ?", "nc ?", "formation ?", "ll ?", "rti ?"}
        --> Sends first: SendBotCommand("Tankbot", "co ?")
          --> WHISPER to Tankbot: "co ?"
          --> [Bot responds via WHISPER: "Strategies: tank, dps"]
          --> CHAT_MSG_WHISPER fires (sender = "Tankbot")
            --> ResponseParser matches "^Strategies: (.+)$"
            --> StateManager checks lastQueryType["Tankbot"] == "co"
            --> Parses "tank, dps" --> { "tank", "dps" }
            --> Updates botStates["Tankbot"].coStrategies = { tank=true, dps=true }
            --> Clears pending states for co:*
            --> addon:FireCallback("BOTCP_STATE_CHANGED", "Tankbot", "co")
              --> ControlFrame:RefreshControlFrame()
                --> Each ToggleButton calls UpdateFromStateManager("Tankbot")
                --> co:tank button --> GetButtonState --> "ACTIVE" --> green border
                --> co:dps button --> GetButtonState --> "ACTIVE" --> green border
                --> co:aoe button --> GetButtonState --> "INACTIVE" --> gray border
            --> Pops "co ?" from queryQueue, sends next: "nc ?"
            --> ... (repeat for nc, formation, ll, rti)
```

### 5.3 Flow: Player Toggles a Strategy

```
Player clicks "Tank AOE" button (currently INACTIVE)
  --> onStrategyButtonClick(button, "Tankbot")
    --> currentState = "INACTIVE"
    --> command = "co +tank aoe,?"  (add strategy + query)
    --> requestId = addon:SendBotCommand("Tankbot", "co +tank aoe,?")
    --> addon:SetPendingState("Tankbot", "co:tank aoe", requestId, false)
    --> button:SetState("PENDING") --> yellow pulse animation starts

    --> CommandEngine queues command, sends after throttle
    --> SendChatMessage("co +tank aoe,?", "WHISPER", nil, "Tankbot")

    --> [Bot processes command, responds:]
    --> CHAT_MSG_WHISPER: "Strategies: tank, dps, tank aoe"
      --> ResponseParser matches, StateManager updates
      --> coStrategies now has tank_aoe = true
      --> ClearPendingState("Tankbot", "co:tank aoe")
      --> FireCallback("BOTCP_STATE_CHANGED", "Tankbot", "co:tank aoe")
        --> button:UpdateFromStateManager("Tankbot")
        --> GetButtonState returns "ACTIVE"
        --> button:SetState("ACTIVE") --> green border, pulse stops
```

### 5.4 Flow: Pending Timeout

```
Player clicks "Formation: Circle" button
  --> command sent, button goes PENDING
  --> ... 3 seconds pass, no response from server ...

  --> StateManager timeout checker (OnUpdate every 0.5s):
    --> Finds pending["formation"].timestamp + 3.0 < GetTime()
    --> Restores previousValue (e.g., "near")
    --> ClearPendingState
    --> FireCallback("BOTCP_STATE_CHANGED", "Tankbot", "formation")
      --> Button reverts to previous state (ACTIVE if was "near" before)
      --> Pulse animation stops
```

### 5.5 Flow: Party Mode

```
Player checks "Party Mode" checkbox
  --> ControlFrame sets partyMode = true
  --> Title updates to "BotCP - Party Mode"

Player clicks "Follow" button
  --> onActionButtonClick checks partyMode flag
  --> Instead of: addon:SendBotCommand(botName, "follow")
  --> Sends:      addon:SendPartyCommand("follow")
    --> SendChatMessage("follow", "PARTY")
    --> All bots in party receive and execute the command
```

### 5.6 Data Storage

**Runtime State (not persisted, rebuilt on login):**

```lua
-- In StateManager:
botStates = {
    ["Tankbot"] = {
        coStrategies = { ["tank"] = true, ["dps"] = true },
        ncStrategies = { ["food"] = true, ["potions"] = true },
        formation = "near",
        lootStrategy = "normal",
        rti = "skull",
        pending = {},
    },
    ["Healbot"] = { ... },
}

-- In BotRoster:
addon.botRoster = {
    ["Tankbot"]  = { class = "WARRIOR", online = true },
    ["Healbot"]  = { class = "PRIEST",  online = true },
    ["Magebot"]  = { class = "MAGE",    online = false },
}
```

**Persisted State (SavedVariables):**

```lua
-- BotCP_DB (account-wide):
BotCP_DB = {
    minimapButton = { position = 195 },
    rosterPosition = { point = "CENTER", x = 0, y = 0 },
    controlPosition = nil,
    knownBots = {
        ["Tankbot"]  = { class = "WARRIOR" },
        ["Healbot"]  = { class = "PRIEST" },
        ["Magebot"]  = { class = "MAGE" },
    },
    autoQueryOnTarget = true,
    commandThrottle = 0.3,
    pendingTimeout = 3.0,
}

-- BotCP_CharDB (per-character):
BotCP_CharDB = {
    rosterVisible = false,
    controlVisible = false,
    lastSelectedBot = "Tankbot",
}
```

---

## 6. Server Interaction -- Complete Command Reference

### 6.1 Dot-Commands (via SAY chat)

| Command | Purpose | Response Event | Response Pattern |
|---------|---------|----------------|-----------------|
| `.playerbots bot list` | Get roster | `CHAT_MSG_SYSTEM` | See 6.4 |
| `.playerbots bot add <name>` | Login bot | `CHAT_MSG_SYSTEM` | `"Bot added: ..."` |
| `.playerbots bot add <n1>,<n2>` | Login multiple | `CHAT_MSG_SYSTEM` | `"Bot added: ..."` |
| `.playerbots bot rm <name>` | Logout bot | `CHAT_MSG_SYSTEM` | `"Bot removed: ..."` |

**Send method:** `SendChatMessage(command, "SAY")`

### 6.2 Whisper Commands (to specific bot)

| Command | Purpose | Response Event | Response Pattern |
|---------|---------|----------------|-----------------|
| `co ?` | Query combat strategies | `CHAT_MSG_WHISPER` | `"Strategies: ..."` |
| `nc ?` | Query non-combat strategies | `CHAT_MSG_WHISPER` | `"Strategies: ..."` |
| `co +name` | Enable combat strategy | `CHAT_MSG_WHISPER` | Varies |
| `co -name` | Disable combat strategy | `CHAT_MSG_WHISPER` | Varies |
| `co +name,?` | Enable + query | `CHAT_MSG_WHISPER` | `"Strategies: ..."` |
| `co -name,?` | Disable + query | `CHAT_MSG_WHISPER` | `"Strategies: ..."` |
| `nc +name` | Enable non-combat strategy | `CHAT_MSG_WHISPER` | Varies |
| `nc -name` | Disable non-combat strategy | `CHAT_MSG_WHISPER` | Varies |
| `nc +name,?` | Enable + query | `CHAT_MSG_WHISPER` | `"Strategies: ..."` |
| `formation ?` | Query formation | `CHAT_MSG_WHISPER` | `"Formation: <name>"` |
| `formation <name>` | Set formation | `CHAT_MSG_WHISPER` | Varies |
| `ll ?` | Query loot strategy | `CHAT_MSG_WHISPER` | `"Loot strategy: <name>"` |
| `ll <name>` | Set loot strategy | `CHAT_MSG_WHISPER` | Varies |
| `rti ?` | Query RTI | `CHAT_MSG_WHISPER` | `"RTI: <name>"` |
| `rti <name>` | Set RTI | `CHAT_MSG_WHISPER` | Varies |
| `follow` | Follow player | `CHAT_MSG_WHISPER` | Varies |
| `stay` | Stay in place | `CHAT_MSG_WHISPER` | Varies |
| `guard` | Guard position | `CHAT_MSG_WHISPER` | Varies |
| `grind` | Grind mobs | `CHAT_MSG_WHISPER` | Varies |
| `flee` | Flee from combat | `CHAT_MSG_WHISPER` | Varies |
| `attack` | Attack target | `CHAT_MSG_WHISPER` | Varies |
| `tank attack` | Tank attack | `CHAT_MSG_WHISPER` | Varies |
| `stats` | Show stats | `CHAT_MSG_WHISPER` | Multi-line stats |
| `leave` | Leave group | `CHAT_MSG_WHISPER` | Varies |
| `revive` | Resurrect | `CHAT_MSG_WHISPER` | Varies |
| `release` | Release spirit | `CHAT_MSG_WHISPER` | Varies |
| `summon` | Summon to player | `CHAT_MSG_WHISPER` | Varies |

**Send method:** `SendChatMessage(command, "WHISPER", nil, botName)`

### 6.3 Party Commands (to all bots)

Same commands as whisper, but sent via `SendChatMessage(command, "PARTY")`.

### 6.4 Response Parsing Patterns

**Roster response** (`CHAT_MSG_SYSTEM`):

The exact format depends on the mod-playerbots version. The parser must handle multiple formats:

```lua
-- Format 1: "Bot added: BotName"
local name = msg:match("^Bot added: (%S+)")

-- Format 2: "Bot removed: BotName"
local name = msg:match("^Bot removed: (%S+)")

-- Format 3: Roster list "+Name Class, -Name Class, ..."
-- Match each segment:
for status, name, class in msg:gmatch("([%+%-])(%S+)%s+(%a[%a%s]*)") do
    -- status: "+" (online) or "-" (offline)
    -- name: bot character name
    -- class: localized class name (e.g., "Warrior", "Death Knight")
end
```

**Strategy response** (`CHAT_MSG_WHISPER`):

```lua
local strategies = msg:match("^Strategies: (.+)$")
if strategies then
    local list = {}
    for s in strategies:gmatch("[^,]+") do
        local trimmed = s:match("^%s*(.-)%s*$")
        if trimmed and trimmed ~= "" then
            list[trimmed] = true
        end
    end
    -- list is now { ["tank"] = true, ["dps"] = true, ... }
end
```

**Formation response:**
```lua
local formation = msg:match("^Formation: (%S+)$")
```

**Loot response:**
```lua
local loot = msg:match("^Loot strategy: (%S+)$")
```

**RTI response:**
```lua
local rti = msg:match("^RTI: (%S+)$")
```

### 6.5 Error Handling

**No response (timeout):**
- Handled by StateManager's pending timeout (default 3s)
- Button reverts to previous state
- No error message shown (silent recovery)

**Unknown bot:**
- If `.playerbots bot add` fails, server may respond with error message
- Parser should watch for: `msg:match("not found")` or `msg:match("does not exist")`
- On error: fire `"BOTCP_COMMAND_ERROR"` callback with error text

**Bot offline:**
- Whisper to offline bot will not get a response
- Handled by pending timeout
- BotRow shows offline status, ControlFrame buttons are disabled

**Chat throttle:**
- WoW client has internal chat throttle (~10 messages per 10 seconds for SAY/WHISPER)
- CommandEngine throttle (0.3s default) keeps us well under this limit
- If throttled by server, messages are silently dropped -- pending timeout handles recovery

---

## 7. Constraints and Notes for the Coder

### 7.1 Critical WoW 3.3.5a API Notes

1. **No C_Timer.** All timers must use the OnUpdate pattern with a frame and elapsed tracking. Create timer frames once, reuse them.

2. **No BackdropTemplateMixin.** Use `frame:SetBackdrop({...})` directly. The backdrop table format:
   ```lua
   {
       bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
       edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
       tile = true, tileSize = 32, edgeSize = 32,
       insets = { left = 8, right = 8, top = 8, bottom = 8 }
   }
   ```

3. **SetDesaturated(bool)** is available on Texture objects in 3.3.5a. Returns true if the hardware supports it (it almost always does). Call it as `texture:SetDesaturated(true)`.

4. **CHAT_MSG_WHISPER event args:** `(message, sender, language, channelString, target, flags, unknown, channelNumber, channelName, unknown, counter, guid)`. Use `sender` (arg2) to identify the bot. In 3.3.5a, `sender` is the character name without realm.

5. **CHAT_MSG_SYSTEM event args:** `(message)`. Just one argument.

6. **GetNumPartyMembers()** returns the number of party members (not including player). In 3.3.5a this is the correct function (NOT `GetNumGroupMembers()` which is post-MoP).

7. **UnitName("partyN")** where N = 1-4 returns the name of the Nth party member. Use this to check if a bot is in the group.

8. **InviteUnit(name)** exists in 3.3.5a and is the proper way to invite. It IS a protected function but can be called out of combat. In combat, it will fail silently. This is acceptable for our use case since bot management is typically done out of combat.

9. **`getglobal(name)`** is available in 3.3.5a for accessing named frame children (e.g., template-created sub-elements).

### 7.2 Performance Considerations

1. **Command throttle:** Default 0.3s between commands. This prevents chat flooding but may feel slow when querying state for multiple bots. Consider grouping queries: `co +strategy,?` combines set + query in one message.

2. **OnUpdate throttling:** The StateManager timeout checker and CommandEngine queue processor should both throttle their OnUpdate to run logic only every 0.1-0.5 seconds, not every frame.
   ```lua
   local elapsed = 0
   frame:SetScript("OnUpdate", function(self, dt)
       elapsed = elapsed + dt
       if elapsed < 0.1 then return end
       elapsed = 0
       -- actual logic here
   end)
   ```

3. **Roster UI rebuild:** Use object pooling for BotRow frames. Create them once, show/hide as needed. Do not destroy and recreate frames on every roster refresh.

4. **ToggleButton creation:** All toolbar buttons are created once when ControlFrame is first shown. For class-specific toolbar, create a pool of 10 buttons (max strategies for any class). Show/hide and reconfigure on bot selection change.

### 7.3 Edge Cases to Handle

1. **No bots configured:** First launch, `BotCP_DB.knownBots` is empty. Show an empty roster with a message "No bots found. Use /botcp add <name> or click Refresh."

2. **Bot name casing:** Server may return bot names with different casing than what was sent. Always use `addon.FormatBotName(name)` for comparison (capitalize first letter, lowercase rest).

3. **Whisper sender matching:** The `sender` in `CHAT_MSG_WHISPER` must be checked against known bots. If the whisper is from a real player (not a bot), ignore it in ResponseParser. Check `addon.botRoster[sender] ~= nil`.

4. **Multiple strategy responses arriving rapidly:** When querying all 5 states sequentially, responses may arrive out of order or be interleaved with other chat. The per-bot query queue + lastQueryType tracking handles this. If a response arrives for a query type we didn't expect, log a warning but still process it.

5. **UI reload (/reload):** All runtime state is lost. On `ADDON_LOADED`, only SavedVariables are available. The player must manually refresh roster and select a bot to re-query state. The `lastSelectedBot` in CharDB helps restore context.

6. **Closing panels:** When ControlFrame is closed, stop any pending animations but do NOT clear bot state from StateManager (so it persists if the panel is reopened).

7. **Bot goes offline while ControlFrame is open:** Listen for `"BOTCP_ROSTER_CHANGED"`, check if selected bot is still online. If not, show a "Bot Offline" overlay or disable all buttons.

### 7.4 Module Initialization Order

Each module initializes by listening to `"BOTCP_LOADED"` callback (fired by Core.lua after ADDON_LOADED):

1. **Constants** -- no init needed, just table definitions
2. **CommandEngine** -- creates timer frame for queue processing
3. **ResponseParser** -- creates event frame, registers CHAT_MSG_SYSTEM / CHAT_MSG_WHISPER
4. **StateManager** -- registers response handlers with ResponseParser, creates timeout frame
5. **BotRoster** -- loads knownBots from SavedVariables, registers PARTY_MEMBERS_CHANGED / PLAYER_TARGET_CHANGED
6. **Widgets** -- no init needed, just constructors
7. **MinimapButton** -- creates button, positions from SavedVariables
8. **RosterFrame** -- creates frame (hidden), registers callbacks
9. **ControlFrame** -- creates frame (hidden), creates all toolbars, registers callbacks

All modules listen to `"BOTCP_LOADED"` and fire in the order they registered (which is the load order from .toc). This is guaranteed because `"BOTCP_LOADED"` is fired synchronously from the `ADDON_LOADED` handler, and callbacks are invoked in registration order.

### 7.5 Naming Conventions Summary

| Type | Convention | Example |
|------|-----------|---------|
| Global frame names | `BotCP_PascalCase` | `BotCP_RosterFrame`, `BotCP_MinimapButton` |
| Namespace functions | `addon:PascalCase` | `addon:SendBotCommand()` |
| Local functions | `camelCase` | `local function processResponse()` |
| Local variables | `camelCase` | `local botName`, `local requestId` |
| Constants (module-level) | `UPPER_SNAKE_CASE` | `local THROTTLE_INTERVAL = 0.3` |
| Callback event names | `"BOTCP_UPPER_SNAKE_CASE"` | `"BOTCP_STATE_CHANGED"` |
| State keys | `"channel:name"` | `"co:tank"`, `"nc:food"`, `"formation:near"` |
| SavedVariables | `BotCP_DB`, `BotCP_CharDB` | -- |

### 7.6 File Template

Every `.lua` file must start with:

```lua
local addonName, addon = ...
```

No file should create global variables except:
- `BotCP_DB` and `BotCP_CharDB` (SavedVariables, created by WoW on load)
- `SLASH_BOTCP1`, `SLASH_BOTCP2`, `SlashCmdList["BOTCP"]` (slash command registration)
- Global frame names passed to `CreateFrame` (e.g., `"BotCP_RosterFrame"`)

### 7.7 Addon Communication Note

This addon does NOT use addon channel messaging (`SendAddonMessage` / `CHAT_MSG_ADDON`) because PlayerBots do not process addon messages. All communication is via regular chat channels (SAY for dot-commands, WHISPER for bot commands, PARTY for group commands).

### 7.8 Slash Command Extensions

Beyond basic show/hide, support these slash commands for power users:

```
/botcp              -- toggle roster
/botcp show         -- show roster
/botcp hide         -- hide all panels
/botcp add <name>   -- add bot to known list (prompts for class if not detectable)
/botcp remove <name> -- remove bot from known list
/botcp login <name> -- login specific bot
/botcp logout <name> -- logout specific bot
/botcp help         -- show all commands
```

---

## 8. Self-Check

- [x] All files listed and described with clear responsibilities
- [x] .toc load order is correct (dependencies load before dependents)
- [x] Every public function has parameters and return values specified
- [x] UI elements have concrete anchor points, sizes, and parent frames
- [x] Data flows described from source through transformation to storage
- [x] PlayerBots commands listed with exact syntax
- [x] Response parsing patterns provided with Lua string.match patterns
- [x] Error handling (timeouts, missing responses, offline bots) addressed
- [x] No circular dependencies between modules
- [x] No use of APIs unavailable in WoW 3.3.5a
- [x] Specification is consistent with CLAUDE.md conventions
