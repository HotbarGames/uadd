"""UADD_Scrap on a stand-in for Scrap (tools/harness/scrap). Scrap's licence allows none of its English here:
the game runs the installed Scrap's LibStub, AceLocale and enUS locale file (read only) before the stand-in,
and the flow hands over the four texts its settings code writes (scrap_source.code_texts) at run time.
Scrap_Config and Scrap_Merchant load on demand, after login, as in the game. The rows that stay English (chat
lines with an item link) get test Ukrainian in the module's data (flow_scrap.lua), so taking STAY out shows.

  * Game E (no UADD_Scrap): Scrap's English: what "off" must give back.
  * Game A (on at login): 1 all of it ours: locale table, key binding names, settings pages (names, rows,
    tips, buttons), the junk list, the merchant button's tooltip, the tutorial, the pop-up, the money lines;
    the game's words stay. 2 Chat lines with an item link stay English. 3 Hold key, off and on, three times:
    English exactly, then ours exactly. 4 Our font, read back, on every text with Cyrillic and on no other,
    also on the pages and list that load later. 5 Patron and item names never change (one is named like a
    button, one like a tab). 6 A foreign tooltip and chat line cost no work of ours. 7 No half line.
  * Game B: no Scrap (the module waits).
"""
import os
import sys
from types import SimpleNamespace

import halves_mods
import session
from flow_pawn_game import cyr, diff, errors

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import scrap_source as G  # noqa: E402
from flow import Check  # noqa: E402
from loader import Addon, Client, lua_str, read_text, txt  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
MODULE, TARGET = "UADD_Scrap", "Scrap"
LATER = ("Scrap_Config", "Scrap_Merchant")
REAL = ("libs/LibStub/LibStub.lua", "libs/AceLocale-3.0/AceLocale-3.0.lua", "localization/en.lua")
STAY = {"L.Added": "Тест %s", "L.Removed": "Тест %s", "L.Forgotten": "Тест %s", "L.Destroyed": "Тест %s %s"}


def addon_dir():
    return str(G.addon_dir())


def installed():
    return all(os.path.isfile(os.path.join(addon_dir(), *r.split("/"))) for r in REAL + (G.OPTIONS,))


def module_there():
    return os.path.isfile(os.path.join(session.REPO, MODULE, MODULE + ".toc"))


class ScrapClient(Client):
    """Runs the installed Scrap's LibStub, AceLocale and locale file first; its two LoD parts after login."""

    def run_addon_files(self, a):
        if a.name == TARGET:
            self.H.addons[a.name].loading = True
            real = SimpleNamespace(name=a.name, folder=addon_dir())
            for rel in REAL:
                self.run_lua(real, rel)
        super().run_addon_files(a)

    def start(self):
        self.later = [a for a in self.addons if a.name in LATER]
        self.addons = [a for a in self.addons if a.name not in LATER]
        super().start()
        self.H.pump(20)
        for a in self.later:
            self.addons.append(a)
            self.run_addon_files(a)
            self.H.loadSaved("", a.name)
            self.H.fire("ADDON_LOADED", a.name)
            self.H.pump(5)


def words():
    """(the four code texts and an item named like a tab, {row: English} of the locale table)."""
    a = G.addon_dir()
    en = {row: e for row, e, _ in G.read_locale(a / G.LOCALE)}
    code = [e for e, _ in sorted(G.code_texts(a), key=lambda x: x[1])]
    return code + [en.get("L.Junk", "QUIX")], en


def game(code, target=True, module=True):
    addons = [Addon(n, os.path.join(HERE, "scrap", n), session.FLAVOR) for n in (TARGET,) + LATER] if target else []
    addons += [Addon(n, os.path.join(session.REPO, n), session.FLAVOR) for n in ("UADD",) + ((MODULE,) if module else ())]
    if target:
        addons = addons[:1] + addons[3:] + addons[1:3]
    c = ScrapClient(addons, None, "enUS")
    c.lua.execute(read_text(os.path.join(HERE, "flow_scrap.lua")))
    M = c.H.scrap
    if target:
        M.code(*[lua_str(x) for x in code])
    for row, uk in STAY.items():
        M.put(lua_str(row), lua_str(uk))
    c.start()
    c.H.pump(20)
    return c, M


def snap(M):
    return {txt(k): (txt(v) if isinstance(v, (str, bytes)) else v) for k, v in M.snap().items()}


def loop(check, M, en, uk):
    bad = []
    for i in range(3):
        for how, want in (("hold", en), ("release", uk), ("off", en), ("on", uk)):
            if how in ("hold", "release"):
                M.key(how == "hold")
            else:
                M.uadd("scrap " + how)
            d = diff(want, snap(M))
            n = int(M.count()) + (int(M.fontCount()) if how == "off" else 0)
            if d or (how in ("off", "hold") and n):
                bad.append((i + 1, how, d[:3], n))
    check("3 hold key, off, on (x3): English exactly (bindings, page names too), then ours exactly",
          not bad, bad[:3])


def game_a(check, facts, code, en, E):
    c, M = game(code)
    A = snap(M)
    texts = [k for k in A if k[0] in "LBRVMUPH" and not k.endswith(".w")]
    notcyr = [k for k in texts if k[0] != "L" and not cyr(A[k])]
    want = {k: M.want(lua_str(k[2:] if k.startswith("L:FAQ.") else "L." + k[2:])) for k in texts if k[0] == "L"}
    wrong = [k for k, w in want.items() if w is not None and txt(w) != A[k]]
    kinds = {k[0] for k in diff(E, A)}
    game_words = [k for k in E if k[0] == "G"]
    check("1 all ours: locale table, bindings, pages (names, rows, tips, buttons), junk list, merchant tooltip, "
          "tutorial, pop-up, money lines; the game's words stay",
          set("LBRVMUPH") <= kinds and not notcyr and not wrong and game_words
          and all(A.get(k) == E[k] for k in game_words),
          (sorted(kinds), notcyr[:4], wrong[:3], [k for k in game_words if A.get(k) != E[k]][:3]))
    facts["texts"], facts["changed"], facts["test_rows"] = len(texts), len(diff(E, A)), len(M.used)

    stay = [k for k in E if k[0] == "S"]
    check(f"2 chat lines with an item link stay English ({len(stay)} rows and lines, {len(M.used)} with test "
          "Ukrainian)", len(stay) == 8 and len(M.used) == 4 and all(A.get(k) == E[k] and not cyr(A[k]) for k in stay),
          [(k, A.get(k)) for k in stay if A.get(k) != E[k]][:3])

    bad, n, pages, lst = M.fonts()
    bad = [txt(x) for x in bad.values()]
    check(f"4 our font read back: on every Cyrillic text, on no other ({int(n)} texts; pages and list loaded "
          f"later: {int(pages)}, {int(lst)})", not bad and int(pages) > 10 and int(lst) >= 4, bad[:4])

    names = [k for k in E if k[0] == "N"]
    join = [k for k in A if k.startswith("R:Credits.") and E.get(k) == code[3]]
    check(f"5 patron and item names never change ({len(names)}); the button named like a patron is ours",
          len(names) >= 7 and all(A.get(k) == E[k] for k in names) and join and cyr(A[join[0]]),
          ([k for k in names if A.get(k) != E[k]][:3], join))

    foreign, ours = M.cheap()
    check(f"6 a foreign tooltip and chat line cost no work of ours (calls: {int(foreign)}; ours: {int(ours)})",
          int(foreign) == 0 and int(ours) > 0, (foreign, ours))

    loop(check, M, E, A)
    halves_mods.scrap(check, M, en)
    errors(c, check, "game A")


def game_b(check):
    c, M = game([], target=False)
    c.slash("uadd scrap")
    out = [x for x in c.chat() if "Scrap" in x and "чекає" in x]
    check("game B (no Scrap): the module waits", out, c.chat()[-3:])
    errors(c, check, "game B")


def run(check, facts):
    if not module_there() or not installed():
        halves_mods.scrap(check, None)
        facts["note"] = "Scrap or the module not there: skipped"
        return
    code, en = words()
    if len(code) != 5:
        check("the installed Scrap's settings code writes four texts", False, len(code) - 1)
        return
    c, M = game(code, module=False)
    E = snap(M)
    errors(c, check, "game E")
    game_a(check, facts, code, en, E)
    game_b(check)


def run_checks():
    """Every check of this file. Returns (checks, facts)."""
    checks, facts = [], {}

    def check(name, ok, detail=""):
        checks.append(Check("scrap: " + name, bool(ok), str(detail)))
    run(check, facts)
    return checks, facts


if __name__ == "__main__":       # alone: python3 tools/harness/flow_scrap.py
    cs, fs = run_checks()
    for x in cs:
        print(("ok    " if x.ok else "FAIL  ") + x.name + (f"  [{x.detail[:400]}]" if x.detail else ""))
    print(fs)
    print(f"{sum(x.ok for x in cs)}/{len(cs)} passed")
    sys.exit(0 if all(x.ok for x in cs) else 1)
