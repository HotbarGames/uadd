-- Dungeon Journal's StaticPopup questions (hide the minimap button, delete a run, reset the tracker, reset
-- the dungeon list), through the core helper (UADD/Popups.lua, docs/LESSONS3.md "Lesson 1 again, in
-- Auctionator's popups").
--   * The game's YES and NO on their buttons are ours while the global is English and our language is on
--     (Language.lua: L.Active), English while held, with another language and off. The globals are never
--     written; one already Cyrillic stays.
--   * The journal draws each question's text itself, in our words while our language is on. The minimap
--     and the dungeon list questions are one whole text of ours each (WHOLE), so a shown one flips both
--     ways too. The run question has a dungeon's name in it and stays as the journal drew it; the tracker
--     question has no words of ours.
--   * No font change: the game's own fonts are left on the dialogs.

local _, ns = ...
local U = UADD
local P = {}
ns.Popup = P

local KEY = "dj"
local WHOLE = { "MINIMAP_HIDE_CONFIRM", "RESET_UI_CONFIRM" }     -- the journal's locale keys of whole question texts

-- The journal's English for a key (read from it in the game, never kept here), and ours.
local function English(k)
    local fdj = rawget(_G, "ForeverDungeonJournal_NS")
    local en = type(fdj) == "table" and type(fdj.Locales) == "table" and type(fdj.Locales.enUS) == "table"
        and rawget(fdj.Locales.enUS, k)
    return type(en) == "string" and en ~= "" and en or nil
end

local function Ours(k)
    local v = type(ns.uiStrings) == "table" and ns.uiStrings[k]
    return type(v) == "string" and v ~= "" and v or nil
end

U.Popups.Register(KEY, {
    names = { FOREVERDUNGEONJOURNAL_HIDE_MINIMAP = true, FDJ_RUNLOG_DELETE = true, FDJ_TRACKER_RESET = true,
        FDJ_RESET_HOME_UI = true },
    globals = { YES = "ui.yes", NO = "ui.no" },
    text = function(en)
        for _, k in ipairs(WHOLE) do if en == English(k) then return Ours(k) end end
    end,
    english = function(uk)
        for _, k in ipairs(WHOLE) do if uk == Ours(k) then return English(k) end end
    end,
    wanted = function() return ns.Lang.Active() end,
})

-- After login, on, the hold key: the button fields and the shown dialogs as our language says now.
function P.Sync() U.Popups.Sync(KEY) end

-- Language.lua calls L.Forget on every change of language (ours picked, another one, install, uninstall).
local forget = ns.Lang.Forget
function ns.Lang.Forget(...)
    forget(...)
    P.Sync()
end

-- "/uadd dj off": the English back where it is still ours.
function P.Off() U.Popups.Off(KEY) end

-- For the checks: how many dialogs show our words.
function P.Count() return U.Popups.Count(KEY) end
