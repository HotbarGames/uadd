"""UADD_ForeverQuestPins' data (data/uk_*.lua, T["English"] = "Ukrainian").

Its Locale.lua finds the English of a text on screen by its Ukrainian (Lc.En, used by the hold key and by off).
When two English keys share one Ukrainian, Lc.En gives nil for it, so that text could not go back to English.
Each Ukrainian must belong to one English key, and each English key must be written once.

python3 -m unittest tools.test_fqp_data
"""
import collections
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from game_names_src import fqp_data  # noqa: E402


class Data(unittest.TestCase):
    def test_data_read(self):
        self.assertGreater(len(fqp_data()), 100, "the reader found almost no T[...] = ... lines")

    def test_one_english_per_ukrainian(self):
        by_uk = collections.defaultdict(set)
        where = {}
        for name, line, en, uk in fqp_data():
            by_uk[uk].add(en)
            where.setdefault(uk, "%s:%s" % (name, line))
        shared = ["%s: %r is the Ukrainian of %d keys: %s" % (where[uk], uk, len(ens), sorted(ens))
                  for uk, ens in sorted(by_uk.items()) if len(ens) > 1]
        self.assertEqual(shared, [], "\n".join(shared))

    def test_each_english_once(self):
        seen, twice = {}, []
        for name, line, en, _ in fqp_data():
            if en in seen:
                twice.append("%s:%s: %r is written again (first at %s)" % (name, line, en, seen[en]))
            seen.setdefault(en, "%s:%s" % (name, line))
        self.assertEqual(twice, [], "\n".join(twice))


if __name__ == "__main__":
    unittest.main()
