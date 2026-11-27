"""python3 tools/modules.py: one row per UADD_* module: folder, drift name (tools/drift_sources.py MODULES),
missed key (STAY_LISTS in tools/missed.py, else "-"), its generators (tools/make_<x>_*.py) and test files
(tools/test_<x>_*.py). <x> is matched to a module by its real name: the whole name, its capitals ("fxpb"),
a prefix, or (generators, and tests of 3 letters or less) letters in order. Standard library only."""
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent


def rank(x, folder, loose):
    """(tier, name length) of how well token x names the module folder; None when it does not."""
    name = folder[5:]
    low = name.lower()
    if not x or not low:  # test__parallel.py gives an empty token
        return None
    caps = "".join(w[0] for w in re.findall(r"[A-Z][a-z0-9]*", name)).lower()
    if x == low:
        return (1, len(low))
    if x == caps:
        return (2, len(low))
    if len(x) >= 3 and low.startswith(x):
        return (3, len(low))
    if loose and low[0] == x[0] and (lambda it: all(c in it for c in x))(iter(low)):
        return (4, len(low))
    return None


def owner(x, folders, loose):
    best = [(r, f) for f in folders for r in [rank(x, f, loose)] if r]
    return min(best)[1] if best else None


def rows():
    folders = sorted(p.name for p in REPO.glob("UADD_*") if p.is_dir())
    src = (HERE / "drift_sources.py").read_text(encoding="utf-8")
    drift = dict(re.findall(r'^\s+"(UADD_\w+)":\s*\("(\w+)"', src, re.M))
    block = (HERE / "missed.py").read_text(encoding="utf-8").split("STAY_LISTS = {", 1)[1].split("\n}", 1)[0]
    keys = {name.lower(): key for key, name in re.findall(r'^\s+"(\w+)":\s*\("(\w+)"', block, re.M)}
    gens = {f: [] for f in folders}
    tests = {f: [] for f in folders}
    for path in sorted(HERE.glob("make_*_*.py")):
        f = owner(path.name.split("_")[1], folders, True)
        if f:
            gens[f].append(path.name)
    for path in sorted(HERE.glob("test_*.py")):
        x = path.name.split("_")[1].removesuffix(".py")
        f = owner(x, folders, len(x) <= 3)
        if f:
            tests[f].append(path.stem)
    return [(f, drift.get(f, "?"), keys.get(drift.get(f, "").lower(), "-"), gens[f], tests[f]) for f in folders]


def main():
    for f, name, key, g, t in rows():
        print(f"{f} | drift {name} | missed {key} | gen {' '.join(g) or '-'} | tests {' '.join(t) or '-'}")


if __name__ == "__main__":
    main()
