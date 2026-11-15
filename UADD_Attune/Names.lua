-- Quest, NPC, item, zone and other names in Ukrainian, asked one by one from UALL Forever (UADD.UALL)
-- through the shared background runner (UADD/Collector.lua).
--
-- Attune shows these in English from its own tables: quest titles (AttuneLang Q1_<id>), NPC names
-- (N1_<id>, the quest givers, the NPC table), item names (I_<id>), zones (step LOCATION) and the
-- attunement names (class attunements are spell names). UALL can only answer after login and outside
-- combat, so we go through every name in the background, a few milliseconds per frame, and save what
-- we find in UADD_DB. Words.lua then looks names up in that saved map only: a SetText never asks UALL.
--
-- The saved copy is thrown away when UADD, this module, Attune, UALL Forever or the game version
-- changes, or a UALLF route is switched on or off (UADD/Routes.lua), and collected again.
-- A kind whose route is off in UALLF is not asked at all: it stays English, as in UALLF.
-- Attune's tables are only read (rawget and pairs), never written.

local _, ns = ...
local N = {}
ns.Names = N

N.KINDS = { "Quest", "Npc", "Item", "zones", "Text" }
N.counts = { Quest = 0, Npc = 0, Item = 0, zones = 0, Text = 0 }
N.map = {}                           -- English -> Ukrainian, all kinds together (read by Words.lua)

local function Count(map)
    local n = 0
    for _ in pairs(map) do n = n + 1 end
    return n
end

local function Good(s) return type(s) == "string" and s ~= "" and s:find("%a") ~= nil end

-- ── What to ask ───────────────────────────────────────────────────────────────────────────────

local function Lang() local t = rawget(_G, "AttuneLang") return type(t) == "table" and t or nil end
local function Data() local t = rawget(_G, "Attune_Data") return type(t) == "table" and t or nil end

-- { {id, English}, ... } for the AttuneLang keys "<prefix><id>", sorted by id.
local function ById(prefix)
    local out, lang = {}, Lang()
    for key, en in pairs(lang or {}) do
        local id = type(key) == "string" and tonumber(key:match("^" .. prefix .. "(%d+)$"))
        if id and Good(en) then out[#out + 1] = { id, en } end
    end
    table.sort(out, function(a, b) return a[1] < b[1] end)
    return out
end

-- Sorted English names, each once.
local function Unique(list)
    local seen, out = {}, {}
    for _, en in ipairs(list) do
        if Good(en) and not seen[en] then seen[en], out[#out + 1] = true, en end
    end
    table.sort(out)
    return out
end

local function Npcs()
    local list, d = {}, Data()
    for _, row in ipairs(ById("N1_")) do list[#list + 1] = row[2] end
    for _, giver in pairs(d and type(d.questGivers) == "table" and d.questGivers or {}) do
        if type(giver) == "table" then list[#list + 1] = giver[4] end
    end
    for _, npc in pairs(d and type(d.npcs) == "table" and d.npcs or {}) do
        if type(npc) == "table" then list[#list + 1] = npc[3] end   -- a name, or a creature kind
    end
    return Unique(list)
end

local function Zones()
    local list, d = {}, Data()
    for _, step in ipairs(d and type(d.steps) == "table" and d.steps or {}) do
        local loc = type(step) == "table" and step.LOCATION
        if type(loc) == "string" and not loc:find("^%d+$") then list[#list + 1] = loc end
    end
    return Unique(list)
end

local function Others()
    local list, d = {}, Data()
    for _, a in ipairs(d and type(d.attunes) == "table" and d.attunes or {}) do
        if type(a) == "table" then list[#list + 1] = a.NAME end
    end
    return Unique(list)
end

-- ── The saved copy ────────────────────────────────────────────────────────────────────────────

function N.Signature()
    local parts = { "1", "rules=" .. tostring(UADD.UALL and UADD.UALL.RULES) }
    for _, addon in ipairs({ "UADD", "UADD_Attune", "Attune", "UALLF" }) do
        parts[#parts + 1] = addon .. "=" .. tostring(UADD.Meta(addon, "Version"))
    end
    local ok, version, build = pcall(GetBuildInfo)
    parts[#parts + 1] = ok and (tostring(version) .. "." .. tostring(build)) or "?"
    -- Only when a route is off, so a saved copy with every route on stays valid as it is.
    local okOff, off = pcall(function() return UADD.UALL.RoutesOff() end)
    if okOff and type(off) == "string" and off ~= "" then parts[#parts + 1] = "off=" .. off end
    return table.concat(parts, "|")
end

-- db.cache = { sig = "...", Quest = {...}, Npc = {...}, Item = {...}, zones = {...}, Text = {...} },
-- each English -> Ukrainian. A missing part means "not collected yet".
function N.LoadCache(db)
    local sig = N.Signature()
    if type(db.cache) ~= "table" or db.cache.sig ~= sig then db.cache = { sig = sig } end
    return db.cache
end

-- One map for Words.lua from the saved parts. Later kinds do not replace a name already there.
function N.Use(cache)
    local map = {}
    for _, kind in ipairs(N.KINDS) do
        local part = type(cache) == "table" and cache[kind]
        N.counts[kind] = type(part) == "table" and Count(part) or 0
        for en, uk in pairs(type(part) == "table" and part or {}) do
            -- %a alone misses Cyrillic bytes (Lua's C locale), so a Ukrainian answer is checked by bytes too.
            if map[en] == nil and type(uk) == "string" and uk:find("[%a\128-\255]") and uk ~= en then map[en] = uk end
        end
    end
    N.map = map
    ns.Words.SetNames(map)
    if ns.OnNames then UADD.SafeCall(ns.OnNames) end   -- Module.lua: the shown texts again
end

-- ── Collecting in the background ──────────────────────────────────────────────────────────────

local C = UADD.Collector
local runner = C.New()
local Ask = C.Ask

local function Answer(en, uk, wait)
    if uk == en then uk = nil end
    return en, uk, wait
end

local function Task(kind)
    if kind == "Quest" then
        local task = { kind = kind, items = ById("Q1_") }
        function task.lookup(row) return Answer(row[2], Ask(UADD.UALL.Quest, row[1], row[2])) end
        return task
    end
    if kind == "Item" then
        local task = { kind = kind, items = ById("I_") }
        function task.lookup(row) return Answer(row[2], Ask(UADD.UALL.Item, row[2])) end
        return task
    end
    if kind == "zones" then
        local task = { kind = kind, items = Zones() }
        function task.lookup(en)
            local known = UADD.CachedName("zones", en)        -- another module's saved copy: no asking
            if known then return en, known end
            return Answer(en, Ask(UADD.UALL.Zone, en))
        end
        return task
    end
    local task = { kind = kind, items = kind == "Npc" and Npcs() or Others() }
    local ask = kind == "Npc" and UADD.UALL.Npc or UADD.UALL.Text
    function task.lookup(en) return Answer(en, Ask(ask, en)) end
    return task
end

-- A task cut short (task.partial) is used now but not saved, so the next login asks again.
-- A route switched off midway (task.unsaved) is not saved either: the signature still says "on".
local function FinishTask(task, job)
    if task.partial then job.partial = true elseif not task.unsaved then job.cache[task.kind] = task.found end
    job.used[task.kind] = task.found
    local merged = {}
    for k, v in pairs(job.cache) do merged[k] = v end
    for k, v in pairs(job.used) do merged[k] = v end
    N.Use(merged)
end

local function Finish(done)
    if done.onDone then UADD.SafeCall(done.onDone, done.partial and true or false) end
end

function N.IsAvailable() return C.IsAvailable() end

-- Starts collecting what the saved copy lacks (everything when `all`). onDone(partial) runs at the
-- end. Returns true, or false and why: "busy", "no-uall", "no-attune", "done".
function N.Start(db, all, onDone)
    if runner.Busy() then return false, "busy" end
    if not N.IsAvailable() then return false, "no-uall" end
    if not (Lang() and Data()) then return false, "no-attune" end
    local cache = N.LoadCache(db)
    local tasks = {}
    for _, kind in ipairs(N.KINDS) do
        if all or cache[kind] == nil then
            -- The Text route is UALL's quest-title one: off together with quests.
            local off = kind == "Text" and C.RouteOff("Quest")
            if not off then tasks[#tasks + 1] = Task(kind) end
        end
    end
    if #tasks == 0 then return false, "done" end
    runner.Start({ tasks = tasks, cache = cache, used = {}, onDone = onDone,
        finishTask = FinishTask, finish = Finish })
    return true
end

function N.Stop() runner.Stop() end

-- nil when idle, otherwise asked, total (for the status line).
function N.Progress() return runner.Progress() end

-- For the status line: how many names Words.lua can use now.
function N.Count() return Count(N.map) end
