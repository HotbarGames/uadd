-- ForeverXP Bar's questions in the game's StaticPopup dialogs ("FOREVERXP..." ones only: reload the
-- UI, delete a profile, turn the challenge on or off) in Ukrainian, through the core helper
-- (UADD/Popups.lua, docs/LESSONS3.md "Lesson 1 again, in Auctionator's popups").
--   * The game's YES and NO on the challenge questions' buttons are ours while the global is English,
--     English while held and off. The globals are never written; one already Cyrillic stays.
--   * A shown dialog's text and its other buttons get our words (only texts Words.lua knows) and a font
--     with Ukrainian letters; both flip back on the hold key, when it hides and off. Nothing in combat.
--   * The dialog grows or shrinks by what the text's height changed (SetHeight only).

local _, ns = ...
local U = UADD
local P = {}
ns.Popup = P

local KEY = "fxpb"

U.Popups.Register(KEY, {
    prefix = "FOREVERXP",
    globals = { YES = "ui.yes", NO = "ui.no" },
    text = function(en) return ns.Words.Text(en) end,
    wanted = function() return ns.WordsWanted() end,
    fix = function(fs) ns.Fonts.Fix(fs) end,
    back = function(fs) ns.Fonts.Back(fs) end,
})

-- After login and on: the hook, the button fields, and a dialog already shown.
function P.Install() U.Popups.Sync(KEY) end

-- The hold key and after combat: English or ours on the fields and the shown dialogs.
function P.Sync() U.Popups.Sync(KEY) end

-- "/uadd fxpb off": English and the fonts back.
function P.Restore() U.Popups.Off(KEY) end

-- For the checks: how many dialogs show our words.
function P.Count() return U.Popups.Count(KEY) end
