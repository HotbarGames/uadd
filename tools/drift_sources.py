"""The extraction tools/drift.py runs per module: the generators' and tests' own functions, given the installed
addon's folder. Each gives rows of (tag, key or None, English, where); tag "!" is a note: the texts were not all
read (a failed extractor gives one too), so that run is not cached and --update-versions refuses it.
MODULES: per UADD_* module its addon folder, extractor, tracked English (only for licence-allowed addons, whose
English our data already keys by) and extra folders of our Ukrainian.
Also here: scan() with its cache stamp, and the words our data names (for a record base.json does not hold).
"""
import contextlib
import hashlib
import importlib.util
import io
import json
import re
import sys
from pathlib import Path
from unittest import mock

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import copy_scan as C  # noqa: E402

REPO = HERE.parent
UALLF_FILES = ("NpcNames.lua", "Items.lua", "World.lua", "Quests.lua")   # what the DJ prose reads of UALLF
BLIND = """What drift.py cannot see:
  * DialogueUI, OpenMap, Questie: only their locale tables are compared; English built in their code is not.
  * Code files are compared by name only: a new or gone .lua/.xml file shows, a changed one shows only through
    the texts an extractor reads from it.
  * Attune: a code string shows only when copy_scan's filter calls it a sentence or a label.
  * ForeverDungeonJournal prose needs lupa and UALLF; without them it is not read (a note, exit 1)."""


def _hashed(gen):
    def run(path):
        kept, _ = gen.collect(path)
        return [("X", None, en, f"{area} {kind} {' '.join(where)}")
                for area, rows in kept.items() for kind, en, where in rows]
    return run


def ex_fxpb(path):
    import make_fxpb_data
    return _hashed(make_fxpb_data)(path)


def ex_lsw(path):
    import make_lsw_data
    return _hashed(make_lsw_data)(path)


def ex_ap(path):
    import make_ap_text as P
    return [("X", None, en, f"{kind} {where}") for _, kind, en, where in P.texts(path)]


def ex_dui(path):
    import make_dui_data as D
    enus, _ = D.read_enus(path / "Locales" / "enUS.lua")
    return [("L", lit, en, "Locales/enUS.lua") for lit, (_, en) in enus.items()]


def ex_att(path):
    import make_att_text as A
    rows = [("L", k, en, "Locales/enUS.lua") for k, en in A.enus(path)[0].items()]
    return rows + [("C", None, s, "code") for s in sorted(A.code_strings(path)) if C.meaningful(s) or C.label(s)]


def ex_auc(path):
    import make_auc_text as U
    rows = [("L", k, en, "Locales/enUS.lua") for k, (en, _) in U.read_enus(path)[0].items()]
    return rows + [("C", None, en, rel) for rel, en in U.all_code_texts(path)]


def ex_dj(path):
    import test_dj_strings as DJ
    with mock.patch.object(DJ, "FDJ_LOCALE", path / "Localization" / "Localization.lua"):
        rows = [("L", k, en, "Localization.lua") for k, en in DJ.english().items()]
        rows += [("S", k, en, "enUS table") for k, en in DJ.side_english().items()]
    try:
        import dj_prose_fdj as P
        import dj_prose_names as N
        with mock.patch.object(P, "FDJ_DIR", path), mock.patch.object(N, "UALLF_DIR", path.parent / "UALLF"), \
                contextlib.redirect_stderr(io.StringIO()):
            prose, _ = P.collect(P.load_fdj(), N.Names())
    except Exception as e:  # lupa or UALLF missing: the strings are still checked
        return rows + [("!", None, f"prose not checked: {type(e).__name__}: {e}", "")]
    return rows + [("P", None, en, where) for _, kind, where, en, shown in prose if shown]


def ex_openmap(path):
    import test_openmap_strings as OM
    with mock.patch.object(OM, "OPENMAP", path):
        return [("L", None, k, "L[...]") for k in sorted(OM.openmap_keys())]


def ex_questie(path):
    import extract_questie_keys as Q
    return [("L", None, en, rel) for en, rel in Q.extract(path)["keys"].items()]


def old_questie():
    return json.loads((REPO / "data" / "questie-keys.json").read_text(encoding="utf-8"))["keys"]


def old_openmap():
    import test_openmap_strings as OM
    return [k for rows in OM.ours().values() for k, *_ in rows]


# module: (addon folder, extractor, tracked English of an allowed addon or None, our extra data files)
MODULES = {
    "UADD_Attune": ("Attune", ex_att, None, ()),
    "UADD_Auctionator": ("Auctionator", ex_auc, None, ()),
    "UADD_AutoPotion": ("AutoPotion", ex_ap, None, ()),
    "UADD_DialogueUI": ("DialogueUI", ex_dui, None, ()),
    "UADD_DungeonJournal": ("ForeverDungeonJournal", ex_dj, None, ("tools/dj_prose",)),
    "UADD_ForeverXPBar": ("ForeverXPbar", ex_fxpb, None, ()),
    "UADD_LayerSwap": ("LayerSwap", ex_lsw, None, ()),
    "UADD_OpenMap": ("OpenMap", ex_openmap, old_openmap, ()),
    "UADD_Questie": ("Questie", ex_questie, old_questie, ()),
}


# ── The installed addon, and the cache stamp ────────────────────────────────────────────────────────────

def toc(folder):
    """(Version, Interface) from the TOC named as the folder, else from the first TOC with a Version."""
    tocs = sorted(folder.glob("*.toc"))
    for t in [t for t in tocs if t.stem.lower() == folder.name.lower()] + tocs:
        s = t.read_text(encoding="utf-8-sig", errors="replace")
        v = re.search(r"^## Version:\s*(.*?)\s*$", s, re.M)
        if v:
            i = re.search(r"^## Interface:\s*(.*?)\s*$", s, re.M)
            return v.group(1), i.group(1) if i else None
    return None, None


def code_files(folder, files):
    return sorted(Path(f).relative_to(folder).as_posix() for f in files
                  if f.lower().endswith((".lua", ".xml")) and not C.OTHER_LOCALE.search(f))


def lupa_state():
    if importlib.util.find_spec("lupa") is None:
        return "no lupa"
    try:
        from importlib.metadata import version
        return "lupa " + version("lupa")
    except Exception:  # noqa: BLE001 - installed without metadata
        return "lupa"


def tools_stamp(mod, addons):
    """What else the extraction reads: our tools, our module's data and data/*.json, lupa (there or not, its
    version), and for DungeonJournal the UALLF files its prose uses. Each file by path, size and time."""
    paths = list(HERE.glob("*.py")) + list((REPO / "data").glob("*.json"))
    for d in (mod, *MODULES[mod][3]):
        paths += [p for p in (REPO / d).rglob("*") if p.is_file()]
    if mod == "UADD_DungeonJournal":
        paths += [Path(addons) / "UALLF" / f for f in UALLF_FILES]
    h = hashlib.sha1(lupa_state().encode())
    for p in sorted(paths):
        try:
            st = p.stat()
            h.update(f"{p}\0{st.st_size}\0{st.st_mtime_ns}\n".encode())
        except OSError:
            h.update(f"{p}\0-\n".encode())
    return h.hexdigest()


def scan(mod, folder, cache, pool):
    """{version, interface, files, rows} of one installed addon, from the cache when nothing changed. An
    extractor that fails gives a "!" row; a run with a "!" row is not cached."""
    files = C.addon_files(str(folder), pool)
    stamp = C.stamp(str(folder), pool, files) + tools_stamp(mod, folder.parent)
    hit = cache.get(mod)
    if hit and hit.get("stamp") == stamp:
        return hit
    version, interface = toc(folder)
    try:
        rows = [list(r) for r in MODULES[mod][1](folder)]
    except Exception as e:  # noqa: BLE001 - shown as a note; --update-versions refuses
        rows = [["!", None, f"texts not read: {type(e).__name__}: {e}", ""]]
    got = {"stamp": stamp, "version": version, "interface": interface, "files": code_files(folder, files),
           "rows": rows}
    if any(r[0] == "!" for r in rows):
        cache.pop(mod, None)
    else:
        cache[mod] = got
    return got


# ── Our data ────────────────────────────────────────────────────────────────────────────────────────────

def our_lines(mod):
    paths = sorted((REPO / mod).rglob("*.lua"))
    for extra in MODULES[mod][3]:
        paths += sorted((REPO / extra).glob("uk_*.lua"))
    return [ln.strip() for p in paths for ln in p.read_text(encoding="utf-8", errors="replace").splitlines()]


def our_terms(lines):
    """Every quoted string, word and hash in our data: what names a text (its key, its English hash)."""
    text = "\n".join(lines)
    return (set(re.findall(r'"((?:[^"\\]|\\.)*)"', text)) | set(re.findall(r"[A-Za-z_]\w*", text))
            | set(re.findall(r"\d+:[0-9a-f]{8}|(?<![0-9a-f])[0-9a-f]{8}(?![0-9a-f])", text)))


def named(terms, row, allowed=False):
    """True when our data names the row: by its key, the hash of its English, or (allowed addons) its English."""
    import hashtext as H
    tag, key, en, _ = row
    found = {H.key(en), H.djb2(en)} | ({key, H.key(key), H.djb2(key)} if key else set()) | ({en} if allowed else set())
    return bool(found & terms)
