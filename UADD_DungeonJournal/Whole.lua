-- Whole lines only (CLAUDE.md "No half translations", docs/LESSONS.md lesson 6). FDJ.LocalizeFreeText
-- puts each comma part (and each part between wide dashes) through its places on its own, so a quest
-- giver line "Name, Town, Zone" with one name UALL Forever lacks came out half Ukrainian. Wrapped (by
-- Language.lua's Install): when any part with Latin letters has no Ukrainian, the whole line stays
-- exactly English. Only while our language is shown; FDJ's own languages are left as they are.
-- The same for two lines with a name in them: a Tier 0.5 quest's title with its item or boss in brackets,
-- and Edit Mode's place tip with a dungeon's name.

local _, ns = ...
local W = {}
ns.Whole = W

local DASH = " \226\128\148 "   -- FDJ's wide dash between parts
local orig

local function Places()
    local fdj = rawget(_G, "ForeverDungeonJournal_NS")
    local c = fdj and type(fdj.ContentLocales) == "table" and fdj.ContentLocales[ns.Lang.LOCALE]
    return type(c) == "table" and type(c.places) == "table" and c.places or {}
end

-- One part: no Latin letters (a number, a mark, already Ukrainian), or a name FDJ's map has.
local function Known(part)
    return not part:find("%a") or orig(part) ~= part
end

local function AllKnown(piece, places)
    if places[piece] then return true end
    for _, part in ipairs(ns.Content.Parts(piece)) do
        if not Known(part) then return false end
    end
    return true
end

-- Our check runs under UADD.Safe (docs/LESSONS2.md lesson 19): on an error of ours the line is English.
local Check = UADD.Safe("dj", function(value, out)
    if out == value or type(value) ~= "string" or not ns.Lang.Active() then return out end
    local places = Places()
    if places[value] then return out end
    local rest = value
    while rest do
        local i = rest:find(DASH, 1, true)
        if not AllKnown(i and rest:sub(1, i - 1) or rest, places) then return value end
        rest = i and rest:sub(i + #DASH) or nil
    end
    return out
end)

local function LocalizeFreeText(value, ...)
    local out = orig(value, ...)
    local checked = Check(value, out)
    if checked == nil then return value end
    return checked
end
W.LocalizeFreeText = LocalizeFreeText

-- ── Objective lines ──────────────────────────────────────────────────────────────────────────
-- The game's objective lines ("Name: 0/6", or "0/6 Name") under a quest in the list and in FDJ's
-- tracker. FDJ.LocalizeObjectives translates them only through its own name table, which has no
-- Ukrainian, so they stayed English. Before FDJ reads them we put the item or object name into
-- Ukrainian (UADD.UALL.Item: ClassicUA first, UALL Forever on a miss) and keep the game's numbers and
-- layout. A line whose name has no Ukrainian, a kill line, or any other line is passed on as it was:
-- the line is whole Ukrainian or whole English. An error of ours: FDJ gets the game's own lines.
local origObjectives

local function NameUk(en)
    local item = UADD.UALL and UADD.UALL.Item
    if type(item) ~= "function" or en:find("[\128-\255|]") then return nil end
    local uk = item(en)
    -- Whole Ukrainian only: Cyrillic, no Latin letters, no markup.
    if type(uk) ~= "string" or uk == "" or uk == en or uk:find("[%a|{}]") or not uk:find("[\208-\210]") then return nil end
    return uk
end

-- One objective's text in Ukrainian, or nil to leave it as it is.
local function ObjectiveUk(o)
    if type(o) ~= "table" or type(o.text) ~= "string" or o.type == "monster" then return nil end
    local text = o.text
    local done, needed, name = text:match("^(%d+%s*/%s*)(%d+)%s+(.-)%s*$")
    if name then
        local uk = NameUk(name)
        return uk and (done .. needed .. " " .. uk) or nil
    end
    name, done = text:match("^(.-)%s*:%s*(%d+%s*/%s*%d+)%s*$")
    if name and name ~= "" then
        local uk = NameUk(name)
        return uk and (uk .. ": " .. done) or nil
    end
    return nil
end
W.ObjectiveUk = ObjectiveUk

-- A copy of the game's list with our names in, or nil when no line changed (the list is left alone).
local Prepare = UADD.Safe("dj", function(objectives)
    local copy, changed = {}, false
    for i, o in ipairs(objectives) do
        local uk = ObjectiveUk(o)
        if uk then
            local c = {}
            for k, v in pairs(o) do c[k] = v end
            c.text, changed = uk, true
            copy[i] = c
        else
            copy[i] = o
        end
    end
    return changed and copy or nil
end)

local function LocalizeObjectives(questID, objectives, ...)
    if type(objectives) == "table" and ns.Lang.Active() then
        local mine = Prepare(objectives)
        if type(mine) == "table" then
            local ok, out = pcall(origObjectives, questID, mine, ...)
            if ok then return out end
        end
    end
    return origObjectives(questID, objectives, ...)
end
W.LocalizeObjectives = LocalizeObjectives

-- ── Lines with a name in them ─────────────────────────────────────────────────────────────────
local origField, origL

local function Half(text) return text:find("%a") and text:find("[\208-\210]") and true or false end

-- What FDJ's own function gives in English (while held its GetLanguage gives English), or nil.
local function InEnglish(fn, ...)
    local was = ns.held
    ns.held = true
    local ok, out = pcall(fn, ...)
    ns.held = was
    return ok and type(out) == "string" and out or nil
end

-- Bodley's quests of one title: FDJ glues " (<item or boss>)" onto it, the item as the game says it.
-- The title and the name both ours, else the whole line English.
local Title = UADD.Safe("dj", function(out, questID, ...)
    local N = ns.Names
    if not out:find(")", -1, true) or out == N.Quest(questID) or not ns.Lang.Active() then return out end
    local i = out:find(" (", 1, true)
    if not (i and Half(out)) then return out end
    local title, name = out:sub(1, i - 1), out:sub(i + 2, -2)
    if not title:find("%a") then
        local uk = N.Item(name) or N.Boss(name) or NameUk(name)
        if uk and not Half(uk) then return title .. " (" .. uk .. ")" end
    end
    return InEnglish(origField, questID, "name", ...)
end)

local function LocalizeQuestField(questID, field, ...)
    local out = origField(questID, field, ...)
    if field ~= "name" or type(out) ~= "string" then return out end
    local whole = Title(out, questID, ...)
    return type(whole) == "string" and whole or out
end

-- "Click to swap with <dungeon>": the name is the card's text when it was picked, so it may be English
-- (no Ukrainian) or still Ukrainian while the key is held.
local PLACE = "REORDER_PLACE_TIP"

local function CardEnglish(label)
    local fdj = rawget(_G, "ForeverDungeonJournal_NS")
    for _, name in ipairs(type(fdj.HomeOrder) == "function" and fdj.HomeOrder() or {}) do
        if ns.Names.Dungeon(name) == label then return name end
    end
    return InEnglish(origL, "RPG_LOCKED_TIP_TITLE")     -- the one other label a card may have
end

local Place = UADD.Safe("dj", function(out, label)
    if type(label) ~= "string" or not Half(out) then return out end
    if ns.Lang.Active() then return InEnglish(origL, PLACE, label) end
    if ns.held and ns.Lang.Wants() then return InEnglish(origL, PLACE, CardEnglish(label)) end
    return out
end)

local function Text(key, ...)
    if key ~= PLACE then return origL(key, ...) end
    local out = origL(key, ...)
    local whole = Place(out, ...)
    return type(whole) == "string" and whole or out
end

function W.Install(fdj)
    if type(fdj.LocalizeQuestField) == "function" and fdj.LocalizeQuestField ~= LocalizeQuestField then
        origField, fdj.LocalizeQuestField = fdj.LocalizeQuestField, LocalizeQuestField
    end
    if type(fdj.L) == "function" and fdj.L ~= Text then origL, fdj.L = fdj.L, Text end
    if type(fdj.LocalizeFreeText) == "function" and fdj.LocalizeFreeText ~= LocalizeFreeText then
        orig, fdj.LocalizeFreeText = fdj.LocalizeFreeText, LocalizeFreeText
    end
    if type(fdj.LocalizeObjectives) == "function" and fdj.LocalizeObjectives ~= LocalizeObjectives then
        origObjectives, fdj.LocalizeObjectives = fdj.LocalizeObjectives, LocalizeObjectives
    end
end

-- Puts FDJ's functions back where nobody wrapped ours since.
function W.Uninstall(fdj)
    if origField and fdj.LocalizeQuestField == LocalizeQuestField then fdj.LocalizeQuestField = origField end
    if origL and fdj.L == Text then fdj.L = origL end
    if orig and fdj.LocalizeFreeText == LocalizeFreeText then fdj.LocalizeFreeText = orig end
    if origObjectives and fdj.LocalizeObjectives == LocalizeObjectives then fdj.LocalizeObjectives = origObjectives end
end
