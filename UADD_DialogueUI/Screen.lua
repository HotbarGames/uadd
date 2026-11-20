-- Finds DialogueUI's FontStrings and hands them to Texts.lua (hook once, then our words).
-- The roots: the global frames DUIQuestFrame (dialogue window), DUIDialogSettings (settings) and
-- DUIBookFrame (books), and DialogueUI's own tooltips, which have no name: they are found by walking
-- all frames (EnumerateFrames) once, again only while fewer than two are known, and cached; and its
-- nameless page in the game's options (FindCanvas below).
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

-- DialogueUI's page in the game's options (Options > AddOns > Dialogue UI): a nameless canvas it gives
-- to Settings.RegisterCanvasLayoutCategory when it loads. Its one child is a button with its "Open
-- Settings" L value (known here by that value's hash), and it sets its instruction line on each show
-- (its first OnShow then replaces itself with SetScript, so a hook on that OnShow does not last). It
-- is found by walking all frames: at Install, and when the game's options window opens or a page in
-- it is picked (a user's click, not a game-wide path), until found. Its FontStrings are hooked at once, so the instruction line set on the
-- first show is caught; the button's text (set once, by Button:SetText) is changed by the look that
-- the options window asks for, as the page shows.
local canvas

local function IsCanvas(f)
    if type(f) ~= "table" or (f.IsForbidden and f:IsForbidden()) or not f.GetChildren or not f.GetRegions or (f.GetName and f:GetName()) then return false end
    local want = type(ns.DUI_HASH) == "table" and type(ns.DUI_HASH["Open Settings"]) == "table"
        and ns.DUI_HASH["Open Settings"].e
    if not want or (f.GetNumChildren and f:GetNumChildren() ~= 1) then return false end
    local b = f:GetChildren()
    if not (b and b.GetObjectType and b:GetObjectType() == "Button" and b.GetText) then return false end
    local t = UADD.Plain(b:GetText())
    if type(t) ~= "string" or #t .. ":" .. (U.Hash(t) or "") ~= want then return false end
    for _, g in ipairs({ f:GetRegions() }) do
        if g.GetObjectType and g:GetObjectType() == "FontString" then return true end
    end
    return false
end

local function HookCanvas(f)
    for _, g in ipairs({ f:GetRegions() }) do
        if g.GetObjectType and g:GetObjectType() == "FontString" then ns.Texts.Hook(g) end
    end
    local b = f:GetChildren()
    local fs = b and b.GetFontString and b:GetFontString()
    if fs then ns.Texts.Hook(fs) end
end

local function FindCanvas()
    if canvas or type(EnumerateFrames) ~= "function" then return end
    local f = EnumerateFrames()
    while f do
        if IsCanvas(f) then
            canvas = f
            HookCanvas(f)
            return
        end
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
    if canvas then roots[#roots + 1] = canvas end
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

-- The game's options window opens, or a page in it is picked: look once the page shows (next frame;
-- the open and the pick in one frame make one look).
local panelHooked, panelPending = false, false
local function OnPanel()
    if panelPending then return end
    panelPending = true
    C_Timer.After(0, function()
        panelPending = false
        if not ns.On() then return end
        U.SafeCall(FindCanvas)
        U.SafeCall(S.Start)
    end)
end

local function HookPanel()
    local panel = rawget(_G, "SettingsPanel")
    if panelHooked or type(panel) ~= "table" or not panel.HookScript then return end
    panelHooked = true
    panel:HookScript("OnShow", OnPanel)
    if type(panel.SelectCategory) == "function" then hooksecurefunc(panel, "SelectCategory", OnPanel) end
end

-- Once DialogueUI is loaded and the module is on.
function S.Install()
    for _, e in ipairs(EVENTS) do pcall(events.RegisterEvent, events, e) end
    FindTips()
    U.SafeCall(FindCanvas)
    HookPanel()
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

-- For the checks: the tooltips found so far, and DialogueUI's options page once found.
function S.Tips() return tips end
function S.Canvas() return canvas end
