"""UADD_ForeverXPBar/data/words.lua: built from ForeverXP Bar's texts and our Ukrainian, and read back.

The file holds no English. tools/hashtext.py makes the keys and UADD/Hash.lua matches them in game:
  exact      a whole text: "<bytes>:<hash>" -> our Ukrainian ("text" or G"glossary.id")
  templates  a text with slots: the length and hash of each literal piece, the slot kinds, our Ukrainian
             as pieces (a number k is slot k); blank: slots our Ukrainian leaves empty; free: slots that
             hold a name and may stay English; g: the glossary id the Ukrainian came from
  known      the keys of all the addon's whole texts, translated or not (Words.Known)
  long       all its templates with 12+ bytes of literal text, translated or not (Words.Distinct)
One record per line with uk last, so read() needs no Lua parser. Used by tools/make_fxpb_data.py.
"""
import re

import hashtext as H

KEY = re.compile(r"\d+:[0-9a-f]{8}")
STR = r'"(?:[^"\\]|\\.)*"'
VALUE = re.compile(r"G?" + STR)
ESC = {"n": "\n", "t": "\t", "r": "\r", "\\": "\\", '"': '"', "'": "'", "a": "\a", "b": "\b", "f": "\f",
       "v": "\v"}
# Slots that hold an English plural ending ("" or "s"): our Ukrainian keeps the slot (so the slots
# still match) and Words.lua fills it with "". Key of the template's English -> its slot numbers.
BLANK = {"29:4a3152ef": [2]}
# Slots that hold a name the player or the game made (a profile, a race and its code, a buff, an error
# message): Words.lua keeps any English there. Every other %s must hold a number, a time or one of the
# addon's own texts, or the template does not fit (no half-translated line). Key -> slot numbers.
FREE = {
    "17:c757025a": [1], "14:736280ca": [1], "12:c3d2438b": [1, 2], "33:973e3092": [1], "14:96895e64": [1],
    "101:9782882a": [1], "18:891820e1": [1, 2], "19:d9efc37d": [1, 2], "57:e6ae55c5": [1, 2],
    "46:34ffda9f": [1], "47:6bdd9834": [1], "22:97ab7162": [1], "20:c28e6b09": [1], "36:9fc3a2e8": [1],
    "48:2308670f": [1], "59:33bb4d30": [1], "79:0da4320d": [1], "19:3c1148b3": [1], "58:9775fef2": [1, 2],
    "34:ea5c92e7": [1, 2], "35:8eeefe7c": [1, 2], "46:4eb614f3": [1, 2], "50:85aa874c": [1],
    "23:00d86a45": [1], "35:0bae7f36": [1, 2], "23:e2f95839": [1], "91:d9cc2802": [1], "58:83460d43": [1],
    "52:21d77602": [1],
}
LONG_LIT = 12
PER_LINE = 8          # keys per line in `known`


def unlua(lit):
    """The text of a Lua string literal. \\ddd escapes are bytes, so "\\226\\128\\162" is one character."""
    body, out, i = lit[1:-1], bytearray(), 0
    while i < len(body):
        c = body[i]
        if c != "\\":
            out += c.encode("utf-8")
            i += 1
        elif body[i + 1].isdigit():
            m = re.match(r"\d{1,3}", body[i + 1:])
            out.append(int(m.group(0)))
            i += 1 + len(m.group(0))
        else:
            out += ESC.get(body[i + 1], body[i + 1]).encode("utf-8")
            i += 2
    return out.decode("utf-8")


def text_of(value, glossary):
    """The Ukrainian text of a value ("text" or G"id"), or None for an empty one or an unknown id."""
    if not value:
        return None
    if value.startswith("G"):
        return glossary.text(unlua(value[1:]))
    return unlua(value)


def specs(en):
    """The printf spec of each slot of `en`, by slot number ("%s", "%.1f", "%02x")."""
    out, arg = {}, 0
    for m in H.SLOT.finditer(en):
        if m.group(3):                   # numbered the way hashtext.tokens numbers them
            if m.group(1):
                n = int(m.group(1))
            else:
                arg += 1
                n = arg
            out.setdefault(n, "%" + m.group(2) + m.group(3))
    return out


def template_text(en, uk):
    """Our Ukrainian pieces back as a template with the English's specs; %k$ only when out of order."""
    sp, nums = specs(en), [p for p in uk if isinstance(p, int)]
    plain = nums == list(range(1, len(nums) + 1))
    out = []
    for p in uk:
        if isinstance(p, int):
            out.append(sp[p] if plain else "%%%d$%s" % (p, sp[p][1:]))
        else:
            out.append(p.replace("%", "%%"))
    return "".join(out)


def own(en):
    """The template's English pieces alone (no Ukrainian): its len, hash and kinds."""
    return H.template(en, en, min_lit=0)


def signature(rec):
    return tuple(rec["len"]), tuple(rec["hash"]), tuple(rec["kinds"])


def build(texts, uk, glossary):
    """The data for `texts` ([(kind, English)]) and `uk` ({English: value}): (data, problems)."""
    data = {"exact": {}, "templates": [], "known": set(), "long": []}
    problems = []
    for kind, en in texts:
        value = uk.get(en)
        text = text_of(value, glossary)
        if kind == "exact":
            data["known"].add(H.key(en))
            if text and text != en:
                data["exact"][H.key(en)] = value if value.startswith("G") else H.lua_str(text)
            elif value and text is None:
                problems.append("%r: no glossary word %s" % (en, value))
            continue
        mine = own(en)
        if mine["lit"] >= LONG_LIT:
            data["long"].append(mine)
        if not text or text == en:
            if value and text is None:
                problems.append("%r: no glossary word %s" % (en, value))
            continue
        extra = {"blank": BLANK[H.key(en)]} if H.key(en) in BLANK else {}
        if value.startswith("G"):
            extra["g"] = unlua(value[1:])
        try:
            rec = H.template(en, text, **extra)
            if rec is not None and H.key(en) in FREE:
                rec["free"] = FREE[H.key(en)]
        except ValueError as e:
            problems.append(str(e))
            continue
        if rec is None:
            problems.append("%r: too little fixed text to find it" % en)
            continue
        rec["en"] = en                   # for the order only; never written
        data["templates"].append(rec)
    data["templates"].sort(key=lambda r: (-r["lit"], r["en"]))
    data["long"].sort(key=lambda r: (-r["lit"], r["hash"]))
    return data, problems


def _rec(rec, uk=True):
    """One template as a Lua table on one line, uk last."""
    parts = ["len = %s" % H.lua_value(rec["len"]), "hash = %s" % H.lua_value(rec["hash"]),
             "kinds = %s" % H.lua_value(rec["kinds"])]
    if rec.get("blank"):
        parts.append("blank = %s" % H.lua_value(rec["blank"]))
    if rec.get("free"):
        parts.append("free = %s" % H.lua_value(rec["free"]))
    if rec.get("g"):
        parts.append("g = %s" % H.lua_str(rec["g"]))
    parts.append("uk = %s" % (H.lua_value(rec["uk"]) if uk else "{}"))
    return "{ " + ", ".join(parts) + " }"


def write(data, version):
    """The text of data/words.lua."""
    out = ["-- Made by tools/make_fxpb_data.py from ForeverXP Bar %s. Do not edit: change the review file" % version,
           "-- (local/foreverxpbar.txt) and run the tool again. No English here: only hashes of it (UADD/Hash.lua)",
           "-- and our Ukrainian. Words.lua builds its tables from it. Over the 300-line budget on purpose: data.",
           "local _, ns = ...",
           "local G = UADD and UADD.Glossary and UADD.Glossary.Text or function() return nil end",
           "ns.FXPB = {", "    exact = {"]
    for k in sorted(data["exact"]):
        out.append("        [%s] = %s," % (H.lua_str(k), data["exact"][k]))
    out += ["    },", "    templates = {"]
    out += ["        %s," % _rec(r) for r in data["templates"]]
    out += ["    },", "    known = {"]
    keys = sorted(data["known"])
    for i in range(0, len(keys), PER_LINE):
        out.append("        " + " ".join(H.lua_str(k) + "," for k in keys[i:i + PER_LINE]))
    out += ["    },", "    long = {"]
    out += ["        %s," % _rec(r, uk=False) for r in data["long"]]
    out += ["    },", "}", ""]
    return "\n".join(out)


LINE = re.compile(r"^\s*\{ len = \{ ([^}]*) \}, hash = \{ ([^}]*) \}, kinds = \{ ([^}]*) \}"
                  r"(?:, blank = \{ ([^}]*) \})?(?:, free = \{ [^}]* \})?(?:, g = (" + STR + r"))?"
                  r", uk = \{ ?(.*?) ?\} \},$")
EXACT = re.compile(r'^\s*\["(\d+:[0-9a-f]{8})"\] = (G?' + STR + r"),$")


def _items(s):
    return [unlua(x) if x.startswith('"') else int(x) for x in re.findall(STR + r"|\d+", s)]


def read(text):
    """data/words.lua's exact ({key: value}) and templates ({signature: (uk pieces, glossary id)})."""
    exact, templates, part = {}, {}, None
    for line in text.split("\n"):
        if re.match(r"^    \w+ = \{$", line):
            part = line.split()[0]
        m = EXACT.match(line)
        if m and part == "exact":
            exact[m.group(1)] = m.group(2)
        m = LINE.match(line)
        if m and part == "templates":
            rec = {"len": _items(m.group(1)), "hash": _items(m.group(2)), "kinds": _items(m.group(3))}
            templates[signature(rec)] = (_items(m.group(6)), unlua(m.group(5)) if m.group(5) else None)
    return exact, templates


def ukrainian(texts, text):
    """Our Ukrainian from data/words.lua's `text`, by English, for `texts` ([(kind, English)])."""
    exact, templates = read(text)
    out = {}
    for kind, en in texts:
        if kind == "exact":
            if H.key(en) in exact:
                out[en] = exact[H.key(en)]
            continue
        hit = templates.get(signature(own(en)))
        if hit:
            uk, gid = hit
            out[en] = "G" + H.lua_str(gid) if gid else H.lua_str(template_text(en, uk))
    return out


def overlay(seed, text, glossary):
    """For the harness: (Lua chunk, expected). The chunk has the `seed` texts ({English: Ukrainian})
    that data/words.lua (`text`) does not translate, hashed for UADD.TextIndex; expected is each seed
    text's Ukrainian, data/words.lua's wording where it has one."""
    exact, templates = read(text)
    keyed, recs, want = [], [], {}
    for en, uk in seed.items():
        if not H.is_template(en):
            have = text_of(exact.get(H.key(en)), glossary)
            want[en] = have or uk
            if not have:
                keyed.append("[%s] = %s" % (H.lua_str(H.key(en)), H.lua_str(uk)))
            continue
        hit = templates.get(signature(own(en)))
        if hit:
            want[en] = glossary.text(hit[1]) if hit[1] else template_text(en, hit[0])
            continue
        want[en] = uk
        blank = BLANK.get(H.key(en))
        rec = H.template(en, uk, min_lit=0, **({"blank": blank} if blank else {}))
        if H.key(en) in FREE:
            rec["free"] = FREE[H.key(en)]
        recs.append({k: v for k, v in rec.items() if k not in ("id", "lit")})
    return "return { exact = { %s }, templates = %s }" % (", ".join(keyed), H.lua_value(recs)), want
