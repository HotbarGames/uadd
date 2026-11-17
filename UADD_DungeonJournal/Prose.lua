-- The journal's long texts in Ukrainian: quest objectives, notes, warnings and step descriptions.
--
-- data/prose.lua (made by tools/make_dj_prose_data.py) maps a key to the Ukrainian text. The key
-- is djb2 of the journal's English, taken live from its own data (FDJ.DB quests and
-- QUEST_PREREQ_DETAILS, read only). When the journal changes a text, its key changes, so that
-- text stays English instead of showing an old translation.
--
-- The Ukrainian goes into our own ukUA content table only (Content.lua):
--   * quests[id].objective / note / warning / description, for FDJ.LocalizeQuestField (the quest
--     page and the tracker's worded objective line);
--   * places[English] = Ukrainian, for FDJ.LocalizeFreeText: the 3 warnings built with %s, and a
--     quest id whose text differs between two dungeons (that id gets no quest field).
--     The English of the 3 warnings is in no table we read for quests: the journal's own other
--     languages have them as "places" keys (FDJ.ContentLocales[lang].places), so they are found
--     there by their hash (ns.proseTemplates).
-- Placeholders ({npc:..} {item:..} {zone:..} {quest:..}) are filled with UALL names when the table
-- is built; a name UALL lacks stays English. Names.lua asks UALL for these names too.
--
-- One text is out of reach of the tables: for one faction the journal cuts a note's closing line
-- (the link to an optional first quest) off and shows the cut note as it is. That line is known
-- here by its length and hash only (CUT). That FontString's SetText is hooked; the English is put
-- back when our language is not shown (module off, Shift held, another language).
--
-- Combat: the first read of the journal's English (the index) waits for the end of combat, and so
-- does putting our text on the cut note; each sets one flag and is done once after combat ends.
-- Build (names arriving, once the index exists) and Restore ("/uadd dj off", another language)
-- can still run in combat: Build only fills our own tables, Restore only calls SetText on the
-- journal's plain (not secure) note text. Neither taints anything. Shift's Restore comes with the
-- redraw (Lang.Light), which waits for the end of combat.

local _, ns = ...
local P = {}
ns.Prose = P

local FIELDS = { "objective", "note", "warning", "description" }
-- The closing line the journal cuts off a note: its length in bytes and its hash.
local CUT = { len = 28, hash = "852e682d" }
local KINDS = { npc = "Npc", item = "Item", zone = "zones", quest = "Quest" }

local idx                 -- the English the journal has, built once (P.Use resets it)
P.cut = {}                -- cut English note -> filled Ukrainian

-- djb2 of the English, 8 hex digits: the core's hash (UADD/Hash.lua), as tools/hashtext.py makes it.
function P.Key(s) return UADD.Hash(s) end

-- The note as the journal shows it once it has cut the closing line (and the white space around
-- it) off the end; the note itself when it does not end with that line.
function P.Cut(en)
    local s = en:gsub("%s+$", "")
    if #s < CUT.len or P.Key(s:sub(-CUT.len)) ~= CUT.hash then return en end
    return (s:sub(1, -CUT.len - 1):gsub("%s+$", ""))
end

-- The English of the templates (ns.proseTemplates: their hashes), from the "places" keys of the
-- journal's other languages. Only keys with a %s are hashed.
local function Templates(F)
    local want = {}
    for _, h in ipairs(ns.proseTemplates or {}) do want[h] = true end
    local out = {}
    if not next(want) then return out end
    local all = type(F) == "table" and rawget(F, "ContentLocales")
    for lang, c in pairs(type(all) == "table" and all or {}) do
        local places = lang ~= "ukUA" and type(c) == "table" and rawget(c, "places")
        for en in pairs(type(places) == "table" and places or {}) do
            if type(en) == "string" and en:find("%s", 1, true) and want[P.Key(en)] then out[en] = true end
        end
    end
    return out
end

-- Test data in place of data/prose.lua (the harness).
function P.Use(data, quests, templates)
    ns.proseData, ns.proseQuests, ns.proseTemplates = data, quests or {}, templates or {}
    idx = nil
end

local function Index()
    if idx then return idx end
    local F = ForeverDungeonJournal_NS
    local data = ns.proseData or {}
    local I = { byId = {}, tr = {}, cut = {} }
    local function Text(en)
        if I.tr[en] == nil then I.tr[en] = data[P.Key(en)] or false end
        return I.tr[en] or nil
    end
    local function Add(id, field, en)
        if type(en) ~= "string" or en == "" or id == nil then return end
        local uk = Text(en)
        local q = I.byId[id] or {}
        I.byId[id] = q
        if q[field] == nil then q[field] = en elseif q[field] ~= en then q[field] = false end
        local cut = field == "note" and P.Cut(en)
        if uk and cut and cut ~= en and cut ~= "" then
            local _, n = en:gsub("\n\n", "")
            local _, m = uk:gsub("\n\n", "")
            local head = n == m and uk:match("^(.*)\n\n")
            if head then I.cut[cut] = head:gsub("%s+$", "") end
        end
    end
    local function Fields(id, t)
        if type(t) ~= "table" then return end
        for _, f in ipairs(FIELDS) do Add(id, f, t[f]) end
    end
    for _, d in pairs(type(F and F.DB) == "table" and F.DB or {}) do
        for _, q in ipairs(type(d) == "table" and type(d.quests) == "table" and d.quests or {}) do
            if type(q) == "table" then Fields(q.id, q) end
        end
    end
    for id, det in pairs(type(F and F.QUEST_PREREQ_DETAILS) == "table" and F.QUEST_PREREQ_DETAILS or {}) do
        Fields(id, det)
    end
    for en in pairs(Templates(F)) do Text(en) end
    idx = I
    return I
end

-- A Ukrainian text with its names filled in. `fmt`: the text goes through string.format.
function P.Fill(uk, fmt)
    local N = ns.Names
    return (uk:gsub("{(%a+):([^{}]+)}", function(kind, en)
        local name
        if kind == "npc" then name = N.maps.Npc[en]
        elseif kind == "item" then name = N.Item(en)
        elseif kind == "zone" then name = N.Dungeon(en)
        elseif kind == "quest" then
            local id = ns.proseQuests and ns.proseQuests[en]
            name = id and N.Quest(id)
        end
        name = type(name) == "string" and name or en
        return fmt and (name:gsub("%%", "%%%%")) or name
    end))
end

-- Work held back until combat ends, one flag each so nothing stacks: `names` (the table was asked
-- for before the index existed) and `note` (the cut note was left English).
local wait = {}
local later = CreateFrame("Frame")
later:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    local names, note = wait.names, wait.note
    wait.names, wait.note = nil, nil
    if names and ns.OnNames then
        UADD.SafeCall(ns.OnNames)                 -- a new table, then the open page again
    elseif note and ns.Lang and ns.Lang.Active() then
        UADD.SafeCall(ns.Lang.Light)              -- the open page again: the note goes through OnNote
    end
end)
local function Later(what)
    wait[what] = true
    later:RegisterEvent("PLAYER_REGEN_ENABLED")
end

-- quests: id -> { field = Ukrainian }; places: English -> Ukrainian. Empty in combat (built after).
function P.Build()
    if not idx and InCombatLockdown and InCombatLockdown() then
        Later("names")
        return {}, {}
    end
    local I = Index()
    local quests, places = {}, {}
    for en, uk in pairs(I.tr) do
        if uk then places[en] = P.Fill(uk, en:find("%%s") ~= nil) end
    end
    for id, fields in pairs(I.byId) do
        for field, en in pairs(fields) do
            if en and places[en] then
                quests[id] = quests[id] or {}
                quests[id][field] = places[en]
            end
        end
    end
    local cut = {}
    for en, uk in pairs(I.cut) do cut[en] = P.Fill(uk) end
    P.cut = cut
    return quests, places
end

-- Names to ask UALL for: { kind, English, id } (kinds as in Names.lua).
function P.Names()
    local out, seen = {}, {}
    for _, uk in pairs(ns.proseData or {}) do
        for kind, en in uk:gmatch("{(%a+):([^{}]+)}") do
            local k = KINDS[kind]
            local id = k == "Quest" and ns.proseQuests and ns.proseQuests[en] or nil
            if k and not seen[kind .. en] and (k ~= "Quest" or id) then
                seen[kind .. en] = true
                out[#out + 1] = { k, en, id }
            end
        end
    end
    return out
end

-- ── The cut note ──────────────────────────────────────────────────────────────────────────────

local shown = {}          -- FontString -> { English, Ukrainian } while it shows ours
local guard = false
local hooked

local function OnNote(fs, text)
    if guard then return end
    shown[fs] = nil
    if not (ns.Lang and ns.Lang.Active()) then return end
    text = UADD.Plain(text)                -- a secret text (combat): left as it is
    local uk = text and P.cut[text]
    if not uk then return end
    if InCombatLockdown and InCombatLockdown() then return Later("note") end   -- English until then
    guard = true
    fs:SetText(uk)
    guard = false
    shown[fs] = { text, uk }
end

-- Once the journal's note text exists (it is made with the journal's window).
function P.HookNotes()
    if ns.Built then ns.Built.Install() end   -- the summon line and the joined-item row
    if hooked then return end
    local f = rawget(_G, "ForeverDungeonJournalFrame")
    local fs = type(f) == "table" and f.questNotesText
    if type(fs) ~= "table" or not fs.SetText then return end
    hooked = true
    hooksecurefunc(fs, "SetText", OnNote)
end

-- The English back on every note that still shows ours.
function P.Restore()
    for fs, t in pairs(shown) do
        if UADD.Plain(fs:GetText()) == t[2] then
            guard = true
            fs:SetText(t[1])
            guard = false
        end
        shown[fs] = nil
    end
end
