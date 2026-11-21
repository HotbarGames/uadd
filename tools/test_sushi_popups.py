"""Bagnon's and Scrap's own Sushi-3.2 pop-ups: each word they show is one the module handles (docs/LESSONS3.md).

Both addons open pop-ups through the shared Sushi-3.2 library and put the game's globals (OKAY, CANCEL, YES, ...)
on the buttons, and L's words or a game global in the body. ClassicUA alone leaves those globals English, so the
core helper UADD/SushiPopups.lua shows our word on them (WORDS), and flips a body that is one whole L text. This
test reads the installed addons (their own .lua, not libs/), finds every Sushi pop-up they open (`Popup {`,
`Popup(`, `Popup:New`, `Popup:Toggle`, `Popup:External`), and reads each button and body value. It fails when one
shows a game global or an L word the helper does not handle (a global not in WORDS, a body built with format or
taken from the game), unless that place is in ALLOW with a reason. An ALLOW entry that no pop-up needs any more
fails too. That part skips, with a message, when an addon is not installed ($UADD_ADDONS_DIR or the WoW
_forever_ folder, tools/copy_scan.py). Without the addons it still wants each module in MODULES to register with
the core helper (Register and Sync with its own key), its OWNERS to name the folders the pop-ups come from, no
module to keep its own copy of the Sushi pop-up code, and no other module to register unlisted.

    python3 -m unittest tools.test_sushi_popups
"""
import re
import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import copy_scan  # noqa: E402

ROOT = HERE.parent
MODULES = {"UADD_Bagnon": "BagBrother", "UADD_Scrap": "Scrap"}   # module -> the folder that must be installed
# "<folder>/<file>:<slot>" -> why the module leaves that value as the addon built it (a known gap)
ALLOW = {
    "BagBrother/core/classes/offlineSelector.lua:text": "a character's name in a slot: L's words are ours already "
        "(the line is whole Ukrainian on), but the hold key cannot give back the English of a built line",
    "BagBrother/core/features/slashCommands.lua:text": "the addon's name in a slot: as offlineSelector",
    "BagBrother/frames/vault/vault.lua:text": "the vault price in a slot (retail only): as offlineSelector",
    "BagBrother/frames/guild/guildTab.lua:text": "a game global (the guild bank tab question): UALL Forever's to "
        "translate, never ours",
    "BagBrother/frames/guild/guildMoney.lua:text": "game globals (guild bank deposit and withdraw): as guildTab",
    "BagBrother/frames/bank/accountMoney.lua:text": "game globals (warband bank money, retail only): as guildTab",
    "BagBrother/config/panels/infoPanels.lua:external": "Sushi's own link text (GPL library, no word of ours); "
        "its OKAY button is ours",
    "BagBrother/config/panels/ruleEdit.lua:external": "as infoPanels",
    "Scrap/addons/config/options.lua:external": "as infoPanels",
}
SLOTS = ("button1", "button2", "button3", "text")
CALL = re.compile(r"Popup\s*(?::\s*(New|Toggle|External)\s*)?[({]")


def _strip(code):
    """The code with comments and string bodies blanked (same length), so brackets inside them do not count."""
    out, i, n = [], 0, len(code)
    while i < n:
        if code.startswith("--", i):
            j = code.find("\n", i)
            j = n if j < 0 else j
            out.append(" " * (j - i))
            i = j
        elif code[i] in "\"'":
            q, j = code[i], i + 1
            while j < n and code[j] != q and code[j] != "\n":
                j += 2 if code[j] == "\\" else 1
            out.append(q + "_" * (min(j, n) - i - 1) + (q if j < n else ""))
            i = j + 1
        else:
            out.append(code[i])
            i += 1
    return "".join(out)[:n]


def _close(s, i):
    """Index just past the bracket that closes the one at s[i]."""
    pairs, depth = {"(": ")", "{": "}", "[": "]"}, []
    for j in range(i, len(s)):
        c = s[j]
        if c in pairs:
            depth.append(pairs[c])
        elif depth and c == depth[-1]:
            depth.pop()
            if not depth:
                return j + 1
    return len(s)


def _value(s, i):
    """The value expression starting at s[i], up to a comma or closing bracket at its own depth."""
    depth, j = 0, i
    while j < len(s):
        c = s[j]
        if c in "({[":
            depth += 1
        elif c in ")}]":
            if depth == 0:
                break
            depth -= 1
        elif c in ",;\n" and depth == 0:
            break
        j += 1
    return s[i:j].strip()


def popups(top, folder):
    """[(place "<folder>/<file>", kind, {slot: value})] for every Sushi pop-up the folder's own code opens."""
    out = []
    base = Path(top) / folder
    for path in sorted(base.rglob("*.lua")):
        rel = path.relative_to(base).as_posix()
        if re.search(r"(^|/)libs?/", rel, re.I):
            continue
        code = _strip(path.read_text(encoding="utf-8", errors="replace"))
        for m in CALL.finditer(code):
            body = code[m.end() - 1:_close(code, m.end() - 1)]
            kind = (m.group(1) or "new").lower()
            vals = {}
            for s in re.finditer(r"\b(%s)\s*=\s*" % "|".join(SLOTS), body):
                vals[s.group(1)] = _value(body, s.end())
            out.append((f"{folder}/{rel}", kind, vals))
    return out


CORE = ROOT / "UADD" / "SushiPopups.lua"


def _words():
    code = CORE.read_text(encoding="utf-8")
    m = re.search(r"local WORDS = \{(.*?)\}", code, re.S)
    return set(re.findall(r"\b([A-Z][A-Z_]+)\s*=", m.group(1))) if m else set()


def _key(module):
    """The module's /uadd key, from its U.RegisterModule call."""
    m = re.search(r'U\.RegisterModule\("(\w+)"', (ROOT / module / "Module.lua").read_text(encoding="utf-8"))
    return m.group(1) if m else None


def _calls(module, fn):
    """Keys the module's Lua files pass to U.SushiPopups.<fn> (as U.SafeCall(U.SushiPopups.fn, "key") or a call)."""
    out = set()
    for p in sorted((ROOT / module).rglob("*.lua")):
        code = p.read_text(encoding="utf-8")
        out |= set(re.findall(r'U\.SushiPopups\.%s\s*(?:,|\()\s*"(\w+)"' % fn, code))
    return out


def _owners(module):
    code = (ROOT / module / "Module.lua").read_text(encoding="utf-8")
    m = re.search(r"local OWNERS = \{(.*?)\}", code, re.S)
    return set(re.findall(r"\b(\w+)\s*=\s*true", m.group(1))) if m else set()


L_WORD = re.compile(r"^L(\.\w+|\[\s*['\"][^'\"]+['\"]\s*\])$")
GLOBAL = re.compile(r"^[A-Z][A-Z0-9_]+$")


def problems(found, words):
    """(problems, places ALLOW was needed for) for one module's pop-ups."""
    bad, used = [], set()
    for place, kind, vals in found:
        if kind == "external":
            key = place + ":external"
            used.add(key)
            if key not in ALLOW:
                bad.append(f"{place}: a link pop-up (Sushi's own body text): handle it or ALLOW {key!r}")
            continue
        for slot, v in vals.items():
            if L_WORD.match(v):
                continue                               # one whole L text: ours, flipped both ways
            if GLOBAL.match(v) and slot != "text" and v in words:
                continue                               # a button global the module shows our word on
            if not (GLOBAL.search(v.split("(")[0]) or "L." in v or "L[" in v or GLOBAL.match(v)):
                continue                               # neither a game global nor an L word (a local, a value)
            key = f"{place}:{slot}"
            used.add(key)
            if key not in ALLOW:
                bad.append(f"{place}: {slot} = {v} is not handled by UADD/SushiPopups.lua: add it to WORDS, "
                           f"or ALLOW {key!r}")
    return bad, used


class SushiPopups(unittest.TestCase):
    def test_modules_register_with_the_core_helper(self):
        """Only the core helper hooks Sushi's pop-ups; each module registers, syncs and names its folders."""
        self.assertIn("SushiPopups.lua", (ROOT / "UADD" / "UADD.toc").read_text(encoding="utf-8").split())
        for module, folder in MODULES.items():
            key = _key(module)
            self.assertTrue(key, f"{module}/Module.lua: no U.RegisterModule key")
            self.assertEqual(_calls(module, "Register"), {key}, f"{module}: U.SushiPopups.Register({key!r}, ...)")
            self.assertEqual(_calls(module, "Sync"), {key}, f"{module}: U.SushiPopups.Sync({key!r}) on on/off/hold")
            owners = _owners(module)
            self.assertIn(folder, owners, f"{module}: OWNERS must name {folder}")
            self.assertTrue(all(re.match(r"^\w+$", o) and not o.startswith("UADD") for o in owners), owners)
        for d in sorted(ROOT.glob("UADD_*")):
            if (d / "Popups.lua").exists():
                code = (d / "Popups.lua").read_text(encoding="utf-8")
                self.assertNotIn("Sushi-3.2", code, f"{d.name}/Popups.lua: Sushi pop-ups go through UADD/SushiPopups.lua")
            if d.is_dir() and d.name not in MODULES and (d / "Module.lua").exists():
                self.assertEqual(_calls(d.name, "Register"), set(),
                                 f"{d.name} registers Sushi pop-ups: add it to MODULES here")

    def test_every_popup_handled_or_allowed(self):
        top = copy_scan.addons_dir()
        used, seen = set(), set()
        for module, folder in MODULES.items():
            if not top or not (Path(top) / folder / f"{folder}.toc").exists() and not (Path(top) / folder).is_dir():
                self.skipTest(f"{folder} is not installed")
            words, owners = _words(), _owners(module)
            self.assertTrue(words, "UADD/SushiPopups.lua: no WORDS table found")
            found = []
            for f in sorted(owners):
                if (Path(top) / f).is_dir():
                    found += popups(top, f)
            self.assertTrue(found, f"{module}: no Sushi pop-up found in {sorted(owners)} (the search is broken?)")
            seen |= {p.split("/")[0] for p, _, _ in found}
            bad, u = problems(found, words)
            used |= u
            self.assertEqual(bad, [], "\n" + "\n".join(bad))
            self.assertIn(folder, owners, f"{module}: OWNERS must name {folder}")
        stale = sorted(k for k in ALLOW if k.split("/")[0] in seen and k not in used)
        self.assertEqual(stale, [], f"ALLOW entries no pop-up needs any more: {stale}")

    def test_finder_reads_a_made_up_popup(self):
        import tempfile
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "X" / "a.lua"
            p.parent.mkdir()
            p.write_text("Sushi.Popup { id = 'a', text = format(L.Q, n), button1 = OKAY, button2 = UNKNOWN_G,\n"
                         "  OnAccept = function() end }\n-- Sushi.Popup { button1 = NO }\n"
                         "LibStub('Sushi-3.2').Popup:External('x.y')\n", encoding="utf-8")
            (Path(d) / "X" / "libs").mkdir()
            (Path(d) / "X" / "libs" / "b.lua").write_text("Popup:New { button1 = ZZZ }", encoding="utf-8")
            found = popups(d, "X")
            self.assertEqual([(k, v) for _, k, v in found], [
                ("new", {"text": "format(L.Q, n)", "button1": "OKAY", "button2": "UNKNOWN_G"}), ("external", {})])
            bad, _ = problems(found, {"OKAY"})
            self.assertEqual(len(bad), 3, bad)         # the built body, the unknown global, the link pop-up


if __name__ == "__main__":
    unittest.main()
