"""RareScanner's texts for UADD_RareScanner.

RareScanner is All Rights Reserved (CLAUDE.md "Other addons' texts"): the data keeps only our Ukrainian, keyed
by the AceLocale key. The module writes each one into RareScanner's AceLocale table (AL[key]) after load.
The English is read from the installed addon (Locales/RareScanner-enUS.lua and its code); which keys, the
slot sorts and the batches are in tools/rs_rules.py. The review files with the English go to local/rs/
(git-ignored).
  review [RS_DIR]  write local/rs/review_01.txt ... review_08.txt (one per batch of tools/rs_rules.py
      BATCHES). A rerun keeps every UA, matched by key; keys gone from the addon move to a "gone" part at
      the end of the last batch.
  build [RS_DIR]   write UADD_RareScanner/data/text01.lua ... (always all FILES, so the TOC stays the same):
      T["KEY"] = "Ukrainian", and S["KEY"] = "letters" for a key with slots. A UA that drops, adds or moves
      a slot (%s %d %.1f), a colour code, an icon, a link, a {tag} or a line break, or that changes the
      spaces at a line's ends, is refused; so is a translated template with a slot tools/rs_rules.py has no
      sort for. An empty UA is not translated (left out).
  stats [RS_DIR]   per batch: keys, done, left, refused.
"""
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import hashtext as H  # noqa: E402
import rs_rules as R  # noqa: E402
from rs_rules import check  # noqa: E402
from rs_source import addon_dir, source, version  # noqa: E402

ROOT = HERE.parent
LOCAL = ROOT / "local" / "rs"
DATA = ROOT / "UADD_RareScanner" / "data"
FILES = 8  # the TOC lists all of them; the last ones are room for an addon update
MAX_LINES, MAX_BYTES, MAX_LINE, CHUNK = 280, 24000, 380, 300
UA_LINE = re.compile(r"^(?:UA|uk):\s?(.*)$")

HEAD = """\
# RareScanner's texts, batch {n} of {m}: {area}. Made by: python3 tools/make_rs_text.py review
# Never commit this file: RareScanner's English is all rights reserved (local/ is git-ignored).
# Write the Ukrainian after "UA: " under each "EN:". An empty UA keeps that text English.
# Do not change the lines that start with "#" or "EN:". The tool finds each text by its key [KEY].
# Keep in the UA, as they are in the EN and IN THE SAME ORDER (Lua's string.format has no %2$s):
#   - slots: %s %d %.1f %%
#   - colour codes |cffxxxxxx ... |r, icons |T...|t, atlas |A...|a, links |H...|h ... |h, tags {{area:123}}.
#   - \\n (a line break): the same number of lines.
#   - the spaces at the start and the end of each line.
# No plural {{один|два|п'ять}} (nothing reads it here). Never the middle dot (the Cyrillic font has none).
# G"glossary.id" puts in a glossary word (UADD/Glossary.lua) at build time.
# "slots:" says what each slot holds: v a number, time, clock, id, colour or icon: keep it.
#   n a game name (NPC, treasure, item, item class): UALL Forever gives it, or it stays English.
#   f a name or value kept as typed (a group name, a profile, a path, a key binding).
#   t another RareScanner text of ours (named after "t:"): translate that key too.
#   ? not sorted yet: ask the lead, or leave the UA empty.
# Game names (NPCs, treasures, items, zones, dungeons) are never written here (lesson 9): a text that names
# one keeps it only as UALL Forever has it; when UALL has none, leave the UA empty.
# "where" says the area and file:line of its use. Short words for menu entries, buttons and tooltips.
"""
GONE = "# ── Gone: no longer in RareScanner. Kept so their Ukrainian is not lost. ──"
DATA_HEAD = [
    "-- Made by tools/make_rs_text.py build from RareScanner {ver}. Do not edit: change the review files",
    "-- (local/rs/review_NN.txt) and build again. Only AceLocale keys of RareScanner and our Ukrainian.",
    "-- T: AL[key] = Ukrainian. S: what each slot of a template holds, in order: v value, f free (kept as",
    "-- typed), n game name (UALL Forever's, else the whole line stays English), t our text (another key).",
    "local _, ns = ...",
    "local T = ns.AL or {}; ns.AL = T",
    "local S = ns.SORT or {}; ns.SORT = S",
]


# ── Review files ───────────────────────────────────────────────────────────────────────────────

def esc(s):
    return s.replace("\\", "\\\\").replace("\n", "\\n")


def unesc(s):
    return re.sub(r"\\(.)", lambda m: "\n" if m.group(1) == "n" else m.group(1), s)


def kind_of(en):
    tpl = bool(R.slots(en))
    return ("multi-line template" if tpl else "multi-line") if "\n" in en else ("template" if tpl else "exact")


def review_files(folder=LOCAL):
    return sorted(p for p in Path(folder).glob("review_*.txt") if re.fullmatch(r"review_\d\d\.txt", p.name))


def read_review(text):
    """{key: (English, UA)} of one review file, gone blocks too."""
    out, key, en = {}, None, None
    for raw in text.split("\n"):
        m = re.match(r"^#\d+ \S.*?\[([A-Za-z0-9_]+)\]", raw)
        if m:
            key, en = m.group(1), None
        elif raw.startswith("EN: ") and key:
            en = unesc(raw[4:])
        elif key and en is not None and UA_LINE.match(raw):
            out[key] = (en, unesc(UA_LINE.match(raw).group(1)))
            key, en = None, None
    return out


def read_all(folder=LOCAL):
    out = {}
    for p in review_files(folder):
        for k, v in read_review(p.read_text(encoding="utf-8")).items():
            if v[1] or k not in out:
                out[k] = v
    return out


def slot_line(key, en):
    return " ".join(x or "?" for x in R.sorts(key, en))


def block(n, key, en, ua, note=""):
    kind = kind_of(en)
    sl = slot_line(key, en) if "template" in kind else ""
    head = f"#{n} {kind}  [{key}]" + (f"  slots: {sl}" if sl else "") + (f"  ({note})" if note else "")
    return [head, "EN: " + esc(en), "UA: " + esc(ua), ""]


def review(rows, folder=LOCAL):
    """Write one review file per batch, keeping every UA by key. Returns ({batch: count}, gone count)."""
    folder = Path(folder)
    folder.mkdir(parents=True, exist_ok=True)
    old = read_all(folder)
    nums = [b[0] for b in R.BATCHES]
    sizes, now, n = {}, set(), 0
    for b, area, _ in R.BATCHES:
        out = [HEAD.format(n=f"{b:02d}", m=f"{len(nums):02d}", area=area)]
        where = None
        for key, en, batch, live, note in rows:
            if batch != b:
                continue
            f = live[0][0] if live else "(dynamic keys)"
            if f != where:
                where = f
                out.append(f"# ── {f} ──\n")
            n += 1
            now.add(key)
            out += block(n, key, en, old.get(key, ("", ""))[1], note)
            sizes[b] = sizes.get(b, 0) + 1
        if b == nums[-1]:
            gone = [(k, v) for k, v in old.items() if k not in now and v[1]]
            if gone:
                out.append(GONE + "\n")
            for k, (en, ua) in gone:
                n += 1
                out += [f"#{n} gone  [{k}]", "EN: " + esc(en), "UA: " + esc(ua), ""]
        (folder / f"review_{b:02d}.txt").write_text("\n".join(out), encoding="utf-8", newline="\n")
    return sizes, len([k for k, v in old.items() if k not in now and v[1]])


# ── Checks ─────────────────────────────────────────────────────────────────────────────────────

def expand(ua, glossary):
    problems = []

    def one(m):
        word = glossary.text(m.group(1)) if glossary else None
        if word is None:
            problems.append(f'no glossary word G"{m.group(1)}"')
            return m.group(0)
        return word
    return re.sub(r'G"([a-z][a-z0-9_]*(?:\.[a-z0-9_]+)+)"', one, ua), problems


# ── Data files ─────────────────────────────────────────────────────────────────────────────────

def lua_entry(name, key, value):
    """`T["KEY"] = "..."`, cut into `"..." ..` pieces on several lines when it is long (check_repo maxLine)."""
    first = f"{name}[{H.lua_str(key)}] = "
    whole = first + H.lua_str(value)
    if len(whole) <= MAX_LINE:
        return whole
    parts = [value[i:i + CHUNK] for i in range(0, len(value), CHUNK)]
    return first + " ..\n\t".join(H.lua_str(p) for p in parts)


def build(rows, glossary, folder=LOCAL):
    """(entries, result). entries: Lua chunks for the data files; result: done, left, bad [(key, problems)]."""
    rev = read_all(folder)
    entries, bad, left, done = [], [], 0, 0
    for key, en, *_ in rows:
        ua = rev.get(key, ("", ""))[1]
        if not ua.strip():
            left += 1
            continue
        full, problems = expand(ua, glossary)
        problems += check(key, en, full)
        if problems:
            bad.append((key, problems))
            continue
        done += 1
        chunk = [lua_entry("T", key, full)]
        letters = R.sorts(key, en)
        if letters:
            chunk.append(f'S[{H.lua_str(key)}] = {H.lua_str("".join(letters))}')
        entries.append("\n".join(chunk))
    return entries, {"done": done, "left": left, "bad": bad}


def write_data(entries, ver, out_dir=DATA, files=FILES):
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    head = [h.replace("{ver}", ver) for h in DATA_HEAD]
    room_b = MAX_BYTES - len("\n".join(head).encode("utf-8")) - 1
    room_l = MAX_LINES - len(head) - 1
    parts, i, size, nl = [[] for _ in range(files)], 0, 0, 0
    for e in entries:
        b, ln = len(e.encode("utf-8")) + 1, e.count("\n") + 1
        if parts[i] and (nl + ln > room_l or size + b > room_b):
            i, size, nl = i + 1, 0, 0
            if i == files:
                raise SystemExit(f"the data does not fit in {files} files: raise FILES (and the TOC)")
        parts[i].append(e)
        size, nl = size + b, nl + ln
    for n, f in enumerate(parts, 1):
        (out_dir / f"text{n:02d}.lua").write_text("\n".join(head + f) + "\n", encoding="utf-8", newline="\n")


def stats(rows, folder=LOCAL):
    rev = read_all(folder)
    out = {}
    for key, en, batch, *_ in rows:
        s = out.setdefault(batch, {"keys": 0, "done": 0, "left": 0, "refused": 0, "en_chars": 0})
        s["keys"] += 1
        s["en_chars"] += len(en)
        ua = rev.get(key, ("", ""))[1]
        if not ua.strip():
            s["left"] += 1
        elif check(key, en, ua):
            s["refused"] += 1
        else:
            s["done"] += 1
    return out


def main(argv):
    if len(argv) < 2 or argv[1] not in ("review", "build", "stats"):
        print(__doc__)
        return 2
    addon = addon_dir(argv[2] if len(argv) > 2 else None)
    rows, why = source(addon)
    if not rows:
        print(f"RareScanner not found in {addon} (pass its folder or set UADD_ADDONS_DIR)")
        return 1
    if argv[1] == "review":
        sizes, gone = review(rows)
        print(f"{len(rows)} keys in {len(sizes)} batches " + " ".join(f"{b:02d}:{n}" for b, n in sorted(sizes.items()))
              + f"; gone with UA: {gone} -> {LOCAL}")
        print("left out: " + ", ".join(f"{k} {v}" for k, v in sorted(why.items())))
        return 0
    if argv[1] == "stats":
        tot = {"keys": 0, "done": 0, "left": 0, "refused": 0, "en_chars": 0}
        for b, s in sorted(stats(rows).items()):
            print(f"batch {b:02d}: {s['keys']} keys, done {s['done']}, left {s['left']}, refused {s['refused']}")
            for k in tot:
                tot[k] += s[k]
        print(f"all: {tot['keys']} keys, done {tot['done']}, left {tot['left']}, refused {tot['refused']}; "
              f"English {tot['en_chars']} letters")
        return 0
    from glossary import Glossary
    entries, res = build(rows, Glossary())
    write_data(entries, version(addon))
    for key, problems in res["bad"]:
        print(f"refused [{key}]: " + "; ".join(problems))
    print(f"built {res['done']} keys; untranslated {res['left']}; refused {len(res['bad'])} -> {DATA} "
          f"(text01.lua ... text{FILES:02d}.lua)")
    return 1 if res["bad"] else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
