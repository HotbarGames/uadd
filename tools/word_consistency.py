"""Word consistency across translation batches: the same English, or the same term, with different Ukrainian.

python3 tools/word_consistency.py               the report (exit 0)
python3 tools/word_consistency.py --strict      exit 1 when kind 1 finds other words that ALLOW does not list
Options: --module NAME (more than once), --top N (cases per kind, default 15; 0 = all, with kind 1's
forms-only cases), --english (print the English of all-rights-reserved addons too: for a local look only,
never paste it into a tracked file), --source review (read the English from the review files in local/
instead of the installed addons), --ui (kind 3 also for the ui.* glossary words).

Texts are translated by several agents in batches of ~150, so one English can come out two ways. Three kinds:
  1  in one module: the same English (case, spaces and trailing .:!?… aside) with two or more Ukrainian texts.
     Variants with the same words in other forms only («Хост» / «хоста») are counted apart and never strict.
  2  across modules: a short label (1-3 words, no slots or codes) with different Ukrainian in different modules
     or against the glossary; forms of one word (синій / синя) count as one. When the glossary has two meanings
     for that English (docs/GLOSSARY.md), a text that is linked to one or matches one is fine; only texts that
     fit no meaning are compared.
  3  a glossary term inside a longer English text whose Ukrainian has no form of the glossary word (words are
     compared by stem: Ukrainian inflects). A shorter term inside a longer one that also matched is skipped; in
     a text of 5+ words only a capitalised term counts. Many hits are a second meaning the glossary lacks
     (Key: a keyboard key) - read them, they are leads, not errors.

The English comes from the installed addons, through the same extractors tools/drift.py runs (their cache in
tools/.cache/drift.json is read, never written), or from the review files in local/ when an addon is not
installed. Our Ukrainian comes from the module's data (UADD_*/**/*.lua): a text is found by its key, its
English or the hash of its English (tools/hashtext.py), as the module itself finds it. The report names a text
of an all-rights-reserved addon by its key or hash only (the licence rule in CLAUDE.md), unless --english.
Files: this one (CLI, report), tools/word_match.py (stems, the three kinds), tools/word_sources.py (our data,
the English). Standard library only. Tests: python3 -m unittest tools.test_word_consistency
"""
import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import hashtext as H  # noqa: E402
from word_match import (Pair, clusters, content_words, has_word, kind1, kind2, kind3, norm,  # noqa: E402,F401
                        same_forms, short_label, stem, stem_match, strict_cases)
from word_sources import (REPO, installed_rows, pair, parse_data, read_review,  # noqa: E402,F401
                          review_rows, template_term)

# Kind-1 cases that are right as they are (the context differs): (module, djb2 of the normalised English) ->
# why. Hashes only, never the English. --strict ignores them.
ALLOW = {}


# ── Report ──────────────────────────────────────────────────────────────────────────────────────────────

def _arr(mod):
    import copy_scan as C
    from drift_sources import MODULES
    return MODULES.get(mod, (mod,))[0] not in C.ALLOWED


def _name(p, english):
    if english or not _arr(p.module):
        return repr(p.en[:70])
    return p.key if p.key else H.key(p.en)


def _uk(s):
    s = s.replace("\n", "\\n")
    return repr(s if len(s) <= 70 else s[:67] + "...")


def report(pairs, entries, top=15, english=False, out=print, ui=False):
    k1, k2, k3 = kind1(pairs, ALLOW), kind2(pairs, entries), kind3(pairs, entries, ui)
    by_id = {e["id"]: e for e in entries}
    show = lambda xs: xs if not top else xs[:top]  # noqa: E731
    words1, forms1 = strict_cases(k1), [c for c in k1 if c[5]]
    out(f"kind 1 (one module, one English, 2+ Ukrainian): {len(words1)} with other words, {len(forms1)} with "
        f"other forms only (case, ending, short form; listed with --top 0)"
        + (f", {len(k1) - len(words1) - len(forms1)} in ALLOW" if len(k1) > len(words1) + len(forms1) else ""))
    for score, mod, h, variants, allowed, forms in show([c for c in k1 if top == 0 or not c[5]]):
        any_p = next(iter(variants.values()))[0]
        out(f"  {mod} h:{h} {_name(any_p, english) if not _arr(mod) or english else ''}".rstrip()
            + (" [ALLOW]" if allowed else "") + (" [forms]" if forms else ""))
        for uk, ps in sorted(variants.items(), key=lambda v: -len(v[1])):
            out(f"      {len(ps)}x {_uk(ps[0].uk)}  " + ", ".join(_name(p, english) for p in ps[:4])
                + (" ..." if len(ps) > 4 else ""))
    out(f"kind 2 (short label, different Ukrainian across modules or the glossary): {len(k2)} cases")
    for score, en, variants, meanings in show(k2):
        mods = {m.split()[0] for ms in variants.values() for m in ms}
        allowed_en = english or all(m == "glossary" or not _arr(m) for m in mods)
        name = repr(en) if allowed_en else "h:" + H.djb2(norm(en))
        out(f"  {name}" + (f"  (glossary meanings: {', '.join(meanings)})" if len(meanings) > 1 else ""))
        for uk, places in sorted(variants.items(), key=lambda v: -len(v[1])):
            out(f"      {uk!r}: {', '.join(sorted(places))}")
    total3 = sum(len(v) for v in k3.values())
    out(f"kind 3 (glossary term in a longer English, its word not in our Ukrainian): {total3} texts in "
        f"{len(k3)} module/term pairs")
    for (mod, gid), ps in show(sorted(k3.items(), key=lambda kv: (-len(kv[1]), kv[0]))):
        e = by_id[gid]
        out(f"  {mod} {gid} {' / '.join(e['en'])!r} = {e['uk']!r}: {len(ps)} text(s): "
            + ", ".join(_name(p, english) for p in ps[:5]) + (" ..." if len(ps) > 5 else ""))
    return k1, k2, k3


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--strict", action="store_true")
    ap.add_argument("--module", action="append")
    ap.add_argument("--top", type=int, default=15)
    ap.add_argument("--english", action="store_true")
    ap.add_argument("--source", choices=("installed", "review"), default="installed")
    ap.add_argument("--ui", action="store_true", help="kind 3 also for the ui.* glossary words")
    a = ap.parse_args(argv)
    import glossary
    from drift_sources import MODULES
    g = glossary.Glossary(REPO)
    gloss = {gid: e["uk"] for gid, e in g.entries.items()}
    mods = [m if m.startswith("UADD_") else "UADD_" + m for m in a.module or MODULES]
    rows, notes = installed_rows(mods) if a.source == "installed" else ({}, [])
    pairs, stats = [], []
    for mod in mods:
        src = rows.get(mod)
        if src is None:
            src = review_rows(mod, gloss)
            if not src:
                continue
        terms, alias = parse_data(sorted((REPO / mod).rglob("*.lua")), gloss)
        got = pair(mod, src, terms, alias)
        stats.append(f"{mod[5:]} {len(got)}/{len(src)}")
        pairs += got
    print("paired (texts with our Ukrainian / texts read): " + ", ".join(stats))
    for n in notes:
        print("note: " + n)
    k1, _, _ = report(pairs, list(g.entries.values()), a.top, a.english, ui=a.ui)
    return 1 if a.strict and strict_cases(k1) else 0


if __name__ == "__main__":
    sys.exit(main())
