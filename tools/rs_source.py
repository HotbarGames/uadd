"""Reads the installed RareScanner for tools/make_rs_text.py: its English (Locales/RareScanner-enUS.lua), where
its code names each key, and the ids in its Tables. Which keys are kept: tools/rs_rules.py.
Nothing here names RareScanner's English (it is all rights reserved)."""
import os
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import luatok  # noqa: E402
import rs_rules as R  # noqa: E402

ADDON_DIRS = ["/mnt/c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns",
              "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns"]
LOCALE = "Locales/RareScanner-enUS.lua"
SKIP_DIRS = ("Locales/", "ExternalLibs/", "Media/")
XML_STR = re.compile(r'"([A-Z][A-Z0-9_]+)"')


def addon_dir(arg=None):
    if arg:
        return Path(arg)
    base = os.environ.get("UADD_ADDONS_DIR") or next((d for d in ADDON_DIRS if os.path.isdir(d)), ADDON_DIRS[0])
    return Path(base) / "RareScanner"


def version(addon):
    toc = Path(addon) / "RareScanner.toc"
    m = re.search(r"^## Version:\s*(\S+)", toc.read_text(encoding="utf-8-sig", errors="replace"), re.M) \
        if toc.is_file() else None
    return m.group(1) if m else "?"


def read_locale(path):
    """{key: English} of `AL["KEY"] = "..." (.. "...")` in file order."""
    t = list(luatok.tokens(luatok.read(path)))
    out = {}
    for i in range(len(t) - 5):
        if t[i][:2] == (luatok.NAME, "AL") and t[i + 1][:2] == (luatok.SYM, "[") and t[i + 2][0] == luatok.STR \
                and t[i + 3][:2] == (luatok.SYM, "]") and t[i + 4][:2] == (luatok.SYM, "=") \
                and t[i + 5][0] == luatok.STR:
            val, j = t[i + 5][1], i + 6
            while j + 1 < len(t) and t[j][:2] == (luatok.SYM, "..") and t[j + 1][0] == luatok.STR:
                val, j = val + t[j + 1][1], j + 2
            out[t[i + 2][1]] = val
    return out


def code_files(addon):
    addon = Path(addon)
    for p in sorted(addon.rglob("*")):
        rel = p.relative_to(addon).as_posix()
        if p.suffix in (".lua", ".xml") and not rel.startswith(SKIP_DIRS):
            yield rel, p


def code_uses(addon, keys):
    """{key: [(file, line)]} of every string in the code (comments skipped) that is a locale key; and
    {(file, line): [keys named on that line]} for the t-slot notes."""
    uses, lines = {}, {}
    for rel, p in code_files(addon):
        if p.suffix == ".lua":
            found = [(v, ln) for kind, v, ln in luatok.tokens(luatok.read(p)) if kind == luatok.STR]
        else:
            text = p.read_text(encoding="utf-8", errors="replace")
            found = [(m.group(1), text.count("\n", 0, m.start()) + 1) for m in XML_STR.finditer(text)]
        for v, ln in found:
            if v in keys:
                uses.setdefault(v, []).append((rel, ln))
                lines.setdefault((rel, ln), []).append(v)
    return uses, lines


def table_ids(addon):
    """{"entity": ids, "event": ids, "map": ids} from RareScanner's Tables (stage 1 map A)."""
    def read(name):
        p = Path(addon) / "Tables" / name
        return p.read_text(encoding="utf-8", errors="replace") if p.is_file() else ""

    def nums(rx, text):
        return {int(x) for x in re.findall(r"\d+", " ".join(re.findall(rx, text)))}
    top = re.compile(r"^\t\[(\d+)\] = \{", re.M)
    cont = {int(x) for x in top.findall(read("ContainerInfoTables.lua"))}
    npc = {int(x) for x in top.findall(read("NpcInfoTables.lua"))}
    ev = {int(x) for x in top.findall(read("EventInfoTables.lua"))}
    ment = nums(r"\[\d\] = \{([\d,]+)\}", read("MapEntitiesTables.lua"))
    zones = nums(r"zones = \{([\d,]+)\}", read("ZoneTables.lua"))
    return {"entity": cont | npc | ment | ev, "event": ev, "map": zones}


def reachable(key, ids):
    for rx, need in R.DYNAMIC:
        m = rx.match(key)
        if m:
            a = int(m.group(1))
            if need == "entity":
                return a in ids["entity"]
            if need == "entity+map":
                return a in ids["entity"] and int(m.group(2)) in ids["map"]
            return a in ids[need]
    return False


def source(addon):
    """([row], {why left out: count}); row = (key, English, batch, [(file, line)], note), in batch order."""
    path = Path(addon) / LOCALE
    if not path.is_file():
        return [], {}
    loc = read_locale(path)
    uses, lines = code_uses(addon, set(loc))
    ids = table_ids(addon)
    rows, why = [], {}

    def drop(reason):
        why[reason] = why.get(reason, 0) + 1
    for key, en in loc.items():
        where = uses.get(key, [])
        live = [w for w in where if w[0] not in R.DEAD_FILES]
        if key in R.STAY:
            drop("stay")
        elif key in R.GAME or re.match(r"^CONTAINER_\d", key):
            drop("game name")
        elif not en.strip():
            drop("empty")
        elif R.ID_KEY.match(key) and not live:
            if reachable(key, ids):
                rows.append((key, en, 8, [], "read by a built key (dynamic); id in RareScanner's Tables; "
                                             "names in [ ] are game names: UALL Forever's, else leave the UA empty"))
            else:
                drop("id not in Tables")
        elif not where:
            drop("not named in code")
        elif not live:
            drop("only in dead files")
        else:
            batch = min(R.batch_of(f) for f, _ in live)
            live.sort(key=lambda w: (R.batch_of(w[0]) != batch, w))
            rows.append((key, en, batch, live, note(key, live, lines)))
    rows.sort(key=lambda r: (r[2], r[3][0] if r[3] else ("~", 0)))
    return rows, why


def calls(text, head):
    """[(line, args text)] of each call whose head (a regex that ends at its "(") is in `text`; the args may
    span lines (balanced brackets, strings skipped)."""
    out = []
    for m in re.finditer(head, text):
        i, depth, quote = m.end(), 1, None
        while i < len(text) and depth:
            c = text[i]
            if quote:
                if c == "\\":
                    i += 1
                elif c == quote:
                    quote = None
            elif c in "\"'":
                quote = c
            elif c in "([{":
                depth += 1
            elif c in ")]}":
                depth -= 1
            i += 1
        out.append((text.count("\n", 0, m.start()) + 1, text[m.end():i - 1]))
    return out


def split_args(args):
    """The top-level arguments of a call's args text."""
    out, depth, cur, quote = [], 0, "", None
    for c in args:
        if quote:
            quote = None if c == quote and not cur.endswith("\\") else quote
        elif c in "\"'":
            quote = c
        elif c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
        elif c == "," and depth == 0:
            out, cur = out + [cur.strip()], ""
            continue
        cur += c
    return out + [cur.strip()] if cur.strip() else out


def duration_keys(addon):
    """{key: [slot index]} of each string.format(AL["KEY"], ...) whose slot gets a time span in RareScanner's own
    English units: RSTimeUtils.FormatShortDuration, a function that returns it, or a local set from either."""
    out = {}
    for _, p in code_files(addon):
        if p.suffix != ".lua":
            continue
        text = p.read_text(encoding="utf-8", errors="replace")
        if "FormatShortDuration" not in text:
            continue
        names = {"FormatShortDuration"}
        for m in re.finditer(r"(?ms)^(?:local )?function ([\w.:]+)\(.*?^end", text):
            if "FormatShortDuration" in m.group(0):
                names.add(re.split(r"[.:]", m.group(1))[-1])
        fn = re.compile(r"\b(?:%s)\(" % "|".join(sorted(names)))
        held = {m.group(1) for m in re.finditer(r"\blocal (\w+) = ([^\n]*)", text) if fn.search(m.group(2))}
        var = re.compile(r"\b(?:%s)\b" % "|".join(sorted(held))) if held else None
        for _, args in calls(text, r"\bstring\.format\("):
            parts = split_args(args)
            key = re.fullmatch(r'AL\["([A-Z0-9_]+)"\]', parts[0]) if parts else None
            if key:
                slots = [i for i, a in enumerate(parts[1:]) if fn.search(a) or (var and var.search(a))]
                if slots:
                    out.setdefault(key.group(1), set()).update(slots)
    return {k: sorted(v) for k, v in out.items()}


def note(key, live, lines):
    area = next(a for n, a, _ in R.BATCHES if n == R.batch_of(live[0][0]))
    bits = [f"where: {area}: " + ", ".join(f"{f}:{ln}" for f, ln in live[:3]) + (" ..." if len(live) > 3 else "")]
    if "t" in R.SORTS.get(key, ""):
        inner = [k for k in lines.get(live[0], []) if k != key]
        bits.append("t: " + (", ".join(inner) if inner else "see the code line"))
    if key in R.RISKY:
        bits.append("risky name slot: " + R.RISKY[key])
    return "; ".join(bits)
