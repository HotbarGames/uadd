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
8. Before you call the module done, run all checks:
   `python3 tools/check_repo.py`, `python3 -m unittest discover -s tools -p 'test_*.py'`,
   `python3 tools/harness/run.py`.

## 1. Text made in code or taken from the game is easy to miss

**What went wrong.** In Auctionator, the "Quantity" column and the headers of the bag categories stayed
English. These texts are not in the addon's locale tables: the addon builds them in its code, or takes them
from the game.

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

**Check.** `tools/test_font_chars.py` checks only that our strings use letters the fonts can draw. It does
not test the font change itself. Check: `python3 tools/harness/run.py`. Its font objects return
nothing from `SetFont`, as in the game, so code that trusts that return fails. The step "header of a
canvas made after OnReady" (`late_header` in `tools/harness/flow_header.py`) builds a Questie options canvas
after the addon is ready, opens it two ways (the Settings window shown, a category picked) and reads the
font back.

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

**Rule.** A text that shares a row with another text, or sits in a fixed-size box (a button, a column, a
bar), must fit at the addon's own font size on a narrow window. Make the words shorter. Never make the font
smaller: the size is the addon's and the player's choice. Try to keep such texts no longer than the
English.

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

## 7. A free slot that swallows glued text

**What went wrong.** LayerSwap's one-line mini bar is the layer's name, a wide gap, then its status
(«Лейер B   Пауза 4:59»). The status template starts with a slot that only holds a colour code, and that
slot was marked free. A free slot keeps any English, so on another split the whole name could land in it,
and the line would come out half Ukrainian. It came out right only because an older guard (no wide gap
inside a `%s`) said no first. The half-translation check never fed glued text into free slots, so nobody
saw it. Six more free marks were the same kind (a colour code or a clock). The minimap tooltip's first line
(name, gap, host mark) stayed all English: the host mark is a text that starts with the gap, so the split
at the gap never finds it.

**Rule.** Mark a slot free only when it holds one name. Never mark a slot free that holds a colour code, a
number or a clock: those pass as values anyway. A free slot keeps one name, never a line break or " - "
with more text after it (Words.lua says no then). When an addon glues two of its texts with a gap, the
whole line must be ours: check it, and add a JOINED recipe when a piece carries the gap itself.

**Check.** `python3 tools/harness/run.py`. In the half-translation check of each module that finds whole
lines on screen (ForeverXPBar, LayerSwap: `glue=True`; `halves.glued` in `tools/harness/halves.py`), every
free slot at the start or end of a template gets a name glued to made-up English with "   ", a line break
or " - "; an output that changed and still has the made-up English fails.
LayerSwap's flow also builds its real glued lines from the installed addon (`glued()` in
`tools/harness/flow_lsw_mixed.py`) and wants each one all Ukrainian, each half as it is alone.
`dashed()` there does the same for the lines glued with a wide dash ("  -  "): a layer row («Лейер C  —
6864-5») stayed English because Words.lua split it at " - " and kept a space on the name. A new joining
mark goes in `SEPS` (Words.lua), wider marks before narrower ones. The panel's zone line (id, dash, zone)
takes the zone's name from UALL Forever (lesson 6) and stays whole English when UALL has none.

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
