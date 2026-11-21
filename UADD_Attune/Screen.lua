-- Finds Attune's FontStrings and hands them to Texts.lua (hook once, then our words).
-- The roots, all by name (no walk over every frame of the game): the main window (an AceGUI Frame:
-- tree, step graph, status bar, results lists), the survey menu, the Next window, the quest reward
-- and quest detail panels, the sync progress bar, and Attune's pages in the game's Settings window
-- (AceConfigDialog's BlizOptions["Attune"], read with rawget). The list is made again only when a root
-- is missing from it, or once on the next frame after a look was asked for.
-- Never entered: edit boxes (what the player types, the export string) and secure frames.
-- When we look:
--   * a root shows (OnShow, now and again one frame later, when Attune has filled it);
--   * after Attune's own functions that build or rebuild a view (post-hooks with hooksecurefunc on
--     the globals: picking an attunement, the tree, the results list, the Next window ...): a look at
--     once (new texts are ours on their first draw) and one on the next frame, however many of them
--     ran. At once only one look per frame, unless a frame was made inside Attune's windows since the
--     last one (Attune_NextFrameRefresh calls Attune_NextFrameLayout: one look, not two). The Next
--     window functions run on every bag change, so they look at the Next window only;
--   * after AceGUI makes a widget for Attune (Claim.lua) or while Attune's settings page shows; never
--     because another addon made one while the Next window shows.
-- A hidden frame looked at before, with the same number of children and regions, is not entered
-- again, unless a frame was made inside it since (a post-hook on CreateFrame marks its parents).
-- Hidden texts there are hooked already; a frame that shows is always entered.
-- Once hooked, each FontString's SetText swaps the words itself (reused rows and step boxes too).
-- AceGUI widgets are pooled: when AceGUI releases one we walked or claimed, its texts and fonts go
-- back and are forgotten (a post-hook on AceGUI:Release), so another addon never gets our words.
-- In combat only a cheap look (Texts.lua); a full look waits until it ends.

local _, ns = ...
local U = UADD
local S = {}
ns.Screen = S
if type(UADD) == "table" then UADD.AttuneScreen = S end   -- for the checks (tools/harness)

local ROOTS = { "Attune_MainFrame", "Attune_SurveyMenuFrame", "Attune_NextFrame", "AttuneQuestRewardFrame",
    "AttuneQuestDetail", "Attune_SyncProgress_Frame", "Attune_GraphRoot" }
local VIEW = { "Attune_Frame", "Attune_Select", "Attune_LoadTree", "Attune_UpdateTreeGroup",
    "Attune_ReloadAttuneTree", "Attune_ToggleView", "Attune_ShowResultList", "Attune_ShowIconView",
    "Attune_LayoutIconView", "Attune_RefreshAttunePanel", "Attune_ForceAttuneTabRefresh",
    "Attune_ShowQuestRewards", "Attune_ShowQuestDetail", "Attune_ShowWebsiteURL", "Attune_StartSync",
    "Attune_InstallCategoryOptions", "Attune_UpdateLogs" }
local NEXT = { "Attune_NextFrameLayout", "Attune_NextFrameRefresh", "Attune_NextFrameSetMinimized" }

local roots, rootSet, seen, hookedRoot = {}, {}, {}, {}
-- Frames we walked: true for a shown one, its number of children and regions for a hidden one.
local walked = setmetatable({}, { __mode = "k" })
local pendingAll, pendingNext = false, false
local doneAll, doneNext = false, false   -- a look at once already ran this frame
local dirty = false                      -- a frame was made inside Attune's windows since that look
local collectDue = true                  -- make the root list again at the next look
local installed = false
local walks = 0                          -- for the checks: how many walks so far

local function Visible(f) return type(f) == "table" and f.IsVisible and f:IsVisible() or false end
local function AceLib(name) return type(LibStub) == "table" and LibStub(name, true) or nil end

-- In combat only known texts change (Texts.lua's cheap look); the rest waits until combat ends.
local waiter = CreateFrame("Frame")
waiter:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    if not ns.On() then return S.Restore() end
    U.SafeCall(ns.Texts.Sync)
    U.SafeCall(ns.Tooltip.Sync, not ns.WordsWanted())
    U.SafeCall(ns.Popup.Sync)
    U.SafeCall(S.Scan)
end)

function S.WaitCombat()
    if not (InCombatLockdown and InCombatLockdown()) then return false end
    waiter:RegisterEvent("PLAYER_REGEN_ENABLED")
    return true
end

local OnRoot

-- Attune's pages in the game's Settings window (AceGUI widgets), or nil.
local function Pages()
    local acd = AceLib("AceConfigDialog-3.0")
    local blz = type(acd) == "table" and rawget(acd, "BlizOptions")
    local pages = type(blz) == "table" and rawget(blz, "Attune")
    return type(pages) == "table" and pages or nil
end

local function Missing()
    for _, name in ipairs(ROOTS) do
        local f = rawget(_G, name)
        if type(f) == "table" and not rootSet[f] then return true end
    end
    return false
end

local function Collect(force)
    if not (force or collectDue or next(rootSet) == nil or Missing()) then return end
    collectDue = false
    wipe(roots) wipe(rootSet)
    local function Add(f)
        if type(f) ~= "table" or rootSet[f] then return end
        roots[#roots + 1], rootSet[f] = f, true
        if not hookedRoot[f] then
            hookedRoot[f] = true
            if f.HookScript then f:HookScript("OnShow", OnRoot) end
        end
    end
    for _, name in ipairs(ROOTS) do Add(rawget(_G, name)) end
    for _, w in pairs(Pages() or {}) do
        if type(w) == "table" then Add(rawget(w, "frame")) end
    end
end

-- The set of root frames (Tooltip.lua: is an owner one of Attune's frames?). Asked on every SetText,
-- so it does not look for missing roots (each look does).
function S.RootSet()
    if collectDue or next(rootSet) == nil then Collect(true) end
    return rootSet
end

-- f, or a frame it is inside, is one of the roots.
function S.Inside(f)
    local set = S.RootSet()
    for _ = 1, 30 do
        if type(f) ~= "table" then return false end
        if set[f] then return true end
        f = f.GetParent and f:GetParent() or nil
    end
    return false
end

local function Skipped(f)
    return (f.IsProtected and f:IsProtected()) or (f.IsObjectType and f:IsObjectType("EditBox")) or false
end

local function Count(f)
    return (f.GetChildren and select("#", f:GetChildren()) or 0) + (f.GetRegions and select("#", f:GetRegions()) or 0)
end

-- A shown root and everything in it, hidden frames too (a panel sets its text and then shows: its
-- FontString must be hooked by then). Our words go on the shown texts now.
local function Walk(f, parent)
    if seen[f] then return end
    local shown = Visible(f)
    if not parent and not shown then return end
    seen[f] = true
    if Skipped(f) then return end
    if shown then
        walked[f] = true
    else
        local n = Count(f)
        if walked[f] == n then return end          -- hidden, looked at before, nothing new in it
        walked[f] = n
    end
    if f.GetRegions then
        for _, g in ipairs({ f:GetRegions() }) do
            if g.GetObjectType and g:GetObjectType() == "FontString" then
                ns.Texts.Hook(g)                       -- hidden ones too: their next SetText is caught
                if shown and g:IsVisible() then ns.Texts.Apply(g) end
            end
        end
    end
    if f.GetChildren then
        for _, c in ipairs({ f:GetChildren() }) do Walk(c, f) end
    end
end

local function WalkList(list)
    walks = walks + 1
    wipe(seen)
    local ok, err = pcall(function() for _, f in ipairs(list) do Walk(f) end end)
    wipe(seen)
    if not ok then error(err, 0) end
end

-- Runs now: our words on every shown text of the shown roots.
function S.Scan()
    if not ns.On() or S.WaitCombat() then return end
    Collect()
    WalkList(roots)
    ns.Tooltip.Look()
end

local function WalkOne(f)
    if not ns.On() or S.WaitCombat() then return end
    Collect()
    if rootSet[f] then WalkList({ f }) end
end

-- A window shows: new texts hooked and put right, and once more one frame later (Attune fills
-- some of them in its own OnShow).
OnRoot = function(f)
    if not ns.On() or (InCombatLockdown and InCombatLockdown()) then return end
    U.SafeCall(WalkOne, f)
    C_Timer.After(0, function() U.SafeCall(WalkOne, f) end)
end

local function Flush()
    local all, nxt = pendingAll, pendingNext
    pendingAll, pendingNext, doneAll, doneNext, collectDue = false, false, false, false, true
    if all then S.Scan() elseif nxt then WalkOne(rawget(_G, "Attune_NextFrame")) end
end

-- One look on the next frame, however many calls come before it. nextOnly: the Next window only.
function S.Queue(nextOnly)
    if not ns.On() then return end
    local first = not (pendingAll or pendingNext)
    if nextOnly then pendingNext = true else pendingAll = true end
    if first then C_Timer.After(0, function() U.SafeCall(Flush) end) end
end

-- After one of Attune's view functions: a look now (the texts it just made are ours before the game
-- draws them; once per frame unless something new was made) and the one on the next frame.
local function After(nextOnly)
    if ns.On() and not (InCombatLockdown and InCombatLockdown()) and (dirty or not (doneAll or nextOnly and doneNext)) then
        dirty = false
        if nextOnly then
            doneNext = true
            U.SafeCall(WalkOne, rawget(_G, "Attune_NextFrame"))
        else
            doneAll = true
            U.SafeCall(S.Scan)
        end
    end
    S.Queue(nextOnly)
end

local function SettingsShown()
    for _, w in pairs(Pages() or {}) do
        if type(w) == "table" and Visible(rawget(w, "frame")) then return true end
    end
    return false
end

-- A frame made inside one we walked: it and the ones around it are entered again. Every CreateFrame of the game
-- passes here (U.OnNewFrame, under U.SafeCall): odd arguments leave at the first type or table look-up.
local function OnNewFrame(_, _, parent)
    if type(parent) == "string" then parent = rawget(_G, parent) end
    if type(parent) ~= "table" or walked[parent] == nil then return end
    dirty = true
    for _ = 1, 30 do
        if type(parent) ~= "table" or walked[parent] == nil then return end
        walked[parent] = true
        local up = parent.GetParent
        parent = type(up) == "function" and up(parent) or nil
    end
end

-- A widget AceGUI gives back to its pool: what we put on its texts and fonts goes back, forgotten.
local function ForgetIn(f, depth)
    if depth > 8 or type(f) ~= "table" then return end
    walked[f] = nil
    if f.GetRegions then
        for _, g in ipairs({ f:GetRegions() }) do if ns.Texts.Known(g) then ns.Texts.Forget(g) end end
    end
    if f.GetChildren then
        for _, c in ipairs({ f:GetChildren() }) do if walked[c] then ForgetIn(c, depth + 1) end end
    end
end

local function OnRelease(_, widget)
    ns.Claim.Release(widget)
    local f = type(widget) == "table" and rawget(widget, "frame")
    if f and walked[f] then ForgetIn(f, 0) end
end

local function OnCreate(_, widgetType)
    local _, mine = U.SafeCall(ns.Claim.OnCreate, widgetType)
    if mine then dirty = true end
    if not pendingAll and ns.On() and (mine or SettingsShown()) then S.Queue(false) end
end

-- Once Attune is loaded and the module is on: the post-hooks (each one only once per session).
function S.Install()
    Collect(true)
    if installed then return end
    installed = true
    for _, name in ipairs(VIEW) do
        if type(rawget(_G, name)) == "function" then hooksecurefunc(name, function() After(false) end) end
    end
    for _, name in ipairs(NEXT) do
        if type(rawget(_G, name)) == "function" then hooksecurefunc(name, function() After(true) end) end
    end
    U.OnNewFrame(OnNewFrame)
    local gui = AceLib("AceGUI-3.0")
    U.SafeCall(ns.Claim.Install, gui)
    if type(gui) == "table" and type(gui.Release) == "function" then
        hooksecurefunc(gui, "Release", function(...) U.SafeCall(OnRelease, ...) end)
    end
    if type(gui) == "table" and type(gui.Create) == "function" then
        hooksecurefunc(gui, "Create", function(...) U.SafeCall(OnCreate, ...) end)
    end
end

-- Every text and font back as Attune had it (module off).
function S.Restore()
    U.SafeCall(ns.Texts.Restore)
    U.SafeCall(ns.Popup.Restore)
    U.SafeCall(ns.Fonts.Restore)
    U.SafeCall(ns.Tooltip.Sync, true)
    U.SafeCall(ns.Tooltip.Stop)
end

-- For the checks: the roots found so far; true once the post-hooks are in; how many walks so far.
function S.Roots() return roots end
function S.Installed() return installed end
function S.Walks() return walks end
