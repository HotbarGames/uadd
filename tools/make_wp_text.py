"""Waypoint UI's texts for UADD_WaypointUI.

Waypoint UI has no licence file: all rights reserved (CLAUDE.md "Other addons' texts"). The data keeps only our
Ukrainian, keyed by a hash of the English (UADD/Hash.lua). The English is read from the installed addon: the values
of Locales/enUS.lua (L["KEY"] = "..."), less tools/wp_rules.py STAY. The review files with the English go to
local/waypointui/ (git-ignored, as all of local/).
  review [WP_DIR]  write local/waypointui/01.txt ... A rerun keeps every UA, matched by the hash of the English;
      texts gone from the addon move to a "gone" part at the end.
  build [WP_DIR]   write UADD_WaypointUI/data/text01.lua and text02.lua (always both, so the TOC stays the same).
      A UA with a bad slot, colour code, icon, link or line count is refused, and so is a translated template
      with a slot tools/wp_rules.py has no letter for. With no review files every text stays English.
  stats [WP_DIR]   count texts, translated and left.
"""
import os
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(HERE))
import hashtext as H  # noqa: E402
import luatok  # noqa: E402
import text_lib as L  # noqa: E402
import wp_rules as R  # noqa: E402

LOCAL = ROOT / "local" / "waypointui"
DATA = ROOT / "UADD_WaypointUI" / "data"
FILES, BATCH = 2, 150
MAX_LINES, MAX_BYTES = 280, 24000
ADDON_DIRS = ["/mnt/c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns",
              "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns"]
LOCALE = "Locales/enUS.lua"
TOC = "WaypointUI_Camelot.toc"          # the one Forever loads (Interface 16001)

HEAD = """\
# Waypoint UI's texts, batch {n} of {m}. Made by: python3 tools/make_wp_text.py review
# Never commit this file: Waypoint UI's English is all rights reserved (local/ is git-ignored).
# Write the Ukrainian after "UA: " under each "EN:". An empty UA keeps that text English.
# Do not change the lines that start with "#" or "EN:". The tool finds each text by its English.
# Keep in the UA, as they are in the EN:
#   - slots: %s %d %.1f ... To change their order, number them: %2$s ... %1$s.
#   - colour codes |cffxxxxxx ... |r, icons |T...|t, links |H...|h ... |h.
#   - \\n (a line break): the same number of lines; each line keeps its own slots.
#   - the spaces at the start and the end of each line.
# Slash words stay English as the player types them: /way /waypoint /wp and the words after them.
# Never the middle dot (the Cyrillic font has none): use a comma. No plural marks: units are in our code.
# G"glossary.id" puts in a glossary word (UADD/Glossary.lua), so a later word change is a rebuild.
#   Waypoint G"map.waypoint", Pinpoint G"map.pinpoint", Navigator G"map.navigator", Beam G"map.beam",
#   Pathfinding G"map.pathfinding", Context Icon G"map.context_icon".
# "slots:" says what each slot holds: v a number or coordinates: keep it.  f a name kept as it is (a
#   waypoint, pin or guide step name).  ? not sorted yet: ask the lead, or leave the UA empty.
# "key" is Waypoint UI's locale key: it says where the text shows. Short words for buttons and tabs.
"""
GONE = "# ── Gone: no longer in Waypoint UI. Kept so their Ukrainian is not lost. ──"
DATA_HEAD = [
    "-- Made by tools/make_wp_text.py build from Waypoint UI {ver}. Do not edit: change the review files",
    "-- (local/waypointui/NN.txt) and build again. Only hashes of the English (UADD/Hash.lua) and our",
    "-- Ukrainian. sort: what each slot holds, v value, f free name (tools/wp_rules.py SORTS).",
    "local _, ns = ...",
    "local G = UADD and UADD.Glossary and UADD.Glossary.Text or function() return nil end",
    "local M = ns.WP or { exact = {}, templates = {} }",
    "ns.WP = M",
    "local E, T = M.exact, M.templates",
]
KEYOF = {}                              # English -> locale key, filled by source()


def addon_dir(arg=None):
    if arg:
        return Path(arg)
    base = os.environ.get("UADD_ADDONS_DIR") or next((d for d in ADDON_DIRS if os.path.isdir(d)), ADDON_DIRS[0])
    return Path(base) / "WaypointUI"


def version(addon):
    toc = Path(addon) / TOC
    m = re.search(r"^## Version:\s*(\S+)", toc.read_text(encoding="utf-8-sig", errors="replace"), re.M) \
        if toc.is_file() else None
    return m.group(1) if m else "?"


def locale_pairs(path):
    """[(key, English or None)] of `L["KEY"] = "..."` (or nil) in the enUS file, in file order."""
    t = list(luatok.tokens(luatok.read(path)))
    out = []
    for i in range(len(t) - 5):
        if t[i][:2] == (luatok.NAME, "L") and t[i + 1][:2] == (luatok.SYM, "[") and t[i + 2][0] == luatok.STR \
                and t[i + 3][:2] == (luatok.SYM, "]") and t[i + 4][:2] == (luatok.SYM, "="):
            v = t[i + 5]
            out.append((t[i + 2][1], v[1] if v[0] == luatok.STR else None))
    return out


def source(addon):
    """([(English, kind, section, sub, file)], {English: note}, {reason: count}) in file order, each once."""
    path = Path(addon) / LOCALE
    if not path.is_file():
        return [], {}, {}
    rows, notes, why = [], {}, {}
    for key, en in locale_pairs(path):
        kept, reason = R.keep(key, en)
        if not kept:
            why[reason] = why.get(reason, 0) + 1
            continue
        if en in notes:
            notes[en] += f", {key}"
            continue
        KEYOF[en] = key
        notes[en] = f"key {key}"
        rows.append((en, L.kind_of(en), "enUS", key, LOCALE))
    return rows, notes, why


def sorts(line):
    """[letter or None] per slot of one English line (text_lib.records)."""
    return R.letters(KEYOF.get(line, ""), line)


def slot_line(en):
    parts = [" ".join(x or "?" for x in sorts(line)) for line in en.split("\n")]
    return " | ".join(p for p in parts if p)


def main(argv):
    if len(argv) < 2 or argv[1] not in ("review", "build", "stats"):
        print(__doc__)
        return 2
    addon = addon_dir(argv[2] if len(argv) > 2 else None)
    rows, notes, why = source(addon)
    if not rows:
        print(f"Waypoint UI not found in {addon} (pass its folder or set UADD_ADDONS_DIR)")
        return 1
    if argv[1] == "review":
        sizes, gone = L.review(rows, LOCAL, HEAD, GONE, slot_line, BATCH, note=lambda en: notes.get(en, ""))
        print(f"{len(rows)} texts in {len(sizes)} batches {sizes}; gone with UA: {gone} -> {LOCAL}")
        print("left out: " + ", ".join(f"{k} {v}" for k, v in sorted(why.items())))
        return 0
    from glossary import Glossary
    entries, res = L.build(rows, LOCAL, Glossary(), sorts)
    if argv[1] == "stats":
        print(f"{len(rows)} texts: translated {res['done']}, left {res['left']}, refused {len(res['bad'])}; "
              f"left out: " + ", ".join(f"{k} {v}" for k, v in sorted(why.items())))
        return 0
    head = [h.replace("{ver}", version(addon)) for h in DATA_HEAD]
    L.write_data(entries, DATA, head, FILES, MAX_LINES, MAX_BYTES)
    for n, k, problems in res["bad"]:
        print(f"refused #{n} [{k}]: " + "; ".join(problems))
    print(f"built {res['exact']} exact + {res['templates']} templates from {res['done']} texts; "
          f"untranslated {res['left']}; refused {len(res['bad'])}; loose (not shipped) {len(res['loose'])} -> {DATA}")
    return 1 if res["bad"] else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
