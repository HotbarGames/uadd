-- Dungeon, wing, boss, quest NPC, quest and item names in Ukrainian, asked from UALL Forever
-- (UADD.UALL) in the background by the shared runner (UADD/Collector.lua).
--
-- The English names come from the journal's own data (ForeverDungeonJournal_NS.DB), read only.
-- A name with ": " is asked whole first ("Excavation Site: Wetlands", "Dire Maul: East"). Without
-- an answer, a wing ("Stratholme: Living") is the dungeon's name, ": " and the wing word: the
-- glossary's wing.* entry first, then UALL's word for the wing.
-- Names Questie's module already collected (UADD_DB.modules.questie.cache) are taken by id,
-- without asking UALL again, when that copy was made under the same UALL rules, versions, game
-- build and routes (N.Basis). A name UALL lacks stays English.
-- The results are saved in UADD_DB under a signature, like Questie's (UADD_Questie/Names.lua).

local _, ns = ...
local U = UADD
local C = U.Collector
local N = {}
ns.Names = N

N.KINDS = { "zones", "Npc", "Quest", "Item" }
N.maps = { zones = {}, Npc = {}, Quest = {}, Item = {} }   -- zones/Npc/Item by English, Quest by id
N.version = 0
local runner = C.New()

local function Journal() return rawget(_G, "ForeverDungeonJournal_NS") end
local function Data()
    local fdj = Journal()
    return fdj and type(fdj.DB) == "table" and fdj.DB or {}
end

function N.Split(key)
    local base, wing = key:match("^(.-): (.+)$")
    return base or key, wing
end

local function Word(id)
    local e = U.Glossary and U.Glossary.entries[id]
    return e and e.uk or nil
end

-- ── Reading names (called while the journal draws) ────────────────────────────────────────────

function N.Dungeon(key)
    if type(key) ~= "string" then return nil end
    local z = N.maps.zones
    if z[key] then return z[key] end
    local base, wing = N.Split(key)
    if not wing then return nil end
    local b, w = z[base], Word("wing." .. wing:lower()) or z[wing]
    if b and w then return b .. ": " .. w end
    return nil
end

function N.Boss(en) return type(en) == "string" and N.maps.Npc[en] or nil end
function N.Quest(id) return N.maps.Quest[id] end
function N.Item(en) return type(en) == "string" and N.maps.Item[en] or nil end
function N.Npcs() return N.maps.Npc end
function N.Zones() return N.maps.zones end

-- ── The English names in the journal ──────────────────────────────────────────────────────────

-- Who gives or takes a quest: the part before the first comma, when it looks like a name.
local function Person(text)
    local who = type(text) == "string" and text:match("^([^,]+)")
    if not who then return nil end
    who = who:gsub("%s+$", "")
    if who:find("^%u") and not who:find("[:%(]") and not who:find(" the ") then return who end
    return nil
end

function N.Sources()
    local out = { zones = {}, Npc = {}, Quest = {}, Item = {} }
    local seen = { zones = {}, Npc = {}, Quest = {}, Item = {} }
    local function Add(kind, en, id)
        if type(en) ~= "string" or en == "" or seen[kind][en] then return end
        seen[kind][en] = true
        out[kind][#out[kind] + 1] = { en = en, id = id }
    end
    local function AddItem(t)
        if type(t) == "table" then Add("Item", t[2], t[1]) end
    end
    for key, d in pairs(Data()) do
        local base, wing = N.Split(key)
        Add("zones", base)
        if wing then
            Add("zones", key)            -- the whole name first: "Excavation Site: Wetlands" is one place
            Add("zones", wing)
        end
        if type(d) == "table" then
            for _, b in ipairs(type(d.bosses) == "table" and d.bosses or {}) do
                Add("Npc", b.name, b.npcID)
                for _, it in ipairs(type(b.loot) == "table" and b.loot or {}) do
                    AddItem(it)
                    if type(it) == "table" then AddItem(it.makes) end   -- the item two halves make (Built.lua)
                end
            end
            for _, q in ipairs(type(d.quests) == "table" and d.quests or {}) do
                if type(q.id) == "number" and type(q.name) == "string" and not seen.Quest[q.id] then
                    seen.Quest[q.id] = true               -- a quest can sit in two dungeons
                    out.Quest[#out.Quest + 1] = { en = q.name, id = q.id }
                end
                for _, it in ipairs(type(q.rewardItems) == "table" and q.rewardItems or {}) do AddItem(it) end
                AddItem(q.noteItem)
                AddItem(q.requiredItem)
                local help = type(q.summonHelp) == "table" and q.summonHelp      -- Built.lua, B.Summon
                if help then Add("Item", help.itemName, help.item) end
                Add("Npc", Person(q.pickup))
                Add("Npc", Person(q.turnin))
                for _, text in pairs({ q.pickup, q.turnin }) do   -- "Name, Town, Zone": the places after the name
                    for i, en in ipairs(ns.Content.Parts(text)) do if i > 1 and en:find("^%u") then Add("zones", en) end end
                end
            end
        end
    end
    for _, en in ipairs(ns.Content and ns.Content.PlaceNames() or {}) do Add("zones", en) end  -- where
    for _, e in ipairs(ns.Prose and ns.Prose.Names() or {}) do   -- names in the long texts
        if e[1] ~= "Quest" then Add(e[1], e[2])
        elseif not seen.Quest[e[3]] then
            seen.Quest[e[3]] = true
            out.Quest[#out.Quest + 1] = { en = e[2], id = e[3] }
        end
    end
    for _, kind in ipairs(N.KINDS) do
        table.sort(out[kind], function(a, b)
            if a.id and b.id and kind == "Quest" then return a.id < b.id end
            return a.en < b.en
        end)
    end
    return out
end

-- ── The saved copy ────────────────────────────────────────────────────────────────────────────

function N.Signature()
    local parts = { "dj6", "rules=" .. tostring(U.UALL and U.UALL.RULES) }
    for _, addon in ipairs({ "UADD", "UADD_DungeonJournal", "ForeverDungeonJournal", "UALLF" }) do
        parts[#parts + 1] = addon .. "=" .. tostring(U.Meta(addon, "Version"))
    end
    local ok, version, build = pcall(GetBuildInfo)
    parts[#parts + 1] = ok and (tostring(version) .. "." .. tostring(build)) or "?"
    local okOff, off = pcall(function() return U.UALL.RoutesOff() end)
    if okOff and type(off) == "string" and off ~= "" then parts[#parts + 1] = "off=" .. off end
    return table.concat(parts, "|")
end

-- Takes the saved names into use. db.cache = { sig, zones, Npc, Quest, Item }.
function N.Load(db)
    local sig = N.Signature()
    if type(db.cache) ~= "table" or db.cache.sig ~= sig then db.cache = { sig = sig } end
    for _, kind in ipairs(N.KINDS) do
        N.maps[kind] = type(db.cache[kind]) == "table" and db.cache[kind] or {}
    end
    N.version = N.version + 1
    return db.cache
end

-- ── Collecting ────────────────────────────────────────────────────────────────────────────────

-- The parts of a saved copy's signature that decide what UALL answers: its rules, UADD's and
-- UALLF's versions, the game build and the routes switched off. A Questie copy is reused only when
-- all of them are the same as ours now (the rest of its signature is about Questie itself).
local function Basis(sig)
    local out = {}
    for part in tostring(sig):gmatch("[^|]+") do
        local key = part:match("^([%w_]+)=")
        if key == "rules" or key == "UADD" or key == "UALLF" or key == "off" then
            out[#out + 1] = part
        elseif not key and part:find("^%d+%.[%d%.]+$") then
            out[#out + 1] = part                    -- the game build, "1.15.7.12345"
        end
    end
    return table.concat(out, "|")
end
N.Basis = Basis

local function QuestieCache()
    local m = type(UADD_DB) == "table" and type(UADD_DB.modules) == "table" and UADD_DB.modules.questie
    local c = type(m) == "table" and m.cache
    if type(c) ~= "table" or type(c.sig) ~= "string" or Basis(c.sig) ~= Basis(N.Signature()) then return {} end
    return c
end

-- "Лютопащ (Схід)" and "Багряний Монастир — Збройова" written the journal's way: "Лютопащ: Схід".
function N.WingForm(uk)
    if type(uk) ~= "string" then return uk end
    local base, wing = uk:match("^(.-) %((.+)%)$")
    if not base then base, wing = uk:match("^(.-) \226\128[\147\148] (.+)$") end   -- en or em dash
    if not base then base, wing = uk:match("^(.-) %- (.+)$") end
    return base and (base .. ": " .. wing) or uk
end

-- A dungeon or wing: the zone route first, then UALLF's UI words (where it keeps "Hall of Thanes"
-- and the Blackrock Spire halves), then, for a wing, the spellings UALLF uses for it there:
-- "Dire Maul (East)", "Scarlet Monastery - Armory".
-- Each fallback goes through its own route: UALL.Zone through "zones", UALL.Text through the
-- bag-title route, gated like "Quest" (interface.storage, Routes.lua). A route switched off says
-- "not now" for ever, so its "not now" counts as a miss here, or the whole kind would wait
-- GIVE_UP seconds and never be saved.
local function AskZone(e)
    local waited = false
    local function Try(fn, route, en)
        local uk, wait = fn(en)
        if wait and not C.RouteOff(route) then waited = true end
        if uk and uk ~= en then return uk end
        return nil
    end
    local uk = Try(U.UALL.Zone, "zones", e.en) or Try(U.UALL.Text, "Quest", e.en)
    if uk then return uk end
    local base, wing = N.Split(e.en)
    if wing then
        uk = Try(U.UALL.Text, "Quest", base .. " (" .. wing .. ")") or Try(U.UALL.Text, "Quest", base .. " - " .. wing)
        if uk then return N.WingForm(uk) end
    end
    return nil, waited
end

-- A quest by the journal's title, then by the game's own title for the ID, then with "..." written
-- ". . ." as the game writes it in some titles ("Oh Brother. . .").
local function AskQuest(e)
    local uk, wait = U.UALL.Quest(e.id, e.en)
    if uk or wait then return uk, wait end
    local tries = {}
    local ok, client = pcall(function()
        return C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(e.id)
    end)
    client = ok and UADD.Plain(client)
    if client and client ~= "" and client ~= e.en then tries[#tries + 1] = client end
    if type(e.en) == "string" and e.en:find("%.%.%.") then tries[#tries + 1] = (e.en:gsub("%.%.%.", ". . .")) end
    for _, en in ipairs(tries) do
        uk, wait = U.UALL.Quest(e.id, en)
        if uk or wait then return uk, wait end
    end
    return nil
end

local ASK = {
    zones = AskZone,
    Npc = function(e) return U.UALL.Npc(e.en) end,
    Quest = AskQuest,
    Item = function(e) return U.UALL.Item(e.en) end,
}

local function Task(kind, items)
    local reuse = QuestieCache()[kind ~= "zones" and kind or "none"]
    reuse = type(reuse) == "table" and reuse or {}
    local task = { kind = kind, items = items }
    function task.lookup(e)
        local key = kind == "Quest" and e.id or e.en
        local had = e.id and reuse[e.id]
        if type(had) == "string" and had ~= "" then
            N.reused = (N.reused or 0) + 1
            return key, had
        end
        local uk, wait = C.Ask(ASK[kind], e)
        if uk == e.en then uk = nil end
        return key, uk, wait
    end
    return task
end

local function FinishTask(task, job)
    if task.partial then job.partial = true elseif not task.unsaved then job.cache[task.kind] = task.found end
    N.maps[task.kind] = task.found
    N.version = N.version + 1
    if ns.OnNames then U.SafeCall(ns.OnNames) end
end

local function Finish(done)
    if done.onDone then U.SafeCall(done.onDone, done.partial and true or false) end
end

-- Starts collecting what the saved copy lacks (everything when `all`). Returns true, or false
-- and why: "busy", "no-uall", "done".
function N.Start(db, all, onDone)
    if runner.Busy() then return false, "busy" end
    if not C.IsAvailable() then return false, "no-uall" end
    local cache = N.Load(db)
    local sources, tasks = N.Sources(), {}
    for _, kind in ipairs(N.KINDS) do
        if all or cache[kind] == nil then tasks[#tasks + 1] = Task(kind, sources[kind]) end
    end
    if #tasks == 0 then return false, "done" end
    runner.Start({ tasks = tasks, cache = cache, onDone = onDone, finishTask = FinishTask, finish = Finish })
    return true
end

function N.Stop() runner.Stop() end
function N.Progress() return runner.Progress() end

-- How many names are Ukrainian now, by kind ("dungeons" counts whole journal entries).
function N.Counts()
    local function Count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
    local dungeons, total = 0, 0
    for key in pairs(Data()) do
        total = total + 1
        if N.Dungeon(key) then dungeons = dungeons + 1 end
    end
    return { dungeons = dungeons, dungeonsTotal = total, Npc = Count(N.maps.Npc),
        Quest = Count(N.maps.Quest), Item = Count(N.maps.Item) }
end
