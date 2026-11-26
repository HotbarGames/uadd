# Open cases of boxes

Owner's rule (2026-11-26), very important: **while one case of boxes instead of letters is not fixed, nothing
is released.** Any module, any window, also when it shows only for a moment (the mouse over a button).

`tools/bump_version.py` and `tools/make_zip.py` refuse while a line below starts with `- OPEN`
(`tools/open_boxes.py`).

- A case goes in at once when it is seen or found: date, addon, where, what to do to see it.
- It goes out (the line is deleted) only when all three hold: the fix is in; a check fails without the fix;
  the owner looked in the game and it is gone.
- A case nobody can reproduce stays open until its cause is known.

## Cases

- OPEN 2026-11-26 BugSack: a bottom tab shows boxes while the mouse is over it (the second tab, "this session").
- OPEN 2026-11-26 Forever Quest Pins: the breadcrumb dialog's Ignore button (found by the harness, not seen in the game yet). Fix in, not yet checked in the game.
- OPEN 2026-11-26 Dungeon Journal: two button labels, on the mode chooser and on the main window (found by the harness, not seen in the game yet).
- OPEN 2026-11-26 LayerSwap: the panel's swap button, after a button state change when our font copy could not be made (found by the chaos test, not seen in the game yet).
- OPEN 2026-11-26 OpenMap: the dungeon view, a Latin font set by hand under our Ukrainian (found by the chaos test, not seen in the game yet).
