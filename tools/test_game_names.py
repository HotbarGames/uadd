"""Game names in our Ukrainian come from UALL Forever, never from us (docs/LESSONS.md, lesson 9).

Items, spells, NPCs, zones and quests are UALL Forever's (UALLF) to name. For each text a hashed module
ships in Ukrainian, this reads the addon's English (from the installed addon, never kept here) and looks
for two signs of a game name:

- a UALLF name (Items, Spells, NpcNames, World, Quests tables; a plural "s" too). A name of two or more
  words, or a one-word item, must be in our Ukrainian as UALLF has it (each word of 3+ letters by its
  first 3 letters, so a case ending may change). One-word spell, NPC and zone names are only known words:
  many of them are plain words too.
- a name UALLF lacks: a word with a capital letter that is not at a sentence start, not an acronym, and
  never written in small letters in any of the addon's texts (so it is not a plain word of this addon),
  and not kept as it is in our Ukrainian (an addon's name, a key). In a short label that holds a UALLF
  item name, the first word counts too.

A text with such a word fails, unless its key is in ALLOW with the hash (hashtext.key) of the Ukrainian
that was looked at: a person read it and found no game name we wrote. When that Ukrainian changes, the
check fails again until someone reads it and updates the hash.

Misses (manual review still needed): a name whose words the addon also writes in small letters elsewhere,
a name at a sentence start, a name written in small letters, a UALLF name we spelled close enough to pass
the 3-letter test.

Modules: MODULES in tools/game_names_src.py, one function each that gives [(key, English, our Ukrainian or
""] and the module's own words: words that name no game thing there (an addon's name, its tabs, months,
languages; a possessive "'s" too). An own word is never taken for a name, also when UALLF has it as a
one-word name (a book called like a profession rank). That file also reads UALLF ($UALLF_DIR, $UADD_ADDONS_DIR/UALLF or the WoW _forever_ folder). An addon
or UALLF that is not installed skips the test.

python3 -m unittest tools.test_game_names
"""
import functools
import re
import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import hashtext as H  # noqa: E402
from game_names_src import MODULES, uallf_names  # noqa: E402

WORD = re.compile(r"[A-Za-z][A-Za-z'’-]*")
COLOR = re.compile(r"\|c[0-9a-fA-F]{8}|\|r")
CYR = re.compile(r"[^\W\d_]+(?:['’ʼ][^\W\d_]+)*")
LONGEST = 6           # words in the longest UALLF name looked for

# Reviewed texts: module -> {key of the English: key of the Ukrainian that was read}. Each one has a word
# the check takes for a name, and a person found no game name of ours in the Ukrainian. Say why.
ALLOW = {
    "UADD_AutoPotion": {
        "15:abb9c630": "31:e40d7e4e",    # a plain word in British spelling (the addon writes it US style)
        "25:c31a35ab": "42:b852d0b3",    # a label's first word is a plain adjective
        "140:956c20e3": "328:05f0bd2d",  # another addon's blurb: the game's UI layout mode, no game name
        "167:7fe635ae": "270:cc1584c2",  # two example items UALLF lacks: our Ukrainian leaves them out
        "134:750b46f4": "286:a5b49e1f",  # a buff name UALLF lacks, in our words: the owner to confirm
        "206:d52285e4": "390:4b6e80d6",  # the same buff name: the owner to confirm
    },
    "UADD_LayerSwap": {
        "66:9351f041": "107:3afd6b7c",   # the addon's own option name (auto-leave), not a game name
    },
    "UADD_Mastercraft": {   # reviewed 2026-11-19
        "7:270fcac7": "22:40f65383",     # a button verb (a chat whisper); UALLF's item of that English is another thing
        "27:bb19586f": "58:9909a834",    # the same verb on a help line
        "30:b39fadc8": "32:99020882",    # the author's name, kept in Latin letters as it is
        "164:b93e2e44": "317:b96752de",  # a plain past participle at a sentence start, not the UALLF item
        "34:75d0dfa7": "83:f98acaca",    # an NPC's short name: our Ukrainian has UALLF's full NPC name
        "96:e52cdf15": "288:7651ca0c",   # short specialization names: our Ukrainian has UALLF's spell names exactly
        "36:f2e7fe21": "134:c0d81526",   # the same specializations
        "38:7b68a52d": "151:747b7702",   # the same specializations
        "20:4e557136": "38:6ca5c8a4",    # a holiday: UALLF's UI.lua (not read here) has this Ukrainian
        "67:a35a4aae": "141:0881956d",   # a fishing event: UALLF's UI.lua Ukrainian; the zone is UALLF's
        "136:db515e66": "220:f460a032",  # the auction house as a place: the glossary's «аукціон» (as in Bagnon)
    },
    "UADD_ForeverQuestPins": {   # reviewed 2026-11-20
        "89:a188e9e3": "177:f584fb5c",   # the event's name: ClassicUA's word (UALLF's tables lack the event)
    },
}


# ── The check ────────────────────────────────────────────────────────────────────────────────────

def _norm(s):
    return s.lower().replace("’", "'").replace("ʼ", "'")


def has_name(ours, theirs):
    """True when UALLF's Ukrainian `theirs` is in `ours`: each of its words of 3+ letters starts a word of
    ours with the same 3 letters (a case ending may differ); a shorter name must be there as it is."""
    words = [w for w in CYR.findall(_norm(theirs)) if len(w) >= 3]
    if not words:
        return _norm(theirs) in _norm(ours)
    mine = CYR.findall(_norm(ours))
    return all(any(m.startswith(w[:3]) for m in mine) for w in words)


def vocabulary(english_texts):
    """Words the addon writes in small letters somewhere (lower case)."""
    out = set()
    for en in english_texts:
        out.update(w.lower() for w in WORD.findall(en) if w[0].islower())
    return out


def _known(word, vocab):
    w = word.lower().rstrip("'")
    return any(x in vocab for x in (w, w[:-1] if w.endswith("s") else w, w[:-2] if w.endswith("es") else w,
                                       w[:-2] if w.endswith("'s") else w))


def _sentence_start(en, pos):
    before = en[:pos].rstrip(" \t")
    return not before or before[-1] in ".!?:\n"


def _acronym(word):
    core = word[:-1] if word.endswith("s") and len(word) > 2 else word
    return len(core) == 1 or core.isupper()


def _uallf_at(en, ws, i, names):
    """(name, words it spans) of the longest UALLF name with a capital letter that starts at word i."""
    for j in range(min(len(ws), i + LONGEST), i, -1):
        s = en[ws[i].start():ws[j - 1].end()]
        if not s[0].isupper():
            continue
        for cand in (s, s[:-1] if s.endswith("s") else None, s[:-2] if s.endswith("es") else None):
            if cand and cand in names:
                return cand, j - i
    return None, 0


def problems(en, uk, vocab, names, own=()):
    """What looks like a game name we wrote ourselves in `uk`, the Ukrainian of `en` ([] when none)."""
    en, uk = COLOR.sub("", en), COLOR.sub("", uk)
    ws = list(WORD.finditer(en))
    out, covered, item = [], set(), False
    i = 0
    while i < len(ws):
        name, n = _uallf_at(en, ws, i, names)
        if not name or (n == 1 and name in own):
            i += 1       # an own word (the module's list) that UALLF also has as one word: not that name here
            continue
        theirs, kind = names[name]
        covered.update(range(i, i + n))
        item = item or kind == "item"
        if (n > 1 or kind == "item") and not has_name(uk, theirs):
            out.append("UALLF %s %r is %r there, not in our Ukrainian" % (kind, name, theirs))
        i += n
    label = len(ws) <= LONGEST and not re.search(r"[.!?]\s|[.!?]$", en)
    for i, m in enumerate(ws):
        w = m.group(0)
        if i in covered or not w[0].isupper() or _acronym(w) or re.sub(r"'s$", "", w) in own or _known(w, vocab):
            continue
        if re.search(r"(?<![A-Za-z])%s(?![a-z])" % re.escape(re.sub(r"'s$", "", w)), uk):
            continue      # kept as it is (an addon's name, a key): not a name we wrote
        if _sentence_start(en, m.start()) and not (label and item and i == 0):
            continue
        out.append("%r looks like a name UALLF lacks (never in small letters in the addon)" % w)
    return out


def check_module(rows, allow, names, own=()):
    """[(key, problem)] for a module's rows [(key, English, Ukrainian)]; ALLOW entries checked too."""
    vocab = vocabulary(en for _, en, _ in rows)
    shipped = {k: uk for k, _, uk in rows if uk}
    out = []
    for k, en, uk in rows:
        if not uk:
            continue
        found = problems(en, uk, vocab, names, own)
        if k in allow:
            if H.key(uk) != allow[k]:
                out.append((k, "its Ukrainian changed since it was reviewed (ALLOW): read it again for game "
                               "names we wrote, then put %s in ALLOW" % H.key(uk)))
            elif not found:
                out.append((k, "in ALLOW but the check finds nothing now: remove it"))
            continue
        out += [(k, p) for p in found]
    out += [(k, "in ALLOW but not shipped in Ukrainian: remove it") for k in allow if k not in shipped]
    return out


# ── Tests ────────────────────────────────────────────────────────────────────────────────────────

# Texts UADD_AutoPotion shipped with game names of our own before lesson 9 (two potions, an engineering
# injector, a spell+item option, a sentence naming a spell, an item and a reagent, a tooltip naming two
# example items), and one more item name of the same kind. Their Ukrainian was dropped or rewritten.
AP_DROPPED = ["26:75373760", "28:aab41e5a", "37:582a96f1", "20:f69f495e", "176:f52dda02", "167:7fe635ae",
              "16:779bf91e"]


@functools.lru_cache(maxsize=None)
def _load(module):
    return MODULES[module]()


class Names(unittest.TestCase):
    """The parts, on made-up texts (no game folder needed)."""

    NAMES = {"Mana Potion": ("Зілля Мани", "item"), "Healthstone": ("Камінь Здоров'я", "item"),
             "Troll": ("Троль", "spell")}

    def test_has_name_allows_case_endings(self):
        self.assertTrue(has_name("Спершу Камені Здоров'я", "Камінь Здоров'я"))
        self.assertFalse(has_name("Спершу Цілющий камінь", "Камінь Здоров'я"))

    def test_problems(self):
        vocab = vocabulary(["use a potion first", "the gizmo is ready"])
        self.assertEqual(problems("Use a Mana Potion", "Зілля мани", vocab, self.NAMES), [])
        self.assertTrue(problems("Use a Mana Potion", "Еліксир сили", vocab, self.NAMES))
        self.assertTrue(problems("Potion of Wobbly Dreams", "Зілля", vocab, self.NAMES))
        self.assertTrue(problems("Casts Zapburn before the gizmo", "Тест", vocab, self.NAMES))
        self.assertTrue(problems("Zapburn Healthstone", "Камінь Здоров'я", vocab, self.NAMES))
        self.assertEqual(problems("Gizmo Ready. Wobbly is fine", "Тест", vocab, self.NAMES), [])
        self.assertEqual(problems("Use (Troll racial) and UI", "Тест", vocab, self.NAMES), [])

    def test_allow_pins_the_ukrainian(self):
        vocab_rows = [("1:a", "Casts Zapburn now", "Тест")]
        self.assertEqual(check_module(vocab_rows, {"1:a": H.key("Тест")}, self.NAMES), [])
        self.assertTrue(check_module(vocab_rows, {"1:a": H.key("Інше")}, self.NAMES))
        self.assertTrue(check_module(vocab_rows, {}, self.NAMES))
        self.assertTrue(check_module(vocab_rows, {"2:b": "1:x"}, self.NAMES))


class Shipped(unittest.TestCase):
    """The modules' shipped Ukrainian against the installed addons and UALLF."""

    def setUp(self):
        if not uallf_names():
            self.skipTest("UALL Forever is not installed (set UALLF_DIR)")

    def test_no_game_names_of_ours(self):
        for module in MODULES:
            with self.subTest(module=module):
                got = _load(module)
                if got is None:
                    self.skipTest("%s: its addon is not installed" % module)
                rows, own = got
                found = check_module(rows, ALLOW.get(module, {}), uallf_names(), own)
                self.assertEqual(found, [], "\n".join("%s: %s" % p for p in found))

    def test_catches_the_names_we_dropped(self):
        """Had the dropped texts kept Ukrainian of ours, the check fails on each of them. Two kinds of
        made-up Ukrainian: plain, and one that holds UALLF's Ukrainian for every UALLF name in the English
        (the hardest case: only the names UALLF lacks give it away)."""
        got = _load("UADD_AutoPotion")
        if got is None:
            self.skipTest("Auto Potion is not installed")
        rows, own = got
        english = {k: en for k, en, _ in rows}
        missing = [k for k in AP_DROPPED if k not in english]
        if missing:
            self.skipTest("Auto Potion changed: %s gone" % missing)
        names = uallf_names()
        allow = {k: v for k, v in ALLOW["UADD_AutoPotion"].items() if k not in AP_DROPPED}
        for smart in (False, True):
            caught = []
            for k in AP_DROPPED:
                en = english[k]
                fake = "Наша назва"
                if smart:
                    fake += " " + " ".join(uk for n, (uk, _) in names.items() if n in en)
                test_rows = [(r[0], r[1], fake if r[0] == k else "") for r in rows]
                if any(p[0] == k for p in check_module(test_rows, allow, names, own)):
                    caught.append(k)
            with self.subTest(smart=smart):
                self.assertEqual(caught, AP_DROPPED)


if __name__ == "__main__":
    unittest.main()
