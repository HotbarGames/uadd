"""A new module's skeleton and its place in every list, so neither is written by hand.

  python3 tools/new_module.py ADDON --short x [--licence arr|none|gpl|mit] [--like rts|bs] [--name N] [--key k]
                              [--title "In-game name"]
        writes UADD_<N>/, its generator, rules, source, drift, test, stand-in, flow and halves (tools/scaffold/*.tmpl),
        for the addon folder ADDON of the WoW AddOns folder (or $UADD_ADDONS_DIR). Never over a file that is there.
        --like rts: windows and chat (prints, tooltips, popups). --like bs: windows only, no Chat.lua.
        licence: arr its TOC says All Rights Reserved; none no licence file; gpl, mit.
  python3 tools/new_module.py --register N [--short x --licence l] [--dry]     puts it in every list; twice = once
  python3 tools/new_module.py --check [N]                                      the lists it is missing from

What needs judgment is left as the mark (new_module_lists.MARK); tools/test_new_module.py fails while a tracked file
has it. The lists: new_module_reg.PLACES. By hand: --check's "no room" ones, addon_versions.json (update-translations),
SHOWS in test_uall_routes.py and game_names_src.py (modules that show game names), the glossary.
"""
import argparse
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import lua_literals as LL  # noqa: E402
import new_module_reg as G  # noqa: E402
from new_module_lists import MARK  # noqa: E402

ROOT = HERE.parent
OURS = ("rts", "bs")                # rts: windows and chat; bs: windows only
SHORT = re.compile(r"[a-z][a-z0-9]{1,7}")
LIC = {"arr": "{t} is all rights reserved (its TOC says so).", "none": "{t} has no licence file: all rights reserved.",
       "gpl": "{t} is GPL-3.0.", "mit": "{t} is MIT (its notice goes with copies)."}
# template -> the file it makes
FILES = {"toc": "{F}/{F}.toc", "data.lua": "{F}/data/text01.lua", "words.lua": "{F}/Words.lua",
         "screen.lua": "{F}/Screen.lua", "chat.lua": "{F}/Chat.lua", "module.lua": "{F}/Module.lua",
         "make.py": "tools/make_{x}_text.py", "rules.py": "tools/{x}_rules.py", "source.py": "tools/{x}_source.py",
         "drift.py": "tools/drift_{x}.py", "test.py": "tools/test_{x}_text.py",
         "halves.py": "tools/harness/halves_{x}.py", "flow.py": "tools/harness/flow_{x}.py",
         "flow.lua": "tools/harness/flow_{x}.lua", "stand.toc": "tools/harness/{x}/{T}/{T}.toc",
         "stand.lua": "tools/harness/{x}/{T}/Stand.lua"}


def plain(text):
    return re.sub(r"\|c[0-9a-fA-F]{8}|\|r|\|T.*?\|t", "", text).strip()


def addon_title(target, addon=None):
    """The addon's TOC Title without colour codes, or None when it is not installed."""
    toc = Path(addon or LL.addon_dir(None, target)) / (target + ".toc")
    m = re.search(r"^## Title:\s*(.+?)\s*$", toc.read_text(encoding="utf-8-sig", errors="replace"), re.M) \
        if toc.is_file() else None
    return plain(m.group(1)) if m else None


def words(root, target, short, licence, name=None, key=None, title=None):
    """{placeholder: text} for the templates."""
    if not re.fullmatch(r"\w+", target, re.A):
        raise SystemExit(f"{target}: a folder name with other letters than A-Z 0-9 _ is not made here")
    if not SHORT.fullmatch(short):
        raise SystemExit("--short: 2 to 8 small letters or digits, a letter first")
    title = title or addon_title(target) or target
    name = name or re.sub(r"[^A-Za-z0-9]", "", target)
    if not re.fullmatch(r"[A-Za-z0-9]+", name):
        raise SystemExit(f"--name {name!r}: letters and digits only")
    if key is not None and not re.fullmatch(r"[a-z0-9]+", key):
        raise SystemExit(f"--key {key!r}: small letters and digits only")
    if re.search(r'["\\%@{}]', title):
        raise SystemExit(f"title {title!r}: give --title in plain letters")
    core = (Path(root) / "UADD" / "UADD.toc").read_text(encoding="utf-8")
    iface = re.search(r"^## Interface:\s*(.+?)\s*$", core, re.M).group(1)
    ver = re.search(r"^## Version:\s*(.+?)\s*$", core, re.M).group(1)
    return {"F": "UADD_" + name, "T": target, "TITLE": title, "x": short, "X": short.upper(), "key": key or short,
            "VER": ver, "IFACE": iface, "TODO": MARK, "L": licence, "LIC": LIC[licence].format(t=title),
            "PREFIX": f"|cff33ff99{title}|r: "}


def fill(template, w, chat=True):
    """The template's text: lines marked @chat only with chat, placeholders filled."""
    out = []
    for line in template.split("\n"):
        tagged = re.sub(r"\s*(?:--|#)@chat$", "", line)
        if tagged == line or chat:
            out.append(tagged)
    return re.sub(r"@(\w+)@", lambda m: w.get(m.group(1), m.group(0)), "\n".join(out))


def scaffold(root, w, like="rts"):
    """{path under root: text} of the skeleton."""
    out = {}
    for name, rel in FILES.items():
        if name == "chat.lua" and like == "bs":
            continue
        text = (HERE / "scaffold" / (name + ".tmpl")).read_text(encoding="utf-8")
        out[rel.format(**w)] = fill(text, w, like != "bs")
    return out


def taken(root, w, files=None):
    """Why this short or folder is in use already, or "": any file of the skeleton there, or the halves function."""
    root = Path(root)
    for rel in (f"tools/harness/flow_{w['x']}.py", f"tools/make_{w['x']}_text.py", w["F"],
                *(scaffold(root, w) if files is None else files)):
        if (root / rel).exists():
            return f"{rel} is there already"
    halves = root / "tools/harness/halves_mods.py"
    if halves.is_file() and re.search(rf"^def {w['x']}\(", halves.read_text(encoding="utf-8"), re.M):
        return f"halves_mods.{w['x']} is there already"
    return ""


def write(root, files):
    for rel, text in files.items():
        p = Path(root) / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text, encoding="utf-8", newline="\n")


def listing(root, others=False):
    """(module folders git knows, git's error or ""): the tracked ones, and the untracked ones too with others."""
    try:
        r = subprocess.run(["git", "-C", str(root), "ls-files", "-co" if others else "-c", "--exclude-standard",
                            "--", "UADD_*/*.toc"], capture_output=True, text=True, check=False)
    except OSError as e:
        return [], str(e)
    if r.returncode:
        return [], r.stderr.strip() or f"git exit {r.returncode}"
    return sorted({x.split("/")[0] for x in r.stdout.split("\n") if x}), ""


def tracked(root):
    """The module folders git tracks."""
    return listing(root)[0]


def folder(name):
    return name if name.startswith("UADD_") else "UADD_" + name


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("addon", nargs="?")
    ap.add_argument("--register", metavar="N")
    ap.add_argument("--check", nargs="?", const="", metavar="N")
    for opt in ("--short", "--name", "--key", "--title"):
        ap.add_argument(opt)
    ap.add_argument("--licence", choices=sorted(LIC), default=None)
    ap.add_argument("--like", choices=OURS, default="rts")
    ap.add_argument("--dry", action="store_true")
    ap.add_argument("--root", default=str(ROOT))
    a = ap.parse_args(argv)
    root = Path(a.root)
    if a.check is not None:
        bad = 0
        mods, err = ([folder(a.check)], "") if a.check else listing(root, others=True)
        if err or not mods:
            print(f"no modules to check: {err or 'no UADD_*/UADD_*.toc found (git tracked or untracked)'}")
            return 2
        for f in mods:
            for place, rel in G.missing(G.Mod(root, f)):
                bad += 1
                print(f"{f}: not in {rel} ({place})")
        print(f"{bad} missing")
        return 1 if bad else 0
    if a.register:
        m = G.Mod(root, folder(a.register), short=a.short, licence=a.licence)
        done, left = G.register(m, a.dry)
        for place, rel in done:
            print(f"{'would add' if a.dry else 'added'}: {rel} ({place})")
        for place, rel, why in left:
            print(f"LEFT: {rel} ({place}): {why}")
        print(f"{len(done)} added, {len(left)} left for you")
        return 1 if left else 0
    if not a.addon or not a.short:
        ap.error("give the addon's folder and --short, or --register, or --check")
    w = words(root, a.addon, a.short, a.licence or "arr", a.name, a.key, a.title)
    files = scaffold(root, w, a.like)
    why = taken(root, w, files)
    if why:
        raise SystemExit(why)
    if not a.dry:
        write(root, files)
    for rel, text in files.items():
        print(f"{rel}: {text.count(MARK)} {MARK}" if MARK in text else rel)
    print(f"next: python3 tools/new_module.py --register {w['F'][5:]}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
