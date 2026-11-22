"""Dropdown list checks (flow_dropdown.lua).

Questie's older options window (AceConfigDialog) shows "select" options as AceGUI dropdowns.
Their list items draw text with GameFontNormalSmall, which has no "і", "ї", "є", "ґ". While one
of Questie's lists is open, its Ukrainian items must be in our Cyrillic font at the same size;
once released, given plain text, or with "/uadd questie off", each item has its own font back
exactly. AceGUI pools the items for every addon, so no pooled item may keep our font. Nothing is
changed in combat, and the shared font object is never touched. A closed dropdown's Ukrainian
value is in our font too, and back in its own with "off". Last, an options window of our own
(served as OpenMap's is): its select's label, value and list in our font, and every widget released
to AceGUI's pools (another tab, the window closed) in its own font before any addon reuses it.

Questie 12.12 dropped that older window and AceConfigDialog with it. Then only the buttons of its
own window and our own options window are checked; AceConfig-3.0 for the latter is read from
another installed addon that carries it (OpenMap, Attune, GatherMate2 ...), as the game would.
"""
import glob
import os
import types

import session
from loader import txt

OLD_WINDOW = "Modules/Options/QuestieOptions.lua"
ACE_CONFIG = "Libs/AceConfig-3.0/AceConfig-3.0.xml"


def _questie(c):
    return next(a for a in c.addons if a.name == "Questie")


def _old_window(c):
    return os.path.isfile(os.path.join(_questie(c).folder, *OLD_WINDOW.split("/")))


def _ace_config(c):
    """Loads AceConfig-3.0 from another installed addon, as Questie's library. Returns its folder."""
    if c.ev('LibStub("AceConfigDialog-3.0", true) ~= nil'):
        return "loaded"
    for xml in sorted(glob.glob(os.path.join(session.addons_dir(), "*", *ACE_CONFIG.split("/")))):
        folder = os.path.dirname(os.path.dirname(os.path.dirname(xml)))
        c.run_xml(types.SimpleNamespace(name="Questie", folder=folder), ACE_CONFIG)
        if c.ev('LibStub("AceConfigDialog-3.0", true) ~= nil'):
            return os.path.basename(folder)
    return None


def dropdown(f, c, step):
    old = _old_window(c)
    need = 18
    if not old:
        src = _ace_config(c)
        f.check(f"{step}: dropdown list: AceConfig-3.0 for our own window", src, str(src))
        if not src:
            return
        need = 10
    got = [txt(x) for x in c.lines(c.F.dropdown(old))]
    for i in range(0, len(got) - 2, 3):
        name, ok, detail = got[i:i + 3]
        f.check(f"{step}: dropdown list: {name}", ok == "1", detail)
    f.check(f"{step}: dropdown list: all steps ran", len(got) >= 3 * need, f"{len(got) // 3} steps")
    f.no_errors(c, f"{step}: dropdown list")
