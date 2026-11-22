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

    -- Core/Journal.lua: the row under an item that is joined with another into a third (Built.lua)
    LOOT_COMBINE_WITH = "Поєднайте з: %s",
    LOOT_MADE_FROM = "Створюється поєднанням: %s і %s.",

    -- Systems/QuestText.lua and Systems/OnyxiaAttunement.lua: the home page icons' menu
    SLEEPING_BAG_HIDE = G"ui.hide",
    SLEEPING_BAG_HIDE_TIP = "Правий клік — сховати",
    ONYXIA_HIDE = G"ui.hide",
    ONYXIA_HIDE_TIP = "Правий клік — сховати",
    ONYXIA_POPUP_CLICK = "Клацніть, щоб відкрити в журналі.",

    -- Localization.lua (2.1.2): the loot filter's level range label
    LF_LEVEL_RANGE = "Діапазон рівнів",

    -- Core/Journal.lua: the strip of a whole set under an item
    SET_CLICK_SHOW = "Клацніть, щоб показати весь комплект",
    SET_CLICK_HIDE = "Клацніть, щоб сховати комплект",

    -- Systems/CharacterExport.lua: the character code for the website
    OPT_HIDE_EXPORT = "Сховати кнопку експорту на головній сторінці",
    OPT_HIDE_EXPORT_TIP = "Ховає кнопку «Експорт» угорі журналу, ліворуч від «Повідомити». Код вашого персонажа лишається на вкладці «Експорт» у налаштуваннях.",
    EXPORT_TITLE = "Журнал підземель - код персонажа",
    EXPORT_COPY = "Натисніть Ctrl+A, потім Ctrl+C і вставте код на сайті.",
    EXPORT_HINT = "%s - завдань виконано: %d. Хочете бачити свій прогрес, коли ви не в грі? Вставте цей код на сайті.",
    EXPORT_ERROR = "Не вдалося створити код персонажа.",
    EXPORT_SITE = "Вставте код тут:",
    RUNLOG_EXPORT = "Експорт",
    OPT_EXPORT = "Експорт на сайт",
    OPT_EXPORT_TIP = "Створює код цього персонажа, який можна скопіювати й вставити на сайті. Також можна ввести /dj export.",

    -- Systems/GamePad.lua: the button hints under the journal (the only texts it shows)
    PAD_OPEN = "Відкрити",
    PAD_BACK = G"ui.back",
    PAD_TABS = "Карта / Боси / Завдання",
    PAD_SCROLL = "Прокрутка",
    PAD_FAV = G"ui.favourites",
    PAD_CLOSE = G"ui.close",
    MAP_PAD_MARKED = "%s позначено на карті. Відкрийте карту, щоб побачити.",

    -- Systems/MapMarkers.lua: the arrow that leads to a quest spot. A place or an item name in %s
    -- always stands after a colon, so it needs no case ending.
    ARROW_NEXT_SPAWN = "Не знайшли? Наступне місце (%d/%d)",
    ARROW_USE_ITEM = "Щоб почати завдання, використайте із сумок: %s",
    ARROW_DISTANCE = "%d ярд.",
    ARROW_TIP_MOVE = "Тягніть, щоб перемістити.",
    ARROW_TIP_HIDE = "Shift + правий клік — сховати стрілку.",
    ARROW_BOAT = "Сядьте на корабель: %s",
    ARROW_ZEPPELIN = "Сядьте на цепелін: %s",
    ARROW_FLY = "Летіть: %s",
    ARROW_FLY_FROM = "Летіть з %s до %s",
    ARROW_TALK_TO = "Поговоріть: %s",
    ARROW_DIVE_DOWN = "Пірніть прямо вниз",
    ARROW_PICK_UP_BOTTOM = "Підберіть це на дні",
    ARROW_SWIM_UNDER = "Пливіть під водою",
    ARROW_PICK_UP = "Підберіть це",
    ARROW_GET_TO = "Дістаньтеся: %s",
    ARROW_FLYING = "Політ: %s",
    ARROW_BELOW = "Під землею: знайдіть шлях вниз",
    ARROW_ABOVE = "Нагорі: знайдіть шлях угору",
    ARROW_TIP_MAP = "Клацніть, щоб показати на карті.",
    ARROW_PORTAL = "Скористайтеся порталом: %s",
    ARROW_HEARTH = "Повернення додому: %s",
    ARROW_ELEVATOR = "Підніміться ліфтом",
}
if ns then
    local all = ns.uiStrings or {}
    for k, v in pairs(S) do all[k] = v end
    ns.uiStrings = all
end
return S
