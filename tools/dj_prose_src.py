"""Placeholder rules for make_dj_prose.py: turn the UALLF names in an English text into
{npc:..} / {item:..} / {zone:..} / {quest:..} placeholders. Split out of dj_prose_names.py."""
import re
from collections import OrderedDict

LEAD_WORDS = {"The", "In", "At", "To", "From", "Of", "On", "Near", "Inside", "Outside", "Enter", "Kill",
              "Slay", "Defeat", "Bring", "Take", "Deliver", "Return", "Speak", "Talk", "Use", "Find",
              "Collect", "Loot", "Visit", "Travel", "Go", "Then", "After", "Before", "And", "Or", "A", "An"}
TRAIL_WORDS = {"I", "If", "Then", "And", "Or"}

# A quest title becomes {quest:..} only when the text marks a quest there. Strong marks work
# for every title; weak ones only for a title that is not also an NPC, item or place name.
STRONG_LEFT = re.compile(
    r"(?:\b(?:[Ll]eading to|[Ll]eads to|[Ll]ead to|[Ll]eads directly into|[Ll]eading into|[Ll]ead-in(?: to)?:?|[Bb]readcrumb(?: to)?"
    r"|after completing|before accepting|accepted alongside|alongside|[Cc]ompleting|[Cc]omplete|[Aa]ccept|[Aa]ccepting"
    r"|[Aa]bandon|[Rr]equired (?:before|for)|[Rr]equires(?: the(?: earlier)?)?|[Aa]vailable after(?: completing)?"
    r"|[Uu]nlocks?|[Cc]ontinuing to|[Cc]ontinues with|begins with|version of|step of|[Ff]ollows|[Ff]ollow-up,"
    r"|[Hh]and in|[Hh]anding in|[Tt]urn in|[Tt]urning in|quests?:?"
    r"|(?:step|quest|investigation|prerequisite)s? (?:before|after)))\s+$")
WEAK_LEFT = re.compile(r"(?:\b(?:[Aa]fter|[Bb]efore|for|with|into|starts|offers|[Tt]hen take|[Gg]ives|In this dungeon:)\s+|\(|\")$")
STRONG_RIGHT = re.compile(
    r"^(?: (?:quests?|chain|questline|steps?|becomes available|is available|turned in|is handed in|are handed in"
    r"|must be in progress|in your quest log|is not required)\b|\")")
LIST_SEP = re.compile(r"(?:, and |, then |, | and | or )$")
TITLE_RUN = re.compile(r"[A-Z][\w'!:-]*(?: (?:[A-Z][\w'!:-]*|of|the|in|to|a|an|is|on))*$")
COUNT = re.compile(r"(?:^|[\s(])(\d+) $")
WORD = re.compile(r"[A-Z][\w'-]*")
# A one-word UALLF NPC ("Morphaz") only where the text plainly names a creature or person.
NPC_CUE = re.compile(r"(?:\b(?:[Dd]rops? from|[Dd]ropped by|from|[Kk]ill|[Ss]lay|[Dd]efeat|[Dd]estroy|[Ff]ind|[Cc]onfront"
                     r"|track down|[Ss]peak with|[Tt]alk to|is|champion,|guardians:|[Gg]roup quest:)"
                     r"|\{npc:[^{}]+\}(?:, and|,| and)) $")
NPC_RIGHT = re.compile(r"^(?: attunement\b|'s [a-z])")
ITEM_CUE = re.compile(r"(?:\b[Kk]ill (?:\{npc:[^{}]+\}|[A-Z][\w'-]*(?: [A-Z][\w'-]*)*) for|\b[Tt]ake|\bhammer,) $")
# Places UALLF has that the texts use as a person's name ("put Anvilmar's spirit to rest").
NOT_PLACE = {"Anvilmar"}
# One-word UALLF NPCs that name someone else in the texts ("Jordan's ore shipment" is Jordan Stilwell's).
NOT_ONE_WORD = {"Jordan"}
# "Dire Maul West": a wing word after the dungeon name does not glue it to a longer name.
WINGS = re.compile(r" (?:West|North|East)\b")
WINGED = {"Dire Maul"}
# "Westfall's mines": a possessive "'s" ends a name like a space does.
POSS = re.compile(r"'s(?![\w'])")


def quest_cue(en, i, end, pure):
    """Does the text around en[i:end] mark a quest title?"""
    if STRONG_RIGHT.match(en[end:]):
        return True
    left = en[:i]
    while True:
        if STRONG_LEFT.search(left) or (pure and WEAK_LEFT.search(left)):
            return True
        # Lists: "Complete A, B and C, then D before ..." — step back over earlier titles.
        sep = LIST_SEP.search(left)
        if not sep:
            return False
        run = TITLE_RUN.search(left[:sep.start()])
        if not run:
            return False
        # "Complete The Barrens Oases, ...": the cue word opens the run itself.
        words = run.group(0).split(" ")
        for k in range(1, len(words)):
            if STRONG_LEFT.search(left[:run.start()] + " ".join(words[:k]) + " "):
                return True
        left = left[:run.start()]


def joined_left(en, i, cand, names):
    """Is the name at en[i] glued to a longer capitalised name on its left?"""
    left = en[:i]
    sentence_start = bool(re.search(r"(^|[.!?:]\s+|\n)\S+ $", left))
    m = re.search(r"([A-Z][\w'-]*) $", left)
    if m and not sentence_start:
        if m.group(1) == "The":
            # Mid-sentence "The" belongs to a longer name ("and The Hand of Rastakhan"), except for
            # places ("in The Hinterlands") and after a sentence-opening verb ("Find The ...").
            if re.search(r"(^|[.!?:]\s+|\n)(%s) The $" % "|".join(LEAD_WORDS), left):
                return False
            return names.known[cand][0] != "zone" and ("The " + cand) not in names.titles
        # "Stormwind's Dwarven District": a place after a possessive stands on its own.
        if m.group(1) not in LEAD_WORDS and not (m.group(1).endswith("'s") and names.known[cand][0] == "zone"):
            return True
    # "The Gauntlet of Gordok Might": glued only when the longer run is a known name or title.
    m = re.search(r"((?:The )?(?:[A-Z][\w'-]* )+of (?:the )?)$", left)
    return bool(m and names.is_name(m.group(1) + cand))


def joined_right(en, i, end, names):
    m = re.match(r" of (?:the )?[A-Z][\w'-]*(?: [A-Z][\w'-]*)*", en[end:])
    if m:
        words = m.group(0).split(" ")
        for k in range(len(words), 2, -1):
            if names.is_name(en[i:end] + " ".join(words[:k])):
                return True
        return False
    if en[i:end] in WINGED and WINGS.match(en, end):
        return False
    m = re.match(r" ([A-Z][\w'-]*)", en[end:])
    return bool(m and m.group(1) not in TRAIL_WORDS)


def name_end(en, end, kind):
    """Does a name stop at en[end]? A possessive counts, but not "X's Capitalised" (an item
    or place UALLF lacks, "Jordan's Hammer"), except for a place ("Stormwind's Dwarven District")."""
    if end >= len(en) or not re.match(r"[\w'}]", en[end]):
        return True
    return bool(POSS.match(en, end)) and (kind == "zone" or not re.match(r"'s [A-Z]", en[end:]))


def the_name(en, i, names):
    """'the Hinterlands' / 'the Nameless Prophet' / 'the Defias Brotherhood chain':
    a UALLF name that starts with "The", written lower-case mid-sentence."""
    longer = [c for c in names.idx.get(en[i + 4:i + 7], ()) if en.startswith(c, i + 4)]
    for cand in names.idx.get("The", ()):
        end = i + len(cand)
        if en[i + 4:end] != cand[4:] or not name_end(en, end, "") or re.match(r" of | [A-Z]", en[end:]):
            continue
        kind = names.known.get(cand, ("",))[0]
        if kind != "zone" and cand in names.quests and quest_cue(en, i, end, False):
            return end, "{quest:%s}" % cand, names.quests[cand]
        # NPCs: not a group that is also a quest title ("the Earthen Ring party").
        if (kind == "zone" or (kind == "npc" and cand not in names.titles)) and cand[4:] not in names.known \
                and not any(len(c) > len(cand) - 4 for c in longer):
            return end, "{%s:%s}" % (kind, cand), None
    return None


def one_word(en, i, left, names):
    """'drops from Morphaz', 'Kill Fineous Darkvire for Ironfel': a one-word UALLF NPC or item.
    left is the src built so far, so earlier placeholders count as cues ("Gasher, Mijan")."""
    word = re.match(r"[A-Z][\w'-]*", en[i:])
    if not word:
        return None
    w = word.group(0)
    if w.endswith("'s"):
        w = w[:-2]
    end = i + len(w)
    if w in NOT_ONE_WORD or not name_end(en, end, "") or joined_right(en, i, end, names):
        return None
    if w in names.npcs and (NPC_CUE.search(left) or NPC_RIGHT.match(en[end:])):
        return end, "{npc:%s}" % w, None
    if w in names.items and ITEM_CUE.search(left):
        return end, "{item:%s}" % w, None
    return None


def make_src(en, names):
    """English -> (src with placeholders, {placeholder: id}, [counted placeholders])."""
    out, refs, counts = [], OrderedDict(), []
    i, last, n = 0, 0, len(en)
    while i < n:
        if not en[i].isalnum() or (i and re.match(r"[\w'{:]", en[i - 1])):
            i += 1
            continue
        done = None
        count = COUNT.search(en[:i])
        for cand in names.idx.get(en[i:i + 3], ()):
            end = i + len(cand)
            if not en.startswith(cand, i):
                continue
            kind = names.known.get(cand, ("",))[0]
            if cand in names.titles and not count and (end >= n or not re.match(r"[\w'}]", en[end])) \
                    and quest_cue(en, i, end, names.pure_title(cand)):
                if cand in names.quests:
                    done = (end, "{quest:%s}" % cand, names.quests[cand])
                else:
                    done = (end, None, None)   # a quest UALLF lacks: keep it whole, plain
                break
            if cand in names.known and name_end(en, end, kind) and not joined_left(en, i, cand, names) \
                    and not (cand in NOT_PLACE and en.startswith("'", end)) \
                    and not joined_right(en, i, end, names):
                done = (end, "{%s:%s}" % (kind, cand), names.known[cand][1])
                break
        if done is None and en.startswith("the ", i):
            done = the_name(en, i, names)
        if done is None:
            done = one_word(en, i, "".join(out) + en[last:i], names)
        if count and (done is None or done[1] is None or done[1].startswith("{quest:")):
            # "10 Red Silk Bandanas": the item / creature by its singular UALLF name.
            run = re.match(r"[A-Z][\w'-]*(?: (?:[A-Z][\w'-]*|of|of the))*", en[i:])
            if run:
                text = run.group(0)
                while text.endswith(" of") or text.endswith(" of the"):
                    text = text.rsplit(" ", 1)[0]
                sing = names.singular(text)
                if sing:
                    done = (i + len(text), "{%s:%s}" % sing, None)
        if done and done[1] is None:
            i = done[0]
            continue
        if done:
            end, ph, ident = done
            out.append(en[last:i])
            out.append(ph)
            refs[ph] = ident
            if count and ph.startswith(("{item:", "{npc:")):
                counts.append("%s %s" % (count.group(1), ph))
            i = last = end
            continue
        m = re.match(r"[\w'-]+", en[i:])
        i += len(m.group(0)) if m else 1
    out.append(en[last:])
    return "".join(out), refs, counts
