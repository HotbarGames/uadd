"""Which RareScanner texts UADD_RareScanner translates, what each template slot holds, and the review batches.
Used by tools/make_rs_text.py.

RareScanner is All Rights Reserved (CLAUDE.md "Other addons' texts"): nothing here names its English. Every
entry is keyed by its AceLocale key (AL["KEY"]); the English is read from the installed addon by the
generator. Run `python3 tools/make_rs_text.py review` to see which text a key is.

Which keys (lead decision, stage 1 map A):
  - a non-id key named as a string in RareScanner's Lua or XML (not in a file of DEAD_FILES only);
  - NOTE_<id> (and NOTE_<id>_<map>, EVENT_<id>, ZONE_<map>) only when the id (and map) is in its Tables:
    they are read with a built key (Core/Plugins/Tooltips/RSNotes.lua, RSEventDB, RSMapDB);
  - never CONTAINER_<id>: treasure names are game names, UALL Forever's or English (lesson 9);
  - never a key of STAY or GAME.

Letters, one per slot (see UADD/Words.lua):
  v  a value (a count, a time, a clock, an id, a colour, an icon): kept as it is
  n  a game name (NPC, treasure, item, item class, appearance): UALL Forever's Ukrainian, else English
  f  a free text, kept as it is: a custom NPC group name, a value the player typed, a profile name, a
     folder path, a key binding action, a macro name, a command word
  t  another text of ours (an AL key filled in by RareScanner): translate that key too; which keys: INNER
  u  a time span RareScanner writes in its own English units ("1h 5m", RSTimeUtils.FormatShortDuration):
     the module keeps the whole line English (a test finds every such slot in its code)
A %d or %f is always v. A |cff%s slot is always v. A %s with no entry here has no sort: the build refuses its
Ukrainian until one is added.
Lua's string.format has no %2$s: the Ukrainian keeps every slot in the English order.
"""
import re

# Never translated, with the reason.
STAY = {
    "CHAT_NOTIFICATION_RARE": "sent to the General chat channel (Core/Libs/RSHyperlinks.lua): other players read "
                              "it, and RareScanner on their side may read it too",
    "CUSTOM_NPC_GROUP_DEFAULT": "saved as the default group's name in the player's RareScanner data "
                                "(RSNpcDB.SetCustomNpcGroupByKey): it would stay Ukrainian with the module off",
    "EXPLORER_CUSTOM_ITEMS_GROUP_DEFAULT": "saved as the first custom item group's name in the player's RareScanner "
                                           "data (RSCollectionsDB.AddItemGroup): the same",
    "CONTAINER": "a nameless treasure's name (RSButtonHandler), saved with SetContainerName and compared with "
                 "AL in RSContainerDB.GetContainerName: ours would stay in the saved data",
}

# Literal keys whose text is a game name (a chest or a treasure): UALL Forever's or English (lesson 9).
GAME = {
    "CONTAINERS_BATTERED_CHESTS": "a chest name (RSContainerDB.GetContainerName)",
    "CONTAINERS_SOLID_CHESTS": "a chest name (RSContainerDB.GetContainerName)",
    "CONTAINERS_ALLIANCE_CHESTS": "a chest name (RSContainerDB.GetContainerName)",
}

# Files whose texts never show on Forever (stage 1 map C): a key used only in them is left out.
DEAD_FILES = {
    "Core/SpecialEvents/MidnightPrePatch.lua": "retail pre-patch event",
    "Core/SpecialEvents/ShadowlandsPrePatch.lua": "retail pre-patch event",
}

# Keys read with a built name (AL[string.format(...)]): (regex of the key, what must be in the Tables).
DYNAMIC = [
    (re.compile(r"^NOTE_(\d+)$"), "entity"),
    (re.compile(r"^NOTE_(\d+)_(\d+)$"), "entity+map"),
    (re.compile(r"^EVENT_(\d+)$"), "event"),
    (re.compile(r"^ZONE_(\d+)$"), "map"),
]
ID_KEY = re.compile(r"^(CONTAINER|NOTE|NOTE_GLYPH|EVENT|ZONE)_\d")

# By AceLocale key: one letter per slot, in slot order (%d/%f slots count too).
SORTS = {
    "ALARM_MESSAGE": "n",                         # NPC, treasure or event name (RareScanner.lua)
    "PRE_EVENT": "n",                             # the same name, scanner button title
    "ENTITY_FILTERED": "n",                       # the scanner button title (a name, or PRE_EVENT's line)
    "EXPLORER_AUTOFILTER": "n",                   # NPC or treasure name (RSCollectionsDB, 8 places)
    "CHAT_NOTIFICATION_RARE": "nf",               # STAY: name, a waypoint link
    "CUSTOM_NPC_DELETE_NPC_CONFIRM": "n",         # NPC name (RSNpcDB.GetNpcName)
    "EXPLORER_MISSING_APPEARANCES": "vn",         # count, appearance name
    "LOOT_CATEGORY_FILTERED": "nn",               # item class, item subclass (game API)
    "LOOT_CATEGORY_NOT_FILTERED": "nn",
    "LOOT_TOGGLE_FILTER": "nn",
    "LOOT_INDIVIDUAL_FILTERED": "n",              # item link
    "LOOT_INDIVIDUAL_NOT_FILTERED": "n",
    "TELEMETRY_REPORT_TITLE": "nv",               # coloured NPC name, NPC id
    "PRE_PATCH_MISSING": "vn",
    "PRE_PATCH_MIDNIGHT_MISSING": "vn",
    "PRE_PATCH_NEXTSPAWN": "n",
    "PRE_PATCH_SPAWNINGTIMER": "v",
    "COLLECTION_FILTERS_PROFILE_BACKUP_CREATED": "f",   # profile name
    "CUSTOM_NPC_ERROR1_DISPLAYID": "f",           # values the player typed (RSCustomNpcs.lua)
    "CUSTOM_NPC_ERROR1_GROUP": "f",
    "CUSTOM_NPC_ERROR2_COORDX": "f",
    "CUSTOM_NPC_ERROR2_COORDY": "f",
    "CUSTOM_NPC_ERROR2_ITEMID": "f",
    "CUSTOM_NPC_ERROR2_MAPID": "f",
    "CUSTOM_NPC_ERROR2_NPCID": "f",
    "CUSTOM_NPC_ERROR3_COORDX": "f",
    "CUSTOM_NPC_ERROR3_COORDY": "f",
    "CUSTOM_NPC_ERROR3_MAPID": "f",
    "CUSTOM_NPC_ERROR3_NPCID": "f",
    "CUSTOM_NPC_ERROR4_NPCID": "f",
    "CUSTOM_NPC_IMPORT_OK": "f",                  # an imported NPC id
    "CUSTOM_NPC_GROUP_DELETE_CONFIRM": "f",       # the group name the player typed
    "CUSTOM_NPC_VALIDATION_CHAR": "v",            # the allowed characters
    "ENABLE_SCAN_MACRO_CREATED": "fv",            # macro name, icon
    "EXPLORER_CUSTOM_ITEMS_TOOLTIP_ID": "v",
    "EXPLORER_CUSTOM_ITEMS_WRONG_IDS_CHAT": "f",  # ids the player typed
    "EXPLORER_FILTER_CUSTOM": "f",                # custom NPC group name
    "LOOT_EXPLORER_SHOW_MISSING_CUSTOM": "f",
    "LOOT_EXPLORER_SHOW_MISSING_CUSTOM_DESC": "f",
    "MAP_MENU_FILTER_ALL_GROUP": "f",
    "MAP_MENU_SHOW_CUSTOM_NPC_GROUP": "f",
    "KEYBINDING_ERROR": "f",                      # a key binding action
    "SOUND_CUSTOM_FILE_INFO1": "f",               # a folder path
    "TELEMETRY_USAGE": "f",                       # a command word
    "EXPLORER_CREATE_BACKUP_DESC": "t",           # AL keys filled in by RareScanner
    "EXPLORER_FILTERING_DESC": "tt",
    "EXPLORER_FILTERING_DIALOG": "tttt",
    "FILTER_DESC": "ttt",
    "IGNORE_WORLDMAP_SHOW_ON_MINIMAP": "t",
    "IGNORE_WORLDMAP_SHOW_ON_MINIMAP_DESC": "t",
    "SOUND_CUSTOM_FILE_INFO3": "t",
    "EXPLORER_FOUND_CONTAINERS": "v", "EXPLORER_FOUND_NPCS": "v",
    "EXPLORER_MISSING_MOUNTS": "v", "EXPLORER_MISSING_PETS": "v", "EXPLORER_MISSING_TOYS": "v",
    "MAP_ROUTES_CALCULATING": "v", "MAP_SPAWN_SPOTS_COLOUR": "v",
    "MAP_TOOLTIP_CONTAINER_COUNTER": "v", "MAP_TOOLTIP_NPC_COUNTER": "v", "MAP_TOOLTIP_RESET": "v",
    "MAP_TOOLTIP_SEEN": "v",
    "TELEMETRY_EXPORT_SUMMARY": "vv", "TELEMETRY_LEARNED_SCHEDULE": "v",
    "TELEMETRY_SAMPLES": "vv", "TELEMETRY_TOTAL_NPCS": "v",
    # u: a time span in RareScanner's own English units (RSTooltip.lua, RSTelemetry.lua): the line stays English
    "MAP_TOOLTIP_NEXT_SPAWN": "uv", "MAP_TOOLTIP_RESPAWN_APPROX": "u", "MAP_TOOLTIP_RESPAWN_ESTIMATE": "uu",
    "MAP_TOOLTIP_RESPAWN_EXACT": "u", "MAP_TOOLTIP_RESPAWN_IN": "u", "MAP_TOOLTIP_RESPAWN_IN_APPROX": "u",
    "MAP_TOOLTIP_RESPAWN_IN_RANGE": "uu", "MAP_TOOLTIP_RESPAWN_POSSIBLE": "u", "MAP_TOOLTIP_RESPAWN_RANGE": "uu",
    "TELEMETRY_DATABASE_EXACT": "u", "TELEMETRY_DATABASE_RANGE": "uu", "TELEMETRY_EXACT_LEARNED": "u",
    "TELEMETRY_LAST_RESPAWN": "u", "TELEMETRY_NEXT_RESPAWN": "uv", "TELEMETRY_OBSERVED_RANGE": "uu",
    "TELEMETRY_RESPAWN_UNCONFIRMED": "u",
}
# The AL keys RareScanner fills into each t slot, in order. The module (Module.lua INNER, kept the same by
# tools/test_rs_text.py) uses a template only when each of these is ours too: else the line stays English.
INNER = {
    "EXPLORER_CREATE_BACKUP_DESC": ("EXPLORER_FILTERING",),
    "EXPLORER_FILTERING_DESC": ("EXPLORER_FILTERS", "EXPLORER_FILTER_COLLECTIONS"),
    "EXPLORER_FILTERING_DIALOG": ("EXPLORER_FILTERS", "EXPLORER_FILTER_COLLECTIONS", "EXPLORER_FILTER_MOUNTS",
                                  "EXPLORER_FILTER_TOYS"),
    "FILTER_DESC": ("FILTER_TYPE_ALL", "FILTER_TYPE_WORLDMAP", "FILTER_TYPE_ALERTS"),
    "IGNORE_WORLDMAP_SHOW_ON_MINIMAP": ("MAP_MENU_SHOW",),
    "IGNORE_WORLDMAP_SHOW_ON_MINIMAP_DESC": ("MAP_MENU_SHOW",),
    "SOUND_CUSTOM_FILE_INFO3": ("SOUND_RELOAD",),
}
# Templates whose n slot can be filled from RareScanner's own English data, not the game: a treasure name
# falls back to AL["CONTAINER_<id>"] or AL["CONTAINERS_*_CHESTS"] (RSContainerDB.GetContainerName), which we
# leave English. Such a line shows our Ukrainian around an English name (CLAUDE.md "No half translations"):
# the module must keep the whole line English when the name is not Ukrainian.
RISKY = {
    "ALARM_MESSAGE": "treasure name may be RareScanner's English (CONTAINER_<id>)",
    "PRE_EVENT": "treasure or event name may be RareScanner's English",
    "ENTITY_FILTERED": "the title holds the name (and maybe PRE_EVENT's line)",
    "EXPLORER_AUTOFILTER": "treasure name may be RareScanner's English (RSCollectionsDB 646-820)",
}

# Review batches (stage 1 map H): first match of a path part wins; a key used in several files goes to the
# lowest batch of its uses.
BATCHES = [
    (1, "Options map", ("Options/RSMapOptions",)),
    (2, "Options loot, loot tooltip and loot bar", ("Options/RSLootOptions", "RSLootTooltip", "RSLoot")),
    (3, "Options general, display, sound", ("Options/RSGeneralOptions", "Options/RSDisplayOptions",
                                            "Options/RSSoundOptions")),
    (4, "Options chat, custom NPCs and their errors", ("Options/RSChat", "Options/RSCustomNpcs",
                                                      "RSCustomNpcs")),
    (5, "Filters and the options root", ("FiltersOptions", "Options/RSOptions", "Options/RSCollections")),
    (6, "Explorer, collections, popups", ("ExplorerPlugin", "RSCollectionsDB", "RSStaticPopups")),
    (7, "World map menu, pin tooltip, search, minimap, commands, telemetry",
     ("RSWorldMapButtonMixin", "Tooltips/RSTooltip", "RSSearch", "RSNavigation", "RSMinimap",
      "RSAddonCompartment", "RSCommandLine", "Telemetry")),
    (8, "The rest", ("",)),
]


def batch_of(path):
    for n, _, parts in BATCHES:
        if any(p in path for p in parts):
            return n
    return BATCHES[-1][0]


SLOT = re.compile(r"%%|%[-+ #0-9.]*[a-zA-Z]")


def slots(en):
    """[printf conversion letter] of each slot of `en`, in order (%% is no slot)."""
    return [m.group(0)[-1] for m in SLOT.finditer(en) if m.group(0) != "%%"]


# What must stay, in the same order: slots, colour codes, icons, links, atlas marks, {tags}, line breaks.
SPECIAL = re.compile(r"%%|%[-+ #0-9.]*[a-zA-Z]|\|c[0-9a-fA-F]{8}|\|r|\|T[^|]*\|t|\|A[^|]*\|a|\|H[^|]*\|h|\|h"
                     r"|\|n|\{[a-z]+:\d+\}|\n")
POSITIONAL = re.compile(r"%\d+\$")
PLURAL = re.compile(r"\{[^{}]*\|[^{}]*\}")
CYR = re.compile(r"[Ѐ-ӿ]")
LATIN_WORD = re.compile(r"[A-Za-z]{2,}")
WS = " \t\n\r\v\f"


def ends(line):
    return (len(line) - len(line.lstrip(WS)), len(line) - len(line.rstrip(WS)))


def check(key, en, ua):
    """What makes `ua` unfit for AL[key] = en (empty: fit)."""
    if key in STAY:
        return ["a STAY key (tools/rs_rules.py): never translated"]
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
    letters = sorts(key, en)
    if None in letters:
        problems.append(f"slot {letters.index(None) + 1} is not sorted (tools/rs_rules.py SORTS)")
    return problems


def sorts(key, en):
    """[letter or None] for each slot of `en` (the text of AL[key]), in order."""
    over = SORTS.get(key, "")
    out = []
    for i, m in enumerate(x for x in SLOT.finditer(en) if x.group(0) != "%%"):
        before = en[:m.start()]
        if m.group(0)[-1] != "s" or re.search(r"\|c(?:ff|FF)?$", before):
            out.append("v")
        elif i < len(over):
            out.append(over[i])
        else:
            out.append(None)
    return out
