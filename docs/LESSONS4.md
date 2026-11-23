# Lessons, part 4

Lessons 40 and up. The rules for this list and "Before a new addon" are in `docs/LESSONS.md`.

## 40. A saved name cache that froze the words found before ClassicUA answered

**What went wrong.** In the Dungeon Journal's quest list for Razorfen Kraul, two quest titles stayed English, the
others showed UALL Forever's words, not ClassicUA's, and the objective line "0/6 <item>" stayed English (the
owner's shot, 2026-11-22). Three causes:

- While UADD was still looking for ClassicUA's hook (up to 3 tries, 3 s apart), each name got UALL Forever's word
  or a miss. The collector saved them under ClassicUA's signature, so they stayed until the next addon update.
- A cache built on a character with ClassicUA switched off had no ClassicUA part in its signature. That part is
  right, but a collection that ran while ClassicUA came or went saved its words under the old sources.
- Objective lines go through `FDJ.LocalizeObjectives`. With our language on, `CanUseClientLocalizedText` is false,
  so it runs, but it knows only its own name table, which has no Ukrainian.

**Rule.**

- A saved name cache's signature adds `UADD.UALL.ProviderSig()`. A task marked `partial` or `unsaved` is used now,
  never saved.
- The core collector (`UADD/Collector.lua`) asks nothing while ClassicUA is active but not settled
  (`C.Settled()`, from `U.cua.Settled` in `UADD/uall_cua.lua`): that is "not now", asked again a second later.
  A task that ends after the name sources changed (`job.psig`) is marked unsaved.
- The Dungeon Journal collects once more when the signature changed by the end of a collection.
- An objective line ("<item>: 0/6", "0/6 <item>") gets the item's name through `UADD.UALL.Item` (ClassicUA first,
  UALL Forever on a miss), before FDJ reads it (`UADD_DungeonJournal/Whole.lua`). A kill line, or a name with no
  whole Ukrainian, keeps the line as the game gave it. An error of ours gives FDJ the game's own lines.

**Check.** `python3 -m unittest tools.test_name_caches`: every module that saves a name cache signs it with
`ProviderSig` and never saves an unsaved task; the collector waits and marks; the journal collects again. Its
mutants take each fix out. `python3 -m unittest tools.test_dj_objectives`: in a small Lua world, an item with
ClassicUA's word, one only UALL Forever has, an unknown one, both line shapes, a kill line, a lookup that throws and
the module off (FDJ's own function back); its mutants take each fix out. `python3 tools/harness/run.py`, the DJ module's ClassicUA games
(`tools/harness/flow_dj_cua.py`): a cache built without ClassicUA, then ClassicUA on, gives ClassicUA's titles; a
late ClassicUA hook leaves no UALL Forever title saved (mutant `settle` takes the wait out and wants UALL Forever's
titles kept); objective lines whole Ukrainian or whole English. Manual, in the game: the real ClassicUA hook timing,
and the objective lines in the quest list and in FDJ's tracker.

## 41. A push check that grew too slow

**What went wrong.** By 2026-11-22 the push check (the whole suite) took about 9 minutes, close to the hook's
20-minute limit, and each new module made it longer. The harness ran its 40 flows one after another (275 s). The
Lua tokenizer read every file letter by letter (54 s over the suite). `test_popups` tokenized every file of every
addon, though only a few hold a dialog (30 s).

**Rule.**

- Make a check faster only in ways that lose none of it: the same checks, in the same order, each still failing
  on its bug.
- Flows run side by side, one process each (`tools/harness/pool.py`). A flow leaves nothing behind for the next
  one, and its time bounds follow the load (`clock.py`, lesson 22 again in part 3).
- A job that fails, dies or runs too long is a FAIL with a repro line, never a lost check.
- A fast path keeps the old code as its reference (`luatok.slow_tokens`), and a test wants both to give the same
  result.

**Check.** `python3 -m unittest tools.test_pool`: the checks keep their order, and a job that raises, dies or
runs past `UADD_JOB_TIMEOUT` gives a FAIL with a repro line, while the other jobs' checks stay.
`python3 -m unittest tools.test_glossary` (`test_fast_reader_matches_slow`): the fast tokenizer gives exactly the
old reader's tokens on every Lua file of the repo and on 20k odd made-up texts. On 2026-11-22 they also matched on
all 8144 Lua, XML and TOC files of the installed addons and 200k made-up texts. `UADD_JOBS=1` gives the same
check names as the side-by-side run.

## 42. A version record that hid new texts

**What went wrong.** To record OneForAll's version (2026-11-22), `python3 tools/drift.py --update-versions` ran over
every module. Forever Quest Pins, Mastercraft and OpenMap had new versions that day, so their new texts were recorded
too, and drift no longer showed them: the push check found them only by luck (three other tests failed on them).
In the same push, drift could not see a new Forever Quest Pins What's New line at all: its extractor read L keys
only, and the What's New lines are a plain list in `WhatsNew.lua`.

**Rule.**

- `--update-versions` records a module whose texts changed only when our data names each new or changed text, or
  when the module is named with `--module` (its other texts stay English on purpose). Otherwise it leaves that
  module out, says so, and exits 1.
- An extractor reads every place the addon shows a text from, not only its locale table.
- A key in our data is matched as the addon shows it: two OpenMap texts with `\n` and `\\` in their Lua keys
  were held as "not named", though we had them.

**Check.** `python3 -m unittest tools.test_drift`: `test_update_holds_untranslated` (a new text our data does not
name is not recorded, its drift still shows; recorded once named, or with `--module`) and `test_whats_new_lines_read`
(drift_fqp reads the `lines = { ... }` of a made-up WhatsNew.lua), `test_escaped_key_named` (a key with `\n` and
`\\` names its text).

## More cases of older lessons

**Lesson 14 again, in WhatTheWhisper's group chats (2026-11-22).** It names a group thread (each kind of group) with its
locale words and saves the name into its history. Rule: a word it saves and draws nowhere else stays English
(STAY); a word it also draws elsewhere (the guild's) is wrapped where the name is built
(`GroupChat.Label`, `UADD_WhatTheWhisper/Groups.lua`) to give its English back, and old Ukrainian names saved
before are turned back at start. Check: `python3 -m unittest tools.test_wtw_groups` (a small Lua world; its mutants
take each fix out).

**Lesson 15 again, in Forever Quest Pins 1.1.4 (2026-11-22).** Its new quest tracker page glues text in code: a
" (BETA)" tag onto the heading and a checkbox label, and two L sentences joined by a space into the help line. Each
was whole before. The match failed quietly, so on the hold key and off these texts stayed Ukrainian. Rule: after an
addon update, look in its diff for new `..` around L words. `Turn` (`UADD_ForeverQuestPins/Screen.lua`) cuts a
" (BETA)" tail off as it cuts the level range, and swaps two joined sentences only when both are ours, so a line is
never half translated. Check: `python3 tools/harness/flow_fqp.py`, "fqp: 3 hold canvas"; its mutants `beta` and
`join` take each fix out and want that step to fail.

**Lesson 32 again, in BugSack (2026-11-22).** What went wrong: the module saves a label's own font before it puts
UADD's Cyrillic font on, and puts the saved one back on the hold key and off. Its re-apply step (`Refix`, on hover
and on a font object change) cleared that saved font on every run. A hover that ran it twice saved our own Cyrillic
font as the "original", so held and off then put our font back on the English (the Wipe button). The harness found
it. Rule: forget a saved font only when ours is not on the label now (`Fresh` in `UADD_BugSack/Screen.lua`); never
save a font while ours is on. Check: `python3 tools/harness/flow_bs.py --prove`; its mutant `fresh` puts the old
line back and wants step 5 to fail.
The review found one more: the sack's Options tab calls the Wipe button's `SetEnabled`, a native method that runs
no Lua `Enable`, `Disable` or `SetFontObject`, so no hook saw the font change and our words would show as boxes.
Rule: hook every state method a button has, `SetEnabled` too, and make the stand's version native (it uses the raw
`SetFontObject`, with no hover after it). Check: the same `--prove`, mutant `enabled`.

**Lesson 7 again, in Mastercraft 2.1.1 (2026-11-23).** What went wrong: two new texts made free slots swallow
English. A locale key of two slots and glue alone (a gap and a grey colour, 18:9436262a) was sorted free, then
text. No code formats it, but row titles and cooldown chips have its shape (a recipe, then a count in grey), so
the free slot took the recipe as it was: the row title came out the same as it went in, so `P.Count` never ran, and
lines with a longer template's slot missing came out half Ukrainian. A short new template ("<word> %s", 14:9a89c630)
is the start of an older one ("<word> %s: %s"): when the older one's text slot failed, the short one's free slot
took "<name>: <English>". Rule: a free slot says no to ": " too (Words.lua). A template of glue alone gets no free
slot unless the code that builds it puts a name there (`IN_CODE`); 18:9436262a is now n, t (`tools/mc_rules.py`).
Check: `python3 tools/harness/flow_mastercraft.py` (the halves check and the row-title steps);
`python3 -m unittest tools.test_mc_slots` (`test_glue_only_template_has_no_free_slot`).
