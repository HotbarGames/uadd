# Changelog

## Unreleased

- Game names (zones, NPCs, items, quests) now come from ClassicUA too. With both installed, UADD takes
  ClassicUA's name first and UALL Forever's where ClassicUA has none. Either one works, and so do both.
  Назви з гри (зони, НІП, предмети, завдання) тепер беруться й з ClassicUA. Коли встановлено обидва, UADD
  спершу бере назву з ClassicUA, а з UALL Forever — там, де в ClassicUA її немає. Підійде будь-який із них або обидва.
- The show-original key works with UALL Forever, ClassicUA or both: UADD follows UALL Forever's key, or
  ClassicUA's when only ClassicUA is on. The chat names the key once, and again when you add or remove one of
  them; `/uadd` shows it too.
  Клавіша оригіналу працює з UALL Forever, ClassicUA чи обома: UADD бере клавішу UALL Forever, а коли ввімкнено
  лише ClassicUA — клавішу ClassicUA. Чат називає клавішу один раз і знову, коли ви додаєте чи прибираєте одне з
  них; `/uadd` теж її показує.
- New module UADD_WaypointUI: Waypoint UI's settings, its pop-up windows, and the distance and arrival time to
  the waypoint are in Ukrainian.
  Новий модуль UADD_WaypointUI: налаштування Waypoint UI, його спливні вікна, відстань і час прибуття до точки
  маршруту українською.
- New module UADD_ForeverQuestPins: Forever Quest Pins' settings, its World Map menu, the setup and the
  breadcrumb notice are in Ukrainian.
  Новий модуль UADD_ForeverQuestPins: налаштування Forever Quest Pins, його меню на карті світу, налаштування
  при першому запуску і сповіщення про вступне завдання українською.
- New module UADD_LiteMount: LiteMount's settings, rules, mount lists, menus and dialogs are in Ukrainian.
  Новий модуль UADD_LiteMount: налаштування LiteMount, його правила, списки маунтів, меню й діалоги українською.
- LayerSwap: updated for 1.14.42; its new texts are in Ukrainian.
  LayerSwap: оновлено для 1.14.42; його нові тексти українською.
- Auto Potion: updated for 4.1.1; its new texts are in Ukrainian.
  Auto Potion: оновлено для 4.1.1; його нові тексти українською.
- Dungeon Journal: updated for 2.1.2; its new texts are in Ukrainian.
  Dungeon Journal: оновлено для 2.1.2; його нові тексти українською.
- Mastercraft: updated for 2.0.8; its new texts are in Ukrainian.
  Mastercraft: оновлено для 2.0.8; його нові тексти українською.
- OpenMap: updated for v0.8.11; its new texts are in Ukrainian. With ClassicUA, the zone name on the World Map
  now shows in English while you hold the show-original key.
  OpenMap: оновлено для v0.8.11; його нові тексти українською. З ClassicUA назва зони на карті світу тепер
  показується англійською, поки ви тримаєте клавішу оригіналу.
- Mastercraft: «Українська» is in its own language menu (the globe button). Pick it to read Mastercraft in
  Ukrainian; pick another language and that language shows whole.
  Mastercraft: «Українська» є в його власному меню мов (кнопка з глобусом). Оберіть її, щоб читати Mastercraft
  українською; оберіть іншу мову, і вона показується ціла.
- Mastercraft: more lines are in Ukrainian: the zone under your name, the materials lists, the next steps, item
  and fish names, the cooking vendor line and the skill rank, when UALL Forever or ClassicUA has every name in
  them.
  Mastercraft: більше рядків українською: зона під ім'ям, списки матеріалів, наступні кроки, назви предметів і
  риби, рядок продавця в кулінарії та ранг навички, коли UALL Forever або ClassicUA має всі назви в них.
- Mastercraft: the guide's step names on the Professions page ("<recipe> x51") are in Ukrainian when UALL Forever
  or ClassicUA knows the recipe.
  Mastercraft: назви кроків посібника на сторінці професій («<рецепт> x51») українською, коли UALL Forever або
  ClassicUA знає рецепт.
- What's Training?: the section headers ("Available now", "Missing requirements" and the like) are in Ukrainian.
  What's Training?: заголовки розділів («Доступно зараз», «Доступно, але бракує вимог» тощо) українською.

## 1.2.2

- ForeverXP Bar: updated for 0.9.4; its new texts are in Ukrainian (the flight map time, What's New).
  ForeverXP Bar: оновлено для 0.9.4; його нові тексти українською (час перельоту на мапі, «Що нового»).
- Fixed: item and spell tooltips, and TomTom's arrow title, could show boxes instead of letters until /reload,
  because UADD put a line's old font back by its file, which has no Cyrillic letters.
  Виправлено: підказки предметів і заклять, а також назва над стрілкою TomTom, могли показувати квадратики
  замість літер до /reload, бо UADD повертав рядку старий шрифт за його файлом, у якому немає кирилиці.
- New: safeguards. A module that keeps failing turns itself off for the session, says so once in chat, and its
  addon is English again. A guard repairs a tooltip font or a keyboard that UADD might still break, and says so.
  Нове: запобіжники. Модуль, що раз у раз дає помилку, вимикається до кінця сесії, пише про це один раз у чат, і
  його аддон знову англійською. Охоронець лагодить шрифт підказки чи клавіатуру, якщо UADD таки їх зламає, і
  пише про це.
- Fixed: game names (zones, NPCs, items, spells) inside What's Training?, TomTom and Mastercraft lines stayed
  English; they now come from UALL Forever.
  Виправлено: назви з гри (зони, NPC, предмети, закляття) в рядках What's Training?, TomTom і Mastercraft
  лишалися англійською; тепер вони беруться з UALL Forever.
- Fixed: several modules did extra work for every chat line or tooltip of the game, or let an error reach the
  game's error window; found by a new test that tries to break every module on purpose.
  Виправлено: кілька модулів робили зайву роботу для кожного рядка чату чи підказки гри або пропускали помилку у
  вікно помилок гри; це знайшов новий тест, що навмисно пробує зламати кожен модуль.
- Dialogue UI: its page in the game's options (Options > AddOns) is in Ukrainian.
  Dialogue UI: його сторінка в налаштуваннях гри (Options > AddOns) українською.
- Dungeon Journal: quest giver lines ("Name, Town, Zone") and the header's level line are in Ukrainian when
  UALL Forever has every name in them; otherwise the line stays whole English.
  Dungeon Journal: рядки про того, хто дає завдання («Ім'я, Місто, Зона»), і рядок рівня в заголовку українською,
  коли UALL Forever має всі назви в них; інакше рядок лишається цілком англійським.
- LayerSwap: updated for 1.14.39; its new texts (panel statuses, buttons, tooltips) are in Ukrainian.
  LayerSwap: оновлено для 1.14.39; його нові тексти (стани панелі, кнопки, підказки) українською.
- Dungeon Journal: updated for 2.1.0; its new texts and the reputation requirement line are in Ukrainian, and
  quest texts follow UALL Forever's new names.
  Dungeon Journal: оновлено для 2.1.0; його нові тексти й рядок вимоги репутації українською, а тексти завдань
  узгоджено з новими назвами UALL Forever.
- Dungeon Journal: about 220 quest texts no longer carry an English name in the middle of Ukrainian. Each is
  said without the name, or stays whole English where the name is the point (whom to find).
  Dungeon Journal: близько 220 текстів завдань більше не мають англійської назви посеред української. Кожен
  сказано без назви або лишено цілком англійським, коли назва і є суттю (кого знайти).
- Pawn, AutoPotion, Bagnon, Scrap: the game names they show (stats, classes, spells, potions, bag titles,
  items) come from UALL Forever; a name it lacks stays English.
  Pawn, AutoPotion, Bagnon, Scrap: назви з гри, які вони показують (характеристики, класи, закляття, зілля, назви
  сумок, предмети), беруться з UALL Forever; назва, якої там немає, лишається англійською.
- Changed: profession, rank, trainer and weapon skill names now use UALL Forever's words, as in the rest of the
  game (Skinning is «Білування», Mining «Гірнича справа», Expert «Експерт»).
  Змінено: назви професій, рангів, учителів і володіння зброєю тепер ті самі, що в UALL Forever і в решті гри
  (Skinning - «Білування», Mining - «Гірнича справа», Expert - «Експерт»).

## 1.2.1

- Fixed: with the Mastercraft or What's Training? module loaded, the keyboard stopped working (Enter did not open
  chat), because UADD made an invisible text box that took the keyboard.
  Виправлено: з модулем Mastercraft або What's Training? клавіатура переставала працювати (Enter не відкривав
  чат), бо UADD створював невидиме текстове поле, яке забирало клавіатуру.
- New module UADD_SpeedyAutoLoot: Speedy AutoLoot's chat lines, its /sal help and the loot display's anchor in
  Ukrainian. Item names and money in the loot display stay as the game gives them.
  Новий модуль UADD_SpeedyAutoLoot: рядки в чаті, довідка /sal та рамка показу здобичі Speedy AutoLoot
  українською. Назви предметів і гроші в показі здобичі лишаються такими, як їх дає гра.

## 1.2.0

- New module UADD_Pawn: Pawn's window, settings page, item tooltip lines, upgrade advisors and chat lines in
  Ukrainian. Names from the game (scale names, spec names) stay English, and a few lines with game names stay English.
  Новий модуль UADD_Pawn: вікно, сторінка налаштувань, рядки підказок предметів, поради щодо покращень та рядки в
  чаті Pawn українською. Назви з гри (назви шкал, спеціалізацій) лишаються англійською, як і кілька рядків з назвами з гри.
- New module UADD_GatherMate2: GatherMate2's settings pages, chat lines, launcher tooltip and map pin menu in
  Ukrainian. Herb, ore, fish, zone and profession names stay as the game gives them.
  Новий модуль UADD_GatherMate2: сторінки налаштувань, рядки в чаті, підказка кнопки та меню точки на мапі
  GatherMate2 українською. Назви трав, руд, риби, зон і професій лишаються такими, як їх дає гра.
- New module UADD_Scrap: Scrap's settings pages, junk list, vendor button, chat lines, key bindings and tutorial
  in Ukrainian. Item names stay as the game gives them, and chat lines with an item link stay English.
  Новий модуль UADD_Scrap: сторінки налаштувань, список мотлоху, кнопка в торговця, рядки в чаті, клавіші та
  підказки для новачків Scrap українською. Назви предметів лишаються такими, як їх дає гра, а рядки в чаті з
  посиланням на предмет лишаються англійською.

## 1.1.0

- New module UADD_RareScanner: RareScanner's settings, map menus, explorer, pop-ups, tooltips and chat lines in
  Ukrainian. Lines with a game name stay English for now; the default custom group names stay English.
  Новий модуль UADD_RareScanner: налаштування, меню на мапі, провідник, спливні вікна, підказки та рядки в чаті
  RareScanner українською. Рядки з назвами з гри поки лишаються англійською, як і типові назви власних груп.
- LayerSwap: updated for 1.14.38; its new texts are in Ukrainian (swap limit, mini bar, nameplate help).
  LayerSwap: оновлено для 1.14.38; його нові тексти українською (ліміт змін, мала панель, підказка табличок).
- New module UADD_TomTom: TomTom's settings, arrow, menus, pop-ups, tooltips and chat lines in Ukrainian.
  Zone names follow UALL Forever; waypoint titles stay as they are.
  Новий модуль UADD_TomTom: налаштування, стрілка, меню, спливні вікна, підказки та рядки в чаті TomTom
  українською. Назви зон беруться з UALL Forever; назви точок маршруту лишаються як є.
- New module UADD_WhatsTraining: What's Training?'s windows, buttons, tooltips (also the broker and minimap
  ones) and chat lines in Ukrainian. The broker's own text on a data bar stays English. Spell, faction and other game names follow UALL Forever or stay English. New
  shared core files UADD/Words.lua and UADD/Lines.lua.
  Новий модуль UADD_WhatsTraining: вікна, кнопки, підказки (і ті, що в брокера та
  мінікарти) та рядки в чаті What's Training? українською. Сам текст брокера на панелі даних лишається
  англійським. Назви заклять, фракцій та інші назви з гри беруться з UALL Forever або
  лишаються англійськими. Нові спільні файли ядра: UADD/Words.lua і UADD/Lines.lua.
- New module UADD_Mastercraft: Mastercraft's windows, tabs, buttons, tooltips, pop-ups and chat lines in
  Ukrainian. Item, zone and NPC names stay the game's.
  Новий модуль UADD_Mastercraft: вікна, вкладки, кнопки, підказки, спливні вікна й рядки в чаті Mastercraft
  українською. Назви предметів, зон і NPC лишаються такими, як у грі.
- New module UADD_Bagnon: Bagnon's bag, bank and guild bank windows, menus, tooltips, Key Bindings names
  and settings pages in Ukrainian. Item names stay the game's.
  Новий модуль UADD_Bagnon: вікна сумок, банку й банку гільдії, меню, підказки, назви в Key Bindings і
  сторінки налаштувань Bagnon українською. Назви предметів лишаються такими, як у грі.
- New module UADD_AutoPotion: Auto Potion's settings, tooltips, chat lines and Key Bindings names in
  Ukrainian. Macro, spell and item names stay English.
  Новий модуль UADD_AutoPotion: налаштування, підказки, рядки в чаті й назви в Key Bindings Auto Potion
  українською. Назви макросів, заклять і предметів лишаються англійською.
- New module UADD_LayerSwap: LayerSwap's panel, small bar, menus, options, tooltips and chat
  lines in Ukrainian. Its layer channel, whispers, invites and addon messages stay English.
  Новий модуль UADD_LayerSwap: панель, мала панель, меню, налаштування, підказки й рядки в чаті LayerSwap
  українською.
- LayerSwap: updated for 1.14.35; its new texts are in Ukrainian (flight paths, hosts that do not answer,
  inviting in a group). A server layer is now «лейер» everywhere in the module.
  LayerSwap: оновлено для 1.14.35; його нові написи українською (польоти, хости, що не відповідають,
  запрошення в групі). Серверний шар тепер скрізь «лейер».
- LayerSwap: updated for 1.14.36; its new text is in Ukrainian (the game moved you back to your layer).
  LayerSwap: оновлено для 1.14.36; його новий напис українською (гра повернула вас на ваш лейер).
- Auto Potion: updated for 4.1.0; its new texts are in Ukrainian (mana spells, Demonic Runes).
  Auto Potion: оновлено для 4.1.0; його нові написи українською (закляття мани, Демонічні Руни).
- Questie: updated for 12.11.1; its new tracker shortcut options are in Ukrainian.
  Questie: оновлено для 12.11.1; його нові налаштування комбінацій трекера українською.
- ForeverXP Bar: updated for 0.9.3; its new texts are in Ukrainian (the "What's new" page and button,
  the /fxpb help line, flight times, gold per hour, the settings rows that still showed English).
  The new /fxpb blizzdebug lines stay English: they are for bug reports.
  ForeverXP Bar: оновлено для 0.9.3; його нові написи українською (сторінка й кнопка «Що нового»,
  довідка /fxpb, час польоту, золото за годину, рядки налаштувань, що ще були англійською).
  Нові рядки /fxpb blizzdebug лишаються англійською: вони для звітів про помилки.
- Dungeon Journal: updated for 2.0.12; its new texts are in Ukrainian (resizing the journal, quest rewards in
  the loot search, "can also spawn here" on the map, why a dungeon is hidden, a Blackrock Depths quest).
  Dungeon Journal: оновлено для 2.0.12; його нові написи українською (зміна розміру журналу, нагороди за
  завдання в пошуку здобичі, «Може з'явитися й тут» на мапі, чому підземелля сховано, завдання в Глибинах
  Чорної Скелі).
- Questie: updated for 12.11.0; its new texts are in Ukrainian ("Also for active quests", the share
  shortcut, "Share Quest", the QuestieTrace messages).
  Questie: оновлено для 12.11.0; його нові тексти українською («Також для активних завдань», комбінація
  «Поділитися / Посилання», «Поділитися завданням», повідомлення QuestieTrace).
- Attune: checked for 16001-43; its new texts are quest, NPC and item names, which UALL Forever translates.
  Attune: перевірено для 16001-43; його нові написи — назви завдань, НІП і предметів, їх перекладає UALL Forever.
- New command for testers: `/uadd missed on` notes the texts the modules show in English for lack of
  Ukrainian (off by default, and then free). `/uadd missed` shows how many per module. The list stays on
  your PC. `/uadd missed off` stops it, `/uadd missed clear` empties it.
  Нова команда для тестувальників: `/uadd missed on` записує написи, які модулі показують англійською,
  бо ще не мають перекладу (типово вимкнена, тоді нічого не коштує). `/uadd missed` показує, скільки їх у
  кожному модулі. Список лишається на вашому комп'ютері. `/uadd missed off`
  зупиняє, `/uadd missed clear` стирає.
- Dialogue UI: updated for 1.0.7 c; its new "Restart" quest button is «Почати знову».
  Dialogue UI: оновлено для 1.0.7 c; його нова кнопка завдання «Restart» тепер «Почати знову».

## 1.0.1

- The addon list shows the UADD logo as the icon of UADD and of each module, instead of a red question mark.
- "Instance" is now «підземелля» everywhere, not «інстанс»: in the settings of Questie, Dialogue UI and
  OpenMap, in the Dungeon Journal and in Attune's notes.
- The tab name at the top of Questie's options again gets the font with Cyrillic letters, so
  «Загальні налаштування» has no box instead of "і". Before, UADD wrongly thought the font did not load and
  gave up. A Questie options tab made later, in the game's settings window, gets the font too.
- The "show original" key follows UALL Forever's reverse setting: when it is on, the addons show English and
  holding the key shows Ukrainian. Without UALL Forever, nothing changes.
- Auctionator: more of its Selling and Cancelling tabs is in Ukrainian. The "Quantity" label next to the
  number box, the bag group titles (Favourites, Consumable, Trade Goods, Recipe and the rest), and the
  column headers of tables that were hidden when they were built (the price history tables under the
  Selling tab's price boxes). The item names in the Cancelling list come from UALL Forever when it is on,
  in their quality colour; a name it does not know stays English.
- Auctionator: the big item name at the top of the Selling tab, and the item name in the Shopping tab's buy
  panel, now come from UALL Forever too («Важка Шкіра» for "Heavy Hide"), in their quality colour. An item
  level like "(35)" stays after the name, also in the Shopping and Cancelling lists. A name UALL Forever
  does not know stays English.
- Auctionator: the item level column header in the Buy, Selling and Shopping lists is «Рівень», so it
  is no longer cut to «Рівень пред...». Roomier places (the Shopping item range, tooltips) keep
  «Рівень предмета».
- OpenMap: the World Map's label over a zone is whole Ukrainian where OpenMap adds the zone's levels
  and fishing skill. "Tirisfal Glades (1-10)" shows the zone's Ukrainian name with "(1-10)", and
  "Fishing 25" is «Риболовля 25». The zone's name is UALL Forever's own; a zone without one stays
  whole English.
- Questie: UADD no longer translates the tracker (the quest list on the screen). UALL Forever does that, with
  its own font for each line. UADD now only keeps Questie's own words in the tracker English, so UALL Forever
  can translate each whole line. The `/uadd questie font` and `font off` commands are gone. If an older UADD
  switched the tracker fonts to "UADD Cyrillic", the fonts it switched come back (Friz Quadrata TT by default).
  Menus, settings, tooltips, My Journey, map pins and the names from UALL Forever are still Ukrainian.
- ForeverXP Bar: the line under the bar is shorter, «До рівня: 3 год 59 хв (16.5k/год)», so it no longer
  runs into «Виконано / Відпочинок» on a narrow bar.

## 1.0.0

First release, for WoW Forever. Its full notes: docs/CHANGELOG-1.0.0.md in the GitHub repo.
Перший випуск, для WoW Forever. Повний опис: docs/CHANGELOG-1.0.0.md у репозиторії на GitHub.
