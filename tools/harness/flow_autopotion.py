"""UADD_AutoPotion on a stand-in for Auto Potion (tools/harness/autopotion: its six settings pages built
at its own ADDON_LOADED, check boxes with and without an icon, its Reset button, tooltips on OnEnter,
its chat lines and its key binding names). The stand-in holds none of Auto Potion's English: this flow
reads the real texts from the installed addon (make_ap_text.texts) and hands them in by hash before the
game starts. The expected Ukrainian is data/words.lua's own (ns.AP, read by M.want in the flow's Lua).

  * Game A (English client): load order, then the Info page (exact texts, templates, a coloured text, a
    made-up text and a link that stay), fonts read back (also on the Food page opened later), the Heal
    page's Reset button and icon check boxes refitted, the hold key, "/uadd autopotion off" and "on",
    tooltips (ours and another addon's), chat lines, key binding names, the half-translation check and
    the speed of the miss paths. The checks that need our Ukrainian: flow_autopotion_uk.py.
  * Game B: no Auto Potion (the module waits).
Checks that need our Ukrainian are skipped with a note while data/words.lua is still empty.
"""
import collections
import gc
import os
import sys

import halves_mods
import session
from flow_autopotion_uk import txt, ukrainian

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import make_ap_text  # noqa: E402
from loader import Addon, Client, lua_str, read_text  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
STAND_IN = Addon("AutoPotion", os.path.join(HERE, "autopotion"), session.FLAVOR)
MODULE = "UADD_AutoPotion"
EMPTY = "skipped: data/words.lua has no Ukrainian yet"
SPEED_N = 10000
SPEED_MS = 150         # 3 x SPEED_N misses (a text, a chat line, a shown FontString)
SPEED_KB = 4           # garbage they may make in all
PAGES = ("Info", "Heal", "ManaPotion", "Food", "Drink", "Bandage")


def module_there():
    return os.path.isfile(os.path.join(session.REPO, MODULE, MODULE + ".toc"))


def english():
    """{hash: English} of Auto Potion's texts, or None when it is not installed."""
    addon = make_ap_text.addon_dir()
    if not (addon / "Locales" / "enUS.lua").is_file():
        return None
    return {k: en for k, _, en, _ in make_ap_text.texts(addon)}


def _addon(name):
    return Addon(name, os.path.join(session.REPO, name), session.FLAVOR)


def _game(addons, en):
    c = Client(addons, None, "enUS")
    c.lua.execute(read_text(os.path.join(HERE, "flow_autopotion.lua")))
    c.lua.globals().AP_STANDIN_EN = c.lua.table_from({k: lua_str(v) for k, v in (en or {}).items()})
    c.start()
    c.H.pump(60)
    return c, c.H.ap


def _errors(c, check, step):
    errs = c.errors()
    check(f"{step}: no Lua errors", not errs, "; ".join(f"{w}: {m[:160]}" for w, m, _ in errs[:3]))


def game_a(check, facts, en):
    c, M = _game([STAND_IN, _addon("UADD"), _addon(MODULE)], en)
    # 1. Load order like the game: the pages exist before UADD loads; the module then starts.
    check("load order: six pages built at Auto Potion's ADDON_LOADED, before UADD",
          M.pageCount() == 6 and M.uaddAtBuild() is False, (M.pageCount(), M.uaddAtBuild()))
    check("module on after login", M.on(), "")
    check("chat wrapped", M.chatActive(), "")
    facts["words"], facts["data"] = int(M.count()), int(M.dataCount())
    if M.dataCount() == 0:
        check(f"Ukrainian on pages, fonts, boxes, hold key, off/on, tooltips, chat, bindings ({EMPTY})", True, EMPTY)
    else:
        ukrainian(check, c, M, en)
    # 8. No half-translated line.
    halves_mods.ap(check, M)
    # 9. Speed: the miss paths.
    M.page("Heal", True)
    ms, kb = M.speed(SPEED_N)
    M.page("Heal", False)
    facts["speed_ms"], facts["garbage_kb"] = round(ms, 2), round(kb, 2)
    check(f"speed: {3 * SPEED_N} misses under {SPEED_MS} ms, under {SPEED_KB} KB garbage",
          ms < SPEED_MS and kb < SPEED_KB, f"{ms:.1f} ms, {kb:.1f} KB")
    facts["texts"], facts["fonts"] = int(M.textCount()), int(M.fontCount())
    _errors(c, check, "game A")


def game_b(check):
    c, M = _game([_addon("UADD"), _addon(MODULE)], None)
    out = txt(M.uadd("autopotion") or "")
    _errors(c, check, "game B (no Auto Potion)")
    last = " ".join(txt(x) for x in list(c.H.chat.values())[-3:])
    check("game B: module waits", "Auto Potion" in last and not M.standIn(), out or last)


def run(check, facts):
    if not module_there():
        check("UADD_AutoPotion is there", False, "no UADD_AutoPotion/UADD_AutoPotion.toc")
        return
    en = english()
    if en is None:
        check("Auto Potion checks (skipped: Auto Potion is not installed)", True, "")
        halves_mods.ap(check, None)
        return
    for g in (lambda: game_a(check, facts, en), lambda: game_b(check)):
        g()
        gc.collect()


Check = collections.namedtuple("Check", "name ok detail")


def run_checks():
    """Every check of this file. Returns (checks, facts)."""
    checks, facts = [], {}

    def check(name, ok, detail=""):
        checks.append(Check("ap: " + name, bool(ok), str(detail)))
    run(check, facts)
    return checks, facts


if __name__ == "__main__":       # alone: python3 tools/harness/flow_autopotion.py
    cs, fs = run_checks()
    for x in cs:
        print(("ok    " if x.ok else "FAIL  ") + x.name + (f"  [{x.detail}]" if x.detail else ""))
    print(fs)
    print(f"{sum(x.ok for x in cs)}/{len(cs)} passed")
    sys.exit(0 if all(x.ok for x in cs) else 1)
