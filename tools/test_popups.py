"""Each StaticPopup dialog of a translated addon whose buttons show a game global or an L word goes through the
core popup helper (UADD/Popups.lua, docs/LESSONS3.md "Lesson 1 again, in Auctionator's popups").

ClassicUA alone leaves the game's globals (ACCEPT, CANCEL, YES, ...) English, and an addon's L word on a
dialog's button is copied when the dialog is made, often before our words are in L. So the module registers the
dialog with UADD.Popups.Register (by name, or by a name start: `prefix`), and the helper gives the button our
word. This test reads each installed translated addon (its own .lua files; libs and Sushi skipped), finds every
`StaticPopupDialogs[<name>] = { ... }` and `StaticPopupDialogs[<name>].buttonN = ...`, and keeps the dialogs
whose button fields hold an all-capitals global or an L word. Each one must be registered by its module (a name
or a prefix in the module's file that calls U.Popups.Register), or be in ALLOW with a reason. A name it cannot
read (a variable in a function) is keyed by "<folder>/<file>:<what is in the brackets>". An ALLOW entry that no
dialog needs any more fails too. An addon that is not installed is skipped, with a message ($UADD_ADDONS_DIR or
the WoW _forever_ folder, tools/copy_scan.py). Only dialog names are kept here, never the addons' English.

    python3 -m unittest tools.test_popups
    python3 tools/test_popups.py            (lists every dialog found: module, name, buttons, registered or not)
"""
import re
import sys
import unittest
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import copy_scan  # noqa: E402
import drift_sources  # noqa: E402
import luatok  # noqa: E402

ROOT = HERE.parent
# "<folder>:<name>" or "<folder>/<file>:<key>" -> why the module does not register that dialog
ALLOW = {
    "TomTom/core/profiles.lua:name": "made by its ConfirmDialog(name, ...) for the TOMTOM_*_PROFILE dialogs; every "
        "one is in POPUPS (UADD_TomTom/Settings.lua), which it registers by name",
    "DeleteCheapestItem:DCI_RELOADED_DELETE_ITEM": "its body is the game's DELETE_ITEM global and an item, none of "
        "our words, as in the game's own delete question; YES and NO then follow the game's language with it, so "
        "our buttons under an English body would mix two languages in one question",
}

ENTRY = re.compile(r"StaticPopupDialogs\s*\[([^\]]+)\]\s*(?:=\s*(?:StaticPopupDialogs\s*\[[^\]]+\]\s*or\s*)?\{"
                   r"|\.\s*button([1-4])\s*=\s*([^\n,;]+))")
BUTTON = re.compile(r"\bbutton[1-4]\s*=\s*([^,\n}]+)")
GLOBAL = re.compile(r"^[A-Z][A-Z0-9_]*$")
LWORD = re.compile(r"^\w*(?:L|Lang|Locale)(?:\[|\.\w)")
STRING = re.compile(r'^"(.*)"$')


def _q(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def _strip(code):
    """The code again from its Lua tokens (tools/luatok.py): no comments, each string in double quotes, one line
    of tokens per source line."""
    lines = {}
    for kind, value, line in luatok.tokens(code):
        lines.setdefault(line, []).append(_q(value) if kind == luatok.STR else value)
    return "\n".join(" ".join(lines.get(i, [])) for i in range(1, max(lines, default=0) + 1))


def _tidy(value):
    return re.sub(r"\s*([\[\].])\s*", r"\1", value.strip())


def _body(code, i):
    """The table that opens at code[i] ("{"), up to its closing brace (strings not counted)."""
    depth, j, quote = 0, i, None
    while j < len(code):
        c = code[j]
        if quote:
            if c == "\\":
                j += 1
            elif c == quote:
                quote = None
        elif c in "\"'":
            quote = c
        elif c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return code[i:j + 1]
        j += 1
    return code[i:]


def shows_word(value):
    """A button value that is a game global or an L word (its first operand, before any "or")."""
    v = _tidy(_tidy(value).split(" or ")[0])
    return bool(GLOBAL.match(v) or LWORD.match(v))


class _Stripped:
    """The addon's files as _strip gives them, each stripped only when asked for. A file without the name in its
    raw text cannot hold it as a word after _strip (a word token keeps its letters), so it is never stripped for
    that name: the tokenizer is the slow part (30 s of 40 for every file, 2026-11-22)."""

    def __init__(self, raws):
        self.raws, self.done = raws, {}

    def having(self, word):
        for p, raw in self.raws.items():
            if word in raw:
                if p not in self.done:
                    self.done[p] = _strip(raw)
                yield p, self.done[p]


def _name(raw, code, files):
    """The dialog's name: a string in the brackets, or a variable set to one (this file first, then the addon:
    `files`, a _Stripped)."""
    raw = _tidy(raw)
    m = STRING.match(raw)
    if m:
        return m.group(1)
    ident = raw.split(".")[-1]
    if not re.match(r"^\w+$", ident):
        return None
    if ident[0].islower():      # a function's argument (name, key): only a local set in this file counts
        m = re.search(r"\blocal\s+" + ident + r"\s*=\s*\"([^\"]+)\"", code)
        return m.group(1) if m else None
    pat = re.compile(r"\b" + ident + r"\s*=\s*\"([^\"]+)\"")
    m = pat.search(code)
    if m:
        return m.group(1)
    for _, text in files.having(ident):
        m = pat.search(text)
        if m:
            return m.group(1)
    return None


def _lua(top):
    for p in sorted(top.rglob("*.lua")):
        low = str(p.relative_to(top)).lower().replace("\\", "/")
        if "libs/" in low or "sushi" in low:
            continue
        yield p


def dialogs(top, folder):
    """[(key, name, [button values])] for each dialog whose buttons show a global or an L word."""
    paths = list(_lua(top))
    with ThreadPoolExecutor(16) as pool:     # the WoW folder is on /mnt/c: each open waits, the reads overlap
        raws = list(pool.map(lambda p: p.read_text(encoding="utf-8", errors="replace"), paths))
    every = _Stripped(dict(zip(paths, raws)))
    found = {}
    for p, code in every.having("StaticPopupDialogs"):
        rel = str(p.relative_to(top)).replace("\\", "/")
        for m in ENTRY.finditer(code):
            if m.group(2):
                values = [m.group(3)]
            else:
                values = BUTTON.findall(_body(code, m.end() - 1))
            values = [_tidy(v) for v in values if shows_word(v)]
            if not values:
                continue
            name = _name(m.group(1), code, every)
            key = f"{folder}:{name}" if name else f"{folder}/{rel}:{_tidy(m.group(1))}"
            found.setdefault(key, (name, []))[1].extend(values)
    return [(k, n, v) for k, (n, v) in sorted(found.items())]


def registered(module_dir):
    """(names, prefixes) from the module's files that call U.Popups.Register."""
    names, prefixes = set(), set()
    for p in sorted(Path(module_dir).rglob("*.lua")):
        code = _strip(p.read_text(encoding="utf-8", errors="replace"))
        if not re.search(r"\b(?:U|UADD)\s*\.\s*Popups\s*\.\s*Register\s*\(", code):
            continue
        prefixes |= {x.upper() for x in re.findall(r"\bprefix\s*=\s*\"([^\"]+)\"", code)}
        names |= set(re.findall(r"\"([A-Za-z][A-Za-z0-9_]+)\"", code))
        names |= set(re.findall(r"\b([A-Z][A-Z0-9_]+)\s*=\s*true\b", code))
    return names, prefixes


def covered(name, names, prefixes):
    return bool(name) and (name in names or any(name.upper().startswith(x) for x in prefixes))


def problems(found, names, prefixes):
    return [f"{k}: {', '.join(v)}" for k, n, v in found if not covered(n, names, prefixes) and k not in ALLOW]


def installed_modules():
    """[(module, folder, path or None)] for each translated addon."""
    base = Path(copy_scan.addons_dir())
    out = []
    for module, row in sorted(drift_sources.MODULES.items()):
        folder = row[0]
        top = base / folder
        out.append((module, folder, top if top.is_dir() else None))
    return out


class PopupsTest(unittest.TestCase):
    def test_every_dialog_registered_or_allowed(self):
        bad, seen, skipped = [], set(), []
        for module, folder, top in installed_modules():
            if top is None:
                skipped.append(folder)
                continue
            names, prefixes = registered(ROOT / module)
            found = dialogs(top, folder)
            seen |= {k for k, _, _ in found}
            bad += [f"{module}: {p}" for p in problems(found, names, prefixes)]
        if skipped:
            print(f"\ntest_popups: not installed, skipped: {', '.join(skipped)}")
        self.assertEqual(bad, [], "dialogs with a game global or an L word on a button, not registered with "
                         "U.Popups.Register (UADD/Popups.lua) and not in ALLOW")
        gone = [k for k in ALLOW if k.split(":")[0].split("/")[0] not in skipped and k not in seen]
        self.assertEqual(gone, [], "ALLOW entries no dialog needs any more")

    def test_finder_reads_made_up_dialogs(self):
        import tempfile
        with tempfile.TemporaryDirectory() as d:
            top = Path(d) / "Made"
            (top / "libs").mkdir(parents=True)
            (top / "a.lua").write_text(
                'local P = "MADE_TWO"\n'
                'StaticPopupDialogs["MADE_ONE"] = { text = "", button1 = OKAY or "x", button2 = L["Nope"] }\n'
                'StaticPopupDialogs[P] = { text = "", button1 = "plain" }\n'
                'StaticPopupDialogs[P].button2 = CANCEL\n'
                'StaticPopupDialogs["MADE_STR"] = { button1 = "plain", button2 = someVar }\n'
                '-- StaticPopupDialogs["MADE_COMMENT"] = { button1 = OKAY }\n'
                'local function F(n) StaticPopupDialogs[n] = { button1 = YES } end\n', encoding="utf-8")
            (top / "libs" / "b.lua").write_text('StaticPopupDialogs["MADE_LIB"] = { button1 = OKAY }\n',
                                                encoding="utf-8")
            found = {k: v for k, _, v in dialogs(top, "Made")}
            self.assertEqual(sorted(found), ["Made/a.lua:n", "Made:MADE_ONE", "Made:MADE_TWO"])
            self.assertEqual(found["Made:MADE_ONE"], ['OKAY or "x"', 'L["Nope"]'])
            mod = Path(d) / "UADD_Made"
            mod.mkdir()
            (mod / "M.lua").write_text('U.Popups.Register("made", { names = { MADE_ONE = true }, prefix = "made_t" })\n',
                                       encoding="utf-8")
            names, prefixes = registered(mod)
            self.assertEqual(problems(dialogs(top, "Made"), names, prefixes), ["Made/a.lua:n: YES"])
            (mod / "M.lua").write_text('U.Popups.Register("made", { names = { MADE_ONE = true } })\n', encoding="utf-8")
            names, prefixes = registered(mod)
            self.assertIn("Made:MADE_TWO: CANCEL", problems(dialogs(top, "Made"), names, prefixes))


if __name__ == "__main__":
    for module, folder, top in installed_modules():
        if top is None:
            print(f"{module}: {folder} not installed")
            continue
        names, prefixes = registered(ROOT / module)
        for k, n, v in dialogs(top, folder):
            state = "registered" if covered(n, names, prefixes) else "ALLOW" if k in ALLOW else "MISSING"
            print(f"{module}: {k}: {', '.join(v)}: {state}")
