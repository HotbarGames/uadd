"""Where a module is registered: tools/new_module.py's --register and --check work from PLACES (below).

A place: (name, file, has(text, m), add(text, m), when(m)). has says the module is there; add gives the text with
it in (a list entry where the list keeps it, a stub with the TODO mark where a person must write). add runs only
when has is false, so a second run changes nothing. A file that would go over check_repo.py's limits (and its
size-budget.json entry) is left as it was and reported as "no room". A list whose shape changed: "by hand".
Player texts get the addon's name only; each sentence is a TODO.
"""
import json
import re
from pathlib import Path

import new_module_lists as L
from new_module_lists import MARK, Gap, after_line, before, join_last, put_entry, wrap
from new_module_mod import Mod, flows, section     # noqa: F401  (Mod: for the callers)

LIMITS = {"lines": 300, "bytes": 25000, "maxLine": 400}


# ── Adders that are more than a list entry ─────────────────────────────────────────────────────

def licence_md(text, m, arr, none, mit):
    if m.licence in ("arr", "none"):
        return wrap(join_last(text, arr if m.licence == "arr" else none, m.title), "  ")
    return wrap(before(text, r"OpenMap \(MIT", f"{m.title} ({L.licence_name(m)}), "), "  ")


def bat_block(m):
    return (f'if exist "%ADDONS%\\{m.target}\\" (\n    echo   ok       {m.target} ^(for {m.folder}^)\n) else (\n'
            f"    echo   optional {m.target} not installed: the {L.cmd_safe(m.title)} module stays off\n)\n")


def bat_mods(text, m):
    last = [x for x in re.finditer(r'^set "MODS=.*"$', text, re.M)][-1]
    line = last.group(0)
    new = line[:-1] + f' {m.folder}"' if len(line) < 340 else f'{line}\nset "MODS=%MODS% {m.folder}"'
    return text[:last.start()] + new + text[last.end():]


def readme_rows(m):
    return (f"| `/uadd {m.key}` | Shows the {m.title} module's status and commands. |\n"
            f"| `/uadd {m.key} on` / `off` | Turns the {m.title} translation on or off, at once. Off gives {m.title} "
            "back as it is without UADD. |\n")


def changelog(text, m):
    row = f"- {m.title}: new module; {MARK}\n  {m.title}: новий модуль; {MARK}\n"
    if "\n## Unreleased\n" not in text:
        text = before(text, r"## \d", "## Unreleased\n\n")
        return text.replace("## Unreleased\n\n", "## Unreleased\n\n" + row + "\n", 1)
    a = text.index("\n## Unreleased\n") + len("\n## Unreleased\n")
    b = text.find("\n## ", a)
    part = text[a:b if b >= 0 else len(text)]
    mods = [x.end() for x in re.finditer(r"^- .+: new module;.*\n(?:  .*\n)*", part, re.M)]
    at = a + (mods[-1] if mods else len(part) - len(part.lstrip("\n")))
    return text[:at] + row + text[at:]


def restricted(text, m):
    if m.licence == "none":
        return before(text, r'\),\s*\n\s*"no licence', f', "{m.target}"')
    a = text.index("RESTRICTED = {")
    start, end = a, text.index("**dict.fromkeys", a)
    lines = [x for x in re.finditer(r'^    ".*",$', text[start:end], re.M)]
    if not lines:
        raise Gap("RESTRICTED has no entry line")
    best = min(lines, key=lambda x: len(x.group(0)))
    at = start + best.end()
    return text[:at] + f' "{m.target}": "All Rights Reserved in its TOC",' + text[at:]


def chaos_import(text, m):
    x = re.search(r"^from chaos_mods2 import (.+)$", text, re.M)
    if not x:
        raise Gap("no chaos_mods2 import line")
    names = sorted([*x.group(1).split(", "), "_" + m.short])
    text = text[:x.start(1)] + ", ".join(names) + text[x.end(1):]
    return before(text, r"^\]\n(?=\n)", f'    ("{m.folder}", "{m.target}", _{m.short}),\n')


def chaos_def(m):
    return (f"\n\ndef _{m.short}():\n    import flow_{m.short} as F\n"
            "    return F.shown() if F.module_there() else None\n")


def runner(text, m):
    x = m.short
    text = before(text, r"^UADD/Missed\.lua's checks",
                  f"{m.folder}'s checks run next, on a stand-in for {m.title} (flow_{x}.py).\n")
    text = before(text, r"^    import flow_dialogueui$", f"    import flow_{x}\n")
    return before(text, r' \("pops", flow_popups\)', f'\n        ("{x}", flow_{x}),')


def in_runner(text, m):
    """run.py names its segment: a flow it imports (or its docstring) names the module folder."""
    if m.short and re.search(rf"(?<!\w)flow_{re.escape(m.short)}\)", text):
        return True
    word = re.compile(rf"(?<!\w){re.escape(m.folder)}(?!\w)")
    return any(word.search(flows(m.root).get(f, "")) for f in re.findall(r"^    import (flow\w*)$", text, re.M))


def halves_fn(text, m):
    last = [x for x in re.finditer(r"^def \w+\(.*\): run\(.*\n", text, re.M)]
    if not last:
        raise Gap("halves_mods.py has no one-line function")
    row = (f'def {m.short}(check, c, note=""): run(check, "{m.folder}", *__import__("halves_{m.short}").parts(c, note))'
           f"  # noqa: E704,E501  {m.title}: halves_{m.short}.py; c None: not installed\n")
    return text[:last[-1].end()] + row + text[last[-1].end():]


def covered(text, m):
    return any(f'    "{m.folder}":' in text.split(start, 1)[1].split("\n}", 1)[0]
               for start in ("\nCOVERED = {", "\nNO_SLOTS = {"))


def halves_there(text, m):
    call = f'run(check, "{m.folder}"'
    return call in text or covered_no_slots(m) or any(
        call in p.read_text(encoding="utf-8") for p in (m.root / "tools" / "harness").glob("halves_*.py"))


def covered_no_slots(m):
    t = (m.root / "tools" / "halves_cover.py").read_text(encoding="utf-8")
    return f'    "{m.folder}":' in t.split("\nNO_SLOTS = {", 1)[1].split("\n}", 1)[0]


def said(*where):
    """has: one of the module's names stands in that part of the file."""
    return lambda t, m: L.entry(section(t, *where), m.titles)


def testing(text, m):
    """Any of the three test guides has its heading or a step that looks for it in /uadd."""
    docs = [text] + [(m.root / "docs" / f"TESTING{x}.md").read_text(encoding="utf-8") for x in ("", "-ADDONS")]
    return any(f"### {m.title}\n" in d or f'lists "{m.title}"' in d for d in docs)


def has(fmt):
    return lambda t, m: any(fmt.format(m=m, target=x, title=m.title) in t for x in m.targets)


def quoted(start, end):
    return lambda t, m: any(f'"{x}"' in section(t, start, end) for x in m.targets)


def _row(text, m, at, row):
    return before(text, at, row.format(m=m, MARK=MARK))


ARR, ALL = (lambda m: m.restricted()), (lambda m: True)
NOTE = {"arr": "TOC: All Rights Reserved; our data holds hashes only",
        "none": "no licence file: all rights reserved; our data holds hashes only"}
CF, CFQ, CFQU = "docs/curseforge-description.md", r"^- \*\*Questie\*\*: its", r"^- \*\*Questie\*\*: його"
H = "tools/harness/"
PLACES = [
    ("move-folders", ".pkgmeta", lambda t, m: re.search(rf"UADD/{m.folder}: {m.folder}(?!\w)", t),
     lambda t, m: after_line(t, r"^  UADD/UADD_\w+: UADD_\w+$", f"  UADD/{m.folder}: {m.folder}"), ALL),
    ("zip folders", "tools/make_zip.py", lambda t, m: f'"{m.folder}"' in section(t, "FOLDERS = [", "]"),
     lambda t, m: put_entry(t, "FOLDERS = [", "]", f'"{m.folder}"', 11), ALL),
    ("zip extra", "tools/make_zip.py", lambda t, m: f'"{m.folder}"' in section(t, "EXTRA = {", "}"),
     lambda t, m: put_entry(t, "EXTRA = {", "}\n", f'"{m.folder}": []', 9), ALL),
    ("install.bat rem", "install.bat", lambda t, m: re.search(rf"^rem .*\b{m.folder}\b", t, re.M),
     lambda t, m: wrap(join_last(t, "into the WoW Forever AddOns folder", m.folder), "rem "), ALL),
    ("install.bat MODS", "install.bat", lambda t, m: re.search(rf'^set "MODS=.*\b{m.folder}\b', t, re.M), bat_mods, ALL),
    ("install.bat check", "install.bat", lambda t, m: any(f"%ADDONS%\\{x}\\" in t or f"({x} " in t
                                                          for x in [*m.targets, m.name]),
     lambda t, m: before(t, r"^echo\.\necho Done", bat_block(m)), ALL),
    ("core TOC Notes", "UADD/UADD.toc", lambda t, m: L.entry(section(t, "## Notes:", "\n"), [m.title]),
     lambda t, m: re.sub(r"(?m)^(## Notes: .*)\.$", lambda x: f"{x.group(1)}, {m.title}.", t, count=1), ALL),
    ("CHANGELOG", "UADD/CHANGELOG.md", said(""), changelog, ALL),
    ("README list", "README.md", lambda t, m: re.search(rf"^- {re.escape(m.title)}(?::|$)", t, re.M),
     lambda t, m: _row(t, m, r"^- Questie: its", "- {m.title}\n"), ALL),
    ("README install", "README.md", has("`{m.folder}`"),
     lambda t, m: wrap(join_last(t, "folders into `World", f"`{m.folder}`"), ""), ALL),
    ("README commands", "README.md", has("| `/uadd {m.key}` |"),
     lambda t, m: before(t, r"^\| `/uadd combat off`", readme_rows(m)), ALL),
    ("README licence", "README.md", said("Do not copy another"), lambda t, m: licence_md(
        t, m, "(their TOCs say so)", "(no licence, so all rights are reserved)", None), ALL),
    ("CLAUDE.md licence", "CLAUDE.md", said("- Not allowed", "For the not-allowed"), lambda t, m: licence_md(
        t, m, "(TOC: All Rights Reserved)", "(no licence file)", None), ALL),
    ("notices", "THIRD-PARTY-NOTICES.md", said(""), lambda t, m: t.rstrip("\n") + f"\n\n## {m.title} "
     f"({L.licence_name(m)})\n\n{MARK} its page, what we hold of it, its notice; the count at the top of this file\n",
     lambda m: not m.restricted()),
    ("copy_scan", "tools/copy_scan.py", quoted("RESTRICTED = {", "THREADS"),
     lambda t, m: restricted(t, m) if m.restricted() else before(
         t, r"\}\nTHREADS", f', "{m.target}": "{L.licence_name(m)}"'), ALL),
    ("copy_check limit", "tools/copy_check.py", quoted("LABEL_LIMIT = {", "}"),
     lambda t, m: put_entry(t, "LABEL_LIMIT = {", "}", f'"{m.target}": 20', 15), ARR),
    ("drift", "tools/drift_sources.py", lambda t, m: f'"{m.folder}":' in section(t, "\nMODULES = {"),
     lambda t, m: before(t, r'^    "UADD_WowheadQuickLink"', f'    "{m.folder}": ("{m.target}", lambda p: __import__('
                         f'"drift_{m.short}").extract(p), None, ()),   # ' + NOTE.get(
                             m.licence, f"{L.licence_name(m)}; our data is keyed by hashes, no tracked English")
                         + "\n"), ALL),
    ("halves cover", "tools/halves_cover.py", covered, lambda t, m: before(
        t, r"^\}\nNO_SLOTS", f'    "{m.folder}": ("flow_{m.short}.py", "{m.short}"),\n'), ALL),
    ("halves function", H + "halves_mods.py", halves_there, halves_fn, ALL),
    ("chaos recipe", H + "chaos_mods.py", lambda t, m: f'"{m.folder}"' in t.replace(
        f'{{"{m.folder}"', f'"{m.folder}"'), chaos_import, ALL),
    ("chaos builder", H + "chaos_mods2.py", lambda t, m: not m.short or f"def _{m.short}(" in t + (
        m.root / H / "chaos_mods.py").read_text(encoding="utf-8"), lambda t, m: t.rstrip("\n") + chaos_def(m), ALL),
    ("harness segment", H + "run.py", in_runner, runner, ALL),
    ("TESTING", "docs/TESTING-ADDONS2.md", testing, lambda t, m: t.rstrip("\n") + f"\n\n### {m.title}\n\n{MARK} steps"
     f"\n\nOnly in the real client: {MARK}\n", ALL),
    ("CurseForge list", CF, lambda t, m: f"- **{m.title}**" in t.partition("\n# Українською")[0],
     lambda t, m: _row(t, m, CFQ, "- **{m.title}**\n"), ALL),
    ("CurseForge list uk", CF, lambda t, m: f"- **{m.title}**" in t.partition("\n# Українською")[2],
     lambda t, m: _row(t, m, CFQU, "- **{m.title}**\n"), ALL),
    ("CurseForge thanks", CF, has("- {title} by "), lambda t, m: _row(
        t, m, r"^- Questie by", "- {m.title} by {MARK}: https://www.curseforge.com/wow/addons/{MARK}\n"), ALL),
]


def over(root, rel, text):
    """Why this text breaks check_repo's limits, or ""."""
    budget = json.loads((Path(root) / "size-budget.json").read_text(encoding="utf-8")) \
        if (Path(root) / "size-budget.json").is_file() else {}
    room = dict(LIMITS, **budget.get("files", {}).get(rel, {}))
    lines = text.split("\n")
    got = {"lines": len(lines) - (lines[-1] == ""), "bytes": len(text.encode("utf-8")),
           "maxLine": max(len(x) for x in lines)}
    return ", ".join(f"{k} {got[k]} > {room[k]}" for k in got if got[k] > room[k])


def read(path):
    raw = path.read_bytes().decode("utf-8")
    return raw.replace("\r\n", "\n"), "\r\n" in raw


def missing(m, cache=None):
    """[(place, file)] where the module is not registered."""
    out, cache = [], {} if cache is None else cache
    for name, rel, there, _, when in PLACES:
        if rel not in cache:
            cache[rel] = read(m.root / rel)[0]
        if when(m) and not there(cache[rel], m):
            out.append((name, rel))
    return out


def register(m, dry=False):
    """Adds the module everywhere it is missing. (done, left): done [(place, file)], left [(place, file, why)]."""
    if not m.short or m.licence not in ("arr", "none", "gpl", "mit"):
        raise SystemExit("give --short and --licence (arr, none, gpl, mit): its flow has no new_module line")
    done, left, texts, crlf = [], [], {}, {}
    for name, rel, there, add, when in PLACES:
        if rel not in texts:
            texts[rel], crlf[rel] = read(m.root / rel)
        if not when(m) or there(texts[rel], m):
            continue
        try:
            new = add(texts[rel], m)
        except (Gap, ValueError, IndexError) as e:
            left.append((name, rel, f"by hand: the list changed shape ({e})"))
            continue
        why = over(m.root, rel, new)
        if why and not over(m.root, rel, texts[rel]):
            left.append((name, rel, f"no room: {why}"))
        elif new == texts[rel] or not there(new, m):
            left.append((name, rel, "by hand: the list changed shape (the new entry is not found after it)"))
        else:
            texts[rel] = new
            done.append((name, rel))
    changed = {r for _, r in done}
    broke = L.broken_python({r: texts[r] for r in changed})
    if broke:                            # all texts first, then the writing: one bad text and nothing is written
        why = dict(broke)
        left += [(n, r, f"nothing written: its new text does not compile ({why[r]})" if r in why
                  else "nothing written: another place's new text does not compile") for n, r in done]
        return [], left
    for rel in changed if not dry else ():
        out = texts[rel].replace("\n", "\r\n") if crlf[rel] else texts[rel]
        (m.root / rel).write_bytes(out.encode("utf-8"))
    return done, left
