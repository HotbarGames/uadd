"""A small Lua tokenizer: enough to read string tables and glossary data files.

tokens(text) yields (kind, value, line). kind is STR, NAME or SYM. STR values have escapes decoded; comments
are skipped; numbers come out as (SYM, "0"). Standard library only. Used by tools/glossary.py.
"""
import re
from pathlib import Path

STR, NAME, SYM = "str", "name", "sym"
ESCAPES = {"a": "\a", "b": "\b", "f": "\f", "n": "\n", "r": "\r", "t": "\t", "v": "\v",
           "\\": "\\", '"': '"', "'": "'", "\n": "\n"}


def _long_level(text, i):
    """At text[i] == '[': the level of a long bracket ([[ or [==[), or -1."""
    j = i + 1
    while j < len(text) and text[j] == "=":
        j += 1
    return j - i - 1 if j < len(text) and text[j] == "[" else -1


def tokens(text):
    """Lua tokens (kind, value, line). STR values have escapes decoded. Comments are skipped."""
    i, n, line = 0, len(text), 1
    while i < n:
        c = text[i]
        if c == "\n":
            line += 1
            i += 1
        elif c in " \t\r":
            i += 1
        elif text.startswith("--", i):
            i += 2
            level = _long_level(text, i) if i < n and text[i] == "[" else -1
            end = text.find("]" + "=" * level + "]", i) if level >= 0 else text.find("\n", i)
            end = n if end < 0 else end
            line += text.count("\n", i, end)
            i = end + (level + 2 if level >= 0 else 0)
        elif c in "\"'":
            start, out, i = line, [], i + 1
            while i < n and text[i] != c:
                if text[i] == "\\" and i + 1 < n:
                    e = text[i + 1]
                    m = re.match(r"\d{1,3}", text[i + 1:i + 4])
                    if e in ESCAPES:
                        out.append(ESCAPES[e])
                        line += e == "\n"
                        i += 2
                    elif m:
                        out.append(chr(int(m.group()) & 255))
                        i += 1 + len(m.group())
                    else:
                        out.append(e)
                        i += 2
                else:
                    line += text[i] == "\n"
                    out.append(text[i])
                    i += 1
            i += 1
            yield STR, "".join(out), start
        elif c == "[" and _long_level(text, i) >= 0:
            level = _long_level(text, i)
            start = i + level + 2
            if text.startswith("\n", start):
                start += 1
            end = text.find("]" + "=" * level + "]", start)
            end = n if end < 0 else end
            yield STR, text[start:end], line
            line += text.count("\n", i, end)
            i = end + level + 2
        elif c.isalpha() or c == "_":
            m = re.match(r"[A-Za-z_][A-Za-z0-9_]*", text[i:])
            yield NAME, m.group(), line
            i += len(m.group())
        elif c.isdigit():
            m = re.match(r"[0-9A-Fa-fxX.]+", text[i:])
            yield SYM, "0", line
            i += len(m.group())
        else:
            yield SYM, c, line
            i += 1


def read(path):
    return Path(path).read_bytes().decode("utf-8", "replace")
