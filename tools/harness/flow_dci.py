"""UADD_DeleteCheapestItem on a stand-in for DeleteCheapestItem Reloaded (tools/harness/deletecheapestitem). Its English
may not be copied here (all rights reserved): the stand-in draws its frames, tooltips, chat lines and popup with the
installed addon's English, fed at run time (dci_feed.py, dci_source.py).

  * Game E (no module): its English: what "off" and the hold key must give back.
  * Game A: 1 every text of its windows, tooltips (also the minimap button's), chat and profile popup: whole
    Ukrainian or whole English, ours where we have words; Cyrillic only in our font. 2 hold key: English; release:
    ours. 3 off: English as in game E, no hook made by its own redraw (lesson 37); on: ours; three times. 4 lines on
    GameTooltip with another owner cost no Translate. 5 profile names stay as typed (lesson 13). 6 the game's globals:
    ours only while Latin, never written. 7 glued lines: a known name all Ukrainian, an unknown one or a cut name
    whole English. 8 a redraw while shown. 9 the buttons keep their font size (lesson 5). 10 five errors: off, the
    English back, then on (lesson 19). 11 status. No half line (halves_mods.dci).
  * Game B (no DeleteCheapestItem Reloaded): "/uadd dci" says it waits.
"""
import os
import sys

import halves_mods
import session
from flow_pawn_game import cyr, diff as _diff, errors

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import dci_feed  # noqa: E402
import dci_rules as R  # noqa: E402
import dci_source as G  # noqa: E402
from flow import Check  # noqa: E402
from loader import Addon, Client, lua_str, read_text, txt  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
MODULE, TARGET = "UADD_DeleteCheapestItem", "DeleteCheapestItem"
MONEY = "12|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"
# Texts that stay as they are, on and off: the addon's name and version, item names and counts, money, the chosen
# profile, a blank line, the empty-list text when the list has rows.
KEEP = ("T:title", ":TopLeft", ":TopRight", ":BottomRight", ":count", "I:label1", "I:empty", "P:select",
        "C:DCI_ConfigPanel.title", "C:DCI_ConfigPanel.version", "G:1R", "G:2L", "G:6L", "B:1L", "G:3R", "G:4R",
        "D:DCI_Config_Dropdown_ConfirmMinQuality", "D:DCI_Config_Dropdown_MaxQuality")  # quality names: the game's


def installed():
    d = G.addon_dir()
    return bool(d) and os.path.isfile(os.path.join(str(d), G.TOC))


def module_there():
    return os.path.isfile(os.path.join(session.REPO, MODULE, MODULE + ".toc"))


def diff(a, b):
    return str(_diff(a, b))


def rows():
    return G.source(G.addon_dir())[0] if installed() else []


def english():
    return {r[0]: r[1] for r in rows()}


def feed():
    return dci_feed.feed()


def game(module=True, target=True):
    addons = [Addon(TARGET, os.path.join(HERE, "deletecheapestitem", TARGET), session.FLAVOR)] if target else []
    addons += [Addon(n, os.path.join(session.REPO, n), session.FLAVOR) for n in ("UADD",) + ((MODULE,) if module else ())]
    c = Client(addons, None, "enUS")
    c.lua.execute(read_text(os.path.join(HERE, "flow_dci.lua")))
    M = c.H.dci
    if target:
        M.feed(lua_str(feed()))
    c.start()
    c.H.pump(20)
    if module and target:
        M.uall()
    return c, M


def snap(M):
    return {txt(k): txt(v) for k, v in M.snap().items()}


def _bare(s):
    """s without item links (a link is a value: the game names it in its own language)."""
    import re
    return re.sub(r"\|H.-\|h.*?\|h", "", s or "")


def whole(out, en):
    """Whole English (as it was) or whole Ukrainian (Cyrillic, no made-up English outside a link)."""
    return out == en or (out is not None and cyr(out) and "Quix" not in _bare(out) and "Zorp" not in _bare(out))


def kept(k):
    return any(k == x or (x.startswith(":") and k.endswith(x)) for x in KEEP)


def templates(en, T):
    """Each template the module fills (dci_rules.SORTS), with real values: a known name, money, a coloured count,
    our own words where a slot holds ours (T: the stand-in's English by role)."""
    count = "|cffffd2003|r"
    ours = {G.key_of(T["looting"]): T["items"].replace("%s", count), G.key_of(T["questRewards"]):
            T["items"].replace("%s", count), G.key_of(T["caution"]): "|cffaa0000" + T["red"] + "|r"}
    out = []
    for k, s in sorted(R.SORTS.items()):
        if k not in en:
            continue
        free, good = {}, {}
        for i, kind in enumerate(s if len(s) > 1 else s * max(1, en[k].count("%s") + en[k].count("%d")), 1):
            if kind == "f":
                free[i] = halves_mods.NAME
            elif kind == "n":
                good[i] = "|cff1eff00|Hitem:4711::::::::60:::::|h[Zorp Shard]|h|r"
            elif kind == "t":
                good[i] = ours.get(k, count)
            else:
                good[i] = MONEY if k == "Code.5da45718" else "4711" if k == "Code.a3427f33" else count
        out.append(halves_mods.tpl(k, en[k], free, good, sorts=s))
    return out


def roles(M):
    t = M.stand().T
    return {txt(k): txt(v) for k, v in t.items()}


def steps(check, c, M, E, A, en):
    T = roles(M)
    bad = {k: A[k] for k in A if not whole(A[k], E.get(k))}
    stayed = sorted(k for k in A if A[k] == E.get(k) and (A[k] or "").strip() and not kept(k))
    gone = sorted(k for k in A if kept(k) and A[k] != E.get(k))
    check("1 every text whole; ours where we have words", len(A) > 40 and not bad and not stayed and not gone,
          {"half": bad, "English": stayed, "changed but kept": gone} if bad or stayed or gone else f"{len(A)} texts")
    check("1 minimap tooltip ours (Broker)", all(cyr(A.get(f"B:{i}L")) for i in (2, 3, 4)) and A["B:1L"] == E["B:1L"],
          {k: A[k] for k in A if k.startswith("B:")})
    check("1 profile messages and questions ours", all(cyr(A.get(k)) for k in ("Q:copy", "Q:reset", "Q:delete",
          "C:DCI_ProfileControls.status")), {k: A[k] for k in A if k[:2] == "Q:"})
    fb, n = M.fonts()
    boxes = list(M.cyrBoxes().values())
    check("1 Cyrillic only in our font (lesson 32)", len(fb) == 0 and n > 0 and not boxes,
          f"{n} ours; bad {[txt(b) for b in fb.values()]}; boxes {boxes}")
    M.key(True)
    Hd = snap(M)
    M.key(False)
    Rl = snap(M)
    check("2 hold key: English; release: ours", Hd == E and Rl == A, (diff(E, Hd)[:300], diff(A, Rl)[:300]))
    for i in (1, 2, 3):
        M.uadd("dci off")
        h0 = M.hooks
        O = snap(M)
        made = M.hooks - h0
        M.uadd("dci on")
        N = snap(M)
        check(f"3 off {i}: English as without it, no hook made by its redraw; on: ours",
              O == E and made == 0 and N == A, (made, diff(E, O)[:300], diff(A, N)[:300]))
    n, grow, lines = M.cheap()
    lines = {txt(k): txt(v) for k, v in lines.items()}
    check("4 another owner's tooltip: no Translate, no cache, English", n == 0 and grow == 0
          and not any(cyr(v) for v in lines.values()), (n, grow, lines))
    S = M.stand()
    word = T["create"]
    S.SetProfiles(c.lua.table_from({1: word, 2: "Alpha"}), word)
    P = snap(M)
    M.uadd("dci off")
    Po = snap(M)
    M.uadd("dci on")
    S.SetProfiles(c.lua.table_from({1: A["P:select"]}), A["P:select"])
    check("5 a profile named like our word stays as typed (lesson 13)", P["P:select"] == word and Po["P:select"] == word
          and cyr(P["C:DCI_ProfileCreate"]), (P["P:select"], Po["P:select"]))
    g0 = txt(M.globals())
    snap(M)
    M.setGlobal("DELETE", lua_str("Вилучити"))
    M.setGlobal("YES", lua_str("Атож"))
    Gd = snap(M)
    g1 = txt(M.globals())
    M.setGlobal("DELETE", "Delete")
    M.setGlobal("YES", "Yes")
    check("6 globals: ours while Latin, a Cyrillic one left alone, never written",
          g0 == "Delete|Yes|No|Quest Item" and cyr(A["R1:delete"]) and Gd["R1:delete"] == "Вилучити"
          and Gd["Q:yes"] == "Атож" and g1 == "Вилучити|Атож|No|Quest Item", (g0, g1, Gd["R1:delete"], Gd["Q:yes"]))
    known, other = txt(M.chat("ignore", M.ITEM)), txt(M.chat("ignore", M.OTHER))
    lk = txt(M.chat("delete", lua_str("3x " + txt(M.link(M.ITEM)))))
    M.key(True)
    other_en = txt(M.chat("ignore", M.OTHER))
    wide_en, cut_en = txt(M.loot(M.ITEM, 2000, True)), txt(M.loot(M.OTHER + " of the Very Long Name", 290))
    M.key(False)
    wide, cut = txt(M.loot(M.ITEM, 2000, True)), txt(M.loot(M.OTHER + " of the Very Long Name", 290))
    check("7 glued chat: a known name all Ukrainian, an unknown one whole English, a link ours",
          cyr(known) and "Zorp" not in known and other == other_en and not cyr(other) and cyr(lk), (known, other, lk))
    check("7 loot line: a known name ours; a name cut with ... whole English", cyr(wide) and "Zorp" not in wide
          and wide_en != wide and "..." in cut and cut == cut_en, (wide, cut))
    S.db.UseAuctionPrices, S.db.AuctionSource = True, "Auctionator"
    Au = snap(M)
    S.db.UseAuctionPrices = False
    check("7 the price addon's name in the info tooltip: ours on the left, its name as it is",
          cyr(Au.get("G:5L")) and Au.get("G:5R") == "Auctionator", {k: Au[k] for k in Au if k.startswith("G:")})
    snap(M)
    b, tip = M.redraw(True)
    b, tip = txt(b), txt(tip)
    b2, _ = M.redraw(False)
    b2 = txt(b2)
    check("8 drawn again while shown (a merchant): the button and its tooltip ours", cyr(b) and cyr(tip) and cyr(b2),
          (b, tip, b2))
    halves_mods.dci(check, M, templates(en, T))
    return T


def late_steps(check, c, M, E, A, SE):
    SA = {txt(k): v for k, v in M.sizes().items()}
    check("9 fixed-width buttons keep the addon's font size (lesson 5)", SA == SE and len(SA) >= 4, (SE, SA))
    errors(c, check, "game A before the errors")
    M.wait(4)                    # past the settle time after login: an error now counts
    M.fault(5)
    M.reopen()                   # the walk hooks the new text
    for _ in range(8):
        if M.boom <= 0:
            break
        M.poke()
    left = M.boom
    M.wait(0.3)                  # U.TurnOff runs the module's off one frame later
    said = "\n".join(c.chat()[-12:])
    F = snap(M)
    check("10 five errors: off, English back (lesson 19)", left == 0 and not M.on() and "вимкнено до кінця сесії" in said
          and F == E, (left, M.on(), said[-200:], diff(E, F)[:300]))
    M.uadd("dci on")
    N = {k: v for k, v in snap(M).items() if k[:2] != "Q:"}   # the popup's: core U.Popups runs under U.Safe (a gap)
    check("10 then on: ours (its windows)", M.on() and N == {k: v for k, v in A.items() if k[:2] != "Q:"},
          diff(A, N)[:300])
    st = txt(M.said("dci"))
    check("11 status", "увімкнено" in st, st[:300])


def run(check, facts):
    if not module_there() or not installed():
        halves_mods.dci(check, None, [], halves_mods.SKIP)
        facts["note"] = "DeleteCheapestItem Reloaded or the module not there: skipped"
        return
    en = english()
    c, M = game(module=False)
    E = snap(M)
    SE = {txt(k): v for k, v in M.sizes().items()}
    errors(c, check, "game E")
    del c, M
    c, M = game()
    A = snap(M)
    steps(check, c, M, E, A, en)
    late_steps(check, c, M, E, A, SE)
    del c, M
    if os.path.isfile(os.path.join(HERE, "flow_dci_mut.py")):
        import flow_dci_mut
        flow_dci_mut.mutants(check, E, en)
    c, M = game(target=False)
    st = txt(M.said("dci"))
    check("B without DeleteCheapestItem Reloaded: waits", "чекає" in st, st[:300])
    facts["changed"] = sum(1 for k in A if A[k] != E.get(k))
    facts["texts"] = len(A)


def run_checks():
    """Every check of this file. Returns (checks, facts)."""
    checks, facts = [], {}

    def check(name, ok, detail=""):
        checks.append(Check("dci: " + name, bool(ok), str(detail)))
    run(check, facts)
    return checks, facts


if __name__ == "__main__":       # alone: python3 tools/harness/flow_dci.py
    cs, fs = run_checks()
    for x in cs:
        print(("ok    " if x.ok else "FAIL  ") + x.name + (f"  [{x.detail[:600]}]" if x.detail else ""))
    print(fs)
    print(f"{sum(x.ok for x in cs)}/{len(cs)} passed")
    sys.exit(0 if all(x.ok for x in cs) else 1)
