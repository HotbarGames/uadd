"""UADD_DungeonJournal next to the real Dungeon Journal and UALL Forever, in one game.

Usage: python3 tools/harness/flow_dj_module.py   (needs lupa and the Forever AddOns folder;
UADD_ADDONS_DIR overrides the folder, as for run.py). run.py runs it too.

Checks: Ukrainian by default, «Українська» in the language menu, Русский steps aside and
Українська comes back, the journal's saved language is never "ukUA", /uadd dj off (pure FDJ) and
on, UALL names on the Razorfen Kraul page, the Stratholme wing names, English for a name UALL
lacks, search in Ukrainian and English, the show-original key, our fonts (Blizzard's shared font
objects untouched), the title's font on later dungeons, size and OUTLINE kept, fonts put back
exactly and hooks idle when off or under another language, item names on item rows only and after
every page change, no look while no window shows, dungeon names past the zone route, and no Lua
errors; short words from our tables (flow_dj_words.py); the header's level line and quest giver
lines (flow_dj_head.py); Shift on search results and on a shut
journal (flow_dj_shift.py); the summon line and the joined-item row (flow_dj_summon.py). Two more games: UALLF's storage route off (the collection still ends
and is saved) and a Russian client on "auto" (we step aside). Three with ClassicUA (flow_dj_cua.py): a
cache saved without it is built again with its titles, a late hook is waited for, objective lines get its
item names. The Lua helpers are in flow_dj_module.lua.
UADD_OpenMap runs in the same games, on a stand-in for OpenMap (flow_openmap.py): its checks at
the end of the main game ("openmap: ..."), then a game with UADD and UADD_OpenMap alone.
`run()` returns (checks, facts).
"""
import collections
import gc
import json
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import loader  # noqa: E402
import flow_dj_cua  # noqa: E402
import flow_dj_head  # noqa: E402
import flow_dj_prose  # noqa: E402
import flow_dj_readback  # noqa: E402
import flow_dj_shift  # noqa: E402
import flow_dj_summon  # noqa: E402
import flow_dj_words  # noqa: E402
import flow_openmap  # noqa: E402
import session  # noqa: E402
from flow_dj import DJSession, JOURNAL, plain, uniq  # noqa: E402
from loader import Addon, read_text, txt, lua_str  # noqa: E402
from flow_dj_screen import UK, run_client_locale, run_storage_off, screen_checks, triple  # noqa: E402

Check = collections.namedtuple("Check", "name ok detail")
MODULE = "UADD_DungeonJournal"
# The client's order: dependencies first (UALLF is optional for both of ours).
ORDER = [JOURNAL, "OpenMap", "UALLF", "UADD", MODULE, flow_openmap.MODULE]
HELD = 0.3                 # seconds: the core waits 0.25 s before it shows the original
SHARED_FONTS = ["GameFontNormal", "GameFontHighlight", "GameFontNormalSmall", "GameFontHighlightSmall",
                "GameFontNormalLarge", "GameFontHighlightLarge", "GameFontNormalHuge", "GameFontDisable"]


class ModuleSession(DJSession):
    def __init__(self, saved=None, locale="enUS"):
        d = session.addons_dir()
        addons = [flow_openmap.STAND_IN if n == "OpenMap" else   # the stand-in, not the AddOns folder
                  Addon(n, os.path.join(session.REPO, n) if n.startswith("UADD") else os.path.join(d, n),
                        session.FLAVOR) for n in ORDER]
        super().__init__(saved=saved, locale=locale, addons=addons)
        self.lua.execute(read_text(os.path.join(HERE, "flow_dj_module.lua")))
        self.M = self.H.djm
        self.M.SHARED = self.lua.table_from(SHARED_FONTS)

    def uadd(self, msg):
        self.M.uadd(msg)
        self.pump(40)


def missing_addons():
    d = session.addons_dir()
    return [n for n in (JOURNAL, "UALLF") if not os.path.isdir(os.path.join(d, n))]


def run():
    checks, facts = [], {}

    def check(name, ok, detail=""):
        checks.append(Check("dj module: " + name, bool(ok), str(detail)))
        return bool(ok)

    def om_check(name, ok, detail=""):
        checks.append(Check("openmap: " + name, bool(ok), str(detail)))
        return bool(ok)

    # One game at a time: each ends (and is collected) before the next starts.
    saved, q_uk = run_main(check, om_check, facts)
    gc.collect()
    flow_openmap.alone(saved, q_uk, om_check, facts)
    gc.collect()
    run_storage_off(ModuleSession, check, facts)
    gc.collect()
    run_client_locale(ModuleSession, check, facts)
    gc.collect()
    # with ClassicUA: no frozen cache, objective lines; the journal's SetFont of our file (lesson 48)
    for extra in (flow_dj_cua.run, flow_dj_readback.run):
        extra(check, facts)
        gc.collect()
    return checks, facts


def run_main(check, om_check, facts):
    """The main game. Returns (its saved variables, the Ukrainian quest title OpenMap showed)."""
    s = ModuleSession()
    M = s.M
    fonts_before = txt(M.fonts())
    errs = s.new_errors()
    check("loads without Lua errors", not errs, "; ".join(f"{w}: {m[:160]}" for w, m in errs[:3]))

    # Names from UALL, collected in the background a few seconds after login.
    done = M.collect(200000)
    dungeons, dungeons_total, npc, quest, item = M.counts()
    zones_t, npc_t, quest_t, item_t = M.totals()
    facts["coverage"] = {"dungeons": f"{dungeons}/{dungeons_total}", "bosses_and_npcs": f"{npc}/{npc_t}",
                         "quests": f"{quest}/{quest_t}", "items": f"{item}/{item_t}"}
    check("names collected", done and npc > 0 and quest > 0 and item > 0, facts["coverage"])

    # 1. Ukrainian by default, «Українська» in the menu.
    s.open_dungeon("rfk")
    rfk_uk = txt(M.name("dungeon", "Razorfen Kraul"))
    check("Ukrainian by default", txt(M.language()) == "ukUA" and s.current_language_label() == UK,
          f"{txt(M.language())} / {s.current_language_label()}")
    labels = s.language_labels()
    check("«Українська» in the language menu", UK in labels and "English" in labels, labels)
    check("FDJ's saved language untouched", s.saved_language() in (None, "auto"), s.saved_language())

    # 2. UALL names on the Razorfen Kraul page.
    check("RFK: dungeon name in Ukrainian", rfk_uk and s.has(rfk_uk) and not s.has("Razorfen Kraul"), rfk_uk)
    s.set_tab("bosses")
    boss_uk = txt(M.name("boss", "Charlga Razorflank"))
    check("RFK: boss name in Ukrainian", boss_uk and s.has(boss_uk) and not s.has("Charlga Razorflank"), boss_uk)
    boss_en, item_en, item_uk = [txt(x) if x is not None else None for x in triple(M.lootItem("Razorfen Kraul"))]
    facts["rfk_item"] = [boss_en, item_en, item_uk]
    s.set_tab("quests")
    rows = s.quest_rows()
    titled = [(r["id"], r["name"]) for r in rows if r["shown"]]
    uk_titles = [n for qid, n in titled if txt(M.name("quest", qid)) == n]
    check("RFK: quest titles in Ukrainian", uk_titles, titled)
    facts["rfk_quests"] = titled

    # Item names: open a boss whose loot has a Ukrainian name and look for it.
    s.set_tab("bosses")
    shown_item = item_uk is not None and s.has(item_uk)
    if not shown_item and boss_en:
        uk = M.name("boss", boss_en)
        facts["rfk_item_clicked"] = bool(M.clickNamed(uk if uk is not None else lua_str(boss_en)))
        s.pump(30)
        shown_item = item_uk is not None and s.has(item_uk)
    facts["rfk_item_en_shown"] = s.has(item_en or "\0")
    facts["rfk_item_texts"] = [repr(t) + " @ " + str(at) for t, at in s.texts_at() if "Phlog" in t][:5]
    check("RFK: item name in Ukrainian", shown_item and not s.has(item_en or "\0"), facts["rfk_item"])

    # Every page change gets its item names swapped, not just a boss click.
    def no_english_items(what):
        s.pump(5)
        left = [txt(x) for x in s.listing(M.englishItems())]
        check(f"item names in Ukrainian after {what}", not left, left[:4])
    s.set_tab("quests")
    s.set_tab("bosses")
    no_english_items("a tab switch")
    s.open_dungeon("sfk")
    no_english_items("a dungeon switch")
    M.search(lua_str("wailing"))
    s.pump(5)
    clicked = M.clickResult()
    s.pump(30)
    M.search(lua_str(""))
    no_english_items("a search result click" + ("" if clicked else " (no result to click)"))
    s.open_dungeon("rfk")
    check("loot count word fits the number", txt(M.plural(3, lua_str("предметів"))) == "предмети"
          and txt(M.plural(11, lua_str("предметів"))) == "предметів"
          and txt(M.plural(21, lua_str("завдань"))) == "завдання"
          and M.countText(lua_str("|Tx|t 2/6 завдань")) is None
          and txt(M.countText(lua_str("|Tx|t 2/3 завдань"))) == "|Tx|t 2/3 завдання")

    # 3. Stratholme wings and an English fallback.
    living = txt(M.name("dungeon", "Stratholme: Living"))
    check("Stratholme: Living = «Стратгольм: Живі»", living == "Стратгольм: Живі", living)
    facts["stratholme_undead"] = txt(M.name("dungeon", "Stratholme: Undead"))
    # Names the zone route lacks: a whole name with ": ", UALL's UI words, a wing spelled UALL's way.
    other = {k: M.name("dungeon", k) for k in ("Excavation Site: Wetlands", "Hall of Thanes",
                                                "Dire Maul: East", "Scarlet Monastery: Armory")}
    other = {k: txt(v) if v is not None else None for k, v in other.items()}
    check("dungeon names past the zone route (whole name, UI words, wing spelling)",
          all(v and v != k for k, v in other.items())
          and all(": " in (other[k] or "") for k in ("Dire Maul: East", "Scarlet Monastery: Armory")), other)
    en, shown = [txt(x) if x is not None else None for x in triple(M.missingBoss(), 2)]
    check("a name UALL lacks stays English", en is None or shown == en, f"{en!r} -> {shown!r}")

    # 4. Search: Ukrainian (any case) and English.
    first = rfk_uk.split(" ")[0] if rfk_uk else ""
    hits_uk = [txt(x) for x in s.listing(M.search(lua_str(first[:5].lower())))]
    check("search in Ukrainian (lower case) finds the dungeon", rfk_uk in hits_uk, hits_uk[:6])
    hits_uk2 = [txt(x) for x in s.listing(M.search(lua_str(first[:5])))]
    check("search in Ukrainian (as written) finds the dungeon", rfk_uk in hits_uk2, hits_uk2[:6])
    hits_en = [plain(txt(x)) for x in s.listing(M.search(lua_str("razorf")))]
    check("search in English still works", any(rfk_uk == h or "Razorfen" in h for h in hits_en), hits_en[:6])
    M.search(lua_str(""))
    s.pump(5)

    # 5. The show-original key: English after 0.25 s, Ukrainian again on release.
    s.set_tab("bosses")
    M.key(True)
    s.pump(1)
    early = s.has(boss_uk) if boss_uk else True
    M.wait(HELD)
    held_en = s.has("Charlga Razorflank")
    M.key(False)
    M.wait(0.1)
    back = s.has(boss_uk) if boss_uk else False
    check("hold key: nothing at once, English after 0.25 s, Ukrainian on release",
          early and held_en and back, f"early={early} held={held_en} back={back}")
    check("FDJ's saved language still untouched after the key", s.saved_language() in (None, "auto"),
          s.saved_language())

    # 6. Fonts: ours on the journal's text, Blizzard's shared font objects unchanged.
    s.pump(5)
    ours = int(M.ourFonts())
    facts["font_strings_with_our_font"] = ours
    check("our font on the journal's text", ours > 20, ours)
    check("shared font objects untouched", txt(M.fonts()) == fonts_before)

    probe_before = screen_checks(s, check, facts, item_en, item_uk)
    flow_dj_words.run(s, check, facts)     # Favourites, place lines, loot types, Trash Drops
    flow_dj_head.run(s, check, facts)      # the header's level line and notes; quest giver lines
    flow_dj_shift.run(s, check, facts)     # Shift on search results and on a shut journal
    flow_dj_summon.run(s, check, facts)    # the summon line, the joined-item row; no half lines

    # 7. Русский: we step aside; Українська: we come back.
    s.switch_language("Русский")
    ru_ok = (txt(M.language()) == "ruRU" and s.saved_language() == "ruRU" and txt(M.choice()) == "other"
             and s.current_language_label() == "Русский")
    check("picking Русский steps aside", ru_ok and not s.has(boss_uk or "\0"),
          f"{txt(M.language())} saved={s.saved_language()} choice={txt(M.choice())}")
    check("our fonts put back under Русский", int(M.ourFonts()) == 0, int(M.ourFonts()))
    check("the test text's font put back exactly under Русский", txt(triple(M.probeNow(), 3)[0]) == probe_before,
          txt(triple(M.probeNow(), 3)[0]))
    ru_set, ru_cyr = triple(M.probeSet(16, lua_str("")), 2)
    M.probeSet(17, lua_str("OUTLINE"))
    check("under Русский our font hooks do nothing", not ru_cyr, txt(ru_set))
    s.switch_language(UK)
    check("picking Українська comes back", txt(M.language()) == "ukUA" and txt(M.choice()) == "uk"
          and s.current_language_label() == UK and s.has(boss_uk or "\0"), s.current_language_label())
    check("FDJ's saved language never ukUA", s.saved_language() == "ruRU", s.saved_language())

    # 8. /uadd dj off: pure FDJ (with its saved Русский); on: Ukrainian again.
    s.uadd("dj off")
    loc, content = M.tables()
    check("/uadd dj off: FDJ as without UADD", not loc and not content and txt(M.language()) == "ruRU"
          and not M.entryShown(), f"tables={loc},{content} lang={txt(M.language())}")
    check("/uadd dj off: our fonts put back", int(M.ourFonts()) == 0, int(M.ourFonts()))
    off_probe = txt(triple(M.probeNow(), 3)[0])
    off_title, off_title_cyr, _ = triple(M.titleFont(), 3)
    check("/uadd dj off: the original font back exactly (file, size, flags, object)",
          off_probe == probe_before and not off_title_cyr and txt(off_title) == facts["title_font"][2],
          f"{probe_before} -> {off_probe}; title {txt(off_title)} (was {facts['title_font'][2]})")
    off_set, off_cyr = triple(M.probeSet(16, lua_str("")), 2)
    M.probeSet(17, lua_str("OUTLINE"))
    check("/uadd dj off: our font hooks do nothing", not off_cyr, txt(off_set))
    s.uadd("dj on")
    check("/uadd dj on: Ukrainian again", txt(M.language()) == "ukUA" and s.has(boss_uk or "\0"),
          txt(M.language()))
    check("shared font objects still untouched", txt(M.fonts()) == fonts_before)

    flow_dj_prose.run(s, check)            # the long texts, with a stand-in table

    errs = s.new_errors()
    check("no Lua errors", not errs, "; ".join(f"{w}: {m[:160]}" for w, m in errs[:3]))
    hidden = s.swallowed()
    check("no errors hidden by the journal's pcall", not hidden, "; ".join(h[:160] for h in hidden[:3]))

    # 9. OpenMap's dungeon view (the stand-in) with UADD_OpenMap, then the guard on the whole game.
    q_uk = flow_openmap.in_game(s, om_check, facts)
    boxes = session.cyr_boxes(s.client)
    check("no Ukrainian text in a font without Ukrainian letters", not boxes, boxes[:3])
    return s.client.dump_saved(), q_uk


def main():
    if loader.lua_runtime() is None:
        print("cannot run: lupa is not installed (pip install lupa)")
        return 2
    missing = missing_addons()
    if missing:
        print("cannot run: missing addons: " + ", ".join(missing))
        return 2
    t0 = time.time()
    checks, facts = run()
    bad = [c for c in checks if not c.ok]
    for c in checks:
        print(("ok    " if c.ok else "FAIL  ") + c.name + (f"  [{c.detail}]" if c.detail else ""))
    print(json.dumps(facts, ensure_ascii=False, indent=1))
    print(f"{len(checks) - len(bad)}/{len(checks)} passed in {time.time() - t0:.0f} s")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
