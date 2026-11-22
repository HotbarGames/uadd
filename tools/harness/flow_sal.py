"""UADD_SpeedyAutoLoot on a stand-in for Speedy AutoLoot (tools/harness/speedyautoloot). Its licence allows none
of its English here: the stand-in holds only the game functions the harness lacks (Shim.lua), and the game then
runs the installed addon's own two files (read only). The flow runs its /sal commands and moves its loot display.

  * Game E (no UADD_SpeedyAutoLoot): its English: what "off" must give back.
  * Game A (on at login): 1 ours: every chat line of its commands and help (the header has no words and stays),
    the anchor's label, the two test entries (the coin entry is the game's money and stays). 2 Anchor off and on
    again: the new test entries are ours again. 3 Hold key, off and on, three times: English exactly, then ours
    exactly. 4 Our font, read back, on every text with Cyrillic and on no other. 5 A loot line the addon does not
    mark as a test stays English, even named like one. 6 A foreign chat line costs no work of ours (lesson 12).
    7 /uadd sal says on, with counts. Then no half line (the sound line's number).
  * Game B: no Speedy AutoLoot (the module waits; the real client does not load it then: a required dependency).
"""
import os
import sys
from types import SimpleNamespace

import halves_mods
import session
from flow_pawn_game import cyr, diff, errors

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import sal_source as G  # noqa: E402
from flow import Check  # noqa: E402
from loader import Addon, Client, lua_str, read_text, txt  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
MODULE, TARGET = "UADD_SpeedyAutoLoot", "SpeedyAutoLoot"


def addon_dir():
    return str(G.addon_dir())


def installed():
    return all(os.path.isfile(os.path.join(addon_dir(), f)) for f in (G.MAIN, G.DISPLAY))


def module_there():
    return os.path.isfile(os.path.join(session.REPO, MODULE, MODULE + ".toc"))


class SalClient(Client):
    """The stand-in's Shim.lua, then the installed addon's own files, as one addon."""

    def run_addon_files(self, a):
        if a.name != TARGET:
            return super().run_addon_files(a)
        state = self.H.addons[a.name]
        state.loading = True
        self.run_lua(a, "Shim.lua")
        real = SimpleNamespace(name=a.name, folder=addon_dir())
        for rel in (G.MAIN, G.DISPLAY):
            self.run_lua(real, rel)
        state.loading = False
        state.loaded = True


def game(target=True, module=True):
    addons = [Addon(TARGET, os.path.join(HERE, "speedyautoloot", TARGET), session.FLAVOR)] if target else []
    addons += [Addon(n, os.path.join(session.REPO, n), session.FLAVOR) for n in ("UADD",) + ((MODULE,) if module else ())]
    c = SalClient(addons, None, "enUS")
    c.lua.execute(read_text(os.path.join(HERE, "flow_sal.lua")))
    M = c.H.sal
    c.start()
    c.H.pump(20)
    return c, M


def templates(en):
    """The half-line check's templates: sal_rules.SORTS, only v (the sound's number); the module fills a template
    only from digits."""
    import sal_rules as R
    return [halves_mods.tpl(k, en[k], {}, sorts=s) for k, s in sorted(R.SORTS.items())]


def snap(M):
    return {txt(k): txt(v) for k, v in M.snap().items()}


def loop(check, M, en, uk):
    bad = []
    for i in range(3):
        for how, want in (("hold", en), ("release", uk), ("off", en), ("on", uk)):
            if how in ("hold", "release"):
                M.key(how == "hold")
            else:
                M.uadd("sal " + how)
            d = diff(want, snap(M))
            n = int(M.saved())
            if d or (how in ("off", "hold") and n):
                bad.append((i + 1, how, d[:3], n))
    check("3 hold key, off, on (x3): English exactly (chat, label, test entries), then ours exactly", not bad, bad[:3])


def game_a(check, facts, en, E):
    c, M = game()
    shown = M.show(True)
    A = snap(M)
    chat = sorted((k for k in A if k.startswith("C:")), key=lambda k: int(k[2:]))
    tests = [k for k in A if k.startswith("P:")]
    ours = [k for k in A if A[k] != E.get(k)]
    head = chat[:1]
    stay = [k for k in tests if not cyr(A[k])]
    # 17 on Forever (WOW_PROJECT_CAMELOT, wow_api.lua): no bop help line or bop command lines there.
    check(f"1 ours: chat lines of every command and the help ({len(chat) - 1}), the anchor's label, the test entries; "
          "the help's header (no words) and the coin entry stay",
          shown and set(A) == set(E) and len(chat) >= 17 and all(cyr(A[k]) for k in chat[1:] + ["A:label"])
          and all(A[k] == E[k] for k in head) and len(tests) == 3 and len(stay) == 1 and A[stay[0]] == E[stay[0]],
          (sorted(set(A) ^ set(E))[:4], [A[k] for k in chat if not cyr(A[k])][:3], [A[k] for k in tests]))
    facts["chat_lines"], facts["changed"] = len(chat), len(ours)

    off, on = M.show(False), M.show(True)
    again = snap(M)
    check("2 anchor off, then on again: the new test entries are ours again",
          off and on and not diff(A, again), diff(A, again)[:3])

    loop(check, M, E, A)

    bad, n = M.fonts()
    bad = [txt(x) for x in bad.values()]
    check(f"4 our font read back: on every Cyrillic text, on no other ({int(n)} texts)", not bad and int(n) == 3, bad[:4])

    r = c.ev("""(function()
        local D = HARNESS.ns.UADD_SpeedyAutoLoot.Display
        for fs, en in pairs(D.en) do
            local b = D.owner[fs]
            b.isPermanent = false
            fs:SetText(en)
            local plain, font = fs:GetText(), UADD.IsCyrFont((fs:GetFont())) and true or false
            b.isPermanent = true
            fs:SetText(en)
            return { plain, en, font, fs:GetText() }
        end
        return {}
    end)()""")
    plain, en_line, font, back = (txt(r[i]) if isinstance(r[i], (str, bytes)) else r[i] for i in range(1, 5))
    check("5 a loot line the addon does not mark as a test stays English (its font too), even named like a test entry",
          plain and plain == en_line and font is False and cyr(back), (plain, font, back))

    foreign, work = M.cheap()
    check(f"6 a foreign chat line costs no work of ours (calls: {int(foreign)}; on its own lines: {int(work)})",
          int(foreign) == 0 and int(work) > 0, (foreign, work))

    M.uadd("sal")
    status = [x for x in c.chat()[-5:] if "увімкнено" in x]
    check("7 /uadd sal: on, with counts", status, c.chat()[-4:])

    halves_mods.sal(check, M, templates(en))
    errors(c, check, "game A")


def game_b(check):
    c, M = game(target=False)
    c.slash("uadd sal")
    out = [x for x in c.chat() if "Speedy AutoLoot" in x and "чекає" in x]
    check("game B (no Speedy AutoLoot): the module waits", out, c.chat()[-3:])
    errors(c, check, "game B")


def run(check, facts):
    if not module_there() or not installed():
        halves_mods.sal(check, None, [], halves_mods.SKIP)
        facts["note"] = "Speedy AutoLoot or the module not there: skipped"
        return
    rows, _ = G.source(G.addon_dir())
    en = {r[0]: r[1] for r in rows}
    c, M = game(module=False)
    M.show(True)
    E = snap(M)
    errors(c, check, "game E")
    game_a(check, facts, en, E)
    game_b(check)


def run_checks():
    """Every check of this file. Returns (checks, facts)."""
    checks, facts = [], {}

    def check(name, ok, detail=""):
        checks.append(Check("sal: " + name, bool(ok), str(detail)))
    run(check, facts)
    return checks, facts


if __name__ == "__main__":       # alone: python3 tools/harness/flow_sal.py
    cs, fs = run_checks()
    for x in cs:
        print(("ok    " if x.ok else "FAIL  ") + x.name + (f"  [{x.detail[:400]}]" if x.detail else ""))
    print(fs)
    print(f"{sum(x.ok for x in cs)}/{len(cs)} passed")
    sys.exit(0 if all(x.ok for x in cs) else 1)
