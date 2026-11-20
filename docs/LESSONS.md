# Lessons

This file lists mistakes we already made, so we do not make them again.

- Read it before you translate an addon or change any module.
- When you find a new **kind** of problem, add a lesson here. If a script can catch it, add a check too.
  Put the lesson, the check and the fix in the **same commit**.
- Each lesson has: **What went wrong** (one real example), **Rule**, and **Check** (a command or test to
  run, or "manual:" and what to do by hand when no script can catch it yet).

Two rules in `CLAUDE.md` already have their own checks. They are not repeated here:

- No bulk copy of another addon's text: `CLAUDE.md` "Other addons' texts", checked by `python3 tools/check_repo.py`.
- No half translations: `CLAUDE.md` "No half translations", checked by `python3 tools/harness/run.py`.

## Before a new addon

1. Read this whole file.
2. Check the addon's licence (`CLAUDE.md` "Other addons' texts").
3. Read what UALL Forever already translates in this addon (lesson 3). Leave those parts out.
4. Look up each game word in the glossary (`UADD/glossary/*.lua`, `docs/GLOSSARY.md`). Do not use a word
   from the banned list (lesson 4). When the owner picks a word, add it to the glossary and ban the word
   it replaces in the same turn (lesson 8).
5. Open every window and tab of the addon. Write down every English text you see, not only the texts in
   its locale tables (lesson 1).
6. If the module changes a font, test that the change really shows, also in windows made later (lesson 2).
7. Look for lines that share a row with another text, and for names the addon glues extra text onto
   (lessons 5, 6 and 7).
8. Before you call the module done, run all checks: `python3 tools/check_repo.py`,
   `python3 -m unittest discover -s tools -p 'test_*.py'`, `python3 tools/harness/run.py`.

## 1. Text made in code or taken from the game is easy to miss

**What went wrong.** In Auctionator, the "Quantity" column and the headers of the bag categories stayed English.
These texts are not in the addon's locale tables: the addon builds them in its code, or takes them from the game.

**Rule.** Before you call a module done, list every English text that its windows show, not only the
texts in its locale tables. Translate each one, or write down why it stays English.

**Check.** Manual for now: open every window and tab, in the game or in the harness (`tools/harness/`),
and look for English. Only Questie has a tool for this (`python3 tools/coverage.py`); the other modules
do not yet. This is a gap: automate it when we can.

## 2. A font change that fails without a sign

**What went wrong.** The header of the Questie options showed «Загальн□ налаштування» (a box instead of a
letter). Our own Cyrillic font object was never used, but the code said it worked.

**Rule.** Any font change must test that it really worked (read the font back from the text after the
change). It must also cover windows that the game builds later (for example the canvases of the Blizzard
Settings window), not only the windows that exist when the addon loads.

**Check.** `tools/test_font_chars.py` checks only that our strings use letters the fonts can draw. It does not test
the font change itself. Check: `python3 tools/harness/run.py`. Its font objects return nothing from `SetFont`, as in
the game, so code that trusts that return fails. The step "header of a canvas made after OnReady" (`late_header` in
`tools/harness/flow_header.py`) builds a Questie options canvas after the addon is ready, opens it two ways (the
Settings window shown, a category picked) and reads the font back.

**Again in What's Training? (2026-11-19).** On Forever its main window (`WhatsTrainingFloatingFrame`) is
made on first open, from a template, and shown at once. The module scanned its windows only at login, and
the template's texts are not made by `CreateFontString`, so the title and buttons would have stayed English.
The independent review found it; the harness had no late window. Rule: a window the addon makes on first
open is scanned when it appears (`NewRoot()` in `UADD_WhatsTraining/Screen.lua`), not only at login, and the
stand-in makes it late too. Check: `python3 tools/harness/run.py` (What's Training?'s "late window" step).

**Again in Dialogue UI (2026-11-20).** Its page in the game's options (Options > AddOns) stayed English: it is a
nameless frame, not under the module's named roots, and its first OnShow replaces itself, so a hook on it does not
last. Rule: such a page is found by what it holds (its one button's text, by hash), when the options window opens,
and its texts are hooked at once. Check: `python3 tools/harness/run.py`, the Dialogue UI canvas steps
(`tools/harness/flow_dialogueui_canvas.py`; game E makes the page after login).

## 3. The same text translated by two addons

**What went wrong.** UALL Forever (UALLF) is a separate Ukrainian addon. It is installed at
`C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\UALLF`. It skips text that already
has Cyrillic letters, and it translates some parts of other addons on purpose: its `Settings.lua` lists
them as `addons.*` options (today it does the Questie tracker). UADD and UALLF used different words for the
same thing, and the Questie Settings tree became a mix of the two.

**Rule** (the owner decided this):

- UADD does **not** translate the parts that UALLF translates on purpose.
- Before you start an addon, read the tooltips of the `addons.*` options in UALLF's `Settings.lua`, and
  its `*Hooks.lua` file for that addon. Leave those parts out of UADD.
- Check again when UALLF gets a new version.
- Where both addons change the same window, use UALLF's word when it already has one, so one window never
  shows two words for one thing.
- Before you pick a word for an addon's feature, grep UALL Forever for it: a Forever-only feature
  (Mastercraft's Camping) is named there, and a guess from the English word alone was wrong.

**Check.** Manual: in the commit message or the module notes, list what you checked and the UALLF version
(the `## Version:` line of `UALLF.toc`).

## 4. Words we decided against

**What went wrong.** We wrote «інстанс». It is slang. The right word is «підземелля»: у підземеллі,
у підземеллях, поза підземеллям, портал підземелля.

**Rule.** A word we decided against goes in the banned list (`BANNED` in `tools/test_banned_words.py`).
The right word goes in the glossary (`UADD/glossary/*.lua`, `docs/GLOSSARY.md`). When we decide against
a new word, add it to both in the same commit.

**Check.** `python3 -m unittest tools.test_banned_words`. It reads every string we ship (the `.lua` files
that each `UADD*/*.toc` loads, the TOC Title and Notes lines, and `tools/dj_prose/uk_*.lua`) and lists each
banned word as file:line: text. `python3 tools/test_banned_words.py` prints the same list.

## 5. A translation too long for its place

**What went wrong.** In ForeverXP Bar, the line under the bar («До рівня: 3 год 59 хв (16.5k досвіду/год)»,
41 letters; the English has 35) ran into the «Виконано / Відпочинок» line on the same row. It looked like a
font bug, but the addon draws that line big (size 15) on purpose. The fix was shorter words:
«До рівня: 3 год 59 хв (16.5k/год)».

**Rule.** A text that shares a row with another text, or sits in a fixed-size box (a button, a column, a bar), must
fit at the addon's own font size on a narrow window. Make the words shorter. Never make the font smaller: the size
is the addon's and the player's choice. Try to keep such texts no longer than the English.

**Check.** Auctionator's column headers: `python3 -m unittest tools.test_auc_headers`. Each header's
Ukrainian may be at most 2 letters longer than its English; a longer one gets a short form in
`ns.UA_HEAD` (`UADD_Auctionator/ui/locale.lua`, used only on headers, so the same English elsewhere keeps
the full words) or goes in `LONG` with a reason. It was added after the Selling tab cut «Рівень предмета»
to «Рівень пред...». Everything else is manual: in the game, make the window or bar as narrow as it goes
and look at each row with two texts. `python3 tools/harness/run.py` only checks that the module keeps the
addon's font size and outline ("keeps its own size and outline, also on resize").
LayerSwap's fixed boxes: `python3 -m unittest tools.test_lsw_strings` (`test_box_texts_not_much_longer_than_english`).
Each text of the panel's status box (2 lines) and host line (3 lines) may be at most 10% longer than its
English (read from the installed addon), or up to 50 / 75 letters. It was added after the help line
«Хост вимкнено до виходу з гри. Увімкнений хост допомагає гравцям LayerSwap змінити ша...» was cut.
Other modules' texts are not measured yet. This is a gap.

## 6. A name with extra text glued on

**What went wrong.** OpenMap puts the zone's levels after its name on the World Map ("Tirisfal Glades
(1-10)") and adds a "Fishing 25" line. UALL Forever translates zone names, but only when the whole text is
exactly a name, so both lines stayed English. Nobody hooked them, because each part looked translated.

**Rule.** Search the addon's code for places where it glues extra text onto a name or a game text
(`..`, `format`, `table.concat`). If UALL Forever or the game would translate the bare text, the glued line
is now ours: translate the whole line, with the name taken from UALL Forever. A name it does not know keeps
the whole line English (no half translations).

**Check.** Manual: list such places in the module notes. For each one, add a flow with a real joined text
in the harness (as `tools/harness/flow_openmap_label.py` does), then run `python3 tools/harness/run.py`.

**Again in Dungeon Journal (2026-11-20).** A quest's giver line is "Name, Town, Zone" in one text, so UALL Forever,
which knows each part alone, left it English. Rule: split it at the commas; all Ukrainian when UALL Forever names
every part, else whole English. Check: `python3 tools/harness/run.py`, the DJ module's header and giver-line steps
(`tools/harness/flow_dj_head.py`, also made-up lines with one unknown name).

**Again in What's Training? (2026-11-20).** Its section headers are a title, a bullet and a count glued in code
("%s • %d"). We had the title's Ukrainian but none for the glue template, so the whole header stayed English, with
no error, and the harness never fed it a real glued header. Rule: every template the addon glues in code gets its
Ukrainian, and a flow builds the real glued lines from the installed addon's English. Never ship "•" in our
Ukrainian: the Cyrillic font may draw it as a box (we use "—"). Check: `python3 tools/harness/run.py`, What's
Training?'s "glue 1-3" steps (`tools/harness/flow_whatstraining_glue.py`); `python3 -m unittest tools.test_font_chars`.

**Again in Mastercraft (2026-11-20).** A list of items ("2 X, 2 Y") and a bare item, NPC or zone on its own line
were asked from UALL Forever as one name, so they stayed English, also where UALL Forever knows every name. Rule:
a slot or line that holds a list asks UALL Forever for each name; all Ukrainian when it names every one, else
whole English. Check: `python3 tools/harness/run.py`, the Mastercraft code steps (`tools/harness/flow_mc_code2.py`).
A guide step's row title is the recipe, a gap and its count in grey ("<recipe>   x51", the count in its own
colour) in one text, so it stayed English too: no split step knew a name with a coloured count after it. Rule: a
count the addon glues on in colour gets its own split (`P.Count` in `UADD_Mastercraft/Split.lua`), the name asked
alone. Check: the "guide step's row title" steps in the same file (a reused row; they fail with the split taken out).

## 7. A free slot that swallows glued text

**What went wrong.** LayerSwap's one-line mini bar is the layer's name, a wide gap, then its status
(«Лейер B   Пауза 4:59»). The status template starts with a slot that only holds a colour code, and that slot was
marked free. A free slot keeps any English, so on another split the whole name could land in it, and the line would
come out half Ukrainian. It came out right only because an older guard (no wide gap inside a `%s`) said no first.
The half-translation check never fed glued text into free slots, so nobody saw it. Six more free marks were the same
kind (a colour code or a clock). The minimap tooltip's first line (name, gap, host mark) stayed all English: the
host mark is a text that starts with the gap, so the split at the gap never finds it.

**Rule.** Mark a slot free only when it holds one name. Never mark a slot free that holds a colour code, a
number or a clock: those pass as values anyway. A free slot keeps one name, never a line break or " - "
with more text after it (Words.lua says no then). When an addon glues two of its texts with a gap, the
whole line must be ours: check it, and add a JOINED recipe when a piece carries the gap itself.

**Check.** `python3 tools/harness/run.py`. In the half-translation check of each module that finds whole lines on
screen (ForeverXPBar, LayerSwap: `glue=True`; `halves.glued` in `tools/harness/halves.py`), every free slot at the
start or end of a template gets a name glued to made-up English with "   ", a line break or " - "; an output that
changed and still has the made-up English fails. LayerSwap's flow also builds its real glued lines from the
installed addon (`glued()` in `tools/harness/flow_lsw_mixed.py`) and wants each one all Ukrainian, each half as it
is alone. `dashed()` there does the same for the lines glued with a wide dash ("  -  "): a layer row
(«Лейер C  — 6864-5») stayed English because Words.lua split it at " - " and kept a space on the name. A new joining
mark goes in `SEPS` (Words.lua), wider marks before narrower ones. The panel's zone line (id, dash, zone) takes the
zone's name from UALL Forever (lesson 6) and stays whole English when UALL has none.

**Again in Mastercraft (2026-11-19).** Its Words.lua splits a text into lines and translates each piece alone. A
free slot at a piece's start or end then took a name with English glued after it (a wide gap, a line break), and a
short "from %s" template took a whole English phrase as its "name". Rule: a free slot also says no to any word in
small letters (a name is capitalised; a phrase is not), and a text of several lines stays all English when one line
with English words has no Ukrainian. A `|cff%s` slot is always a value, never free (`tools/mc_rules.py`,
`test_colour_slot_never_free`). Check: Mastercraft is in the same glued feed in `tools/harness/halves_mods.py`.

## 8. A word the owner picked, lost in chat

**What went wrong.** On 2026-11-18 the owner picked «лейер» for a server layer in LayerSwap («Змінити
лейер»). The choice lived only in the chat. The module shipped «шар» 145 times («Змінити шар», «ВАШ ШАР»),
the word OpenMap uses for a drawn map layer. Nothing in the repo knew about the choice, so no check failed.

**Rule.** When the owner picks a word, in the same turn:

- add it to the glossary (`UADD/glossary/*.lua`), with a note that says it is the owner's choice and the date;
  if the same English has another meaning elsewhere, add a row to "Is it the same meaning?" in
  `docs/GLOSSARY.md`;
- ban the word it replaces: in `BANNED` (`tools/test_banned_words.py`) when it is wrong everywhere, or in
  `BANNED_IN` for the modules where it is wrong when it is right elsewhere («шар» is banned only in
  `UADD_LayerSwap`, since OpenMap's map layer is «шар»).

**Check.** `python3 -m unittest tools.test_banned_words`. `BANNED_IN` reads only the files that the module's
TOC loads, and its TOC lines. `python3 tools/test_banned_words.py` lists each hit as file:line: text.

## 9. A game name we wrote ourselves

**What went wrong.** The first AutoPotion module shipped our own Ukrainian for six texts that name game things UALL
Forever does not have: two potions, an engineering injector, an option and its tooltip with the warlock spell
Soulburn, and a tooltip with two example items. The owner's rule is that game names come from UALL Forever, but the
Ukrainian looked fine, so nobody saw it. The six now stay English, or say the same without the names.

**Rule.** Items, spells, NPCs, zones and quests are UALL Forever's to name (`Items.lua`, `Spells.lua`,
`NpcNames.lua`, `World.lua`, `Quests.lua` in its folder). We write none.

- A name UALL Forever has: use its Ukrainian exactly.
- A name it lacks: leave the text English, or say the same without the name (no half translations).
- Plain game words in the glossary that match UALL Forever (Healthstone «Камінь Здоров'я», Soul Shard)
  are fine.

**Check.** `python3 -m unittest tools.test_game_names` (AutoPotion and LayerSwap). For each text we ship, it reads
the English from the installed addon. A UALL Forever name in it must be in our Ukrainian as UALL Forever has it. A
word with a capital letter mid-sentence that the addon never writes in small letters, and that our Ukrainian does
not keep as it is, looks like a name UALL Forever lacks: the test fails. A text a person read and found clean goes
in `ALLOW` in that file, with the hash of its Ukrainian, so a later change is read again. It would have caught all
six texts above. It misses a name made of plain words the addon also writes in small letters, a name at a sentence
start, and modules not in its list (`MODULES` in `tools/game_names_src.py`; ForeverXPBar gives too many false hits
yet). Manual: read every capitalised word of the English.

**Again in Dungeon Journal (2026-11-20).** About 220 long texts (`tools/dj_prose/uk_N.lua`) kept English game names
inside the Ukrainian, as in «Faldrim Anvilmar». That is a half line. The generator makes a placeholder (`{npc:..}`,
`{zone:..}`, `{item:..}`, `{quest:..}`) only for names UALL Forever has. The translators copied the other names as
they were. Rule: a name UALL Forever lacks is said another way, without the name, or the whole text stays English.
We never write the name in Ukrainian letters ourselves. Check: `python3 -m unittest tools.test_dj_prose`
(`test_no_latin_in_uk`). After placeholders, colour and texture codes, links and `%s` are taken out, no Latin word
of 2 or more letters may stay. `ALLOW` in that file lists the few that may (the realm, the game, the addon, a
website), each with a reason; a game name never goes there. `KNOWN` lists texts still being fixed; it only goes
down. `python3 tools/test_dj_prose.py --latin` prints every hit and a new `KNOWN` block.

**Again in Forever Quest Pins (2026-11-20).** The first module wrote game names itself: a What's New line with our
Ukrainian for two quest titles, «Ярмарок Даркмун» (UALL Forever's word, where ClassicUA says «Ярмарок Темного
місяця»), the two capitals by name, and «Ан'Кіраж» alone. The module was not in `MODULES`, so the check never read
it. Rule: the What's New line with the quest names stays English; an event takes ClassicUA's word, UALL Forever
fills what ClassicUA lacks; a war effort is the glossary's «воєнні зусилля Ан'Кіражу»; two capitals are «у
столицях». Check: `python3 -m unittest tools.test_game_names` (Forever Quest Pins is in `MODULES` now);
`python3 tools/harness/run.py`, "fqp: 4 names" (a What's New line that quotes quest names stays English).

## 10. Checks that passed because the files were new

**What went wrong.** The AutoPotion module was checked before its first commit. `python3 tools/check_repo.py`
passed. Then the push failed: the pre-push hook checks a clean copy of the commit, and there the module's TOC said
version 1.0.0 (the others said 1.0.1), and two new Python files were over 300 lines. The check had read only tracked
files (`git ls-files`), and the module's new files were not tracked yet, so it never looked at them.

**Rule.** A check of the repo reads the files that the next commit will hold: the tracked ones and the
untracked ones git does not ignore. A file that must never be committed goes in `.gitignore`.

**Check.** `python3 -m unittest tools.test_check_repo` (`test_untracked_new_file_over_budget_fails`,
`test_untracked_new_toc_must_share_version`). `tools/check_repo.py` reads `git ls-files` and
`git ls-files --others --exclude-standard` for the size, TOC and copy checks.

## 11. An addon update that drift could not see

**What went wrong.** The new Bagnon module reads its texts from the BagBrother folder. BagBrother's TOC has no
`## Version:` line (Bagnon's TOC has it), so `tools/addon_versions.json` recorded version null for UADD_Bagnon. A
new Bagnon version would not have shown as a version change. In the same review, `docs/TESTING.md` told the tester
that `/uadd <module>` says it waits for its addon when that addon is missing. For a module whose TOC has the addon
in `## Dependencies:` that cannot happen: the game does not load the module at all, so `/uadd` does not list it.

**Rule.** Each module's record in `tools/addon_versions.json` has a version. When the folder with the texts
has no Version, name the folder that has it in `VERSION_FROM` (`tools/drift_sources.py`). A test step says
only what the real client can show: a module with a required dependency is not loaded without it.

**Check.** `python3 -m unittest tools.test_drift` (`test_every_version_recorded`). Test steps: manual, read
each "without <addon>" step against the module's TOC.

## 12 and up

Lessons 12 and up (hooks on game-wide paths, the player's own text, saved data, words set after load, widgets
that take the keyboard) are in `docs/LESSONS2.md`. Read that file too.
