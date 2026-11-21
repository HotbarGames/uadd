"""Copy guard: no bulk copies of an all-rights-reserved addon's text or code in this public repo.

Used by tools/check_repo.py (its problems fail the check). The rule: README.md "Rules for contributors", CLAUDE.md.
tools/copy_scan.py reads the installed RESTRICTED addons' texts and labels (what counts as each: there).
This file looks for them:
  1. in every tracked or untracked-but-not-ignored text file (LICENSE files skipped):
       * texts anywhere in the file. A file under tools/harness/ (test stand-ins of the addons) may hold
         HARNESS_BUDGET of one addon's texts, and all harness files together HARNESS_TOTAL; any other file none;
       * labels as whole strings only (a quoted string, a line, a comment, a table cell: see segments()). One
         file may hold LABEL_LIMIT[addon] of one addon's labels;
  2. flags a tracked file that is a byte-for-byte copy of one of its text files, and a tracked file named like
     an English locale file (en.lua, enUS.lua, en_*.lua) in a module folder or in tools/dj_prose/.
An addon that is not installed is skipped with a note. Only exact matches count. Questie and Forever Quest Pins
(GPL-3.0), LiteMount (GPL-2.0), OpenMap and What's Training? (MIT) may be copied with their notices (THIRD-PARTY-NOTICES.md). Standard library only.
"""
import hashlib
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from copy_scan import (ALLOWED, CACHE, ESC, MIN_LEN, RESTRICTED, SPLIT, UNESC, addons_dir,  # noqa: E402,F401
                       decode, label, meaningful, split, targets)

TAG = "[copy]"   # starts every problem line of this check
HINT = (f"{TAG} Fix: keep only our Ukrainian, keyed by the addon's own locale key or by a hash of the English; "
        "read the English from the installed addon at build or test time (CLAUDE.md, 'Other addons' texts').")
HARNESS = "tools/harness/"
HARNESS_BUDGET = 10   # texts of one restricted addon that one test stand-in file may hold
# texts of one restricted addon that all test stand-in files together may hold. Measured 2026-11-15: at most
# 15 (Auctionator; DialogueUI 10, ForeverXPbar 9, Attune 5, ForeverDungeonJournal 3). 20 = two full files.
HARNESS_TOTAL = 20
# labels of one restricted addon that one file (any file, tools/harness/ too) may hold. Measured 2026-11-15,
# worst file: Auctionator 17 (its harness stand-in; 15 in UADD/glossary/world.lua), DialogueUI 11,
# ForeverXPbar 11 (harness stand-ins), Attune 69 (UADD_DungeonJournal/data/prose.lua), ForeverDungeonJournal 79
# (UADD/glossary/journal.lua). Those two are big because their labels are mostly the game's own names (quests,
# items, stats) that our glossary and data use too. Limit: about 40% over the worst file, rounded up to 5,
# at least 20. A bulk copy is still hundreds (they have 200 to 8,000 labels each).
LABEL_LIMIT = {"Auctionator": 25, "Attune": 100, "DialogueUI": 20, "ForeverXPbar": 20,
               "ForeverDungeonJournal": 115, "LayerSwap": 20, "AutoPotion": 20,
               "Bagnon": 20, "BagBrother": 20, "Mastercraft": 20, "Mastercraft_Inbox": 20,
               "TomTom": 20, "RareScanner": 20, "Pawn": 20, "GatherMate2": 20, "Scrap": 20,
               "SpeedyAutoLoot": 20, "WaypointUI": 20, "WhatTheWhisper": 20}
EXAMPLES = 3
LICENSE_NAME = re.compile(r"^(?:LICEN[CS]E|COPYING|THIRD-PARTY-NOTICES)(?:\.\w+)?$", re.I)
EN_LOCALE_NAME = re.compile(r"^(?:en|enus|engb|en_.+)\.lua$", re.I)
START = re.compile(r"(?<![A-Za-z0-9])\S|[^\sA-Za-z0-9]")   # where a copied text can begin
KEY = MIN_LEN
# where a label can stand as a whole string in one of our files
QUOTED = re.compile(r""""((?:[^"\\\n]|\\.)*)"|'((?:[^'\\\n]|\\.)*)'|`([^`\n]*)`""")
LINE_LEAD = re.compile(r"^(?:--+|#+|//+|[-*>]|\d+[.)])\s*")
TRAILING_COMMENT = re.compile(r"\s--+\s*(.*)$")


def index(texts):
    """{first KEY characters: [(text, addon)]} for a fast search."""
    idx = {}
    for addon, ts in texts.items():
        for t in ts:
            idx.setdefault(t[:KEY], []).append((t, addon))
    return idx


def views(text):
    """The file as written, and with \\" \\n escapes and colour codes undone (for texts inside a string)."""
    out = [text]
    if "\\" in text or "|c" in text or "|r" in text:
        out.append(SPLIT.sub("\n", UNESC.sub(lambda e: ESC.get(e.group(1), "\\" + e.group(1)), text)))
    return out


def hits_in(text, idx):
    """{addon: set(texts)} found in one file's text."""
    found = {}
    for view in views(text):
        for m in START.finditer(view):
            i = m.start()
            for t, addon in idx.get(view[i:i + KEY], ()):
                if view.startswith(t, i):
                    found.setdefault(addon, set()).add(t)
    return found


def segments(text):
    """The whole strings of one file where a label can stand: quoted strings, lines (without a leading
    comment or list mark), trailing comments and table cells, split at colour codes."""
    out = set()
    for m in QUOTED.finditer(text):
        raw = next(g for g in m.groups() if g is not None)
        out |= split(decode(raw))
    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue
        out |= split(LINE_LEAD.sub("", line))
        c = TRAILING_COMMENT.search(line)
        if c:
            out |= split(c.group(1))
        if line.startswith("|"):
            out.update(cell.strip() for cell in line.strip("|").split("|") if cell.strip())
    return out


def label_hits(text, labels):
    """{addon: set(labels)} standing as whole strings in one file's text."""
    seg = segments(text)
    return {addon: seg & ls for addon, ls in labels.items() if seg & ls}


def untracked(root):
    """The untracked files git does not ignore (they get committed next), or [] outside a git repo."""
    try:
        out = subprocess.run(["git", "ls-files", "--others", "--exclude-standard", "-z"], cwd=root,
                             capture_output=True)
    except OSError:
        return []
    if out.returncode != 0:
        return []
    return [p for p in out.stdout.decode("utf-8", "surrogateescape").split("\0") if p]


def short(t, n=50):
    return repr(t if len(t) <= n else t[:n] + "...")


def examples(found):
    return ", ".join(short(t) for t in sorted(found)[:EXAMPLES])


def locale_named(p):
    return bool(EN_LOCALE_NAME.match(p.rsplit("/", 1)[-1])) and (
        p.split("/")[0].startswith("UADD_") or p.startswith("tools/dj_prose/"))


def check(root, paths, is_binary, base=None, cache=CACHE):
    """(problems, notes) for the tracked paths and the untracked, not ignored files under root.
    is_binary(path) says which paths to skip by name."""
    base = base or addons_dir()
    seen = set(paths)
    paths = list(paths) + [p for p in untracked(root) if p not in seen]
    problems = [f"{TAG} {p}: named like a copied English locale file; English is read from the installed addon "
                "at build or test time, into a git-ignored place" for p in paths if locale_named(p)]
    texts, hashes, notes, labels = targets(base, cache, with_labels=True)
    if not texts:
        return problems, notes
    idx = index(texts)
    sizes = {size for files in hashes.values() for size, _ in files}
    harness = {}   # addon -> texts in all harness files
    for p in paths:
        full = os.path.join(root, p)
        if LICENSE_NAME.match(p.rsplit("/", 1)[-1]) or is_binary(p) or os.path.islink(full) \
                or not os.path.isfile(full):
            continue
        with open(full, "rb") as f:
            data = f.read()
        if b"\0" in data[:8192]:
            continue
        if len(data) in sizes:
            digest = hashlib.sha1(data).hexdigest()
            problems += [f"{TAG} {p}: an exact copy of a file of {addon} ({RESTRICTED[addon]})"
                         for addon, files in hashes.items() if (len(data), digest) in files]
        in_harness = p.startswith(HARNESS)
        budget = HARNESS_BUDGET if in_harness else 0
        text = data.decode("utf-8", "replace")
        for addon, found in sorted(hits_in(text, idx).items()):
            if in_harness:
                harness.setdefault(addon, set()).update(found)
            if len(found) > budget:
                problems.append(f"{TAG} {p}: {len(found)} text(s) copied from {addon} ({RESTRICTED[addon]}; "
                                f"allowed here: {budget}), e.g. {examples(found)}")
        for addon, found in sorted(label_hits(text, labels).items()):
            limit = LABEL_LIMIT[addon]
            if len(found) > limit:
                problems.append(f"{TAG} {p}: {len(found)} label(s) copied from {addon} ({RESTRICTED[addon]}; "
                                f"allowed here: {limit}), e.g. {examples(found)}")
    for addon, found in sorted(harness.items()):
        if len(found) > HARNESS_TOTAL:
            problems.append(f"{TAG} {HARNESS}: {len(found)} text(s) copied from {addon} in all its files together "
                            f"({RESTRICTED[addon]}; allowed: {HARNESS_TOTAL}), e.g. {examples(found)}")
    return problems, notes
