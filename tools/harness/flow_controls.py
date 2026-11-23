"""Checks for the texts of Questie 12.8's own options controls (UADD_Questie/ControlFont.lua).

Questie 12.8 draws row titles, descriptions, container titles, slider texts, a dropdown's value and
the entries of its menu in the client's shared fonts, which have no "і", "ї", "є", "ґ". Each such
Ukrainian text must be in our font at its own size and flags, stay so when its frame is set up
again, and get exactly its own font back with the show-original key held and on "off".
The Lua side is flow_controls.lua.
"""
from loader import txt


def first(f, c, step):
    """Every settings-panel tab: labels in our font, after re-layout, the menu, the key, combat."""
    counts, bad = (txt(x) for x in c.F.controlFonts())
    kinds = dict(p.split(" ") for p in counts.split(", ") if p)
    full = all(n.split("/")[0] == n.split("/")[1] for n in kinds.values())
    want = ("title", "description", "container", "slider", "dropdown")
    missing = [k for k in want if k not in kinds]
    f.check(f"{step}: options labels, descriptions, slider and dropdown text in our font, size kept",
            full and not missing and not bad, counts + (f"; missing {missing}" if missing else "") + (f"; {bad}" if bad else ""))
    ok, n = c.F.controlRecycle()
    f.check(f"{step}: options texts still ours after re-layout and frame set-up again", n > 0 and ok == n, f"{ok}/{n}")
    ok, detail = c.F.controlMenu()
    f.check(f"{step}: dropdown menu entries ours while open, own font after", ok, txt(detail))
    ok, detail = c.F.controlShift()
    f.check(f"{step}: show-original key and combat give option texts their exact own font", ok, txt(detail))
    label, ok, n, swapped = c.F.controlSearch()
    f.check(f"{step}: Questie window: search label in our font", bool(label), str(label))
    f.check(f"{step}: Questie window: a tab its search builds again has its texts in our font",
            bool(swapped) and n > 0 and ok == n, f"{ok}/{n}, content swapped {swapped}")


def snapshot(c):
    """Before "/uadd questie off": how many control texts are in our font."""
    return c.F.controlSnapshot()


def after_off(f, c, before, step):
    cyr, ok, n, bad = c.F.controlAfterOff()
    tail = f"; {txt(bad)}" if txt(bad) else ""
    f.check(f"{step}: options control texts still Ukrainian keep a Cyrillic font (no boxes)",
            before > 0 and cyr == n == before, f"{cyr}/{n} of {before}{tail}")
    f.check(f"{step}: options control texts set English get their exact own font back",
            before > 0 and ok == n == before, f"{ok}/{n} of {before}{tail}")
