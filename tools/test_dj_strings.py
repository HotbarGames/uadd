"""Checks UADD_DungeonJournal/ui/strings.lua and ui/strings_systems.lua against ForeverDungeonJournal's
own enUS table, and the enUS tables its feature files (Systems/*.lua and the like) add themselves.

- every key we translate is a key of one of those enUS tables, and every key of the main enUS table
  is translated (the feature files' keys may stay English: each falls back on its own);
- every G"id" link names a glossary entry;
- each Ukrainian value has the same %s/%d list, |c |r |T |t |H |h |n escapes, newlines and
  leading or trailing spaces as the English one;
- each value uses only letters the game fonts draw, has no Russian-only letters, and is
  Ukrainian (has a Cyrillic letter) unless it is a name that stays as it is.

FDJ is not in this repo (All Rights Reserved): its locale file is read from the game folder, or from
the path in FDJ_LOCALIZATION. Without it, the tests that need it are skipped.

python3 -m unittest discover -s tools
python3 tools/test_dj_strings.py
"""
import os
import re
import sys
import unittest
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent
sys.path.insert(0, str(HERE))
import glossary  # noqa: E402
import luatok  # noqa: E402

STRINGS = [REPO / "UADD_DungeonJournal" / "ui" / n for n in ("strings.lua", "strings_systems.lua")]
FDJ_DEFAULT = ("/mnt/c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/"
               "ForeverDungeonJournal/Localization/Localization.lua")
FDJ_LOCALE = Path(os.environ.get("FDJ_LOCALIZATION", FDJ_DEFAULT))

KEY = re.compile(r"^[A-Z][A-Z0-9_]*$")
# A format spec as string.format reads it, minus the space flag: "20% of" is not a spec.
SPEC = re.compile(r"%(?:%|(?:\d+\$)?[-+#0]*\d*(?:\.\d+)?[a-zA-Z])")
ESCAPES = ("|c", "|r", "|T", "|t", "|H", "|h", "|n")
PUNCTUATION = "«»—–…’"
ALLOWED = re.compile("[\n\x20-\x7e" + "А-ЩЬЮЯа-щьюяІіЇїЄєҐґ" + PUNCTUATION + "]*")
RUSSIAN_ONLY = re.compile("[ЫыЭэЪъЁё]")
CYRILLIC = re.compile("[А-Яа-яІіЇїЄєҐґ]")
KEEP_AS_IS = {"OPT_DISCORD", "LF_STAT_MP5", "LF_STAT_HP5"}


def read_table(toks):
    """{KEY: (kind, value, line)} for `KEY = "text"` and `KEY = G"id"` lines; kind is "str" or "g".
    Also returns the keys seen more than once."""
    out, twice = {}, []
    for i in range(len(toks) - 2):
        kind, name, line = toks[i]
        if kind != luatok.NAME or not KEY.match(name) or toks[i + 1][:2] != (luatok.SYM, "="):
            continue
        if i and toks[i - 1][:2] in ((luatok.SYM, "."), (luatok.SYM, ":")):
            continue
        v = toks[i + 2]
        if v[0] == luatok.STR:
            entry = ("str", v[1], line)
        elif v[:2] == (luatok.NAME, "G") and i + 3 < len(toks) and toks[i + 3][0] == luatok.STR:
            entry = ("g", toks[i + 3][1], line)
        else:
            continue  # `local S = {` and the like
        if name in out:
            twice.append(name)
        out[name] = entry
    return out, twice


def ours():
    toks = []
    for path in STRINGS:
        toks += list(luatok.tokens(luatok.read(path)))
    return read_table(toks)


def english():
    """FDJ's enUS table: {KEY: text}."""
    text = luatok.read(FDJ_LOCALE)
    start = text.index("FDJ.Locales.enUS = {")
    end = text.index("FDJ.Locales.deDE", start)
    table, _ = read_table(list(luatok.tokens(text[start:end])))
    return {k: v for k, (kind, v, _) in table.items() if kind == "str"}


def side_english():
    """The `enUS = { KEY = "text" }` tables FDJ's other files add: {KEY: text}."""
    out = {}
    for path in sorted(FDJ_LOCALE.parent.parent.rglob("*.lua")):
        if path == FDJ_LOCALE:
            continue
        toks = list(luatok.tokens(luatok.read(path)))
        for i in range(len(toks) - 2):
            if toks[i][:2] != (luatok.NAME, "enUS") or toks[i + 1][:2] != (luatok.SYM, "=") \
                    or toks[i + 2][:2] != (luatok.SYM, "{"):
                continue
            depth, j = 1, i + 3
            while j < len(toks) and depth:
                if toks[j][0] == luatok.SYM and toks[j][1] in ("{", "}"):
                    depth += 1 if toks[j][1] == "{" else -1
                j += 1
            table, _ = read_table(toks[i + 3:j])
            out.update({k: v for k, (kind, v, _) in table.items() if kind == "str"})
    return out


def resolved():
    """{KEY: (Ukrainian text or None, line, glossary id or None)}"""
    g = glossary.Glossary(REPO)
    table, _ = ours()
    return {k: ((g.text(v), line, v) if kind == "g" else (v, line, None)) for k, (kind, v, line) in table.items()}


def specs(s):
    found = SPEC.findall(s)
    return sorted(found) if any("$" in f for f in found) else found


def shape(s):
    """What must match between English and Ukrainian."""
    return (specs(s), tuple(s.count(e) for e in ESCAPES), s.count("\n"),
            s[:len(s) - len(s.lstrip())], s[len(s.rstrip()):])


class OurStrings(unittest.TestCase):
    def test_no_key_twice(self):
        _, twice = ours()
        self.assertEqual(twice, [])

    def test_links_resolve(self):
        bad = [f"{k} (line {line}): G{gid!r}" for k, (uk, line, gid) in resolved().items() if gid and uk is None]
        self.assertEqual(bad, [], "no glossary entry")

    def test_letters(self):
        bad = []
        for k, (uk, line, _) in resolved().items():
            if uk is None:
                continue
            if not ALLOWED.fullmatch(uk) or RUSSIAN_ONLY.search(uk):
                bad.append(f"{k} (line {line}): {uk!r}")
            elif k not in KEEP_AS_IS and not CYRILLIC.search(uk):
                bad.append(f"{k} (line {line}): not Ukrainian: {uk!r}")
        self.assertEqual(bad, [])


@unittest.skipUnless(FDJ_LOCALE.is_file(), f"FDJ locale file not found: {FDJ_LOCALE} (set FDJ_LOCALIZATION)")
class AgainstFdj(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.en = english()
        cls.side = side_english()
        cls.all = {**cls.side, **cls.en}
        cls.uk = resolved()

    def test_enus_read(self):
        self.assertGreater(len(self.en), 250)
        self.assertIn("FAVOURITES", self.side)

    def test_every_key_is_fdj_key(self):
        self.assertEqual(sorted(set(self.uk) - set(self.all)), [], "keys FDJ's enUS tables do not have")

    def test_every_fdj_key_translated(self):
        self.assertEqual(sorted(set(self.en) - set(self.uk)), [], "enUS keys with no Ukrainian")

    def test_same_shape(self):
        bad = []
        for k, (uk, line, _) in self.uk.items():
            if k in self.all and uk is not None and shape(self.all[k]) != shape(uk):
                bad.append(f"{k} (line {line}): {shape(self.all[k])} vs {shape(uk)}")
        self.assertEqual(bad, [], "%s/%d, | escapes, newlines or edge spaces differ")

    def test_spec_regex(self):
        self.assertEqual(SPEC.findall("about 20% of the trash"), [])
        self.assertEqual(SPEC.findall("Journey %d/%d (%d%%) %1$s %.1f"), ["%d", "%d", "%d", "%%", "%1$s", "%.1f"])


if __name__ == "__main__":
    unittest.main()
