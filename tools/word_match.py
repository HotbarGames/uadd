"""Word consistency, the matching: normalised English, Ukrainian stems, and the three kinds of case.

Used by tools/word_consistency.py (the CLI and report; its docstring says what each kind is).
Standard library only. Tests: python3 -m unittest tools.test_word_consistency
"""
import collections
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import hashtext as H  # noqa: E402

CYR = re.compile(r"[А-Яа-яІіЇїЄєҐґ]")
PRINTF = re.compile(r"%(?:\d+\$)?[-+ #0]*\d*(?:\.\d*)?[sdifx]")
TRAIL = re.compile(r"[\s.:!?…,;]+$")
GAME_NAME = re.compile(r"\{(?:npc|zone|item|quest|spell|obj|faction):")
WORD = re.compile(r"[A-Za-zА-Яа-яІіЇїЄєҐґ'’ʼ]+")
VOWELS = set("аеєиіїоуюя")
STOP = {"у", "в", "з", "із", "зі", "на", "до", "для", "за", "від", "та", "і", "й", "або", "не", "по", "що", "як"}
ENDINGS = sorted(("ування", "ювання", "ується", "юються", "ються", "ється", "увати", "ювати", "ами", "ями", "ові",
                  "еві", "єві", "ого", "ому", "ими", "іми", "ій", "ий", "их", "іх", "ої", "ою", "ею", "єю", "ам", "ям",
                  "ах", "ях", "ом", "ем", "єм", "ів", "їв", "ти", "ть", "ся", "сь", "а", "я", "у", "ю", "і", "ї", "и",
                  "о", "е", "є", "ь", "й"), key=len, reverse=True)

Pair = collections.namedtuple("Pair", "module key en uk gid where")


# ── Normalising and stems ───────────────────────────────────────────────────────────────────────────────

def norm(text):
    """Case, inner spaces and trailing punctuation aside; every printf slot reads %s."""
    return TRAIL.sub("", " ".join(PRINTF.sub("%s", text).split())).lower()


def stem(word):
    w = word.lower().replace("’", "'").replace("ʼ", "'")
    if w[:1] == "у" and (len(w) == 1 or w[1] not in VOWELS):
        w = "в" + w[1:]   # у/в swap by sound: «уміння» = «вміння», «у мережі» = «в мережі»
    elif w == "й":
        w = "і"
    for end in ENDINGS:
        if w.endswith(end) and len(w) - len(end) >= 2:
            return w[:-len(end)]
    return w


def stem_match(a, b):
    """True when two words look like forms of one word: their stems share all but at most one letter."""
    sa, sb = (stem(w).replace("і", "о") for w in (a, b))   # і/о swap in a stem: «вхід» = «входу»
    if sa == sb:
        return True
    cp = 0
    for x, y in zip(sa, sb):
        if x != y:
            break
        cp += 1
    return cp >= max(2, min(len(sa), len(sb)) - 1)


def same_forms(a, b):
    """True when two Ukrainian texts have the same words in other forms only (case, ending, a short form)."""
    wa, wb = WORD.findall(a), WORD.findall(b)
    return bool(wa) and len(wa) == len(wb) and all(stem_match(x, y) for x, y in zip(wa, wb))


def clusters(texts):
    """The texts in groups that differ only in word forms (same_forms with the group's first text)."""
    out = []
    for t in texts:
        for c in out:
            if same_forms(c[0], t):
                c.append(t)
                break
        else:
            out.append([t])
    return out


def content_words(text):
    return [w for w in WORD.findall(text) if len(w) >= 2 and w.lower() not in STOP]


def has_word(text, word):
    """True when `text` holds a form of the Ukrainian `word`."""
    return any(stem_match(word, w) for w in WORD.findall(text))


def short_label(en):
    words = en.split()
    return (1 <= len(words) <= 3 and not re.search(r"[%|{}\[\]\n]|##", en) and re.search("[A-Za-z]", en)
            and len(en) <= 40)


# ── The three kinds ─────────────────────────────────────────────────────────────────────────────────────

def kind1(pairs, allow=None):
    """[(score, module, group hash, {variant: [pairs]}, allowed, forms only)] for one English with 2+ Ukrainian
    texts. forms only: the variants differ only in word forms (case, ending, a short form), not in words.
    allow: {(module, group hash): why} (ALLOW in word_consistency.py)."""
    allow = allow or {}
    groups = collections.defaultdict(list)
    for p in pairs:
        groups[(p.module, norm(p.en))].append(p)
    out = []
    for (mod, en), ps in groups.items():
        variants = collections.defaultdict(list)
        for p in ps:
            variants[norm(p.uk)].append(p)
        if len(variants) < 2:
            continue
        gids = [{p.gid for p in v} for v in variants.values()]
        if all(None not in g for g in gids) and len(set().union(*gids)) == sum(len(g) for g in gids):
            continue  # each variant is linked to its own glossary meaning
        h = H.djb2(en)
        forms = len(clusters(list(variants))) == 1
        out.append((len(variants) * 100 + len(ps), mod, h, dict(variants), (mod, h) in allow, forms))
    return sorted(out, key=lambda c: (c[5], -c[0], c[1], c[2]))


def strict_cases(k1):
    """The kind-1 cases --strict fails on: other words (not only other forms) and not in ALLOW."""
    return [c for c in k1 if not c[4] and not c[5]]


def _gloss_by_en(entries):
    by = collections.defaultdict(list)
    for e in entries:
        for w in e["en"]:
            by[norm(w)].append(e)
    return by


def kind2(pairs, entries):
    """[(score, English, {variant: [places]}, meaning ids)] for short labels that read differently."""
    by_en = _gloss_by_en(entries)
    labels = collections.defaultdict(lambda: collections.defaultdict(set))   # en -> variant -> {module}
    raw = {}
    for p in pairs:
        if short_label(p.en):
            n = norm(p.en)
            raw.setdefault(n, p.en)
            labels[n][(norm(p.uk), p.gid)].add(p.module)
    out = []
    for en, seen in labels.items():
        meanings = by_en.get(en, [])
        variants = collections.defaultdict(set)
        for (uk, gid), mods in seen.items():
            if len(meanings) > 1 and (gid or uk in {norm(e["uk"]) for e in meanings}):
                continue   # it fits one of the glossary's meanings
            if gid and len(meanings) <= 1:
                uk = norm(next((e["uk"] for e in entries if e["id"] == gid), uk))
            variants[uk] |= mods
        if len(meanings) == 1:
            variants[norm(meanings[0]["uk"])].add("glossary " + meanings[0]["id"])
        merged = {}
        for group in clusters(sorted(variants, key=lambda u: -len(variants[u]))):
            merged[" / ".join(group)] = set().union(*(variants[u] for u in group))
        variants = merged   # one entry per word; its forms (синій / синя) are one
        places = set().union(*variants.values()) if variants else set()
        if len(variants) < 2 or len(places) < 2:
            continue
        if not any(variants[a] != variants[b] for a in variants for b in variants):
            continue
        if len({frozenset(m) for m in variants.values()}) == 1:
            continue   # one place holds every variant: that is kind 1
        out.append((len(variants) * 100 + len(places), raw[en], dict(variants), [e["id"] for e in meanings]))
    return sorted(out, key=lambda c: (-c[0], c[1]))


def _term_patterns(entries):
    pats = []
    for e in entries:
        for w in e["en"]:
            if re.search(r"[%|]|##", w) or len(re.findall("[A-Za-z]", w)) < 3:
                continue
            pats.append((e, w, re.compile(r"(?<![A-Za-z])" + re.escape(w) + r"(?:s|es)?(?![A-Za-z])", re.I)))
    return pats


def kind3(pairs, entries, ui=False):
    """{(module, glossary id): [pairs]}: the term is in the English, no form of its Ukrainian is in ours (one
    word of a glossary word made of several is enough: «точки» for «Точка збору»). The ui.* entries (Show,
    Enable, Back) are left out unless ui: a longer text says such a verb in its own way."""
    pats = [t for t in _term_patterns(entries) if ui or not t[0]["id"].startswith("ui.")]
    by_en = _gloss_by_en(entries)
    out = collections.defaultdict(list)
    for p in pairs:
        if not CYR.search(p.uk):
            continue
        hits = []
        for e, w, pat in pats:
            if norm(p.en) == norm(w):
                continue
            for m in pat.finditer(p.en):
                hits.append((m.start(), m.end(), w, e))
        long_text = len(p.en.split()) > 4
        names = GAME_NAME.search(p.uk)
        for s, t, w, e in hits:
            if any(s2 <= s and t <= t2 and (t2 - s2) > (t - s) for s2, t2, _, _ in hits):
                continue   # a longer term holds this one
            if long_text and not p.en[s].isupper():
                continue   # a plain word in a sentence ("bring it back"), not the term
            if s and p.en[s].isupper() and names:
                continue   # likely part of a game name we take from UALL Forever ("Master Gadrin")
            meanings = by_en.get(norm(w), [e]) + by_en.get(norm(p.en[s:t]), [])   # Bag, and Bags too
            if any(not content_words(m["uk"]) or any(has_word(p.uk, cw) for cw in content_words(m["uk"]))
                   for m in meanings):
                continue
            if p not in out[(p.module, e["id"])]:
                out[(p.module, e["id"])].append(p)
    return out
