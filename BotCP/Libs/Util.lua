-- Получение ссылки на namespace аддона
local addonName, addon = ...

-- Локальные ссылки на часто используемые API (для производительности)
local type = type
local pairs = pairs
local string_match = string.match
local string_gmatch = string.gmatch
local string_sub = string.sub
local string_upper = string.upper
local string_lower = string.lower
local table_insert = table.insert

-- ============================================================================
-- addon.DeepCopy(src)
-- Deep copy a table. Returns a new table.
-- ============================================================================
function addon.DeepCopy(src)
    if type(src) ~= "table" then
        return src
    end
    local copy = {}
    for k, v in pairs(src) do
        if type(v) == "table" then
            copy[k] = addon.DeepCopy(v)
        else
            copy[k] = v
        end
    end
    return copy
end

-- ============================================================================
-- addon.MergeDefaults(target, defaults)
-- For each key in defaults, if target[key] is nil, set target[key] = defaults[key].
-- Recurse into sub-tables. Returns target (modified in place).
-- ============================================================================
function addon.MergeDefaults(target, defaults)
    if type(target) ~= "table" then
        return target
    end
    if type(defaults) ~= "table" then
        return target
    end
    for k, v in pairs(defaults) do
        if target[k] == nil then
            if type(v) == "table" then
                target[k] = addon.DeepCopy(v)
            else
                target[k] = v
            end
        elseif type(v) == "table" and type(target[k]) == "table" then
            addon.MergeDefaults(target[k], v)
        end
    end
    return target
end

-- ============================================================================
-- addon.ClassColor(englishClass)
-- Returns r, g, b (0-1 floats) for the given class name.
-- Uses RAID_CLASS_COLORS global table available in 3.3.5a.
-- ============================================================================
function addon.ClassColor(englishClass)
    if not englishClass then
        return 1, 1, 1
    end
    local color = RAID_CLASS_COLORS[englishClass]
    if color then
        return color.r, color.g, color.b
    end
    return 1, 1, 1
end

-- ============================================================================
-- addon.ClassIconCoords(englishClass)
-- Returns left, right, top, bottom texcoords for class icon in
-- "Interface\\GLUES\\CHARACTERCREATE\\UI-CharacterCreate-Classes"
-- Uses CLASS_ICON_TCOORDS global.
-- ============================================================================
function addon.ClassIconCoords(englishClass)
    if not englishClass then
        return 0, 1, 0, 1
    end
    local coords = CLASS_ICON_TCOORDS[englishClass]
    if coords then
        return coords[1], coords[2], coords[3], coords[4]
    end
    return 0, 1, 0, 1
end

-- ============================================================================
-- addon.TrimString(s)
-- Remove leading/trailing whitespace. Returns trimmed string.
-- ============================================================================
function addon.TrimString(s)
    if type(s) ~= "string" then
        return ""
    end
    return string_match(s, "^%s*(.-)%s*$") or ""
end

-- ============================================================================
-- addon.SplitString(s, delimiter)
-- Split string by delimiter. Returns table of substrings.
-- ============================================================================
function addon.SplitString(s, delimiter)
    if type(s) ~= "string" then
        return {}
    end
    if not delimiter or delimiter == "" then
        delimiter = ","
    end
    local result = {}
    local pattern = "([^" .. delimiter .. "]+)"
    for part in string_gmatch(s, pattern) do
        table_insert(result, addon.TrimString(part))
    end
    return result
end

-- ============================================================================
-- addon.TableContains(tbl, value)
-- Returns boolean.
-- ============================================================================
function addon.TableContains(tbl, value)
    if type(tbl) ~= "table" then
        return false
    end
    for _, v in pairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

-- ============================================================================
-- addon.FormatBotName(name)
-- Capitalize first letter, lowercase rest. Returns formatted string.
-- ============================================================================
function addon.FormatBotName(name)
    if type(name) ~= "string" or name == "" then
        return ""
    end
    return string_upper(string_sub(name, 1, 1)) .. string_lower(string_sub(name, 2))
end
