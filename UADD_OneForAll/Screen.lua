-- UADD - OneForAll: its windows, walked by the core walker (U.Walk). Each text of theirs that is a whole text of
-- ours shows our Ukrainian, in UADD's Cyrillic font (lesson 32); off and the hold key give the English back where
-- ours still shows (lesson 23). OneForAll's own L, its saved data and the game's globals are never written.
--   * Roots: its named frames (the main window with its tabs and Settings, the info bar, the minimap and world map
--     buttons, its popups and small windows). A frame it makes later by its name prefix, or under a root, starts a
--     walk again (U.Walk's OnNewFrame), so windows made on first open are covered (lesson 2). Its drop-down list
--     (UI.OpenDropDown) and its own confirm box are under these roots or by the prefix.
--   * Left out: its map pins (OneForAllMapPin*: game names) and its hidden scan tooltip.
--   * The player's own names stay as typed (lesson 13): a text that is one of the player's profile names (its
--     saved profile list) is never ours, in any of its frames.
-- Any error leaves the English as it was (U.Walk runs each hook under a pcall that reports and counts).

local _, ns = ...
local U = UADD

local S = {}
ns.Screen = S

local ROOTS = { "OneForAllFrame", "OneForAllAlertTargetButton", "OneForAllBuffReminder", "OneForAllBuffReminderCast",
    "OneForAllChatHideButton", "OneForAllConfirm", "OneForAllConfirmSecure", "OneForAllCraftButton",
    "OneForAllCraftList", "OneForAllDungeonMapKey", "OneForAllInfoBar", "OneForAllInfoBarUse",
    "OneForAllMinimapButton", "OneForAllMinimapCollector", "OneForAllMinimapCollectorBar",
    "OneForAllWorldMapButton", "OneForAllWorldMapMenu", "OneForAllBagsFull", "OneForAllBugReport",
    "OneForAllCopyChat", "OneForAllDiscord", "OneForAllFlightTimer", "OneForAllGuildGames",
    "OneForAllGuildGamesInvite", "OneForAllGuildGamesTurn", "OneForAllLibraryInfoPopup", "OneForAllLootFeed",
    "OneForAllLowRank", "OneForAllNearbyAlert", "OneForAllPreviewFrame", "OneForAllProfilePopup",
    "OneForAllQuestChain", "OneForAllQuestSharePopup", "OneForAllRunTracker", "OneForAllSkillUpGuide",
    "OneForAllTalentCode", "OneForAllTrainerSpells", "OneForAllWeightEditor", "OneForAllWelcome" }
-- Frames of its prefix the walker leaves alone: map pins show game names; the scan tooltip is never shown; its
-- "Noteworthy changes" window and that window's screenshot stay English (lesson 43: never its news).
local SKIP_PREFIX = { "OneForAllMapPin", "OneForAllTrainerScanTip", "OneForAllWhatsNew", "OneForAllNewsShot" }

local isRoot = {}                -- the roots met (lesson 48: never left out when hidden); game frames are never freed
local function Roots()
    local list = {}
    for _, name in ipairs(ROOTS) do
        local f = rawget(_G, name)
        if type(f) == "table" then list[#list + 1] = f; isRoot[f] = true end
    end
    return list
end

-- Its hidden pages (lesson 48): OneForAll builds each page and each dungeon, pet or recipe view once and keeps it
-- hidden, so one walk over all of them passed the walker's 4000 frames and the pages made later stayed English.
-- A hidden frame that is not a root is left out of the walk. Each OnShow walks only that frame's own subtree, all
-- shown in one frame together, on the next frame, never in combat (a pooled row shown while scrolling costs its
-- few frames, never a whole walk). Its own SetScript("OnShow") drops our hook (lesson 2): each walk compares the
-- script with the one seen after hooking and hooks again. Roots keep the walker's own OnShow hook.
local waiting = {}               -- hidden frame -> its OnShow script as seen after our hook
local toWalk, queued = {}, false
local function WalkShown()
    queued = false
    if not ns.On() or not S.W then toWalk = {} return end
    if U.AfterCombat(WalkShown) then queued = true return end
    local list = toWalk
    toWalk = {}
    for f in pairs(list) do
        if f:IsShown() then pcall(S.W.Walk, f) end
    end
end
local function OnPageShow(f)
    if not ns.On() or type(f) ~= "table" then return end
    toWalk[f] = true
    if queued then return end
    queued = true
    if C_Timer and C_Timer.After then C_Timer.After(0, WalkShown) else WalkShown() end
end
local function Hidden(f)
    if isRoot[f] or type(f) ~= "table" or type(f.IsShown) ~= "function" or f:IsShown() ~= false then return false end
    if type(f.IsProtected) == "function" and f:IsProtected() then return false end
    local seen = waiting[f]
    if seen == nil or (seen and f:GetScript("OnShow") ~= seen) then
        if type(f.HookScript) ~= "function" or not pcall(f.HookScript, f, "OnShow", OnPageShow) then return false end
        waiting[f] = type(f.GetScript) == "function" and f:GetScript("OnShow") or false
    end
    return true
end

local function Skip(f, name)
    if type(name) == "string" then
        for i = 1, #SKIP_PREFIX do
            local p = SKIP_PREFIX[i]
            if name:sub(1, #p) == p then return true end
        end
    end
    return Hidden(f)
end

-- Lesson 13: the player's profile names, from its saved profile list (OneForAllDB.profiles: name -> profile).
-- Read each time the walker asks (a cheap table look), so a profile made or renamed now counts at once.
local function ProfileName(s)
    local db = rawget(_G, "OneForAllDB")
    if type(db) ~= "table" then return false end
    for _, field in ipairs({ "profiles", "profileKeys" }) do
        local t = rawget(db, field)
        if type(t) == "table" then
            if rawget(t, s) ~= nil then return true end
            for _, v in pairs(t) do
                if v == s or (type(v) == "table" and rawget(v, "name") == s) then return true end
            end
        end
    end
    return false
end

-- Its tab bar sizes each tab by its name's width when it lays the tabs out (UI.LayoutTabs, which also takes all
-- names down a size, 13 to 10, while they do not fit). Our longer names ran over the next tab, so once a tab name
-- of ours was seen, each change between ours and the English (a tab name of ours, on, off, the hold key and its
-- release) lays the bar out again with its own function: once, on the next frame, never in combat (lesson 36).
local relayout, tabsOurs = false, false
local function Relayout()
    if U.AfterCombat(Relayout) then return end         -- still queued: no second chain in combat
    relayout = false
    local F = rawget(_G, "OneForAll")
    local ui = type(F) == "table" and rawget(F, "UI")
    local lay = type(ui) == "table" and rawget(ui, "LayoutTabs")
    if type(lay) == "function" then
        local ok, err = pcall(lay)
        if not ok then pcall(U.ReportError, tostring(err)) end
    end
end
local function Queue()
    if relayout or not tabsOurs then return end
    relayout = true
    if C_Timer and C_Timer.After then C_Timer.After(0, Relayout) else Relayout() end
end
local function TabName(fs)
    if relayout or type(fs) ~= "table" or type(fs.GetParent) ~= "function" then return end
    local ok, b = pcall(fs.GetParent, fs)
    if not ok or type(b) ~= "table" or rawget(b, "_label") ~= fs or type(rawget(b, "_place")) ~= "function" then return end
    tabsOurs = true
    Queue()
end
S.TabName = TabName

-- Lesson 13 also for a name in a colour or with a colon after it (Words.lua `Dressed`).
local function Typed(s)
    local core = s:gsub("^|c%x%x%x%x%x%x%x%x", ""):gsub("|r$", "")
    if core ~= s and ProfileName(core) then return true end
    local bare = core:gsub(":$", "")
    return bare ~= core and ProfileName(bare)
end

local W = U.Walk({
    key = "oneforall",
    title = "OneForAll",
    On = function() return ns.On() end,
    Wanted = function() return ns.WordsWanted() end,
    roots = Roots,
    skip = Skip,
    Lookup = function(en, fs)
        local s = U.Plain(en)
        if not s or ProfileName(s) then return nil, false end
        if Typed(s) then return nil, false end
        local uk = ns.Words.Translate(s)
        if uk then TabName(fs) end
        return uk
    end,
    prefix = "OneForAll",
    font = true,
    hints = true,                                  -- the item search box's "Search all items..." (lesson 44)
})
S.W = W

local tabHook = false
function S.Install()
    if not ns.On() then return end
    W.Install()
    if not tabHook then
        tabHook = true
        U.OnOriginal(function() if ns.On() then Queue() end end, "OneForAll tabs")
    end
end
-- On: walk again; off or held: the English back where ours shows. Either way the tab bar is laid out again.
function S.Sync()
    W.Sync()
    Queue()
end
function S.Remove()
    W.Sync()
    W.Remove()
    W.Forget()
    Queue()
end
function S.Later() W.Later() end
function S.Count() return W.Count() end
function S.Shown() return W.Shown() end
S.ProfileName = ProfileName                       -- for the checks
