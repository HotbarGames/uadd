"""Which OneForAll texts UADD_OneForAll translates, what each template slot holds, the batches, and the check.
Used by tools/make_ofa_text.py (through tools/key_text.py) and tools/ofa_source.py.

OneForAll is GPL-3.0-or-later, so its English may stand here (the tables below are keyed by it). Every row of the
data is keyed Code.<hash>, UADD.Hash of the English text as OneForAll draws it (the key of its L table, a data
sentence with its numbers as %s, or one string literal of its code).

Slot letters (key_text.py), one per slot: v a value (number, money, clock, date), f a name kept as it is (a
profile or player name), n a game name (links, digits and items through UALL Forever or ClassicUA; anything else
leaves the line English), t our text glued in. %d, %f and |cff%s slots are v by themselves. A %s whose letter is
not known yet shows "?" in the review files and is refused by the build until SORTS below has it.
Plurals are written in Ukrainian as {one|few|many} after a number slot: "%d {рецепт|рецепти|рецептів}".
"""
import re

import key_text as K
from test_banned_words import BANNED

MAX_BATCH = 150          # rows of one batch
PROSE_BATCH = 60         # rows of one prose batch (long sentences), or PROSE_BYTES of English
PROSE_BYTES = 6000
MAXLEN = 34              # a fixed box: the UA's first line at most this long unless in LONG

# Texts OneForAll shows that stay English, with the reason (lesson 14: saved; one-letter marks; names).
STAY = {
    "R (raid quest)": "its one-letter quest mark: MapQuests keeps the letter while the text holds 'quest'",
    "D (dungeon quest)": "its one-letter quest mark: MapQuests keeps the letter while the text holds 'quest'",
    "Imported": "the default name of an imported profile: saved in the player's data (lesson 13, 14)",
    "OneForAll": "the addon's own name",
}
# A text OneForAll writes into its saved data or matches by name (never change, OneForAll.md): by English.
STAY_PREFIX = ()
# Slot letters by Code key (or by English), one letter per slot, %d too. A %s missing here is "?" in review.
SORTS = {
    "Code.00ee5646": "vvv", "Code.00f5c353": "n", "Code.015a3685": "n", "Code.01da3541": "f",
    "Code.05494310": "v", "Code.05b15d03": "vf", "Code.06ac75a1": "n", "Code.0a51fcad": "v",
    "Code.0adc2da1": "v", "Code.0b064a70": "n", "Code.0c2189e5": "n", "Code.0c54d8fb": "ntv",
    "Code.0c5f3a6b": "v", "Code.0d8dfc5f": "v", "Code.0e2c75e0": "n", "Code.0f27853f": "n",
    "Code.0f94c355": "f", "Code.125126cf": "f", "Code.1294e9b0": "f", "Code.13ddce5b": "t",
    "Code.14d4d8df": "f", "Code.15535c35": "n", "Code.15cdc0c3": "nv", "Code.1617a860": "tn",
    "Code.166ad36a": "n", "Code.181c6902": "vvn", "Code.1898a055": "v", "Code.18e98644": "v",
    "Code.1bf385f6": "n", "Code.1bf5bc72": "nn", "Code.1c109aac": "v", "Code.1c964ba5": "v",
    "Code.1e070028": "v", "Code.21a5c0dc": "vv", "Code.222d4471": "n", "Code.22d82511": "v",
    "Code.24312e48": "n", "Code.24423d3c": "vvv", "Code.24a8628e": "t", "Code.24e26421": "v",
    "Code.268cf87e": "t", "Code.27c6530f": "fv", "Code.2850814d": "nnv", "Code.2914c1d3": "nv",
    "Code.2a894688": "nf", "Code.2c0fd0d0": "f", "Code.2d19fdea": "fv", "Code.2d360c43": "ff",
    "Code.2dd2342e": "n", "Code.2ddcd47e": "vv", "Code.2e174645": "ft", "Code.2e3f31b3": "f",
    "Code.3021fcd7": "n", "Code.31774ba8": "fvv", "Code.3299f542": "fv", "Code.32ad761f": "n",
    "Code.33bd8c3d": "f", "Code.3574d1a9": "v", "Code.35a670e2": "t", "Code.36c23ae2": "v",
    "Code.3ae14509": "n", "Code.3b852b9b": "n", "Code.3e6e7a5c": "v", "Code.3e777cab": "t",
    "Code.3f4295f4": "ff", "Code.4024d16b": "t", "Code.41608240": "v", "Code.43b4914b": "t",
    "Code.443d8fad": "t", "Code.4919da4d": "v", "Code.4cb5f43c": "v", "Code.512255b7": "f",
    "Code.51359af5": "f", "Code.524f194a": "f", "Code.530a41e7": "t", "Code.56cefc41": "t",
    "Code.57dd507d": "v", "Code.580c98ca": "n", "Code.58c59232": "n", "Code.59152f21": "nv",
    "Code.59b43698": "f", "Code.5c4e4e49": "f", "Code.5f4a5321": "vv", "Code.5fc7ae5b": "t",
    "Code.60f4dd1c": "v", "Code.615a1562": "f", "Code.6263b96b": "v", "Code.62fba321": "t",
    "Code.646a7ddd": "n", "Code.674dfcec": "v", "Code.68f9c3c8": "vvn", "Code.699ab1d9": "t",
    "Code.69d212df": "n", "Code.6a04642b": "t", "Code.6a938310": "n", "Code.6e002485": "v",
    "Code.6f2e9b24": "n", "Code.6f999cc0": "t", "Code.7164bbbc": "n", "Code.71894578": "ffv",
    "Code.71e62e4b": "v", "Code.744fae47": "vn", "Code.76048340": "t", "Code.796c1b33": "v",
    "Code.7a9cde6b": "n", "Code.7d7ef18e": "t", "Code.7f09e971": "f", "Code.805fca38": "fv",
    "Code.8156e1b5": "n", "Code.818ccf93": "t", "Code.846fc024": "v", "Code.84b1f05c": "n",
    "Code.856f561b": "v", "Code.86798557": "n", "Code.88ea47ff": "f", "Code.89d3cce4": "n",
    "Code.8bd69a69": "v", "Code.8c5f4cd2": "v", "Code.8f898696": "vn", "Code.918a17a4": "f",
    "Code.93830646": "n", "Code.93f737ea": "t", "Code.944cf9dd": "t", "Code.94815478": "f",
    "Code.962d3989": "v", "Code.9856bfbc": "v", "Code.99bc95d2": "t", "Code.9b269860": "vntvv",
    "Code.9cb03d4b": "n", "Code.9d21f843": "t", "Code.9d8cad25": "n", "Code.9d8cd6f1": "fv",
    "Code.9f96b273": "v", "Code.a0d33c75": "v", "Code.a263868f": "n", "Code.a3427f33": "v",
    "Code.a34ec0fe": "t", "Code.a9512651": "n", "Code.aa0b08b0": "n", "Code.aafb62cc": "n",
    "Code.abccb153": "ft", "Code.ac32e275": "nv", "Code.ad082b38": "n", "Code.ae60f26c": "n",
    "Code.af911cb4": "ff", "Code.b00d4dea": "v", "Code.b067376a": "n", "Code.b19a4a44": "f",
    "Code.b40742bd": "fv", "Code.b5aa3664": "v", "Code.b5bd0e78": "t", "Code.b5d82b67": "n",
    "Code.b8f1f850": "t", "Code.ba752530": "v", "Code.bb6c1be2": "t", "Code.bb9a5dba": "f",
    "Code.be5ed555": "tvv", "Code.bfc1222e": "f", "Code.bfe21f04": "v", "Code.c04bedf2": "f",
    "Code.c1464234": "n", "Code.c1758401": "v", "Code.c32374a0": "vv", "Code.c3d09e10": "v",
    "Code.c50372a5": "v", "Code.c5b09e86": "n", "Code.c6330e0b": "f", "Code.c6a9167c": "v",
    "Code.c7f3255b": "f", "Code.c983c98d": "vn", "Code.ca2a7b8b": "nf", "Code.cb43a0f6": "tt",
    "Code.cb7be02a": "n", "Code.ce10d379": "n", "Code.d0cf26fb": "vv", "Code.d19aad4f": "n",
    "Code.d25947f0": "ttv", "Code.d270fb0a": "n", "Code.d757ac00": "n", "Code.d8821f2e": "nvv",
    "Code.d8e9ae47": "t", "Code.d9dda078": "n", "Code.d9f2a213": "n", "Code.db3511e7": "vv",
    "Code.dba8f5a8": "nf", "Code.dbee665a": "nf", "Code.dedd2926": "ttn", "Code.df57a77c": "f",
    "Code.dff9b97e": "v", "Code.e2662d71": "n", "Code.e387a0bd": "t", "Code.e39f3245": "t",
    "Code.e7641635": "n", "Code.ecf3e226": "t", "Code.edd65af9": "v", "Code.ee407b2b": "f",
    "Code.ef33a4f0": "fv", "Code.efb22e55": "ftv", "Code.eff6aa8f": "v", "Code.f23487e3": "n",
    "Code.f267241d": "vn", "Code.f278c82d": "n", "Code.f5388795": "n", "Code.f58996c8": "f",
    "Code.f5fc475f": "v", "Code.f63ac0a5": "v", "Code.f6883947": "n", "Code.f6c877e7": "n",
    "Code.f6f15ff7": "tv", "Code.fc405369": "v", "Code.fd3a6448": "n", "Code.fd812865": "v",
    "Code.fe038c61": "n", "Code.a174ec26": "v",
    "Code.e6a0c449": "vn",    # a count, then the dungeon's name (FLT.DungeonName)
    "Code.54e50a58": "v", "Code.d03d79eb": "v", "Code.e70eba84": "v", "Code.ab9a6ab8": "v",    # RT.Clock times
    "Code.f31989ba": "n",     # the wishlist item's name (GetItemInfo)
}
# Fixed-width boxes (OneForAll-design.md): English -> letters. Filled as the review finds them.
BOX = {}
LONG = {}
# Data pools and their fixed widths (HunterPets columns, TrainerSpells, LowRank): a note per pool.
POOL_NOTE = {
    "pets": "Hunter pets: a sentence of its data, numbers as %s (FLT.LNum)",
    "boss": "a boss's description in the Dungeons tab",
    "summary": "a key or attunement summary",
    "enchant": "where an enchant comes from (Enchants tab)",
    "code": "a literal of its code (not through L)",
    "upper": "a tile label it shows in capitals (SkillUpUI): write it in capitals too",
    "colon": "the text with its colon cut and a full stop (SkillUpUI)",
}
PLURAL = re.compile(r"\{([^{}|]*)\|([^{}|]*)\|([^{}|]*)\}")
NUMBER_BEFORE = re.compile(r"(?:%\d*(?:\.\d*)?[df]|%s)\s*$")     # a number slot right before a plural mark
AREAS = {}               # batch number -> what it holds (filled by split)


def key_of(en):
    import hashtext as H
    return "Code." + H.djb2(en)


def sorts(key, en):
    """[letter or None] per slot. A slot inside a LNum sentence (made from numbers) is v."""
    mark = SORTS.get(key, SORTS.get(en))
    if mark is not None:
        return K.sorts_from({key: mark}, key, en)
    letters = K.sorts_from({}, key, en)
    if en in NUMBERED:
        return ["v" for _ in letters]
    return letters


NUMBERED = set()         # LNum sentences: each %s was a number (filled by ofa_source)


def keep(en, pool="L"):
    """(kept, reason left out)."""
    if en in STAY or any(en.startswith(p) for p in STAY_PREFIX):
        return False, "stays English"
    if not en.strip():
        return False, "empty"
    plain = K.SPECIAL.sub("", en)
    if not K.LATIN_WORD.search(plain):
        return False, "no words"
    if re.fullmatch(r"\s*[A-Za-z]\s*", plain):
        return False, "one letter"
    if pool == "code":
        if re.fullmatch(r"[a-z_]+[a-z0-9_]*", en):
            return False, "machine word"
        if re.fullmatch(r"/\S+|[A-Z0-9_]+", en):
            return False, "command or key"
        if en.startswith("|T") or en.startswith("|A") or en.startswith("|H"):
            return False, "icon or link piece"
    return True, ""


def split(groups):
    """groups: [(area, pool, rows)] in order. Returns rows numbered by batch: an L group is cut into equal parts of
    at most MAX_BATCH (small neighbours are joined), a prose group into parts of PROSE_BATCH rows / PROSE_BYTES."""
    out, n, AREAS_ = [], 0, {}
    cur, cur_areas = [], []

    def flush():
        nonlocal n, cur, cur_areas
        if cur:
            n += 1
            out.extend([r[0], r[1], n, r[3], r[4]] for r in cur)
            AREAS_[n] = ", ".join(dict.fromkeys(cur_areas))[:150]
        cur, cur_areas = [], []

    for area, pool, rows in groups:
        if not rows:
            continue
        if pool in ("L", "code", "upper", "colon"):
            if len(rows) > MAX_BATCH:
                flush()
                parts = -(-len(rows) // MAX_BATCH)
                size = -(-len(rows) // parts)
                for i in range(0, len(rows), size):
                    cur, cur_areas = list(rows[i:i + size]), [area]
                    flush()
                continue
            if len(cur) + len(rows) > MAX_BATCH:
                flush()
            cur += rows
            cur_areas.append(area)
            continue
        flush()                              # prose: its own batches
        size = 0
        for r in rows:
            b = len(r[1].encode("utf-8"))
            if cur and (len(cur) >= PROSE_BATCH or size + b > PROSE_BYTES):
                flush()
                size = 0
            cur.append(r)
            cur_areas.append(area)
            size += b
        flush()
    flush()
    AREAS.clear()
    AREAS.update(AREAS_)
    return out


def batches():
    """[(number, area)] for key_text.review."""
    return [(b, a) for b, a in sorted(AREAS.items())] or [(1, "nothing")]


def check(key, en, ua):
    """What makes `ua` unfit as the Ukrainian of `en`."""
    plain, problems = PLURAL.sub(lambda m: m.group(3), ua), []     # a plural read as its "many" form
    for m in PLURAL.finditer(ua):
        if not NUMBER_BEFORE.search(ua[:m.start()]):
            problems.append("a plural {a|b|c} only after a number slot (%d)")
    if ("{" in plain or "}" in plain) and "{" not in en:
        problems.append("a stray brace (a plural has three forms: one|few|many)")
    letters = sorts(key, en)
    problems += K.base_check(en, plain, letters)
    if en in STAY:
        problems.append("stays English (STAY)")
    if len(K.SPECIAL.sub("", en).strip()) < 2:
        problems.append("a text under two letters is never ours")
    if en.count("|c") != ua.count("|c") or en.count("|r") != ua.count("|r"):
        problems.append("colour codes (|c...|r) differ in number")
    if re.match(r"\|c[0-9a-fA-F]{8}", en) and not ua.startswith(en[:10]):
        problems.append("the colour code at the start moved")
    if en.count("\n") != ua.count("\n"):
        problems.append("line breaks differ in number")
    if en.isupper() and ua != ua.upper():
        problems.append("OneForAll shows this one in capitals: write it in capitals")
    for ch, why in (("—", "a long dash"), ("–", "a long dash"), ("·", "a middle dot"), ("•", "a bullet"),
                    ("«", "angle quotes"), ("»", "angle quotes")):
        if ch in ua and ch not in en:
            problems.append(f"no {why} (the Cyrillic font and the owner's rule)")
    for rx, (use, why) in BANNED.items():
        if re.search(rx, ua, re.I):
            problems.append(f"banned word: use {use} ({why})")
    limit = LONG.get(en, BOX.get(en))
    if limit and len(plain.split("\n")[0]) > limit:
        problems.append(f"too long for its box: {len(plain.split(chr(10))[0])} > {limit}")
    return problems
