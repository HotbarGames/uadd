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
"""
from loader import txt


def dropdown(f, c, step):
    got = [txt(x) for x in c.lines(c.F.dropdown())]
    for i in range(0, len(got) - 2, 3):
        name, ok, detail = got[i:i + 3]
        f.check(f"{step}: dropdown list: {name}", ok == "1", detail)
    f.check(f"{step}: dropdown list: all steps ran", len(got) >= 3 * 18, f"{len(got) // 3} steps")
    f.no_errors(c, f"{step}: dropdown list")
