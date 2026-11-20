"""What each slot of a Mastercraft template holds (CLAUDE.md "No half translations"). Used by
tools/make_mc_text.py.

Sorts:
  VALUE  a number, money, a time, a level, a colour: kept, or (a time like "3 hr") put through our own
         texts; the line stays English when Latin words are left in it
  FREE   a name kept as it is: a player or character, another addon, a version, a key binding
  NAME   a game name (item, zone, NPC, spell, profession rank...): the runtime takes UALL Forever's
         Ukrainian, else the whole line stays English
  TEXT   another Mastercraft text: put through our own texts, else the whole line stays English
  BLANK  only an English plural ending ("s" or nothing): put in as nothing; our Ukrainian uses {..|..|..}
%d / %f are always VALUE. A %s is sorted by OVERRIDE (by "<bytes>:<hash>" of the English, one letter
per slot: V F N T, "-" = %d/%f or use the rules) or else by RULES: regexes over the text around the slot
with that slot as "@", the other slots as "#" and colour codes taken out. The first rule that matches
wins. Only short word fragments here (at most 3 words in a row), never Mastercraft's sentences.
"""
import re

import hashtext as H

VALUE, FREE, NAME, TEXT, BLANK = "VALUE", "FREE", "NAME", "TEXT", "BLANK"
LETTER = {"V": VALUE, "F": FREE, "N": NAME, "T": TEXT, "B": BLANK}
CODE = re.compile(r"\|c[0-9A-Fa-f]{8}|\|c(?=@|#)|\|r|\|T[^|]*\|t")

RULES = [
    # an English plural ending glued to a word ("s" or nothing)
    (r"\b(?:item|step|character|error|member|point|cooldown|result|stack|recipe|zone|node|alt|craft|catch|"
     r"slot)@", BLANK),
    # a colour code or an icon glued before a word or a number; a weekday or "Today" before a date or time
    (r"^@(?:[a-z]|#)", VALUE),
    (r"^@, # (?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)$|^@ #:# (?:server|your) time", TEXT),
    # more text glued at the end; a reason; a setting's state (our "on" / "off")
    (r"louder splash: @|(?:done|needed|bags\.|#)@$|waypoint there\. @|profession window: @|^imported: #.*, @|usually online @", TEXT),
    # a time, money, a count, a level
    (r"@ ago|\b(?:seen|scan|updated|last|since|answered|are from|contents are from) @|^since @", VALUE),
    (r"\b(?:next|starts|ready|one|bites) in:? @", VALUE),
    (r"@ (?:left|sec|/ hour|this week|each|per |in gold|in materials|gold\b|more than|times\b|items\b)", VALUE),
    (r"(?:worth|cost|costs|pays|paid|profit|loss|lose|saves|about|~|gear for|repair|sells for|disenchants for|"
     r"vendor pays|auction house:|vendor:|vendor all|disenchant all|than|bought for) +\(?@", VALUE),
    (r"\b(?:item )?level @|@ enemies|@ beasts|@ / #|# / @|\(@ of the time\)|\bpays @", VALUE),
    # a version, a key binding, another addon
    (r"\bv@|\bversion @|\(@\) - (?:please|update)|mastercraft @$|is out \(@\)|key: @|open mastercraft: @", FREE),
    (r"^@ is (?:on|off)\b|@ casts and|@ jumps", FREE),
    # a player or a character
    (r"^@ (?:knows|can |can't|needs \+|asks|already|is not online|will |marked|is done|is in an? |hasn't|"
     r"accepted|broke|is unblocked|isn't|is fully|is capped|is almost|\(your alt\)|\(on their alt|\(under|'s )", FREE),
    (r"^@  \(you\)|\(@'s alt\)|ready on @|your account: @|learned by: @|"
     r"put @'s|players on @|by @\.?$|all characters: @|is saved - @|^@ is ready on|\(@\)\. please|"
     r"or here: @|in chat: @|the link: @|first on @", FREE),
    (r"^@'s |@  \(#'s alt\)|# \(on their alt @\)|\bon their alt @|(?:known by|learned by|log in with|whisper|"
     r"mail it to|mailing .* to|asking|online as|crafter:|bank alt:|leave|meet|code sent to|reminder:|"
     r"hides \d+ alts?:|hides # alts:|is ready on|has it|for #'s) @|# - @ has it|^from @$|^to @$|"
     r"remove @ \(level", FREE),
    # a game name; an alt's zone before when it was seen (Alts.lua: the zone, never a player)
    (r"^@  -  (?:online now|seen)", NAME),
    (r"\b(?:sells|sold by|taught by|drops from|found in|in|from the|from|quest|quests:|reward:|recipe item:|"
     r"learn from:|learned from:|requires|needs|track|open your|your|zone:|"
     r"where:|map: @|waypoint:|wants:|watching:|cook now:|smelt now:|fishing:|"
     r"for your|any|every|of your|craft|make|eat|learn|attached .* for|items for|bags:|bags that|"
     r"also needs:|needs #x|recommended for you:|not now:|best spots:|"
     r"teaches it|at your|crafter of|ask for|asks for|make #|can make|can't make|have it -|"
     r"none has|mats for|crafts of|about # crafts of|guide uses all # you have|keep # for your|mats each:|"
     r"guide lists:|extra find:|raid drop  -|your game:|extras:|vendor|recipe:|open map:|found in:|nodes|show|"
     r"see|no|missing|quest:|manual:|holiday recipe:|points here:|buy all|cheapest way:?|instead of|"
     r"materials|couldn't find|could not find|haven't learned|link for|turn on|gathered|opens it at|"
     r"opens at|after the fight:|still needed:|lure,|click:|you have|characters has|rate|e\.g\.|"
     r"boss drop -|book|after the quest|learned at|ready:|alts:|trade board:|for|next:|here:|or:|skill-ups:|"
     r"report:|# -|level # beasts -) \"?@", NAME),
    (r"^@:? (?:ready|few reports|choose a)|^@ (?:\(gadgetzan\)|- # merchant's)|^@, (?:both|after)|"
     r"^@\. dense|^@ and other|^@ +x#|^@  ~#|^@ +\(\+# on|^@ #|^@ - # \(skill|^@ - # guide|# - @ guide|"
     r"^@ +-  # each|^@ by #|# \(formerly @\)|ready @", NAME),
    (r"^@ (?:trainer|shopping list|guide|nodes|recipes|camping object|step done|x#|-|\(|  -|,|\.|is in #|"
     r"\(skill|\(rank|\(both|\(gadgetzan|\(formerly|by #|and more|and # more|in booty|in your bags|"
     r"is open|needs one|= same|same materials|on the ah)", NAME),
]
RULES = [(re.compile(p, re.I), s) for p, s in RULES]

# By "<bytes>:<hash>" of the English: one letter per slot (V F N T, "-": a %d/%f).
OVERRIDE = {
    "21:2dffa21a": "T", "30:2b6028d5": "VNV", "25:a416ff5a": "NT", "16:a1183c3f": "N", "36:1a310d98": "N",
    "38:f74706b4": "VV", "34:7aa1bae1": "VN", "31:6f4b569b": "NNV", "52:f79a5080": "NNVV",
    "15:bc090e32": "VN", "18:4a35255c": "VN", "13:b69472a2": "V", "36:25a51017": "FV", "56:2300719d": "F",
    "52:f0542eff": "NN", "116:5daaeed5": "NN", "12:fa0b1e27": "NT", "16:285ec4e8": "NVN",
    "46:56fa984f": "VNV", "49:7ab7ad5e": "VNVV", "39:5ee21ff0": "VN", "46:61ac302f": "VNV",
    "56:9f26585d": "VNVVV", "47:ebb4fe4f": "VV", "27:347a4657": "NVNN", "16:b6ba03c5": "NNN",
    "40:cffe9244": "TVV", "89:280439c8": "FVNN", "21:61ca9680": "F", "14:ea7f7876": "VNN",
    "11:c97b8fde": "VN", "29:b0ee0bab": "FNV", "35:8fad60ae": "FNV", "102:4155d29f": "N",
    "69:05e6a50f": "N", "29:e8f9bd19": "FF", "35:fa8949ac": "T", "32:54df3a13": "T", "33:a8773893": "T",
    "23:73017ff2": "VT", "35:8cfdd55e": "VVT", "41:6c19ffad": "FN", "49:d8831a88": "NN",
    "19:cf254038": "NVT", "25:38aa8b14": "NVN", "14:37601502": "NN", "22:805a5752": "NN",
    "41:03b035e5": "NNVV", "16:3c12c57d": "VT", "15:c240f54a": "VT",
    # Stage 3, read from the code that builds each line: a list of two (never shipped: loose); an icon
    # then mats; char (where) -> char, profession; icon, count, plural, "show"; chance, money, can-make;
    # count, item, crafters; quest, level, needs-level; char, where; profession; rank, level, trainer,
    # zone, note (two); count, step title, count, money; profession, count; credits: addon, author, what
    # for; a character; who, recipe, link; a vendor line from the data, favour count.
    "6:66679401": "TT", "16:cbe63335": "VN", "48:2da42a30": "FTFN", "20:6b8bd5b8": "VVBT",
    "21:d9ebf7b8": "TVT", "15:1e6df1ed": "VNF", "39:d6528a38": "NVT", "18:9436262a": "FT",
    "42:c33a0463": "N", "32:27231f3c": "NVNNT", "21:c858716a": "NNNT", "21:c3a7c5ff": "VNVV",
    "16:589231fd": "NV", "13:e0813675": "FFT", "5:10147f1a": "F", "18:1490fe3a": "FNF",
    "71:eb2d9b36": "NV", "23:cd938ab2": "F",
    # Found by tools/test_mc_slots.py: a vendor and its zone; a recipe (never a player there).
    "10:166ad36a": "N", "11:5f7c4ced": "N",
    # Texts built in code (IN_CODE below): an icon, a disenchant material, its count, its price; who can
    # craft it (players, kept), the profession; money before "each" / "ea".
    "24:a3fbd071": "VNVV", "19:d68addfb": "FN", "7:32a7c1ce": "V", "5:0adc2fe3": "V",
    # The owner's screenshots (2026-11-20): a step title is a recipe or a guide's own text (T: Words.lua
    # finds a bare game name too); a vendor line from the data holds an NPC and its price. (Built in code
    # and too short to ship: "<count>x <fish>" is Words.lua step 12, the guide's "<label>:  <what>" step 9c.)
    "10:27784c65": "N",
}

# Texts Mastercraft builds in its code, not in its locales (tools/mc_text_lib.py code_rows): by
# "<bytes>:<hash>" of the shape Words.lua sees. Its item tooltip: a disenchant material row, "Crafted by"
# players and profession, money with "each" / "ea" after it. (A chance, "<word> 75%", is Words.lua step 7.)
IN_CODE = {"24:a3fbd071", "19:d68addfb", "7:32a7c1ce", "5:0adc2fe3"}


def context(en, n):
    """The text with slot n as "@", the other slots as "#", colour codes out."""
    out, i = [], 0
    for t in H.tokens(en):
        if t[0] == "lit":
            out.append(t[1])
        else:
            i += 1
            out.append("@" if i == n else "#")
    return CODE.sub("", "".join(out)).strip()


def sorts(en):
    """[sort or None] for each slot of one line of a template, by slot number."""
    key = H.key(en)
    slots = [t for t in H.tokens(en) if t[0] == "slot"]
    over = OVERRIDE.get(key, "")
    out = []
    toks = H.tokens(en)
    for n, t in enumerate(slots, 1):
        letter = over[n - 1] if n <= len(over) else "-"
        before = "".join(x[1] for x in toks[:toks.index(t)] if x[0] == "lit")
        if t[1] == "s" and re.search(r"\|c(?:ff)?$", before):
            out.append(VALUE)             # |cff%s: a colour, never free (lesson 7), whatever OVERRIDE says
        elif letter in LETTER:
            out.append(LETTER[letter])
        elif t[1] != "s":
            out.append(VALUE)
        else:
            ctx = context(en, n)
            out.append(next((s for rx, s in RULES if rx.search(ctx)), None))
    return out
