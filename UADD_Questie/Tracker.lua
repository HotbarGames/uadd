-- UADD - Questie: the quest tracker (the list of quests on the screen) stays English.
--
-- UALL Forever translates the tracker (its QuestieHooks.lua) and picks a Cyrillic font for each
-- line it translates. It skips a line that already has Cyrillic letters. Questie builds tracker
-- lines from the game's quest log (English) plus a few of its own words through l10n(), such as
-- "(Complete)" (Modules/Tracker/TrackerData.lua:270-276). Under our language those words would be
-- Ukrainian, so a line would be half English, UALLF would skip it, and the tracker font would draw
-- boxes. So while Questie draws the tracker, its l10n() speaks English (Localization/l10n.lua,
-- SetUILocale and GetUILocale), and every line reaches UALLF in English. Without UALLF the
-- tracker is all English.
--
-- The tracker is drawn by these QuestieTracker functions (Questie 12.10, QuestieTracker.lua:834,
-- 980, 1476, 1485). Questie calls them through the module table, and its header button keeps the
-- one it gets at Questie's start (:249), which is after our ADDON_LOADED. So our wrappers run.

local _, ns = ...
local T = {}
ns.Tracker = T
local L = ns.Locale

local function Module(name)
    local ok, mod = pcall(function() return QuestieLoader:ImportModule(name) end)
    return ok and type(mod) == "table" and mod or nil
end

-- Our own part never breaks Questie: any error in it means "no change".
local function Try(fn, ...)
    local ok, result = pcall(fn, ...)
    return ok and result or nil
end

-- ── English while the tracker is drawn ────────────────────────────────────────────────────────

local DRAW = { "Update", "UpdateFormatting", "UpdateQuestLines", "UpdateScenarioLines" }

-- The l10n module when Questie speaks our language now, else nil.
local function Ours()
    if L.state ~= "on" then return nil end
    local l10n = L.Questie_l10n()
    local ok, current = pcall(function() return l10n:GetUILocale() end)
    return ok and current == L.LOCALE and l10n or nil
end

local function Finish(l10n, ok, ...)
    pcall(l10n.SetUILocale, l10n, L.LOCALE)
    if not ok then error((...), 0) end          -- Questie's own error stays Questie's
    return ...
end

local function English(original)
    return function(...)
        local l10n = Ours()
        if not l10n or not pcall(l10n.SetUILocale, l10n, "enUS") then return original(...) end
        return Finish(l10n, pcall(original, ...))
    end
end

-- ── The letter after the level: "[34D]" ───────────────────────────────────────────────────────
-- QuestieLib:GetQuestTypeSuffix (Modules/Libs/QuestieLib.lua:247-287) takes the first BYTE of the
-- tag name, except in Chinese, Korean and Russian, where it picks a Latin letter by tag id. Some
-- tag names come from Questie's own list (Database/Corrections/questTagInfoCorrections.lua, e.g.
-- [1102] = {81, l10n("Dungeon")}), and that is "Підземелля" in Ukrainian: its first byte is half
-- of a letter, which the font draws as a box. Then we give Questie's own Latin letter instead.
-- This stays on after "/uadd questie off": those tag names stay Ukrainian until /reload.
local LETTER = { RAID = "R", RAID_10 = "R", RAID_25 = "R", DUNGEON = "D", HEROIC = "H",
    SCENARIO = "S", ACCOUNT = "A", CELESTIAL = "C", WORLD_EVENT = "W" }

function T.TagLetter(questId)
    local DB = Module("QuestieDB")
    local id = DB and type(DB.GetQuestTagInfo) == "function" and DB.GetQuestTagInfo(questId)
    for name, letter in pairs(LETTER) do
        if id ~= nil and type(DB.questTagIds) == "table" and DB.questTagIds[name] == id then return letter end
    end
    return ""
end

local suffixDone
local function InstallSuffix()
    local lib = Module("QuestieLib")
    local original = lib and lib.GetQuestTypeSuffix
    if suffixDone or type(original) ~= "function" then return end
    suffixDone = true
    lib.GetQuestTypeSuffix = function(self, questId, ...)
        local s = original(self, questId, ...)
        if not UADD.Plain(s) or not s:find("[\128-\255]") then return s end
        return Try(T.TagLetter, questId) or ""
    end
end

-- ── Fonts an older UADD switched ──────────────────────────────────────────────────────────────
-- UADD used to switch the tracker fonts to "UADD Cyrillic" (the old Font.lua). UALL Forever now
-- picks the font for each tracker line, so we put back, once, the fonts we switched (Questie's
-- settings: Modules/Options/QuestieOptionsDefaults.lua:126-133) and forget the old saved data.
-- A font the player picked again since then is left as it is.
local FONT_FIELDS = { "trackerFontHeader", "trackerFontZone", "trackerFontQuest", "trackerFontObjective" }

function T.RestoreFonts(db)
    local backup = db.fontBackup
    db.fontBackup, db.fontAuto, db.fontHint = nil, nil, nil
    if type(backup) ~= "table" then return end
    local profile = Questie.db.profile
    local n = 0
    for _, field in ipairs(FONT_FIELDS) do
        if profile[field] == UADD.FONT_NAME then
            profile[field] = backup[field] or "Friz Quadrata TT"  -- Questie's own default
            n = n + 1
        end
    end
    local tracker = n > 0 and Module("QuestieTracker")
    if tracker and type(tracker.Update) == "function" then pcall(tracker.Update, tracker) end
end

local drawDone
-- At our ADDON_LOADED, before the tracker is first drawn. Returns how many draw functions are wrapped.
function T.Install()
    InstallSuffix()
    if drawDone then return drawDone end
    local tracker = Module("QuestieTracker")
    local n = 0
    for _, key in ipairs(DRAW) do
        if tracker and type(tracker[key]) == "function" then
            tracker[key] = English(tracker[key])
            n = n + 1
        end
    end
    if n > 0 then drawDone = n end
    return n
end
