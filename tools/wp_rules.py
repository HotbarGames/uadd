"""Which Waypoint UI texts UADD_WaypointUI translates and what each template slot holds. Used by
tools/make_wp_text.py (through tools/text_lib.py).

Waypoint UI has no licence file (all rights reserved; CLAUDE.md "Other addons' texts"): nothing here names its
English. Rows are its locale values (Locales/enUS.lua, L["KEY"] = "..."), named here by their locale KEY.
The units (distance, time) are not here: UADD_WaypointUI/Words.lua reads them by pattern (values only).

Letters, one per slot (text_lib.py, UADD/Words.lua): v a value, f a free name kept as it is, n a game name,
t another text of ours.
"""
import re

# Locale keys that stay English: names (addons, libraries, people), never translated.
STAY = {
    "FARSTRIDERLIB", "MAPZEROTH",                       # path providers: addon or library names
    "CONFIG_ABOUT_DEVELOPER_ADAPTIVEX",                 # the developer's name
}
STAY_RE = [
    re.compile(r"^CONTRIBUTORS_[A-Z0-9]+$"),            # a contributor's name (their role has its own key)
    re.compile(r"^CONFIG_EXTENSIONS_[A-Z]+SUPPORT$"),   # the title of an addon's support section: its name
]

# A letter per %s, by locale key. The six replace prompts hold the name of the waypoint, pin or guide step
# that would be replaced: the player's text or another addon's (lesson 13), kept as it is.
FREE_PROMPTS = ("GUIDE_PIN_ASSISTANT", "TOMTOM", "MAPZEROTH", "RESTEDXP", "DUGISGUIDEVIEWERZ", "APR")
SORTS = {f"{p}_REPLACEPROMPT": "f" for p in FREE_PROMPTS}
SORTS["WAYPOINTSYSTEM_COORDINATE_FORMAT"] = "vv"        # coordinates: values only
FREE = sorted(k for k, v in SORTS.items() if "f" in v)  # the free-slot marks (CLAUDE.md "No half translations")

# The code's own default names (a guide pin, a Dugi waypoint) are not rows at all: they are saved with the pin
# (mapPinSessionData, Code/MapPin/MapPin.lua CreatePinData keeps options.name), so they stay English
# (lesson 14).

SLOT = re.compile(r"%%|%[-+#0]*\d*(?:\.\d*)?[sdifx]")


def stays(key):
    return key in STAY or any(r.match(key) for r in STAY_RE)


def letters(key, en):
    """[letter or None] per slot of `en`: %d/%f are v; a %s takes SORTS[key]'s letter in order."""
    given = list(SORTS.get(key, ""))
    out, k = [], 0
    for m in SLOT.finditer(en):
        if m.group(0) == "%%":
            continue
        if m.group(0)[-1] in "dif":
            out.append("v")
            if k < len(given) and given[k] == "v":
                k += 1
            continue
        out.append(given[k] if k < len(given) else None)
        k += 1
    return out


def keep(key, en):
    """(kept, reason left out)."""
    if en is None:
        return False, "nil in enUS"
    if not en.strip():
        return False, "empty"
    if stays(key):
        return False, "a name (STAY)"
    if not re.search(r"[A-Za-z]{2,}", SLOT.sub("", en)):
        return False, "no words"
    return True, ""
