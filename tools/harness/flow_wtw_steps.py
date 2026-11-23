"""The steps of flow_wtw.py (UADD_WhatTheWhisper), each on game A after login; and --prove: each step fails on a
fresh game with one fix of the module cut out (in memory, flow_wtw.lua M.cut)."""
import flow_wtw as F
from flow_pawn_game import cyr, diff
from flow_wtw_gaps import gaps
from loader import lua_str, txt

STEPS = {
    "loop": "1 on ours, hold key English, release ours, off English with the enUS table exact, on ours (x2)",
    "locale": "2 another language in its settings: nothing of ours, enUS exact; English again: ours",
    "once": "3 built-once texts (stub, dialog buttons, also built after login, emoji tabs) both ways",
    "font": "3 the stub's game fonts: Cyrillic while ours shows, their own font object and file back when off "
            "(also after its Russian)",
    "copies": "4 binding names, sound and export labels, date line and list stamp both ways; WEEKDAY_* untouched",
    "stay": "5 STAY texts stay English while on",
    "combat": "6 a switch in combat waits for PLAYER_REGEN_ENABLED, off in combat is never a mix (lesson 36)",
    "langcombat": "6 another language picked in combat: none of ours through its L at once; after: enUS exact",
    "dups": "3 a built-once text whose Ukrainian another key shares (emoji tab made after ours was in, export "
            "labels) gets its own English back, held and off",
    "export": "4 the saved-file export holds its English (sender, day lines) while ours shows",
    "faults": "7 five errors in its code turn it off for the session, English back (lesson 19)",
    "refaults": "7 after the off for errors, /uadd wtw on: ours; another language picked: none of ours, enUS exact; "
                "English again: ours (lesson 19)",
}


def _ours(A, E, prefix):
    return [k for k in A if k.startswith(prefix) and A[k] != E.get(k) and cyr(A[k])]


def loop(check, c, M, E, A):
    bad = []
    for i in range(2):
        for how, want in (("hold", E), ("release", A), ("off", E), ("on", A)):
            M.key(how == "hold") if how in ("hold", "release") else M.uadd("wtw " + how)
            M.wait(0.2)
            d = diff(want, F.snap(M))
            if d or (how in ("off", "hold") and not F.enus_exact(M)):
                bad.append((i + 1, how, d[:3], M.enusDiff()))
    n = len(_ours(A, E, "L:"))
    ok = n >= 300 and not bad
    check(f"{STEPS['loop']} ({n} lines ours)", ok, bad[:3] or n)
    return ok


def locale(check, c, M, E, A):
    code = txt(M.locale(lua_str("ruRU")))
    R = F.snap(M)
    ru = {k: txt(M.ru(lua_str(k[2:]))) for k in R if k.startswith("L:")}   # its own Russian may match ours
    ru.update({k: txt(M.ruRow(int(k.rsplit(":", 1)[1]))) for k in R if k.startswith("R:")})
    ours = [k for k in R if R[k] != E.get(k) and R[k] == A.get(k) and cyr(R[k]) and R[k] != ru.get(k)]
    exact, was = F.enus_exact(M), M.enusDiff()
    back = txt(M.locale(lua_str("auto")))
    d = diff(A, F.snap(M))
    ok = code == "ruRU" and not ours and exact and back == "enUS" and not d
    check(STEPS["locale"], ok, (code, ours[:3], was, back, d[:3]))
    return ok


def once(check, c, M, E, A):
    keys = [k for k in E if k[:2] in ("P:", "G:", "E:")]
    eng = [k for k in keys if not cyr(A[k])]
    M.key(True)
    held = diff({k: E[k] for k in keys}, {k: v for k, v in F.snap(M).items() if k in keys})
    M.key(False)
    M.uadd("wtw off")
    off = diff({k: E[k] for k in keys}, {k: v for k, v in F.snap(M).items() if k in keys})
    M.uadd("wtw on")
    on = diff({k: A[k] for k in keys}, {k: v for k, v in F.snap(M).items() if k in keys})
    ok = len(keys) >= 8 and any(k.startswith("E:") for k in keys) and not eng and not held and not off and not on
    check(f"{STEPS['once']} ({len(keys)} texts)", ok, (eng[:3], held[:2], off[:2], on[:2]))
    return ok


def font(check, c, M, E, A, facts=None):
    M.locale(lua_str("ruRU"))           # its Russian is Cyrillic too: our font stays, its record must too
    M.locale(lua_str("auto"))
    body, body_cyr, _, btn, btn_cyr = M.stubFont()
    M.uadd("wtw off")
    obody, _, obj, obtn, _ = M.stubFont()
    was = (facts or {}).get("E_paths") or F.E_PATHS
    M.uadd("wtw on")
    ok = body_cyr and btn_cyr and obj and (txt(obody), txt(obtn)) == tuple(was)
    check(STEPS["font"], ok, (txt(body), body_cyr, txt(btn), btn_cyr, txt(obody), obj, txt(obtn), was))
    return ok


def copies(check, c, M, E, A):
    groups = {p: [k for k in E if k.startswith(p)] for p in ("B:", "X:sound:", "X:export:", "D:")}
    need = {"B:": 2, "X:sound:": 10, "X:export:": 1, "D:": 11}    # its name and the plain dates stay
    got = {p: len(_ours(A, E, p)) for p in groups}
    same, day = M.weekdaysSame()
    M.uadd("wtw off")
    keys = [k for p in groups for k in groups[p]]
    off = diff({k: E[k] for k in keys}, {k: v for k, v in F.snap(M).items() if k in keys})
    same2, _ = M.weekdaysSame()
    M.uadd("wtw on")
    ok = all(got[p] >= need[p] for p in need) and same and same2 and not off
    check(f"{STEPS['copies']} {got}", ok, (got, day, off[:3]))
    return ok


def stay(check, c, M, E, A):
    import wtw_source as G
    keys = list(G.stay_texts(G.addon_dir()))
    bad = [k for k in keys if A.get("L:" + k) != k]
    ok = len(keys) >= 5 and not bad
    check(f"{STEPS['stay']} ({len(keys)})", ok, bad[:3])
    return ok


def combat(check, c, M, E, A):
    M.combat(True)
    M.uadd("wtw off")
    now = F.snap(M)
    still = diff(A, now) and diff(E, now)     # all ours until combat ends, or all English: never a mix
    M.combat(False)
    after = diff(E, F.snap(M))
    M.uadd("wtw on")
    M.combat(True)
    M.key(True)
    held = diff(A, F.snap(M))
    M.combat(False)
    eng = diff(E, F.snap(M))
    M.key(False)
    ok = not still and not after and not held and not eng
    check(STEPS["combat"], ok, (still[:2], after[:2], held[:2], eng[:2]))
    return ok


def langcombat(check, c, M, E, A):
    M.combat(True)
    code = txt(M.locale(lua_str("deDE")))
    n, first = M.cyrL()
    days = [k for k, v in F.snap(M).items() if k.startswith("D:") and cyr(v)]
    M.combat(False)
    exact, drawn = F.enus_exact(M), [k for k, v in F.snap(M).items() if k.startswith("L:") and cyr(v)]
    back = txt(M.locale(lua_str("auto")))
    d = diff(A, F.snap(M))
    ok = code == "deDE" and int(n) == 0 and not days and exact and not drawn and back == "enUS" and not d
    check(STEPS["langcombat"], ok, (code, int(n), first and txt(first), days[:2], exact, drawn[:2], back, d[:2]))
    return ok


def dups(check, c, M, E, A):
    by = {}
    for k, v in A.items():
        if k.startswith("L:") and cyr(v):
            by.setdefault(v, []).append(k)
    two = {v for v, ks in by.items() if len(ks) > 1}
    objs = [k for k in A if (k[:2] in ("P:", "G:", "E:") or k.startswith("X:export:")) and A[k] in two]
    bad = []
    for how in ("hold", "off"):
        M.key(True) if how == "hold" else M.uadd("wtw off")
        s = F.snap(M)
        bad += [(how, k) for k in objs if s.get(k) != E[k]]
        M.key(False) if how == "hold" else M.uadd("wtw on")
    ok = bool(objs) and not bad
    check(f"{STEPS['dups']} ({len(two)} shared words, {len(objs)} built-once texts)", ok, bad[:3] or objs)
    return ok


def table(t):
    return {txt(k): txt(v) for k, v in t.items()}


E_EXPORT = None


def export(check, c, M, E, A):
    on = table(M.exportFile())
    M.uadd("wtw off")
    off = table(M.exportFile())
    M.uadd("wtw on")
    was = E_EXPORT or off
    cy = [f for f, t in on.items() if cyr(t) or t.startswith("failed")]
    other = [f for f in on if on[f] != was.get(f) or off[f] != was.get(f)]
    shown = diff(A, F.snap(M))
    ok = len(on) >= 3 and not cy and not other and not shown
    check(f"{STEPS['export']} ({len(on)} formats)", ok, (cy, other, "off as game E" if off == was else "off differs",
                                                       shown[:2]))
    return ok


def faults(check, c, M, E, A=None):
    M.wait(4)
    M.throw(5)
    for _ in range(3):
        M.key(True)
        M.key(False)
    left = int(M.thrown())
    M.throw(0)
    M.wait(0.3)
    d = diff(E, F.snap(M))
    said = "\n".join(c.chat()[-8:])
    M.key(True)
    M.key(False)
    d2 = diff(E, F.snap(M))
    ok = left == 0 and not M.on() and "вимкнено до кінця сесії" in said and not d and not d2 and F.enus_exact(M)
    check(STEPS["faults"], ok, (left, M.on(), d[:3], d2[:2], said[-200:]))
    return ok


def refaults(check, c, M, E, A):
    """After faults (run here first on a fresh game): on again, then another language picked in its list."""
    if M.on():
        faults(lambda *a: None, c, M, E)
    turned = not M.on()
    M.uadd("wtw on")
    M.wait(0.3)
    on = diff(A, F.snap(M))
    code = txt(M.locale(lua_str("deDE")))
    n, first = M.cyrL()
    exact, drawn = F.enus_exact(M), [k for k, v in F.snap(M).items() if k.startswith("L:") and cyr(v)]
    back = txt(M.locale(lua_str("auto")))
    d = diff(A, F.snap(M))
    ok = turned and not on and code == "deDE" and int(n) == 0 and exact and not drawn and back == "enUS" and not d
    check(STEPS["refaults"], ok, (turned, on[:2], code, int(n), first and txt(first), exact, drawn[:2], back, d[:2]))
    return ok


def steps(check, facts, c, M, E, A):
    F.E_PATHS = facts.get("E_paths")
    for fn in (loop, locale, once, copies, stay, combat, langcombat, dups, export, gaps):
        fn(check, c, M, E, A)
    font(check, c, M, E, A, facts)


# cut -> (file, the module's exact code, what it becomes, the step it must break)
CUTS = {
    "off": ("Swap.lua", "            if rawget(base, k) == ua then rawset(base, k, k) end\n", "", loop),
    "hold": ("Module.lua", '    return ns.On() and not U.originalShown and ns.Swap.Active() == "enUS"\n',
             '    return ns.On() and ns.Swap.Active() == "enUS"\n', loop),
    "locale": ("Module.lua", '    return ns.On() and not U.originalShown and ns.Swap.Active() == "enUS"\n',
               "    return ns.On() and not U.originalShown\n", locale),
    "once": ("Module.lua", "    U.SafeCall(on and ns.Screen.Apply or ns.Screen.Restore)\n", "    U.SafeCall(ns.Screen.Restore)\n",
             once),
    "font": ("Screen.lua", "then FontOn(fs) else FontOff(fs) end\n", "then FontOff(fs) else FontOff(fs) end\n", font),
    # the record dropped while its Russian kept our font: ours stays on its English after off
    "fontkeep": ("Screen.lua", "not U.IsCyrFont(was.path) then fonts[fs] = was end\n", "false then end\n", font),
    "bindings": ("Swap.lua", "            PutGlobal(name, ua)\n", "", copies),
    "days": ("Module.lua", "    U.SafeCall(ns.Days.Install)\n", "", copies),
    # its data has no Ukrainian for a STAY key, so the cut also gives each one a word, as a bad build would
    "stay": ("Swap.lua", "    if STAY[h] then return true end\n", '    if STAY[h] then ns.AL[h] = "Наше" end\n', stay),
    "combat": ("Module.lua", "        if U.AfterCombat(Try) then return end\n", "", combat),
    "langcombat": ("Module.lua", "    if not on then U.SafeCall(ns.Swap.SwapOut) end\n", "", langcombat),
    "export": ("Swap.lua", "    E.ToFile = fn\n", "", export),
    "faults": ("Module.lua", "    U.SafeCall(ns.Groups.Remove)\n    Apply(false)\nend\n",
               "    U.SafeCall(ns.Groups.Remove)\nend\n", faults),
    # the language-list hook under U.Safe again: dead after the off for errors, so ours stays in its enUS table
    "guard": ("Module.lua", 'hooksecurefunc(O, "Apply", Guard(AfterApply))',
              'hooksecurefunc(O, "Apply", U.Safe("wtw", AfterApply))', refaults),
    # the emoji tab's own category label taken away: a shared word alone cannot find its key
    "dups": ("Screen.lua", "U.SafeCall(Button, c, Category(c.categoryID))", "U.SafeCall(Button, c)", dups),
    # Gaps.lua: no KB; no size line of ours; panels made later not seen; ours also while held or off (rows, size)
    "gapswant": ("Gaps.lua", "            if want and not was then\n", "            if not was then\n", gaps),
    "gapsheld": ("Gaps.lua", '        if type(en) ~= "string" or not Want() then return en end\n',
                 '        if type(en) ~= "string" then return en end\n', gaps),
    "gapsunits": ("Gaps.lua", '{ "^(%d+%.%d) KB$", "%s КБ" }, ', "", gaps),
    "gapssize": ("Gaps.lua", "        SizeRow(spec)\n", "", gaps),
    "gapsnew": ("Gaps.lua", "        P.New = news.fn\n", "", gaps),
}
E_PATHS = None


def prove():
    """Each cut: a fresh game without that fix; the step must fail. Returns the exit code."""
    c, M = F.game(module=False)
    E = F.snap(M)
    F.E_PATHS = tuple(txt(p) for p in M.stubPaths())
    del c, M
    cuts = {k: v[:3] for k, v in CUTS.items()}
    bad = []
    for name, (_, _, _, step) in CUTS.items():
        got = []
        c, M = F.game(cut=name, cuts=cuts)
        A = F.snap(M)
        ok = step(lambda n, o, d="": got.append(o), c, M, E, A)
        cut = bool(M.wasCut)
        print(("ok    " if cut and ok is False else "FAIL  ") + f"cut {name}: cut={cut}, step {step.__name__} ok={ok}")
        if not (cut and ok is False):
            bad.append(name)
    print(f"{len(CUTS) - len(bad)}/{len(CUTS)} cuts break their step")
    return 1 if bad else 0
