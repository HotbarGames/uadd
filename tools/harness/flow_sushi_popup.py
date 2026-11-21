"""The game's button words on Bagnon's and Scrap's own Sushi pop-ups (lesson 1 again, 2026-11-21).

Both addons carry the same Sushi-3.2, so one Popup class serves them and every other addon that has it.
The core helper UADD/SushiPopups.lua hooks it once; UADD_Bagnon and UADD_Scrap register their folders with
it, and each module's pop-ups follow that module only. Bagnon and Scrap stand-ins load together here, with
the core and both modules.

  * sushi: 1  on: Bagnon's and Scrap's pop-ups show our words (fields and shown buttons, our font), their
              bodies ours, the core helper counts each as its module's; a pop-up opened again on a pooled
              frame is ours too.
  * sushi: 2  hold key: the shown pop-ups English (buttons and body), one opened while held English; ours after.
  * sushi: 3  "/uadd bagnon off": Bagnon's English, Scrap's still ours (shown and new); the other way round
              with Scrap off; both on: ours.
  * sushi: 4  the globals are never written; another addon's pop-up, one on a frame Bagnon used before, one
              under a pop-up Bagnon opens twice, and one a library opens alone keep the game's words, also
              after the hold key.
  * sushi: 5  OKAY already Cyrillic (another addon set it): it stays on, held and off; CANCEL ours.
  * sushi: 6  an error inside while a pop-up opens: the pop-up stays whole English; the next one is ours.
Each mutant cuts one fix out of the core file (in memory, flow_sushi_popup.lua) and wants its step to fail.
"""
import collections
import gc
import os
import re
import sys

import flow_bagnon
import flow_scrap
import session
from loader import Addon, lua_str, read_text, txt

HERE = os.path.dirname(os.path.abspath(__file__))
HELD = 0.4
PRESET = "Добре"            # a made-up Cyrillic OKAY, as if another addon had set it
STEPS = {
    1: "sushi: 1 on: Bagnon's and Scrap's pop-ups ours (fields, shown buttons, font, body), also on a pooled frame",
    2: "sushi: 2 hold key: shown pop-ups English (buttons and body), one opened while held English; ours after",
    3: "sushi: 3 one module off, the other on: each addon's pop-ups follow their own module; both on: ours",
    4: "sushi: 4 globals never written; another addon's, a reused frame's, a duplicate's and a library's pop-up untouched",
    5: "sushi: 5 an OKAY already Cyrillic stays as it is on, held and off; CANCEL ours",
    6: "sushi: 6 an error while a pop-up opens: that pop-up whole English, the next one ours",
}
BGN = ("Bagnon", "core/features/popup.lua", "Bagnon")
SCR = ("Scrap", "addons/main/main.lua", "Scrap")


def cyr(s): return re.search("[Ѐ-ӿ]", s or "") is not None  # noqa: E704


class SushiClient(flow_bagnon.BgnClient, flow_scrap.ScrapClient):
    """Bagnon's and Scrap's stand-ins, each with its installed addon's real files run first."""


def installed():
    return flow_scrap.installed() and all(os.path.isdir(p) for p in (str(flow_bagnon.make_bgn_text.addon_dir()),))


def _game(cut=None, preset=None):
    addons = [flow_bagnon._stand_in("Bagnon"), Addon("Scrap", os.path.join(HERE, "scrap", "Scrap"), session.FLAVOR)]
    addons += [flow_bagnon._addon(n) for n in ("UADD", "UADD_Bagnon", "UADD_Scrap")]
    c = SushiClient(addons, None, "enUS")
    c.lua.execute(read_text(os.path.join(HERE, "flow_sushi_popup.lua")))
    P = c.H.sushi
    P.setCut(cut)
    if preset:
        P.preset("OKAY", lua_str(preset))
    c.start()
    c.H.pump(60)
    return c, P


class Game:
    def __init__(self, c, P):
        self.c, self.P = c, P
        self.bkey = P.plainKey("Bagnon")

    def key(self, down):
        self.c.H["keys"]["SHIFT"] = down
        self.c.H.fire("MODIFIER_STATE_CHANGED", "LSHIFT", 1 if down else 0)
        for _ in range(int(HELD / 0.05)):
            self.c.H.step(0.05)

    def uadd(self, msg):
        self.c.H.call("/uadd " + msg, self.c.lua.globals().SlashCmdList.UADD, msg)

    def open(self, who, b1="OKAY", b2="CANCEL", key=None, id_=None):
        folder, file, app = who
        if key is None:
            key = self.bkey if app == "Bagnon" else "ConfirmDelete"
        return self.P.open(folder, file, b1, b2, app, key, id_)

    def view(self, f):
        fields, shown, font = self.P.view(f)
        return txt(fields), txt(shown), bool(font)

    def want(self, who, want, b1="OKAY", b2="CANCEL", body=None):
        """fields and shown texts the pop-up should have; body: the locale text read now (None: read it)."""
        P = self.P
        w1, w2 = txt(P.word(b1, want)), txt(P.word(b2, want))
        if body is None:
            body = txt(P.L(who[2], self.bkey if who[2] == "Bagnon" else "ConfirmDelete"))
        return f"{w1} / {w2} / {body}", f"{body} | {w1} | {w2}"

    def plain(self, b1="OKAY", b2="CANCEL", body=""):
        w1, w2 = txt(self.P.word(b1, "en")), txt(self.P.word(b2, "en"))
        return f"{w1} / {w2} / {body}", f"{body} | {w1} | {w2}"


def _is(g, f, want_pair):
    fields, shown, font = g.view(f)
    return (fields, shown) == want_pair and (font or not cyr(shown)), (fields, shown, font, "want", want_pair)


def step1(check, g):
    got, ok = [], True
    for who, key in ((BGN, "bagnon"), (SCR, "scrap")):
        f = g.open(who)
        good, d = _is(g, f, g.want(who, "uk"))
        n = g.P.count(key)
        ok = ok and good and cyr(d[1]) and n == 1
        got.append(d + ("core count", n))
        g.P.release(f)
        f2 = g.open(who)                                  # the pool gives the same frame back
        good, d = _is(g, f2, g.want(who, "uk"))
        ok = ok and good
        got.append(d)
        g.P.release(f2)
    f = g.open(BGN, "YES", "NO")
    good, d = _is(g, f, g.want(BGN, "uk", "YES", "NO"))
    g.P.release(f)
    check(STEPS[1], ok and good, got + [d])


def _pair_state(g, fb, fs, wb, ws):
    a, da = _is(g, fb, wb)
    b, db = _is(g, fs, ws)
    return a and b, [da, db]


def step2(check, g):
    fb, fs = g.open(BGN), g.open(SCR)
    g.key(True)
    ok, got = _pair_state(g, fb, fs, g.want(BGN, "en"), g.want(SCR, "en"))
    fn = g.open(BGN, "YES", "NO", id_="held")
    good, d = _is(g, fn, g.want(BGN, "en", "YES", "NO"))
    g.key(False)
    after, got2 = _pair_state(g, fb, fs, g.want(BGN, "uk"), g.want(SCR, "uk"))
    good2, d2 = _is(g, fn, g.want(BGN, "uk", "YES", "NO"))
    for f in (fb, fs, fn):
        g.P.release(f)
    check(STEPS[2], ok and good and after and good2, {"held": got + [d], "after": got2 + [d2]})


def step3(check, g):
    fb, fs = g.open(BGN), g.open(SCR)
    res = []
    for cmds, wb, ws in ((("bagnon off",), "en", "uk"), (("bagnon on", "scrap off"), "uk", "en"),
                         (("scrap on",), "uk", "uk")):
        for m in cmds:
            g.uadd(m)
        ok, d = _pair_state(g, fb, fs, g.want(BGN, wb), g.want(SCR, ws))
        nb, ns_ = g.open(BGN, id_="n1"), g.open(SCR, id_="n2")
        ok2, d2 = _pair_state(g, nb, ns_, g.want(BGN, wb), g.want(SCR, ws))
        g.P.release(nb)
        g.P.release(ns_)
        res.append((cmds, ok and ok2, d, d2))
    g.P.release(fb)
    g.P.release(fs)
    check(STEPS[3], all(r[1] for r in res), [r for r in res if not r[1]] or "")


def step4(check, g, seen):
    other = ("OtherAddon", "core/ask.lua", None)
    got, ok = {}, True
    f = g.open(other, key=False)                          # another addon's pop-up
    ok, got["other"] = _is(g, f, g.plain())
    g.P.release(f)
    fb = g.open(BGN)                                      # Bagnon's frame, then the pool gives it to another addon
    g.P.release(fb)
    fo = g.open(other, key=False, id_="reuse")
    g.key(True)
    g.key(False)
    good, got["reused"] = _is(g, fo, g.plain())
    ok = ok and good
    fb = g.open(BGN, id_="twice")                         # Bagnon's twice: Sushi makes nothing the 2nd time
    fo2 = g.open(other, key=False, id_="top")
    g.open(BGN, id_="twice")
    good, got["under a duplicate"] = _is(g, fo2, g.plain())
    ok = ok and good
    lib = ("BagBrother", "libs/StaleCheck-1.0/StaleCheck-1.0.lua", None)
    fl = g.open(lib, "OKAY", None, key=False)
    w = txt(g.P.word("OKAY", "en"))
    good, got["library"] = _is(g, fl, (f"{w} / nil / ", f" | {w}"))
    ok = ok and good
    for x in (fo, fb, fo2, fl):
        g.P.release(x)
    seen.append(txt(g.P.globals()))
    ok = ok and len(set(seen)) == 1
    got["globals"] = sorted(set(seen))
    check(STEPS[4], ok, got)


def step5(check, g):
    got, ok = [], True
    f = g.open(BGN)
    for act in (None, lambda: g.key(True), lambda: g.key(False), lambda: g.uadd("bagnon off"),
                lambda: g.uadd("bagnon on")):
        if act:
            act()
        fields, shown, _ = g.view(f)
        got.append((fields, shown))
        ok = ok and fields.startswith(PRESET + " / ") and shown.split(" | ")[1] == PRESET
    good, d = _is(g, f, g.want(BGN, "uk"))
    ok = ok and good and cyr(d[0].split(" / ")[1]) and txt(g.P.globals()).startswith(PRESET + " / ")
    g.P.release(f)
    check(STEPS[5], ok, {"on, held, released, off, on": got, "now": d})


def step6(check, g):
    # 5 s after login: an error now counts as one error, not as a failed setup (UADD/Safe.lua turns that off).
    g.c.lua.execute("HARNESS.pump(100, function() return false end, 0.05)")
    g.P.breakGlossary(True)
    f = g.open(SCR, key=False)
    g.P.breakGlossary(False)
    good, d = _is(g, f, g.plain())
    g.P.release(f)
    f2 = g.open(SCR)
    good2, d2 = _is(g, f2, g.want(SCR, "uk"))
    g.P.release(f2)
    check(STEPS[6], good and good2, [d, d2])


def game_a(check, cut=None):
    c, P = _game(cut)
    g = Game(c, P)
    seen = [txt(P.globals())]
    for s in (step1, step2, step3):
        s(check, g)
        seen.append(txt(P.globals()))
    step4(check, g, seen)
    errs = c.errors()
    check("sushi: game A: no Lua errors", not errs, "; ".join(f"{w}: {m[:160]}" for w, m, _ in errs[:3]))
    step6(check, g)
    return c, P


def game_b(check, cut=None):
    c, P = _game(cut, preset=PRESET)
    step5(check, Game(c, P))
    errs = c.errors()
    check("sushi: game B (OKAY Cyrillic): no Lua errors", not errs, "; ".join(f"{w}: {m[:160]}" for w, m, _ in errs[:3]))
    return c, P


# cut -> (the step it must break, the game that reaches it)
MUTANTS = {"fields": (1, game_a), "shown": (1, game_a), "owner": (4, game_a), "cyr": (5, game_b),
           "release": (1, game_a), "seen": (4, game_a), "body": (2, game_a), "sync": (2, game_a)}


def mutants(check):
    for cut, (step, game) in MUTANTS.items():
        got = {}

        def quiet(name, ok, detail=""): got[name] = ok  # noqa: E704
        c, P = game(quiet, cut)
        ok = got.get(STEPS[step])
        check(f"sushi: mutant {cut} (the core file without that fix, in memory only): step {step} fails",
              P.wasCut and ok is False, "cut not found" if not P.wasCut else "it passed" if ok else "")
        del c, P
        gc.collect()


def run(check, facts):
    if not installed():
        return check("Bagnon and Scrap are installed (their real files run first)", True, "not installed: skipped")
    for g in (lambda: game_a(check), lambda: game_b(check), lambda: mutants(check)):
        g()
        gc.collect()


Check = collections.namedtuple("Check", "name ok detail")


def run_checks():
    """Every check of this file. Returns (checks, facts)."""
    checks, facts = [], {}

    def check(name, ok, detail=""):
        checks.append(Check("pop: " + name, bool(ok), str(detail)))
    run(check, facts)
    return checks, facts


if __name__ == "__main__":       # alone: python3 tools/harness/flow_sushi_popup.py
    cs, _ = run_checks()
    for x in cs:
        print(("ok    " if x.ok else "FAIL  ") + x.name + (f"  [{x.detail}]" if x.detail else ""))
    print(f"{sum(x.ok for x in cs)}/{len(cs)} passed")
    sys.exit(0 if all(x.ok for x in cs) else 1)
