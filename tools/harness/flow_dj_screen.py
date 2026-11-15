"""More of the Dungeon Journal module's checks (flow_dj_module.py runs them): what Screen.lua and
Fonts.lua do on the journal's windows, and two more games, one at a time: UALLF's storage route off
and a Russian client with the journal on "auto".
"""
from loader import lua_str, txt

UK = "Українська"


def triple(r, n=3):
    """A Lua call's results as a list of n (lupa gives None, one value or a tuple)."""
    r = r if isinstance(r, tuple) else (r,)
    return (list(r) + [None] * n)[:n]


def screen_checks(s, check, facts, item_en, item_uk):
    """Fonts across pages (a test text with its own object, size and OUTLINE; the title), item
    names on item rows only, and looks. Returns the test text's font before we changed it."""
    M = s.M
    # 6b. Fonts across pages: a test text with its own object, size and OUTLINE; the title.
    probe_before = txt(M.probe())
    s.open_dungeon("sfk")
    s.pump(10)
    title2 = triple(M.titleFont(), 3)
    fns = txt(M.setFontFns())
    s.open_dungeon("gnomer")
    s.pump(10)
    title3 = triple(M.titleFont(), 3)
    facts["title_font"] = [txt(title2[0]), txt(title3[0]), txt(title3[2]) if title3[2] else None]
    check("dungeon title has a Ukrainian-capable font on a 2nd and a 3rd dungeon",
          title2[1] and title3[1], facts["title_font"])
    check("font hooks installed once per text, not once per look", txt(M.setFontFns()) == fns, fns)
    now, orig, is_cyr = [txt(x) for x in triple(M.probeNow(), 3)]
    check("size and OUTLINE kept with our font file", is_cyr and now.split("/")[1:] == ["17", "OUTLINE", "GameFontNormalHuge"]
          and orig == probe_before, f"{probe_before} -> {now} (remembered {orig})")
    after, after_cyr = triple(M.probeSet(15, lua_str("THICKOUTLINE")), 2)
    _, orig15, _ = triple(M.probeNow(), 3)
    check("a font the journal sets again gets our file at once, its size and flags kept",
          after_cyr and txt(after).split("/")[1:3] == ["15", "THICKOUTLINE"]
          and (txt(orig15) or "").startswith("Fonts\\FRIZQT__.TTF/15/THICKOUTLINE"), f"{txt(after)} (remembered {txt(orig15)})")
    M.probeSet(17, lua_str("OUTLINE"))
    n_kept, bad_kept = triple(M.sizesKept(), 2)
    check("every changed text keeps its size and flags", int(n_kept) > 20 and not txt(bad_kept),
          f"{int(n_kept)} texts; {txt(bad_kept)[:200]}")

    # 6c. Item names only on item rows: a boss row with an item's English name keeps it.
    if item_en and item_uk:
        M.row(lua_str(item_en))
        s.pump(10)
        as_boss = txt(M.rowText())
        as_item = txt(M.rowSet(lua_str(item_en), 1234))
        reused = txt(M.rowSet(lua_str(item_en), None))
        M.rowDone()
        check("item names swapped on item rows only (a boss row keeps the same English name)",
              as_boss == item_en and as_item == item_uk and reused == item_en, [as_boss, as_item, reused])
    else:
        check("item names swapped on item rows only", False, "no item name with a Ukrainian name to test with")

    # 6d. Looks: none with every window hidden, one for a burst of reads with the window shown.
    M.countLooks()
    M.hideAll()
    s.pump(10)
    M.countLooks()
    M.burst(500)
    s.pump(10)
    hidden_looks = int(M.looksSince())
    check("no look while no journal window is shown", not M.anyShown() and hidden_looks == 0, hidden_looks)
    s.open_dungeon("rfk")
    s.pump(10)
    M.countLooks()
    M.burst(500)
    s.pump(10)
    shown_looks = int(M.looksSince())
    check("500 reads with the window shown bring one look", shown_looks == 1, shown_looks)
    s.set_tab("bosses")
    return probe_before


def run_storage_off(make, check, facts):
    """UALLF's storage route off (its quest and bag-title words stay English): the collection
    still ends, the dungeon names are saved, and no «took long» message is printed."""
    s = make(saved={"UALLF": 'UALLFSettingsDB = { ["interface.storage"] = false }'})
    M = s.M
    done = M.collect(200000)
    off = bool(M.routeOff("Quest"))
    saved = bool(M.zonesSaved())
    slow = [line for line in s.chat if "довго" in line]
    dungeons, total = triple(M.counts(), 2)
    facts["storage_off"] = {"route_off": off, "dungeons": f"{dungeons}/{total}", "zones_saved": saved}
    check("UALLF storage route off: collection ends, dungeon names saved, no «довго»",
          off and done and saved and not slow, f"{facts['storage_off']} slow={slow[:1]}")
    errs = s.new_errors()
    check("UALLF storage route off: no Lua errors", not errs, "; ".join(f"{w}: {m[:160]}" for w, m in errs[:3]))


def run_client_locale(make, check, facts):
    """A Russian client with the journal on "auto": the journal is in the player's language, so
    the module steps aside (Українська stays in the menu to pick)."""
    s = make(locale="ruRU")
    M = s.M
    s.open_dungeon("rfk")
    s.pump(10)
    lang, wants, ours = txt(M.language()), bool(M.wants()), int(M.ourFonts())
    labels = s.language_labels()
    facts["ruRU_client"] = {"language": lang, "wants": wants, "our_fonts": ours, "saved": s.saved_language()}
    check("ruRU client, journal on «auto»: the module steps aside",
          not wants and lang != "ukUA" and ours == 0 and s.saved_language() in (None, "auto")
          and s.current_language_label() != UK and UK in labels, facts["ruRU_client"])
    errs = s.new_errors()
    check("ruRU client: no Lua errors", not errs, "; ".join(f"{w}: {m[:160]}" for w, m in errs[:3]))
