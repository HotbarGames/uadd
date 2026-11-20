"""Fails when our code makes an EditBox, or a frame of a kind it cannot see (docs/LESSONS2.md lesson 16).

A new EditBox is shown with autoFocus on, so it takes the keyboard for good: Enter no longer opens chat.
Mastercraft and What's Training? did this to reach the EditBox method table. It reads the .lua files each
UADD*/*.toc loads and lists every CreateFrame call (also one through pcall or xpcall) whose kind is "EditBox"
or not a string literal (a variable: it may be "EditBox"). The one place allowed is the core helper
UADD.WidgetMethods (UADD/Widgets.lua), which never makes an EditBox. To reach a widget kind's methods,
use that helper.

python3 -m unittest discover -s tools -p 'test_*.py'
python3 tools/test_no_editbox.py          (lists every hit: file:line: what)
"""
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import luatok  # noqa: E402
from test_ukrainian_letters import shipped_lua  # noqa: E402

ALLOWED = {"UADD/Widgets.lua"}      # UADD.WidgetMethods: takes an EditBox's table from the chat edit box
CALLERS = {"pcall", "xpcall", "securecall"}


def files():
    """Repo-relative .lua files that a UADD*/*.toc loads."""
    return [p for p in shipped_lua() if p.split("/", 1)[0].startswith("UADD")]


def hits_in_text(path, text):
    """[(path, line, what)] for each CreateFrame call in Lua source text that may make an EditBox."""
    if path in ALLOWED:
        return []
    toks = list(luatok.tokens(text))
    sym = lambda j, s: 0 <= j < len(toks) and toks[j][0] == luatok.SYM and toks[j][1] == s  # noqa: E731
    found = []
    for i, (kind, value, line) in enumerate(toks):
        if kind != luatok.NAME or value != "CreateFrame" or sym(i - 1, ".") or sym(i - 1, ":"):
            continue
        direct = sym(i + 1, "(")
        passed = sym(i - 1, "(") and i >= 2 and toks[i - 2][0] == luatok.NAME and toks[i - 2][1] in CALLERS \
            and sym(i + 1, ",")
        if not (direct or passed):
            continue                      # not a call (type(CreateFrame), a hook by name)
        arg = toks[i + 2] if i + 2 < len(toks) else (None, None, line)
        if arg[0] != luatok.STR:
            found.append((path, line, "CreateFrame with a kind that is not a string literal"))
        elif arg[1].lower() == "editbox":
            found.append((path, line, 'CreateFrame("EditBox"): it takes the keyboard'))
    return found


def hits():
    found = []
    for path in files():
        full = os.path.join(REPO, path)
        if os.path.isfile(full):
            with open(full, encoding="utf-8", errors="replace") as f:
                found += hits_in_text(path, f.read())
    return found


class NoEditBox(unittest.TestCase):
    def test_no_editbox_made_by_our_code(self):
        found = hits()
        self.assertEqual(found, [], "\n".join(f"{p}:{n}: {w} (use UADD.WidgetMethods)" for p, n, w in found))

    def test_catches_each_shape(self):
        src = ('local a = CreateFrame("EditBox")\n'
               'local ok, f = pcall(CreateFrame, kind)\n'
               'local b = CreateFrame(k, nil, UIParent)\n'
               "local c = CreateFrame('editbox', nil, p)\n"
               'local d = CreateFrame("Frame", nil, UIParent)\n'
               'if type(CreateFrame) == "function" then hooksecurefunc("CreateFrame", F) end\n'
               'local e = pcall(CreateFrame, "Button")\n'
               '-- CreateFrame("EditBox") in a comment\n')
        self.assertEqual([n for _, n, _ in hits_in_text("UADD_X/Screen.lua", src)], [1, 2, 3, 4])
        self.assertEqual(hits_in_text("UADD/Widgets.lua", src), [])

    def test_reads_the_modules(self):
        fs = files()
        for want in ("UADD/Widgets.lua", "UADD_Mastercraft/Screen.lua", "UADD_WhatsTraining/Screen.lua"):
            self.assertIn(want, fs)


if __name__ == "__main__":
    for p, n, w in hits():
        print(f"{p}:{n}: {w}")
