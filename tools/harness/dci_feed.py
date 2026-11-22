#!/usr/bin/env python3
"""The run-time feed of the DeleteCheapestItem stand-in (tools/harness/deletecheapestitem).

The addon is all rights reserved, so its English never sits in this repo. feed() reads it from the
installed addon each run and returns Lua code that sets the global DCIStandInFeed:
  fn   = { <function name> = { the distinct L reads of that function, in source order } }
  page = the settings page: one entry per CreateConfigPanel* call, in order
  choices = the dropdown choice tables, by their local name
  title, version, slash (the literal strings of the slash command handler)
Counts are checked against COUNTS, so an addon update that moves texts fails loudly here.
`python3 tools/harness/dci_feed.py --roles` prints counts and line numbers only, never the English.
"""
import os
import re
import sys

ADDON = "DeleteCheapestItem"
ADDON_DIRS = [os.environ.get("UADD_ADDONS_DIR", ""),
              "/mnt/c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns",
              "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns"]
MAIN = ADDON + ".lua"
# (file, function) -> how many distinct L reads it has (v1.9.1). The stand-in names them by position.
COUNTS = {
    (MAIN, "SaveIgnoredItem"): 1, (MAIN, "ResetIgnoredItem"): 1, (MAIN, "ConfirmAndDeleteBagItem"): 1,
    (MAIN, "RefreshIgnoredItems"): 3, (MAIN, "ShowIgnoredItems"): 2, (MAIN, "CreateDCIFrame"): 15,
    (MAIN, "UpdateDCIFrame"): 21, ("ProfileUI.lua", "CreateProfileControls"): 10,
    ("Profiles.lua", "ConfirmProfileAction"): 4, ("Broker.lua", "InitializeBroker"): 3,
}
LREAD = re.compile(r"""\bL\[\s*(?:"((?:[^"\\]|\\.)*)"|'((?:[^'\\]|\\.)*)')\s*\]""")
STR = re.compile(r""""((?:[^"\\]|\\.)*)"|'((?:[^'\\]|\\.)*)'""")
CALL = re.compile(r"^\s*(?:local\s+(\w+)\s*=\s*)?CreateConfigPanel(Button|Section|Checkbox|Dropdown)\((.*)$")
ARITH = re.compile(r"^[\d+\-* ()]+$")


def folder():
    for base in ADDON_DIRS:
        if base and os.path.isfile(os.path.join(base, ADDON, MAIN)):
            return os.path.join(base, ADDON)
    raise SystemExit(f"dci_feed: {ADDON} is not installed in any of {[d for d in ADDON_DIRS if d]}")


def unesc(s):
    return re.sub(r"\\(.)", lambda m: {"n": "\n", "t": "\t"}.get(m.group(1), m.group(1)), s)


def lines_of(path):
    with open(path, encoding="utf-8", errors="replace") as f:
        return f.read().split("\n")


def body(lines, name):
    """(first line number, lines) of the function `name`, up to its `end` at the same indent."""
    head = re.compile(r"^(\s*)(?:local\s+)?function\s+(?:[\w.:]*[.:])?" + re.escape(name) + r"\s*\(")
    for i, ln in enumerate(lines):
        m = head.match(ln)
        if m:
            stop = re.compile("^" + m.group(1) + r"end\b")
            for j in range(i + 1, len(lines)):
                if stop.match(lines[j]):
                    return i + 1, lines[i:j + 1]
    raise SystemExit(f"dci_feed: function {name} not found")


def reads(lines, start=1):
    """[(line number, English)] of the distinct L reads, first seen first."""
    seen, out = set(), []
    for n, ln in enumerate(lines, start):
        for m in LREAD.finditer(ln):
            s = unesc(m.group(1) if m.group(1) is not None else m.group(2))
            if s not in seen:
                seen.add(s)
                out.append((n, s))
    return out


def args(text):
    """The top-level comma-separated arguments of a call whose text starts after its '('."""
    out, depth, cur, quote, i = [], 0, "", None, 0
    while i < len(text):
        c = text[i]
        if quote:
            cur += c
            if c == "\\" and i + 1 < len(text):
                cur += text[i + 1]
                i += 1
            elif c == quote:
                quote = None
        elif c in "\"'":
            quote, cur = c, cur + c
        elif c in "([{":
            depth, cur = depth + 1, cur + c
        elif c in ")]}":
            if depth == 0:
                break
            depth, cur = depth - 1, cur + c
        elif c == "," and depth == 0:
            out.append(cur.strip())
            cur = ""
        else:
            cur += c
        i += 1
    if cur.strip():
        out.append(cur.strip())
    return out


def value(a):
    """An argument as a feed value: English for L[..], a string, a number, or the raw name."""
    m = LREAD.fullmatch(a.strip())
    if m:
        return unesc(m.group(1) if m.group(1) is not None else m.group(2))
    m = STR.fullmatch(a.strip())
    if m:
        return unesc(m.group(1) if m.group(1) is not None else m.group(2))
    if ARITH.match(a):
        return int(eval(a, {"__builtins__": {}}))  # digits and + - * ( ) only
    return {"name": a.strip()}


def page(lines):
    entries, choices = [], {}
    for ln in lines:
        m = re.match(r"^\s*local\s+(\w+Choices)\s*=\s*\{(.*)\}\s*$", ln)
        if m:
            items = []
            for a in args(m.group(2)):
                parts = [p.strip() for p in a.split("..")]
                if len(parts) == 2 and STR.fullmatch(parts[0]) and re.fullmatch(r"\w+", parts[1]):
                    items.append({"c": value(parts[0]), "g": parts[1]})
                else:
                    items.append({"t": value(a)})
            choices[m.group(1)] = items
        m = CALL.match(ln)
        if m:
            entries.append({"kind": m.group(2), "local": m.group(1) or "", "a": [value(a) for a in args(m.group(3))]})
    return entries, choices


def gather():
    root, fn, info = folder(), {}, {}
    files = {}
    for (fname, name), want in COUNTS.items():
        lines = files.setdefault(fname, lines_of(os.path.join(root, fname)))
        start, part = body(lines, name)
        got = reads(part, start)
        info[name] = (fname, [n for n, _ in got])
        if len(got) != want:
            raise SystemExit(f"dci_feed: {fname} {name} has {len(got)} L reads, the stand-in knows {want}; update COUNTS and Stand.lua roles")
        fn[name] = [s for _, s in got]
    main = files[MAIN]
    start, settings = body(main, "CreateDCISettings")
    entries, choices = page(settings)
    fn["CreateDCISettings"] = [s for _, s in reads(settings, start)]
    fn["ProfileMessages"] = [s for _, s in reads(files["Profiles.lua"]) if s not in fn["ConfirmProfileAction"]]
    _, slash = body(main, "HandleSlashCommand")
    lits = [[unesc(m.group(1) or m.group(2) or "") for m in STR.finditer(ln)] for ln in slash if "DebugPrint(" in ln]
    for ln in settings:  # the grey note on one checkbox: its local name, then its two texts
        m = re.search(r"auctionCheckboxText2\s*=\s*(\w+):CreateFontString", ln)
        for e in entries:
            if m and e["local"] == m.group(1):
                e["aux"] = True
    aux = [x for ln in settings if "auctionCheckboxText2:SetText" in ln for _, x in reads([ln])]
    title = next((unesc(m.group(1)) for ln in main for m in [re.match(r'^\s*DCI\.ADDON_TITLE\s*=\s*"((?:[^"\\]|\\.)*)"', ln)] if m), ADDON)
    toc = lines_of(os.path.join(root, ADDON + ".toc"))
    version = next((ln.split(":", 1)[1].strip() for ln in toc if ln.startswith("## Version:")), "0")
    return {"fn": fn, "page": entries, "choices": choices, "title": title, "version": version,
            "slash": lits, "aux": aux}, info


def _q(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\r", "\\r") + '"'


def lua(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, int):
        return str(v)
    if isinstance(v, str):
        return _q(v)
    if isinstance(v, list):
        return "{" + ",".join(lua(x) for x in v) + "}"
    return "{" + ",".join(f"[{_q(k)}]={lua(x)}" for k, x in v.items()) + "}"


def feed():
    """Lua code that sets DCIStandInFeed from the installed addon."""
    data, _ = gather()
    return "DCIStandInFeed = " + lua(data)


if __name__ == "__main__":
    data, info = gather()
    if "--roles" in sys.argv:
        for name, (fname, nums) in info.items():
            print(f"{fname} {name}: {len(nums)} reads at lines {nums}")
        print("settings reads:", len(data["fn"]["CreateDCISettings"]), "entries:",
              [(e["kind"], len(e["a"])) for e in data["page"]])
        print("choices:", {k: len(v) for k, v in data["choices"].items()}, "profile msgs:", len(data["fn"]["ProfileMessages"]),
              "slash lines:", [len(x) for x in data["slash"]], "aux:", len(data["aux"]),
              "aux on:", sum(1 for e in data["page"] if e.get("aux")), "title len:", len(data["title"]), "feed bytes:", len(feed()))
    else:
        print(feed())
