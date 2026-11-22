"""Reads the installed addons for the copy guard (tools/copy_check.py): their texts, labels and file hashes.

For each RESTRICTED or ALLOWED addon that is installed (folder in $UADD_ADDONS_DIR, else the WoW _forever_
AddOns folder) it collects its strings: every string literal in its .lua files (its English locale file and its
code; not the other languages, not its bundled Libs) and every attribute value and element text in its .xml
files (Lua in their script elements read as Lua), split at line breaks and colour codes. A restricted addon's
own locale keys (L["Some Key"]) are not counted: our data may be keyed by them. Two kinds are kept:
  * texts: pieces that could only be copied (see meaningful());
  * labels: short UI strings ("Buy Now", "Cancel All", "Auction House"; see label()), which prove a copy only in bulk.
Texts and labels that Questie (GPL-3.0), OpenMap or What's Training? (MIT) also have count as shared game words (targets()).
The scan is cached in tools/.cache/copy_check.json (git-ignored; $UADD_COPY_CACHE: another path, empty = none)
until a file it reads (path, size, time) or this file changes; delete it for a fresh scan. Standard library only.
"""
import hashlib
import html
import json
import os
import re
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.environ.get("UADD_COPY_CACHE", os.path.join(HERE, ".cache", "copy_check.json"))   # "" = no cache
DEFAULT_DIRS = ["/mnt/c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns",
                "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns"]
# folder name -> why it may not be copied
RESTRICTED = {
    "Auctionator": "All Rights Reserved in its LICENSE",
    "Mastercraft": "all rights reserved in its LICENSE.txt", "Mastercraft_Inbox": "all rights reserved (Mastercraft's licence)",
    "Pawn": "Creative Commons BY-NC-ND 3.0 (no derivatives)", "GatherMate2": "ARR in its TOC (its LICENSE.txt says GPL; until settled, ARR)","TomTom": "All Rights Reserved in its TOC", "RareScanner": "All Rights Reserved in its TOC", "Bagnon": "All Rights Reserved in its TOC", "BagBrother": "All Rights Reserved in its TOC (Bagnon's texts)", "Scrap": "All Rights Reserved in its TOC",
    **dict.fromkeys(("Attune", "DialogueUI", "ForeverXPbar", "ForeverDungeonJournal", "LayerSwap", "AutoPotion", "SpeedyAutoLoot", "WaypointUI", "WhatTheWhisper", "LootTriage"),
                    "no licence, so all rights reserved"),
}
ALLOWED = {"Questie": "GPL-3.0", "OpenMap": "MIT", "WhatsTraining": "MIT", "ForeverQuestPins": "GPL-3.0", "LiteMount": "GPL-2.0"}
THREADS = 32   # for reading the installed addons

# What counts as a copied text. A short or generic string ("Cancel", "Drag to move", "%s - %s") is something
# anyone writes, and a name ("Edwin VanCleef", "Large Brilliant Shard", "A Better Ingredient", "Auction
# House") is the game's, not the addon author's. Neither proves a copy. So a piece counts only when it has
#   * at least MIN_LEN characters, a space, MIN_WORDS words of two or more letters and MIN_LETTERS letters
#     (so no CONSTANT_NAMES, frame names, file paths, or pure %s / |cff colour codes), and
#   * a word of four or more letters that starts lower-case and is not one of SMALL (so not a Title Case
#     name or label).
# Texts that Questie, OpenMap or What's Training? also have are common game or UI words, so they are dropped too.
# A bulk copy (a locale file, English comments, English keys) still shows up as hundreds of texts.
MIN_LEN = 16
MIN_WORDS = 3
MIN_LETTERS = 10
# What counts as a label: any other piece with LABEL_LETTERS letters that reads as UI words, not code: one
# Capitalised word ("Cancel", not "OnClick", "LEFT" or "frame"), or two or more words with a lower-case letter
# ("Buy Now", "Auction House"). No _ \ / $ @ { } < > = | (identifiers, paths, code, escapes).
LABEL_LETTERS = 4
LABEL_MAX = 120
ONE_WORD = re.compile(r"[A-Z][a-z]{3,}[:.!?]?")
CODEY = re.compile(r"[_\\/$@{}<>=|]")

SKIP_DIRS = {"libs", "libs_modernah"}   # bundled libraries (Ace3 and others) with their own licences
TEXT_EXT = (".lua", ".xml", ".toc", ".txt", ".md", ".json")
OTHER_LOCALE = re.compile(r"(?:^|_)(?:deDE|esES|esMX|frFR|itIT|koKR|ptBR|ruRU|zhCN|zhTW|arAR)\.lua$")

LUA_PART = re.compile(r"""--\[(=*)\[.*?\]\1\]|--[^\n]*|"((?:[^"\\\n]|\\.)*)"|'((?:[^'\\\n]|\\.)*)'|\[(=*)\[(.*?)\]\4\]""",
                      re.S)
XML_COMMENT = re.compile(r"<!--.*?-->", re.S)
XML_TAG = re.compile(r"""<(/?)([A-Za-z_][\w:.-]*)((?:[^>"']|"[^"]*"|'[^']*')*)>""")
XML_ATTR = re.compile(r"""([A-Za-z_][\w:.-]*)\s*=\s*(?:"([^"]*)"|'([^']*)')""")
TEXT_ATTRS = {"text", "title", "label", "tooltip", "tooltiptext", "header", "headertext", "desc", "description"}
ESC = {"n": "\n", "t": "\t", "r": "\r", "\\": "\\", '"': '"', "'": "'"}
UNESC = re.compile(r"\\(.)")
SPLIT = re.compile(r"[\n\r\t]|\|c[0-9A-Fa-f]{8}|\|r|\|n")
WORD = re.compile(r"[A-Za-z][A-Za-z'-]*")   # "Torn-heart" is one word
# small words that names use too ("Speak with Shoni", "Heart of the Wild"): they do not make a text a sentence
SMALL = {"with", "from", "into", "onto", "upon", "your", "this", "that", "than", "then", "them", "they", "have",
         "will", "were", "been", "what", "when", "each", "only", "over"}
ARTICLES = {"the", "an"}   # a copied text needs MIN_WORDS words without these: a game place with its article is a name

_memo = {}


def addons_dir():
    env = os.environ.get("UADD_ADDONS_DIR")
    if env:
        return env
    return next((d for d in DEFAULT_DIRS if os.path.isdir(d)), DEFAULT_DIRS[0])


def meaningful(piece):
    if len(piece) < MIN_LEN or " " not in piece or sum(c.isascii() and c.isalpha() for c in piece) < MIN_LETTERS:
        return False
    words = WORD.findall(piece)
    return (sum(len(w) >= 2 for w in words) >= MIN_WORDS
            and any(len(w) >= 4 and w[0].islower() and w not in SMALL for w in words))


def sentence(piece):
    """A copied text: meaningful(), with MIN_WORDS words besides ARTICLES; else it can still be a label()."""
    return meaningful(piece) and sum(len(w) >= 2 and w.lower() not in ARTICLES for w in WORD.findall(piece)) >= MIN_WORDS


def label(piece):
    """Is this piece a short UI string (not a text, not code)?"""
    if len(piece) > LABEL_MAX or CODEY.search(piece) or sentence(piece) \
            or sum(c.isascii() and c.isalpha() for c in piece) < LABEL_LETTERS:
        return False
    if " " not in piece:
        return bool(ONE_WORD.fullmatch(piece))
    return sum(len(w) >= 2 for w in WORD.findall(piece)) >= 2 and any(c.islower() for c in piece)


def split(text):
    """The stripped, non-empty pieces of one decoded string."""
    return {p.strip() for p in SPLIT.split(text) if p.strip()}


def decode(raw):
    return UNESC.sub(lambda e: ESC.get(e.group(1), e.group(1)), raw) if "\\" in raw else raw


def is_key(source, m):
    """Is the string at m an index, as in L["Some Key"]?"""
    return source[max(0, m.start() - 3):m.start()].rstrip().endswith("[") and source[m.end():m.end() + 3].lstrip().startswith("]")


def lua_strings(source):
    """(values, keys): the pieces of the string literals in Lua source (comments skipped), keys apart."""
    values, keys = set(), set()
    for m in LUA_PART.finditer(source):
        raw = m.group(2) if m.group(2) is not None else m.group(3)
        if raw is not None:
            (keys if is_key(source, m) else values).update(split(decode(raw)))
        elif m.group(5) is not None:
            values |= split(m.group(5))
    return values, keys


def xml_strings(source):
    """(values, label_values, keys): the pieces of the attribute values and element text in XML source
    (comments skipped; Lua in script elements as Lua, its keys apart). label_values: only text-like attributes
    and element text."""
    source = XML_COMMENT.sub(" ", source)
    values, label_values, keys, stack, pos = set(), set(), set(), [], 0
    for m in XML_TAG.finditer(source):
        between = source[pos:m.start()]
        pos = m.end()
        if between.strip():
            inner = stack[-1] if stack else ""
            if inner == "script" or inner.startswith("on"):
                v, k = lua_strings(html.unescape(between))
                values, label_values, keys = values | v, label_values | v, keys | k
            else:
                got = split(html.unescape(between))
                values |= got
                label_values |= got
        close, name, attrs = m.group(1), m.group(2).lower(), m.group(3)
        if close:
            if name in stack:
                del stack[len(stack) - 1 - stack[::-1].index(name):]
            continue
        for a in XML_ATTR.finditer(attrs):
            got = split(html.unescape(a.group(2) if a.group(2) is not None else a.group(3)))
            values |= got
            if a.group(1).lower() in TEXT_ATTRS:
                label_values |= got
        if not attrs.rstrip().endswith("/"):
            stack.append(name)
    return values, label_values, keys


def _listdir(top):
    """(folders to go into, text files) of one folder."""
    try:
        with os.scandir(top) as it:
            entries = list(it)
    except OSError:
        return [], []
    dirs = [e.path for e in entries if e.is_dir() and not e.is_symlink()
            and e.name.lower() not in SKIP_DIRS and not e.name.startswith(".")]
    return dirs, [e.path for e in entries if e.name.lower().endswith(TEXT_EXT) and not e.is_dir()]


def addon_files(folder, pool=None):
    """The text files of an addon that the scan reads, sorted (bundled Libs and dot folders skipped).
    pool: a thread pool to list the folders of one level at once (the WoW folder is slow to read from WSL)."""
    out, level = [], [folder]
    while level:
        listed = list((pool.map if pool else map)(_listdir, level))
        level = [d for dirs, _ in listed for d in dirs]
        out += [f for _, files in listed for f in files]
    return sorted(out)


def stamp(folder, pool=None, files=None):
    """What tells a reinstalled or updated addon: a hash of every file the scan reads (path, size, time)."""
    files = addon_files(folder, pool) if files is None else files
    h = hashlib.sha1()
    for path, st in zip(files, (pool.map if pool else map)(os.stat, files)):
        h.update(f"{os.path.relpath(path, folder)}\0{st.st_size}\0{st.st_mtime_ns}\n".encode("utf-8", "replace"))
    return h.hexdigest()


def _read(path):
    with open(path, "rb") as f:
        return f.read()


def scan_addon(folder, restricted, pool=None, files=None):
    """{"texts": [...], "labels": [...], "files": [[size, sha1], ...]} for one installed addon."""
    values, label_values, keys, hashes = set(), set(), set(), set()
    paths = addon_files(folder, pool) if files is None else files
    for path, data in zip(paths, (pool.map if pool else map)(_read, paths)):
        if restricted and len(data) >= 64:
            hashes.add((len(data), hashlib.sha1(data).hexdigest()))
        name = os.path.basename(path).lower()
        if name.endswith(".lua") and not OTHER_LOCALE.search(os.path.basename(path)):
            v, k = lua_strings(data.decode("utf-8", "replace"))
            values |= v
            label_values |= v
            keys |= k
        elif name.endswith(".xml"):
            v, lv, k = xml_strings(data.decode("utf-8", "replace"))
            values |= v
            label_values |= lv
            keys |= k
    if restricted:   # our data may be keyed by its own locale keys
        label_values -= keys
    else:            # all of a shared addon's words are shared
        values |= keys
        label_values |= keys | values
    return {"texts": sorted(p for p in values if sentence(p)),
            "labels": sorted(p for p in label_values if label(p)), "files": sorted(hashes)}


def source_stamp():
    with open(os.path.abspath(__file__), "rb") as f:
        return hashlib.sha1(f.read()).hexdigest()


def load_cache(path):
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        return data if data.get("source") == source_stamp() else {}
    except (OSError, ValueError):
        return {}


def save_cache(path, data):
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f)
    except OSError:
        pass   # a cache that cannot be written only costs time


def scans(base, cache):
    """{addon: scan} for every installed RESTRICTED / ALLOWED addon, from the cache when it is current."""
    key = (base, cache)
    if key in _memo:
        return _memo[key]
    old = load_cache(cache).get("addons", {}) if cache else {}
    names = [n for n in list(ALLOWED) + list(RESTRICTED) if os.path.isdir(os.path.join(base, n))]

    def one(name):   # (scan, scanned again?)
        folder = os.path.join(base, name)
        files = addon_files(folder, pool)
        st = stamp(folder, pool, files)
        prev = old.get(name)
        if prev and prev.get("base") == base and prev.get("stamp") == st:
            return prev, False
        return dict(scan_addon(folder, name in RESTRICTED, pool, files), base=base, stamp=st), True

    # threads: each stat or read in the WoW folder waits on Windows, so many at once are far faster
    with ThreadPoolExecutor(THREADS) as pool, ThreadPoolExecutor(max(1, len(names))) as per_addon:
        done = list(per_addon.map(one, names))
    out = {name: scan for name, (scan, _) in zip(names, done)}
    changed = any(again for _, again in done)
    if cache and out and (changed or set(out) != set(old)):   # never wipe it for an empty folder
        save_cache(cache, {"source": source_stamp(), "addons": out})
    _memo[key] = out
    return out


def targets(base, cache=CACHE, with_labels=False):
    """({addon: texts}, {addon: {(size, sha1)}}, notes) for the installed restricted addons
    (and {addon: labels} after them if with_labels)."""
    found = scans(base, cache)
    shared, shared_labels = set(), set()
    for name in ALLOWED:
        shared.update(found.get(name, {}).get("texts", ()))
        shared_labels.update(found.get(name, {}).get("labels", ()))
    texts, hashes, labels, notes = {}, {}, {}, []
    for name in RESTRICTED:
        if name not in found:
            notes.append(f"copy check: {name} is not installed in {base}; skipped")
            continue
        texts[name] = set(found[name]["texts"]) - shared
        hashes[name] = {tuple(f) for f in found[name]["files"]}
        labels[name] = set(found[name].get("labels", ())) - shared_labels
    if with_labels:
        return texts, hashes, notes, labels
    return texts, hashes, notes
