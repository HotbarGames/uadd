"""The English Auctionator writes straight in its code (slash command help, chat lines), read from the
installed addon at build or test time by make_auc_text.py. Nothing here is kept in the repo."""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import hashtext  # noqa: E402
import luatok  # noqa: E402

SOURCES = ("Source/SlashCmd/Commands.lua", "Source/SlashCmd/Main.lua")


def _call_args(t, i):
    """Tokens of the argument of the call whose "(" is t[i], and the index after its ")"."""
    depth, j = 0, i
    while j < len(t):
        if t[j][1] in "([{" and t[j][0] == luatok.SYM:
            depth += 1
        elif t[j][1] in ")]}" and t[j][0] == luatok.SYM:
            depth -= 1
            if depth == 0:
                return t[i + 1:j], j + 1
        j += 1
    return t[i + 1:], j


def _joined(args):
    """A text made of `a .. b .. c`: its string pieces as they are, every other piece a %s; None when
    no piece is a string."""
    parts, cur, depth, k = [], [], 0, 0
    while k < len(args):
        kind, v = args[k][:2]
        if kind == luatok.SYM and v in "([{":
            depth += 1
        elif kind == luatok.SYM and v in ")]}":
            depth -= 1
        if depth == 0 and kind == luatok.SYM and v == "." and k + 1 < len(args) and args[k + 1][1] == ".":
            parts.append(cur)
            cur, k = [], k + 2
            continue
        cur.append(args[k])
        k += 1
    parts.append(cur)
    if len(parts) == 1:
        return args[0][1] if len(args) == 1 and args[0][0] == luatok.STR else None
    if not any(len(p) == 1 and p[0][0] == luatok.STR for p in parts):
        return None
    return "".join(p[0][1].replace("%", "%%") if len(p) == 1 and p[0][0] == luatok.STR else "%s" for p in parts)


def code_texts(text):
    """The English one Lua file writes straight in its code and shows: help texts (message = "..."),
    what it passes to Utilities.Message (a join of strings and values as a %s template), a colour
    wrapped string, and a local "...%s..." format string. Only texts with letters, once each."""
    t = list(luatok.tokens(text))
    out = []
    for i, (kind, v, _) in enumerate(t):
        got = None
        nxt = t[i + 1][:2] if i + 1 < len(t) else None
        if kind == luatok.NAME and v == "message" and nxt == (luatok.SYM, "=") and t[i + 2][0] == luatok.STR:
            got = t[i + 2][1]
        elif kind == luatok.NAME and v == "Message" and nxt == (luatok.SYM, "(") and i > 1 and t[i - 2][1] == "Utilities":
            got = _joined(_call_args(t, i + 1)[0])
        elif kind == luatok.NAME and v == "WrapTextInColorCode" and nxt == (luatok.SYM, "("):
            args = _call_args(t, i + 1)[0]
            got = args[0][1] if len(args) == 1 and args[0][0] == luatok.STR else None
        elif kind == luatok.NAME and v == "local" and i + 3 < len(t) and t[i + 2][1] == "=" \
                and t[i + 3][0] == luatok.STR and hashtext.is_template(t[i + 3][1]):
            got = t[i + 3][1]
        if got and re.search(r"[A-Za-z]", got) and got not in out and _long_enough(got):
            out.append(got)
    return out


def _long_enough(en):
    """A template needs MIN_LIT bytes of its own words ("%s: %s" alone would match anything)."""
    if not hashtext.is_template(en):
        return True
    return sum(len(p[1].encode("utf-8")) for p in hashtext.tokens(en) if p[0] == "lit") >= hashtext.MIN_LIT


def all_code_texts(addon):
    """[(file, English)] for every file of SOURCES that is there."""
    out = []
    for rel in SOURCES:
        p = addon / rel
        if p.is_file():
            out += [(rel, en) for en in code_texts(luatok.read(p)) if en not in {e for _, e in out}]
    return out
