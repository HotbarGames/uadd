"""Word consistency, the sources: our Ukrainian from a module's Lua data, and the English it pairs with
(the installed addons through tools/drift.py's extractors, or the review files in local/).

Used by tools/word_consistency.py. The drift cache (tools/.cache/drift.json) is read, never written.
Standard library only. Tests: python3 -m unittest tools.test_word_consistency
"""
import collections
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import hashtext as H  # noqa: E402
from luatok import NAME, STR, SYM, read as _read, tokens  # noqa: E402
from word_match import CYR, Pair  # noqa: E402

REPO = HERE.parent
CACHE = HERE / ".cache" / "drift.json"
HASHKEY = re.compile(r"^\d+:[0-9a-f]{8}$")

# Review files per module (git-ignored local/): the English when the addon is not installed.
REVIEWS = {
    "UADD_Attune": ["attune.txt"], "UADD_Auctionator": ["auctionator.txt"], "UADD_AutoPotion": ["autopotion.txt"],
    "UADD_Bagnon": ["bagnon.txt"], "UADD_DialogueUI": ["dialogueui.txt"], "UADD_ForeverXPBar": ["foreverxpbar.txt"],
    "UADD_LayerSwap": ["layerswap.txt"], "UADD_GatherMate2": ["gathermate2/*.txt"], "UADD_Mastercraft": ["mastercraft/*.txt"],
    "UADD_Pawn": ["pawn/*.txt"], "UADD_RareScanner": ["rs/*.txt"], "UADD_Scrap": ["scrap/*.txt"],
    "UADD_SpeedyAutoLoot": ["sal/*.txt"], "UADD_TomTom": ["tomtom/*.txt"], "UADD_WaypointUI": ["waypointui/*.txt"],
    "UADD_WhatsTraining": ["whatstraining/*.txt"],
}


# ── Our data ────────────────────────────────────────────────────────────────────────────────────────────

def _link(toks, i):
    """(glossary id, next index) when toks[i] is G"id" / G("id") / Glossary.Text("id"), else (None, i)."""
    if toks[i][:2] == (NAME, "G"):
        j = i + 1
    elif toks[i][:2] == (NAME, "Glossary") and [t[:2] for t in toks[i + 1:i + 3]] == [(SYM, "."), (NAME, "Text")]:
        j = i + 3
    else:
        return None, i
    if j < len(toks) and toks[j][0] == STR and toks[i][1] == "G":
        return toks[j][1], j + 1
    if j + 2 < len(toks) and toks[j][:2] == (SYM, "(") and toks[j + 1][0] == STR and toks[j + 2][:2] == (SYM, ")"):
        return toks[j + 1][1], j + 3
    return None, i


def _value(toks, i, gloss):
    """(Ukrainian, glossary id) of the value at toks[i]: a string with Cyrillic (not "a" .. b) or a link."""
    if i >= len(toks):
        return None, None
    if toks[i][0] == STR:
        if i + 1 < len(toks) and toks[i + 1][:2] == (SYM, "."):
            return None, None
        return (toks[i][1], None) if CYR.search(toks[i][1]) else (None, None)
    gid, _ = _link(toks, i)
    if gid is not None:
        return gloss.get(gid), gid
    return None, None


def _record(toks, i, gloss):
    """The fields id, hash and uk of the table constructor at toks[i] == "{", at its own depth only."""
    out, j, depth = {}, i + 1, 1
    while j < len(toks) and depth:
        kind, val, _ = toks[j]
        if depth == 1 and kind == NAME and val in ("id", "hash", "uk") and j + 1 < len(toks) \
                and toks[j + 1][:2] == (SYM, "="):
            k = j + 2
            if k < len(toks) and toks[k][0] == STR and val != "uk":
                out[val] = toks[k][1]
            elif k < len(toks) and toks[k][:2] == (SYM, "{"):
                parts, k = [], k + 1
                while k < len(toks) and toks[k][:2] != (SYM, "}"):
                    if toks[k][0] == STR:
                        parts.append(toks[k][1])
                    elif toks[k][:2] == (SYM, "0"):
                        parts.append("%s")
                    k += 1
                out[val] = parts if val == "hash" else "".join(parts)
                j = k + 1
                continue
            elif val == "uk":
                out["uk"], _ = _value(toks, k, gloss)
            j = k + 1
            continue
        depth += (kind, val) == (SYM, "{")
        depth -= (kind, val) == (SYM, "}")
        j += 1
    return out


def tpl_term(hashes):
    return "tpl:" + ",".join(hashes)


def template_term(en):
    """The term a template's record in our data has: the hashes of its literal pieces, as hashtext stores them."""
    if not H.is_template(en):
        return None
    pieces = [""]
    for t in H.tokens(en):
        if t[0] == "lit":
            pieces[-1] += t[1]
        else:
            pieces.append("")
    return tpl_term(H.djb2(p) for p in pieces)


def parse_data(paths, gloss):
    """(terms, alias) of a module's Lua files. terms: name -> [(Ukrainian, glossary id, where)], a name being
    a table key (["key"] = or key =), a record's id, or tpl:<piece hashes> of a template record. alias: an
    English hash -> the keys a src table points from it (Bagnon's B.src["config:X"] = "13:...")."""
    terms, alias = collections.defaultdict(list), collections.defaultdict(list)
    for path in paths:
        toks = list(tokens(_read(path)))
        where = Path(path).name
        for i, tok in enumerate(toks):
            if tok[:2] == (SYM, "{"):
                rec = _record(toks, i, gloss)
                if rec.get("uk"):
                    if rec.get("id"):
                        terms[rec["id"]].append((rec["uk"], None, f"{where}:{tok[2]}"))
                    if isinstance(rec.get("hash"), list):
                        terms[tpl_term(rec["hash"])].append((rec["uk"], None, f"{where}:{tok[2]}"))
                continue
            name = None
            if tok[:2] == (SYM, "[") and i + 3 < len(toks) and toks[i + 1][0] == STR \
                    and toks[i + 2][:2] == (SYM, "]") and toks[i + 3][:2] == (SYM, "="):
                name, k = toks[i + 1][1], i + 4
                if k < len(toks) and toks[k][0] == STR and HASHKEY.match(toks[k][1]):
                    alias[toks[k][1]] += [name, name.split(":", 1)[-1]]
                    continue
            elif tok[0] == NAME and i + 1 < len(toks) and toks[i + 1][:2] == (SYM, "=") \
                    and tok[1] not in ("uk", "id", "en", "note", "hash"):
                name, k = tok[1], i + 2
            if name is None:
                continue
            uk, gid = _value(toks, k, gloss)
            if uk:
                terms[name].append((uk, gid, f"{where}:{tok[2]}"))
    return terms, alias


def candidates(key, en):
    out = []
    if key:
        out += [key, key.strip('"'), H.key(key), H.djb2(key)]
    out += [en, H.key(en), H.djb2(en), "Code." + H.djb2(en)]
    t = template_term(en)
    if t:
        out.append(t)
    return out


def pair(module, rows, terms, alias):
    """Pairs of (English, our Ukrainian) for the rows (key or None, English, Ukrainian from a review or None)."""
    out, seen = [], set()
    for key, en, review_uk in rows:
        if not en or not en.strip():
            continue
        hit = None
        for c in candidates(key, en):
            if c in terms:
                hit = terms[c][0]
                break
            for a in alias.get(c, ()):
                if a in terms:
                    hit = terms[a][0]
                    break
            if hit:
                break
        if hit is None and review_uk and CYR.search(review_uk):
            hit = (review_uk, None, "review")
        if hit is None:
            continue
        ident = (key, en)
        if ident in seen:
            continue
        seen.add(ident)
        out.append(Pair(module, key, en, hit[0], hit[1], hit[2]))
    return out


# ── Where the English comes from ────────────────────────────────────────────────────────────────────────

REVIEW_EN = re.compile(r"^(?:EN|en): ?(.*)$")
REVIEW_UK = re.compile(r"^(?:UA|uk): ?(.*)$")
QUOTED = re.compile(r'^"((?:[^"\\]|\\.)*)"')
KEY_MARK = re.compile(r"^#.*\[([^\]\s]+)\]\s*$|^== (?:\S+ )?(\S+)(?: \w+)?$|^\[\"(.+)\"\]$|^key: (.+)$")


def _unquote(s, gloss):
    s = s.strip("\r")
    m = re.match(r'^G\(?"([^"]+)"\)?$', s.strip())
    if m:
        return gloss.get(m.group(1))
    m = QUOTED.match(s)
    if m:
        return next((t[1] for t in tokens(m.group(0)) if t[0] == STR), "")
    return s


def read_review(path, gloss):
    """[(key or None, English, Ukrainian)] from a review file: EN:/UA: or en:/uk: lines, the key from the
    [KEY] mark, the == header or the ["key"] line before them."""
    rows, key, en = [], None, None
    for line in Path(path).read_text(encoding="utf-8", errors="replace").splitlines():
        m = REVIEW_EN.match(line)
        if m:
            en = _unquote(m.group(1), gloss)
            continue
        m = REVIEW_UK.match(line)
        if m and en is not None:
            rows.append((key, en, _unquote(m.group(1), gloss)))
            en, key = None, None
            continue
        m = KEY_MARK.match(line)
        if m:
            key = next(g for g in m.groups() if g)
    return rows


def installed_rows(modules):
    """{module: [(key, English, None)]} from the installed addons, through tools/drift.py's extractors."""
    from concurrent.futures import ThreadPoolExecutor
    import copy_scan as C
    from drift_sources import MODULES, scan
    try:
        cache = json.loads(CACHE.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        cache = {}
    addons, out, notes = Path(C.addons_dir()), {}, []
    with ThreadPoolExecutor(C.THREADS) as pool:
        for mod in modules:
            folder = addons / MODULES[mod][0]
            if not folder.is_dir():
                notes.append(f"{mod}: {MODULES[mod][0]} not installed")
                continue
            got = scan(mod, folder, cache, pool)
            notes += [f"{mod}: {r[2]}" for r in got["rows"] if r[0] == "!"]
            out[mod] = [(r[1], r[2], None) for r in got["rows"] if r[0] != "!"]
    return out, notes


def review_rows(mod, gloss, root=REPO):
    paths = [p for pat in REVIEWS.get(mod, ()) for p in sorted((Path(root) / "local").glob(pat))]
    return [r for p in paths for r in read_review(p, gloss)]
