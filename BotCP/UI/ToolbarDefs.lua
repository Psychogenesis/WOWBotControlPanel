-- Получение ссылки на namespace аддона
local addonName, addon = ...

-- Локальные ссылки на часто используемые API (для производительности)
local ipairs = ipairs
local tostring = tostring

-- ============================================================================
-- Icon constants for toolbar buttons
-- ============================================================================
local ICONS = {
    -- Movement
    follow      = "Interface\\Icons\\Ability_Tracking",
    stay        = "Interface\\Icons\\Spell_Nature_TimeStop",
    guard       = "Interface\\Icons\\Ability_Defend",
    grind       = "Interface\\Icons\\Ability_DualWield",
    flee        = "Interface\\Icons\\Ability_Rogue_Sprint",
    passive     = "Interface\\Icons\\Spell_Nature_Sentinal",

    -- Actions
    attack      = "Interface\\Icons\\Ability_SteelMelee",
    tank_attack = "Interface\\Icons\\Ability_Warrior_DefensiveStance",
    stats       = "Interface\\Icons\\INV_Misc_Note_01",
    summon      = "Interface\\Icons\\Spell_Shadow_Twilight",
    revive      = "Interface\\Icons\\Spell_Holy_Resurrection",
    release     = "Interface\\Icons\\Spell_Holy_GuardianSpirit",

    -- Formations
    near        = "Interface\\Icons\\Ability_Warrior_Charge",
    melee       = "Interface\\Icons\\Ability_Warrior_Cleave",
    line        = "Interface\\Icons\\Spell_Frost_FrostBolt02",
    circle      = "Interface\\Icons\\Spell_Arcane_TeleportStormwind",
    arrow       = "Interface\\Icons\\Ability_Hunter_FocusedAim",
    far         = "Interface\\Icons\\Ability_Hunter_Pathfinding",
    chaos       = "Interface\\Icons\\Spell_Shadow_RainOfFire",

    -- Loot
    loot_normal     = "Interface\\Icons\\INV_Misc_Coin_01",
    loot_all        = "Interface\\Icons\\INV_Misc_Coin_17",
    loot_gray       = "Interface\\Icons\\INV_Misc_Coin_06",
    loot_disenchant = "Interface\\Icons\\Spell_Holy_GreaterHeal",
    loot_skill      = "Interface\\Icons\\Trade_Engineering",

    -- Attack Type
    tank_aoe    = "Interface\\Icons\\Spell_Holy_SealOfProtection",
    tank_assist = "Interface\\Icons\\Ability_Warrior_ShieldBash",
    dps_assist  = "Interface\\Icons\\Ability_Warrior_Rampage",
    caster_aoe  = "Interface\\Icons\\Spell_Fire_Flamestrike",

    -- Generic strategies
    potions       = "Interface\\Icons\\INV_Potion_51",
    food          = "Interface\\Icons\\INV_Misc_Food_11",
    cast_time     = "Interface\\Icons\\Spell_Nature_Lightning",
    conserve_mana = "Interface\\Icons\\INV_Enchant_EssenceMagicSmall",
    buff          = "Interface\\Icons\\Spell_Holy_GreaterBlessingofKings",
    attack_weak   = "Interface\\Icons\\Ability_BackStab",
    threat        = "Interface\\Icons\\Spell_Nature_ReincarnationMan",

    -- Save mana
    save_mana   = "Interface\\Icons\\INV_Elemental_Mote_Mana",

    -- Class-specific (default icon for class strats, used as fallback)
    class_default = "Interface\\Icons\\Trade_Engineering",

    -- Per-strategy icons for class-specific strategies
    bear        = "Interface\\Icons\\Ability_Racial_BearForm",
    cat         = "Interface\\Icons\\Ability_Druid_CatForm",
    caster      = "Interface\\Icons\\Spell_Nature_StarFall",
    heal        = "Interface\\Icons\\Spell_Holy_FlashHeal",
    dps         = "Interface\\Icons\\Ability_Warrior_InnerRage",
    bspeed      = "Interface\\Icons\\Spell_Nature_Swiftness",
    bmana       = "Interface\\Icons\\Spell_Frost_ManaRecharge",
    bdps        = "Interface\\Icons\\Spell_Holy_MindVision",
    arcane      = "Interface\\Icons\\Spell_Holy_MagicSentry",
    fire        = "Interface\\Icons\\Spell_Fire_FlameBolt",
    fire_aoe    = "Interface\\Icons\\Spell_Fire_SelfDestruct",
    frost       = "Interface\\Icons\\Spell_Frost_FrostBolt02",
    frost_aoe   = "Interface\\Icons\\Spell_Frost_IceStorm",
    tank        = "Interface\\Icons\\Ability_Warrior_DefensiveStance",
    bhealth     = "Interface\\Icons\\Spell_Holy_SealOfSacrifice",
    barmor      = "Interface\\Icons\\Spell_Holy_DevotionAura",
    bthreat     = "Interface\\Icons\\Spell_Nature_ReincarnationMan",
    holy        = "Interface\\Icons\\Spell_Holy_HolyBolt",
    shadow      = "Interface\\Icons\\Spell_Shadow_ShadowBolt",
    shadow_debuff = "Interface\\Icons\\Spell_Shadow_CurseOfSargeras",
    shadow_aoe  = "Interface\\Icons\\Spell_Shadow_RainOfFire",
    behind      = "Interface\\Icons\\Ability_BackStab",
    caster_aoe_class = "Interface\\Icons\\Spell_Fire_Fireball",
    totems      = "Interface\\Icons\\Spell_Nature_ManaTide",
    pet         = "Interface\\Icons\\Spell_Shadow_SummonImp",
    rshadow     = "Interface\\Icons\\Spell_Shadow_Requiem",
    aoe         = "Interface\\Icons\\Ability_Warrior_Whirlwind",
    blood       = "Interface\\Icons\\Spell_Deathknight_BloodPresence",
    unholy      = "Interface\\Icons\\Spell_Deathknight_UnholyPresence",
}

-- ============================================================================
-- Helper: get an icon for a strategy name
-- ============================================================================
local function getStrategyIcon(strategyName)
    -- Normalize: replace spaces with underscores for lookup
    local key = strategyName:gsub(" ", "_")
    return ICONS[key] or ICONS.class_default
end

-- ============================================================================
-- Build formation buttons from Constants
-- ============================================================================
local function buildFormationButtons()
    local buttons = {}
    for _, formation in ipairs(addon.FORMATIONS) do
        buttons[#buttons + 1] = {
            id = formation.id,
            label = formation.label,
            tooltip = "Formation: " .. formation.label,
            stateKey = "formation:" .. formation.id,
            commandType = "formation",
            command = "formation " .. formation.id,
            icon = ICONS[formation.id] or ICONS.class_default,
        }
    end
    return buttons
end

-- ============================================================================
-- Build loot strategy buttons from Constants
-- ============================================================================
local function buildLootButtons()
    local buttons = {}
    for _, loot in ipairs(addon.LOOT_STRATEGIES) do
        buttons[#buttons + 1] = {
            id = loot.id,
            label = loot.label,
            tooltip = "Loot Strategy: " .. loot.label,
            stateKey = "loot:" .. loot.id,
            commandType = "loot",
            command = "ll " .. loot.id,
            icon = ICONS["loot_" .. loot.id] or ICONS.class_default,
        }
    end
    return buttons
end

-- ============================================================================
-- Build RTI buttons from Constants
-- ============================================================================
local function buildRtiButtons()
    local buttons = {}
    for _, rti in ipairs(addon.RTI_TARGETS) do
        buttons[#buttons + 1] = {
            id = rti.id,
            label = rti.label,
            tooltip = "RTI Target: " .. rti.label,
            stateKey = "rti:" .. rti.id,
            commandType = "rti",
            command = "rti " .. rti.id,
            icon = rti.icon,
        }
    end
    return buttons
end

-- ============================================================================
-- Build attack type buttons from Constants
-- ============================================================================
local function buildAttackTypeButtons()
    local buttons = {}
    for _, strat in ipairs(addon.ATTACK_TYPE_STRATEGIES) do
        buttons[#buttons + 1] = {
            id = strat.id,
            label = strat.label,
            tooltip = "Attack Type: " .. strat.label,
            stateKey = strat.channel .. ":" .. strat.id,
            commandType = "strategy",
            channel = strat.channel,
            strategyName = strat.id,
            icon = ICONS[strat.id:gsub(" ", "_")] or ICONS.class_default,
        }
    end
    return buttons
end

-- ============================================================================
-- Build generic strategy buttons from Constants
-- ============================================================================
local function buildGenericButtons()
    local buttons = {}
    for _, strat in ipairs(addon.GENERIC_STRATEGIES) do
        buttons[#buttons + 1] = {
            id = strat.id,
            label = strat.label,
            tooltip = "Strategy: " .. strat.label .. " (" .. strat.channel .. ")",
            stateKey = strat.channel .. ":" .. strat.id,
            commandType = "strategy",
            channel = strat.channel,
            strategyName = strat.id,
            icon = ICONS[strat.id:gsub(" ", "_")] or ICONS.class_default,
        }
    end
    return buttons
end

-- ============================================================================
-- Build save mana buttons from Constants
-- ============================================================================
local function buildSaveManaButtons()
    local buttons = {}
    for _, level in ipairs(addon.SAVE_MANA_LEVELS) do
        local levelStr = tostring(level)
        local stratName = "save mana " .. levelStr
        buttons[#buttons + 1] = {
            id = "save_mana_" .. levelStr,
            label = levelStr,
            tooltip = "Save Mana Level " .. levelStr,
            stateKey = "co:" .. stratName,
            commandType = "strategy",
            channel = "co",
            strategyName = stratName,
            icon = ICONS.save_mana,
        }
    end
    return buttons
end

-- ============================================================================
-- TOOLBAR_DEFS
-- The main toolbar definitions table consumed by ControlFrame.
-- ============================================================================
addon.TOOLBAR_DEFS = {
    -- ========================================================================
    -- 1. Movement toolbar
    -- ========================================================================
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
                stateKey = nil,
                commandType = "action",
                command = "follow",
                icon = ICONS.follow,
            },
            {
                id = "stay",
                label = "Stay",
                tooltip = "Bot stays in place",
                stateKey = nil,
                commandType = "action",
                command = "stay",
                icon = ICONS.stay,
            },
            {
                id = "guard",
                label = "Guard",
                tooltip = "Bot guards current position",
                stateKey = nil,
                commandType = "action",
                command = "guard",
                icon = ICONS.guard,
            },
            {
                id = "grind",
                label = "Grind",
                tooltip = "Bot grinds nearby mobs",
                stateKey = nil,
                commandType = "action",
                command = "grind",
                icon = ICONS.grind,
            },
            {
                id = "flee",
                label = "Flee",
                tooltip = "Bot flees from combat",
                stateKey = nil,
                commandType = "action",
                command = "flee",
                icon = ICONS.flee,
            },
            {
                id = "passive",
                label = "Passive",
                tooltip = "Toggle passive mode (non-combat strategy)",
                stateKey = "nc:passive",
                commandType = "strategy",
                channel = "nc",
                strategyName = "passive",
                icon = ICONS.passive,
            },
        },
    },

    -- ========================================================================
    -- 2. Actions toolbar
    -- ========================================================================
    {
        id = "actions",
        label = "Actions",
        columns = 8,
        buttonSize = { 32, 32 },
        hasReset = false,
        buttons = {
            {
                id = "attack",
                label = "Attack",
                tooltip = "Attack your target",
                stateKey = nil,
                commandType = "action",
                command = "attack",
                icon = ICONS.attack,
            },
            {
                id = "tank_attack",
                label = "Tank Attack",
                tooltip = "Tank attacks your target",
                stateKey = nil,
                commandType = "action",
                command = "tank attack",
                icon = ICONS.tank_attack,
            },
            {
                id = "stats",
                label = "Stats",
                tooltip = "Show bot statistics",
                stateKey = nil,
                commandType = "action",
                command = "stats",
                icon = ICONS.stats,
            },
            {
                id = "summon",
                label = "Summon",
                tooltip = "Summon bot to you",
                stateKey = nil,
                commandType = "action",
                command = "summon",
                icon = ICONS.summon,
            },
            {
                id = "revive",
                label = "Revive",
                tooltip = "Resurrect at Spirit Healer",
                stateKey = nil,
                commandType = "action",
                command = "revive",
                icon = ICONS.revive,
            },
            {
                id = "release",
                label = "Release",
                tooltip = "Release spirit",
                stateKey = nil,
                commandType = "action",
                command = "release",
                icon = ICONS.release,
            },
        },
    },

    -- ========================================================================
    -- 3. Formation toolbar (exclusive, generated from Constants)
    -- ========================================================================
    {
        id = "formation",
        label = "Formation",
        columns = 8,
        buttonSize = { 32, 32 },
        hasReset = true,
        exclusive = true,
        buttons = buildFormationButtons(),
    },

    -- ========================================================================
    -- 4. Loot Strategy toolbar (exclusive, generated from Constants)
    -- ========================================================================
    {
        id = "loot",
        label = "Loot Strategy",
        columns = 8,
        buttonSize = { 32, 32 },
        hasReset = false,
        exclusive = true,
        buttons = buildLootButtons(),
    },

    -- ========================================================================
    -- 5. RTI Target toolbar (exclusive, generated from Constants)
    -- ========================================================================
    {
        id = "rti",
        label = "RTI Target",
        columns = 8,
        buttonSize = { 32, 32 },
        hasReset = false,
        exclusive = true,
        buttons = buildRtiButtons(),
    },

    -- ========================================================================
    -- 6. Attack Type toolbar (generated from Constants)
    -- ========================================================================
    {
        id = "attack_type",
        label = "Attack Type",
        columns = 8,
        buttonSize = { 32, 32 },
        hasReset = true,
        buttons = buildAttackTypeButtons(),
    },

    -- ========================================================================
    -- 7. Generic strategies toolbar (generated from Constants)
    -- ========================================================================
    {
        id = "generic",
        label = "Generic",
        columns = 8,
        buttonSize = { 32, 32 },
        hasReset = true,
        buttons = buildGenericButtons(),
    },

    -- ========================================================================
    -- 8. Save Mana toolbar (exclusive, generated from Constants)
    -- ========================================================================
    {
        id = "save_mana",
        label = "Save Mana",
        columns = 5,
        buttonSize = { 32, 32 },
        hasReset = true,
        exclusive = true,
        buttons = buildSaveManaButtons(),
    },

    -- ========================================================================
    -- 9. Class-specific toolbar (dynamic, populated at runtime)
    -- ========================================================================
    {
        id = "class_specific",
        label = "Class",
        columns = 8,
        buttonSize = { 32, 32 },
        hasReset = true,
        dynamic = true,
        buttons = {},
    },
}

-- ============================================================================
-- addon.BuildClassButtons(className)
-- Build button definitions for a specific class from CLASS_STRATEGIES.
-- Called by ControlFrame when selecting a bot to populate the dynamic toolbar.
-- @param className string - uppercase English class name (e.g. "WARRIOR")
-- @return table - array of button definition tables, or empty table if unknown class
-- ============================================================================
function addon.BuildClassButtons(className)
    local buttons = {}
    if not className then
        return buttons
    end

    local strategies = addon.CLASS_STRATEGIES[className]
    if not strategies then
        return buttons
    end

    for _, stratName in ipairs(strategies) do
        -- Determine channel: class strategies are combat ("co") by default
        local channel = "co"

        buttons[#buttons + 1] = {
            id = stratName:gsub(" ", "_"),
            label = stratName:sub(1, 1):upper() .. stratName:sub(2),
            tooltip = "Class Strategy: " .. stratName:sub(1, 1):upper() .. stratName:sub(2),
            stateKey = channel .. ":" .. stratName,
            commandType = "strategy",
            channel = channel,
            strategyName = stratName,
            icon = getStrategyIcon(stratName),
        }
    end

    return buttons
end
