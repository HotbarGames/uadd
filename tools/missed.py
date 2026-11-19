"""Lists the texts the modules showed in English because we have no Ukrainian for them yet.

The recorder is off by default. Turn it on in the game with /uadd missed on; then UADD notes each such text
once (UADD/Missed.lua) in its SavedVariables. After you log out (the game writes the file then), run:
    python3 tools/missed.py
It reads WTF/Account/*/SavedVariables/UADD.lua under the WoW _forever_ folder ($UADD_WTF_DIR: another WTF
folder; or give the UADD.lua path as an argument), prints per module the missed texts (most shown first)
and writes all of them to local/missed/<module>.txt (git-ignored: it holds the addons' English).
Exit code: 1 when it lists missed texts, 0 with "nothing missed." when there are none, 2 when no file
could be read.
  * Kept quiet here: a module's STAY texts (English on purpose), for every module in STAY_LISTS. A STAY
    template ("%s ...") also hides its filled lines; the English of a STAY hash is read from the installed
    addon at run time (never written to a tracked file). Without the addon only exact texts are dropped.
  * "maybe names": texts the game noted as a name (1 to 5 capitalised words). A UI label can land here too.
  * "older version": noted while an older version of the addon was installed; it may be gone now.
  * In a text, <link> is an item or player link and "<name>" a quoted name; %s a slot that held a name.
Account folders are never printed: they show as "account 1", "account 2". Standard library only.
"""
import glob
import math
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
OUT = os.path.join(REPO, "local", "missed")
DEFAULT_WTF = ["/mnt/c/Program Files (x86)/World of Warcraft/_forever_/WTF",
               "C:/Program Files (x86)/World of Warcraft/_forever_/WTF"]
SHOW = 15            # texts per module on screen; the file has all
NAME = re.compile(r"^[A-Z][\w'-]*( (of|the|de|[A-Z][\w'-]*)){0,2}$")
sys.path.insert(0, HERE)
import hashtext  # noqa: E402
from svread import parse  # noqa: E402,F401  (tests and callers use missed.parse)


# ── Finding and reading the files ──────────────────────────────────────────────────────────────

def find_files(argv):
    """[(label, path)]: the UADD.lua files to read, labelled "account N" (never the folder name)."""
    if argv:
        return [("file %d" % (i + 1), p) for i, p in enumerate(argv)]
    roots = [os.environ["UADD_WTF_DIR"]] if os.environ.get("UADD_WTF_DIR") else DEFAULT_WTF
    for root in roots:
        files = sorted(glob.glob(os.path.join(root, "Account", "*", "SavedVariables", "UADD.lua")))
        if files:
            return [("account %d" % (i + 1), p) for i, p in enumerate(files)]
    return []


def collect(files, problems=None):
    """{module: {"v", "dropped", "namesDropped", "texts": {text: {"n", "d", "v"}}, "names": {same}}}, all
    files merged. A file that cannot be read is skipped; its label and the error's kind (never its path or
    message: the account folder is private) go to `problems`."""
    mods = {}
    for label, path in files:
        try:
            with open(path, "rb") as f:
                collect_db(parse(f.read()), mods)
        except Exception as e:      # noqa: BLE001 - any broken file: say so, read the others
            if problems is not None:
                problems.append("%s: cannot read (%s)" % (label, type(e).__name__))
    return mods


def _count(v):
    """A count from someone else's data: a finite whole number >= 0, else 0."""
    if isinstance(v, bool) or not isinstance(v, (int, float)) or not math.isfinite(v) or v < 0:
        return 0
    return int(v)


def _str(v):
    return v if isinstance(v, str) else None if v is None or isinstance(v, (dict, list)) else str(v)


def collect_db(saved, mods=None):
    """Adds the entries of one parsed file ({global: value}) to mods; returns mods."""
    mods = {} if mods is None else mods
    db = saved.get("UADD_DB") if isinstance(saved, dict) else None
    missed = db.get("missed") if isinstance(db, dict) else None
    all_mods = missed.get("mods") if isinstance(missed, dict) else None
    for key, m in (all_mods.items() if isinstance(all_mods, dict) else ()):
        if not isinstance(m, dict):
            continue
        mod = mods.setdefault(str(key), {"v": None, "dropped": 0, "namesDropped": 0, "texts": {}, "names": {}})
        mod["v"] = _str(m.get("v")) or mod["v"]
        mod["dropped"] += _count(m.get("dropped"))
        mod["namesDropped"] += _count(m.get("namesDropped"))
        for bucket in ("texts", "names"):
            entries = m.get(bucket)
            for e in (entries.values() if isinstance(entries, dict) else ()):
                if not isinstance(e, dict) or not isinstance(e.get("t"), str):
                    continue
                had, n, d = mod[bucket].get(e["t"]), _count(e.get("n")), _str(e.get("d")) or "?"
                if had:
                    had["n"] += n
                    had["d"] = min(had["d"], d)
                else:
                    mod[bucket][e["t"]] = {"n": n, "d": d, "v": _str(e.get("v"))}
    return mods


# ── STAY: English on purpose, for every module ──────────────────────────────────────────────────

def _attr(module, name, default=()):
    try:
        return getattr(__import__(module), name, default)
    except Exception:      # noqa: BLE001 - a missing tool: nothing from it
        return default


def _att_never(path):
    import make_att_text as A
    en = A.enus(path)[0]
    return {en[k] for k in _attr("make_att_text", "NEVER") if isinstance(en.get(k), str)}


# module key: (addon folder, hash keys, English texts, function(addon path) -> more English texts)
STAY_LISTS = {
    "attune": ("Attune", lambda: (), lambda: (), _att_never),
    "auctionator": ("Auctionator", lambda: (), lambda: (), None),
    "autopotion": ("AutoPotion", lambda: (), lambda: (), None),       # Keep (Module.lua) keeps them quiet in Lua
    "bagnon": ("BagBrother", lambda: (), lambda: (), None),           # Keep (Module.lua) keeps them quiet in Lua
    "dialogueui": ("DialogueUI", lambda: (), lambda: (), None),        # ns.NotOurs keeps them quiet in Lua
    "fxpb": ("ForeverXPbar", lambda: _attr("test_fxpb_strings", "STAY"), lambda: _attr("fxpb_rules", "STAY_ENGLISH"),
             None),
    "layerswap": ("LayerSwap", lambda: _attr("test_lsw_strings", "STAY"), lambda: _attr("lsw_rules", "STAY_ENGLISH"),
                  None),
    "mastercraft": ("Mastercraft", lambda: (), lambda: (), None),     # Keep (Module.lua) keeps them quiet in Lua
    "whatstraining": ("WhatsTraining", lambda: (), lambda: (), None),   # Keep (Module.lua) keeps them quiet in Lua
    "tomtom": ("TomTom", lambda: (), lambda: (), None),   # Keep (Module.lua) keeps them quiet in Lua
    "rarescanner": ("RareScanner", lambda: (), lambda: (), None),   # Keep (Module.lua) keeps them quiet in Lua
    "openmap": ("OpenMap", lambda: (), lambda: set(_attr("test_openmap_strings", "SKIP_NAMES"))
                | set(_attr("test_openmap_strings", "SKIP_OTHER")), None),
}
SLOT_RE = {"d": r"-?\d[\d,.]*", "f": r"-?\d[\d,.]*", "x": r"[0-9a-fA-F]+", "x2": r"[0-9a-fA-F]{2}"}


def matcher(en):
    """A regex that a recorded text of the English template `en` matches in full (the raw line, its plain
    form, or the recorder's form with %s in a slot); None for a plain text or one with under 3 letters."""
    toks = hashtext.tokens(en)
    if not any(t[0] == "slot" for t in toks) or len(re.findall(r"[A-Za-z]", "".join(
            t[1] for t in toks if t[0] == "lit"))) < 3:
        return None
    parts = [re.escape(t[1]) if t[0] == "lit" else "(?:%%s|%s)" % SLOT_RE.get(t[1], ".*?") for t in toks]
    return re.compile("".join(parts), re.S)


def _addon_strings(folder):
    """Every Lua string in the installed addon's .lua files, or None when it is not installed."""
    import copy_scan as C
    import luatok
    root = os.path.join(C.addons_dir(), folder)
    if not os.path.isdir(root):
        return None
    found = set()
    for path in glob.glob(os.path.join(root, "**", "*.lua"), recursive=True):
        try:
            found.update(v for k, v, _ in luatok.tokens(luatok.read(path)) if k == luatok.STR)
        except OSError:
            pass
    return found


def stay_sets():
    """{module key: {"keys", "texts", "templates": [regex], "note": str or None}}."""
    out = {}
    for key, (folder, keys, texts, more) in STAY_LISTS.items():
        keys, texts, note = set(keys()), set(texts()), None
        if keys or more:
            import copy_scan as C
            path = os.path.join(C.addons_dir(), folder)
            strings = _addon_strings(folder) if keys else set()
            if strings is None or not os.path.isdir(path):
                note = "%s not installed: only exact STAY texts dropped" % folder
            else:
                texts |= {s for s in strings if hashtext.key(s) in keys}
                if more:
                    try:
                        texts |= set(more(path))
                    except Exception as e:      # noqa: BLE001
                        note = "STAY of %s not read (%s)" % (folder, type(e).__name__)
        templates = [m for m in map(matcher, sorted(texts)) if m]
        out[key] = {"keys": keys, "texts": texts, "templates": templates, "note": note}
    return out


def plain(t):
    return re.sub(r"\|c[0-9a-fA-F]{8}|\|r|\|T.*?\|t", "", t).strip()


def is_stay(t, s):
    if not s:
        return False
    if hashtext.key(t) in s["keys"] or t in s["texts"] or plain(t) in s["texts"]:
        return True
    return any(m.fullmatch(t) or m.fullmatch(plain(t)) for m in s["templates"])


def sort_out(key, mod, stay):
    """(texts, names, older, stayed): lists of (text, entry), most shown first."""
    s = stay.get(key)
    texts, names, older, stayed = [], [], [], 0
    rows = [(t, e, False) for t, e in mod["texts"].items()] + [(t, e, True) for t, e in mod.get("names", {}).items()]
    for t, e, name in sorted(rows, key=lambda x: (-x[1]["n"], x[0])):
        if is_stay(t, s):
            stayed += 1
        elif mod["v"] and e["v"] and e["v"] != mod["v"]:
            older.append((t, e))
        elif name or NAME.match(plain(t)):
            names.append((t, e))
        else:
            texts.append((t, e))
    return texts, names, older, stayed


def line(t, e):
    return "%5d x  %s  (%s%s)" % (e["n"], t.replace("\n", "\\n"), e["d"], ", version " + str(e["v"]) if e["v"] else "")


def report(mods, stay, out_dir, show=SHOW):
    """Prints the summary and writes out_dir/<module>.txt. Returns the number of texts listed."""
    total = 0
    os.makedirs(out_dir, exist_ok=True)
    for old in glob.glob(os.path.join(out_dir, "*.txt")):
        os.remove(old)
    for key in sorted(mods):
        mod = mods[key]
        texts, names, older, stayed = sort_out(key, mod, stay)
        n = len(texts) + len(names) + len(older)
        if n == 0:
            continue
        total += n
        head = "%s: %d missed" % (key, n) + (" (addon version %s)" % mod["v"] if mod["v"] else "")
        over = mod["dropped"] + mod.get("namesDropped", 0)
        extra = [x for x in ("%d maybe names" % len(names) if names else "",
                             "%d from an older version" % len(older) if older else "",
                             "%d over the limit, not kept" % over if over else "",
                             "%d STAY not shown" % stayed if stayed else "",
                             (stay.get(key) or {}).get("note") or "") if x]
        print(head + ("; " + ", ".join(extra) if extra else ""))
        for t, e in texts[:show]:
            print("  " + line(t, e))
        if len(texts) > show:
            print("  ... %d more" % (len(texts) - show))
        path = os.path.join(out_dir, key + ".txt")
        with open(path, "w", encoding="utf-8") as f:
            for title, group in (("missed", texts), ("maybe names", names), ("from an older version", older)):
                if group:
                    f.write("# %s (%d)\n" % (title, len(group)))
                    f.writelines(line(t, e) + "\n" for t, e in group)
        print("  all: " + os.path.relpath(path, REPO))
    return total


def main(argv):
    files = find_files(argv)
    if not files:
        print("No UADD.lua found under WTF/Account/*/SavedVariables. Log out of the game first, "
              "or set UADD_WTF_DIR to the WTF folder.")
        return 2
    print("Read: " + ", ".join(label for label, _ in files))
    problems = []
    mods = collect(files, problems)
    for p in problems:
        print(p)
    if len(problems) == len(files):
        return 2
    if report(mods, stay_sets(), OUT) == 0:
        print("nothing missed.")
        return 0
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
