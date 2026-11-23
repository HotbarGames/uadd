-- Finds ForeverXP Bar's FontStrings and hands them to Texts.lua (hook once, then our words).
-- The roots:
--   * its named frames (NAMED): the bar, flight line, minimap button, options, settings, record,
--     banner, session summary, level-up card, race windows;
--   * nameless ones, found by walking all frames (EnumerateFrames) a few times only: its two pages
--     in the game's Settings window (page.name is the addon's name; made at PLAYER_ENTERING_WORLD),
--     and, made with the options window, the lists of its drop-downs (on UIParent, anchored to a button
--     inside one of its named frames).
-- Never entered: ForeverXPBarScanTip (it reads item lines back), edit boxes' text, secure frames, and its
-- What's New page (a nameless dialog on UIParent): it stays English, as players read the news before our
-- update comes; data/words.lua holds none of its texts either (tools/make_fxpb_data.py, "news").
-- When we look: a root shows (OnShow, which also puts right texts the hold key skipped while
-- hidden), and every TICK seconds: the shown windows, and the always-shown bar every BAR_EVERY ticks
-- (a new camp icon or tab). Once hooked, each FontString's SetText swaps the words itself, so the
-- bar's per-tick texts need no look. In combat only a cheap look (Texts.lua); a full look waits until it ends.

local _, ns = ...
local U = UADD
local S = {}
ns.Screen = S
if type(UADD) == "table" then UADD.ForeverXPBarScreen = S end   -- for the checks (tools/harness)

local TICK, BAR_EVERY, FIND_GAP = 1, 3, 5
local BAR = { "ForeverXPBarMainFrame", "ForeverXPBarFlightLine", "ForeverXPBarMinimapButton" }
local NAMED = { "ForeverXPBarOptionsFrame", "ForeverXPBarSettingsFrame", "ForeverXPBarRecordFrame",
    "ForeverXPBarBanner", "ForeverXPBarSummary", "ForeverXPBarCard", "ForeverXPBarRace",
    "ForeverXPBarRaceAll" }
local PAGES = { ["ForeverXP Bar"] = true, ["Forever Challenge XP"] = true }
local SKIP = { ForeverXPBarScanTip = true }
local OURS = {}
for _, name in ipairs(NAMED) do OURS[name] = true end
for _, name in ipairs(BAR) do OURS[name] = true end

local extras, extraSet, roots, rootSet, seen, hookedRoot = {}, {}, {}, {}, {}, {}
local ticker, ticks, lastFind = nil, 0, -100
local pages, built = 0, false   -- Settings pages found; the options window (and all made with it) looked at

local function Visible(f) return type(f) == "table" and f.IsVisible and f:IsVisible() or false end

-- In combat only known texts change (Texts.lua's cheap look); the rest waits until combat ends.
local waiter = CreateFrame("Frame")
waiter:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    if not ns.On() then return S.Restore() end
    U.SafeCall(ns.Texts.Sync)
    U.SafeCall(ns.Popup.Sync)
    U.SafeCall(S.Scan, true)
end)

function S.WaitCombat()
    if not (InCombatLockdown and InCombatLockdown()) then return false end
    waiter:RegisterEvent("PLAYER_REGEN_ENABLED")
    return true
end

-- f, or a frame it is inside, is one of ForeverXP Bar's named frames.
local function InOurs(f)
    for _ = 1, 30 do
        if type(f) ~= "table" then return false end
        local name = f.GetName and f:GetName()
        if name and OURS[name] then return true end
        f = f.GetParent and f:GetParent()
    end
    return false
end

-- A nameless frame of ForeverXP Bar's: "page" (Settings), "pop" (a drop-down's list). Its What's New
-- page (on UIParent, anchored to UIParent) is neither, so it is never a root.
local function Kind(f)
    if f.GetName and f:GetName() then return nil end
    if PAGES[rawget(f, "name")] then return "page" end
    if not (f.GetParent and f:GetParent() == UIParent and f.GetFrameStrata
        and f:GetFrameStrata() == "FULLSCREEN_DIALOG") then return nil end
    if f.GetNumPoints and f:GetNumPoints() > 0 then
        local _, rel = f:GetPoint(1)
        if rel ~= UIParent and InOurs(rel) then return "pop" end
    end
    return nil
end

local Collect

-- force: now, else at most every FIND_GAP seconds. Done once both pages and the options window's
-- frames are found (the options window makes its lists at once, when it is first built).
local function FindExtra(force)
    if (pages >= 2 and built) or not ns.On() or type(EnumerateFrames) ~= "function" then return end
    if not force and GetTime() - lastFind < FIND_GAP then return end
    lastFind = GetTime()
    if rawget(_G, "ForeverXPBarOptionsFrame") then built = true end
    local n, f = #extras, EnumerateFrames()
    while f do
        if not extraSet[f] then
            local kind = Kind(f)
            if kind then
                extras[#extras + 1], extraSet[f] = f, true
                if kind == "page" then pages = pages + 1 end
            end
        end
        f = EnumerateFrames(f)
    end
    if #extras > n then Collect() end   -- their OnShow hooks on at once
end

local OnRoot

Collect = function()
    wipe(roots) wipe(rootSet)
    local function Add(f, bar)
        if type(f) ~= "table" or rootSet[f] then return end
        roots[#roots + 1], rootSet[f] = { f = f, bar = bar }, true
        if not hookedRoot[f] and f.HookScript then
            hookedRoot[f] = true
            f:HookScript("OnShow", OnRoot)
        end
    end
    for _, name in ipairs(BAR) do Add(rawget(_G, name), true) end
    for _, name in ipairs(NAMED) do Add(rawget(_G, name), false) end
    for _, f in ipairs(extras) do Add(f, false) end
end

-- The set of root frames (Tooltip.lua: is a tooltip's owner one of ForeverXP Bar's frames?).
function S.RootSet()
    if next(rootSet) == nil then Collect() end
    return rootSet
end

local function Walk(f)
    if seen[f] or not Visible(f) then return end
    seen[f] = true
    if (f.IsProtected and f:IsProtected()) or (f.GetName and SKIP[f:GetName() or ""]) then return end
    if f.GetRegions then
        for _, g in ipairs({ f:GetRegions() }) do
            if g.GetObjectType and g:GetObjectType() == "FontString" then
                ns.Texts.Hook(g)                       -- hidden ones too: their next SetText is caught
                if g:IsVisible() then ns.Texts.Apply(g) end
            end
        end
    end
    if f.GetChildren then
        for _, c in ipairs({ f:GetChildren() }) do Walk(c) end
    end
end

-- Runs now: our words on every shown text of the shown roots. bar: the bar roots too.
function S.Scan(bar)
    if not ns.On() or S.WaitCombat() then return end
    Collect()
    wipe(seen)
    local ok, err = pcall(function()
        for _, r in ipairs(roots) do
            if bar ~= false or not r.bar then Walk(r.f) end
        end
    end)
    wipe(seen)
    if not ok then error(err, 0) end
end

-- A window shows: texts the hold key skipped while hidden are put right at once, new ones hooked.
OnRoot = function(f)
    if not ns.On() or (InCombatLockdown and InCombatLockdown()) then return end
    U.SafeCall(ns.Texts.Flush)
    if f == rawget(_G, "ForeverXPBarOptionsFrame") or f == rawget(_G, "ForeverXPBarSettingsFrame") then
        FindExtra()   -- the drop-down lists are made with the options window
    end
    if rootSet[f] then
        wipe(seen)
        U.SafeCall(Walk, f)
        wipe(seen)
    end
end

local function Tick()
    if not ns.On() or (InCombatLockdown and InCombatLockdown()) then return end
    if not built and rawget(_G, "ForeverXPBarOptionsFrame") then U.SafeCall(FindExtra, true) end
    ticks = ticks + 1
    U.SafeCall(S.Scan, ticks % BAR_EVERY == 0)
end

function S.Start()
    if not ns.On() then return end
    if not ticker then ticker = C_Timer.NewTicker(TICK, Tick) end
end

-- Once ForeverXP Bar is loaded and the module is on.
function S.Install()
    FindExtra(true)
    S.Start()
end

-- PLAYER_ENTERING_WORLD: ForeverXP Bar makes its Settings pages then (after this handler, maybe).
function S.World()
    if pages >= 2 or not ns.On() then return end
    C_Timer.After(0, function() U.SafeCall(FindExtra, true) end)
end

-- Every text and font back as ForeverXP Bar had it (module off).
function S.Restore()
    U.SafeCall(ns.Texts.Restore)
    U.SafeCall(ns.Popup.Restore)
    U.SafeCall(ns.Fonts.Restore)
    U.SafeCall(ns.Tooltip.Sync, true)
    U.SafeCall(ns.Tooltip.Stop)
end

function S.Stop()
    if ticker then ticker:Cancel() ticker = nil end
end

-- For the checks: the nameless frames found so far.
function S.Extras() return extras end
