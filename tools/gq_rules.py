"""Which GearQuest Forever texts UADD_GearQuestForever translates, what each template slot holds, and the review
batches. Used by tools/make_gq_text.py (through tools/key_text.py).

GearQuest Forever has no licence (all rights reserved; CLAUDE.md "Other addons' texts"): nothing here names its
English. Its locale keys ARE its English, so every row is keyed by a hash:
  L.<hash>   a key of its locale table (GearQuest.L): UADD.Hash of the key as Lua reads it
  X.<hash>   a whole text it draws without its locale table: UADD.Hash of the English
Run `python3 tools/make_gq_text.py review` to see the texts (local/gearquest/, git-ignored).

Letters, one per slot (key_text.py): v a value (number, money, colour, link), f a free name kept as it is (a
player, the addon's own name, a version), n a game name (item, zone, NPC, quest, spell, skill: the line stays
English, as its lookups give it English), t another text of ours, u its own English units (the line stays
English). Every %s of a template must be sorted here before its Ukrainian builds (key_text.base_check).
"""
import key_text as K

SIZE = 150          # rows per review batch (one text agent's batch)

# Slot letters by key: {"L.<hash>": "vn"}. Filled at stage 4, one batch at a time, from where its code formats
# the key (the review file names the file and line).
SORTS = {
    "L.00eead0a": "fn", "L.014ec57e": "vnn", "L.04129dec": "vtt", "L.0863c6da": "n",
    "L.12cca58c": "n", "L.1a93b778": "n", "L.1c2b90df": "n", "L.249da6c6": "nun",
    "L.3574d1a9": "v", "L.39cd57c2": "nu", "L.42f9996b": "n", "L.457ca282": "vnnn",
    "L.487fb172": "n", "L.49c0fcc5": "t", "L.4b3e5940": "tvt", "L.5572aa91": "n",
    "L.5bd4587d": "v", "L.60430687": "n", "L.605056a1": "vnnn", "L.62fae1e7": "vvt",
    "L.6e002485": "v", "L.6f5e7a51": "vv", "L.76ce680c": "n", "L.796e4b7d": "nv",
    "L.7daf35e5": "t", "L.87ee594c": "tn", "L.88b5f338": "nn", "L.89a29845": "v",
    "L.8a3e3ad4": "vnnn", "L.8a889cf9": "vnn", "L.901e85b2": "nvv", "L.96f290dd": "vnn",
    "L.9e6ac7b7": "n", "L.a0d33c75": "v", "L.a15adaf4": "uu", "L.a4ba060b": "n",
    "L.a4c1921f": "n", "L.a703ad46": "nvn", "L.a7078c6a": "t", "L.ab47495c": "n",
    "L.ace59b8b": "n", "L.b32b5450": "vvt", "L.b4025168": "f", "L.b5148265": "vtv",
    "L.b82ef798": "n", "L.b8791b47": "v", "L.c1ce0042": "v", "L.c7a26104": "n",
    "L.c99879bb": "fu", "L.cb9da328": "tnvt", "L.d09e067a": "u", "L.d2488fc2": "t",
    "L.d564d1cb": "t", "L.d6baf587": "tn", "L.d7df10fe": "vv", "L.e1738a51": "v",
    "L.e2444f80": "f", "L.ea1111b9": "tn", "L.eb6795de": "tv", "L.ec4b6e21": "f",
    "L.ec9a5326": "vttn", "L.ef95b3dc": "n", "L.f17cb760": "f", "L.f18d8a55": "vv",
    "L.f1eb36a3": "n", "L.f9fe7525": "n", "L.fa12b2ca": "v", "L.facab15d": "v",
    "L.fc8ab34d": "vv",
}

# Keys never written: a text it saves into the player's data or compares with its own English (lesson 14).
# Filled at stage 4 from its code (its saved settings, the /gq arguments it compares in English).
STAY = {}           # {"L.<hash>": "why"}

# Keys kept as they are (a name): {"L.<hash>": "why"}.
NAMES = {
    "L.0069dd59": "spec name",
    "L.0d321e13": "talent tab name",
    "L.0e8b73bf": "talent tab name",
    "L.11317a2d": "prose that names a zone",
    "L.11e69245": "talent tab name",
    "L.12128532": "spec name",
    "L.267b8838": "spec name",
    "L.2a509873": "fallback class name, where a class name is expected",
    "L.3072b141": "talent tab name",
    "L.3decbf64": "talent tab name",
    "L.3eca30e2": "talent tab name",
    "L.5504a83a": "spec name",
    "L.55e80d01": "talent tab name",
    "L.5886c800": "button label that holds a zone name",
    "L.675a91ad": "spec name",
    "L.67cb0a7c": "talent tab name",
    "L.73468deb": "talent tab name",
    "L.73d36936": "spec name",
    "L.7c82a798": "talent tab name",
    "L.7c853fcb": "talent tab name",
    "L.7c8572eb": "talent tab name",
    "L.7c867161": "talent tab name",
    "L.7d05c3f9": "spec name",
    "L.84693ffc": "prose that names dungeons",
    "L.9d2e4bcc": "talent tab name",
    "L.9f6682a1": "start of a chat line that ends with a raw Lua error (half line)",
    "L.a7c533cf": "talent tab name",
    "L.ac3eb9fb": "talent tab name",
    "L.b18beb59": "talent tab name",
    "L.b8be2e7c": "talent tab name",
    "L.c661146b": "talent tab name",
    "L.d10c0e4b": "talent tab name",
    "L.d16c0fb7": "start of a chat line that ends with a raw Lua error (half line)",
    "L.d7bc2a97": "item-name fallback of a line that stays English",
    "L.e918a813": "talent tab name",
    "L.eee85579": "talent tab name",
    "L.f2f44dc9": "talent tab name",
}

# Notes shown in the review file, by key.
NOTES = {}

# Texts drawn through L[var] (dynamic keys): (file, pattern of the first line, pattern of the last line) ranges whose
# string literals are keys of its locale table; no last pattern: that one line. Each line that matches the first
# pattern starts a range. Found by its code, not by line number: a line number moves at each update, and the words
# of a moved range looked gone (1.3.4). Only labels, never ids; tools/test_gq_text.py wants each range found.
DYNAMIC = [
    ("CustomSpec.lua", r"^local FIELDS = \{", r"^\}"),
    ("_generated/ScoringWeights.generated.lua", r"^GQ\.ScoringWeightLabels = \{", r"^\}"),
    ("Compare.lua", r"^    if \(dpsWeight or 0\) > 0 then", r"^    return rows"),
    ("Log.lua", r"^local LIST_NEW_LABEL = ", None),
    ("Log.lua", r"^    local donationText = ", None),
    ("Log.lua", r'^    local order = \{ "[A-Z][a-z]+", "[A-Z][a-z]+", "[A-Z]', None),
    ("PortraitGuide.lua", r"^local GUIDE_NAME = ", None),
    ("Tracker.lua", r"^local TITLE_TEXT = ", None),
    ("MobDrop.lua", r"^    header = header or ", None),
]

# Its own folders and files that are data or stay English (lore, generated names, What's New, debug).
SKIP_PARTS = ("Locales", "_generated", "Libs", "libs")


def stay(key):
    return key in STAY


def sorts(key, en):
    return K.sorts_from(SORTS, key, en)


def keep(key, en):
    """(kept, reason left out)."""
    if stay(key):
        return False, "stay"
    if key in NAMES:
        return False, "name kept"
    letters = set(sorts(key, en))
    if "n" in letters or "u" in letters:
        return False, "own English in a slot"
    if not en.strip():
        return False, "empty"
    if not K.LATIN_WORD.search(K.SPECIAL.sub("", en)):
        return False, "no words"
    return True, ""


def check(key, en, ua):
    """What makes `ua` unfit as the Ukrainian of `en`."""
    problems = K.base_check(en, ua, sorts(key, en))
    if stay(key):
        problems.append("a STAY key (never written)")
    if key in NAMES:
        problems.append("a name kept as it is")
    return problems
