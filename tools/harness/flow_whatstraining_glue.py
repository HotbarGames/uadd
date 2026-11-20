"""UADD_WhatsTraining: section headers What's Training? glues in code, " • " and a count after its own title
(Forever/Views.lua: the list's "<title> • <count>", the levels view's "<level> • <title>", its count font
string " • <n spells>"; Forever/Layout.lua: "<title> • <continued>"; SECTION_COUNT elsewhere). The owner saw
them English in the game (2026-11-20): the data had no Ukrainian for the glue templates.

The titles are read from the installed What's Training? (its locale keys), never written here. Each line is
made the way the addon makes it, on a font string under its window (the stand-in, tools/harness/whatstraining).

  glue 1: each header is all ours (glued with " — ": the Cyrillic font may have no "•"), the count kept as it
          is, in our font (read back).
  glue 2: anything unknown glued on (a title or a tail we have no Ukrainian for): the whole line English.
  glue 3: /uadd whatstraining off: every line its English again; on: ours again.
"""
import flow_whatstraining as fw
import hashtext
from flow_whatstraining_texts import CYR
from loader import lua_str, txt

UNKNOWN = "Quix Gloom"           # made up: no text of ours
SEP = " — "                      # our glue: the Cyrillic font may have no "•" (tools/test_font_chars.py)
STUB = """
local G = { fs = {} }
HARNESS.wtGlue = G
function G.make(key, text)
    local fs = WhatsTrainingFrame:CreateFontString(nil, "OVERLAY")
    fs:SetFont(WhatsTrainingStandIn.PATH, 12, "")
    fs:SetText(text)
    G.fs[key] = fs
end
function G.shown(key) return G.fs[key]:GetText() or "" end
function G.cyr(key) return UADD.IsCyrFont((G.fs[key]:GetFont())) and true or false end
"""
KEYS = ("AVAILABLE_HEADER", "MISSINGREQS_HEADER", "IGNORED_HEADER", "NEXTLEVEL_HEADER", "CONTINUED",
        "LEVEL_FORMAT", "LEVELS_SPELLS_COUNT")


def _english():
    """{locale key: What's Training?'s English} for KEYS, from the installed addon; None when not there."""
    try:
        import make_wt_text as mk
        names = mk.source(mk.addon_dir())[1]
    except Exception:
        return None
    en = {k: e for e, k in names.items() if k in KEYS}
    return en if len(en) == len(KEYS) else None


def lines(M, en):
    """{key: (English as What's Training? glues it, our Ukrainian for it or None: stays English)}."""
    def uk(e):
        u = txt(M.want(lua_str(hashtext.key(e))) or "")
        return u if CYR.search(u) else None

    def fill(e, *vals):
        return txt(M.fill(lua_str(hashtext.key(e)), *map(lua_str, vals)) or "") or None
    av, miss, ign = en["AVAILABLE_HEADER"], en["MISSINGREQS_HEADER"], en["IGNORED_HEADER"]
    level = en["LEVEL_FORMAT"] % "10"
    return {
        "ledger": (f"{av} • 12", f"{uk(av)}{SEP}12"),                                # Views.lua renderLedger
        "ledger2": (f"{miss} • 21", f"{uk(miss)}{SEP}21"),
        "section": (f"{ign} • 3", f"{uk(ign)}{SEP}3"),                               # SECTION_COUNT
        "continued": (f"{av} • {en['CONTINUED']}", f"{uk(av)}{SEP}{uk(en['CONTINUED'])}"),   # Layout.lua
        "level": (f"{level} • {en['NEXTLEVEL_HEADER']}",                             # Views.lua groupTitle
                  f"{fill(en['LEVEL_FORMAT'], '10')}{SEP}{uk(en['NEXTLEVEL_HEADER'])}"),
        "count": (" • " + en["LEVELS_SPELLS_COUNT"] % 12,                            # Views.lua header.count
                  SEP + str(fill(en["LEVELS_SPELLS_COUNT"], "12"))),
        "odd1": (f"{UNKNOWN} • 12", None),
        "odd2": (f"{av} • {UNKNOWN}", None),
        "odd3": (f"{UNKNOWN} • {en['CONTINUED']}", None),
        "odd4": (f" • {UNKNOWN}", None),
        "odd5": (f"{av} • 12 {UNKNOWN}", None),
    }


def run(check, facts):
    en = _english()
    if not en:
        return check("glue: section headers (skipped: What's Training? not installed)", True, "")
    c, M = fw._game([fw._stand_in(), fw._addon("UADD"), fw._addon(fw.MODULE)], "enUS")
    c.lua.execute(STUB)
    G = c.H.wtGlue
    want = lines(M, en)
    for key, (e, _) in want.items():
        G.make(key, lua_str(e))
    M.wait(0.1)

    def shown():
        return {k: txt(G.shown(k)) for k in want}
    ours = {k: u for k, (e, u) in want.items() if u is not None}
    now = shown()
    bad = {k: (now[k], u) for k, u in ours.items() if now[k] != u or "None" in u or not G.cyr(k)}
    check("glue 1: section headers glued to a count or a tail: all ours, the count kept, in our font",
          not bad and len(ours) == 6, bad)
    odd = {k: now[k] for k, (e, u) in want.items() if u is None and now[k] != e}
    check("glue 2: an unknown title or tail glued on: the whole line English", not odd, odd)
    M.uadd("whatstraining off")
    M.wait(0.1)
    off = shown()
    back = {k: off[k] for k, (e, _) in want.items() if off[k] != e}
    M.uadd("whatstraining on")
    M.wait(0.1)
    again = shown()
    check("glue 3: off: every header English; on: ours again",
          not back and all(again[k] == u for k, u in ours.items()), (back, {k: again[k] for k in ours}))
    fw._errors(c, check, "glue")
