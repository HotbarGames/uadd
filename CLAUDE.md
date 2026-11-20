# UADD

## Lessons (read first)

@docs/LESSONS.md
@docs/LESSONS2.md

When a new kind of problem is found, add a lesson there and a check in the same commit as the fix.

## Translation skills

They live outside this repo, in the workspace folder above it (`../.claude/skills/`): a private GitHub repo, HotbarGames/hotbar-claude.

- `update-translations`: after the addons update, or after a test with `/uadd missed on`.
  It runs `tools/drift.py` and `tools/missed.py` first; when both are empty it stops at once.
- `translate-addon`: a new addon, from `docs/LESSONS.md` "Before a new addon" to the
  owner's test.
- `translations-review`: about every 5 runs (`python3 tools/ledger.py summary` says when).
  Each run adds a row with `python3 tools/ledger.py add` (`../.claude/ledger.tsv`, in the private skills repo).

## Other addons' texts

**Rule.** Never commit another addon's text or code in bulk unless its licence allows it.

- Not allowed (all rights reserved): Auctionator (LICENSE: All Rights Reserved), Bagnon and BagBrother
  (TOC: All Rights Reserved; Bagnon's texts are in BagBrother), Mastercraft and Mastercraft_Inbox
  (LICENSE.txt: all rights reserved), Attune, DialogueUI,
  ForeverXPbar, ForeverDungeonJournal, LayerSwap, AutoPotion (no licence file), TomTom and RareScanner (TOC:
  All Rights Reserved), Pawn (CC BY-NC-ND 3.0: no derivatives), GatherMate2 (TOC: ARR, while its
  LICENSE.txt says GPL-2.0; treated as ARR until the owner settles it), Scrap (TOC: All Rights Reserved),
  Speedy AutoLoot and Waypoint UI (no licence file).
- Allowed: Questie (GPL-3.0), OpenMap (MIT; its notice must go with copies), What's Training? (MIT; its
  notice must go with copies). See `THIRD-PARTY-NOTICES.md`.

For the not-allowed ones:

- Our data keeps only our Ukrainian, keyed by the addon's own locale key or by a hash of the English.
- Read the English from the installed addon at build or test time. Never commit it; write files made from it
  to a git-ignored place (add the path to `.gitignore`).
- No English of theirs in comments.
- `tools/harness/` stand-ins may use a few short real labels (the check allows 10 per file), not bulk.

**Why.** This repo is public. A bulk copy of an all-rights-reserved addon breaks its authors' rights, and
CurseForge can pull the whole project for it.

**How to check.** `python3 tools/check_repo.py` (the pre-push hook runs it). Lines that start with `[copy]`
are this rule. It reads the installed addons (their `.lua` and `.xml`) from the WoW `_forever_` AddOns
folder, or from `$UADD_ADDONS_DIR`; one that is not installed is a note, not a problem. It checks tracked
files and untracked ones git does not ignore. It counts their sentences (any file outside `tools/harness/`:
none; one harness file: 10; all harness files together: 20) and their short labels ("Buy Now"), which fail
only in bulk (a limit per addon, per file). The scan is cached in `tools/.cache/` (git-ignored) until a file
it reads changes; delete it to force a fresh scan. Thresholds: `tools/copy_check.py`; what counts as a
sentence or a label, and the scan itself: `tools/copy_scan.py`.

## No half translations

**Rule.** A line is all Ukrainian or all English, never a mix. A template ("Level %s") may fill a slot only
with a value (a number, a time, money, a link), a name we translate, or a slot marked free (one that holds a
name as it is: a player, an addon, a version). If any slot holds other English, the whole line stays English.
Text the player wrote (a pin's note, chat) is never changed, on or off: only our words around it.

**Why.** A half line ("Рівень card theme") looks broken and is harder to read than plain English. It also
hides a missing translation, so nobody adds it.

**How to check.** `python3 tools/harness/run.py` runs the check (`tools/harness/halves.py`). For each module
it takes every real template, puts made-up English ("wobbly gizmo") in each slot, and sends the text through
the module's own translate code (`tools/harness/halves_mods.py`, one function per module). Any output that is
not the input but still has the made-up English fails, and so does a path that takes over 5 ms on one long or
tricky text (`halves.hard`: many short Cyrillic words, a 160-byte note, many separators). Each template must also fit: with its real sample
values the output must differ from the input. A template that stays English goes in `UNFIT` in
`tools/halves_cover.py` with a reason (a real gap: no Ukrainian for it); an `UNFIT` entry that fits now, or
whose template is gone, fails too. Feed texts the way the addon really builds them (OpenMap: its English
around L's words, which are ours). `run.py` fails a module in `COVERED` whose flow gave no result.
`python3 -m unittest tools.test_halves` makes sure no module is missed: each `UADD_*` folder is in
`COVERED` or `NO_SLOTS` (with a reason), its flow really calls its function (not in a comment), and each
free-slot mark points to a real `%s` slot. Free slots are marked here, by English or locale key:

- ForeverXPBar: `FREE` and `BLANK` in `tools/fxpb_words.py`.
- LayerSwap: `FREE` and `BLANK` in `tools/lsw_words.py`.
- AutoPotion: `FREE` and `GLUED` in `tools/make_ap_text.py`.
- Bagnon: `FREE` in `tools/make_bgn_text.py` (`VALUE`: slots that hold only a number or money).
- DialogueUI: `SLOTS` in `UADD_DialogueUI/Slots.lua` (what each `%s` holds).
- Auctionator: `FREE` in `UADD_Auctionator/Words.lua`; code texts: `SLOTS` in `tools/make_auc_text.py`.
- Attune: `KIND`, `BYKEY` and `FREE` in `UADD_Attune/Pairs.lua`.
- OpenMap: `Lc.FREE` in `UADD_OpenMap/Locale.lua`.
- Questie: none (UALL Forever translates its tracker; UADD_Questie is in `NO_SLOTS`).
- What's Training?: none free; what each slot holds (value, game name, our text) is in `tools/wt_rules.py`.
- TomTom: `SORTS` in `tools/tt_rules.py` (`f`: a waypoint title, a profile or page name, a sender).
- RareScanner: `SORTS` in `tools/rs_rules.py` (`v` value, `f` free name, `n` game name, `t` our text, `u` a
  duration with English units: the line stays English).
- Pawn: `SORTS` in `tools/pawn_rules.py` (`v` value, `f` free name: a scale, player or realm name, `n` game
  name, `t` our text: the line stays English when a slot holds an `n`).
- GatherMate2: `SORTS` in `tools/gm_rules.py` (same marks as Pawn; `f`: an addon's folder name kept as it is;
  the pin menu's node name is `n`, so that line stays English).
- Scrap: `SORTS` in `tools/scrap_rules.py` (only `v`: money in the sold and repaired lines; lines with an item
  link stay English).
- Speedy AutoLoot: `SORTS` in `tools/sal_rules.py` (only `v`: the sound's number).

A new module that fills slots gets a function in `halves_mods.py` and a line in `COVERED`. Mark a slot free
only when the game or the addon puts a name there that has no translation; never one that holds only a
colour code, a number or a clock. In modules that find whole lines on screen (ForeverXPBar, LayerSwap,
AutoPotion: `glue=True`), a free slot at a template's start or end is also fed a name glued to made-up English ("   ",
a line break, " - "), as when the addon glues two texts (`docs/LESSONS.md`, lesson 7).
