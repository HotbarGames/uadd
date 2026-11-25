"""What each slot of a What's Training? template holds (CLAUDE.md "No half translations"). Used by
tools/make_wt_text.py. What's Training? is MIT (THIRD-PARTY-NOTICES.md), so its templates may stand here
by their English.

Letters, one per slot (see UADD/Words.lua):
  v  a value (a number, money, a count, a level): kept when it has no English word, else put through our
     own texts; the line stays English when that fails
  n  a game name (zone, NPC, faction, standing, spell): UALL Forever's Ukrainian, else the whole line stays
     English (a spell: its spell route, UADD.UALL.Spell, through ns.Words with spells on)
  t  another What's Training? text: put through our own texts, else the whole line stays English
  f  a free name: none in What's Training? (no player or addon names in its templates)
  b  an English plural ending: none (it uses the game's |4one:many; escape, our Ukrainian uses {..|..|..})
A %d or %f is always v. A |cff%s slot is always v (a colour, lesson 7). A %s not listed here has no sort:
the build refuses its Ukrainian until it is added.
"""
import re

import hashtext as H

# By the English template.
SORTS = {
    "Cost: %s": "v", "Total Cost: %s": "v", "Total Savings: %s": "v", "Total Spent: %s": "v",
    "Base cost: %s": "v",
    "%s · %s · %d%% off": "nnv",            # faction, standing, discount (Utils.lua)
    "%s · no reputation": "n",
    "%s · %d%%": "nv",                       # standing, discount
    "%s shown (%s total)": "vv",             # coloured counts (Broker.lua)
    "And another %d that cost %s": "vv",
    "Level %s": "v", "Available total: %s": "v", "Skill %s": "v", "Show recipes costing %s": "v",
    "Train %d |4spell:spells; for %s": "vv", "Train %d |4spell:spells; for %s?": "vv",
    "Learned %d |4spell:spells; for %s": "vv",
    "%d |4rank:ranks; of %s": "vn",          # a spell name (UALL Forever's spell route)
    "Trained in %s": "n", "Starts in %s": "n", "Sold in %s": "n",   # zones, joined by ", " (Rows.lua)
    "Obtained from %s": "n",                 # the other faction
    "Requires %s reputation": "n", "Requires %s": "n", "Source: %s": "n",
    "%s - %s": "nn",                         # faction - standing
    "%s (%s)": "nn",                         # spell (rank) or profession (skill)
    "%d %s %s": "vnn",
    "%s • %s": "tv",                         # a section title of ours, a count (SECTION_COUNT)
    "%s • %d": "tv",                         # the same, glued in code: Views.lua
    "%s available": "v", "%s soon": "v",
    # glued in code (lessons 6 and 7), CODE below
    "%s (%.1f, %.1f)": "nvv",                # zone (x, y): Rows.lua
    "%s — %s": "nn",                    # zone - weapon master: WeaponGrouping.lua
    "• %s": "v",                             # the levels view's count, its own font string: Views.lua
}
# A price row (Utils.lua priceRowLabel) with its "best price" mark glued on.
ROWS = ("%s · %s · %d%% off", "%s · no reputation")
TAILS = (" · Best",)
SORTS.update({row + tail: SORTS[row] for row in ROWS for tail in TAILS})

# Lines What's Training? builds in code around a game name or its own text, not from its locale table (lesson 6):
# (English template, where). Our Ukrainian for them is the same template (only the name changes).
CODE = [
    ("%s (%.1f, %.1f)", "Rows.lua: a trainer's zone and map spot"),
    ("%s — %s", "WeaponGrouping.lua: zone, then the weapon master"),
    ("%s • %d", "Forever/Views.lua: a section title of ours, then its count"),
    ("• %s", "Forever/Views.lua: the levels view's count (\" • \" and a count of ours; outer spaces kept)"),
    ("%s • %s", "SECTION_COUNT in RecipeList.lua, SkillsRecipeList.lua, Forever/Ignored.lua: title, count"),
] + [(row + tail, "Utils.lua: a price row with its marks") for row in ROWS for tail in TAILS]


def sorts(en):
    """[letter or None] for each slot of one line of a template, by slot number."""
    over = SORTS.get(en, "")
    toks = H.tokens(en)
    out, n = [], 0
    for i, t in enumerate(toks):
        if t[0] != "slot":
            continue
        n += 1
        before = "".join(x[1] for x in toks[:i] if x[0] == "lit")
        if t[1] == "s" and re.search(r"\|c(?:ff)?$", before):
            out.append("v")
        elif t[1] != "s":
            out.append("v")
        elif n <= len(over):
            out.append(over[n - 1])
        else:
            out.append(None)
    return out
