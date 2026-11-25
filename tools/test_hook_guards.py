"""Fails when module code hooks a game-wide path itself, past the core guards (docs/LESSONS3.md lesson 35), or puts a
text hook under U.Safe (lesson 19: tools/hook_scan.py, which also holds the token helpers).

Every chat line, print, CreateFrame and CreateFontString of the game (a BG makes hundreds a second) goes through one
core hook each: U.ChatHook (UADD/Lines.lua), U.PrintHook (UADD/Print.lua), U.OnNewFrame / U.OnNewFontString
(UADD/Widgets.lua). They test cheaply first and run each module's handler under U.SafeCall, so an error gives back
the line or frame as it was. A module (a file a UADD_*/*.toc loads) may not:
  - assign a chat frame's AddMessage (x.AddMessage = ..., rawset(x, "AddMessage", ...));
  - name setprinthandler at all (also rawget(_G, "setprinthandler")): only the core's handler is off in an instance;
  - hooksecurefunc "CreateFrame" (also through pcall), or a "CreateFontString" method (a widget kind's methods);
  - in a chat handler (U.ChatHook's line and maybe, U.PrintHook's line, a Chat.lua's Line) or a SetText hook, put its
    text through a string op (text:sub, ==, ~=, #, .., sub(text)) before U.Plain: a BG's secret lines throw on one.

python3 -m unittest discover -s tools -p 'test_*.py'
python3 tools/test_hook_guards.py          (lists every hit: file:line: what)
"""
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import luatok  # noqa: E402
from hook_scan import chain_end, function_defs, safe_hits_in_text, top_strings  # noqa: E402
import test_no_editbox  # noqa: E402

CALLERS = {"pcall", "xpcall", "securecall"}
WIDE = {"CreateFrame": "hooksecurefunc(\"CreateFrame\"): use U.OnNewFrame",
        "CreateFontString": "a CreateFontString hook: use U.OnNewFontString"}


def files():
    """Module files (not the core UADD/ folder) that a UADD_*/*.toc loads."""
    return [p for p in test_no_editbox.files() if p.split("/", 1)[0].startswith("UADD_")]


def hits_in_text(path, text):
    """[(path, line, what)] for each game-wide hook in Lua source text."""
    toks = list(luatok.tokens(text))
    n = len(toks)
    sym = lambda j, s: 0 <= j < n and toks[j][0] == luatok.SYM and toks[j][1] == s  # noqa: E731
    found = []
    for i, (kind, value, line) in enumerate(toks):
        if kind not in (luatok.NAME, luatok.STR):
            continue
        if value == "setprinthandler":                     # a call, or a lookup as rawget(_G, "setprinthandler")
            found.append((path, line, "setprinthandler: use U.PrintHook"))
        elif kind != luatok.NAME:
            continue
        elif value == "AddMessage" and sym(i - 1, ".") and sym(i + 1, "=") and not sym(i + 2, "="):
            found.append((path, line, "AddMessage replaced: use U.ChatHook"))
        elif value == "rawset" and sym(i + 1, "(") and "AddMessage" in top_strings(toks, i + 2):
            found.append((path, line, "AddMessage replaced: use U.ChatHook"))
        elif value == "hooksecurefunc" and not sym(i - 1, ".") and not sym(i - 1, ":"):
            if sym(i + 1, "("):
                start = i + 2
            elif sym(i + 1, ",") and sym(i - 1, "(") and i >= 2 and toks[i - 2][1] in CALLERS:
                start = i + 2
            else:
                continue
            for s in top_strings(toks, start):
                if s in WIDE:
                    found.append((path, line, WIDE[s]))
                    break
    return found


def _targets(path, toks, defs):
    """[(function name or def index, which param holds the text, line)]: the chat handlers (U.ChatHook's line and
    maybe, a Chat.lua's Line) and the SetText hooks (hooksecurefunc(x, "SetText", F), also through U.Safe(key, F)
    or function(f, t) U.SafeCall(F, f, t) end)."""
    out, n = [], len(toks)
    if path.endswith("/Chat.lua"):
        out += [(d[0], 0, toks[i][2]) for i, d in defs.items() if d[0] == "Line"]
    for i, (kind, value, line) in enumerate(toks):
        if kind == luatok.NAME and value in ("ChatHook", "PrintHook") and i + 2 < n and toks[i + 2][1] == "{":
            depth, j = 0, i + 2
            while j < n:
                depth += toks[j][1] in "({[" and toks[j][0] == luatok.SYM
                depth -= toks[j][1] in ")}]" and toks[j][0] == luatok.SYM
                if depth == 0:
                    break
                if depth == 1 and toks[j][1] in ("line", "maybe") and toks[j + 1][1] == "=":
                    out.append((j + 2 if toks[j + 2][1] == "function" else toks[j + 2][1], 0, toks[j][2]))
                j += 1
        if not (kind == luatok.NAME and value == "hooksecurefunc" and "SetText" in top_strings(toks, i + 2)):
            continue
        j = i + 2
        while j < n and not (toks[j][0] == luatok.STR and toks[j][1] == "SetText"):
            j += 1
        j += 2                                             # past "SetText" and its comma
        if j < n and toks[j][1] == "function":
            d = defs.get(j)
            text = d and len(d[1]) > 1 and d[1][1]
            for k in range((d[2] if d else n), (d[3] if d else n)):
                if text and toks[k][1] == "SafeCall" and toks[k + 1][1] == "(":
                    f, after = chain_end(toks, k + 2)
                    args = [t[1] for t in toks[after:d[3]] if t[0] == luatok.NAME]
                    if f and text in args:
                        out.append((f, args.index(text), line))
                    break
        else:
            f, after = chain_end(toks, j)
            if f == "Safe" and toks[after][1] == "(":
                k = after + 1
                while k < n and toks[k][1] != ",":
                    k += 1
                f, _ = chain_end(toks, k + 1)
            if f:
                out.append((f, 1, line))
    return out


def plain_hits_in_text(path, text):
    """[(path, line, what)]: a chat handler or SetText hook that uses its text before U.Plain (lesson 35)."""
    toks = list(luatok.tokens(text))
    defs = function_defs(toks)
    byname = {d[0]: d for d in defs.values() if d[0]}
    found = []
    for target, at, line in _targets(path, toks, defs):
        d = defs.get(target) if isinstance(target, int) else byname.get(target)
        if not d or len(d[1]) <= at:
            continue
        p = d[1][at]
        for k in range(d[2], d[3]):
            if toks[k][0] != luatok.NAME or toks[k][1] != p or toks[k - 1][1] in (".", ":"):
                continue
            if _plain_at(toks, k):
                break
            if _string_op_at(toks, k):
                found.append((path, toks[k][2], f"{d[0] or 'a handler'}: {p} used before U.Plain"))
                break
    return sorted(set(found))


def _plain_at(toks, k):
    """toks[k] (the text) goes into U.Plain here: Plain(text), text = U.Plain(text), a, text = U.Plain(a), ..."""
    if toks[k - 1][1] == "(" and toks[k - 2][1] == "Plain":
        return True
    j = k + 1
    while j < len(toks) and j < k + 8 and (toks[j][1] == "," or toks[j][0] == luatok.NAME):
        j += 1                                             # past the other names of a multiple assignment
    return toks[j][1] == "=" and toks[j + 1][1] != "=" and "Plain" in [t[1] for t in toks[j + 1:j + 5]]


STRING_FNS = {"sub", "find", "match", "gmatch", "gsub", "byte", "len", "lower", "upper", "format", "rep"}


def _string_op_at(toks, k):
    """toks[k] (the text) meets a string op here: text:sub(...), text == x, x ~= text, #text, sub(text, ...)."""
    nxt, nxt2, prev, prev2 = toks[k + 1][1], toks[k + 2][1], toks[k - 1][1], toks[k - 2][1]
    if nxt == ":" or (nxt, nxt2) in ((".", "."), ("=", "="), ("~", "=")):
        return True
    if prev == "#" or (prev == "=" and prev2 in "=~") or (prev == "." and prev2 == "."):
        return True
    return prev == "(" and prev2 in STRING_FNS


def hits():
    found = []
    for path in files():
        full = os.path.join(REPO, path)
        if os.path.isfile(full):
            with open(full, encoding="utf-8", errors="replace") as f:
                text = f.read()
            found += hits_in_text(path, text) + plain_hits_in_text(path, text)
    return found


# Text hooks that may stay under U.Safe: path -> why (none today).
SAFE_OK = {}


def safe_hits():
    found = []
    for path in files():
        with open(os.path.join(REPO, path), encoding="utf-8", errors="replace") as f:
            found += safe_hits_in_text(path, f.read())
    return found


class HookGuards(unittest.TestCase):
    def test_no_text_hook_under_safe(self):
        found = safe_hits()
        bad = [f"{p}:{n}: {w} (lesson 19)" for p, n, w in found if p not in SAFE_OK]
        self.assertEqual(bad, [], "\n".join(bad))
        self.assertEqual(sorted(set(SAFE_OK) - {p for p, _, _ in found}), [], "SAFE_OK entries that hit nothing")

    def test_catches_a_text_hook_under_safe(self):
        src = ('local Late = U.Safe("x", function(f) Changed(f) end)\n'
               'ns.Put = UADD.Safe("x", Put)\n'
               'local function Safe(fn) return U.Safe("x", fn) end\n'
               'local function Guard(fn) return function(...) local ok = pcall(fn, ...) end end\n'
               'local function Wrap(fs) if on then Late(fs) end end\n'
               'local function Good(fs) U.SafeCall(Changed, fs) end\n'
               'f:HookEvent("OnTextChanged", Late)\n'                                           # 7
               'f:HookEvent("OnFormattedTextChanged", U.Safe("x", Changed))\n'                  # 8
               'hooksecurefunc(fs, "SetText", U.Safe("x", Put))\n'                              # 9
               'hooksecurefunc(fs, "SetFormattedText", ns.Put)\n'                               # 10
               'pcall(hooksecurefunc, fs, "SetText", Late)\n'                                   # 11
               'hooksecurefunc(fs, "SetText", function(self, t) if t then Late(self, t) end end)\n'  # 12
               'hooksecurefunc(fs, "SetText", Wrap)\n'                                          # 13
               'hooksecurefunc(fs, "SetText", Safe(Put))\n'                                     # 14
               'for _, m in ipairs({ "Enable", "SetText" }) do hooksecurefunc(b, m, Late) end\n'  # 15
               'hooksecurefunc(fs, "SetText", Guard(Put))\n'
               'hooksecurefunc(fs, "SetText", Good)\n'
               'hooksecurefunc(fs, "SetText", function(f, t) U.SafeCall(Put, f, t) end)\n'
               'f:HookEvent("OnTextChanged", Guard(Put))\n'
               'f:HookEvent("OnShow", Late)\n'
               'hooksecurefunc(o, "SetFont", U.Safe("x", Refit))\n'                              # 21
               'hooksecurefunc("CloseAll", Late)\n'
               '-- hooksecurefunc(fs, "SetText", U.Safe("x", Put)) in a comment\n')
        self.assertEqual([n for _, n, _ in safe_hits_in_text("UADD_X/Screen.lua", src)], [*range(7, 16), 21])

    def test_no_module_hooks_a_game_wide_path(self):
        found = hits()
        self.assertEqual(found, [], "\n".join(f"{p}:{n}: {w} (lesson 35)" for p, n, w in found))

    def test_catches_each_shape(self):
        src = ('DEFAULT_CHAT_FRAME.AddMessage = Mine\n'                       # 1
               'rawset(f, "AddMessage", Mine)\n'                              # 2
               'hooksecurefunc("CreateFrame", OnNew)\n'                       # 3
               'pcall(hooksecurefunc, "CreateFrame", OnNew)\n'                # 4
               'hooksecurefunc(t, "CreateFontString", OnFont)\n'              # 5
               "hooksecurefunc(getmetatable(f).__index, 'CreateFontString', F)\n"  # 6
               'if f.AddMessage == x then end\n'
               'hooksecurefunc(fs, "SetText", function() U.SafeCall(F) end)\n'
               'U.OnNewFrame(OnNew)\n'
               '-- hooksecurefunc("CreateFrame", F) in a comment\n'
               'local s = "hooksecurefunc(\\"CreateFrame\\")"\n'
               'setprinthandler(Mine)\n'                                     # 12
               'local get, set = getprinthandler, rawget(_G, "setprinthandler")\n'  # 13
               'pcall(setprinthandler, had)\n'                               # 14
               'local h = UADD.PrintHook({ line = Line })\n'
               '-- setprinthandler(x) in a comment\n')
        self.assertEqual([n for _, n, _ in hits_in_text("UADD_X/Screen.lua", src)], [1, 2, 3, 4, 5, 6, 12, 13, 14])

    def test_catches_a_string_op_before_plain(self):
        src = ('local function Line(msg)\n'
               '    if not ok or msg:sub(1, 3) ~= P then return nil end\n'           # 2: flagged
               'end\n'
               'local function Good(msg)\n'
               '    if type(msg) ~= "string" or not U.Plain(msg) then return end\n'
               '    return msg:sub(2)\n'
               'end\n'
               'local h = UADD.ChatHook({ marks = { P }, line = Line, maybe = function(t) return #t > 3 end })\n'  # 8
               'local g = UADD.ChatHook({ line = Good })\n'
               'function A.On(fs, text)\n'
               '    if A.busy then return end\n'
               '    if text == A.en then return end\n'                                # 12: flagged
               'end\n'
               'function A.Ok(fs, left, right)\n'
               '    left, right = U.Plain(left), U.Plain(right)\n'
               '    return left and left:find("x")\n'
               'end\n'
               'local function Keep(fs, text) raw[fs] = type(text) == "string" and text end\n'
               'hooksecurefunc(fs, "SetText", function(f, t) U.SafeCall(A.On, f, t) end)\n'
               'hooksecurefunc(fs, "SetText", function(f, t) U.SafeCall(A.Ok, f, t) end)\n'
               'hooksecurefunc(fs, "SetText", U.Safe("k", Keep))\n'
               'hooksecurefunc(fs, "SetText", function(self) Walk(self) end)\n'
               'local p = UADD.PrintHook({ line = function(t) return t:sub(2) end })\n')         # 23: flagged
        self.assertEqual([n for _, n, _ in plain_hits_in_text("UADD_X/Chat.lua", src)], [2, 8, 12, 23])
        self.assertEqual([n for _, n, _ in plain_hits_in_text("UADD_X/Other.lua", src.replace("Line", "Lime"))],
                         [2, 8, 12, 23])

    def test_reads_the_modules_not_the_core(self):
        fs = files()
        for want in ("UADD_Attune/Screen.lua", "UADD_Mastercraft/Find.lua", "UADD_LayerSwap/Chat.lua"):
            self.assertIn(want, fs)
        self.assertNotIn("UADD/Lines.lua", fs)
        self.assertNotIn("UADD/Widgets.lua", fs)
        self.assertNotIn("UADD/Print.lua", fs)
        self.assertIn("UADD_Auctionator/Chat.lua", fs)


if __name__ == "__main__":
    for p, n, w in hits() + safe_hits():
        print(f"{p}:{n}: {w}")
