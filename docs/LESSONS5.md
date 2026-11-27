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
- Open (core): that layout reads our Cyrillic file back and sets it with SetFont, so the label's own font becomes
  the Cyrillic file; the English on hold and off then shows in it (Latin draws fine, no boxes).

**Check.** `python3 tools/harness/flow_ofa.py --prove`, step 14 (`tools/harness/flow_ofa_pages.lua`): 50 kept
hidden pages of 90 frames, then a page made later; a kept page shown, hidden and shown again walks only itself; a
kept page whose OnShow it set again after our hook; "X:" and a grey "X"; a grey text with English left stays
English; a profile name in a colour or with a colon stays; a tab button whose layout sets each size 13 to 10 by
SetFont keeps our Cyrillic font and counts its layout calls on, on hold, on release and off. Mutants `hidden`,
`showwalk`, `rehook`, `typed`, `tabhold`, `dressed` and `tabs` cut each fix and want step 14 to fail.

**Lesson 22 again, a frame count under load (2026-11-27).** The route check "off: collection finishes fast"
(under 1000 frames) failed twice on the pre-push run of fine code: 1092 and 1018 frames, while another session's
tests kept the PC busy. The collector does 6 ms of real-clock work per frame (`BUDGET_MS`), so a busy PC does
less per frame and the frame count grows with load: the check measured the PC, not whether UADD waited. Rule: a
check that counts frames to catch a wait first lifts the per-frame work budget, so the frames left are the waits
only. Check: `tools/harness/flow_routes.py` `_budget` (an off route takes 1 frame, the bound is 100); with the
collector's off-route branches cut (old waiting kept) every route takes 2416 frames and fails.
