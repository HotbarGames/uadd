"""Which LayerSwap strings players see, and which must stay English. Used by tools/make_lsw_data.py.

skip_reason(item, line_text, in_debug) returns None for a text to translate, or a short reason why it is
left out:
  debug     output of the debug slash commands (DEBUG_STARTS blocks)
  protocol  what other players and addons read: channel names, the addon-message prefix and words, the
            whisper asking for an invite and its variants, the English word lists that read other
            players' chat, the game's refusal lines it reads back
  name      the addon's own name
  path      textures, fonts, sounds
  code      compared or used as a key, given to a technical call or field (frame points, events,
            SavedVariables keys, slash words)
  ident     one identifier-like word that is not given to a text call
  slash     a help line that is only a slash command
  data      lower-case match lists
  nowords   no two letters in a row once colour codes and %s are taken out
The shared lists (calls, fields, codes) come from tools/fxpb_rules.py; only LayerSwap's own are here.
"""
import re

import fxpb_rules as F
import hashtext as H

KEYWORDS = F.KEYWORDS
PATH, CODES, SPEC, IDENT, FONT_FLAGS = F.PATH, F.CODES, F.SPEC, F.IDENT, F.FONT_FLAGS
DEBUG_STARTS = [r'if (cmd|sub|msg) == "(debug|dump|trace)" then', r"^function (Who\.phase|Near\.probe)\("]
# elseif branches of the slash command that are measurements for the author (to the next elseif/else/end)
DEBUG_BRANCHES = [r'elseif msg == "(loot|phase|spot)"']
# calls whose whole argument list is a SavedVariables trace: every non-text string inside them is code
LOG_CALLS = {"log", "logEviction"}
STAY_ENGLISH = {"LayerSwap", "LS"}
# Protocol: what goes over the wire or is read back from other players' chat.
PROTOCOL = re.compile(r"^(?i:inv layer|<LS\b|\[AutoLayer\]|LayerSwap[:;])|^layer$")
CODE_CALLS = F.CODE_CALLS | {"SendAddonMessage", "sendAddon", "send", "whisper", "Whisper", "InviteUnit",
                             "JoinTemporaryChannel", "GetChannelName", "RegisterForClicks", "strfind",
                             "strmatch", "SetUserPlaced", "NewDataObject", "Register", "GetPlayerInfoByGUID",
                             "UnitGUID", "UnitPosition", "GetBestMapForUnit", "SetFixedFrameStrata",
                             "log", "logEviction"}   # log: a SavedVariables trace, never shown
# one argument of the addon's own functions that only reaches the log, a wire note or a key
CODE_ARGS = {"drop#1", "skip#1", "want#1", "setLoot#2", "removeHosted#1", "world#2", "phase#1", "add#1",
             "note#3", "sendNote#1", "addText#2", "check#1", "sameSkip#2", "seenSkip#2", "sameSkip#3",
             "seenSkip#3"}
CODE_FIELDS = F.CODE_FIELDS
CODE_SETS = F.CODE_SETS | {"CHANNEL", "PREFIX", "ADDON_PREFIX", "own", "at", "readBy", "c", "note", "ping"}
# a table entry that is shown (one part of a status line), by "<bytes>:<hash>" key (H.key)
TABLE_TEXT = {"12:bf3cc071"}
# single texts that are a wire note, a state key or a log word, by "<bytes>:<hash>" key (H.key)
CODE_KEYS = {"18:61e92f0c", "31:ac9f1aa4", "10:24e3843b", "10:709c04e0", "11:27d4f13f", "11:3b6fa68f", "11:6213f16f", "12:f0711a91",
             "13:5ad381bb", "14:9ed1891c", "15:a42eae8d", "15:a6eebaf7", "15:a98c3e07", "15:e3b9c775",
             "16:f7f0f2ee", "17:6ae9a69f", "17:b26450fd", "19:319d252f", "19:ad72ae5c", "24:f9fac8b6",
             "25:156dbaef", "33:9291c290", "4:7c887790", "5:0e063143", "6:1062517c", "6:c320d7b4",
             "7:50bf5a03", "7:da158e07", "8:462701f3", "8:bd515302", "9:4356a313", "9:667e3f5f",
             "9:9d1db0de", "9:dff36733", "11:dedf4143", "8:bd4d9cc1"}
TEXT_CALLS = F.TEXT_CALLS | {"say", "setNotice", "setButtonText", "addText", "makeButton", "addCheckbox", "check"}
TEXT_FIELDS = F.TEXT_FIELDS
# Whole texts glued at run time from pieces (see tools/fxpb_rules.py JOINED): "<bytes>:<hash>" keys of
# the addon's own literals and glue with no words.
JOINED = [
    ["%s", "7:b0229352"],
    ["%s", "8:b474fe05"],
    ["%s", "7:b0229352", "%s"],
    ["%s", "8:b474fe05", "%s"],
    [", %s", "13:48315fe0", "13:3bfbb2d4"],
    ["%s", "8:54e59d81", ", %s", "19:8bad343b"],
    ["%s", "8:54e59d81", ", %s", "9:592d9b44"],
    ["%s", "8:54e59d81", ", %s", "13:2e32c9eb"],
    ["%s", "8:54e59d81", ", %s", "13:2e32c9eb", ", %s", "19:8bad343b"],
    ["%s", "8:54e59d81", ", %s", "13:2e32c9eb", ", %s", "9:592d9b44"],
    ["12:bf3cc071", ", %s", "19:8bad343b"],
    ["12:bf3cc071", ", %s", "9:592d9b44"],
    ["12:bf3cc071", ", %s", "13:2e32c9eb"],
    ["12:bf3cc071", ", %s", "13:2e32c9eb", ", %s", "19:8bad343b"],
    ["12:bf3cc071", ", %s", "13:2e32c9eb", ", %s", "9:592d9b44"],
    ["3:0b881142", "%s", "4:7c70689c", "%s", "58:85ca696e"],
    ["3:0b881142", "%s", "4:7c70689c", "%s", "35:577c0e02"],
    ["%s", "27:d2eb3cf7", "%s."],
    ["%s", "28:9ad6e16a", "%s."],
    ["%s", "22:80b4f84d"],     # minimap tooltip: the layer's name, the wide gap, its host mark (lesson 7)
]


def plain(text):
    return F.plain(text)


def _sink_parts(sink):
    kind, _, rest = sink.partition(":")
    return kind, rest.split("#")[0]


def is_text_sink(sink):
    kind, name = _sink_parts(sink)
    return (kind == "call" and name in TEXT_CALLS) or (kind == "field" and name in TEXT_FIELDS)


def skip_reason(item, line_text, in_debug, in_log=False):
    text, sink = item.text, item.sink
    words = plain(text)
    kind, name = _sink_parts(sink)
    if in_debug:
        return "debug"
    if in_log and not is_text_sink(sink):
        return "code"                                  # inside log(...): the trace only
    if text in STAY_ENGLISH or words in STAY_ENGLISH:
        return "name"
    if PROTOCOL.match(text) or PROTOCOL.match(words):
        return "protocol"
    if PATH.search(text):
        return "path"
    if not re.search(r"[A-Za-z]{2}", words):
        return "nowords"
    if sink in ("cmp", "index"):
        return "code"
    if F.CAMEL_ID.fullmatch(text) or text in FONT_FLAGS or re.fullmatch(r"[A-Z][A-Z0-9]*_[A-Z0-9_]+", text):
        return "code"
    if kind == "call" and (name in CODE_CALLS or sink[5:] in CODE_ARGS):
        return "code"
    if H.key(text) in CODE_KEYS:
        return "code"
    if (kind == "field" and name in CODE_FIELDS) or (kind == "set" and (name in CODE_SETS or name.startswith("SLASH_"))):
        return "code"
    if IDENT.match(text) and not is_text_sink(sink) and not re.fullmatch(r"[A-Z][a-z]+", text):
        return "ident"
    if text.startswith("/") and " - " not in text and not re.search(r"\s[A-Za-z]{3,}\s+[a-z]{3,}", text):
        return "slash"
    if sink == "table" and text[:1].islower() and H.key(text) not in TABLE_TEXT:
        return "data"
    if sink == "field:?" and text[:1].islower():
        return "code"                                  # diagnostic fields kept for the log
    return None
