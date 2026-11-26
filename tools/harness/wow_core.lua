-- Harness core: error capture, the frame clock, C_Timer, events, hooksecurefunc and the small Lua
-- extras the WoW client adds (strsplit, wipe, bit, ...). Loaded first, into a plain Lua 5.1 state.
-- Everything the runner needs is kept in the global HARNESS table.

local H = {}
HARNESS = H
H.errors = {}         -- { { where = "...", msg = "...", tb = "..." } }
H.chat = {}           -- every line printed to chat or with print()
H.autostubs = {}      -- name -> count: globals a third-party file read that no stub defines
H.ourMissing = {}     -- "Frame:Method" or global name -> where: OUR code used something not stubbed
H.time = 1000         -- GetTime(), seconds; moves only when the runner pumps frames
H.frameNo = 0
H.combat = false
H.loggedIn = false
H.keys = { SHIFT = false, CTRL = false, ALT = false }
H.ourAddons = { UADD = true, UADD_Questie = true }

local clock = os.clock
H.clock = clock

-- ── Errors ────────────────────────────────────────────────────────────────────────────────────

function H.report(where, err)
    local tb = debug.traceback(tostring(err), 2)
    H.errors[#H.errors + 1] = { where = tostring(where), msg = tostring(err), tb = tb }
end

local handler = function(err) H.report("error handler", err) end
function geterrorhandler() return handler end
function seterrorhandler(fn) if type(fn) == "function" then handler = fn end end
function CallErrorHandler(...) return geterrorhandler()(...) end

-- Runs fn under xpcall; a failure is recorded with its traceback. Returns ok, results...
-- A watchdog stops any one outermost call that runs over H.callLimit seconds (a hang, e.g. a loop
-- waiting on GetTime, which only moves between frames).
H.callLimit, H.depth = 30, 0
local function watchdog()
    if os.clock() > H.deadline then error("harness watchdog: call ran over " .. H.callLimit .. " s", 2) end
end
function H.call(where, fn, ...)
    local args, n = { ... }, select("#", ...)
    local tb
    if H.depth == 0 then H.deadline = os.clock() + H.callLimit debug.sethook(watchdog, "", 1000000) end
    H.depth = H.depth + 1
    local res = { xpcall(function() return fn(unpack(args, 1, n)) end,
        function(e) tb = debug.traceback(tostring(e), 2); return e end) }
    H.depth = H.depth - 1
    if H.depth == 0 then debug.sethook() end
    if not res[1] then
        H.errors[#H.errors + 1] = { where = tostring(where), msg = tostring(res[2]), tb = tb }
    end
    return unpack(res, 1, table.maxn(res))
end

-- Which addon a stack level belongs to (chunk names are "@AddOns/<Addon>/<file>").
function H.addonAt(level)
    local info = debug.getinfo(level + 1, "S")
    local src = info and info.source or ""
    return src:match("^@AddOns/([^/]+)/"), src, info and info.currentline
end

function H.calledFromOurs(maxDepth)
    for level = 3, (maxDepth or 4) + 2 do
        local addon, src = H.addonAt(level)
        if addon then return H.ourAddons[addon] and src or nil end
    end
    return nil
end

-- ── Timers and the frame clock ────────────────────────────────────────────────────────────────

H.timers = {}
local timerSeq = 0

local function NewTimer(delay, fn, iterations)
    timerSeq = timerSeq + 1
    local t = { due = H.time + math.max(delay or 0, 0), delay = delay or 0, fn = fn, left = iterations,
                seq = timerSeq, frame = H.frameNo }
    function t.Cancel(self) (self or t).cancelled = true end
    function t.IsCancelled(self) return (self or t).cancelled == true end
    H.timers[#H.timers + 1] = t
    return t
end

C_Timer = {
    After = function(delay, fn)
        if type(fn) ~= "function" then error("Usage: C_Timer.After(seconds, callback)", 2) end
        NewTimer(delay, fn, 1)
    end,
    NewTimer = function(delay, fn) return NewTimer(delay, fn, 1) end,
    NewTicker = function(delay, fn, iterations) return NewTimer(delay, fn, iterations or math.huge) end,
}

function H.pendingTimers()
    local n = 0
    for _, t in ipairs(H.timers) do if not t.cancelled then n = n + 1 end end
    return n
end

-- One frame: time moves by dt, OnUpdate scripts of visible frames run, then due timers.
-- A timer made during this frame never runs before the next one (like C_Timer.After(0)).
function H.step(dt)
    dt = dt or 0.016
    H.frameNo = H.frameNo + 1
    H.time = H.time + dt
    for _, f in ipairs(H.updaters()) do
        local script = H.scriptOf(f, "OnUpdate")
        if script and f:IsVisible() then H.call("OnUpdate", script, f, dt) end
    end
    local due = {}
    for _, t in ipairs(H.timers) do
        if not t.cancelled and t.due <= H.time and t.frame < H.frameNo then due[#due + 1] = t end
    end
    table.sort(due, function(a, b) if a.due ~= b.due then return a.due < b.due end return a.seq < b.seq end)
    for _, t in ipairs(due) do
        if not t.cancelled then
            t.left = t.left - 1
            if t.left <= 0 then t.cancelled = true else t.due = H.time + math.max(t.delay, 0.001) end
            H.call("C_Timer callback", t.fn, t)
        end
    end
    local keep = {}
    for _, t in ipairs(H.timers) do if not t.cancelled then keep[#keep + 1] = t end end
    H.timers = keep
end

-- Pumps frames until cond() is true (or, without cond, until no timer is waiting). Returns frames run.
function H.pump(maxFrames, cond, dt)
    for i = 1, maxFrames do
        if cond then
            if cond() then return i - 1, true end
        elseif H.pendingTimers() == 0 then
            return i - 1, true
        end
        H.step(dt)
    end
    return maxFrames, cond and cond() or H.pendingTimers() == 0
end

-- ── Events ────────────────────────────────────────────────────────────────────────────────────

H.eventFrames = {}    -- event -> ordered list of frames
H.allEvents = {}      -- frames that called RegisterAllEvents

function H.register(frame, event)
    local list = H.eventFrames[event]
    if not list then list = {} H.eventFrames[event] = list end
    for _, f in ipairs(list) do if f == frame then return end end
    list[#list + 1] = frame
end

function H.unregister(frame, event)
    local list = H.eventFrames[event]
    if not list then return end
    for i, f in ipairs(list) do if f == frame then table.remove(list, i) return end end
end

function H.isRegistered(frame, event)
    for _, f in ipairs(H.eventFrames[event] or {}) do if f == frame then return true end end
    return false
end

-- Fires an event at every registered frame in registration order. Errors are recorded, not lost.
function H.fire(event, ...)
    local list = {}
    for _, f in ipairs(H.eventFrames[event] or {}) do list[#list + 1] = f end
    for _, f in ipairs(H.allEvents) do list[#list + 1] = f end
    for _, f in ipairs(list) do
        local script = H.scriptOf(f, "OnEvent")
        if script then H.call(event .. " handler of " .. tostring(f:GetName() or "?"), script, f, event, ...) end
    end
    if EventRegistry and EventRegistry.TriggerEvent then H.call(event .. " (EventRegistry)", EventRegistry.TriggerEvent, EventRegistry, event, ...) end
end

-- ── hooksecurefunc ────────────────────────────────────────────────────────────────────────────

-- A crash of the real client (docs/LESSONS4.md lesson 47): a font object made to inherit from itself
-- (wow_widgets2.lua), a hooked setter re-entered through its own hook. The game dies there and no pcall
-- catches it; here the run fails: H.crashes keeps it (boxes.py: "no client crash"), the call errors and
-- changes nothing. A mutant client (H.boxQuiet) keeps it in H.crashes only.
H.crashes = {}
function H.Crash(why)
    why = tostring(why)
    if #H.crashes < 20 then H.crashes[#H.crashes + 1] = why end
    local rep = H.crashReport
    if not H.boxQuiet and (type(rep) == "function" or type(rep) == "userdata") then pcall(rep, why) end
    error("client crash: " .. why, 0)
end

-- Like the client: the original runs first and its results are returned; the hook then gets the
-- same arguments. A hook's error goes to the error handler and does not reach the caller.
-- A setter that runs again inside its own hook, on the same object, more than HOOK_DEEP deep: the client's
-- stack runs out (a crash, lesson 47).
local HOOK_DEEP = 8
function hooksecurefunc(a, b, c)
    local t, name, hook
    if type(a) == "string" then t, name, hook = _G, a, b else t, name, hook = a, b, c end
    if type(t) ~= "table" then error("hooksecurefunc(): not a table", 2) end
    if type(hook) ~= "function" then error("Usage: hooksecurefunc([table,] \"functionName\", hookfunc)", 2) end
    local orig = t[name]
    if type(orig) ~= "function" then error("hooksecurefunc(): " .. tostring(name) .. " is not a function", 2) end
    local depth, NONE = setmetatable({}, { __mode = "k" }), {}
    t[name] = function(...)
        local self = ...
        local key = type(self) == "table" and self or NONE
        local d = (depth[key] or 0) + 1
        if d > HOOK_DEEP then H.Crash("hook re-entered " .. tostring(name) .. " " .. HOOK_DEEP .. " deep") end
        depth[key] = d
        local res = { pcall(orig, ...) }
        if not res[1] then depth[key] = d > 1 and d - 1 or nil error(res[2], 0) end
        local ok, err = pcall(hook, ...)
        depth[key] = d > 1 and d - 1 or nil
        if not ok then geterrorhandler()(err) end
        return unpack(res, 2, table.maxn(res))
    end
end

-- ── Global environments ─────────────────────────────────────────────────────────────────────

-- Third-party files run in _G itself. A global nobody defines reads as nil, as in the client; the
-- name is only counted (H.autostubs) so a missing stub is easy to spot.
function H.isMagic() return false end
setmetatable(_G, { __index = function(_, k)
    H.autostubs[k] = (H.autostubs[k] or 0) + 1
    return nil
end })

-- Our files get a proxy: every read of an undefined global and every global write is recorded.
function H.envFor(addon)
    if not H.ourAddons[addon] then return _G end
    return setmetatable({}, {
        __index = function(_, k)
            local v = rawget(_G, k)
            if v == nil and not H.ourGlobalsOk[k] then
                local _, src, line = H.addonAt(2)
                H.ourMissing["global " .. tostring(k)] = tostring(src) .. ":" .. tostring(line)
            end
            return v
        end,
        __newindex = function(_, k, v)
            H.ourWrites[k] = true
            rawset(_G, k, v)
        end,
    })
end
H.ourWrites = {}
-- Globals our files may read while they are still nil (the code checks for them on purpose).
H.ourGlobalsOk = { UADD = true, UADD_DB = true, QUESTIE_LOCALES_OVERRIDE = true }
