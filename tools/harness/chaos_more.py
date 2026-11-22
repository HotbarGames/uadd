"""The chaos test's cases that need games of their own (tools/harness/chaos.py runs them after the modules):

  * an Install that fails part-way (the k-th hooksecurefunc of a first run refused): no error reaches the
    game, every text whole, off gives the English back (no half-set hooks left working);
  * the addon missing, and loaded late (modules whose addon is only an OptionalDep);
  * an addon update that compares a locale string we swap (a static scan of the installed addons);
  * U.SafeCall flooded with 1000 errors of changing text and 1000 places: the report table stays bounded;
  * the UALL Forever probe: another addon's spy on the game's zone text never sees the probe as the game's.
"""
import os
import re

import chaos_mods
import session
from loader import Client, lua_str, read_text, txt

HERE = os.path.dirname(os.path.abspath(__file__))
OPTIONAL = {"UADD_DialogueUI": ("DialogueUI", "flow_dialogueui"), "UADD_GatherMate2": ("GatherMate2", None),
            "UADD_Scrap": ("Scrap", None)}
# Installed addon -> (module folder, the name its locale goes by in code). A compare of a locale string the
# module swaps breaks the addon's logic (it then compares our Ukrainian with its English).
COMPARES = {"Pawn": ("UADD_Pawn", r"PawnLocal(?:\.\w+)*"), "GatherMate2": ("UADD_GatherMate2", r"L"),
            "AutoPotion": ("UADD_AutoPotion", r"L"), "BagBrother": ("UADD_Bagnon", r"L"),
            "Bagnon": ("UADD_Bagnon", r"L")}
MAX_REPORTED = 50


def _uadd():
    return chaos_mods._repo("UADD")


def _ours_back(c, key):
    """The font strings UADD changed now; after "<key> off" those not back to their English."""
    C = c.lua.globals().CHAOS
    fss = [fs for fs in C.Touched(50).values()]
    c.slash(key + " off")
    c.H.pump(5)
    wrong = [txt(C.Orig(fs)) for fs in fss if txt(C.Text(fs)) != txt(C.Orig(fs))]
    c.slash(key + " on")
    return len(fss), wrong


def install_partway(check, spied, hooks, seed, only):
    """Each module built again with its install's middle hooksecurefunc refused."""
    from chaos import Run
    import chaos_cases as K
    for folder, target, build in chaos_mods.RECIPES:
        n = hooks.get(folder, 0)
        if (only and folder != only) or n < 2:
            continue
        spied.hook_fail = max(1, n // 2)
        try:
            c = build()
        except Exception as e:
            check(f"chaos: {folder} install fails part-way: its game still builds", False,
                  f"{type(e).__name__}: {str(e)[:120]} | hook {n // 2} of {n} refused | seed {seed}")
            continue
        finally:
            spied.hook_fail = None
        if c is None:
            continue
        r = Run(folder, target, c, check)
        r.base = 0
        e = r.errors()
        r.ok(f"install fails part-way (hook {n // 2} of {n}): no error reaches the game", not e, "; ".join(e[:2]))
        C = r.C
        half = [txt(C.Text(fs)) for fs in C.Touched(50).values() if K.half(txt(C.Text(fs)), txt(C.Orig(fs)))]
        r.ok("install fails part-way: every text whole", not half, "; ".join(h[:60] for h in half[:2]))
        if r.key:
            n_ours, wrong = _ours_back(c, r.key)
            r.ok(f"install fails part-way: off gives back the English ({n_ours} texts)", not wrong,
                 "; ".join(w[:50] for w in wrong[:2]))
        focus = c.lua.globals().GetCurrentKeyBoardFocus()
        r.ok("install fails part-way: the keyboard is free", focus is None)


def missing_and_late(check, seed, only):
    for folder, (target, flow) in OPTIONAL.items():
        if only and folder != only:
            continue
        name = f"chaos: {folder} its addon missing"
        c = Client([_uadd(), chaos_mods._repo(folder)], None, "enUS")
        c.start()
        c.H.pump(60)
        c.slash("/uadd")
        c.H.pump(5)
        e = [f"{w}: {m[:120]}" for w, m, tb in c.errors() if "UADD" in (w + m + tb)]
        check(name + ": no Lua error", not e, "; ".join(e[:2]) + f" | seed {seed}")
        check(name + ": the keyboard is free", c.lua.globals().GetCurrentKeyBoardFocus() is None)
        if not flow:
            continue
        F = __import__(flow)
        stand = F.STAND_IN
        c = Client([_uadd(), chaos_mods._repo(folder), stand], None, "enUS")
        c.lua.execute(read_text(os.path.join(HERE, flow + ".lua")))
        c.addons = c.addons[:2]
        c.start()
        c.H.pump(60)
        c.addons.append(stand)
        c.run_addon_files(stand)
        c.H.loadSaved("", stand.name)
        c.H.fire("ADDON_LOADED", stand.name)
        c.H.pump(30)
        if folder == "UADD_DialogueUI":
            c.H.dui.showAll()
            c.H.dui.wait(F.WAIT)
        e = [f"{w}: {m[:120]}" for w, m, tb in c.errors() if "UADD" in (w + m + tb)]
        late = f"chaos: {folder} its addon loaded after login"
        check(late + ": no Lua error", not e, "; ".join(e[:2]) + f" | seed {seed}")
        n = len(list(c.lua.globals().CHAOS.Touched(50).values()))
        check(late + ": its texts are translated", n > 0, f"no text changed | seed {seed}")


def locale_compares(check):
    """Every `== <locale>.key` in the installed addons (not their Libs): the key must not be swapped."""
    base = session.addons_dir()
    for addon, (folder, name) in COMPARES.items():
        root = os.path.join(base, addon)
        if not os.path.isdir(root):
            continue
        pat = re.compile(r"(?:==|~=)\s*%s(?:\.(\w+)|\[\"([^\"]+)\"\])|%s(?:\.(\w+)|\[\"([^\"]+)\"\])\s*(?:==|~=)"
                         % (name, name))
        keys = set()
        for d, subs, files in os.walk(root):
            subs[:] = [s for s in subs if s.lower() not in ("libs", "lib", "libraries")]
            for f in files:
                if f.endswith(".lua"):
                    for m in pat.finditer(read_text(os.path.join(d, f))):
                        keys.add(next(g for g in m.groups() if g))
        mod = os.path.join(session.REPO, folder)
        code = "".join(read_text(os.path.join(dd, f)) for dd, _, fs in os.walk(mod) for f in fs if f.endswith(".lua"))
        stay = "\n".join(x for x in code.splitlines() if re.search(r"STAY|DISPLAY|KEEP", x))
        swapped = sorted(k for k in keys if re.search(r'\[\s*"(?:[\w.]*\.)?%s"\s*\]\s*=' % re.escape(k), code)
                         and k not in stay)
        check(f"chaos: {folder} {addon} compares no locale string we swap ({len(keys)} compared)", not swapped,
              f"swapped and compared: {swapped[:4]}")


def safecall_flood(check):
    c = Client([_uadd()], None, "enUS")
    c.start()
    c.H.pump(5)
    places, lines, kb = c.lua.globals().CHAOS.SafeFlood(1000)
    check(f"chaos: U.SafeCall 2000 errors: at most {MAX_REPORTED} places kept", 0 <= int(places) <= MAX_REPORTED,
          f"{int(places)} places")
    check(f"chaos: U.SafeCall 2000 errors: at most {MAX_REPORTED} error lines in chat", int(lines) <= MAX_REPORTED,
          f"{int(lines)} lines")
    check("chaos: U.SafeCall 2000 errors: memory stays under 256 KB", kb < 256, f"{kb:.0f} KB")
    e = [m[:100] for w, m, tb in c.errors() if "chaos" in m]
    check("chaos: U.SafeCall 2000 errors: none reaches the game", not e, "; ".join(e[:2]))


def uallf_probe(check):
    c = Client([_uadd()], None, "enUS")
    c.H.addons["UALLF"] = c.lua.table_from({"meta": c.lua.table_from({}), "loaded": True})
    c.lua.execute("UALLFSettingsDB = { enabled = true }")
    c.start()
    c.H.pump(5)
    C = c.lua.globals().CHAOS
    seen = C.ZoneSpy()
    C.FakeUallf()
    ua = c.lua.globals().UADD.UALL.Zone(lua_str("Elwynn Forest"))
    ua = ua[0] if isinstance(ua, tuple) else ua      # Zone returns (Ukrainian, wait)
    mine, other, now = seen()
    check("chaos: UALL Forever probe works through a spied, hooked zone text", ua is not None and "Ельв" in txt(ua),
          f"got {txt(ua) if ua else None!r}")
    check("chaos: UALL Forever probe: a spy on the game's zone text never sees the probe as the game's text",
          int(mine) == 0 and txt(now) == "Chaos Zone", f"spy saw the game's string {int(mine)} times, it now says "
          f"{txt(now)!r} (another self: {int(other)})")


def run(check, notes, spied, seed, only, hooks=None):
    """The cases above. hooks=None: all but install part-way, which chaos.part runs per module (partway())."""
    cases = [("SafeCall flood", lambda: safecall_flood(check)), ("UALLF probe", lambda: uallf_probe(check)),
             ("locale compares", lambda: locale_compares(check)),
             ("addon missing or late", lambda: missing_and_late(check, seed, only))]
    for name, fn in cases:
        _case(check, name, fn, seed)
    if hooks is not None:
        partway(check, spied, hooks, seed, only)
        notes.append(covers(hooks))


def partway(check, spied, hooks, seed, only):
    _case(check, "install fails part-way", lambda: install_partway(check, spied, hooks, seed, only), seed)


def covers(hooks):
    return "chaos_more: install part-way covers " + ", ".join(sorted(f for f, n in hooks.items() if n >= 2))


def _case(check, name, fn, seed):
    try:
        fn()
    except Exception as e:      # one broken case is a failure here, the others still run
        check(f"chaos: {name} ran", False, f"{type(e).__name__}: {str(e)[:160]} | seed {seed}")
