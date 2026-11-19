"""The game for flow_pawn.py: Pawn's own locale and UI strings (read from the installed addon, never
copied) under the stand-in (tools/harness/pawn), UADD and UADD_Pawn, and the test Ukrainian made from
Pawn's English for keys the module's data lacks (words made Cyrillic; slots, colour codes, ": " kept)."""
import os
import re
import sys
from types import SimpleNamespace

import session

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import pawn_rules as R  # noqa: E402
import pawn_source  # noqa: E402
from loader import Addon, Client, lua_str, read_text, txt  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
MODULE = "UADD_Pawn"
TARGET = "Pawn"
REAL = ("Localization.lua", "UIStrings.lua")


def addon_dir():
    return str(pawn_source.addon_dir())


def installed():
    return all(os.path.isfile(os.path.join(addon_dir(), r)) for r in REAL)


def module_there():
    return os.path.isfile(os.path.join(session.REPO, MODULE, MODULE + ".toc"))


class PawnClient(Client):
    """Runs the installed Pawn's locale and UI strings (read only) before the stand-in."""

    def run_addon_files(self, a):
        if a.name == TARGET:
            self.H.addons[a.name].loading = True
            real = SimpleNamespace(name=a.name, folder=addon_dir())
            for rel in REAL:
                self.run_lua(real, rel)
        super().run_addon_files(a)


# ── Test Ukrainian, made from Pawn's English ─────────────────────────────────────────────────────

KEEP = re.compile(r"%%|%(?:\d+\$)?[-+ #0]*\d*(?:\.\d*)?[sdifx]|\|c[0-9a-fA-F]{8}|\|c(?:ff|FF)?|\|r|\|T[^|]*\|t"
                  r"|\|n|\|H[^|]*\|h|\|h")
WORD = re.compile(r"[A-Za-z]+")
ABC = "абвгдежзиклмнопрстуфхцчшщюя"


def _tag(i):
    out = "т"
    while True:
        out += ABC[i % len(ABC)]
        i //= len(ABC)
        if not i:
            return out


def test_line(en, i):
    """en with its words made Cyrillic (the first one unique to i); slots and codes kept."""
    first = [True]

    def word(_):
        if first[0]:
            first[0] = False
            return _tag(i)
        return "ук"
    out, pos = [], 0
    for m in KEEP.finditer(en):
        out += [WORD.sub(word, en[pos:m.start()]), m.group(0)]
        pos = m.end()
    return "".join(out + [WORD.sub(word, en[pos:])])


def test_data():
    """({path: (test Ukrainian, sort)} for each key the build would take, {path: Pawn's English})."""
    en, _ = pawn_source.read_locale(os.path.join(addon_dir(), "Localization.lua"))
    out = {}
    for i, (path, e) in enumerate(en.items()):
        s = R.sorts(path, e)
        if not R.keep(path, e)[0] or None in s:
            continue
        uk = test_line(e, i)
        if uk != e and not R.check(path, e, uk):
            out[path] = (uk, "".join(s))
    return out, en


# ── The game and reading it ──────────────────────────────────────────────────────────────────────

def game(data, target=True, module=True):
    addons = [Addon(TARGET, os.path.join(HERE, "pawn"), session.FLAVOR)] if target else []
    addons += [Addon(n, os.path.join(session.REPO, n), session.FLAVOR) for n in ("UADD",) + ((MODULE,) if module else ())]
    c = PawnClient(addons, None, "enUS")
    c.lua.execute(read_text(os.path.join(HERE, "flow_pawn.lua")))
    M = c.H.pawn
    for p, (uk, s) in data.items():
        M.put(lua_str(p), lua_str(uk), s)
    c.start()
    c.H.pump(60)
    return c, M


def cyr(s):
    return isinstance(s, str) and any("Ѐ" <= ch <= "ӿ" for ch in s)


def snap(M):
    return {txt(k): txt(v) for k, v in M.snap().items()}


def diff(a, b):
    return sorted(k for k in set(a) | set(b) if a.get(k) != b.get(k))


def fonts(M):
    bad, n = M.fonts()
    return [txt(x) for x in bad.values()], int(n)


def tip_lines(t):
    return [[txt(r[1]), txt(r[2]), bool(r[3]), bool(r[4])] for r in t.values()]


def errors(c, check, step):
    errs = c.errors()
    check(f"{step}: no Lua errors", not errs, "; ".join(f"{w}: {m[:160]}" for w, m, _ in errs[:3]))
