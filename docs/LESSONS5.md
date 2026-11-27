# Lessons, part 5

Lessons 48 and up. The rules for this list and "Before a new addon" are in `docs/LESSONS.md`.

## 48. Pages kept hidden filled the walk, so the pages opened later stayed English

**What went wrong.** In the owner's game check of OneForAll (2026-11-27), "Your professions", the Dungeons & Raids
page and the Armory stayed English, though our data had their Ukrainian. OneForAll builds each page, and each
dungeon, pet and recipe view, once and keeps it hidden. The core walker visits at most 4000 frames in one walk,
over all roots, and it counts hidden frames too. The kept views used up the 4000 before the walk reached the page
just opened. Two smaller kinds on the same pages: labels its code dresses ("Diet:" from the word and a colon, "None"
inside one grey colour code) are not a whole text of ours, so they stayed English; and its tab bar sizes each tab by
the width of its name when it lays the tabs out, so our longer names ran over the next tab.

**Rule.**

- A window that keeps built pages hidden: the walk leaves out a hidden frame that is not a root, and hooks its
  OnShow (UADD_OneForAll/Screen.lua `Hidden`). A show walks only that frame's own subtree, all frames shown in one
  frame together, on the next frame, never in combat: a pooled row shown while scrolling costs its few frames,
  never a whole walk. Never a protected frame, nor one the walk skips by name (lesson 43). Its own
  SetScript("OnShow") drops our hook (lesson 2): each walk compares the script with the one seen after hooking and
  hooks again. Roots keep the walker's own OnShow hook.
- A label dressed by its code: a colon after a whole text of ours, or a whole text of ours in one colour, is ours
  with the colon or the colour kept. Anything else inside the colour: whole English (Words.lua `Dressed`). A
  profile name dressed so stays as typed (lesson 13, Screen.lua `Typed`).
- A bar that sizes its tabs by their names: once a tab name of ours was seen, each change between ours and the
  English (a tab name of ours, on, off, the hold key and its release) calls the addon's own layout function once,
  on the next frame, after combat (Screen.lua `TabName`, `Queue`). Never set the widths or sizes ourselves; the
  addon's own layout may take all its tab names down a size (13 to 10), as it does for its own long names.
- An addon's SetFont that reads our file back (that layout sets each size with the font GetFont gives) pins our
  Cyrillic file. A U.SaveFont record whose file goes back by path anyway (set by hand before us, `own`, as
  OneForAll's tab label at 13; or by U.CyrOnOwn, `byhand`) takes the new size and flags, so off and held give
  back its own file at its latest size (UADD/FontReadBack.lua, for every module that puts our font on through the
  core). Never any other record: a line that follows its font object (a game tooltip line) gets its object back and
  keeps the file the addon pinned, English in our font, never a Latin file by path (lessons 18, 45). UADD's own
  SetFont (U.SetFontSelf for the core, the first addon file on the stack for a module) leaves the record; the
  stack is read once per size; no stack counts as the addon's (the file stays its own either way); a hook that
  fails 5 times goes quiet.

**Check.** `python3 tools/harness/flow_ofa.py --prove`, step 14 (`tools/harness/flow_ofa_pages.lua`): 50 kept
hidden pages of 90 frames, then a page made later; a kept page shown, hidden and shown again walks only itself; a
kept page whose OnShow it set again after our hook; "X:" and a grey "X"; a grey text with English left stays
English; a profile name in a colour or with a colon stays; a tab button whose layout sets each size 13 to 10 by
SetFont keeps our Cyrillic font and counts its layout calls on, on hold, on release and off, and on hold and off
its English is in its own file at size 10, as its layout reads it back (its label set to 13 by hand, its layout
run from a chunk in OneForAll's folder). Mutants `hidden`, `showwalk`, `rehook`, `typed`, `tabhold`, `dressed`,
`tabs` and `readback` cut each fix and want step 14 to fail. The core alone: `python3 tools/harness/flow_button.py
--prove`, step 14 (`flow_button_read.lua`): a label set by hand (`byhand`, then `own`; once called from a module,
as our Relayout calls OneForAll's layout) gets back its own file at its latest size and flags; a game tooltip line
gets its object back and no Latin file, and a later Ukrainian on it draws letters; UADD's own call three times
leaves the record and reads the stack once; a failing debugstack counts as the addon's; a hook whose GetFont throws
reports 5 errors of 10. Mutants `readback`, `objectrec` (the old hook: every record took the size as set by hand),
`byuadd`, `stackonce`, `stackfail` and `faults`.

**Lesson 22 again, a frame count under load (2026-11-27).** The route check "off: collection finishes fast"
(under 1000 frames) failed twice on the pre-push run of fine code: 1092 and 1018 frames, while another session's
tests kept the PC busy. The collector does 6 ms of real-clock work per frame (`BUDGET_MS`), so a busy PC does
less per frame and the frame count grows with load: the check measured the PC, not whether UADD waited. Rule: a
check that counts frames to catch a wait first lifts the per-frame work budget, so the frames left are the waits
only. Check: `tools/harness/flow_routes.py` `_budget` (an off route takes 1 frame, the bound is 100); with the
collector's off-route branches cut (old waiting kept) every route takes 2416 frames and fails.

**Lesson 32 again, modules with their own font code (2026-11-27).** DialogueUI and What's Training? put our font
on with their own code, so the core never saw it. DialogueUI kept our file while the key was held: the English
showed in our Cyrillic file. What's Training? gave back only the font object, but our file had been set by hand,
and the client keeps a hand-set file over a new object (`keepsFileOverObject`): the English stayed in our file
and a pooled row lost its size. Rule: a module puts our font on and takes it off only through U.CyrFix /
U.CyrUnfix, or through its own helper that gives the font back both off and held, English first (lesson 45).
Check: `python3 tools/harness/flow_dialogueui.py --prove` (game F in `flow_dialogueui_hold.py`, mutants
`holdback`, `heldsize`); `python3 tools/harness/flow_whatstraining.py --prove` (`flow_whatstraining_objs.py`,
mutants `unfix`, `refix`).

**Lesson 48 again, modules that set our font themselves (2026-11-27).** UADD/FontReadBack.lua watches only
records made through core helpers. Mastercraft put our file on through the addon's raw setter; the addon's
fitters read the font back and its wrapper stored our file as its own (`mcPath`), so off and hold gave our
Cyrillic file back. Dungeon Journal's own SetFont hook took the journal setting our read-back file again as the
journal choosing a Cyrillic font, and dropped the record, so off had nothing to put back. Rule: a module with its
own font code and its own SetFont hook takes an addon's SetFont of our file as a read-back: the record keeps the
addon's own file and takes the new size and flags. A SetFontObject while our hand-set file stays keeps the
record. Off forgets a record only once ours is off the line. A copy that reads the font again every few frames
(ForeverXP Bar's options preview) heals itself and needs nothing. Check: `python3 tools/harness/flow_mastercraft.py
--prove` (`flow_mc_readback.py`, mutants `readback_size`, `readback_kept`); `python3
tools/harness/flow_dj_readback.py --prove` (mutants `readback`, `object`, `keep`).
