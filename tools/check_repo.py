"""Repo guard: a size ratchet for tracked text files, a leak guard for claude-config files, and a TOC check.

python3 tools/check_repo.py            check (exit 0 = ok, 1 = problems)
python3 tools/check_repo.py --update   lower the numbers in size-budget.json / drop entries (never raises or adds)
python3 tools/check_repo.py --init     create size-budget.json from today's oversized files (once)

size-budget.json: {"files": {"<path>": {"lines": n, "bytes": n, "maxLine": n}}, "ignore": [{"glob": "data/*.csv",
"reason": "why this is not hand-written code"}]}. Only the numbers over the limits are recorded.

TOC check: for every tracked addon folder X/X.toc, each file the TOC lists is tracked, each tracked .lua/.xml
in X/ is listed, and all TOCs share one ## Version and one ## Interface.

Glossary check (when UADD/Glossary.lua exists): the problems tools/glossary.py finds fail the check too;
its warnings are a one-line note.

Copy check (tools/copy_check.py): no bulk copies of an all-rights-reserved addon's texts or files (the rule is
in README.md and CLAUDE.md). Reads the installed addons ($UADD_ADDONS_DIR, else the WoW folder); one that is
not installed is a note.

Standard library only. Reads tracked files only (`git ls-files -z`), from the git repo in the current folder.
Tests: python3 -m unittest discover -s tools
"""
import fnmatch
import json
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import copy_check  # noqa: E402
import glossary  # noqa: E402

BUDGET = "size-budget.json"
LIMITS = {"lines": 300, "bytes": 25000, "maxLine": 400}
WHAT = {"lines": "lines", "bytes": "bytes", "maxLine": "longest line (chars)"}

# never committed to these public repos, at any folder level
LEAK_DIRS = {".claude"}
LEAK_FILES = {".mcp.json", "CLAUDE.local.md"}

LOCKFILES = {
    "package-lock.json", "npm-shrinkwrap.json", "yarn.lock", "pnpm-lock.yaml", "bun.lockb", "poetry.lock",
    "Pipfile.lock", "uv.lock", "Cargo.lock", "Gemfile.lock", "composer.lock", "go.sum",
}
BINARY_EXT = {
    ".png", ".jpg", ".jpeg", ".gif", ".bmp", ".ico", ".webp", ".avif", ".tga", ".blp", ".psd", ".tif", ".tiff",
    ".mp3", ".mp4", ".ogg", ".wav", ".flac", ".m4a", ".webm", ".mov", ".avi", ".mkv",
    ".zip", ".gz", ".tgz", ".7z", ".rar", ".bz2", ".xz", ".jar",
    ".pdf", ".ttf", ".otf", ".woff", ".woff2", ".eot",
    ".exe", ".dll", ".so", ".dylib", ".bin", ".pyc", ".wasm", ".db", ".sqlite",
}
# vendored / third-party code and generated or built output (folder names, any level, case-insensitive)
SKIP_DIRS = {
    "vendor", "vendored", "third_party", "third-party", "thirdparty", "node_modules", "bower_components", "libs",
    "dist", "build", "__pycache__", "coverage",
}
HINT = ("Fix: split the file by topic (one feature or section per file) instead of raising its numbers. "
        "Recorded a shrink? `python3 tools/check_repo.py --update` lowers the budget.")


def git_root():
    out = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True)
    if out.returncode != 0:
        sys.exit("check_repo: not inside a git repository")
    return out.stdout.strip()


def tracked(root):
    out = subprocess.run(["git", "ls-files", "-z"], cwd=root, capture_output=True, check=True)
    return [p for p in out.stdout.decode("utf-8", "surrogateescape").split("\0") if p]


def is_leak(path):
    parts = path.split("/")
    return any(p in LEAK_DIRS for p in parts) or parts[-1] in LEAK_FILES


def ignore_globs(budget):
    globs = []
    for entry in budget.get("ignore", []):
        globs.append(entry if isinstance(entry, str) else entry.get("glob", ""))
    return [g for g in globs if g]


def matches(path, glob):
    if glob.endswith("/"):
        return path.startswith(glob)
    return fnmatch.fnmatchcase(path, glob)


def skip_reason(path, globs):
    """Why a path is not size-checked (None = checked). Content-free checks only."""
    parts = path.split("/")
    name = parts[-1]
    if name in LOCKFILES:
        return "lockfile"
    if os.path.splitext(name)[1].lower() in BINARY_EXT:
        return "binary"
    if any(p.lower() in SKIP_DIRS for p in parts[:-1]):
        return "vendored or generated"
    if ".min." in name or name.endswith(".map"):
        return "generated"
    if any(matches(path, g) for g in globs):
        return "ignored in " + BUDGET
    return None


def measure(full):
    with open(full, "rb") as f:
        data = f.read()
    if b"\0" in data[:8192]:
        return None  # binary
    lines = data.count(b"\n") + (1 if data and not data.endswith(b"\n") else 0)
    text = data.decode("utf-8", "replace")
    longest = max((len(line.rstrip("\r")) for line in text.split("\n")), default=0)
    return {"lines": lines, "bytes": len(data), "maxLine": longest}


def load_budget(root):
    path = os.path.join(root, BUDGET)
    if not os.path.exists(path):
        return None
    try:
        with open(path, encoding="utf-8") as f:
            budget = json.load(f)
    except ValueError as e:
        sys.exit(f"{BUDGET}: not valid JSON ({e})")
    budget.setdefault("files", {})
    budget.setdefault("ignore", [])
    return budget


def save_budget(root, budget):
    budget["files"] = {k: budget["files"][k] for k in sorted(budget["files"])}
    with open(os.path.join(root, BUDGET), "w", encoding="utf-8", newline="\n") as f:
        json.dump(budget, f, indent=2, ensure_ascii=False)
        f.write("\n")


def scan(root, budget):
    """Returns (leaks, sizes): leak paths and {path: metrics} for every size-checked tracked file."""
    globs = ignore_globs(budget)
    leaks, sizes = [], {}
    for path in tracked(root):
        if is_leak(path):
            leaks.append(path)
        full = os.path.join(root, path)
        if skip_reason(path, globs) or os.path.islink(full) or not os.path.isfile(full):
            continue
        m = measure(full)
        if m is not None:
            sizes[path] = m
    return leaks, sizes


def over_limits(m):
    return {k: m[k] for k in LIMITS if m[k] > LIMITS[k]}


def toc_problems(root, paths):
    """Each addon folder X with a tracked X/X.toc: the TOC's file list matches the tracked .lua/.xml files,
    and every TOC has the same ## Version and ## Interface."""
    problems, seen = [], {"Version": {}, "Interface": {}}
    tracked_set = set(paths)
    for toc in sorted(p for p in paths if p.count("/") == 1 and p.endswith(".toc")
                      and p.split("/")[0] + ".toc" == p.split("/")[1]):
        folder = toc.split("/")[0]
        if not os.path.isfile(os.path.join(root, toc)):
            problems.append(f"{toc}: tracked but missing on disk")
            continue
        with open(os.path.join(root, toc), encoding="utf-8-sig", errors="replace") as f:
            lines = [line.strip() for line in f]
        listed = []
        for line in lines:
            if line.startswith("##"):
                key, _, value = line[2:].partition(":")
                if key.strip() in seen:
                    seen[key.strip()].setdefault(value.strip(), []).append(toc)
            elif line and not line.startswith("#"):
                listed.append(folder + "/" + line.replace("\\", "/"))
        for path in listed:
            if path not in tracked_set:
                problems.append(f"{toc}: lists {path}, which is not a tracked file")
        for path in sorted(p for p in paths if p.startswith(folder + "/") and p.endswith((".lua", ".xml"))):
            if path not in listed:
                problems.append(f"{toc}: does not list {path} (add it to the TOC or remove the file)")
    for key, values in seen.items():
        if len(values) > 1:
            problems.append(f"TOCs disagree on ## {key}: " + "; ".join(f"{v} in {', '.join(t)}"
                                                                      for v, t in sorted(values.items())))
    return problems


def check(root, budget):
    """Returns (problems, notes) as printable lines."""
    leaks, sizes = scan(root, budget)
    problems = [f"{p}: claude-config file must never be committed (git rm --cached '{p}')" for p in leaks]
    paths = tracked(root)
    problems += toc_problems(root, paths)
    problems_c, notes = copy_check.check(root, paths, lambda p: os.path.splitext(p)[1].lower() in BINARY_EXT)
    problems += problems_c
    if os.path.isfile(os.path.join(root, "UADD", "Glossary.lua")):
        g_problems, g_warnings, _ = glossary.check(root)
        problems += ["glossary: " + p for p in g_problems]
        if g_warnings:
            notes.append(f"glossary: {len(g_warnings)} warning(s); python3 tools/glossary.py lists them")
    files = budget["files"]
    for path, m in sizes.items():
        rec = files.get(path, {})
        for k in LIMITS:
            limit = rec.get(k, LIMITS[k])
            if m[k] > limit:
                tag = " over its budget" if k in rec else ""
                problems.append(f"{path}: {WHAT[k]}{tag} ({m[k]} > {limit})")
        if path in files and not over_limits(m):
            problems.append(f"{path}: now under all limits; remove its entry from {BUDGET} (--update does it)")
        elif any(k in LIMITS and m[k] < v for k, v in rec.items()):
            notes.append(f"{path}: shrank; --update locks in the smaller numbers")
    for path in files:
        if path not in sizes:
            problems.append(f"{path}: in {BUDGET} but not a tracked, size-checked file; remove its entry "
                            "(--update does it)")
    return problems, notes


def update(root, budget):
    """Lowers numbers and removes entries only. Never raises a number, never adds a file."""
    _, sizes = scan(root, budget)
    new = {}
    for path, rec in budget["files"].items():
        m = sizes.get(path)
        if m is None:
            continue
        kept = {k: min(v, m[k]) for k, v in rec.items() if k in LIMITS and m[k] > LIMITS[k]}
        if kept:
            new[path] = kept
    budget["files"] = new
    save_budget(root, budget)


def init(root):
    budget = {"files": {}, "ignore": []}
    _, sizes = scan(root, budget)
    budget["files"] = {p: over_limits(m) for p, m in sizes.items() if over_limits(m)}
    save_budget(root, budget)
    return budget


def main(argv):
    root = git_root()
    budget = load_budget(root)
    if "--init" in argv:
        if budget is not None:
            sys.exit(f"{BUDGET} already exists; --init runs once. Use --update to lower it.")
        budget = init(root)
        print(f"{BUDGET}: recorded {len(budget['files'])} file(s)")
    elif "--update" in argv:
        if budget is None:
            sys.exit(f"no {BUDGET} to update")
        update(root, budget)
    if budget is None:
        budget = {"files": {}, "ignore": []}
    problems, notes = check(root, budget)
    for line in notes:
        print(line)
    for line in problems:
        print(line)
    if problems:
        print(HINT)
        if any(copy_check.TAG in p for p in problems):
            print(copy_check.HINT)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
