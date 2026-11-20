"""What's Training?'s texts for UADD_WhatsTraining.

What's Training? is MIT, but the module keeps the same small data as the other hash-keyed modules: our
Ukrainian keyed by a hash of the English (UADD/Hash.lua), no English at runtime. The English is read from
the installed addon: the enUS tables of Localization.lua and LocalizationFallbacks.lua (only keys that a
file live on Forever uses), plus the lines it glues in code (tools/wt_rules.py CODE).
Left out: game names (factions FACTION_*, Alliance, Horde, the profession ranks, Merchant's Favor):
UALL Forever's to name (lesson 9).
  review [WT_DIR]  write local/whatstraining/01.txt ... (about 150 texts each). A rerun keeps every UA,
      matched by the hash of the English; texts gone from the addon move to a "gone" part at the end.
  build [WT_DIR]   write UADD_WhatsTraining/data/text01.lua ... text04.lua (always all 4, so the TOC
      stays the same). A UA with a bad slot, colour code, icon, link or line count is refused, and so is a
      translated template with a slot tools/wt_rules.py has no sort for. Counts are printed.
"""
import os
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import luatok  # noqa: E402
import text_lib as L  # noqa: E402
import wt_rules as R  # noqa: E402

ROOT = HERE.parent
LOCAL = ROOT / "local" / "whatstraining"
DATA = ROOT / "UADD_WhatsTraining" / "data"
FILES, BATCH = 4, 150
MAX_LINES, MAX_BYTES = 280, 24000
ADDON_DIRS = ["/mnt/c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns",
              "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns"]
SOURCES = ("Localization.lua", "LocalizationFallbacks.lua")
# Not loaded on Forever (classic only), or not code that shows text.
DEAD = {"Localization.lua", "LocalizationFallbacks.lua", "Crafting/SkillLines.lua", "Crafting/SkillsTab.lua",
        "Crafting/ProfessionTabs.lua"}
GAME = {"Alliance", "Horde", "Journeyman", "Expert", "Artisan", "MERCHANTS_FAVOR"}
USE = re.compile(r"\bL\.([A-Za-z_][A-Za-z0-9_]*)|\bL\[\s*\"([^\"]+)\"\s*\]")

HEAD = """\
# What's Training?'s texts, batch {n} of {m}. Made by: python3 tools/make_wt_text.py review
# Write the Ukrainian after "UA: " under each "EN:". An empty UA keeps that text English.
# Do not change the lines that start with "#" or "EN:". The tool finds each text by its English.
# Keep in the UA, as they are in the EN:
#   - slots: %s %d %.1f ... To change their order, number them: %2$s ... %1$s.
#   - colour codes |cffxxxxxx ... |r, icons |T...|t, links |H...|h ... |h.
#   - \\n (a line break): the same number of lines; each line keeps its own slots.
#   - the spaces at the start and the end of each line.
# Never the middle dot "·" (the Cyrillic font has none): use a comma. "|4one:many;" is the English
# plural: write {{один|два|п'ять}} instead (only in a line with %d or %f).
# G"glossary.id" puts in a glossary word (UADD/Glossary.lua), so a later word change is a rebuild.
# "slots:" says what each slot holds: v a number, money or count: keep it.  n a game name (zone, NPC,
#   faction, spell): UALL Forever gives it in Ukrainian.  t another What's Training? text.
#   ? not sorted yet: ask the lead, or leave the UA empty.
# Game names (zones, NPCs, spells, factions) are never written here: they come in through the slots.
# Glossary: «Класовий тренер» (class trainer), «закляття» (spell).
"""
GONE = "# ── Gone: no longer in What's Training?. Kept so their Ukrainian is not lost. ──"
DATA_HEAD = [
    "-- Made by tools/make_wt_text.py build from What's Training? {ver}. Do not edit: change the review files",
    "-- (local/whatstraining/NN.txt) and build again. Only hashes of the English (UADD/Hash.lua) and our",
    "-- Ukrainian. sort: what each slot holds, v value, n game name, t our text.",
    "local _, ns = ...",
    "local G = UADD and UADD.Glossary and UADD.Glossary.Text or function() return nil end",
    "local M = ns.WT or { exact = {}, templates = {} }",
    "ns.WT = M",
    "local E, T = M.exact, M.templates",
]


def addon_dir(arg=None):
    if arg:
        return Path(arg)
    base = os.environ.get("UADD_ADDONS_DIR") or next((d for d in ADDON_DIRS if os.path.isdir(d)), ADDON_DIRS[0])
    return Path(base) / "WhatsTraining"


def version(addon):
    toc = Path(addon) / "WhatsTraining.toc"
    m = re.search(r"^## Version:\s*(\S+)", toc.read_text(encoding="utf-8-sig", errors="replace"), re.M) \
        if toc.is_file() else None
    return m.group(1) if m else "?"


def enus(path):
    """[(key, English, line)] of the `enUS = { KEY = "..." }` table of one locale file."""
    t = list(luatok.tokens(luatok.read(path)))
    out, i = [], 0
    while i < len(t) - 2 and not (t[i][:2] == (luatok.NAME, "enUS") and t[i + 1][1] == "=" and t[i + 2][1] == "{"):
        i += 1
    depth, i = 1, i + 3
    while i < len(t) and depth:
        if t[i][:2] == (luatok.SYM, "{"):
            depth += 1
        elif t[i][:2] == (luatok.SYM, "}"):
            depth -= 1
        elif depth == 1 and t[i][0] == luatok.NAME and i + 2 < len(t) and t[i + 1][1] == "=" \
                and t[i + 2][0] == luatok.STR:
            out.append((t[i][1], t[i + 2][1], t[i][2]))
            i += 2
        i += 1
    return out


def used(addon):
    """Every locale key a live file names (L.KEY or L["KEY"])."""
    keys = set()
    for p in Path(addon).rglob("*.lua"):
        rel = p.relative_to(addon).as_posix()
        if rel in DEAD or rel.startswith("libs/"):
            continue
        for m in USE.finditer(p.read_text(encoding="utf-8", errors="replace")):
            keys.add(m.group(1) or m.group(2))
    return keys


def source(addon):
    """([(English, kind, section, sub, file)], {English: key}) in source order, each English once."""
    rows, names, live = [], {}, used(addon)
    for rel in SOURCES:
        path = Path(addon) / rel
        if not path.is_file():
            continue
        for key, en, _ in enus(path):
            if key in GAME or key.startswith("FACTION_") or key not in live or not en.strip() or en in names:
                continue
            names[en] = key
            rows.append((en, L.kind_of(en), "enUS", "", rel))
    if rows:
        for en, where in R.CODE:
            if en not in names:
                names[en] = where
                rows.append((en, L.kind_of(en), "glued in code", "", "code"))
    return rows, names


def slot_line(en):
    parts = [" ".join(x or "?" for x in R.sorts(line)) for line in en.split("\n")]
    return " | ".join(parts) if any(parts) else ""


def main(argv):
    if len(argv) < 2 or argv[1] not in ("review", "build"):
        print(__doc__)
        return 2
    addon = addon_dir(argv[2] if len(argv) > 2 else None)
    rows, names = source(addon)
    if not rows:
        print(f"What's Training? not found in {addon} (pass its folder or set UADD_ADDONS_DIR)")
        return 1
    if argv[1] == "review":
        sizes, gone = L.review(rows, LOCAL, HEAD, GONE, slot_line, BATCH, note=lambda en: names.get(en, ""))
        print(f"{len(rows)} texts in {len(sizes)} batches {sizes}; gone with UA: {gone} -> {LOCAL}")
        return 0
    from glossary import Glossary
    entries, res = L.build(rows, LOCAL, Glossary(), R.sorts)
    head = [h.replace("{ver}", version(addon)) for h in DATA_HEAD]
    L.write_data(entries, DATA, head, FILES, MAX_LINES, MAX_BYTES)
    for n, k, problems in res["bad"]:
        print(f"refused #{n} [{k}]: " + "; ".join(problems))
    print(f"built {res['exact']} exact + {res['templates']} templates from {res['done']} texts; "
          f"untranslated {res['left']}; refused {len(res['bad'])}; loose (not shipped) {len(res['loose'])} -> {DATA}")
    return 1 if res["bad"] else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
