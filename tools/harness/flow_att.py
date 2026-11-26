"""UADD_Attune on a stand-in for Attune (tools/harness/attune: its AttuneLang words, Attune_Data rows,
the main window with its tree and step boxes, the Next window, the quest panels, the four dialogs, the
settings, the minimap button and the [Attune] chat lines), run on the real libraries of the installed
Attune (read only). Names come from a UALL stand-in (flow_att.lua). Run by run.py after the others.

  * Game D (no module): the same player actions (flow_att_game.player) give the English, the fonts,
    the saved tables, what goes to other players and the export string to compare with.
  * Game A (enUS): English with no error before the names; every surface in Ukrainian after them
    (flow_att_more.py), boxes and lists made late on their first draw; the saved tables, the values
    Attune compares, the guild announce, addon messages and the export string as in game D; no field
    or method of a frame the module did not make changed; Shift and "/uadd attune off" (exact English
    and fonts, chat unwrapped) and on; combat (no UALL call, no search); the cost of bag updates and
    of picking an attunement again; the step box sizes.
  * Game B: a German client (no hooks at all).
  * Game C: no Attune (the module waits).
"""
import collections
import gc
import statistics
import sys

import clock
import flow_att_game as G
import flow_att_fix
import flow_att_more
import session
from loader import txt

HELD = 0.4                      # the hold key counts after 0.25 s
BURST = 50                      # bag updates and picks in the cost burst
SELECT_BUDGET_MS, BAG_BUDGET_MS = 3.0, 3.0
COST_RUNS = 3                   # bursts timed; the best counts
WHERE = [("title",), ("status",), ("survey",), ("nextTitle",), ("sync",), ("node", "20"), ("node", "30"),
         ("node", "115"), ("type", "20"), ("type", "30"), ("tree", "RAIDS"), ("tree", "COMPLETED"),
         ("tree", "Will not do"), ("tree", "20"), ("tree", "160"), ("next", 1), ("next", 2), ("next", 3),
         ("results", "head2"), ("reward", "title"), ("detail", "title"), ("detail", "giver"), ("menu", "guild"),
         ("popup", "EXPORT_ATTUNE_GUILD", "text"), ("popup", "SYNC_ATTUNE", "text"),
         ("popup", "SYNC_CONFIRM", "button1"), ("popup", "ATTUNE_SHOW_URL", "editBox")]
read = flow_att_more.read


def _font(M, w):
    f = M.font("popup", M.popupOf(w[1]), w[2]) if w[0] == "popup" else M.font(*w)
    return None if f is None else (txt(f[0]), f[1], txt(f[2]))


def shown(M):
    return {w: (read(M, w), _font(M, w)) for w in WHERE}


def before(M):
    """Before the names: the window open on Molten Core. Returns the box texts."""
    M.open()
    M.select("20")
    M.wait(0.1)
    return {sid: txt(M.text("node", sid)) for sid in ("30", "40", "45")}


def game_d():
    c, M = G.game(module=False)
    d = {"pre": before(M)}
    M.wait(6)
    d["seen"] = G.player(M)
    d["shown"], d["snaps"], d["sent"] = shown(M), G.snaps(M), txt(M.sentAll())
    d["export"], d["slash"] = txt(M.si("export")), txt(M.si("slash"))
    d["picked"] = [txt(x) for x in M.si("picked").values()]
    d["errors"] = [f"{w}: {str(m)[:160]}" for w, m, _ in c.errors()]
    del c, M
    return d


def game_a(check, facts, d):
    c, M = G.game()
    Cyr = c.lua.globals().UADD.IsCyrFont
    w = flow_att_more.Want(M)
    pre = before(M)
    check("before the names: English names, as without the module", pre == d["pre"], f"{pre} | {d['pre']}")
    G.errors(c, check, "before the names")
    M.stubUall()
    M.uallReadyNow(True)
    M.uadd("attune rebuild")
    M.wait(6)
    check("names asked outside combat", M.uallIn("out") > 0 and M.uallIn("combat") == 0, (M.uallIn("out"), M.uallIn("combat")))
    seen = G.player(M)
    chat = [txt(x) for x in c.H.chat.values()]
    flow_att_more.surfaces(check, M, seen, w, chat)
    check("box: Cyrillic font, size 11 kept", Cyr(M.font("node", "20")[0]) and M.font("node", "20")[1] == 11, M.font("node", "20"))
    # Nothing written, nothing sent in Ukrainian.
    for name, snap in G.snaps(M).items():
        check(f"{name} as in game D", snap == d["snaps"][name], f"{len(snap)} vs {len(d['snaps'][name])} chars")
    check("sent to other players as in game D (guild announce, addon messages)", txt(M.sentAll()) == d["sent"],
          txt(M.sentAll())[:200])
    check("export string as in game D", txt(M.si("export")) == d["export"], txt(M.si("export")))
    check("slash word as in game D", txt(M.si("slash")) == d["slash"], txt(M.si("slash")))
    picked = [txt(x) for x in M.si("picked").values()]
    check("tree values Attune compares as in game D", picked == d["picked"], f"{picked} | {d['picked']}")
    check("value compares: group, expansion, Completed, Will not do",
          (txt(M.si("group")), txt(M.si("expac")), M.si("archived"), M.si("willnotdo")) ==
          ("RAIDS", "World of Warcraft", True, True), (M.si("group"), M.si("expac"), M.si("archived"), M.si("willnotdo")))
    types = [txt(M.typeOf(a, s)) for a, s in (("20", "30"), ("30", "30"), ("30", "115"), ("20", "40"))]
    check("stored step TYPE stays English", types == ["Pick Up", "Kill", "Interact", "Item"], types)
    # Shift: the exact English; up again: ours.
    want = {k: v[0] for k, v in d["shown"].items()}
    M.key(True)
    M.wait(HELD)
    got = {k: v[0] for k, v in shown(M).items()}
    bad = [f"{k}: {got[k]!r} | {want[k]!r}" for k in WHERE if got[k] != want[k]]
    check("Shift held: every text exact English", not bad, bad[:3])
    M.key(False)
    M.wait(0.1)
    ours = shown(M)
    check("Shift up: ours again", ours[("node", "20")][0] == w.uk("Quest", "Warlord's Command")
          and ours[("tree", "RAIDS")][0] == "|cffA0A0A0" + w.t("Raids") + "|r", ours[("node", "20")])
    # Off: exact English and fonts, chat unwrapped; on again.
    M.uadd("attune off")
    got = shown(M)
    bad = [f"{k}: {got[k]!r} | {d['shown'][k]!r}" for k in WHERE if got[k] != d["shown"][k]]
    check("off: every text and font exact English", not bad, bad[:3])
    check("off: chat unwrapped, no font of ours left", M.chatPutBack() and not M.chatActive() and M.fontCount() == 0,
          (M.chatPutBack(), M.chatActive(), M.fontCount()))
    M.slash("help")
    check("off: chat line exact English", txt(M.chat()) == flow_att_more.P + w.en("Help1"), txt(M.chat()))
    M.select("20")
    check("off: a new draw stays English", txt(M.text("node", "30")) == "Attunement to the Core", txt(M.text("node", "30")))
    M.uadd("attune on")
    M.select("30")
    check("on again: ours", txt(M.text("node", "20")) == w.uk("Quest", "Warlord's Command")
          and read(M, ("tree", "RAIDS")) == "|cffA0A0A0" + w.t("Raids") + "|r" and M.chatActive(),
          (txt(M.text("node", "20")), read(M, ("tree", "RAIDS"))))
    more(check, facts, c, M, w, d, Cyr)


def more(check, facts, c, M, w, d, Cyr):
    """Reused frames, combat, cost, sizes, traps, settings."""
    M.select("20")
    check("reused box: new text in Ukrainian at once", txt(M.text("node", "30")) == w.uk("Quest", "Attunement to the Core"),
          txt(M.text("node", "30")))
    M.call("Attune_ShowQuestDetail", 4903)
    check("reused panel: new text in Ukrainian at once", txt(M.text("detail", "title")) == w.uk("Quest", "Warlord's Command"),
          txt(M.text("detail", "title")))
    # Combat: no UALL call, no search, known texts stay ours.
    M.combat(True)
    memo0, asked0 = M.memo(), M.uallIn("out")
    M.uadd("attune rebuild")
    M.wait(1)
    M.select("30")
    M.select("20")
    check("combat: no UALL call", M.uallIn("combat") == 0 and M.uallIn("out") == asked0, (M.uallIn("combat"), M.uallIn("out")))
    check("combat: no search (memo unchanged)", M.memo() == memo0, f"{memo0} -> {M.memo()}")
    check("combat: known box stays ours", txt(M.text("node", "30")) == w.uk("Quest", "Attunement to the Core"), txt(M.text("node", "30")))
    M.combat(False)
    M.wait(6)
    # Cost: bag updates and picks again are bounded by the memo.
    memo0, r0, s0 = M.memo(), M.refreshes(), M.selects()
    refs = [clock.sample()]
    facts["bag_ms"] = round(M.bagCost(BURST), 4)
    refs.append(clock.sample())
    facts["select_ms"] = round(M.selectCost(BURST), 4)
    refs.append(clock.sample())
    check("cost: one Next refresh per bag update, one pick per call", (M.refreshes() - r0, M.selects() - s0) == (BURST, BURST),
          (M.refreshes() - r0, M.selects() - s0))
    check("cost: memo does not grow on the same texts", M.memo() - memo0 <= 2, f"{memo0} -> {M.memo()}")
    # The time: the best of COST_RUNS bursts (one the scheduler cut into is not the code's time). The bound stays
    # 3.0 ms, not stretched by the load (clock.py): a pick costs 0.8-0.9 of the reference job, so a stretched bound
    # would let a 3x slower pick pass. The reference seen between the bursts is in the detail (2026-11-26).
    bag, pick = [facts["bag_ms"]], [facts["select_ms"]]
    for _ in range(COST_RUNS - 1):
        bag.append(M.bagCost(BURST))
        refs.append(clock.sample())
        pick.append(M.selectCost(BURST))
        refs.append(clock.sample())
    check(f"cost: under {BAG_BUDGET_MS} ms per bag update, {SELECT_BUDGET_MS} ms per pick",
          min(bag) < BAG_BUDGET_MS and min(pick) < SELECT_BUDGET_MS,
          (round(min(bag), 4), round(min(pick), 4), f"reference {statistics.median(refs):.2f} ms"))
    # Width: the box text keeps Attune's sizes.
    size = tuple(M.size("node", "30")) + (M.font("node", "30")[1],) + tuple(M.nodeSize("30"))
    check("box text 120x16 at size 11, box 170x48", size == (120, 16, 11, 170, 48), size)
    facts["bag_walks"] = flow_att_fix.run(check, c, M)
    flow_att_more.settings(check, M, w)
    check("saved tables still as in game D", G.snaps(M) == d["snaps"], "")
    check("no field written on a frame the module did not make", txt(M.violated()) == "", txt(M.violated())[:200])
    check("no method replaced (hooksecurefunc only)", txt(M.replaced()) == "", txt(M.replaced())[:200])
    check("module hooks installed", M.hooksBy("UADD_Attune") > 0, M.hooksBy("UADD_Attune"))
    check("guard (no Ukrainian in a font without Ukrainian letters)", not session.cyr_boxes(c), session.cyr_boxes(c)[:3])
    G.errors(c, check, "game A")


def game_b(check):
    c, M = G.game(locale="deDE")
    pre = before(M)
    G.player(M)
    check("deDE: no hooks at all", M.hooksBy("UADD_Attune") == 0 and not M.installed(), M.hooksBy("UADD_Attune"))
    check("deDE: chat not wrapped", not M.chatActive() and M.chatPutBack(), "")
    check("deDE: boxes English", pre["30"] == "Attunement to the Core", pre)
    G.errors(c, check, "game B (deDE)")


def game_c(check):
    c, M = G.game(attune=False)
    M.uadd("attune")
    G.errors(c, check, "game C (no Attune)")
    said = [txt(x) for x in c.H.chat.values()]
    check("game C: module waits", any("чекає: Attune не завантажено" in s for s in said), said[-5:])


def run(check, facts):
    if not G.module_there():
        check("UADD_Attune is there", False, "no UADD_Attune/UADD_Attune.toc")
        return
    if not G.libraries_there():
        check("installed Attune's libraries are there", False, G.REAL)
        return
    d = game_d()
    check("game D (no module): no Lua errors", not d["errors"], d["errors"][:2])
    gc.collect()
    for g in (lambda: game_a(check, facts, d), lambda: game_b(check), lambda: game_c(check)):
        g()
        gc.collect()


Check = collections.namedtuple("Check", "name ok detail")


def run_checks():
    """Every check of this file. Returns (checks, facts)."""
    checks, facts = [], {}

    def check(name, ok, detail=""):
        checks.append(Check("att: " + name, bool(ok), str(detail)))
    run(check, facts)
    return checks, facts


if __name__ == "__main__":       # alone: python3 tools/harness/flow_att.py
    cs, fs = run_checks()
    for x in cs:
        print(("ok    " if x.ok else "FAIL  ") + x.name + (f"  [{x.detail}]" if x.detail else ""))
    print(fs)
    print(f"{sum(x.ok for x in cs)}/{len(cs)} passed")
    sys.exit(0 if all(x.ok for x in cs) else 1)
