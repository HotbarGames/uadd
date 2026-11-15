"""Auctionator's texts for UADD_Auctionator, without keeping Auctionator's English in this repo.

Auctionator is All Rights Reserved, so the repo holds only our Ukrainian:
  * UADD_Auctionator/ui/locale.lua (ns.UA): keyed by Auctionator's locale key. In the game the module
    reads the English of each key from Auctionator's own AUCTIONATOR_L_<KEY> globals.
  * UADD_Auctionator/ui/text.lua (ns.UA_TEXT, made here): the English Auctionator writes in its code
    (slash command help and chat lines), keyed by a hash of that English (tools/hashtext.py).

Translator workflow (Auctionator installed; the English is read from it, never committed):
  python3 tools/make_auc_text.py review [AUCTIONATOR_DIR]
      writes local/auctionator.txt (git-ignored): every text with its English (en:) and our
      Ukrainian (uk:) side by side. Edit the uk: lines there (or edit ui/locale.lua by hand).
  python3 tools/make_auc_text.py build
      puts the uk: lines back: changed locale keys into ui/locale.lua, the code texts into ui/text.lua.
  Then run python3 -m unittest tools.test_auc_strings and the harness flow (tools/harness/flow_auc.py).
After an Auctionator update: review, fill in the new or changed texts, build.
Lines are Lua string contents: \\n is a line break, \\" a quote. An empty uk: stays English. A key whose
Ukrainian comes from the glossary shows uk: G"id"; change those in ui/locale.lua or the glossary.
Auctionator is read from AUCTIONATOR_DIR, $UADD_ADDONS_DIR/Auctionator or the WoW _forever_ AddOns
folder. Standard library only.
"""
import os
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import hashtext  # noqa: E402
from auc_code_texts import all_code_texts, code_texts  # noqa: E402,F401  (code texts)

REPO = HERE.parent
MODULE = REPO / "UADD_Auctionator"
LOCALE = MODULE / "ui" / "locale.lua"
TEXT_LUA = MODULE / "ui" / "text.lua"
REVIEW = REPO / "local" / "auctionator.txt"
ADDON_DIRS = ["/mnt/c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns",
              "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns"]
# Where Auctionator writes English straight in its code (the slash commands and their chat lines).

STR = r'"(?:[^"\\]|\\.)*"'
ENUS_LINE = re.compile(r'^L\[("[A-Z0-9_]+")\]\s*=\s*(' + STR + r')\s*;?\s*(?:--.*)?$')
UA_LINE = re.compile(r'^(\s*\["([A-Z0-9_]+)"\]\s*=\s*)(' + STR + r')(\s*,.*)$')
G_LINE = re.compile(r'^\s*(?:\["([A-Z0-9_]+)"\]|([A-Z0-9_]+))\s*=\s*G\s*\(?\s*"([^"]*)"')
ESC = {"n": "\n", "t": "\t", "r": "\r", "\\": "\\", '"': '"', "'": "'", "a": "\a", "b": "\b", "f": "\f", "v": "\v"}
HEADER = ["Auctionator's code texts (slash command help and chat lines) in Ukrainian, for UADD_Auctionator.",
          "Made by tools/make_auc_text.py build from local/auctionator.txt (see the tool for the workflow)."]


def addon_dir(arg=None):
    """Auctionator's folder: the argument, AUCTIONATOR_DIR, $UADD_ADDONS_DIR/Auctionator, the game's."""
    if arg:
        return Path(arg)
    if os.environ.get("AUCTIONATOR_DIR"):
        return Path(os.environ["AUCTIONATOR_DIR"])
    base = os.environ.get("UADD_ADDONS_DIR") or next((d for d in ADDON_DIRS if os.path.isdir(d)), ADDON_DIRS[0])
    return Path(base) / "Auctionator"


def unquote(lit):
    """A Lua string literal ("...") as its text."""
    out, i, s = [], 0, lit[1:-1]
    while i < len(s):
        c = s[i]
        if c == "\\" and i + 1 < len(s):
            m = re.match(r"\d{1,3}", s[i + 1:i + 4])
            if m:
                out.append(chr(int(m.group())))
                i += 1 + len(m.group())
                continue
            out.append(ESC.get(s[i + 1], s[i + 1]))
            i += 2
            continue
        out.append(c)
        i += 1
    return "".join(out)


def parse_enus(text):
    """{key: (English as the game shows it, the literal as enUS.lua writes it)}, the later line kept
    for a key set twice (as Auctionator); and the L[...] lines it cannot read."""
    out, bad = {}, []
    for n, raw in enumerate(text.splitlines(), 1):
        line = raw.strip()
        if not line.startswith("L["):
            continue
        m = ENUS_LINE.match(line)
        if not m:
            bad.append(f"enUS.lua:{n}: cannot read this line")
            continue
        out.pop(m.group(1)[1:-1], None)
        out[m.group(1)[1:-1]] = (unquote(m.group(2)).replace("\\n", "\n"), m.group(2)[1:-1])   # AddNewLines
    return out, bad


def read_enus(addon):
    return parse_enus((addon / "Locales" / "enUS.lua").read_text(encoding="utf-8-sig"))


# ── Our Ukrainian ─────────────────────────────────────────────────────────────────────────────

def read_ua(path=LOCALE):
    """{key: ("str", literal as written) or ("glossary", id)} of ns.UA in ui/locale.lua."""
    out, inside = {}, False
    for line in Path(path).read_text(encoding="utf-8").splitlines() if Path(path).is_file() else []:
        if line.startswith("ns.UA = {"):
            inside = True
        elif inside and line.startswith("}"):
            break
        elif inside:
            m, g = UA_LINE.match(line), G_LINE.match(line)
            if m:
                out[m.group(2)] = ("str", m.group(3)[1:-1])
            elif g:
                out[g.group(1) or g.group(2)] = ("glossary", g.group(3))
    return out


def read_text_lua(path=TEXT_LUA):
    """{key or template id: [Ukrainian pieces]} of ui/text.lua (an exact text is one piece)."""
    return parse_text_lua(Path(path).read_text(encoding="utf-8") if Path(path).is_file() else "")


def parse_text_lua(text):
    out = {}
    for line in text.splitlines():
        m = re.match(r'^\s*\["(\d+:[0-9a-f]{8})"\] = (' + STR + r'),$', line)
        if m:
            out[m.group(1)] = [unquote(m.group(2))]
            continue
        m = re.match(r'^\s*\{ id = (' + STR + r'), .*?\buk = \{ ', line)
        if m:
            pieces, pos = [], m.end()
            for p in re.finditer(r'\s*(?:(' + STR + r')|(\d+))\s*(,|\})', line[pos:]):
                pieces.append(unquote(p.group(1)) if p.group(1) else int(p.group(2)))
                if p.group(3) == "}":
                    break
            out[unquote(m.group(1))] = pieces
    return out


def uk_text(en, pieces):
    """Our Ukrainian as one text, its slots written as in the English (%s, or %2$s out of order)."""
    specs = [m.group(0) for m in hashtext.SLOT.finditer(en) if m.group(0) != "%%"]
    nums = [p for p in pieces if isinstance(p, int)]
    in_order = nums == list(range(1, len(nums) + 1))
    out = []
    for p in pieces:
        if isinstance(p, int):
            out.append(specs[p - 1] if in_order else "%" + str(p) + "$" + specs[p - 1][1:])
        else:
            out.append(p.replace("%", "%%") if specs else p)
    return "".join(out)


def esc(text):
    return hashtext.lua_str(text)[1:-1]


# ── review / build ────────────────────────────────────────────────────────────────────────────

def review_text(addon):
    enus, bad = read_enus(addon)
    ua, made = read_ua(), read_text_lua()
    lines = ["# Auctionator texts: its English (en:) and our Ukrainian (uk:). Made by tools/make_auc_text.py",
             "# review; not tracked by git. Edit the uk: lines, then run tools/make_auc_text.py build.", ""]
    for key, (_, raw) in enus.items():
        kind, val = ua.get(key, ("str", ""))
        lines += [f"[KEY {key}]", "en: " + raw, "uk: " + (f'G"{val}"' if kind == "glossary" else val), ""]
    for rel, en in all_code_texts(addon):
        k = hashtext.key(en)
        uk = uk_text(en, made[k]) if k in made else ""
        lines += [f"[CODE {k} {rel}]", "en: " + esc(en), "uk: " + esc(uk), ""]
    return "\n".join(lines), bad


def parse_review(text):
    """[(kind, name, English, Ukrainian literal)] of a review file."""
    out, cur = [], None
    for line in text.splitlines():
        m = re.match(r"^\[(KEY|CODE) ([^\]\s]+)", line)
        if m:
            cur = [m.group(1), m.group(2), None, None]
            out.append(cur)
        elif cur and line.startswith("en: "):
            cur[2] = line[4:]
        elif cur and line.startswith("uk: "):
            cur[3] = line[4:]
    return [tuple(e) for e in out if e[2] is not None and e[3] is not None]


def build_text_lua(entries):
    """ui/text.lua's text from the CODE entries of a review file."""
    exact, templates = {}, []
    for kind, _, en_raw, uk_raw in entries:
        en, uk = unquote('"' + en_raw + '"'), unquote('"' + uk_raw + '"')
        if kind != "CODE" or not uk or uk == en:
            continue
        if hashtext.is_template(en):
            templates.append(hashtext.template(en, uk, id=hashtext.key(en)))
        else:
            exact[hashtext.key(en)] = uk
    return hashtext.write_lua(exact, templates, "UA_TEXT", HEADER)


def build_locale(entries, text):
    """ui/locale.lua's text with the KEY entries' Ukrainian put in, and warnings."""
    want = {name: uk for kind, name, _, uk in entries if kind == "KEY"}
    lines, seen, warn = text.split("\n"), set(), []
    for i, line in enumerate(lines):
        m, g = UA_LINE.match(line), G_LINE.match(line)
        if m and m.group(2) in want:
            seen.add(m.group(2))
            if want[m.group(2)] != m.group(3)[1:-1]:
                lines[i] = m.group(1) + '"' + want[m.group(2)] + '"' + m.group(4)
        elif g and (g.group(1) or g.group(2)) in want:
            key = g.group(1) or g.group(2)
            seen.add(key)
            if want[key] != f'G"{g.group(3)}"':
                warn.append(f"{key}: its Ukrainian is a glossary word: change it in ui/locale.lua by hand")
    new = [f'    ["{k}"] = "{uk}",' for k, uk in want.items() if k not in seen and uk and not uk.startswith('G"')]
    if new:
        end = lines.index("}", next(i for i, l in enumerate(lines) if l.startswith("ns.UA = {")))
        lines[end:end] = ["", "    -- New (tools/make_auc_text.py build): move each to its place above"] + new
    return "\n".join(lines), warn


def main(argv):
    if len(argv) < 2 or argv[1] not in ("review", "build"):
        print(__doc__)
        return 2
    if argv[1] == "review":
        addon = addon_dir(argv[2] if len(argv) > 2 else None)
        if not (addon / "Locales" / "enUS.lua").is_file():
            print(f"Auctionator not found in {addon} (give its folder, or set AUCTIONATOR_DIR)")
            return 1
        text, bad = review_text(addon)
        REVIEW.parent.mkdir(parents=True, exist_ok=True)
        REVIEW.write_text(text, encoding="utf-8", newline="\n")
        for b in bad:
            print("warning:", b)
        print(f"{REVIEW.relative_to(REPO)}: written")
        return 0
    entries = parse_review(REVIEW.read_text(encoding="utf-8"))
    TEXT_LUA.write_text(build_text_lua(entries), encoding="utf-8", newline="\n")
    text, warn = build_locale(entries, LOCALE.read_text(encoding="utf-8"))
    LOCALE.write_text(text, encoding="utf-8", newline="\n")
    for w in warn:
        print("warning:", w)
    print(f"{TEXT_LUA.relative_to(REPO)} and {LOCALE.relative_to(REPO)}: written")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
