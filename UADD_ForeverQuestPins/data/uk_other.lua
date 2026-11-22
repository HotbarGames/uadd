-- Ukrainian for Forever Quest Pins: the L keys of its other files, Setup's pages, and What's New.
local _, ns = ...
local T = ns.UK or {}
ns.UK = T

-- Breadcrumbs.lua
-- stays English (debug only): "Skipped breadcrumb notice for %s: the dialog queue is full.",
-- "Quest %d skipped breadcrumbs: %s", "none"
T["Preview only. Accept a quest that skips its breadcrumb to use this action."] = "Лише перегляд. Щоб скористатися цією дією, прийміть завдання, що пропускає своє вступне завдання."
T["No waypoint is available for this quest."] = "Для цього завдання немає точки маршруту."
T["This quest is no longer in your log."] = "Цього завдання вже немає у вашому журналі."
T["This quest is ready to turn in. Abandon it from the quest log instead."] = "Це завдання готове до здачі. Покиньте його в журналі завдань."
T["You accepted %s without completing its breadcrumb quest %s."] = "Ви прийняли %s, не виконавши вступне завдання %s."
T["Breadcrumb Quest Skipped"] = "Пропущене вступне завдання"
T["Abandon Quest"] = "Покинути завдання"
T["Ignore"] = "Ігнорувати"
T["Set Waypoint"] = "Поставити точку маршруту"
T["Abandoned %s."] = "Покинуто %s."
T["Could not create a waypoint for this quest."] = "Не вдалося створити точку маршруту для цього завдання."
T["Could not abandon this quest."] = "Не вдалося покинути це завдання."

-- MapPins.lua
T["Quest"] = "Завдання"
T["Breadcrumb quest"] = "Вступне завдання"
T["Includes a breadcrumb quest"] = "Містить вступне завдання"
T["Quest giver NPC "] = "НІП, що видає завдання, "
T["%d possible spawn locations"] = "Можливих місць появи: %d"
T["Click to track this quest start."] = "Клікніть, щоб відстежувати початок цього завдання."
T["Shift-click to hide this marker."] = "Shift+клік, щоб сховати цей значок."
T["|cffffd100Forever Quest Pins:|r Hid %d quest(s). Use Reset hidden quest pins in options or /fqp unhide to restore."] = "|cffffd100Forever Quest Pins:|r Сховано завдань: %d. Щоб відновити, скористайтеся «Скинути сховані значки завдань» у налаштуваннях або /fqp unhide."

-- Waypoints.lua
T["TomTom is not loaded. Choose Blizzard Map Pins or enable TomTom."] = "TomTom не завантажено. Оберіть позначки карти Blizzard або увімкніть TomTom."
T["TomTom could not create this waypoint."] = "TomTom не зміг створити цю точку маршруту."
T["Blizzard quest tracking is unavailable on this client."] = "Відстеження завдань Blizzard недоступне в цьому клієнті."
T["No quest location is available yet."] = "Місце завдання ще невідоме."
T["Blizzard Map Pins are unavailable on this client. TomTom can be selected in options."] = "Позначки карти Blizzard недоступні в цьому клієнті. TomTom можна обрати в налаштуваннях."
T["Blizzard does not allow a map pin in this zone."] = "Blizzard не дозволяє ставити позначку на карті в цій зоні."

T["Quest tracking is unavailable in combat."] = "Відстеження завдань недоступне в бою."

-- HiddenQuests.lua
T["Restored %d hidden quest pin(s)."] = "Відновлено схованих значків завдань: %d."
T["No hidden quest pins on this character."] = "У цього персонажа немає схованих значків завдань."
T["Hidden quest pins on this character (%d):"] = "Сховані значки завдань цього персонажа (%d):"
T["  /fqp unhide <id> or /fqp unhide all to restore"] = "  /fqp unhide <id> або /fqp unhide all, щоб відновити"
T["Usage: /fqp unhide <id> or /fqp unhide all"] = "Використання: /fqp unhide <id> або /fqp unhide all"
T["Restored quest %d."] = "Відновлено завдання %d."
T["Quest %d is not hidden on this character."] = "Завдання %d не сховане в цього персонажа."

-- QuestLinks.lua
T["Copy Wowhead URL\nPress Cmd+C or Ctrl+C to copy the selected link."] = "Копіювати посилання Wowhead\nНатисніть Cmd+C або Ctrl+C, щоб скопіювати виділене посилання."
T["Copy Wowhead URL"] = "Копіювати посилання Wowhead"

-- NPCTooltips.lua
T["Quest %d (title unavailable)"] = "Завдання %d (назва недоступна)"

-- Setup.lua: window texts, buttons and the four pages
T["Choose your options"] = "Оберіть налаштування"
T["Choose what works for you. You can change these later in the addon options."] = "Оберіть, що вам підходить. Пізніше це можна змінити в налаштуваннях аддона."
T["Set up quest pins, use the defaults, or keep your current settings."] = "Налаштуйте значки завдань, залиште типові або збережіть поточні налаштування."
T["Apply"] = "Застосувати"
T["Back"] = "Назад"
T["Next"] = "Далі"
T["Use Defaults"] = "Типові налаштування"
T["Use Current Settings"] = "Поточні налаштування"
T["Choose Options"] = "Обрати налаштування"
-- The page labels that Config.lua uses too are in uk_config.lua (one wording for both).
T["Quest categories"] = "Категорії завдань"

-- Sparkle.lua
T["Quest item sparkles are off. Restart the game to remove them; /reload is not enough."] = "Блиск предметів завдань вимкнено. Щоб він зник, перезапустіть гру; /reload не досить."

-- What's New (WhatsNew.lua lines, and the header printed by Setup.lua)
-- stays English: a line that quotes quest names (game names are ClassicUA's or UALL Forever's, lesson 9).
T["What is new in %s:"] = "Що нового у %s:"
T["Let Shift-click hide quest pins on world and continent maps, where pins ignored clicks so the map could still be dragged. Pin tooltips there now mention Shift-click."] = "Shift-клік тепер ховає значки завдань і на картах світу й континентів. Раніше там значки не реагували на кліки, щоб карту можна було тягнути. Підказки значків там тепер згадують Shift-клік."
T["Recover hidden quest pins saved before 1.1.0. Those lists were keyed by realm name, so they looked empty after 1.1.0 changed the character key."] = "Сховані значки завдань, збережені до 1.1.0, тепер відновлюються. Ці списки були прив'язані до назви сервера, тож після 1.1.0, де змінився ключ персонажа, вони здавалися порожніми."
T["Keep the enhanced quest tracker out of Blizzard's combat layout. The addon restores Blizzard's tracker methods while in combat, so the scenario tracker can read secret aura data, then re-applies the zone groups, sort, and filters after combat."] =
    "Покращений трекер завдань більше не заважає бойовому розміщенню Blizzard. У бою аддон повертає трекеру Blizzard його власні методи, щоб трекер сценаріїв міг читати приховані дані аур, а після бою знову застосовує групи за зонами, сортування й фільтри."
T["Stop quest tracking from writing Blizzard's waypoint or super-track during combat or another restricted action. The write could taint the map's pin refresh and block SetPassThroughButtons. Existing tracking resumes after combat."] =
    "Відстеження завдань більше не змінює точку маршруту Blizzard і пріоритетне завдання в бою чи під час іншої обмеженої дії. Така зміна могла зіпсувати оновлення значків на карті й заблокувати SetPassThroughButtons. Наявне відстеження відновлюється після бою."
