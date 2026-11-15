"""tools/hashtext.py against UADD/Hash.lua: the same hash on both sides for tricky texts (empty,
Cyrillic, |c codes, line breaks, %%, long), the stored forms, and a written data file that Lua loads
and fills in. Lua runs with lupa on bytes (encoding=None), as the game sees them."""
import sys
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))
import hashtext as HT  # noqa: E402

try:
    from lupa import lua51
except ImportError:  # pragma: no cover
    lua51 = None

TRICKY = ["", "a", "Рівень", "|cffffd100Gold|r", "Line one\nLine two\r\n", "100%% done", "100% done",
          "\\ \" ' [[ ]]", "\t\x01\x7f", "Ж" * 700, "x" * 5000]


def lua_core():
    """A Lua 5.1 with only UADD/Hash.lua loaded (every text plain)."""
    lua = lua51.LuaRuntime(unpack_returned_tuples=True, encoding=None)
    lua.execute(b"UADD = { Plain = function(v) if type(v) == 'string' then return v end end }")
    lua.execute((TOOLS.parent / "UADD" / "Hash.lua").read_bytes())
    return lua


def b(s):
    return s.encode("utf-8")


class HashTest(unittest.TestCase):
    def test_known_values(self):
        self.assertEqual(HT.djb2(""), "00001505")
        self.assertEqual(HT.djb2("a"), "0002b606")          # 5381 * 33 + 97
        self.assertEqual(HT.djb2(b"a"), HT.djb2("a"))
        self.assertEqual(HT.key("Рівень"), "12:" + HT.djb2("Рівень"))

    def test_same_as_dj_prose(self):
        import make_dj_prose
        for s in TRICKY:
            self.assertEqual(make_dj_prose.djb2(s), HT.djb2(s))


@unittest.skipIf(lua51 is None, "lupa is not installed")
class LuaHashTest(unittest.TestCase):
    def test_lua_hash_is_python_hash(self):
        lua = lua_core()
        H = lua.eval("UADD.Hash")
        for s in TRICKY:
            self.assertEqual(H(b(s)), b(HT.djb2(s)), repr(s[:20]))

    def test_not_plain_is_nil(self):
        lua = lua_core()
        self.assertIsNone(lua.eval("UADD.Hash(nil)"))
        self.assertIsNone(lua.eval("UADD.Hash({})"))


class FormsTest(unittest.TestCase):
    def test_tokens(self):
        self.assertEqual(HT.tokens("Rested: %.1f%%"), [("lit", "Rested: "), ("slot", "f", ("arg", 1)), ("lit", "%")])
        self.assertEqual(HT.tokens("%2$s %1$d")[0], ("slot", "s", ("arg", 2)))
        self.assertEqual(HT.tokens("|cff%02x")[1], ("slot", "x2", ("arg", 1)))
        self.assertEqual(HT.tokens("%i/%x")[::2], [("slot", "d", ("arg", 1)), ("slot", "x", ("arg", 2))])
        self.assertEqual(HT.tokens("by ##NAME##", ("NAME",))[1], ("slot", "l", ("place", "NAME")))
        self.assertEqual(HT.tokens("[KEY:PC:SPACE] go")[0], ("slot", "t", ("key", "[KEY:PC:SPACE]")))
        self.assertFalse(HT.is_template("100%% done"))
        self.assertTrue(HT.is_template("Sold by %s"))

    def test_check(self):
        self.assertEqual(HT.check("Level %d of %d", "Рівень %d з %d"), [])
        self.assertEqual(HT.check("%1$s gets %2$d", "%2$d для %1$s"), [])
        self.assertTrue(HT.check("Level %d", "Рівень %s"))                 # another kind
        self.assertTrue(HT.check("Level %d of %d", "Рівень %d"))            # a slot left out
        self.assertTrue(HT.check("Level %d", "Рівень %d з %d"))             # a slot too many
        self.assertTrue(HT.check("|cffffd100%s|r", "%s"))                   # codes lost
        self.assertEqual(HT.check("Press [KEY:PC:E]", "Натисніть [KEY:PC:E] або [KEY:PC:E]"), [])

    def test_template(self):
        t = HT.template("Level %d of %d", "Рівень %d з %d")
        self.assertEqual(t["len"], [6, 4, 0])
        self.assertEqual(t["hash"], [HT.djb2("Level "), HT.djb2(" of "), "00001505"])
        self.assertEqual(t["kinds"], ["d", "d"])
        self.assertEqual(t["uk"], ["Рівень ", 1, " з ", 2])
        self.assertEqual(t["lit"], 10)
        self.assertEqual(t["id"], HT.key("Level %d of %d"))
        t = HT.template("Completed ##TYPE## for ##NAME##", "##NAME##: ##TYPE##", id="done", strict=True)
        self.assertEqual((t["uk"], t["names"], t["id"], t["strict"]), ([2, ": ", 1], ["TYPE", "NAME"], "done", True))
        self.assertIsNone(HT.template("%s: %s", "%s: %s"))                 # 2 literal bytes: too loose
        self.assertIsNotNone(HT.template("%s: %s", "%s: %s", min_lit=2))
        with self.assertRaises(ValueError):
            HT.template("Done", "Готово")                                    # no slot
        with self.assertRaises(ValueError):
            HT.template("Level %d", "Рівень %s")

    def test_write_lua_keeps_no_english(self):
        text = HT.write_lua({"Buy All": "Купити все"}, [HT.template("Sold by %s", "Продає %s")], "t")
        self.assertNotIn("Buy All", text)
        self.assertNotIn("Sold by", text)
        self.assertIn(HT.key("Buy All"), text)
        with self.assertRaises(ValueError):
            HT.write_lua({}, [HT.template("A %s B", "А %s Б")] * 2, "t")


@unittest.skipIf(lua51 is None, "lupa is not installed")
class RoundTripTest(unittest.TestCase):
    def test_written_data_loads_and_fills(self):
        exact = {"Buy All": "Купити все", "100% done": "100% готово", "Line\nTwo": "Рядок\nДва"}
        temps = [HT.template("Level %d of %d", "Рівень %d з %d"),
                 HT.template("|cff%02x%02x%02x%s|r gets %d%%", "%5$d%% для |cff%1$02x%2$02x%3$02x%4$s|r"),
                 HT.template("Press [KEY:PC:SPACE] now", "Тисніть [KEY:PC:SPACE]")]
        lua = lua_core()
        lua.execute(b"function load_data(t) local ns = {}; assert(loadstring(t))('x', ns); "
                    b"IDX = UADD.TextIndex(ns.t) end")
        lua.globals().load_data(b(HT.write_lua(exact, temps, "t")))
        text = lua.eval("function(s) return (IDX:Text(s)) end")
        cases = {"Buy All": "Купити все", "100% done": "100% готово", "Line\nTwo": "Рядок\nДва",
                 "Level 3 of 60": "Рівень 3 з 60", "|cff10a0ffThrall|r gets 15%": "15% для |cff10a0ffThrall|r",
                 "Press |TInterface\\K:16|t now": "Тисніть |TInterface\\K:16|t", "Level up": None, "": None}
        for en, uk in cases.items():
            got = text(b(en))
            self.assertEqual(got.decode("utf-8") if got is not None else None, uk, repr(en))


if __name__ == "__main__":
    unittest.main()
