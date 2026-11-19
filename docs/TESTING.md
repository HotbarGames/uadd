# Testing in the game

What to check before a release, on WoW Forever with Questie installed. UALL Forever is optional: test
once with it and once without it.

## Install

Close the game, then run `install.bat` (or copy `UADD`, `UADD_Questie` and `UADD_DungeonJournal` into
`World of Warcraft\_forever_\Interface\AddOns\`). The journal checks need Dungeon Journal installed. Turn on Lua errors: `/console scriptErrors 1`, or use BugSack.

## Checks

1. Log in. `/uadd` lists the modules "Questie" and "Dungeon Journal" with their status.
2. `/uadd questie` shows the status line and the commands.
3. Questie's options (`/questie`), the minimap button tooltip and the quest tooltips are in
   Ukrainian. Questie's language setting shows «Українська».
4. With UALL Forever: the chat says names are being collected. Wait for the message that the names are ready
   and shown. Do not `/reload`. The map pins vanish for a moment and come back. Now quest, NPC, item and zone
   names on Questie's map pins and in its tooltips are Ukrainian where UALL Forever has them. The rest stays
   English. Check a quest you already have in your quest log: its map pins and tooltip are Ukrainian too.
   Only the continent list in "My Journey" stays English until the next login.
   Questie's tracker (the quest list on the screen) is UALL Forever's work, not UADD's. UADD only keeps
   Questie's own words in it English, so UALL Forever can translate each whole line. Check that its lines,
   its zone headers and its title ("Questie Tracker: 7/20") show no boxes, also a quest that is done
   ("(Complete)") and a dungeon quest ("[34D]", a Latin letter after the level).
5. Without UALL Forever: the menus are still Ukrainian, the names stay English, and there are no errors.
6. If an older UADD switched the tracker fonts to "UADD Cyrillic", the first login with this version puts back
   the fonts it switched (Friz Quadrata TT by default). A font you picked yourself stays.
7. `/uadd questie off`, then `/reload`: Questie is fully English. `/uadd questie on`, then `/reload`: Ukrainian
   again. A second login uses the saved names and does not collect them again.
8. `/uadd questie rebuild` collects the names again in the background. `/uadd questie test` checks the link to
   UALL Forever.
9. Fight while names are being collected: no stutter, and collection pauses until the fight ends. If the
   collection ends during a fight, the "ready" message and the new names come only once the fight ends.
   `/uadd questie off` before that: nothing is put into Questie.
10. No Lua errors. Log out once and back in: everything works again.

### Dungeon Journal

11. Open the journal. Its language menu shows «Українська», picked. The menus, tabs and buttons are Ukrainian,
    with Cyrillic letters (no boxes).
12. With UALL Forever, after the names are ready: dungeon names (also "Dire Maul: East", "Scarlet Monastery:
    Armory", "Hall of Thanes"), boss names, quest titles and item names are Ukrainian where UALL Forever has
    them. Click another boss, another tab, another dungeon and a search result: the item names change with
    the page each time and are never stale English. Quest objectives, notes and warnings are Ukrainian.
13. Hold Shift for a moment: the names on the page (dungeons, bosses, quests, items) turn English while
    you hold it. Let go: Ukrainian again. A quick Shift-click stays Ukrainian. The journal's own labels
    (tabs, buttons) stay Ukrainian while you hold the key: the journal has no quiet way to redraw them.
    Open a second and a third dungeon: the dungeon title has no boxes on any of them.
14. Pick «Русский» in the journal: it looks the same as without UADD. Pick «Українська» again: Ukrainian.
15. `/uadd dj off`: the journal is as without UADD, at once. `/uadd dj on`: Ukrainian again. Each of the
    two plays the journal's menu click once (it redraws through the journal's own language option).
    `/uadd dj rebuild` collects the names again in the background.

### OpenMap

16. Go into a dungeon with quests in your log (Razorfen Kraul is a good one) and open the World Map.
    OpenMap's dungeon map, its side panel and the card: every text has Cyrillic letters, no boxes. Quest
    titles from Questie read in Ukrainian. Do the same outside, from OpenMap's dungeon chooser.
17. The tabs, quest states ("виконано", "у журналі"), the level line, the floor name, the hint and the Back
    button are Ukrainian. Dungeon and boss names are Ukrainian once the journal or Questie module saved them;
    before that, English. Check that the tab labels ("Завдання") and the Back button fit their boxes.
18. Hold Shift for a moment: OpenMap's words turn English, the fonts stay (no boxes). Let go: Ukrainian.
19. `/uadd openmap off`: the map is as without UADD, at once (and shows the boxes again, as before UADD).
    `/uadd openmap on`: Ukrainian again. `/uadd dj off` leaves OpenMap's map in Ukrainian.
20. Open the World Map in a fight: nothing breaks and no Lua errors. After the fight the map is Ukrainian.
21. Open the map's menu (OpenMap's button on the World Map): the tabs ("На карті", "Вигляд", "Більше"),
    every row and button are Ukrainian, with no boxes. Check that long labels fit their rows.
22. Open OpenMap's options (right-click the minimap button, or "Відкрити налаштування OpenMap" on its page
    in the game's Settings, Esc > Options > AddOns): names and descriptions are Ukrainian, no boxes. Close
    it and open another addon's options (Questie's): its fonts look as they do without UADD.
23. Open the News window (What's new): the title "Що нового", the buttons and the Credits page are
    Ukrainian, no boxes. The title loses its old-style MORPHEUS look (the game has no such font with
    Ukrainian letters); the English version lines keep it.
24. With the menu, the options window and News open, hold Shift: all three turn English. Let go: Ukrainian.
    Hold Shift in a fight: nothing changes until the fight ends, then English while you still hold it.
25. `/uadd openmap off` with them open: English at once, the News title back in MORPHEUS. `on`: Ukrainian.
26. Point at buttons and tabs on OpenMap's menu, the dungeon map's side tabs and map pins: the tooltips are
    Ukrainian, no boxes. Then point at an item in your bags: its tooltip looks as without UADD.
27. In OpenMap's options window open a dropdown list: its items are Ukrainian, no boxes. Close the list: the
    chosen value shows with no boxes. Do the same in Questie's options window. Then switch tabs, close the
    window and open another addon's options: its fonts look as without UADD.
28. On the dungeon map, hold Shift: the side tab tooltip says "Dungeon", the menu header "Dungeons" (both
    «Підземелля» in Ukrainian). `/uadd openmap off`: tooltips, the options window and the News window are all
    English in their own fonts, also windows you open for the first time after "off".

### Dialogue UI

These need Dialogue UI on an English client. Test once with Dialogue UI - UALL and once without it.

29. Log in. `/uadd` lists "Dialogue UI". `/uadd dialogueui` shows "увімкнено" with the word count.
30. Talk to an NPC with quests: the buttons ("Прийняти", "Відмовитися", "Далі"...), the quest type labels and
    the key hints are Ukrainian, with no boxes. Quest titles and quest text are as before (Ukrainian from
    Dialogue UI - UALL, or English without it).
31. Accept, progress and complete a quest with item rewards: item names, counts and "Item Level" lines stay as
    the game shows them; the item level difference (green or red number) still shows.
32. Open Dialogue UI's settings: tab and option names are Ukrainian in CAPITALS; the description of an option is
    Ukrainian, also when it has two parts ("Default: ..."). Open a dropdown list: no boxes.
33. Point at a reward and at a setting: Dialogue UI's own tooltip lines are Ukrainian and fit the tooltip.
34. Read a book or a plaque (Dialogue UI's book window): its buttons are Ukrainian; the book's own text is as before.
35. Make Dialogue UI print a chat line (for example turn on auto select and pick an option): the header is
    Ukrainian, the quest or option name after it is not changed.
36. Hold Shift with the dialogue window and the settings open: Dialogue UI's words turn English. Let go: Ukrainian.
37. `/uadd dialogueui off` with the window open: English at once, in Dialogue UI's own fonts. Its chat lines are
    English too. `/uadd dialogueui on`: Ukrainian again.
38. Talk to an NPC in a fight, and type `/uadd dialogueui off` in a fight: no Lua errors, no blocked action. The
    words change once the fight ends.
39. In Dialogue UI's settings change the font and the font size: the words stay Ukrainian, with no boxes.
40. With Dialogue UI - UALL: its quest titles, NPC names and option texts keep its words and its fonts.
41. Log in without Dialogue UI: `/uadd dialogueui` says it waits for Dialogue UI, and there are no errors.

### Auctionator

These need Auctionator on an English client, and an auction house to stand at.

42. Log in. `/uadd` lists "Auctionator". `/uadd auctionator` shows "увімкнено" with the word count.
43. Open the auction house: Auctionator's tabs (Shopping, Selling, Cancelling) and its buttons are Ukrainian,
    with no boxes. The game's own tabs and buttons (Browse, Bids, Cancel) stay as the game shows them.
44. Search on the Shopping tab: the column heads and the status line are Ukrainian; item names,
    prices and counts stay as they are. Click a row and use the buy panel: its words are Ukrainian.
45. Type in the search box and in a shopping list name: what you type stays as you typed it. Turn on the
    extended search: its text in the search box stays English and the search still works.
46. Selling tab: put an item in; the duration buttons read in Ukrainian with their 2 / 8 / 12 / 24 / 48 hours,
    the "undercut" column and the post button work as before.
47. Open Auctionator's settings (game Settings, AddOns, Auctionator): its pages and options are Ukrainian.
48. Point at an item in your bags: Auctionator's price lines in the tooltip (auction, vendor ...) are
    Ukrainian; the money stays as the game shows it.
49. Type `/auctionator help` (or `/atr help`): its chat lines are Ukrainian, with the command names unchanged.
50. Open a drop-down (the shopping list menu, a column head's right-click menu): its items are Ukrainian.
51. Hold Shift with the auction house open: Auctionator's words turn English. Let go: Ukrainian.
52. `/uadd auctionator off` with the auction house open: English at once, in Auctionator's own fonts; chat
    and tooltip lines are English too. `/uadd auctionator on`: Ukrainian again.
53. Type `/uadd auctionator off` in a fight: no Lua errors, no blocked action. The words change once the fight ends.
54. Log in without Auctionator: the game does not load UADD - Auctionator (a required dependency), `/uadd`
    does not list it, and there are no errors.

### Attune

These need Attune on an English client. UALL Forever is needed for the names.

55. Log in. `/uadd` lists "Attune". `/uadd attune` shows "увімкнено" with the word count; a minute later the
    name counts (quests, NPCs, items, zones) are above 0.
56. Open Attune (`/attune`): the title, the tree, the buttons and the status bar are Ukrainian, with no boxes.
    Attunement names, quest titles, NPC and zone names are Ukrainian where UALL Forever has them.
57. Pick an attunement: the step boxes show Ukrainian step types and notes; quest objectives stay English.
    Long words fit their boxes (check the width by eye).
58. Point at a step, a tree row, a button and the minimap button: the tooltip lines are Ukrainian and fit.
    Point at a quest step: the small "starts at" tooltip next to it is Ukrainian too.
59. Open the Next window and minimize it: its words are Ukrainian. Switch to the icon view and the list view.
60. Open Attune's settings (game Settings, AddOns, Attune): its pages, options and their tooltips are Ukrainian.
61. Open the export, sync and website dialogs: their texts are Ukrainian; the export string and the address in
    the edit box stay as they are. A sync with a guild mate still works.
62. Make Attune print a chat line (for example `/attune help`): the line after "[Attune]" is Ukrainian; the
    guild announce of a finished attunement stays English. The Survey Log stays English.
63. Hold Shift with the window and a tooltip open: Attune's words turn English. Let go: Ukrainian.
64. `/uadd attune off` with the window open: English at once, in Attune's own fonts; tooltips, dialogs and chat
    are English too. `/uadd attune on`: Ukrainian again.
65. Type `/uadd attune off` in a fight: no Lua errors, no blocked action. The words change once the fight ends.
66. Log in without Attune: the game does not load UADD - Attune (a required dependency), `/uadd` does not
    list it, and there are no errors. Log in without
    UALL Forever: Attune's own words are Ukrainian, the names stay English.

### Auto Potion

These need Auto Potion on an English client. UALL Forever is not needed (it has no hooks for Auto Potion).

67. Log in. `/uadd` lists "Auto Potion". `/uadd autopotion` shows "увімкнено" with the word count.
68. Open Auto Potion's settings (`/ap`, or game Settings, AddOns): its six pages, check boxes and the Reset
    button are Ukrainian, with no boxes, and fit. Spell, item and class names stay as the game shows them.
69. Point at a check box: its tooltip is Ukrainian. Other tooltips (bags, spells) do not change.
70. Open Key Bindings: the "Auto Potion" category's five lines are Ukrainian.
71. Type `/ap` with a word after it, and `/ap debug`: the lines after "AutoPotion:" are Ukrainian; the debug
    log lines stay English. The five macros keep their English names.
72. Hold Shift with the settings and a tooltip open: the words turn English. Let go: Ukrainian.
73. `/uadd autopotion off` with the settings open: English at once, in Auto Potion's own fonts; Key Bindings
    and chat are English too. `/uadd autopotion on`: Ukrainian again.
74. Log in without Auto Potion: the game does not load UADD - Auto Potion (a required dependency), `/uadd`
    does not list it, and there are no errors.

### Bagnon

These need Bagnon (with BagBrother, Bagnon_Config, Bagnon_Bank and Bagnon_GuildBank) on an English client.

75. Log in. `/uadd` lists "Bagnon". `/uadd bagnon` shows "увімкнено" with the word and font counts.
76. Open the bags: the title («Інвентар: <name>»), the buttons' tooltips and the right-click menus are
    Ukrainian, with no boxes, and fit. Item names and item tooltips stay as the game shows them.
77. Open the bank at a banker: its title («Банк: <name>»), tooltips and menus are Ukrainian. Then the guild
    bank: its title is the guild's name; the tabs' tooltips and «Кошти гільдії» are Ukrainian. Numbers and
    money stay as the game writes them. These lines stay English on purpose (Bagnon glues them to the
    game's own English word): the title tooltip's search line, the guild money tooltip's withdraw line, and
    a guild tab's remaining-withdrawals line.
78. Open Bagnon's settings (game Settings, AddOns, Bagnon): every page (general, windows, display, slot
    colours, help, patrons) is Ukrainian and fits; the help page's questions and answers too. The page
    names in the game's Settings list are Ukrainian (after a `/reload` if Bagnon_Config loaded first).
79. Open Key Bindings: the "Bagnon" lines are Ukrainian.
80. Hold Shift with the bags and a tooltip open: Bagnon's words turn English. Let go: Ukrainian.
81. `/uadd bagnon off` with the bags open: English at once, in Bagnon's own fonts. The page names in the
    game's Settings list stay until `/reload`. `/uadd bagnon on`: Ukrainian again.
82. Log in without Bagnon: the game does not load UADD - Bagnon (Bagnon is a required dependency), `/uadd`
    does not list it, and there are no errors.

### Mastercraft

These need Mastercraft (Mastercraft_Inbox loads on demand with it and needs nothing of its own) on an
English client. Mastercraft stays on its English; UADD changes what it shows. How to open each window is
Mastercraft's own (its minimap button or slash command).

83. Log in. `/uadd` lists "Mastercraft". `/uadd mastercraft` shows "увімкнено" with the text and font counts.
84. Open Mastercraft and click every tab: Home («Головна»), Professions («Професії»), Codex («Кодекс»),
    Alts («Альти»), Cooldowns («Перезарядки»), Crafters («Майстри»), Camping («Табір»), Gold («Золото»),
    Specs («Спеціалізації»), Suggestions («Поради»), Settings («Налаштування»). Each tab name and the
    page under it is Ukrainian, with no boxes. The side names fit; the capital-letter column headings show
    і ї є ґ correctly. Mastercraft's own language button still lists its own languages.
85. Open the fishing helper, the trade board and a profession guide: titles, buttons and hints are
    Ukrainian (the fishing words: «приманка», «вудка», «поплавок»; the board: «Торгова дошка»). Item, zone and
    NPC names stay as UALL Forever (or the game) has them; a line with a name UALL Forever lacks stays
    wholly English.
86. Open a crafter's shop and the Network page («Мережа»), then the Inbox part of the Crafters tab: the
    lines are Ukrainian. Text another player typed (a request note, chat) is never changed.
87. Point at an item and at a recipe: the lines Mastercraft adds to the tooltip are Ukrainian; the rest of
    the tooltip is the game's. Do something Mastercraft reports in chat (learn a recipe, skill up): its chat
    lines are Ukrainian.
88. Hold Shift with Mastercraft and a tooltip open: Mastercraft's words turn English. Let go: Ukrainian.
89. `/uadd mastercraft off` with a window open: English at once, in Mastercraft's own fonts; tooltips and
    chat lines are English too. `/uadd mastercraft on`: Ukrainian again.
90. Log in without Mastercraft: the game does not load UADD - Mastercraft (Mastercraft is a required
    dependency), `/uadd` does not list it, and there are no errors.

### What's Training?

These need What's Training? (folder WhatsTraining) on an English client. It stays on its English; UADD
changes what it shows. Open its window with its own button or slash command (`/wt`), or its minimap
button.

91. Log in. `/uadd` lists "What's Training?". `/uadd whatstraining` shows "увімкнено" with the text counts.
92. Open the What's Training? window and click each tab and button: the labels, headings, filters and
    settings are Ukrainian, with no boxes (і ї є ґ draw), and each fits its box.
93. Point at a row and at its buttons: the lines What's Training? adds to the tooltip are Ukrainian; the
    spell text is the game's. Spell, faction, zone and NPC names are UALL Forever's, or stay English.
    A line with a name UALL Forever lacks stays wholly English.
94. Point at the broker (data bar) and the minimap button: their tooltips are Ukrainian. The broker's own
    text on the bar stays English (another addon draws it). Do something it reports in
    chat (a waypoint, a trainer lookup): its chat lines are Ukrainian.
95. Hold Shift with What's Training? and a tooltip open: its words turn English. Let go: Ukrainian.
96. `/uadd whatstraining off` with the window open: English at once. `/uadd whatstraining on`: Ukrainian
    again.
97. Log in without What's Training?: the game does not load UADD - What's Training? (it is a required
    dependency), `/uadd` does not list it, and there are no errors.

### TomTom

These need TomTom on an English client. Type `/uadd missed on` first, then `/reload`.
98. Log in. `/uadd` lists "TomTom". `/uadd tomtom` shows "увімкнено" with the text counts.
99. Open TomTom's settings pages (rows, tooltips, dropdowns): Ukrainian, no boxes, each text fits.
100. Make a waypoint. The arrow's distance line reads «1 ярд», «2 ярди», «5 ярдів», «21 ярд».
101. `/way 50 50 Test`: the chat line is Ukrainian; the title "Test" stays as typed.
102. Point at a pin on the world map and on the minimap: the tooltip lines are Ukrainian.
103. `/ttpaste` (paste window), "Remove all" (pop-up), the coordinate block and the world map's Player and
    Cursor labels: Ukrainian, no boxes.
104. Hold Shift with a tooltip open: English; let go: Ukrainian.
105. `/uadd tomtom off`: English again (settings pages after `/reload`); `on`: Ukrainian.
106. Log in without TomTom: the game does not load UADD - TomTom, `/uadd` does not list it, no errors.

## Not checked outside the game

- Whether `Fonts\FRIZQT___CYR.TTF` exists in the Forever client (the addon falls back to `Fonts\ARIALN.TTF`).
- How many names UALL Forever has, and how long the first collection takes.
- Whether every Questie window shows the translated names.
- Whether the names show at once after the first collection in every Questie window, with no `/reload`:
  map pins, tooltips, "My Journey", quest details. The test harness checks Questie's quest, NPC and item
  data, not what the map and tooltips draw.
- How long the map pins are gone while Questie puts the new names in, with a full quest log.
- How big the saved name cache gets in `WTF\Account\<ACCOUNT>\SavedVariables\UADD.lua`.
- Questie's options tabs as the game draws them: since Questie 12.8 a tab scrolls in the game's scroll box
  and its dropdowns use the game's menu. The harness builds the real tabs, but on simple stand-ins for
  those game parts. A Questie error printed in chat (`[ERROR]`) counts as a Lua error in the checks.
- OpenMap's real frames: the harness checks UADD_OpenMap on a small stand-in shaped like OpenMap's dungeon
  map, not on OpenMap itself. Its tooltips are checked on stand-in windows too, not on OpenMap's own.
- Dialogue UI's real frames: whether every text fits after it turns Ukrainian (Dialogue UI may size a frame
  before our words go in), and whether its alerts, tutorials and the Blizzard tooltip option are covered
  (they are not walked now).
- Bagnon's real frames: the harness runs Bagnon's real locale files, but on stand-in windows and pages. Its
  item slots, Sushi pop-ups, right-click menus and the game's Settings list are not drawn there.
- Mastercraft's real windows: whether every text fits its place (side tabs, capital-letter headings, fitted
  buttons), whether the fishing helper, trade board and pop-ups are all reached, the chat lines, and the
  lines with item, zone and NPC names (which depend on UALL Forever) are only seen in the real client.
- What's Training?'s real windows: whether every text fits its fixed boxes, that spell names stay English,
  and whether "•" and "—" draw in the Cyrillic font are only seen in the real client.

## Without the game

`python3 -m unittest discover -s tools` checks the repo, the tools and the Lua syntax.
`python3 tools/harness/run.py` loads the real Questie, QuestieDB and UALL Forever on a fake game and checks
the whole flow. It also fills a fake quest log with real quests and lets Questie's real tracker draw it. It
checks that Questie hands the tracker to UALL Forever in its exact English (with UADD on, off and after
`/reload`), that UALL Forever then translates it, and that old UADD tracker fonts come back as they were.
Then it loads the real Dungeon Journal with UALL Forever and checks the journal module: the language
menu, names on each page change (boss, tab, dungeon, search result), fonts, Shift, Русский and
`/uadd dj off`/`on`. It prints how many dungeon, boss, quest and item names are Ukrainian.
`python3 tools/coverage.py` shows how much of Questie's text is translated.
