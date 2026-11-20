"""UADD_GatherMate2 on a stand-in for GatherMate2 (tools/harness/gathermate2). GatherMate2's licence allows
none of its English here: the game runs the installed GatherMate2's libraries and enUS locale files (read
only) before the stand-in, and the flow names the locale keys the stand-in uses at run time. For each row
the module's data lacks, a test line made from GatherMate2's English (words in Cyrillic; slots, codes and
a last space kept) goes to the module (flow_gm.lua).

  * Game E (no UADD_GatherMate2): GatherMate2's English: what "off" must give back.
  * Game A (on at login): 1 all it changed is ours: locale table, settings, page names, Profiles tab, key
    binding names. 2 Lists of node and zone names never change (a list changes only when all of it is ours).
    3 The profession names and the node tables are never written. 4 The Profiles tab gets its own copy:
    another addon's Profiles tab (the shared table) stays English. 5 The pin menu line (a node's name glued
    after a word) stays all English; the settings Delete button with the same word is ours. 6 Chat lines:
    the auto import line is ours with the addon's name after the last space; the fail line (an engine
    token glued after it) stays English. 7 Off, on and the hold key, three times: English exactly, then
    ours exactly. 8 No half line.
  * Game B: no GatherMate2 (the module waits).
"""
import os
import sys
from types import SimpleNamespace

import halves_mods
import session
from flow_pawn_game import cyr, diff, errors, test_line

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import gm_rules as R  # noqa: E402
import gm_source as G  # noqa: E402
import hashtext  # noqa: E402
from flow import Check  # noqa: E402
from loader import Addon, Client, lua_str, read_text, txt  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
MODULE = "UADD_GatherMate2"
TARGET = "GatherMate2"
REAL = ("Libs/LibStub/LibStub.lua", "Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua",
        "Libs/AceAddon-3.0/AceAddon-3.0.lua", "Libs/AceDB-3.0/AceDB-3.0.lua",
        "Libs/AceDBOptions-3.0/AceDBOptions-3.0.lua", "Libs/AceLocale-3.0/AceLocale-3.0.lua",
        "Libs/AceConfig-3.0/AceConfigRegistry-3.0/AceConfigRegistry-3.0.lua",
        "Locales/GatherMate2-enUS.lua", "Locales/Vanilla/GatherMate2-Vanilla-enUS.lua")
PIN, AUTO, FAIL, TITLE = "L.adde7058", "L.d7c16fbf", "L.8d54e40a", "L.0cfe2a5a"
BIND = ("L.81dd86b7", "L.647b91d2")
NODE = "Quix Bloom"


def addon_dir():
    return str(G.addon_dir())


def installed():
    return all(os.path.isfile(os.path.join(addon_dir(), *r.split("/"))) for r in REAL)


def module_there():
    return os.path.isfile(os.path.join(session.REPO, MODULE, MODULE + ".toc"))


class GmClient(Client):
    """Runs the installed GatherMate2's libraries and enUS locale files (read only) before the stand-in."""

    def run_addon_files(self, a):
        if a.name == TARGET:
            self.H.addons[a.name].loading = True
            real = SimpleNamespace(name=a.name, folder=addon_dir())
            for rel in REAL:
                self.run_lua(real, rel)
        super().run_addon_files(a)


def words():
    """(stand-in keys [(slot, a, b)], test rows {row: Ukrainian}, {row: English} of the locale table)."""
    a = G.addon_dir()
    loc = G.read_locale(a / G.LOCALE)
    key = {"L." + hashtext.djb2(k): k for k, _, _ in loc}
    en = {"L." + hashtext.djb2(k): e for k, e, _ in loc}
    named = {"del": PIN, "auto": AUTO, "fail": FAIL, "title": TITLE, "bindMini": BIND[0], "bindMain": BIND[1]}
    keys = [(slot, key[row], None) for slot, row in named.items()]
    keys += [("prof", key[row], None) for row in sorted(R.DISPLAY_ONLY)]
    keys += [("other", key[row], None) for row in sorted(key) if row not in R.DISPLAY_ONLY and row not in
             named.values() and R.keep(row, en[row])[0]]
    keys += [("page", app, label) for app, label, _ in G.panels(a)]
    src = [(row, e) for row, e in en.items() if R.keep(row, e)[0]]
    src += [("Panel." + app, label) for app, label, _ in G.panels(a)]
    src += [("AceDBO." + k, e.strip("\n")) for k, e, _ in G.dbo_texts(a)]
    data = {}
    for i, (row, e) in enumerate(sorted(src)):
        uk = test_line(e, i)
        if uk != e and not R.check(row, e, uk):
            data[row] = uk
    return keys, data, en


def game(keys, data, target=True, module=True):
    addons = [Addon(TARGET, os.path.join(HERE, "gathermate2"), session.FLAVOR)] if target else []
    addons += [Addon(n, os.path.join(session.REPO, n), session.FLAVOR) for n in ("UADD",) + ((MODULE,) if module else ())]
    c = GmClient(addons, None, "enUS")
    c.lua.execute(read_text(os.path.join(HERE, "flow_gm.lua")))
    M = c.H.gm
    for slot, a, b in keys:
        M.word(slot, lua_str(a), b and lua_str(b))
    for row, uk in data.items():
        M.put(lua_str(row), lua_str(uk))
    c.start()
    c.H.pump(60)
    return c, M


def snap(M):
    return {txt(k): txt(v) for k, v in M.snap().items()}


def menu(M, title):
    return [txt(x) for x in M.pinMenu(lua_str(title)).values()]


def chat(M):
    return txt(M.autoImport("Quix")), txt(M.loadFail("Zorp"))


def game_e(keys):
    c, M = game(keys, {}, module=False)
    return {"snap": snap(M), "menu": menu(M, NODE), "chat": chat(M)}


def loop(check, M, en, uk):
    """Hold key, off and on, three times: English exactly, then ours exactly."""
    bad = []
    for i in range(3):
        for how, want in (("hold", en), ("release", uk), ("off", en), ("on", uk)):
            if how in ("hold", "release"):
                M.key(how == "hold")
            else:
                M.uadd("gathermate2 " + how)
            d = diff(want, snap(M))
            if d or (how in ("off", "hold") and int(M.count()) + int(M.optCount()) != 0):
                bad.append((i + 1, how, d[:3]))
    check("7 hold key, off, on (x3): English exactly, then ours exactly", not bad, bad[:3])


def game_a(check, facts, keys, data, en, E):
    c, M = game(keys, data)
    e, A = E["snap"], snap(M)
    changed = diff(e, A)
    notcyr = [k for k in changed if not cyr(A.get(k))]
    kinds = {k.split(":")[0] for k in changed}
    check("1 all it changed is ours: locale table, settings, page names, Profiles tab, key binding names",
          {"L", "O", "C", "P", "B"} <= kinds and not notcyr, (sorted(kinds), notcyr[:5]))
    facts["test_rows"], facts["swapped"], facts["changed"] = len(M.used), int(M.count()), len(changed)

    lists = [k for k in e if k.startswith(("O:mini.nodes.values.", "O:mini.zones.values."))]
    profs = [k for k in e if k.startswith("O:mini.profs.values.")]
    check(f"2 node and zone lists never change ({len(lists)} entries); a list all ours does (professions)",
          lists and all(A.get(k) == e[k] for k in lists) and profs and all(cyr(A.get(k)) for k in profs),
          ([k for k in lists if A.get(k) != e[k]][:3], [A.get(k) for k in profs][:2]))

    names = {"L:" + txt(x[1]) for x in keys if x[0] == "prof"}
    fixed = [k for k in e if k in names or k.startswith(("N:", "V:", "K:"))]
    check(f"3 the profession names and node tables are never written ({len(fixed)} entries)",
          len(names) == 5 and fixed and all(A.get(k) == e[k] for k in fixed),
          [k for k in fixed if A.get(k) != e[k]][:3])

    other = [k for k in e if k.startswith("Q:")]
    mine = [k for k in changed if k.startswith("P:")]
    check(f"4 Profiles tab: ours on its own copy ({len(mine)}); another addon's (the shared table) stays English",
          mine and other and all(A.get(k) == e[k] for k in other), [k for k in other if A.get(k) != e[k]][:3])

    m, uk_del = menu(M, NODE), txt(M.want(PIN))
    check("5 pin menu: the line with a node's name stays all English; the menu's title is ours",
          len(m) == 2 and m[1] == E["menu"][1] and not cyr(m[1]) and cyr(m[0]), (m, E["menu"]))
    check("5 the settings Delete button (same locale key) is ours",
          uk_del and A.get("O:mini.del.name") == uk_del, (A.get("O:mini.del.name"), uk_del))

    auto, fail = chat(M)
    uk_auto = txt(M.want(AUTO))
    check("6 chat: the auto import line is ours, the addon's name after its last space; the fail line "
          "(an engine token glued after it) stays English",
          uk_auto and uk_auto.endswith(" ") and auto == uk_auto + "Quix" and fail == E["chat"][1] and not cyr(fail),
          (auto, fail))

    loop(check, M, e, A)
    halves_mods.gm(check, M, en)
    errors(c, check, "game A")


def game_b(check, keys, data):
    c, M = game(keys, data, target=False)
    c.slash("uadd gathermate2")
    out = [x for x in c.chat() if "GatherMate2" in x and "чекає" in x]
    check("game B (no GatherMate2): the module waits", out, c.chat()[-3:])
    errors(c, check, "game B")


def run(check, facts):
    if not module_there() or not installed():
        halves_mods.gm(check, None)
        facts["note"] = "GatherMate2 or the module not there: skipped"
        return
    keys, data, en = words()
    E = game_e(keys)
    game_a(check, facts, keys, data, en, E)
    game_b(check, keys, data)


def run_checks():
    """Every check of this file. Returns (checks, facts)."""
    checks, facts = [], {}

    def check(name, ok, detail=""):
        checks.append(Check("gathermate2: " + name, bool(ok), str(detail)))
    run(check, facts)
    return checks, facts


if __name__ == "__main__":       # alone: python3 tools/harness/flow_gm.py
    cs, fs = run_checks()
    for x in cs:
        print(("ok    " if x.ok else "FAIL  ") + x.name + (f"  [{x.detail[:400]}]" if x.detail else ""))
    print(fs)
    print(f"{sum(x.ok for x in cs)}/{len(cs)} passed")
    sys.exit(0 if all(x.ok for x in cs) else 1)
