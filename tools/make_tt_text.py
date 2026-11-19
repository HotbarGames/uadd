"""TomTom's texts for UADD_TomTom.

TomTom is All Rights Reserved (CLAUDE.md "Other addons' texts"): the data keeps only our Ukrainian, keyed by a
hash of the English (UADD/Hash.lua). The English is read from the installed addon: the keys of
i18n/Localization.enUS.lua (all are live), less tools/tt_rules.py STAY, plus the texts it shows from its own code
(tools/tt_rules.py CODE). The review files with the English go to local/tomtom/ (git-ignored).
  review [TT_DIR]  write local/tomtom/01.txt ... (about 150 texts each). A rerun keeps every UA, matched by the
      hash of the English; texts gone from the addon move to a "gone" part at the end.
  build [TT_DIR]   write UADD_TomTom/data/text01.lua ... text03.lua (always all 3, so the TOC stays the same).
      A UA with a bad slot, colour code, icon, link or line count is refused, and so is a translated template
      with a slot tools/tt_rules.py has no sort for, or one that splits a group (GROUPS). Templates whose slots are only values or free names and
      whose Ukrainian has no plural also go to the swap list (put into TomTom.L itself). Texts TomTom also
      shows in its data feed go to the keep list (never put into TomTom.L). Counts are printed.
"""
import os
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import hashtext as H  # noqa: E402
import luatok  # noqa: E402
import text_lib as L  # noqa: E402
import tt_rules as R  # noqa: E402

ROOT = HERE.parent
LOCAL = ROOT / "local" / "tomtom"
DATA = ROOT / "UADD_TomTom" / "data"
FILES, BATCH = 3, 150
MAX_LINES, MAX_BYTES = 280, 24000
ADDON_DIRS = ["/mnt/c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns",
              "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns"]
LOCALE = "i18n/Localization.enUS.lua"
XML_HINT = re.compile(r'key="defaultText"\s+value="([^"]*)"')

HEAD = """\
# TomTom's texts, batch {n} of {m}. Made by: python3 tools/make_tt_text.py review
# Never commit this file: TomTom's English is all rights reserved (local/ is git-ignored).
# Write the Ukrainian after "UA: " under each "EN:". An empty UA keeps that text English.
# Do not change the lines that start with "#" or "EN:". The tool finds each text by its English.
# Keep in the UA, as they are in the EN:
#   - slots: %s %d %.1f ... To change their order, number them: %2$s ... %1$s.
#   - colour codes |cffxxxxxx ... |r, icons |T...|t, links |H...|h ... |h.
#   - \\n (a line break): the same number of lines; each line keeps its own slots.
#   - the spaces at the start and the end of each line.
# Command words stay English, as the player types them: /way /tway /cway /ttpaste and the words after them
#   (arrow, block, list, local, reset, all, away, not, clear, remove, save, load, toggle, minimap, help),
#   and <x> <y>. Write [desc] as [опис], [title] as [назва], <zone> as <зона>. Only the words around them
#   are ours. A help line whose coloured part is only command words stays English (tools/tt_rules.py STAY).
# Never the middle dot (the Cyrillic font has none): use a comma. A plural (yards, miles, characters,
# waypoints) is written {{один|два|п'ять}} (only in a line with %d or %f).
# G"glossary.id" puts in a glossary word (UADD/Glossary.lua), so a later word change is a rebuild.
# "slots:" says what each slot holds: v a number, a distance or coordinates: keep it.  n a game name (zone,
#   quest): UALL Forever gives it in Ukrainian.  t another TomTom text of ours (a colour word).
#   f a name kept as it is (a waypoint title, a profile or page name, a player, an addon).
#   w only spaces (an indent): keep it.  [f - v] slots that touch, read as one (tools/tt_rules.py GROUPS):
#   keep them together, in order, with nothing between.  ? not sorted yet: ask the lead, or leave the UA empty.
# "max N" is the longest Ukrainian that fits there, in letters: keep it shorter.
# "where" says where it shows. Short words for buttons, the world map header and the arrow distance.
"""
GONE = "# ── Gone: no longer in TomTom. Kept so their Ukrainian is not lost. ──"
DATA_HEAD = [
    "-- Made by tools/make_tt_text.py build from TomTom {ver}. Do not edit: change the review files",
    "-- (local/tomtom/NN.txt) and build again. Only hashes of the English (UADD/Hash.lua) and our",
    "-- Ukrainian. sort: what each slot holds, v value, f free name, n game name, t our text, w spaces, or a",
    "-- recipe \"a SEP b\" for slots that touch (tools/tt_rules.py GROUPS).",
    "-- S: templates put into TomTom.L itself (slots v and f only, no plural). K: texts that stay English in",
    "-- TomTom.L because they also show in another addon's bar (its font has no Ukrainian letters).",
    "local _, ns = ...",
    "local G = UADD and UADD.Glossary and UADD.Glossary.Text or function() return nil end",
    "local M = ns.TT or { exact = {}, templates = {}, swap = {}, keep = {} }",
    "ns.TT = M",
    "local E, T, S, K = M.exact, M.templates, M.swap, M.keep",
]
FEED = "data feed"


def addon_dir(arg=None):
    if arg:
        return Path(arg)
    base = os.environ.get("UADD_ADDONS_DIR") or next((d for d in ADDON_DIRS if os.path.isdir(d)), ADDON_DIRS[0])
    return Path(base) / "TomTom"


def version(addon):
    toc = Path(addon) / "TomTom.toc"
    m = re.search(r"^## Version:\s*(\S+)", toc.read_text(encoding="utf-8-sig", errors="replace"), re.M) \
        if toc.is_file() else None
    return m.group(1) if m else "?"


def locale_keys(path):
    """[English] of `L["..."]`-style keys in the enUS file, in file order."""
    t = list(luatok.tokens(luatok.read(path)))
    out = []
    for i in range(len(t) - 2):
        if t[i][:2] == (luatok.SYM, "[") and t[i + 1][0] == luatok.STR and t[i + 2][:2] == (luatok.SYM, "]"):
            out.append(t[i + 1][1])
    return out


def uses(addon):
    """{English: [(file, line)]} of every literal L["..."] in core/ and modules/."""
    out = {}
    for p in sorted(list((Path(addon) / "core").rglob("*.lua")) + list((Path(addon) / "modules").rglob("*.lua"))):
        rel = p.relative_to(addon).as_posix()
        t = list(luatok.tokens(luatok.read(p)))
        for i in range(len(t) - 3):
            if t[i][:2] == (luatok.NAME, "L") and t[i + 1][:2] == (luatok.SYM, "[") and t[i + 2][0] == luatok.STR:
                out.setdefault(t[i + 2][1], []).append((rel, t[i + 2][2]))
    return out


def code_texts(addon):
    """[(English, file, note)] of tools/tt_rules.py CODE, found by hash in the named files."""
    out, cache = [], {}
    for rel, k, note in R.CODE:
        if rel not in cache:
            src = luatok.read(Path(addon) / rel) if (Path(addon) / rel).is_file() else ""
            cache[rel] = XML_HINT.findall(src) if rel.endswith(".xml") else \
                [v for kind, v, _ in luatok.tokens(src) if kind == luatok.STR]
        if k == "xml:defaultText":
            found = cache[rel][:1]
        else:
            found = [s for s in cache[rel] if H.key(s) == k][:1]
        if found:
            out.append((found[0], rel, note))
        else:
            print(f"note: code text {k} not found in {rel} (TomTom changed: update tools/tt_rules.py CODE)")
    return out


def source(addon):
    """([(English, kind, section, sub, file)], {English: note}) in source order, each English once."""
    path = Path(addon) / LOCALE
    if not path.is_file():
        return [], {}
    used = uses(addon)
    rows, notes = [], {}
    for en in locale_keys(path):
        if H.key(en) in R.STAY or not en.strip() or en in notes:
            continue
        where = used.get(en, [])
        places = []
        for rel, line in where:
            p = R.place(rel, line)
            if p and p not in places:
                places.append(p)
        bits = ["where: " + ", ".join(places)] if places else []
        bits += [", ".join(f"{rel}:{line}" for rel, line in where[:2]) + (" ..." if len(where) > 2 else "")]
        if H.key(en) in R.MAXLEN:
            bits.append(f"max {R.MAXLEN[H.key(en)]}")
        notes[en] = "; ".join(b for b in bits if b)
        rows.append((en, L.kind_of(en), "enUS", "", LOCALE))
    for en, rel, note in code_texts(addon):
        if en in notes:
            continue
        notes[en] = f"in code, not L: {rel}; where: {note}"
        rows.append((en, L.kind_of(en), "in code", "", rel))
    return rows, notes


def slot_line(en):
    parts = [" ".join((x if len(x) == 1 else f"[{x}]") if x else "?" for x in R.sorts(line))
             for line in en.split("\n")]
    return " | ".join(parts) if any(parts) else ""


def swaps(rows, glossary):
    """Lua lines S["key"] = "..." for translated one-line templates with only v/f slots and no plural."""
    rev = L.read_all(LOCAL)
    out = []
    for en, kind, *_ in rows:
        if "template" not in kind or "\n" in en:
            continue
        ua = rev.get(H.key(en), ("", "", ""))[2]
        if not ua.strip():
            continue
        full, problems = L.expand(ua, glossary)
        letters = R.sorts(en)
        if problems or L.check(en, full) or "{" in full or None in letters or set(letters) - {"v", "f"}:
            continue
        out.append(f"S[{H.lua_str(H.key(en))}] = {H.lua_str(full)}")
    return sorted(out)


def group_refused(rows, glossary):
    """[(english, problems)] for translated templates whose Ukrainian breaks a group (tools/tt_rules.py GROUPS)."""
    rev, out = L.read_all(LOCAL), []
    for en, *_ in rows:
        ua = rev.get(H.key(en), ("", "", ""))[2] if H.key(en) in R.GROUPS else ""
        if ua.strip():
            problems = R.group_problems(en, L.expand(ua, glossary)[0])
            if problems:
                out.append((H.key(en), problems))
    return out


def keeps(rows, notes):
    """Lua lines K["key"] = true for the texts TomTom also puts in its data feed (another addon's bar)."""
    return sorted(f"K[{H.lua_str(H.key(en))}] = true" for en, *_ in rows
                  if FEED in notes.get(en, "") and not notes.get(en, "").startswith("in code"))


def main(argv):
    if len(argv) < 2 or argv[1] not in ("review", "build"):
        print(__doc__)
        return 2
    addon = addon_dir(argv[2] if len(argv) > 2 else None)
    rows, notes = source(addon)
    if not rows:
        print(f"TomTom not found in {addon} (pass its folder or set UADD_ADDONS_DIR)")
        return 1
    if argv[1] == "review":
        sizes, gone = L.review(rows, LOCAL, HEAD, GONE, slot_line, BATCH, note=lambda en: notes.get(en, ""))
        print(f"{len(rows)} texts in {len(sizes)} batches {sizes}; gone with UA: {gone} -> {LOCAL}")
        return 0
    from glossary import Glossary
    glossary = Glossary()
    groups = group_refused(rows, glossary)
    if groups:
        for k, problems in groups:
            print(f"refused [{k}]: " + "; ".join(problems))
        return 1
    entries, res = L.build(rows, LOCAL, glossary, R.sorts)
    sw = swaps(rows, glossary)
    kp = keeps(rows, notes)
    head = [h.replace("{ver}", version(addon)) for h in DATA_HEAD]
    L.write_data(entries + sw + kp, DATA, head, FILES, MAX_LINES, MAX_BYTES)
    for n, k, problems in res["bad"]:
        print(f"refused #{n} [{k}]: " + "; ".join(problems))
    print(f"built {res['exact']} exact + {res['templates']} templates ({len(sw)} into L, {len(kp)} kept out of L) "
          f"from {res['done']} texts; "
          f"untranslated {res['left']}; refused {len(res['bad'])}; loose (not shipped) {len(res['loose'])} -> {DATA}")
    return 1 if res["bad"] else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
