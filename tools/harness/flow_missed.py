"""UADD/Missed.lua: the texts a module showed in English because it has no Ukrainian for them yet, noted
while you play (UADD_DB.missed) and listed after logout by tools/missed.py. Runs on the LayerSwap
stand-in (flow_lsw.py) with UADD_LayerSwap, plus made-up modules for the core rules. All English here is
made up ("Wobbly gizmo"); the stand-in's own texts are read at run time.

  * Off by default: nothing noted or stored, a module start reads nothing, and a note costs next to nothing.
  * Not noted: texts we translate, values, Cyrillic, long prose, the target addon's name, a module's
    `keep` texts, texts set in combat, a name UALL Forever knows; nothing at all while "/uadd missed off".
  * Noted once: a made-up text set again and again on one FontString, a chat line, "Level 5"/"Level 6".
  * Names out of texts: a link is <link>, a quoted name "<name>", a template slot with a name %s; a whole
    name goes to its own bucket with its own cap (500), so names never push texts out.
  * The caps (1000 per module, 3000 in all), "/uadd missed" on/off/clear, the prune on "on" and on module
    start, the saved file read back by tools/missed.py, and speed (a seen text costs little, no garbage).
"""
import collections
import gc
import os
import sys

import flow_lsw

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import missed  # noqa: E402
from loader import lua_str, read_text, txt  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
FAKE = "Wobbly gizmo panel"
SPEED_N = 10000
SPEED_MS = 60          # 2 x SPEED_N notes of a text already seen
SPEED_KB = 4           # garbage they may make in all
OFF_MS = 15            # 2 x SPEED_N notes while off (one boolean each)


def _game():
    c, L = flow_lsw._game([flow_lsw.STAND_IN, flow_lsw._addon("UADD"), flow_lsw._addon(flow_lsw.MODULE)])
    c.lua.execute(read_text(os.path.join(HERE, "flow_missed.lua")))
    return c, L, c.H.missed


def game(check, facts):
    c, L, M = _game()
    key = "layerswap"
    # Off by default: nothing noted, nothing stored, and a module start does not walk stored entries.
    on = c.lua.eval("UADD.MissedOn()")
    check("off by default", not on, on)
    M.note(key, lua_str("Wobbly gizmo while off"))
    check("off: an English text is not noted or stored", not M.stored(), M.count(key))
    ms, kb = M.speed(SPEED_N)
    facts["off_ms"] = round(ms, 2)
    check(f"off: {2 * SPEED_N} notes under {OFF_MS} ms, no garbage", ms < OFF_MS and kb < SPEED_KB,
          f"{ms:.1f} ms, {kb:.2f} KB")
    calls = M.plant("prunemod")
    check("off: a module start reads no stored entry", calls() == 0, calls())
    L.uadd("missed on")
    check("on: the stored entries are checked once, and kept", calls() == 1 and M.has("prunemod", "Old wobbly gizmo"),
          calls())
    # Texts we translate: the panel shown and refreshed by the stand-in for a few seconds.
    L.panel(True)
    L.wait(3.2)
    check("translated texts are not noted", M.count(key) == 0, M.count(key))
    # A made-up English text on a hooked FontString, set again and again: one entry, counted once.
    M.setHeading(FAKE, 5)
    L.wait(0.2)
    check("an English text is noted once", M.count(key) == 1 and M.times(key, FAKE) == 1,
          (M.count(key), M.times(key, FAKE)))
    check("its version is the addon's", txt(M.entryVersion(key, FAKE)) == txt(M.version(key)) == "0",
          (txt(M.entryVersion(key, FAKE)), txt(M.version(key))))
    L.panel(False)
    # A chat line the module has no words for.
    L.say("Wobbly gizmo chat line")
    check("an unknown chat line is noted", M.has(key, "Wobbly gizmo chat line"), M.count(key))
    # Combat: a miss then is not noted.
    M.inCombat(True)
    M.setHeading("Wobbly combat gizmo")
    L.wait(0.2)
    M.inCombat(False)
    check("a text set in combat is not noted", not M.has(key, "Wobbly combat gizmo"), M.count(key))

    # The core rules, on a made-up module (target: the stand-in, so its title stays quiet).
    t = "testmod"

    def note(k, text):
        M.note(k, lua_str(text))
    M.register(t)
    title = txt(c.lua.eval('UADD.Meta("LayerSwap", "Title")') or "")
    for quiet in ("1,234", "4h 03m", "12.3k", "+5%", "Гарний текст", "x" + " wobbly" * 60,
                  "Kept on purpose", title, "|cffff0000" + title + "|r", "", "!!"):
        note(t, quiet)
    check("values, Cyrillic, prose, title and keep texts are not noted", M.count(t) == 0, M.count(t))
    note(t, "Wobbly level 5")
    note(t, "Wobbly level 6")
    check("numbers make no new entry", M.count(t) == 1 and M.times(t, "Wobbly level 5") == 2,
          (M.count(t), M.times(t, "Wobbly level 5")))
    note(t, "|cff00ff00Gizmo green|r")
    check("a coloured English text is noted", M.has(t, "|cff00ff00Gizmo green|r"), M.count(t))

    # On and off.
    L.uadd("missed off")
    note(t, "Gizmo while off")
    note(t, "Wobbly level 5")
    check("off: nothing noted or counted",
          not M.has(t, "Gizmo while off") and M.times(t, "Wobbly level 5") == 2, M.count(t))
    L.uadd("missed on")
    note(t, "Gizmo while on")
    check("on again: noted", M.has(t, "Gizmo while on"), M.count(t))
    L.uadd("missed")
    out = " ".join(c.chat()[-3:])
    check("/uadd missed prints the counts", "testmod 3" in out and "layerswap 2" in out, out[-300:])

    # Names out of texts: links, quoted names, template slots; whole names in their own bucket.
    k = "maskmod"
    M.register(k)
    note(k, 'Wobbly gizmo says "Bob"')
    note(k, 'Wobbly gizmo says "Alice Smith"')
    check("quoted names make one entry", M.count(k) == 1 and M.times(k, 'Wobbly gizmo says "<name>"') == 2,
          (M.count(k), M.times(k, 'Wobbly gizmo says "<name>"')))
    note(k, "Wobbly gizmo got |cff1eff00|Hitem:123::|h[Shiny Bauble]|h|r")
    check("a link is noted as <link>", M.has(k, "Wobbly gizmo got |cff1eff00<link>|r"), M.count(k))
    M.indexed("idxmod")
    note("idxmod", "Bob wobbles at Old Mill")
    note("idxmod", "Alice wobbles at 12")
    note("idxmod", "Bob wobbles at the old mill on a rainy day")
    check("a template slot with a name or a value is %s",
          M.times("idxmod", "%s wobbles at %s") == 2 and M.has("idxmod", "%s wobbles at the old mill on a rainy day"),
          (M.count("idxmod"), M.times("idxmod", "%s wobbles at %s")))
    M.noteUall(k, "Gizmo Vale")
    check("a name UALL Forever knows is not noted", not M.has(k, "Gizmo Vale"), M.names(k))
    texts = M.count(k)
    M.floodNames(k, 520)
    check("names go to their own bucket, at most 500",
          M.names(k) == 500 and M.namesDropped(k) == 20 and M.count(k) == texts and M.dropped(k) == 0,
          (M.names(k), M.namesDropped(k), M.count(k)))

    # Caps: 1000 per module, 3000 in all; past that only a count.
    M.flood("capmod", 1, 1050)
    check("a module keeps at most 1000", M.count("capmod1") == 1000 and M.dropped("capmod1") == 50,
          (M.count("capmod1"), M.dropped("capmod1")))
    M.flood("bigmod", 4, 1000)
    check("all modules keep at most 3000", M.total() == 3000, M.total())
    size = c.lua.eval("UADD.MissedSessionSize()")
    check("the session cache stays bounded", 0 < size <= 4000, size)
    L.uadd("missed clear capmod1")
    check("clear one module", M.count("capmod1") == 0 and M.count(t) == 3, (M.count("capmod1"), M.count(t)))
    for b in range(1, 5):
        L.uadd(f"missed clear bigmod{b}")

    # Prune on start: an entry the module translates now goes, an unknown one stays.
    en = txt(L.en("swap"))
    M.restart(en, "Old wobbly gizmo")
    check("module start drops texts it translates now",
          not M.has(key, en) and M.has(key, "Old wobbly gizmo"), M.count(key))

    # Speed: a text already seen (the miss path of a text shown every second).
    ms, kb = M.speed(SPEED_N)
    facts["speed_ms"], facts["garbage_kb"] = round(ms, 2), round(kb, 2)
    check(f"{2 * SPEED_N} notes of a seen text under {SPEED_MS} ms", ms < SPEED_MS, f"{ms:.1f} ms")
    check(f"they make under {SPEED_KB} KB of garbage", kb < SPEED_KB, f"{kb:.2f} KB")
    facts["entries"] = M.total()

    # Logout: the saved file, read back as tools/missed.py reads it.
    saved = txt(c.dump_saved().get("UADD") or "")
    try:
        db = missed.parse(saved.encode("utf-8"))
        mods = missed.collect_db(db)
        ok = (FAKE in mods.get(key, {}).get("texts", {}) and "Wobbly level 5" in mods["testmod"]["texts"]
              and len(mods["maskmod"]["names"]) == 500 and "%s wobbles at %s" in mods["idxmod"]["texts"])
        check("tools/missed.py reads the saved file", ok, sorted(mods))
    except Exception as e:      # noqa: BLE001 - shown as a failed check
        check("tools/missed.py reads the saved file", False, f"{type(e).__name__}: {e}")
    errs = c.errors()
    check("no Lua errors", not errs, "; ".join(f"{w}: {m[:160]}" for w, m, _ in errs[:3]))


Check = collections.namedtuple("Check", "name ok detail")


def run_checks():
    """Every check of this file. Returns (checks, facts)."""
    checks, facts = [], {}

    def check(name, ok, detail=""):
        checks.append(Check("missed: " + name, bool(ok), str(detail)))
    if not flow_lsw.module_there():
        check("UADD_LayerSwap is there", False, "no UADD_LayerSwap/UADD_LayerSwap.toc")
    else:
        game(check, facts)
        gc.collect()
    return checks, facts


if __name__ == "__main__":       # alone: python3 tools/harness/flow_missed.py
    cs, fs = run_checks()
    for x in cs:
        print(("ok    " if x.ok else "FAIL  ") + x.name + (f"  [{x.detail}]" if x.detail else ""))
    print(fs)
    print(f"{sum(x.ok for x in cs)}/{len(cs)} passed")
    sys.exit(0 if all(x.ok for x in cs) else 1)
