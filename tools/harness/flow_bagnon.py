"""UADD_Bagnon on stand-ins for Bagnon and Bagnon_Config (tools/harness/bagnon). The stand-ins hold none
of Bagnon's English: before their own files, BgnClient runs the installed BagBrother's LibStub,
AceLocale-3.0 and its two en.lua locale files, so every word comes from Bagnon's own AceLocale tables.
The expected Ukrainian is the module's own data (ns.BGN, read by M.want in flow_bagnon.lua).

  * A plain game (no UADD): what Bagnon shows in English (the base).
  * Game A (English client): Bagnon, UADD, UADD_Bagnon; Bagnon_Config loads after login, as in the game.
    Our words reach both tables (the config one through the NewLocale wrapper), the words read at load
    (window titles, rules, key bindings, page titles and subtitles) and the screen; three lines whose
    English changed (src hash) stay English; fonts read back, also on the bank window made later; the
    hold key and "/uadd bagnon off" give the base back, key up and "on" give ours again; no half-
    translated line; the speed of the miss paths.
  * Game B: no Bagnon (the module waits).
"""
import collections
import gc
import os
import sys
from types import SimpleNamespace

import halves_mods
import session

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import hashtext  # noqa: E402
import make_bgn_text  # noqa: E402
from loader import Addon, Client, read_text, txt  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
MODULE = "UADD_Bagnon"
LATER = "Bagnon_Config"
REAL = {"Bagnon": ("libs/LibStub/LibStub.lua", "libs/AceLocale-3.0/AceLocale-3.0.lua",
                   "core/localization/en.lua"),
        LATER: ("config/localization/en.lua",)}
TAMPER = ("core:OpenBags", "config:Columns", "faq:1")
STALE_SHOWN = ("core:OpenBags", "bind:TOGGLE", "config:Columns", "page:FrameOptions:Columns", "faq:1",
               "page:Help:faq1")
GROUPS = {"core": "tables", "config": "tables", "faq": "tables", "class": "read at load", "rule": "read at load",
          "bind": "read at load", "panel": "read at load", "win": "screen", "page": "screen"}
SPEED_N = 10000
SPEED_MS = 150         # 3 x SPEED_N misses (a shown FontString, a text, a frame not Bagnon's)
SPEED_KB = 4           # garbage they may make in all


def module_there():
    return os.path.isfile(os.path.join(session.REPO, MODULE, MODULE + ".toc"))


def _addon(name):
    return Addon(name, os.path.join(session.REPO, name), session.FLAVOR)


def _stand_in(name):
    return Addon(name, os.path.join(HERE, "bagnon", name), session.FLAVOR)


class BgnClient(Client):
    """Runs the installed BagBrother's files (read only) before each stand-in's own, and loads
    Bagnon_Config after login."""

    def run_addon_files(self, a):
        if a.name in REAL:
            self.H.addons[a.name].loading = True
            real = SimpleNamespace(name=a.name, folder=str(make_bgn_text.addon_dir()))
            for rel in REAL[a.name]:
                self.run_lua(real, rel)
        super().run_addon_files(a)

    def start(self):
        every = self.addons
        self.addons = [a for a in every if a.name != LATER]
        super().start()
        self.addons = every
        for a in every:
            if a.name == LATER:
                self.run_addon_files(a)
                self.H.loadSaved("", a.name)
                self.H.fire("ADDON_LOADED", a.name)


def _game(addons):
    c = BgnClient(addons, None, "enUS")
    c.lua.execute(read_text(os.path.join(HERE, "flow_bagnon.lua")))
    M = c.H.bgn
    for id_ in TAMPER:
        M.tamper[id_] = True
    c.start()
    c.H.pump(60)
    return c, M


def _snap(M):
    return {txt(k): txt(v) for k, v in M.snap().items()}


def _show(M):
    """The player opens the bags and every settings page (each page sets its texts on show)."""
    M.open("inventory")
    M.pages(True)


def _errors(c, check, step):
    errs = c.errors()
    check(f"{step}: no Lua errors", not errs, "; ".join(f"{w}: {m[:160]}" for w, m, _ in errs[:3]))


def _diff(a, b):
    names = sorted(n for n in set(a) | set(b) if a.get(n) != b.get(n))
    return len(names), names[:4]


def _compare(M, base, now):
    """Names whose text is not what we want (ours, or the base where we have none), and how many show
    our words, by group."""
    bad, uk = [], collections.Counter()
    for name in sorted(set(base) | set(now)):
        w = M.want(name)
        w = None if w is None else txt(w)
        if now.get(name) != (base.get(name) if w is None else w):
            bad.append(name)
        elif w is not None and w != base.get(name):
            uk[GROUPS.get(name.split(":")[0], "other")] += 1
    return bad, uk


def plain_game(check):
    c, M = _game([_stand_in("Bagnon"), _stand_in(LATER)])
    _show(M)
    M.open("bank")
    base = _snap(M)
    check("plain game: Bagnon's English read from the installed addon",
          len(base) > 150 and base.get("core:OpenBags"), len(base))
    _errors(c, check, "plain game")
    return base


def game_a(check, facts, base, rows):
    c, M = _game([_stand_in("Bagnon"), _addon("UADD"), _addon(MODULE), _stand_in(LATER)])
    en = {k: v for k, _, v, _ in rows}
    for id_, text in en.items():
        if txt(M.src(id_) or "") not in ("", hashtext.key(text)):
            M.markStale(id_)
    # 1. Load order: Bagnon_Config after the module (after login), through the NewLocale wrapper.
    check("load order: Bagnon_Config loaded after UADD_Bagnon, after login",
          M.loaded(LATER) and M.loaded(MODULE) and c.H.loggedIn, "")
    check("NewLocale wrapper in place, config words not late", M.wrapOk() and not M.late(), (M.wrapOk(), M.late()))
    check("module on after login", M.on(), "")
    # 2. Our words: tables, words read at load, screen. 3. Stale lines stay English.
    _show(M)
    M.open("bank")
    on = _snap(M)
    bad, uk = _compare(M, base, on)
    check("our words where we have them, Bagnon's English elsewhere", not bad, bad[:6])
    for g in ("tables", "read at load", "screen"):
        check(f"Ukrainian {g}: {uk[g]}", uk[g] > 0, "")
    facts["words"], facts["uk"] = int(M.count()), dict(uk)
    check("stale lines (src hash changed) stay English",
          all(M.stale[i] for i in TAMPER) and all(on.get(n) == base.get(n) for n in STALE_SHOWN),
          [n for n in STALE_SHOWN if on.get(n) != base.get(n)])
    # 4. Fonts read back, also on the bank window made after login.
    good, badf, wrong = M.fonts()
    check(f"fonts: {good} Ukrainian texts in our font, none without, none on English",
          good > 0 and badf == 0 and wrong == 0 and M.fontCount() >= good, (good, badf, wrong, M.fontCount()))
    bank = sum(1 for n, t in on.items() if n.startswith("win:bank:") and t != base.get(n))
    check("bank window made later: Ukrainian", bank > 0, bank)
    # 5. The hold key: Bagnon's English while held, ours again after.
    M.key(True)
    M.pages(True)
    n, names = _diff(_snap(M), base)
    check("hold key down: Bagnon's English", n == 0, (n, names))
    M.key(False)
    M.pages(True)
    n, names = _diff(_snap(M), on)
    check("hold key up: our words again", n == 0, (n, names))
    # 6. Off and on.
    M.uadd("bagnon off")
    M.pages(True)
    n, names = _diff(_snap(M), base)
    check("/uadd bagnon off: Bagnon's English, no font of ours", n == 0 and M.fontCount() == 0,
          (n, names, M.fontCount()))
    M.uadd("bagnon on")
    M.pages(True)
    n, names = _diff(_snap(M), on)
    good2, bad2, wrong2 = M.fonts()
    check("/uadd bagnon on: our words and fonts again", n == 0 and good2 == good and bad2 == 0 and wrong2 == 0,
          (n, names, good2, bad2, wrong2))
    # 7. No half-translated line.
    halves_mods.bgn(check, M, rows)
    # 8. Speed: the miss paths.
    ms, kb = M.speed(SPEED_N)
    facts["speed_ms"], facts["garbage_kb"] = round(ms, 2), round(kb, 2)
    check(f"speed: {3 * SPEED_N} misses under {SPEED_MS} ms, under {SPEED_KB} KB garbage",
          ms < SPEED_MS and kb < SPEED_KB, f"{ms:.1f} ms, {kb:.1f} KB")
    facts["fonts"] = int(M.fontCount())
    _errors(c, check, "game A")


def game_b(check):
    c, M = _game([_addon("UADD"), _addon(MODULE)])
    out = txt(M.uadd("bagnon") or "")
    _errors(c, check, "game B (no Bagnon)")
    last = " ".join(txt(x) for x in list(c.H.chat.values())[-3:])
    check("game B: module waits", "Bagnon не завантажено" in last and not M.standIn(), out or last)


def run(check, facts):
    if not module_there():
        check("UADD_Bagnon is there", False, "no UADD_Bagnon/UADD_Bagnon.toc")
        return
    rows, problems = make_bgn_text.texts(make_bgn_text.addon_dir())
    if not rows:
        check("Bagnon checks (skipped: Bagnon is not installed)", True, "")
        halves_mods.bgn(check, None, None)
        return
    check("make_bgn_text: every text sorted", not problems, problems[:3])
    base = plain_game(check)
    gc.collect()
    game_a(check, facts, base, rows)
    gc.collect()
    game_b(check)
    gc.collect()
    import flow_bagnon_names       # the game's words from UALL Forever (UADD_Bagnon/Game.lua)
    flow_bagnon_names.run(check, facts)


Check = collections.namedtuple("Check", "name ok detail")


def run_checks():
    """Every check of this file. Returns (checks, facts)."""
    checks, facts = [], {}

    def check(name, ok, detail=""):
        checks.append(Check("bgn: " + name, bool(ok), str(detail)))
    run(check, facts)
    return checks, facts


if __name__ == "__main__":       # alone: python3 tools/harness/flow_bagnon.py
    cs, fs = run_checks()
    for x in cs:
        print(("ok    " if x.ok else "FAIL  ") + x.name + (f"  [{x.detail}]" if x.detail else ""))
    print(fs)
    print(f"{sum(x.ok for x in cs)}/{len(cs)} passed")
    sys.exit(0 if all(x.ok for x in cs) else 1)
