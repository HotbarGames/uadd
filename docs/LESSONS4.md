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
name is not recorded, its drift still shows; recorded once named, or with `--module`) and `test_escaped_key_named`
(a key with `\n` and `\\` names its text).

**Since 2026-11-23** news texts are the one exception to "read every place": an addon's What's New, News and
changelog stay English (lesson 43), so drift reads none of them. The What's New check is now
`test_whats_new_lines_not_read` (drift_fqp skips the `lines = { ... }` of a made-up WhatsNew.lua, and keeps an L key
there that another file also uses) and `test_news_rows_skipped`.

## 43. News we translated after the players had read it

**What went wrong.** Six modules translated their addon's What's New, News or changelog window: Forever Quest Pins'
login lines and window, OpenMap's News window and Credits page, LootTriage's What's New dialog, OneForAll's
"Noteworthy changes", Road to Sixty's What's New and ForeverXP Bar's changes page. Our update always comes after the
addon's, so players had read the news in English already. Each new news line was also drift work on every update
(lesson 42 was one), and owner minutes in the game, for nothing (the owner, 2026-11-23).

**Rule.**

- Never translate an addon's What's New, News or changelog window, nor a page shown only inside it: it stays the
  addon's own English, on, held and off. Its frame is no root to walk or hook; a skip table may name it to leave it
  alone.
- Extractors, generators and drift leave news out (`tools/news_texts.py`: a news file by its name, `TEXTS` for a
  news text outside one).
- Not news, so still ours: a button or menu entry that only opens the news ("What's new"), a help line that names
  it, and a fixed one-line chat notice that a new version is out or that the addon was updated to X (it tells no
  changes). These go in `KEEP` when the addon keeps them in its news file.

**Check.** `python3 -m unittest tools.test_news`: no shipped module code names a news frame outside a skip table
(it finds the old OpenMap and Road to Sixty roots), no `TEXTS` entry and no Forever Quest Pins What's New line is
in our data, and `is_news` on made-up paths. `python3 -m unittest tools.test_drift` (`test_news_rows_skipped`).
Per module: `tools/test_openmap_strings.py` (`test_news_stays_english`, `test_update_lines_are_ours`),
`tools/test_lt_text.py`, and the flows of Forever Quest Pins, OpenMap, LootTriage, OneForAll, Road to Sixty and
ForeverXP Bar (the news window stays English on, held and off).

## 44. Labels whose font the addon set by hand

**What went wrong.** In OneForAll (the owner's shots, 2026-11-23), the setup wizard's last page had our heading
but English buttons, body and title. In Armory > Gear Planner, the top tabs, the left nav, the buttons, the search
box's "Search all items..." and the level line were English, though our data had every one. Three causes:

- OneForAll sets its buttons' and nav's fonts by hand (SetFont at its own size). Our Cyrillic font object did not
  take over such a label, or none was left: we made one per base object, size and flags, and the shared 64 ran out.
  The walker could not put a Cyrillic font on, so it put the English back, with no error.
- The walker left every text box alone, also the hint text the addon draws in it.
- The page's body ends with the author's signature line ("- Name", in colour). It has Latin letters, so the
  several-lines rule kept the whole body English.

**Rule.**

- A font object of ours is made once per file, size and flags (`CyrObject`, `UADD/Font.lua`).
- When it does not take, the Cyrillic file goes on by hand at the label's own size (`U.CyrOnOwn`); `U.FontBack`
  puts the addon's file back when its object does not. Never on a menu row (lesson 38). Read back (lesson 2).
- A walker with `hints` reaches a text box's hint FontStrings, never the typed text (`U.Walk`, `UADD/Walk.lua`).
- A signature line ("- Name", maybe in one colour) is kept as it is, like a line with no words.
- OneForAll's small-caps titles (one FontString per letter group) and the see-through page are its own; not fixed.

**Check.** `python3 tools/harness/flow_ofa.py --prove`, step 11 (a made-up Gear Planner and end page: labels set by
hand at sizes 11 and 12 that keep their file over any font object, a search hint with typed text, a signed body;
ours on, English and the hand-set font back off); its mutants `hints`, `signed` and `own` (the last cuts
`U.CyrOnOwn` in core `UADD/Font.lua`) each want step 11 to fail. Manual, in the game: the real labels take our font,
the buttons fit the Ukrainian, the typed search text is never changed.

## 45. Boxes that no check looked for

**What went wrong.** The tooltip boxes (lesson 18 again, below) reached the owner (2026-11-23). No check looked at
what was on screen: each check read one font in one step. Four guardrails were built after it, and on their first
run they found more boxes, in core and in 16 modules:

- A font put back while the line still showed our Cyrillic text (core `U.FontBack`, Popups, AceFont, TipLines).
- Off took our font away while built windows kept Ukrainian until /reload (Questie's headers and controls).
- A saved font record dropped while our font was still on, so held and off had nothing to put back (lesson 32 again,
  in many modules).
- A module that never put a Cyrillic font on a line drawn in a game font object (GameFontNormal), also when off.
- OpenMap's first build of a named window set texts before any look of ours (`UADD_OpenMap/Born.lua`).
- The harness itself: a hand-set file dropped on SetFontObject (the client keeps it), and Widgets.lua's hooks given a
  method table no frame used, so a core hook never fired there.

**Rule.** The font follows the text.

- Cyrillic on screen is always in a font with Cyrillic. Once the text is English, its exact old font goes back.
- Never a Latin file pinned by path on a line whose object is a family (game tooltip lines).
- Forget a saved font only once our font is off the line (`U.CyrFix`, `U.CyrUnfix`, `U.SaveFont`, `U.FontBack`).
- A check sets English through the same setter the addon uses.
- A harness client loaded with a cut (a mutant, the probe) sets `H.boxQuiet`, so its wanted boxes stay its own.
- The guard (`UADD/Guard.lua`) repairs a box that still slips through and reports it.

**Check.**

- `python3 tools/harness/run.py`: after every segment of every flow, the box check (`tools/harness/boxes.lua`,
  `boxes.py`) wants no visible Cyrillic text in a font without Cyrillic. Each hit names the line, its font and a
  sample. Mutant `fontback` (`flow_mastercraft.py --prove`) wants it to see a hit.
- `python3 -m unittest tools.test_health_report`: the guard's reports show in `tools/missed.py` and
  `tools/health_report.py`.
- `python3 -m unittest tools.test_client_facts`: the harness facts about fonts
  (`tools/harness/client_facts.py`) match what `UADD/Probe.lua` saw in the real client. Manual, in the game: log in
  once and log out, so the probe can write its facts.
- `python3 -m unittest tools.test_shared_state`: frame walks only through `U.Regions` and `U.Children`.

## 46. Button states that put a Latin font back

**What went wrong.** On hover, on a press or when greyed out, the client itself puts the font object of the
button's state on its label. No Lua hook sees it. We put our font on the label only, so the state's own object
came back and our words showed as boxes: BugSack's tab under the mouse, the Dungeon Journal's mode chooser and back
buttons from the moment the journal set them until our next look (the harness, 2026-11-26, once its button stand-in
switched states as the client does: `tools/harness/wow_button.lua`). Two more gaps came out with it:

- LiteMount, Auto Potion and LayerSwap went on when `U.CyrFix` said false (no Cyrillic font took) on a text that
  already showed Ukrainian. A failed fix is never watched by the box guard (`U.BoxWatch`), so nothing saw it.
- LayerSwap's flow kept its own older state setters, so it did not test the client's switch.

**Rule.**

- Our Cyrillic goes in every state object of a button, not only on its label: `U.ButtonCyr` gives each state our
  copy of its object (its file, size and colour), and `U.ButtonBack` puts the button's own objects back
  (`UADD/ButtonFont.lua`). Whole or nothing: when one state cannot get a copy (the cap of 64), all stay its own.
- The core's state hooks give an object the addon sets later our copy too. A module needs no hooks for it.
- A protected or forbidden button is never touched; its label stays English.
- The width guard (`UADD/BoxGuard.lua`) finds what still slips through and gives up to whole English
  (`U.BoxGiveUp`), never boxes.
- `U.CyrFix` false on a text that shows Ukrainian: the addon's English back first, then its font (lesson 45),
  through the setter the addon uses (`Fixed` in `UADD_LiteMount/Fonts.lua`; `T.English` in Auto Potion's and
  LayerSwap's `Texts.lua`).

**Check.**

- `python3 tools/harness/run.py`: the box check's state rule (`tools/harness/boxes.lua`). A button's label that
  shows Cyrillic, and each of its state objects, must have a Cyrillic file of its own, else a hit ("state
  Highlight"). No flow has to hover for it.
- `python3 tools/harness/flow_button.py --prove`: the core alone (every state, protected buttons, the client's own
  switches, the cap, a state set while the label was empty, `U.BoxGiveUp`); each mutant cuts one fix and wants its
  step to fail.
- `python3 tools/harness/flow_litemount.py --prove`, "litemount: 9 a text no Cyrillic font can take": a secure
  button's label and a name the guard gave up on show whole English; mutant `sgiveup` keeps the Ukrainian.
- Manual, in the game: a real protected button, the real cap, the switch on hover and press, the width guard on
  real fonts.

## 47. A font object put back on itself crashed the game

**What went wrong.** The game died (a stack overflow inside the client's SetFontObject, 2026-11-26) after BugSack
showed our no-bugs line, then an error. An edit box's GetFontObject gives its own nameless font record, not a game
font. `U.SaveFont` saved that record for BugSack's text area and `U.FontBack` put it back on the box: the record now
inherited from itself, and the client looped in its own code until the game died. No pcall catches that. The button
helpers and six modules put saved objects back the same way, and the harness's SetFontObject took any object.

**Rule.** A saved font object goes back only through `U.SetFontObject` (`UADD/FontObject.lua`): an object the client
knows by name (its global is this object), whose chain ends within 10 steps, never the text or its own nameless
record, one set at a time per text. Save with `U.SafeFontObject` (the first such object in the chain). None in the
chain: the font stays as it is (a Cyrillic file draws English too), never a file by path (lesson 18).

**Check.**

- `python3 -m unittest tools.test_shared_state`: "put object", a SetFontObject with a saved object outside the core.
- `python3 tools/harness/run.py`: the harness's SetFontObject fails the run (`H.Crash`) on a font chain that loops, and
  so does a hook re-entered 8 deep on one object. "bs: 8 text area" (mutant `record` in `flow_bs.py --prove`) and
  the chaos case "BugSack font records".
- Manual, in the game: the real edit box record, and no crash.

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
never half translated. The joined help line exists only in its 1.1.4 to 1.1.6 (1.1.8 dropped the second sentence);
the flow still proves it. Check: `python3 tools/harness/flow_fqp.py`, "fqp: 3 hold canvas"; its mutants `beta` and
`join` take each fix out and want that step to fail.

**Lesson 32 again, in BugSack (2026-11-22).** What went wrong: the module saves a label's own font before it puts
UADD's Cyrillic font on, and puts the saved one back on the hold key and off. Its re-apply step (`Refix`, on hover
and on a font object change) cleared that saved font on every run. A hover that ran it twice saved our own Cyrillic
font as the "original", so held and off then put our font back on the English (the Wipe button). The harness found
it. Rule: forget a saved font only when ours is not on the label now (`Fresh` in `UADD_BugSack/Screen.lua`); never
save a font while ours is on. Since lesson 46 the core keeps this for every button's label: `U.SaveFont` and
`U.FontBack` take the button's own object, never our copy (`U.FontBase`, `UADD/Font.lua`). Check:
`python3 tools/harness/flow_button.py --prove`; its mutant `fontbase` cuts `U.FontBase` and wants step 6 to fail
(BugSack's old mutant `fresh` changed nothing once the core did this, so it is gone).
The review found one more: the sack's Options tab calls the Wipe button's `SetEnabled`, a native method that runs
no Lua `Enable`, `Disable` or `SetFontObject`, so no hook saw the font change and our words would show as boxes.
Rule: every state of a button carries our copy (lesson 46), so a native switch has nothing Latin to put on. Check:
`flow_button.py --prove` step 4 (hover, `Disable`, `Enable`, `SetEnabled`, `LockHighlight`) and mutant `states`,
there and in `flow_bs.py`.

**Lesson 18 again, after lesson 44 (2026-11-23).** What went wrong: item and spell tooltips showed boxes (the owner's
shots). Lesson 44's `U.FontBack` put a file back by path on any line whose Cyrillic file stayed over its object, also
on the game's tooltip lines after Mastercraft's block; that pinned them to the Latin file. The harness passed: its
tooltip lines dropped a hand-set file on SetFontObject, so that branch never ran there. Rule: only a label that
`U.CyrOnOwn` set by hand (`was.byhand`) gets its file back by path. Check: every harness FontString keeps a hand-set
file over SetFontObject, as the client does (`__hand`, `tools/harness/wow_widgets.lua`, `wow_fontfam.lua`); after
every segment the box check (`tools/harness/boxes.lua`, lesson 45) looks at what is on screen.
`python3 tools/harness/flow_mastercraft.py --prove`: mutant `fontback` cuts `U.FontBack` to a plain SetFont by path
and wants the box check to see a hit on Mastercraft's "item tooltip filled again".

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

**Lesson 41 again, kept results (2026-11-25).** Hand runs of `run.py` ran every flow after a one-module edit (163 s).
Now a job's passed result is reused while its inputs are the same (`tools/harness/jobcache.py`). Rule: a kept result
is only as good as its list of inputs, so list what the job was seen to read (files, folders, missing paths,
modules, environment) and, in doubt, more. Never keep a FAIL, a time that passed only by the load's stretch, a job
that runs a program, or one whose input changed during the run. The push check and CI never reuse. New ways to
read (Lua `io`, a relative import) need `jobinputs.py` first. Check: `python3 -m unittest tools.test_jobcache` (one
test per kind of input).
