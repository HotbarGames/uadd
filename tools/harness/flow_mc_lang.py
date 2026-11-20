"""UADD_Mastercraft's «Українська» in Mastercraft's own language menu (UADD_Mastercraft/Language.lua), on a
stand-in of that menu (tools/harness/mastercraft/Lang.lua: no code or words of Mastercraft's). Real texts for
its font strings come from the installed Mastercraft (flow_mastercraft.picks); English client.

  mcl 1  the menu gets our row: one more row, the list one row taller, "UA" on the button, our tick.
  mcl 2  another language picked: the module does nothing, that language is whole, no Cyrillic left.
  mcl 3  «Українська» picked again: Mastercraft back on its English (its own English row pressed), ours.
  mcl 4  Mastercraft's saved language is only ever one it knows, and only Mastercraft writes it.
  mcl 5  a menu that does not look like the one we know is left as it was.
  mcl 6  a first run (no choice saved) is on, as before the menu entry.
  mcl 7  its language picked outside the menu (its command, its setup): that language whole, never English.
  mcl 8  "/uadd mastercraft off" while Mastercraft is on another language: that language, never English.
  mcl 9  Mastercraft saved a code it does not know or cannot draw ("zh" without its font): it draws English,
         so ours is on, and «Українська» picked stays on.
Also: its own English row picked, off/on, a saved choice, Mastercraft saved in another language.

python3 tools/harness/flow_mc_lang.py           the checks
python3 tools/harness/flow_mc_lang.py --prove   each step again with its fix taken out: each must FAIL
"""
import collections
import os
import sys

import flow_mastercraft as F
import loader
import session
from loader import Client, lua_str, read_text, txt

HERE = os.path.dirname(os.path.abspath(__file__))
LANG = os.path.join(session.REPO, F.MODULE, "Language.lua")
SCREEN = os.path.join(session.REPO, F.MODULE, "Screen.lua")
CODES = os.path.join(session.REPO, F.MODULE, "LangCodes.lua")
KNOWN = {"nil", "en", "de"}           # Mastercraft's saved language: never set, or a code it knows


def _cut(cut):
    """cut: (file name in the module, its text with a fix taken out)."""
    name, text = cut
    plain = loader.read_text

    def read(path):
        if path.replace("\\", "/").endswith("/" + F.MODULE + "/" + name):
            return text.encode("utf-8").decode("latin-1")
        return plain(path)
    return plain, read


def _menu_addon():
    a = F._stand_in()
    a.files = ["Lang.lua"]                  # only the menu stand-in: its window is made by S.Build
    return a


def _game(texts, codes="en,de", shape="", saved=None, mc_lang=None):
    c = Client([_menu_addon(), F._addon("UADD"), F._addon(F.MODULE)], saved, "enUS")
    c.lua.execute(read_text(os.path.join(HERE, "flow_mastercraft.lua")))
    c.lua.execute(read_text(os.path.join(HERE, "flow_mc_lang.lua")))
    if mc_lang:
        c.lua.execute(f'MastercraftDB = {{ settings = {{ lang = "{mc_lang}" }} }}')
    M = c.H.mcl
    for t in texts:
        M.text(lua_str(t))
    c.start()
    c.H.pump(20)
    M.build(codes, shape)
    return c, M


def _shown(M, n):
    return [txt(M.shown(i)) for i in range(1, n + 1)]


def _run(check, facts):
    src = F.rows()
    if not src:
        check("menu checks (skipped: Mastercraft is not installed)", True, "")
        return
    p = F.picks(src, *F.shipped())
    if not p:
        check("menu: real texts read from the installed Mastercraft", False, len(src))
        return
    en = [p["label"], p["tip"], p["tip2"]]
    c, M = _game(en)
    uk = [F._want(c.H.mc, e) for e in en]
    de = ["[de] " + e for e in en]
    langs = []

    def lang_ok(step):
        lg, last = txt(M.lang()), txt(M.lastWrite())
        langs.append(f"{step}:{lg}")
        return lg in KNOWN and lg == last

    # 6: first run
    s = _shown(M, 3)
    check("mcl 6 first run: on, ours on its strings, no choice saved",
          M.on() and all(uk) and s == uk and txt(M.choice()) == "nil", f"{M.on()} {txt(M.choice())} {s}")
    lang_ok("start")
    # 1: our row
    h = M.height()
    ours, en_tick, _ = M.ticks(None)
    check("mcl 1 menu: our row added, list one row taller, UA, our tick and not its English one",
          M.entry() and M.extra() == 1 and h == 7 * 2 + 26 * 3 and txt(M.code()) == "UA" and ours and not en_tick,
          f"entry {M.entry()} extra {M.extra()} height {h} code {txt(M.code())} ticks {ours}/{en_tick}")
    # 2: another language
    M.pick("de")
    s = _shown(M, 3)
    ours, en_tick, de_tick = M.ticks("de")
    check("mcl 2 other language: module inert, its texts whole German, no Cyrillic, its tick",
          not M.on() and txt(M.choice()) == "other" and s == de and M.cyr() == 0 and txt(M.code()) == "DE"
          and not ours and de_tick and txt(M.lang()) == "de",
          f"on {M.on()} choice {txt(M.choice())} cyr {M.cyr()} code {txt(M.code())} ticks {ours}/{de_tick} {s}")
    check("mcl 4 saved language after another one picked", lang_ok("de"), langs[-1])
    # 3: ours again
    M.pick("uk")
    s = _shown(M, 3)
    ours, en_tick, _ = M.ticks(None)
    check("mcl 3 ours again: Mastercraft on English, ours on its strings, UA, our tick",
          M.on() and txt(M.choice()) == "uk" and txt(M.lang()) == "en" and s == uk and txt(M.code()) == "UA"
          and ours and not en_tick,
          f"on {M.on()} choice {txt(M.choice())} lang {txt(M.lang())} code {txt(M.code())} {s}")
    check("mcl 4 saved language after ours picked", lang_ok("uk"), langs[-1])
    # its own English row: inert too, its English whole
    M.pick("en")
    s = _shown(M, 3)
    check("its English row picked: module inert, its English whole, no Cyrillic",
          not M.on() and txt(M.choice()) == "other" and s == en and M.cyr() == 0 and txt(M.code()) == "EN",
          f"on {M.on()} cyr {M.cyr()} {s}")
    check("mcl 4 saved language after its English picked", lang_ok("en"), langs[-1])
    M.pick("uk")
    check("ours again with Mastercraft already on English", M.on() and _shown(M, 3) == uk, _shown(M, 3))
    # off and on
    M.uadd("mastercraft off")
    off = _shown(M, 3)
    M.uadd("mastercraft on")
    on = _shown(M, 3)
    check("off: its English and its button; on: ours again", off == en and on == uk and M.cyr() > 0,
          f"{off} {on}")
    check("mcl 4 saved language after off/on", lang_ok("off/on"), langs[-1])
    # 7: its own language command (or its setup screen), outside the menu, while ours is on.
    M.setLanguage("de")
    s = _shown(M, 3)
    check("mcl 7 its language command outside the menu: inert, its texts whole German, no Cyrillic or our font",
          not M.on() and txt(M.choice()) == "other" and s == de and M.cyr() == 0 and M.cyrFont() == 0
          and txt(M.code()) == "DE",
          f"on {M.on()} choice {txt(M.choice())} cyr {M.cyr()} font {M.cyrFont()} code {txt(M.code())} {s}")
    check("mcl 4 saved language after its own language command", lang_ok("command"), langs[-1])
    M.pick("uk")
    check("ours again after its language command", M.on() and _shown(M, 3) == uk and txt(M.lang()) == "en",
          f"on {M.on()} lang {txt(M.lang())} {_shown(M, 3)}")
    # 8: "/uadd mastercraft off" while Mastercraft is on German and our words still show.
    M.saveOnly("de")
    M.uadd("mastercraft off")
    s = _shown(M, 3)
    check("mcl 8 off while Mastercraft is on German: its texts whole German, no Cyrillic or our font",
          s == de and M.cyr() == 0 and M.cyrFont() == 0 and txt(M.lang()) == "de",
          f"cyr {M.cyr()} font {M.cyrFont()} lang {txt(M.lang())} {s}")
    M.uadd("mastercraft on")
    check("on again with Mastercraft on German: still inert, its German whole",
          not M.on() and _shown(M, 3) == de and M.cyr() == 0, f"on {M.on()} {_shown(M, 3)}")
    F._errors(c, check, "mcl game")
    facts["mcl: saved languages"] = " ".join(langs)

    # 5: menus we do not know
    for codes, shape, why in (("uk,en,de", "", "it has its own Ukrainian"), ("fr,de", "", "no English row"),
                              ("en,de", "noPaint", "no Paint"), ("en,de", "noCode", "a row without a code")):
        c, M = _game(en, codes, shape)
        n = len(codes.split(","))
        check(f"mcl 5 unknown menu ({why}): left as it was, the module still on",
              not M.entry() and M.extra() == 0 and M.height() == 7 * 2 + 26 * n and M.on()
              and _shown(M, 3) == uk, f"entry {M.entry()} extra {M.extra()} height {M.height()}")
        F._errors(c, check, f"mcl 5 ({why})")

    # A saved choice of another language: inert at login, the row there, its English.
    c, M = _game(en, saved={"UADD": "UADD_DB = { modules = { mastercraft = { enabled = true, choice = \"other\" } } }"})
    check("saved choice 'other': inert at login, our row there, its English, EN",
          not M.on() and M.entry() and _shown(M, 3) == en and txt(M.code()) == "EN" and M.cyr() == 0,
          f"on {M.on()} entry {M.entry()} code {txt(M.code())}")
    F._errors(c, check, "mcl saved choice")
    # Mastercraft saved in German, no choice yet: that is the player's pick.
    c, M = _game(en, mc_lang="de")
    check("Mastercraft saved in German: inert, choice 'other', its German whole, saved language untouched",
          not M.on() and txt(M.choice()) == "other" and _shown(M, 3) == de and M.cyr() == 0
          and txt(M.lang()) == "de" and txt(M.writes()) == "",
          f"on {M.on()} choice {txt(M.choice())} lang {txt(M.lang())} {_shown(M, 3)}")
    F._errors(c, check, "mcl saved German")
    # 9: Mastercraft saved a code it does not know, or one it cannot draw: it draws English, ticks English.
    for code in ("xx", "zh"):
        c, M = _game(en, mc_lang=code)
        s = _shown(M, 3)
        check(f"mcl 9 Mastercraft saved '{code}' (it draws English): on, ours on its strings, its code untouched",
              M.on() and s == uk and txt(M.choice()) != "other" and txt(M.lang()) == code and txt(M.writes()) == "",
              f"on {M.on()} choice {txt(M.choice())} lang {txt(M.lang())} {s}")
        M.pick("uk")
        s = _shown(M, 3)
        check(f"mcl 9 «Українська» picked with '{code}' saved: on, ours, choice 'uk', UA",
              M.on() and s == uk and txt(M.choice()) == "uk" and txt(M.code()) == "UA",
              f"on {M.on()} choice {txt(M.choice())} code {txt(M.code())} {s}")
        F._errors(c, check, f"mcl saved {code}")


def run(check, facts, cut=None):
    plain = None
    if cut is not None:
        plain, loader.read_text = _cut(cut)
    try:
        _run(check, facts)
    finally:
        if plain:
            loader.read_text = plain


Check = collections.namedtuple("Check", "name ok detail")


def run_checks(cut=None):
    """Every check of this file. Returns (checks, facts)."""
    checks, facts = [], {}

    def check(name, ok, detail=""):
        checks.append(Check(name if name.startswith("mcl") else "mcl: " + name, bool(ok), str(detail)))
    run(check, facts, cut)
    return checks, facts


def _replace(*pairs):
    """Language.lua with each (old, new) replaced: replace(old, new[, old2, new2 ...])."""
    with open(LANG, encoding="utf-8") as f:
        text = f.read()
    for old, new in zip(pairs[::2], pairs[1::2]):
        assert old in text, old
        text = text.replace(old, new)
    return os.path.basename(LANG), text


def _edit(path, pairs):
    """That module file with each (old, new) replaced."""
    with open(path, encoding="utf-8") as f:
        name, text = os.path.basename(path), f.read()
    for old, new in pairs:
        assert old in text, old
        text = text.replace(old, new)
    return name, text


def _screen(*pairs):
    """Screen.lua with each (old, new) replaced."""
    return _edit(SCREEN, pairs)


def _codes(*pairs):
    """LangCodes.lua (which language Mastercraft draws in) with each (old, new) replaced."""
    return _edit(CODES, pairs)


# Screen.lua's Restore as it was: its English always put back with the game's setter.
OLD_RESTORE = (('local still = type(wrote) == "string" and type(raw) == "string" and fs:GetText() == wrote',
                'local still = type(raw) == "string"'),
               ("if not ns.Lang or ns.Lang.MastercraftEnglish() then", "if true then"))


def proofs():
    """(step, (file, its text with that step's fix taken out))."""
    return [
        ("mcl 7", _screen(*OLD_RESTORE)),
        ("mcl 8", _screen(OLD_RESTORE[1])),
        ("mcl 1", _replace('pcall(self.HookScript, self, "OnShow", OnShow)', "local _ = OnShow")),
        ("mcl 1", _replace("if menu and not done[menu] then Add(b, menu, rows, en) L.Redraw() end",
                           "if menu and not done[menu] then L.Redraw() end")),
        # (its rows' PreClick and L.Check both see another language picked: both taken out)
        ("mcl 2", _replace('for _, r in ipairs(rows) do r:HookScript("PreClick", Safe(Other)) end', "",
                           'if db and db.choice ~= "other" and sure and lang ~= "en" then', "if false then")),
        ("mcl 3", _replace('local ok = pcall(fn, en, "LeftButton", false)', "local ok = true")),
        ("mcl 4", _replace("    if ns.Begin then ns.Begin() end\n    L.Redraw()",
                           '    MastercraftDB.settings.lang = "uk"\n    if ns.Begin then ns.Begin() end\n    L.Redraw()')),
        ("mcl 5", _replace('        if r.code == "uk" then return end', "", "    if not en then return end\n", "")),
        ("mcl 6", _codes(('db.choice ~= "other" and L.MastercraftEnglish()', 'db.choice == "uk" and L.MastercraftEnglish()'))),
        ("mcl 9", _codes(("    local k = Known()\n", "    local k = nil\n"))),
    ]


if __name__ == "__main__":       # alone: python3 tools/harness/flow_mc_lang.py [--prove]
    if "--prove" in sys.argv:
        bad = 0
        for step, cut in proofs():
            try:
                cs, _ = run_checks(cut)
                failed = [x.name for x in cs if x.name.startswith(step) and not x.ok]
            except Exception as e:
                failed = []
                print(f"  flow stopped: {e!r}"[:300])
            print(("proof ok  " if failed else "PROOF BAD ") + step + ": " + "; ".join(failed)[:300])
            bad += not failed
        sys.exit(1 if bad else 0)
    cs, fs = run_checks()
    for x in cs:
        print(("ok    " if x.ok else "FAIL  ") + x.name + (f"  [{x.detail}]" if x.detail else ""))
    print(fs)
    print(f"{sum(x.ok for x in cs)}/{len(cs)} passed")
    sys.exit(0 if all(x.ok for x in cs) else 1)
