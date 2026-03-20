-- Получение ссылки на namespace аддона
local addonName, addon = ...

-- Локальные ссылки на часто используемые API (для производительности)
local ipairs = ipairs
local string_lower = string.lower
local string_gsub = string.gsub

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
    tank_assist = "Interface\\Icons\\Ability_Warrior_ShieldBash",
    dps_assist  = "Interface\\Icons\\Ability_Warrior_Rampage",
    dps_aoe     = "Interface\\Icons\\Spell_Fire_Flamestrike",

    -- Generic strategies
    potions       = "Interface\\Icons\\INV_Potion_51",
    food          = "Interface\\Icons\\INV_Misc_Food_11",
    cast_time     = "Interface\\Icons\\Spell_Nature_Lightning",
    threat        = "Interface\\Icons\\Spell_Nature_ReincarnationMan",
    behind        = "Interface\\Icons\\Ability_BackStab",
    ranged        = "Interface\\Icons\\Ability_Marksmanship",
    close         = "Interface\\Icons\\Ability_Warrior_Charge",
    kite          = "Interface\\Icons\\Ability_Hunter_Pathfinding",
    avoid_aoe     = "Interface\\Icons\\Spell_Arcane_Blink",
    tank_face     = "Interface\\Icons\\Ability_Warrior_ShieldBash",
    aggressive    = "Interface\\Icons\\Ability_Warrior_InnerRage",
    save_mana     = "Interface\\Icons\\INV_Elemental_Mote_Mana",
    pvp           = "Interface\\Icons\\INV_BannerPVP_01",
    mount         = "Interface\\Icons\\Ability_Mount_Ridinghorse",

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
    frost       = "Interface\\Icons\\Spell_Frost_FrostBolt02",
    tank        = "Interface\\Icons\\Ability_Warrior_DefensiveStance",
    bhealth     = "Interface\\Icons\\Spell_Holy_SealOfSacrifice",
    barmor      = "Interface\\Icons\\Spell_Holy_DevotionAura",
    bthreat     = "Interface\\Icons\\Spell_Nature_ReincarnationMan",
    holy        = "Interface\\Icons\\Spell_Holy_HolyBolt",
    shadow      = "Interface\\Icons\\Spell_Shadow_ShadowBolt",
    shadow_debuff = "Interface\\Icons\\Spell_Shadow_CurseOfSargeras",
    shadow_aoe  = "Interface\\Icons\\Spell_Shadow_RainOfFire",
    pet         = "Interface\\Icons\\Spell_Shadow_SummonImp",
    rshadow     = "Interface\\Icons\\Spell_Shadow_Requiem",
    aoe         = "Interface\\Icons\\Ability_Warrior_Whirlwind",
    blood       = "Interface\\Icons\\Spell_Deathknight_BloodPresence",
    unholy      = "Interface\\Icons\\Spell_Deathknight_UnholyPresence",
    buff        = "Interface\\Icons\\Spell_Holy_GreaterBlessingofKings",

    -- Class abilities (new)
    cure        = "Interface\\Icons\\Spell_Holy_DispelMagic",
    boost       = "Interface\\Icons\\Spell_Holy_PowerInfusion",
    cc          = "Interface\\Icons\\Spell_Frost_Stun",
    pull        = "Interface\\Icons\\Ability_Marksmanship",

    -- Paladin buffs (new)
    bstats      = "Interface\\Icons\\Spell_Holy_GreaterBlessingofKings",
    bcast       = "Interface\\Icons\\Spell_Holy_SealOfWisdom",
    baoe        = "Interface\\Icons\\Spell_Holy_SealOfRighteousness",

    -- Resistances (new)
    rfrost      = "Interface\\Icons\\Spell_Frost_WizardMark",
    rfire       = "Interface\\Icons\\Spell_Fire_SealOfFire",
    rnature     = "Interface\\Icons\\Spell_Nature_NatureResistanceTotem",

    -- Hunter specs (new)
    bm          = "Interface\\Icons\\Ability_Hunter_BeastTaming",
    mm          = "Interface\\Icons\\Ability_Hunter_FocusedAim",
    surv        = "Interface\\Icons\\Ability_Hunter_SurvivalInstincts",
    trap_weave  = "Interface\\Icons\\Spell_Frost_ChainsOfIce",

    -- Rogue (new)
    stealthed   = "Interface\\Icons\\Ability_Stealth",
    stealth     = "Interface\\Icons\\Ability_Ambush",

    -- Warrior (new)
    arms        = "Interface\\Icons\\Ability_Warrior_SavageBlow",
    fury        = "Interface\\Icons\\Ability_Warrior_InnerRage",

    -- Priest (new)
    holy_dps    = "Interface\\Icons\\Spell_Holy_SearingLight",
    holy_heal   = "Interface\\Icons\\Spell_Holy_Renew",

    -- Shaman (new)
    strength_of_earth = "Interface\\Icons\\Spell_Nature_EarthBindTotem",
    stoneskin   = "Interface\\Icons\\Spell_Nature_StoneSkinTotem",
    tremor      = "Interface\\Icons\\Spell_Nature_TremorTotem",
    earthbind   = "Interface\\Icons\\Spell_Nature_StrengthOfEarthTotem02",
    searing     = "Interface\\Icons\\Spell_Fire_SearingTotem",
    magma       = "Interface\\Icons\\Spell_Fire_SelfDestruct",
    flametongue = "Interface\\Icons\\Spell_Nature_GuardianWard",

    -- Mage (new)
    frostfire   = "Interface\\Icons\\Spell_Frost_FrostFire",
    firestarter = "Interface\\Icons\\Spell_Fire_Immolation",

    -- Warlock (new)
    affli       = "Interface\\Icons\\Spell_Shadow_CurseOfSargeras",
    demo        = "Interface\\Icons\\Spell_Shadow_Metamorphosis",
    destro      = "Interface\\Icons\\Spell_Shadow_RainOfFire",
    meta_melee  = "Interface\\Icons\\Spell_Shadow_DemonForm",
    imp         = "Interface\\Icons\\Spell_Shadow_SummonImp",
    voidwalker  = "Interface\\Icons\\Spell_Shadow_SummonVoidWalker",
    succubus    = "Interface\\Icons\\Spell_Shadow_SummonSuccubus",
    felhunter   = "Interface\\Icons\\Spell_Shadow_SummonFelHunter",
    felguard    = "Interface\\Icons\\Spell_Shadow_SummonFelGuard",
    ss_self     = "Interface\\Icons\\Spell_Shadow_SoulGem",
    ss_master   = "Interface\\Icons\\Spell_Shadow_SoulGem",
    ss_tank     = "Interface\\Icons\\Spell_Shadow_SoulGem",
    ss_healer   = "Interface\\Icons\\Spell_Shadow_SoulGem",

    -- Druid (new)
    offheal     = "Interface\\Icons\\Spell_Nature_HealingTouch",
    cat_aoe     = "Interface\\Icons\\Ability_Druid_Swipe",
    caster_aoe  = "Interface\\Icons\\Spell_Fire_Fireball",
    caster_debuff = "Interface\\Icons\\Spell_Nature_InsectSwarm",

    -- DK (new)
    frost_aoe   = "Interface\\Icons\\Spell_Frost_IceStorm",
    unholy_aoe  = "Interface\\Icons\\Spell_DeathKnight_Pestilence",
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
-- Build attack type buttons from Constants (exclusive group)
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
            exclusiveGroup = "attack_type",
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
    -- 6. Attack Type toolbar (exclusive, generated from Constants)
    -- ========================================================================
    {
        id = "attack_type",
        label = "Attack Type",
        columns = 8,
        buttonSize = { 32, 32 },
        hasReset = true,
        exclusive = true,
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
    -- 8. Class-specific toolbar (dynamic, populated at runtime)
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
-- addon.BuildClassToolbarDefs(className)
-- Build sub-group toolbar definitions for a specific class from CLASS_STRATEGIES.
-- Called by ControlFrame when selecting a bot to populate class sub-toolbars.
-- @param className string - uppercase English class name (e.g. "WARRIOR")
-- @return table - array of sub-group definition tables, or empty table if unknown class
-- ============================================================================
function addon.BuildClassToolbarDefs(className)
    local result = {}
    if not className then
        return result
    end

    local classGroups = addon.CLASS_STRATEGIES[className]
    if not classGroups then
        return result
    end

    -- Build a display name for labels: "Warrior" from "WARRIOR", "Death Knight" from "DEATHKNIGHT"
    local DISPLAY_NAMES = {
        DEATHKNIGHT = "Death Knight",
    }
    local displayName = DISPLAY_NAMES[className] or (className:sub(1, 1) .. className:sub(2):lower())

    for _, group in ipairs(classGroups) do
        -- Build the exclusiveGroup identifier for exclusive sub-groups:
        -- Format: "<CLASS>_<normalized_label>" where label is lowercased,
        -- spaces -> underscores, parentheses removed
        local exclusiveGroupId = nil
        if group.exclusive then
            local normalizedLabel = string_lower(group.label)
            normalizedLabel = string_gsub(normalizedLabel, "[%(%)]", "")
            normalizedLabel = string_gsub(normalizedLabel, " ", "_")
            exclusiveGroupId = className .. "_" .. normalizedLabel
        end

        local buttons = {}
        for _, strat in ipairs(group.strategies) do
            buttons[#buttons + 1] = {
                id = strat.id,
                label = strat.label,
                tooltip = "Class Strategy: " .. strat.label,
                stateKey = group.channel .. ":" .. strat.id,
                commandType = "strategy",
                channel = group.channel,
                strategyName = strat.id,
                exclusiveGroup = exclusiveGroupId,
                icon = getStrategyIcon(strat.id),
            }
        end

        result[#result + 1] = {
            label = displayName .. " - " .. group.label,
            exclusive = group.exclusive,
            channel = group.channel,
            buttons = buttons,
        }
    end

    return result
end
