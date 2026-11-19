"""Bagnon's texts for UADD_Bagnon, without keeping its English in this repo.

Bagnon (folders Bagnon, BagBrother, Bagnon_Config, Bagnon_Bank, Bagnon_GuildBank) is all rights
reserved: the repo holds only our Ukrainian, keyed by Bagnon's own locale keys. Its English lives in
BagBrother: core/localization/en.lua (the bag, bank and guild bank windows; AceLocale app "Bagnon") and
config/localization/en.lua (the settings pages; app "Bagnon_Config", with the FAQ list of the Help page).
Workflow (Bagnon installed):
  review [BAGBROTHER_DIR]  writes or updates local/bagnon.txt (git-ignored): one block per text, its
      English (en:) and our Ukrainian (uk:). A rerun keeps every uk: line already written (by key).
  build  writes UADD_Bagnon/data/core.lua, config.lua and faq.lua (locale keys, our Ukrainian, and a hash of the English each
      line was made from, so the game uses a line only while Bagnon's English is the same). A uk: line that drops
      or changes a %s slot or a colour code, or (FAQ) drops the word ADDON, is refused; untranslated
      texts are listed. A key with a %s slot that is not sorted below (FREE, VALUE, STAY, SKIP) is refused.
Kinds: exact, template (has %s), stay (shown, but must stay English: glued to a word of the game) and
skip (not shown). Lines are Lua string contents (\\n, \\\\). An empty uk: leaves the text English.
"""
import os
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import hashtext  # noqa: E402
import luatok  # noqa: E402

REPO = HERE.parent
DATA = REPO / "UADD_Bagnon" / "data"           # core.lua, config.lua, faq.lua
REVIEW = REPO / "local" / "bagnon.txt"
ADDON_DIRS = ["/mnt/c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns",
              "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns"]
FILES = (("core", "core/localization/en.lua"), ("config", "config/localization/en.lua"))

# What each %s holds (docs: "No half translations"). By "table:key".
# FREE: a name as it is: the owner of the bags (a character or the guild), the addon's name, a
# character's name in the delete question.
FREE = {"core:TitleBags": [1], "core:TitleBank": [1], "core:TitleVault": [1], "core:ResetConfirm": [1],
        "core:ConfirmDelete": [1], "config:FrameOptionsDescription": [1], "config:SlotOptionsDescription": [1],
        "config:HelpDescription": [1], "config:PatronsDescription": [1]}
# VALUE: a number, or money (GetMoneyString).
VALUE = {"core:NumWithdraw": "a number", "core:NumDeposit": "a number",
         "core:CannotPurchaseVault": "money", "core:PurchaseVault": "money"}
# STAY: shown, but glued to the game's own English word (or to its NONE in the slot): stays English.
STAY = {"core:Drag": "glued after the game's word for search in the title bar (title.lua)",
        "core:NumAllowed": "glued after the game's word for withdraw (guildMoney.lua)",
        "core:NumRemaining": "its slot can hold the game's English NONE (guildTab.lua)"}
# SKIP: Bagnon never shows these.
SKIP = {"core:OutOfDate": "not used by Bagnon", "core:InvalidVersion": "not used by Bagnon"}
WHERE = {"core": "Bagnon window (bags, bank, guild bank, menus, tooltips)",
         "config": "Bagnon settings (Bagnon_Config)",
         "faq": "Bagnon settings, Help page FAQ: keep the word ADDON as it is (Bagnon puts its name there)"}
HEADER = ["Bagnon's texts in Ukrainian, for UADD_Bagnon (see Locale.lua): Bagnon's locale keys and our",
          "Ukrainian only. Made by tools/make_bgn_text.py build from local/bagnon.txt. Do not edit."]
SLOT = re.compile(r"%[-0-9.]*[sd]")


def addon_dir(arg=None):
    """BagBrother's folder: the argument, $UADD_ADDONS_DIR/BagBrother, the game's."""
    if arg:
        return Path(arg)
    base = os.environ.get("UADD_ADDONS_DIR") or next((d for d in ADDON_DIRS if os.path.isdir(d)), ADDON_DIRS[0])
    return Path(base) / "BagBrother"


def locale(path):
    """({key: English}, [FAQ English], [keys whose value is not a plain string]) of one en.lua."""
    if not path.is_file():
        return {}, [], []
    t = list(luatok.tokens(luatok.read(path)))
    out, faq, other = {}, [], []
    for i in range(len(t) - 4):
        if t[i][:2] != (luatok.NAME, "L") or t[i + 1][1] != "." or t[i + 2][0] != luatok.NAME or t[i + 3][1] != "=":
            continue
        if i and t[i - 1][1] == ".":
            continue
        k, v = t[i + 2][1], t[i + 4]
        if k == "FAQ" and v[1] == "{":
            j = i + 5
            while j < len(t) and t[j][1] != "}":
                if t[j][0] == luatok.STR:
                    faq.append(t[j][1])
                j += 1
        elif v[0] == luatok.STR and not (i + 5 < len(t) and t[i + 5][1] == "."):
            out[k] = v[1]
        else:
            other.append(k)
    return out, faq, other


def texts(bb):
    """[(key, kind, English, where)] and [problems]: every text of both tables and the FAQ."""
    rows, problems = [], []
    for table, rel in FILES:
        found, faq, other = locale(Path(bb) / rel)
        for k in other:
            print(f"note: {table}:{k} is not a plain string (the game's own word): left alone")
        for k, en in found.items():
            key = f"{table}:{k}"
            where = WHERE[table]
            if key in SKIP:
                rows.append((key, "skip", en, SKIP[key]))
                continue
            if key in STAY:
                rows.append((key, "stay", en, "stays English: " + STAY[key]))
                continue
            if SLOT.search(en):
                if key in FREE:
                    where += " (slot free: a name as it is)"
                elif key in VALUE:
                    where += f" (slot: {VALUE[key]})"
                else:
                    problems.append(f"{key}: a %s slot nobody sorted (add it to FREE, VALUE, STAY or SKIP)")
                rows.append((key, "template", en, where))
            else:
                rows.append((key, "exact", en, where))
        for n, en in enumerate(faq, 1):
            rows.append((f"faq:{n}", "exact", en, WHERE["faq"] + (" (question)" if n % 2 else " (answer)")))
    known = {r[0] for r in rows}
    for d in (FREE, VALUE, STAY, SKIP):
        for k in d:
            if rows and k not in known:
                problems.append(f"{k}: sorted here but no longer in the installed Bagnon")
    return rows, problems


# ── The review file ──────────────────────────────────────────────────────────────────────────────

def esc(s):
    return s.replace("\\", "\\\\").replace("\n", "\\n")


def unesc(s):
    return re.sub(r"\\(.)", lambda m: "\n" if m.group(1) == "n" else m.group(1), s)


def read_review(text):
    """{key: {field: value}} from the review file."""
    out, cur = {}, None
    for raw in text.splitlines():
        if raw.startswith("== "):
            parts = raw[3:].split()
            cur = out.setdefault(parts[0], {"kind": parts[1] if len(parts) > 1 else "exact"}) if parts else None
            continue
        m = re.match(r"^(where|en|uk): ?(.*)$", raw)
        if cur is not None and m:
            cur[m.group(1)] = unesc(m.group(2))
    return out


def review_text(rows, old):
    out = ["# Bagnon's English and our Ukrainian, side by side. Made by tools/make_bgn_text.py review.",
           "# Write the Ukrainian on each uk: line; build reads it back. Never commit this file.",
           "# Kinds: exact, template (keep each %s), stay and skip (no uk: line: they stay English).", ""]
    for k, kind, en, where in rows:
        uk = old.get(k, {}).get("uk", "")
        out += [f"== {k} {kind}", "where: " + where, "en: " + esc(en)]
        if kind in ("exact", "template"):
            out.append("uk: " + esc(uk))
        out.append("")
    gone = [k for k in old if k not in {r[0] for r in rows} and old[k].get("uk")]
    return "\n".join(out), gone


# ── The data file ────────────────────────────────────────────────────────────────────────────────

def build_text(blocks):
    """({table: its data file's text}, [problems], [untranslated])."""
    tables = {"core": {}, "config": {}, "faq": {}}
    problems, todo, src = [], [], {}
    for k, f in blocks.items():
        kind, en, uk = f.get("kind"), f.get("en", ""), f.get("uk", "")
        if kind not in ("exact", "template"):
            continue
        table, _, name = k.partition(":")
        if table not in tables or not name:
            problems.append(f"{k}: not a key of Bagnon's tables")
            continue
        if not uk:
            todo.append(f"{k}")
            continue
        if kind == "template" and k not in FREE and k not in VALUE:
            problems.append(f"{k}: a %s slot nobody sorted (FREE or VALUE)")
            continue
        bad = hashtext.check(en, uk)
        if table == "faq" and "ADDON" in en and "ADDON" not in uk:
            bad.append("the word ADDON is missing (Bagnon puts its name there)")
        if re.search(r"[A-Za-z]{3,}", re.sub(r"ADDON|%[-0-9.]*[sd]|\|c\w{8}|\|[rTtHhn][^|]*", "", uk)) \
                and not re.search(r"[\u0400-\u04ff]", uk):
            bad.append("no Ukrainian letters in uk:")
        if bad:
            problems.append(f"{k}: " + "; ".join(bad))
            continue
        tables[table][int(name) if table == "faq" else name] = uk
        src[k] = hashtext.key(en)
    files = {}
    for table in ("core", "config", "faq"):
        # One file per table (the size budget): its words, then the hash of the English each line was
        # made from (Locale.lua uses a line only while it still fits). All merge into ns.BGN.
        lines = ["-- " + h for h in HEADER] + ["local _, ns = ...", "local B = ns.BGN or { src = {}, free = {} }",
                                               "ns.BGN = B", f"B.{table} = {{"]
        for name in sorted(tables[table], key=lambda n: (str(type(n)), n)):
            key = f"[{name}]" if table == "faq" else f"[{hashtext.lua_str(name)}]"
            lines.append(f"    {key} = {hashtext.lua_str(tables[table][name])},")
        lines.append("}")
        if table == "core":
            for k in sorted(FREE):
                lines.append(f"B.free[{hashtext.lua_str(k)}] = true")
        for k in sorted(s for s in src if s.startswith(table + ":")):
            lines.append(f"B.src[{hashtext.lua_str(k)}] = {hashtext.lua_str(src[k])}")
        lines.append("")
        files[table] = "\n".join(lines)
    return files, problems, todo


def main(argv):
    args = [a for a in argv[1:] if not a.startswith("--")]
    if not args or args[0] not in ("review", "build"):
        print(__doc__)
        return 2
    rel = lambda p: p.relative_to(REPO)  # noqa: E731
    if args[0] == "review":
        bb = addon_dir(args[1] if len(args) > 1 else None)
        rows, problems = texts(bb)
        if not rows:
            print(f"BagBrother not found in {bb} (pass its folder or set UADD_ADDONS_DIR)")
            return 1
        for p in problems:
            print("problem:", p)
        if problems:
            return 1
        old = read_review(REVIEW.read_text(encoding="utf-8")) if REVIEW.is_file() else {}
        text, gone = review_text(rows, old)
        REVIEW.parent.mkdir(parents=True, exist_ok=True)
        REVIEW.write_text(text, encoding="utf-8", newline="\n")
        for k in gone:
            print(f"note: {k} has Ukrainian but is no longer in the installed Bagnon (dropped)")
        n = sum(1 for r in rows if r[1] in ("exact", "template"))
        by = {t: sum(1 for r in rows if r[0].startswith(t + ":") and r[1] in ("exact", "template"))
              for t in ("core", "config", "faq")}
        print(f"{rel(REVIEW)} written: {n} texts to translate ({by['core']} core, {by['config']} config, "
              f"{by['faq']} FAQ), {len(rows) - n} stay English or are not shown")
        return 0
    if not REVIEW.is_file():
        print(f"{rel(REVIEW)} is not there: run review first")
        return 1
    files, problems, todo = build_text(read_review(REVIEW.read_text(encoding="utf-8")))
    for p in problems:
        print("problem:", p)
    if problems:
        return 1
    DATA.mkdir(parents=True, exist_ok=True)
    for table, text in files.items():
        (DATA / f"{table}.lua").write_text(text, encoding="utf-8", newline="\n")
    print(f"{rel(DATA)}/{{{','.join(files)}}}.lua written; {len(todo)} texts still without Ukrainian")
    for t in todo[:10]:
        print("  untranslated:", t)
    if len(todo) > 10:
        print(f"  ... and {len(todo) - 10} more")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
