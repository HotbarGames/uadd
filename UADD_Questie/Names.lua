-- Quest, NPC, item and zone names in Ukrainian, asked one by one from UALL Forever (ns.UALL,
-- the shared UADD.UALL) through the shared background runner (UADD/Collector.lua).
--
-- UALL can only answer after login and outside combat, so the first time we go through every
-- name in the background, a few milliseconds per frame. Quest, NPC and item names go to QuestieDB
-- with LibQuestieDB.l10n.SetCorrection("UADD", "ukUA", type, "Names", rows). Zone names go into
-- Questie's l10n.translations (see Locale.lua).
--
-- The results are saved in UADD_DB. On the next login we hand them over at ADDON_LOADED, before
-- Questie builds its quest list. Names found later, in a running game, also reach QuestieDB at
-- once, but Questie keeps its own copies of quests, NPCs and items. N.changed lists the ids whose
-- names changed, so Module.lua can ask Questie to drop those copies and rebuild (no /reload).
-- The saved copy is thrown away when UADD, Questie, QuestieDB, UALL Forever or the game version
-- changes, or a UALLF route is switched on or off (Routes.lua), and collected again.
-- A kind whose route is off in UALLF is not asked at all: it stays English, as in UALLF.

local _, ns = ...
local N = {}
ns.Names = N

N.KINDS = { "Quest", "Npc", "Item" }
local OWNER, SLOT = "UADD", "Names"
N.counts = { Quest = 0, Npc = 0, Item = 0, zones = 0 }
N.maps = {}                          -- [kind] = { [id] = "назва" } as published now (read by Original.lua)
N.changed = {}                       -- [kind] = { [id] = true }: names changed since Questie last saw them

local function Lib()
    local lib = _G.LibQuestieDB
    return type(lib) == "table" and lib or nil
end

local function NameIndex(dt)
    local ok, idx = pcall(function() return Lib().Meta[dt].keys.name end)
    return ok and type(idx) == "number" and idx or nil
end

local function Count(map)
    local n = 0
    for _ in pairs(map) do n = n + 1 end
    return n
end

-- ── Hand names to QuestieDB ───────────────────────────────────────────────────────────────────

-- map = { [id] = "назва" }, or nil to take ours back. Returns true on success.
function N.Publish(dt, map)
    local lib, idx = Lib(), NameIndex(dt)
    if not (lib and lib.l10n and type(lib.l10n.SetCorrection) == "function" and idx) then return false end
    local rows, n = nil, 0
    if map then
        rows = {}
        for id, uk in pairs(map) do
            if type(id) == "number" and id > 0 and id % 1 == 0 and type(uk) == "string" and uk ~= "" then
                rows[id] = { [idx] = uk }
                n = n + 1
            end
        end
    end
    local ok = pcall(lib.l10n.SetCorrection, OWNER, ns.Locale.LOCALE, dt, SLOT, rows)
    if ok then
        -- Old ids and new ids alike: a name taken away is a change too.
        local changed = N.changed[dt] or {}
        for id in pairs(N.maps[dt] or {}) do changed[id] = true end
        for id in pairs(rows or {}) do changed[id] = true end
        N.changed[dt] = changed
        N.counts[dt], N.maps[dt] = n, map
    end
    return ok
end

-- The English names Questie shows for an id: QuestieDB's Correction Overlay first
-- (read/shared.lua:307-318), then the base name. Neither read adds to QuestieDB's read cache,
-- and neither sees translations (Get would hand us back our own Ukrainian).
function N.EnglishNames(dt, id)
    local lib, idx = Lib(), NameIndex(dt)
    local entity = lib and lib[dt]
    if type(entity) ~= "table" or type(entity.GetRaw) ~= "function" then return nil, nil end
    local layer = idx and type(entity.overlay) == "table" and entity.overlay[id]
    local fixed = type(layer) == "table" and layer[idx] or nil
    local ok, raw = pcall(entity.GetRaw, id, "name")
    return fixed, ok and raw or nil
end

function N.WithdrawAll()
    for _, dt in ipairs(N.KINDS) do N.Publish(dt, nil) end
end

-- ── The saved copy ────────────────────────────────────────────────────────────────────────────

function N.Signature()
    local parts = { "1", "rules=" .. tostring(ns.UALL and ns.UALL.RULES) }
    for _, addon in ipairs({ "UADD", "UADD_Questie", "Questie", "QuestieDB", "UALLF" }) do
        parts[#parts + 1] = addon .. "=" .. tostring(UADD.Meta(addon, "Version"))
    end
    local ok, version, build = pcall(GetBuildInfo)
    parts[#parts + 1] = ok and (tostring(version) .. "." .. tostring(build)) or "?"
    -- Only when a route is off, so a saved copy with every route on stays valid as it is.
    local okOff, off = pcall(function() return ns.UALL.RoutesOff() end)
    if okOff and type(off) == "string" and off ~= "" then parts[#parts + 1] = "off=" .. off end
    return table.concat(parts, "|")
end

-- db.cache = { sig = "...", zones = {...}, Quest = {...}, Npc = {...}, Item = {...} }.
-- A missing part means "not collected yet".
function N.LoadCache(db)
    local sig = N.Signature()
    if type(db.cache) ~= "table" or db.cache.sig ~= sig then db.cache = { sig = sig } end
    return db.cache
end

function N.PublishCached(cache)
    for _, dt in ipairs(N.KINDS) do
        if type(cache[dt]) == "table" then N.Publish(dt, cache[dt]) end
    end
    if type(cache.zones) == "table" then N.counts.zones = Count(cache.zones) end
    N.changed = {}                   -- before QuestieDB.Initialize: Questie has no copies yet
end

-- ── Collecting in the background ──────────────────────────────────────────────────────────────
-- The budgeted runner, the combat pause and the "not now" waits are shared: UADD/Collector.lua.

local C = UADD.Collector
local runner = C.New()
local Ask, RouteOff = C.Ask, C.RouteOff

local function ZoneTask()
    local task = { kind = "zones", items = ns.Locale.ZoneNames() }
    function task.lookup(name)
        if ns.uiStrings and ns.uiStrings[name] ~= nil then return name, nil end   -- ours wins
        local uk, wait = Ask(ns.UALL.Zone, name)
        if uk == name or not ns.Locale.SafeName(uk) then uk = nil end
        return name, uk, wait   -- written in FinishTask, so a route switched off midway writes none
    end
    return task
end

local function EntityTask(dt)
    local lib = Lib()
    local entity = lib and lib[dt]
    if type(entity) ~= "table" or type(entity.GetAllIds) ~= "function" then return nil end
    local ok, ids = pcall(entity.GetAllIds)
    if not ok or type(ids) ~= "table" then return nil end
    local task = { kind = dt, items = ids }
    local ask = dt == "Quest" and function(id, en) return ns.UALL.Quest(id, en) end
        or dt == "Npc" and function(_, en) return ns.UALL.Npc(en) end
        or function(_, en) return ns.UALL.Item(en) end
    local function Try(id, en)
        if type(en) ~= "string" or en == "" then return nil end
        local uk, wait = Ask(ask, id, en)
        if uk == en then uk = nil end
        return uk, wait
    end
    function task.lookup(id)
        if not entity.Exists(id) then return id, nil end
        local fixed, raw = N.EnglishNames(dt, id)
        local uk, wait = Try(id, fixed)
        if not uk and not wait and raw ~= fixed then uk, wait = Try(id, raw) end
        return id, uk, wait
    end
    return task
end

-- A task cut short (task.partial) is used now but not saved, so the next login asks again.
-- A route switched off midway (task.unsaved) is not saved either: the signature still says "on".
local function FinishTask(task, job)
    if task.partial then job.partial = true elseif not task.unsaved then job.cache[task.kind] = task.found end
    if task.kind == "zones" then
        for name, uk in pairs(task.found) do ns.Locale.AddZone(name, uk) end
        N.counts.zones = Count(task.found)
    else
        N.Publish(task.kind, task.found)
    end
end

-- onDone(partial, off) tells the player, once Questie shows the names (Module.lua); off lists
-- the kinds left English because their route is off in UALLF. It guards itself and always ends
-- with a message; an error that still gets out is shown in chat.
local function Finish(done)
    local off = {}
    for _, task in ipairs(done.tasks) do
        if task.off then off[#off + 1] = task.kind end
    end
    if done.onDone then UADD.SafeCall(done.onDone, done.partial and true or false, off) end
end

function N.IsAvailable()
    return C.IsAvailable()
end

-- Starts collecting what the saved copy lacks (everything when `all`). onDone(partial) runs at
-- the end. Returns true, or false and why: "busy", "no-uall", "done".
function N.Start(db, all, onDone)
    if runner.Busy() then return false, "busy" end
    if not N.IsAvailable() then return false, "no-uall" end
    local cache = N.LoadCache(db)
    local tasks = {}
    if all or cache.zones == nil then tasks[#tasks + 1] = ZoneTask() end
    for _, dt in ipairs(N.KINDS) do
        if all or cache[dt] == nil then
            local task = EntityTask(dt)
            if task then tasks[#tasks + 1] = task end
        end
    end
    if #tasks == 0 then return false, "done" end
    runner.Start({ tasks = tasks, cache = cache, onDone = onDone, finishTask = FinishTask, finish = Finish })
    return true
end

function N.Stop()
    runner.Stop()
end

-- nil when idle, otherwise "asked / total" for the status line.
function N.Progress()
    return runner.Progress()
end
