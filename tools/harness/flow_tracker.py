"""Tracker checks: Questie's real quest tracker draws a stubbed quest log (flow_tracker.lua).

UADD leaves the tracker to UALL Forever: while Questie draws it, Questie speaks English
(UADD_Questie/Tracker.lua). The English drawing before any names are known is the baseline. With
names, and when off, the tracker must be exactly the baseline (UALL held back), and UALL Forever
must translate it as the player sees it. old_fonts: the tracker fonts the old UADD switched go back.
"""
import re

from loader import lua_str, txt

COLOUR = re.compile(r"\|c[0-9A-Fa-f]{8}|\|r")
CYRILLIC = re.compile("[Ѐ-ӿ]")
# Free-text objectives, unknown names and an unknown header in the quest log (flow_tracker.lua).
# Made-up names, so no UALL update can know them.
KEPT = ["0/1 Zzyzx Harness Skullcap", "0/1 Find Zzyzx Harness Wife", "Zzyzx Harness Vale",
        "0/8 Zzyzx Harness Pelt"]

# Questie's default tracker font, and old saved data for old_fonts: three fonts the old UADD
# switched, one the player picked later, one saved font.
DEFAULT_FONT = "Friz Quadrata TT"
OLD_UADD = """
UADD_DB.modules.questie.fontBackup = { trackerFontZone = "Morpheus" }
UADD_DB.modules.questie.fontAuto = true
"""
OLD_QUESTIE = """
QuestieConfig = QuestieConfig or {}
QuestieConfig.profiles = QuestieConfig.profiles or {}
local names = { Default = true }
for _, n in pairs(QuestieConfig.profileKeys or {}) do names[n] = true end
for n in pairs(names) do
    local p = QuestieConfig.profiles[n] or {}
    QuestieConfig.profiles[n] = p
    p.trackerFontHeader, p.trackerFontZone = "UADD Cyrillic", "UADD Cyrillic"
    p.trackerFontQuest, p.trackerFontObjective = "UADD Cyrillic", "Arial Narrow"
end
"""


def plain(line):
    return COLOUR.sub("", line)


def uall_held(c, fn):
    """Runs fn with Shift held for UALL only: UALL then holds back its own translation of the
    tracker (UALLF QuestieHooks.lua, since 2026-11-13), so what is drawn is Questie's own text. Our show-original key is not pressed: no key event fires."""
    c.H["keys"].SHIFT = True
    try:
        return fn()
    finally:
        c.H["keys"].SHIFT = False


def draw(c, fill=True):
    lines, set_texts = c.F.drawTracker(fill)
    return [txt(x) for x in c.lines(lines)], [txt(x) for x in c.lines(set_texts)]


class Tracker:
    def __init__(self, f):
        self.f = f
        self.english = None

    def baseline(self, c):
        """Before names are collected: our caches are empty, so the tracker is Questie's English."""
        # Shift held makes UALL say "not now", so the background collection waits while we draw.
        N = c.H.ns.UADD_Questie.Names
        empty = not any(N.maps[k] for k in ("Quest", "Npc", "Item"))
        lines, _ = uall_held(c, lambda: draw(c))
        cyrillic = [plain(x) for x in lines if CYRILLIC.search(plain(x))]
        self.f.check("tracker: caches empty, Questie's English untouched", empty and not cyrillic, str(cyrillic[:4]))
        self.english = lines
        shown = [plain(x) for x in lines]
        want = ["Ruins of Lordaeron", "Harpy Raiders", "Witchwing Talon: 3/8", "0/10 Kobold Vermin slain"] + KEPT
        missing = [w for w in want if not any(w in s for s in shown)]
        self.f.check("tracker: Questie draws the quest log", len(lines) == 18 and not missing,
                     f"{len(lines)} lines, missing {missing}: {shown}")
        self.f.facts["tracker_english"] = shown
        return lines

    def stays_english(self, c, step, on=True):
        """With names known, and also when off: the tracker is drawn exactly in Questie's English,
        colours and all (Tracker.lua), so UALL Forever gets whole English lines. Drawn with UALL held
        back (uall_held). When on, Questie speaks Ukrainian again right after the draw. Then drawn
        as the player sees it: UALL Forever translates the lines."""
        lines, _ = uall_held(c, lambda: draw(c))
        diff = [f"{plain(a)!r} vs {plain(b)!r}" for a, b in zip(lines, self.english) if a != b]
        self.f.check(f"{step}: tracker English, exactly as Questie draws it",
                     lines == self.english, "; ".join(diff[:4]) or f"{len(lines)} lines")
        if on:
            after = txt(c.F.l10n(lua_str("General")))
            self.f.check(f"{step}: Questie speaks Ukrainian again after the draw", after == "Загальне", after)
        lines, _ = draw(c)
        cyr = [plain(x) for x in lines if CYRILLIC.search(plain(x))]
        self.f.check(f"{step}: UALL Forever translates the tracker", cyr, str([plain(x) for x in lines][:4]))


def old_fonts(f, saved):
    """The old UADD switched the tracker fonts to "UADD Cyrillic" and saved the old ones
    (fontBackup). Now UALL Forever picks the fonts, so at the next login the switched fonts go
    back: the saved one, else Questie's default. A font the player picked later stays."""
    saved = dict(saved)
    saved["UADD"] = saved.get("UADD", "") + OLD_UADD
    saved["Questie"] = saved.get("Questie", "") + OLD_QUESTIE
    c = f.start(saved)
    db = c.lua.globals().UADD_DB.modules.questie
    fonts = [txt(x) for x in c.F.fonts()]
    want = [DEFAULT_FONT, "Morpheus", DEFAULT_FONT, "Arial Narrow"]
    f.check("old fonts: switched fonts back, the player's pick kept", fonts == want, str(fonts))
    f.check("old fonts: old font data forgotten",
            db.fontBackup is None and db.fontAuto is None and db.fontHint is None)
    f.no_errors(c, "old fonts")

