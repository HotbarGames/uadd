"""Our code touches the game's shared state only in a few known places (docs/LESSONS2.md lesson 19).

Two bugs broke the whole game: a throwaway EditBox took the keyboard (lesson 16), and a tooltip line put back
with SetFont lost its font family, so its Cyrillic showed boxes (lesson 18). Both came from a risky call in a
module file. This check reads every .lua file a UADD*/*.toc loads and lists each risky call:

- set font      SetFont on anything (it pins one file; a game line loses its font family)
- font object   a method that changes a font object (SetFont, SetTextColor, ...) on a global *Font* name:
                GameFontNormal, GameTooltipText, ... are shared by the whole game. Never allowed.
- put object    SetFontObject with an object that is not a game global by its name, nil or a string (a saved one,
                a local, a field): only U.SetFontObject (UADD/FontObject.lua) checks it may go back. An edit box's
                GetFontObject is its own nameless record; put back, it inherits from itself and the game dies
                (docs/LESSONS4.md lesson 47)
- new font      CreateFont: a new global font object
- frame kind    CreateFrame("EditBox") or a kind that is not a string (tools/test_no_editbox.py)
- keyboard      SetFocus, ClearFocus, EnableKeyboard, SetPropagateKeyboardInput, SetAutoFocus
- set script    SetScript on a frame this file did not make (it drops the game's or the addon's own script)
- global write  _G[...] = ..., _G.x = ..., rawset(_G, ...), setglobal(...)
- game field    a field written on, or a function put on, a global table that is not ours (GameTooltip.X = ...)
- settings      SetCVar, SetBinding*, SetOverrideBinding*, SaveBindings, ConsoleExec, EnableAddOn, DisableAddOn
- run code      RunScript, loadstring
- chat replace  x.AddMessage = ... (a chat frame's AddMessage replaced: a bug there loses every chat line)
- walk          :GetRegions() / :GetChildren() with no "Forbidden" test in the 15 lines above (a forbidden frame
                throws, and a walk over the game's frames can reach one)

HELPERS may use them freely: the core helpers made for this. Any other use is in ALLOW (tools/shared_state_allow.py):
(file, kind) -> (how many, why). More uses than that fails (a new one: use a helper), fewer fails too (lower the number). "TODO: move to
helper" marks old uses that should go through a core helper.

python3 -m unittest discover -s tools -p 'test_*.py'
python3 tools/test_shared_state.py        (lists every use: file:line: kind)
"""
import collections
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import luatok  # noqa: E402
import test_no_editbox  # noqa: E402

HELPERS = {
    "UADD/Font.lua": "U.SaveFont / U.FontBack: a line's font object back, never a pinned file",
    "UADD/FontObject.lua": "U.SetFontObject: only an object that may go back (no loop, lesson 47)",
    "UADD/FontReadBack.lua": "U.SetFontSelf: the core's own SetFont, told from an addon's of our file read back (lesson 48)",
    "UADD/Widgets.lua": "U.WidgetMethods: a widget kind's methods, never a new EditBox",
    "UADD/Guard.lua": "the runtime guard: puts broken shared state back",
    "UADD/ButtonFont.lua": "U.ButtonCyr / U.ButtonBack: a button's state objects, our copies on and its own back",
    "UADD/BoxGuard.lua": "the box guard: a text drawn as boxes gets our font again, then the file, else its English",
}

from shared_state_allow import ALLOW  # noqa: E402  (file, kind) -> (how many, why)

FONT_METHODS = {"SetFont", "SetFontObject", "SetTextColor", "SetShadowColor", "SetShadowOffset", "SetSpacing",
                "SetJustifyH", "SetJustifyV", "CopyFontObject", "SetFontHeight", "SetIndentedWordWrap"}
KEYBOARD = {"SetFocus", "ClearFocus", "EnableKeyboard", "SetPropagateKeyboardInput", "SetAutoFocus"}
SETTINGS = {"SetCVar", "SetBinding", "SetBindingClick", "SetBindingSpell", "SetBindingItem", "SetBindingMacro",
            "SetOverrideBinding", "SetOverrideBindingClick", "SetOverrideBindingSpell", "SetOverrideBindingItem",
            "SetOverrideBindingMacro", "ClearOverrideBindings", "SaveBindings", "LoadBindings", "ConsoleExec",
            "EnableAddOn", "DisableAddOn"}
RUN = {"RunScript", "loadstring"}
WALK_NEAR = 15          # a walk is guarded when "Forbidden" (IsForbidden, a Forbidden() helper) is this close above
FONT_GLOBALS = {"GameTooltipText", "GameTooltipHeaderText", "GameTooltipTextSmall", "Tooltip_Med", "Tooltip_Small",
                "ChatFontNormal", "ChatFontSmall", "SystemFont_Med1", "NumberFontNormal"}
OURS = {"UADD", "UADD_DB", "_G", "self"}
LUA = {"and", "break", "do", "else", "elseif", "end", "false", "for", "function", "if", "in", "local", "nil", "not",
       "or", "repeat", "return", "then", "true", "until", "while"}


def files():
    return test_no_editbox.files()


def _locals(toks):
    """Names the file declares (local, function parameters, for loops), and names it binds to CreateFrame."""
    names, made = set(), set()
    n = len(toks)
    for i, (kind, value, _) in enumerate(toks):
        if kind == luatok.NAME and value in ("local", "for"):
            j = i + 1
            if j < n and toks[j][1] == "function":
                j += 1
            while j < n and toks[j][0] == luatok.NAME and toks[j][1] not in LUA:
                names.add(toks[j][1])
                j += 1
                if j < n and toks[j][1] == ",":
                    j += 1
                else:
                    break
        elif kind == luatok.NAME and value == "function":
            j = i + 1
            while j < n and toks[j][1] != "(":
                j += 1
            j += 1
            while j < n and toks[j][1] != ")":
                if toks[j][0] == luatok.NAME:
                    names.add(toks[j][1])
                j += 1
        elif kind == luatok.NAME and i + 2 < n and toks[i + 1][1] == "=" and toks[i + 2][1] == "CreateFrame":
            made.add(value)
    return names, made


def hits_in_text(path, text):
    """[(path, line, kind)] for each risky call in Lua source text (none in a HELPERS file)."""
    if path in HELPERS:
        return []
    toks = list(luatok.tokens(text))
    src_lines = text.split("\n")
    n = len(toks)
    names, made = _locals(toks)

    def t(j):
        return toks[j] if 0 <= j < n else (None, None, 0)

    def is_sym(j, *s):
        return t(j)[0] == luatok.SYM and t(j)[1] in s

    def assign(j):          # toks[j] is "=" and not "=="
        return is_sym(j, "=") and not is_sym(j + 1, "=") and not is_sym(j - 1, "=", "~", "<", ">")

    def global_name(j):
        k, v, _ = t(j)
        return k == luatok.NAME and v not in names and v not in LUA and not is_sym(j - 1, ".", ":")

    found = [(p, line, "frame kind") for p, line, _ in test_no_editbox.hits_in_text(path, text)]
    for i, (kind, value, line) in enumerate(toks):
        if kind != luatok.NAME:
            continue
        method = is_sym(i - 1, ":", ".") and (is_sym(i + 1, "(") or (is_sym(i - 1, ".") and is_sym(i + 1, ",")))
        bare = not is_sym(i - 1, ":", ".") and is_sym(i + 1, "(") and not (t(i - 1)[1] == "function")
        recv = i - 2
        if method and value in FONT_METHODS and global_name(recv) and t(recv)[1][:1].isupper() \
                and ("Font" in t(recv)[1] or t(recv)[1] in FONT_GLOBALS):
            found.append((path, line, "font object"))
        elif method and value == "SetFont":
            found.append((path, line, "set font"))
        if method and value == "SetFontObject" and t(recv)[1] not in ("UADD", "U"):
            a = i + 2 if is_sym(i + 1, "(") else i + 4      # fs:SetFontObject(x) / pcall(fs.SetFontObject, fs, x)
            k, v, _ = t(a)
            named = k == luatok.STR or (k == luatok.NAME and (v == "nil" or (
                v[:1].isupper() and global_name(a) and not is_sym(a + 1, ".", ":", "["))))
            if not named:
                found.append((path, line, "put object"))
        if method and value in KEYBOARD:
            found.append((path, line, "keyboard"))
        if method and value == "SetScript" and not (t(recv)[1] in made and t(recv)[0] == luatok.NAME
                                                    and not is_sym(recv - 1, ".", ":")):
            found.append((path, line, "set script"))
        if is_sym(i - 1, ".") and value == "AddMessage" and assign(i + 1):
            found.append((path, line, "chat replace"))
        if is_sym(i - 1, ":") and is_sym(i + 1, "(") and value in ("GetRegions", "GetChildren") \
                and "Forbidden" not in "\n".join(src_lines[max(0, line - 1 - WALK_NEAR):line]):
            found.append((path, line, "walk"))
        if bare and value == "CreateFont":
            found.append((path, line, "new font"))
        if (bare or method) and value in SETTINGS:
            found.append((path, line, "settings"))
        if bare and value in RUN:
            found.append((path, line, "run code"))
        if value == "_G" and not is_sym(i - 1, ".", ":"):
            if is_sym(i + 1, "["):                       # _G[...] =
                depth, j = 0, i + 1
                while j < n:
                    depth += is_sym(j, "[") - is_sym(j, "]")
                    if depth == 0:
                        break
                    j += 1
                if assign(j + 1):
                    found.append((path, line, "global write"))
            elif is_sym(i + 1, ".") and assign(i + 3):
                found.append((path, line, "global write"))
        if bare and value in ("rawset", "setglobal") and (value == "setglobal" or t(i + 2)[1] == "_G"):
            found.append((path, line, "global write"))
        # NAME = ... at statement level, NAME a global (not in a table constructor, not a field)
        if global_name(i) and value not in OURS and assign(i + 1) and not is_sym(i - 1, "{", ",", ";", "("):
            found.append((path, line, "global write"))
        # GLOBAL.x = ..., GLOBAL[x] = ..., function GLOBAL.x(...) / GLOBAL:x(...)
        if global_name(i) and value not in OURS and value[:1].isupper() and is_sym(i + 1, ".", ":") \
                and t(i + 2)[0] == luatok.NAME and (assign(i + 3) or t(i - 1)[1] == "function"):
            found.append((path, line, "game field"))
        if t(i - 1)[1] == "function" and global_name(i) and not is_sym(i + 1, ".", ":") and is_sym(i + 1, "(") \
                and t(i - 2)[1] != "local":
            found.append((path, line, "global write"))
    return found


def hits():
    found = []
    for path in files():
        full = os.path.join(REPO, path)
        if os.path.isfile(full):
            with open(full, encoding="utf-8", errors="replace") as f:
                found += hits_in_text(path, f.read())
    return found


def problems(found):
    """Lines that say what is wrong: uses over ALLOW, and ALLOW entries with fewer uses or none."""
    count = collections.Counter((p, k) for p, _, k in found)
    where = collections.defaultdict(list)
    for p, line, k in found:
        where[(p, k)].append(line)
    out = []
    for key, got in sorted(count.items()):
        allowed = ALLOW.get(key, (0, ""))[0]
        if key[1] == "font object" or got > allowed:
            lines = ",".join(map(str, where[key]))
            out.append(f"{key[0]}:{lines}: {key[1]} x{got} (allowed {allowed}): use a core helper")
    for key, (allowed, _) in sorted(ALLOW.items()):
        if count.get(key, 0) < allowed:
            out.append(f"{key[0]}: {key[1]} x{count.get(key, 0)}, ALLOW says {allowed}: lower it in ALLOW")
    return out


class SharedState(unittest.TestCase):
    def test_risky_calls_only_where_allowed(self):
        bad = problems(hits())
        self.assertEqual(bad, [], "\n" + "\n".join(bad))

    def test_catches_each_kind(self):
        src = ('fs:SetFont("Fonts\\\\FRIZQT__.TTF", 12, "")\n'          # 1 set font
               'GameTooltipText:SetFont(p, 12, "")\n'                    # 2 font object
               'pcall(GameFontNormal.SetTextColor, GameFontNormal, 1, 1, 1)\n'  # 3 font object
               'local e = CreateFrame("EditBox")\n'                      # 4 frame kind
               'box:SetFocus()\n'                                        # 5 keyboard
               'GameTooltip:SetScript("OnShow", nil)\n'                  # 6 set script
               '_G[name] = "x"\n'                                        # 7 global write
               'GameTooltip.AddLine = function() end\n'                  # 8 game field
               'SetCVar("x", 1)\n'                                       # 9 settings
               'RunScript("x")\n'                                        # 10 run code
               'local f = CreateFont("UADD_X")\n'                        # 11 new font
               'Thing = 1\n'                                             # 12 global write
               'function ChatFrame_OnLoad() end\n'                       # 13 global write
               'ChatFrame1.AddMessage = F\n'                             # 14 chat replace (and game field)
               'for _, c in ipairs({ f:GetChildren() }) do end\n'        # 15 walk
               'if f:IsForbidden() then return end local r = f:GetRegions()\n'  # guarded: fine
               'local w = CreateFrame("Frame") w:SetScript("OnEvent", F)\n'   # ours: fine
               'if _G[name] == x then end\n'                             # a read: fine
               'local t = { a = 1, b = 2 }\n'                            # a table: fine
               'hooksecurefunc(fs, "SetFont", F) local ok = type(gui.SetFocus)\n'  # not calls
               'fs:SetFontObject(GameFontNormal)\n'                      # a FontString's own font: fine
               'pcall(fs.SetFontObject, fs, saved[fs])\n'                # 22 put object
               'fs:SetFontObject(was.object) UADD.SetFontObject(fs, was.object)\n'  # 23 put object; the helper: fine
               '-- GameFontNormal:SetFont() in a comment\n')
        got = [(n, k) for _, n, k in hits_in_text("UADD_X/Screen.lua", src)]
        self.assertEqual(sorted(got), sorted([(1, "set font"), (2, "font object"), (3, "font object"),
                                              (4, "frame kind"), (5, "keyboard"), (6, "set script"),
                                              (7, "global write"), (8, "game field"), (9, "settings"),
                                              (10, "run code"), (11, "new font"), (12, "global write"),
                                              (13, "global write"), (14, "chat replace"), (14, "game field"),
                                              (15, "walk"), (22, "put object"), (23, "put object")]))
        self.assertEqual(hits_in_text("UADD/Guard.lua", src), [])

    def test_a_planted_line_fails(self):
        found = hits() + hits_in_text("UADD_Attune/Fonts.lua", "GameFontNormal:SetFont(p, 12)\nfs:SetFont(p, 1)\n")
        bad = problems(found)
        self.assertTrue(any("font object" in b for b in bad), bad)
        self.assertTrue(any("UADD_Attune/Fonts.lua" in b and "set font" in b for b in bad), bad)

    def test_allow_has_reasons(self):
        for key, (count, why) in ALLOW.items():
            self.assertTrue(count > 0 and len(why) > 10, key)
            self.assertNotEqual(key[1], "font object", key)


if __name__ == "__main__":
    for p, n, k in hits():
        print(f"{p}:{n}: {k}")
    print("\n".join(problems(hits())) or "ok")
