"""Auto Potion's texts for UADD_AutoPotion, without keeping its English in this repo.

Auto Potion (folder AutoPotion) has no licence, so it is all rights reserved: the repo holds only our
Ukrainian, keyed by a hash of the English (tools/hashtext.py, the same as UADD.Hash). Its locale keys
are the English sentences themselves, so they are never used as keys here.
Workflow (Auto Potion installed):
  review [ADDON_DIR]  writes or updates local/autopotion.txt (git-ignored): one block per text, its
      English (en:) and our Ukrainian (uk:). A rerun keeps every uk: line already written (by hash).
  build  writes UADD_AutoPotion/data/words.lua (hashes and our Ukrainian only). A uk: line that drops
      or changes a %s slot or a colour code is refused; untranslated texts are listed.
Where the texts come from: every key of Locales/enUS.lua, the key binding names (Bindings.lua) and
their category (Bindings.xml), and the few chat lines code.lua and the slash command print with the
addon's name in front. Its debug log lines stay English. Skipped (never translated): the five macro
names, which must match the macros in the game, and two keys the addon does not show.
Lines are Lua string contents (\\n, \\\\). An empty uk: leaves the text English.
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
DATA = REPO / "UADD_AutoPotion" / "data" / "words.lua"
REVIEW = REPO / "local" / "autopotion.txt"
ADDON_DIRS = ["/mnt/c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns",
              "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns"]
MACROS = ("AutoPotion", "AutoBandage", "AutoFood", "AutoDrink", "AutoManaPotion", "AutoManaGem")
# By hash: keys the addon never shows (an item name it no longer uses, an old header).
UNUSED = {"21:e749cbee", "19:b42bf369"}
# By hash: slots that hold a name as it is (the author, a key name, a macro name).
FREE = {"17:14e192a4": [1], "26:65c53d41": [1], "102:486aa8d6": [1]}
# By hash: keys printed to chat with nothing in front (Chat.lua looks for these alone).
BARE = {"17:bf4baa09"}
GLUED = {"16:75e93e3f"}   # a key printed with the player's own word after it: a template, its slot free
HEADER = ["Auto Potion's texts in Ukrainian, for UADD_AutoPotion (see Words.lua).",
          "Made by tools/make_ap_text.py build from local/autopotion.txt."]
SLOT = re.compile(r"%[-0-9.]*[sd]")


def addon_dir(arg=None):
    """Auto Potion's folder: the argument, $UADD_ADDONS_DIR/AutoPotion, the game's."""
    if arg:
        return Path(arg)
    base = os.environ.get("UADD_ADDONS_DIR") or next((d for d in ADDON_DIRS if os.path.isdir(d)), ADDON_DIRS[0])
    return Path(base) / "AutoPotion"


def _read(path):
    return path.read_text(encoding="utf-8-sig") if path.is_file() else ""


def enus(addon):
    """[English] from Locales/enUS.lua: each L["key"] = "value" (the value is what shows)."""
    p = Path(addon) / "Locales" / "enUS.lua"
    if not p.is_file():
        return []
    t = list(luatok.tokens(luatok.read(p)))
    out = []
    for i in range(len(t) - 5):
        if t[i][:2] == (luatok.NAME, "L") and t[i + 1][1] == "[" and t[i + 2][0] == luatok.STR \
                and t[i + 3][1] == "]" and t[i + 4][1] == "=":
            v = t[i + 5]
            out.append(v[1] if v[0] == luatok.STR else t[i + 2][1])
    return out


def extras(addon):
    """[(kind, English, where)] for texts outside enUS.lua: binding names and category, chat lines."""
    addon, out = Path(addon), []
    for m in re.finditer(r'_G\["BINDING_NAME_MACRO \w+"\]\s*=\s*"([^"]+)"', _read(addon / "Bindings.lua")):
        out.append(("exact", m.group(1), "key binding name"))
    cats = sorted(set(re.findall(r'category="([^"]+)"', _read(addon / "Bindings.xml"))))
    out += [("exact", c, "key binding category") for c in cats]
    code = "\n".join(_read(p) for d in ("", "Core", "FrameXML") for p in sorted((addon / d).glob("*.lua")))
    for m in re.finditer(r'"\|cff[0-9a-f]{6}AutoPotion Error:\|r ([^"]*)"\s*\.\.\s*tostring\(\w+\)\s*\.\.\s*"([^"]*)"',
                         code):
        out.append(("free", m.group(1) + "%s" + m.group(2), "chat, after the addon's red error name"))
    for m in re.finditer(r'"\|cff[0-9a-f]{6}AutoPotion:\|r ([^"]*)"\s*\.\.\s*\(\s*[\w.]+\s+and\s+"(\w+)"\s+or\s+"(\w+)"\s*\)',
                         code):
        out += [("exact", m.group(1) + m.group(n), "chat, /ap debug") for n in (2, 3)]
    return out


def texts(addon):
    """[(hash, kind, English, where)]: kind exact, template, skip; BARE / GLUED ones say so in where."""
    rows, seen = [], set()

    def add(kind, en, where):
        k = hashtext.key(en)
        if k not in seen:
            seen.add(k)
            rows.append((k, kind, en, where))
    for en in enus(addon):
        k = hashtext.key(en)
        if en in MACROS:
            add("skip", en, "macro name: stays English")
        elif k in UNUSED:
            add("skip", en, "not shown by the addon")
        elif k in GLUED:
            add("template", en + "%s", "chat, alone: the player's word in the slot (slot free)")
        else:
            add("template" if SLOT.search(en) else "exact", en,
                "chat, alone" if k in BARE else "locale" + (" (slot free)" if k in FREE else ""))
    for kind, en, where in extras(addon):
        add("template" if kind == "free" else kind, en, where + (" (slot free)" if kind == "free" else ""))
    return rows


# ── The review file ──────────────────────────────────────────────────────────────────────────────

def esc(s):
    return s.replace("\\", "\\\\").replace("\n", "\\n")


def unesc(s):
    return re.sub(r"\\(.)", lambda m: "\n" if m.group(1) == "n" else m.group(1), s)


def read_review(text):
    """{hash: {field: value}} from the review file."""
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
    out = ["# Auto Potion's English and our Ukrainian, side by side. Made by tools/make_ap_text.py review.",
           "# Write the Ukrainian on each uk: line; build reads it back. Never commit this file.", ""]
    for k, kind, en, where in rows:
        uk = old.get(k, {}).get("uk", "")
        out += [f"== {k} {kind}", "where: " + where, "en: " + esc(en)]
        if kind != "skip":
            out.append("uk: " + esc(uk))
        out.append("")
    gone = [k for k in old if k not in {r[0] for r in rows} and old[k].get("uk")]
    return "\n".join(out), gone


# ── The data file ────────────────────────────────────────────────────────────────────────────────

def build_text(blocks):
    """(words.lua's text, [problems], [untranslated])."""
    exact, temps, bare_exact, bare_temps = {}, [], {}, []
    problems, todo = [], []
    for k, f in blocks.items():
        kind, en, uk = f.get("kind"), f.get("en", ""), f.get("uk", "")
        if kind == "skip":
            continue
        if not uk:
            todo.append(f"{k}: {en[:60]}")
            continue
        if hashtext.key(en) != k:
            problems.append(f"{k}: its en: line was changed (the hash no longer fits)")
            continue
        bad = hashtext.check(en, uk)
        if bad:
            problems.append(f"{k}: " + "; ".join(bad))
            continue
        where = f.get("where", "")
        bare = where.startswith("chat, alone")
        if kind == "template":
            free = FREE.get(k) or ([1] if "(slot free)" in where else None)
            try:
                rec = hashtext.template(en, uk, min_lit=1, **({"free": free} if free else {}))
            except ValueError as e:
                problems.append(f"{k}: {e}")
                continue
            (bare_temps if bare else temps).append(rec)
        else:
            (bare_exact if bare else exact)[k] = uk
    text = hashtext.write_lua(exact, temps, "AP", HEADER)
    more = hashtext.write_lua(bare_exact, bare_temps, "AP_BARE").splitlines()
    text += "\n".join(more[more.index("local _, ns = ...") + 1:]) + "\n"
    return text, problems, todo


def main(argv):
    args = [a for a in argv[1:] if not a.startswith("--")]
    if not args or args[0] not in ("review", "build"):
        print(__doc__)
        return 2
    rel = lambda p: p.relative_to(REPO)  # noqa: E731
    if args[0] == "review":
        addon = addon_dir(args[1] if len(args) > 1 else None)
        rows = texts(addon)
        if not rows:
            print(f"Auto Potion not found in {addon} (pass its folder or set UADD_ADDONS_DIR)")
            return 1
        old = read_review(REVIEW.read_text(encoding="utf-8")) if REVIEW.is_file() else {}
        text, gone = review_text(rows, old)
        REVIEW.parent.mkdir(parents=True, exist_ok=True)
        REVIEW.write_text(text, encoding="utf-8", newline="\n")
        for k in gone:
            print(f"note: {k} has Ukrainian but is no longer in the installed Auto Potion (dropped)")
        n = sum(1 for r in rows if r[1] != "skip")
        print(f"{rel(REVIEW)} written: {n} texts to translate, {len(rows) - n} skipped")
        return 0
    if not REVIEW.is_file():
        print(f"{rel(REVIEW)} is not there: run review first")
        return 1
    text, problems, todo = build_text(read_review(REVIEW.read_text(encoding="utf-8")))
    for p in problems:
        print("problem:", p)
    if problems:
        return 1
    DATA.parent.mkdir(parents=True, exist_ok=True)
    DATA.write_text(text, encoding="utf-8", newline="\n")
    print(f"{rel(DATA)} written; {len(todo)} texts still without Ukrainian")
    for t in todo:
        print("  untranslated:", t)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
