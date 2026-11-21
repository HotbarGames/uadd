-- Attune's StaticPopup dialogs in Ukrainian, through the core helper UADD.Popups (UADD/Popups.lua):
-- EXPORT_ATTUNE_GUILD (copy the guild export), SYNC_CONFIRM and SYNC_ATTUNE (a sync request sent or
-- received), ATTUNE_SHOW_URL (a web link), ACHIEVEANNOUNCE_CONFIRM (the achievement survey question),
-- INVITE_ATTUNE_RAID (a raid invite) and RENAME_ATTUNE_RAID (a raid's new name).
--   * Their buttons hold Attune's own words (its AttuneLang: Yes, No, Accept, Reject, Save, Close): our
--     glossary word while the field or the shown button holds that English, the English again on the hold
--     key and off.
--   * The shown dialog's text gets our words where Words.lua knows them, in a font with Ukrainian letters.
--     The player name in a sync question stays. The edit box (the export string, the link, the raid name
--     the player types) is never touched.
--   * The hold key and "/uadd attune off": the English and the fonts back. Nothing in combat.

local _, ns = ...
local U = UADD
local P = {}
ns.Popup = P

local KEY = "attune"
local WHICH = { EXPORT_ATTUNE_GUILD = true, SYNC_CONFIRM = true, SYNC_ATTUNE = true, ATTUNE_SHOW_URL = true,
    ACHIEVEANNOUNCE_CONFIRM = true, INVITE_ATTUNE_RAID = true, RENAME_ATTUNE_RAID = true }

-- Attune's English for one of its locale keys. rawget: AceLocale reports a missing key, and that report
-- must never come from us. A key it has not set yet is the English itself (AceLocale's default).
local function L(k)
    local t = rawget(_G, "AttuneLang")
    local v = type(t) == "table" and rawget(t, k) or nil
    return type(v) == "string" and v or k
end

U.Popups.Register(KEY, {
    names = WHICH,
    own = { Yes = "ui.yes", No = "ui.no", Accept = "ui.accept", Reject = "ui.reject", Save = "ui.save",
        Close = "ui.close" },
    L = L,
    text = function(en) return ns.Words.Text(en) end,
    wanted = function() return ns.WordsWanted() end,
    fix = function(fs) ns.Fonts.Fix(fs) end,
    back = function(fs) ns.Fonts.Back(fs) end,
})

function P.Install() U.Popups.Sync(KEY) end

-- The hold key: English or ours on the fields and the shown dialogs.
function P.Sync() U.Popups.Sync(KEY) end

-- "/uadd attune off": English and the fonts back.
function P.Restore() U.Popups.Off(KEY) end

-- For the checks: how many dialogs show our words.
function P.Count() return U.Popups.Count(KEY) end
