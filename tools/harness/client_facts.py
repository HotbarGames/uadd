"""What the harness assumes about the client's fonts, and what the real client recorded.

UADD/Probe.lua runs once per session in the game and saves facts about fonts in UADD_DB.health.probe (the
owner only logs in; the game writes the file at logout). tools/test_client_facts.py compares each recorded
fact with FACTS below: a mismatch means the harness models the client wrong, as when it dropped a hand-set
file on SetFontObject and boxes in tooltips reached the owner (docs/LESSONS4.md, lesson 44).

FACTS: {fact: (what the harness assumes, note)}. Where the client differs, fix the harness model
(tools/harness/wow_widgets.lua, wow_fontfam.lua), then the value here. INFO_ONLY facts are recorded, not
compared. Standard library only.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import missed  # noqa: E402  (find_files, parse: the same finder and reader as tools/missed.py)

FACTS = {
    "keepsFileOverObject": (True, "wow_widgets.lua: SetFont marks a FontString or EditBox __hand, and "
                                  "SetFontObject then sets the object but keeps the hand-set file (lesson 44)"),
    "otherThenBackKeepsFile": (True, "same model: another object, then back, keeps the hand-set file"),
    "nilKeepsFile": (True, "SetFontObject(nil) has no object file to copy, so the file stays"),
    "nilClearsObject": (True, "SetFontObject(nil) sets __fontObject to nil"),
    "objectPath": ("fonts\\frizqt__.ttf", "GameTooltipText:GetFont(), lower case, \\ (wow_fontfam.lua)"),
    "objectReportsLatin": (True, "GetFont on the family shows only its Latin file"),
    "fsPath": ("fonts\\frizqt__.ttf", "a FontString on GameTooltipText reports the object's file"),
    "fsReportsLatin": (True, "same"),
    "setFontReturnsFS": ("true", "Widget:SetFont returns true when the file exists"),
    "setFontReturnsMissing": ("false", "Widget:SetFont returns false for a file the client lacks"),
    "setFontReturnsObject": ("none", "a font object's SetFont returns nothing (lesson 2)"),
    "hasFontFamily": (True, "boxes.lua: CreateFontFamily makes a family; one with a Cyrillic member draws "
                            "Cyrillic (ForeverDungeonJournal's ForeverDJ_* fonts)"),
}
INFO_ONLY = {"widthObject", "widthFriz", "widthCyr", "widthNormal", "build", "at"}   # harness: #text * 6 for all three


def mismatches(probe):
    """[message] for each recorded fact that differs from FACTS; facts the probe lacks are skipped."""
    out = []
    for name, (assumed, note) in sorted(FACTS.items()):
        if name not in probe:
            continue
        got = probe[name]
        if got != assumed:
            out.append("%s: the client says %r, the harness assumes %r: fix the harness model (%s)"
                       % (name, got, assumed, note))
    return out


def probes(files):
    """[probe dict] from each readable UADD.lua in `files` ([(label, path)]); unreadable files are skipped."""
    out = []
    for _label, path in files:
        try:
            with open(path, "rb") as f:
                saved = missed.parse(f.read())
        except (OSError, ValueError):
            continue
        db = saved.get("UADD_DB") if isinstance(saved, dict) else None
        health = db.get("health") if isinstance(db, dict) else None
        probe = health.get("probe") if isinstance(health, dict) else None
        if isinstance(probe, dict):
            out.append(probe)
    return out


def latest_probe(argv=None):
    """The newest probe (largest `at`) in the owner's SavedVariables, or None."""
    found = probes(missed.find_files(argv or []))
    if not found:
        return None
    return max(found, key=lambda p: p.get("at") if isinstance(p.get("at"), (int, float)) else 0)


if __name__ == "__main__":
    p = latest_probe(sys.argv[1:])
    if p is None:
        print("no probe recorded yet (log in once with UADD on, then log out)")
        sys.exit(0)
    bad = mismatches(p)
    print("\n".join(bad) if bad else "every recorded fact matches the harness")
    sys.exit(1 if bad else 0)
