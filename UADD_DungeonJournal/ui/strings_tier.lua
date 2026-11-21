-- UADD: Ukrainian for the Tier Sets page and a few options that ForeverDungeonJournal's
-- Systems/TierSets.lua, OptionsPanel.lua and CharacterExport.lua add to its language tables themselves
-- (see strings_systems.lua). Same rules as ui/strings.lua; tools/test_dj_strings.py checks it.
-- Left out on purpose: the talent tree names on the Tier 0.5 page (TIER05_SPEC_*) and the Onyxia and
-- Sleeping Bag texts: they are game names, which must come from UALL or ClassicUA. Merged into ns.uiStrings.
local _, ns = ...
local G = UADD and UADD.Glossary and UADD.Glossary.Text or function() return nil end
local S = {
    -- Systems/CharacterExport.lua: the note on the home page
    EXPORT_NOTE = "Тепер можна експортувати прогрес вашого персонажа на сайт",
    EXPORT_NOTE_CLICK = "Клацніть тут або на %s.",

    -- Options
    OPT_HIDE_UNAVAILABLE = "Сховати недоступні завдання",
    OPT_HIDE_UNAVAILABLE_TIP = "Ховає завдання з позначкою «Недоступне» (поки що їх немає у WoW Forever або вони не для вашої раси). Якщо оновлення знову робить якесь із них доступним, цей параметр вимикається сам, щоб ви його побачили.",
    OPT_LOOT = G"game.loot",
    OPT_HIDE_QUEST_DROPS = "Сховати предмети завдань зі здобичі",
    OPT_HIDE_QUEST_DROPS_TIP = "Сторінки здобичі босів не показують предметів завдань, які падають із боса.",
    OPT_SEARCH = "Пошук налаштувань",
    OPT_SEARCH_RESULTS = "Результати пошуку",
    OPT_SEARCH_NONE = "Налаштувань не знайдено.",

    -- Systems/TierSets.lua: the Tier Sets page ("тір" is the players' word for a tier)
    TIER_TITLE = "Комплекти тіру",
    TIER_0 = "Тір 0",
    TIER_ICON_TIP = "Комплекти тіру вашого класу: кожна частина й те, звідки вона падає.",
    TIER_ALL_CLASSES = "Показати всі класи",
    TIER_SHOW_CLASSES = "Показати класи",
    TIER_ALL = "Усі",
    TIER_PIECE_TIP = "Клацніть, щоб відкрити, звідки це падає.",
    BACK_TO_TIERS = "До тірів",
    TIER_05 = "Тір 0.5",
    TIER05_LABEL = "Тір 0.5: %s",
    TIER05_FROM = "Завдання тіру 0.5: %s",
    TIER_HIDE = G"ui.hide",
    TIER_HIDE_TIP = "Правий клік — сховати",
    OPT_HIDE_TIER = "Сховати комплекти тіру",
    OPT_HIDE_TIER_TIP = "Ховає значок комплектів тіру на головній сторінці журналу. Він лишається схованим до 50 рівня; зніміть позначку, щоб побачити його раніше. Також можна правим кліком по значку вибрати «Сховати».",
}
if ns then
    local all = ns.uiStrings or {}
    for k, v in pairs(S) do all[k] = v end
    ns.uiStrings = all
end
return S
