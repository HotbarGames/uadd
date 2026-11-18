"""Which ForeverXP Bar strings players see, and which must stay English. Used by tools/make_fxpb_data.py.

skip_reason(item, line_text) returns None for a text to translate, or a short reason why it is left out:
  debug     output of the debug slash commands and dump helpers (DEBUG_STARTS blocks, DEBUG_TEXT)
  protocol  addon-message prefix "FXPB", channel "FXPBGlobal", "[FXPB]" chat lines and their payloads
  name      names that stay English (the addon's own name, the default race name sent to other players)
  path      textures, fonts, sounds
  code      compared or used as a key, given to a technical call or field (frame points, events, theme
            ids, SavedVariables keys, font flags, slash words), or parsed back from game chat
  ident     one identifier-like word that is not given to a text call
  slash     a help line that is only a slash command
  data      lower-case match lists (buff names the addon looks for), sample racer names
  nowords   no two letters in a row once colour codes and %s are taken out
"""
import re

KEYWORDS = {"and", "break", "do", "else", "elseif", "end", "false", "for", "function", "goto", "if", "in", "local",
            "nil", "not", "or", "repeat", "return", "then", "true", "until", "while"}

# Blocks (if/function ... end) whose first line matches: debug output only.
DEBUG_STARTS = [r'if cmd == "(globalpeers|repdebug|flightdebug|questdebug|globaldebug|blizzdebug)" then',
                r"function Camp\.dump\(", r"^\s*if learn then\s*$", r"function Ins\.testHybridTextures\(",
                r"function Timing\.DebugText\("]
DEBUG_TEXT = re.compile(r"^(REP|FLIGHT|QUEST|GLOBAL) DEBUG|^GLOBAL PEERS|^settings check|^#%d id=%s|^loaded %d values$")

STAY_ENGLISH = {"ForeverXP Bar", "ForeverXPBar", "Forever Challenge XP", "XP Race", "FXPB", "FXPBGlobal",
                "|cff8ee6deForeverXP Bar|r %s", "|cff8ee6deForeverXP Bar|r"}
PROTOCOL = re.compile(r"^\[?FXPB")
NAME_TEXT = re.compile(r"^%sXP\|r Bar  %s[\d.]+\|r$")      # the title with the version number
PATH = re.compile(r"\\|\.(tga|blp|ttf|otf|ogg|mp3)\b|^Interface/", re.I)

# Calls whose string arguments are never shown as they are.
CODE_CALLS = {
    "SetPoint", "CreateFrame", "SetScript", "CreateTexture", "CreateFontString", "SetJustifyH", "SetJustifyV",
    "SetFrameStrata", "RegisterForDrag", "RegisterForClicks", "HookScript", "hooksecurefunc", "RegisterEvent",
    "UnregisterEvent", "SetBlendMode", "SetTexture", "SetFont", "SetAtlas", "GetScript", "SetGradient", "_newBox",
    "hybridTexture", "grad", "stroke", "match", "find", "gsub", "gmatch", "sub", "rawget", "UnitName", "UnitClass",
    "UnitLevel", "UnitFactionGroup", "UnitSex", "UnitExists", "UnitIsUnit", "UnitBuff", "UnitAura", "pcall",
    "LibStub", "List", "Fetch", "StaticPopup_Show", "DisableAddOn", "EnableAddOn", "GetChannelName",
    "JoinChannelByName", "LeaveChannelByName", "addonSend", "sendGoal", "SendAddonMessage",
    "RegisterAddonMessagePrefix", "flightTimingCall", "_resizableFont", "step", "startupStep", "applyPosition",
    "SetOwner", "SetNormalTexture", "SetHighlightTexture", "SetPushedTexture", "SetDisabledTexture",
    "SetCheckedTexture", "StartSizing", "IsMouseButtonDown", "GetAuraDataByIndex", "date", "PlaySoundFile",
    "PlaySound", "GetCVar", "SetCVar", "GetCVarBool", "CreateMacro", "EditMacro", "GetMacroIndexByName",
    "IsAddOnLoaded", "GetAddOnMetadata", "SetDrawLayer", "SetVertexColor", "createRace", "rep", "upper", "lower",
    "byte", "char", "split", "strsplit", "tonumber", "select", "type", "error", "assert", "SetShadowColor",
    "SetTexCoord", "SetFontObject", "EnableMouse", "SetMovable", "SetClampedToScreen", "SetAttribute",
    "SetBackdrop", "IsShown", "C_Timer", "After", "NewTicker", "SetHyperlink", "GetItemInfo", "GetSpellInfo",
    "IsSpellKnown", "C_ChatInfo", "sendChannel", "sendGuild", "IsInGroup", "IsInRaid", "GetNumGroupMembers",
    "mk", "SendChatMessage", "concat", "tostring",
}
# Arguments that are ids, not words (tab and page keys, banner kinds, popup names, icon kinds).
CODE_ARGS = {"makeTab#1", "makeCompanionTab#1", "newPage#1", "switchTab#1", "switchCompanionTab#1", "SwitchTab#1",
             "openCompanion#1", "switchOptionsSubTab#1", "banner#1", "finish#1", "makeRecordIcon#2", "iconButton#1",
             "popup#1", "addSource#3", "newFS#6", "add#2", "_slice9#2", "button#7"}
# Button looks and page ids written as words ("primary", "barNew"): never shown.
STYLE_IDS = {"primary", "danger"}
CAMEL_ID = re.compile(r"[a-z]+[A-Z][A-Za-z0-9]*")
# Table fields and variables that hold ids, keys, paths or settings, not words.
CODE_FIELDS = {"point", "relPoint", "relativePoint", "key", "flags", "class", "icon", "path", "bgFile", "edgeFile",
               "kit", "colorPreset", "textStyle", "cardTheme", "raceView", "fontInside", "fontOutside",
               "campTimerFont", "racePanelFont", "value", "macroStatus", "p", "r", "id", "theme", "font", "sound",
               "file", "tex", "texture", "atlas", "event", "prefix", "channel", "kind", "mode", "style", "anchor",
               "side", "unit", "cvar", "token", "type", "cmd", "keyName", "dbKey", "setting", "opt", "state"}
CODE_SETS = {"macroStatus", "cvarStatus", "CVAR_NAME", "MACRO_NAME", "MACRO_TAG", "GCHAN", "raceKey", "key",
             "SPARK", "STRIPE_TEX", "SOUND_DIR", "FONT_DIR", "BAR_FONT", "BOLD_FONT", "DIR", "GUIDE_VERSION",
             "fmt", "addon", "ADDON", "PREFIX", "CHANNEL", "cmd", "sub", "rest", "event", "kind", "mode", "unit",
             "dbKey", "state", "source", "view", "side", "cardTheme", "cardAuto", "textStyle", "theme", "point", "k",
             "activeProfile", "raceView", "faction"}
# Calls whose string arguments are shown (labels, chat lines, tooltips). One plain word is kept here.
TEXT_CALLS = {"SetText", "printMsg", "AddLine", "AddDoubleLine", "label", "addCheck", "addHeader", "addSlider",
              "addDropdown", "addColorSwatch", "addChoiceN", "addChoice", "addButton", "note", "caption", "button",
              "banner", "buffExpiryBanner", "announce", "makeTab", "makeCompanionTab", "cardSettingButton",
              "footerButton", "heroCard", "makePage", "makeRecordIcon", "iconButton", "raceBtn", "popup",
              "styleText", "finish", "editBox", "fontListFn", "SetFormattedText", "AddMessage", "SetTitle",
              "setText", "mk", "tip", "line", "row", "header", "title", "say", "warn", "msg", "status", "hint"}
TEXT_FIELDS = {"text", "label", "name", "button1", "button2", "title", "desc", "tooltip", "tip", "hint", "short",
               "active", "travel", "idle", "town", "flight", "dead", "help", "sub", "subtitle", "caption"}

# Whole texts the addon glues together at run time from pieces the scanner lists one by one (a
# table.concat with a bullet, an optional suffix, a literal behind an `or`, a count before a word).
# Each is a list of parts joined as they are: a "<bytes>:<hash>" key is one of the addon's own string
# literals (tools/hashtext.py key; no English kept here), anything else is glue with no words. The tool
# lists them in a last area, "joined", while all their pieces are still in the addon; the test checks that.
JOINED = [
    ["|cFFFF9A8A~%s", "8:2d527dd2", " |cFFFFFFFF•|r |cFFFFD27A~%s", "9:ed130558"],   # kills and quests to level, each in its colour
    ["13:583cea8f", "%s  (%s", "7:7610643f"],   # XP gained with the hourly rate
    # Time to level with the hourly rate, under the bar: its own short Ukrainian, so the big left line
    # stays clear of the Completed/Rested line on a narrow bar (the nested "%s XP/Hour" is longer).
    ["13:6fe4bc8c", "%s (%s", "8:380b5d7a", ")"],
    ["6:c08d2fdd", "%d • %.1f%%"],   # text styles: level and percent
    ["%s", "6:58e93956", " • ", "10:5684dfcc", "%s • %.1f%%"],   # text styles: rate, time to level, percent
    ["%s", "6:58e93956", " • %.1f%%"],   # text styles: rate and percent
    ["10:5684dfcc", "%s • %.1f%%"],   # text styles: time to level and percent
    ["|cff4fd8ff%.1f%%|r", "28:eae4bb71"],   # percent with the quest part
    ["19:6aae364a", "%s", "21:fffa5ffd"],   # session time with the paused mark
    ["8:5374b59b", "%s", "23:058cc7c4"],   # the built-in profile line
    ["6:0b3243fd", "%s", "12:2b850e26", "%s  (%s)"],   # a level time on the record panel
    ["12:f40fe000", "%s ", "7:6e987a58", "%s"],   # race goals
    ["18:3bf2a73b", "%s"],
    ["23:b20d97f8", "%s", "4:7c704c40", "%s"],
    ["23:b20d97f8", "%s"],
    ["23:f0b2bcbd", "%s", "4:7c704c40", "%s"],
    ["23:f0b2bcbd", "%s"],
    ["32:9f7f145f", "%s", "4:7c704c40", "%s."],
    ["%d", "7:b0229352"],   # player counts
    ["%d", "8:b474fe05"],
    ["%d", "7:b0229352", "13:322b66fe"],
    ["%d", "8:b474fe05", "13:322b66fe"],
    ["6:1c443945", "%s", "35:c2e4f00e"],   # camp buff answers
    ["6:1c443945", "%s", "20:d9b6a1f8"],
    ["35:89560e06", " |cFFFFFFFF•|r ", "26:fbd2ad9f"],   # completed and rested, each in its colour
]

FONT_FLAGS = {"OUTLINE", "THICKOUTLINE", "MONOCHROME", "OUTLINE, MONOCHROME", "OUTLINE,MONOCHROME"}
IDENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
SPEC = re.compile(r"%(?:\d+\$)?[-+ #0]*\d*(?:\.\d+)?[sdifgxXc%]")
CODES = re.compile(r"\|cff(?:%02x){3}|\|c[0-9a-fA-F]{8}|\|r|\|T[^|]*\|t|\|H[^|]*\|h|\|n|\n")


def plain(text):
    """The words of a text: colour codes, escapes and %s specs taken out."""
    return SPEC.sub(" ", CODES.sub(" ", text)).strip()


def _sink_parts(sink):
    """'call:Name#2' -> ('call', 'Name'); 'field:text' -> ('field', 'text')."""
    kind, _, rest = sink.partition(":")
    return kind, rest.split("#")[0]


def is_text_sink(sink):
    kind, name = _sink_parts(sink)
    return (kind == "call" and name in TEXT_CALLS) or (kind == "field" and name in TEXT_FIELDS)


def skip_reason(item, line_text, in_debug):
    text, sink = item.text, item.sink
    words = plain(text)
    kind, name = _sink_parts(sink)
    if in_debug or DEBUG_TEXT.search(text):
        return "debug"
    if text in STAY_ENGLISH or words in STAY_ENGLISH:
        return "protocol" if text.startswith("FXPB") else "name"
    if PROTOCOL.match(text) or PROTOCOL.match(words):
        return "protocol"
    if PATH.search(text):
        return "path"
    if NAME_TEXT.match(text):
        return "name"
    if not re.search(r"[A-Za-z]{2}", words) or re.fullmatch(r"[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?|%\.%sf\w", text):
        return "nowords"
    if sink in ("cmp", "index"):
        return "code"
    if text in STYLE_IDS or CAMEL_ID.fullmatch(text):
        return "code"
    if text in FONT_FLAGS or re.fullmatch(r"[A-Z][A-Z0-9]*_[A-Z0-9_]+", text):
        return "code"                                  # font flags, popup names and other ALL_CAPS ids
    if kind == "call" and (name in CODE_CALLS or sink.split(":", 1)[1] in CODE_ARGS) and not (name == "mk" and not text.isupper()):
        return "code"
    if kind == "call" and name == "add" and PATH.search(line_text):
        return "name"                                  # font names in the font menu (Friz Quadrata, Arial Narrow)
    if (kind == "field" and name in CODE_FIELDS) or (kind == "set" and (name in CODE_SETS or name.startswith("SLASH_"))):
        return "code"
    if kind == "field" and name == "name" and "class =" in line_text:
        return "data"                                  # sample racers on the preview leaderboard
    if IDENT.match(text) and not is_text_sink(sink) and not re.fullmatch(r"[A-Z][a-z]+", text):
        return "ident"
    bare = text.replace("(or /foreverxpbar)", "")
    if text.startswith("/") and not re.search(r"\([^)]*[A-Za-z]{3}", bare) and " - " not in text:
        return "slash"
    if sink == "table" and text[:1].islower():
        return "data"
    return None
