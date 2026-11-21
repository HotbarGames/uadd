-- UADD: the one print handler every module shares (docs/LESSONS3.md, lesson 35).
--
-- print() hands its values to the game's print handler (getprinthandler / setprinthandler). A module that
-- translates an addon's printed lines adds a handler here with U.PrintHook(o) -> { Start, Stop, Active, Count };
-- no module calls setprinthandler itself (tools/test_hook_guards.py).
--   * A print of one string reaches o.line(text) (under U.SafeCall), only when U.Plain says it is a plain
--     string; o.line returns the new text, or nil / text to leave it. The first hook that changes it wins.
--   * Every other print (several values, no string, a secret line, an error in our code) goes to the old
--     handler untouched, exactly once.
--   * Ours goes on with the first Start and comes off when no hook is on and nobody set a handler after us
--     (then ours stays in their chain and passes every print through as it is).
--   * In an instance (a BG) ours is off, as U.ChatHook's chat wrap (UADD/Lines.lua): there printed lines can
--     be secret, and code of ours on the game's print path taints it. Ours on top: the old handler goes back.
--     Another addon set one after us: theirs stays, ours only passes prints through. It goes on again outside
--     (PLAYER_ENTERING_WORLD, ZONE_CHANGED_NEW_AREA). Our printed lines stay English in an instance.
-- A client without getprinthandler / setprinthandler: printed lines stay English.

local U = UADD
local hooks, nLive = {}, 0
local had, on, inside, busy = nil, false, false, false  -- had: the handler before ours; on: ours set (maybe under theirs)

local function Pick(text)
    if not U.Plain(text) then return nil end
    for i = 1, #hooks do
        local h = hooks[i]
        if h.live then
            local ok, out = U.SafeCall(h.line, text)
            if ok and type(out) == "string" and out ~= text then h.count = h.count + 1 return out end
        end
    end
end

local function Printed(...)
    local old = had
    if nLive > 0 and not inside and not busy and select("#", ...) == 1 and type((...)) == "string" then
        busy = true
        local ok, out = pcall(Pick, (...))
        busy = false
        if ok and type(out) == "string" then return old(out) end
    end
    return old(...)
end
U.PrintWrapped = Printed                                 -- for the checks

local function Api()
    local get, set = rawget(_G, "getprinthandler"), rawget(_G, "setprinthandler")
    if type(get) ~= "function" or type(set) ~= "function" then return nil end
    return get, set
end

local function Set()
    if on then return true end                           -- set already (maybe under a later handler)
    inside = U.InInstance()
    if inside then return false end                      -- never in an instance (see above)
    local get, set = Api()
    if not get then return false end
    local old = get()
    if old == Printed and had then on = true return true end     -- another addon put ours back on top
    if type(old) ~= "function" or old == Printed then return false end
    had = old
    set(Printed)
    on = true
    return true
end

-- force: off while hooks are on (an instance). Set after us: we stay in their chain, passing all.
local function Unset(force)
    if (nLive > 0 and not force) or not on then return end
    local get, set = Api()
    if not get or get() ~= Printed then return end
    set(had)                                             -- had stays: a chain that kept ours still reaches it
    on = false
end

-- In an instance: off. Outside, with a hook on: on again.
local function Sync()
    inside = U.InInstance()
    if inside then Unset(true) elseif nLive > 0 then Set() end
end
U.PrintSync = Sync                                       -- for the checks
do
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    ev:SetScript("OnEvent", function() pcall(Sync) end)
end

function U.PrintHook(o)
    local h = { line = o.line, live = false, count = 0 }
    hooks[#hooks + 1] = h
    local P = {}
    function P.Start()
        if h.live then Set() return end
        if not Set() and not inside then return end      -- in an instance: on, set when we leave it
        h.live, nLive = true, nLive + 1
    end
    function P.Stop()
        if h.live then h.live, nLive = false, nLive - 1 end
        Unset()
    end
    function P.Active() return h.live and on and not inside end
    function P.Count() return h.count end
    return P
end
