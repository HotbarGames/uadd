-- Finds OpenMap's windows and fixes what they show: fonts (Fonts.lua) and words (Words.lua), on
-- shown frames only, at most one look per MIN_GAP.
-- The frames (each a "root"):
--   * the dungeon view (OpenMapDungeonView and its side panel), the dungeon chooser and the card on
--     a dungeon's map: every text there gets the Cyrillic font (Questie's Ukrainian titles need it);
--   * the map menu (OpenMapMenu), the pin list and editor, the note editor and export box, the
--     report box, the News window (OpenMapNews) and the page in the game's Settings: words, and the
--     Cyrillic font on a text only once it shows Ukrainian letters (the News title keeps its
--     MORPHEUS font while it reads English);
-- The options window (AceConfig, built from L, so its words come from Locale.lua) is not ours to
-- walk: its widgets are shared with other addons' windows, so UADD/AceFont.lua does its fonts.
-- OpenMap makes these frames on first use, so we look for them every TICK seconds while the World
-- Map or one of them is shown (backing off to IDLE_MAX while a look finds no new frame or text), and once a second, while the World Map is shown, until all the
-- named ones exist; their OnShow is hooked. Nothing of the World Map's own is touched (but its hover
-- label, where OpenMap writes its own parts: Label.lua). Nothing is changed in combat. S.Sweep ("/uadd openmap off") reaches every text, shown or not.

local _, ns = ...
local U = UADD
local S = {}
ns.Screen = S
if type(UADD) == "table" then UADD.OpenMapScreen = S end   -- for the checks (tools/harness)

local MIN_GAP = 0.2
local TICK = 0.5
local FIND = 1
local IDLE_MAX = 4   -- seconds: the longest wait between looks while a look finds nothing new

local NAMED = { "OpenMapMenu", "OpenMapNews", "OpenMapPins", "OpenMapPinEditor", "OpenMapPinsCode",
    "OpenMapNoteEditor", "OpenMapNotesExport", "OpenMapReport" }

local roots, seen, hookedRoot = {}, {}, {}
local pending, last, ticker, finder = false, 0, nil, nil
-- The idle look backs off (lesson 12): each frame and text a look has met is known; a look that meets
-- nothing new doubles the wait before the next tick's look, up to IDLE_MAX. A window that shows or hides,
-- a text OpenMap sets (its SetText hook) or a look that meets something new brings it back to TICK.
local known = setmetatable({}, { __mode = "k" })
local gap, fresh = TICK, false
S.panel = nil        -- OpenMap's page in the game's Settings (caught when OpenMap registers it)

local function Visible(f) return type(f) == "table" and f.IsVisible and f:IsVisible() or false end

-- Nothing is changed in combat: a change asked for then waits until combat ends.
local waiter = CreateFrame("Frame")
local function CombatOver(self)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    U.SafeCall(ns.Locale.Sync)
    U.SafeCall(ns.Words.Sync)
    if ns.On() then
        gap = TICK
        S.Start()           -- a look, and the tickers right for the windows shown now (none: stopped)
    else
        U.SafeCall(S.Sweep)
    end
end
waiter:SetScript("OnEvent", function(self) U.SafeCall(CombatOver, self) end)

function S.WaitCombat()
    if not (InCombatLockdown and InCombatLockdown()) then return false end
    waiter:RegisterEvent("PLAYER_REGEN_ENABLED")
    return true
end

local function IsCard(f)
    return type(f) == "table" and rawget(f, "fold") ~= nil and rawget(f, "title") ~= nil
        and rawget(f, "child") ~= nil and rawget(f, "scroll") ~= nil
end

local function Add(f, words, all)
    if type(f) == "table" then roots[#roots + 1] = { f = f, words = words, all = all } end
end

local function Collect()
    wipe(roots)
    local view = rawget(_G, "OpenMapDungeonView")
    if type(view) == "table" then
        Add(view, true, true)
        Add(rawget(view, "side"), true, true)
    end
    Add(rawget(_G, "OpenMapDungeonChooser"), true, true)
    local map = rawget(_G, "WorldMapFrame")
    if type(map) == "table" and map.GetChildren then
        for _, c in ipairs({ map:GetChildren() }) do
            if IsCard(c) then Add(c, true, true) end
        end
    end
    for _, name in ipairs(NAMED) do Add(rawget(_G, name), true, false) end
    Add(S.panel, true, false)
end

-- OpenMap's windows and the World Map, as a set: for tooltips (Tooltip.lua).
function S.RootSet()
    Collect()
    local set = {}
    local map = rawget(_G, "WorldMapFrame")
    if type(map) == "table" then set[map] = true end
    for _, r in ipairs(roots) do set[r.f] = true end
    return set
end

local function StopTicker()
    if ticker then ticker:Cancel() ticker = nil end
end

-- A window shows or hides: texts the hold key skipped while hidden are put right at once.
local function OnRoot()
    gap = TICK
    if ns.On() and not (InCombatLockdown and InCombatLockdown()) then U.SafeCall(ns.Words.Flush) end
    S.Start()
end
local function OnRootHook() U.SafeCall(OnRoot) end

local function WatchShow(r)
    local f = r.f
    if not hookedRoot[f] and f.HookScript then
        hookedRoot[f] = true
        f:HookScript("OnShow", OnRootHook)
        f:HookScript("OnHide", OnRootHook)
    end
end

local function AnyShown()
    Collect()
    local any = Visible(rawget(_G, "WorldMapFrame"))
    for _, r in ipairs(roots) do
        WatchShow(r)
        any = any or Visible(r.f)
    end
    return any
end
S.AnyShown = AnyShown

local CYR = "[\208\209]"

-- `every`: shown or not, words only (S.Sweep).
local function Walk(f, r, every)
    if seen[f] or not (every or Visible(f)) then return end
    seen[f] = true
    if not every and not known[f] then known[f], fresh = true, true end
    if f.IsProtected and f:IsProtected() then return end   -- secure frames (a gamepad's button): never ours
    if r.words and not every and f.GetObjectType and f:GetObjectType() == "Button" then ns.Words.HookButton(f) end
    if f.GetRegions then
        for _, g in ipairs({ f:GetRegions() }) do
            if g.GetObjectType and g:GetObjectType() == "FontString" and (every or g:IsVisible()) then
                if not every and not known[g] then known[g], fresh = true, true end
                if every then
                    if r.words then ns.Words.Apply(g) end
                else
                    if r.words then
                        ns.Words.Hook(g)
                        ns.Words.Apply(g)
                    end
                    local t = UADD.Plain(g:GetText())
                    if r.all or (type(t) == "string" and t:find(CYR)) then ns.Fonts.Fix(g, false) end
                end
            end
        end
    end
    if f.GetChildren then
        for _, c in ipairs({ f:GetChildren() }) do Walk(c, r, every) end
    end
end

-- "/uadd openmap off" (after L is English again): every text of OpenMap's windows, shown or not,
-- as OpenMap would show it now. A window OpenMap built once while L was ours (the Settings
-- button, the map menu, the pin list title) and nobody opened since would keep our words.
function S.Sweep()
    if S.WaitCombat() then return end                     -- after combat (waiter above)
    Collect()
    wipe(seen)
    local ok, err = pcall(function()
        for _, r in ipairs(roots) do Walk(r.f, r, true) end
    end)
    wipe(seen)
    if not ok then error(err, 0) end
end

-- Runs now: fonts and words on every shown text of OpenMap's windows.
function S.Scan()
    if not ns.On() or S.WaitCombat() then return end
    Collect()
    wipe(seen)
    local ok, err = pcall(function()
        for _, r in ipairs(roots) do
            WatchShow(r)
            Walk(r.f, r)
        end
    end)
    wipe(seen)
    if not ok then error(err, 0) end
end

local function Run()
    pending = false
    last = GetTime()
    fresh = false
    U.SafeCall(S.Scan)
    gap = fresh and TICK or math.min(gap * 2, IDLE_MAX)
    if not AnyShown() then StopTicker() end
end
local function SafeRun() U.SafeCall(Run) end

-- At most one look per MIN_GAP, and none while none of OpenMap's windows is shown.
local function Schedule()
    if pending or not ns.On() or S.WaitCombat() or not AnyShown() then return end
    pending = true
    C_Timer.After(math.max(0, last + MIN_GAP - GetTime()), SafeRun)
end
-- Asked for (a text OpenMap set, a window shown, combat over): a look soon, and the idle wait from TICK.
function S.Schedule()
    gap = TICK
    Schedule()
end
-- The ticker: a look only once the idle wait has passed.
local function Tick()
    if GetTime() - last + 0.01 >= gap then Schedule() end
end
local function SafeTick() U.SafeCall(Tick) end
S.Gap = function() return gap end   -- for the checks

-- While the World Map or one of OpenMap's windows is shown: a look every TICK seconds (new
-- frames, and texts OpenMap set before we hooked them).
local function AllFound()
    for _, name in ipairs(NAMED) do
        if type(rawget(_G, name)) ~= "table" then return false end
    end
    return true
end

-- The once-a-second look for new named windows: only with the module on, the World Map shown
-- and a named window still missing (some, like OpenMapReport, are rarely ever made).
local function Finding() return ns.On() and Visible(rawget(_G, "WorldMapFrame")) and not AllFound() end
local Find

-- `quiet`: only keep the tickers right; the look waits for the ticker's idle wait.
function S.Start(quiet)
    if ns.On() and S.WaitCombat() then return end   -- in combat no Collect: S.Start once after it
    if not ns.On() or not AnyShown() then
        StopTicker()
        if finder and not Finding() then finder:Cancel() finder = nil end
        return
    end
    if not ticker then ticker = C_Timer.NewTicker(TICK, SafeTick) end
    if not finder and Finding() then finder = C_Timer.NewTicker(FIND, function() U.SafeCall(Find) end) end
    if not quiet then Schedule() end
end

-- For the checks: true while the once-a-second look runs.
function S.Finding() return finder ~= nil end

-- How many of the named windows exist: a new one gets a look at once, otherwise the idle wait holds.
local named = 0
local function Named()
    local n = 0
    for _, name in ipairs(NAMED) do
        if type(rawget(_G, name)) == "table" then n = n + 1 end
    end
    return n
end

Find = function()
    if not Finding() then
        if finder then finder:Cancel() finder = nil end
    end
    if not ns.On() or S.WaitCombat() or not AnyShown() then return end
    local n = Named()
    if n ~= named then
        named, gap = n, TICK
        S.Start()
    else
        S.Start(true)
    end
end

-- At ADDON_LOADED, before OpenMap's PLAYER_LOGIN: catches the page OpenMap adds to Settings.
function S.CatchPanel()
    local st = rawget(_G, "Settings")
    if type(st) ~= "table" or type(st.RegisterCanvasLayoutCategory) ~= "function" or S.panelHooked then return end
    S.panelHooked = true
    hooksecurefunc(st, "RegisterCanvasLayoutCategory", function(frame, name)
        if name == "OpenMap" and type(frame) == "table" then S.panel = frame end
    end)
end

function S.Install()
    local map = rawget(_G, "WorldMapFrame")
    if type(map) == "table" and map.HookScript and not hookedRoot[map] then
        hookedRoot[map] = true
        map:HookScript("OnShow", OnRootHook)
        map:HookScript("OnHide", OnRootHook)
    end
    S.Start()
end

function S.Stop()
    StopTicker()
    if finder then finder:Cancel() finder = nil end
end
