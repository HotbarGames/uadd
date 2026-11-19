"""Shared review/build/stats machinery for key-based modules: our Ukrainian keyed by the addon's own locale
key, its English read from the installed addon at build time (CLAUDE.md "Other addons' texts").

A module gives a `spec` (see tools/make_pawn_text.py) with:
  NAME, TOOL        the addon's name, the command that makes the files (for the file heads)
  LOCAL, DATA       the folder of review files (under local/, git-ignored), the module's data folder
  FILES             how many data files the TOC lists (text01.lua ...)
  BATCHES           [(n, area, ...)]: the review files
  HELP              extra "#" lines for the review head (what the slot letters mean for this addon)
  DATA_HEAD         the data file head (Lua lines; "{ver}" is the addon version)
  check(key, en, ua) -> [problem]; sorts(key, en) -> [letter or None]
A row is (key, English, batch, [(file, line)], note), in batch order.
RareScanner keeps its own copy (tools/make_rs_text.py); this is the same code made shareable.
"""
import re
from pathlib import Path

import hashtext as H

MAX_LINES, MAX_BYTES, MAX_LINE, CHUNK = 280, 24000, 380, 300
UA_LINE = re.compile(r"^(?:UA|uk):\s?(.*)$")
KEY = r"[A-Za-z0-9_.]+"

HEAD = """\
# {name}'s texts, batch {n} of {m}: {area}. Made by: python3 {tool} review
# Never commit this file: it holds {name}'s English (local/ is git-ignored).
# Write the Ukrainian after "UA: " under each "EN:". An empty UA keeps that text English.
# Do not change the lines that start with "#" or "EN:". The tool finds each text by its key [KEY].
# Keep in the UA, as they are in the EN and IN THE SAME ORDER (Lua's string.format has no %2$s):
#   - slots: %s %d %.1f %%
#   - colour codes |cffxxxxxx ... |r, icons |T...|t, atlas |A...|a, links |H...|h ... |h.
#   - \\n (a line break): the same number of lines.
#   - the spaces at the start and the end of each line.
# No plural {{один|два|п'ять}} (nothing reads it here). Never the middle dot (the Cyrillic font has none).
# G"glossary.id" puts in a glossary word (UADD/Glossary.lua) at build time.
"""
GONE = "# ── Gone: no longer in {name}. Kept so their Ukrainian is not lost. ──"


# ── Slots and the shared checks ───────────────────────────────────────────────────────────────

# Only real string.format slots (%s %d %i %f %x, flags without a space): "50% upgrade" in a text that is never
# formatted holds no slot. UADD_Pawn/Module.lua Specs reads them the same way.
SLOT = re.compile(r"%%|%[-+#0]*\d*(?:\.\d*)?[sdifx]")
SPECIAL = re.compile(r"%%|%[-+#0]*\d*(?:\.\d*)?[sdifx]|\|c[0-9a-fA-F]{8}|\|r|\|T[^|]*\|t|\|A[^|]*\|a"
                     r"|\|H[^|]*\|h|\|h|\|n|\{[a-z]+:\d+\}|\n")
POSITIONAL = re.compile(r"%\d+\$")
PLURAL = re.compile(r"\{[^{}]*\|[^{}]*\}")
CYR = re.compile(r"[Ѐ-ӿ]")
LATIN_WORD = re.compile(r"[A-Za-z]{2,}")
WS = " \t\n\r\v\f"


def slots(en):
    """[printf conversion letter] of each slot of `en`, in order (%% is no slot)."""
    return [m.group(0)[-1] for m in SLOT.finditer(en) if m.group(0) != "%%"]


def sorts_from(table, key, en):
    """[letter or None] for each slot of `en`: %d/%f and a |cff%s slot are v; a %s takes table[key]'s letter."""
    over, out = table.get(key, ""), []
    for i, m in enumerate(x for x in SLOT.finditer(en) if x.group(0) != "%%"):
        if m.group(0)[-1] != "s" or re.search(r"\|c(?:ff|FF)?$", en[:m.start()]):
            out.append("v")
        else:
            out.append(over[i] if i < len(over) else None)
    return out


def ends(line):
    return (len(line) - len(line.lstrip(WS)), len(line) - len(line.rstrip(WS)))


def base_check(en, ua, letters):
    """What makes `ua` unfit as the Ukrainian of `en` (slots, codes, line ends, letters)."""
    if ua == en:
        return ["the same as the English"]
    problems = []
    se, su = SPECIAL.findall(en), SPECIAL.findall(ua)
    if se != su:
        problems.append(f"slots and codes differ: the English has {se}, the UA {su}")
    if POSITIONAL.search(ua):
        problems.append("%n$ slots do not work in Lua's string.format")
    if PLURAL.search(ua):
        problems.append("a plural {..|..} (nothing reads it)")
    el, ul = en.split("\n"), ua.split("\n")
    if len(el) == len(ul) and any(ends(e) != ends(u) for e, u in zip(el, ul)):
        problems.append("the spaces at a line's ends differ")
    if LATIN_WORD.search(SPECIAL.sub("", en)) and not CYR.search(ua):
        problems.append("no Ukrainian letters")
    if None in letters:
        problems.append(f"slot {letters.index(None) + 1} is not sorted (the rules file's SORTS)")
    return problems


# ── Review files ───────────────────────────────────────────────────────────────────────────────

def esc(s):
    return s.replace("\\", "\\\\").replace("\n", "\\n")


def unesc(s):
    return re.sub(r"\\(.)", lambda m: "\n" if m.group(1) == "n" else m.group(1), s)


def kind_of(en):
    tpl = bool(slots(en))
    return ("multi-line template" if tpl else "multi-line") if "\n" in en else ("template" if tpl else "exact")


def review_files(folder):
    return sorted(p for p in Path(folder).glob("review_*.txt") if re.fullmatch(r"review_\d\d\.txt", p.name))


def read_review(text):
    """{key: (English, UA)} of one review file, gone blocks too."""
    out, key, en = {}, None, None
    for raw in text.split("\n"):
        m = re.match(r"^#\d+ \S.*?\[(%s)\]" % KEY, raw)
        if m:
            key, en = m.group(1), None
        elif raw.startswith("EN: ") and key:
            en = unesc(raw[4:])
        elif key and en is not None and UA_LINE.match(raw):
            out[key] = (en, unesc(UA_LINE.match(raw).group(1)))
            key, en = None, None
    return out


def read_all(folder):
    out = {}
    for p in review_files(folder):
        for k, v in read_review(p.read_text(encoding="utf-8")).items():
            if v[1] or k not in out:
                out[k] = v
    return out


def block(spec, n, key, en, ua, note=""):
    kind = kind_of(en)
    sl = " ".join(x or "?" for x in spec.sorts(key, en)) if "template" in kind else ""
    head = f"#{n} {kind}  [{key}]" + (f"  slots: {sl}" if sl else "") + (f"  ({note})" if note else "")
    return [head, "EN: " + esc(en), "UA: " + esc(ua), ""]


def review(spec, rows, folder=None):
    """One review file per batch, keeping every UA by key. Returns ({batch: count}, gone count)."""
    folder = Path(folder or spec.LOCAL)
    folder.mkdir(parents=True, exist_ok=True)
    old = read_all(folder)
    nums = [b[0] for b in spec.BATCHES]
    sizes, now, n = {}, set(), 0
    for b, area, *_ in spec.BATCHES:
        out = [HEAD.format(name=spec.NAME, tool=spec.TOOL, n=f"{b:02d}", m=f"{len(nums):02d}", area=area)
               + spec.HELP]
        where = None
        for key, en, batch, live, note in rows:
            if batch != b:
                continue
            f = live[0][0] if live else "(not named in its code)"
            if f != where:
                where = f
                out.append(f"# ── {f} ──\n")
            n += 1
            now.add(key)
            out += block(spec, n, key, en, old.get(key, ("", ""))[1], note)
            sizes[b] = sizes.get(b, 0) + 1
        if b == nums[-1]:
            gone = [(k, v) for k, v in old.items() if k not in now and v[1]]
            if gone:
                out.append(GONE.format(name=spec.NAME) + "\n")
            for k, (en, ua) in gone:
                n += 1
                out += [f"#{n} gone  [{k}]", "EN: " + esc(en), "UA: " + esc(ua), ""]
        (folder / f"review_{b:02d}.txt").write_text("\n".join(out), encoding="utf-8", newline="\n")
    return sizes, len([k for k, v in old.items() if k not in now and v[1]])


# ── Build ──────────────────────────────────────────────────────────────────────────────────────

def expand(ua, glossary):
    problems = []

    def one(m):
        word = glossary.text(m.group(1)) if glossary else None
        if word is None:
            problems.append(f'no glossary word G"{m.group(1)}"')
            return m.group(0)
        return word
    return re.sub(r'G"([a-z][a-z0-9_]*(?:\.[a-z0-9_]+)+)"', one, ua), problems


def lua_entry(name, key, value):
    """`T["KEY"] = "..."`, cut into `"..." ..` pieces on several lines when it is long (check_repo maxLine)."""
    first = f"{name}[{H.lua_str(key)}] = "
    whole = first + H.lua_str(value)
    if len(whole) <= MAX_LINE:
        return whole
    parts = [value[i:i + CHUNK] for i in range(0, len(value), CHUNK)]
    return first + " ..\n\t".join(H.lua_str(p) for p in parts)


def build(spec, rows, glossary, folder=None):
    """(entries, result). entries: Lua chunks for the data files; result: done, left, bad [(key, problems)]."""
    rev = read_all(folder or spec.LOCAL)
    entries, bad, left, done = [], [], 0, 0
    for key, en, *_ in rows:
        ua = rev.get(key, ("", ""))[1]
        if not ua.strip():
            left += 1
            continue
        full, problems = expand(ua, glossary)
        problems += spec.check(key, en, full)
        if problems:
            bad.append((key, problems))
            continue
        done += 1
        chunk = [lua_entry("T", key, full)]
        letters = spec.sorts(key, en)
        if letters:
            chunk.append(f'S[{H.lua_str(key)}] = {H.lua_str("".join(letters))}')
        entries.append("\n".join(chunk))
    return entries, {"done": done, "left": left, "bad": bad}


def write_data(spec, entries, ver, out_dir=None, files=None):
    out_dir, files = Path(out_dir or spec.DATA), files or spec.FILES
    out_dir.mkdir(parents=True, exist_ok=True)
    head = [h.replace("{ver}", ver) for h in spec.DATA_HEAD]
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


def stats(spec, rows, folder=None):
    rev = read_all(folder or spec.LOCAL)
    out = {}
    for key, en, batch, *_ in rows:
        s = out.setdefault(batch, {"keys": 0, "done": 0, "left": 0, "refused": 0, "en_chars": 0})
        s["keys"] += 1
        s["en_chars"] += len(en)
        ua = rev.get(key, ("", ""))[1]
        if not ua.strip():
            s["left"] += 1
        elif spec.check(key, en, ua):
            s["refused"] += 1
        else:
            s["done"] += 1
    return out


def print_stats(spec, rows):
    tot = {"keys": 0, "done": 0, "left": 0, "refused": 0, "en_chars": 0}
    for b, s in sorted(stats(spec, rows).items()):
        print(f"batch {b:02d}: {s['keys']} keys, done {s['done']}, left {s['left']}, refused {s['refused']}")
        for k in tot:
            tot[k] += s[k]
    print(f"all: {tot['keys']} keys, done {tot['done']}, left {tot['left']}, refused {tot['refused']}; "
          f"English {tot['en_chars']} letters")
