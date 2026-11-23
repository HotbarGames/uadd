"""The chaos test's module builders, part 2 (chaos_mods.py imports them for its RECIPES): the modules whose flow
gives a game() or _game() builder that runs only when the addon (or its libraries) is installed. Each returns
the Client with the addon's windows shown, or None when the flow cannot run here."""


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


def _lm():
    import flow_litemount as F
    if not F.installed():
        return None
    c, M = F._game()
    M.showAdd()
    return c


def _sal():
    import flow_sal as F
    if not F.installed():
        return None
    c, M = F.game()
    M.show(True)
    return c


def _wtw():
    import flow_wtw as F
    if not (F.installed() and F.module_there()):
        return None
    c, _ = F.game()
    return c


def _lt():
    import flow_lt as F
    if not (F.installed() and F.module_there()):
        return None
    c, _ = F.game()
    return c


def _dci():
    import flow_dci as F
    if not (F.installed() and F.module_there()):
        return None
    c, _ = F.game()
    return c


def _wql():
    import flow_wql as F
    if not (F.installed() and F.module_there()):
        return None
    c, _ = F.game()           # the /wql window open and an item's link popup shown
    return c


def _bs():                    # the sack window open (session label, tabs, options) and the send popup shown
    import flow_bs as F
    c, M = F.game() if F.installed() and F.module_there() else (None, None)
    return (M.popup(), c)[1] if M else None


def _gq():                    # its window, guide page and Orders rows shown (flow_gq.game)
    import flow_gq as F
    return F.game()[0] if F.installed() and F.module_there() else None


def _att():
    import flow_att_game as G
    if not G.libraries_there():
        return None
    c, _ = G.game()
    return c


def _rts():
    """Road to Sixty: the harness stand-in (tools/harness/rts/) with the module; its map, compare and news
    windows shown, so the module has changed texts (the news window stays English, lesson 43)."""
    import flow_rts as F
    if not F.module_there():
        return None
    c, M = F.game(True)
    S = M.stand()
    S.OpenMap()
    S.OpenCompare()
    S.OpenNews()
    M.wait(0.5)
    return c
