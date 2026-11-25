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
- Auto Potion
- Bagnon
- Mastercraft
- What's Training?
- TomTom
- RareScanner
- Pawn
- GatherMate2
- Scrap
- Speedy AutoLoot
- Waypoint UI
- Forever Quest Pins
- LiteMount
- WhatTheWhisper
- LootTriage
- DeleteCheapestItem Reloaded
- Wowhead Quick Link
- BugSack
- Road to Sixty
- OneForAll
- GearQuest Forever
- Questie: its menus and settings. The quest tracker and quest texts come from
  [UALL Forever](https://www.curseforge.com/wow/addons/uall-forever-ukrainian-localization).

Game names (zones, NPCs, items, quests, spells) come from [UALL Forever](https://www.curseforge.com/wow/addons/uall-forever-ukrainian-localization) or [ClassicUA](https://www.curseforge.com/wow/addons/classicua) while you play. Either one works, and so do both together. They are optional: without them, the names
stay English and the menus are still Ukrainian.

Hold a key to see English. Let go, and it is Ukrainian again. With UALL Forever, UADD uses UALL Forever's key
(Shift by default). With only ClassicUA, it uses ClassicUA's tooltip key (Alt by default). The first time you log in,
UADD says in chat which key it is. `/uadd` shows it again.

## Install

Each module needs its addon. UALL Forever and ClassicUA are optional.

Copy the `UADD`, `UADD_Questie`, `UADD_DungeonJournal`, `UADD_OpenMap`, `UADD_DialogueUI`, `UADD_ForeverXPBar`,
`UADD_Auctionator`, `UADD_Attune`, `UADD_LayerSwap`, `UADD_AutoPotion`, `UADD_Bagnon`, `UADD_Mastercraft`, `UADD_WhatsTraining`, `UADD_TomTom`, `UADD_RareScanner`, `UADD_Pawn`, `UADD_GatherMate2`, `UADD_Scrap`, `UADD_SpeedyAutoLoot`,
`UADD_WaypointUI`, `UADD_ForeverQuestPins`, `UADD_LiteMount`, `UADD_WhatTheWhisper`, `UADD_LootTriage`, `UADD_DeleteCheapestItem`, `UADD_WowheadQuickLink`, `UADD_BugSack`, `UADD_RoadToSixty`, `UADD_OneForAll` and `UADD_GearQuestForever` folders into `World of Warcraft\_forever_\Interface\AddOns\`,
or run `install.bat`. Start the game. A module whose addon is not installed stays off.

The first time, UADD collects the names from UALL Forever or ClassicUA in the background. When the chat says the names
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
| `/uadd questie rebuild` | Collects the names from UALL Forever or ClassicUA again. |
| `/uadd questie test` | Checks the link to UALL Forever and ClassicUA. |
| `/uadd dj` | Shows the journal module's status and commands. |
| `/uadd dj on` / `off` | Turns the journal translation on or off, at once. Off gives the journal back as it is without UADD. |
| `/uadd dj rebuild` | Collects the journal's names from UALL Forever or ClassicUA again. |
| `/uadd openmap` | Shows the OpenMap module's status and commands. |
| `/uadd openmap on` / `off` | Turns the OpenMap translation on or off, at once. Off gives the map back as it is without UADD. |
| `/uadd dialogueui` | Shows the Dialogue UI module's status and commands. |
| `/uadd dialogueui on` / `off` | Turns the Dialogue UI translation on or off, at once. Off gives Dialogue UI back as it is without UADD (after the fight, if you are in one). |
| `/uadd auctionator` | Shows the Auctionator module's status and commands. |
| `/uadd auctionator on` / `off` | Turns the Auctionator translation on or off, at once. Off gives Auctionator back as it is without UADD (after the fight, if you are in one). |
| `/uadd attune` | Shows the Attune module's status and commands. |
| `/uadd attune on` / `off` | Turns the Attune translation on or off, at once. Off gives Attune back as it is without UADD (after the fight, if you are in one). |
| `/uadd attune rebuild` | Collects Attune's names from UALL Forever or ClassicUA again. |
| `/uadd autopotion` | Shows the Auto Potion module's status and commands. |
| `/uadd autopotion on` / `off` | Turns the Auto Potion translation on or off, at once. Off gives Auto Potion back as it is without UADD. |
| `/uadd bagnon` | Shows the Bagnon module's status and commands. |
| `/uadd bagnon on` / `off` | Turns the Bagnon translation on or off, at once. Off gives Bagnon back as it is without UADD; the names of its pages in the game's Settings list change back after `/reload`. |
| `/uadd mastercraft` | Shows the Mastercraft module's status and commands. |
| `/uadd mastercraft on` / `off` | Turns the Mastercraft translation on or off, at once. Off gives Mastercraft back as it is without UADD. |
| `/uadd whatstraining` | Shows the What's Training? module's status and commands. |
| `/uadd whatstraining on` / `off` | Turns the What's Training? translation on or off, at once. Off gives What's Training? back as it is without UADD. |
| `/uadd tomtom` | Shows the TomTom module's status and commands. |
| `/uadd tomtom on` / `off` | Turns the TomTom translation on or off, at once. Off gives TomTom back as it is without UADD; its settings pages change back after `/reload`. |
| `/uadd rarescanner` | Shows the RareScanner module's status and commands. |
| `/uadd rarescanner on` / `off` | Turns the RareScanner translation on or off, at once. Off gives RareScanner back as it is without UADD; its settings page names change back after `/reload`. |
| `/uadd pawn` | Shows the Pawn module's status and commands. |
| `/uadd pawn on` / `off` | Turns the Pawn translation on or off, at once. Off gives Pawn back as it is without UADD. Scale names (yours and Pawn's own) stay as they are. |
| `/uadd gathermate2` | Shows the GatherMate2 module's status and commands. |
| `/uadd gathermate2 on` / `off` | Turns the GatherMate2 translation on or off, at once. Off gives GatherMate2 back as it is without UADD; its settings page names change back after `/reload`. Herb, ore and fish names stay as the game gives them. |
| `/uadd scrap` | Shows the Scrap module's status and commands. |
| `/uadd scrap on` / `off` | Turns the Scrap translation on or off, at once. Off gives Scrap back as it is without UADD; its settings page names change back after `/reload`. Item names stay as the game gives them. |
| `/uadd sal` | Shows the Speedy AutoLoot module's status and commands. |
| `/uadd sal on` / `off` | Turns the Speedy AutoLoot translation on or off, at once. Off gives Speedy AutoLoot back as it is without UADD. Item names and money in its loot display stay as the game gives them. |
| `/uadd waypointui` | Shows the Waypoint UI module's status and commands. |
| `/uadd waypointui on` / `off` | Turns the Waypoint UI translation on or off, at once. Off gives Waypoint UI back as it is without UADD. |
| `/uadd foreverquestpins` | Shows the Forever Quest Pins module's status and commands. |
| `/uadd foreverquestpins on` / `off` | Turns the Forever Quest Pins translation on or off, at once. Off gives Forever Quest Pins back as it is without UADD. The skipped-breadcrumb window and the abandoned-quest chat line take their quest and zone names from UALL Forever or ClassicUA; when neither has a name, that line stays in English. |
| `/uadd litemount` | Shows the LiteMount module's status and commands. |
| `/uadd litemount on` / `off` | Turns the LiteMount translation on or off, at once. Off gives LiteMount back as it is without UADD. Mount names and the names you typed (rules, groups, profiles) stay as they are. |
| `/uadd wtw` | Shows the WhatTheWhisper module's status and commands. |
| `/uadd wtw on` / `off` | Turns the WhatTheWhisper translation on or off, at once. Off gives WhatTheWhisper back as it is without UADD. Player names and the texts the addon saves stay as they are. |
| `/uadd lt` | Shows the LootTriage module's status and commands. |
| `/uadd lt on` / `off` | Turns the LootTriage translation on or off, at once. Off gives LootTriage back as it is without UADD. Item and quest names come from UALL Forever or ClassicUA; when neither has a name, that text stays in English. |
| `/uadd dci` | Shows the DeleteCheapestItem Reloaded module's status and commands. |
| `/uadd dci on` / `off` | Turns the DeleteCheapestItem Reloaded translation on or off, at once. Off gives DeleteCheapestItem Reloaded back as it is without UADD. Item names come from UALL Forever or ClassicUA; when neither has a name, that line stays in English. Your profile names stay as you typed them. |
| `/uadd wql` | Shows the Wowhead Quick Link module's status and commands. |
| `/uadd wql on` / `off` | Turns the Wowhead Quick Link translation on or off, at once. Off gives Wowhead Quick Link back as it is without UADD. The links themselves, and the names Armory and Raider.IO, stay as they are. |
| `/uadd bs` | Shows the BugSack module's status and commands. |
| `/uadd bs on` / `off` | Turns the BugSack translation on or off, at once. Off gives BugSack back as it is without UADD. The texts of the Lua errors themselves stay as they are. |
| `/uadd rts` | Shows the Road to Sixty module's status and commands. |
| `/uadd rts on` / `off` | Turns the Road to Sixty translation on or off, at once. Off gives Road to Sixty back as it is without UADD. Names of zones, quests, items and players, and what Road to Sixty saved about your journey, stay as they are. |
| `/uadd oneforall` | Shows the OneForAll module's status and commands. |
| `/uadd oneforall on` / `off` | Turns the OneForAll translation on or off, at once. Off gives OneForAll back as it is without UADD. It works only while OneForAll's own language is English. Names of zones, quests, items, spells and players, and what OneForAll saved, stay as they are. |
| `/uadd gq` | Shows the GearQuest Forever module's status and commands. |
| `/uadd gq on` / `off` | Turns the GearQuest Forever translation on or off, at once. Off gives GearQuest Forever back as it is without UADD. It works while GearQuest Forever's language list says Ukrainian or nothing (auto). Names of zones, quests, items and players stay as the game gives them. |
| `/uadd combat off` / `on` | Off: the hold key works in a fight too. On (the default): in a fight it does nothing. |
| `/uadd missed` | Shows, per module, how many texts stayed English because UADD has no Ukrainian for them yet. |
| `/uadd missed on` / `off` | A tool for testers, off unless you turn it on. On: UADD notes each text it shows in English. Off (the default) costs nothing. The list stays on your PC; nothing is sent. |
| `/uadd missed clear` | Empties the list. `/uadd missed clear fxpb` empties one module's part (the names are in `/uadd missed`). |

If Questie shows a different language, open Questie's options and pick «Українська».

## For contributors: what changed, what stayed English

Two tools tell you what needs work. They need no network.

- `python3 tools/drift.py`: run it after the addons update. It says which addons changed since our data was
  built, and which of their texts are new, gone or changed. "no drift" means there is nothing to do. The texts
  are in `local/drift/`. After you rebuild the data, run `python3 tools/drift.py --update-versions`.
- `python3 tools/missed.py`: type `/uadd missed on` in the game, play, log out, then run it. It lists, per
  module, the texts that stayed English in the game. All of them are in `local/missed/`.

`local/` is git-ignored, because these files hold the addons' English. Never commit them.

## Rules for contributors

Do not copy another addon's text or code into this repo in bulk, unless its licence allows it.

- **Not allowed** (all rights reserved): Auctionator (its LICENSE says so), Bagnon (its TOC says so), Mastercraft (its LICENSE.txt says so), TomTom, RareScanner, Scrap, DeleteCheapestItem Reloaded and BugSack (their TOCs say so), Pawn (CC BY-NC-ND 3.0: no derivatives), GatherMate2 (its TOC says all rights reserved, its LICENSE.txt says GPL; we keep to the stricter one), and Attune, Dialogue UI,
  ForeverXP Bar, Dungeon Journal, LayerSwap, Auto Potion, Speedy AutoLoot, Waypoint UI, WhatTheWhisper, LootTriage, Wowhead Quick Link, Road to Sixty and GearQuest Forever (no licence, so all rights are reserved).
- **Allowed**: Questie (GPL-3.0), Forever Quest Pins (GPL-3.0), LiteMount (GPL-2.0), OneForAll (GPL-3.0-or-later), OpenMap (MIT) and What's Training? (MIT). Their notices are in `THIRD-PARTY-NOTICES.md`.

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
