"""The show-original key with UALL Forever (UALLF), ClassicUA, both or neither, and the one-time chat notice
that names it (UADD/Original.lua: U.OriginalKey, U.KeyNoticeLines, U.KeyNotice; UADD/Core.lua: the login
timer and /uadd).

Each game is UADD alone; UALLF and ClassicUA are made-up addons that the game reports as loaded, with only
their saved settings (UALLFSettingsDB.originalKey / reverseOriginal, ClassicUA_Options.tooltip_original_key).
For each case: the key UADD follows (held 0.3 s shows the English, another key does not), the notice lines,
/uadd shows the same lines, and no error. Then a run of logins with the saved UADD_DB carried over: the notice
prints at the first login only, again when ClassicUA is added, again when it goes, never at a login with the
same addons.

python3 tools/harness/flow_keynotice.py
"""
import collections
import os
import sys

import session
from loader import Addon, Client, lua_str

HELD = 0.3
NOTE_WAIT = 6.0         # seconds after login: the notice waits 4 s (NOTICE_DELAY in UADD/Core.lua)
BAD = "{} with a throwing read"

# name: (UALLF settings or None when not loaded, ClassicUA options or None when not loaded,
#        key UADD must follow or None for no key, reverse, words each notice line must hold)
CASES = {
    "UALLF Shift": ({"originalKey": "SHIFT"}, None, "SHIFT", False, [["Shift", "UALL Forever"]]),
    "UALLF Ctrl": ({"originalKey": "CTRL"}, None, "CTRL", False, [["Ctrl", "UALL Forever"]]),
    "UALLF no key": ({"originalKey": "NONE"}, None, None, False, [["вимкнено", "UALL Forever"]]),
    "UALLF reverse": ({"originalKey": "SHIFT", "reverseOriginal": True}, None, "SHIFT", True,
                      [["Shift", "обернений"]]),
    "UALLF no settings": ("nil", None, "SHIFT", False, [["Shift", "UALL Forever"]]),
    "ClassicUA Alt": (None, {"tooltip_original_key": "ALT"}, "ALT", False, [["Alt", "ClassicUA", "/ua"],
                                                                          ["кнопку мови"]]),
    "ClassicUA Ctrl": (None, {"tooltip_original_key": "CTRL"}, "CTRL", False, [["Ctrl", "ClassicUA"],
                                                                             ["кнопку мови"]]),
    "both, keys differ": ({"originalKey": "SHIFT"}, {"tooltip_original_key": "ALT"}, "SHIFT", False,
                          [["Shift", "UALL Forever", "ClassicUA", "Alt"], ["/ua", "UALL Forever"]]),
    "both, one key": ({"originalKey": "CTRL"}, {"tooltip_original_key": "CTRL"}, "CTRL", False,
                      [["Ctrl", "UALL Forever", "ClassicUA", "/ua"]]),
    "both, UALLF no key": ({"originalKey": "NONE"}, {"tooltip_original_key": "ALT"}, None, False,
                           [["вимкнено", "ClassicUA", "Alt"], ["/ua"]]),
    "neither": (None, None, "SHIFT", False, []),
    "ClassicUA options nil": (None, "nil", "SHIFT", False, [["Shift"]]),
    "ClassicUA options a string": (None, "'ALT'", "SHIFT", False, [["Shift"]]),
    "ClassicUA options without the key": (None, {}, "SHIFT", False, [["Shift"]]),
    "ClassicUA key unknown": (None, {"tooltip_original_key": "NONE"}, "SHIFT", False, [["Shift"]]),
    "ClassicUA options throw": (None, BAD, "SHIFT", False, [["Shift"]]),
    "both, ClassicUA options broken": ({"originalKey": "CTRL"}, "'x'", "CTRL", False, [["Ctrl", "UALL Forever"]]),
}
KEYS = ("SHIFT", "CTRL", "ALT")
BANNED = ("краще", "якісніш", "гірше", "•")     # the owner: both named side by side, neither as better


def lua_value(v):
    if v is None or v == "nil":
        return "nil"
    if v == BAD:
        return 'setmetatable({}, { __index = function() error("broken options") end })'
    if isinstance(v, str):
        return v
    parts = []
    for k, x in v.items():
        parts.append(f'{k} = {"true" if x is True else repr(x).replace(chr(39), chr(34))}')
    return "{ " + ", ".join(parts) + " }"


def game(uallf, cua, saved=None):
    """A logged-in game with UADD, and UALLF / ClassicUA reported loaded when their settings are given."""
    c = Client([Addon("UADD", os.path.join(session.REPO, "UADD"), session.FLAVOR)], saved, "enUS")
    L = c.lua
    for name, settings, glob in (("UALLF", uallf, "UALLFSettingsDB"), ("ClassicUA", cua, "ClassicUA_Options")):
        if settings is None:
            continue
        L.execute(f'HARNESS.addons["{name}"] = {{ meta = {{}}, metaLower = {{}}, loaded = true }}\n'
                  f'{glob} = {lua_value(settings)}')
    c.start()
    pump(c, NOTE_WAIT)
    return c


def pump(c, seconds):
    c.lua.execute(f"HARNESS.pump({int(seconds / 0.05 + 0.5)}, function() return false end, 0.05)")


def key(c, name, down):
    c.H["keys"][name] = down        # c.H.keys is lupa's own keys() method
    c.H.fire("MODIFIER_STATE_CHANGED", "L" + name, 1 if down else 0)


def followed(c):
    """{key: English shown while it is held} after 0.3 s, and what shows with no key held."""
    out = {}
    for k in KEYS:
        key(c, k, True)
        pump(c, HELD)
        out[k] = bool(c.lua.globals().UADD.originalShown)
        key(c, k, False)
        pump(c, 0.1)
    return out, bool(c.lua.globals().UADD.originalShown)


def notice(lines):
    return [x for x in lines if "Затисніть" in x or "Клавішу оригіналу" in x or "кнопку мови" in x
            or "Одна клавіша" in x]


def errors(c):
    return [e[1] for e in c.errors()] + [x for x in c.chat() if "помилка" in x]


def run(check, facts):
    for name, (uallf, cua, want, reverse, words) in CASES.items():
        c = game(uallf, cua)
        said = notice(c.chat())
        held, idle = followed(c)
        want_held = {k: (k == want) != reverse for k in KEYS}
        check(f"{name}: follows the right key", held == want_held and idle == reverse,
              f"held={held} idle={idle} want={want} reverse={reverse}")
        lines = [x.replace("|cff4fc3f7UADD|r ", "") for x in said]
        ok = len(lines) == len(words) and all(all(w in line for w in ws) for line, ws in zip(lines, words))
        check(f"{name}: notice at login names the key", ok, lines)
        check(f"{name}: notice is plain and neutral",
              not any(b in line.lower() for line in lines for b in BANNED) and all(len(x) <= 160 for x in lines),
              lines)
        before = len(c.chat())
        c.slash("")
        shown = notice(c.chat()[before:])
        want_list = lines or ["Затисніть Shift"]
        check(f"{name}: /uadd shows the same lines",
              [x.replace("|cff4fc3f7UADD|r ", "") for x in shown] == lines if lines
              else len(shown) == 1 and want_list[0] in shown[0], shown)
        check(f"{name}: no error", not errors(c), errors(c)[:3])
        facts[name] = lines

    # Logins one after another, UADD_DB carried over (dump_saved: as written at logout).
    uallf, cua = {"originalKey": "SHIFT"}, {"tooltip_original_key": "ALT"}
    runs, saved = [], None
    for step, (u, a) in enumerate(((uallf, None), (uallf, None), (uallf, cua), (uallf, cua), (uallf, None),
                                   (None, None), (None, None), (uallf, None))):
        c = game(u, a, saved)
        runs.append(len(notice(c.chat())))
        saved = c.dump_saved()
        if step == 0:
            first_saved = saved.get("UADD", "")
    check("logins: notice once at the first login, not at the second",
          runs[0] == 1 and runs[1] == 0 and "keyNotice" in first_saved, f"{runs} {first_saved[:200]!r}")
    check("logins: ClassicUA added, notice again (2 lines), then not again", runs[2] == 2 and runs[3] == 0, runs)
    check("logins: ClassicUA gone, notice again", runs[4] == 1, runs)
    check("logins: neither addon, no notice; UALLF back, notice again",
          runs[5] == 0 and runs[6] == 0 and runs[7] == 1, runs)
    facts["logins"] = runs

    # The notice waits for the timer: nothing right at login, so it is not lost among the login lines.
    c = Client([Addon("UADD", os.path.join(session.REPO, "UADD"), session.FLAVOR)], None, "enUS")
    c.lua.execute('HARNESS.addons["UALLF"] = { meta = {}, metaLower = {}, loaded = true }')
    c.start()
    pump(c, 1)
    early = len(notice(c.chat()))
    pump(c, NOTE_WAIT)
    check("notice comes a few seconds after login", early == 0 and len(notice(c.chat())) == 1,
          f"{early} {notice(c.chat())}")

    # A key notice that throws: the key and the chat still work, /uadd still lists.
    c = game({"originalKey": "CTRL"}, None)
    c.lua.execute(lua_str('UADD.KeyNoticeLines = function() error("notice broke") end'))
    before = len(c.chat())
    c.slash("")
    listed = any("версія" in x for x in c.chat()[before:])          # UADD alone: no modules to list
    held, _ = followed(c)
    check("a notice that throws: /uadd still lists, the key still works",
          listed and held["CTRL"] and not held["SHIFT"], f"{listed} {held}")


Check = collections.namedtuple("Check", "name ok detail")


def run_checks():
    """Every check of this file. Returns (checks, facts)."""
    checks, facts = [], {}

    def check(name, ok, detail=""):
        checks.append(Check("keynotice: " + name, bool(ok), str(detail)))
    run(check, facts)
    return checks, facts


if __name__ == "__main__":       # alone: python3 tools/harness/flow_keynotice.py
    cs, fs = run_checks()
    for x in cs:
        print(("ok    " if x.ok else "FAIL  ") + x.name + (f"  [{x.detail}]" if x.detail else ""))
    for k, v in fs.items():
        print(f"{k}: {v}")
    print(f"{sum(x.ok for x in cs)}/{len(cs)} passed")
    sys.exit(0 if all(x.ok for x in cs) else 1)
