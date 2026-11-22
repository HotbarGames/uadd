"""The parts of flow.run() that play game sessions of their own, so pool.py can run them side by side.

Each part is fn(f, *args) with f a Flow: it adds its checks to f. With a pool (flow.run(spawn=pool.spawn)) a part
starts as its own job as soon as its inputs are known, and its checks go where the part's call stood, so the check
list keeps its order. With no pool, a part runs at its own place, as before.
"""
import session


def part(fn, *args):
    """A pool job: fn(a new Flow, *args). Returns (checks, facts)."""
    import flow
    f = flow.Flow()
    fn(f, *args)
    return f.checks, f.facts


class Parts:
    def __init__(self, f, spawn):
        self.f, self.spawn, self.got = f, spawn, {}

    def start(self, name, fn, *args):
        if self.spawn is None:
            self.got[name] = (fn, args)
        else:
            self.got[name] = [self.spawn(part, fn, *args)]

    def put(self, name):
        """The part's checks, here: run now (no pool), or the job's place-holder (pool.py swaps it later)."""
        got = self.got.pop(name)
        if isinstance(got, tuple):
            got[0](self.f, *got[1])
        else:
            self.f.checks += got


def combat(f, counts):
    """7. Combat pauses the collection; it goes on after combat. `counts`: the first login's name counts."""
    from flow_live import Live
    live = Live(f)
    c5 = f.start()
    c5.F.fillLog()
    N5 = c5.H.ns.UADD_Questie.Names
    c5.ev("function(N) return HARNESS.pump(2000, function() local a = N.Progress() return a and a > 0 end, 0.05) end")(N5)
    # UALLF shows English while its key (Shift) is held, so UALL says "not now": the collection
    # waits on the same name instead of saving it as a miss, then goes on.
    pump = c5.ev("function(n) return HARNESS.pump(n, nil, 0.05) end")
    c5.H["keys"].SHIFT = True
    held = N5.Progress()
    pump(400)
    f.check("shift held: collection waits", N5.Progress() == held, f"{held} -> {N5.Progress()}")
    c5.H["keys"].SHIFT = False
    pump(60)
    f.check("shift released: collection goes on", N5.Progress()[0] > held[0], str(N5.Progress()))
    c5.H.combat = True
    asked = N5.Progress()
    pump(400)
    paused = N5.Progress()
    f.check("combat: collection pauses", paused is not None and paused[0] == asked[0], f"{asked} -> {paused}")
    c5.H.combat = False
    c5.F.combatAtFinish()                        # 7b. ...and ends in combat: Questie waits too
    idle, _, _ = f.collect(c5)
    f.check("combat: collection resumes and finishes", idle)
    f.check("combat: same counts after combat", {k: int(N5.counts[k]) for k in counts} == counts)
    pump(200)
    f.check("combat at the end: no rebuild in combat", c5.H.combat and c5.F.resets == 0, str(c5.F.resets))
    c5.H.combat = False
    c5.H.fire("PLAYER_REGEN_ENABLED")
    c5.F.settle()
    f.check("after combat: Questie rebuilt once", c5.F.resets == 1, str(c5.F.resets))
    live.shown(c5, "after combat")
    # 7c. A rebuild that ends in combat, then /uadd questie off before combat is over: no rebuild.
    c5.slash("questie rebuild")
    c5.F.combatAtFinish()
    f.collect(c5)
    c5.slash("questie off")
    c5.H.combat = False
    c5.H.fire("PLAYER_REGEN_ENABLED")
    pump(200)
    f.check("off while waiting for combat to end: no rebuild", c5.F.resets == 1, str(c5.F.resets))
    f.no_errors(c5, "combat")
    globals_ok(f, c5, "combat session")


def globals_ok(f, cl, name):
    """8. Globals our files read but nobody defines; no Ukrainian in a font without its letters."""
    from loader import txt
    missing = [txt(x) for x in cl.lines(cl.H.listOf(cl.H.ourMissing))]
    f.check(f"globals: none undefined ({name})", not missing, ", ".join(missing))
    boxes = session.cyr_boxes(cl)
    f.check(f"guard: no Ukrainian text in a font without Ukrainian letters ({name})", not boxes, boxes[:3])
