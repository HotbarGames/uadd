"""UADD_WhatTheWhisper on a stand-in for WhatTheWhisper (tools/harness/whatthewhisper). Its English may not be
copied here (no licence): the stand-in's Shim.lua holds only what the addon's own files need first, the game runs
the installed addon's Namespace, locale, date, sound and export files (read only), and Stand.lua draws a made-up
window from them. Which keys its built-once texts use is read from the installed code at run time (feed()).

  * Game E (no module): its English: what "off" and the hold key must give back.
  * Game A: 1 ours on, hold key English, release ours, off English with its enUS table exactly as before, on ours
    (x2). 2 another language picked in its settings: nothing of ours, enUS exact; back: ours. 3 built-once texts
    (the options stub, dialog buttons, also those built after login, the emoji tabs) both ways; the stub's game
    fonts get Cyrillic while ours shows and their own font back when off (lesson 32). 4 binding names, export and
    sound labels, the date line and the list's stamp both ways; the game's WEEKDAY_* never written. 5 STAY texts
    stay English. 6 a switch in combat waits for PLAYER_REGEN_ENABLED (lesson 36); off in combat is never a mix;
    another language picked in combat shows none of ours. No half line (halves_mods.wtw). 7 five errors in its
    hooks turn it off, English back (lesson 19); then "/uadd wtw on" and another language picked: none of ours in
    its enUS table. Also: a built-once text whose Ukrainian another key shares (the emoji tab made after ours was
    in, the export labels) gets its own English back; the saved-file export (Export.ToFile) holds its English while
    ours shows. 8 labels its enUS table lacks (the profile panel's rows, also a popout made later and a panel shown
    again; settings captions) and the History page's size line: ours on, English held and off; a size in B, KB, MB
    ours, any other the whole line English. 9 Lines.lua: flow_wtw_lines.py.
  * Mutants (--prove, flow_wtw_steps.py): each step fails with its fix cut out.
"""
import os
import re
import sys
from pathlib import Path
from types import SimpleNamespace

import halves_mods
import session
from flow_pawn_game import cyr, diff, errors

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import hashtext  # noqa: E402
import key_text  # noqa: E402
import wtw_rules as R  # noqa: E402
import wtw_source as G  # noqa: E402
from flow import Check  # noqa: E402
from loader import Addon, Client, lua_str, read_text, txt  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
MODULE, TARGET, CMD = "UADD_WhatTheWhisper", "WhatTheWhisper", "wtw"
REAL = ("Core/Namespace.lua", "Core/Locale/Locale.lua", "Core/Locale/enUS.lua", "Core/Locale/ruRU.lua",
        "Core/Locale/deDE.lua", "Core/Util/Format.lua", "Modules/Sounds.lua", "Modules/Export.lua")
LIT = r'"((?:[^"\\]|\\.)*)"'


def addon_dir():
    return str(G.addon_dir())


def installed():
    return all(os.path.isfile(os.path.join(addon_dir(), f)) for f in REAL + ("Core/Core.lua", "UI/Dialogs.lua"))


def module_there():
    return os.path.isfile(os.path.join(session.REPO, MODULE, MODULE + ".toc"))


def _src(rel):
    with open(os.path.join(addon_dir(), rel), encoding="utf-8", errors="replace") as f:
        return f.read()


def feed():
    """Lua code setting WhatTheWhisperStandInFeed: the keys of its built-once texts, as its code names them."""
    core = _src("Core/Core.lua")
    stub = core[core.index("BuildOptionsStub()\n"):]
    body = re.search(r"body:SetText\(L\[" + LIT + r"\]\)", stub).group(1)
    button = re.search(r"button:SetText\(L\[" + LIT + r"\]\)", stub).group(1)
    binds = re.findall(r"_G\.BINDING_NAME_WHATTHEWHISPER_(\w+) = L\[" + LIT + r"\]", core)
    dialogs, parts = [], re.split(r'makeDialog\("(\w+)"', _src("UI/Dialogs.lua"))
    for name, seg in zip(parts[1::2], parts[2::2]):
        btns = [(f, t.group(1)) for f, body_ in re.findall(r"d\.(\w+) = ns\.Button\.Text\(d, \{(.*?)\}\)", seg, re.S)
                for t in [re.search(r"text = L\[" + LIT + r"\]", body_)]
                if t and not re.search(r"d\." + f + r":SetText\(", seg)]     # set again on each show: not built once
        if btns:
            dialogs.append((name, btns))
    recent = re.search(r'id = "recent", label = L\[' + LIT + r"\]", _src("UI/EmojiPicker.lua")).group(1)
    cats = re.findall(r'id = "(\w+)", label = ' + LIT, _src("Modules/Emoticons.lua"))
    # the profile panel's row labels, the History page's size line (its key), the settings captions its enUS lacks
    root = Path(addon_dir())
    profile = [t for t, _ in G._labels(root / G.PROFILE, "FIELDS")]
    size = re.search(r"L\[" + LIT + r"\]:format\(ns\.Format\.Bytes\(", _src("Core/Options.lua")).group(1)
    enus = {e for e, *_ in G.read_enus(root / G.LOCALE)}
    captions = [en for en, f, _ in G.missing(root, enus) if f == "Options.lua"]
    q = '"{}"'.format
    pick = _src("UI/IconPicker.lua")
    icon = {f: re.search(r"d\." + f + r":SetText\(L\[" + LIT, pick).group(1) for f in ("title", "hint", "empty", "reset")}
    export = re.search(r"d\.title:SetText\(L\[" + LIT + r"\] \.\. ", _src("UI/Dialogs.lua")).group(1)

    def ql(s):
        return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'
    return ("WhatTheWhisperStandInFeed = { stub = { body = %s, button = %s }, bindings = { %s }, dialogs = { %s }, "
            "emoji = { %s }, profile = { %s }, size = %s, captions = { %s }, "
            "icon = { %s }, export = %s }" % (
                q(body), q(button), ", ".join(f"{n} = {q(k)}" for n, k in binds),
                ", ".join("{ name = %s, buttons = { %s } }" % (q(n), ", ".join(
                    "{ %s, %s }" % (q(f), q(k)) for f, k in b)) for n, b in dialogs),
                ", ".join("{ %s, %s }" % (q(i), q(k)) for i, k in [("recent", recent)] + cats),
                ", ".join(map(ql, profile)), ql(size), ", ".join(map(ql, captions)),
                ", ".join(f"{f} = {ql(t)}" for f, t in icon.items()), ql(export)),
            len(dialogs))


class WtwClient(Client):
    """The stand-in's Shim.lua, then the installed addon's own files, then Stand.lua, as one addon."""

    def run_addon_files(self, a):
        if a.name != TARGET:
            return super().run_addon_files(a)
        state = self.H.addons[a.name]
        state.loading = True
        self.run_lua(a, "Shim.lua")
        real = SimpleNamespace(name=a.name, folder=addon_dir())
        for rel in REAL:
            self.run_lua(real, rel)
        self.run_lua(a, "Stand.lua")
        state.loading = False
        state.loaded = True


def game(module=True, cut=None, cuts=None):
    addons = [Addon(TARGET, os.path.join(HERE, "whatthewhisper", TARGET), session.FLAVOR)]
    addons += [Addon(n, os.path.join(session.REPO, n), session.FLAVOR) for n in ("UADD",) + ((MODULE,) if module else ())]
    c = WtwClient(addons, None, "enUS")
    c.lua.execute(read_text(os.path.join(HERE, "flow_wtw.lua")))
    c.lua.execute(read_text(os.path.join(HERE, "flow_wtw_lines.lua")))
    M = c.H.wtw
    code, n = feed()
    M.feed(lua_str(code))
    for name, (file, old, new) in (cuts or {}).items():
        M.addCut(lua_str(name), lua_str(file), lua_str(old), lua_str(new))
    M.cut = lua_str(cut) if cut else None
    c.start()
    c.H.pump(20)
    for i in range(n // 2 + 1, n + 1):          # the dialogs built after login
        M.build(i)
    M.picker()
    M.wait(0.3)
    return c, M


def snap(M):
    return {txt(k): txt(v) for k, v in M.snap().items()}


def enus_exact(M):
    n, _ = M.enusDiff()
    return int(n) == 0


def templates(en):
    """The half-line check's templates: each enUS key with a slot, its sorts from wtw_rules.SORTS (f: free name;
    v: a path or a player link, so the addon never puts other text there; u and unmarked: fed as they are)."""
    out = []
    for k, e in sorted(en.items()):
        toks = hashtext.tokens(e)
        slots = [t for t in toks if t[0] == "slot"]
        if not slots:
            continue
        sorts = key_text.sorts_from(R.SORTS, "L." + hashtext.djb2(e), e)
        free = {i: "Zorp" for i, s in enumerate(sorts, 1) if s == "f"}
        good = {i: "|Hplayer:Zorp|h[Zorp]|h" for i, s in enumerate(sorts, 1) if s == "v"}
        rx = re.compile("".join(re.escape(t[1]) if t[0] == "lit" else "(.*?)" for t in toks if t != ("slot", "%")), re.S)

        def args(t, rx=rx, sorts=sorts):
            m = rx.fullmatch(t)
            if not m:
                return None
            vals = list(m.groups())
            for v, s in zip(vals, sorts):
                if s == "v" and not ("|H" in v or "\\" in v or halves_mods.bgn_value(v)):
                    return None           # the addon puts only a value there: it never builds this text
            return vals
        out.append(halves_mods.tpl("L." + hashtext.djb2(e), e, free, good, key=k, args=args))
    return out


def run(check, facts):
    if not module_there() or not installed():
        halves_mods.wtw(check, None, [], halves_mods.SKIP)
        facts["note"] = "WhatTheWhisper or the module not there: skipped"
        return
    import flow_wtw_steps as S
    rows, _ = G.source(G.addon_dir())
    c, M = game(module=False)
    E = snap(M)
    facts["E_paths"] = tuple(txt(p) for p in M.stubPaths())
    S.E_EXPORT = S.table(M.exportFile())
    errors(c, check, "game E")
    del c, M
    c, M = game()
    A = snap(M)
    S.steps(check, facts, c, M, E, A)
    halves_mods.wtw(check, M, templates({k[2:]: k[2:] for k in E if k.startswith("L:")}))
    errors(c, check, "game A before the errors")
    S.faults(check, c, M, E)
    S.refaults(check, c, M, E, A)


def run_checks():
    """Every check of this file. Returns (checks, facts)."""
    checks, facts = [], {}

    def check(name, ok, detail=""):
        checks.append(Check("wtw: " + name, bool(ok), str(detail)))
    run(check, facts)
    return checks, facts


if __name__ == "__main__":       # alone: python3 tools/harness/flow_wtw.py [--prove]
    if "--prove" in sys.argv:
        import flow_wtw_steps as S
        sys.exit(S.prove())
    cs, fs = run_checks()
    for x in cs:
        print(("ok    " if x.ok else "FAIL  ") + x.name + (f"  [{x.detail[:400]}]" if x.detail else ""))
    print({k: v for k, v in fs.items() if k != "E_paths"})
    print(f"{sum(x.ok for x in cs)}/{len(cs)} passed")
    sys.exit(0 if all(x.ok for x in cs) else 1)
