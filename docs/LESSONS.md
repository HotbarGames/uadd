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
   from the banned list (lesson 4).
5. Open every window and tab of the addon. Write down every English text you see, not only the texts in
   its locale tables (lesson 1).
6. If the module changes a font, test that the change really shows, also in windows made later (lesson 2).
7. Look for lines that share a row with another text, and for names the addon glues extra text onto
   (lessons 5 and 6).
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

**Check.** Manual: in the game, make the window or bar as narrow as it goes and look at each row with two
texts. `python3 tools/harness/run.py` only checks that the module keeps the addon's font size and outline
("keeps its own size and outline, also on resize"); no script measures the length yet. This is a gap.

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
