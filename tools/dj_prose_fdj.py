"""Reading Forever Dungeon Journal for make_dj_prose.py: load its Lua data, then list
every English text with where it is used. Split out of make_dj_prose.py."""
import re
import sys

from lupa import lua51

from dj_prose_names import ADDONS, person, places

FDJ_DIR = ADDONS / "ForeverDungeonJournal"

DATA_FILES = [
    "Data/Dungeons.lua", "Data/SharedLoot.lua", "Data/DungeonEntrances.lua",
    "Data/DungeonRoutes.lua", "Data/Bosses.lua", "Data/QuestMaps.lua",
    "Data/QuestChains.lua", "Data/QuestRewards.lua", "Data/QuestShareability.lua",
    "Data/QuestUpdates.lua",
]

# Warnings built in Core/Journal.lua with string.format: FDJ passes the template, a string literal,
# through FreeText (LocalizeFreeText), then fills %s with client quest titles. Read from the installed
# Journal.lua (its English is not kept in this repo): every FreeText("...%s...") literal.
JOURNAL_TEMPLATE = re.compile(r'FreeText\("((?:[^"\\\n]|\\.)*%s(?:[^"\\\n]|\\.)*)"\)')

STUBS = b"""
FDJ = { Constants = { ALBA_FAIRMOON_LOCATION = "Alba Fairmoon, Sentinel Hill inn, Westfall" } }
GetLocale = function() return "enUS" end
local dummy; dummy = setmetatable({}, {
  __index = function() return function() return dummy end end,
  __call = function() return dummy end })
CreateFrame = function() return dummy end
C_Timer = dummy
hooksecurefunc = function() end
"""
LOADER = b"""function(src, name)
  local f, e = loadstring(src, name)
  if not f then return e end
  local ok, err = pcall(f, "ForeverDungeonJournal", FDJ)
  return ok and "ok" or tostring(err)
end"""


def py(obj, depth=0):
    """Lua value -> Python (str/num/bool/list/dict). Bytes become UTF-8 str."""
    if isinstance(obj, bytes):
        return obj.decode("utf-8", "replace")
    if lua51.lua_type(obj) != "table":
        return obj if not callable(obj) else None
    if depth > 12:
        return None
    keys = list(obj.keys())
    if keys and all(isinstance(k, int) for k in keys) and sorted(keys) == list(range(1, len(keys) + 1)):
        return [py(obj[k], depth + 1) for k in range(1, len(keys) + 1)]
    return {py(k): py(v, depth + 1) for k, v in obj.items()}


def load_fdj():
    lua = lua51.LuaRuntime(unpack_returned_tuples=True, encoding=None)
    lua.execute(STUBS)
    run = lua.eval(LOADER)
    for rel in DATA_FILES:
        res = run((FDJ_DIR / rel).read_bytes(), rel.encode())
        if res != b"ok":
            # QuestUpdates ends with frame code; its data is set before that.
            print("note: %s stopped: %s" % (rel, res.decode("utf-8", "replace")), file=sys.stderr)
    fdj = lua.globals().FDJ
    return {k: py(fdj[k.encode()]) for k in
            ("DB", "ORDER", "QUEST_PREREQ_CHAINS", "QUEST_PREREQ_DETAILS")}


def collect(data, names):
    """Return ordered list of (group, kind, where, english, shown)."""
    db, order = data["DB"], data["ORDER"]
    chains, details = data["QUEST_PREREQ_CHAINS"] or {}, data["QUEST_PREREQ_DETAILS"] or {}
    groups = list(order) + [k for k in db if k not in order]
    out = []

    def items_of(lst):
        for it in lst or []:
            if isinstance(it, list) and len(it) > 1:
                names.add("item", it[1], it[0])
            elif isinstance(it, dict):
                names.add("item", it.get("name") or it.get(2), it.get("id") or it.get(1))

    def people(s):
        if isinstance(s, str):
            p = person(s)
            if p:
                names.add("npc", p)
            for pl in places(s):
                names.add("zone", pl)

    step_group = {}
    for g in groups:
        d = db.get(g) or {}
        names.add("zone", g)
        for b in d.get("bosses") or []:
            if not isinstance(b, dict):
                continue
            names.add("npc", b.get("name"), b.get("npcID"))
            items_of(b.get("loot"))
            if isinstance(b.get("description"), str):
                out.append((g, "description", "%s / boss %s" % (g, b.get("name")), b["description"], False))
        if isinstance(d.get("description"), str):
            out.append((g, "description", "%s / dungeon" % g, d["description"], False))
        for q in d.get("quests") or []:
            if not isinstance(q, dict):
                continue
            qid = q.get("id")
            names.add("quest", q.get("name"), qid)
            people(q.get("pickup")); people(q.get("turnin"))
            items_of(q.get("rewardItems"))
            for f in ("noteItem", "startItem", "requiredItem"):
                v = q.get(f)
                if isinstance(v, list) and len(v) > 1:
                    names.add("item", v[1], v[0])
                    if len(v) > 3 and isinstance(v[3], str) and v[3].startswith("Dropped by:"):
                        for src in v[3][len("Dropped by:"):].split(","):
                            names.add("npc", src.strip())
            for f in ("objective", "note", "warning", "description"):
                if isinstance(q.get(f), str) and q[f].strip():
                    out.append((g, f if f != "description" else "description",
                                "%s / quest %s %s" % (g, qid, f), q[f], True))
            for step in chains.get(qid) or []:
                if isinstance(step, dict) and step.get("id"):
                    names.add("quest", step.get("name"), step["id"])
                    step_group.setdefault(step["id"], g)
                elif isinstance(step, list) and step:
                    names.add("quest", step[1] if len(step) > 1 else None, step[0])
                    step_group.setdefault(step[0], g)
    for sid, det in sorted(details.items(), key=lambda kv: str(kv[0])):
        if not isinstance(det, dict):
            continue
        g = step_group.get(sid, "(other prereq steps)")
        people(det.get("pickup")); people(det.get("turnin"))
        for f in ("startItem", "providedItem"):
            v = det.get(f)
            if isinstance(v, list) and len(v) > 1:
                names.add("item", v[1], v[0])
        items_of(det.get("requiredItems"))
        for f in ("objective", "note", "warning", "description"):
            if isinstance(det.get(f), str) and det[f].strip():
                out.append((g, f, "%s / step %s %s" % (g, sid, f), det[f], True))
    journal = (FDJ_DIR / "Core" / "Journal.lua").read_text("utf-8", "replace")
    templates = list(dict.fromkeys(m.group(1) for m in JOURNAL_TEMPLATE.finditer(journal)))
    if not templates:
        print("note: no FreeText templates found in Journal.lua", file=sys.stderr)
    for t in templates:
        out.append(("(journal templates)", "warning", "Core/Journal.lua template", t, True))
    return out, groups + ["(other prereq steps)", "(journal templates)"]
