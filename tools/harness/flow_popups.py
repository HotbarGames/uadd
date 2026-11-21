"""The core popup helper (UADD/Popups.lua) in each module that uses it besides Auctionator (2026-11-21).

LiteMount (its LM_OPTIONS_* dialogs), TomTom (TOMTOM_NEW_PROFILE), Forever Quest Pins (its Wowhead link popup),
Attune (its survey, raid invite and raid rename questions), Dungeon Journal (the game's YES and NO on its three
questions) and ForeverXP Bar (YES and NO on its challenge questions) register their dialogs with the helper. Each
game is the module's own flow game (flow_litemount, flow_tomtom, flow_fqp, flow_att_game, flow_dj_module with the
real journal, flow_fxpb) with the popup stand-in (flow_popups.lua) put in as it starts. For each module:

  * pops: 1  a dialog made after login (as Forever Quest Pins makes its popup on first use): ours when shown.
  * pops: 2  off and on: the button fields hold our words.
  * pops: 3  the hold key: fields and the shown dialog English while held, ours after release.
  * pops: 4  off: fields and the shown dialog English, also one shown while off; on: ours on it again.
  * pops: 5  the game's globals are never written, and another addon's dialog keeps the game's words.
  * pops: 6  a source word already Cyrillic (another addon set it) stays as it is, on and off.
  * pops: dj: 7  the journal's real minimap question: its text, drawn by the journal in our words, and its
             buttons flip both ways (held, off); another language in the journal's menu puts the English on the
             button fields, ours again when ours is picked.
  * pops: 8  a dialog shown in combat (no record, our words from the fields): English on the hold key and off,
             ours after.
Each mutant cuts one fix out of the core helper or a module file (in memory, flow_popups.lua) and wants its
step to fail. Auctionator's popups: flow_auc_popup.py. Run by run.py.
"""
import collections
import gc
import os
import re
import sys

import flow_att_game
import flow_dj_module
import flow_fqp
import flow_fxpb
import flow_litemount
import flow_tomtom
import flow_tomtom_texts as TT
from loader import Client, lua_str, read_text, txt

HERE = os.path.dirname(os.path.abspath(__file__))
PRESET = "Згода"            # a made-up Cyrillic word, as if another addon had set it

# module -> (its /uadd name, the dialogs: which, (src, glossary id) per button)
MODS = {
    "litemount": ("litemount", [
        ("LM_OPTIONS_RENAME_GROUP", ("G:ACCEPT", "ui.accept"), ("G:CANCEL", "ui.cancel")),
        ("LM_OPTIONS_DELETE_PROFILE", ("G:DELETE", "ui.delete"), ("G:OKAY", "ui.ok"))]),
    "tomtom": ("tomtom", [("TOMTOM_NEW_PROFILE", ("G:ACCEPT", "ui.accept"), ("G:CANCEL", "ui.cancel"))]),
    "fqp": ("foreverquestpins", [("FOREVER_QUEST_PINS_WOWHEAD_URL", ("G:CLOSE", "ui.close"), None)]),
    "attune": ("attune", [
        ("ACHIEVEANNOUNCE_CONFIRM", ("L:Yes", "ui.yes"), ("L:No", "ui.no")),
        ("INVITE_ATTUNE_RAID", ("L:Accept", "ui.accept"), ("L:Reject", "ui.reject")),
        ("RENAME_ATTUNE_RAID", ("L:Save", "ui.save"), ("L:Close", "ui.close"))]),
    "dj": ("dj", [(w, ("G:YES", "ui.yes"), ("G:NO", "ui.no")) for w in
                  ("FOREVERDUNGEONJOURNAL_HIDE_MINIMAP", "FDJ_RUNLOG_DELETE", "FDJ_TRACKER_RESET")]),
    "fxpb": ("fxpb", [(w, ("G:YES", "ui.yes"), ("G:NO", "ui.no")) for w in
                      ("FOREVERXP_ENABLE_CHALLENGE", "FOREVERXP_DISABLE_CHALLENGE")]),
}

STEPS = {
    1: "1 a dialog made after login is ours when shown",
    2: "2 off and on: the button fields hold our words",
    3: "3 English while held (fields, the shown dialog), ours after release",
    4: "4 English when off (fields, shown, one shown while off), ours when on again",
    5: "5 the game's globals are never written; another addon's dialog keeps the game's words",
    6: "6 a source word already Cyrillic stays as it is, on and off",
    7: "7 the journal's minimap question: text and buttons flip both ways; another language: English fields",
    8: "8 a dialog shown in combat: English on the hold key and off, ours after",
}


def cyr(s): return re.search("[Ѐ-ӿ]", s or "") is not None  # noqa: E704


def _tomtom():
    src = TT.rows()
    if not src:
        return None
    exact, temps, keep = TT.shipped()
    p = TT.picks(src, exact, temps, keep)
    return (lambda: flow_tomtom._game(p)) if p else None


def makers():
    """module -> a function that builds its game, or None (the addon not installed)."""
    return {"litemount": (lambda: flow_litemount._game()) if flow_litemount.installed() else None,
            "tomtom": _tomtom() if TT.module_there() else None,
            "fqp": (lambda: flow_fqp._game()) if flow_fqp.installed() else None,
            "attune": (lambda: flow_att_game.game()) if os.path.isdir(flow_att_game.REAL) else None,
            "dj": (lambda: (flow_dj_module.ModuleSession().client,)) if not flow_dj_module.missing_addons() else None,
            "fxpb": (lambda: flow_fxpb._game([flow_fxpb.STAND_IN, flow_fxpb._addon("UADD"),
                                              flow_fxpb._addon(flow_fxpb.MODULE)])) if flow_fxpb.module_there() else None}


def dj_body(check, P, tag, cmd):
    """Step 7: the journal's own minimap question, through its real code."""
    w = "FOREVERDUNGEONJOURNAL_HIDE_MINIMAP"
    en = txt(P.djEnglish())
    got = {"shown": (txt(P.djAsk()), txt(P.expect(w, "uk")))}
    ours = txt(P.djBody())
    ok = cyr(ours) and ours != en and got["shown"][0] == got["shown"][1]
    P.hold(True)
    got["held"] = (txt(P.djBody()), txt(P.shown(w)), txt(P.expect(w, "en")))
    ok = ok and got["held"][0] == en and got["held"][1] == got["held"][2]
    P.hold(False)
    got["after"] = (txt(P.djBody()) == ours, txt(P.shown(w)), txt(P.expect(w, "uk")))
    ok = ok and got["after"][0] and got["after"][1] == got["after"][2]
    P.uadd(cmd + " off")
    got["off"] = (txt(P.djBody()) == en, txt(P.shown(w)), txt(P.expect(w, "en")))
    ok = ok and got["off"][0] and got["off"][1] == got["off"][2]
    P.uadd(cmd + " on")
    got["on"] = (txt(P.djBody()) == ours, txt(P.shown(w)), txt(P.expect(w, "uk")))
    ok = ok and got["on"][0] and got["on"][1] == got["on"][2]
    P.hide(w)
    P.djLanguage(True)
    got["other"] = (txt(P.fields(w)), txt(P.expect(w, "en")))
    P.djLanguage(False)
    got["ours"] = (txt(P.fields(w)), txt(P.expect(w, "uk")))
    ok = ok and got["other"][0] == got["other"][1] and got["ours"][0] == got["ours"][1] and cyr(got["ours"][0])
    check(tag + STEPS[7], ok, got)


def combat_shown(check, P, tag, cmd, dialogs):
    """Step 8: a dialog shown in combat has no record (our words come from the fields alone)."""
    first = dialogs[0][0]
    P.combat(True)
    got = {"combat": (txt(P.show(first)), txt(P.expect(first, "uk")))}
    P.combat(False)
    P.hold(True)
    got["held"] = (txt(P.shown(first)), txt(P.expect(first, "en")))
    P.hold(False)
    got["after"] = (txt(P.shown(first)), txt(P.expect(first, "uk")))
    P.hide(first)
    P.combat(True)
    P.show(first)
    P.combat(False)
    P.uadd(cmd + " off")
    got["off"] = (txt(P.shown(first)), txt(P.expect(first, "en")))
    P.uadd(cmd + " on")
    got["on"] = (txt(P.shown(first)), txt(P.expect(first, "uk")))
    P.hide(first)
    check(tag + STEPS[8], all(a == b for a, b in got.values()) and cyr(got["combat"][0]), got)


EXTRA = {"dj": dj_body}          # module -> its own steps, run before step 6 (which makes a global Cyrillic)


def _game(make, cut=None):
    """The module's flow game, with flow_popups.lua run as it starts (after the flow's own Lua)."""
    start = Client.start
    code = read_text(os.path.join(HERE, "flow_popups.lua"))

    def started(self):
        self.lua.execute(code)
        self.H.pops.setCut(cut and lua_str(cut))
        start(self)
    Client.start = started
    try:
        c = make()[0]
    finally:
        Client.start = start
    return c, c.H.pops


def _define(P, dialogs):
    for which, b1, b2 in dialogs:
        P.define(which, b1[0], b1[1], *(b2 or (None, None)))


def _all(P, dialogs, what, want):
    """Each dialog's fields (or shown buttons) against what it should say."""
    got = [(txt(P.fields(w) if what == "fields" else P.shown(w)), txt(P.expect(w, want))) for w, _, _ in dialogs]
    return all(a == b for a, b in got), got


def module(check, name, make, cut=None):
    cmd, dialogs = MODS[name]
    c, P = _game(make, cut)
    ok_g, seen = True, [txt(P.globals())]
    tag = f"pops: {name}: "

    _define(P, dialogs)                                       # 1: made after login, shown
    got = [(txt(P.show(w)), txt(P.expect(w, "uk"))) for w, _, _ in dialogs]
    ok = all(a == b and cyr(a) for a, b in got)
    check(tag + STEPS[1], ok, got)
    for w, _, _ in dialogs:
        P.hide(w)

    P.uadd(cmd + " off")                                      # 2: the fields after off and on
    P.uadd(cmd + " on")
    ok, got = _all(P, dialogs, "fields", "uk")
    check(tag + STEPS[2], ok and cyr(str(got)), got)
    seen.append(txt(P.globals()))

    first = dialogs[0][0]                                     # 3: the hold key
    P.show(first)
    P.hold(True)
    ok1, a = _all(P, dialogs, "fields", "en")
    held = (txt(P.shown(first)), txt(P.expect(first, "en")))
    P.hold(False)
    ok2, b = _all(P, dialogs, "fields", "uk")
    back = (txt(P.shown(first)), txt(P.expect(first, "uk")))
    check(tag + STEPS[3], ok1 and ok2 and held[0] == held[1] and back[0] == back[1],
          {"held": a + [held], "after": b + [back]})
    seen.append(txt(P.globals()))

    P.uadd(cmd + " off")                                      # 4: off, a dialog shown while off, on
    ok1, a = _all(P, dialogs, "fields", "en")
    off = (txt(P.shown(first)), txt(P.expect(first, "en")))
    last = dialogs[-1][0]
    if last != first:
        P.hide(first)
    late = (txt(P.show(last)), txt(P.expect(last, "en")))
    P.uadd(cmd + " on")
    ok2, b = _all(P, dialogs, "fields", "uk")
    on = (txt(P.shown(last)), txt(P.expect(last, "uk")))
    check(tag + STEPS[4], ok1 and ok2 and off[0] == off[1] and late[0] == late[1] and on[0] == on[1],
          {"off": a + [off, late], "on": b + [on]})
    for w, _, _ in dialogs:
        P.hide(w)
    seen.append(txt(P.globals()))

    other = txt(P.other())                                    # 5: globals never written, other addon's dialog
    want = " / ".join(txt(P.globals()).split(" / ")[i] for i in (0, 4))
    check(tag + STEPS[5], len(set(seen)) == 1 and other == want, {"globals": sorted(set(seen)), "other": other})
    if name in EXTRA:
        EXTRA[name](check, P, tag, cmd)
    combat_shown(check, P, tag, cmd, dialogs)

    src = dialogs[0][1][0]                                    # 6: a Cyrillic source word stays
    kind, sname = src.split(":")
    (P.setGlobal if kind == "G" else P.setL)(sname, lua_str(PRESET))
    _define(P, dialogs)
    got = []
    for msg in ("off", "on"):
        P.uadd(cmd + " " + msg)
        got.append(txt(P.fields(first)))
    shown = txt(P.show(first))
    ok = all(g.startswith(PRESET + " / ") for g in got) and shown.startswith(PRESET)
    ok = ok and txt(P.fields(first)) == txt(P.expect(first, "uk"))
    check(tag + STEPS[6], ok, {"off, on": got, "shown": shown})
    errs = c.errors()
    check(tag + "no Lua errors", not errs, "; ".join(f"{w}: {m[:160]}" for w, m, _ in errs[:3]))
    return c, P


# cut -> (the module game it runs in, the step it must break)
MUTANTS = {"fields": ("litemount", 2), "shown": ("litemount", 1), "restore": ("litemount", 4),
           "rescan": ("litemount", 4), "ours": ("litemount", 5), "cyr": ("litemount", 6), "names": ("fqp", 1),
           "lmhold": ("litemount", 3), "ttoff": ("tomtom", 4), "fqpoff": ("fqp", 4), "english": ("dj", 7),
           "djhold": ("dj", 3), "djlang": ("dj", 7), "fxglobals": ("fxpb", 1), "unrecorded": ("litemount", 8)}


def mutants(check, make):
    for cut, (name, step) in MUTANTS.items():
        if not make.get(name):
            continue
        got = {}

        def quiet(n, ok, detail=""): got[n] = ok  # noqa: E704
        c, P = module(quiet, name, make[name], cut)
        ok = got.get(f"pops: {name}: " + STEPS[step])
        check(f"pops: mutant {cut} (the helper or module file without that fix, in memory only): {name} step {step} "
              "fails", P.wasCut and ok is False, "cut not found" if not P.wasCut else "it passed" if ok else "")
        del c, P
        gc.collect()


def run(check, facts):
    make = makers()
    for name, m in make.items():
        if not m:
            check(f"pops: {name} (skipped: its addon is not installed)", True, "")
            continue
        module(check, name, m)
        gc.collect()
    mutants(check, make)


Check = collections.namedtuple("Check", "name ok detail")


def run_checks():
    """Every check of this file. Returns (checks, facts)."""
    checks, facts = [], {}

    def check(name, ok, detail=""):
        checks.append(Check(name, bool(ok), str(detail)))
    run(check, facts)
    return checks, facts


if __name__ == "__main__":       # alone: python3 tools/harness/flow_popups.py
    cs, _ = run_checks()
    for x in cs:
        print(("ok    " if x.ok else "FAIL  ") + x.name + (f"  [{x.detail}]" if x.detail else ""))
    print(f"{sum(x.ok for x in cs)}/{len(cs)} passed")
    sys.exit(0 if all(x.ok for x in cs) else 1)
