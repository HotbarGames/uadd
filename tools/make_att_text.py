"""Attune's texts for UADD_Attune, without keeping Attune's English in this repo.

Attune has no licence (all rights reserved), so the repo holds only our Ukrainian:
  * ui/locale.lua by Attune's locale keys (ns.UA, ns.UA_CATEGORY, ns.UA_GLUED) and step TYPE values
    (ns.UA_STEP_TYPE); ui/notes.lua by N2_<id>. The game reads the English from AttuneLang (Pairs.lua).
  * data/hashed.lua (made here), by hash (tools/hashtext.py): ns.UA_KEYHASH (locale keys that are English
    prose), ns.UA_GLUEHASH (such a key glued to a number: { shape, uk }, {} where the key's text goes),
    ns.UA_TEXTHASH (English written straight in Attune's code).
Workflow (Attune installed):
  review [ATTUNE_DIR] [--force]  writes local/attune.txt (git-ignored): English (en:) and Ukrainian (uk:)
      side by side. Edit uk: in the KEYHASH, GLUEHASH and TEXTHASH blocks, or add a block
      ("== TEXTHASH", "key: <English or locale key>", "shape: ..." for GLUEHASH, "uk: ..."); the other
      blocks are for reading (edit those in ui/locale.lua or ui/notes.lua).
  build  writes data/hashed.lua from it. Then run tools.test_att_strings and tools/harness/flow_att.py.
Lines are Lua string contents (\\n, \\\\). An empty uk: drops the text; a block whose English is not found
keeps its hash. After an Attune update: review, read the "not in the installed Attune" notes, build.
"""
import os
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import glossary  # noqa: E402
import copy_check  # noqa: E402
import hashtext  # noqa: E402
import luatok  # noqa: E402

REPO = HERE.parent
MODULE = REPO / "UADD_Attune"
LOCALE, NOTES = MODULE / "ui" / "locale.lua", MODULE / "ui" / "notes.lua"
HASHED = MODULE / "data" / "hashed.lua"
REVIEW = REPO / "local" / "attune.txt"
ADDON_DIRS = ["/mnt/c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns",
              "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns"]
CODE = ("Attune.lua", "AttuneData.lua", "AttuneClassQuests.lua", "AttuneQuestGivers.lua", "AttuneQuestRewards.lua")
# Keys that stay English (Words.lua skips them too): the guild line goes to other players, the request
# line is saved into the Survey Log as it is written.
NEVER = {"AttuneCompleteGuild", "ReceivedRequestFrom"}
prose = copy_check.meaningful   # a locale key that reads as English prose goes to UA_KEYHASH, not ns.UA
PLAIN = ("UA", "UA_CATEGORY", "UA_GLUED", "UA_STEP_TYPE", "UA_NOTES")
BY_HASH = ("UA_KEYHASH", "UA_GLUEHASH", "UA_TEXTHASH")
TABLES = PLAIN + BY_HASH
HASH = re.compile(r"^\d+:[0-9a-f]{8}$")

STR = r'"(?:[^"\\]|\\.)*"'
ENUS_LINE = re.compile(r'^Lang\[(' + STR + r"|'(?:[^'\\]|\\.)*')\]\s*=\s*(" + STR + r")\s*;?\s*(?:--.*)?$")
HEADER = ["Attune's texts that have no plain locale key, in Ukrainian, for UADD_Attune (see Words.lua).",
          "Made by tools/make_att_text.py build from local/attune.txt (see the tool for the workflow)."]


def addon_dir(arg=None):
    """Attune's folder: the argument, ATTUNE_DIR, $UADD_ADDONS_DIR/Attune, the game's."""
    if arg:
        return Path(arg)
    if os.environ.get("ATTUNE_DIR"):
        return Path(os.environ["ATTUNE_DIR"])
    base = os.environ.get("UADD_ADDONS_DIR") or next((d for d in ADDON_DIRS if os.path.isdir(d)), ADDON_DIRS[0])
    return Path(base) / "Attune"


# ── Attune's files ───────────────────────────────────────────────────────────────────────────────

def parse_enus(text):
    """({key: English}, [lines not read]). A key set twice: the later line wins, as in AceLocale."""
    out, bad = {}, []
    for n, raw in enumerate(text.splitlines(), 1):
        line = raw.strip()
        if not line.startswith("Lang["):
            continue
        m = ENUS_LINE.match(line)
        if not m:
            bad.append(f"enUS.lua:{n}: cannot read the line")
            continue
        key = next(v for k, v, _ in luatok.tokens(m.group(1)) if k == luatok.STR)
        out[key] = next(v for k, v, _ in luatok.tokens(m.group(2)) if k == luatok.STR)
    return out, bad


def enus(addon):
    p = Path(addon) / "Locales" / "enUS.lua"
    return parse_enus(p.read_text(encoding="utf-8-sig")) if p.is_file() else ({}, [])


def code_strings(addon):
    """Every Lua string in Attune's code files (comments are skipped by the tokenizer)."""
    found = set()
    for name in CODE:
        p = Path(addon) / name
        if p.is_file():
            found.update(v for k, v, _ in luatok.tokens(luatok.read(p)) if k == luatok.STR)
    return found


# ── Our files ────────────────────────────────────────────────────────────────────────────────────

def _value(t, j):
    """(uk, glossary id, next index) for a value at t[j]: "uk" or a glossary link."""
    if t[j][0] == luatok.STR and t[j + 1][:2] != (luatok.SYM, ".."):
        return t[j][1], None, j + 1
    gid = glossary._ref_at(t, j)
    return None, gid, j + (1 if gid is None else 4 if t[j + 1][:2] == (luatok.SYM, "(") else 2)


def read_tables(path):
    """{table: [(key, uk or None, glossary id or None, line, shape or None)]} for the ns.<table> = { ... } of
    TABLES in one file: `["key"] = "uk"`, `["key"] = G"id"`, `KEY = G"id"`, `["key"] = { "shape", "uk" }`.
    A table that is not there is []."""
    out = {name: [] for name in TABLES}
    path = Path(path)
    if not path.is_file():
        return out
    t = list(luatok.tokens(luatok.read(path))) + [(luatok.SYM, "", 0)] * 6
    S = luatok.SYM
    table, depth, i = None, 0, 0
    while i < len(t) - 6:
        if table is None:
            kv = [x[:2] for x in t[i:i + 5]]
            if kv[0] == (luatok.NAME, "ns") and kv[1] == (S, ".") and kv[2][0] == luatok.NAME \
                    and kv[2][1] in TABLES and kv[3:] == [(S, "="), (S, "{")]:
                table, depth, i = kv[2][1], 1, i + 5
                continue
            i += 1
            continue
        if t[i][:2] == (S, "{"):
            depth += 1
        elif t[i][:2] == (S, "}"):
            depth -= 1
            if depth == 0:
                table = None
        elif depth == 1:
            key, j = None, None
            if t[i][:2] == (S, "[") and t[i + 1][0] == luatok.STR and t[i + 2][:2] == (S, "]") \
                    and t[i + 3][:2] == (S, "="):
                key, j = t[i + 1][1], i + 4
            elif t[i][0] == luatok.NAME and t[i + 1][:2] == (S, "=") and t[i - 1][:2] in ((S, ","), (S, "{")):
                key, j = t[i][1], i + 2
            if key is not None:
                shape = None
                if t[j][:2] == (S, "{") and t[j + 1][0] == luatok.STR and t[j + 2][:2] == (S, ","):
                    shape, j = t[j + 1][1], j + 3
                uk, gid, j = _value(t, j)
                if shape is not None and t[j][:2] == (S, "}"):
                    j += 1
                out[table].append((key, uk, gid, t[i][2], shape))
                i = j
                continue
        i += 1
    return out


def our_tables():
    """Every table, from ui/locale.lua, ui/notes.lua and data/hashed.lua."""
    files = [read_tables(p) for p in (LOCALE, NOTES, HASHED)]
    return {name: [row for f in files for row in f[name]] for name in TABLES}


def glue(shape, text):
    """A glued line's English: the shape with the key's text at {}."""
    return shape.replace("{}", text)


# ── The review file ──────────────────────────────────────────────────────────────────────────────

def esc(s):
    return s.replace("\\", "\\\\").replace("\n", "\\n")


def unesc(s):
    return re.sub(r"\\(.)", lambda m: "\n" if m.group(1) == "n" else m.group(1), s)


def english(table, key, shape, lang, by_key, by_text):
    """(key as the review shows it, its English or None) for one row."""
    if table == "UA_TEXTHASH":
        text = by_text.get(key)
        return text, text
    if table in ("UA_KEYHASH", "UA_GLUEHASH"):
        key = by_key.get(key)
    if table == "UA_STEP_TYPE":
        return key, lang.get(key, key)
    en = lang.get(key) if key is not None else None
    return key, glue(shape, en) if en is not None and shape else en


def review_text(tables, lang, strings):
    """(the review file, [notes]): one block per text, the hashed ones first."""
    by_key = {hashtext.key(k): k for k in lang}
    by_text = {hashtext.key(s): s for s in strings}
    out = ["# Attune's English and our Ukrainian, side by side. Made by tools/make_att_text.py review.",
           "# build reads back only the KEYHASH, GLUEHASH and TEXTHASH blocks. Never commit this file.", ""]
    notes = []
    for table in BY_HASH + PLAIN:
        for key, uk, gid, _line, shape in tables[table]:
            name, en = english(table, key, shape, lang, by_key, by_text)
            if en is None:
                notes.append(f"{table} {name or key}: not in the installed Attune")
            out.append(f"== {table} {key}" if table in BY_HASH else f"== {table}")
            out.append("key: " + esc(name or ""))
            if shape is not None:
                out.append("shape: " + esc(shape))
            out += ["en: " + esc(en or ""), "uk: " + esc(f'G"{gid}"' if gid else uk or ""), ""]
    notes += [f"UA {k}: English prose as a key: move it to a KEYHASH block" for k, *_ in tables["UA"] if prose(k)]
    return "\n".join(out), notes


def read_review(text):
    """[(table, hash or None, {field: value})] for the blocks of the hashed tables."""
    out, cur = [], None
    for raw in text.splitlines():
        if raw.startswith("== "):
            parts = raw[3:].split()
            cur = (parts[0], parts[1] if len(parts) > 1 else None, {}) if parts else None
            if cur and cur[0] in BY_HASH:
                out.append(cur)
            continue
        m = re.match(r"^(key|shape|en|uk): ?(.*)$", raw)
        if cur and m:
            cur[2][m.group(1)] = unesc(m.group(2))
    return out


def build_text(blocks):
    """(hashed.lua's text, [problems]) from the review file's hashed blocks."""
    data = {name: {} for name in BY_HASH}
    problems = []
    for table, h, f in blocks:
        name, uk, shape = f.get("key", ""), f.get("uk", ""), f.get("shape")
        k = hashtext.key(name) if name else h
        if not k or not HASH.match(k):
            problems.append(f"{table}: a block with neither key: nor a hash")
            continue
        if not uk:
            continue
        if uk.startswith('G"'):
            problems.append(f"{table} {k}: a glossary link cannot be hashed; write the Ukrainian")
            continue
        if table == "UA_GLUEHASH" and (not shape or "{}" not in shape):
            problems.append(f"{table} {k}: needs a shape: line with {{}} in it")
            continue
        en = glue(shape, "") if table == "UA_GLUEHASH" else f.get("en") or name
        bad = hashtext.check(en, uk) if en else []
        if bad:
            problems.append(f"{table} {k}: " + "; ".join(bad))
        elif k in data[table]:
            problems.append(f"{table} {k}: twice")
        else:
            data[table][k] = (shape, uk)
    lines = ["-- " + h for h in HEADER]
    lines += ["-- No English is kept here, only hashes of it (tools/hashtext.py, the same as UADD.Hash).",
              "local _, ns = ..."]
    for table in BY_HASH:
        lines.append(f"ns.{table} = {{")
        for k in sorted(data[table]):
            shape, uk = data[table][k]
            value = hashtext.lua_str(uk) if shape is None else \
                "{ %s, %s }" % (hashtext.lua_str(shape), hashtext.lua_str(uk))
            lines.append(f"    [{hashtext.lua_str(k)}] = {value},")
        lines.append("}")
    return "\n".join(lines) + "\n", problems


def main(argv):
    args = [a for a in argv[1:] if not a.startswith("--")]
    if not args or args[0] not in ("review", "build"):
        print(__doc__)
        return 2
    if args[0] == "review":
        addon = addon_dir(args[1] if len(args) > 1 else None)
        lang, bad = enus(addon)
        if not lang:
            print(f"Attune not found in {addon} (pass its folder or set ATTUNE_DIR)")
            return 1
        if REVIEW.exists() and "--force" not in argv:
            print(f"{REVIEW.relative_to(REPO)} is there: build it first, or pass --force to write over it")
            return 1
        text, notes = review_text(our_tables(), lang, code_strings(addon))
        REVIEW.parent.mkdir(parents=True, exist_ok=True)
        REVIEW.write_text(text, encoding="utf-8", newline="\n")
        for n in bad + notes:
            print("note:", n)
        print(f"{REVIEW.relative_to(REPO)} written")
        return 0
    if not REVIEW.is_file():
        print(f"{REVIEW.relative_to(REPO)} is not there: run review first")
        return 1
    text, problems = build_text(read_review(REVIEW.read_text(encoding="utf-8")))
    for p in problems:
        print("problem:", p)
    if problems:
        return 1
    HASHED.parent.mkdir(parents=True, exist_ok=True)
    HASHED.write_text(text, encoding="utf-8", newline="\n")
    print(f"{HASHED.relative_to(REPO)} written")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
