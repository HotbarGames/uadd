#!/usr/bin/env python3
"""The release stop: no release while docs/OPEN-BOXES.md lists an open case of boxes (owner, 2026-11-26).

    python3 tools/open_boxes.py   prints the open cases; exits 1 when there is one

bump_version.py and make_zip.py call stop(). There is no switch to skip it, on purpose. A missing list, or one
without its "## Cases" heading, stops the release too.
"""
import re
import sys
from pathlib import Path

LIST = Path(__file__).resolve().parent.parent / "docs" / "OPEN-BOXES.md"
HEAD = re.compile(r"^## Cases[ \t]*\r?$", re.M)


def cases(path=LIST):
    """The open cases, or ValueError when the list cannot be read."""
    if not path.is_file():
        raise ValueError(f"{path.name} is missing")
    text = path.read_text(encoding="utf-8")
    head = HEAD.search(text)
    if not head:
        raise ValueError(f"{path.name} has no '## Cases' heading")
    # every item under the heading is a case: a typo in "OPEN" must not let a release through
    return [m.group(1).strip() for m in re.finditer(r"^[ \t]*[-*+][ \t]+(.*)$", text[head.end():], re.M)]


def stop(path=LIST):
    """None when nothing is open, else why there is no release."""
    try:
        found = cases(path)
    except ValueError as e:
        return f"no release: {e}"
    if found:
        return "no release: boxes not fixed (docs/OPEN-BOXES.md):\n" + "\n".join("  " + c for c in found)
    return None


if __name__ == "__main__":
    why = stop()
    print(why or "no open case of boxes")
    sys.exit(1 if why else 0)
