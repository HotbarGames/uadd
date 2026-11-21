-- UADD: Ukrainian for the RPG Mode strings that ForeverDungeonJournal's Systems/RPGMode.lua and
-- Systems/ProgressTransfer.lua add to its language tables themselves (see strings_systems.lua).
-- Same rules as ui/strings.lua; tools/test_dj_strings.py checks it. Merged into ns.uiStrings.
-- Left out on purpose: the account-wide tip (it names three dungeons) and the two Legacy Challenges
-- lines (a Forever feature name): each stays English until UALL has the names.
local _, ns = ...
local G = UADD and UADD.Glossary and UADD.Glossary.Text or function() return nil end
local S = {
    -- Systems/ProgressTransfer.lua: take the RPG Mode progress to another computer
    OPT_RPG_EXPORT = "Експорт прогресу",
    OPT_RPG_EXPORT_TIP = "Код із прогресом режиму RPG цього персонажа, щоб перенести його на інший комп'ютер.",
    OPT_RPG_IMPORT = "Імпорт прогресу",
    OPT_RPG_IMPORT_TIP = "Вставте код, отриманий через «Експорт прогресу» на іншому комп'ютері.",
    RPG_EXPORT_TITLE = "Експорт прогресу",
    RPG_EXPORT_TEXT = "Змінюєте комп'ютер? Скопіюйте цей код і вставте його, коли зайдете в гру на іншому пристрої.",
    RPG_EXPORT_COPY = "Ctrl+A, потім Ctrl+C, щоб скопіювати.",
    RPG_IMPORT_TITLE = "Імпорт прогресу",
    RPG_IMPORT_TEXT = "Вставте код з іншого комп'ютера (Ctrl+V), потім натисніть «Імпорт».",
    RPG_IMPORT_BUTTON = G"ui.import",
    RPG_IMPORT_DONE = "Прогрес імпортовано: сторінок — %d, босів — %d, завдань — %d, карт — %d.",
    RPG_IMPORT_NOTHING = "Нічого нового для імпорту: цей персонаж уже має все.",
    RPG_IMPORT_BAD = "Цей код не підходить. Скопіюйте його знову, весь, і вставте сюди.",
    RPG_IMPORT_OTHER = "Цей код від персонажа %s. Зайдіть цим персонажем, щоб імпортувати його.",
    RPG_EXPORT_ERROR = "Не вдалося створити код.",

    -- Systems/RPGMode.lua: the RPG Mode options page
    OPT_RPG_SHOW_QUESTS = "Показувати завдання підземель",
    OPT_RPG_SHOW_QUESTS_TIP = "Завдання кожного підземелля видно в режимі RPG, а картки підземель показують кількість завдань. Боси, здобич і карти, як і раніше, відкриваються в міру гри. Поки це ввімкнено, сповіщень про досягнення завдань немає.",
    OPT_RPG_ENABLE = G"ui.enable",
    OPT_RPG_PAGE = "Режим RPG",
    OPT_RPG_HIDE_QUEST = "Сховати сповіщення про досягнення завдань",
    OPT_RPG_HIDE_QUEST_TIP = "Без сповіщення, коли в режимі RPG відкривається завдання підземелля (рядок у чаті лишається).",
    OPT_RPG_HIDE_BOSS = "Сховати сповіщення про досягнення босів",
    OPT_RPG_HIDE_BOSS_TIP = "Без сповіщення, коли останній бос відкриває сторінку журналу в режимі RPG (рядок у чаті лишається).",
    OPT_RPG_MUTE = "Вимкнути звук досягнень",
    OPT_RPG_MUTE_TIP = "Сповіщення про досягнення звучать без звуку.",
    OPT_RPG_VOLUME = "Гучність сповіщень про досягнення",
    OPT_RPG_VOLUME_TIP = "Наскільки гучно грає фанфара досягнення (100% = так само гучно, як звуки самої гри).",
    OPT_RPG_ACCOUNT = "Відкриття для всього облікового запису",
    RPG_PROOF_UNLOCKED = "Відкрито завданнями, які ви виконали: %s",
    RPG_PROOF_REVEALED = "Показано завданнями, які ви виконали: %s",
    RPG_DONE_BUTTON = "Підземелля вже пройдено до встановлення журналу",
    RPG_DONE_TIP = "Уже пройшли його до встановлення журналу? Клацніть сторінку.",
    RPG_DONE_CONFIRM = "Ця сторінка: %s.\n\nПозначити її як пройдену? Уся сторінка відкриється, ніби ви вбили її останнього боса. Лише для підземель, пройдених до встановлення журналу.",
    RPG_DONE_OK = "Позначити як пройдене",
    RPG_DONE_BACK = G"ui.back",
    RPG_DONE_CLOSE = G"ui.close",
}
if ns then
    local all = ns.uiStrings or {}
    for k, v in pairs(S) do all[k] = v end
    ns.uiStrings = all
end
return S
