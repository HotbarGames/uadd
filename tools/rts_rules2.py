"""The tables of tools/rts_rules.py (split off for the file size budget): stay-English keys, slot sorts, notes,
fixed boxes and batches. Keys are Code.<hash> of a literal of Road to Sixty (all rights reserved: no English here).
"""
# Literals it shows but we leave English (by hash), with the reason.
STAY = {
    "Code.b3427cc2": "a map key, not shown", "Code.e1645b58": "a map key, not shown",
    "Code.652fe41b": "a map key, not shown",
    "Code.7dd4d16f": "the addon's own name", "Code.64d88e66": "chat prefix with its name and colour",
    "Code.86ebf99e": "a chat link whose text is matched by the addon",
    "Code.7ca2c130": "colour code piece", "Code.fd3abe8c": "colour value", "Code.f2e83f62": "colour value",
    "Code.fabfb81f": "colour value", "Code.fd3aa506": "colour value", "Code.84c98519": "colour value",
    "Code.fd20db9b": "colour value",
    "Code.3a7e2f4a": "an item name (UALL Forever's to give)",
    "Code.4733fd91": "English plural suffix slot: no Ukrainian form fits it",
    "Code.b9a6fb2f": "a count the addon writes in English units (time/times)",
    "Code.4de27395": "a count the addon writes in English units (run/runs)",
    "Code.c7e4ece5": "a duration the addon writes in English units",
    "Code.d702e5a7": "a duration in English units and a game slot name",
}
# Single lowercase words that ARE shown (the rest of such words are code values and are left out).
WORDS = {"on", "off", "enabled", "disabled", "hidden.", "shown.", "quests", "yourself"}
# A letter per slot, %d too (key_text.py): v value, f the player's own name, n game name, t our text, u English duration.
# %d, %f and |cff%s slots are v by themselves.
SORTS = {
    "Code.c52924cc": "nn", "Code.1cbb536c": "nn", "Code.c97b8fde": "vn", "Code.d16f1ff0": "nn",
    "Code.f8f4014a": "vn", "Code.52617094": "f", "Code.1831f4e0": "f", "Code.48204ce8": "ff",
    "Code.44635a7c": "f", "Code.a141cefe": "vv", "Code.205f37f2": "vu", "Code.9207f3ad": "vt",
    "Code.9ff8af0a": "ft", "Code.9147fc0f": "v", "Code.eda961e9": "vv",
    "Code.83a6ef2d": "vu", "Code.667eca79": "vu", "Code.16a2068b": "vu", "Code.ddd48a7c": "",
    "Code.111e0944": "", "Code.32338925": "", "Code.43114625": "f",
    # the joined rows of rts_source.JOINED: a character's name between two pieces of the code
    "Code.1ec1348d": "f", "Code.1ac8a0ea": "f", "Code.3ea43ef7": "f",
    # Map FormatTime and StatsScreen Day print English month names (%b): u, so those lines stay English.
}
NOTES = {
    "Code.d44015dc": "plural: write %d {one|few|many}, like %d {квест|квести|квестів}",
    "Code.060f4940": "plural: write %d {one|few|many}",
    "Code.44daf5b4": "a count: no plural needed; keep %d",
    "Code.000eb1e1": "glued in code before another text: keep the trailing space",
    "Code.cd4f6d37": "glued in code before a quest number: keep the trailing space",
    "Code.17f481aa": "glued after a number by the code (not by a slot): short, lowercase",
    "Code.fc3d3329": "glued in code before a level: keep the trailing space",
    "Code.e1ed2344": "glued in code before a time: keep the trailing space",
    "Code.0e5e71d1": "glued in code before a week number: keep the trailing space",
    "Code.14ff1b04": "glued in code before a duration: keep the trailing space",
    "Code.cd418c21": "glued in code before a duration: keep the leading comma and space",
    "Code.9a7ab82b": "glued after a character name (genitive, 'journey of X'): keep the leading text shape",
    "Code.fb33200b": "glued after a character name in a window title",
    "Code.7e0fad59": "glued before a character name: keep the trailing space",
    "Code.b0229344": "glued after a time: keep the leading space",
    "Code.b24711ef": "glued before a character name: keep the trailing space",
    "Code.9551d73b": "glued before a character name and the rest of its sentence: keep spaces",
    "Code.6713713c": "glued after a character name: keep the leading space",
    "Code.a7c8d916": "glued after a character name: keep the leading text shape",
    "Code.9b27ba56": "glued after another sentence: keep the leading space",
    "Code.10592050": "glued before a time ago: keep the trailing space",
    "Code.91f1e1cc": "glued before 'hidden.' or 'shown.': keep the trailing space",
    "Code.6dfae297": "glued before 'off' or 'on': keep the trailing space",
    "Code.ca106cc3": "glued before 'enabled' or 'disabled': keep the trailing space",
    "Code.f0142f83": "glued before a duration: keep the trailing space",
    "Code.4ca3a3e5": "glued after a duration: keep the leading comma",
    "Code.47b48811": "glued after a duration: keep the leading space",
    "Code.c08d2fdd": "glued before a level number: keep the trailing space",
    "Code.069aed5a": "glued after a number",
    "Code.87d1a6d2": "glued after a number (a tile line): keep the leading space",
    "Code.b72cee27": "glued after a number: keep the leading space",
    "Code.04bcff4d": "glued after a number: keep the leading space",
    "Code.ca78a40c": "glued after a time: keep the leading comma",
    "Code.2bb937ad": "glued after a text: keep the leading comma",
    "Code.a4484f7a": "glued after a count: keep the leading space",
    "Code.d1220869": "glued after a count: keep the leading space",
    "Code.9cd31208": "glued after a duration: keep the leading space",
    "Code.29eec211": "glued after a text: keep the leading comma",
    "Code.ca554e64": "Stats tile label: short, a fixed box",
}
# Fixed boxes: key -> the longest UA (letters of its first line); LONG overrides the default limit.
BOX = {
    "Code.0b880763", "Code.f06d95ad", "Code.0e2d9ee6", "Code.51bc68df", "Code.8ebab381", "Code.52ad78ad",
    "Code.392fdf50", "Code.2bd778c7", "Code.cb152b16", "Code.0dddda23", "Code.7c8ac63b", "Code.7c8c7982",
    "Code.82613931", "Code.ce885eaf", "Code.3e22a095", "Code.0276b293", "Code.adde7058", "Code.ab41f40b",
    "Code.6240e346", "Code.a770e2f7", "Code.4ce5b225", "Code.21bda250",
    "Code.0d1fc9f5", "Code.ce876053", "Code.ca554e64", "Code.a5b4e728", "Code.0d879b84", "Code.cd4f6d8a",
    "Code.add8a67e", "Code.7c85e4eb", "Code.73a63428", "Code.0e01d638", "Code.7c8cec74", "Code.e0ddf63a",
    "Code.0e1e39f4", "Code.8fd0686d", "Code.cb609b81",
}
LONG = {
    "Code.0b880763": 8, "Code.a770e2f7": 12, "Code.4ce5b225": 14, "Code.21bda250": 12,
    "Code.6240e346": 20, "Code.82613931": 22, "Code.ce885eaf": 22, "Code.3e22a095": 22, "Code.0276b293": 22,
    "Code.ca554e64": 14, "Code.a5b4e728": 14, "Code.0d879b84": 14, "Code.cd4f6d8a": 14, "Code.add8a67e": 14,
    "Code.7c85e4eb": 14, "Code.73a63428": 14, "Code.0e01d638": 14, "Code.7c8cec74": 14, "Code.e0ddf63a": 16,
    "Code.adde7058": 16, "Code.ab41f40b": 16, "Code.0d1fc9f5": 16, "Code.ce876053": 16,
    "Code.0e1e39f4": 14, "Code.8fd0686d": 22, "Code.cb609b81": 22, "Code.0dddda23": 14, "Code.7c8ac63b": 14,
    "Code.7c8c7982": 14,
}
# A file's first batch; split() cuts a group into batches of at most MAX_BATCH rows.
BATCH_FILES = {"Map.lua": 1, "Screens.lua": 1, "Range.lua": 1, "LevelShot.lua": 1,
               "Panel.lua": 2, "Style.lua": 2, "MinimapButton.lua": 2, "WhatsNew.lua": 2,
               "Options.lua": 3, "Core.lua": 3, "Journal.lua": 3, "LevelChat.lua": 3, "FriendsPanel.lua": 3,
               "StatsScreen.lua": 4}
BATCHES = [(n, f"batch {n} of Road to Sixty's v1 texts", lambda k, sec: True) for n in range(1, 5)]
