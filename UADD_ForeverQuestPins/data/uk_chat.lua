-- Ukrainian for Forever Quest Pins: the L keys of its Config.lua that go to chat (its replies, toggle labels, /fqp help).
-- stays English (debug only, not written): the /fqp help lines for nameplatedebug, taint, stats, settings, wipe, apis, why,
-- available; the stats/settings/wipe/why/available output lines ("QuestieDB %s | ...", "Usage: /fqp why <questID>",
-- "would pin", "would paint on map", "hidden", "Would pin on map ", "  count ", "  auto-accept %s | ...",
-- "  hidden quest pins on this character: %d", ...), and the /fqp wipe how-to (its "Close the game..." lines).
local _, ns = ...
local T = ns.UK or {}
ns.UK = T

-- Chat replies
T["Auto-accept quest levels: yours %+d to %+d"] = "Рівні автоприйняття завдань: від %+d до %+d від вашого"
T["|cff33ff99Forever Quest Pins:|r In-world navigation is unavailable on this client."] = "|cff33ff99Forever Quest Pins:|r Навігація у світі недоступна на цьому клієнті."
T["on"] = "увімкнено"
T["off"] = "вимкнено"
T["Pins enabled."] = "Значки увімкнено."
T["Pins disabled."] = "Значки вимкнено."
T["Nameplates module not loaded."] = "Модуль табличок імен не завантажено."
T["Low-level pins: hiding quests %d+ levels below you."] = "Значки низькорівневих завдань: ховаю завдання на %d+ рівнів нижче вашого."
T["Low-level pins are currently shown. Type /fqp trivial to hide them."] = "Значки низькорівневих завдань зараз показано. Щоб сховати їх, введіть /fqp trivial."
T["Showing quests at every level above you."] = "Показую завдання будь-якого рівня вище вашого."
T["Hiding quests %d+ levels above you."] = "Ховаю завдання на %d+ рівнів вище вашого."
T["Breadcrumb warnings are not loaded."] = "Попередження про вступні завдання не завантажено."
T["Refreshed."] = "Оновлено."
T["Unknown command. Type /fqp help"] = "Невідома команда. Введіть /fqp help"
T["Quest "] = "Завдання "
T[" is not in the quest database."] = " немає в базі завдань."
T["No viewed map. Open the world map first."] = "Немає відкритої карти. Спершу відкрийте карту світу."

-- Toggle labels (printed as "<label>: увімкнено/вимкнено")
T["NPC quest tooltips"] = "Підказки завдань біля НІП"
T["Nameplate quest icons"] = "Значки завдань на табличках імен"
T["Show trivial quests"] = "Показувати низькорівневі завдання"
T["Show repeatable quests"] = "Показувати повторювані завдання"
T["Show spawn clusters"] = "Показувати групи місць появи"
T["Show seasonal/holiday pins"] = "Показувати сезонні / святкові значки"
T["Show PvP quest pins"] = "Показувати значки PvP-завдань"
T["Show quests in unexplored areas"] = "Показувати завдання в недосліджених місцях"
T["Show AQ war effort pins"] = "Показувати значки воєнних зусиль Ан'Кіражу"
T["Auto-accept quests"] = "Автоприйняття завдань"
T["Auto-turn in quests"] = "Автоздача завдань"
T["Skipped breadcrumb warnings"] = "Попередження про пропущені вступні завдання"

-- /fqp help
T["Commands:"] = "Команди:"
T["  /fqp setup   Open the setup guide"] = "  /fqp setup   Відкрити посібник налаштування"
T["  /fqp track <id> Track a quest start, objective, or turn-in"] = "  /fqp track <id> Відстежити початок, ціль або здачу завдання"
T["  /fqp clear    Clear the addon waypoint"] = "  /fqp clear    Прибрати точку маршруту аддона"
T["  /fqp on       Enable quest-start pins"] = "  /fqp on       Увімкнути значки початку завдань"
T["  /fqp off      Disable quest-start pins"] = "  /fqp off      Вимкнути значки початку завдань"
T["  /fqp trivial  Toggle low-level/trivial pins (off by default)"] = "  /fqp trivial  Значки низькорівневих завдань (типово вимкнено)"
T["  /fqp trivial <%d-%d> Hide quests this many levels below you (default %d)"] = "  /fqp trivial <%d-%d> Ховати завдання настільки рівнів нижче вашого (типово %d)"
T["  /fqp highlevel <%d-%d> Hide quests this many levels above you (default %d means show all)"] = "  /fqp highlevel <%d-%d> Ховати завдання настільки рівнів вище вашого (типово %d: показувати всі)"
T["  /fqp repeatable Toggle repeatable quest pins (on by default)"] = "  /fqp repeatable Значки повторюваних завдань (типово увімкнено)"
T["  /fqp books    Toggle collectible book quest pins (off by default)"] = "  /fqp books    Значки колекційних книг (типово вимкнено)"
T["  /fqp spawns   Toggle grouped spawn pins (on by default)"] = "  /fqp spawns   Згруповані значки місць появи (типово увімкнено)"
T["  /fqp seasonal Toggle holiday/seasonal pins (off by default)"] = "  /fqp seasonal Сезонні / святкові значки (типово вимкнено)"
T["  /fqp pvp      Toggle PvP quest pins (off by default)"] = "  /fqp pvp      Значки PvP-завдань (типово вимкнено)"
T["  /fqp unexplored Toggle quest pins in unexplored areas (on by default)"] = "  /fqp unexplored Значки завдань у недосліджених місцях (типово увімкнено)"
T["  /fqp wareffort Toggle AQ war effort pins in capitals (off by default)"] = "  /fqp wareffort Значки воєнних зусиль Ан'Кіражу в столицях (типово вимкнено)"
T["  /fqp wareffort always Always show AQ war effort pins"] = "  /fqp wareffort always Завжди показувати значки воєнних зусиль Ан'Кіражу"
T["  /fqp accept   Toggle auto-accept quests"] = "  /fqp accept   Автоприйняття завдань"
T["  /fqp turnin   Toggle auto-turn in quests"] = "  /fqp turnin   Автоздача завдань"
T["  /fqp breadcrumb Toggle skipped-breadcrumb warnings"] = "  /fqp breadcrumb Попередження про пропущені вступні завдання"
T["  /fqp breadcrumbtest Preview the skipped-breadcrumb dialog"] = "  /fqp breadcrumbtest Переглянути вікно про пропущене вступне завдання"
T["  /fqp npctooltip Toggle quest accept and ready turn-in lines on NPC mouseover"] = "  /fqp npctooltip Рядки про прийняття й здачу завдань у підказці НІП"
T["  /fqp nameplates Toggle quest icons on nameplates (on by default)"] = "  /fqp nameplates Значки завдань на табличках імен (типово увімкнено)"
T["  /fqp hidden   List quest pins hidden with Shift-click on this character"] = "  /fqp hidden   Список значків, схованих Shift-кліком на цьому персонажі"
T["  /fqp unhide <id|all> Restore one or all hidden quest pins"] = "  /fqp unhide <id|all> Повернути один або всі сховані значки"
T["  /fqp debug    Toggle debug tooltips and chat diagnostics"] = "  /fqp debug    Підказки й повідомлення для налагодження"
T["  /fqp refresh  Rebuild pins on the current map"] = "  /fqp refresh  Перебудувати значки на поточній карті"
T["  /fqp nearest  Select the nearest tracked quest"] = "  /fqp nearest  Вибрати найближче відстежуване завдання"

-- /fqp nearest replies
T["Select nearest quest is unavailable in combat."] = "Вибір найближчого завдання недоступний у бою."
T["Selected the nearest quest."] = "Вибрано найближче завдання."
T["No tracked quest with a location was found."] = "Не знайдено відстежуваного завдання з відомим місцем."
