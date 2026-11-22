# Changelog

## 1.2.3

- Fixed: in battlegrounds and dungeons, UADD could make the game show many Lua errors, because chat lines there
  are protected. UADD now leaves the chat alone there, and waits until a fight ends to change a window.
  Виправлено: на полях бою та в підземеллях UADD міг спричиняти багато помилок Lua, бо рядки чату там захищені.
  Тепер UADD там не чіпає чат, а вікна змінює, лише коли бій скінчився.
- Fixed: with the TomTom module, the game menu could give a "SetFont is disallowed" error.
  Виправлено: з модулем TomTom меню гри могло давати помилку «SetFont is disallowed».
- Fixed: Questie's tracker showed a box instead of a letter in a dungeon quest's level ("[40?]").
  Виправлено: трекер Questie показував квадратик замість літери в рівні завдання підземелля («[40?]»).
- The addons' own pop-up windows have their Accept, Cancel, Yes, No and Okay buttons in Ukrainian.
  Кнопки «Прийняти», «Скасувати», «Так», «Ні» та «Гаразд» у спливних вікнах аддонів українською.
- New module UADD_DeleteCheapestItem: DeleteCheapestItem Reloaded's window, its ignored-items window, its settings page, profiles, tooltips and the minimap button's tooltip are in Ukrainian.
  Новий модуль UADD_DeleteCheapestItem: вікно DeleteCheapestItem Reloaded, вікно ігнорованих предметів, сторінка налаштувань, профілі, підказки й підказка кнопки біля мінімапи українською.
- New module UADD_LootTriage: LootTriage's settings window, its row in the game's AddOns settings, tooltip lines, chat messages, the loot window's Delete button and its What's New window are in Ukrainian.
  Новий модуль UADD_LootTriage: вікно налаштувань LootTriage, його рядок у налаштуваннях аддонів гри, рядки підказок, повідомлення в чаті, кнопка видалення у вікні здобичі та вікно «Що нового» українською.
- New module UADD_WhatTheWhisper: WhatTheWhisper's messenger window, settings, dialogs, emoji tabs, key bindings, weekday stamps, notes, the profile panel and the minimap button's place are in Ukrainian.
  Новий модуль UADD_WhatTheWhisper: вікно месенджера WhatTheWhisper, його налаштування, діалоги, вкладки емодзі, назви клавіш, дні тижня, нотатки, панель профілю й положення кнопки біля мінікарти українською.
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
- LayerSwap: updated for 1.14.43; its new texts are in Ukrainian.
  LayerSwap: оновлено для 1.14.43; його нові тексти українською.
- ForeverXP Bar: updated for 0.9.5; its new texts are in Ukrainian.
  ForeverXP Bar: оновлено для 0.9.5; його нові тексти українською.
- Auto Potion: updated for 4.1.1; its new texts are in Ukrainian.
  Auto Potion: оновлено для 4.1.1; його нові тексти українською.
- Dungeon Journal: updated for 2.1.2; its new texts are in Ukrainian.
  Dungeon Journal: оновлено для 2.1.2; його нові тексти українською.
- Mastercraft: updated for 2.0.9; its new texts are in Ukrainian.
  Mastercraft: оновлено для 2.0.9; його нові тексти українською.
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

## 1.1.0 and older

Notes for 1.0.0, 1.0.1 and 1.1.0: docs/CHANGELOG-1.0.0.md and docs/CHANGELOG-1.1.md in the GitHub repo.
Опис 1.0.0, 1.0.1 і 1.1.0: docs/CHANGELOG-1.0.0.md і docs/CHANGELOG-1.1.md у репозиторії на GitHub.
