# UADD - Ukrainian for Addons

UADD puts other World of Warcraft addons into Ukrainian. It is made for WoW Forever only.

**Your game must be in English (enUS or enGB).** On other languages UADD stays off.

## What it translates

- Dungeon Journal
- OpenMap
- Dialogue UI
- ForeverXP Bar
- Auctionator
- Attune
- LayerSwap
- Questie: its menus and settings. The quest tracker and quest texts come from
  [UALL Forever](https://www.curseforge.com/wow/addons/uall-forever-ukrainian-localization).

Quest, NPC, item and zone names come from UALL Forever while you play. It is optional: without it, the names
stay English and the menus are still Ukrainian.

Hold Shift to see English. Let go, and it is Ukrainian again.

## Install

Each module needs its addon. UALL Forever is optional.

Copy the `UADD`, `UADD_Questie`, `UADD_DungeonJournal`, `UADD_OpenMap`, `UADD_DialogueUI`, `UADD_ForeverXPBar`,
`UADD_Auctionator`, `UADD_Attune` and `UADD_LayerSwap` folders into `World of Warcraft\_forever_\Interface\AddOns\`, or run `install.bat`. Start the game. A module whose addon
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
  ForeverXP Bar, Dungeon Journal and LayerSwap (no licence, so all rights are reserved).
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
