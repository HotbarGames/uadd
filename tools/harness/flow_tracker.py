"""Tracker checks: Questie's real quest tracker draws a stubbed quest log (flow_tracker.lua).

The English drawing (before any names are known) is the baseline. With names, each line must be
the baseline line with only the known names swapped, colours untouched; every other line must
stay exactly as Questie drew it. Off must give the baseline back.
"""
import re

from loader import txt

COLOUR = re.compile(r"\|c[0-9A-Fa-f]{8}|\|r")
# Lines that must never change: free-text objectives, names we do not know, an unknown header.
# Made-up names, so no UALL update can know them (flow_tracker.lua).
KEPT = ["0/1 Zzyzx Harness Skullcap", "0/1 Find Zzyzx Harness Wife", "Zzyzx Harness Vale",
        "0/8 Zzyzx Harness Pelt"]


def plain(line):
    return COLOUR.sub("", line)


def uall_held(c, fn):
    """Runs fn with Shift held for UALL only: UALL then holds back its own translation of the
    tracker (UALLF QuestieHooks.lua, since 2026-11-13), so what is drawn is Questie's text plus
    ours. Our show-original key is not pressed: no key event fires."""
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
        self.ukrainian = None

    def baseline(self, c):
        """Before names are collected: our caches are empty, so the tracker is Questie's English."""
        # Shift held makes UALL say "not now", so the background collection waits while we draw.
        N = c.H.ns.UADD_Questie.Names
        empty = N.version == 0 and not any(N.maps[k] for k in ("Quest", "Npc", "Item"))
        lines, _ = uall_held(c, lambda: draw(c))
        cyrillic = [plain(x) for x in lines if re.search("[Ѐ-ӿ]", plain(x))]
        self.f.check("tracker: caches empty, Questie's English untouched", empty and not cyrillic, str(cyrillic[:4]))
        self.english = lines
        shown = [plain(x) for x in lines]
        want = ["Ruins of Lordaeron", "Harpy Raiders", "Witchwing Talon: 3/8", "0/10 Kobold Vermin slain"] + KEPT
        missing = [w for w in want if not any(w in s for s in shown)]
        self.f.check("tracker: Questie draws the quest log", len(lines) == 18 and not missing,
                     f"{len(lines)} lines, missing {missing}: {shown}")
        self.f.facts["tracker_english"] = shown
        return lines

    def expected(self, c):
        """English plain line -> the Ukrainian line we expect, from our own published names."""
        N = c.H.ns.UADD_Questie.Names
        l10n = c.ev("QuestieLoader:ImportModule('l10n')")

        def quest(i): return txt(N.maps.Quest[i])
        def item(i): return txt(N.maps.Item[i])
        def npc(i): return txt(N.maps.Npc[i])
        def zone(en): return txt(l10n.translations[en].ukUA)
        return {
            "Ruins of Lordaeron": zone("Ruins of Lordaeron"),
            "[21] Unending Torment": "[21] " + quest(97291),
            "0/5 Essence of Agony": "0/5 " + item(8923),
            "The Barrens": zone("The Barrens"),
            "[15] Harpy Raiders": "[15] " + quest(867),
            "Witchwing Talon: 3/8": item(5064) + ": 3/8",
            "[20] Lost in Battle": "[20] " + quest(4921),
            "Elwynn Forest": zone("Elwynn Forest"),
            "[4] Kobold Camp Cleanup": "[4] " + quest(7),
            "0/10 Kobold Vermin slain": "0/10 убито: " + npc(6),
            "Warsong Gulch": zone("Warsong Gulch"),
            "[19] Fight for Warsong Gulch": "[19] " + quest(8386),
            "2/3 Warsong Gulch Mark of Honor": "2/3 " + item(20558),
            "[6] Wolves Across the Border": "[6] " + quest(33),
        }

    def translated(self, c, step):
        """With names: every known name in Ukrainian, colours and everything else kept."""
        f, tr = self.f, self.expected(c)
        lines, set_texts = draw(c)
        bad = []
        for en, uk in zip(self.english, lines):
            want = tr.get(plain(en), plain(en))
            if plain(uk) != want or COLOUR.findall(uk) != COLOUR.findall(en):
                bad.append(f"{plain(en)!r} -> {uk!r} (want {want!r})")
        f.check(f"{step}: tracker in Ukrainian, colours kept", len(lines) == len(self.english) and not bad,
                "; ".join(bad[:4]) or f"{len(lines)} lines")
        kept = [x for x in KEPT if x not in [plain(y) for y in lines]]
        f.check(f"{step}: free-text and unknown names unchanged", not kept, str(kept))
        english_set = [plain(t) for t in set_texts if plain(t) in tr]
        f.check(f"{step}: no English drawn first (no flicker)", not english_set, str(english_set[:3]))
        self.ukrainian = lines
        f.facts.setdefault("tracker_ukrainian", [plain(x) for x in lines])
        return lines

    def reused(self, c, step):
        """A smaller log reuses the pool's lines: none may keep an old translation."""
        c.F.useSmallLog()
        lines, _ = draw(c)
        shown = [plain(x) for x in lines]
        quest = c.H.ns.UADD_Questie.Names.maps.Quest
        want = ["Zzyzx Harness Vale", "[6] " + txt(quest[33]), "0/8 Zzyzx Harness Pelt",
                "[20] " + txt(quest[4921]), "0/1 Find Zzyzx Harness Wife"]
        self.f.check(f"{step}: reused lines get fresh text", sorted(shown) == sorted(want), str(shown))
        c.F.resetQuestLog()

    def english_again(self, c, step):
        """Off: the English baseline again, colours and all. Drawn with UALL held back (uall_held):
        with us off, UALL's own translation of the tracker is shown, as it should be."""
        lines, _ = uall_held(c, lambda: draw(c))
        diff = [f"{plain(a)!r} vs {plain(b)!r}" for a, b in zip(lines, self.english) if a != b]
        self.f.check(f"{step}: tracker English, exactly as Questie draws it",
                     lines == self.english, "; ".join(diff[:4]) or f"{len(lines)} lines")

    def same_as_before(self, c, step):
        lines, _ = draw(c)
        self.f.check(f"{step}: tracker Ukrainian from the saved names", lines == self.ukrainian,
                     str([plain(x) for x in lines][:6]))
