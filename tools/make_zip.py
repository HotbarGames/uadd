"""Build the CurseForge upload by hand: dist/UADD-<version>.zip with one top-level folder per addon: UADD/ (the
core) and each module's folder (CurseForge needs each TOC name to match its folder). Each folder holds its TOC,
the files the TOC loads and the files in EXTRA; any other file there stops the build, and so does a TOC whose
version differs. .pkgmeta (the release workflow) packs the same folders; this is for a manual upload or a
local look.

python3 tools/make_zip.py   (WSL or Windows; standard library only)
"""
import re
import zipfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
FOLDERS = ["UADD", "UADD_Questie", "UADD_DungeonJournal", "UADD_OpenMap", "UADD_DialogueUI", "UADD_ForeverXPBar",
           "UADD_Auctionator", "UADD_Attune", "UADD_LayerSwap", "UADD_AutoPotion", "UADD_Bagnon", "UADD_Mastercraft",
           "UADD_WhatsTraining", "UADD_TomTom", "UADD_RareScanner", "UADD_Pawn", "UADD_GatherMate2",
           "UADD_Scrap", "UADD_SpeedyAutoLoot", "UADD_WaypointUI",
           "UADD_ForeverQuestPins", "UADD_LiteMount", "UADD_WhatTheWhisper", "UADD_LootTriage",
           "UADD_DeleteCheapestItem", "UADD_WowheadQuickLink"]
EXTRA = {"UADD": ["LICENSE.txt", "CHANGELOG.md", "Logo.tga"], "UADD_Questie": [], "UADD_DungeonJournal": [], "UADD_OpenMap": [],
         "UADD_DialogueUI": [], "UADD_ForeverXPBar": [], "UADD_Auctionator": [], "UADD_Attune": [], "UADD_LayerSwap": [],
         "UADD_AutoPotion": [], "UADD_Bagnon": [], "UADD_Mastercraft": [],
         "UADD_WhatsTraining": [], "UADD_TomTom": [], "UADD_RareScanner": [], "UADD_Pawn": [], "UADD_GatherMate2": [],
         "UADD_Scrap": [], "UADD_SpeedyAutoLoot": [], "UADD_WaypointUI": [],
         "UADD_ForeverQuestPins": [], "UADD_LiteMount": [], "UADD_WhatTheWhisper": [], "UADD_LootTriage": [],
         "UADD_DeleteCheapestItem": [], "UADD_WowheadQuickLink": []}
# files from the repo root that go into a folder of the zip: the notices for the OpenMap (MIT) and Questie (GPL)
# texts we copy must ship with the copies
FROM_ROOT = {"UADD": ["THIRD-PARTY-NOTICES.md"]}


def toc_files(folder):
    text = (REPO / folder / f"{folder}.toc").read_text(encoding="utf-8")
    files = [line.strip().replace("\\", "/") for line in text.splitlines()
             if line.strip() and not line.startswith("#")]
    return text, [f"{folder}.toc"] + files + EXTRA[folder]


def main():
    version = None
    entries = []
    for folder in FOLDERS:
        text, files = toc_files(folder)
        v = re.search(r"^## Version:\s*(\S+)", text, re.M).group(1)
        if version not in (None, v):
            raise SystemExit(f"{folder}.toc has version {v}, not {version}")
        version = v
        present = sorted(p.relative_to(REPO / folder).as_posix() for p in (REPO / folder).rglob("*") if p.is_file())
        extra = [p for p in present if p not in files]
        if extra:
            raise SystemExit(f"unexpected files in {folder}/, add them to the TOC or EXTRA, or remove: {extra}")
        entries += [(REPO / folder / f, f"{folder}/{f}") for f in files]
        entries += [(REPO / f, f"{folder}/{f}") for f in FROM_ROOT.get(folder, [])]

    out = REPO / "dist" / f"UADD-{version}.zip"
    out.parent.mkdir(exist_ok=True)
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for src, name in entries:
            z.write(src, name)
    print(out, out.stat().st_size, "bytes")
    import listing  # the CurseForge description is pasted by hand: say when the page is behind (lesson 24)
    print(listing.reminder() or "CurseForge description: the one last pasted.")


if __name__ == "__main__":
    main()
