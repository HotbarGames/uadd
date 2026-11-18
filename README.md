# UADD - Ukrainian for Addons

UADD puts other World of Warcraft addons into Ukrainian. It is made for WoW Forever only.

There are seven modules: one for **Questie**, one for **Dungeon Journal**, one for **OpenMap**, one
for **Dialogue UI**, one for **ForeverXP Bar**, one for **Auctionator** and one for **Attune**.

## What you get

- Questie's interface in Ukrainian: menus, settings, tooltips, My Journey and so on. We wrote this translation
  ourselves. The main Questie translation (the tracker on screen, and quest titles and texts) comes from
  UALL Forever.
- Quest, NPC, item and zone names in Questie's map pins, tooltips and windows in Ukrainian, taken from
  [UALL Forever](https://www.curseforge.com/wow/addons/uall-forever-ukrainian-localization) while you play.
  If UALL Forever has no translation for a name, the English name stays. Without UALL Forever, all names stay
  English and the menus are still Ukrainian.
- Dungeon Journal in Ukrainian: its menus, and dungeon, boss, quest and item names from UALL Forever.
  Quest objectives, notes and warnings are Ukrainian too. «Українська» is picked in the journal's language menu
  by itself.
  Hold Shift to see the journal in English for as long as you hold the key.
- OpenMap in Ukrainian: the map's menu, map pins and notes, its options, the News window and its page in the
  game's Settings. Its dungeon map on the World Map has no boxes: its texts get a font with Cyrillic letters,
  so Ukrainian quest titles from Questie read. Its labels are Ukrainian, and dungeon and boss names come from the
  names the other modules saved (English where none is saved). Hold Shift to see its words in English.
- Dialogue UI in Ukrainian: its buttons, quest type labels, hints, settings window, tooltips, book window and
  its chat lines. Quest text, quest titles and NPC names stay as they are: the Dialogue UI - UALL addon
  translates those, and UADD leaves its texts alone. Item names, reward counts and item levels stay as the game
  shows them. Ukrainian letters get a font that has them. Hold Shift to see the words in English. This
  works only on an English game client: on other clients Dialogue UI has its own translation.
- ForeverXP Bar in Ukrainian: the XP bar texts, its tooltips, the options and settings windows, the record,
  level-up and race windows, and its chat lines. Numbers, player names and what it sends to other players stay
  as they are. Ukrainian letters get a font that has them. Hold Shift to see the words in English;
  `/uadd fxpb off` gives ForeverXP Bar back as it was. This works only on an English game client.
- Auctionator in Ukrainian: its auction house tabs, the buy and sell panels, its dialogs, its settings pages,
  the price lines in item tooltips and its chat lines. Item names, prices, shopping list names and what you type
  stay as they are. Ukrainian letters get a font that has them. Hold Shift to see the words in English;
  `/uadd auctionator off` gives Auctionator back as it was. This works only on an English game client.
- Attune in Ukrainian: its window, the step boxes and the tree, the Next window, its settings pages, its
  tooltips, dialogs and chat lines, and its step notes. Quest, NPC, item and zone names come from UALL Forever
  (English where it has none). Quest objectives, the Survey Log, the export string, what it sends to other
  players and its guild messages stay English. Ukrainian letters get a font that has them. Hold Shift to see
  the words in English; `/uadd attune off` gives Attune back as it was. This works only on an English game client.

## Install

You need Questie for the Questie module, Dungeon Journal for the journal module and OpenMap for the
OpenMap module, Dialogue UI for the Dialogue UI module, ForeverXP Bar for the ForeverXP Bar module,
Auctionator for the Auctionator module and Attune for the Attune module. UALL Forever is optional.

Copy the `UADD`, `UADD_Questie`, `UADD_DungeonJournal`, `UADD_OpenMap`, `UADD_DialogueUI`, `UADD_ForeverXPBar`,
`UADD_Auctionator` and `UADD_Attune` folders into `World of Warcraft\_forever_\Interface\AddOns\`, or run `install.bat`. Start the game. A module whose addon
is not installed stays off.

The first time, UADD collects the names from UALL Forever in the background. When the chat says the names
are ready, Questie shows them right away. You do not need `/reload`. UADD waits for a fight to end first.
While Questie puts the names in, its map pins vanish for a moment and come back.

One thing stays English until your next login: the list of continents in Questie's "My Journey" window.
Questie builds that list only once, when it starts.

## Commands

| Command | What it does |
| --- | --- |
| `/uadd` | Lists the modules and their status. |
| `/uadd questie` | Shows the status and the commands. |
| `/uadd questie on` / `off` | Turns the Questie translation on or off. Then type `/reload`. |
| `/uadd questie rebuild` | Collects the names from UALL Forever again. |
| `/uadd questie test` | Checks the link to UALL Forever. |
| `/uadd dj` | Shows the journal module's status and commands. |
| `/uadd dj on` / `off` | Turns the journal translation on or off, at once. Off gives the journal back as it is without UADD. |
| `/uadd dj rebuild` | Collects the journal's names from UALL Forever again. |
| `/uadd openmap` | Shows the OpenMap module's status and commands. |
| `/uadd openmap on` / `off` | Turns the OpenMap translation on or off, at once. Off gives the map back as it is without UADD. |
| `/uadd dialogueui` | Shows the Dialogue UI module's status and commands. |
| `/uadd dialogueui on` / `off` | Turns the Dialogue UI translation on or off, at once. Off gives Dialogue UI back as it is without UADD (after the fight, if you are in one). |
| `/uadd auctionator` | Shows the Auctionator module's status and commands. |
| `/uadd auctionator on` / `off` | Turns the Auctionator translation on or off, at once. Off gives Auctionator back as it is without UADD (after the fight, if you are in one). |
| `/uadd attune` | Shows the Attune module's status and commands. |
| `/uadd attune on` / `off` | Turns the Attune translation on or off, at once. Off gives Attune back as it is without UADD (after the fight, if you are in one). |
| `/uadd attune rebuild` | Collects Attune's names from UALL Forever again. |
| `/uadd combat off` / `on` | Off: the hold key (Shift) works in a fight too. On (the default): in a fight it does nothing. |

If Questie shows a different language, open Questie's options and pick «Українська».

## Rules for contributors

Do not copy another addon's text or code into this repo in bulk, unless its licence allows it.

- **Not allowed** (all rights reserved): Auctionator (its LICENSE says so), and Attune, Dialogue UI,
  ForeverXP Bar and Dungeon Journal (no licence, so all rights are reserved).
- **Allowed**: Questie (GPL-3.0) and OpenMap (MIT). Their notices are in `THIRD-PARTY-NOTICES.md`.

So for the addons that are not allowed:

- Our files hold only our Ukrainian. Each line is found by the addon's own locale key, or by a hash of the
  English line.
- The English is read from the installed addon when we build or test. It is never committed. Files made
  from it go in a git-ignored place.
- No English lines of theirs in comments either.
- Test stand-ins (`tools/harness/`) may use a few short real labels, not whole lists.

`python3 tools/check_repo.py` checks this (the lines that start with `[copy]`). It reads the addons
installed in WoW; set `UADD_ADDONS_DIR` to use another AddOns folder. An addon that is not installed is
skipped with a note.

## License

GPL-3.0. See `LICENSE`. Notices for code we use from other addons: `THIRD-PARTY-NOTICES.md`.
