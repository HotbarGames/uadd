"""Shared parts of the hash-keyed text tools (tools/make_mc_text.py through mc_text_lib.py, and
tools/make_wt_text.py): the review batches (local/<addon>/NN.txt), the checks of one Ukrainian against
its English, and the data files (UADD/Hash.lua records, spread over a fixed number of files).

A row is (English, kind, section, sub-section, source file). kind: exact, template, multi-line,
multi-line template. Every record is keyed by "<bytes>:<hash>" of the English (tools/hashtext.py).
"""
import re
from pathlib import Path

import hashtext as H

WS = " \t\n\r\v\f"                      # Lua's %s
IS_PATTERN = re.compile(r"%[-0-9.]*[sdif]")
PLURAL = re.compile(r"\{([^{}|]*)\|([^{}|]*)\|([^{}|]*)\}")
GREF = re.compile(r'G"([a-z][a-z0-9_]*(?:\.[a-z0-9_]+)+)"')
ONE_G = re.compile(r'^G"([a-z][a-z0-9_]*(?:\.[a-z0-9_]+)+)"$')
CYR = re.compile(r"[Ѐ-ӿ]")
LATIN_WORD = re.compile(r"[A-Za-z]{2,}")


def is_pattern(en):
    return bool(IS_PATTERN.search(en))


def kind_of(en):
    """exact, template, multi-line or multi-line template."""
    multi = "\n" in en
    if is_pattern(en):
        return "multi-line template" if multi else "template"
    return "multi-line" if multi else "exact"


# ── Review batches ─────────────────────────────────────────────────────────────────────────────

def esc(s):
    return s.replace("\\", "\\\\").replace("\n", "\\n")


def unesc(s):
    return re.sub(r"\\(.)", lambda m: "\n" if m.group(1) == "n" else m.group(1), s)


def batches(rows, size=280):
    """Rows cut into batches of about `size`: a section stays whole when it fits, a big one is cut at
    its sub-sections where it can."""
    groups = []
    for r in rows:
        key = (r[4], r[2])
        if groups and groups[-1][0] == key:
            groups[-1][1].append(r)
        else:
            groups.append((key, [r]))
    out = [[]]
    for _, g in groups:
        if out[-1] and len(out[-1]) + len(g) > size * 1.15 and (len(g) <= size or len(out[-1]) > size * 0.8):
            out.append([])
        while len(out[-1]) + len(g) > size * 1.15:
            room = size - len(out[-1])
            if room < 20:
                out.append([])
                continue
            cut = max((i for i in range(1, len(g)) if g[i][3] != g[i - 1][3] and i <= room), default=room)
            cut = cut if cut >= room // 2 else room
            out[-1].extend(g[:cut])
            g = g[cut:]
            out.append([])
        out[-1].extend(g)
    return [b for b in out if b]


def read_review(text):
    """{key(English): (English, kind, UA)} of one batch; gone blocks too (kind "gone")."""
    out, en, kind = {}, None, None
    for raw in text.split("\n"):
        m = re.match(r"^#\d+ (gone|exact|template|multi-line(?: template)?)\b", raw)
        if m:
            kind, en = m.group(1), None
        elif raw.startswith("EN: ") and kind:
            en = unesc(raw[4:])
        elif raw.startswith("UA:") and en is not None:
            out[H.key(en)] = (en, kind, unesc(raw[4:] if raw.startswith("UA: ") else raw[3:]))
            en, kind = None, None
    return out


def block(n, en, kind, ua, slots="", note=""):
    head = f"#{n} {kind}  [{H.key(en)}]" + (f"  slots: {slots}" if slots else "") + (f"  ({note})" if note else "")
    return [head, "EN: " + esc(en), "UA: " + esc(ua), ""]


def batch_files(folder):
    return sorted(p for p in Path(folder).glob("*.txt") if re.fullmatch(r"\d\d\.txt", p.name))


def read_all(folder):
    """{key: (English, kind, UA)} of every batch file in `folder`."""
    out = {}
    for p in batch_files(folder):
        for k, v in read_review(p.read_text(encoding="utf-8")).items():
            if v[2] or k not in out:
                out[k] = v
    return out


def review(rows, folder, head, gone_head, slot_line, size, note=lambda en: ""):
    """Write the batches into `folder`, keeping every UA (by the hash of the English); texts gone from
    the addon move to a "gone" part at the end of the last batch. Returns (batch sizes, gone count)."""
    folder = Path(folder)
    folder.mkdir(parents=True, exist_ok=True)
    old = read_all(folder)
    bs = batches(rows, size)
    now, n = set(), 0
    for i, b in enumerate(bs, 1):
        out = [head.format(n=f"{i:02d}", m=f"{len(bs):02d}")]
        where = None
        for en, kind, sec, sub, fname in b:
            if (fname, sec, sub) != where:
                where = (fname, sec, sub)
                out.append(f"# ── {fname}: {sec}" + (f" / {sub}" if sub else "") + " ──\n")
            n += 1
            k = H.key(en)
            now.add(k)
            ua = old.get(k, ("", "", ""))[2]
            out += block(n, en, kind, ua, slot_line(en) if "template" in kind else "", note(en))
        if i == len(bs):
            gone = [(k, v) for k, v in old.items() if k not in now and v[2]]
            if gone:
                out.append(gone_head + "\n")
            for k, (en, _, ua) in gone:
                n += 1
                out += block(n, en, "gone", ua)
        (folder / f"{i:02d}.txt").write_text("\n".join(out), encoding="utf-8", newline="\n")
    for p in batch_files(folder):
        if int(p.stem) > len(bs):
            p.unlink()
    return [len(b) for b in bs], len([k for k, v in old.items() if k not in now and v[2]])


# ── Checks ─────────────────────────────────────────────────────────────────────────────────────

def ends(line):
    return (len(line) - len(line.lstrip(WS)), len(line) - len(line.rstrip(WS)))


def expand(ua, glossary):
    """UA with each inline G"id" put in from the glossary, and [problems]."""
    problems = []

    def one(m):
        word = glossary.text(m.group(1)) if glossary else None
        if word is None:
            problems.append(f'no glossary word G"{m.group(1)}"')
            return m.group(0)
        return word
    return GREF.sub(one, ua), problems


def check(en, ua):
    """What makes `ua` unfit for `en` (empty: fit). Line by line: the same slots (each in its own
    line; %2$s counts within the line), |c |r |T |t |H |h |n codes, spaces at both ends of a line;
    {one|few|many} only in a line with a number slot; some Ukrainian letters."""
    problems = []
    el, ul = en.split("\n"), ua.split("\n")
    if len(el) != len(ul):
        return [f"{len(ul)} lines, the English has {len(el)}"]
    for i, (e, u) in enumerate(zip(el, ul), 1):
        where = f"line {i}: " if len(el) > 1 else ""
        bare = PLURAL.sub("", u)
        if "{" in bare or "}" in bare:
            problems.append(where + "a { } that is not {one|few|many}")
        if PLURAL.search(u) and not any(t[0] == "slot" and t[1] in ("d", "f") for t in H.tokens(e)):
            problems.append(where + "{one|few|many} with no number slot")
        problems += [where + p for p in H.check(e, PLURAL.sub("x", u))]
        if ends(e) != ends(u):
            problems.append(where + "the spaces at its ends differ")
    words = LATIN_WORD.findall(re.sub(r"\|c\w{8}|\|T[^|]*\|t|\|H[^|]*\|h|%[-0-9.$]*[sdif]", "", en))
    if words and not CYR.search(ua):
        problems.append("no Ukrainian letters")
    return problems


# ── Data files ─────────────────────────────────────────────────────────────────────────────────

def records(en, kind, ua, glossary, sorts):
    """([(key, Lua value)], [template records], [problems], [loose lines]) for one translated text.
    `sorts(line)`: [one letter v f n t b, or None] per slot of a template line."""
    full, problems = expand(ua, glossary)
    problems += check(en, full)
    if problems:
        return [], [], problems, []
    if kind in ("exact", "multi-line"):
        m = ONE_G.match(ua)
        return [(H.key(en), f'G"{m.group(1)}"' if m else H.lua_str(full))], [], [], []
    exact, temps, loose = [], [], []
    for i, (e, u) in enumerate(zip(en.split("\n"), full.split("\n")), 1):
        where = f"line {i}: " if "\n" in en else ""
        if not e.strip(WS):
            continue
        if not is_pattern(e):
            exact.append((H.key(e), H.lua_str(u)))
            continue
        letters = sorts(e)
        if None in letters:
            return [], [], [where + f"slot {letters.index(None) + 1} is not sorted"], []
        rec = H.template(e, u, sort=letters)
        if rec is None:
            loose.append(e)
        else:
            temps.append(rec)
    return exact, temps, [], loose


def build(rows, folder, glossary, sorts):
    """(entries, result): the Lua lines for the data files, and {"done", "left", "bad", "loose", ...}."""
    rev = read_all(folder)
    exact, temps, bad, loose, left = {}, {}, [], [], 0
    for n, (en, kind, *_) in enumerate(rows, 1):
        k = H.key(en)
        ua = rev.get(k, ("", "", ""))[2]
        if not ua.strip():
            left += 1
            continue
        ex, ts, problems, lo = records(en, kind, ua, glossary, sorts)
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
    entries = [f"E[{H.lua_str(k)}] = {v}" for k, v in sorted(exact.items())]
    entries += ["T[#T + 1] = " + H.lua_value({x: y for x, y in t.items() if x != "lit"})
                for _, t in sorted(temps.items())]
    return entries, {"done": len(rows) - left - len(bad), "left": left, "bad": bad, "loose": loose,
                     "exact": len(exact), "templates": len(temps)}


def write_data(entries, out_dir, head, files, max_lines, max_bytes):
    """Spread `entries` over `files` files (text01.lua ...), each under max_lines lines and max_bytes."""
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    parts = [[] for _ in range(files)]
    room = max_bytes - len("\n".join(head).encode("utf-8"))
    i, size = 0, 0
    for e in entries:
        b = len(e.encode("utf-8")) + 1
        if parts[i] and (len(parts[i]) >= max_lines - len(head) - 1 or size + b > room):
            i, size = i + 1, 0
            if i == files:
                raise SystemExit(f"the data does not fit in {files} files: raise FILES (and the TOC)")
        parts[i].append(e)
        size += b
    for n, f in enumerate(parts, 1):
        text = "\n".join(head + f) + "\n"
        (out_dir / f"text{n:02d}.lua").write_text(text, encoding="utf-8", newline="\n")
