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
            { id = "tank", label = "Tank", desc = "Defensive stance, high threat" },
            { id = "arms", label = "Arms", desc = "Arms DPS with Mortal Strike" },
            { id = "fury", label = "Fury", desc = "Dual-wield fury DPS" },
        }},
        { label = "Abilities", channel = "co", exclusive = false, strategies = {
            { id = "aoe",  label = "AOE", desc = "Use area damage abilities" },
            { id = "pull", label = "Pull", desc = "Pull enemies from range" },
        }},
    },
    PALADIN = {
        { label = "Spec", channel = "co", exclusive = true, strategies = {
            { id = "tank", label = "Tank", desc = "Protection tanking" },
            { id = "dps",  label = "DPS", desc = "Retribution DPS" },
            { id = "heal", label = "Heal", desc = "Holy healing" },
        }},
        { label = "Abilities", channel = "co", exclusive = false, strategies = {
            { id = "cure",  label = "Cure", desc = "Cleanse diseases and magic" },
            { id = "boost", label = "Boost", desc = "Use cooldown abilities" },
            { id = "cc",    label = "CC", desc = "Use crowd control" },
        }},
        { label = "Buffs", channel = "co", exclusive = false, strategies = {
            { id = "bthreat", label = "Threat", desc = "Blessing of Sanctuary" },
            { id = "bhealth", label = "Health", desc = "Blessing of Kings (health)" },
            { id = "bmana",   label = "Mana", desc = "Blessing of Wisdom" },
            { id = "bdps",    label = "DPS", desc = "Blessing of Might" },
            { id = "bstats",  label = "Stats", desc = "Blessing of Kings (stats)" },
            { id = "barmor",  label = "Armor", desc = "Devotion Aura" },
            { id = "bcast",   label = "Cast", desc = "Concentration Aura" },
            { id = "bspeed",  label = "Speed", desc = "Crusader Aura" },
            { id = "baoe",    label = "AOE", desc = "Retribution Aura" },
        }},
        { label = "Resistances", channel = "co", exclusive = false, strategies = {
            { id = "rshadow", label = "Shadow", desc = "Shadow Resistance Aura" },
            { id = "rfrost",  label = "Frost", desc = "Frost Resistance Aura" },
            { id = "rfire",   label = "Fire", desc = "Fire Resistance Aura" },
        }},
    },
    HUNTER = {
        { label = "Spec", channel = "co", exclusive = true, strategies = {
            { id = "bm",   label = "BM", desc = "Beast Mastery spec" },
            { id = "mm",   label = "MM", desc = "Marksmanship spec" },
            { id = "surv", label = "Surv", desc = "Survival spec" },
        }},
        { label = "Abilities", channel = "co", exclusive = false, strategies = {
            { id = "pet",        label = "Pet", desc = "Use pet abilities" },
            { id = "aoe",        label = "AOE", desc = "Use multi-target abilities" },
            { id = "boost",      label = "Boost", desc = "Use cooldown abilities" },
            { id = "cc",         label = "CC", desc = "Use traps and crowd control" },
            { id = "trap weave", label = "Trap Weave", desc = "Weave traps between shots" },
        }},
        { label = "Buffs", channel = "co", exclusive = false, strategies = {
            { id = "bspeed", label = "Speed", desc = "Aspect of the Cheetah/Pack" },
            { id = "bdps",   label = "DPS", desc = "Aspect of the Hawk/Dragonhawk" },
            { id = "bmana",  label = "Mana", desc = "Aspect of the Viper" },
        }},
        { label = "Resistances", channel = "co", exclusive = false, strategies = {
            { id = "rnature", label = "Nature", desc = "Aspect of the Wild" },
        }},
    },
    ROGUE = {
        { label = "Spec", channel = "co", exclusive = true, strategies = {
            { id = "dps",   label = "DPS", desc = "Combat DPS rotation" },
            { id = "melee", label = "Melee", desc = "Melee-focused combat" },
        }},
        { label = "Abilities", channel = "co", exclusive = false, strategies = {
            { id = "aoe",      label = "AOE", desc = "Use Fan of Knives and AOE" },
            { id = "stealthed", label = "Stealthed", desc = "Open from stealth" },
            { id = "stealth",  label = "Stealth", desc = "Use stealth approach" },
            { id = "boost",    label = "Boost", desc = "Use cooldown abilities" },
            { id = "cc",       label = "CC", desc = "Use Sap and Blind" },
        }},
    },
    PRIEST = {
        { label = "Spec", channel = "co", exclusive = true, strategies = {
            { id = "heal",      label = "Heal", desc = "Discipline healing" },
            { id = "shadow",    label = "Shadow", desc = "Shadow DPS" },
            { id = "holy dps",  label = "Holy DPS", desc = "Holy DPS (Smite)" },
            { id = "holy heal", label = "Holy Heal", desc = "Holy healing" },
        }},
        { label = "Abilities", channel = "co", exclusive = false, strategies = {
            { id = "shadow aoe",    label = "Shadow AOE", desc = "Mind Sear and AOE" },
            { id = "shadow debuff", label = "Shadow Debuff", desc = "Apply Shadow Word: Pain, VT" },
            { id = "cure",          label = "Cure", desc = "Dispel magic and diseases" },
            { id = "buff",          label = "Buff", desc = "Apply Power Word: Fortitude" },
            { id = "boost",         label = "Boost", desc = "Use Inner Focus, cooldowns" },
            { id = "cc",            label = "CC", desc = "Use Shackle Undead, Psychic Scream" },
        }},
        { label = "Resistances", channel = "co", exclusive = false, strategies = {
            { id = "rshadow", label = "Shadow", desc = "Shadow Protection" },
        }},
    },
    SHAMAN = {
        { label = "Spec", channel = "co", exclusive = true, strategies = {
            { id = "heal",   label = "Heal", desc = "Restoration healing" },
            { id = "melee",  label = "Melee", desc = "Enhancement melee DPS" },
            { id = "caster", label = "Caster", desc = "Elemental caster DPS" },
        }},
        { label = "Abilities", channel = "co", exclusive = false, strategies = {
            { id = "aoe",   label = "AOE", desc = "Use Chain Lightning, Fire Nova" },
            { id = "cure",  label = "Cure", desc = "Cleanse poisons and diseases" },
            { id = "boost", label = "Boost", desc = "Use Heroism/Bloodlust" },
        }},
        { label = "Totems (Earth)", channel = "co", exclusive = false, strategies = {
            { id = "strength of earth", label = "Strength", desc = "Strength of Earth Totem" },
            { id = "stoneskin",         label = "Stoneskin", desc = "Stoneskin Totem" },
            { id = "tremor",            label = "Tremor", desc = "Tremor Totem (fear removal)" },
            { id = "earthbind",         label = "Earthbind", desc = "Earthbind Totem (slow)" },
        }},
        { label = "Totems (Fire)", channel = "co", exclusive = false, strategies = {
            { id = "searing",     label = "Searing", desc = "Searing Totem (single target)" },
            { id = "magma",       label = "Magma", desc = "Magma Totem (AOE damage)" },
            { id = "flametongue", label = "Flametongue", desc = "Flametongue Totem (spell power)" },
        }},
    },
    MAGE = {
        { label = "Spec", channel = "co", exclusive = true, strategies = {
            { id = "frost",     label = "Frost", desc = "Frost spec" },
            { id = "fire",      label = "Fire", desc = "Fire spec" },
            { id = "frostfire", label = "Frostfire", desc = "Frostfire Bolt spec" },
            { id = "arcane",    label = "Arcane", desc = "Arcane spec" },
        }},
        { label = "Abilities", channel = "co", exclusive = false, strategies = {
            { id = "aoe",         label = "AOE", desc = "Use Blizzard, Flamestrike" },
            { id = "cure",        label = "Cure", desc = "Remove Curse" },
            { id = "buff",        label = "Buff", desc = "Apply Arcane Intellect" },
            { id = "boost",       label = "Boost", desc = "Use Icy Veins, Arcane Power" },
            { id = "cc",          label = "CC", desc = "Use Polymorph" },
            { id = "firestarter", label = "Firestarter", desc = "Open with Fireball before combat" },
        }},
        { label = "Buffs", channel = "co", exclusive = false, strategies = {
            { id = "bmana", label = "Mana", desc = "Mage Armor (mana regen)" },
            { id = "bdps",  label = "DPS", desc = "Molten Armor (crit)" },
        }},
    },
    WARLOCK = {
        { label = "Spec", channel = "co", exclusive = true, strategies = {
            { id = "affli",  label = "Affli", desc = "Affliction DOT spec" },
            { id = "demo",   label = "Demo", desc = "Demonology spec" },
            { id = "destro", label = "Destro", desc = "Destruction direct damage" },
        }},
        { label = "Abilities", channel = "co", exclusive = false, strategies = {
            { id = "aoe",        label = "AOE", desc = "Use Rain of Fire, Seed" },
            { id = "pet",        label = "Pet", desc = "Use pet abilities actively" },
            { id = "tank",       label = "Tank", desc = "Voidwalker tanking mode" },
            { id = "boost",      label = "Boost", desc = "Use cooldown abilities" },
            { id = "cc",         label = "CC", desc = "Use Fear, Banish" },
            { id = "meta melee", label = "Meta Melee", desc = "Metamorphosis melee mode" },
        }},
        { label = "Pet", channel = "co", exclusive = true, strategies = {
            { id = "imp",        label = "Imp", desc = "Summon Imp (ranged DPS)" },
            { id = "voidwalker", label = "Voidwalker", desc = "Summon Voidwalker (tank)" },
            { id = "succubus",   label = "Succubus", desc = "Summon Succubus (CC)" },
            { id = "felhunter",  label = "Felhunter", desc = "Summon Felhunter (anti-caster)" },
            { id = "felguard",   label = "Felguard", desc = "Summon Felguard (melee DPS)" },
        }},
        { label = "Soulstone", channel = "co", exclusive = true, strategies = {
            { id = "ss self",   label = "SS Self", desc = "Soulstone on self" },
            { id = "ss master", label = "SS Master", desc = "Soulstone on master" },
            { id = "ss tank",   label = "SS Tank", desc = "Soulstone on tank" },
            { id = "ss healer", label = "SS Healer", desc = "Soulstone on healer" },
        }},
    },
    DRUID = {
        { label = "Spec", channel = "co", exclusive = true, strategies = {
            { id = "bear",    label = "Bear", desc = "Bear form tanking" },
            { id = "cat",     label = "Cat", desc = "Cat form DPS" },
            { id = "caster",  label = "Caster", desc = "Moonkin caster DPS" },
            { id = "heal",    label = "Heal", desc = "Restoration healing" },
            { id = "offheal", label = "Offheal", desc = "Offheal while in cat form" },
        }},
        { label = "Abilities", channel = "co", exclusive = false, strategies = {
            { id = "melee",         label = "Melee", desc = "Melee combat style" },
            { id = "cat aoe",       label = "Cat AOE", desc = "Swipe in cat form" },
            { id = "caster aoe",    label = "Caster AOE", desc = "Hurricane, Starfall" },
            { id = "caster debuff", label = "Caster Debuff", desc = "Apply Insect Swarm, Moonfire" },
            { id = "cure",          label = "Cure", desc = "Remove Poison, Curse" },
            { id = "buff",          label = "Buff", desc = "Apply Mark of the Wild, Thorns" },
            { id = "boost",         label = "Boost", desc = "Use Berserk, Nature's Swiftness" },
            { id = "cc",            label = "CC", desc = "Use Entangling Roots, Hibernate" },
        }},
    },
    DEATHKNIGHT = {
        { label = "Spec", channel = "co", exclusive = true, strategies = {
            { id = "blood",  label = "Blood", desc = "Blood tanking spec" },
            { id = "frost",  label = "Frost", desc = "Frost DPS spec" },
            { id = "unholy", label = "Unholy", desc = "Unholy DPS spec" },
        }},
        { label = "Abilities", channel = "co", exclusive = false, strategies = {
            { id = "frost aoe",  label = "Frost AOE", desc = "Howling Blast AOE" },
            { id = "unholy aoe", label = "Unholy AOE", desc = "Pestilence spread diseases" },
        }},
        { label = "Buffs", channel = "co", exclusive = false, strategies = {
            { id = "bdps", label = "DPS", desc = "Horn of Winter" },
        }},
    },
}

-- ============================================================================
-- FORMATIONS
-- Available formation options for bots.
-- ============================================================================
addon.FORMATIONS = {
    { id = "near",   label = "Near",   desc = "Stay close to the leader" },
    { id = "melee",  label = "Melee",  desc = "Melee formation around target" },
    { id = "line",   label = "Line",   desc = "Form a line behind leader" },
    { id = "circle", label = "Circle", desc = "Spread in a circle around leader" },
    { id = "arrow",  label = "Arrow",  desc = "Arrow formation pointing forward" },
    { id = "far",    label = "Far",    desc = "Keep maximum distance from leader" },
    { id = "chaos",  label = "Chaos",  desc = "Random positioning around leader" },
}

-- ============================================================================
-- LOOT_STRATEGIES
-- Available loot strategy options for bots.
-- ============================================================================
addon.LOOT_STRATEGIES = {
    { id = "normal",      label = "Normal",      desc = "Loot normally" },
    { id = "all",         label = "All",         desc = "Loot everything" },
    { id = "gray",        label = "Gray",        desc = "Only loot gray (vendor trash) items" },
    { id = "disenchant",  label = "Disenchant",  desc = "Disenchant green+ items" },
    { id = "skill",       label = "Skill",       desc = "Loot items for professions" },
}

-- ============================================================================
-- RTI_TARGETS
-- Raid Target Icon options with corresponding icon textures.
-- ============================================================================
addon.RTI_TARGETS = {
    { id = "skull",    label = "Skull",    icon = "Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_8", desc = "Focus target: Skull" },
    { id = "cross",    label = "Cross",    icon = "Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_7", desc = "Focus target: Cross" },
    { id = "circle",   label = "Circle",   icon = "Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_2", desc = "Focus target: Circle" },
    { id = "star",     label = "Star",     icon = "Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_1", desc = "Focus target: Star" },
    { id = "square",   label = "Square",   icon = "Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_6", desc = "Focus target: Square" },
    { id = "triangle", label = "Triangle", icon = "Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_3", desc = "Focus target: Triangle" },
    { id = "diamond",  label = "Diamond",  icon = "Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_4", desc = "Focus target: Diamond" },
    { id = "moon",     label = "Moon",     icon = "Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_5", desc = "Focus target: Moon" },
}

-- ============================================================================
-- MOVEMENT_COMMANDS
-- Movement-related commands for bots.
-- isAction = true means it is sent as a direct action whisper.
-- isStrategy = true means it is toggled as a strategy.
-- channel specifies the strategy channel ("nc" = non-combat, "co" = combat).
-- ============================================================================
addon.MOVEMENT_COMMANDS = {
    { id = "follow",  label = "Follow",  isAction = true, desc = "Bot follows your character" },
    { id = "stay",    label = "Stay",    isAction = true, desc = "Bot stays at current position" },
    { id = "guard",   label = "Guard",   isAction = true, desc = "Bot guards a specific location" },
    { id = "grind",   label = "Grind",   isAction = true, desc = "Bot grinds nearby enemies" },
    { id = "passive", label = "Passive", isStrategy = true, channel = "nc", desc = "Bot avoids combat entirely" },
    { id = "flee",    label = "Flee",    isAction = true, desc = "Bot flees from combat" },
}

-- ============================================================================
-- ACTION_COMMANDS
-- General action commands for bots.
-- ============================================================================
addon.ACTION_COMMANDS = {
    { id = "attack",      label = "Attack",      isAction = true, desc = "Attack your current target" },
    { id = "tank attack", label = "Tank Attack",  isAction = true, desc = "Tank engages your target" },
    { id = "stats",       label = "Stats",        isAction = true, desc = "Show bot statistics" },
    { id = "revive",      label = "Revive",       isAction = true, desc = "Resurrect at Spirit Healer" },
    { id = "release",     label = "Release",      isAction = true, desc = "Release spirit after death" },
    { id = "summon",      label = "Summon",       isAction = true, desc = "Teleport bot to your location" },
}

-- ============================================================================
-- GENERIC_STRATEGIES
-- Generic strategies applicable to all classes.
-- channel specifies "nc" (non-combat) or "co" (combat).
-- ============================================================================
addon.GENERIC_STRATEGIES = {
    { id = "cast time",   label = "Cast Time",   channel = "co", desc = "Use abilities with cast time" },
    { id = "threat",      label = "Threat",       channel = "co", desc = "Use threat management abilities" },
    { id = "behind",      label = "Behind",       channel = "co", desc = "Position behind the target" },
    { id = "ranged",      label = "Ranged",       channel = "co", desc = "Keep distance, use ranged attacks" },
    { id = "close",       label = "Close",        channel = "co", desc = "Stay in melee range" },
    { id = "kite",        label = "Kite",         channel = "co", desc = "Kite enemies while attacking" },
    { id = "avoid aoe",   label = "Avoid AOE",    channel = "co", desc = "Move out of area damage effects" },
    { id = "tank face",   label = "Tank Face",    channel = "co", desc = "Tank faces target away from group" },
    { id = "aggressive",  label = "Aggressive",   channel = "co", desc = "Engage enemies more aggressively" },
    { id = "save mana",   label = "Save Mana",    channel = "co", desc = "Conserve mana during combat" },
    { id = "potions",     label = "Potions",       channel = "nc", desc = "Use potions when needed" },
    { id = "food",        label = "Food",          channel = "nc", desc = "Eat and drink out of combat" },
    { id = "pvp",         label = "PvP",           channel = "nc", desc = "Attack enemy players" },
    { id = "mount",       label = "Mount",         channel = "nc", desc = "Use mount when traveling" },
}

-- ============================================================================
-- ATTACK_TYPE_STRATEGIES
-- Attack-type strategies (combat channel).
-- ============================================================================
addon.ATTACK_TYPE_STRATEGIES = {
    { id = "dps assist",  label = "DPS Assist",  channel = "co", desc = "DPS focuses your target" },
    { id = "dps aoe",     label = "DPS AOE",     channel = "co", desc = "DPS uses area damage on all enemies" },
    { id = "tank assist", label = "Tank Assist",  channel = "co", desc = "Tank holds aggro on your target" },
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
