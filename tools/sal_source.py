"""Reads the installed Speedy AutoLoot for tools/make_sal_text.py: the chat lines its slash command prints, the
label of its loot display's anchor and the two test entries shown while the anchor is moved. Which texts are
kept and how: tools/sal_rules.py. Nothing here names its English (no licence file: all rights reserved).

Every text is keyed Code.<hash>: UADD.Hash of the English as the module sees it at run time.
  * A chat line after the addon's name prefix (its local fName): the rest of the line.
  * A help line (no name prefix): the rest after HELP_PREFIX (the colour code and the slash command).
  * A chat line with a value in it (a sound's number): a template, the value as %s.
  * The anchor's label, the test entries' item names: the text itself.
"""
import os
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import hashtext as H  # noqa: E402
import luatok  # noqa: E402
import sal_rules as R  # noqa: E402

ADDON_DIRS = ["/mnt/c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns",
              "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns"]
MAIN, DISPLAY = "SpeedyAutoLoot.lua", "LootDisplay.lua"
HELP_PREFIX = "  |cff58C6FA/sal "      # a help line's start: kept as it is (UADD_SpeedyAutoLoot/Module.lua)
NAME_VAR = "fName"                     # the addon's local that holds its name prefix
S, N, Y = luatok.STR, luatok.NAME, luatok.SYM
SPLIT = {"and", "or", "not", "if", "then", "else"}


def addon_dir(arg=None):
    if arg:
        return Path(arg)
    base = os.environ.get("UADD_ADDONS_DIR") or next((d for d in ADDON_DIRS if os.path.isdir(d)), ADDON_DIRS[0])
    return Path(base) / "SpeedyAutoLoot"


def version(addon):
    toc = Path(addon) / "SpeedyAutoLoot.toc"
    m = re.search(r"^## Version:\s*(\S+)", toc.read_text(encoding="utf-8-sig", errors="replace"), re.M) \
        if toc.is_file() else None
    return m.group(1) if m else "?"


def _toks(path):
    return list(luatok.tokens(luatok.read(path)))


def _call(t, i):
    """Tokens inside the parentheses that open at t[i], and the index after the closing one."""
    depth, j = 0, i
    while j < len(t):
        if t[j][:2] == (Y, "("):
            depth += 1
        elif t[j][:2] == (Y, ")"):
            depth -= 1
            if depth == 0:
                return t[i + 1:j], j + 1
        j += 1
    return t[i + 1:], len(t)


def _texts(inner):
    """[(text, named)] of one AddMessage call: each run of strings joined by `..` (a variable in it is %s),
    split at and/or, commas and parentheses. named: the call has the name prefix in it."""
    named = any(x[:2] == (N, NAME_VAR) for x in inner)
    out, seg, prev, prev2 = [], [], None, None

    def field(p, p2):       # a name after "." (not the "..") or ":" is a field, part of the variable before it
        return p and p[0] == Y and (p[1] == ":" or (p[1] == "." and not (p2 and p2[:2] == (Y, "."))))

    def flush():
        if any(k == S for k, _ in seg):
            esc = any(k == "v" for k, _ in seg)
            out.append(("".join((v.replace("%", "%%") if esc else v) if k == S else "%s" for k, v in seg), named))
        seg.clear()
    for tok in inner:
        kind, value = tok[0], tok[1]
        if kind == S:
            seg.append((S, value))
        elif kind == N and value in SPLIT:
            flush()
        elif kind == N:
            if value != NAME_VAR and not field(prev, prev2):
                seg.append(("v", ""))
        elif kind == Y and value in ("(", ")", ","):
            flush()
        prev, prev2 = tok, prev
    flush()
    return out


def chat_texts(addon):
    """[(text as the module sees it, line, kind)] of every AddMessage call: kind 'state' (after the name
    prefix), 'help' (after HELP_PREFIX) or 'other'."""
    p = Path(addon) / MAIN
    if not p.is_file():
        return []
    t, out, i = _toks(p), [], 0
    while i < len(t) - 1:
        if t[i][:2] == (N, "AddMessage") and t[i + 1][:2] == (Y, "("):
            inner, nxt = _call(t, i + 1)
            for text, named in _texts(inner):
                if named:
                    out.append((text, t[i][2], "state"))
                elif text.startswith(HELP_PREFIX):
                    out.append((text[len(HELP_PREFIX):], t[i][2], "help"))
                else:
                    out.append((text, t[i][2], "other"))
            i = nxt
        else:
            i += 1
    return out


def display_texts(addon):
    """[(text, line, kind)] of the loot display: 'label' (a SetText with a string) and 'test' (the item name of
    a PostLoot(..., isCoin false, isTest true); the coin one shows money, not its name)."""
    p = Path(addon) / DISPLAY
    if not p.is_file():
        return []
    t, out = _toks(p), []
    for i in range(len(t) - 3):
        if t[i][:2] == (N, "SetText") and t[i + 1][:2] == (Y, "(") and t[i + 2][0] == S and t[i + 3][:2] == (Y, ")"):
            out.append((t[i + 2][1], t[i][2], "label"))
        if t[i][:2] == (N, "PostLoot") and t[i + 1][:2] == (Y, "(") and t[i + 2][0] == S:
            inner, _ = _call(t, i + 1)
            args, cur, depth = [], [], 0
            for x in inner:
                if x[:2] == (Y, ",") and depth == 0:
                    args.append(cur)
                    cur = []
                    continue
                depth += 1 if x[:2] == (Y, "(") else -1 if x[:2] == (Y, ")") else 0
                cur.append(x)
            args.append(cur)
            word = [a[0][1] if len(a) == 1 else None for a in args]
            if len(args) == 10 and word[8] == "false" and word[9] == "true":
                out.append((t[i + 2][1], t[i][2], "test"))
    return out


def source(addon):
    """(rows, why). rows: (key, English, batch, [(file, line)], note) in batch order; why: {reason: count} of
    the texts left out."""
    addon = Path(addon)
    if not (addon / MAIN).is_file():
        return [], {}
    rows, why, seen = [], {}, set()
    found = [(MAIN, x) for x in chat_texts(addon)] + [(DISPLAY, x) for x in display_texts(addon)]
    for f, (en, line, kind) in found:
        key = "Code." + H.djb2(en)
        kept, reason = R.keep(kind, en)
        if not kept:
            why[reason] = why.get(reason, 0) + 1
            continue
        if key in seen:
            continue
        seen.add(key)
        rows.append((key, en, R.batch_of(key), [(f, line)], R.NOTES[kind]))
    return rows, why


if __name__ == "__main__":      # prints the English: for a look, never into a tracked file
    rs, w = source(addon_dir(sys.argv[1] if len(sys.argv) > 1 else None))
    for r in rs:
        print(r[0], repr(r[1]), r[3], r[4][:30])
    print(w)
