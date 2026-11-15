"""Live-names checks (flow_live.lua): names found in a running game show in Questie at once.

Questie keeps its own quest, NPC and item objects. After a collection they must hold the
Ukrainian names in the same session, with no /reload: the quest QuestieDB.GetQuest hands out,
the object Questie's quest log holds (and it must be that same object, not a stale copy), and
the NPC and item objects. A /reload must give exactly the same names.
"""
import re

from loader import txt

CYRILLIC = re.compile("[Ѐ-ӿ]")
READY = "назви готові"
LOG = [97291, 867, 4921, 7, 8386, 33]     # F.logIds in flow_live.lua


class Live:
    def __init__(self, f):
        self.f = f
        self.names = None

    def got(self, c):
        return [txt(x) for x in c.lines(c.F.questieNames())]

    def expected(self, c):
        """The names we published, in the order questieNames() lists them."""
        m = c.H.ns.UADD_Questie.Names.maps
        out = [f"quest 2={txt(m.Quest[2])}"]
        out += [f"log {i}={txt(m.Quest[i])}" for i in LOG]
        return out + [f"npc 6={txt(m.Npc[6])}", f"item 5064={txt(m.Item[5064])}"]

    def english(self, c, step):
        """Before any names are known: Questie's objects are English (so the later check means something)."""
        got = self.got(c)
        uk = [x for x in got if CYRILLIC.search(x)]
        self.f.check(f"{step}: Questie's own objects English", not uk and len(got) == 9, str(uk or got))

    def shown(self, c, step):
        """Questie's own objects carry our Ukrainian names, and none is stale."""
        got, want = self.got(c), self.expected(c)
        bad = [f"{a} (want {b})" for a, b in zip(got, want) if a != b or not CYRILLIC.search(a)]
        self.f.check(f"{step}: Questie's quest, quest-log, NPC and item objects Ukrainian, none stale",
                     len(got) == len(want) and not bad, "; ".join(bad[:3]) or f"{len(got)} names")
        return got

    def first(self, c, chat):
        """The first collection: one rebuild, Ukrainian at once, and a message with no /reload in it."""
        frames, done = c.F.settle()
        self.f.check("live: Questie's rebuild finishes", done, f"{frames} frames")
        self.f.check("live: Questie rebuilt exactly once", c.F.resets == 1, str(c.F.resets))
        self.names = self.shown(c, "live")
        ready = [x for x in chat() if READY in x]
        self.f.check("live: player told the names are shown, no /reload",
                     len(ready) == 1 and "/reload" not in ready[0], str(ready))
        self.f.facts["questie_names_live"] = self.names

    def same_after_reload(self, c):
        got = self.shown(c, "reload")
        self.f.check("reload: the same names as the live session", got == self.names, str(got[:3]))

    def extra(self, c, step, after):
        """A logged quest with an English title and a translated target (flow_live.lua F.extraId).
        Before: its map pins are English. After the live apply: the pins carry Ukrainian names,
        the title stays English, and every tooltip points at the quest's current objectives."""
        N = c.H.ns.UADD_Questie.Names
        got = [txt(x) for x in c.lines(c.F.objectiveNames(c.F.extraId))]
        title = [x for x in got if x.startswith("title=")]
        spawns = {int(x.split()[1].split("=")[0]): x.split("=", 1)[1] for x in got if x.startswith("spawn ")}
        tips = [x for x in got if x.startswith("tooltip ")]
        ok = title == ["title=The Return of Korrak"] and spawns and tips
        if not after:
            ok = ok and not any(CYRILLIC.search(v) for v in spawns.values())
        else:
            want = {i: txt(N.maps.Npc[i]) for i in spawns if N.maps.Npc[i]}
            ok = ok and want and all(spawns[i] == w for i, w in want.items()) and all(x.endswith(" fresh") for x in tips)
        self.f.check(f"{step}: English-titled logged quest, map pins and tooltips "
                     + ("English" if not after else "Ukrainian and fresh"), ok, "; ".join(got[:8]))

    def failures(self, c, collect):
        """Each way the live path can go wrong ends with one "/reload" message and no "shown"."""
        pump = c.ev("function(s) return HARNESS.pump(math.floor(s / 0.05), nil, 0.05) end")
        cases = [("rebuild never ends", lambda: c.F.stuckReset(True), lambda: c.F.stuckReset(False), 20, 15),
                 ("Questie never starts", lambda: c.F.notStarted(True), lambda: c.F.notStarted(False), 110, 15),
                 ("end of collection fails", c.F.failAtFinish, lambda: None, None, 5)]
        for name, setup, teardown, early, late in cases:
            before = len(c.chat())
            setup()
            c.slash("questie rebuild")
            collect()
            too_soon = []
            if early is not None:              # nothing said while we still wait
                pump(early)
                too_soon = [x for x in c.chat()[before:] if READY in x]
            pump(late)
            teardown()
            said = [x for x in c.chat()[before:] if READY in x]
            self.f.check(f"{name}: player told to /reload once, not before giving up",
                         not too_soon and len(said) == 1 and "/reload" in said[0], str(too_soon or said))

    def fallback(self, c, run):
        """The Questie function we need is missing: the old way, saved and shown after /reload."""
        before, resets = len(c.chat()), c.F.resets
        c.F.breakLive(True)
        run()
        c.F.breakLive(False)
        said = [x for x in c.chat()[before:] if READY in x]
        self.f.check("live path missing: player told to /reload",
                     len(said) == 1 and "/reload" in said[0] and c.F.resets == resets, str(said))
