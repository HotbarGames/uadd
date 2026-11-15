-- Helpers for flow_dj_prose.py: the journal's long texts (UADD_DungeonJournal/Prose.lua) with a
-- small stand-in Ukrainian table made from the journal's live English. Reached as HARNESS.djp.
local H = HARNESS
local P = {}
H.djp = P
local function ns() return H.ns.UADD_DungeonJournal end
local function F() return ForeverDungeonJournal_NS end
local TAG = "UADDTEST"
P.UNKNOWN = "Nobody Uaddtest"

local function str(v) return type(v) == "string" and v ~= "" end
-- Does FDJ cut this note's closing line (the optional first-quest link) off? Prose.Cut knows that
-- line only by length and hash, so a note it does not cut comes back unchanged.
local function Cuts(en) return str(en) and ns().Prose.Cut(en) ~= en end

-- The quest (and its dungeon) with the most of objective, note and warning; a note that FDJ may
-- cut is left out. Then a second quest with an objective without commas, for the drift check.
local function Pick()
    local best, bestN, drift
    for key, d in pairs(F().DB) do
        for _, q in ipairs(type(d) == "table" and d.quests or {}) do
            if type(q.id) == "number" then
                local n = (str(q.objective) and 1 or 0) + (str(q.warning) and 1 or 0)
                    + (str(q.note) and not Cuts(q.note) and 1 or 0)
                if not best or n > bestN or (n == bestN and q.id < best[2].id) then best, bestN = { key, q }, n end
            end
        end
    end
    for _, d in pairs(F().DB) do
        for _, q in ipairs(type(d) == "table" and d.quests or {}) do
            if type(q.id) == "number" and q.id ~= best[2].id and str(q.objective) and q.objective ~= best[2].objective
                and not q.objective:find(",") and (not drift or q.id < drift.id) then drift = q end
        end
    end
    return best[1], best[2], drift
end

-- A note FDJ cuts the closing line off, and a Ukrainian with as many paragraphs.
local function CutNote()
    local found
    for _, d in pairs(F().DB) do
        for _, q in ipairs(type(d) == "table" and d.quests or {}) do
            local en = q.note
            if Cuts(en) and ns().Prose.Cut(en) ~= "" and (not found or en < found) then found = en end
        end
    end
    if not found then return nil end
    local _, n = found:gsub("\n\n", "")
    local parts = {}
    for i = 1, n do parts[i] = TAG .. "-cut" .. i end
    parts[#parts + 1] = TAG .. "-intro:"
    return found, table.concat(parts, "\n\n"), ns().Prose.Cut(found), table.concat(parts, "\n\n", 1, n)
end

-- A name UALL gave a Ukrainian for: Charlga Razorflank when it has one.
local function KnownNpc()
    local map = ns().Names.maps.Npc
    if map["Charlga Razorflank"] then return "Charlga Razorflank", map["Charlga Razorflank"] end
    local en
    for k, v in pairs(map) do if v ~= k and (not en or k < en) then en = k end end
    return en, en and map[en]
end

-- With the shipped data: quest entries and whole texts that match the journal's English now.
function P.shipped()
    local quests, places = ns().Prose.Build()
    local q, t = 0, 0
    for _ in pairs(quests) do q = q + 1 end
    for _ in pairs(places) do t = t + 1 end
    return q, t
end

-- The journal's warnings with %s (ns.proseTemplates: hashes only): how many of them were found in
-- the journal's other languages, how many we have, and how many FDJ.LocalizeFreeText gives as ours.
function P.templates()
    local Pr, want = ns().Prose, {}
    for _, h in ipairs(ns().proseTemplates or {}) do want[h] = true end
    local _, places = Pr.Build()
    local found, shown = 0, 0
    for en, uk in pairs(places) do
        if want[Pr.Key(en)] then
            found = found + 1
            if F().LocalizeFreeText(en) == uk then shown = shown + 1 end
        end
    end
    return found, H.count(ns().proseTemplates or {}), shown
end

-- FDJ.LocalizeQuestField gives our field without looking at the English it would show. So every
-- quest field we give must still be the translation of the journal's English as it is now (FDJ.DB
-- and QUEST_PREREQ_DETAILS, read again here): a journal that changes a text after our index was
-- built fails this. Returns the fields checked and the first few that differ.
function P.live()
    local Pr, data = ns().Prose, ns().proseData or {}
    local quests = Pr.Build()
    local en = {}               -- id -> field -> { English = true }
    local function Add(id, t)
        if id == nil or type(t) ~= "table" then return end
        for _, f in ipairs({ "objective", "note", "warning", "description" }) do
            if str(t[f]) then
                en[id] = en[id] or {}
                en[id][f] = en[id][f] or {}
                en[id][f][t[f]] = true
            end
        end
    end
    for _, d in pairs(F().DB) do
        for _, q in ipairs(type(d) == "table" and type(d.quests) == "table" and d.quests or {}) do
            if type(q) == "table" then Add(q.id, q) end
        end
    end
    for id, det in pairs(type(F().QUEST_PREREQ_DETAILS) == "table" and F().QUEST_PREREQ_DETAILS or {}) do
        Add(id, det)
    end
    local n, bad = 0, {}
    for id, fields in pairs(quests) do
        for f, ours in pairs(fields) do
            n = n + 1
            local one, many = nil, false
            for s in pairs(en[id] and en[id][f] or {}) do
                if one then many = true end
                one = one or s
            end
            local uk = one and not many and data[Pr.Key(one)]
            local want = uk and Pr.Fill(uk, one:find("%%s") ~= nil)
            if want ~= ours and #bad < 5 then bad[#bad + 1] = tostring(id) .. "." .. f end
        end
    end
    return n, table.concat(bad, ", ")
end

-- Puts the stand-in table in; returns what each text should now show.
function P.setup()
    local Pr = ns().Prose
    P.saved = { ns().proseData, ns().proseQuests, ns().proseTemplates }
    local dungeon, q, drift = Pick()
    local npc, npcUk = KnownNpc()
    local data, want = {}, { dungeon = dungeon, id = q.id, enObjective = q.objective, enNote = q.note,
        enWarning = q.warning, npc = npc, npcUk = npcUk, driftId = drift and drift.id,
        driftEn = drift and drift.objective }
    if str(q.objective) then
        data[Pr.Key(q.objective)] = TAG .. "-O {npc:" .. npc .. "}"
        want.objective = TAG .. "-O " .. npcUk
    end
    if str(q.note) and not Cuts(q.note) then
        data[Pr.Key(q.note)] = TAG .. "-N {npc:" .. P.UNKNOWN .. "}"
        want.note = TAG .. "-N " .. P.UNKNOWN
    end
    if str(q.warning) then
        data[Pr.Key(q.warning)] = TAG .. "-W"
        want.warning = TAG .. "-W"
    end
    if drift then data[Pr.Key(drift.objective .. " (older text)")] = TAG .. "-DRIFT" end
    local cutFull, cutUk, cutEn, cutUkCut = CutNote()
    if cutFull then
        data[Pr.Key(cutFull)] = cutUk
        want.cutEn, want.cutUk = cutEn, cutUkCut
    end
    Pr.Use(data, {}, {})
    ns().OnNames()
    return want
end

function P.restore()
    ns().Prose.Use(P.saved[1], P.saved[2], P.saved[3])
    ns().OnNames()
end

function P.field(id, field, fallback) return F().LocalizeQuestField(id, field, fallback) end
-- What FDJ gives on its own in its own language (call it while ours is not shown): its own
-- table's field, else the English. Read from FDJ's tables, not through our wrappers.
function P.own(id, field, fallback)
    local c = F().ContentLocales[F().GetLanguage()]
    local e = c and c.quests and c.quests[id]
    local v = e and e[field]
    if type(v) == "string" and v ~= "" then return v end
    return fallback
end

function P.open(dungeon, id)
    F().OpenQuestPage(dungeon, id)
    H.step(0.05)
end

-- Is `sub` part of a shown text under the journal?
function P.shown(sub)
    local list = H.dj.visible(ForeverDungeonJournalFrame)
    for i = 1, H.count(list) do
        if list[i]:find(sub, 1, true) then return true end
    end
    return false
end

-- The tracker's worded objective line for the quest.
function P.tracker(id)
    local out = F().LocalizeObjectives(id, { { text = "Speak with someone", finished = false } }, nil, false)
    return out and out[1] and out[1][1]
end

-- The cut note: FDJ writes `en` on its note text; what shows.
function P.note(en)
    local fs = ForeverDungeonJournalFrame.questNotesText
    if en then fs:SetText(en) end
    return fs:GetText()
end
function P.restoreNotes() ns().Prose.Restore() end

-- The cut note written twice in combat: what shows then, and how many page redraws (L.Light)
-- the end of combat brings, firing the event twice (one wait, nothing stacked).
function P.noteInCombat(en)
    local L = ns().Lang
    local light, lights = L.Light, 0
    L.Light = function(...) lights = lights + 1 return light(...) end
    H.combat = true
    P.note(en)
    local during = P.note(en)
    H.combat = false
    H.fire("PLAYER_REGEN_ENABLED")
    H.fire("PLAYER_REGEN_ENABLED")
    L.Light = light
    return during, lights
end
