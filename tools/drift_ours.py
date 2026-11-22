"""The words our data names, for tools/drift.py: what names a text (its key, the hash of its English) when
local/drift/base.json does not hold the record, and for the --update-versions guard (lesson 42)."""
import re

from drift_sources import MODULES, REPO


def our_lines(mod):
    paths = sorted((REPO / mod).rglob("*.lua"))
    for extra in MODULES[mod][3]:
        paths += sorted((REPO / extra).glob("uk_*.lua"))
    return [ln.strip() for p in paths for ln in p.read_text(encoding="utf-8", errors="replace").splitlines()]


def our_terms(lines):
    """Every quoted string, word and hash in our data: what names a text (its key, its English hash)."""
    text = "\n".join(lines)
    quoted = set(re.findall(r'"((?:[^"\\]|\\.)*)"', text))
    # A key is matched as the addon shows it too: Lua's \n, \t, \" and \\ read as the letters they stand for.
    esc = {"n": "\n", "t": "\t", '"': '"', "'": "'", "\\": "\\"}
    quoted |= {re.sub(r"\\(.)", lambda m: esc.get(m.group(1), m.group(0)), q) for q in quoted if "\\" in q}
    return (quoted | set(re.findall(r"[A-Za-z_]\w*", text))
            | set(re.findall(r"\d+:[0-9a-f]{8}|(?<![0-9a-f])[0-9a-f]{8}(?![0-9a-f])", text)))


def named(terms, row, allowed=False):
    """True when our data names the row: by its key, the hash of its English, or (allowed addons) its English."""
    import hashtext as H
    tag, key, en, _ = row
    found = {H.key(en), H.djb2(en)} | ({key, H.key(key), H.djb2(key)} if key else set()) | ({en} if allowed else set())
    return bool(found & terms)
