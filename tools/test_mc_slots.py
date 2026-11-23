"""The slot sorts we ship for Mastercraft (UADD_Mastercraft/data, from tools/mc_rules.py) against what the
installed Mastercraft's code really puts in each slot (CLAUDE.md "No half translations").

The halves check (tools/harness/halves_mods.py) trusts each slot's sort: a free slot keeps a capitalised
name as it is, by design. So a zone sorted free ("Undercity  -  online now", Alts.lua) passed it and showed
a half line in the game. This test reads the code: a format string's arguments, and a game name joined to a
text with "..", and fails when a slot that gets a zone, race, class, profession, item or NPC is free.
It reads the installed addon at test time and keeps none of its English; it skips when it is not installed.
"""
import re
import sys
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))
import hashtext as H  # noqa: E402
import luatok as T  # noqa: E402
import make_mc_text as M  # noqa: E402

DATA = TOOLS.parent / "UADD_Mastercraft" / "data"
# The last name of an expression that holds a game name (a field, a local or a function).
GAME = {"zone", "zoneName", "subzone", "subZone", "race", "class", "className", "ClassName", "UnitClass",
        "UnitRace", "GetZoneText", "GetRealZoneText", "GetSubZoneText", "GetMinimapZoneText", "profName",
        "profession", "ProfName", "itemName", "ItemName", "GetItemInfo", "recipeName", "RecipeName",
        "npc", "npcName", "vendor", "trainer", "spellName", "GetSpellInfo", "questName", "mapName"}
# (English key, slot): checked by hand, the name in the code is not a game name there.
ALLOW = {
    # Mastercraft 2.0.8, Tabs/Alts.lua, a move row (from one character to another): its local ClassName(c)
    # gives the character's own name (ns.CharName: the name and the surname the player picked) in its class
    # colour, never the class's name. A player's name: free (F), kept as it is.
    ("48:2da42a30", 1): "the character an item moves from: its name in class colour",
    ("48:2da42a30", 3): "the character it moves to: its name in class colour",
}


def shipped():
    """{template key: [sort letter per slot]} from the module's data files."""
    out = {}
    for p in sorted(DATA.glob("text*.lua")):
        for line in p.read_text(encoding="utf-8").splitlines():
            m = re.match(r'T\[#T \+ 1\] = \{ id = "([^"]+)".*sort = \{([^}]*)\}', line)
            if m:
                out[m.group(1)] = re.findall(r'"(\w)"', m.group(2))
    return out


def _close(t, i):
    """Index of the token that closes the bracket at t[i]."""
    depth = 0
    for j in range(i, len(t)):
        if t[j][0] == T.SYM and t[j][1] in "([{":
            depth += 1
        elif t[j][0] == T.SYM and t[j][1] in ")]}":
            depth -= 1
            if depth == 0:
                return j
    return len(t) - 1


def _args(t, i):
    """The arguments of the call whose "(" is t[i]: a list of token lists."""
    end, out, cur, depth = _close(t, i), [], [], 0
    for tok in t[i + 1:end]:
        if tok[0] == T.SYM and tok[1] in "([{":
            depth += 1
        elif tok[0] == T.SYM and tok[1] in ")]}":
            depth -= 1
        if depth == 0 and tok[:2] == (T.SYM, ","):
            out.append(cur)
            cur = []
        else:
            cur.append(tok)
    return out + ([cur] if cur else [])


def _game(toks):
    """The game-name word an expression uses, or None (text through ns.L or a number is not one)."""
    names = [v for k, v, _ in toks if k == T.NAME]
    return next((v for v in names if v in GAME), None)


def _operand_end(t, j):
    """The name at the end of the operand that ends at t[j]: a field (c.zone) or a call (GetZoneText())."""
    if t[j][0] == T.NAME:
        return t[j][1]
    if t[j][:2] == (T.SYM, ")"):
        depth = 0
        for k in range(j, -1, -1):
            if t[k][0] == T.SYM and t[k][1] in ")]}":
                depth += 1
            elif t[k][0] == T.SYM and t[k][1] in "([{":
                depth -= 1
                if depth == 0:
                    return t[k - 1][1] if k and t[k - 1][0] == T.NAME else None
    return None


def _is_concat(t, j):
    return j + 1 < len(t) and t[j][:2] == (T.SYM, ".") and t[j + 1][:2] == (T.SYM, ".")


def sites(text):
    """[(how, English, slot or literal, game word, line)] in one Lua file:
      ("format", fmt, slot, word): ("fmt"):format(...) or string.format("fmt", ...), slot gets `word`;
      ("after", lit, None, word): `word .. "lit"`;  ("before", lit, None, word): `"lit" .. word`."""
    t = list(T.tokens(text))
    out = []
    for i, (kind, v, line) in enumerate(t):
        if kind == T.STR and i + 4 < len(t) and i and t[i - 1][:2] == (T.SYM, "(") \
                and [x[:2] for x in t[i + 1:i + 4]] == [(T.SYM, ")"), (T.SYM, ":"), (T.NAME, "format")] \
                and t[i + 4][:2] == (T.SYM, "("):
            args = _args(t, i + 4)
        elif kind == T.NAME and v == "format" and i > 1 and t[i - 2][1] == "string" and i + 2 < len(t) \
                and t[i + 1][:2] == (T.SYM, "(") and t[i + 2][0] == T.STR:
            v, args = t[i + 2][1], _args(t, i + 1)[1:]
        else:
            if kind == T.STR and i > 1 and _is_concat(t, i - 2) and i > 2:
                word = _operand_end(t, i - 3)
                if word in GAME:
                    out.append(("after", v, None, word, line))
            if kind == T.STR and _is_concat(t, i + 1) and i + 3 < len(t) and t[i + 3][0] == T.NAME:
                k = i + 3
                while k + 2 < len(t) and t[k + 1][:2] == (T.SYM, ".") and t[k + 2][0] == T.NAME \
                        and not _is_concat(t, k + 1):
                    k += 2
                if t[k][1] in GAME and (k + 1 >= len(t) or t[k + 1][:2] != (T.SYM, "(")):
                    out.append(("before", v, None, t[k][1], line))
            continue
        if not H.is_template(v):
            continue
        for n, arg in enumerate(args, 1):
            word = _game(arg)
            if word and not any(x[:2] == (T.NAME, "L") for x in arg):
                out.append(("format", v, n, word, line))
    return out


def _slot_args(en):
    """Slot numbers of the %s / %d in a template (1-based, in order)."""
    return [x[1] for x in H.tokens(en) if x[0] == "slot"]


def problems(addon, temps):
    """["file:line ..."] for every slot fed a game name that we ship as free."""
    rows = [en for en, kind, *_ in M.L.source(addon) if kind == "template"]
    lines = sorted({ln for en in rows for ln in en.split("\n") if H.is_template(ln)})
    bad = []
    for path in sorted(Path(addon).rglob("*.lua")):
        if "Locales" in path.parts:
            continue
        rel = path.relative_to(addon).as_posix()
        for how, v, n, word, line in sites(T.read(path)):
            if how == "format":
                hits = [(v, n)]
            else:                       # every shipped line that has the literal right after/before a slot
                hits = []
                for en in lines:
                    toks = H.tokens(en)
                    for k, tok in enumerate(toks):
                        if tok[0] != "slot":
                            continue
                        nxt = toks[k + 1][1] if how == "after" and k + 1 < len(toks) else None
                        prv = toks[k - 1][1] if how == "before" and k else None
                        start = how == "after" and k == 0 and nxt is not None and nxt.startswith(v) and v.strip()
                        end = how == "before" and k == len(toks) - 1 and prv is not None and prv.endswith(v) \
                            and v.strip()
                        if start or end:
                            hits.append((en, sum(1 for x in toks[:k + 1] if x[0] == "slot")))
            for en, slot in hits:
                key = H.key(en)
                sort = temps.get(key)
                if not sort or slot > len(sort) or (key, slot) in ALLOW:
                    continue
                if _slot_args(en)[slot - 1] == "s" and sort[slot - 1] == "f":
                    bad.append(f"{rel}:{line} {key} slot {slot} gets {word} but is free")
    return sorted(set(bad))


class Sites(unittest.TestCase):
    """The scanner on made-up Lua."""

    def test_format(self):
        got = sites('x:SetText(("Wobble %d %s"):format(lvl, c.zone or ""))')
        self.assertEqual([s[:4] for s in got], [("format", "Wobble %d %s", 2, "zone")])
        got = sites('x = string.format("Fizz %s", ClassName(a))')
        self.assertEqual([s[:4] for s in got], [("format", "Fizz %s", 1, "ClassName")])
        self.assertEqual(sites('x = ("Fizz %s"):format(ns.L(c.zone))'), [])

    def test_join(self):
        got = [s[:4] for s in sites('a = (c.zone .. "  -  ") .. "x"')]
        self.assertIn(("after", "  -  ", None, "zone"), got)
        got = [s[:4] for s in sites('a = "Near " .. me.race')]
        self.assertEqual(got, [("before", "Near ", None, "race")])
        got = [s[:4] for s in sites('a = GetZoneText() .. " gizmo"')]
        self.assertEqual(got, [("after", " gizmo", None, "GetZoneText")])


class Installed(unittest.TestCase):
    def test_no_game_name_in_a_free_slot(self):
        addon = M.addon_dir()
        if not (addon / "Locales").is_dir():
            self.skipTest("Mastercraft is not installed")
        bad = problems(addon, shipped())
        self.assertEqual(bad, [], "a game name in a free slot: sort it NAME (n) in tools/mc_rules.py")

    def test_glue_only_template_has_no_free_slot(self):
        """A template of slots and glue alone (gaps, colour codes, marks: no word) joins texts the code builds:
        a free slot there takes a recipe name glued to a count (lesson 7), unless its code puts a name there."""
        addon = M.addon_dir()
        if not (addon / "Locales").is_dir():
            self.skipTest("Mastercraft is not installed")
        import mc_rules
        temps, bad = shipped(), []
        for en, kind, *_ in M.L.source(addon):
            key = H.key(en)
            if kind != "template" or "f" not in temps.get(key, ()) or key in mc_rules.IN_CODE:
                continue
            glue = "".join(x[1] for x in H.tokens(en) if x[0] == "lit")
            if not re.search(r"[A-Za-z]", re.sub(r"\|c[0-9a-fA-F]{0,8}|\|r", "", glue)):
                bad.append(key)
        self.assertEqual(bad, [], "glue only, with a free slot: sort it n or t in tools/mc_rules.py")


if __name__ == "__main__":
    unittest.main()
