"""Hashed texts for UADD's data: our Ukrainian, keyed by hashes of another addon's English.

Most addons we translate are All Rights Reserved, so the repo keeps no English of theirs. A module's
generator reads the installed addon at build time and writes only what this file makes: the hash
of each English text and our Ukrainian. UADD/Hash.lua finds the texts on screen by the same hash.

  djb2(text)            8 hex digits, the same as UADD.Hash (and UADD_DungeonJournal's prose keys)
  key(text)             "<bytes>:<hash>", an exact text's key in data.exact
  tokens(text)          the text as ("lit", text) and ("slot", kind, ref) pieces
  is_template(text)     True when the text has a slot
  template(en, uk, ..)  a template's stored form (no English in it), or None when too short
  write_lua(..)         the Lua data file: ns.<name> = { exact = {..}, templates = {..} }

Slots: printf specs (%s %d %i %.1f %02x %1$s; %% is a plain "%"), Attune's ##NAME## places and
DialogueUI's [KEY:..] markup (it reaches the screen as a |T..|t picture). Kinds, as in Hash.lua:
s any text, l one line, d whole number, f number with a point, x hex, x2 two hex digits, t picture.
"""
import re

SLOT = re.compile(r"%%|%(?:(\d+)\$)?([-+ #0]*\d*(?:\.\d*)?)([sdifx])|##([A-Z][A-Z0-9_]*)##"
                  r"|\[KEY:[A-Za-z0-9:]+\]")
PRINTF_KIND = {"s": "s", "d": "d", "i": "d", "f": "f", "x": "x"}
CODES = ("|c", "|r", "|T", "|t", "|H", "|h", "|n")
KEY_MARK = re.compile(r"\[KEY:[A-Za-z0-9:]+\]")
MIN_LIT = 3          # "%s%s" or "%d/%d" alone would match anything


def djb2(text):
    """The hash of the UTF-8 bytes of `text` (or of `bytes`), as 8 hex digits."""
    data = text if isinstance(text, bytes) else text.encode("utf-8")
    h = 5381
    for b in data:
        h = (h * 33 + b) % 4294967296
    return "%08x" % h


def key(text):
    """An exact text's key: its length in bytes and its hash."""
    return "%d:%s" % (len(text.encode("utf-8")), djb2(text))


def tokens(text, one_line=()):
    """("lit", text) and ("slot", kind, ref) pieces. ref: ("arg", n), ("place", NAME) or
    ("key", markup). Places named in `one_line` hold one line (kind "l")."""
    out, pos, arg = [], 0, 0
    for m in SLOT.finditer(text):
        if m.start() > pos:
            out.append(("lit", text[pos:m.start()]))
        pos = m.end()
        whole = m.group(0)
        if whole == "%%":
            out.append(("lit", "%"))
        elif m.group(3):
            if m.group(1):
                n = int(m.group(1))
            else:
                arg += 1
                n = arg
            kind = PRINTF_KIND[m.group(3)]
            if kind == "x" and "02" in m.group(2):
                kind = "x2"
            out.append(("slot", kind, ("arg", n)))
        elif m.group(4):
            out.append(("slot", "l" if m.group(4) in one_line else "s", ("place", m.group(4))))
        else:
            out.append(("slot", "t", ("key", whole)))
    if pos < len(text):
        out.append(("lit", text[pos:]))
    return _merge(out)


def _merge(toks):
    """Neighbouring literal pieces as one ("100" "%" " done" -> "100% done")."""
    out = []
    for t in toks:
        if t[0] == "lit" and out and out[-1][0] == "lit":
            out[-1] = ("lit", out[-1][1] + t[1])
        else:
            out.append(t)
    return out


def is_template(text):
    return any(t[0] == "slot" for t in tokens(text))


def _codes(text):
    text = KEY_MARK.sub("", text)
    return [text.count(c) for c in CODES]


def check(en, uk, one_line=()):
    """What makes `uk` unfit for template `en` (empty list: fit). The same slots (by ref, each with
    the same kind), our Ukrainian may repeat a [KEY:..] or leave one out; the same |c |r |T |t |H |h
    |n codes."""
    problems = []
    es = {t[2]: t[1] for t in tokens(en, one_line) if t[0] == "slot"}
    us = [t for t in tokens(uk, one_line) if t[0] == "slot"]
    for _, kind, ref in us:
        if ref not in es:
            problems.append("slot %s %s is not in the English" % ref)
        elif es[ref] != kind:
            problems.append("slot %s %s is %s in the English, %s here" % (ref + (es[ref], kind)))
    used = {t[2] for t in us}
    for ref in es:
        if ref[0] != "key" and ref not in used:
            problems.append("slot %s %s is missing" % ref)
    if _codes(en) != _codes(uk):
        problems.append("|c |r |T |t |H |h |n codes differ")
    return problems


def template(en, uk, id=None, one_line=(), min_lit=MIN_LIT, **extra):
    """The stored form of template `en` with our Ukrainian `uk`, or None when its literal pieces
    have fewer than `min_lit` bytes. Raises ValueError when `uk` does not fit (see check()).
    id: the module's own name for it (default key(en)); extra: more fields for the Lua table."""
    problems = check(en, uk, one_line)
    if problems:
        raise ValueError("%r: %s" % (en, "; ".join(problems)))
    pieces, kinds, names, index = [""], [], [], {}
    for t in tokens(en, one_line):
        if t[0] == "lit":
            pieces[-1] += t[1]
            continue
        if t[2][0] == "place" and t[2] in index:
            raise ValueError("%r: place %s twice" % (en, t[2][1]))
        index.setdefault(t[2], len(kinds) + 1)
        kinds.append(t[1])
        names.append(t[2][1] if t[2][0] == "place" else "")
        pieces.append("")
    if not kinds:
        raise ValueError("%r has no slot: it is an exact text" % en)
    lit = sum(len(p.encode("utf-8")) for p in pieces)
    if lit < min_lit:
        return None
    out = []
    for t in tokens(uk, one_line):
        part = t[1] if t[0] == "lit" else index[t[2]]
        if isinstance(part, str) and out and isinstance(out[-1], str):
            out[-1] += part
        elif part != "":
            out.append(part)
    rec = {"id": id or key(en), "len": [len(p.encode("utf-8")) for p in pieces],
           "hash": [djb2(p) for p in pieces], "kinds": kinds, "uk": out, "lit": lit}
    if any(names):
        rec["names"] = names
    rec.update(extra)
    return rec


def lua_str(s):
    """A Lua string literal; bytes under 32 (but \\n \\r \\t) as \\ddd."""
    out = ['"']
    for ch in s:
        if ch in '\\"':
            out.append("\\" + ch)
        elif ch == "\n":
            out.append("\\n")
        elif ch == "\r":
            out.append("\\r")
        elif ch == "\t":
            out.append("\\t")
        elif ord(ch) < 32:
            out.append("\\%03d" % ord(ch))
        else:
            out.append(ch)
    return "".join(out + ['"'])


def lua_value(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(v)
    if isinstance(v, str):
        return lua_str(v)
    if isinstance(v, (list, tuple)):
        return "{ " + ", ".join(lua_value(x) for x in v) + " }"
    if isinstance(v, dict):
        return "{ " + ", ".join("%s = %s" % (k, lua_value(x)) for k, x in v.items()) + " }"
    raise TypeError("no Lua form for %r" % (v,))


def write_lua(exact, templates, name, header=(), path=None):
    """The Lua data file: `ns.<name> = { exact = {..}, templates = {..} }`, for UADD.TextIndex.
    exact: {English: Ukrainian} (hashed here) or {key: Ukrainian}; templates: template() results.
    Templates go longest literal first (then by id), the order Hash.lua ranks ties in. Written to
    `path` when given; the text is returned either way."""
    lines = ["-- " + h for h in header]
    lines += ["-- Made by a UADD generator with tools/hashtext.py. Do not edit: no English is kept here,",
              "-- only hashes of it (UADD/Hash.lua finds the texts on screen by them).",
              "local _, ns = ...", "ns.%s = {" % name, "    exact = {"]
    keyed = {}
    for en, uk in exact.items():
        k = en if re.fullmatch(r"\d+:[0-9a-f]{8}", en) else key(en)
        if k in keyed and keyed[k] != uk:
            raise ValueError("two exact texts with key %s" % k)
        keyed[k] = uk
    for k in sorted(keyed):
        lines.append("        [%s] = %s," % (lua_str(k), lua_str(keyed[k])))
    lines += ["    },", "    templates = {"]
    seen = set()
    for t in sorted((t for t in templates if t), key=lambda t: (-t["lit"], str(t["id"]))):
        if t["id"] in seen:
            raise ValueError("two templates with id %s" % t["id"])
        seen.add(t["id"])
        lines.append("        %s," % lua_value({k: v for k, v in t.items() if k != "lit"}))
    lines += ["    },", "}", ""]
    text = "\n".join(lines)
    if path:
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
    return text
