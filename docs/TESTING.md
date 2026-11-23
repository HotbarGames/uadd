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
23. The menu's "What's new" entry is Ukrainian («Що нового»). Open it: the News window and its Credits
    page stay OpenMap's English (we never translate a What's New window), the title in its MORPHEUS look,
    no boxes. OpenMap's chat line about an update stays English too.
24. With the menu and the options window open, hold Shift: both turn English. Let go: Ukrainian. News stays
    English all the time. Hold Shift in a fight: nothing changes until the fight ends, then English while you
    still hold it.
25. `/uadd openmap off` with them open: English at once; News stays English, in MORPHEUS. `on`: Ukrainian.
26. Point at buttons and tabs on OpenMap's menu, the dungeon map's side tabs and map pins: the tooltips are
    Ukrainian, no boxes. Then point at an item in your bags: its tooltip looks as without UADD.
27. In OpenMap's options window open a dropdown list: its items are Ukrainian, no boxes. Close the list: the
    chosen value shows with no boxes. Do the same in Questie's options window. Then switch tabs, close the
    window and open another addon's options: its fonts look as without UADD.
28. On the dungeon map, hold Shift: the side tab tooltip says "Dungeon", the menu header "Dungeons" (both
    «Підземелля» in Ukrainian). `/uadd openmap off`: tooltips and the options window are all English in
    their own fonts (the News window stays English on and off), also windows you open for the first time after "off".

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

### The show-original key (UALL Forever, ClassicUA, both)

- First login with this version: a few seconds after login the chat names the key once. Log in again: no
  line. Turn ClassicUA on (or off) and log in: the line comes once more. `/uadd` always shows it.
- Only ClassicUA, its key set to Alt in `/ua`: hold Alt in a UADD window (the Dungeon Journal): English;
  Shift does nothing. Both addons with different keys: UADD follows UALL Forever's key.

### The other addons

Auctionator, Attune, Auto Potion, Bagnon, Mastercraft, What's Training?, TomTom, RareScanner, Pawn, GatherMate2, Scrap, Speedy
AutoLoot (steps 42-148): `docs/TESTING-ADDONS.md`. Waypoint UI, Forever Quest Pins, LiteMount and the popups of
all modules (steps 149 and on): `docs/TESTING-ADDONS2.md`.

### DeleteCheapestItem Reloaded

Type `/uadd missed on` first. Log in: `/uadd` lists "DeleteCheapestItem Reloaded". Open its window (the minimap
button), its ignored-items window, its settings page (Options > AddOns) with the profile dropdowns and a profile
question; hover the minimap button, the info circle and the Sell / Delete button: every text is Ukrainian, with
letters, not boxes, and it fits. Item names come from the game as they are; profile names stay as the player typed
them. `/uadd missed` shows what stayed English. `/uadd dci off`: English; `on`: Ukrainian.

### Wowhead Quick Link

Type `/uadd missed on` first. Log in: `/uadd` lists "Wowhead Quick Link". Hover an item, a spell or a quest and press
its key (Ctrl+C by default): the link window's header and its Close button are Ukrainian, with letters, not boxes, and
they fit; the link stays as it is. Type `/wql`: its settings window's title and labels are Ukrainian. Open Esc > Key
Bindings: its two key names are Ukrainian. Hold the show-original key with the link window open: English. `/uadd
missed` shows what stayed English. `/uadd wql off`: English; `on`: Ukrainian.

### BugSack

Type `/uadd missed on` first. Log in: `/uadd` lists "BugSack". Make a Lua error (for example `/run error("test")`)
and open the sack window: its tabs, the Next, Previous, Send and Wipe buttons, the Filter label and the
session line at the top are Ukrainian, with letters, not boxes, and they fit. Open its options page (Esc > Options >
AddOns, or its minimap button) and hover each option: the tooltips are Ukrainian. Press Send: the send popup is
Ukrainian. Hover the minimap or LDB button: the tooltip is Ukrainian. Its chat lines (a new error, a wiped sack) are
Ukrainian. The Lua error text itself stays as the game gave it. The Font size menu rows stay English (a game menu).
Hold the show-original key with the window open: English. `/uadd missed` shows what stayed English. `/uadd bugsack off`:
English; `on`: Ukrainian.

### Road to Sixty

Type `/uadd missed on` first. Log in: `/uadd` lists "Road to Sixty". Open its journey map and its panel: the tabs,
buttons, labels and tips are Ukrainian, with letters, not boxes, and they fit. Open its settings (Esc > Options >
AddOns, or its minimap button): the section titles, options and tooltips are Ukrainian. Open its stats page:
Ukrainian. Open its What's New window: it stays English (we never translate its news). Its chat lines are Ukrainian. Zone, quest, item and player names stay as the
game gives them (UALL Forever or ClassicUA names them), and so do the lines it saved about your journey. Hold the
show-original key with a window open: English. `/uadd missed` shows what stayed English. `/uadd rts off`: English;
`on`: Ukrainian.

### OneForAll

Needs OneForAll's own language set to English (its Settings > General). Type `/uadd missed on` first. Log in:
`/uadd` lists "OneForAll". Open its main window and go through every tab (dungeons, quests, loot, professions,
talents, hunter pets, and the rest): tabs, buttons, labels, tips and descriptions are Ukrainian, with letters, not
boxes, and they fit. Open its Settings, the info bar, the minimap button and its menu, the world map button and menu,
and its small windows (Welcome, craft list, trainer spells, skill-up guide, weight editor, quest chain): Ukrainian.
Its "Noteworthy changes" window (`/ofa news`) stays English (we never translate its news); the Settings button that
opens it is Ukrainian. Hover things: tooltips are Ukrainian. Its chat lines and loot feed lines are Ukrainian. Zone, quest, NPC,
item, spell and player names, and your profile names, stay as the game gives them (UALL Forever or ClassicUA names
them). Pick another language in its Settings (German, say), reload: UADD does nothing there. Hold the show-original
key with a window open: English. `/uadd missed` shows what stayed English. `/uadd oneforall off`: English; `on`:
Ukrainian.

### LootTriage

Type `/uadd missed on` first. Log in: `/uadd` lists "LootTriage". Open its settings window and its row in the game's
AddOns settings panel; loot something: the loot window's Delete button, the tooltip lines and the chat messages
are Ukrainian, with letters, not boxes, and they fit. Its two "New" buttons read «Що нового»; the What's New window
they open stays English (we never translate its news). Item and quest names come from
UALL Forever or ClassicUA; one with no name stays English. `/uadd missed` shows what stayed English.
`/uadd lt off`: English; `on`: Ukrainian.

### WhatTheWhisper

Type `/uadd missed on` first. Log in: `/uadd` lists "WhatTheWhisper". Open its window and its settings, each tab
and dialog, the emoji picker tabs and the key binding names (Esc, Key Bindings): every text is Ukrainian, with
letters, not boxes, and it fits. Send or receive a whisper: the weekday stamps in the list are Ukrainian; player
names and saved texts stay as they are. Open the export and the sound list. `/uadd missed` shows what stayed
English. `/uadd wtw off`: English; `on`: Ukrainian.

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
- RareScanner's real windows: the settings page names on real category IDs, the world map menus, the pin
  tooltips (LibQTip) and their widths, the scanner button's fonts in a fight, the export window and the custom
  NPC options are only seen in the real client.
- Pawn's real windows: whether every text fits its tabs and buttons, the Settings page, the tooltip lines
  and their number alignment, the loot, bag and quest upgrade advisors, the scale dialogs, and whether the
  tab names and headers switch back on `/uadd pawn off` are only seen in the real client.
- GatherMate2's real windows: whether it loads on Forever at all (its TOC is for the main game), the
  Settings pages on real category IDs and their fit, the launcher tooltip, the pin menu, and that gathering
  still saves nodes while the module is on are only seen in the real client.
- Scrap's real windows: whether UALL Forever puts its own word on a Scrap tab or title, whether «Корисне» and
  «Мотлох» fit the junk list tabs, the key bindings list font (letters or boxes), the settings list page names
  after a switch, and the tutorial steps are only seen in the real client.
- Speedy AutoLoot's real loot display: the font of the anchor's label and test entries, whether they fit the
  box, and that real loot lines keep the game's item names and money are only seen in the real client.
- Waypoint UI's real windows: the settings and prompt fonts (letters or boxes), whether the Ukrainian fits its
  prompts, and the distance and arrival time shown on a real waypoint are only seen in the real client.
- Forever Quest Pins' real windows: its settings page and World Map filter menu, the setup and breadcrumb notice
  fonts (letters or boxes), whether the Ukrainian fits their boxes, and that the game's quest, NPC and zone names
  stay as the game gives them are only seen in the real client.
- LiteMount's real windows: the names on its Settings pages (the game's initializers, built when its pages
  register), its Mounts filter menu and Falling dropdown on the game's menu, the fonts (letters or boxes), whether
  the Ukrainian fits its tabs and buttons, and that mount names stay as the game gives them are only seen in the
  real client.
- WhatTheWhisper's real windows: the messenger window, settings and dialogs, the emoji picker tabs, the key
  binding list font (letters or boxes), whether the Ukrainian fits, and the weekday stamps in the list are only
  seen in the real client.
- LootTriage's real windows: its settings window, its dropdown menus, its row in the AddOns settings panel, the loot window's Delete
  button, the tooltip lines, the chat messages, the "New" buttons (and that the What's New window they open stays
  English), the fonts (letters or boxes), and whether the Ukrainian fits, are only seen in the real client.
- DeleteCheapestItem Reloaded's real windows: its main window's top lines (money, links, counts), the fixed-width
  Remove and Delete buttons, its settings page on the game's Settings window, the profile question, the minimap
  tooltip, the fonts (letters or boxes), and whether the Ukrainian fits, are only seen in the real client.
- Wowhead Quick Link's real windows: the game's link pop-up with our header and Close button (font and fit in its
  fixed width), the `/wql` settings window's labels, the Key Bindings list (letters or boxes), and that a real
  link stays as the addon builds it, are only seen in the real client.
- BugSack's real windows: the sack window (tabs, buttons, Filter label, session line) with a real error in it, its
  options page and tooltips, the send popup, the minimap tooltip, the fonts (letters or boxes), and whether the
  Ukrainian fits, are only seen in the real client.
- Road to Sixty's real windows: the journey map, the panel and its tabs, the settings page, the What's New window
  (whole English), the stats page, the minimap button's tooltip, the fonts (letters or boxes), whether the Ukrainian fits its fixed
  boxes, and that the chat and the saved journey lines still work, are only seen in the real client.
- OneForAll's real windows: every tab of the main window, the settings, the info bar, the map buttons and menus, the
  small windows, the tooltips, the fonts (letters or boxes), whether the Ukrainian fits its fixed boxes, and that its
  chat lines and loot feed still work, are only seen in the real client.

## Without the game

`python3 -m unittest discover -s tools` checks the repo, the tools and the Lua syntax.
`python3 tools/harness/run.py` loads the real Questie, QuestieDB and UALL Forever on a fake game and checks
the whole flow. It also fills a fake quest log with real quests and lets Questie's real tracker draw it. It
checks that Questie hands the tracker to UALL Forever in its exact English (with UADD on, off and after
`/reload`), that UALL Forever then translates it, and that old UADD tracker fonts come back as they were.
Then it loads the real Dungeon Journal with UALL Forever and checks the journal module: the language
menu, names on each page change (boss, tab, dungeon, search result), fonts, Shift, Русский and
`/uadd dj off`/`on`. It prints how many dungeon, boss, quest and item names are Ukrainian.

How fast it runs (2026-11-22, 8 cores): the whole suite takes about 80 s, `run.py` alone about 40 s.

- `run.py` runs its flows side by side, one process per flow (`tools/harness/pool.py`, `jobs.py`). The checks come
  out in the same order as one after another.
- A flow that fails, dies or runs past its time gives a FAIL line with a repro line. The run then ends with code 1.
- `UADD_JOBS=1` runs every flow in one process, one after another, as before. Use it to look at one failure
  closely. `UADD_JOBS=4` runs 4 at a time.
- `UADD_JOB_TIMEOUT` is the seconds one flow may take (default 900).
- In the suite, `tools/test_harness.py` starts the harness as soon as it is imported, so it runs while the other
  tests run. `UADD_HARNESS_EARLY=0` runs it at its own turn instead.
`python3 tools/coverage.py` shows how much of Questie's text is translated.
