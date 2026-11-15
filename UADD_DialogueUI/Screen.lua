-- Finds DialogueUI's FontStrings and hands them to Texts.lua (hook once, then our words).
-- The roots: the global frames DUIQuestFrame (dialogue window), DUIDialogSettings (settings) and
-- DUIBookFrame (books), and DialogueUI's own tooltips, which have no name: they are found by walking
-- all frames (EnumerateFrames) once, again only while fewer than two are known, and cached.
-- When we look: a root shows (OnShow), the frame after a QUEST_* / GOSSIP_* event, and every TICK
-- seconds while a root is shown (new pooled FontStrings, a new settings tab). Once hooked, each
-- FontString's SetText swaps the words itself. Hidden FontStrings of shown frames are hooked too (a
-- pooled one shows our words from its first SetText); only shown ones are changed. Secure (protected)
-- frames, like the use-item button, are never entered. Nothing is changed in combat: a look asked
-- for then runs when combat ends.

local _, ns = ...
local U = UADD
local S = {}
ns.Screen = S
if type(UADD) == "table" then UADD.DialogueUIScreen = S end   -- for the checks (tools/harness)

local MIN_GAP, TICK, FIND_GAP = 0.2, 0.5, 5
local NAMED = { "DUIQuestFrame", "DUIDialogSettings", "DUIBookFrame" }
local EVENTS = { "QUEST_GREETING", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "GOSSIP_SHOW",
    "QUEST_ITEM_UPDATE" }

local tips, roots, seen, hookedRoot = {}, {}, {}, {}
local pending, last, ticker, lastFind = false, 0, nil, -100

local function Visible(f) return type(f) == "table" and f.IsVisible and f:IsVisible() or false end

-- Nothing is changed in combat: a change asked for then waits until combat ends.
local waiter = CreateFrame("Frame")
waiter:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    if not ns.On() then return S.Restore() end
    U.SafeCall(ns.Texts.Sync)
    S.Schedule()
end)

function S.WaitCombat()
    if not (InCombatLockdown and InCombatLockdown()) then return false end
    waiter:RegisterEvent("PLAYER_REGEN_ENABLED")
    return true
end

-- DialogueUI's tooltip (CreateTooltipBase): a nameless frame with its mixin's methods on it.
local function IsTip(f)
    return type(f) == "table" and type(rawget(f, "AddDoubleLine")) == "function"
        and type(rawget(f, "AddLeftLine")) == "function" and rawget(f, "ShowFrame") ~= nil
        and rawget(f, "HideFrame") ~= nil
end

local function FindTips()
    local gap = #tips == 0 and FIND_GAP or FIND_GAP * 6   -- the second one is made on first use
    if #tips >= 2 or type(EnumerateFrames) ~= "function" or GetTime() - lastFind < gap then return end
    lastFind = GetTime()
    local known = {}
    for _, t in ipairs(tips) do known[t] = true end
    local f = EnumerateFrames()
    while f do
        if not known[f] and IsTip(f) then tips[#tips + 1] = f end
        f = EnumerateFrames(f)
    end
end

local function Collect()
    wipe(roots)
    for _, name in ipairs(NAMED) do
        local f = rawget(_G, name)
        if type(f) == "table" then roots[#roots + 1] = f end
    end
    for _, t in ipairs(tips) do roots[#roots + 1] = t end
end

-- A window shows or hides: texts the hold key skipped while hidden are put right at once.
local function OnRoot()
    if ns.On() and not (InCombatLockdown and InCombatLockdown()) then U.SafeCall(ns.Texts.Flush) end
    S.Start()
end

local function AnyShown()
    Collect()
    local any = false
    for _, f in ipairs(roots) do
        if not hookedRoot[f] and f.HookScript then
            hookedRoot[f] = true
            f:HookScript("OnShow", OnRoot)
            f:HookScript("OnHide", OnRoot)
        end
        any = any or Visible(f)
    end
    return any
end

local function Walk(f)
    if seen[f] or not Visible(f) then return end
    seen[f] = true
    if f.IsProtected and f:IsProtected() then return end   -- secure frames: never ours
    if f.GetRegions then
        for _, g in ipairs({ f:GetRegions() }) do
            if g.GetObjectType and g:GetObjectType() == "FontString" then
                ns.Texts.Hook(g)                       -- hidden ones too: a pooled FontString's or
                if g:IsVisible() then ns.Texts.Apply(g) end   -- tooltip line's next SetText is caught
            end
        end
    end
    if f.GetChildren then
        for _, c in ipairs({ f:GetChildren() }) do Walk(c) end
    end
end

-- Quest and book text: a FontString right on a window's ContentFrame. DialogueUI's fontStringPool
-- makes its paragraphs (the game's quest prose, its translations) and sub-headers there; buttons
-- and rewards have their FontStrings on their own frames.
function S.IsBody(fs)
    local p = fs.GetParent and fs:GetParent()
    if not p then return false end
    for _, name in ipairs(NAMED) do
        local f = rawget(_G, name)
        if type(f) == "table" and rawget(f, "ContentFrame") == p then return true end
    end
    return false
end

-- Runs now: our words on every shown text of DialogueUI's windows.
function S.Scan()
    if not ns.On() or S.WaitCombat() then return end
    FindTips()
    Collect()
    wipe(seen)
    local ok, err = pcall(function()
        for _, f in ipairs(roots) do Walk(f) end
    end)
    wipe(seen)
    if not ok then error(err, 0) end
end

local function StopTicker()
    if ticker then ticker:Cancel() ticker = nil end
end

local function Run()
    pending = false
    last = GetTime()
    U.SafeCall(S.Scan)
    if not AnyShown() then StopTicker() end
end

-- At most one look per MIN_GAP, and none while none of DialogueUI's windows is shown.
function S.Schedule()
    if pending or not ns.On() or S.WaitCombat() or not AnyShown() then return end
    pending = true
    C_Timer.After(math.max(0, last + MIN_GAP - GetTime()), Run)
end

function S.Start()
    if not ns.On() or not AnyShown() then return StopTicker() end
    if not ticker then ticker = C_Timer.NewTicker(TICK, S.Schedule) end
    S.Schedule()
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function()
    C_Timer.After(0, function() U.SafeCall(S.Start) end)
end)

-- Once DialogueUI is loaded and the module is on.
function S.Install()
    for _, e in ipairs(EVENTS) do pcall(events.RegisterEvent, events, e) end
    FindTips()
    S.Start()
end

-- Every text and font back as DialogueUI had it (module off).
function S.Restore()
    U.SafeCall(ns.Texts.Restore)
    U.SafeCall(ns.Fonts.Restore)
end

function S.Stop()
    StopTicker()
    events:UnregisterAllEvents()
end

-- For the checks: the tooltips found so far.
function S.Tips() return tips end
