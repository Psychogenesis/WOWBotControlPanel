-- Получение ссылки на namespace аддона
local addonName, addon = ...

-- ============================================================================
-- CLASS_STRATEGIES
-- Maps each class (English uppercase) to an ordered list of strategy names
-- that can be toggled for that class.
-- ============================================================================
addon.CLASS_STRATEGIES = {
    DRUID       = { "bear", "cat", "caster", "heal" },
    HUNTER      = { "dps", "bspeed", "bmana", "bdps" },
    MAGE        = { "arcane", "fire", "fire aoe", "frost", "frost aoe", "bmana", "bdps" },
    PALADIN     = { "dps", "tank", "bmana", "bhealth", "bdps", "barmor", "bspeed", "bthreat" },
    PRIEST      = { "heal", "holy", "shadow", "shadow debuff", "shadow aoe" },
    ROGUE       = { "dps", "behind" },
    SHAMAN      = { "heal", "caster", "caster aoe", "bmana", "bdps", "totems" },
    WARLOCK     = { "shadow", "shadow debuff", "shadow aoe", "pet", "rshadow" },
    WARRIOR     = { "tank", "tank aoe", "dps", "aoe" },
    DEATHKNIGHT = { "blood", "frost", "unholy" },
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
    { id = "potions",       label = "Potions",       channel = "nc" },
    { id = "food",          label = "Food",          channel = "nc" },
    { id = "cast time",     label = "Cast Time",     channel = "co" },
    { id = "conserve mana", label = "Conserve Mana", channel = "co" },
    { id = "buff",          label = "Buff",          channel = "nc" },
    { id = "attack weak",   label = "Attack Weak",   channel = "co" },
    { id = "threat",        label = "Threat",        channel = "co" },
}

-- ============================================================================
-- ATTACK_TYPE_STRATEGIES
-- Attack-type strategies (combat channel).
-- ============================================================================
addon.ATTACK_TYPE_STRATEGIES = {
    { id = "tank aoe",    label = "Tank AOE",    channel = "co" },
    { id = "tank assist", label = "Tank Assist",  channel = "co" },
    { id = "dps assist",  label = "DPS Assist",   channel = "co" },
    { id = "caster aoe",  label = "Caster AOE",   channel = "co" },
}

-- ============================================================================
-- SAVE_MANA_LEVELS
-- Available save mana levels (1-5).
-- ============================================================================
addon.SAVE_MANA_LEVELS = { 1, 2, 3, 4, 5 }

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
