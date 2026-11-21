-- UADD: Ukrainian for the Character Logs window and the dungeon tracker that ForeverDungeonJournal's
-- Systems/RunLogUI.lua, RunLog.lua and OptionsPanel.lua add to its language tables themselves
-- (see strings_systems.lua). Same rules as ui/strings.lua; tools/test_dj_strings.py checks it.
-- A "run" is «проходження»; "trash" is «звичайні вороги» (as in the glossary); the roll button
-- "Need" is «Потрібно» (the game's own button word). Merged into ns.uiStrings.
local _, ns = ...
local G = UADD and UADD.Glossary and UADD.Glossary.Text or function() return nil end
local S = {
    -- The Character Logs window
    RUNLOG = "Записи персонажа",
    RUNLOG_TIP = "Кожне проходження підземелля цим персонажем: час, вбивства й досвід, смерті та кидки «Потрібно».",
    RUNLOG_EMPTY = "Проходжень ще немає.\n\nЗайдіть у підземелля: кожне проходження записується окремо.",
    RUNLOG_IN_PROGRESS = "Триває",
    RUNLOG_COMPLETED = "Завершено",
    RUNLOG_UNFINISHED = "Не завершено",
    RUNLOG_TIME = "Час",
    RUNLOG_TIME_TIP = "Від першого вбитого звичайного ворога до вбивства останнього боса.",
    RUNLOG_RUNNING = "триває",
    RUNLOG_DEATHS = "Смерті",
    RUNLOG_DIED_AT = "Загинули: %s",
    RUNLOG_TRASH = "Убито звичайних ворогів",
    RUNLOG_TRASH_OF = "%d з %d",
    RUNLOG_TRASH_TIP = "Звичайні вороги, убиті за це проходження (боси й рідкісні не враховано).",
    RUNLOG_XP = "Досвід із ворогів",
    RUNLOG_BOSSES = G"game.bosses",
    RUNLOG_TRASH_MOBS = "Звичайні вороги",
    RUNLOG_NEED = "Кидки «Потрібно»",
    RUNLOG_NO_NEED = "Цього проходження ви нічого не брали через «Потрібно».",
    RUNLOG_NO_TRASH = "Звичайних ворогів не вбито.",
    RUNLOG_NOT_KILLED = "не вбито",
    RUNLOG_RARE = "Рідкісний",
    RUNLOG_WON = "Виграно",
    RUNLOG_LOST = "Програно",
    RUNLOG_ROLLS = "Кидки",
    RUNLOG_ROLLING = "Кидають...",
    RUNLOG_OUTSIDE = "Час поза підземеллям",
    RUNLOG_RELEASED = "Шлях привида",
    RUNLOG_STEPPED = "Вийшли",
    RUNLOG_STILL_OUT = "ще поза підземеллям",
    RUNLOG_ROW_HINT = "Правий клік — видалити це проходження",
    RUNLOG_DELETE = "Видалити це проходження: %s?",
    RUNLOG_DONE = "%s пройдено за %s - смерті: %d - звичайні вороги: %s - досвід: %s  (/dj log)",
    RUNLOG_PARTY = G"game.group",
    RUNLOG_MONEY = "Зароблено грошей",
    RUNLOG_SHOW_GOLD = "Клацніть: показати золото",
    RUNLOG_SHOW_XP = "Клацніть: показати досвід із ворогів",
    RUNLOG_GOLD = "Золото",
    RUNLOG_MOBS_XP = "Досвід із ворогів",
    RUNLOG_HIDE_TIP = "Правий клік — сховати",
    RUNLOG_HIDE = G"ui.hide",
    RUNLOG_DEL = "Видалити це проходження",
    RUNLOG_NOT_FOUND = "не знайдено",
    RUNLOG_NO_LOOT = "Здобичі не бачено.",
    RUNLOG_TRACK = "Показати на екрані",
    RUNLOG_UNTRACK = "Не стежити",
    RUNLOG_TRACK_TIP = "Показує час, досвід і босів цього проходження на екрані, поки триває підземелля. Перетягніть, щоб перемістити.",
    RUNLOG_OPTIONS = G"ui.settings",

    -- Options: the icon and the tracker window
    OPT_HIDE_RUNLOG = "Сховати значок записів персонажа",
    OPT_HIDE_RUNLOG_TIP = "Ховає значок записів персонажа (портрет вашого персонажа, ліворуч від «Обране») на головній сторінці журналу. Також можна правим кліком по значку вибрати «Сховати». Проходження все одно записуються; /dj log відкриває записи персонажа.",
    OPT_TRACKER = "Трекер підземель",
    OPT_TRACK_HIDE = "Сховати трекер",
    OPT_TRACK_HIDE_TIP = "Ховає трекер для цього проходження. Коли ви закриваєте його хрестиком, це вмикається; вихід із підземелля живим або нове проходження вимикає це саме. «/dj tracker» або зняття позначки знову показує трекер.",
    OPT_TRACK_SOLO = "Показувати трекер і для сольних проходжень",
    OPT_TRACK_SOLO_TIP = "Трекер також відкривається сам, коли ви в підземеллі без групи.",
    OPT_TRACK_HIDE_BOSSES = "Сховати босів",
    OPT_TRACK_HIDE_BOSSES_TIP = "Трекер не показує портрети босів і рідкісних ворогів.",
    OPT_TRACK_NEVER = "Ніколи не стежити за підземеллями",
    OPT_TRACK_NEVER_TIP = "Маленьке вікно трекера (час, досвід, золото й боси) ніколи не відкривається само в підземеллях. Проходження все одно записуються, а «Показати на екрані» в записах персонажа його відкриває.",
    OPT_TRACK_HIDE_TIME = "Сховати час",
    OPT_TRACK_HIDE_TIME_TIP = "Трекер не показує час проходження.",
    OPT_TRACK_HIDE_XP = "Сховати досвід із ворогів",
    OPT_TRACK_HIDE_XP_TIP = "Трекер не показує досвід із ворогів.",
    OPT_TRACK_HIDE_GOLD = "Сховати золото",
    OPT_TRACK_HIDE_GOLD_TIP = "Трекер не показує зароблені гроші.",
    OPT_TRACK_LOCK = "Закріпити трекер",
    OPT_TRACK_LOCK_TIP = "Трекер не можна пересувати, а в нього зникають куточок зміни розміру й хрестик. Правий клік усе одно відкриває налаштування.",
}
if ns then
    local all = ns.uiStrings or {}
    for k, v in pairs(S) do all[k] = v end
    ns.uiStrings = all
end
return S
