"""Checks UADD_DialogueUI/ui/locale.lua (ns.UA) and ui/hashes.lua (ns.DUI_HASH) against the installed
DialogueUI's Locales/enUS.lua.

- locale.lua has every key enUS.lua gives an English text, no key twice, and no key enUS.lua lacks;
- no English of DialogueUI's in locale.lua: no comment holds its key's English, and no Ukrainian is a copy
  of it (a text kept in English on purpose is false);
- each Ukrainian value has the same codes, in the same order, as its English: % specs (%%
  too), |c |r |T..|t |H..|h |n, \\n line breaks and [KEY:..] key markup; and the same leading or
  trailing space;
- hashes.lua is what tools/make_dui_data.py builds from enUS.lua and locale.lua now.

DialogueUI is not in this repo: its files are read from the game folder, or from the path in
DIALOGUEUI_DIR. Without it, the tests are skipped.

python3 tools/test_dialogueui_strings.py
"""
import os
import re
import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent
sys.path.insert(0, str(HERE))
import glossary  # noqa: E402
import make_dui_data  # noqa: E402
LOCALE = REPO / "UADD_DialogueUI" / "ui" / "locale.lua"
HASHES = REPO / "UADD_DialogueUI" / "ui" / "hashes.lua"
DUI_DEFAULT = "/mnt/c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/DialogueUI"
DUI = Path(os.environ.get("DIALOGUEUI_DIR", DUI_DEFAULT))
ENUS = DUI / "Locales" / "enUS.lua"

LIT = r'"((?:[^"\\]|\\.)*)"'
CODES = re.compile(r'%(?:\d+\$)?[-+ #0]*\d*(?:\.\d+)?[sdifgxXc%]|\|c[0-9a-fA-F]{8}|\|r|\|T[^|]*\|t'
                   r'|\|H[^|]*\|h|\|n|\\n|\[KEY:[^\]]+\]')


def read_enus():
    """{key: English literal} and [keys that are only a game global]."""
    en, only_global = {}, []
    for line in ENUS.read_text(encoding="utf-8").splitlines():
        m = re.match(r'\s*L\[' + LIT + r'\]\s*=\s*(.*)', line)
        if not m:
            continue
        lits = re.findall(LIT, m.group(2))
        if lits:
            en.setdefault(m.group(1), lits[0])
        else:
            only_global.append(m.group(1))
    return en, only_global


def read_ua():
    """{key: Ukrainian or None}, {key: comment}, [keys seen twice], {key: plain literal}. A G"id" value is
    the glossary's Ukrainian ("" when the id is missing; tools/glossary.py reports that); false is None."""
    g = glossary.Glossary(REPO)
    ua, comments, twice, plain = {}, {}, [], {}
    for line in LOCALE.read_text(encoding="utf-8").splitlines():
        m = re.match(r'\s*\[' + LIT + r'\]\s*=\s*(?:(G\s*)?' + LIT + r'|(false))\s*,(?:\s*-- (.*))?$', line)
        if m:
            k = m.group(1)
            if k in ua:
                twice.append(k)
            if m.group(4):
                ua[k] = None
            elif m.group(2):
                ua[k] = g.text(m.group(3)) or ""
            else:
                ua[k] = plain[k] = m.group(3)
            comments[k] = m.group(5)
    return ua, comments, twice, plain


@unittest.skipUnless(ENUS.is_file(), f"DialogueUI not found ({DUI}); set DIALOGUEUI_DIR")
@unittest.skipUnless(LOCALE.is_file(), "UADD_DialogueUI/ui/locale.lua not there")
class LocaleAgainstEnUS(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.en, cls.only_global = read_enus()
        cls.ua, cls.comments, cls.twice, cls.plain = read_ua()

    def test_keys(self):
        self.assertEqual(self.twice, [], "keys twice")
        self.assertEqual([k for k in self.en if k not in self.ua], [], "enUS keys missing from locale.lua")
        extra = [k for k in self.ua if k not in self.en and k not in self.only_global]
        self.assertEqual(extra, [], "locale.lua keys enUS.lua does not have")

    def test_no_english_in_comments(self):
        bad = [k for k, en in self.en.items() if len(en.strip()) > 3 and en.strip() in (self.comments.get(k) or "")]
        self.assertEqual(bad, [], "these keys' comments hold DialogueUI's English: take it out")

    def test_no_copied_english(self):
        bad = [k for k, v in self.plain.items() if k in self.en and v == self.en[k]]
        self.assertEqual(bad, [], "Ukrainian that is the English: make it false (kept in English on purpose)")

    def test_codes_in_order(self):
        bad = []
        for k, en in self.en.items():
            if self.ua.get(k) is not None:
                a, b = CODES.findall(en), CODES.findall(self.ua[k])
                if a != b:
                    bad.append((k, a, b))
        self.assertEqual(bad, [], "codes differ or are in another order")

    def test_edge_spaces(self):
        bad = [k for k, en in self.en.items() if self.ua.get(k) is not None and
               (en.startswith(" ") != self.ua[k].startswith(" ") or en.endswith(" ") != self.ua[k].endswith(" "))]
        self.assertEqual(bad, [], "leading or trailing space differs")


@unittest.skipUnless(ENUS.is_file(), f"DialogueUI not found ({DUI}); set DIALOGUEUI_DIR")
@unittest.skipUnless(LOCALE.is_file() and HASHES.is_file(), "UADD_DialogueUI/ui/hashes.lua not there")
class HashesAgainstEnUS(unittest.TestCase):
    def test_up_to_date(self):
        enus, bad = make_dui_data.read_enus(ENUS)
        self.assertEqual(bad, [], "enUS.lua lines tools/make_dui_data.py cannot read")
        made = make_dui_data.hashes_text(enus, make_dui_data.read_locale())
        self.assertEqual(HASHES.read_text(encoding="utf-8"), made,
                         "ui/hashes.lua is out of date: run python3 tools/make_dui_data.py")

    def test_no_english(self):
        # Only the values: a key is DialogueUI's locale key, which the rule allows.
        values = "\n".join(re.findall(r'^    \[(?:"(?:[^"\\]|\\.)*")\] = (.*)$',
                                      HASHES.read_text(encoding="utf-8"), re.M))
        self.assertTrue(values, "hashes.lua has no keys")
        enus, _ = make_dui_data.read_enus(ENUS)
        bad = [k for k, (_, en) in enus.items() if len(en) > 3 and make_dui_data.lua_str(en) in values]
        self.assertEqual(bad, [], "hashes.lua holds DialogueUI's English")


if __name__ == "__main__":
    unittest.main()
