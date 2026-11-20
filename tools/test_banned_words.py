"""Fails when a string we ship uses a word we decided against.

BANNED maps a regex (case is ignored) to (the word to use instead, why): it is banned everywhere.
BANNED_IN does the same for one module folder only (UADD_LayerSwap): for a word that is right elsewhere
but wrong in that module («шар» is a map layer, but LayerSwap's server layer is «лейер»). It reads every
string literal in the .lua files each addon's TOC loads (every .toc in the repo, so a new addon is checked
as soon as it has one), each TOC's Title and Notes lines, and the Dungeon Journal texts in
tools/dj_prose/uk_*.lua; a BANNED_IN rule reads only the files and TOC inside its folder. Comments, docs/
and test files are not read. When we (or the owner) decide on a word, add the rejected one to BANNED or
BANNED_IN and put the right word in the glossary (UADD/glossary/*.lua, docs/GLOSSARY.md), in the same
commit. See docs/LESSONS.md, lessons 4 and 8.

python3 -m unittest discover -s tools -p 'test_*.py'
python3 tools/test_banned_words.py          (lists every hit: file:line: text -> use ...)
"""
import glob
import os
import re
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import luatok  # noqa: E402
from test_font_chars import TOC_SHOWN  # noqa: E402
from test_ukrainian_letters import shipped_lua, tocs  # noqa: E402

# regex: (use instead, reason) - banned in every shipped string
BANNED = {
    r"інстанс": ("підземелля (у підземеллі, у підземеллях, поза підземеллям, портал підземелля)",
                 "«інстанс» is slang"),
    r"\bПКМ\b|\bЛКМ\b": ("правий клік / клік (glossary ui.right_click)",
                         "mouse shorthand is slang; the glossary word is «Правий клік» (lead, 2026-11-19, What's Training?)"),
    # Profession words: UALL Forever's word wins (owner 2026-11-20; docs/LESSONS2.md lesson 17).
    r"здиранн[яюі]\w* шкур": ("Білування (prof.skinning)", "not UALL Forever's word for Skinning"),
    r"шкірництв": ("шкіряна справа (prof.leatherworking)", "not UALL Forever's word for Leatherworking"),
    r"гірництв": ("гірнича справа (prof.mining)", "not UALL Forever's word for Mining"),
    r"\bзнав(?:ець|ц)": ("Експерт (prof.rank_expert)", "not UALL Forever's word for the Expert rank"),
    r"каліграф": ("накреслення (prof.inscription)", "not UALL Forever's word for Inscription"),
    r"ювелірн\w* справ": ("ювелірство (prof.jewelcrafting)", "not UALL Forever's word for Jewelcrafting"),
    r"навич\w* зброї": ("володіння зброєю (weapon.skill)", "not UALL Forever's word for Weapon Skills"),
}
# module folder: {regex: (use instead, reason)} - banned only in that module's files
BANNED_IN = {
    "UADD_Mastercraft": {
        r"чатуван": ("табір (Camping is Forever's camp system: Табір)",
                     "lead's choice 2026-11-19, Mastercraft: «чатування» is waiting at a spawn, the wrong meaning"),
        r"принад": ("приманка (Lure)", "lead's choice 2026-11-19, Mastercraft"),
    },
    "UADD_Pawn": {
        r"масштаб": ("шкала (glossary gear.scale)",
                     "lead's choice 2026-11-20, Pawn: a scale values an item; «масштаб» is UALL's word for the UI size"),
    },
    "UADD_WaypointUI": {
        r"точн\w* позначк": ("мітка (glossary map.pinpoint)", "the owner's word for Pinpoint, 2026-11-20"),
        r"покажчик": ("навігатор (glossary map.navigator)", "the owner's word for Navigator, 2026-11-20"),
        r"пошук\w* шлях": ("прокладання маршруту (glossary map.pathfinding)",
                           "the owner's word for Pathfinding, 2026-11-20"),
        r"контекстн\w* знач": ("значок цілі (glossary map.context_icon)",
                               "the owner's word for Context Icon, 2026-11-20"),
    },
    "UADD_LayerSwap": {
        r"\bшар(?:а|у|ом|і|и|ів|ам|ами|ах|е)?\b": ("лейер (лейера, на лейері, лейерів; glossary game.server_layer)",
                   "the owner's word for a server layer, 2026-11-18; «шар» is a map layer (map.layer)"),
    },
}
RULES = [(re.compile(p, re.IGNORECASE), p, use) for p, (use, _) in BANNED.items()]
RULES_IN = {folder: [(re.compile(p, re.IGNORECASE), p, use) for p, (use, _) in rules.items()]
            for folder, rules in BANNED_IN.items()}


def rules_for(path):
    """[(regex, pattern, use instead)] that apply to a repo-relative path."""
    return RULES + RULES_IN.get(path.replace("\\", "/").split("/", 1)[0], [])


def lua_files():
    """Repo-relative .lua files whose strings players can see."""
    prose = sorted(os.path.relpath(p, REPO).replace("\\", "/")
                   for p in glob.glob(os.path.join(REPO, "tools", "dj_prose", "uk_*.lua")))
    return shipped_lua() + [p for p in prose if p not in shipped_lua()]


def hits_in_text(path, text):
    """[(path, line, string, use instead)] for each banned word in the string literals of Lua source text."""
    rules = rules_for(path)
    found = []
    for kind, value, line in luatok.tokens(text):
        if kind == luatok.STR:
            found += [(path, line, value, use) for rx, _, use in rules if rx.search(value)]
    return found


def hits():
    """Every banned word in what we ship: [(path, line, text, use instead)]."""
    found = []
    for toc in tocs():
        rules = rules_for(toc)
        with open(os.path.join(REPO, toc), encoding="utf-8-sig", errors="replace") as f:
            for n, line in enumerate(f, 1):
                m = TOC_SHOWN.match(line.strip())
                if m:
                    found += [(toc, n, m.group(3).strip(), use) for rx, _, use in rules if rx.search(m.group(3))]
    for path in lua_files():
        full = os.path.join(REPO, path)
        if os.path.isfile(full):
            found += hits_in_text(path, luatok.read(full))
    return found


class BannedWords(unittest.TestCase):
    def test_no_banned_word_is_shipped(self):
        bad = hits()
        detail = "\n".join(f"{p}:{n}: {v!r} -> use {use}" for p, n, v, use in bad[:20])
        self.assertEqual(bad, [], f"{len(bad)} banned words in shipped strings:\n{detail}")

    def test_a_banned_word_is_caught(self):
        src = 'local a = "в інстансі"\n-- інстанс in a comment is fine\nlocal b = "ІНСТАНСАХ"\nlocal c = "підземелля"\n'
        found = hits_in_text("fake.lua", src)
        self.assertEqual([(n, v) for _, n, v, _ in found], [(1, "в інстансі"), (3, "ІНСТАНСАХ")])

    def test_a_module_ban_stays_in_its_module(self):
        src = 'local a = "Змінити шар"\nlocal b = "ВАШ ШАР"\nlocal c = "Шар B"\nlocal d = "Змінити лейер"\n'
        found = hits_in_text("UADD_LayerSwap/data/words.lua", src)
        self.assertEqual([n for _, n, _, _ in found], [1, 2, 3])
        self.assertEqual(hits_in_text("UADD_OpenMap/Locale.lua", src), [])
        self.assertEqual(hits_in_text("UADD/glossary/map.lua", src), [])

    def test_every_file_is_read(self):
        files = lua_files()
        self.assertIn("tools/dj_prose/uk_1.lua", files)
        self.assertTrue(any(f.startswith("UADD/glossary/") for f in files), files[:5])
        self.assertTrue(any(f.startswith("UADD_Questie/") for f in files))
        for folder in BANNED_IN:
            self.assertTrue(any(f.startswith(folder + "/") for f in files), folder)
        self.assertIn("UADD_LayerSwap/data/words.lua", files)


def main():
    for path, line, value, use in hits():
        print(f"{path}:{line}: {value!r} -> use {use}")


if __name__ == "__main__":
    main()
