"""DialogueUI's English for UADD_DialogueUI, read from the installed addon and never kept in the repo.

DialogueUI is all rights reserved and keeps its locale table (L) private, so the module finds its texts
on screen by hash (UADD/Hash.lua). This tool reads the installed DialogueUI's Locales/enUS.lua and writes
  * UADD_DialogueUI/ui/hashes.lua (tracked): for each key of ui/locale.lua, hashes of that key's English
    and nothing else (no Ukrainian: the module joins them with ns.UA in game);
  * local/dialogueui.txt (git-ignored): each key's English and our Ukrainian side by side.

Translator workflow:
  1. python3 tools/make_dui_data.py           after DialogueUI updates, or to get the review file
  2. change our Ukrainian, either in UADD_DialogueUI/ui/locale.lua (no rebuild needed) or on the UA lines
     of local/dialogueui.txt, then: python3 tools/make_dui_data.py --apply   (puts them into locale.lua)
  3. python3 -m unittest tools.test_dialogueui_strings, then the harness.
A UA value is a Lua value: "text", G"glossary.id", or false (kept in English on purpose).

python3 tools/make_dui_data.py [--apply] [--addon path/to/DialogueUI]
The shapes here match Words.lua's Shape(), which makes the same from a game global in game. Standard library.
"""
import argparse
import os
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent
sys.path.insert(0, str(HERE))
from hashtext import djb2, key as text_key, lua_str  # noqa: E402

DEFAULT = Path(os.environ.get("DIALOGUEUI_DIR",
                              "/mnt/c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/DialogueUI"))
LOCALE = REPO / "UADD_DialogueUI" / "ui" / "locale.lua"
OUT = REPO / "UADD_DialogueUI" / "ui" / "hashes.lua"
REVIEW = REPO / "local" / "dialogueui.txt"

STR = r'"(?:[^"\\]|\\.)*"'
ENUS_LINE = re.compile(r'^L\[(' + STR + r')\]\s*=\s*\(?\s*(?:([A-Z][A-Z0-9_]*)\s+or\s+)?(' + STR + r')\s*\)?\s*;?\s*(?:--.*)?$')
VALUE = r'G\s*' + STR + r'|' + STR + r'|false'
UA_LINE = re.compile(r'^(\s*\[(' + STR + r')\]\s*=\s*)(' + VALUE + r')(\s*,.*)$')
TOKEN = re.compile(r'(%%)|(%[-+ #0]*[0-9]*\.?[0-9]*[sdif])|(\[KEY:[A-Za-z0-9:]+\])')   # Words.lua's Tokens
SPEC = re.compile(r'%[-+ #0]*[0-9]*\.?[0-9]*[sdif]')
CODES = ("|c", "|r", "|T", "|t", "|H", "|h", "|n")
KIND = {"s": "s", "d": "d", "i": "d", "f": "f"}
ESC = {"n": "\n", "t": "\t", "r": "\r", "\\": "\\", '"': '"', "'": "'", "a": "\a", "b": "\b", "f": "\f", "v": "\v"}


def unlua(lit):
    """The text of a Lua string literal ("..." with \\n, \\ddd and the like)."""
    body, out, i = lit[1:-1], [], 0
    while i < len(body):
        c = body[i]
        if c != "\\":
            out.append(c)
            i += 1
        elif body[i + 1].isdigit():
            m = re.match(r"\d{1,3}", body[i + 1:])
            out.append(chr(int(m.group(0))))
            i += 1 + len(m.group(0))
        else:
            out.append(ESC.get(body[i + 1], body[i + 1]))
            i += 2
    return "".join(out)


def read_enus(path):
    """{key literal: (global name or None, English text)} and lines it could not read."""
    out, bad = {}, []
    for n, raw in enumerate(path.read_text(encoding="utf-8-sig").splitlines(), 1):
        line = raw.strip()
        if not line.startswith("L["):
            continue
        m = ENUS_LINE.match(line)
        if not m:
            bad.append(f"enUS.lua:{n}: cannot read this line")
            continue
        out.setdefault(m.group(1), (m.group(2), unlua(m.group(3))))
    return out, bad


def read_locale(path=LOCALE):
    """[(key literal, value expression)] in file order."""
    return [(m.group(2), m.group(3)) for m in map(UA_LINE.match, path.read_text(encoding="utf-8").splitlines()) if m]


def upper(s):
    """Lua's string.upper: ASCII letters only."""
    return s.encode("utf-8").upper().decode("utf-8")


def nbytes(s):
    return len(s.encode("utf-8"))


def pieces(en):
    """A template's English side, as Words.lua's Pieces makes it, or None when it has no slot."""
    lens, hashes, kinds, keys, piece, lit, sp = [], [], [], {}, "", 0, ""
    pos = 0
    for m in TOKEN.finditer(en):
        if m.start() > pos:
            piece += en[pos:m.start()]
            lit += nbytes(en[pos:m.start()])
        pos = m.end()
        if m.group(1):
            piece += "%"
            continue
        lens.append(nbytes(piece))
        hashes.append(djb2(piece))
        piece = ""
        if m.group(3):
            kinds.append("t")
            keys.setdefault(djb2(m.group(3)), len(kinds))
        else:
            kinds.append(KIND[m.group(2)[-1]])
            sp += m.group(2)[-1]
    if not kinds:
        return None
    rest = en[pos:]
    piece += rest
    lit += nbytes(rest)
    lens.append(nbytes(piece))
    hashes.append(djb2(piece))
    plain = re.sub(r"\[KEY:[A-Za-z0-9:]+\]", "", en)
    codes = ",".join(str(plain.count(c)) for c in CODES)
    return {"len": lens, "hash": hashes, "kinds": kinds, "keys": keys, "sp": sp, "c": codes, "lit": lit}


def shape(en, glob=None):
    """What hashes.lua keeps of one English text (see Words.lua's Shape)."""
    s = {"e": text_key(en)}
    if not SPEC.search(en.replace("%%", "")):
        s["x"] = True
        shown = en.replace("%%", "%")
        if shown != en:
            s["p"] = text_key(shown)
        if upper(en) != en:
            s["u"] = text_key(upper(en))
    if glob:
        s["g"] = glob
    if "%" in en or "[KEY:" in en:
        t = pieces(en)
        if t:
            s["t"] = t
    return s


def lua(v):
    if v is True:
        return "true"
    if isinstance(v, int):
        return str(v)
    if isinstance(v, str):
        return lua_str(v)
    if isinstance(v, list):
        return "{ " + ", ".join(lua(x) for x in v) + " }"
    return "{ " + ", ".join((f"{k} = " if re.fullmatch(r"[a-z]+", k) else f"[{lua_str(k)}] = ") + lua(x)
                            for k, x in v.items() if x != {}) + " }"


HEADER = """-- Made by tools/make_dui_data.py from the installed DialogueUI's Locales/enUS.lua. Do not edit; run it again.
-- No English here: for each DialogueUI locale key, hashes of its English (UADD/Hash.lua). Words.lua joins them
-- with our Ukrainian (ns.UA, ui/locale.lua). e: the whole text; x: shown as it is (no % value); u: upper case;
-- p: with %% shown as %; g: the game global DialogueUI shows first, when there is one; t: a template's pieces.
local _, ns = ...
ns.DUI_HASH = {
"""


def hashes_text(enus, locale):
    """The text of hashes.lua: one line per locale.lua key that enUS.lua has, in locale.lua's order."""
    lines = [HEADER]
    for k, _ in locale:
        if k in enus:
            glob, en = enus[k]
            lines.append(f"    [{k}] = {lua(shape(en, glob))},\n")
    lines.append("}\n")
    return "".join(lines)


def build(enus, locale):
    OUT.write_text(hashes_text(enus, locale), encoding="utf-8", newline="\n")
    return [k for k, _ in locale if k in enus]


def write_review(enus, locale):
    have = dict(locale)
    REVIEW.parent.mkdir(exist_ok=True)
    out = ["# DialogueUI's English (EN) and our Ukrainian (UA), by its locale key. Made by tools/make_dui_data.py.",
           "# Change UA lines only (\"text\", G\"id\" or false), then: python3 tools/make_dui_data.py --apply", ""]
    for k, (glob, en) in enus.items():
        out.append(f"[{k}]")
        out.append("EN: " + lua_str(en) + (f"   (in game the game's {glob} first)" if glob else ""))
        out.append("UA: " + have.get(k, ""))
        out.append("")
    REVIEW.write_text("\n".join(out), encoding="utf-8", newline="\n")


def read_review():
    out, k = {}, None
    for line in REVIEW.read_text(encoding="utf-8").splitlines():
        if line.startswith('["') and line.endswith("]"):
            k = line[1:-1]
        elif line.startswith("UA:") and k:
            v = line[3:].strip()
            if v and not re.fullmatch(VALUE, v):
                raise SystemExit(f"{REVIEW}: {k}: not a Lua value: {v}")
            out[k] = v
            k = None
    return out


def apply_review():
    """Puts changed UA lines of the review file into locale.lua; new keys go before the closing brace."""
    want = read_review()
    lines, seen, changed = LOCALE.read_text(encoding="utf-8").split("\n"), set(), 0
    for i, line in enumerate(lines):
        m = UA_LINE.match(line)
        if m and m.group(2) in want:
            seen.add(m.group(2))
            v = want[m.group(2)]
            if v and v != m.group(3):
                lines[i] = m.group(1) + v + m.group(4)
                changed += 1
    new = [f"    [{k}] = {v}," for k, v in want.items() if k not in seen and v]
    if new:
        end = max(i for i, line in enumerate(lines) if line.strip() == "}")
        lines[end:end] = ["", "    -- New in DialogueUI"] + new
    LOCALE.write_text("\n".join(lines), encoding="utf-8", newline="\n")
    print(f"{LOCALE.relative_to(REPO)}: {changed} changed, {len(new)} added")


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--apply", action="store_true", help="put the review file's UA lines into locale.lua first")
    ap.add_argument("--addon", type=Path, default=DEFAULT, help="the installed DialogueUI folder")
    args = ap.parse_args(argv)
    src = args.addon / "Locales" / "enUS.lua"
    if not src.is_file():
        print(f"DialogueUI not found: {src} (use --addon or DIALOGUEUI_DIR)")
        return 1
    if args.apply:
        apply_review()
    enus, bad = read_enus(src)
    locale = read_locale()
    keys = build(enus, locale)
    write_review(enus, locale)
    for b in bad:
        print("warning:", b)
    for k, _ in locale:
        if k not in enus:
            print("warning: not in enUS.lua (DialogueUI dropped it?):", k)
    for k in enus:
        if k not in dict(locale):
            print("note: no Ukrainian yet (fill its UA line in the review file):", k)
    print(f"{OUT.relative_to(REPO)}: {len(keys)} keys; review: {REVIEW.relative_to(REPO)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
