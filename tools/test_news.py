"""Lesson 43 (docs/LESSONS4.md): UADD never translates an addon's What's New, News or changelog.

- (a) No code a UADD TOC loads names a news frame (a global like "<Addon>WhatsNew", "<Addon>News",
  "<Addon>Changelog") as a root to walk or hook. A name inside a skip table (a local whose name has SKIP:
  OneForAll's SKIP_PREFIX, Road to Sixty's SKIP) is allowed: it names the window only to leave it alone.
  Comments are not read.
- (b) No module data has Ukrainian for a news text: no entry of news_texts.TEXTS is a string in its module's
  shipped files, and Forever Quest Pins' data has no What's New line (WhatsNew.lua `lines`) and no L key that only
  WhatsNew.lua uses. KEEP and TEXTS never share a text.
- (c) news_texts.is_news, news_only, drop and news_row on made-up paths and rows.
Reads the installed Forever Quest Pins for (b); that test skips when it is missing. Standard library only.
"""
import os
import re
import sys
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
ROOT = TOOLS.parent
sys.path.insert(0, str(TOOLS))
import drift_fqp  # noqa: E402
import luatok  # noqa: E402
import news_texts as N  # noqa: E402
from test_ukrainian_letters import shipped_lua  # noqa: E402

WOW = "/mnt/c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns"
FQP = Path(os.environ.get("UADD_ADDONS_DIR") or WOW) / "ForeverQuestPins"

# A global frame name of a news window: an addon prefix, then WhatsNew / News / Changelog as a word part.
NEWS_NAME = re.compile(r"^[A-Z][A-Za-z0-9]*?(?:WhatsNew|WhatNew|News|Changelog|ChangeLog)(?:[A-Z_0-9]|$)")


def news_names(text):
    """[(line, name)] of news frame names in Lua code (strings and names), outside skip tables."""
    toks = list(luatok.tokens(text))
    out, i, depth, skip_at = [], 0, 0, None
    while i < len(toks):
        kind, val, line = toks[i]
        if (skip_at is None and kind == luatok.NAME and "SKIP" in val and i + 2 < len(toks)
                and toks[i + 1][:2] == (luatok.SYM, "=") and toks[i + 2][:2] == (luatok.SYM, "{")):
            skip_at, depth, i = depth, depth + 1, i + 3
            continue
        if kind == luatok.SYM and val == "{":
            depth += 1
        elif kind == luatok.SYM and val == "}":
            depth -= 1
            if skip_at is not None and depth == skip_at:
                skip_at = None
        elif kind in (luatok.NAME, luatok.STR) and skip_at is None and NEWS_NAME.match(val):
            out.append((line, val))
        i += 1
    return out


def shipped_by_module():
    """{module folder: [repo-relative .lua paths its TOC loads]} for every UADD folder."""
    mods = {}
    for rel in shipped_lua():
        top = rel.split("/")[0]
        if top.startswith("UADD"):
            mods.setdefault(top, []).append(rel)
    return mods


def strings_of(paths):
    found = set()
    for rel in paths:
        p = ROOT / rel
        if p.is_file():
            found |= {v for k, v, _ in luatok.tokens(luatok.read(p)) if k == luatok.STR}
    return found


class NoNewsFrame(unittest.TestCase):
    def test_no_module_names_a_news_frame(self):
        bad = []
        for paths in shipped_by_module().values():
            for rel in paths:
                p = ROOT / rel
                if p.is_file():
                    bad += [f"{rel}:{n}: {name}" for n, name in news_names(luatok.read(p))]
        self.assertEqual(bad, [], "a module walks or hooks a news window (lesson 43)")

    def test_skip_tables_still_name_them(self):
        # The allowed names exist, so the skip rule above is not dead code.
        for rel, name in (("UADD_OneForAll/Screen.lua", "OneForAllWhatsNew"),
                          ("UADD_RoadToSixty/Screen.lua", "RoadToSixtyWhatsNew")):
            self.assertIn(name, luatok.read(ROOT / rel), rel)

    def test_finder(self):
        lua = ('local SKIP = { GizmoWhatsNew = true, { "GizmoNews" } }\n'
               'local ROOTS = { "GizmoFrame", "GizmoWhatsNew" }\n'
               '-- GizmoChangelog in a comment\n'
               'local f = _G["GizmoNewsFrame"]; local n = win.news; local s = "PawnNewScale"\n'
               'local SKIP_PREFIX = { "GizmoChangelog" }\nHook(GizmoChangeLog)\n')
        self.assertEqual(news_names(lua), [(2, "GizmoWhatsNew"), (4, "GizmoNewsFrame"), (6, "GizmoChangeLog")])


class NoNewsData(unittest.TestCase):
    def test_texts_not_in_module_data(self):
        mods = shipped_by_module()
        for mod, texts in N.TEXTS.items():
            self.assertIn(mod, mods, f"news_texts.TEXTS names {mod}, which has no TOC")
            self.assertEqual(sorted(set(texts) & strings_of(mods[mod])), [], f"{mod} ships a news text")

    def test_keep_and_texts_apart(self):
        for mod in set(N.KEEP) & set(N.TEXTS):
            self.assertEqual(N.KEEP[mod] & N.TEXTS[mod], set(), mod)

    @unittest.skipUnless((FQP / "WhatsNew.lua").is_file(), "Forever Quest Pins not installed")
    def test_fqp_whats_new_not_ours(self):
        news_toks = list(luatok.tokens(luatok.read(FQP / "WhatsNew.lua")))
        lines = set()
        for i in range(len(news_toks) - 2):
            if news_toks[i][:2] == (luatok.NAME, "lines") and news_toks[i + 2][:2] == (luatok.SYM, "{"):
                for t in news_toks[i + 3:]:
                    if t[:2] == (luatok.SYM, "}"):
                        break
                    if t[0] == luatok.STR:
                        lines.add(t[1])
        self.assertTrue(lines, "no What's New lines found (WhatsNew.lua changed shape?)")
        elsewhere = set()
        for f in FQP.rglob("*.lua"):
            if f.name != "WhatsNew.lua" and "Libs" not in f.relative_to(FQP).parts:
                elsewhere |= set(drift_fqp._l_keys(list(luatok.tokens(luatok.read(f)))))
        only_news = set(drift_fqp._l_keys(news_toks)) - elsewhere
        ours = strings_of(shipped_by_module()["UADD_ForeverQuestPins"])
        self.assertEqual(len(ours & lines), 0, "FQP data has Ukrainian for a What's New line")
        self.assertEqual(len(ours & only_news), 0, "FQP data has Ukrainian for a key only WhatsNew.lua uses")


class IsNews(unittest.TestCase):
    def test_is_news(self):
        for rel in ("WhatsNew.lua", "UI/WhatsNew.lua", "Map/News.lua", "Data/Forever/Changelog.lua",
                    "whats_new.xml", "News.xml", "WhatNew.lua", "CHANGELOG.lua", "UI/WhatsNewFrame.lua"):
            self.assertTrue(N.is_news(rel), rel)
        for rel in ("NewsletterPanel.lua", "NewButton.lua", "Renews.lua", "UI/MyNews.lua", "News.md", "", None,
                    "Map/Newsfeed.lua"):
            self.assertFalse(N.is_news(rel), rel)

    def test_news_only_and_drop(self):
        self.assertTrue(N.news_only([("WhatsNew.lua", 3), ("Map/News.lua", 9)]))
        self.assertFalse(N.news_only([("WhatsNew.lua", 3), ("Core.lua", 9)]))
        self.assertFalse(N.news_only([]))
        rows = [["k1", "Gizmo", 1, [("WhatsNew.lua", 1)], ""], ["k2", "Wobble", 1, [("Core.lua", 2)], ""],
                ["k3", "Both", 1, [("News.lua", 1), ("UI.lua", 4)], ""]]
        self.assertEqual([r[0] for r in N.drop(rows)], ["k2", "k3"])

    def test_news_row_keeps(self):
        for mod, kept in N.KEEP.items():
            for text in kept:
                self.assertFalse(N.news_row(mod, ("L", None, text, "Map/News.lua")), (mod, text))
                self.assertFalse(N.news_row(mod, ("L", text, "x", "WhatsNew.lua")), (mod, text))
        self.assertTrue(N.news_row("UADD_X", ("L", None, "Gizmo", "UI/WhatsNew.lua")))


if __name__ == "__main__":
    unittest.main()
