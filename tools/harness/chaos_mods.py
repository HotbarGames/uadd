"""The chaos test's modules: for each UADD_* folder with a harness flow, how to build its game with the flow's
own builder (the stand-in, UADD, the module) and show the addon's windows, so the module has changed texts.

RECIPES: [(module folder, the addon its code is, build)]; build() -> Client, or None when the flow cannot run
here (the addon is not installed). Questie and the Dungeon Journal need the real addons and UALL Forever
(flow.py, flow_dj_module.py): they are left to those flows and named in SKIPPED.
"""
import os

import session

SKIPPED = {"UADD_Questie": "needs the real Questie and UALL Forever (flow.py)",
           "UADD_DungeonJournal": "needs the real ForeverDungeonJournal and UALL Forever (flow_dj_module.py)"}


def _lsw():
    import flow_lsw as F
    c, M = F._game([F.STAND_IN, F._addon("UADD"), F._addon(F.MODULE)])
    M.panel(True)
    M.wait(1.2)
    return c


def _fxpb():
    import flow_fxpb as F
    c, M = F._game([F.STAND_IN, F._addon("UADD"), F._addon(F.MODULE)])
    F._seed(c, M)
    return c


def _auc():
    import flow_auc as F
    c, _ = F._game([F.STAND_IN, F._addon("UADD"), F._addon(F.MODULE)])
    return c


def _ap():
    import flow_autopotion as F
    en = F.english()
    if en is None:
        return None
    c, _ = F._game([F.STAND_IN, F._addon("UADD"), F._addon(F.MODULE)], en)
    return c


def _dui():
    import flow_dialogueui as F
    c, M = F._game([F.STAND_IN, F._uadd(), F._module()])
    M.showAll()
    M.wait(F.WAIT)
    return c


def _bgn():
    import flow_bagnon as F
    import make_bgn_text
    if not make_bgn_text.texts(make_bgn_text.addon_dir())[0]:
        return None
    c, M = F._game([F._stand_in("Bagnon"), F._addon("UADD"), F._addon(F.MODULE), F._stand_in(F.LATER)])
    F._show(M)
    M.open("bank")
    return c


def _mc():
    import flow_mastercraft as F
    src = F.rows()
    if not src:
        return None
    p = F.picks(src, *F.shipped())
    if not p:
        return None
    c, M = F._game([F._stand_in(), F._addon("UADD"), F._addon(F.MODULE)], "enUS", p)
    M.later()
    c.H.pump(5)
    return c


def _wt():
    import flow_whatstraining as F
    src = F.rows()
    if not src:
        return None
    p = F.picks(src, *F.shipped())
    if not p:
        return None
    p["title"] = F.title(F.shipped()[0]) or p["label"]
    c, M = F._game([F._stand_in(), F._addon("UADD"), F._addon(F.MODULE)], "enUS", p)
    M.later()
    c.H.pump(5)
    return c


def _tt():
    import flow_tomtom as F
    src = F.rows()
    if not src:
        return None
    p = F.picks(src, *F.shipped())
    if not p:
        return None
    c, _ = F._game(p)
    return c


def _wp():
    import flow_wp as F
    src = F.rows()
    p = src and F.picks(src, *F.shipped())
    if not p:
        return None
    c, _ = F._game(p)
    return c


def _rs():
    import flow_rarescanner as F
    if not F.installed():
        return None
    c, _ = F._game([F.TARGET])
    return c


def _pawn():
    import flow_pawn_game as F
    if not F.installed():
        return None
    data, _ = F.test_data()
    c, M = F.game(data)
    if hasattr(M, "open"):
        M.open()
    return c


def _gm():
    import flow_gm as F
    if not F.installed():
        return None
    keys, data, _ = F.words()
    c, _ = F.game(keys, data)
    return c


def _scrap():
    import flow_scrap as F
    if not F.installed():
        return None
    code, _ = F.words()
    c, _ = F.game(code)
    return c


def _sal():
    import flow_sal as F
    if not F.installed():
        return None
    c, M = F.game()
    M.show(True)
    return c


def _att():
    import flow_att_game as G
    if not G.libraries_there():
        return None
    c, _ = G.game()
    return c


def _om():
    import flow_openmap as F
    from loader import Client, lua_str, read_text
    c = Client([F.STAND_IN, _repo("UADD"), F.module_addon()], None, "enUS")
    c.lua.execute(read_text(os.path.join(F.HERE, "flow_openmap.lua")))
    c.start()
    c.H.pump(60)
    M = c.H.om
    M.open(lua_str("Second Quest"), lua_str("Second Quest"))
    M.wait(0.6)
    return c


def _repo(name):
    from loader import Addon
    return Addon(name, os.path.join(session.REPO, name), session.FLAVOR)


# (module folder, the addon whose code feeds it, build)
RECIPES = [
    ("UADD_LayerSwap", "LayerSwap", _lsw),
    ("UADD_ForeverXPBar", "ForeverXPbar", _fxpb),
    ("UADD_Auctionator", "Auctionator", _auc),
    ("UADD_AutoPotion", "AutoPotion", _ap),
    ("UADD_DialogueUI", "DialogueUI", _dui),
    ("UADD_Bagnon", "Bagnon", _bgn),
    ("UADD_Mastercraft", "Mastercraft", _mc),
    ("UADD_WhatsTraining", "WhatsTraining", _wt),
    ("UADD_TomTom", "TomTom", _tt),
    ("UADD_WaypointUI", "WaypointUI", _wp),
    ("UADD_RareScanner", "RareScanner", _rs),
    ("UADD_Pawn", "Pawn", _pawn),
    ("UADD_GatherMate2", "GatherMate2", _gm),
    ("UADD_Scrap", "Scrap", _scrap),
    ("UADD_SpeedyAutoLoot", "SpeedyAutoLoot", _sal),
    ("UADD_Attune", "Attune", _att),
    ("UADD_OpenMap", "OpenMap", _om),
]


def folders():
    """Every UADD_* folder in the repo with a TOC."""
    return sorted(d for d in os.listdir(session.REPO)
                  if d.startswith("UADD_") and os.path.isfile(os.path.join(session.REPO, d, d + ".toc")))
