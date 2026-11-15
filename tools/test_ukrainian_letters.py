"""For reference only, never fails: every Ukrainian string we ship that has і, ї, є or ґ.

Some Blizzard fonts (the font families such as Game13Font) draw Russian letters but show a box for
these four, so a place that shows one of these strings needs a font that has them. This lists them;
it checks nothing.

python3 -m unittest discover -s tools          (prints one summary line)
python3 tools/test_ukrainian_letters.py         (prints the whole list: file:line: text)
"""
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import extract_questie_keys as eqk  # noqa: E402

LETTERS = "іїєґІЇЄҐ"
SKIP_DIRS = {"tools", "node_modules", "dist", "build"}


def tocs():
    """Every addon .toc in the repo (any new addon folder too), as repo-relative paths, sorted."""
    out = []
    for root, dirs, files in os.walk(REPO):
        dirs[:] = sorted(d for d in dirs if not d.startswith(".") and d not in SKIP_DIRS)
        for name in sorted(files):
            if name.lower().endswith(".toc"):
                out.append(os.path.relpath(os.path.join(root, name), REPO).replace("\\", "/"))
    return out


def shipped_lua():
    """The .lua files each addon's TOC loads, as repo-relative paths (each once)."""
    out = []
    for toc in tocs():
        folder = os.path.dirname(toc)
        with open(os.path.join(REPO, toc), encoding="utf-8-sig", errors="replace") as f:
            for line in f:
                line = line.strip().replace("\\", "/")
                if line and not line.startswith("#") and line.lower().endswith(".lua"):
                    path = (folder + "/" + line) if folder else line
                    if path not in out:
                        out.append(path)
    return out


def strings_with_letters():
    """[(path, line, text)] for every string literal that has one of LETTERS."""
    found = []
    for path in shipped_lua():
        full = os.path.join(REPO, path)
        if not os.path.isfile(full):
            continue
        with open(full, "rb") as f:
            data = f.read()
        text = data.decode("utf-8", "replace")
        seen, where = set(), 0
        for kind, value in eqk.tokens(data):
            if kind != eqk.STR or not any(ch in value for ch in LETTERS) or value in seen:
                continue
            seen.add(value)
            # The line number: the first place the text appears from the last one on (good enough here).
            head = value[:20]
            at = text.find(head, where)
            if at < 0:
                at = text.find(head)
            if at >= 0:
                where = at
            found.append((path, text.count("\n", 0, max(at, 0)) + 1, value))
    return found


def letter_counts(found):
    return {ch: sum(1 for _, _, s in found if ch in s) for ch in LETTERS}


class Reference(unittest.TestCase):
    def test_list_strings_with_i_yi_ye_ge(self):
        found = strings_with_letters()
        counts = ", ".join(f"{ch} {n}" for ch, n in letter_counts(found).items() if n)
        print(f"\n[reference] {len(found)} shipped Ukrainian strings have і/ї/є/ґ ({counts}). "
              "Full list: python3 tools/test_ukrainian_letters.py", file=sys.stderr)


def main():
    found = strings_with_letters()
    for path, line, value in found:
        print(f"{path}:{line}: {value}")
    counts = ", ".join(f"{ch} {n}" for ch, n in letter_counts(found).items() if n)
    print(f"{len(found)} strings ({counts})")


if __name__ == "__main__":
    main()
