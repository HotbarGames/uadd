"""The chaos test's cases: odd values to feed, and the check that a text came out whole (chaos.py).

A fed text comes out right when it is exactly what went in (left English, untouched), or when it changed and
holds no made-up English outside a link or a picture (all Ukrainian around the parts that stay as they are).
A changed text that still holds made-up English is a half line (CLAUDE.md "No half translations").
No text of another addon is written here: the English fed is read at run time from the font strings the
module changed (the installed addon's own words, or the stand-in's few labels).
"""
import random
import re

from halves import FILLERS

ODD = ("Zorp", "Blatter", "wobbly", "gizmo", "zork42", "went fine")
CYR = re.compile("[Ѐ-ӿ]")
LINK = re.compile(r"\|H.*?\|h.*?\|h|\|T.*?\|t|\|A.*?\|a|\|c[0-9a-fA-F]{8}|\|r", re.S)
WORDS = ("blue", "gizmo", "ferret", "Quantum", "lantern", "seventh", "Mossy", "harbor", "spindle", "Vortex",
         "wobbly", "copper", "Zorp", "candle", "Blatter", "drift", "plum")


def plain(text):
    """text without links, pictures and colour codes (what may keep English inside a Ukrainian line)."""
    return LINK.sub(" ", text or "")


def half(out, fed):
    """Why `out` (what the font string shows after `fed` went in) is a half line, or None."""
    if not isinstance(out, str) or out == fed:
        return None
    rest = plain(out)
    if not CYR.search(rest):
        return None                      # changed but no Ukrainian: another kind of English, not half
    left = [w for w in ODD if w in rest]
    return f"made-up English kept: {left}" if left else None


def unseen(rng, n=1):
    """n made-up English texts, never in any data (they must stay as they are)."""
    out = []
    for _ in range(n):
        k = rng.randint(2, 7)
        s = " ".join(rng.choice(WORDS) for _ in range(k))
        out.append(s[:1].upper() + s[1:] + rng.choice(("", ".", ":", "!", " %", " 42")))
    return out


def bad_values():
    """(name, Lua-side value builder) for non-strings: (name, python value). None is nil in Lua."""
    return [("nil", None), ("number", 42), ("float", 4.5), ("empty", ""), ("space", " "), ("zero", "0")]


def fed(en, rng):
    """(name, text) cases built from one real English text `en`."""
    w = en.split()
    swapped = " ".join(FILLERS[1] if i == len(w) // 2 else x for i, x in enumerate(w)) if len(w) > 1 else FILLERS[1]
    cut = en[: max(1, len(en) // 2)]
    cases = [
        ("exact", en),
        ("filler after", en + " " + FILLERS[3]),
        ("filler before", FILLERS[0] + " " + en),
        ("word swapped", swapped),
        ("glued line", en + "\n" + FILLERS[2]),
        ("glued dash", en + " - " + FILLERS[0]),
        ("glued gap", en + "   " + FILLERS[1]),
        ("colour", "|cffff2020" + en + "|r"),
        ("colour filler", "|cffff2020" + en + "|r " + FILLERS[0]),
        ("link inside", en + " |cff9d9d9d|Hitem:2589::::::::1:::::::|h[" + FILLERS[1] + "]|h|r"),
        ("texture", "|TInterface\\Icons\\INV_Misc_QuestionMark:0|t " + en),
        ("escape pipes", en + " || " + FILLERS[3]),
        ("newline only", en + "\n"),
        ("upper", en.upper()),
        ("lower", en.lower()),
        ("doubled", en + " " + en),
        ("half cut", cut),
        ("cyrillic already", "Вже " + en),
        ("mixed scripts", en + " Привіт " + FILLERS[3]),
        ("broken utf-8", en + "\xff\xfe\xc3"),
        ("lone lead byte", "\xd0" + en),
        ("percent", en + " %s %d %%"),
        ("spaces", "  " + en + "  "),
        ("tab", en.replace(" ", "\t", 1)),
        ("nul byte", en + "\x00" + FILLERS[3]),
        ("10 KB", (en + " ") * max(1, 10240 // (len(en) + 1))),
        ("unseen", unseen(rng)[0]),
    ]
    return cases


def lua_bytes(text):
    """A Python str of real text -> the Lua state's latin-1 bytes; bytes already above 0x7f in the
    'broken' cases (\\xff...) are kept as they are."""
    out = []
    for ch in text:
        if ord(ch) < 0x80 or (0x80 <= ord(ch) <= 0xff and ch in "\xff\xfe\xc3\xd0"):
            out.append(ch)
        else:
            out.append(ch.encode("utf-8").decode("latin-1"))
    return "".join(out)


def seeded(seed, name):
    """A random.Random for one module and case, the same for the same seed."""
    return random.Random(f"{seed}:{name}")
