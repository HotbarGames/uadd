"""Font facts for tools/scan_addon.py: which Cyrillic letters a .ttf/.otf file has (its cmap, read with the
standard library), and what is known about the game's own font files.

cyr_status(bytes) is "uk" (А-я and і ї є ґ), "ru-only" (А-я, no Ukrainian letters), "none" or "unreadable".
"""
import re
import struct

RU = range(0x410, 0x450)
UK = (0x456, 0x457, 0x454, 0x491)
# The game's own files. The English client's default font (FRIZQT__) has no Cyrillic; UADD's candidates
# (UADD/Font.lua) are FRIZQT___CYR and ARIALN. Other files live in the game archive: unknown here.
GAME_CYR = {"FRIZQT___CYR.TTF", "ARIALN.TTF", "MORPHEUS_CYR.TTF", "SKURRI_CYR.TTF"}
GAME_LATIN = {"FRIZQT__.TTF", "MORPHEUS.TTF", "SKURRI.TTF"}


def _fmt4(d, o, want):
    seg = struct.unpack_from(">H", d, o + 6)[0] // 2
    ends, starts = o + 14, o + 16 + seg * 2
    deltas, ranges = starts + seg * 2, starts + seg * 4
    have = set()
    for k in range(seg):
        end, start = struct.unpack_from(">H", d, ends + k * 2)[0], struct.unpack_from(">H", d, starts + k * 2)[0]
        delta, roff = struct.unpack_from(">h", d, deltas + k * 2)[0], struct.unpack_from(">H", d, ranges + k * 2)[0]
        for c in want:
            if start <= c <= end:
                if roff == 0:
                    g = (c + delta) & 0xFFFF
                else:
                    at = ranges + k * 2 + roff + (c - start) * 2
                    g = struct.unpack_from(">H", d, at)[0] if at + 2 <= len(d) else 0
                    g = (g + delta) & 0xFFFF if g else 0
                if g:
                    have.add(c)
    return have


def _fmt12(d, o, want):
    n = struct.unpack_from(">I", d, o + 12)[0]
    have = set()
    for k in range(n):
        start, end, _ = struct.unpack_from(">III", d, o + 16 + k * 12)
        have.update(c for c in want if start <= c <= end)
    return have


def chars(data, want):
    """The code points of want that the font maps to a glyph, or None when the file cannot be read."""
    try:
        base = 0
        if data[:4] == b"ttcf":
            base = struct.unpack_from(">I", data, 12)[0]
        ntab = struct.unpack_from(">H", data, base + 4)[0]
        cmap = None
        for k in range(ntab):
            tag, _, off, _ = struct.unpack_from(">4sIII", data, base + 12 + k * 16)
            if tag == b"cmap":
                cmap = off
        if cmap is None:
            return None
        have, nrec = set(), struct.unpack_from(">H", data, cmap + 2)[0]
        for k in range(nrec):
            plat, enc, off = struct.unpack_from(">HHI", data, cmap + 4 + k * 8)
            if (plat, enc) not in ((3, 1), (3, 10)) and plat != 0:
                continue
            fmt = struct.unpack_from(">H", data, cmap + off)[0]
            if fmt == 4:
                have |= _fmt4(data, cmap + off, want)
            elif fmt == 12:
                have |= _fmt12(data, cmap + off, want)
        return have
    except (struct.error, IndexError):
        return None


def cyr_status(data):
    want = list(RU) + list(UK)
    have = chars(data, want)
    if have is None:
        return "unreadable"
    if not any(c in have for c in RU):
        return "none"
    return "uk" if all(c in have for c in UK) else "ru-only"


def game_file(path):
    """For a font path outside the addon: 'game cyr', 'game latin-only' or 'game unknown'."""
    name = re.split(r"[\\/]", path)[-1].upper()
    if name in GAME_CYR:
        return "game cyr"
    if name in GAME_LATIN:
        return "game latin-only"
    return "game unknown"
