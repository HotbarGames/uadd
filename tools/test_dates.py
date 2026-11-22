"""UADD/Dates.lua: UADD.DateUk turns a date line with English month and weekday names into Ukrainian, and gives
nil for any line with another word in it (no half lines). The real file in a small Lua world; mutants take a
month out, swap two months, and take the gate for unknown words out, and want the test to fail. Only the game's
generic month and weekday names are used here."""
import sys
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
ROOT = TOOLS.parent
sys.path.insert(0, str(TOOLS / "harness"))
from loader import lua_runtime, read_text  # noqa: E402

LUA = lua_runtime()
DATES = ROOT / "UADD" / "Dates.lua"
WORLD = 'UADD = {}\nfunction UADD.Plain(v) return type(v) == "string" and v or nil end\n'

MONTHS = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October",
          "November", "December", "Jan", "Feb", "Mar", "Apr", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
DAYS = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday",
        "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

CASES = [
    ("12 Nov 2026, 14:03", "12 лист. 2026, 14:03"),
    ("Sunday 12 November", "Неділя 12 листопада"),
    ("Sunday, 12 November", "Неділя, 12 листопада"),
    ("November 12, 2026", "12 листопада 2026"),
    ("Nov 12, 2026 14:03", "12 лист. 2026 14:03"),
    ("November 2026", "листопад 2026"),
    ("May 3", "3 травня"),
    ("3 May", "3 травня"),
    ("May", "травень"),
    ("1 January, 2 February, 3 March, 4 April, 5 May, 6 June",
     "1 січня, 2 лютого, 3 березня, 4 квітня, 5 травня, 6 червня"),
    ("7 July, 8 August, 9 September, 10 October, 11 November, 12 December",
     "7 липня, 8 серпня, 9 вересня, 10 жовтня, 11 листопада, 12 грудня"),
    ("January February March April May June", "січень лютий березень квітень травень червень"),
    ("July August September October November December", "липень серпень вересень жовтень листопад грудень"),
    ("1 Jan, 2 Feb, 3 Mar, 4 Apr, 6 Jun, 7 Jul, 8 Aug, 9 Sep, 10 Oct, 11 Nov, 12 Dec",
     "1 січ., 2 лют., 3 бер., 4 квіт., 6 черв., 7 лип., 8 серп., 9 вер., 10 жовт., 11 лист., 12 груд."),
    ("Monday Tuesday Wednesday Thursday Friday Saturday Sunday",
     "Понеділок вівторок середа четвер п'ятниця субота неділя"),
    ("Sun Mon Tue Wed Thu Fri Sat", "Нд пн вт ср чт пт сб"),
    ("12/11 Mon", "12/11 пн"),
    ("Mon 12 Jan", "Пн 12 січ."),
    ("1 March - 4 April", "1 березня - 4 квітня"),
    ("12:03", "12:03"),
    ("", ""),
]
MISSES = ["12 Nov 2026, 2:03 PM", "November 12th", "Sunday at noon", "november 12", "Novembers",
          "|cffffffffNov|r"]


def raw(s):
    return s.encode("utf-8").decode("latin-1")


def world(src=None):
    L = LUA.LuaRuntime(unpack_returned_tuples=True, encoding="latin-1")
    L.execute(WORLD)
    load = L.eval("function(src, name) assert(loadstring(src, name))() end")
    load(read_text(DATES) if src is None else src, "@Dates.lua")
    return L


def problems(src=None):
    L = world(src)
    turn = L.eval("UADD.DateUk")
    out = []
    for en, uk in CASES:
        got = turn(raw(en))
        if got != raw(uk):
            out.append(f"{en!r}: {got!r}")
    for en in MISSES:
        if turn(raw(en)) is not None:
            out.append(f"{en!r} not nil")
    for name in MONTHS + DAYS:
        got = turn(name)
        if not got or got == name or any(c.isascii() and c.isalpha() for c in got):
            out.append(f"{name}: {got!r}")
    for bad in ("nil", "12", "{}", "true"):
        if L.eval(f"UADD.DateUk({bad})") is not None:
            out.append(f"{bad} not nil")
    return out


@unittest.skipIf(LUA is None, "lupa is not installed")
class Dates(unittest.TestCase):
    def test_turns_and_misses(self):
        self.assertEqual(problems(), [])

    def test_every_name_listed(self):
        L = world()
        months = L.eval("UADD.DATE_MONTHS")
        days = L.eval("UADD.DATE_DAYS")
        self.assertEqual(sorted(months.keys()), sorted(MONTHS))
        self.assertEqual(sorted(days.keys()), sorted(DAYS))

    def test_mutants_fail(self):
        src = read_text(DATES)
        mutants = {
            "drop": ('Nov = { "лист.", "лист." }, ', ""),
            "swap": ('June = { "червень", "червня" }', 'June = { "липень", "липня" }'),
            "gate": ("local m, d = MONTHS[w], DAYS[w]", "local m, d = MONTHS[w], DAYS[w] or (not MONTHS[w] and { w, w })"),
            "year": ('local y = match(s, "^, (%d%d%d%d)", at)', "local y = nil"),
            "capital": ("d[a == 1 and 2 or 1]", "d[1]"),
        }
        for name, (old, new) in mutants.items():
            with self.subTest(name):
                old, new = raw(old), raw(new)
                self.assertIn(old, src)
                bad = src.replace(old, new, 1)
                try:
                    found = problems(bad)
                except Exception as e:     # a mutant that breaks the file fails too
                    found = [str(e)]
                self.assertTrue(found, name)


if __name__ == "__main__":
    unittest.main()
