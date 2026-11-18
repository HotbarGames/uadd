"""Part of flow_lsw.py (game A): no half-translated line, the hold key (Shift = English), combat, and
"/uadd layerswap off" / "on".

  * halves_mods.lsw: every template of the installed addon, made-up English in each slot.
  * glued(): the lines LayerSwap glues with a wide gap (mini bar on one line, minimap tooltip) are
    all Ukrainian.
  * Shift held: the panel, the button label, the lazy menu and the tooltip show the addon's own English
    and fonts; let go, Ukrainian again.
  * Combat: texts set in combat are still translated (only font object changes wait).
  * Off: exact English, our fonts gone, chat put back. On: Ukrainian again.
"""
import re

import halves
import halves_mods
import hashtext
from loader import lua_str, txt

FRIZ = "Fonts\\FRIZQT__.TTF"


def _all(M, EN, UK, which, letter):
    """[(name, got, want)] for the panel, the button and the layer menu."""
    w = EN if which == "en" else UK
    return [("heading", M.text("heading"), w["heading"]),
            ("layer", M.text("layer"), w["layer_t"] % letter),
            ("button", M.text("swap"), w["leave"]),
            ("menu age", M.text("menuAge"), w["ago_t"] % "3")]


def _same(check, name, rows):
    bad = [(n, txt(g), w) for n, g, w in rows if txt(g) != w]
    check(name, not bad, bad[:3])


# The texts LayerSwap glues with a wide gap (its one-line mini bar: name, gap, status; its minimap
# tooltip's first line: name, gap, "Host on"), by key (hashtext.key) of its English: names, then
# (status template or exact text, the values of its slots).
GLUED_NAMES = (("8:ebb2717a", ("B",)), ("12:fc83be06", ()), ("13:04f97572", ()))
GLUED_TAILS = (("12:3c294e85", ("|cffffb040", " 4:59")), ("12:3c294e85", ("|cffffb040", "")),
               ("12:4f100e04", ("|cff8a8a8a",)), ("18:ef7869fc", ("|cff8a8a8a",)), ("22:80b4f84d", ()))


def _english_left(t):
    """English words left in t (colour codes taken out); a layer's letter alone is not a word."""
    return re.findall(r"[A-Za-z]{2,}", re.sub(r"\|c[0-9a-fA-F]{8}|\|r", "", t))


def glued(check, M):
    """The real glued lines (the installed addon's English, never kept here): all Ukrainian, each half
    as it is alone, so no free slot at a text's edge swallows the other half (docs/LESSONS.md, lesson 7)."""
    import make_lsw_data
    name = "the glued mini bar and tooltip lines are whole Ukrainian"
    if not make_lsw_data.have_addon():
        return check(f"{name} (LayerSwap not installed)", True, "")
    kept, _ = make_lsw_data.collect()
    by_key = {hashtext.key(en): en for _, en in make_lsw_data.texts(kept)}
    bad, n = [], 0
    for nk, nv in GLUED_NAMES:
        for tk, tv in GLUED_TAILS:
            if nk not in by_key or tk not in by_key:
                bad.append(("gone", nk, tk))
                continue
            head = halves.fill(by_key[nk], lambda k, _: nv[k - 1])
            tail = halves.fill(by_key[tk], lambda k, _: tv[k - 1])
            gap = "" if tail.startswith("   ") else "   "     # the host mark brings its own gap
            text = head + gap + tail
            want = [txt(M.uk(lua_str(p))) if M.uk(lua_str(p)) else None for p in (head, tail)]
            got = M.uk(lua_str(text))
            got = txt(got) if got else None
            n += 1
            if None in want or got != want[0] + gap + want[1] or _english_left(got):
                bad.append((text, got, want))
    check(f"{name} ({n})", n and not bad, bad[:2])


def checks(check, eq, M, EN, UK, Cyr, c):
    halves_mods.lsw(check, M)
    glued(check, M)
    M.menu(True, 3)
    M.wait(0.1)
    _same(check, "before Shift: Ukrainian", _all(M, EN, UK, "uk", "D"))
    # Hold Shift: English, its own fonts.
    M.key(True)
    M.wait(0.4)
    _same(check, "Shift held: English", _all(M, EN, UK, "en", "D"))
    check("Shift held: button keeps its own font", not Cyr(M.font("swap")[0]), M.font("swap")[0])
    M.hover()
    eq(check, "Shift held: tooltip English", M.tipLine(1), EN["shift"])
    check("Shift held: tooltip font", txt(M.tipFont(1)) == FRIZ, M.tipFont(1))
    M.leave()
    M.wait(1.1)
    _same(check, "Shift held: English after its own refresh", _all(M, EN, UK, "en", "D"))
    M.key(False)
    M.wait(0.4)
    _same(check, "Shift let go: Ukrainian again", _all(M, EN, UK, "uk", "D"))
    p, size = M.font("swap")[:2]
    check("Shift let go: button Cyrillic font at its object's size", Cyr(p) and size == M.objectSize("swap"),
          f"{p} {size} {M.objectSize('swap')}")
    # Combat: its refresh still runs.
    M.combat(True)
    M.letter(lua_str("E"))
    M.wait(1.1)
    eq(check, "combat: layer line translated", M.text("layer"), UK["layer_t"] % "E")
    M.combat(False)
    M.wait(0.2)
    # Off: exact English, fonts and chat put back.
    M.uadd("layerswap off")
    M.wait(0.2)
    _same(check, "off: exact English", _all(M, EN, UK, "en", "E"))
    check("off: our fonts gone", M.fontCount() == 0, M.fontCount())
    check("off: button keeps its own font", not Cyr(M.font("swap")[0]), M.font("swap")[0])
    check("off: chat put back", M.chatPutBack(), "")
    M.say(lua_str(EN["nobody"]))
    eq(check, "off: say() line English", M.lastChat(), txt(M.prefix()) + EN["nobody"])
    M.hover()
    eq(check, "off: tooltip English", M.tipLine(1), EN["shift"])
    M.leave()
    M.wait(1.1)
    _same(check, "off: English after its own refresh", _all(M, EN, UK, "en", "E"))
    # On again.
    M.uadd("layerswap on")
    M.wait(1.2)
    _same(check, "on again: Ukrainian", _all(M, EN, UK, "uk", "E"))
    M.say(lua_str(EN["nobody"]))
    eq(check, "on again: say() line Ukrainian", M.lastChat(), txt(M.prefix()) + UK["nobody"])
    M.hover()
    eq(check, "on again: tooltip Ukrainian", M.tipLine(1), UK["shift"])
    M.leave()
