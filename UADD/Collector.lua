-- UADD core: asks UALL Forever (UADD.UALL) for many names in the background, a few milliseconds
-- per frame, so the game never stutters. Shared by the modules (Questie, Dungeon Journal).
--
-- UALL only answers after login and outside combat. In combat we wait. When UALL says "not now"
-- (a window open, Shift held, UALL not ready) we ask the same name again a second later, for up to
-- GIVE_UP seconds; then the task is cut short (task.partial) and used, but not saved.
-- A kind whose route is off in UALL Forever (Routes.lua) is not asked at all: it stays English.
--
-- A module makes its own runner with UADD.Collector.New() and starts it with a job:
--   job = { tasks = { task, ... }, finishTask = fn(task, job), finish = fn(job), ... }
--   task = { kind = "zones" | "Quest" | "Npc" | "Item" | ..., items = { ... },
--            lookup = fn(item) -> key, ukrainian or nil, wait }
-- Each task collects task.found[key] = "назва". The runner adds job.i, job.asked, job.total,
-- job.partial and task.pos, task.found, task.off (route off), task.unsaved (switched off midway).

local C = {}
UADD.Collector = C

C.BUDGET_MS = 6                      -- work per frame
C.GIVE_UP = 120                      -- seconds UALL may say "not now" for one name before we stop

-- true when this kind's route is switched off in UALL Forever's settings.
function C.RouteOff(kind)
    local ok, off = pcall(function() return UADD.UALL.RouteOff(kind) end)
    return ok and off == true
end

-- Returns the Ukrainian, or nil and wait (true = UALL said "not now": ask again later).
function C.Ask(fn, ...)
    local ok, uk, wait = pcall(fn, ...)
    if ok and type(uk) == "string" and uk ~= "" then return uk end
    return nil, ok and wait or nil
end

function C.IsAvailable()
    local A = UADD.UALL
    if not (A and type(A.IsAvailable) == "function") then return false end
    local ok, yes = pcall(A.IsAvailable)
    return ok and yes and true or false
end

function C.New()
    local R = {}
    local job
    local scheduled = false          -- at most one timer waiting, even after Stop and Start
    local Step

    local function Schedule(delay)
        if scheduled then return end
        scheduled = true
        C_Timer.After(delay, Step)
    end

    local function Finish()
        local done = job
        job = nil
        if done.finish then UADD.SafeCall(done.finish, done) end
    end

    Step = function()
        scheduled = false
        if not job then return end
        if InCombatLockdown and InCombatLockdown() then
            job.waitSince = nil                -- combat does not count towards GIVE_UP
            Schedule(2)                        -- UALL does not answer in combat
            return
        end
        local stop = debugprofilestop() + C.BUDGET_MS
        while debugprofilestop() < stop do
            local task = job.tasks[job.i]
            if not task then return Finish() end
            local item = task.items[task.pos]
            if item == nil then
                if job.finishTask then job.finishTask(task, job) end
                job.i = job.i + 1
            else
                local ok, key, uk, wait = pcall(task.lookup, item)
                if ok and wait and C.RouteOff(task.kind) then
                    -- Switched off in UALLF while we collect: English from now on, as in UALLF.
                    job.waitSince, task.off, task.unsaved = nil, true, true
                    task.found, task.pos = {}, #task.items + 1
                elseif ok and wait then
                    -- "Not now": the same name again in a second. Only a real answer or a real
                    -- miss moves on, so misses stay real.
                    local now = GetTime()
                    job.waitSince = job.waitSince or now
                    if now - job.waitSince < C.GIVE_UP then return Schedule(1) end
                    job.waitSince, task.partial, task.pos = nil, true, #task.items + 1
                else
                    job.waitSince = nil
                    task.pos = task.pos + 1
                    job.asked = job.asked + 1
                    if ok and uk then task.found[key] = uk end
                end
                if InCombatLockdown and InCombatLockdown() then break end
            end
        end
        Schedule(0)
    end

    -- Starts the job. Returns false when this runner is busy.
    function R.Start(j)
        if job then return false end
        j.i, j.asked, j.total = 1, 0, 0
        for _, task in ipairs(j.tasks) do
            task.pos, task.found = 1, {}
            -- Route off in UALLF: nothing to ask, the kind stays English.
            if C.RouteOff(task.kind) then task.items, task.off = {}, true end
            j.total = j.total + #task.items
        end
        job = j
        Schedule(0)
        return true
    end

    function R.Stop() job = nil end
    function R.Busy() return job ~= nil end

    -- nil when idle, otherwise asked, total.
    function R.Progress()
        if not job then return nil end
        return math.min(job.asked, job.total), job.total
    end

    return R
end
