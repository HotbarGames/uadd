"""Reads the installed Wowhead Quick Link for tools/make_wql_text.py: its link popup's text and button, the header
of the popup (a template and the link types it fills in), its two key binding names and the labels of its /wql
window. Which texts are kept and how: tools/wql_rules.py. Nothing here names its English (no licence file: all
rights reserved).

Every text is keyed by UADD.Hash of the English as the module sees it at run time:
  Pop.<hash>   the popup's text, its header as %s (the game fills it in)
  Head.<hash>  the header's template: the words glued before the link type, the type as %s
  Type.<hash>  a link type as the header shows it (the addon's capitalised form)
  Code.<hash>  the popup's button, a binding name, a label of the /wql window
"""
import os
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import hashtext as H  # noqa: E402
import luatok  # noqa: E402
import wql_rules as R  # noqa: E402

ADDON_DIRS = ["/mnt/c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns",
              "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns"]
FOLDER = "WowheadQuickLink"
TOC = "WowheadQuickLink.toc"
MAIN, CONFIG, STRAT, XML = ("WowheadQuickLink.lua", "WowheadQuickLinkConfig.lua", "WowheadQuickLinkStrategies.lua",
                            "WowheadQuickLinkConfig.xml")
POPUP_VAR = "popupText"          # the local that holds the popup's text
TYPE_VAR = "typeStr"             # the local glued after the header's words
URL_NAME = "WowheadQuickLinkConfig_FinalUrlText"   # shows the URL, not a word (skipped by name)
S, N, Y = luatok.STR, luatok.NAME, luatok.SYM


def addon_dir(arg=None):
    if arg:
        return Path(arg)
    base = os.environ.get("UADD_ADDONS_DIR") or next((d for d in ADDON_DIRS if os.path.isdir(d)), ADDON_DIRS[0])
    return Path(base) / FOLDER


def version(addon):
    toc = Path(addon) / TOC
    m = re.search(r"^## Version:\s*(\S+)", toc.read_text(encoding="utf-8-sig", errors="replace"), re.M) \
        if toc.is_file() else None
    return m.group(1) if m else "?"


def _toks(path):
    return list(luatok.tokens(luatok.read(path))) if Path(path).is_file() else []


def cap(t):
    """A link type as the header shows it: the addon's rule (npc in capitals, else the first letter)."""
    return t.upper() if t == "npc" else t[:1].upper() + t[1:]


def main_texts(addon):
    """[(kind, text, line)]: the popup's text (the local POPUP_VAR) and its button1."""
    t, out = _toks(Path(addon) / MAIN), []
    for i in range(len(t) - 2):
        if t[i][:2] == (N, POPUP_VAR) and t[i + 1][:2] == (Y, "=") and t[i + 2][0] == S:
            out.append(("popup", t[i + 2][1], t[i][2]))
        if t[i][:2] == (N, "button1") and t[i + 1][:2] == (Y, "=") and t[i + 2][0] == S:
            out.append(("button", t[i + 2][1], t[i][2]))
    return out


def binding_texts(addon):
    """[(kind, text, line)] of each BINDING_NAME_* the addon sets (the header and description are not drawn as ours)."""
    t, out = _toks(Path(addon) / CONFIG), []
    for i in range(len(t) - 2):
        if t[i][0] == N and t[i][1].startswith("BINDING_NAME_") and t[i + 1][:2] == (Y, "=") and t[i + 2][0] == S:
            out.append(("binding", t[i + 2][1], t[i][2]))
    return out


def header_texts(addon):
    """[(kind, text, line)]: the header's template (a string glued to TYPE_VAR) and each link type the strategies
    return as a word (`return <id>, "<type>"`), in the addon's capitalised form; whole headers ("kept")."""
    t, out = _toks(Path(addon) / STRAT), []
    for i in range(len(t) - 2):
        if t[i][0] == S and t[i + 1][:2] == (Y, ".") and t[i + 2][:2] == (Y, ".") and i + 3 < len(t) \
                and t[i + 3][:2] == (N, TYPE_VAR):          # luatok gives `..` as two "." symbols
            out.append(("head", t[i][1] + "%s", t[i][2]))
        if t[i][:2] == (Y, ",") and t[i + 1][0] == S and re.fullmatch(r"[a-z]+", t[i + 1][1]) \
                and (i + 2 >= len(t) or t[i + 2][:2] in ((N, "end"), (N, "return"), (N, "elseif"), (N, "else"))
                     or t[i + 2][2] > t[i + 1][2]):
            j = i - 1           # only after a return on the same statement
            while j >= 0 and t[j][2] == t[i][2] and t[j][:2] != (N, "return"):
                j -= 1
            if j >= 0 and t[j][:2] == (N, "return"):
                out.append(("type", cap(t[i + 1][1]), t[i][2]))
        if t[i][:2] == (N, "return") and t[i + 1][0] == S and t[i + 2][:2] == (Y, ","):
            out.append(("whole", t[i + 1][1], t[i][2]))
    return out


XML_FS = re.compile(r"<FontString\b([^>]*)>", re.S)


def xml_texts(addon):
    """[(kind, text, line)] of each FontString with a text= in the /wql window (the URL line skipped by name)."""
    p = Path(addon) / XML
    if not p.is_file():
        return []
    src, out = p.read_text(encoding="utf-8-sig", errors="replace"), []
    for m in XML_FS.finditer(src):
        attrs = dict(re.findall(r'(\w+)="([^"]*)"', m.group(1)))
        if "text" in attrs and attrs.get("name") != URL_NAME:
            text = attrs["text"].replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">").replace("&quot;", '"')
            out.append(("label", text, src.count("\n", 0, m.start()) + 1))
    return out


PREFIX = {"popup": "Pop.", "head": "Head.", "type": "Type."}


def key_of(kind, en):
    return PREFIX.get(kind, "Code.") + H.djb2(en)


def source(addon):
    """(rows, why). rows: (key, English, batch, [(file, line)], note); why: {reason: count} of the texts left out."""
    addon = Path(addon)
    if not (addon / MAIN).is_file():
        return [], {}
    rows, why, seen = [], {}, set()
    found = [(MAIN, x) for x in main_texts(addon)] + [(STRAT, x) for x in header_texts(addon)] \
        + [(CONFIG, x) for x in binding_texts(addon)] + [(XML, x) for x in xml_texts(addon)]
    for f, (kind, en, line) in found:
        kept, reason = R.keep(kind, en)
        if not kept:
            why[reason] = why.get(reason, 0) + 1
            continue
        key = key_of(kind, en)
        if key in seen:
            continue
        seen.add(key)
        rows.append((key, en, R.batch_of(key), [(f, line)], R.NOTES[kind]))
    return rows, why


def kept_as_is(addon):
    """The hashes of the texts kept as they are (R.FREE kinds): whole site headers and the NPC type."""
    out = set()
    for kind, en, _ in header_texts(addon):
        if R.keep(kind, en)[1] == R.AS_IS:
            out.add(H.djb2(en))
    return out


if __name__ == "__main__":      # prints the English: for a look, never into a tracked file
    a = addon_dir(sys.argv[1] if len(sys.argv) > 1 else None)
    rs, w = source(a)
    for r in rs:
        print(r[0], repr(r[1]), r[3], r[4][:30])
    print(w, sorted(kept_as_is(a)))
