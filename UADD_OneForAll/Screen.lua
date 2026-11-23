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
    "OneForAllQuestChain", "OneForAllQuestSharePopup", "OneForAllSkillUpGuide", "OneForAllTalentCode",
    "OneForAllTrainerSpells", "OneForAllWeightEditor", "OneForAllWelcome" }
-- Frames of its prefix the walker leaves alone: map pins show game names; the scan tooltip is never shown; its
-- "Noteworthy changes" window and that window's screenshot stay English (lesson 43: never its news).
local SKIP_PREFIX = { "OneForAllMapPin", "OneForAllTrainerScanTip", "OneForAllWhatsNew", "OneForAllNewsShot" }

local function Roots()
    local list = {}
    for _, name in ipairs(ROOTS) do
        local f = rawget(_G, name)
        if type(f) == "table" then list[#list + 1] = f end
    end
    return list
end

local function Skip(_, name)
    if type(name) ~= "string" then return false end
    for i = 1, #SKIP_PREFIX do
        local p = SKIP_PREFIX[i]
        if name:sub(1, #p) == p then return true end
    end
    return false
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
        return ns.Words.Translate(s)
    end,
    prefix = "OneForAll",
    font = true,
})
S.W = W

function S.Install()
    if not ns.On() then return end
    W.Install()
end
-- On: walk again; off or held: the English back where ours shows.
function S.Sync() W.Sync() end
function S.Remove()
    W.Sync()
    W.Remove()
    W.Forget()
end
function S.Later() W.Later() end
function S.Count() return W.Count() end
function S.Shown() return W.Shown() end
S.ProfileName = ProfileName                       -- for the checks
