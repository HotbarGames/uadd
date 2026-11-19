"""The UADD_AutoPotion checks that need our Ukrainian (data/words.lua not empty), run by flow_autopotion.py in
game A: the Info, Food and Heal pages (texts and fonts read back), the Reset button and the icon check boxes
refitted, tooltips, the hold key, chat lines, key binding names, and "/uadd autopotion off" and "on".
The expected Ukrainian is data/words.lua's own (ns.AP, read by M.want in flow_autopotion.lua).
"""
from loader import lua_str
from loader import txt as _txt

ICON = 6 * 2 + 28      # Auto Potion's gap, icon, gap before an icon check box's label
INFO = ("title", "version", "author", "copy", "installed", "how", "madeup")
HEAL = ("behaviour", "stopcast", "serum", "soulburn", "spell", "current", "reset", "loginSpell")
# Labels that are a game name (an item or a spell, from Auto Potion's own English): only UALL Forever
# names them, so we have no Ukrainian for them on purpose and they stay whole English.
GAME = ("serum",)


def txt(v):
    """Lua bytes to text; a value already text (Cyrillic past latin-1) as it is."""
    try:
        return _txt(v)
    except UnicodeEncodeError:
        return v


def _eq(check, name, got, want):
    got, want = txt(got), txt(want)
    check(name, want is not None and got == want, f"{got!r} | want {want!r}")


def hash_of(en, text):
    text = txt(text)
    return next(k for k, v in en.items() if v == text)


class Page:
    """The texts of one page: English as set, our Ukrainian from the data, the font before."""

    def __init__(self, M, names):
        self.M, self.names = M, names
        self.en = {n: txt(M.text(n)) for n in names}
        self.want = {n: txt(M.want(n)) if M.hash(n) else None for n in names}
        self.font = {n: tuple(M.font(n)) for n in names}

    def ours(self):
        return [n for n in self.names if self.M.hash(n) and n not in GAME]

    def texts(self, check, name, english=False):
        """Each text: our Ukrainian (or English, english=True); a text with no hash, or a game name,
        stays whole."""
        bad = []
        for n in self.names:
            got = txt(self.M.text(n))
            want = self.en[n] if english or n not in self.ours() else self.want[n]
            if got != want:
                bad.append(f"{n}: {got!r} | want {want!r}")
        check(name, not bad, bad[:3] or f"{len(self.names)} texts")

    def fonts(self, check, name):
        """Our font file read back on each Ukrainian text, at the size and with the flags it had."""
        bad = []
        for n in self.ours():
            p, size, flags = self.M.font(n)
            was = self.font[n]
            if not self.M.isCyr(p) or size != was[1] or txt(flags) != txt(was[2]):
                bad.append(f"{n}: {txt(p)} {size} {txt(flags)!r} | was {txt(was[0])} {was[1]} {txt(was[2])!r}")
        check(name, not bad and self.ours(), bad[:3] or f"{len(self.ours())} texts")

    def fonts_back(self, check, name):
        bad = [n for n in self.ours() if tuple(txt(x) if isinstance(x, str) else x for x in self.M.font(n))
               != tuple(txt(x) if isinstance(x, str) else x for x in self.font[n])]
        check(name, not bad, bad[:3])


def boxes(check, M, label, heal):
    """The Reset button's width and the icon check boxes' click area, fitted to what shows now."""
    w = M.resetWidth()
    check(f"{label}: Reset button width fits its label", w == max(120, M.width("reset") + 20),
          f"{w} | label {M.width('reset')}")
    for n in ("serum", "soulburn", "spell", "loginSpell"):
        r = M.hit(n)
        check(f"{label}: icon check box '{n}' click area fits its label", r == -(ICON + M.width(n)),
              f"{r} | label {M.width(n)}")
    check(f"{label}: plain check box keeps its click area", M.hit("stopcast") == 0, M.hit("stopcast"))


def ukrainian(check, c, M, en):
    """Every check that needs our Ukrainian (data/words.lua not empty)."""
    missing = [n for n in M.names().values() if M.hash(n) and n not in GAME and M.want(n) is None]
    check("data/words.lua has Ukrainian for every stand-in text but game names", not missing, missing)
    named = [n for n in GAME if M.want(n) is not None]
    check("data/words.lua has no Ukrainian for game names (UALL Forever's)", not named, named)
    M.fontWidths()   # our font measures wider: "off" must fit the boxes from the width it fitted them to
    # 1. A page shown: every text with a hash in the data is Ukrainian, the others stay whole English.
    M.settings(True)
    info = Page(M, INFO)
    M.page("Info", True)
    info.texts(check, "Info page shown: our texts Ukrainian, a made-up one whole English")
    check("Info page texts hooked", all(M.hooked(n) for n in INFO), "")
    check("Info page: the link (an edit box) untouched", txt(M.linkText()) == "https://example.invalid/quix",
          txt(M.linkText()))
    M.setInstalled()
    _eq(check, "a text set again by Auto Potion: Ukrainian again", M.text("installed"), info.want["installed"])
    # 2. Fonts, read back: this page, then a page opened later; size and outline kept.
    info.fonts(check, "fonts: our font read back on the Info page, size and outline kept")
    p, size, flags = M.font("title")
    check("fonts: the outlined title keeps its outline", txt(flags) == "OUTLINE" and size == 18, f"{size} {flags}")
    M.page("Info", False)
    food = Page(M, ("foodTitle", "buffFood"))
    M.page("Food", True)
    food.texts(check, "Food page (opened later): texts Ukrainian")
    food.fonts(check, "fonts: our font read back on a page opened later")
    M.page("Food", False)
    # 3. The Heal page: the Reset button and the icon check boxes refitted after our words.
    heal = Page(M, HEAL)
    M.page("Heal", True)
    heal.texts(check, "Heal page: our texts Ukrainian, spell names whole English")
    check("Reset button wider than for its English", M.resetWidth() > max(120, len(heal.en["reset"]) * 6 + 20),
          M.resetWidth())
    boxes(check, M, "Ukrainian", heal)
    # 5. Tooltips: ours over a check box of the pages; another addon's with the same English stays.
    M.hover("stopcast")
    _eq(check, "tooltip over a check box: Ukrainian", M.tipLine(1), M.wantHash(M.tipHash("stopcast")))
    check("tooltip: our font", M.isCyr(M.tipFont(1)), M.tipFont(1))
    M.leave("stopcast")
    check("tooltip: font back when hidden", txt(M.tipFont(1)) == "Fonts\\FRIZQT__.TTF", M.tipFont(1))
    M.hover(None)
    _eq(check, "another addon's tooltip (same English) untouched", M.tipLine(1), en[M.tipHash("stopcast")])
    M.leave(None)
    # 4. The hold key: English back on the shown page, boxes fitted to it; a page opened while held is
    # English; Ukrainian again on release.
    M.key(True)
    heal.texts(check, "hold key: Heal page English", english=True)
    heal.fonts_back(check, "hold key: fonts back")
    boxes(check, M, "hold key", heal)
    _eq(check, "hold key: binding name English", M.binding(1), M.bindingEn(1))
    M.page("Info", True)
    info.texts(check, "hold key: a page opened while held is English", english=True)
    M.key(False)
    heal.texts(check, "hold key released: Heal page Ukrainian again")
    info.texts(check, "hold key released: Info page Ukrainian again")
    boxes(check, M, "hold key released", heal)
    M.page("Info", False)
    # 6. Chat.
    pre, red = txt(M.prefix(False)), txt(M.prefix(True))
    M.purple("102:486aa8d6", "AutoFood")
    _eq(check, "chat: line after its name (a macro name in the free slot)", M.lastChat(),
        pre + txt(M.wantHash("102:486aa8d6", "AutoFood")))
    M.purple("25:a143ba8c")
    want = M.wantHash("25:a143ba8c")
    _eq(check, "chat: /ap debug line after its name", M.lastChat(), pre + txt(want) if want else pre + en["25:a143ba8c"])
    M.chatLine(lua_str(pre + "Zorp went fine."))
    _eq(check, "chat: an unknown line after its name stays", M.lastChat(), pre + "Zorp went fine.")
    M.resetDone()
    _eq(check, "chat: /ap answer alone (reset)", M.lastChat(), M.wantBare("17:bf4baa09"))
    M.badOption(lua_str("frobnicate"))
    _eq(check, "chat: /ap answer alone (wrong option, the word kept)", M.lastChat(),
        M.wantBare("18:9531cf37", "frobnicate"))
    M.error(lua_str("Quix Heal"))
    _eq(check, "chat: red MegaMacro error with a macro name", M.lastChat(),
        red + txt(M.wantHash("79:aa814ae1", "Quix Heal")))
    M.chatLine(lua_str(en["16:1ead0710"]))
    _eq(check, "chat: someone's line that reads like a label stays", M.lastChat(), en["16:1ead0710"])
    M.chatLine(lua_str("[Guild] Quix: anyone up?"))
    _eq(check, "chat: other chat lines stay", M.lastChat(), "[Guild] Quix: anyone up?")
    # 7. Key bindings.
    bad = [i for i in range(1, 6) if txt(M.binding(i)) != txt(M.wantHash(hash_of(en, M.bindingEn(i))))
           or txt(M.bindingOwn(i)) != txt(M.binding(i))]
    check("key bindings: the five names Ukrainian (both globals)", not bad, bad)
    _eq(check, "key bindings: the category set (it was unset)", M.category(), M.wantHash("11:3bb4f737"))
    # 4. Off and on.
    M.page("Heal", True)
    M.uadd("autopotion off")
    heal.texts(check, "off: Heal page English", english=True)
    heal.fonts_back(check, "off: fonts back")
    boxes(check, M, "off", heal)
    check("off: binding names and category back", M.binding(1) == M.bindingEn(1) and M.category() is None
          and M.bindingOwn(1) is None, (txt(M.binding(1)), txt(M.category())))
    M.resetDone()
    _eq(check, "off: chat line English", M.lastChat(), en["17:bf4baa09"])
    M.setCategory(lua_str("Zorp header"))
    M.uadd("autopotion on")
    heal.texts(check, "on: Heal page Ukrainian again")
    boxes(check, M, "on", heal)
    _eq(check, "key bindings: a category someone set is kept", M.category(), "Zorp header")
    _eq(check, "on: binding names Ukrainian again", M.binding(1), M.wantHash(hash_of(en, M.bindingEn(1))))
    M.setCategory(None)
    M.resetDone()
    _eq(check, "on: chat Ukrainian again", M.lastChat(), M.wantBare("17:bf4baa09"))
    M.page("Heal", False)
