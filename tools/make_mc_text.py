"""Mastercraft's texts for UADD_Mastercraft, without keeping its English in this repo.

Mastercraft is all rights reserved (CLAUDE.md "Other addons' texts"): the repo holds only our Ukrainian,
keyed by a hash of the English (UADD/Hash.lua). The English is read from the installed addon (see
tools/mc_text_lib.py) into the git-ignored local/mastercraft/NN.txt batches.
  review [MASTERCRAFT_DIR]  write local/mastercraft/01.txt ... (about 280 texts each, by source section).
      A rerun keeps every UA, matched by the hash of the English; texts gone from Mastercraft move to a
      "gone" part at the end of the last batch, with their UA.
  build [MASTERCRAFT_DIR]   write UADD_Mastercraft/data/text01.lua ... text32.lua (always all 32, so the
      TOC stays the same). A UA with a bad slot, colour code, icon, link or line count is refused, and
      so is a translated template with a slot tools/mc_rules.py cannot sort. Counts are printed.
  slots [MASTERCRAFT_DIR]   list the %s slots tools/mc_rules.py cannot sort (into local/mastercraft/).
"""
import os
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import hashtext as H  # noqa: E402
import mc_rules as R  # noqa: E402
import mc_text_lib as L  # noqa: E402

ROOT = HERE.parent
LOCAL = ROOT / "local" / "mastercraft"
DATA = ROOT / "UADD_Mastercraft" / "data"
FILES = 32                      # data/text01.lua ... text32.lua, all listed in the TOC; filled in order
MAX_LINES, MAX_BYTES = 280, 24000
ADDON_DIRS = ["/mnt/c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns",
              "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns"]
SHORT = {R.VALUE: "V", R.FREE: "F", R.NAME: "N", R.TEXT: "T", R.BLANK: "B", R.EXACT: "E", None: "?"}
ONE_G = re.compile(r'^G"([a-z][a-z0-9_]*(?:\.[a-z0-9_]+)+)"$')

HEAD = """\
# Mastercraft's texts, batch {n} of {m}. Made by: python3 tools/make_mc_text.py review
# Write the Ukrainian after "UA: " under each "EN:". An empty UA keeps that text English.
# Do not change the lines that start with "#" or "EN:". The tool finds each text by its English.
# Keep in the UA, as they are in the EN:
#   - slots: %s %d %.1f %02d ... To change their order, number them: %2$s ... %1$s.
#   - colour codes |cffxxxxxx ... |r, icons |T...|t, links |H...|h ... |h.
#   - \\n (a line break): the same number of lines; each line keeps its own slots.
#   - the spaces at the start and the end of each line.
# G"glossary.id" puts in a glossary word (UADD/Glossary.lua), so a later word change is a rebuild.
# {{один|два|п'ять}} picks the form by the last number before it (only in a line with %d or %f).
# "slots:" says what each slot holds (lines split by |):
#   V a number, time, money or colour: keep it.   F a name kept as it is (player, addon, version).
#   N a game name: UALL Forever gives it in Ukrainian.   T another Mastercraft text.
#   B only an English plural "s": keep the %s (it is put in as nothing), right after the word.
#   ? not sorted yet: ask the lead, or leave the UA empty.
# Game names (items, zones, NPCs, spells) are never written here: they come in through the slots.
"""
GONE = "# ── Gone: no longer in Mastercraft. Kept so their Ukrainian is not lost. ──"
DATA_HEAD = [
    "-- Made by tools/make_mc_text.py build from Mastercraft {ver}. Do not edit: change the review files",
    "-- (local/mastercraft/NN.txt) and build again. No English here: only hashes of it (UADD/Hash.lua) and",
    "-- our Ukrainian. sort: what each slot holds, v value, f free name, n game name, t our text, b blank.",
    "local _, ns = ...",
    "local G = UADD and UADD.Glossary and UADD.Glossary.Text or function() return nil end",
    "local M = ns.MC or { exact = {}, templates = {} }",
    "ns.MC = M",
    "local E, T = M.exact, M.templates",
]


def addon_dir(arg=None):
    """Mastercraft's folder: the argument, $UADD_ADDONS_DIR/Mastercraft, the game's."""
    if arg:
        return Path(arg)
    base = os.environ.get("UADD_ADDONS_DIR") or next((d for d in ADDON_DIRS if os.path.isdir(d)), ADDON_DIRS[0])
    return Path(base) / "Mastercraft"


def version(addon):
    toc = Path(addon) / "Mastercraft.toc"
    m = re.search(r"^## Version:\s*(\S+)", toc.read_text(encoding="utf-8-sig", errors="replace"), re.M) \
        if toc.is_file() else None
    return m.group(1) if m else "?"


def slot_line(en):
    """"V N | T": the sort of each slot, line by line ("" when no line has a slot)."""
    parts = [" ".join(SHORT[s] for s in R.sorts(line)) for line in en.split("\n")]
    return " | ".join(parts) if any(parts) else ""


def batch_files(folder):
    return sorted(p for p in Path(folder).glob("*.txt") if re.fullmatch(r"\d\d\.txt", p.name))


def read_all(folder):
    """{key: (English, kind, UA)} of every batch file in `folder`."""
    out = {}
    for p in batch_files(folder):
        for k, v in L.read_review(p.read_text(encoding="utf-8")).items():
            if v[2] or k not in out:
                out[k] = v
    return out


def review(rows, folder):
    """Write the batches into `folder`; returns (batch sizes, gone count)."""
    folder = Path(folder)
    folder.mkdir(parents=True, exist_ok=True)
    old = read_all(folder)
    bs = L.batches(rows)
    now, n = set(), 0
    for i, b in enumerate(bs, 1):
        out = [HEAD.format(n=f"{i:02d}", m=f"{len(bs):02d}")]
        where = None
        for en, kind, sec, sub, fname in b:
            if (fname, sec, sub) != where:
                where = (fname, sec, sub)
                out.append(f"# ── {fname}: {sec}" + (f" / {sub}" if sub else "") + " ──\n")
            n += 1
            k = H.key(en)
            now.add(k)
            ua = old.get(k, ("", "", ""))[2]
            out += L.block(n, en, kind, ua, slot_line(en) if "template" in kind else "")
        if i == len(bs):
            gone = [(k, v) for k, v in old.items() if k not in now and v[2]]
            if gone:
                out.append(GONE + "\n")
            for k, (en, _, ua) in gone:
                n += 1
                out += L.block(n, en, "gone", ua)
        (folder / f"{i:02d}.txt").write_text("\n".join(out), encoding="utf-8", newline="\n")
    for p in batch_files(folder):
        if int(p.stem) > len(bs):
            p.unlink()
    return [len(b) for b in bs], len([k for k, v in old.items() if k not in now and v[2]])


def fit_ends(e, u):
    """The problem when Locale.lua's Strip would take off more of `e` than `u` shows, or None."""
    s = L.strip(e)
    a = e.find(s)
    pre, post = e[:a], e[a + len(s):]
    if not (u.startswith(pre) and u.endswith(post)) or len(u) < len(pre) + len(post):
        return "keep the spaces and the colour code around the line as in the English"
    return None


def records(en, kind, ua, glossary):
    """([(key, Lua value)], [template records], [problems], [loose lines]) for one translated text."""
    full, problems = L.expand(ua, glossary)
    problems += L.check(en, full)
    if problems:
        return [], [], problems, []
    if kind == "exact" or kind == "multi-line":
        m = ONE_G.match(ua)
        return [(H.key(en), f'G"{m.group(1)}"' if m else H.lua_str(full))], [], [], []
    exact, temps, loose = [], [], []
    for i, (e, u) in enumerate(zip(en.split("\n"), full.split("\n")), 1):
        where = f"line {i}: " if "\n" in en else ""
        bad = fit_ends(e, u)
        if bad:
            return [], [], [where + bad], []
        s = L.strip(e)
        a = e.find(s)
        u = u[a:len(u) - (len(e) - a - len(s))]
        if not s:
            continue
        if not L.is_pattern(s):
            exact.append((H.key(s), H.lua_str(u)))
            continue
        sorts = R.sorts(s)
        if None in sorts:
            return [], [], [where + f"slot {sorts.index(None) + 1} is not sorted (tools/mc_rules.py)"], []
        rec = H.template(s, u, sort=[SHORT[x].lower() for x in sorts])
        if rec is None:
            loose.append(s)
        else:
            temps.append(rec)
    return exact, temps, [], loose


def build(rows, folder, out_dir, glossary, ver="?"):
    """Write the data files. Returns {"done", "left", "bad": [(n, key, problems)], "loose"}."""
    rev = read_all(folder)
    exact, temps, bad, loose, left = {}, {}, [], [], 0
    for n, (en, kind, *_) in enumerate(rows, 1):
        k = H.key(en)
        ua = rev.get(k, ("", "", ""))[2]
        if not ua.strip():
            left += 1
            continue
        ex, ts, problems, lo = records(en, kind, ua, glossary)
        for ek, ev in ex:
            if exact.get(ek, ev) != ev:
                problems.append("another text gives this line another Ukrainian")
            exact[ek] = ev
        for t in ts:
            if t["id"] in temps and temps[t["id"]]["uk"] != t["uk"]:
                problems.append("another text gives this line another Ukrainian")
            temps[t["id"]] = t
        loose += lo
        if problems:
            bad.append((n, k, problems))
    entries = [wrap(f"E[{H.lua_str(k)}] = {v}") for k, v in sorted(exact.items())]
    entries += ["T[#T + 1] = " + H.lua_value({x: y for x, y in t.items() if x != "lit"})
                for _, t in sorted(temps.items())]
    write_data(entries, out_dir, ver)
    return {"done": len(rows) - left - len(bad), "left": left, "bad": bad, "loose": loose,
            "exact": len(exact), "templates": len(temps)}


WRAP = 300                      # check_repo.py allows 400 chars a line; a longer E line is cut into pieces


def wrap(line):
    """An E line whose value is one long string literal, as `"a " ..` lines of at most WRAP chars, cut after a
    space (lua_str never puts a space inside an escape). Other lines stay as they are."""
    head, sep, lit = line.partition(" = ")
    if len(line) <= WRAP or not (lit.startswith('"') and lit.endswith('"')):
        return line
    words, pieces, cur = lit[1:-1].split(" "), [], ""
    for n, w in enumerate(words):
        w += " " if n < len(words) - 1 else ""
        if cur and len(cur) + len(w) > WRAP - 10:
            pieces.append(cur)
            cur = ""
        cur += w
    pieces.append(cur)
    return head + sep + ' ..\n    '.join(f'"{p}"' for p in pieces)


def write_data(entries, out_dir, ver):
    """Spread `entries` over the FILES files, each under MAX_LINES lines and MAX_BYTES bytes."""
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    head = [h.replace("{ver}", ver) for h in DATA_HEAD]
    files = [[] for _ in range(FILES)]
    room = MAX_BYTES - len("\n".join(head).encode("utf-8"))
    i, size, lines = 0, 0, 0
    for e in entries:
        b, n = len(e.encode("utf-8")) + 1, e.count("\n") + 1
        if files[i] and (lines + n > MAX_LINES - len(head) - 1 or size + b > room):
            i, size, lines = i + 1, 0, 0
            if i == FILES:
                raise SystemExit(f"the data does not fit in {FILES} files: raise FILES (and the TOC)")
        files[i].append(e)
        size, lines = size + b, lines + n
    for n, f in enumerate(files, 1):
        text = "\n".join(head + f) + "\n"
        (out_dir / f"text{n:02d}.lua").write_text(text, encoding="utf-8", newline="\n")


def unsorted(rows):
    """[(key, letters, line)] of each template line with a slot mc_rules.py cannot sort."""
    out = []
    for en, kind, *_ in rows:
        for line in en.split("\n"):
            s = L.strip(line)
            if L.is_pattern(s) and None in R.sorts(s):
                out.append((H.key(s), " ".join(SHORT[x] for x in R.sorts(s)), s))
    return out


def main(argv):
    if len(argv) < 2 or argv[1] not in ("review", "build", "slots"):
        print(__doc__)
        return 2
    addon = addon_dir(argv[2] if len(argv) > 2 else None)
    rows = L.source(addon)
    if not rows:
        print(f"Mastercraft not found in {addon} (pass its folder or set UADD_ADDONS_DIR)")
        return 1
    if argv[1] == "review":
        sizes, gone = review(rows, LOCAL)
        print(f"{len(rows)} texts in {len(sizes)} batches {sizes}; gone with UA: {gone} -> {LOCAL}")
        return 0
    if argv[1] == "slots":
        us = unsorted(rows)
        LOCAL.mkdir(parents=True, exist_ok=True)
        (LOCAL / "unsorted.txt").write_text("".join(f"{k}  {s}  {L.esc(e)}\n" for k, s, e in us),
                                            encoding="utf-8", newline="\n")
        print(f"{len(us)} template lines with an unsorted slot -> {LOCAL / 'unsorted.txt'}")
        return 0
    from glossary import Glossary
    res = build(rows, LOCAL, DATA, Glossary(), version(addon))
    for n, k, problems in res["bad"]:
        print(f"refused #{n} [{k}]: " + "; ".join(problems))
    print(f"built {res['exact']} exact + {res['templates']} templates from {res['done']} texts; "
          f"untranslated {res['left']}; refused {len(res['bad'])}; loose (not shipped) {len(res['loose'])}; "
          f"unsorted template lines {len(unsorted(rows))} -> {DATA}")
    return 1 if res["bad"] else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
