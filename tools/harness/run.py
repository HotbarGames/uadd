"""Runs the flow checks and prints each one. Usage: python3 tools/harness/run.py

Needs lupa (pip install lupa) and the Forever AddOns folder (UADD_ADDONS_DIR overrides it).
The Dungeon Journal module's checks (flow_dj_module.py) run after the main flow when
ForeverDungeonJournal and UALLF are in that folder; otherwise they are skipped with a note.
UADD_OpenMap's checks run with them, on a stand-in for OpenMap (flow_openmap.py).
UADD_DialogueUI's checks run next, on a stand-in for DialogueUI (flow_dialogueui.py).
UADD_ForeverXPBar's checks run next, on a stand-in for ForeverXP Bar (flow_fxpb.py).
UADD_Auctionator's checks run next, on a stand-in for Auctionator (flow_auc.py).
UADD_Attune's checks run next, on a stand-in for Attune (flow_att.py).
UADD_LayerSwap's checks run next, on a stand-in for LayerSwap (flow_lsw.py).
UADD_AutoPotion's checks run next, on a stand-in for Auto Potion (flow_autopotion.py).
UADD_Bagnon's checks run next, on stand-ins for Bagnon and Bagnon_Config (flow_bagnon.py).
UADD_Mastercraft's checks run next, on a stand-in for Mastercraft (flow_mastercraft.py).
UADD_WhatsTraining's checks run next, on a stand-in for What's Training? (flow_whatstraining.py).
UADD_TomTom's checks run next, on a stand-in for TomTom (flow_tomtom.py).
UADD_RareScanner's checks run next, on a stand-in for RareScanner (flow_rarescanner.py).
UADD_Pawn's checks run next, on a stand-in for Pawn that runs Pawn's own locale files (flow_pawn.py).
UADD_GatherMate2's checks run next, on a stand-in for GatherMate2 that runs GatherMate2's own libraries and
locale files (flow_gm.py).
UADD_Scrap's checks run next, on stand-ins for Scrap and its two load-on-demand parts that run Scrap's own
locale file (flow_scrap.py).
UADD_SpeedyAutoLoot's checks run next, on a stand-in for Speedy AutoLoot that runs its own two files (flow_sal.py).
UADD/Missed.lua's checks (texts noted in English, flow_missed.py) run next, on the LayerSwap stand-in.
UADD/Hash.lua's checks (texts by hash, flow_hash.py) run last.
Each module's flow also runs the half-translation check (halves.py, halves_mods.py); a module in
halves_cover.COVERED whose flow gave no "no half-translated line: <module>" result fails here.
Exit code 0 = every check passed, 1 = a check failed, 2 = cannot run here.
"""
import gc
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import halves_cover  # noqa: E402
import loader  # noqa: E402
import session  # noqa: E402


def halves_guard(checks, skipped=()):
    """[(name, detail)]: one per module in halves_cover.COVERED (not skipped) with no half-translation
    result among the checks, so a flow that stops calling its check cannot pass quietly."""
    return [(f"half-translation check ran: {mod}", "its flow gave no 'no half-translated line' result")
            for mod in halves_cover.COVERED if mod not in skipped
            and not any(f"no half-translated line: {mod} " in c.name for c in checks)]


def run_all():
    """Every flow, one after another. Returns (checks, facts, notes)."""
    import flow
    import flow_att
    import flow_auc
    import flow_autopotion
    import flow_bagnon
    import flow_mastercraft
    import flow_tomtom
    import flow_rarescanner
    import flow_pawn
    import flow_gm
    import flow_scrap
    import flow_sal
    import flow_dialogueui
    import flow_dj_module
    import flow_fxpb
    import flow_hash
    import flow_lsw
    import flow_missed
    import flow_whatstraining
    f = flow.run()
    checks, facts, notes = list(f.checks), dict(f.facts), []
    del f
    gc.collect()                       # the main flow's games go before the journal's starts
    missing = flow_dj_module.missing_addons()
    if missing:
        notes.append("dj module checks skipped: missing addons: " + ", ".join(missing))
    else:
        dj_checks, dj_facts = flow_dj_module.run()
        checks += dj_checks
        facts["dj_module"] = dj_facts
        gc.collect()
    dui_checks, dui_facts = flow_dialogueui.run_checks()
    checks += dui_checks
    facts["dialogueui"] = dui_facts
    gc.collect()
    fx_checks, fx_facts = flow_fxpb.run_checks()
    checks += fx_checks
    facts["fxpb"] = fx_facts
    gc.collect()
    auc_checks, auc_facts = flow_auc.run_checks()
    checks += auc_checks
    facts["auc"] = auc_facts
    gc.collect()
    att_checks, att_facts = flow_att.run_checks()
    checks += att_checks
    facts["att"] = att_facts
    gc.collect()
    lsw_checks, lsw_facts = flow_lsw.run_checks()
    checks += lsw_checks
    facts["lsw"] = lsw_facts
    gc.collect()
    ap_checks, ap_facts = flow_autopotion.run_checks()
    checks += ap_checks
    facts["ap"] = ap_facts
    gc.collect()
    bgn_checks, bgn_facts = flow_bagnon.run_checks()
    checks += bgn_checks
    facts["bgn"] = bgn_facts
    gc.collect()
    mc_checks, mc_facts = flow_mastercraft.run_checks()
    checks += mc_checks
    facts["mc"] = mc_facts
    gc.collect()
    wt_checks, wt_facts = flow_whatstraining.run_checks()
    checks += wt_checks
    facts["wt"] = wt_facts
    gc.collect()
    tt_checks, tt_facts = flow_tomtom.run_checks()
    checks += tt_checks
    facts["tt"] = tt_facts
    gc.collect()
    rs_checks, rs_facts = flow_rarescanner.run_checks()
    checks += rs_checks
    facts["rs"] = rs_facts
    gc.collect()
    pawn_checks, pawn_facts = flow_pawn.run_checks()
    checks += pawn_checks
    facts["pawn"] = pawn_facts
    gc.collect()
    gm_checks, gm_facts = flow_gm.run_checks()
    checks += gm_checks
    facts["gm"] = gm_facts
    gc.collect()
    sc_checks, sc_facts = flow_scrap.run_checks()
    checks += sc_checks
    facts["scrap"] = sc_facts
    gc.collect()
    sal_checks, sal_facts = flow_sal.run_checks()
    checks += sal_checks
    facts["sal"] = sal_facts
    gc.collect()
    miss_checks, miss_facts = flow_missed.run_checks()
    checks += miss_checks
    facts["missed"] = miss_facts
    gc.collect()
    hash_checks, hash_facts = flow_hash.run_checks()
    checks += hash_checks
    facts["hash"] = hash_facts
    skipped = ["UADD_OpenMap"] if missing else []      # its flow runs with the journal's
    checks += [flow.Check(name, False, why) for name, why in halves_guard(checks, skipped)]
    return checks, facts, notes


def main():
    if loader.lua_runtime() is None:
        print("cannot run: lupa is not installed (pip install lupa)")
        return 2
    missing = session.missing_addons()
    if missing:
        print("cannot run: missing addons: " + ", ".join(missing))
        return 2
    t0 = time.time()
    checks, facts, notes = run_all()
    bad = [c for c in checks if not c.ok]
    for c in checks:
        print(("ok    " if c.ok else "FAIL  ") + c.name + (f"  [{c.detail}]" if c.detail else ""))
    for n in notes:
        print("note  " + n)
    print(json.dumps(facts, ensure_ascii=False))
    print(f"{len(checks) - len(bad)}/{len(checks)} passed in {time.time() - t0:.0f} s")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
