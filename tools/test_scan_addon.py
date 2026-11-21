"""Tests for tools/scan_addon.py.

A made-up addon ("Wobble", our own words only) is built in a temp folder with one case per kind. The real-addon
cases (the 8 the map stage must find) read the installed addons and skip when one is not installed.

    python3 -m unittest tools.test_scan_addon
"""
import struct
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import copy_scan  # noqa: E402
import scan_addon  # noqa: E402
from scan_font import cyr_status  # noqa: E402


def ttf(ranges):
    """A tiny font: only a table directory and a format-4 cmap that maps each (start, end) range."""
    segs = list(ranges) + [(0xFFFF, 0xFFFF)]
    n = len(segs)
    sub = struct.pack(">HHHHHHH", 4, 16 + n * 8, 0, n * 2, 2, 0, 0)
    sub += b"".join(struct.pack(">H", e) for _, e in segs) + b"\0\0"
    sub += b"".join(struct.pack(">H", s) for s, _ in segs)
    sub += b"".join(struct.pack(">h", 1) for _ in segs) + b"\0\0" * n
    cmap = struct.pack(">HHHHI", 0, 1, 3, 1, 12) + sub
    head = struct.pack(">IHHHH", 0x00010000, 1, 16, 0, 0)
    return head + struct.pack(">4sIII", b"cmap", 0, 28, len(cmap)) + cmap


FILES = {
    "Wobble.toc": "## Title: Wobble\n## SavedVariables: WobbleDB\nLocale.lua\nLocale/deDE.lua\nMain.lua\n"
                  "UI.xml\nGone.lua\n#Old.lua\n",
    "Locale.lua": 'local _, ns = ...\nns.L = {}\nlocal L = ns.L\nL.HELLO = "Wobbly gizmo here"\n'
                  'L.BYE = "Fluffy sprocket gone"\nL.GROUP = "Default wobble group"\n',
    "Locale/deDE.lua": 'if GetLocale() ~= "deDE" then return end\nlocal L = {}\nL.HELLO = "Wackel"\n',
    "Extra.lua": "local x = 1\n",
    "Main.lua": "\n".join([
        "local _, ns = ...",
        "local L = ns.L",
        'local f = CreateFrame("Frame", "WobbleFrame", UIParent)',
        'local fs = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")',
        "fs:SetText(ADD)",
        'fs:SetText("Wobbly gizmo")',
        'fs:SetFont("Interface\\\\AddOns\\\\Wobble\\\\Fonts\\\\Cyr.ttf", 12)',
        'fs:SetFont("Fonts\\\\FRIZQT__.TTF", 12)',
        "local info = C_Map.GetMapInfo(1)",
        "local zone = GetZoneText()",
        "StaticPopupDialogs.WOBBLE_ASK = { text = L.HELLO, button1 = ACCEPT, button2 = CANCEL }",
        "Menu.ModifyMenu(\"MENU_WORLD_MAP_TRACKING\", function(owner, root) root:CreateCheckbox(L.BYE) end)",
        "function ns.Setup()",
        '  local cat = Settings.RegisterVerticalLayoutCategory("Wobble Options")',
        "  WobbleDB.group = L.GROUP",
        "end",
        "local WORDS = { L.HELLO, L.BYE }",
        ""]),
    "UI.xml": "\n".join([
        "<Ui>",
        '<Font name="WobbleFont" font="Interface\\AddOns\\Wobble\\Fonts\\Latin.ttf" height="12"/>',
        '<Frame name="WobblePanel">',
        "  <Layers><Layer>",
        '    <FontString parentKey="Label" inherits="GameFontNormal" text="REVERT"/>',
        "  </Layer></Layers>",
        "  <Frames>",
        '    <Button parentKey="Ok" text="HELLO"><ButtonText inherits="GameFontHighlight"/></Button>',
        '    <Frame parentKey="Pick" inherits="UIDropDownMenuTemplate"/>',
        "  </Frames>",
        "  <Scripts>",
        "    <OnLoad>",
        "      self.Label:SetText(OKAY)",
        "    </OnLoad>",
        "  </Scripts>",
        "</Frame>",
        '<!--@debug@ <Frame><Scripts><OnLoad>self:SetFont("Fonts\\\\2002.ttf", 9)</OnLoad></Scripts></Frame>',
        "@end-debug@-->",
        "</Ui>",
        ""]),
}


def rows(ctx, kind, rel=None):
    return [(r, n, t) for k, r, n, t in ctx.found if k == kind and (rel is None or r == rel)]


def tags(ctx, kind, rel=None):
    return [t for _, _, t in rows(ctx, kind, rel)]


def has(ctx, kind, *parts, rel=None):
    return any(all(p in t for p in parts) for t in tags(ctx, kind, rel))


class MadeUp(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        root = Path(cls.tmp.name) / "Wobble"
        for rel, text in FILES.items():
            (root / rel).parent.mkdir(parents=True, exist_ok=True)
            (root / rel).write_text(text)
        (root / "Fonts").mkdir()
        (root / "Fonts" / "Cyr.ttf").write_bytes(ttf([(0x41, 0x5A), (0x410, 0x491)]))
        (root / "Fonts" / "Latin.ttf").write_bytes(ttf([(0x41, 0x5A)]))
        cls.ctx = scan_addon.scan(root)

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_cmap(self):
        self.assertEqual(cyr_status(ttf([(0x410, 0x491)])), "uk")
        self.assertEqual(cyr_status(ttf([(0x410, 0x44F)])), "ru-only")
        self.assertEqual(cyr_status(ttf([(0x41, 0x5A)])), "none")
        self.assertEqual(cyr_status(b"junk"), "unreadable")

    def test_toc(self):
        c = self.ctx
        self.assertTrue(has(c, "toc", "listed, missing: Gone.lua"))
        self.assertTrue(has(c, "toc", "commented out: Old.lua"))
        self.assertIn(("Extra.lua", 1, "not loaded by any TOC"), rows(c, "toc"))

    def test_locale(self):
        self.assertIn("defines 3 keys", tags(self.ctx, "locale", "Locale.lua"))
        self.assertTrue(has(self.ctx, "locale", "other-language locale files"))

    def test_global(self):
        self.assertTrue(has(self.ctx, "global", "ADD <", rel="Main.lua"))
        self.assertTrue(has(self.ctx, "global", "REVERT <FontString text>", rel="UI.xml"))
        self.assertTrue(has(self.ctx, "global", "OKAY <", rel="UI.xml"))  # in a multi-line inline script

    def test_text(self):
        self.assertIn("SetText literal(12)", tags(self.ctx, "text", "Main.lua"))
        self.assertTrue(has(self.ctx, "text", "<Button text> L key HELLO", rel="UI.xml"))

    def test_font(self):
        c = self.ctx
        self.assertTrue(has(c, "font", "Cyr.ttf shipped, cyrillic=uk", rel="Main.lua"))
        self.assertTrue(has(c, "font", "FRIZQT__.TTF game latin-only", rel="Main.lua"))
        self.assertTrue(has(c, "font", "Font object WobbleFont", "cyrillic=none", rel="UI.xml"))
        self.assertTrue(has(c, "font", "GameFontHighlight on <ButtonText>", "Cyrillic unknown", rel="UI.xml"))
        self.assertTrue(has(c, "font", "ships Latin.ttf cyrillic=none"))
        self.assertFalse(has(c, "font", "2002"))  # @debug@ blocks are comments in a release

    def test_gamename(self):
        self.assertTrue(has(self.ctx, "gamename", "C_Map.GetMapInfo <map>"))
        self.assertTrue(has(self.ctx, "gamename", "GetZoneText <zone>"))

    def test_popup(self):
        self.assertTrue(has(self.ctx, "popup", "WOBBLE_ASK", "text=L.HELLO", "button1=G:ACCEPT", "button2=G:CANCEL"))

    def test_menu(self):
        self.assertTrue(has(self.ctx, "menu", "Menu.ModifyMenu MENU_WORLD_MAP_TRACKING"))
        self.assertTrue(has(self.ctx, "menu", ":CreateCheckbox L.BYE"))
        self.assertTrue(has(self.ctx, "menu", "inherits UIDropDownMenuTemplate", rel="UI.xml"))

    def test_settings(self):
        self.assertTrue(has(self.ctx, "settings", "Settings.RegisterVerticalLayoutCategory", "literal(14)",
                            "in a function"))

    def test_saved(self):
        self.assertTrue(has(self.ctx, "saved", "WobbleDB.group = L.GROUP"))
        self.assertFalse(has(self.ctx, "saved", "L.HELLO"))

    def test_copies(self):
        self.assertTrue(has(self.ctx, "copies", "WORDS: 2 L word(s) at load"))

    def test_no_english_printed(self):
        for _, _, _, tag in self.ctx.found:
            for word in ("Wobbly", "Fluffy", "Default wobble", "Wobble Options", "Wackel"):
                self.assertNotIn(word, tag)


AD = copy_scan.addons_dir()
CACHE = {}


def real(name):
    p = Path(AD or "") / name
    if not AD or not p.is_dir():
        raise unittest.SkipTest("%s is not installed" % name)
    if name not in CACHE:
        CACHE[name] = scan_addon.scan(p)
    return CACHE[name]


class RealAddons(unittest.TestCase):
    """The 8 places the map stage must find in the installed addons (lessons 1, 14, 15, 30, 32, 33, 34)."""

    def test_1_litemount_globals(self):
        c = real("LiteMount")
        for g in ("ADD <", "KEY_BINDING <", "REVERT <"):
            self.assertTrue(has(c, "global", g), g)

    def test_2_litemount_profiles_font(self):
        c = real("LiteMount")
        self.assertTrue(any(n == 70 and "GameFontNormal on <ButtonText>" in t
                            for _, n, t in rows(c, "font", "UI/PanelTemplate.xml")))
        self.assertTrue(has(c, "font", "2002.TTF game unknown"))

    def test_3_litemount_game_names(self):
        c = real("LiteMount")
        self.assertTrue(has(c, "gamename", "C_MountJournal.GetMountInfoByID <mount>"))
        self.assertTrue(has(c, "gamename", "<spell>"))

    def test_4_popups(self):
        for name, part in (("Auctionator", "StaticPopupDialogs"), ("BagBrother", "Sushi Popup"),
                           ("Scrap", "Sushi Popup")):
            with self.subTest(name):
                c = real(name)
                self.assertTrue(has(c, "popup", part, "=G:"))
        self.assertTrue(has(real("Auctionator"), "popup", "button1=G:ACCEPT", "button2=G:CANCEL"))
        self.assertTrue(has(real("BagBrother"), "popup", "button1=G:YES", "button2=G:NO"))
        self.assertTrue(has(real("Scrap"), "popup", "button1=G:OKAY"))

    def test_5_fqp_world_map_menu(self):
        self.assertTrue(has(real("ForeverQuestPins"), "menu", "Menu.ModifyMenu MENU_WORLD_MAP_TRACKING"))

    def test_6_waypointui_zone_names(self):
        self.assertTrue(has(real("WaypointUI"), "gamename", "C_Map.GetMapInfo <map>"))

    def test_7_settings_pages(self):
        self.assertTrue(has(real("ForeverQuestPins"), "settings", "Settings.RegisterCanvasLayoutSubcategory"))
        self.assertTrue(has(real("LiteMount"), "settings", "Settings.RegisterVerticalLayoutSubcategory",
                            rel="UI/General.lua"))

    def test_8_rarescanner_saved(self):
        c = real("RareScanner")
        self.assertTrue(has(c, "saved", "L.CUSTOM_NPC_GROUP_DEFAULT"))
        self.assertTrue(has(c, "saved", "holds L.CONTAINER"))


if __name__ == "__main__":
    unittest.main()
