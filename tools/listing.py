"""The CurseForge description: is it the one players see?

The description players read on CurseForge is pasted by hand (the upload API cannot change it). Its text lives in
docs/curseforge-description.md; tools/test_listing.py makes sure it, README.md and the core TOC's Notes name every
module. This file remembers which text was last pasted (a sha256 in tools/cf_description.sha256), so a release
can say loudly that the page on CurseForge is behind.

python3 tools/listing.py            says whether the text changed since the last paste (exit 0 either way)
python3 tools/listing.py --pasted   after you pasted it on CurseForge and saved: remember this text
"""
import hashlib
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DESCRIPTION = REPO / "docs" / "curseforge-description.md"
STAMP = REPO / "tools" / "cf_description.sha256"
EDIT_PAGE = "https://authors.curseforge.com/#/projects/1807250/description"


def module_names():
    """{folder: name} for each UADD_* module, the name as its TOC Title shows it in the game."""
    names = {}
    for toc in sorted(REPO.glob("UADD_*/UADD_*.toc")):
        if toc.stem != toc.parent.name:
            continue
        m = re.search(r"^## Title:\s*UADD - (.+?)\s*$", toc.read_text(encoding="utf-8"), re.M)
        names[toc.parent.name] = m.group(1) if m else None
    return names


def digest(text=None):
    if text is None:
        text = DESCRIPTION.read_text(encoding="utf-8")
    return hashlib.sha256(text.replace("\r\n", "\n").encode("utf-8")).hexdigest()


def pasted():
    try:
        return STAMP.read_text(encoding="utf-8").strip()
    except FileNotFoundError:
        return None


def reminder():
    """A loud note when the description changed since the last paste, else None."""
    if pasted() == digest():
        return None
    return ("\n" + "!" * 72 + "\n"
            "The CurseForge description changed since it was last pasted.\n"
            f"Paste docs/curseforge-description.md on {EDIT_PAGE} (Markdown),\n"
            "press Save, then run: python3 tools/listing.py --pasted (and commit the stamp).\n"
            + "!" * 72)


def main(argv):
    if argv[1:] == ["--pasted"]:
        STAMP.write_text(digest() + "\n", encoding="utf-8")
        print("remembered:", STAMP.relative_to(REPO).as_posix())
        return 0
    if argv[1:]:
        print(__doc__)
        return 2
    print(reminder() or "The CurseForge description is the one last pasted.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
