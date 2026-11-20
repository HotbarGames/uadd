"""The journal's short words that come from our tables, in the DJ module flow (language "auto").

Checked: the Favourites button (FDJ's Systems/Favourites.lua adds its words only to the languages it
finds at load, so ours come from ui/strings_systems.lua); the search list's place line under each
dungeon (UALL zone names, and our two phrases with a zone in them; a line with a part UALL lacks stays
whole English, also a made-up one: docs/LESSONS.md lesson 6);
the loot type line ("Two-Hand, Axe") and every type word in the journal's loot; the "Trash Drops"
row on the Deadmines boss list. Each in Ukrainian, exact English with Shift held and with
"/uadd dj off". Fact: "Ogre Loincloth" is not in UALL, so its name stays English.
Ends on the Razorfen Kraul boss list. The Lua helpers are in flow_dj_words.lua."""
import os
import re

from flow_dj_screen import triple
from loader import lua_str, read_text, txt

HERE = os.path.dirname(os.path.abspath(__file__))
CYR = re.compile("[А-Яа-яІіЇїЄєҐґ]")
SLOTS = {"Two-Hand, Axe": "Дворучна, Сокира", "Legs, Cloth": "Ноги, Тканина",
         "Recipe, Blacksmithing": "Рецепт, Ковальство", "Back": "Плащ"}
TRASH_EN, TRASH_UK = "Trash Drops", "Здобич зі звичайних ворогів"
UK_PLACES = ("Moonbrook, Westfall", "Cleft of Shadow, Orgrimmar", "Northern Barrens", "Silverpine Forest")
MADE_UP = "Wobbly Gizmo Hollow"     # a place nobody has a name for


def places(D):
    return dict(line.split("\t", 1) for line in txt(D.locations()).split("\n") if "\t" in line)


def words(D):
    """Everything this flow reads, for the Shift and off checks."""
    fav, button = triple(D.fav(), 2)
    return {"fav": txt(fav), "button": txt(button), "trash": txt(D.boss(lua_str(TRASH_EN))),
            "slots": {en: txt(D.slot(lua_str(en))) for en in SLOTS}, "places": places(D)}


def english(got):
    return (got["fav"] == got["button"] == "Favourites" and got["trash"] == TRASH_EN
            and all(got["slots"][en] == en for en in SLOTS) and all(k == v for k, v in got["places"].items()))


def run(s, check, facts):
    s.lua.execute(read_text(os.path.join(HERE, "flow_dj_words.lua")))
    D, M = s.H.djw, s.M
    got = words(D)
    check("words: the Favourites button in Ukrainian", got["fav"] == got["button"] == "Обране",
          f"{got['fav']!r} / button {got['button']!r}")

    p, hall = got["places"], txt(D.hallWant())
    check("words: a place line with our phrase", hall is not None and p.get("Beneath Ironforge, Dun Morogh") == hall,
          f"{p.get('Beneath Ironforge, Dun Morogh')!r} vs {hall!r}")
    bad = {en: p.get(en) for en in UK_PLACES if not CYR.search(p.get(en) or "")}
    check("words: place lines in Ukrainian from UALL's zone names", not bad, bad or "")
    ruins = p.get("The ruined city of Lordaeron")
    has_lordaeron = D.dungeon(lua_str("Lordaeron")) is not None
    check("words: a place UALL lacks stays English", (ruins == "The ruined city of Lordaeron") != has_lordaeron,
          f"{ruins!r} (UALL has Lordaeron: {has_lordaeron})")
    half = {en: v for en, v in p.items() if v != en and re.search("[A-Za-z]", v)}
    check("words: a place line is all Ukrainian or exactly English", not half, half or "")
    known = UK_PLACES[0].split(", ")[1]
    for line in (f"{known}, {MADE_UP}", f"{MADE_UP}, {known}"):
        shown = txt(D.madeUp(lua_str(UK_PLACES[0]), lua_str(line)))
        check(f"words: a known place beside an unknown one stays whole English ({line})", shown == line, shown)
    facts["dj_place_lines"] =f"{sum(1 for k, v in p.items() if k != v)} of {len(p)} in Ukrainian"

    check("words: loot type lines in Ukrainian", got["slots"] == SLOTS, got["slots"])
    n, gaps = triple(D.slotGaps(), 2)
    check("words: every loot type word in the journal is translated", int(n) > 30 and not txt(gaps),
          f"{int(n)} words; English: {txt(gaps) or 'none'}")
    facts["dj_ogre_loincloth_in_uall"] = D.item(lua_str("Ogre Loincloth")) is not None

    check("words: the Trash Drops row's name", got["trash"] == TRASH_UK, got["trash"])
    s.open_dungeon("dm")
    s.set_tab("bosses")
    check("words: Deadmines boss list shows it", s.has(TRASH_UK) and not s.has(TRASH_EN))

    M.key(True)
    M.wait(0.3)
    s.pump(5)
    shown = s.has(TRASH_EN) and not s.has(TRASH_UK)
    M.key(False)
    M.wait(0.3)
    s.click(s.frame.backButton)            # the home page, where the Favourites button is
    view = txt(s.frame.currentView)
    M.key(True)
    M.wait(0.3)
    s.pump(5)
    held = words(D)
    M.key(False)
    M.wait(0.3)
    s.pump(5)
    check("words: Shift held gives the exact English", view == "home" and english(held) and shown,
          f"{view}: {held['fav']!r} button {held['button']!r} {held['trash']!r} {held['slots']}; list English: {shown}; "
          f"places not English: {[v for k, v in held['places'].items() if k != v]}")
    check("words: Ukrainian again on release", words(D) == got)

    s.uadd("dj off")
    off = words(D)
    s.open_dungeon("dm")
    s.set_tab("bosses")
    listed = s.has(TRASH_EN) and not s.has(TRASH_UK)
    check("/uadd dj off: the short words in exact English", english(off) and listed,
          f"{off['fav']!r} button {off['button']!r} {off['trash']!r} {off['slots']}; list English: {listed}")
    s.uadd("dj on")
    check("/uadd dj on: the short words in Ukrainian again", words(D) == got)
    s.open_dungeon("rfk")
    s.set_tab("bosses")
