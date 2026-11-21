"""UADD_LiteMount on a LiteMount stand-in (tools/harness/litemount) that runs the installed LiteMount's own
Localization.lua; when LiteMount is not installed every check is skipped. Lua helpers: flow_litemount.lua
(HARNESS.litemount). Steps: flow_litemount_steps.py. Test words (S.TESTS) fill only the keys the data lacks.

  * Game A (English client): 1 at login: panels, titles, settings categories, macro help, the Import button,
    conditions, actions, sort keys, filters and "Not" lines ours; the Mounts tabs fitted again. 9 keyboard free.
    2 the 7 dialogs and 4 key binding names. 3 the Falling dropdown's radio (its menuGenerator), both ways; the
    Mounts filter menu, the General page's names and the rule errors, each both ways (lesson 15); lines glued
    to a game global (DEFAULT, MOUNT, OPTIONS_MENU, KEY_BUTTON1, the counts' TOTAL+COLLECTED; "Announce via" with CHAT; uidebug with
    BUG_CATEGORY5): whole English while that global is English. A filter menu whose generator throws: whole English.
    4 hold key. 6 the player's names stay as typed, also on a rule's argument button and a Name label (lesson 13). 7 status. 8 off and on. 5 never English over a
    text LiteMount changed since (lesson 23). No half line (halves_mods.litemount). 10 five errors turn it off.
  * Game B: two spoiled words (a % spec, an escape the English lacks) are not used.
  * A Russian client and a LiteMount with no L: nothing changes.
  * Mutants (one fix cut from one module file, in memory only): each named step must fail, so it has teeth.
"""
import collections
import gc
import os
import sys

import flow_litemount_steps as S
import halves_mods
import session
from loader import Addon, Client, lua_str, read_text

HERE = os.path.dirname(os.path.abspath(__file__))
MODULE = "UADD_LiteMount"
FALLING = "menuGenerator"   # the field the game's DropdownButtonMixin:SetupMenu keeps the Falling menu in


def root():
    return os.path.join(session.addons_dir(), "LiteMount")


def installed():
    return os.path.isfile(os.path.join(root(), "Localization.lua"))


def _game(cut=None, bad=False, locale="enUS", noL=False):
    addons = [Addon("LiteMount", os.path.join(HERE, "litemount"), session.FLAVOR)]
    addons += [Addon(n, os.path.join(session.REPO, n), session.FLAVOR) for n in ("UADD", MODULE)]
    c = Client(addons, None, locale)
    c.lua.execute(read_text(os.path.join(HERE, "flow_litemount.lua")))
    M = c.H.litemount
    M.feed(None if noL else lua_str(read_text(os.path.join(root(), "Localization.lua"))), noL or None)
    for k, w in S.TESTS.items():
        M.test(lua_str(k), lua_str(w))
    M.cut = cut and lua_str(cut)
    M.bad = bad or None
    c.start()
    c.H.pump(60)
    return c, M


def _errors(c, check, step, skip=()):
    errs = [e for e in c.errors() if not any(s in e[1] for s in skip)]
    check(f"{step}: no Lua errors", not errs, "; ".join(f"{w}: {m[:160]}" for w, m, _ in errs[:3]))


# Lines LiteMount glues to game globals: global (or "A+B") -> (step, the line from a word lookup and the global (a
# dict for "A+B"), the key it also shows alone or None). The stand-in builds each as the installed code does.
GLUED = {
    "TOTAL+COLLECTED": ("default", lambda w, g: f"{g['TOTAL']}: |cffffffff5|r {g['COLLECTED']}: |cffffffff3|r "
                        f"{w('LM_USABLE')}: |cffffffff2|r", None),
    "DEFAULT": ("default", lambda w, g: f"{w('LM_SUMMON_STYLE_PRIORITY')} ({g}) | {w('LM_EVERY_TIME')} ({g})", None),
    "MOUNT": ("default", lambda w, g: f"|cffff00ff{w('LM_LEFT_CLICK')}: {g}|r", None),
    "OPTIONS_MENU": ("default", lambda w, g: f"|cffff00ff{w('LM_RIGHT_CLICK')}: {g}|r", None),
    "KEY_BUTTON1": ("default", lambda w, g: f"{g}: {w('LM_TOGGLE')}", None),
    "CHAT": ("announce", lambda w, g: f"{g} + {w('LM_ON_SCREEN_DISPLAY')}", "LM_ON_SCREEN_DISPLAY"),
    "BUG_CATEGORY5": ("uidebug", lambda w, g: f"{g} {w('LM_DEBUGGING_ENABLED')}", "LM_DEBUGGING_ENABLED"),
}
GLUED_CODE = (("UI/General.lua", 'string.format("%s (%s)", L.LM_SUMMON_STYLE_PRIORITY, DEFAULT)'),
              ("UI/General.lua", 'string.format("%s (%s)", L.LM_EVERY_TIME, DEFAULT)'),
              ("UI/General.lua", "container:Add(3, CHAT .. ' + ' .. L.LM_ON_SCREEN_DISPLAY)"),
              ("UI/General.lua", "container:Add(2, L.LM_ON_SCREEN_DISPLAY)"),
              ("UI/MountTooltip.lua", 'self:AddLine("|cffff00ff" .. L.LM_LEFT_CLICK .. ": " .. MOUNT .. "|r")'),
              ("UI/MountTooltip.lua", 'self:AddLine("|cffff00ff" .. L.LM_RIGHT_CLICK .. ": " .. OPTIONS_MENU .. "|r")'),
              ("UI/MountsFilter.lua", "GameTooltip_AddInstructionLine(tooltip, KEY_BUTTON1 .. ': ' .. L.LM_TOGGLE)"),
              ("SlashCommand.lua", "LM.Print(BUG_CATEGORY5 .. ' ' .. L.LM_DEBUGGING_ENABLED)"),
              ("SlashCommand.lua", "LM.Print(L.LM_DEBUGGING_ENABLED)"),
              ("Print.lua", "local msg = format(...)"),
              ("UI/Mounts.lua", "'%s: %s %s: %s %s: %s',"), ("UI/Mounts.lua", "L.LM_USABLE,"))


def glued(check, M, step):
    """Each line glued to a game global: whole English while it is English, whole Ukrainian while it is Cyrillic;
    English while held and off. A word it also shows alone is ours there either way."""
    def en(k): return S.tx(M.en(lua_str(k)))  # noqa: E704
    def uk(k): return S.tx(M.word(lua_str(k)))  # noqa: E704
    ok, seen = True, {}
    for key, (st, line, alone) in GLUED.items():
        if st != step:
            continue
        gs = key.split("+")
        was = {g: S.tx(M.setGlobal(lua_str(g), None)) for g in gs}
        cases = [was, dict.fromkeys(gs, "Кирилиця")] + ([dict(was, **{gs[0]: "Кирилиця"})] if len(gs) > 1 else [])
        for vals in cases:                  # all English, all Cyrillic, one of several Cyrillic (English)
            for g in gs:
                M.setGlobal(lua_str(g), lua_str(vals[g]))
            S.uadd(M, "litemount off")
            S.uadd(M, "litemount on")
            got = S._ways(M, lambda: tuple(S.tx(x) if x else None for x in M.glued(lua_str(key))))
            arg = vals[gs[0]] if len(gs) == 1 else vals
            le = line(en, arg)
            lu = line(uk, arg) if all(S.cyr(vals[g]) for g in gs) else le
            a = (uk(alone), en(alone)) if alone else (None, None)
            want = [(lu, a[0]), (le, a[1]), (lu, a[0]), (le, a[1]), (lu, a[0])]
            ok = ok and got == want and "None" not in lu and (not alone or None not in a)
            seen[f"{key}={'/'.join(vals.values())}"] = got[:2]
        for g in gs:
            M.setGlobal(lua_str(g), lua_str(was[g]))
        S.uadd(M, "litemount off")
        S.uadd(M, "litemount on")
    check(S.STEPS[step], ok, seen)
    return ok


def whole(check, M):
    """Their filter generator throws part-way once: that opening is whole English, the next one has no error."""
    en, got = S.tx(M.filterExpect(lua_str("en"))), []
    M.throw(1, lua_str("filterThrow"))
    for _ in range(2):
        try:
            got.append(S.tx(M.filterOpen()[0]))
        except Exception as e:  # noqa: BLE001  (an error that reached the menu)
            got.append(f"error: {e}"[:160])
    ok = bool(en) and got == [en, en]
    check(S.STEPS["whole"], ok, {"want": en, "got": got})
    return ok


def elsewhere_step(check, c, M, step, want):
    S.uadd(M, "litemount")
    said = "\n".join(c.chat()[-4:])
    hits = S.tx(M.anyOurs(step == "noL")) or ""
    ok = want in said and M.written() == 0 and not hits and not M.on()
    check(S.STEPS[step], ok, (hits[:200], said[-160:]))
    return ok


def game_a(check):
    c, M = _game()
    check("module on, its words in L", M.on() and M.written() > 0, M.written())
    S.login(check, M)
    S.focus(check, M)
    S.popups(check, M)
    S.falling(check, M)
    S.filter_menu(check, M)
    S.general(check, M)
    for step in ("default", "announce", "uidebug"):
        glued(check, M, step)
    S.rules(check, M)
    S.hold(check, M)
    S.names(check, M)
    S.status(check, c, M)
    S.off(check, c, M)
    S.changed(check, M)
    whole(check, M)                 # last of the filter menu checks: it leaves the menu English for the session
    halves_mods.litemount(check, M, S.templates(M))
    _errors(c, check, "game A before the errors")
    S.faults(check, c, M)
    del c, M


def game_b(check):
    c, M = _game(bad=True)
    S.spoiled(check, M)
    _errors(c, check, "game B (spoiled words)")


def elsewhere(check):
    c, M = _game(locale="ruRU")
    elsewhere_step(check, c, M, "ruRU", "не працює")
    _errors(c, check, "a Russian client")
    del c, M
    c, M = _game(noL=True)
    elsewhere_step(check, c, M, "noL","чекає: таблицю слів LiteMount не знайдено")
    _errors(c, check, "no LiteMount.LM.L")


# cut -> (the sub-check it must break, how to build its game, how to reach it on a fresh game).
MUTANTS = {
    "usable": ("spoiled", dict(bad=True), lambda q, c, M: S.spoiled(q, M)),
    "restore": ("off", {}, lambda q, c, M: S.off(q, c, M)),
    "hold": ("hold", {}, lambda q, c, M: S.hold(q, M)),
    "falling": ("falling", {}, lambda q, c, M: S.falling(q, M)),
    "fields": ("popups", {}, lambda q, c, M: S.popups(q, M)),
    "keep": ("changed", {}, lambda q, c, M: S.changed(q, M)),
    "filter": ("filter", {}, lambda q, c, M: S.filter_menu(q, M)),
    "general": ("general", {}, lambda q, c, M: S.general(q, M)),
    "rules": ("rules", {}, lambda q, c, M: S.rules(q, M)),
    "walk": ("names", {}, lambda q, c, M: S.names(q, M)),
    "default": ("default", {}, lambda q, c, M: glued(q, M, "default")),
    "counts": ("default", {}, lambda q, c, M: glued(q, M, "default")),
    "whole": ("whole", {}, lambda q, c, M: whole(q, M)),
    "announce": ("announce", {}, lambda q, c, M: glued(q, M, "announce")),
    "uidebug": ("uidebug", {}, lambda q, c, M: glued(q, M, "uidebug")),
}


def mutants(check):
    for cut, (sub, kw, reach) in MUTANTS.items():
        got = {}

        def quiet(name, ok, detail=""): got[name] = ok  # noqa: E704
        c, M = _game(cut=cut, **kw)
        reach(quiet, c, M)
        ok = got.get(S.STEPS[sub])
        check(f"mutant {cut} (a module file without that fix, in memory only): step '{S.STEPS[sub]}' fails",
              M.wasCut and ok is False, "cut not found" if not M.wasCut else "it passed" if ok else "")
        del c, M
        gc.collect()


def run(check, facts):
    if not os.path.isfile(os.path.join(session.REPO, MODULE, MODULE + ".toc")):
        return check(f"{MODULE} is there", False, f"no {MODULE}/{MODULE}.toc")
    if not installed():
        check("LiteMount checks (skipped: LiteMount is not installed)", True, "")
        return halves_mods.litemount(check, None, [], halves_mods.SKIP)
    S.code(check, root(), GLUED_CODE)
    for game in (lambda: game_a(check), lambda: game_b(check), lambda: elsewhere(check), lambda: mutants(check)):
        game()
        gc.collect()
    facts["Falling dropdown field"] = FALLING


Check = collections.namedtuple("Check", "name ok detail")


def run_checks():
    """Every check of this file. Returns (checks, facts)."""
    checks, facts = [], {}

    def check(name, ok, detail=""):
        checks.append(Check("litemount: " + name, bool(ok), str(detail)))
    run(check, facts)
    return checks, facts


if __name__ == "__main__":       # alone: python3 tools/harness/flow_litemount.py
    cs, fs = run_checks()
    for x in cs:
        print(("ok    " if x.ok else "FAIL  ") + x.name + (f"  [{x.detail}]" if x.detail else ""))
    print(fs)
    print(f"{sum(x.ok for x in cs)}/{len(cs)} passed")
    sys.exit(0 if all(x.ok for x in cs) else 1)
