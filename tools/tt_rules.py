"""What each slot of a TomTom template holds, the texts we never translate, and TomTom's texts glued in code.
Used by tools/make_tt_text.py.

TomTom is All Rights Reserved (CLAUDE.md "Other addons' texts"): nothing here names its English. Every entry is
keyed by the hash of the English ("bytes:djb2", UADD/Hash.lua and tools/hashtext.py `key`), read from the
installed addon by the generator. Run `python3 tools/make_tt_text.py review` to see which text a hash is.

Letters, one per slot (see UADD/Words.lua):
  v  a value (a number, a distance, coordinates, indentation spaces): kept as it is
  n  a game name (zone, quest): UALL Forever's Ukrainian, else the whole line stays English (lesson 9)
  t  another TomTom text of ours (a colour word in a theme name): our Ukrainian, else the line stays English
  f  a free name, kept as it is: a waypoint title, a profile or page name the player typed, a player name,
     another addon's name or id, an error code from the game
  w  only spaces (TomTom's own indent): kept; anything else keeps the whole line English
A %d or %f is always v. A |cff%s slot is always v. A %s with no entry here has no sort: the build refuses its
Ukrainian until one is added.

Groups (GROUPS): slots that touch (no text between them) cannot be told apart on screen: the earlier ones
always read as empty and the last one takes all the text. A group reads them as one text instead, by a
recipe on its last slot, "a SEP b": no SEP in the text, it is checked as b; one SEP, the part before it as a
and the part after it as b; two or more, the whole line stays English. 51 and 52 ("f - v"): a waypoint title,
" - ", the coordinates, or the coordinates alone. So a title that holds " - " itself keeps the line English.
The build refuses a Ukrainian that puts other text between the group's slots or changes their order.

Route (lead decision 2 and 3, made by the build): a template whose slots are only v and f, and whose Ukrainian
has no plural {..|..|..}, is put into TomTom.L itself (the swap list). One with an n, t or w slot, a group, or
a plural, keeps TomTom's English in L and is translated as a finished line where it shows (chat,
TomTomTooltip, the arrow status, the data feed). A w slot is never swapped: in TomTom.L the slot after it is
also filled with TomTom's own texts, and one of them stays English in L (the keep list K), which gave a half
line (19: the /way local line for a waypoint with no title).
"""
import re

import hashtext as H

# By the hash of the English template: one letter per %s slot, in slot order (%d/%f slots count too).
SORTS = {
    "15:cd6e0f70": "nvv",      # zone (x, y): pin tooltip, core/waypoints.lua
    "13:f092c972": "v",        # a whole number of yards: pin tooltip
    "19:a8669b8c": "wfvv",     # indent, waypoint title, coords, map id: /way local (slash.lua:28)
    "49:03257959": "nvvvv",    # zone, map id, then three ids made by tostring: /way list (slash.lua:44)
    "27:e8ed57b3": "v",        # indent spaces (slash.lua:32)
    "16:3a6b38ce": "f",        # another addon's name (core/suppress.lua)
    "65:c5852be4": "f",        # profile name (core/profiles.lua popups)
    "24:1bdc784f": "f",
    "39:3d529b1b": "f",
    "39:1bf8b8a4": "f",        # zone text the player typed (slash.lua:188)
    "63:870e3133": "vf",       # count, zone text the player typed
    "55:0fb5f3ea": "fn",       # zone text the player typed, a list of game zones
    "10:562779d5": "v",        # coords "12.3, 45.6": world map header (map_coords.lua)
    "10:787b92c4": "v",
    "8:67e3f58b": "f",         # data.from: an addon id (pin tooltip)
    "35:19fc722e": "vf",       # count, page title the player typed (paste.lua)
    "36:9933d9d7": "vf",
    "32:3565b007": "vf",
    "15:e3eab85a": "f",        # page titles
    "29:e84b3e5f": "f",
    "15:ae017d95": "t",        # a colour word of ours (core/waypoint_themes.lua:18-32, CODE below)
    "37:fb15bff6": "v",
    "28:882067da": "vn",       # count, zone
    "39:c7b069fb": "n",        # zone
    "11:86798557": "n",        # a quest title (poi.lua:113): UALL's quest route, else English
    "16:34449acc": "f",        # sender name (comm.lua:103), a saved waypoint title
    "33:4247b056": "vnv",      # coords, zone, map id made by tostring (slash.lua:22,40)
    "51:0e87e895": "fvvn",     # waypoint title, " - ", coords, zone (waypoints.lua:472)
    "52:88bde84b": "fvvn",     # (waypoints.lua:566)
    "56:2efdc2e5": "ffn",      # waypoint title, sender, zone (comm.lua)
    "60:98986d28": "f",        # an error code from the game (comm.lua:83)
}

# Touching slots read as one text (see the header): by hash, (first slot, last slot, recipe of the last slot).
GROUPS = {
    "51:0e87e895": (1, 3, "f - v"),   # title, " - " or nothing, coords (waypoints.lua:466-472)
    "52:88bde84b": (1, 3, "f - v"),   # (waypoints.lua:566)
}

# Never translated (lead decision 5): words /ttpaste compares with what the player types, a saved waypoint
# source id, the three debug lines and their "is"/"not" glue, and a line that holds no English word. Then the
# help lines whose coloured part is only command words: our Ukrainian would keep that part as TomTom writes
# it, and a piece of TomTom's English in our data is a copy (tools/check_repo.py [copy]). They stay English.
STAY = {
    "6:1e884d27", "4:7c9a1661", "4:7c9dcb54", "4:7c9a2d85", "6:192c7473", "7:c73b1d70",  # /ttpaste words
    "12:d6a5efbf",                                                                       # waypoint source id
    "41:eb955247", "42:547022be", "41:9dbecd19", "37:e4965282",                          # debug lines
    "2:00597841", "3:0b889596",                                                          # their is/not
    "18:04c9ebe2",                                                                       # no English word
    "81:9831dabf", "96:aeb2f3ad", "71:814ad743", "71:39f5bbda",                          # command-only help
}

# Texts TomTom shows from its own code, not from L (lead decision 7): (file, hash, where it shows).
# The generator reads them from these files (string literals) or from TomTom.xml (KeyValue defaultText).
CODE = [
    ("modules/crazy_arrow/crazy_arrow.lua", "42:0a3e1683", "settings dropdown: distance unit"),
    ("modules/crazy_arrow/crazy_arrow.lua", "26:8804ddec", "settings dropdown: distance unit"),
    ("modules/crazy_arrow/crazy_arrow.lua", "27:6cec3339", "settings dropdown: distance unit"),
    ("modules/crazy_arrow/crazy_arrow.lua", "32:e9f99118", "settings dropdown: distance unit"),
    ("modules/crazy_arrow/crazy_arrow.lua", "30:616284c3", "settings dropdown: distance unit"),
    ("modules/map_click.lua", "3:0b87d5c6", "settings dropdown: a key name; may stay as it is"),
    ("modules/map_click.lua", "4:7c83c97a", "settings dropdown: a key name; may stay as it is"),
    ("modules/map_click.lua", "5:0e17c5a3", "settings dropdown: a key name; may stay as it is"),
    ("modules/map_click.lua", "8:03e76a28", "settings dropdown: key names; may stay as they are"),
    ("modules/map_click.lua", "9:81ef7c11", "settings dropdown: key names; may stay as they are"),
    ("modules/map_click.lua", "10:2ac866c5", "settings dropdown: key names; may stay as they are"),
    ("modules/map_click.lua", "14:287951f3", "settings dropdown: key names; may stay as they are"),
    ("core/waypoint_themes.lua", "4:7c831b6d", "a colour word: fills the theme name template"),
    ("core/waypoint_themes.lua", "6:b3ae1660", "a colour word: fills the theme name template"),
    ("core/waypoint_themes.lua", "5:0d440a36", "a colour word: fills the theme name template"),
    ("core/waypoint_themes.lua", "9:61ae80a5", "a colour word: fills the theme name template"),
    ("core/waypoint_themes.lua", "6:c86c8a41", "a colour word: fills the theme name template"),
    ("core/waypoint_themes.lua", "6:cb0157fd", "a colour word: fills the theme name template"),
    ("core/waypoint_themes.lua", "3:0b881d20", "a colour word: fills the theme name template"),
    ("core/waypoint_themes.lua", "6:dedae2c1", "a colour word: fills the theme name template"),
    ("modules/feeds.lua", "11:fda0a0bd", "data feed text (another addon's bar)"),
    ("modules/feeds.lua", "5:0cfb99ee", "data feed text before the first update"),
    ("modules/coord_block.lua", "11:3b6fe4ee", "saved waypoint title (the arrow shows it)"),
    ("TomTom.xml", "xml:defaultText", "paste window: grey hint inside the empty edit box"),
]

# Longest Ukrainian that fits, in letters (lesson 5; stage 1 map E). By hash of the English.
MAXLEN = {
    "16:be031cb5": 21,         # paste window button, 165 px
    "5:0cf88a3b": 11,          # paste window button, 100 px
    "5:0dddd1c2": 11,
    "10:787b92c4": 10,         # world map header label (the label part, before the value)
    "10:562779d5": 10,
    "41:4dda656b": 24,         # settings button that shows the row name itself
    "14:9fb71c1d": 24,
    "17:7c8885a3": 24,
    "18:61ee04bc": 24,
}

# Where a text shows, by the file and line range of its use. First match wins.
PLACES = [
    ("core/menu.lua", 15, 30, "popup"),
    ("core/options.lua", 335, 350, "popup"),
    ("core/profiles.lua", 100, 155, "popup"),
    ("core/profiles.lua", 156, 190, "right-click menu"),
    ("core/menu.lua", 31, 200, "right-click menu"),
    ("modules/crazy_arrow/crazy_arrow.lua", 540, 610, "right-click menu"),
    ("core/waypoints.lua", 15, 50, "settings row"),
    ("modules/coord_block.lua", 30, 70, "settings row"),
    ("modules/corpse.lua", 15, 30, "settings row"),
    ("modules/feeds.lua", 35, 75, "settings row"),
    ("modules/map_click.lua", 30, 60, "settings row"),
    ("modules/map_coords.lua", 25, 65, "settings row"),
    ("modules/minimap_pins.lua", 50, 90, "settings row"),
    ("modules/worldmap_pins.lua", 45, 80, "settings row"),
    ("modules/paste.lua", 20, 51, "settings row"),
    ("modules/poi.lua", 55, 106, "settings row"),
    ("modules/crazy_arrow/crazy_arrow.lua", 90, 200, "settings row"),
    ("core/options.lua", 1, 9999, "settings page"),
    ("core/profiles.lua", 1, 9999, "settings page (profiles)"),
    ("core/waypoints.lua", 255, 305, "pin tooltip"),
    ("modules/crazy_arrow/crazy_arrow.lua", 280, 290, "arrow title"),
    ("modules/crazy_arrow/crazy_arrow.lua", 700, 900, "arrow status under the arrow"),
    ("modules/crazy_arrow/theme_", 1, 9999, "theme name (settings dropdown)"),
    ("core/waypoint_themes.lua", 1, 9999, "theme name (settings dropdown)"),
    ("modules/map_coords.lua", 150, 220, "world map header"),
    ("modules/feeds.lua", 150, 260, "data feed (another addon's bar or its tooltip)"),
    ("modules/paste.lua", 52, 200, "paste window"),
    ("modules/paste.lua", 201, 9999, "chat"),
    ("modules/slash.lua", 1, 9999, "chat"),
    ("modules/comm.lua", 1, 9999, "chat"),
    ("core/core.lua", 1, 9999, "chat"),
    ("core/waypoints.lua", 400, 9999, "chat"),
    ("modules/corpse.lua", 60, 90, "saved waypoint title (the arrow shows it)"),
]


def place(rel, line):
    for f, lo, hi, what in PLACES:
        if rel.startswith(f) and lo <= line <= hi:
            return what
    return ""


def group_problems(en, ua):
    """Why the Ukrainian ua breaks en's group (GROUPS): [] when it keeps the slots together, in order."""
    g = GROUPS.get(H.key(en))
    if not g:
        return []
    want = list(range(g[0], g[1] + 1))

    def together(text):
        seq = [t[2][1] if t[0] == "slot" and t[2][0] == "arg" else None for t in H.tokens(text)]
        return any(seq[i:i + len(want)] == want for i in range(len(seq)))
    out = [] if together(en) else [f"group slots {g[0]}-{g[1]} do not touch in the English (tt_rules GROUPS)"]
    return out + ([] if together(ua) else [f"slots {g[0]}-{g[1]} must stay together, in order, with nothing between"])


def sorts(en):
    """[letter or None] for each slot of one line of a template, by slot number. The last slot of a group
    (GROUPS) gets its recipe ("f - v") in place of its letter."""
    out = _letters(en)
    g = GROUPS.get(H.key(en))
    if g and len(out) >= g[1]:
        out[g[1] - 1] = g[2]
    return out


def _letters(en):
    over = SORTS.get(H.key(en), "")
    toks = H.tokens(en)
    out, n = [], 0
    for i, t in enumerate(toks):
        if t[0] != "slot":
            continue
        n += 1
        before = "".join(x[1] for x in toks[:i] if x[0] == "lit")
        if t[1] == "s" and re.search(r"\|c(?:ff)?$", before):
            out.append("v")
        elif n <= len(over):
            out.append(over[n - 1])
        elif t[1] != "s":
            out.append("v")
        else:
            out.append(None)
    return out
