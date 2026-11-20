"""The chaos test's steps for one module (tools/harness/chaos.py runs them in order on the module's game).

Each step takes r (chaos.Run: the game, the spies, the check) and the snapshot of the module's texts: a list
of (font string, the English as the addon set it).
"""
import os

import chaos_cases as K
from loader import lua_str, txt

SEED = int(os.environ.get("CHAOS_SEED", "20261120"))
N = int(os.environ.get("CHAOS_N", "3"))
ONLY = os.environ.get("CHAOS_ONLY", "")
MS = 5.0                 # the most one text may take
CACHE = 6000             # Words.lua LIMIT
KB = 512                 # Lua memory a second round of 10k unseen texts may leave (bounded caches: ~0)
IDLE = 600               # UADD's frame visits a minute with the addon's windows closed (10 a second)
IDLE_OPEN = 20000        # the same with its windows open and nothing new on them
SPARE = "Restore|Back|Stop|Off|Cancel|Forget|Unhook|Disable|Sync|Toggle|Command|Install|Start|Load"


def feeds(r, snap, rng):
    """Bad values and odd texts on up to 4 font strings, from the addon's own code."""
    fails, slow, escaped, n = [], [], [], 0
    for fs, en in snap[:4]:
        cases = K.fed(en, rng) + [("unseen", u) for u in K.unseen(rng, N)]
        for name, text in cases:
            raw = K.lua_bytes(text)
            ok, err, ms = r.C.Feed(r.target, fs, raw)
            n += 1
            out = r.C.Text(fs)
            if not ok:
                escaped.append(f"{name}: {txt(err)[:100]}")
            elif isinstance(out, str) and out != raw:
                why = K.half(txt(out), txt(raw))
                if why:
                    fails.append(f"{name} {en[:30]!r} -> {txt(out)[:60]!r}: {why}")
            if ms > MS:
                slow.append(f"{name} {ms:.1f} ms")
        for name, v in K.bad_values():
            ok, err, _ = r.C.Feed(r.target, fs, v)
            n += 1
            if not ok:
                escaped.append(f"{name}: {txt(err)[:100]}")
        r.C.Set(r.target, fs, lua_str(en))
    r.ok(f"feed {n} odd cases: no error reaches the caller", not escaped, "; ".join(escaped[:2]))
    r.ok("feed odd cases: no half line", not fails, "; ".join(fails[:2]))
    r.ok(f"feed odd cases: each under {MS:g} ms", not slow, "; ".join(slow[:3]))
    r.no_errors("feed odd cases")


def chat(r, en):
    """Chat lines of any kind from other code arrive unchanged; the addon's own arrive at all."""
    lost = []
    for v in (None, 42, 4.5, True, lua_str(en), lua_str("|cffff0000" + en + "|r"), "", lua_str("Вже " + en)):
        for src in ("ChaosOther", r.target):
            ok, err, got = r.C.Chat(src, v)
            want = "nil" if v is None else ("true" if v is True else (txt(v) if isinstance(v, str) else None))
            if not ok:
                lost.append(f"{src} {v!r}: error {txt(err)[:80]}")
            elif got is None:
                lost.append(f"{src} {v!r}: no line")
            elif src == "ChaosOther" and want is not None and txt(got) != want:
                lost.append(f"{src} {v!r}: became {txt(got)[:60]!r}")
            elif src == "ChaosOther" and isinstance(v, (int, float)) and not isinstance(v, bool) and float(txt(got)) != v:
                lost.append(f"{src} {v!r}: became {txt(got)!r}")
    r.ok("chat lines of any kind arrive (other code's unchanged)", not lost, "; ".join(lost[:3]))


def foreign(r, en, snap):
    """Other code's tooltip lines and font strings: no work for UADD (lesson 12)."""
    chat(r, en)
    # Its own words on the game tooltip, 5 fills: tipfont.segment (after the module) wants each line UADD
    # changed back on its font object, never pinned to a file (lesson 18).
    ok, err = r.C.OwnTip(r.target, 5, *[lua_str(e) for _, e in snap[:6]])
    r.ok("its own words on the game tooltip: no error reaches it", ok, txt(err))
    r.no_errors("its own words on the game tooltip")
    ok, err, tr, ds = r.C.Tip(50, lua_str("Zorp Blatter"), lua_str("Quibble Fen"))
    r.ok("another addon's tooltip, 50 fills: no error reaches it", ok, txt(err))
    r.ok("another addon's tooltip lines (not its words): no Translate, no debugstack", tr == 0 and ds == 0,
         f"Translate {tr}, debugstack {ds} for 150 lines: {r.C.Where()}")
    # Lines.lua by design: a line that reads like its words gets one (cached) Translate, then one source test.
    ok, err, tr, ds = r.C.Tip(50, lua_str(en), lua_str("Quibble Fen"))
    r.ok("another addon's tooltip lines that read like its words: at most one Translate and one source test a line",
         ok and tr <= 150 and ds <= 150, f"Translate {tr}, debugstack {ds} for 150 lines: {r.C.Where()}")
    ok, err, tr, ds = r.C.Foreign(200, lua_str(en))
    r.ok("another addon's font strings: no error reaches it", ok, txt(err))
    r.ok("another addon's 200 font strings: no Translate, no debugstack", tr == 0 and ds == 0,
         f"Translate {tr}, debugstack {ds}: {r.C.Where()}")
    ok, err = r.C.Forbidden(lua_str(en))
    r.ok("a forbidden frame with new font strings: nothing reaches its code", ok, txt(err))
    e = r.errors()
    r.ok("a forbidden frame: UADD never reads it", not e, "; ".join(e[:2]))


def stress(r, snap):
    """Off/on 100 times, the install run again, combat."""
    fs, en = snap[0]
    tr0 = r.tr_per_set(fs, en)
    hooks0 = int(r.C.hooks)
    for _ in range(100):
        r.c.slash(r.key + " off")
        r.c.slash(r.key + " on")
    r.H.pump(10)
    tr1, hooks1 = r.tr_per_set(fs, en), int(r.C.hooks)
    r.no_errors("off and on 100 times")
    r.ok("off and on 100 times: no hooks stacked", tr1 <= max(tr0, 1) and hooks1 - hooks0 <= 100,
         f"Translate per text {tr0} -> {tr1}, hooksecurefunc +{hooks1 - hooks0}")
    r.off_gives_english("off and on 100 times", snap)
    for ev, args in (("ADDON_LOADED", ("UADD",)), ("ADDON_LOADED", (r.folder,)), ("ADDON_LOADED", (r.target,)),
                     ("PLAYER_LOGIN", ()), ("PLAYER_ENTERING_WORLD", (False, True))):
        r.H.fire(ev, *args)
    r.H.pump(30)
    tr2 = r.tr_per_set(fs, en)
    r.no_errors("install run twice (/reload events again)")
    r.ok("install run twice: no hooks stacked", tr2 <= max(tr0, 1), f"Translate per text {tr0} -> {tr2}")
    r.off_gives_english("install run twice", snap)
    r.H.combat = True
    r.H.fire("PLAYER_REGEN_DISABLED")
    r.c.slash(r.key + " off")
    r.c.slash(r.key + " on")
    for f, e in snap:
        r.C.Set(r.target, f, lua_str(e))
    r.H.pump(20)
    r.H.combat = False
    r.H.fire("PLAYER_REGEN_ENABLED")
    r.H.pump(20)
    r.no_errors("in combat (InCombatLockdown true)")
    r.whole("in combat", snap)


def bulk(r, snap):
    """10k texts, a frame made late, UALL Forever rewriting after us."""
    fs, en = snap[0]
    ok, same, new, kb, most = r.C.Many(r.target, fs, lua_str(en), 10000)
    r.ok("the same text 10k times and 10k unseen: no error", ok)
    r.ok(f"10k texts: under {MS:g} ms each", same < MS and new < MS, f"same {same:.3f} ms, unseen {new:.3f} ms")
    r.ok(f"10k unseen texts: caches stay under {CACHE}", most <= CACHE, f"biggest cache {most}")
    r.ok(f"another 10k unseen texts: Lua memory grows under {KB} KB", kb < KB, f"{kb:.0f} KB")
    late = txt(r.C.Late(r.target, lua_str(en)))
    why = K.half(late, en)
    r.ok("a frame made after login: whole", not why, f"{late!r}: {why}")
    for f, e in snap:
        r.C.Rewriter(f)
    before = int(r.C.n.sets)
    r.C.counting = True
    for f, e in snap:
        r.C.Set(r.target, f, lua_str(e))
    r.C.counting = False
    sets = int(r.C.n.sets) - before
    r.no_errors("UALL Forever rewrites the same text after us")
    r.ok("UALL Forever rewrites after us: no loop", sets <= 10 * len(snap), f"{sets} SetText for {len(snap)} texts")
    r.whole("UALL Forever rewrites after us", snap)
    r.C.rewrite = False
    for f, e in snap:
        r.C.Set(r.target, f, lua_str(e))


def idle(r):
    """Idle minutes with the addon's windows open, then closed: UADD's frame visits stay in budget."""
    shown = [r.C.Idle(60) for _ in range(2)]
    where_shown = r.C.Where()            # C.Idle resets the places: read them before the next minute
    r.C.HideOwn(r.target)
    hidden = [r.C.Idle(60) for _ in range(2)]
    v = [int(x[0]) for x in shown + hidden]
    r.notes.append(f"{r.folder}: frame visits a minute, windows open {v[:2]}, closed {v[2:]}")
    r.ok(f"idle minute, windows open: frame visits under {IDLE_OPEN} and not rising",
         v[0] <= IDLE_OPEN and v[1] <= v[0] + 50, f"visits a minute {v[:2]}: {where_shown}")
    r.ok(f"idle minute, its windows closed: frame visits under {IDLE}", max(v[2:]) <= IDLE,
         f"visits a minute {v[2:]}: {r.C.Where()}")
    r.ok("idle minutes: no debugstack, no Translate", all(x[1] == 0 and x[2] == 0 for x in shown + hidden),
         f"{[(int(x[1]), int(x[2])) for x in shown + hidden]}")


def throw(r, snap):
    """UADD's own code throws: the addon's text must stay English (or whole) and its code must not see it."""
    n0 = len(r.c.chat())
    for fs, en in snap:
        r.C.Set(r.target, fs, lua_str(en))
    r.H.pump(10)
    good = [txt(r.C.Text(fs)) for fs, _ in snap]
    broke = r.C.Break(r.folder, "^%u", 1, SPARE)
    escaped = []
    for fs, en in snap:
        ok, err, _ = r.C.Feed(r.target, fs, lua_str(en))
        if not ok:
            escaped.append(txt(err)[:100])
    r.H.pump(20)
    r.ok(f"its code throws ({broke} functions): no error reaches the caller", not escaped, "; ".join(escaped[:2]))
    r.whole("its code throws", snap)
    r.off_gives_english("its code throws", snap)
    e = r.errors()
    r.ok("its code throws (also off and on): nothing reaches the game's error handler", not e, "; ".join(e[:2]))
    r.C.Unbreak()
    lines = int(r.C.Errlines(n0))
    r.ok("its code throws: few error lines in chat", lines <= 5, f"{lines} lines")
    stuck = txt(r.C.Stuck(r.folder))
    r.ok("after the throw: no busy flag left set", not stuck, stuck)
    # A module Safe.lua turned off after the throws comes back on with /uadd <key> on.
    r.slash(r.key + " on", 10)
    for fs, en in snap:
        r.C.Set(r.target, fs, lua_str(en))
    r.H.pump(10)
    back = [(g, txt(r.C.Text(fs))) for g, (fs, _) in zip(good, snap) if txt(r.C.Text(fs)) != g]
    r.ok("after the throw and on again: each text as before the throw", not back, f"{len(back)}: {back[:2]}")
    r.no_errors("after the throw")


def locale(r, snap, rng):
    """An addon update: some of its locale strings changed, renamed or removed; then off and on."""
    n = int(r.C.Mutate(r.target, 7, rng.randrange(7)))
    if not n:
        r.notes.append(f"{r.folder}: no locale table found for the update case")
        return
    r.slash(r.key + " off", 10)
    r.slash(r.key + " on", 10)
    for fs, en in snap:
        r.C.Set(r.target, fs, lua_str(en))
    r.H.pump(20)
    r.no_errors(f"its locale changed ({n} strings)")
    r.whole("its locale changed", snap)
    r.off_gives_english("its locale changed", snap)
