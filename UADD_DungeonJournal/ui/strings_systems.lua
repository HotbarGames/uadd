-- UADD: Ukrainian for strings that ForeverDungeonJournal's feature files (Systems/*.lua) add to its
-- language tables themselves. Each file adds them only to the languages that exist when it loads, and
-- ukUA is not one of them, so a key that is missing here shows in English (FDJ.L falls back).
-- Same rules as ui/strings.lua; tools/test_dj_strings.py checks both files. Merged into ns.uiStrings.
-- Left out on purpose: texts with game names in them (Onyxia, the Sleeping Bag quest), which must
-- come from UALL, and the large Run Log, RPG mode and export screens (still English).
local _, ns = ...
local G = UADD and UADD.Glossary and UADD.Glossary.Text or function() return nil end
local S = {
    -- Systems/Favourites.lua: the star button on the home page, its window, the item menu
    FAVOURITES = G"ui.favourites",
    FAVOURITES_EMPTY = "Клацніть предмет правою кнопкою, щоб додати його до обраного.",
    FAV_ADD_ITEM = "Додати до обраного",
    FAV_REMOVE_ITEM = "Прибрати з обраного",
    FAV_REMOVE_HINT = "Лівий клік — показати, звідки предмет. Правий клік — прибрати з обраного",

    -- Systems/ItemSource.lua: a quest item a boss drops
    LOOTED_FROM = "Випадає з: %s, %s",
    ITEM_CLICK_BOSS = "Клацніть, щоб показати",

    -- Systems/QuestText.lua and Systems/OnyxiaAttunement.lua: the home page icons' menu
    SLEEPING_BAG_HIDE = G"ui.hide",
    SLEEPING_BAG_HIDE_TIP = "Правий клік — сховати",
    ONYXIA_HIDE = G"ui.hide",
    ONYXIA_HIDE_TIP = "Правий клік — сховати",
    ONYXIA_POPUP_CLICK = "Клацніть, щоб відкрити в журналі.",
}
if ns then
    local all = ns.uiStrings or {}
    for k, v in pairs(S) do all[k] = v end
    ns.uiStrings = all
end
return S
