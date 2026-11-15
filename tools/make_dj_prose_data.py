#!/usr/bin/env python3
"""Builds UADD_DungeonJournal/data/prose.lua from tools/dj_prose/en_N.lua + uk_N.lua.

Only what the game needs is shipped: key -> Ukrainian (placeholders kept), the quest titles used in
{quest:...} placeholders (title -> id) and the keys (hashes) of the translated journal templates;
Prose.lua finds their English in the running journal. The English texts stay in tools/dj_prose/en_N.lua
(git-ignored). A missing or broken uk_N file is skipped; an entry that fails validate() is skipped
with a warning.

    python3 tools/make_dj_prose_data.py
"""
import re
import sys
from collections import Counter
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SRC = REPO / "tools" / "dj_prose"
OUT = REPO / "UADD_DungeonJournal" / "data" / "prose.lua"
BATCHES = range(1, 7)
TEMPLATE_WHERE = "Core/Journal.lua template"

PLACEHOLDER = re.compile(r"\{(npc|item|zone|quest):[^{}]+\}")
COLOR = re.compile(r"\|c[0-9a-fA-F]{8}")
TEXTURE = re.compile(r"\|T[^|]*\|t")
NUMBER = re.compile(r"\d+")
# The letters the shipped fonts have (tools/test_font_chars.py) and Russian-only letters.
ALLOWED_EXTRA = set("ҐґЄєІіЇї’«»—…№")
RUSSIAN_ONLY = re.compile(r"[ЫыЭэЪъЁё]")


def lua_runtime():
    from lupa import lua51
    return lua51.LuaRuntime(unpack_returned_tuples=True, encoding=None)


def _py(v):
    if isinstance(v, bytes):
        return v.decode("utf-8")
    if v is not None and not isinstance(v, (int, float, bool, str)):
        keys = list(v.keys())
        if keys and all(isinstance(k, int) for k in keys):
            return [_py(v[k]) for k in sorted(keys)]
        return {_py(k): _py(x) for k, x in v.items()}
    return v


def load_lua(lua, path):
    """A Lua file that returns a table, as Python data. Raises on a parse error."""
    fn = lua.execute(b"return function(s, n) return assert(loadstring(s, n))() end")
    return _py(fn(path.read_bytes(), str(path.name).encode()))


def load_en(lua, n):
    return {e["key"]: e for e in load_lua(lua, SRC / ("en_%d.lua" % n))}


def load_uk(lua, n):
    """The uk_N table, or None (with a warning) when the file is missing or does not load."""
    path = SRC / ("uk_%d.lua" % n)
    if not path.exists():
        return None
    try:
        t = load_lua(lua, path)
    except Exception as err:  # a translator's file still being written
        print("skip %s: %s" % (path.name, str(err).splitlines()[0]), file=sys.stderr)
        return None
    return t if isinstance(t, dict) else {}


def _codes(s):
    return (Counter(m.group(0) for m in PLACEHOLDER.finditer(s)),
            Counter(c.lower() for c in COLOR.findall(s)), s.count("|r"),
            Counter(TEXTURE.findall(s)), s.count("%s"))


def _numbers(s):
    s = TEXTURE.sub("", COLOR.sub("", PLACEHOLDER.sub("", s)))
    return Counter(NUMBER.findall(s))


def bad_chars(s):
    return sorted({c for c in s if ord(c) > 126 and not (0x400 <= ord(c) <= 0x45F) and c not in ALLOWED_EXTRA})


def validate(entry, uk):
    """Problems of one Ukrainian text against its en_N entry; [] when it may ship."""
    if not isinstance(uk, str) or not uk.strip():
        return ["not a text"]
    src = entry.get("src") or entry["en"]
    want, got = _codes(src), _codes(uk)
    out = []
    for name, a, b in zip(("placeholders", "|c codes", "|r count", "|T textures", "%s count"), want, got):
        if a != b:
            out.append("%s differ" % name)
    if _numbers(src) != _numbers(uk):
        out.append("numbers differ: %s vs %s" % (sorted(_numbers(src).elements()), sorted(_numbers(uk).elements())))
    if bad_chars(uk):
        out.append("letters the fonts lack: %s" % "".join(bad_chars(uk)))
    if RUSSIAN_ONLY.search(uk):
        out.append("Russian-only letters")
    return out


def lua_str(s):
    s = s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\r", "\\r")
    return '"' + s + '"'


def build():
    lua = lua_runtime()
    data, quests, templates, skipped = {}, {}, [], 0
    for n in BATCHES:
        en, uk = load_en(lua, n), load_uk(lua, n)
        if uk is None:
            print("uk_%d.lua missing: batch %d stays English" % (n, n), file=sys.stderr)
            continue
        for key, text in uk.items():
            entry = en.get(key)
            problems = ["key not in en_%d" % n] if entry is None else validate(entry, text)
            if problems:
                skipped += 1
                print("skip uk_%d %s: %s" % (n, key, "; ".join(problems)), file=sys.stderr)
                continue
            if entry.get("shown") is False:   # boss and dungeon descriptions: FDJ never shows them
                continue
            data[key] = text
            for ph, qid in (entry.get("names") or {}).items():
                if ph.startswith("{quest:") and ph in text:
                    quests[ph[7:-1]] = qid
            if TEMPLATE_WHERE in (entry.get("where") or []):
                templates.append(key)
    return data, quests, templates, skipped


def write(data, quests, templates):
    lines = ["-- Made by tools/make_dj_prose_data.py from tools/dj_prose/uk_N.lua. Do not edit.",
             "-- Key: djb2 of FDJ's English text. Placeholders {npc:..} {item:..} {zone:..} {quest:..}",
             "-- are filled at runtime from UALL names (Prose.lua).", "local _, ns = ...", "ns.proseData = {"]
    lines += ["  [%s] = %s," % (lua_str(k), lua_str(data[k])) for k in sorted(data)]
    lines += ["}", "ns.proseQuests = {"]
    lines += ["  [%s] = %d," % (lua_str(t), quests[t]) for t in sorted(quests)]
    lines += ["}", "-- The journal templates (warnings with %s): their keys.", "ns.proseTemplates = {"]
    lines += ["  %s," % lua_str(t) for t in templates]
    lines += ["}", ""]
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_bytes("\n".join(lines).encode("utf-8"))


def main():
    missing = [n for n in BATCHES if not (SRC / ("en_%d.lua" % n)).exists()]
    if missing:  # en_N.lua is FDJ's own text, kept out of git; never write a half-empty prose.lua
        sys.exit("en_%d.lua missing: run tools/make_dj_prose.py first (needs FDJ and UALL Forever)"
                 % missing[0])
    data, quests, templates, skipped = build()
    write(data, quests, templates)
    print("%s: %d texts, %d quest titles, %d templates (%d skipped)"
          % (OUT.relative_to(REPO), len(data), len(quests), len(templates), skipped))


if __name__ == "__main__":
    main()
