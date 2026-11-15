"""UADD_OpenMap on a stand-in for OpenMap (tools/harness/openmap: frames shaped like its dungeon
view, every text in the client's standard font; the real OpenMap is too big to load here).

Run by flow_dj_module.py, so run.py runs it too:
  * in_game(s, check, facts): in the Dungeon Journal module's game (names collected), the Razorfen
    Kraul view: Ukrainian quest titles in a Cyrillic font, Ukrainian labels and names, size and
    flags kept, redraws, the hold key, OpenMap's L (on, hold key, combat, a bad text, off), its
    menu, News and Settings page, "/uadd dj off" leaves it alone, "/uadd openmap off" puts
    everything back exactly and "on" again, the Dungeon Journal's own panel inside the dungeon (a
    fact), the guard (no Ukrainian text in a font without Ukrainian letters) and no Lua errors.
  * alone(saved, check, facts): a second game with UADD and UADD_OpenMap only (no Dungeon
    Journal, no UALL), on the saved settings of the first: fonts fixed, names from the saved copy.
The Lua helpers are in flow_openmap.lua.
"""
import os

import session
from loader import Addon, Client, lua_str, read_text, txt

HERE = os.path.dirname(os.path.abspath(__file__))
STAND_IN = Addon("OpenMap", os.path.join(HERE, "openmap"), session.FLAVOR)
MODULE = "UADD_OpenMap"
HELD = 0.3
FONT_EN = "Fonts\\FRIZQT__.TTF"
TABS = ["Боси", "Завдання", "Здобич", "Поверхи"]


def module_addon():
    return Addon(MODULE, os.path.join(session.REPO, MODULE), session.FLAVOR)


def _reads(M):
    t = lambda k: txt(M.text(k)) or ""  # noqa: E731
    return t


def _view_checks(M, t, check, step, rfk_uk, boss_uk, quest_uk):
    """The view in Ukrainian, as it should be with the module on."""
    n, total = M.cyrCount()
    check(f"{step}: every text in a Cyrillic font", n == total and total > 0, f"{n}/{total}")
    check(f"{step}: the Ukrainian quest title shown", quest_uk in t("quest1"), t("quest1"))
    tabs = [t(k) for k in ("tab1", "tab2", "tab3", "tab4")]
    check(f"{step}: tab labels in Ukrainian", tabs == TABS, tabs)
    states = [t("state1"), t("state2")]
    check(f"{step}: quest states in Ukrainian", "виконано" in states[0] and "у журналі" in states[1], states)
    check(f"{step}: level line in Ukrainian", t("sub").startswith("Рівень 24-33") and "Рейд" in t("sub"), t("sub"))
    check(f"{step}: floor and hint in Ukrainian", "Поверх 1" in t("floor") and "Правий клік" in t("hint"),
          [t("floor"), t("hint")])
    want_name = rfk_uk or "Razorfen Kraul"
    check(f"{step}: dungeon name {'from the saved names' if rfk_uk else 'English (none saved)'}",
          t("where") == want_name and want_name in t("title") and want_name in t("cardTitle"),
          [t("where"), t("title"), t("cardTitle")])
    want_boss = boss_uk or "Charlga Razorflank"
    check(f"{step}: boss row", want_boss in t("boss") and want_boss in t("cardText"), t("boss"))
    check(f"{step}: Back button", "Назад: " in t("back"), t("back"))
    check(f"{step}: card headings", t("cardText").startswith("|cffe6c27aБоси|r") and "Завдання|r" in t("cardText"),
          t("cardText")[:80])


def in_game(s, check, facts):
    """s: a flow_dj_module.ModuleSession with the stand-in and UADD_OpenMap loaded, names collected."""
    s.lua.execute(read_text(os.path.join(HERE, "flow_openmap.lua")))
    M = s.H.om
    t = _reads(M)
    qid, q_en, q_uk = [txt(x) if isinstance(x, str) else x for x in _three(M.rfkQuest())]
    facts["openmap_quest"] = [qid, q_en, q_uk]
    check("a Razorfen Kraul quest with a Ukrainian title (from the journal's names)", q_uk, facts["openmap_quest"])
    q_uk = q_uk or "Тест"
    rfk_uk = txt(M.cached("zones", "Razorfen Kraul"))
    boss_uk = txt(M.cached("Npc", "Charlga Razorflank"))
    facts["openmap_names"] = [rfk_uk, boss_uk]
    check("UADD.CachedName: dungeon and boss names from the saved copy", rfk_uk and boss_uk, facts["openmap_names"])

    M.open(lua_str(q_uk), lua_str("Second Quest"))
    M.wait(0.6)   # the map ticker looks every 0.5 s: the view is built after the map shows
    _view_checks(M, t, check, "open", rfk_uk, boss_uk, q_uk)
    check("open: size and flags kept", [_font(M, "pin")[1:], _font(M, "floor")[1], _font(M, "boss")[1]]
          == [(11, "OUTLINE"), 15, 13], [_font(M, "pin"), _font(M, "floor"), _font(M, "boss")])

    M.open(lua_str(q_uk), lua_str("Second Quest"))      # OpenMap draws the view again
    s.pump(5)
    _view_checks(M, t, check, "redraw", rfk_uk, boss_uk, q_uk)
    # OpenMap sizes Back from its text (GetStringWidth: 6 per byte here) right after SetText; our
    # hook swaps the text first, so from the first redraw on it fits the Ukrainian words.
    check("redraw: the Back button is sized from the Ukrainian text",
          M.backWidth() == len(M.text("back")) * 6 + 24, [M.backWidth(), len(M.text("back"))])
    M.refont()                                           # and sets its fonts again
    s.pump(5)
    n, total = M.cyrCount()
    check("fonts set again: still Cyrillic, sizes kept", n == total and _font(M, "pin")[1:] == (11, "OUTLINE"),
          f"{n}/{total} {_font(M, 'pin')}")

    M.key(True)
    M.wait(HELD)
    held = [t("tab1"), t("where"), t("state1")]
    n_held, _ = M.cyrCount()
    M.key(False)
    M.wait(0.1)
    check("hold key: English words, Cyrillic fonts kept",
          held == ["Bosses", "Razorfen Kraul", "|cff808080done|r"] and n_held == total, f"{held} fonts {n_held}")
    check("hold key released: Ukrainian again", t("tab1") == "Боси", t("tab1"))
    M.map(False)                                         # the map closed: the view's texts are hidden
    M.key(True)
    M.wait(HELD)
    hidden = t("tab1")
    M.map(True)
    held = t("tab1")
    M.map(False)
    M.key(False)
    M.wait(0.1)
    M.map(True)
    check("hold key, map closed: texts left alone; English the moment it opens, then Ukrainian",
          [hidden, held, t("tab1")] == ["Боси", "Bosses", "Боси"], [hidden, held, t("tab1")])

    s.uadd("dj off")
    check("/uadd dj off leaves OpenMap's view in Ukrainian", t("tab1") == "Боси" and M.cyrCount()[0] == total)
    s.uadd("dj on")

    s.uadd("openmap off")
    en = [t("tab1"), t("where"), t("back"), t("sub")]
    check("/uadd openmap off: English back exactly",
          en == ["Bosses", "Razorfen Kraul", "|cffffd100<|r  Back to The Barrens", "Level 24-33   |cffbbbbbbRaid|r"], en)
    fonts = txt(M.fonts()).split("|")
    exact = all(f.startswith(FONT_EN + " ") for f in fonts) and _font(M, "pin") == (FONT_EN, 11, "OUTLINE")
    check("/uadd openmap off: OpenMap's fonts back exactly (file, size, flags)", exact, fonts[:4])
    M.refont()
    M.open(lua_str(q_uk), lua_str("Second Quest"))
    s.pump(30)
    check("/uadd openmap off: hooks idle on a redraw", t("tab1") == "Bosses" and M.cyrCount()[0] == 0,
          f"{t('tab1')} {M.cyrCount()[0]}")
    facts["openmap_guard_off"] = session.cyr_boxes(s.client)[:3]   # the squares, as without UADD
    s.uadd("openmap on")
    s.pump(30)
    _view_checks(M, t, check, "/uadd openmap on", rfk_uk, boss_uk, q_uk)
    before = len(s.client.chat())
    s.uadd("openmap")
    check("/uadd openmap: status line", any("OpenMap:" in line for line in s.client.chat()[before:]),
          s.client.chat()[before:][:2])

    _more(s, M, check)
    boxes = session.cyr_boxes(s.client)
    check("guard: no Ukrainian text in a font without Ukrainian letters (view open)", not boxes, boxes[:3])
    M.close()
    shown, leave = M.insideRFK()
    facts["fdj_map_panel_inside_rfk"] = bool(shown)
    boxes = session.cyr_boxes(s.client)
    check("guard: none inside Razorfen Kraul with the World Map open", not boxes, boxes[:3])
    leave()
    s.pump(10)
    errs = s.new_errors()
    check("no Lua errors", not errs, "; ".join(f"{w}: {m[:160]}" for w, m, *_ in errs[:3]))
    return q_uk


def alone(saved, q_uk, check, facts):
    """UADD + the stand-in + UADD_OpenMap, no Dungeon Journal and no UALL, on game A's saved settings."""
    c = Client([STAND_IN, Addon("UADD", os.path.join(session.REPO, "UADD"), session.FLAVOR), module_addon()],
               saved, "enUS")
    c.lua.execute(read_text(os.path.join(HERE, "flow_openmap.lua")))
    c.start()
    c.H.pump(60)
    M = c.H.om
    t = _reads(M)
    rfk_uk = txt(M.cached("zones", "Razorfen Kraul"))
    M.open(lua_str(q_uk), lua_str("Second Quest"))
    M.wait(0.6)
    n, total = M.cyrCount()
    check("alone: fonts fixed without the Dungeon Journal", n == total and total > 0, f"{n}/{total}")
    check("alone: dungeon name from the saved copy", rfk_uk and t("where") == rfk_uk, [rfk_uk, t("where")])
    check("alone: labels in Ukrainian", t("tab1") == "Боси", t("tab1"))
    boxes = session.cyr_boxes(c)
    check("alone: guard", not boxes, boxes[:3])
    errs = c.errors()
    check("alone: no Lua errors", not errs, "; ".join(f"{w}: {m[:160]}" for w, m, _ in errs[:3]))


def _d(r):
    """A Lua table of texts as a dict of str."""
    return {txt(k): txt(v) for k, v in r.items()}


def _more(s, M, check):
    """OpenMap's L, its menu, News and Settings page: on, the hold key, combat, a bad text, off."""
    ours, total, english = M.lState()
    check("L: our words in OpenMap's locale table", total > 400 and ours == total, f"{ours}/{total}")
    check("L: a word reads in Ukrainian", txt(M.L("Look")) == "Вигляд", txt(M.L("Look")))
    check("L: a Ukrainian text two keys share reads Ukrainian for both", M.shared("Dungeon") and M.shared("Dungeons")
          and txt(M.L("Dungeon")) == "Підземелля" and txt(M.L("Dungeons")) == "Підземелля",
          [txt(M.L("Dungeon")), txt(M.L("Dungeons"))])
    M.menu()
    M.news()
    M.wait(1.5)   # a new frame is found within a second (as in the game), then walked
    m = _d(M.menu())
    check("menu: load-time tab names in Ukrainian", [m["tab1"], m["tab2"]] == ["На карті", "Вигляд"], m)
    check("menu: rows from L in Ukrainian", m["row"] == "Відкрити налаштування OpenMap"
          and m["count"] == "Босів: 3" and m["close"] != "Close", m)
    n = _d(M.news())
    check("News: texts in Ukrainian (from L and load-time)",
          [n["title"], n["head"], n["kind"], n["newer"], n["older"]] == ["Що нового", "Версій: 5", "Ідея", "Новіші", "Старіші"], n)
    check("News: two keys with one Ukrainian text both in Ukrainian",
          [n["dungeon"], n["dungeons"]] == ["Підземелля", "Підземелля"], [n["dungeon"], n["dungeons"]])
    check("News: the Ukrainian title in a Cyrillic font at its size, the English version line keeps MORPHEUS",
          n["titleFont"] in ("Fonts\\FRIZQT___CYR.TTF 28", "Fonts\\ARIALN.TTF 28")
          and n["versionFont"] == "Fonts\\MORPHEUS.TTF 20", [n["titleFont"], n["versionFont"]])
    pnl = _d(M.panel())
    check("Settings page: the button in Ukrainian, the title as OpenMap wrote it",
          pnl["button"] == "Відкрити налаштування OpenMap" and pnl["title"] == "|cff33ccffOpen|rMap", pnl)
    s.pump(10)
    boxes = session.cyr_boxes(s.client)
    check("guard: none with the menu, News and the Settings page open", not boxes, boxes[:3])
    check("the once-a-second look runs while the World Map is shown", M.finding())
    t = _d(M.tip())
    check("tooltip over OpenMap: our line in a Cyrillic font, its own font back once hidden",
          t["text"] != "Close" and t["font"] in ("Fonts\\FRIZQT___CYR.TTF 12", "Fonts\\ARIALN.TTF 12")
          and str(t["n"]) == "1" and t["after"] == "Fonts\\FRIZQT__.TTF 12", t)

    M.key(True)
    M.wait(HELD)
    ours_h, _, english_h = M.lState()
    held = [txt(M.menuText("tab1")), txt(M.menuText("row")), txt(M.newsText("title")), txt(M.newsText("older"))]
    held_d = [txt(M.newsText("dungeon")), txt(M.newsText("dungeons"))]
    M.key(False)
    M.wait(0.1)
    check("hold key: L exactly as OpenMap had it", ours_h == 0 and english_h, f"{ours_h} {english_h}")
    check("hold key: a Ukrainian text two keys share goes back to each widget's own English",
          held_d == ["Dungeon", "Dungeons"], held_d)
    back_d = [txt(M.newsText("dungeon")), txt(M.newsText("dungeons"))]
    check("hold key released: both shared-text widgets Ukrainian again", back_d == ["Підземелля", "Підземелля"], back_d)
    check("hold key: menu and News English (OpenMap's own text kept)",
          held == ["On the map", "Open OpenMap's settings", "What's new", "Older pages"], held)
    check("hold key released: L and menu Ukrainian again", M.lState()[0] == total
          and txt(M.menuText("tab1")) == "На карті", txt(M.menuText("tab1")))

    M.combat(True)
    M.key(True)
    M.wait(HELD)
    in_combat = [M.lState()[0], txt(M.menuText("tab1"))]
    M.combat(False)
    s.pump(5)
    after = [M.lState()[2], txt(M.menuText("tab1"))]
    M.key(False)
    M.wait(0.1)
    check("combat: nothing changed while it lasts", in_combat == [total, "На карті"], in_combat)
    check("combat ended: the change asked for is made", after == [True, "On the map"], after)
    check("combat ended, key released: Ukrainian again", txt(M.menuText("tab1")) == "На карті", txt(M.menuText("tab1")))

    skipped = M.build("%d bosses", "%s босів".encode("utf-8"))
    count = txt(M.L("%d bosses")).replace("%d", "3")
    M.build(None)
    check("a Ukrainian text whose %-specs differ is not used: English stays", skipped and count == "3 bosses",
          [skipped, count])
    check("words built again: Ukrainian back", _d(M.menu())["count"] == "Босів: 3")

    s.uadd("openmap off")
    ours_off, _, english_off = M.lState()
    off_d = [txt(M.newsText("dungeon")), txt(M.newsText("dungeons"))]
    check("/uadd openmap off: a Ukrainian text two keys share goes back to each widget's own English",
          off_d == ["Dungeon", "Dungeons"], off_d)
    m = _d(M.menu())
    n = _d(M.news())
    check("/uadd openmap off: L exactly as OpenMap had it", ours_off == 0 and english_off, f"{ours_off} {english_off}")
    check("/uadd openmap off: menu, News and Settings page English",
          [m["tab1"], m["row"], n["title"], n["older"], txt(M.panel()["button"])]
          == ["On the map", "Open OpenMap's settings", "What's new", "Older pages", "Open OpenMap's settings"],
          [m["tab1"], m["row"], n["title"], n["older"]])
    check("/uadd openmap off: a window built while L was ours and never shown reads English",
          txt(M.pinsTitle()) == "Map pins", txt(M.pinsTitle()))
    check("/uadd openmap off: the once-a-second look stopped", not M.finding())
    check("/uadd openmap off: the News title back in MORPHEUS at 28", n["titleFont"] == "Fonts\\MORPHEUS.TTF 28",
          n["titleFont"])
    s.uadd("openmap on")
    s.pump(30)
    check("/uadd openmap on: L, menu and Settings page Ukrainian again", M.lState()[0] == total
          and _d(M.menu())["tab1"] == "На карті" and txt(M.panel()["button"]) == "Відкрити налаштування OpenMap")
    M.closeNews()
    M.closePanel()


def _three(r):
    if r is None:
        return (None, None, None)
    return tuple(r) if isinstance(r, tuple) else (r, None, None)


def _font(M, key):
    p, size, flags = M.font(key)
    return (txt(p), int(size) if size is not None else None, txt(flags))
