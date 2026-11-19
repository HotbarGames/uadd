"""Mastercraft's texts for UADD_Mastercraft: the source, the review batches and the checks.

Mastercraft is all rights reserved: its English is read from the installed addon (the keys of
Locales/ru.lua and Locales/ru_data.lua, the union of all its locales) and goes only into the
git-ignored local/mastercraft/NN.txt batches. tools/make_mc_text.py is the command line.
Keys are stored the way Mastercraft's Locale.lua stores them (Strip: no spaces around, no colour code
around the whole text); a multi-line key with a slot is one text per line there, so it is here too.
"""
import re
from pathlib import Path

import hashtext as H
import luatok

WS = " \t\n\r\v\f"                      # Lua's %s
COLOUR = re.compile(r"^\|c[0-9A-Fa-f]{8}")
IS_PATTERN = re.compile(r"%[-0-9.]*[sdif]")   # Locale.lua IsPattern
PLURAL = re.compile(r"\{([^{}|]*)\|([^{}|]*)\|([^{}|]*)\}")
GREF = re.compile(r'G"([a-z][a-z0-9_]*(?:\.[a-z0-9_]+)+)"')
CYR = re.compile(r"[Ѐ-ӿ]")
LATIN_WORD = re.compile(r"[A-Za-z]{2,}")
SECTION_RULE = re.compile(r"^-{20,}\s*$")
SOURCES = ("Locales/ru.lua", "Locales/ru_data.lua")


def strip(en):
    """Locale.lua Strip: no spaces around, then no colour code around the whole text (again)."""
    en = en.strip(WS)
    if COLOUR.match(en) and en.endswith("|r") and en.count("|c") == 1 and en.count("|r") == 1:
        return strip(en[10:-2])
    return en


def is_pattern(en):
    return bool(IS_PATTERN.search(en))


def kind_of(en):
    """exact, template, multi-line or multi-line template."""
    multi = "\n" in en
    if is_pattern(en):
        return "multi-line template" if multi else "template"
    return "multi-line" if multi else "exact"


def sections(text):
    """{line number: (section, sub)}: the top-level comment just before an Add({ (under a ---- rule or
    not), and the last indented comment inside it."""
    out, sec, sub = {}, "Other", ""
    lines = text.split("\n")
    for n, line in enumerate(lines, 1):
        s = line.strip()
        after = [x for x in lines[n:n + 3] if not SECTION_RULE.match(x)]
        if line.startswith("--") and not SECTION_RULE.match(line) and after and after[0].startswith("Add("):
            sec, sub = s.lstrip("- ").strip(), ""
        elif line.startswith((" ", "\t")) and s.startswith("--") and not SECTION_RULE.match(s):
            sub = s.lstrip("- ").strip()
        out[n] = (sec, sub)
    return out


def read_keys(path):
    """[(English key, line)] of every ["key"] = ... entry of one locale file."""
    text = luatok.read(path)
    t = list(luatok.tokens(text))
    keys = []
    for i in range(len(t) - 3):
        if t[i][:2] == (luatok.SYM, "[") and t[i + 1][0] == luatok.STR and t[i + 2][:2] == (luatok.SYM, "]") \
                and t[i + 3][:2] == (luatok.SYM, "="):
            keys.append((t[i + 1][1], t[i + 1][2]))
    return keys, sections(text)


def source(addon):
    """[(English, kind, section, sub, file)] in source order, each English once (stripped like Locale.lua)."""
    rows, seen = [], set()
    for rel in SOURCES:
        path = Path(addon) / rel
        if not path.is_file():
            continue
        keys, secs = read_keys(path)
        for raw, line in keys:
            en = strip(raw)
            if not en or en in seen:
                continue
            seen.add(en)
            sec, sub = secs.get(line, ("Other", ""))
            rows.append((en, kind_of(en), sec, sub, Path(rel).name))
    return rows


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


def block(n, en, kind, ua, slots=""):
    head = f"#{n} {kind}  [{H.key(en)}]" + (f"  slots: {slots}" if slots else "")
    return [head, "EN: " + esc(en), "UA: " + esc(ua), ""]


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
