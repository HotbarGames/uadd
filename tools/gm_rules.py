"""Which GatherMate2 texts UADD_GatherMate2 translates, what each template slot holds, and the review batches.
Used by tools/make_gm_text.py (through tools/key_text.py).

GatherMate2 is treated as all rights reserved (its TOC says ARR; CLAUDE.md "Other addons' texts"): nothing
here names its English. Its locale keys ARE its English, so every row is keyed by a hash of the key:
  L.<hash>      a key of GatherMate2's own locale table (hash: tools/hashtext.py djb2 = UADD.Hash in Lua)
  Panel.<app>   the label of a settings sub-panel, by its options app ("GM2/<app>"), written in its code
  AceDBO.<key>  a text of the Profiles tab, by AceDBOptions-3.0's own key
  AceGUI.<name> a fixed text of an AceGUI widget (the key binding hint)
Run `python3 tools/make_gm_text.py review` to see the texts.

Letters, one per slot (key_text.py): v a value, f a free name kept as it is, n a game name (the line stays
English), t another text of ours. GatherMate2's own texts have no %s today; the glued ones are below.
"""
import re

import key_text as K

# Never written into GatherMate2's locale, with the reason (lesson 9, lesson 7).
STAY = {
    "L.8d54e40a": "the chat line glues an engine reason token to it (Config.lua): the line stays English",
}

# In our data, but never written into GatherMate2's locale: GatherMate2 captures these at load
# (Constants.lua SetSkillProfession) and compares them with the game's profession names. The module shows
# ours only where a settings list shows them. Use the glossary word (G"prof.herbalism" and so on).
DISPLAY_ONLY = {
    "L.1e363afc": "a profession name GatherMate2 compares with the game's: use G\"prof.herbalism\"",
    "L.c3266907": "a profession name GatherMate2 compares with the game's: use G\"prof.mining\"",
    "L.0d75bacd": "a profession name GatherMate2 compares with the game's: use G\"prof.fishing\"",
    "L.6585e410": "a profession name GatherMate2 compares with the game's: use G\"prof.engineering\"",
    "L.ba066853": "a profession name GatherMate2 compares with the game's: use G\"prof.archaeology\"",
}

# Keys GatherMate2 glues to something in code (lesson 7). The glued part is listed as a slot letter for the
# review only; the Ukrainian keeps the trailing space.
GLUED = {
    "L.adde7058": "the world map pin menu glues ' :' and the node's game name after it (Display.lua); the "
                  "same key is the Delete button of the settings",
    "L.d7c16fbf": "the chat line glues an addon's folder name after it (a free name): keep the last space",
}

NOTES = dict(DISPLAY_ONLY)
NOTES.update(GLUED)
NOTES["AceGUI.keybinding_hint"] = "the hint under a key binding button while it waits for a key"
for _k in ("intro", "choose_desc", "copy_desc", "delete_desc"):
    NOTES["AceDBO." + _k] = "a line of the Profiles tab; the module adds the line break"
NOTES["AceDBO.current"] = "the module puts the profile name after it, with a space"

# What GatherMate2's code glues after a key, as a slot (lesson 7): the half-line check
# (tools/harness/halves_mods.py gm()) reads each as a template, its English plus this.
GLUE_AFTER = {"L.adde7058": " :%s", "L.d7c16fbf": "%s"}

# A letter per slot, by key: GatherMate2's own texts have no %s today (a new one is refused until it is
# added here), so these are the GLUE_AFTER slots. n: the pin menu line holds a node's game name, so it stays
# English (the module never writes this key into the table). f: an addon's folder name, kept as it is.
SORTS = {"L.adde7058": "n", "L.d7c16fbf": "f"}

# Review batches: (number, area, test(key, live)). The first that fits takes the key. live: [(file, line)].
SPLIT = 700  # Config.lua lines before this: Minimap and Filters; after: Maintenance, Import, FAQ, launcher


def _first(live):
    return live[0] if live else ("", 0)


BATCHES = [
    (1, "settings: the main page, Minimap and Filters (Config.lua, first part)",
     lambda k, live: k.startswith("L.") and _first(live)[0] == "Config.lua" and _first(live)[1] < SPLIT),
    (2, "settings: Maintenance, Import, FAQ, the launcher tooltip (Config.lua, rest)",
     lambda k, live: k.startswith("L.") and _first(live)[0] == "Config.lua"),
    (3, "chat lines, the world map pin menu, panel names, the Profiles tab, the key binding hint",
     lambda k, live: True),
]


def batch_of(key, live=()):
    return next(b for b, _, test in BATCHES if test(key, list(live)))


def stay(key):
    return key in STAY


def keep(key, en):
    """(kept, reason left out)."""
    if stay(key):
        return False, "stay"
    if not en.strip():
        return False, "empty"
    if not K.LATIN_WORD.search(K.SPECIAL.sub("", en)):
        return False, "no words"
    return True, ""


def sorts(key, en):
    return K.sorts_from(SORTS, key, en)


def slot_sorts(key, en):
    """The letters of `en` with what the code glues after it (GLUE_AFTER) as its last slot."""
    return K.sorts_from(SORTS, key, en + GLUE_AFTER.get(key, ""))


def check(key, en, ua):
    """What makes `ua` unfit as the Ukrainian of `en`."""
    problems = K.base_check(en, ua, sorts(key, en))
    if stay(key):
        problems.append("a STAY key (never written)")
    if en.endswith(" ") and not ua.endswith(" "):
        problems.append("the English ends with a space (something is glued after it): keep it")
    m = re.match(r"\|c[0-9a-fA-F]{8}", en)
    if m and not ua.startswith(m.group(0)):
        problems.append("the colour code at the start moved")
    if en.count("|c") != ua.count("|c") or en.count("|r") != ua.count("|r"):
        problems.append("colour codes (|c...|r) differ in number")
    return problems
