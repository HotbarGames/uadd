"""Check the shared word base (UADD/glossary/*.lua) and how modules use it.

python3 tools/glossary.py            check (exit 0 = ok, 1 = problems); warnings are printed, never fail
python3 tools/glossary.py --list     also print every entry: id, English, Ukrainian

Problems (exit 1): an entry without id/en/uk/note, a bad id, the same id twice, an English wording whose
%s/%d list or |c |r |T |t |H |h |n escapes do not match the Ukrainian, a module that asks for an id that is
not in the base, a linked module string that the game would skip.
Warnings: the same English text with different Ukrainian in two places, one of them a module string with its
own Ukrainian (two glossary entries, or links to them, are two meanings); a module
string whose English and Ukrainian are exactly a glossary entry but is not linked to it; a module string
linked to an entry that does not list that English wording.

Module strings are the `["English"] = "Ukrainian"` and `["English"] = G"id"` lines in UADD_*/ui/*.lua.
Links (G"id", G("id"), Glossary.Text("id")) are found in every UADD_*/**/*.lua. Rules: docs/GLOSSARY.md.
Standard library only. Tests: python3 -m unittest discover -s tools
"""
import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from luatok import NAME, STR, SYM, read as _read, tokens  # noqa: E402

REPO = Path(__file__).resolve().parent.parent
GLOSSARY_DIR = Path("UADD") / "glossary"
FIELDS = ("id", "en", "uk", "note")
ID_RE = re.compile(r"^[a-z][a-z0-9_]*(\.[a-z0-9_]+)+$")


def _value(toks, i):
    """A field value at toks[i]: a string, a list of strings, or None. Returns (value, next index)."""
    if i < len(toks) and toks[i][0] == STR:
        return toks[i][1], i + 1
    if i < len(toks) and toks[i][:2] == (SYM, "{"):
        out, i = [], i + 1
        while i < len(toks) and toks[i][0] == STR:
            out.append(toks[i][1])
            i += 1
            if i < len(toks) and toks[i][:2] == (SYM, ","):
                i += 1
        if i < len(toks) and toks[i][:2] == (SYM, "}"):
            return out, i + 1
    return None, i


def parse_entries(path):
    """Every E{ ... } in a glossary data file: [(fields, line)], fields = {name: value or None}."""
    toks = list(tokens(_read(path)))
    out = []
    for i, tok in enumerate(toks):
        if tok[:2] != (NAME, "E"):
            continue
        j = i + 1
        if j < len(toks) and toks[j][:2] == (SYM, "("):
            j += 1
        if j >= len(toks) or toks[j][:2] != (SYM, "{"):
            continue
        fields, j, depth = {}, j + 1, 1
        while j < len(toks) and depth:
            kind, val, _ = toks[j]
            if kind == NAME and j + 1 < len(toks) and toks[j + 1][:2] == (SYM, "=") and depth == 1:
                fields[val], j = _value(toks, j + 2)
                continue
            depth += (kind, val) == (SYM, "{")
            depth -= (kind, val) == (SYM, "}")
            j += 1
        out.append((fields, tok[2]))
    return out


class Glossary:
    """The entries of a repo's word base, plus the problems found while reading it."""

    def __init__(self, root=REPO):
        self.root = Path(root)
        self.entries, self.problems = {}, []
        folder = self.root / GLOSSARY_DIR
        self.files = sorted(folder.glob("*.lua")) if folder.is_dir() else []
        for path in self.files:
            rel = path.relative_to(self.root).as_posix()
            for fields, line in parse_entries(path):
                self._add(fields, f"{rel}:{line}")

    def _add(self, fields, where):
        missing = [f for f in FIELDS if not fields.get(f)]
        if missing:
            self.problems.append(f"{where}: entry has no {', '.join(missing)} (each entry needs id, en, uk, note)")
            return
        e = dict(fields, where=where)
        e["en"] = [e["en"]] if isinstance(e["en"], str) else list(e["en"])
        if not all(isinstance(e[f], str) for f in ("id", "uk", "note")):
            self.problems.append(f"{where}: id, uk and note must be plain strings")
            return
        if not ID_RE.match(e["id"]):
            self.problems.append(f"{where}: bad id {e['id']!r} (use area.name: lower case, digits, _)")
        if e["id"] in self.entries:
            self.problems.append(f"{where}: id {e['id']!r} is already used at {self.entries[e['id']]['where']}")
            return
        from coverage import compatible  # here, not at the top: coverage imports this file
        for en in e["en"]:
            if not compatible(en, e["uk"]):
                self.problems.append(f"{where}: {e['id']}: {en!r} and {e['uk']!r} do not have the same "
                                     "%s/%d list and |c |r |T |t |H |h |n escapes")
        self.entries[e["id"]] = e

    def text(self, gid):
        e = self.entries.get(gid)
        return e["uk"] if e else None


def _ref_at(toks, i):
    """The glossary id if toks[i] starts a link: G"id", G("id"), Glossary.Text("id"). Else None."""
    j = None
    if toks[i][:2] == (NAME, "G"):
        j = i + 1
    elif toks[i][:2] == (NAME, "Glossary") and [t[:2] for t in toks[i + 1:i + 3]] == [(SYM, "."), (NAME, "Text")]:
        j = i + 3
    if j is None or j >= len(toks):
        return None
    if toks[j][:2] == (SYM, "(") and j + 2 < len(toks) and toks[j + 1][0] == STR and toks[j + 2][:2] == (SYM, ")"):
        return toks[j + 1][1]
    if toks[j][0] == STR and toks[i][1] == "G":
        return toks[j][1]
    return None


def find_refs(path):
    """[(id, line)] for every link to the glossary in a Lua file."""
    toks = list(tokens(_read(path)))
    out = []
    for i in range(len(toks)):
        if i and toks[i - 1][:2] in ((SYM, "."), (SYM, ":")) and toks[i][1] == "G":
            continue  # a field called G, not our helper
        gid = _ref_at(toks, i)
        if gid is not None:
            out.append((gid, toks[i][2]))
    return out


def module_pairs(path):
    """[(english, ukrainian or None, glossary id or None, line)] for `["en"] = "uk"` / `["en"] = G"id"`."""
    toks = list(tokens(_read(path)))
    out = []
    for i in range(len(toks) - 4):
        if toks[i][:2] == (SYM, "[") and toks[i + 1][0] == STR and toks[i + 2][:2] == (SYM, "]") \
                and toks[i + 3][:2] == (SYM, "="):
            if toks[i + 4][0] == STR and not (i + 5 < len(toks) and toks[i + 5][:2] == (SYM, ".")):  # not "a" .. b
                out.append((toks[i + 1][1], toks[i + 4][1], None, toks[i][2]))
            else:
                gid = _ref_at(toks, i + 4)
                if gid is not None:
                    out.append((toks[i + 1][1], None, gid, toks[i][2]))
    return out


def read_module_strings(path, glossary=None):
    """{english: ukrainian} as the game builds it from a module's strings file: links are resolved through
    the glossary; a link to a missing id gives no entry. Later lines win, as in a Lua table."""
    path = Path(path)
    if not path.exists():
        return {}
    glossary = glossary if glossary is not None else Glossary()
    out = {}
    for en, uk, gid, _ in module_pairs(path):
        value = uk if gid is None else glossary.text(gid)
        if value is None:
            out.pop(en, None)
        else:
            out[en] = value
    return out


def module_files(root):
    root = Path(root)
    return sorted(p for p in root.glob("UADD_*/**/*.lua") if p.is_file())


def check(root=REPO):
    """Returns (problems, warnings, glossary) as printable lines."""
    root = Path(root)
    g = Glossary(root)
    problems, warnings = list(g.problems), []
    rel = lambda p: Path(p).relative_to(root).as_posix()  # noqa: E731
    for path in module_files(root):
        for gid, line in find_refs(path):
            if gid not in g.entries:
                problems.append(f"{rel(path)}:{line}: no glossary entry {gid!r} (add it to {GLOSSARY_DIR.as_posix()}/"
                                "*.lua or fix the id)")

    from coverage import compatible
    places = {}  # english -> [(ukrainian, where, True for a module string with its own Ukrainian)]
    for e in g.entries.values():
        for en in e["en"]:
            places.setdefault(en, []).append((e["uk"], f"glossary {e['id']} ({e['where']})", False))
    by_pair = {}
    for e in g.entries.values():
        for en in e["en"]:
            by_pair.setdefault((en, e["uk"]), []).append(e["id"])
    for path in sorted(root.glob("UADD_*/ui/*.lua")):
        for en, uk, gid, line in module_pairs(path):
            where = f"{rel(path)}:{line}"
            if gid is not None:
                e = g.entries.get(gid)
                if e is None:
                    continue  # reported above
                uk = e["uk"]
                if not compatible(en, uk):
                    problems.append(f"{where}: {en!r} is linked to {gid}, but {uk!r} has other %s/%d or | escapes; "
                                    "the game would skip it")
                if en not in e["en"]:
                    warnings.append(f"{where}: {en!r} is linked to {gid}, whose English is {e['en']}; add the "
                                    "wording to the entry if the meaning is the same, or unlink it")
            else:
                for other in by_pair.get((en, uk), []):
                    warnings.append(f"{where}: {en!r} = {uk!r} is the same as glossary {other}; link it "
                                    f"(G\"{other}\") if the meaning is the same")
            places.setdefault(en, []).append((uk, where, gid is None))
    # Two entries with one English are two meanings (docs/GLOSSARY.md), and a linked module string chose
    # one of them: only a module string with its own Ukrainian can disagree with something by mistake.
    for en, seen in sorted(places.items()):
        if len({uk for uk, _, _ in seen}) > 1 and any(own for _, _, own in seen):
            warnings.append(f"{en!r} has different Ukrainian: " + "; ".join(f"{uk!r} in {w}" for uk, w, _ in seen))
    return problems, warnings, g


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--root", default=str(REPO))
    ap.add_argument("--list", action="store_true", help="print every entry")
    args = ap.parse_args(argv)
    problems, warnings, g = check(args.root)
    if args.list:
        for e in g.entries.values():
            print(f"{e['id']:<32} {' / '.join(e['en'])}  =  {e['uk']}")
    linked = sum(1 for p in sorted(Path(args.root).glob("UADD_*/ui/*.lua")) for _, _, gid, _ in module_pairs(p) if gid)
    print(f"glossary: {len(g.entries)} entries in {len(g.files)} files; {linked} module strings linked")
    for line in warnings:
        print("warning: " + line)
    for line in problems:
        print("problem: " + line)
    print(f"glossary: {len(problems)} problem(s), {len(warnings)} warning(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
