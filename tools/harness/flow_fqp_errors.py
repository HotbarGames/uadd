"""More steps of flow_fqp.py (its names go into flow_fqp_steps.STEPS): after five errors turned the module off and
"/uadd foreverquestpins on", its hooks work again (lesson 19); its quest tracker's "no quest matches the filter"
line (Forever Quest Pins 1.1.8) switches both ways."""
import os

import flow_fqp_steps as S
import session
from loader import lua_str, read_text, txt

S.STEPS.update({
    "guard": "7 after the off for errors, on again: the breadcrumb hook works (ours; an unknown name and an "
             "untitled quest whole English; off whole English), the filter list and the tips ours (lesson 19)",
    "filter": "6 tracker filter-empty line ours, English while held and off, ours again; another text there stays",
})


def guard(check, c, M, K):
    """Run after S.faults: the module is off for errors."""
    off = not M.on()
    M.uadd(lua_str("foreverquestpins on"))
    M.wait(0.3)
    M.known(True)
    full, got = S.body_en(K, "Quix Hunt", "Zorp Trail", "Blatter Vale"), {}
    q = txt(M.word(lua_str("Quest "))) + "5"
    M.setBody(lua_str(full))
    got["full"] = txt(M.body())
    M.setBody(lua_str(S.body_en(K, q, S.STRANGER)))
    got["stranger"] = txt(M.body())
    M.setBody(lua_str(full))
    got["full again"] = txt(M.body())
    M.listEnglish()
    menu, (shown, tips) = M.menu(), M.tips()      # the click's hook makes the list ours again
    on = M.on()
    M.uadd(lua_str("foreverquestpins off"))
    got["off"] = txt(M.body())
    left, tips_off = M.menu()[2], M.tips()[1]
    ok = (off and on and all(S.cyr(got[k]) and not S.latin(got[k]) for k in ("full", "full again"))
          and got["stranger"] == S.body_en(K, "Quest 5", S.STRANGER) and got["off"] == full
          and menu[1] > 0 and menu[2] == menu[1] and shown > 0 and tips == shown and left == 0 and tips_off == 0)
    check(S.STEPS["guard"], ok, {k: v[:90] for k, v in got.items()} | {
        "off for errors, on": (off, on), "list": (menu[1], menu[2], left), "tips": (shown, tips, tips_off)})
    return ok


def tracker(check, M):
    src = read_text(os.path.join(session.addons_dir(), "ForeverQuestPins", "Tracker.lua"))
    src = src if isinstance(src, str) else src.decode("utf-8")
    real = '"fqp-filter-empty", "ObjectiveTrackerBlockTemplate"' in src and '"FQPQuestObjectiveTracker"' in src
    got = []

    def look(): got.append(txt(M.filterText() or ""))  # noqa: E704
    M.filterLine(None)
    look()
    M.hold(True)
    M.wait(1)
    look()
    M.hold(False)
    M.wait(1)
    look()
    M.uadd(lua_str("foreverquestpins off"))
    look()
    M.uadd(lua_str("foreverquestpins on"))
    look()
    M.filterLine(lua_str("Quix Hunt"))
    M.uadd(lua_str("foreverquestpins off"))
    M.uadd(lua_str("foreverquestpins on"))
    look()
    ok = (real and all(S.cyr(got[i]) and not S.latin(got[i]) for i in (0, 2, 4))
          and all(S.latin(got[i]) and not S.cyr(got[i]) for i in (1, 3)) and got[5] == "Quix Hunt")
    check(S.STEPS["filter"], ok, (real, got))
    return ok
