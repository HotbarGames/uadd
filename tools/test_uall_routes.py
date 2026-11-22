"""Fails when a module shows game names but cannot reach UALL Forever's route for them.

Game names (zones, NPCs, items, spells, class names) come from UALL Forever at runtime, through the routes in
UADD.UALL (UADD/uall.lua). UADD itself has no route: core Words.lua once asked { U.Text, U.Zone, U.Npc, U.Item }
with U = UADD, an empty list, so every game-name slot of What's Training? and TomTom stayed English in the game
while the harness, whose stubs set UADD.Zone and the like, passed. Two checks, over the .lua files each
UADD*/*.toc loads:

  1. No code reads a route from UADD's root (UADD.Zone, or U.Text where U = UADD). A definition in a file whose
     U is UADD.UALL is fine.
  2. Each module in SHOWS reaches each route it needs through UADD.UALL: X.Route or X[...] with the string
     "Route" in the same file, where X is UADD.UALL (or a local set to it). A module that builds its words with
     core U.NewWords reaches core Words.lua's NAMES (and SPELLS with { spells = true }). Every module whose
     data has a game-name slot (sort "n") must be in SHOWS or KNOWN.

KNOWN lists files of other work still broken the same way; the test fails once they are fixed, so the entry
goes. The mutant tests take a fix out (in memory) and want the check to fail.

python3 -m unittest tools.test_uall_routes
python3 tools/test_uall_routes.py          (lists every hit)
"""
import os
import re
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import luatok  # noqa: E402
from test_ukrainian_letters import shipped_lua  # noqa: E402

ROUTES = {"Text", "Zone", "Npc", "Item", "Spell", "Class", "Quest"}
CORE_WORDS = "UADD/Words.lua"
CODE_TEXT = "UADD/CodeText.lua"
# module -> the routes its windows need (what it shows; see each module's notes)
SHOWS = {
    "UADD_AutoPotion": {"Class", "Spell", "Item"},     # class headers, spell and potion boxes (Game.lua)
    "UADD_Scrap": {"Item"},                            # item names (Items.lua)
    "UADD_Bagnon": {"Text"},                           # bag titles (Game.lua)
    "UADD_Pawn": {"Text"},                             # Game.lua
    "UADD_Auctionator": {"Item"},                      # item rows (Rows.lua)
    "UADD_OpenMap": {"Zone"},                          # zone labels (Label.lua)
    "UADD_LayerSwap": {"Zone"},                        # the panel's zone line (Words.lua)
    "UADD_TomTom": {"Text", "Zone", "Npc", "Item"},    # n slots, core Words
    "UADD_WhatsTraining": {"Text", "Zone", "Npc", "Item", "Spell"},   # n slots with spells, spell rows
    "UADD_Mastercraft": {"Text", "Zone", "Npc", "Item"},   # n slots, its own Words.lua Name
    "UADD_ForeverQuestPins": {"Quest", "Zone"},        # breadcrumb dialog and abandoned line (Breadcrumb.lua)
    "UADD_WaypointUI": {"Zone"},                       # a pin named after its map (Words.lua Place)
    "UADD_LootTriage": {"Item", "Quest"},              # item and quest links, quest titles (Slots.lua, Words.lua)
    "UADD_DeleteCheapestItem": {"Item"},               # item names and links in its chat lines (CodeText, Words.lua)
}
# Still broken the same way (other work): file -> why. Remove the entry once the file is fixed.
KNOWN = {}
KNOWN_MODULES = set()


def _sym(toks, j, s):
    return 0 <= j < len(toks) and toks[j][0] == luatok.SYM and toks[j][1] == s


def _name(toks, j, s=None):
    return 0 <= j < len(toks) and toks[j][0] == luatok.NAME and (s is None or toks[j][1] == s)


def roots(toks):
    """Names that hold UADD's root table in this file: UADD, and X of each `local X = UADD` (not UADD.x)."""
    out = {"UADD"}
    for i in range(len(toks)):
        if _name(toks, i, "UADD") and _sym(toks, i - 1, "=") and _name(toks, i - 2) and _name(toks, i - 3, "local") \
                and not _sym(toks, i + 1, "."):
            out.add(toks[i - 2][1])
    return out


def root_hits(path, text):
    """[(path, line, what)] for each route read from UADD's root."""
    toks = list(luatok.tokens(text))
    R = roots(toks)
    found = []
    for i, (kind, value, line) in enumerate(toks):
        if kind == luatok.NAME and value in ROUTES and _sym(toks, i - 1, ".") and _name(toks, i - 2) \
                and toks[i - 2][1] in R and not _sym(toks, i - 3, "."):
            found.append((path, line, f"{toks[i - 2][1]}.{value}: UADD has no {value} route (UADD.UALL.{value})"))
    return found


def reached(text):
    """The routes this Lua source reaches through UADD.UALL."""
    toks = list(luatok.tokens(text))
    R = roots(toks)
    alias, at = {"UALL"}, set()          # names that hold UADD.UALL; token places that are UADD.UALL
    for i in range(len(toks)):
        if _name(toks, i, "UALL") and _sym(toks, i - 1, ".") and _name(toks, i - 2) and toks[i - 2][1] in R:
            at.add(i)
            j = i - 3                    # local A[, b...] = U.UALL[, ...]: A
            if _sym(toks, j, "="):
                k = j - 1
                while _name(toks, k) and _sym(toks, k - 1, ","):
                    k -= 2
                if _name(toks, k) and _name(toks, k - 1, "local"):
                    alias.add(toks[k][1])
    strs = {v for kind, v, _ in toks if kind == luatok.STR}
    out = set()
    for i, (kind, value, _) in enumerate(toks):
        if not (i in at or (kind == luatok.NAME and value in alias and not _sym(toks, i - 1, "."))):
            continue
        if _sym(toks, i + 1, ".") and _name(toks, i + 2) and toks[i + 2][1] in ROUTES:
            out.add(toks[i + 2][1])
        elif _sym(toks, i + 1, "["):
            out |= strs & ROUTES
    return out


def core_lists(text):
    """(NAMES, SPELLS): the routes core Words.lua asks for a name, and with spells on."""
    def one(name):
        m = re.search(r"local %s = \{([^}]*)\}" % name, text)
        return set(re.findall(r'"(\w+)"', m.group(1))) if m else set()
    return one("NAMES"), one("SPELLS")


def module_files(texts):
    """{module: [path]} of shipped .lua files."""
    out = {}
    for path in texts:
        out.setdefault(path.split("/", 1)[0], []).append(path)
    return out


def shows_n(texts):
    """Modules whose data has a game-name slot (sort "n")."""
    return {p.split("/", 1)[0] for p, t in texts.items() if re.search(r'sort = \{[^}]*"n"', t)}


def module_reached(mod, paths, texts):
    got = set()
    core = texts.get(CORE_WORDS, "")
    names, spells = core_lists(core)
    via_core = reached(core)
    for p in paths:
        t = texts[p]
        got |= reached(t)
        for m in re.finditer(r"NewWords\(([^\n]*)", t):
            got |= (spells if re.search(r"spells\s*=\s*true", m.group(1)) else names) & via_core
        if re.search(r"\bU(?:ADD)?\.CodeText\(", t):   # the core link reader (UADD/CodeText.lua) asks for it
            got |= reached(texts.get(CODE_TEXT, ""))
    return got


def problems(texts):
    """[(where, what)]: both checks over {path: text}."""
    out = [(f"{p}:{line}", what) for p, t in texts.items() if p not in KNOWN for p, line, what in root_hits(p, t)]
    mods = module_files(texts)
    for mod in sorted(shows_n(texts) - set(SHOWS) - KNOWN_MODULES):
        out.append((mod, "its data has game-name slots (sort n): add it to SHOWS in tools/test_uall_routes.py"))
    for mod, need in sorted(SHOWS.items()):
        if mod not in mods:
            continue
        miss = need - module_reached(mod, mods[mod], texts)
        if miss:
            out.append((mod, f"shows game names but never reaches UADD.UALL.{', .'.join(sorted(miss))}"))
    return out


def shipped_texts():
    out = {}
    for path in shipped_lua():
        full = os.path.join(REPO, path)
        if path.split("/", 1)[0].startswith("UADD") and os.path.isfile(full):
            with open(full, encoding="utf-8", errors="replace") as f:
                out[path] = f.read()
    return out


class UallRoutes(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.texts = shipped_texts()

    def test_routes_reached_through_uall(self):
        bad = problems(self.texts)
        self.assertFalse(bad, "\n".join(f"{w}: {m}" for w, m in bad))

    def test_known_still_broken(self):
        for path, why in KNOWN.items():
            if path in self.texts:
                self.assertTrue(root_hits(path, self.texts[path]),
                                f"{path} is fixed ({why}): remove it from KNOWN in tools/test_uall_routes.py")

    def test_core_words_asks_uall(self):
        names, spells = core_lists(self.texts[CORE_WORDS])
        self.assertEqual(names, {"Text", "Zone", "Npc", "Item"})
        self.assertEqual(spells, names | {"Spell"})
        self.assertTrue(names <= reached(self.texts[CORE_WORDS]))

    def _mutant(self, path, old, new):
        texts = dict(self.texts)
        self.assertIn(old, texts[path], f"{path}: the fixed code changed; update this mutant")
        texts[path] = texts[path].replace(old, new)
        return problems(texts)

    def test_mutant_old_core_name_fails(self):
        """The old core Name (routes from UADD's root) is found."""
        bad = self._mutant(CORE_WORDS, "for _, route in ipairs(only or routes) do\n"
                           "            local look = type(A) == \"table\" and A[route]",
                           "for _, look in ipairs({ U.Text, U.Zone, U.Npc, U.Item }) do\n            local _ = A")
        self.assertTrue(any(w.startswith(CORE_WORDS) for w, _ in bad), bad)

    def test_mutant_no_spells_fails(self):
        """What's Training? without { spells = true }: its words never reach the spell route."""
        bad = self._mutant("UADD_WhatsTraining/Module.lua", ", { spells = true }", "")
        self.assertIn(("UADD_WhatsTraining", "shows game names but never reaches UADD.UALL.Spell"), bad)

    def test_mutant_root_route_fails(self):
        bad = self._mutant("UADD_Scrap/Items.lua", "U.UALL", "U")
        self.assertTrue(any("UADD_Scrap" in w for w, _ in bad), bad)

    def test_new_module_with_n_slots_fails(self):
        texts = dict(self.texts)
        texts["UADD_Quix/data/text01.lua"] = 'T[#T + 1] = { id = "x", sort = { "n" } }'
        self.assertIn("UADD_Quix", [w for w, _ in problems(texts)])


if __name__ == "__main__":
    t = shipped_texts()
    for where, what in problems(t):
        print(f"{where}: {what}")
    for path, why in KNOWN.items():
        print(f"known: {path}: {why}: {len(root_hits(path, t.get(path, '')))} hit(s)")
