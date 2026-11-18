"""A small reader for the Lua tables WoW writes to SavedVariables (no lupa), for tools/missed.py.
Tolerant: odd numbers a client may write (inf, nan, 1.#INF, -1.#IND) read as floats, a bare word where a
value should be reads as None. Standard library only.
"""
import math
import re


ESC = {b"n": b"\n", b"t": b"\t", b"r": b"\r", b"a": b"\a", b"b": b"\b", b"f": b"\f", b"v": b"\v",
       b"\\": b"\\", b'"': b'"', b"'": b"'", b"\n": b"\n"}
# Numbers, also the odd ones a client may write: inf, -nan, nan(ind), 1.#INF, -1.#IND, 1.#QNAN.
NUM = (rb"-?1\.#(?:INF|IND|QNAN|SNAN)\d*|-?(?:inf(?:inity)?|nan(?:\(\w*\))?)(?!\w)"
       rb"|-?(?:0[xX][0-9a-fA-F]+|\d+\.?\d*(?:[eE][+-]?\d+)?|\.\d+(?:[eE][+-]?\d+)?)")
TOKEN = re.compile(rb"\s+|--\[(=*)\[.*?\]\1\]|--[^\n]*|(?P<str>\"(?:[^\"\\]|\\.)*\"|'(?:[^'\\]|\\.)*')"
                   rb"|(?P<num>" + NUM + rb")|(?P<name>[A-Za-z_]\w*)|(?P<p>[{}\[\]=,;])", re.S | re.I)


def _unquote(raw):
    out, i, s = bytearray(), 0, raw[1:-1]
    while i < len(s):
        c = s[i:i + 1]
        if c != b"\\":
            out += c
            i += 1
            continue
        n = s[i + 1:i + 2]
        if n.isdigit():
            m = re.match(rb"\d{1,3}", s[i + 1:])
            out.append(int(m.group()) % 256)
            i += 1 + len(m.group())
        else:
            out += ESC.get(n, n)
            i += 2
    return out.decode("utf-8", "replace")


def _number(t):
    low = t.lower()
    if "#" in low:
        return float("-inf" if low.startswith("-") else "inf") if "#inf" in low else float("nan")
    if "nan" in low:
        return float("nan")
    if "inf" in low:
        return float("-inf" if low.startswith("-") else "inf")
    if re.fullmatch(r"-?(0x[0-9a-f]+|\d+)", low):
        return int(low, 0) if not re.fullmatch(r"-?0\d+", low) else int(low, 10)
    return float(low)


def _tokens(data):
    pos = 0
    while pos < len(data):
        m = TOKEN.match(data, pos)
        if not m:
            raise ValueError("cannot read the file at byte %d" % pos)
        pos = m.end()
        if m.group("str") is not None:
            yield "v", _unquote(m.group("str"))
        elif m.group("num") is not None:
            yield "v", _number(m.group("num").decode())
        elif m.group("name") is not None:
            w = m.group("name").decode()
            yield ("v", {"true": True, "false": False, "nil": None}[w]) if w in ("true", "false", "nil") else ("n", w)
        elif m.group("p") is not None:
            yield "p", m.group("p").decode()


def parse(data):
    """{global name: value} of a SavedVariables file (bytes); tables become dicts (array items keyed 1, 2...).
    A bare word where a value should be reads as None; a NaN key is left out (it cannot be looked up)."""
    toks = list(_tokens(data)) + [("p", "")]
    i = 0

    def value():
        nonlocal i
        kind, v = toks[i]
        i += 1
        if kind in ("v", "n"):
            return v if kind == "v" else None
        if (kind, v) != ("p", "{"):
            raise ValueError("expected a value")
        t, n = {}, 0
        while toks[i] != ("p", "}"):
            if toks[i] == ("p", ""):
                raise ValueError("the file ends inside a table")
            if toks[i] == ("p", "["):
                i += 1
                k = value()
                if toks[i] != ("p", "]") or toks[i + 1] != ("p", "="):
                    raise ValueError("expected ] =")
                i += 2
                v = value()
                if not (isinstance(k, float) and math.isnan(k)):
                    t[k] = v
            elif toks[i][0] == "n" and toks[i + 1] == ("p", "="):
                k = toks[i][1]
                i += 2
                t[k] = value()
            else:
                n += 1
                t[n] = value()
            if toks[i] in (("p", ","), ("p", ";")):
                i += 1
        i += 1
        return t

    out = {}
    while toks[i] != ("p", ""):
        kind, name = toks[i]
        if kind != "n" or toks[i + 1] != ("p", "="):
            raise ValueError("expected NAME =")
        i += 2
        out[name] = value()
    return out
