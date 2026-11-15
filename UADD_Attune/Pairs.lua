-- Our tables as (English, Ukrainian) pairs, for Words.lua. The repo keeps none of Attune's English: each
-- English text is read from Attune's own AttuneLang (rawget, never written) by the keys of our tables.
--   * ui/locale.lua: ns.UA by locale key; ns.UA_CATEGORY by a category's key (its value, and the value in
--     sentence case as the options list shows it); ns.UA_GLUED by the key of a word Attune glues to a
--     number or a name ({ shape, uk }: {} in the shape is AttuneLang[key]); ns.UA_STEP_TYPE by a step TYPE
--     value (only what is shown changes, step.TYPE stays as it is). ui/notes.lua: ns.UA_NOTES, by N2_<id>.
--   * data/hashed.lua (made by tools/make_att_text.py), by "<bytes>:<hash>" (UADD.Hash): ns.UA_KEYHASH and
--     ns.UA_GLUEHASH are locale keys that are English sentences, found by hashing AttuneLang's keys.
--     (ns.UA_TEXTHASH, English Attune writes in its code, is looked up by the shown text: Words.lua.)
-- A key missing in AttuneLang gives no pair: its text stays English.
-- Below the pairs, ns.Slots: what each template place may hold.

local _, ns = ...

-- Keys that stay English: the guild line goes to other players, the request line is saved in the Survey Log.
local NEVER = { AttuneCompleteGuild = true, ReceivedRequestFrom = true }

-- Calls add(english, ukrainian, key) for every pair, in a fixed order where it matters: the same English
-- under two locale keys takes the first key's Ukrainian. `key`: the ns.UA locale key, else nil.
function ns.Pairs(add)
    local lang = rawget(_G, "AttuneLang")
    lang = type(lang) == "table" and lang or {}
    local function L(key)
        local v = type(key) == "string" and rawget(lang, key)
        return type(v) == "string" and v or nil
    end
    -- Locale keys kept by hash: AttuneLang's keys of those lengths, each hashed once.
    local want, byHash = {}, {}
    for _, t in ipairs({ ns.UA_KEYHASH or {}, ns.UA_GLUEHASH or {} }) do
        for h in pairs(t) do
            local n = tonumber(tostring(h):match("^(%d+):"))
            if n then want[n] = true end
        end
    end
    for key in pairs(lang) do
        if type(key) == "string" and want[#key] then byHash[#key .. ":" .. UADD.Hash(key)] = key end
    end
    local rows = {}
    for key, uk in pairs(ns.UA or {}) do if not NEVER[key] then rows[#rows + 1] = { key, uk, key } end end
    for h, uk in pairs(ns.UA_KEYHASH or {}) do if byHash[h] then rows[#rows + 1] = { byHash[h], uk } end end
    table.sort(rows, function(a, b) return a[1] < b[1] end)
    for _, r in ipairs(rows) do add(L(r[1]), r[2], r[3]) end
    -- Lines glued from a locale word and a number or name: the shape with the word's text at {}.
    for _, t in ipairs({ ns.UA_GLUED or {}, ns.UA_GLUEHASH or {} }) do
        for key, v in pairs(t) do
            local text = L(byHash[key] or key)
            if text and type(v) == "table" and type(v[1]) == "string" then
                add((v[1]:gsub("{}", function() return text end)), v[2])
            end
        end
    end
    -- Categories: the tree shows the value as it is, the options list it in sentence case.
    for key, uk in pairs(ns.UA_CATEGORY or {}) do
        local v = L(key)
        if v then
            add(v, uk)
            add((v:lower():gsub("^%l", string.upper)), uk)
        end
    end
    -- Step type labels: Attune shows AttuneLang[step.TYPE].
    for value, uk in pairs(ns.UA_STEP_TYPE or {}) do add(L(value) or value, uk) end
    -- NPC notes: the English is Attune's own N2_<id> text.
    for key, uk in pairs(ns.UA_NOTES or {}) do add(L(key), uk) end
end

-- ── What a place may hold (ns.Slots) ──────────────────────────────────────────────────────────────

-- What a template's ##PLACE## may hold, for Words.lua. A place that holds anything else means the text is
-- another one that only starts or ends like this template: the template does not fit, the next one is
-- tried, and when none fits the whole text stays English. A line is never half translated.
-- Each place has a kind:
--   * value: a number, an amount, a time or a version ("5", "1h 5min 3sec", "16001-41"). Kept as it is.
--   * player: a player's name, kept as it is: one or two words, each starting with a capital letter,
--     maybe with "-Realm", no digits or codes.
--   * target: a name a player typed or targeted: one word (any case) or a player's name. Kept as it is.
--   * attune: an attunement's name: translated, or the English name of one of Attune's attunements.
--   * step: a step's name or kind: translated, a value, empty, or one of Attune's own names in English
--     (a quest, NPC, item, zone, step or attunement name from Attune's tables).
--   * faction: translated, or a faction name from the glossary (in Ukrainian) or the game's own.
--   * text (any other place): must be translated.
-- BYKEY gives a place another kind in one locale key's text (keys only, no English here).
-- Attune's tables are only read, never written.

local S = {}
ns.Slots = S

local KIND = {
    VERSION = "value", COUNT = "value", DURATION = "value", LEVEL = "value", NUMBER = "value",
    SIZE = "value", SKILL = "value", NB = "value",
    PLAYER = "player", FROM = "player", TO = "target",
    NAME = "attune", STEP = "step", TYPE = "step", FACTION = "faction", WHAT = "text",
}
-- In these two lines ##NAME## is the player the data goes to or comes from.
local BYKEY = { SendingDataTo = { NAME = "player" }, ReceivedDataFromName = { NAME = "player" } }
local FREE = { value = true, player = true, target = true }
local FACTIONS = { "game.alliance", "game.horde" }

local own, attunes = {}, {}       -- English -> true: Attune's own names / its attunements' names

-- The kind of place `name` in the text of locale key `key` (nil for a text found by hash).
function S.Kind(name, key)
    local over = type(key) == "string" and BYKEY[key]
    return over and over[name] or KIND[name] or "text"
end

-- A free place keeps what it holds as it is, so it is not looked up (and holds one line only).
function S.Free(kind) return FREE[kind] == true end

-- A number, amount or time: no letters once colours and icons are gone, or only short units right
-- after a digit ("45sec", "3min", "1h").
local function IsValue(c)
    c = c:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
    local from = 1
    while true do
        local a, b = c:find("%a+", from)
        if not a then return true end
        if b - a > 2 or a == 1 or not c:find("^%d", a - 1) then return false end
        from = b + 1
    end
end

-- A name: one or two words of letters, maybe "-Realm". `anyCase`: one word may start in lower case.
local function IsName(c, anyCase)
    if c == "" or #c > 48 or c:find("[%c|%d]") or c:find("^ ") or c:find(" $") or c:find("  ") then
        return false
    end
    local base, realm = c:match("^(.-)%-([^%- ]+)$")
    if realm and realm:find("[^%a\128-\255]") then return false end
    local words = {}
    for w in (base or c):gmatch("[^ ]+") do words[#words + 1] = w end
    if #words == 0 or #words > 2 then return false end
    for _, w in ipairs(words) do
        if w:find("[^%a\128-\255]") then return false end
        local up = w:find("^%u") or w:byte(1) >= 0xC3     -- a capital, or a letter like "Ä"
        if not up and not (anyCase and #words == 1) then return false end
    end
    return true
end

-- The faction's Ukrainian from the glossary, the game's own faction name as it is, or nil.
local function Faction(c)
    local G = UADD.Glossary
    for _, id in ipairs(FACTIONS) do
        local e = G and G.entries and G.entries[id]
        for _, en in ipairs(type(e) == "table" and type(e.en) == "table" and e.en or {}) do
            if en == c then return UADD.Glossary.Text(id) end
        end
    end
    for _, g in ipairs({ "FACTION_ALLIANCE", "FACTION_HORDE" }) do
        if rawget(_G, g) == c then return c end
    end
    local ok, _, mine = pcall(UnitFactionGroup, "player")
    if ok and type(mine) == "string" and mine == c then return c end
    return nil
end

-- What a place of `kind` shows for c, which our tables did not translate: c as it is, its Ukrainian,
-- or nil (c does not belong there: the template does not fit).
function S.Keep(kind, c)
    if type(c) ~= "string" then return nil end
    if kind == "value" then return IsValue(c) and c or nil end
    if kind == "player" then return IsName(c) and c or nil end
    if kind == "target" then return IsName(c, true) and c or nil end
    if kind == "attune" then return attunes[c] and c or nil end
    if kind == "step" then return (IsValue(c) or own[c]) and c or nil end
    if kind == "faction" then return Faction(c) end
    return nil
end

-- Attune's own names, read again (Words.Build).
function S.Build()
    own, attunes = {}, {}
    if ns.Names and ns.Names.Own then own, attunes = ns.Names.Own() end
end

S.IsValue, S.IsName = IsValue, IsName      -- for the checks
