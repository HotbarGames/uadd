"""Find ForeverXP Bar's user-visible English texts in its Lua source. Used by tools/make_fxpb_data.py.

ForeverXP Bar has no locale table: its words are string literals in SetText, printMsg, tooltip lines,
string.format and `..` joins. scan(text) reads one Lua file with tools/luatok.py and returns Text items:
  kind  "exact" (a literal shown as it is) or "format" (a template: %s %d .. slots, %% a real percent);
  text  the English (a template for "format");
  line  the source line; sink  the call or field it goes to (for the area and the skip rules).
A `..` join becomes one template: each literal piece stays, every other piece is a %s slot.
string.format("...") templates are kept as they are. What is skipped, and why, is in fxpb_rules.py.
Standard library only.
"""
import re
from dataclasses import dataclass

import luatok
import fxpb_rules as R

MERGE = {("<", "="): "<=", (">", "="): ">=", ("=", "="): "==", ("~", "="): "~=", (".", "."): ".."}
ARITH = {"+", "-", "*", "/", "%", "^"}
OPEN, CLOSE = {"(": ")", "[": "]", "{": "}"}, {")", "]", "}"}


@dataclass
class Text:
    kind: str
    text: str
    line: int
    sink: str


def toks(text):
    out = []
    for kind, val, line in luatok.tokens(text):
        if kind == luatok.SYM and out and out[-1][0] == luatok.SYM and (out[-1][1], val) in MERGE:
            out[-1] = (luatok.SYM, MERGE[(out[-1][1], val)], out[-1][2])
        elif kind == luatok.SYM and val == "." and out and out[-1][1] == "..":
            out[-1] = (luatok.SYM, "...", out[-1][2])
        else:
            out.append((kind, val, line))
    return out


def match_close(t, i):
    """t[i] opens a bracket: the index of its partner."""
    depth = 0
    for j in range(i, len(t)):
        if t[j][0] == luatok.SYM and t[j][1] in OPEN:
            depth += 1
        elif t[j][0] == luatok.SYM and t[j][1] in CLOSE:
            depth -= 1
            if depth == 0:
                return j
    return len(t) - 1


def match_open(t, i):
    depth = 0
    for j in range(i, -1, -1):
        if t[j][0] == luatok.SYM and t[j][1] in CLOSE:
            depth += 1
        elif t[j][0] == luatok.SYM and t[j][1] in OPEN:
            depth -= 1
            if depth == 0:
                return j
    return 0


def primary_end(t, i):
    """The last index of the primary expression (with calls, fields, indexes) starting at t[i], or -1."""
    k, v = t[i][0], t[i][1]
    if k == luatok.STR or (k == luatok.SYM and v in ("0", "...")) or (k == luatok.NAME and v in ("nil", "true", "false")):
        return i
    if k == luatok.SYM and v == "{":
        return match_close(t, i)
    if k == luatok.SYM and v == "(":
        j = match_close(t, i)
    elif k == luatok.NAME and v not in R.KEYWORDS:
        j = i
    else:
        return -1
    while j + 1 < len(t):
        nk, nv = t[j + 1][0], t[j + 1][1]
        if nk == luatok.SYM and nv in (".", ":") and j + 2 < len(t) and t[j + 2][0] == luatok.NAME:
            j += 2
        elif nk == luatok.SYM and nv in ("(", "["):
            j = match_close(t, j + 1)
        elif nk == luatok.STR or (nk == luatok.SYM and nv == "{"):
            j = j + 1 if nk == luatok.STR else match_close(t, j + 1)
        else:
            break
    return j


def operand_end(t, i):
    """An arithmetic operand of `..`: unary* primary (op unary* primary)*. Its last index, or -1."""
    j = i - 1
    while True:
        k = j + 1
        while k < len(t) and (t[k][1] in ("-", "#") or (t[k][0] == luatok.NAME and t[k][1] == "not")):
            k += 1
        if k >= len(t):
            return -1
        e = primary_end(t, k)
        if e < 0:
            return -1 if j < i else j
        j = e
        if j + 1 < len(t) and t[j + 1][0] == luatok.SYM and t[j + 1][1] in ARITH:
            continue
        return j


def call_name(t, open_i):
    """The name of the function called by the '(' at open_i (a.b:c -> 'c'), or '' for a bracket."""
    j = open_i - 1
    if j >= 0 and t[j][0] == luatok.NAME and t[j][1] not in R.KEYWORDS:
        return t[j][1]
    return ""


def target_of(t, eq):
    """The name assigned at the '=' t[eq]: 'field:key' in a table constructor, else 'set:name'."""
    p = t[eq - 1] if eq > 0 else (None, "", 0)
    if p[1] == "]":
        q = match_open(t, eq - 1)
        return "field:" + (t[q + 1][1] if t[q + 1][0] == luatok.STR else "?")
    if p[0] != luatok.NAME:
        return "other"
    before = t[eq - 2][1] if eq > 1 else ""
    return ("field:" if before in ("{", ",", ";") else "set:") + p[1]


def sink_of(t, start, end):
    """Where the expression t[start..end] goes: 'call:Name#argN', 'field:key', 'set:name', 'table',
    'cmp', 'index', 'return', or 'stmt:keyword'. Walks left over `..`, and/or, arithmetic and brackets."""
    nxt = t[end + 1][1] if end + 1 < len(t) else ""
    prev = t[start - 1][1] if start > 0 else ""
    if nxt in ("==", "~=") or prev in ("==", "~="):
        return "cmp"
    if prev == "[" and nxt == "]":
        return "index"
    j, argn = start - 1, 1
    while j >= 0:
        k, v = t[j][0], t[j][1]
        if k == luatok.SYM and v in CLOSE:
            j = match_open(t, j) - 1
            continue
        if k == luatok.SYM:
            if v == ",":
                argn += 1
            elif v == "(":
                name = call_name(t, j)
                if name:
                    return f"call:{name}#{argn}"
            elif v == "{":
                return "table"
            elif v == "=":
                return target_of(t, j)
            elif v == "[":
                return "index"
        elif k == luatok.NAME and v in R.KEYWORDS and v not in ("and", "or", "not", "nil", "true", "false"):
            return "return" if v == "return" else "stmt:" + v
        j -= 1
    return "other"


def is_call_paren(t, i):
    """t[i] is the '(' of a call's arguments (f(, a.b(, f(x)(, t[k](), not a bracketed expression."""
    if t[i][1] != "(" or i == 0:
        return False
    p = t[i - 1]
    return (p[0] == luatok.NAME and p[1] not in R.KEYWORDS) or p[1] in (")", "]") or p[0] == luatok.STR


def pieces_to_template(pieces, escape=True):
    out = []
    for kind, val in pieces:
        out.append((val.replace("%", "%%") if escape else val) if kind == "lit" else "%s")
    return "".join(out)


def top_level(t, a, b):
    """Indexes in t[a..b] that are not inside a bracket opened in that range (the operand's own pieces)."""
    out, depth = set(), 0
    for j in range(a, b + 1):
        if depth == 0:
            out.add(j)
        if t[j][0] == luatok.SYM and t[j][1] in OPEN:
            depth += 1
        elif t[j][0] == luatok.SYM and t[j][1] in CLOSE:
            depth -= 1
    return out


def is_format_string(t, i):
    """("..."):format(...) or "...":format(...) -- a template, not a text shown as it is."""
    v = [t[k][1] if k < len(t) else "" for k in range(i + 1, i + 4)]
    if v[0] == ":" and v[1] == "format":
        return True
    return i > 0 and t[i - 1][1] == "(" and v == [")", ":", "format"]


def scan(text):
    """[Text] for every string literal and `..` join, before the skip rules."""
    t = toks(text)
    found, done, blocked = [], set(), set()
    i = 0
    while i < len(t):
        if t[i][0] == luatok.SYM and t[i][1] not in ("(", "{", "-", "#", "0", "...") or is_call_paren(t, i):
            i += 1
            continue
        after_dot = i > 0 and t[i - 1][1] in (".", ":")
        e = operand_end(t, i) if t[i][1] != "{" and i not in blocked and not after_dot else -1
        if e >= 0 and e + 1 < len(t) and t[e + 1][1] == "..":
            parts, ends = [(i, e)], e
            while ends + 2 < len(t) and t[ends + 1][1] == "..":
                e2 = operand_end(t, ends + 2)
                if e2 < 0:
                    break
                parts.append((ends + 2, e2))
                ends = e2
            for a, b in parts:
                blocked.update(top_level(t, a, b))
            pieces = [("lit", t[a][1]) if a == b and t[a][0] == luatok.STR else ("slot", "") for a, b in parts]
            if any(k == "lit" for k, _ in pieces):
                lits = [a for a, b in parts if a == b and t[a][0] == luatok.STR]
                done.update(lits)
                sink = sink_of(t, i, ends)
                tmpl = pieces_to_template(pieces, not sink.startswith("call:format#1"))
                found.append(Text("format", tmpl, t[lits[0]][2], sink))
            i += 1
            continue
        if t[i][0] == luatok.STR and i not in done:
            sink = sink_of(t, i, i)
            prev = t[i - 1] if i > 0 else (None, "", 0)
            if prev[0] == luatok.NAME and prev[1] not in R.KEYWORDS:
                sink = f"call:{prev[1]}#1"           # f"str" call without parentheses
            fmt = sink.startswith("call:format#1") or is_format_string(t, i)
            found.append(Text("format" if fmt else "exact", t[i][1], t[i][2], sink))
        i += 1
    return found
