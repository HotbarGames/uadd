"""Lua reading for tools/scan_addon.py: comments and strings masked, tokens with offsets, a walk that knows each
token's brackets (the call it is an argument of, the table key it is the value of) and its function depth.

LuaFile(text).toks is a list of Tok(kind, val, s, e): kind NAME, STR, NUM or SYM; a STR's val is its raw body.
Standard library only.
"""
import bisect
import re
from collections import namedtuple

Tok = namedtuple("Tok", "kind val s e")
NAME, STR, NUM, SYM = "name", "str", "num", "sym"
KEYWORDS = {"and", "break", "do", "else", "elseif", "end", "false", "for", "function", "goto", "if", "in", "local",
            "nil", "not", "or", "repeat", "return", "then", "true", "until", "while"}
CAPS = re.compile(r"[A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+|[A-Z]{2,}[0-9]*")
TOKRE = re.compile(r"(\s+)|([A-Za-z_]\w*)|(0[xX][0-9A-Fa-f.]+|\d[\d.]*(?:[eE][-+]?\d+)?)|(\"[ \n]*\"|'[ \n]*')"
                   r"|(\[(=*)\[[ \n]*\]\6\])|(==|~=|<=|>=|\.\.\.|\.\.|::|//|<<|>>)|(.)", re.S)
CODES = re.compile(r"\|c[0-9A-Fa-fnN][0-9A-Za-z_:]{0,40}?(?=[^0-9A-Za-z_:]|$)|\|c[0-9A-Fa-f]{8}|\|r|\|n|\|T[^|]*\|t"
                   r"|\|A[^|]*\|a|\|H[^|]*\|h|\|h|%[-+ #0-9.]*[sdifxXgq%]|\\[ntr]")


def _long(text, i):
    j = i + 1
    while j < len(text) and text[j] == "=":
        j += 1
    return j - i - 1 if j < len(text) and text[j] == "[" else -1


def mask(text):
    """(code, bare): comments blanked in both; string bodies blanked too in bare. Newlines and lengths kept."""
    code, bare = list(text), list(text)
    i, n = 0, len(text)

    def blank(a, b, both):
        for k in range(a, b):
            if text[k] != "\n":
                bare[k] = " "
                if both:
                    code[k] = " "
    while i < n:
        c = text[i]
        if text.startswith("--", i):
            lvl = _long(text, i + 2) if text.startswith("[", i + 2) else -1
            end = text.find("]" + "=" * lvl + "]", i) if lvl >= 0 else text.find("\n", i)
            end = n if end < 0 else end + (lvl + 2 if lvl >= 0 else 0)
            blank(i, end, True)
            i = end
        elif c in "\"'":
            j = i + 1
            while j < n and text[j] != c and text[j] != "\n":
                j += 2 if text[j] == "\\" else 1
            blank(i + 1, min(j, n), False)
            i = j + 1
        elif c == "[" and _long(text, i) >= 0:
            lvl = _long(text, i)
            end = text.find("]" + "=" * lvl + "]", i)
            end = n if end < 0 else end
            blank(i + lvl + 2, end, False)
            i = end + lvl + 2
        else:
            i += 1
    return "".join(code), "".join(bare)


def caps(name):
    return bool(CAPS.fullmatch(name)) and sum(ch.isalpha() for ch in name) >= 2


def letters(s):
    """True when a string body has real words: 2+ letters in a row once colour, link and format codes are out."""
    return re.search(r"[A-Za-z]{2}", CODES.sub(" ", s)) is not None


class LuaFile:
    def __init__(self, text):
        self.text = text
        self.code, self.bare = mask(text)
        self.nl = [m.start() for m in re.finditer("\n", text)]
        self.toks = []
        for m in TOKRE.finditer(self.bare):
            if m.group(1):
                continue
            s, e = m.span()
            if m.group(2):
                self.toks.append(Tok(NAME, m.group(2), s, e))
            elif m.group(3):
                self.toks.append(Tok(NUM, m.group(3), s, e))
            elif m.group(4):
                self.toks.append(Tok(STR, self.code[s + 1:e - 1], s, e))
            elif m.group(5):
                lv = len(m.group(6)) + 2
                self.toks.append(Tok(STR, self.code[s + lv:e - lv], s, e))
            else:
                self.toks.append(Tok(SYM, m.group(), s, e))
        self._walk()

    def line(self, i):
        """1-based line of token i."""
        return bisect.bisect_right(self.nl, self.toks[i].s) + 1

    def v(self, i):
        return self.toks[i].val if 0 <= i < len(self.toks) else None

    def is_sym(self, i, s):
        return 0 <= i < len(self.toks) and self.toks[i].kind == SYM and self.toks[i].val == s

    def src(self, a, b, width=40):
        """Code of tokens a..b-1 with string bodies blanked (no addon English), whitespace folded, cut to width."""
        if a >= b:
            return ""
        t = " ".join(self.bare[self.toks[a].s:self.toks[b - 1].e].split())
        t = re.sub(r"\"\s*\"|'\s*'|\[=*\[\s*\]=*\]", '""', t)
        return t if len(t) <= width else t[:width - 3] + "..."

    def chain_start(self, i):
        """Start index of the name chain that ends just before token i (a.b:c, x[1], f(...).y)."""
        j = i - 1
        while j >= 0:
            t = self.toks[j]
            if t.kind == NAME and t.val not in KEYWORDS:
                if j > 0 and self.toks[j - 1].val in (".", ":") and self.toks[j - 1].kind == SYM:
                    j -= 2
                    continue
                return j
            if t.kind == SYM and t.val in (")", "]") and j in self.open_of:
                j = self.open_of[j] - 1
                continue
            return j + 1
        return 0

    def _walk(self):
        """Per token: frames (innermost last: [kind, open index, callee chain, arg no, key, owner]) and depth
        (how many function bodies it is in: 0 runs at load)."""
        self.close, self.open_of, self.depth, self.frames = {}, {}, [], []
        stack, opens, blocks = [], [], []
        toks = self.toks
        for i, t in enumerate(toks):
            if t.kind == SYM and t.val in "([{" and t.val:
                opens.append(i)
            elif t.kind == SYM and t.val in ")]}" and t.val and opens:
                o = opens.pop()
                self.close[o], self.open_of[i] = i, o
        snap = ()
        for i, t in enumerate(toks):
            if t.kind == NAME:
                if t.val in ("function", "if", "do", "repeat"):
                    blocks.append(t.val)
                elif t.val in ("end", "until") and blocks:
                    blocks.pop()
            self.depth.append(blocks.count("function"))
            if t.kind == SYM and t.val in ("(", "{", "["):
                prev = toks[i - 1] if i else None
                callee = None
                is_call = prev is not None and ((prev.kind == NAME and prev.val not in KEYWORDS)
                                                or (prev.kind == SYM and prev.val in (")", "]")))
                if t.val != "[" and is_call:
                    a = self.chain_start(i)
                    callee = self.src(a, i, 80)
                    if a > 0 and self.v(a - 1) == "function":
                        callee = None
                owner = None
                if t.val == "{" and prev is not None and prev.kind == SYM and prev.val == "=":
                    owner = self.src(self.chain_start(i - 1), i - 1, 80)
                stack.append([t.val, i, callee, 0, None, owner])
                snap = tuple(tuple(f) for f in stack)
            elif t.kind == SYM and t.val in (")", "}", "]") and stack:
                stack.pop()
                snap = tuple(tuple(f) for f in stack)
            elif t.kind == SYM and t.val in (",", ";") and stack:
                stack[-1][3] += 1
                stack[-1][4] = None
                snap = tuple(tuple(f) for f in stack)
            elif (stack and stack[-1][0] == "{" and self.is_sym(i + 1, "=") and self.v(i - 1) in ("{", ",", ";")
                  and t.kind == NAME):
                stack[-1][4] = t.val
                snap = tuple(tuple(f) for f in stack)
            elif (stack and stack[-1][0] == "{" and t.kind == STR and self.is_sym(i - 1, "[") and self.is_sym(i + 1, "]")
                  and self.is_sym(i + 2, "=")):
                stack[-1][4] = t.val
                snap = tuple(tuple(f) for f in stack)
            self.frames.append(snap)

    def args(self, o):
        """Token ranges [(a, b)] of the top-level parts of the bracket opened at o, split at , and ;."""
        c = self.close.get(o, len(self.toks))
        out, a, i = [], o + 1, o + 1
        while i < c:
            if i in self.close:
                i = self.close[i] + 1
                continue
            if self.toks[i].kind == SYM and self.toks[i].val in (",", ";"):
                out.append((a, i))
                a = i + 1
            i += 1
        if a < c:
            out.append((a, c))
        return out

    def fields(self, o):
        """{key: (a, b)} of a table constructor opened at o: name = value and ["key"] = value parts."""
        out = {}
        for a, b in self.args(o):
            if b - a >= 3 and self.toks[a].kind == NAME and self.is_sym(a + 1, "="):
                out[self.toks[a].val] = (a + 2, b)
            elif b - a >= 5 and self.is_sym(a, "[") and self.toks[a + 1].kind == STR and self.is_sym(a + 3, "="):
                out[self.toks[a + 1].val] = (a + 4, b)
        return out

    def rhs_end(self, i):
        """End (exclusive) of the expression that starts at i on a statement: to the line end, over brackets."""
        line = self.line(i)
        j = i
        while j < len(self.toks):
            if j in self.close:
                j = self.close[j] + 1
                continue
            t = self.toks[j]
            if (self.line(j) > line or (t.kind == SYM and t.val in (",", ";", ")", "}", "]"))
                    or (t.kind == NAME and t.val in ("then", "do", "end", "else", "elseif", "local", "return"))):
                break
            j += 1
        return max(j, i + 1)

    def calls(self):
        """(open index, callee chain, last name of the chain) of every call with ( or a table argument."""
        for i, t in enumerate(self.toks):
            if t.kind == SYM and t.val in ("(", "{") and self.frames[i] and self.frames[i][-1][1] == i:
                callee = self.frames[i][-1][2]
                if callee:
                    yield i, callee, re.findall(r"[A-Za-z_]\w*", callee)[-1]
