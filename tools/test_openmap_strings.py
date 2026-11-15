"""Checks UADD_OpenMap/ui/locale.lua against OpenMap's own L["..."] keys.

- every L key OpenMap uses is in MAP or LOADTIME, or is a planned skip (SKIP_NAMES, SKIP_OTHER);
  no key is there that OpenMap does not use; LOADTIME keys are OpenMap keys too;
- no key twice, and no key both in MAP and in LOADTIME;
- every G"id" link names a glossary entry;
- each Ukrainian value has the same %s/%d list, |c |r |T |t |H |h |n escapes, newlines and
  leading or trailing spaces as its English key;
- each value uses only letters the game fonts draw, has no Russian-only letters, and is
  Ukrainian (has a Cyrillic letter);
- MONTHS has all twelve months.

OpenMap is not in this repo: its files are read from the game folder, or from the path in
OPENMAP_DIR. Without it, the tests that need it are skipped.

python3 tools/test_openmap_strings.py
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
import luatok  # noqa: E402
import test_font_chars  # noqa: E402  (its ALLOWED: the letters the game fonts draw)

LOCALE = REPO / "UADD_OpenMap" / "ui" / "locale.lua"
OPENMAP_DEFAULT = "/mnt/c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/OpenMap"
OPENMAP = Path(os.environ.get("OPENMAP_DIR", OPENMAP_DEFAULT))

TABLES = ("MAP", "LOADTIME", "MONTHS")
SKIP_NAMES = {"OpenMap"}      # only a name: names come from UALL
SKIP_OTHER = {"%d %s %s"}     # a date: no words, nothing to translate
MONTH_NAMES = ("January", "February", "March", "April", "May", "June", "July", "August",
               "September", "October", "November", "December")

# A format spec as string.format reads it, minus the space flag: "0% keeps" is not a spec.
SPEC = re.compile(r"%(?:%|(?:\d+\$)?[-+#0]*\d*(?:\.\d+)?[a-zA-Z])")
ESCAPES = ("|c", "|r", "|T", "|t", "|H", "|h", "|n")
RUSSIAN_ONLY = re.compile("[ЫыЭэЪъЁё]")
CYRILLIC = re.compile("[А-Яа-яІіЇїЄєҐґ]")


def entries(toks):
    """[(key, kind, value, line)] for `["key"] = "text"` and `["key"] = G"id"`; kind is "str" or "g"."""
    out = []
    for i in range(len(toks) - 5):
        if toks[i][:2] != (luatok.SYM, "[") or toks[i + 1][0] != luatok.STR:
            continue
        if toks[i + 2][:2] != (luatok.SYM, "]") or toks[i + 3][:2] != (luatok.SYM, "="):
            continue
        key, line, v = toks[i + 1][1], toks[i + 1][2], toks[i + 4]
        if v[0] == luatok.STR:
            out.append((key, "str", v[1], line))
        elif v[:2] == (luatok.NAME, "G") and toks[i + 5][0] == luatok.STR:
            out.append((key, "g", toks[i + 5][1], line))
    return out


def ours():
    """{table name: [(key, kind, value, line)]} for MAP, LOADTIME and MONTHS in locale.lua."""
    toks = list(luatok.tokens(luatok.read(LOCALE)))
    found = {}
    i = 0
    while i < len(toks) - 2:
        name = toks[i]
        if (name[0] == luatok.NAME and name[1] in TABLES and toks[i + 1][:2] == (luatok.SYM, "=")
                and toks[i + 2][:2] == (luatok.SYM, "{")):
            depth, j = 1, i + 3
            while j < len(toks) and depth:
                if toks[j][:2] == (luatok.SYM, "{"):
                    depth += 1
                elif toks[j][:2] == (luatok.SYM, "}"):
                    depth -= 1
                j += 1
            found[name[1]] = entries(toks[i + 3:j])
            i = j
        else:
            i += 1
    return found


def resolved():
    """[(table, key, Ukrainian text or None, line, glossary id or None)]"""
    g = glossary.Glossary(REPO)
    return [(t, k, (g.text(v) if kind == "g" else v), line, (v if kind == "g" else None))
            for t, rows in ours().items() for k, kind, v, line in rows]


def openmap_keys():
    """Every L["..."] key in OpenMap's own code (not its Locales or Libs)."""
    keys = set()
    for d, dirs, files in os.walk(OPENMAP):
        rel = Path(d).relative_to(OPENMAP).parts
        if rel and rel[0] in ("Locales", "Libs"):
            dirs[:] = []
            continue
        for f in files:
            if not f.endswith(".lua"):
                continue
            toks = list(luatok.tokens(luatok.read(Path(d) / f)))
            for i in range(len(toks) - 3):
                if (toks[i][:2] == (luatok.NAME, "L") and toks[i + 1][:2] == (luatok.SYM, "[")
                        and toks[i + 2][0] == luatok.STR and toks[i + 3][:2] == (luatok.SYM, "]")):
                    keys.add(toks[i + 2][1])
    return keys


def specs(s):
    found = SPEC.findall(s)
    return sorted(found) if any("$" in f for f in found) else found


def shape(s):
    """What must match between English and Ukrainian."""
    return (specs(s), tuple(s.count(e) for e in ESCAPES), s.count("\n"),
            s[:len(s) - len(s.lstrip())], s[len(s.rstrip()):])


class OurStrings(unittest.TestCase):

    # Two plain words may share one Ukrainian text ("Підземелля": "Dungeon", "Dungeons"):
    # Locale.lua gives them through L's __index and notes which key was read, and Words.lua keeps
    # each FontString's English, so nothing is read back from the text. Formatted texts ("%d ...")
    # are still read back from their Ukrainian pattern (Locale.lua: back), so two of them must not
    # share one Ukrainian text: the second would come back as the first's English.
    def test_no_shared_formatted_ukrainian(self):
        by = {}
        for _t, key, uk, _line, _gid in resolved():
            if "%" in key:
                by.setdefault(uk, set()).add(key)
        bad = {uk: sorted(keys) for uk, keys in by.items() if len(keys) > 1}
        self.assertEqual(bad, {}, "one Ukrainian text for several formatted English keys")
    @classmethod
    def setUpClass(cls):
        cls.tables = ours()
        cls.rows = resolved()

    def test_tables_found(self):
        self.assertEqual(sorted(self.tables), sorted(TABLES))
        self.assertGreater(len(self.tables["MAP"]), 400)

    def test_no_key_twice(self):
        twice = []
        for t, rows in self.tables.items():
            seen = set()
            for k, _, _, line in rows:
                if k in seen:
                    twice.append(f"{t}: {k!r} (line {line})")
                seen.add(k)
        self.assertEqual(twice, [])

    def test_map_and_loadtime_apart(self):
        both = {k for k, *_ in self.tables["MAP"]} & {k for k, *_ in self.tables["LOADTIME"]}
        self.assertEqual(sorted(both), [], "keys in both MAP and LOADTIME")

    def test_no_skipped_key_translated(self):
        keys = {k for t in ("MAP", "LOADTIME") for k, *_ in self.tables[t]}
        self.assertEqual(sorted(keys & (SKIP_NAMES | SKIP_OTHER)), [])

    def test_links_resolve(self):
        bad = [f"{k} (line {line}): G{gid!r}" for _, k, uk, line, gid in self.rows if gid and uk is None]
        self.assertEqual(bad, [], "no glossary entry")

    def test_letters(self):
        bad = []
        for _, k, uk, line, _ in self.rows:
            if uk is None:
                continue
            if not test_font_chars.ALLOWED.fullmatch(uk) or RUSSIAN_ONLY.search(uk):
                bad.append(f"{k} (line {line}): {uk!r}")
            elif not CYRILLIC.search(uk):
                bad.append(f"{k} (line {line}): not Ukrainian: {uk!r}")
        self.assertEqual(bad, [])

    def test_same_shape(self):
        bad = [f"{k} (line {line}): {shape(k)} vs {shape(uk)}"
               for _, k, uk, line, _ in self.rows if uk is not None and shape(k) != shape(uk)]
        self.assertEqual(bad, [], "%s/%d, | escapes, newlines or edge spaces differ")

    def test_months(self):
        self.assertEqual(sorted(k for k, *_ in self.tables["MONTHS"]), sorted(MONTH_NAMES))

    def test_spec_regex(self):
        self.assertEqual(SPEC.findall("0% keeps it solid"), [])
        self.assertEqual(SPEC.findall("%.0f MB (%+.1f MB) %d%% %s"), ["%.0f", "%+.1f", "%d", "%%", "%s"])


@unittest.skipUnless(OPENMAP.is_dir(), f"OpenMap not found: {OPENMAP} (set OPENMAP_DIR)")
class AgainstOpenMap(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.en = openmap_keys()
        cls.tables = ours()

    def test_keys_read(self):
        self.assertGreater(len(self.en), 500)

    def test_every_key_covered(self):
        ours_ = {k for t in ("MAP", "LOADTIME") for k, *_ in self.tables[t]}
        missing = self.en - ours_ - SKIP_NAMES - SKIP_OTHER
        self.assertEqual(sorted(missing), [], "OpenMap keys with no Ukrainian")

    def test_no_extra_keys(self):
        ours_ = {k for t in ("MAP", "LOADTIME") for k, *_ in self.tables[t]}
        self.assertEqual(sorted(ours_ - self.en), [], "keys OpenMap does not use")

    def test_skips_are_keys(self):
        self.assertEqual(sorted((SKIP_NAMES | SKIP_OTHER) - self.en), [], "planned skips OpenMap no longer has")


if __name__ == "__main__":
    unittest.main()
