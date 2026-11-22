"""A small Lua tokenizer: enough to read string tables and glossary data files.

tokens(text) yields (kind, value, line). kind is STR, NAME or SYM. STR values have escapes decoded; comments
are skipped; numbers come out as (SYM, "0"). Standard library only. Used by tools/glossary.py.

tokens() reads the common tokens (spaces, names, numbers, plain strings, short comments, one-letter symbols)
with one regex, and hands the rest (escapes, long brackets, odd letters) to _step, the old letter-by-letter
reader. slow_tokens() is that old reader alone; tools/test_glossary.py wants both to give the same tokens on
every Lua file of the repo and the installed addons (the regex cut the test suite's tokenizing time by ~5x).
"""
import re
from pathlib import Path

STR, NAME, SYM = "str", "name", "sym"
ESCAPES = {"a": "\a", "b": "\b", "f": "\f", "n": "\n", "r": "\r", "t": "\t", "v": "\v",
           "\\": "\\", '"': '"', "'": "'", "\n": "\n"}
_FAST = re.compile(r"""(?P<ws>[ \t\r]+)|(?P<nl>\n+)|(?P<name>[A-Za-z_][A-Za-z0-9_]*)|(?P<num>[0-9][0-9A-Fa-fxX.]*)
    |(?P<str>"[^"\\\n]*"|'[^'\\\n]*')|(?P<sc>--(?!\[)[^\n]*)|(?P<sym>(?![ \t\r\nA-Za-z0-9_"'\[\-])[\x00-\x7f])""",
                   re.X)


def _long_level(text, i):
    """At text[i] == '[': the level of a long bracket ([[ or [==[), or -1."""
    j = i + 1
    while j < len(text) and text[j] == "=":
        j += 1
    return j - i - 1 if j < len(text) and text[j] == "[" else -1


def _step(text, i, n, line, out):
    """One step of the old reader at text[i]: appends its token (if any) to out, returns (i, line)."""
    c = text[i]
    if c == "\n":
        return i + 1, line + 1
    if c in " \t\r":
        return i + 1, line
    if text.startswith("--", i):
        i += 2
        level = _long_level(text, i) if i < n and text[i] == "[" else -1
        end = text.find("]" + "=" * level + "]", i) if level >= 0 else text.find("\n", i)
        end = n if end < 0 else end
        line += text.count("\n", i, end)
        return end + (level + 2 if level >= 0 else 0), line
    if c in "\"'":
        start, buf, i = line, [], i + 1
        while i < n and text[i] != c:
            if text[i] == "\\" and i + 1 < n:
                e = text[i + 1]
                m = re.match(r"\d{1,3}", text[i + 1:i + 4])
                if e in ESCAPES:
                    buf.append(ESCAPES[e])
                    line += e == "\n"
                    i += 2
                elif m:
                    buf.append(chr(int(m.group()) & 255))
                    i += 1 + len(m.group())
                else:
                    buf.append(e)
                    i += 2
            else:
                line += text[i] == "\n"
                buf.append(text[i])
                i += 1
        out.append((STR, "".join(buf), start))
        return i + 1, line
    if c == "[" and _long_level(text, i) >= 0:
        level = _long_level(text, i)
        start = i + level + 2
        if text.startswith("\n", start):
            start += 1
        end = text.find("]" + "=" * level + "]", start)
        end = n if end < 0 else end
        out.append((STR, text[start:end], line))
        return end + level + 2, line + text.count("\n", i, end)
    if c.isalpha() or c == "_":
        m = re.match(r"[A-Za-z_][A-Za-z0-9_]*", text[i:])
        out.append((NAME, m.group(), line))
        return i + len(m.group()), line
    if c.isdigit():
        m = re.match(r"[0-9A-Fa-fxX.]+", text[i:])
        out.append((SYM, "0", line))
        return i + len(m.group()), line
    out.append((SYM, c, line))
    return i + 1, line


def tokens(text):
    """Lua tokens (kind, value, line). STR values have escapes decoded. Comments are skipped."""
    i, n, line, match, out = 0, len(text), 1, _FAST.match, []
    while i < n:
        m = match(text, i)
        if m is None:
            i, line = _step(text, i, n, line, out)
            yield from out
            out.clear()
            continue
        kind = m.lastgroup
        if kind == "nl":
            line += m.end() - i
        elif kind == "name":
            yield NAME, m.group(), line
        elif kind == "num":
            yield SYM, "0", line
        elif kind == "str":
            yield STR, m.group()[1:-1], line
        elif kind == "sym":
            yield SYM, m.group(), line
        i = m.end()


def slow_tokens(text):
    """The old letter-by-letter reader alone: the reference tokens() must match."""
    i, n, line, out = 0, len(text), 1, []
    while i < n:
        i, line = _step(text, i, n, line, out)
        yield from out
        out.clear()


def read(path):
    return Path(path).read_bytes().decode("utf-8", "replace")
