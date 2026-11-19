# Changelog: 1.0.0

The first release. Newer releases are in UADD/CHANGELOG.md.

## 1.0.0

First release, for WoW Forever.

- UADD: the core addon. `/uadd` lists the modules. Adds a font with Cyrillic letters ("UADD Cyrillic") that
  other addons can pick.
- UADD - Questie: Questie's menus, options, tracker and tooltips in Ukrainian. Pick «Українська» as Questie's
  language if it is not picked already.
- Quest, NPC, item and zone names come from UALL Forever when it is installed. Where UALL Forever has no
  translation, the English name stays. The first collection runs in the background. When it ends, Questie
  shows the names right away, with no `/reload` (after the fight, if you are in one). Only the continent
  list in "My Journey" stays English until the next login.
- Questie's tracker gets a font with Cyrillic letters by itself, unless you picked your own font there.
  `/uadd questie font off` brings back the old font; `/uadd questie font` switches all four tracker fonts.
- Questie's tracker shows quest titles and zone headers in Ukrainian. In lines like "0/8 Witchwing Talon", the
  item or NPC name is Ukrainian too, when it is known. Lines with a task in words stay English.
  `/uadd questie off` makes the tracker English again at once.
- 11 more quest titles are Ukrainian, like "WANTED: Arnak Grimtotem". UALL Forever spells them a little
  differently ("Wanted - Arnak Grimtotem"), so UADD also tries a few such spellings. The Ukrainian is still
  UALL Forever's own.
- The tab name at the top of Questie's options ("Questie • Загальні налаштування") no longer shows a box
  instead of "і": it gets the font with Cyrillic letters too.
- A shared word base: words that several addons use with the same meaning get one Ukrainian
  translation, kept in the UADD core. Questie's menus already take their common words from it.
- If you switch off a part of UALL Forever's translation (like loot or NPC talk), those names stay English, as
  in UALL Forever, and UADD no longer waits two minutes for them at every login. Switch it back on, and
  UADD takes those names again at the next login.
- Dungeon quests like "A Vengeful Fate" show "[34D]" in Questie again, not a box after the level.
- Hold Shift (or the key you picked in UALL Forever) for a quarter of a second, and Questie is in English for
  as long as you hold the key: the tracker, quest names, map pin tooltips and Questie's own text. A quick
  Shift-click stays Ukrainian. Let go, and it is Ukrainian again. NPC and item names inside Questie stay
  Ukrainian, and windows that are already open change only when you open them again.
- UADD - Dungeon Journal: Dungeon Journal in Ukrainian, picked by default: its menus, plus dungeon,
  boss, quest and item names from UALL Forever, and the quest objectives, notes and warnings. Hold Shift to see
  English. «Українська» is in the journal's language menu, and `/uadd dj off` gives the journal back as it was.
- UADD - OpenMap: OpenMap's dungeon map on the World Map no longer shows boxes instead of Ukrainian quest titles:
  its texts get the font with Cyrillic letters. Its labels are Ukrainian too, and dungeon and boss names come
  from the names the other modules already saved (English where none is saved). Hold Shift to see English.
  `/uadd openmap off` gives the map back as it was.
- UADD - OpenMap: all of OpenMap is in Ukrainian now, not only the dungeon map: the map's menu and its tabs,
  map pins and notes, the options window, the News window and OpenMap's page in the game's Settings. Texts
  that need Ukrainian letters get a font that has them. Hold Shift or `/uadd openmap off` for English.
- UADD - OpenMap: tooltips over OpenMap's windows are Ukrainian, in a font that has Ukrainian letters; the
  tooltip gets its own font back when it closes. In OpenMap's and Questie's options windows, dropdown lists and
  the chosen value of a closed dropdown get that font too, and each part of the window gets its own font back
  before another addon's window uses it again. "Dungeon" and "Dungeons" are Ukrainian everywhere
  («Підземелля»); Shift shows each one's own English. `/uadd openmap off` puts everything back as it was:
  words, fonts, tooltips and the options window, also in windows made while the module was on but not opened.
- UADD - Dialogue UI: Dialogue UI's own words in Ukrainian: buttons, quest type labels, hints, the settings
  window, its tooltips, the book window and its chat lines. Quest text, titles and NPC names stay with
  Dialogue UI - UALL; item names, counts and item levels stay as the game shows them. Texts with Ukrainian
  letters get a font that has them. Hold Shift for English; `/uadd dialogueui off` gives Dialogue UI back as it
  was. Works on an English client only.
- UADD - ForeverXP Bar: ForeverXP Bar's own words in Ukrainian: the XP bar texts, its tooltips, the options and
  settings windows, the record, level-up and race windows, and its chat lines. Numbers, player names and what it
  sends to other players stay as they are. Texts with Ukrainian letters get a font that has them. Hold Shift for
  English; `/uadd fxpb off` gives ForeverXP Bar back as it was. Works on an English client only.
- ForeverXP Bar: times (4 год 03 хв, 36хв, 1:05), the Completed / Rested line, challenge goal lines and the
  level-up card footer are now in Ukrainian too.
- UADD - Auctionator: Auctionator's own words in Ukrainian: its auction house tabs, the buy and sell panels,
  its dialogs, its settings pages, the price lines in item tooltips and its chat lines. Item names, prices,
  shopping list names and what you type stay as they are; Auctionator's own data and settings are not changed.
  Texts with Ukrainian letters get a font that has them. Hold Shift for English; `/uadd auctionator off` gives
  Auctionator back as it was. Works on an English client only.
- UADD - Attune: Attune's own words in Ukrainian: its window, the step boxes and the tree, the Next window, its
  settings pages, tooltips, dialogs, chat lines and step notes, with quest, NPC, item and zone names from UALL
  Forever. Quest objectives, the Survey Log, the export string, what it sends to other players and its guild
  messages stay English; Attune's own data and settings are not changed. Texts with Ukrainian letters get a
  font that has them. Hold Shift for English; `/uadd attune off` gives Attune back as it was. Works on an
  English client only.
- In a fight the hold key (Shift, or your UALL Forever key) does nothing, so a Shift keybind never turns the
  texts English mid-fight. A fight that starts while English is shown brings the Ukrainian back; if you still
  hold the key when the fight ends, English shows at once. `/uadd combat off` lets the key work in a fight too,
  `/uadd combat on` turns it back.
- Made for the newest versions at release: Dungeon Journal 2.0.9, ForeverXP Bar 0.9.1 and OpenMap 0.8.10.
  Dungeon Journal's "combine with" and "made from" lines and its summon help are Ukrainian too; OpenMap's
  popups get Ukrainian words and the font with Cyrillic letters.

Українською: перший випуск. Questie українською: меню, налаштування, список завдань (назви завдань, зон,
предметів і НІП у цілях) і підказки. Назви завдань,
НІП, предметів і місць беруться з UALL Forever, якщо він встановлений. Уперше їх збирає UADD у фоні, і
коли збір закінчиться, Questie одразу показує їх, без /reload (а якщо йде бій, то після бою). Лише список
континентів у «Моїй подорожі» лишається англійською до наступного входу.
Ще 11 назв завдань тепер українською, як-от «Розшукується — Арнак Ґрімтотем»: UALL Forever пише їх
англійською трохи інакше, тому UADD пробує й такі написи. Переклад і далі береться з UALL Forever.
Назва вкладки вгорі налаштувань Questie («Questie • Загальні налаштування») тепер без квадратика замість «і».
Спільна база слів: слова, які різні аддони вживають в одному значенні, перекладено однаково. Меню Questie
вже беруть з неї спільні слова.
Якщо в UALL Forever вимкнено частину перекладу (як-от здобич чи розмови з NPC), ці назви лишаються англійською,
як і в UALL Forever, і UADD більше не чекає на них дві хвилини при кожному вході. Увімкнете знову, і при
наступному вході UADD візьме ці назви.
Завдання підземель, як-от «Мстива доля», знову показують «[34D]», а не квадратик після рівня.
Затисніть Shift (або клавішу, яку вибрано в UALL Forever) на чверть секунди, і поки тримаєте клавішу,
Questie буде англійською: список завдань, назви завдань, підказки значків на мапі й власні написи Questie.
Швидкий клік із Shift лишає все українською. Відпустіть клавішу, і знову українська.
Назви НІП і предметів у Questie лишаються українською, а вже відкриті вікна зміняться, коли відкриєте їх знову.
UADD - Dungeon Journal: Dungeon Journal українською, одразу без вибору: меню, а також назви підземель,
босів, завдань і предметів з UALL Forever, а також цілі, примітки й попередження завдань.
Затисніть Shift, щоб побачити англійською. «Українська» є в меню мов журналу, а `/uadd dj off` повертає
журнал таким, яким він був.
UADD - OpenMap: на карті підземелля OpenMap на мапі світу більше немає квадратиків замість українських назв
завдань: її тексти отримують шрифт із кирилицею. Її написи теж українською, а назви підземель і босів
беруться з назв, які вже зберегли інші модулі (англійською, якщо їх немає). Затисніть Shift, щоб побачити
англійською. `/uadd openmap off` повертає карту такою, якою вона була.
UADD - OpenMap: тепер українською весь OpenMap, а не лише карта підземелля: меню карти та його вкладки,
позначки й нотатки на карті, вікно налаштувань, вікно новин і сторінка OpenMap у налаштуваннях гри.
Тексти з українськими літерами отримують шрифт, у якому вони є. Затисніть Shift або введіть
`/uadd openmap off`, щоб побачити англійською.
UADD - OpenMap: підказки над вікнами OpenMap українською, шрифтом з українськими літерами; коли підказка
закривається, їй повертається власний шрифт. У вікнах налаштувань OpenMap і Questie такий шрифт мають і списки,
і вибране значення закритого списку, а кожна частина вікна отримує свій шрифт назад, перш ніж її візьме вікно
іншого аддона. «Dungeon» і «Dungeons» тепер усюди українською («Підземелля»); Shift показує англійське слово
кожного з них. `/uadd openmap off` повертає все як було: слова, шрифти, підказки й вікно налаштувань, також у
вікнах, які створено, поки модуль працював, але ще не відкрито.
UADD - Dialogue UI: власні написи Dialogue UI українською: кнопки, позначки типу завдання, підказки клавіш,
вікно налаштувань, підказки, вікно книги та рядки в чаті. Текст завдань, назви й імена НІП лишаються за
Dialogue UI - UALL; назви предметів, кількість і рівень предмета лишаються такими, як їх показує гра. Тексти
з українськими літерами отримують шрифт, у якому вони є. Затисніть Shift, щоб побачити англійською;
`/uadd dialogueui off` повертає Dialogue UI таким, яким він був. Працює лише в англійському клієнті.
UADD - ForeverXP Bar: власні написи ForeverXP Bar українською: тексти смуги досвіду, підказки, вікна
налаштувань, вікна рекорду, нового рівня й перегонів, і його повідомлення в чаті. Числа, імена гравців і те, що
він надсилає іншим гравцям, лишаються як є. Тексти з українськими літерами отримують шрифт, що їх має.
Затисніть Shift, щоб побачити англійською; `/uadd fxpb off` повертає ForeverXP Bar таким, яким він був.
Працює лише в англійському клієнті.
ForeverXP Bar: час (4 год 03 хв, 36хв, 1:05), рядок «Виконано / Відпочинок», рядки виклику й підсумок
картки рівня тепер теж українською.
UADD - Auctionator: власні написи Auctionator українською: вкладки аукціону, панелі купівлі й продажу, його
діалоги, сторінки налаштувань, рядки цін у підказках предметів і його повідомлення в чаті. Назви предметів,
ціни, назви списків покупок і те, що ви вводите, лишаються як є; дані й налаштування Auctionator не
змінюються. Тексти з українськими літерами отримують шрифт, що їх має. Затисніть Shift, щоб побачити
англійською; `/uadd auctionator off` повертає Auctionator таким, яким він був. Працює лише в англійському
клієнті.
UADD - Attune: власні написи Attune українською: його вікно, кроки й дерево, вікно «Далі», сторінки
налаштувань, підказки, діалоги, повідомлення в чаті й примітки до кроків, а назви завдань, НІП, предметів і
зон беруться з UALL Forever. Цілі завдань, журнал опитування, рядок експорту, те, що він надсилає іншим
гравцям, і його повідомлення гільдії лишаються англійською; дані й налаштування Attune не змінюються.
Тексти з українськими літерами отримують шрифт, що їх має. Затисніть Shift, щоб побачити англійською;
`/uadd attune off` повертає Attune таким, яким він був. Працює лише в англійському клієнті.
У бою клавіша оригіналу (Shift або ваша клавіша з UALL Forever) нічого не перемикає, тож Shift у прив'язках
клавіш не вмикає англійську посеред бою. Якщо бій почався, коли видно англійську, повертається українська;
якщо після бою клавіша ще затиснута, англійська з'являється одразу. `/uadd combat off` вмикає клавішу й у бою,
`/uadd combat on` повертає як було.
Зроблено для найновіших версій на час випуску: Dungeon Journal 2.0.9, ForeverXP Bar 0.9.1 і OpenMap 0.8.10.
Рядки Dungeon Journal про те, з чим поєднати предмет і з чого його зроблено, та його довідка про призов теж
українською; спливні вікна OpenMap отримують українські слова й шрифт із кириличними літерами.
