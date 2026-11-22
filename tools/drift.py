"""Which translated addons changed since our data was built, and which of their texts are new, gone or changed.

python3 tools/drift.py                     "no drift" (exit 0), or per module the version old -> new and the
                                           counts (exit 1); the texts are in local/drift/<module>.txt
python3 tools/drift.py --update-versions   after a resync: record today's addons in tools/addon_versions.json
                                           (refused, exit 2, when a module's texts were not all read; a
                                           module with new texts our data does not name is left out, exit 1,
                                           unless named with --module)
python3 tools/drift.py --json              the same as machine output (holds the addons' English: never commit it)
Options: --module NAME (more than once), --addons DIR, --versions FILE, --out DIR, --no-cache.

Zero tokens, no network. It runs the extraction the generators and tests use (their own functions), and compares
it with the record in tools/addon_versions.json: per module the addon folder, its TOC Version and Interface,
its .lua/.xml files, how many texts (per tag) and one hash of all their ids. An id is hashes only (djb2 of the
key and of the English), so the file holds no English and is safe to track (the licence rule in CLAUDE.md).
The full ids and their English are kept in git-ignored local/drift/base.json. With it a gone text is shown and
paired with a new one (difflib ratio >= 0.85) as "changed", so the old Ukrainian can be carried over; a keyed
text whose key stays and whose English changes is always "changed". Without it (a fresh clone), "new" is every
text our data does not name (texts kept English on purpose too) and "gone" is a count only; the output says so.
Questie (GPL-3.0) and OpenMap (MIT) allow their English here and our data keys are their English, so for them
the old English also comes from our tracked files (data/questie-keys.json, UADD_OpenMap/ui/locale.lua).
Not installed: a note, exit 0. Only the version changed: a note, exit 0. New .lua/.xml files: drift, since
text built in code there may be missed. Texts not all read (an extractor failed, or found none where the record
has some): a note, exit 1. Extraction is cached in tools/.cache/drift.json by the stats of what it reads.
"""
import argparse
import collections
import contextlib
import difflib
import hashlib
import json
import re
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import copy_scan as C  # noqa: E402
import hashtext as H  # noqa: E402
from drift_sources import BLIND, MODULES, scan  # noqa: E402
from drift_ours import named, our_lines, our_terms  # noqa: E402

REPO = HERE.parent
VERSIONS = HERE / "addon_versions.json"
OUT = REPO / "local" / "drift"
CACHE = HERE / ".cache" / "drift.json"
RATIO = 0.85
NOTE = ("Made by tools/drift.py --update-versions. Hashes only: ids is sha1 of the sorted text ids "
        "(djb2 of each key and English text), no English.")


def ident(tag, key, en):
    """A row's id: tag/djb2(key)=djb2(English) for a keyed text, tag/djb2(English) otherwise."""
    return f"{tag}/{H.djb2(key)}={H.djb2(en)}" if key is not None else f"{tag}/{H.djb2(en)}"


def hid(i):
    return i.split("=")[0]


def digest(ids):
    return hashlib.sha1("\n".join(sorted(ids)).encode()).hexdigest()


def tags(ids):
    return dict(sorted(collections.Counter(i.split("/")[0] for i in ids).items()))


def record(mod, got, cur):
    return {"addon": MODULES[mod][0], "version": got["version"], "interface": got["interface"],
            "files": got["files"], "count": len(cur), "tags": tags(cur), "ids": digest(cur)}


# ── Comparing ───────────────────────────────────────────────────────────────────────────────────────────

def items(rows):
    """{id: [tag, key, en, where]}, one per text (wheres of a repeated text joined)."""
    out = {}
    for tag, key, en, where in rows:
        if tag == "!":
            continue
        i = ident(tag, key, en)
        if i in out:
            out[i][3] = f"{out[i][3]}; {where}"[:300]
        else:
            out[i] = [tag, key, en, where]
    return out


def compare(base_ids, cur, old):
    """(new, gone, changed): new [row], gone [(id, old row or None)], changed [(old row, new row, ratio)]."""
    base = {hid(i): i for i in base_ids}
    now = {hid(i): i for i in cur}
    new = [cur[now[h]] for h in now if h not in base]
    gone = [(base[h], old.get(base[h])) for h in base if h not in now]
    changed = [(old.get(base[h]) or [None, cur[now[h]][1], None, ""], cur[now[h]], None)
               for h in now if h in base and base[h] != now[h]]
    left = []
    for i, o in gone:
        best, ratio = None, RATIO
        for n in (new if o else ()):
            sm = difflib.SequenceMatcher(None, o[2], n[2])
            if n[0] == o[0] and sm.real_quick_ratio() >= ratio and sm.quick_ratio() >= ratio and sm.ratio() >= ratio:
                best, ratio = n, sm.ratio()
        if best:
            new.remove(best)
            changed.append((o, best, round(ratio, 3)))
        else:
            left.append((i, o))
    return new, left, changed


def baseline_english(mod, base):
    """{id: old row} from local/drift/base.json, else (allowed addons only) from our tracked files."""
    old = dict(base.get(mod, {}))
    allowed = MODULES[mod][2]
    if allowed:
        with contextlib.suppress(Exception):
            for en in allowed():
                old.setdefault(ident("L", None, en), ["L", None, en, "our tracked data"])
    return old


def texts_drift(mod, rec, cur, base, lines):
    """(new, gone, changed, gone count, exact): exact is False when base.json does not hold this record."""
    if digest(cur) == rec.get("ids"):
        return [], [], [], 0, True
    mine = base.get(mod)
    if isinstance(mine, dict) and digest(mine) == rec.get("ids"):
        new, gone, changed = compare(list(mine), cur, baseline_english(mod, base))
        return new, gone, changed, len(gone), True
    terms, allowed = our_terms(lines), MODULES[mod][2] is not None
    now = tags(cur)
    gone = sum(max(0, n - now.get(t, 0)) for t, n in (rec.get("tags") or {}).items())
    return [r for r in cur.values() if not named(terms, r, allowed)], [], [], gone, False


# ── Our Ukrainian, for the translator ───────────────────────────────────────────────────────────────────

def our_uk(lines, row, allowed=False):
    """The first line of our data that names the row's key or hash (holds our Ukrainian), or ""."""
    if not row:
        return ""
    tag, key, en, _ = row
    terms = [H.key(en), H.djb2(en)] + ([key, H.key(key), H.djb2(key)] if key else [])
    if allowed:
        terms.append(en)
    pat = re.compile("|".join(r"(?<![\w:])" + re.escape(t) + r"(?![\w:])" for t in terms if t))
    return next((ln[:200] for ln in lines if pat.search(ln)), "")


def esc(s):
    return (s or "").replace("\\", "\\\\").replace("\n", "\\n")


def detail(mod, info, lines, allowed=False):
    out = [f"# {mod}: {info['addon']} {info['old']} -> {info['new']}. Made by tools/drift.py.",
           "# Holds the addon's English: never commit. uk: is the first line of our data naming the old key or hash.", ""]
    if not info["exact"]:
        out += ["# No local/drift/base.json for this record: new = every text our data does not name (texts kept",
                "# English on purpose too); gone is a count only.", ""]
    for r in info["newTexts"]:
        out += [f"== new {r[0]}", "key: " + esc(r[1]), "en: " + esc(r[2]),
                "slots: " + " ".join(m.group(0) for m in H.SLOT.finditer(r[2])), "where: " + r[3], ""]
    for o, n, ratio in info["changedTexts"]:
        out += [f"== changed {n[0]} ratio {ratio or 'same key'}", "key: " + esc(n[1]),
                "old: " + (esc(o[2]) if o[2] is not None else "(old English not kept)"), "en: " + esc(n[2]),
                "slots: " + " ".join(m.group(0) for m in H.SLOT.finditer(n[2])), "where: " + n[3],
                "uk: " + our_uk(lines, o if o[2] is not None else n, allowed), ""]
    for i, o in info["goneTexts"]:
        out += [f"== gone {i}", "en: " + (esc(o[2]) if o else "(English not kept)"), "uk: " + our_uk(lines, o, allowed), ""]
    if not info["exact"] and info["goneCount"]:
        out += [f"== gone: at least {info['goneCount']} text(s), count only (no local/drift/base.json)", ""]
    out += [f"== new file {f}" for f in info["newFiles"]] + [f"== gone file {f}" for f in info["goneFiles"]]
    return "\n".join(out) + "\n"


# ── Main ────────────────────────────────────────────────────────────────────────────────────────────────

def load(path, default):
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return default


def save(path, data, **kw):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, **kw) + "\n", encoding="utf-8")


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0], epilog=BLIND,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--update-versions", action="store_true")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--module", action="append")
    ap.add_argument("--addons", default=None)
    ap.add_argument("--versions", default=str(VERSIONS))
    ap.add_argument("--out", default=str(OUT))
    ap.add_argument("--no-cache", action="store_true")
    a = ap.parse_args(argv)
    wanted = [m if m.startswith("UADD_") else "UADD_" + m for m in a.module or MODULES]
    if not set(wanted) <= set(MODULES):
        ap.error("unknown module: " + ", ".join(sorted(set(wanted) - set(MODULES))))
    addons, out = Path(a.addons or C.addons_dir()), Path(a.out)
    versions = load(a.versions, {"note": NOTE, "modules": {}})
    base = load(out / "base.json", {})
    cache = {} if a.no_cache else load(CACHE, {})
    notes, report, drift, recorded, incomplete, held = [], {}, False, [], [], []
    explicit = set(wanted) if a.module else set()
    with ThreadPoolExecutor(C.THREADS) as pool:
        for mod in wanted:
            folder = addons / MODULES[mod][0]
            if not folder.is_dir():
                notes.append(f"{mod}: {MODULES[mod][0]} not installed: not checked")
                continue
            got = scan(mod, folder, cache, pool)
            cur, rec = items(got["rows"]), versions["modules"].get(mod)
            bad = [r[2] for r in got["rows"] if r[0] == "!"]
            if not cur and rec and rec.get("count"):
                bad.append(f"no texts found (the record has {rec['count']})")
            notes += [f"{mod}: {b}" for b in bad]
            if bad:
                incomplete.append(mod)
            if a.update_versions:
                # A module whose texts changed is recorded only when our data names each new or changed text,
                # or when it is named with --module: a record taken over untranslated texts hides them for good.
                if rec and digest(cur) != rec.get("ids") and mod not in explicit:
                    lines = our_lines(mod)
                    new, _, changed, _, _ = texts_drift(mod, rec, cur, base, lines)
                    terms, allowed = our_terms(lines), MODULES[mod][2] is not None
                    open_ = [r for r in new + [n for _, n, _ in changed] if not named(terms, r, allowed)]
                    if open_:
                        held.append(f"{mod}: {len(open_)} new or changed text(s) our data does not name")
                        continue
                versions["modules"][mod], base[mod] = record(mod, got, cur), cur
                recorded.append(mod)
                continue
            if not rec:
                drift = True
                notes.append(f"{mod}: no record in {a.versions}: run --update-versions")
                continue
            lines = our_lines(mod)
            new, gone, changed, gone_n, exact = texts_drift(mod, rec, cur, base, lines)
            info = {"addon": rec["addon"], "old": rec["version"], "new": got["version"], "newTexts": new,
                    "goneTexts": gone, "goneCount": gone_n, "changedTexts": changed, "exact": exact,
                    "newFiles": sorted(set(got["files"]) - set(rec["files"])),
                    "goneFiles": sorted(set(rec["files"]) - set(got["files"]))}
            target = out / f"{mod}.txt"
            if not exact:
                notes.append(f"{mod}: texts changed, but local/drift/base.json does not hold the record (a fresh "
                             "clone?): new = texts our data does not name, gone = a count only")
            if new or gone_n or changed or info["newFiles"] or not exact:
                drift = True
                report[mod] = info
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text(detail(mod, info, lines, MODULES[mod][2] is not None), encoding="utf-8")
                info["details"] = str(target)
                continue
            target.unlink(missing_ok=True)
            if info["goneFiles"]:
                notes.append(f"{mod}: files gone, texts the same: {', '.join(info['goneFiles'])}")
            if (got["version"], got["interface"]) != (rec["version"], rec.get("interface")):
                notes.append(f"{mod}: version {rec['version']} -> {got['version']}, same texts: run --update-versions")
    if not a.no_cache:
        save(CACHE, cache)
    if a.update_versions:
        if incomplete:
            print("\n".join(notes + [f"not recorded: the texts of {', '.join(incomplete)} were not all read. "
                                     "Fix that (lupa, UALLF, the extractor) and run again."]))
            return 2
        versions["note"] = NOTE
        versions["modules"] = {k: versions["modules"][k] for k in sorted(versions["modules"])}
        save(a.versions, versions, indent=1)
        save(out / "base.json", base)
        print("\n".join(notes + [f"recorded {len(recorded)} module(s) in {a.versions}"]))
        if held:
            print("\n".join(["not recorded (their drift stays shown):"] + held + [
                "Translate them first, or, when the rest stays English on purpose, name each with --module."]))
            return 1
        return 0
    drift = drift or bool(incomplete)
    if a.json:
        print(json.dumps({"drift": drift, "incomplete": incomplete, "notes": notes, "modules": report,
                          "cannotSee": BLIND.splitlines()[1:]}, ensure_ascii=False, indent=1))
        return 1 if drift else 0
    for mod, i in report.items():
        files = f"; {len(i['newFiles'])} new code file(s)" if i["newFiles"] else ""
        gone = f"{i['goneCount']} gone" + ("" if i["exact"] else " (at least; count only)")
        print(f"{mod}: {i['addon']} {i['old']} -> {i['new']}: {len(i['newTexts'])} new, {gone}, "
              f"{len(i['changedTexts'])} changed{files} -> {i['details']}")
    print("\n".join(notes + ([] if drift else ["no drift"]) + ["", BLIND]))
    return 1 if drift else 0


if __name__ == "__main__":
    sys.exit(main())
