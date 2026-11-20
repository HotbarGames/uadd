# Testing in the game: the other addons

Steps 42 and on of `docs/TESTING.md`: one part per addon. Install and turn on Lua errors as that file says.

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

### RareScanner

These need RareScanner on an English client. Type `/uadd missed on` first, then `/reload`.
107. Log in. `/uadd` lists "RareScanner". `/uadd rarescanner` shows "увімкнено" with the text counts.
108. Open RareScanner's settings (the game's settings list, every page): page names, rows, tooltips and
    dropdowns are Ukrainian, with no boxes, and each text fits. Page names may need a `/reload`.
109. Open the world map: RareScanner's map button menu, its search box and the pin tooltips (point at a rare
    and a treasure). Ukrainian, no boxes, the tooltips are wide enough.
110. Open the explorer (`/rs explorer` or the map menu): the list, the filters, the loot and the custom items.
111. Find a rare (or wait for one): the scanner button, its title and the chat line. In a fight too: no Lua
    errors and the button's words keep their font.
112. Open the export window and add a custom NPC in the settings: their texts are Ukrainian.
113. Hold Shift with a tooltip open: English; let go: Ukrainian.
114. `/uadd rarescanner off`: English again (page names after `/reload`); `on`: Ukrainian. The default custom
    group names are English both ways.
115. Log in without RareScanner: the game does not load UADD - RareScanner, `/uadd` does not list it, no errors.

### Pawn

These need Pawn on an English client. Type `/uadd missed on` first, then `/reload`. Scale names and spec names
stay English on purpose.
116. Log in. `/uadd` lists "Pawn". `/uadd pawn` shows "увімкнено" with the text counts.
117. Open the Pawn window (`/pawn`, or its key binding) and click each tab: Scale, Weights, Compare, Options,
    Help (Getting started), About. Headers, labels, buttons and tooltips are Ukrainian, with no boxes, and each
    text fits its box. Open the Gems tab too if your client shows it.
118. Open the game's Settings, AddOns, "Pawn": the page rows and tooltips are Ukrainian.
119. Point at an item: the scale lines Pawn adds to the tooltip (value, upgrade lines) are Ukrainian; the
    numbers line up and the scale name stays as it is. Do the same on an item you could wear in place of yours.
120. Loot a gear item, open a bag with an upgrade, and look at a quest reward: the upgrade advisors (arrow,
    header, lines) are Ukrainian.
121. Type `/pawn` with no word, and with a wrong word, in chat: the usage lines are Ukrainian; the commands
    and scale names inside stay as they are.
122. In the Scale tab open the dialogs to copy, rename, delete, import and export a scale: their prompts are
    Ukrainian; the scale name you type stays as you typed it, and the export string stays as it is.
123. Hold Shift with the window and a tooltip open: English; let go: Ukrainian.
124. `/uadd pawn off` with the window open: English at once, also the tab names and header; `on`: Ukrainian again.
    Scales and their values stay the same both ways.
125. Log in without Pawn: the game does not load UADD - Pawn (Pawn is a required
    dependency), `/uadd` does not list it, no errors.

### GatherMate2

These need GatherMate2 on an English client. Type `/uadd missed on` first, then `/reload`. Herb, ore, fish,
zone and profession names stay as the game gives them, on purpose: GatherMate2 matches them to save a node.
126. Log in. `/uadd` lists "GatherMate2". `/uadd gathermate2` shows "увімкнено" with the text counts. If it says
    it waits for GatherMate2, GatherMate2 did not load on this client: note that and stop here.
127. Open the game's Settings, AddOns, "GatherMate 2" and each page under it (Minimap, Filters, Maintenance,
    Import, Profiles, FAQ): the page names, rows, buttons and tooltips are Ukrainian, with no boxes, and each
    text fits. The list of herb and ore names stays English. Point at a key binding row: its hint is Ukrainian.
128. Gather an herb or a vein: GatherMate2 still saves it (a new pin on the map). Its chat lines, if any, are
    Ukrainian.
129. Point at the GatherMate2 launcher (minimap or a data broker bar): its tooltip is Ukrainian.
130. Right-click a pin on the map: the menu line with the node name stays all English; the other lines are
    Ukrainian.
131. Hold Shift with the settings open: English; let go: Ukrainian.
132. `/uadd gathermate2 off` with the settings open: English again (page names after `/reload`); `on`:
    Ukrainian. Saved nodes stay the same both ways.
133. Log in without GatherMate2: `/uadd gathermate2` says it waits for GatherMate2, and there are no errors.

### Scrap

These need Scrap on an English client. Type `/uadd missed on` first, then `/reload`. Item names stay as the
game gives them, and chat lines with an item link stay English, on purpose.
134. Log in. `/uadd` lists "Scrap". `/uadd scrap` shows "увімкнено" with the text counts.
135. Open the game's Settings, AddOns, Scrap and each page under it (the main page, the junk list page, Help,
    Patrons): titles, rows, sliders, buttons and tooltips are Ukrainian, with no boxes, and each text fits.
    Patron names stay as they are. Note if any page name or title shows «Брухт» (UALL Forever's word).
136. Visit a vendor. Point at Scrap's button on the vendor window: its tooltip is Ukrainian. Sell junk with
    it: the chat line with the money is Ukrainian. Repair (if on): that chat line is Ukrainian too.
137. Open Scrap's tab on the vendor window (the junk list): both tabs and the buttons under the list are
    Ukrainian and fit. Mark an item as junk and back: the item names stay as the game gives them.
138. Open the game's Key Bindings, the Scrap part: the four names are Ukrainian, with letters, not boxes.
139. If the Scrap tutorial shows (Help, the tutorial button): each step is Ukrainian.
140. Hold Shift with the settings open: English; let go: Ukrainian.
141. `/uadd scrap off` with the settings open: English again (page names after `/reload`); `on`: Ukrainian.
    The junk list stays the same both ways.
142. Log in without Scrap: `/uadd scrap` says it waits for Scrap, and there are no errors.
