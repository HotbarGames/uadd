-- UADD: Ukrainian for the home page's edit bar (Systems/HomeEdit.lua: hide, reorder, view, reset) and for the
-- words Systems/Tier05Chain.lua adds to ForeverDungeonJournal's language tables itself. Same rules as
-- ui/strings.lua; tools/test_dj_strings.py checks it. Merged into ns.uiStrings.
local _, ns = ...
local G = UADD and UADD.Glossary and UADD.Glossary.Text or function() return nil end
local S = {
    -- The bar under the dungeon list. Its buttons are narrow: keep their words short.
    EDIT_MODE = "Редагування",
    EDIT_MODE_TIP = "Тут можна сховати підземелля, змінити їхній порядок або вигляд списку.",
    EDIT_MODE_NEW = "Тепер можна змінити вигляд списку підземель",
    ALL_DUNGEONS_HIDDEN = "Усі підземелля сховано. Клацніть «Редагування», потім «Сховати підземелля», щоб повернути їх.",
    HIDE_DUNGEONS_TIP = "Клацніть підземелля, щоб сховати його. Клацніть ще раз, щоб повернути.",

    -- The order of the dungeons
    REORDER_DUNGEONS = "Змінити порядок",
    REORDER_TIP = "Перетягніть підземелля на інше, щоб поміняти їх місцями, або клацніть одне, а потім друге.",
    REORDER_RESET_TIP = "Правий клік: скинути порядок",
    RESET_ORDER = "Скинути порядок",
    REORDER_CARD_TIP = "Перетягніть на інше підземелля, щоб поміняти їх місцями, або клацніть, щоб вибрати це.",
    REORDER_PICKED_TIP = "Клацніть інше підземелля, щоб поміняти їх місцями. Клацніть це ще раз, щоб скасувати.",
    REORDER_PLACE_TIP = "Клацніть, щоб поміняти місцями з підземеллям «%s».",

    -- The look of the list
    VIEW_MODE = "Вигляд",
    VIEW_MODE_TIP = "Вигляд списку підземель: звичайні картки, менші картки або список.",
    VIEW_DEFAULT = "Звичайний",
    VIEW_SMALL = "Менші картки",
    VIEW_LIST = "Список",
    RESET_UI = G"ui.reset",
    RESET_UI_TIP = "Повернути звичайний список підземель: сховані підземелля повернуться, порядок буде початковий, картки звичайні.",
    RESET_UI_CONFIRM = "Повернути звичайний вигляд?",

    -- The Tier 0.5 chain and the boxes it gives
    TIER05_CHAIN = "Ланцюжок тіру 0.5",
    TIER05_CHAIN_TIP = "Увесь ланцюжок завдань тіру 0.5 для вашого класу й фракції, крок за кроком.",
    BOX_CLICK_SHOW = "Клацніть, щоб показати речі всередині",
    BOX_CLICK_HIDE = "Клацніть, щоб сховати речі",
}
if ns then
    local all = ns.uiStrings or {}
    for k, v in pairs(S) do all[k] = v end
    ns.uiStrings = all
end
return S
