-- UADD - Mastercraft: finding Mastercraft's font strings (Screen.lua puts our words on them).
--
--   * A post-hook on CreateFontString of the frame kinds (Frame, Button, ...): the frame that made one
--     is looked at on the next frame (Mastercraft fills the fields right after it makes the string),
--     at most CAP frames per game frame. A frame of another addon or of the game is looked at twice
--     at most, then left alone (lesson 12): its next CreateFontString costs one table look-up.
--   * Mastercraft's named windows, then every child of UIParent, after login and after "on": a few
--     hundred frames per game frame, never one big walk (a hitch at login).
--   * The named windows again when they show.
-- A forbidden frame is never asked for its regions or children.

local _, ns = ...
local U = UADD
local S = ns.Screen

local shown = {}                                    -- root window -> true: rescanned on OnShow
local queue, queued = {}, false
local walked = setmetatable({}, { __mode = "k" })
local ROOTS = { "MastercraftFrame", "MastercraftCompact", "MastercraftMinimapButton", "MastercraftFarmHUD",
    "MastercraftFishBar", "MastercraftFishRecap", "MastercraftFishWindow", "MastercraftGoals",
    "MastercraftLFGPanel", "MastercraftMiniGuide", "MastercraftNeverBank", "MastercraftRecipePanel",
    "MastercraftAltView", "MastercraftDetails", "MastercraftTradeBoard", "MastercraftConfirm",
    "MastercraftOrderToast" }

local function Forbidden(f) return f.IsForbidden and f:IsForbidden() end

-- How many of a frame's regions are Mastercraft's font strings (hooked now if they were not).
local function Regions(f)
    if not f.GetRegions or Forbidden(f) then return 0 end
    if ns.Raw then ns.Raw.Look(f) end           -- its own words on a few raw strings (Raw.lua)
    local n = 0
    for _, r in ipairs({ f:GetRegions() }) do
        if S.Ours(r) then
            n = n + 1
            S.Hook(r)                           -- once per string (Hook knows)
        end
    end
    return n
end

-- A frame and everything in it, once (later font strings come in through CreateFontString).
local function Walk(f, budget)
    if type(f) ~= "table" or walked[f] or budget[1] <= 0 then return end
    walked[f] = true
    budget[1] = budget[1] - 1
    if Forbidden(f) then return end
    Regions(f)
    if f.GetChildren then
        for _, c in ipairs({ f:GetChildren() }) do Walk(c, budget) end
    end
end

local dry = setmetatable({}, { __mode = "k" })     -- frame -> true: not Mastercraft's, never looked at again
local empty = setmetatable({}, { __mode = "k" })   -- frame -> times looked at with nothing of ours
local CAP = 200                                     -- frames looked at per game frame

-- Inside one of Mastercraft's windows: a frame or a parent whose name starts with "Mastercraft".
local function Inside(f)
    for _ = 1, 30 do
        if type(f) ~= "table" then return false end
        local name = f.GetName and f:GetName()
        if type(name) == "string" and name:find("^Mastercraft") then return true end
        f = f.GetParent and f:GetParent()
    end
    return false
end

local function Look(f)
    if Forbidden(f) then dry[f] = true return end
    if Regions(f) > 0 or Inside(f) then empty[f] = nil return end
    empty[f] = (empty[f] or 0) + 1
    if empty[f] >= 2 then dry[f] = true empty[f] = nil end
end

local nQueued, QUEUE_MAX = 0, 2000                  -- more waiting than that: the rest found by the scans
local Flush
local function SafeFlush() U.SafeCall(Flush) end
Flush = function()
    if U.AfterCombat(SafeFlush) then return end     -- no look in combat (a BG): after it, every second
    local list, n = queue, 0
    queue, nQueued = {}, 0
    for f in pairs(list) do
        if n < CAP then
            n = n + 1
            U.SafeCall(Look, f)
        else
            queue[f], nQueued = true, nQueued + 1   -- the rest on the next frame
        end
    end
    queued = next(queue) ~= nil
    if queued then C_Timer.After(0, SafeFlush) end
end

-- Every CreateFontString of the game passes here (core U.OnNewFontString, under U.SafeCall): table look-ups,
-- and the game's busy frames (nameplates, raid frames) by their name only (lesson 35).
local function OnCreate(self)
    if type(self) ~= "table" or dry[self] or queue[self] then return end
    if nQueued >= QUEUE_MAX then return end
    if U.GameMade(self) then dry[self] = true return end
    queue[self], nQueued = true, nQueued + 1
    if not queued then
        queued = true
        C_Timer.After(0, SafeFlush)
    end
end
S.Dry = function(f) return dry[f] == true end

local installed = false
function S.Install()
    if installed then return end
    installed = true
    U.OnNewFontString(OnCreate)
end

-- The scan: a stack of frames, STEP of them per game frame, 30000 at most.
local pending, scanning, left = {}, false, 0
local STEP = 250                                   -- frames walked per game frame
local function One(f)
    if Forbidden(f) then return end
    Regions(f)
    if f.GetChildren then
        local kids = { f:GetChildren() }
        for i = #kids, 1, -1 do pending[#pending + 1] = kids[i] end
    end
end
local Step
local function SafeStep() U.SafeCall(Step) end
Step = function()
    if U.AfterCombat(SafeStep) then return end      -- no walk in combat: after it, every second
    local n = 0
    while n < STEP and left > 0 do
        local f = table.remove(pending)
        if f == nil then break end
        if type(f) == "table" and not walked[f] then
            walked[f] = true
            n, left = n + 1, left - 1
            U.SafeCall(One, f)
        end
    end
    if pending[1] ~= nil and left > 0 then C_Timer.After(0, SafeStep) else scanning = false pending = {} end
end
S.Scanning = function() return scanning end

-- Every window of Mastercraft's we can reach now (after login, when it shows, after "on").
function S.Scan()
    left = 30000
    if UIParent and UIParent.GetChildren and not Forbidden(UIParent) then
        local kids = { UIParent:GetChildren() }
        for i = #kids, 1, -1 do pending[#pending + 1] = kids[i] end
    end
    for i = #ROOTS, 1, -1 do                        -- on top of the stack: walked first
        local f = rawget(_G, ROOTS[i])
        if type(f) == "table" then
            walked[f] = nil
            pending[#pending + 1] = f
            if f.HookScript and not shown[f] then
                shown[f] = true
                f:HookScript("OnShow", function(self)
                    if ns.On() then walked[self] = nil U.SafeCall(Walk, self, { 5000 }) end
                end)
            end
        end
    end
    if not scanning then
        scanning = true
        Step()                                      -- the first part now, the rest on later frames
    end
end
