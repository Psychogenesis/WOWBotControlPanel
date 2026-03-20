-- Получение ссылки на namespace аддона
local addonName, addon = ...

-- ============================================================================
-- CLASS_STRATEGIES
-- Maps each class (English uppercase) to an ordered list of strategy names
-- that can be toggled for that class.
-- ============================================================================
addon.CLASS_STRATEGIES = {
    WARRIOR = {
        { label = "Spec", channel = "co", exclusive = true, strategies = {
            { id = "tank", label = "Tank" },
            { id = "arms", label = "Arms" },
            { id = "fury", label = "Fury" },
        }},
        { label = "Abilities", channel = "co", exclusive = false, strategies = {
            { id = "aoe",  label = "AOE" },
            { id = "pull", label = "Pull" },
        }},
    },
    PALADIN = {
        { label = "Spec", channel = "co", exclusive = true, strategies = {
            { id = "tank", label = "Tank" },
            { id = "dps",  label = "DPS" },
            { id = "heal", label = "Heal" },
        }},
        { label = "Abilities", channel = "co", exclusive = false, strategies = {
            { id = "cure",  label = "Cure" },
            { id = "boost", label = "Boost" },
            { id = "cc",    label = "CC" },
        }},
        { label = "Buffs", channel = "co", exclusive = false, strategies = {
            { id = "bthreat", label = "Threat" },
            { id = "bhealth", label = "Health" },
            { id = "bmana",   label = "Mana" },
            { id = "bdps",    label = "DPS" },
            { id = "bstats",  label = "Stats" },
            { id = "barmor",  label = "Armor" },
            { id = "bcast",   label = "Cast" },
            { id = "bspeed",  label = "Speed" },
            { id = "baoe",    label = "AOE" },
        }},
        { label = "Resistances", channel = "co", exclusive = false, strategies = {
            { id = "rshadow", label = "Shadow" },
            { id = "rfrost",  label = "Frost" },
            { id = "rfire",   label = "Fire" },
        }},
    },
    HUNTER = {
        { label = "Spec", channel = "co", exclusive = true, strategies = {
            { id = "bm",   label = "BM" },
            { id = "mm",   label = "MM" },
            { id = "surv", label = "Surv" },
        }},
        { label = "Abilities", channel = "co", exclusive = false, strategies = {
            { id = "pet",        label = "Pet" },
            { id = "aoe",        label = "AOE" },
            { id = "boost",      label = "Boost" },
            { id = "cc",         label = "CC" },
            { id = "trap weave", label = "Trap Weave" },
        }},
        { label = "Buffs", channel = "co", exclusive = false, strategies = {
            { id = "bspeed", label = "Speed" },
            { id = "bdps",   label = "DPS" },
            { id = "bmana",  label = "Mana" },
        }},
        { label = "Resistances", channel = "co", exclusive = false, strategies = {
            { id = "rnature", label = "Nature" },
        }},
    },
    ROGUE = {
        { label = "Spec", channel = "co", exclusive = true, strategies = {
            { id = "dps",   label = "DPS" },
            { id = "melee", label = "Melee" },
        }},
        { label = "Abilities", channel = "co", exclusive = false, strategies = {
            { id = "aoe",      label = "AOE" },
            { id = "stealthed", label = "Stealthed" },
            { id = "stealth",  label = "Stealth" },
            { id = "boost",    label = "Boost" },
            { id = "cc",       label = "CC" },
        }},
    },
    PRIEST = {
        { label = "Spec", channel = "co", exclusive = true, strategies = {
            { id = "heal",      label = "Heal" },
            { id = "shadow",    label = "Shadow" },
            { id = "holy dps",  label = "Holy DPS" },
            { id = "holy heal", label = "Holy Heal" },
        }},
        { label = "Abilities", channel = "co", exclusive = false, strategies = {
            { id = "shadow aoe",    label = "Shadow AOE" },
            { id = "shadow debuff", label = "Shadow Debuff" },
            { id = "cure",          label = "Cure" },
            { id = "buff",          label = "Buff" },
            { id = "boost",         label = "Boost" },
            { id = "cc",            label = "CC" },
        }},
        { label = "Resistances", channel = "co", exclusive = false, strategies = {
            { id = "rshadow", label = "Shadow" },
        }},
    },
    SHAMAN = {
        { label = "Spec", channel = "co", exclusive = true, strategies = {
            { id = "heal",   label = "Heal" },
            { id = "melee",  label = "Melee" },
            { id = "caster", label = "Caster" },
        }},
        { label = "Abilities", channel = "co", exclusive = false, strategies = {
            { id = "aoe",   label = "AOE" },
            { id = "cure",  label = "Cure" },
            { id = "boost", label = "Boost" },
        }},
        { label = "Totems (Earth)", channel = "co", exclusive = false, strategies = {
            { id = "strength of earth", label = "Strength" },
            { id = "stoneskin",         label = "Stoneskin" },
            { id = "tremor",            label = "Tremor" },
            { id = "earthbind",         label = "Earthbind" },
        }},
        { label = "Totems (Fire)", channel = "co", exclusive = false, strategies = {
            { id = "searing",     label = "Searing" },
            { id = "magma",       label = "Magma" },
            { id = "flametongue", label = "Flametongue" },
        }},
    },
    MAGE = {
        { label = "Spec", channel = "co", exclusive = true, strategies = {
            { id = "frost",     label = "Frost" },
            { id = "fire",      label = "Fire" },
            { id = "frostfire", label = "Frostfire" },
            { id = "arcane",    label = "Arcane" },
        }},
        { label = "Abilities", channel = "co", exclusive = false, strategies = {
            { id = "aoe",         label = "AOE" },
            { id = "cure",        label = "Cure" },
            { id = "buff",        label = "Buff" },
            { id = "boost",       label = "Boost" },
            { id = "cc",          label = "CC" },
            { id = "firestarter", label = "Firestarter" },
        }},
        { label = "Buffs", channel = "co", exclusive = false, strategies = {
            { id = "bmana", label = "Mana" },
            { id = "bdps",  label = "DPS" },
        }},
    },
    WARLOCK = {
        { label = "Spec", channel = "co", exclusive = true, strategies = {
            { id = "affli",  label = "Affli" },
            { id = "demo",   label = "Demo" },
            { id = "destro", label = "Destro" },
        }},
        { label = "Abilities", channel = "co", exclusive = false, strategies = {
            { id = "aoe",        label = "AOE" },
            { id = "pet",        label = "Pet" },
            { id = "tank",       label = "Tank" },
            { id = "boost",      label = "Boost" },
            { id = "cc",         label = "CC" },
            { id = "meta melee", label = "Meta Melee" },
        }},
        { label = "Pet", channel = "co", exclusive = true, strategies = {
            { id = "imp",        label = "Imp" },
            { id = "voidwalker", label = "Voidwalker" },
            { id = "succubus",   label = "Succubus" },
            { id = "felhunter",  label = "Felhunter" },
            { id = "felguard",   label = "Felguard" },
        }},
        { label = "Soulstone", channel = "co", exclusive = true, strategies = {
            { id = "ss self",   label = "SS Self" },
            { id = "ss master", label = "SS Master" },
            { id = "ss tank",   label = "SS Tank" },
            { id = "ss healer", label = "SS Healer" },
        }},
    },
    DRUID = {
        { label = "Spec", channel = "co", exclusive = true, strategies = {
            { id = "bear",    label = "Bear" },
            { id = "cat",     label = "Cat" },
            { id = "caster",  label = "Caster" },
            { id = "heal",    label = "Heal" },
            { id = "offheal", label = "Offheal" },
        }},
        { label = "Abilities", channel = "co", exclusive = false, strategies = {
            { id = "melee",         label = "Melee" },
            { id = "cat aoe",       label = "Cat AOE" },
            { id = "caster aoe",    label = "Caster AOE" },
            { id = "caster debuff", label = "Caster Debuff" },
            { id = "cure",          label = "Cure" },
            { id = "buff",          label = "Buff" },
            { id = "boost",         label = "Boost" },
            { id = "cc",            label = "CC" },
        }},
    },
    DEATHKNIGHT = {
        { label = "Spec", channel = "co", exclusive = true, strategies = {
            { id = "blood",  label = "Blood" },
            { id = "frost",  label = "Frost" },
            { id = "unholy", label = "Unholy" },
        }},
        { label = "Abilities", channel = "co", exclusive = false, strategies = {
            { id = "frost aoe",  label = "Frost AOE" },
            { id = "unholy aoe", label = "Unholy AOE" },
        }},
        { label = "Buffs", channel = "co", exclusive = false, strategies = {
            { id = "bdps", label = "DPS" },
        }},
    },
}

-- ============================================================================
-- FORMATIONS
-- Available formation options for bots.
-- ============================================================================
addon.FORMATIONS = {
    { id = "near",   label = "Near" },
    { id = "melee",  label = "Melee" },
    { id = "line",   label = "Line" },
    { id = "circle", label = "Circle" },
    { id = "arrow",  label = "Arrow" },
    { id = "far",    label = "Far" },
    { id = "chaos",  label = "Chaos" },
}

-- ============================================================================
-- LOOT_STRATEGIES
-- Available loot strategy options for bots.
-- ============================================================================
addon.LOOT_STRATEGIES = {
    { id = "normal",      label = "Normal" },
    { id = "all",         label = "All" },
    { id = "gray",        label = "Gray" },
    { id = "disenchant",  label = "Disenchant" },
    { id = "skill",       label = "Skill" },
}

-- ============================================================================
-- RTI_TARGETS
-- Raid Target Icon options with corresponding icon textures.
-- ============================================================================
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

-- ============================================================================
-- MOVEMENT_COMMANDS
-- Movement-related commands for bots.
-- isAction = true means it is sent as a direct action whisper.
-- isStrategy = true means it is toggled as a strategy.
-- channel specifies the strategy channel ("nc" = non-combat, "co" = combat).
-- ============================================================================
addon.MOVEMENT_COMMANDS = {
    { id = "follow",  label = "Follow",  isAction = true },
    { id = "stay",    label = "Stay",    isAction = true },
    { id = "guard",   label = "Guard",   isAction = true },
    { id = "grind",   label = "Grind",   isAction = true },
    { id = "passive", label = "Passive", isStrategy = true, channel = "nc" },
    { id = "flee",    label = "Flee",    isAction = true },
}

-- ============================================================================
-- ACTION_COMMANDS
-- General action commands for bots.
-- ============================================================================
addon.ACTION_COMMANDS = {
    { id = "attack",      label = "Attack",      isAction = true },
    { id = "tank attack", label = "Tank Attack",  isAction = true },
    { id = "stats",       label = "Stats",        isAction = true },
    { id = "revive",      label = "Revive",       isAction = true },
    { id = "release",     label = "Release",      isAction = true },
    { id = "summon",      label = "Summon",       isAction = true },
}

-- ============================================================================
-- GENERIC_STRATEGIES
-- Generic strategies applicable to all classes.
-- channel specifies "nc" (non-combat) or "co" (combat).
-- ============================================================================
addon.GENERIC_STRATEGIES = {
    { id = "cast time",   label = "Cast Time",   channel = "co" },
    { id = "threat",      label = "Threat",       channel = "co" },
    { id = "behind",      label = "Behind",       channel = "co" },
    { id = "ranged",      label = "Ranged",       channel = "co" },
    { id = "close",       label = "Close",        channel = "co" },
    { id = "kite",        label = "Kite",         channel = "co" },
    { id = "avoid aoe",   label = "Avoid AOE",    channel = "co" },
    { id = "tank face",   label = "Tank Face",    channel = "co" },
    { id = "aggressive",  label = "Aggressive",   channel = "co" },
    { id = "save mana",   label = "Save Mana",    channel = "co" },
    { id = "potions",     label = "Potions",       channel = "nc" },
    { id = "food",        label = "Food",          channel = "nc" },
    { id = "pvp",         label = "PvP",           channel = "nc" },
    { id = "mount",       label = "Mount",         channel = "nc" },
}

-- ============================================================================
-- ATTACK_TYPE_STRATEGIES
-- Attack-type strategies (combat channel).
-- ============================================================================
addon.ATTACK_TYPE_STRATEGIES = {
    { id = "dps assist",  label = "DPS Assist",  channel = "co" },
    { id = "dps aoe",     label = "DPS AOE",     channel = "co" },
    { id = "tank assist", label = "Tank Assist",  channel = "co" },
}

-- ============================================================================
-- CLASS_NAMES
-- Maps localized (English) class names to uppercase class constants.
-- Used to convert the second return of UnitClass() to the internal format.
-- ============================================================================
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
