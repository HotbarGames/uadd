"""UADD_LayerSwap on a stand-in for LayerSwap (tools/harness/layerswap: its named panel refreshed every
second, a button label set the way it sets it, two menus made when first opened, a tooltip on a menu
row, chat lines through say()). The expected Ukrainian is data/words.lua's own wording.

  * Game A (English client): the panel's heading, layer line (a template) and button label, the
    button's font after its own shrink, the lazy layer menu (a template age column) and settings menu,
    a tooltip over its row, its chat lines (an unknown one and another addon's stay), then
    flow_lsw_mixed.py: no half-translated line, the hold key, combat, "/uadd layerswap off" and "on".
  * Game B: no LayerSwap (the module stays idle).
"""
import collections
import gc
import os
import sys

import flow_lsw_mixed
import session

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import glossary  # noqa: E402
import lsw_words  # noqa: E402
from loader import Addon, Client, lua_str, read_text, txt

HERE = os.path.dirname(os.path.abspath(__file__))
STAND_IN = Addon("LayerSwap", os.path.join(HERE, "layerswap"), session.FLAVOR)
MODULE = "UADD_LayerSwap"


def module_there():
    return os.path.isfile(os.path.join(session.REPO, MODULE, MODULE + ".toc"))


def _addon(name):
    return Addon(name, os.path.join(session.REPO, name), session.FLAVOR)


def _game(addons, locale="enUS"):
    c = Client(addons, None, locale)
    c.lua.execute(read_text(os.path.join(HERE, "flow_lsw.lua")))
    c.start()
    c.H.pump(60)
    return c, c.H.lsw


def _errors(c, check, step):
    errs = c.errors()
    check(f"{step}: no Lua errors", not errs, "; ".join(f"{w}: {m[:160]}" for w, m, _ in errs[:3]))


def _eq(check, name, got, want):
    got = txt(got)
    check(name, got == want, f"{got!r} | want {want!r}")


def expected(M):
    """{English: our Ukrainian from data/words.lua} for the stand-in's texts; a text the data does not
    translate maps to its English (its check then fails and names it)."""
    en = {k: txt(M.en(k)) for k in ("heading", "swap", "leave", "now", "options", "shift", "nobody")}
    en["layer_t"] = en_layer = txt(M.en("layer")) + "%s"
    en["ago_t"] = "%s" + txt(M.en("ago"))
    with open(os.path.join(session.REPO, MODULE, "data", "words.lua"), encoding="utf-8") as f:
        _, want = lsw_words.overlay({v: v for v in en.values()}, f.read(), glossary.Glossary())
    assert en_layer in want
    return en, {k: want[v] for k, v in en.items()}


def game_a(check, facts):
    c, M = _game([STAND_IN, _addon("UADD"), _addon(MODULE)])
    EN, UK = expected(M)
    Cyr = c.lua.globals().UADD.IsCyrFont
    missing = [EN[k] for k in EN if UK[k] == EN[k]]
    check("data/words.lua translates every stand-in text", not missing, missing)
    check("words built", M.wordCount() > 100, M.wordCount())
    # The panel: shown, then refreshed every second by LayerSwap itself.
    M.panel(True)
    M.wait(1.2)
    _eq(check, "panel heading", M.text("heading"), UK["heading"])
    _eq(check, "panel layer line (template)", M.text("layer"), UK["layer_t"] % "B")
    _eq(check, "button label", M.text("swap"), UK["swap"])
    check("panel texts hooked", M.hooked("heading") and M.hooked("swap"), "")
    p, size = M.font("swap")[:2]
    check("button label: Cyrillic font at its font object's size (after its own shrink)",
          Cyr(p) and size == M.objectSize("swap"), f"{p} {size} {M.objectSize('swap')}")
    check("guard (no Ukrainian in a font without Ukrainian letters)", not session.cyr_boxes(c), session.cyr_boxes(c)[:3])
    M.grouped(True)
    M.letter(lua_str("D"))
    M.wait(1.1)
    _eq(check, "button label set again by its refresh", M.text("swap"), UK["leave"])
    _eq(check, "layer line set again by its refresh", M.text("layer"), UK["layer_t"] % "D")
    # Greyed out: its label shows the disabled font object, set again on each refresh. Read right
    # after one refresh (no later scan in between): the button's own hook must have done it.
    M.enabled(False)
    M.wait(1.1)
    M.refresh()
    p, size = M.font("swap")[:2]
    check("disabled button: Cyrillic font at its font object's size", Cyr(p) and size == M.objectSize("swap"),
          f"{p} {size} {M.objectSize('swap')}")
    M.enabled(True)
    M.wait(1.1)
    # The layer menu: made when first opened (CreateFrame hook, a look on the next frame).
    M.menu(True, 0)
    M.wait(0.1)
    _eq(check, "lazy menu: layer", M.text("menuName"), UK["layer_t"] % "C")
    _eq(check, "lazy menu: age", M.text("menuAge"), UK["now"])
    M.menu(True, 12)
    _eq(check, "lazy menu: age template, set again", M.text("menuAge"), UK["ago_t"] % "12")
    M.menu(False)
    # The settings menu and the tooltip over its row.
    M.settings(True)
    M.wait(0.1)
    _eq(check, "lazy settings menu row", M.text("options"), UK["options"])
    M.hover()
    _eq(check, "tooltip over its row", M.tipLine(1), UK["shift"])
    check("tooltip: Cyrillic font", Cyr(M.tipFont(1)), M.tipFont(1))
    M.leave()
    check("tooltip: font back when hidden", txt(M.tipFont(1)) == "Fonts\\FRIZQT__.TTF", M.tipFont(1))
    # Chat: its say() lines.
    pre = txt(M.prefix())
    M.say(lua_str(EN["nobody"]))
    _eq(check, "chat: say() line translated, its name kept", M.lastChat(), pre + UK["nobody"])
    M.say(lua_str("Some other line."))
    _eq(check, "chat: unknown say() line stays", M.lastChat(), pre + "Some other line.")
    M.chatLine(lua_str(EN["nobody"]))
    _eq(check, "chat: a line without its name stays", M.lastChat(), EN["nobody"])
    flow_lsw_mixed.checks(check, _eq, M, EN, UK, Cyr, c)
    _errors(c, check, "game A")


def game_b(check):
    c, M = _game([_addon("UADD"), _addon(MODULE)])
    out = txt(M.uadd("layerswap") or "")
    _errors(c, check, "game B (no LayerSwap)")
    last = " ".join(txt(x) for x in list(c.H.chat.values())[-3:])
    check("game B: module waits", "LayerSwap" in last and not M.standIn(), out or last)


def run(check, facts):
    if not module_there():
        check("UADD_LayerSwap is there", False, "no UADD_LayerSwap/UADD_LayerSwap.toc")
        return
    for g in (lambda: game_a(check, facts), lambda: game_b(check)):
        g()
        gc.collect()


Check = collections.namedtuple("Check", "name ok detail")


def run_checks():
    """Every check of this file. Returns (checks, facts)."""
    checks, facts = [], {}

    def check(name, ok, detail=""):
        checks.append(Check("lsw: " + name, bool(ok), str(detail)))
    run(check, facts)
    return checks, facts


if __name__ == "__main__":       # alone: python3 tools/harness/flow_lsw.py
    cs, fs = run_checks()
    for x in cs:
        print(("ok    " if x.ok else "FAIL  ") + x.name + (f"  [{x.detail}]" if x.detail else ""))
    print(fs)
    print(f"{sum(x.ok for x in cs)}/{len(cs)} passed")
    sys.exit(0 if all(x.ok for x in cs) else 1)
