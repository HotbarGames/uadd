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
