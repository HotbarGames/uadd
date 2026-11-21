"""LiteMount statements that glue one of L's words to a game global (docs/LESSONS2.md, lesson 15, LiteMount).

LiteMount builds some lines from a game global and one of L's words: "%s: %s" with TOTAL and L.LM_USABLE, CHAT
.. ' + ' .. L.LM_ON_SCREEN_DISPLAY. The globals are English on Forever, so our word there makes a half line.
This test reads the installed LiteMount's .lua (not Libs/ or Localization.lua), splits it into statements (a
call or a concatenation can span lines), and for each statement that uses both an L key (L.x, or L["x"]) and a
game global (an ALL_CAPS name that LiteMount does not define, used as a value, not as an object), wants the key
in UADD_LiteMount/Locale.lua's Lc.WITH_GLOBAL (naming each such global), Lc.GLUED (same), Lc.NEVER, or in ALLOW
below with a reason. It also pins the Mounts filter menu (UI/MountsFilter.lua): each L key there must be one the
module switches in the menu (FILTER in UADD_LiteMount/Copies.lua), gated in WITH_GLOBAL, or in FILTER_LEFT with
a reason; a FILTER word the menu no longer uses fails too. It skips, with a message, when LiteMount is not
installed ($UADD_ADDONS_DIR or the WoW _forever_ folder, tools/copy_scan.py).

    python3 -m unittest tools.test_litemount_glue
"""
import os
import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import copy_scan  # noqa: E402
import luatok as T  # noqa: E402

MODULE = HERE.parent / "UADD_LiteMount"
# key: why a statement with it and a game global needs no gate
ALLOW = {
    "LM_MOUNTSPECIAL_TIMER": "its slot holds an emote command (EMOTE171_CMD1), a free slot (Lc.FREE)",
    "Warband": "only a fallback (ACCOUNT_QUEST_LABEL or L[...]), not glued; not an LM_ key, so never written",
}
# an L key of UI/MountsFilter.lua the module leaves as it is in the menu: why
FILTER_LEFT = {}

KEYWORDS = {"local", "function", "return", "if", "then", "else", "elseif", "end", "do", "while", "for", "repeat",
            "until", "break", "in", "goto"}
OPS = {"and", "or", "not"}
VALUE_END = {")", "]", "}"}
OPEN, CLOSE = {"(": ")", "[": "]", "{": "}"}, {")", "]", "}"}


def root():
    return Path(copy_scan.addons_dir()) / "LiteMount"


def lua_files(top):
    for p in sorted(top.rglob("*.lua")):
        rel = p.relative_to(top).as_posix()
        if not rel.startswith("Libs/") and not rel.startswith("Locali"):
            yield rel, p.read_text("utf-8", "replace")


def statements(text):
    """Lists of tokens, one per statement: split at keywords, at ';', at a ',' right inside a table
    constructor, and where a value ends and a new name starts (`f(x) g(y)`). and/or/not join. Each token is
    (kind, value, line, how many brackets are open before it)."""
    out, cur, stack, prev = [], [], [], None
    for kind, val, line in T.tokens(text):
        cut, depth = False, len(stack)
        if kind == T.NAME and val in KEYWORDS:
            cut = True
        elif kind == T.SYM and (val == ";" or (val == "," and stack and stack[-1] == "{")):
            cut = True
        elif kind == T.NAME and val not in OPS and prev is not None:
            pk, pv = prev
            cut = (pk == T.NAME and pv not in OPS and pv not in KEYWORDS) or pk == T.STR or \
                (pk == T.SYM and (pv in VALUE_END or pv == "0"))
        if kind == T.SYM and val in OPEN:
            stack.append(val)
        elif kind == T.SYM and val in CLOSE and stack:
            stack.pop()
        if cut:
            if cur:
                out.append(cur)
            cur = []
            if kind == T.NAME and val in KEYWORDS or kind == T.SYM and val in ",;":
                prev = (kind, val)
                continue
        cur.append((kind, val, line, depth))
        prev = (kind, val)
    if cur:
        out.append(cur)
    return out


def own_names(files):
    """Names LiteMount defines itself: after `local`, a global function's name, and `NAME =` that starts a
    statement outside any bracket (not a table's field)."""
    own = set()
    for _, text in files:
        for st in statements(text):
            if len(st) >= 2 and st[0][0] == T.NAME and st[0][3] == 0 and st[1][1] == "=" and \
                    (len(st) < 3 or st[2][1] != "="):
                own.add(st[0][1])
        toks = list(T.tokens(text))
        for i, (kind, val, _) in enumerate(toks):
            if kind == T.NAME and val in ("local", "function"):
                j = i + 1
                while j < len(toks) and toks[j][0] == T.NAME and toks[j][1] != "function":
                    own.add(toks[j][1])
                    j += 1
                    if j < len(toks) and toks[j][1] == ",":
                        j += 1
                    else:
                        break
    return own


def caps(name):
    return len(name) > 1 and name.upper() == name and name[0].isalpha() and not name.startswith("LM_")


def scan(st, own):
    """(L keys, game globals) one statement uses."""
    keys, globs = [], set()
    for i, (kind, val, _, _) in enumerate(st):
        before = st[i - 1][1] if i else ""
        if before == "." and i > 1 and st[i - 2][1] == ".":
            before = ".."                                    # a concatenation, not a field
        after = st[i + 1][1] if i + 1 < len(st) else ""
        after2 = st[i + 2][1] if i + 2 < len(st) else ""
        if after == "." and after2 == ".":
            after = ".."                                     # a concatenation, not a field
        if kind != T.NAME or before in (".", ":"):
            continue
        if val == "L" and after == "." and i + 2 < len(st) and st[i + 2][0] == T.NAME:
            if not (i + 3 < len(st) and st[i + 3][1] == "=" and (i + 4 >= len(st) or st[i + 4][1] != "=")):
                keys.append(st[i + 2][1])
        elif val == "L" and after == "[" and i + 3 < len(st) and st[i + 2][0] == T.STR and st[i + 3][1] == "]":
            keys.append(st[i + 2][1])
        elif caps(val) and val not in own and after not in (".", ":", "(", "[", "{") and \
                not (after == "=" and after2 != "="):
            globs.add(val)
    return keys, globs


def table_tokens(text, name):
    """The tokens inside `<name> = { ... }` (outer braces left out)."""
    toks = list(T.tokens(text))
    for i in range(len(toks) - 2):
        if toks[i][1] == name and toks[i + 1][1] == "=" and toks[i + 2][1] == "{":
            depth, out = 0, []
            for t in toks[i + 2:]:
                depth += t[1] == "{" if t[0] == T.SYM else 0
                depth -= t[1] == "}" if t[0] == T.SYM else 0
                if depth == 0:
                    return out[1:]
                out.append(t)
    raise AssertionError(f"no table {name}")


def module_rules():
    """(WITH_GLOBAL key -> set of globals, GLUED key -> set of globals, NEVER keys, FILTER keys)."""
    loc = (MODULE / "Locale.lua").read_text("utf-8")
    wg, cur = {}, None
    for kind, val, _ in table_tokens(loc, "WITH_GLOBAL"):
        if kind == T.NAME:
            cur = val
            wg[cur] = set()
        elif kind == T.STR and cur:
            wg[cur].add(val)
    glued, strs = {}, [v for k, v, _ in table_tokens(loc, "GLUED") if k == T.STR]
    for g, _, k in zip(strs[0::3], strs[1::3], strs[2::3]):
        glued.setdefault(k, set()).add(g)
    never, toks = set(), table_tokens(loc, "NEVER")
    for i, (kind, val, _) in enumerate(toks):
        if kind == T.NAME and i + 1 < len(toks) and toks[i + 1][1] == "=":
            never.add(val)
    cop = (MODULE / "Copies.lua").read_text("utf-8")
    filt = {v for k, v, _ in table_tokens(cop, "FILTER") if k == T.STR}
    return wg, glued, never, filt


def problems(files, wg, glued, never, allow):
    """Each statement with an L key and a game global the key's gate does not name."""
    own, out, used = own_names(files), [], set()
    for rel, text in files:
        for st in statements(text):
            keys, globs = scan(st, own)
            if not keys or not globs:
                continue
            for k in keys:
                gate = wg.get(k, glued.get(k))
                if k in allow:
                    used.add(k)
                elif k in never:
                    continue
                elif gate is None or not globs <= gate:
                    out.append(f"{rel}:{st[0][2]}: L.{k} with {sorted(globs)} (gate: {sorted(gate or [])})")
    out += [f"ALLOW.{k}: no such statement now" for k in allow if k not in used]
    return out


def filter_keys(text):
    return {k for st in statements(text) for k in scan(st, set())[0]}


class Synthetic(unittest.TestCase):
    """The scanner on made-up code, so it works without LiteMount too."""
    CODE = ("local WORD = 'x'\nlocal t = { text = L.LM_A, other = SOME_GLOBAL }\n"
            "f(string.format('%s: %s',\n  TOTAL,\n  L.LM_B\n)) g(L.LM_C, WHITE_FONT_COLOR:Wrap(n), WORD)\n"
            "h(CHAT .. ' + ' .. L['LM_D']) L.LM_E = NONE\n")

    def test_finds_a_call_over_lines_and_a_literal_key(self):
        got = problems([("x.lua", self.CODE)], {}, {}, set(), {})
        self.assertEqual([p.split(": L.")[1].split(" with")[0] for p in got], ["LM_B", "LM_D"], got)

    def test_gate_must_name_the_global(self):
        got = problems([("x.lua", self.CODE)], {"LM_B": {"DEFAULT"}}, {"LM_D": {"CHAT"}}, set(), {})
        self.assertEqual(len(got), 1, got)
        self.assertIn("L.LM_B with ['TOTAL']", got[0])

    def test_stale_allow_fails(self):
        got = problems([("x.lua", self.CODE)], {"LM_B": {"TOTAL"}}, {"LM_D": {"CHAT"}}, set(), {"LM_Z": "x"})
        self.assertEqual(got, ["ALLOW.LM_Z: no such statement now"])


@unittest.skipUnless((root() / "Localization.lua").is_file(), "LiteMount is not installed: glue scan skipped")
class Installed(unittest.TestCase):
    def setUp(self):
        self.files = list(lua_files(root()))
        self.wg, self.glued, self.never, self.filt = module_rules()

    def test_each_glued_key_is_gated(self):
        got = problems(self.files, self.wg, self.glued, self.never, ALLOW)
        self.assertEqual(got, [], "\n".join(got))

    def test_finds_the_counts_without_their_gate(self):
        wg = {k: v for k, v in self.wg.items() if k != "LM_USABLE"}
        got = problems(self.files, wg, self.glued, self.never, ALLOW)
        self.assertTrue(any("L.LM_USABLE with ['COLLECTED', 'TOTAL']" in p for p in got), got)

    def test_filter_menu_keys_all_known(self):
        p = root() / "UI" / "MountsFilter.lua"
        keys = filter_keys(p.read_text("utf-8", "replace"))
        miss = sorted(k for k in keys if k not in self.filt and k not in self.wg and k not in FILTER_LEFT)
        stale = sorted(k for k in self.filt | set(FILTER_LEFT) if k not in keys)
        self.assertTrue(keys, "no L key found in UI/MountsFilter.lua")
        self.assertEqual((miss, stale), ([], []), f"unknown to the module: {miss}; no longer in the menu: {stale}")


if __name__ == "__main__":
    unittest.main()
