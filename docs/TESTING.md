# Testing in the game

What to check before a release, on WoW Forever with Questie installed. UALL Forever is optional: test
once with it and once without it.

## Install

Close the game, then run `install.bat` (or copy `UADD`, `UADD_Questie` and `UADD_DungeonJournal` into
`World of Warcraft\_forever_\Interface\AddOns\`). The journal checks need Dungeon Journal installed. Turn on Lua errors: `/console scriptErrors 1`, or use BugSack.

## Checks

1. Log in. `/uadd` lists the modules "Questie" and "Dungeon Journal" with their status.
2. `/uadd questie` shows the status line and the commands.
3. Questie's options (`/questie`), the minimap button tooltip, the tracker headers and the quest tooltips are in
   Ukrainian. Questie's language setting shows «Українська».
4. With UALL Forever: the chat says names are being collected. Wait for the message that the names are ready
   and shown. Do not `/reload`. The map pins vanish for a moment and come back. Now quest, NPC, item and zone
   names on Questie's map pins and in its tooltips are Ukrainian where UALL Forever has them. The rest stays
   English. Check a quest you already have in your quest log: its map pins and tooltip are Ukrainian too.
   Only the continent list in "My Journey" stays English until the next login.
   Questie's tracker (the quest list on the screen) after the names are ready: quest titles and zone headers
   are Ukrainian, with Questie's level in front and its colours. In lines like "0/8 Witchwing Talon" or
   "Witchwing Talon: 0/8", the item or NPC name is Ukrainian when UALL Forever has it. Lines with a task in
   words, like "Find Mankrik's Wife", stay English. No line shows English first and then changes.
   Check a quest that is done ("(Complete)"), a "... slain" line, and a zone you folded up.
5. Without UALL Forever: the menus are still Ukrainian, the names stay English, and there are no errors.
6. The tracker uses a font with Cyrillic letters by itself (a font you picked there stays).
   `/uadd questie font off` brings back the old font; `/uadd questie font` switches all four.
7. `/uadd questie off`: the tracker is English at once. Then `/reload`: Questie is fully English. `/uadd questie on`, then `/reload`: Ukrainian
   again. A second login uses the saved names and does not collect them again.
8. `/uadd questie rebuild` collects the names again in the background. `/uadd questie test` checks the link to
   UALL Forever.
9. Fight while names are being collected: no stutter, and collection pauses until the fight ends. If the
   collection ends during a fight, the "ready" message and the new names come only after the fight.
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
    words change after the fight.
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
53. Type `/uadd auctionator off` in a fight: no Lua errors, no blocked action. The words change after the fight.
54. Log in without Auctionator: `/uadd auctionator` says it waits for Auctionator, and there are no errors.

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
65. Type `/uadd attune off` in a fight: no Lua errors, no blocked action. The words change after the fight.
66. Log in without Attune: `/uadd attune` says it waits for Attune, and there are no errors. Log in without
    UALL Forever: Attune's own words are Ukrainian, the names stay English.

## Not checked outside the game

- Whether `Fonts\FRIZQT___CYR.TTF` exists in the Forever client (the addon falls back to `Fonts\ARIALN.TTF`).
- How many names UALL Forever has, and how long the first collection takes.
- Whether every Questie window shows the translated names.
- Whether the names show at once after the first collection in every Questie window, with no `/reload`:
  map pins, tooltips, "My Journey", quest details. The test harness checks Questie's quest, NPC and item
  data and the tracker, not what the map and tooltips draw.
- How long the map pins are gone while Questie puts the new names in, with a full quest log.
- How big the saved name cache gets in `WTF\Account\<ACCOUNT>\SavedVariables\UADD.lua`.
- Whether the tracker redraws with the new font right away.
- The game's own wording of objective lines in Forever, and how "(Complete)" looks at the end of them.
- The tracker with Questie options we did not try: quest IDs shown, sorting not by zone, folded zones.
- Whether the tracker feels as fast as before with many quests.
- Questie's options tabs as the game draws them: since Questie 12.8 a tab scrolls in the game's scroll box
  and its dropdowns use the game's menu. The harness builds the real tabs, but on simple stand-ins for
  those game parts. A Questie error printed in chat (`[ERROR]`) counts as a Lua error in the checks.
- OpenMap's real frames: the harness checks UADD_OpenMap on a small stand-in shaped like OpenMap's dungeon
  map, not on OpenMap itself. Its tooltips are checked on stand-in windows too, not on OpenMap's own.
- Dialogue UI's real frames: whether every text fits after it turns Ukrainian (Dialogue UI may size a frame
  before our words go in), and whether its alerts, tutorials and the Blizzard tooltip option are covered
  (they are not walked now).

## Without the game

`python3 -m unittest discover -s tools` checks the repo, the tools and the Lua syntax.
`python3 tools/harness/run.py` loads the real Questie, QuestieDB and UALL Forever on a fake game and checks
the whole flow. It also fills a fake quest log with real quests and lets Questie's real tracker draw it. It
checks that titles, zone headers and known names are Ukrainian, that other lines are left as they were, that
a reused line gets fresh text, and that `/uadd questie off` gives back the exact English.
Then it loads the real Dungeon Journal with UALL Forever and checks the journal module: the language
menu, names on each page change (boss, tab, dungeon, search result), fonts, Shift, Русский and
`/uadd dj off`/`on`. It prints how many dungeon, boss, quest and item names are Ukrainian.
`python3 tools/coverage.py` shows how much of Questie's text is translated.
