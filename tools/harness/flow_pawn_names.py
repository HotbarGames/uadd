"""UADD_Pawn/Game.lua: the game's stat names in Pawn's stat list come from UALL Forever (lesson 9).

The game is flow_pawn_game's (the installed Pawn's locale files under the stand-in), plus a stat list shaped like
Pawn's (flow_pawn_names.lua). A few of the game's own stat names (the client's global strings, not Pawn's) hold
their English; UALL Forever's answers come from a stand-in for UADD.UALL.Text, set after login:

  * a name it has: Ukrainian in the list, and the lines built from it ("1 <name> is worth:", "<name> (unusable)")
    whole Ukrainian; a name it lacks: those lines whole English; "not now": English, then Ukrainian a little later;
  * the hold key and "/uadd pawn off": every row and line English again, Ukrainian after.
Called from flow_pawn.run.
"""
import os

import session
from flow_pawn_game import HERE, MODULE, TARGET, PawnClient, cyr
from loader import Addon, lua_str, read_text, txt

# The client's global strings for a few stats (game text, not Pawn's), set before Pawn's UIStrings.lua reads them.
GAME = {"STAT_CATEGORY_ATTRIBUTES": "Attributes", "STAT_CATEGORY_ENHANCEMENTS": "Enhancements",
        "SPELL_STAT1_NAME": "Strength", "SPELL_STAT2_NAME": "Agility", "ITEM_MOD_HIT_RATING_SHORT": "Hit"}
UK = {"Attributes": "Характеристики тест", "Strength": "Сила тест", "Agility": "Спритність тест"}

STUB = r"""
local M = HARNESS.pawn
function M.say(en, uk, later) M.names[en] = uk; M.later[en] = later or nil end
"""


class NamesClient(PawnClient):
    """The stat list goes in right after Pawn's files ran (PawnStats and PawnUIFrame exist), before UADD_Pawn."""

    def run_addon_files(self, a):
        super().run_addon_files(a)
        if a.name == TARGET:
            self.lua.execute(read_text(os.path.join(HERE, "flow_pawn_names.lua")))
            self.lua.execute(STUB)


def game(data):
    addons = [Addon(TARGET, os.path.join(HERE, "pawn"), session.FLAVOR)]
    addons += [Addon(n, os.path.join(session.REPO, n), session.FLAVOR) for n in ("UADD", MODULE)]
    c = NamesClient(addons, None, "enUS")
    c.lua.execute("\n".join(f'{k} = "{v}"' for k, v in GAME.items()))
    c.lua.execute(read_text(os.path.join(HERE, "flow_pawn.lua")))
    M = c.H.pawn
    for p, (uk, s) in data.items():
        M.put(lua_str(p), lua_str(uk), s)
    c.start()
    c.H.pump(60)
    M.stub()
    return c, M


def lines(M, rows):
    return {k: txt(M.line(i)) for k, i in rows.items()}


def run(check, data):
    c, M = game(data)
    s, ag, hit = M.row("Strength")[0], M.row("Agility")[0], M.row("HitRating")[0]
    att, enh = M.header("Attributes"), M.header("Enhancements")
    if not all((s, ag, hit, att, enh)):
        check("names: the stat rows the flow needs are there", False, [s, ag, hit, att, enh])
        return
    rows = {"att": att, "enh": enh, "s": s, "ag": ag, "hit": hit}
    for en, uk in UK.items():
        M.say(lua_str(en), lua_str(uk), en == "Agility")
    unusable_en, worth_en = txt(M.english("Unusable")), txt(M.english("StatNameText"))
    M.open()
    got = lines(M, rows)
    want = {"att": UK["Attributes"], "enh": "Enhancements", "s": "  " + UK["Strength"], "ag": "  Agility",
            "hit": "  Hit"}
    check("names: UALL Forever's name in the list (headers too); a name it lacks, or 'not now', stays English",
          got == want, {"got": got, "want": want})
    M.say(lua_str("Agility"), lua_str(UK["Agility"]))
    M.wait(2.5)
    got = txt(M.line(ag))
    check("names: after 'not now', asked again a little later", got == "  " + UK["Agility"], got)

    M.select(s)
    uk_label = txt(M.label())
    M.select(hit)
    en_label = txt(M.label())
    check("names: '1 <name> is worth:' whole Ukrainian with UALL Forever's name, whole English without",
          UK["Strength"] in (uk_label or "") and cyr((uk_label or "").replace(UK["Strength"], ""))
          and uk_label != worth_en.replace("%s", UK["Strength"]) and en_label == worth_en.replace("%s", "Hit"),
          {"uk": uk_label, "en": en_label})

    M.ignore("Strength", True)
    M.ignore("HitRating", True)
    M.refresh()
    got = lines(M, {"s": s, "hit": hit})
    ok = (got["s"].startswith("  " + UK["Strength"] + " ") and unusable_en not in got["s"] and cyr(got["s"][-4:])
          and got["hit"] == "  Hit " + unusable_en)
    check("names: '<name> (unusable)' whole Ukrainian with UALL Forever's name, whole English without", ok, got)

    M.select(s)
    english = {"att": "Attributes", "enh": "Enhancements", "s": "  Strength " + unusable_en, "ag": "  Agility",
               "hit": "  Hit " + unusable_en}
    bad = []
    for how in ("hold", "release", "off", "on"):
        if how in ("hold", "release"):
            M.key(how == "hold")
        else:
            M.uadd(lua_str("pawn " + how))
        got, label, name = lines(M, rows), txt(M.label()), txt(M.rowName(s))
        if how in ("hold", "off"):
            ok = got == english and name == "Strength" and label == worth_en.replace("%s", "Strength")
        else:
            ok = got["s"].startswith("  " + UK["Strength"]) and name == UK["Strength"] and label == uk_label
        if not ok:
            bad.append((how, got, label, name))
    check("names: hold key and off give every row and line English; release and on give UALL Forever's again",
          not bad, bad[:2])
    errs = c.errors()
    check("names: no Lua errors", not errs, "; ".join(f"{w}: {m[:160]}" for w, m, _ in errs[:3]))
