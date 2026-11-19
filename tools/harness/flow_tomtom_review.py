"""UADD_TomTom review fixes (stage 6; docs/LESSONS.md lesson 12) on the TomTom stand-in. Called from
flow_tomtom.py game A, after the main steps. Each case fails without its fix:

  * 1 A profile named exactly like a TomTom settings text stays as typed in the profile dropdown; the
    installed TomTom still names its profile settings the way Settings.lua finds them.
  * 2 A chat line that is not TomTom's (the same words, from other code) never reaches Translate and does
    not grow the Words cache; TomTom's own line with those words is still ours.
  * 3 The arrow written with the same text on many frames: Translate once, ours on every frame.
  * 4 A unit's GameTooltip (English, or UALL Forever's Ukrainian in its own font) runs no debugstack;
    TomTom's own GameTooltip line still gets our font.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import hashtext  # noqa: E402
import make_tt_text  # noqa: E402
from loader import lua_str, txt  # noqa: E402

ZONE = "Quixwood Vale"                  # the made-up zone flow_tomtom.py gives a UALL name
FRAMES = 50
UNIT_UK = "Квіксвудський кабан"
PROFILE_VAR = '"TOMTOM_PROFILE_"'       # Settings.lua PLAYER: how TomTom names its profile settings


def _w(M, en):
    return txt(M.want(lua_str(hashtext.key(en))) or "")


def _fill(M, en, *v):
    return txt(M.fill(lua_str(hashtext.key(en)), *(lua_str(str(x)) for x in v)) or "")


def _profile(check, M, p):
    got = txt(M.profileEntry())
    check("review 1: a profile named like a TomTom settings text stays as typed in the profile dropdown",
          got == p["option"] != _w(M, p["option"]), got)
    src = make_tt_text.addon_dir() / "core" / "profiles.lua"
    found = src.is_file() and PROFILE_VAR in src.read_text(encoding="utf-8", errors="replace")
    check("review 1: the installed TomTom still names its profile settings TOMTOM_PROFILE_* (Settings.lua)",
          found, str(src))


def _chat(check, M, p):
    if not p["removed"]:
        return check("review 2: chat (skipped: the plural-and-zone line is not shipped)", True, "")
    en = p["removed"]
    line = en % (3, ZONE)                                   # not seen before: Translate would cache it
    calls, grew, shown = M.otherChat(lua_str(line))
    check("review 2: another addon's chat line: no Translate call, Words cache the same, line as it is",
          (int(calls), int(grew), txt(shown)) == (0, 0, line), (calls, grew, txt(shown)))
    got = txt(M.chat(lua_str(en), 3, lua_str(ZONE)))
    check("review 2: TomTom's own plain chat line with the same words still ours", got == _fill(M, en, 3, "Долина Квіксвуд"),
          got)


def _arrow(check, M, p):
    if not p["dist"]:
        return check("review 3: arrow (skipped: distance text not shipped)", True, "")
    calls, text, cyr = M.arrowSame(lua_str(p["dist"]), FRAMES, 7)
    check(f"review 3: the arrow with the same distance text for {FRAMES} frames: Translate once, ours in our font",
          (int(calls), txt(text), bool(cyr)) == (1, _fill(M, p["dist"], 7), True), (calls, txt(text), cyr))


def _tips(check, M, p):
    n_en, n_uk = int(M.unitTip(None)), int(M.unitTip(lua_str(UNIT_UK)))
    check("review 4: a unit tooltip (English, or UALL's Ukrainian in its own font) runs no debugstack",
          (n_en, n_uk) == (0, 0), (n_en, n_uk))
    text, cyr = M.gameTip(lua_str(p["L"]))
    check("review 4: TomTom's own GameTooltip line: ours, in our font", (txt(text), bool(cyr)) == (_w(M, p["L"]), True),
          (txt(text), cyr))


def run(check, M, p):
    _profile(check, M, p)
    _chat(check, M, p)
    _arrow(check, M, p)
    _tips(check, M, p)
