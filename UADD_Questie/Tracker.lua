-- UADD - Questie: Ukrainian in Questie's quest tracker (the list of quests on the screen).
--
-- Questie draws the tracker from what the game's quest log says, so it is English even when
-- Questie itself speaks Ukrainian. We wrap three Questie functions that turn quest data into text.
-- Each wrapper hands back Ukrainian in the same call, so the line is drawn once, already
-- translated (no flicker), and a reused line always gets fresh text. Lines this depends on
-- (Questie 12.6.4, Modules/Tracker/):
--   TrackerData.lua:116-119        objective.questId, .Type and .Description (the game's own text)
--   TrackerData.lua:264-281        GetColoredQuestName(displayQuest, ...) builds the title from
--                                  displayQuest.name and .Id (level, "(Complete)", colour)
--   TrackerData.lua:296-303        GetObjectiveText(objective) returns colour .. objective.Description
--   LineBuilder.lua:51-99          AddHeader(options): options.key is the zone, kept English
--                                  (collapsed zones are saved by it); options.text is shown
--   Sections/QuestSection.lua:87   AddHeader({ key = zoneName, text = zoneName })
--   Sections/QuestSection.lua:133-135, 218 and LinePool/TrackerLinePool.lua:405 call the two
--                                  TrackerData functions through the module table, so our
--                                  wrappers are the ones that run.
-- We never change Questie's data or saved settings. With UADD off, or names not collected yet,
-- every wrapper passes Questie's own text through untouched.

local _, ns = ...
local T = {}
ns.Tracker = T
local L, N = ns.Locale, ns.Names

local function Module(name)
    local ok, mod = pcall(function() return QuestieLoader:ImportModule(name) end)
    return ok and type(mod) == "table" and mod or nil
end

-- Off while the show-original key is held (Original.lua): then Questie's English goes through.
local function Active()
    return L.state == "on" and L.IsActive() and not (ns.Original and ns.Original.held)
end

local function Text(s)
    return UADD.Plain(s) and s ~= "" and s or nil
end

-- ── Names for one quest ───────────────────────────────────────────────────────────────────────

-- For each quest: { Item = { [English] = "назва" }, Npc = {...} }, built from this quest's own
-- objectives in QuestieDB. A name is used only when it is exactly the game's English text, and
-- not at all when two of the quest's ids share an English name but not a Ukrainian one.
-- Only quests the tracker shows get an entry; all of it is dropped when the names change.
local perQuest, builtFor = {}, nil

local function AddName(names, dt, id)
    local uk = type(id) == "number" and N.maps[dt] and Text(N.maps[dt][id])
    if not uk then return end
    local fixed, raw = N.EnglishNames(dt, id)
    for _, en in ipairs({ Text(fixed) or false, Text(raw) or false }) do
        if en then
            local had = names[dt][en]
            if had == nil then names[dt][en] = uk elseif had ~= uk then names[dt][en] = false end
        end
    end
end

-- Quest fields as QuestieDB has them, and its correction on top when there is one.
local function QuestFields(id, key, index)
    local q, out = _G.LibQuestieDB and _G.LibQuestieDB.Quest, {}
    if type(q) ~= "table" then return out end
    local ok, raw = pcall(q.GetRaw, id, key)
    if ok and type(raw) == "table" then out[#out + 1] = raw end
    local layer = type(q.overlay) == "table" and q.overlay[id]
    if type(layer) == "table" and type(layer[index]) == "table" then out[#out + 1] = layer[index] end
    return out
end

-- objectives: [1] creatures { {id, text}, ... }, [3] items { {id, text}, ... },
-- [5] kill credit { {ids}, baseId, baseText, icon } (QuestieDB src/meta/normalize.lua:191).
local function Build(questId)
    local names = { Item = {}, Npc = {} }
    for _, obj in ipairs(QuestFields(questId, "objectives", 10)) do
        for _, e in ipairs(type(obj[1]) == "table" and obj[1] or {}) do
            if type(e) == "table" then AddName(names, "Npc", e[1]) end
        end
        for _, e in ipairs(type(obj[3]) == "table" and obj[3] or {}) do
            if type(e) == "table" then AddName(names, "Item", e[1]) end
        end
        local credit = obj[5]
        if type(credit) == "table" then
            local list = type(credit[1]) == "table" and type(credit[1][1]) == "table" and credit or { credit }
            for _, e in ipairs(list) do
                if type(e) == "table" then
                    for _, id in ipairs(type(e[1]) == "table" and e[1] or {}) do AddName(names, "Npc", id) end
                    AddName(names, "Npc", e[2])
                end
            end
        end
    end
    for _, list in ipairs(QuestFields(questId, "requiredSourceItems", 21)) do
        for _, id in ipairs(list) do AddName(names, "Item", id) end
    end
    return names
end

local function QuestNames(questId)
    if builtFor ~= N.version then perQuest, builtFor = {}, N.version end
    local names = perQuest[questId]
    if not names then
        names = Build(questId)
        perQuest[questId] = names
    end
    return names
end

-- ── Objective lines ───────────────────────────────────────────────────────────────────────────

local KIND = { item = "Item", monster = "Npc" }

local function Complete()
    local l10n = L.Questie_l10n()
    return " " .. l10n("(") .. l10n("Complete") .. l10n(")")
end

-- "0/8 Witchwing Talon" -> "0/8 Кіготь ...", "0/15 Defias Pillager slain" -> "0/15 убито: ...",
-- "Witchwing Talon: 0/8" -> "...: 0/8". Anything else, or a name we do not know: nil.
function T.Objective(questId, objectiveType, text)
    if type(questId) ~= "number" or not Text(text) then return nil end
    local core, done = text:match("^(.-)%s*(%(Complete%))$")
    core = core or text
    local names, kind = QuestNames(questId), KIND[objectiveType]
    local function Name(en)
        local mob = en:match("^(.-) slain$")
        if mob then return names.Npc[mob] or nil, true end
        return kind and names[kind][en] or nil, false
    end
    local out
    local counter, rest = core:match("^(%d+/%d+)%s+(.+)$")
    if counter then
        local uk, slain = Name(rest)
        out = uk and (counter .. (slain and " убито: " or " ") .. uk)
    else
        local head, count = core:match("^(.-)%s*:%s*(%d[%d/%s]*)$")
        local uk, slain = head and Name(head)
        out = uk and (uk .. (slain and " (убито): " or ": ") .. count)
    end
    if out and done then out = out .. Complete() end
    return out
end

-- ── The wrappers ──────────────────────────────────────────────────────────────────────────────

local function QuestTitle(displayQuest)
    local id = type(displayQuest) == "table" and displayQuest.Id
    return type(id) == "number" and N.maps.Quest and Text(N.maps.Quest[id])
end

local function ZoneName(options)
    if type(options) ~= "table" or options.collapsedText ~= nil or options.text ~= options.key then return nil end
    local l10n = L.Questie_l10n()
    local entry = l10n and type(options.text) == "string" and l10n.translations[options.text]
    local uk = type(entry) == "table" and entry[L.LOCALE]
    return L.SafeName(uk) and uk or nil
end

-- Our own part never breaks Questie: any error in it means "no translation".
local function Try(fn, ...)
    local ok, result = pcall(fn, ...)
    return ok and result or nil
end

local function ColoredQuestName(original)
    return function(displayQuest, ...)
        local uk = Try(function() return Active() and QuestTitle(displayQuest) end)
        if not uk then return original(displayQuest, ...) end
        local en = displayQuest.name
        displayQuest.name = uk               -- for this one call only, so the level and suffixes stay Questie's
        local ok, text = pcall(original, displayQuest, ...)
        displayQuest.name = en
        if ok then return text end
        return original(displayQuest, ...)
    end
end

local function ObjectiveText(original)
    return function(objective, ...)
        local text = original(objective, ...)
        return Try(function()
            local desc = Active() and type(objective) == "table" and Text(objective.Description)
            if not desc or not UADD.Plain(text) or text:sub(-#desc) ~= desc then return nil end
            local uk = T.Objective(objective.questId, objective.Type, desc)
            return uk and (text:sub(1, #text - #desc) .. uk)
        end) or text
    end
end

local function Header(original)
    return function(options, ...)
        local uk = Try(function() return Active() and ZoneName(options) end)
        if not uk then return original(options, ...) end
        local copy = {}
        for k, v in pairs(options) do copy[k] = v end
        copy.text = uk                       -- key stays English
        return original(copy, ...)
    end
end

-- ── The letter after the level: "[34D]" ───────────────────────────────────────────────────────
-- QuestieLib:GetQuestTypeSuffix (Modules/Libs/QuestieLib.lua:247-287) takes the first BYTE of the
-- tag name, except in Chinese, Korean and Russian, where it picks a Latin letter by tag id. Some
-- tag names come from Questie's own list (Database/Corrections/questTagInfoCorrections.lua, e.g.
-- [1102] = {81, l10n("Dungeon")}), and that is "Підземелля" in Ukrainian: its first byte is half
-- of a letter, which the font draws as a box. Then we give Questie's own Latin letter instead.
-- This stays on after "/uadd questie off": those tag names stay Ukrainian until /reload.
local LETTER = { RAID = "R", RAID_10 = "R", RAID_25 = "R", DUNGEON = "D", HEROIC = "H",
    SCENARIO = "S", ACCOUNT = "A", CELESTIAL = "C", WORLD_EVENT = "W" }

function T.TagLetter(questId)
    local DB = Module("QuestieDB")
    local id = DB and type(DB.GetQuestTagInfo) == "function" and DB.GetQuestTagInfo(questId)
    for name, letter in pairs(LETTER) do
        if id ~= nil and type(DB.questTagIds) == "table" and DB.questTagIds[name] == id then return letter end
    end
    return ""
end

local suffixDone
local function InstallSuffix()
    local lib = Module("QuestieLib")
    local original = lib and lib.GetQuestTypeSuffix
    if suffixDone or type(original) ~= "function" then return end
    suffixDone = true
    lib.GetQuestTypeSuffix = function(self, questId, ...)
        local s = original(self, questId, ...)
        if not UADD.Plain(s) or not s:find("[\128-\255]") then return s end
        return Try(T.TagLetter, questId) or ""
    end
end

local wrapped = {}

local function Wrap(moduleName, key, make)
    local mod = Module(moduleName)
    local original = mod and mod[key]
    if type(original) ~= "function" then return false end
    local wrapper = make(original)
    mod[key] = wrapper
    wrapped[#wrapped + 1] = { mod = mod, key = key, original = original, wrapper = wrapper }
    return true
end

-- At our ADDON_LOADED, before the tracker is first drawn. Returns how many wrappers are in.
function T.Install()
    InstallSuffix()
    if #wrapped > 0 then return #wrapped end
    Wrap("TrackerData", "GetColoredQuestName", ColoredQuestName)
    Wrap("TrackerData", "GetObjectiveText", ObjectiveText)
    Wrap("LineBuilder", "AddHeader", Header)
    return #wrapped
end

-- /uadd questie off: put Questie's functions back (unless someone wrapped them after us).
function T.Uninstall()
    for i = #wrapped, 1, -1 do
        local w = wrapped[i]
        if w.mod[w.key] == w.wrapper then w.mod[w.key] = w.original end
        wrapped[i] = nil
    end
    perQuest, builtFor = {}, nil
end

-- Redraw the tracker now (Questie skips it in combat and draws again later).
function T.Refresh()
    pcall(function()
        local tracker = Module("QuestieTracker")
        if tracker and type(tracker.Update) == "function" then tracker:Update() end
    end)
end
