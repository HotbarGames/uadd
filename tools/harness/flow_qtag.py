"""The level letter in Questie's quest lines: "[40D] ", never "[40" + half a letter + "] " (a box in the game).

Questie takes the first BYTE of a quest's tag name for the letter (QuestieLib.lua:285), except in four locales.
With a Ukrainian locale its tag name "Dungeon" is «Підземелля», and its first byte is half a letter. UADD_Questie
gives Questie's Latin letter instead (UADD_Questie/Tracker.lua). The owner saw the box when another addon
(Quillshade 1.4.0) gave Questie its own Ukrainian first: UADD then had a conflict, and its guard was not in
(docs/LESSONS3.md, lesson 39). A stand-in (tools/harness/qoverride/) plays that addon.

  * qtag: 1 on: UADD gives Questie its language; quest 1956 reads "[40D] " in the tracker.
  * qtag: 2 conflict: another addon's Ukrainian came first; the same.
  * qtag: 3 off: UADD_Questie off, the other addon's Ukrainian on; the same.
  In each: every tracker line is whole UTF-8, and its level bracket is Latin only.
  * qtag: 4 any tag: an unknown tag with a Ukrainian name gives no letter; a raid gives "R"; elite keeps "+".
  * qtag: 5 later builder: an addon that wraps the suffix after us and gives a Cyrillic word: "[40D] ".
  * qtag: 6 our error: our part throws: Questie's own output, and no error reaches Questie.

`python3 tools/harness/flow_qtag.py --prove` is the same run: each mutant (flow_qtag.lua CUTS) takes one fix out
and wants its step to fail.
"""
import os
import re
import sys

import flow
import loader
import session
from loader import Addon, lua_str, read_text

HERE = os.path.dirname(os.path.abspath(__file__))
LUA = os.path.join(HERE, "flow_qtag.lua")
STAND = "QuestieOverrideStandIn"
COLOUR = re.compile(rb"\|c[0-9A-Fa-f]{8}|\|r")
MUTANTS = [("always", "qtag: 2"), ("level", "qtag: 5"), ("pcall", "qtag: 6")]
GAMES = {  # name: (addon order, saved text)
    "on": (["QuestieDB", "Questie", "UADD", "UALLF", "UADD_Questie"], None),
    "conflict": (["QuestieDB", "Questie", STAND, "UADD", "UALLF", "UADD_Questie"], None),
    "off": (["QuestieDB", "Questie", STAND, "UADD", "UALLF", "UADD_Questie"],
            {"UADD": "UADD_DB = { modules = { questie = { enabled = false } } }"}),
}
STEP = {"on": "1 on", "conflict": "2 conflict", "off": "3 off"}
WANT_STATE = {"on": "on", "conflict": "conflict", "off": "off"}

_cut = [None]


class _Client(loader.Client):
    def start(self):
        self.lua.execute(read_text(LUA))
        if _cut[0]:
            self.H.qtag["cut"] = _cut[0]
        return super().start()


def _folder(n):
    if n.startswith("UADD"):
        return os.path.join(session.REPO, n)
    if n == STAND:
        return os.path.join(HERE, "qoverride", n)
    return os.path.join(session.addons_dir(), n)


def _game(name):
    order, saved = GAMES[name]
    was_addons, was_client = session._ADDONS, session.Client
    session._ADDONS = [Addon(n, _folder(n), session.FLAVOR) for n in order]
    session.Client = _Client
    try:
        return flow.Flow().start(saved)
    finally:
        session._ADDONS, session.Client = was_addons, was_client


def bad_lines(c, lines):
    """Tracker lines (raw bytes) that are not whole UTF-8, or whose "[..]" level bracket is not Latin only."""
    out = []
    for x in c.lines(lines):
        raw = x.encode("latin-1")
        bare = COLOUR.sub(b"", raw)
        close = bare.find(b"]") if bare.startswith(b"[") else -1
        try:
            raw.decode("utf-8")
            ok = close < 0 or all(b < 128 for b in bare[:close])
        except UnicodeDecodeError:
            ok = False
        if not ok:
            out.append(raw[:60])
    return out


def _run(check, name):
    c = _game(name)
    Q = c.H.qtag
    step = "qtag: " + STEP[name]
    state, override, locale = Q.state()
    if name != "on":
        check(f"{step}: set up", state == WANT_STATE[name] and override == "ukUA" and locale == "ukUA",
              f"state {state}, override {override}, Questie's locale {locale}")
    Q.addQuest()
    lines, _ = c.F.drawTracker(True)
    bad = bad_lines(c, lines)
    level = [COLOUR.sub(b"", x.encode("latin-1")) for x in c.lines(lines)
             if "Power in Uldaman" in x or lua_str("Сила в Ульдамані") in x]
    check(f"{step}: quest 1956 reads [40D], every line whole", not bad and level and level[0].startswith(b"[40D] "),
          f"bad {bad[:3]}; line {level[:1]}")
    if name == "conflict":
        unknown, raid, elite = Q.oddTags()
        check("qtag: 4 any tag", (unknown, raid, elite) == ("[40] ", "[40R] ", "[40+] "),
              f"{unknown!r} {raid!r} {elite!r}")
        ok, got = Q.laterBuilder()
        check("qtag: 5 later builder", ok and got == "[40D] ", f"ok {ok}, {got!r}")
        ok, s, got = Q.ourError()
        check("qtag: 6 our error", ok and s == "\xd0" and got == "[40\xd0] ",
              f"ok {ok}, {s!r} {got!r} (want Questie's own)")
    errs = c.errors()
    check(f"{step}: no Lua errors", not errs, "; ".join(f"{w}: {m}" for w, m, _ in errs[:3]))
    return bool(Q.wasCut)


def run_checks(cut=None):
    checks = []

    def check(name, ok, detail=""):
        checks.append(flow.Check(name, bool(ok), str(detail)))

    _cut[0] = cut
    try:
        was = [_run(check, g) for g in (GAMES if cut is None else ("conflict",))]
    finally:
        _cut[0] = None
    if cut is None:
        for name, step in MUTANTS:
            try:
                sub, _ = run_checks(name)
                cutdone = any(x.name == "qtag: cut made" and x.ok for x in sub)
                failed = [x.name for x in sub if x.name.startswith(step) and not x.ok]
            except Exception as e:                      # the cut broke the flow: no proof
                cutdone, failed = False, [f"flow stopped: {e!r}"[:200]]
            check(f"qtag: mutant {name}: {step[6:]} fails without the fix", cutdone and failed,
                  f"cut {'made' if cutdone else 'NOT made'}; failed: {'; '.join(failed)[:200]}")
    else:
        check("qtag: cut made", any(was))
    return checks, {}


if __name__ == "__main__":
    cs, _ = run_checks()
    for x in cs:
        print(("ok    " if x.ok else "FAIL  ") + x.name + (f"  [{x.detail}]" if x.detail else ""))
    print(f"{sum(x.ok for x in cs)}/{len(cs)} passed")
    sys.exit(0 if all(x.ok for x in cs) else 1)
