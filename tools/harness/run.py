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
UADD_Mastercraft's checks run next, on a stand-in for Mastercraft (flow_mastercraft.py; «Українська» in its
language menu: flow_mc_lang.py).
UADD_WhatsTraining's checks run next, on a stand-in for What's Training? (flow_whatstraining.py).
UADD_TomTom's checks run next, on a stand-in for TomTom (flow_tomtom.py; the arrow title's font: flow_tomtom_arrow.py).
UADD_RareScanner's checks run next, on a stand-in for RareScanner (flow_rarescanner.py).
UADD_Pawn's checks run next, on a stand-in for Pawn that runs Pawn's own locale files (flow_pawn.py).
UADD_GatherMate2's checks run next, on a stand-in for GatherMate2 that runs GatherMate2's own libraries and
locale files (flow_gm.py).
UADD_Scrap's checks run next, on stand-ins for Scrap and its two load-on-demand parts that run Scrap's own
locale file (flow_scrap.py).
UADD_SpeedyAutoLoot's checks run next, on a stand-in for Speedy AutoLoot that runs its own two files (flow_sal.py).
UADD/Missed.lua's checks (texts noted in English, flow_missed.py) run next, on the LayerSwap stand-in.
UADD/Hash.lua's checks (texts by hash, flow_hash.py) run next.
ClassicUA as the first name source (flow_classicua.py, lesson 25: its zone hook is a harness stand-in that calls
ClassicUA's real options and glossary) runs next, then the key notice (flow_keynotice.py).
The keyboard check (flow_focus.py: every stand-in and the modules that load with them; after login no text
box has the keyboard, docs/LESSONS2.md lesson 16) runs next.
The safeguards (flow_safe.py: a failing module falls back to English, the guard puts game-wide breakage
right, lesson 19) run last; `python3 tools/harness/flow_safe.py --prove` shows each step fail without its fix.
After each of these, "tooltip font object back after clear: <key>" (tipfont.py, wow_fontfam.lua, lesson 18):
no tooltip line that UADD pinned to a font file stays pinned once the tooltip is cleared.
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
import tipfont  # noqa: E402


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
    import flow_mc_lang
    import flow_tomtom
    import flow_tomtom_arrow
    import flow_rarescanner
    import flow_pawn
    import flow_gm
    import flow_scrap
    import flow_sal
    import flow_dialogueui
    import flow_dj_module
    import flow_classicua
    import flow_keynotice
    import flow_focus
    import chaos
    import flow_fxpb
    import flow_hash
    import flow_lsw
    import flow_missed
    import flow_safe
    import flow_whatstraining
    tipfont.take()
    f = flow.run()
    checks, facts, notes = list(f.checks), dict(f.facts), []
    del f
    checks += tipfont.segment("main", flow.Check)
    gc.collect()                       # the main flow's games go before the journal's starts
    missing = flow_dj_module.missing_addons()
    if missing:
        notes.append("dj module checks skipped: missing addons: " + ", ".join(missing))
    else:
        dj_checks, dj_facts = flow_dj_module.run()
        checks += dj_checks + tipfont.segment("dj", flow.Check)
        facts["dj_module"] = dj_facts
        gc.collect()
    # (facts key, flow module), in run order; each also gets the tooltip font check (tipfont.py)
    for key, mod in (("dialogueui", flow_dialogueui), ("fxpb", flow_fxpb), ("auc", flow_auc), ("att", flow_att),
                     ("lsw", flow_lsw), ("ap", flow_autopotion), ("bgn", flow_bagnon), ("mc", flow_mastercraft),
                     ("mcl", flow_mc_lang), ("wt", flow_whatstraining), ("tt", flow_tomtom), ("tta", flow_tomtom_arrow), ("rs", flow_rarescanner), ("pawn", flow_pawn),
                     ("gm", flow_gm), ("scrap", flow_scrap), ("sal", flow_sal), ("missed", flow_missed),
                     ("hash", flow_hash), ("cua", flow_classicua), ("keynotice", flow_keynotice),
                     ("focus", flow_focus), ("safe", flow_safe),
                     ("chaos", chaos)):
        seg_checks, seg_facts = mod.run_checks()
        checks += seg_checks + tipfont.segment(key, flow.Check)
        facts[key] = seg_facts
        gc.collect()
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
