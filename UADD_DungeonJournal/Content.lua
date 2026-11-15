-- The two tables the journal reads for a language, made for "ukUA":
--   FDJ.Locales.ukUA         its own UI words (ui/strings.lua; a missing key falls back to English
--                            in FDJ.L itself);
--   FDJ.ContentLocales.ukUA  names: dungeons (and where they are), bosses (and our word for the
--                            "Trash Drops" row), quest titles, the loot type words, and quest NPCs
--                            as whole "places" parts (FDJ.LocalizeFreeText).
-- Both are put in by Language.lua when the module is on and taken out again when it is off.
--
-- The names are read when the journal draws, so a name that arrives later shows on the next draw.
-- Each read also asks Screen.lua to look over the window on the next frame (fonts, item rows).
--
-- Long texts (quest objectives, notes, warnings, step descriptions) come from Prose.lua: quest
-- fields, and whole English texts in "places" (FDJ.LocalizeFreeText). No "replacements".

local _, ns = ...
local K = {}
ns.Content = K

-- While Search.lua searches in Ukrainian, names are handed out in lower case (FDJ lowers only
-- A-Z) and K.proper maps them back for the rows that show them.
K.folding = false
K.proper = {}

-- Lower case for Ukrainian and Russian Cyrillic (А-Я, Ѐ-Џ: І Ї Є, and Ґ) and for A-Z.
function K.Fold(s)
    if type(s) ~= "string" then return s end
    s = s:gsub("\208([\144-\159])", function(c) return "\208" .. string.char(c:byte() + 32) end)
    s = s:gsub("\208([\160-\175])", function(c) return "\209" .. string.char(c:byte() - 32) end)
    s = s:gsub("\208([\128-\143])", function(c) return "\209" .. string.char(c:byte() + 16) end)
    s = s:gsub("\210\144", "\210\145")
    return s:lower()
end

local function Show(uk)
    if not K.folding then return uk end
    local f = K.Fold(uk)
    K.proper[f] = uk
    return f
end

-- A name was read, so the journal draws: a look at its windows soon (Screen.lua), and the note
-- hook once the note exists. Both are skipped while a look is already on its way.
local function Touch()
    local S = ns.Screen
    if S and S.Pending() then return end
    if S then S.Schedule() end
    if ns.Prose then ns.Prose.HookNotes() end
end

local function Proxy(get)
    return setmetatable({}, { __index = function(_, key)
        Touch()
        return get(key)
    end })
end

-- The type line under a loot item, word by word ("Two-Hand, Axe"): the glossary's gear.* and item.*
-- entries, and prof.* for the recipes' professions. "Ring" -> "Каблучка".
local function SlotParts()
    local t = {}
    local G = UADD.Glossary
    for id, e in pairs(G and G.entries or {}) do
        if id:find("^gear%.") or id:find("^item%.") or id:find("^prof%.") then
            for _, en in ipairs(e.en or {}) do t[en] = e.uk end
        end
    end
    return t
end

-- The search list's second line, FDJ.DB[key].location: each comma part is a place name from UALL,
-- or one of the journal's own phrases with a place name in it. A part whose name UALL lacks stays
-- English, whole. K.PlaceNames: the names to ask UALL for (Names.lua).
-- The phrases are the journal's own words, so they are keyed by the hash of the English (UADD.Hash).
local PHRASES = {
    ["730591e7"] = "Під містом {zone:Ironforge}",
    ["0def0f81"] = "Зруйноване місто {zone:Lordaeron}",
}
local phraseOf = {}       -- English part -> its phrase, or false (each part is hashed once)
local function Phrase(part)
    if phraseOf[part] == nil then phraseOf[part] = PHRASES[UADD.Hash(part) or ""] or false end
    return phraseOf[part] or nil
end

local function Locations()
    local F = rawget(_G, "ForeverDungeonJournal_NS")
    return F and type(F.DB) == "table" and F.DB or {}
end

local function Parts(text)
    local out = {}
    for part in (type(text) == "string" and text or ""):gmatch("[^,]+") do
        part = part:gsub("^%s+", ""):gsub("%s+$", "")
        if part ~= "" then out[#out + 1] = part end
    end
    return out
end

function K.PlaceNames()
    local out = {}
    for _, d in pairs(Locations()) do
        for _, part in ipairs(Parts(type(d) == "table" and d.location)) do
            local phrase = Phrase(part)
            out[#out + 1] = phrase and phrase:match("{zone:([^{}]+)}") or part
        end
    end
    return out
end

function K.Location(key)
    local d, N = Locations()[key], ns.Names
    local parts = Parts(type(d) == "table" and d.location)
    local changed = false
    for i, en in ipairs(parts) do
        local phrase = Phrase(en)
        local uk = N.Dungeon(phrase and phrase:match("{zone:([^{}]+)}") or en)
        if uk then
            parts[i] = phrase and ns.Prose.Fill(phrase) or uk
            changed = true
        end
    end
    return changed and table.concat(parts, ", ") or nil
end

function K.Build()
    local N = ns.Names
    local prose, places = ns.Prose.Build()
    for en, uk in pairs(N.Npcs()) do places[en] = uk end
    local trash = UADD.Glossary.Text("game.trash_loot")
    return {
        dungeons = Proxy(function(key)
            local uk, where = N.Dungeon(key), K.Location(key)
            if not uk and not where then return nil end
            return { name = uk and Show(uk) or nil, location = where }
        end),
        bosses = Proxy(function(en)
            local uk = en == "Trash Drops" and trash or N.Boss(en)
            return uk and Show(uk) or nil
        end),
        quests = Proxy(function(id)
            local uk, p = N.Quest(id), prose[id]
            if not uk then return p end
            local e = { name = Show(uk) }
            for field, text in pairs(p or e) do e[field] = text end
            e.name = Show(uk)
            return e
        end),
        slotParts = SlotParts(),
        places = places,
    }
end

-- The UI words: FDJ.L reads active[key], so every read goes through here.
function K.Strings()
    local S = ns.uiStrings or {}
    return Proxy(function(key) return S[key] end)
end
