"""Auctionator's column headers must fit their column (docs/LESSONS.md, lesson 5).

A results table's column is as wide as the English needs, so a much longer Ukrainian header is cut
(«Рівень пред...»). For every header Auctionator's code makes from a locale key (`headerText =
AUCTIONATOR_L_<KEY>`), this takes the words UADD shows on it, as Rows.lua does: the short form in
ns.UA_HEAD (ui/locale.lua) for that English, else the ns.UA words Words.lua picks (the first key by
name with that English). Each must be at most the English's length + SLACK letters, unless LONG says
why it may be longer. Also: every ns.UA_HEAD key is a header key, its words are shorter than that key's
ns.UA words, and every LONG entry is still a header that is too long.

The English is read from the installed Auctionator (see tools/test_auc_strings.py); without it the test
is skipped.

python3 -m unittest tools.test_auc_headers
"""
import re
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import glossary  # noqa: E402
import test_auc_strings as S  # noqa: E402

SLACK = 2
HEADER = re.compile(r"headerText\s*=\s*AUCTIONATOR_L_(\w+)")
LONG = {
    "BIDDER": "Cancelling list only, hidden by default, and its column shares the free width with the "
              "name column; no shorter word says «a bidder» (one who has not bought yet).",
}


def words(rows, g):
    """{key: Ukrainian} of read_locale rows, glossary links resolved."""
    return {key: (uk if gid is None else g.text(gid)) for key, uk, gid, _ in rows}


def first_by_english(table, enus):
    """{English: Ukrainian} from {key: Ukrainian}: the first key by name wins, as in Words.lua."""
    out = {}
    for key in sorted(table):
        en = enus[key][0] if key in enus else None
        if en is not None and en not in out and table[key]:
            out[en] = table[key]
    return out


@unittest.skipUnless(S.HAVE_ADDON, S.SKIP)
class HeadersFit(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.enus, _ = S.M.read_enus(S.ADDON)
        g = glossary.Glossary()
        cls.ua = words(S.read_locale(S.LOCALE)["UA"], g)
        cls.head = words(S.read_locale(S.LOCALE, "UA_HEAD")["UA_HEAD"], g)
        cls.keys = sorted({k for text in S.code_files().values() for k in HEADER.findall(text)})
        by_en, short = first_by_english(cls.ua, cls.enus), first_by_english(cls.head, cls.enus)
        cls.shown = {}   # key: (English, Ukrainian shown or None)
        for key in cls.keys:
            en = cls.enus[key][0] if key in cls.enus else None
            cls.shown[key] = (en, short.get(en) or by_en.get(en))

    def test_headers_found(self):
        self.assertTrue(self.keys, "no headerText = AUCTIONATOR_L_ in Auctionator's code")

    def test_headers_fit(self):
        bad = [f"{k}: {len(uk)} letters «{uk}», English {len(en)}"
               for k, (en, uk) in self.shown.items()
               if en and uk and len(uk) > len(en) + SLACK and k not in LONG]
        self.assertEqual(bad, [], f"headers longer than English + {SLACK}: shorten, add to ns.UA_HEAD, "
                                  "or to LONG with a reason")

    def test_long_still_needed(self):
        for key in LONG:
            en, uk = self.shown.get(key, (None, None))
            self.assertTrue(en and uk and len(uk) > len(en) + SLACK, f"LONG {key}: not a long header now")

    def test_short_forms(self):
        for key, uk in self.head.items():
            self.assertIn(key, self.keys, f"ns.UA_HEAD {key}: not a column header key")
            self.assertTrue(uk, f"ns.UA_HEAD {key}: no words")
            self.assertLess(len(uk), len(self.ua.get(key) or ""), f"ns.UA_HEAD {key}: not shorter than ns.UA")


class Readers(unittest.TestCase):
    def test_first_by_english(self):
        enus = {"A": ("Same",), "B": ("Same",), "C": ("Other",)}
        self.assertEqual(first_by_english({"B": "б", "A": "а", "C": "в", "D": "г"}, enus),
                         {"Same": "а", "Other": "в"})


if __name__ == "__main__":
    unittest.main()
