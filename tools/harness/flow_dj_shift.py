"""The show-original key (Shift) on the search results and on a shut journal, in the DJ module flow.

Checked: with the journal open, Shift on an English and on a Cyrillic search gives the rows the
journal shows with "/uadd dj off" (exact English), and release gives the Ukrainian rows again; a
Cyrillic search is run once per switch (the folded search only). With the journal shut and a search
still in its box, Shift down and up start no search at all; opened while Shift is held, the page
and the search are in English, and opened after release, in Ukrainian.
Then the Favourites window (its own window, open over any page): Shift on it off the home page,
with the journal shut, and shown after a switch made while it was hidden; the Favourites button
after a release on a dungeon page; and combat: nothing of ours redraws in it (Shift with the journal
open, the journal opened after a switch while shut), one redraw when it ends.
Starts and ends on the Razorfen Kraul boss list. The Lua helpers are in flow_dj_shift.lua."""
import os
import re

from flow_dj_screen import triple
from loader import lua_str, read_text, txt

HERE = os.path.dirname(os.path.abspath(__file__))
CYR = re.compile("[А-Яа-яІіЇїЄєҐґ]")
HELD = 0.3                 # seconds: the core waits 0.25 s before it shows the original
BOSS_EN = "Charlga Razorflank"
FAV_EN = {"title": "Favourites (1)", "empty": "Right Click on items you want to see as favourites.",
          "slot": "Two-Hand, Axe"}
FAV_UK_SLOT = "Дворучна, Сокира"


def run(s, check, facts):
    s.lua.execute(read_text(os.path.join(HERE, "flow_dj_shift.lua")))
    D, M = s.H.djs, s.M
    rfk_uk = txt(M.name("dungeon", "Razorfen Kraul")) or ""
    boss_uk = txt(M.name("boss", BOSS_EN)) or "\0"
    queries = ["razorf", rfk_uk.split(" ")[0][:5].lower()]

    def rows():
        return [txt(x) for x in s.listing(D.rows())]

    def search(q):
        M.search(lua_str(q))
        s.pump(5)
        return rows()

    def key(down):
        M.key(down)
        M.wait(HELD)
        s.pump(5)

    def page():
        return {"en": s.has(BOSS_EN), "uk": s.has(boss_uk), "texts": s.texts(), "rows": rows()}

    # The rows of pure FDJ (module off) for each query: the exact English.
    s.uadd("dj off")
    s.open_dungeon("rfk")
    s.set_tab("bosses")
    english = {q: search(q) for q in queries}
    search("")
    s.uadd("dj on")
    s.open_dungeon("rfk")
    s.set_tab("bosses")

    # 1. The journal open: Shift on the shown results.
    for q in queries:
        uk = search(q)
        D.countSearches()
        key(True)
        held, down = rows(), int(D.searchesSince())
        key(False)
        back, up = rows(), int(D.searchesSince()) - down
        check(f"Shift on shown search results ({q!r}): exact English, Ukrainian on release",
              held == english[q] and back == uk and held != uk, f"held {held[:3]} vs {english[q][:3]}; back {back[:3]}")
        check(f"Shift on shown search results ({q!r}): one search per switch", down == 1 and up == 1,
              f"down {down}, up {up}")
    facts["dj_shift_search_rows"] = {q: english[q][:2] for q in queries}

    # 2. The journal shut with a Cyrillic search in its box.
    q = queries[1]
    search(q)
    D.close()
    s.pump(5)
    D.open()
    s.pump(5)
    uk_page = page()                       # what a plain close and open shows
    key(True)
    en_page = page()                       # Shift with the journal open
    key(False)
    D.close()
    s.pump(5)
    D.countSearches()
    M.countLooks()
    key(True)
    shut_down = int(D.searchesSince())
    D.open()
    s.pump(5)
    reopened_en = page()
    D.close()
    s.pump(5)
    D.countSearches()
    key(False)
    shut_up = int(D.searchesSince())
    D.open()
    s.pump(5)
    reopened_uk = page()
    check("Shift with the journal shut: no search rebuilt", shut_down == 0 and shut_up == 0,
          f"down {shut_down}, up {shut_up}")
    # FDJ draws its labels (title, tabs) again when the window opens, so they are English too then;
    # with the window open they stay as drawn. Any text that differs must be English.
    other = [t for t in reopened_en["texts"] if t not in en_page["texts"]]
    check("opened while Shift is held: page and search in English",
          reopened_en["en"] and not reopened_en["uk"] and reopened_en["rows"] == english[q]
          and en_page["en"] and not en_page["uk"] and not [t for t in other if CYR.search(t)],
          f"boss en={reopened_en['en']} uk={reopened_en['uk']}; rows {reopened_en['rows'][:3]}; other texts {other[:6]}")
    check("opened after release: page and search in Ukrainian",
          reopened_uk == uk_page and uk_page["uk"] and not uk_page["en"] and uk_page["rows"] != english[q],
          f"boss en={reopened_uk['en']} uk={reopened_uk['uk']}; rows {reopened_uk['rows'][:3]}; "
          f"texts differ: {[t for t in reopened_uk['texts'] if t not in uk_page['texts']][:4]}")
    search("")
    s.open_dungeon("rfk")
    s.set_tab("bosses")
    run_fav(s, check, rows, search, key, english[q], q)


def run_fav(s, check, rows, search, key, english_rows, q):
    """The Favourites window, the Favourites button and combat (see the module docstring)."""
    D, W = s.H.djs, s.H.djw

    def fav():
        title, empty, slot, shown = triple(D.favWords(), 4)
        return {"title": txt(title), "empty": txt(empty), "slot": txt(slot), "shown": bool(shown)}

    def en(g):
        return g["shown"] and all(g[k] == v for k, v in FAV_EN.items())

    def uk(g):
        return (g["shown"] and (g["title"] or "").startswith("Обране") and g["slot"] == FAV_UK_SLOT
                and bool(CYR.search(g["empty"] or "")))

    def label():
        return txt(triple(W.fav(), 2)[1])

    s.click(s.frame.backButton)            # home: the Favourites button
    D.favAdd(lua_str(FAV_EN["slot"]))
    D.favToggle()
    s.pump(5)
    first = fav()
    check("favourites: the window in Ukrainian", uk(first), first)

    # A. Open over a dungeon page (the view is not home).
    s.open_dungeon("rfk")
    key(True)
    held = fav()
    key(False)
    back = fav()
    check("favourites over a dungeon page: Shift gives exact English, Ukrainian on release",
          en(held) and back == first, f"held {held}; back {back}")

    # B. The journal shut, the Favourites window alone (FDJ shuts it with the journal; shown again).
    D.close()
    D.favShow(True)
    s.pump(5)
    key(True)
    held = fav()
    key(False)
    back = fav()
    check("favourites with the journal shut: Shift gives exact English, Ukrainian on release",
          en(held) and back == first, f"held {held}; back {back}")

    # A switch while the window was hidden: right when it is shown next (shown directly, no FDJ draw).
    D.open()
    D.favShow(False)
    s.pump(5)
    key(True)
    D.favShow(True)
    s.pump(5)
    held = fav()
    D.favShow(False)
    key(False)
    D.favShow(True)
    s.pump(5)
    back = fav()
    check("favourites shown after a switch while hidden: English held, Ukrainian released",
          en(held) and back == first, f"held {held}; back {back}")
    D.favShow(False)
    D.favRemove()

    # The Favourites button: Shift on home, a dungeon page opened while held, released there, home.
    s.click(s.frame.backButton)
    key(True)
    held_label = label()
    s.open_dungeon("rfk")
    key(False)
    s.click(s.frame.backButton)
    check("Favourites button: Ukrainian again on home after a release on a dungeon page",
          held_label == "Favourites" and label() == "Обране", f"held {held_label!r}, back home {label()!r}")

    # Combat: Shift with the journal open and a search shown; nothing until combat ends, then one redraw.
    s.open_dungeon("rfk")
    s.set_tab("bosses")
    uk_rows = search(q)
    D.countSearches()
    D.combat(True)
    key(True)
    key(False)
    key(True)
    during, during_rows = int(D.searchesSince()), rows()
    D.combat(False)
    s.pump(5)
    after, after_rows = int(D.searchesSince()), rows()
    check("combat: Shift with the journal open waits for the end of combat, then one redraw",
          during == 0 and during_rows == uk_rows and after == 1 and after_rows == english_rows,
          f"searches in combat {during}, after {after}; rows after {after_rows[:2]}")
    key(False)

    # Combat: the journal opened in combat. FDJ's own draw on show runs the search once (FDJ may
    # redraw its frames in combat); ours (the folded Cyrillic search, or the redraw for a switch made
    # while it was shut) is one search after combat, nothing during it.
    def opened_in_combat(switch):
        D.close()
        s.pump(5)
        if switch:
            key(True)
        D.countSearches()
        D.combat(True)
        D.open()
        s.pump(5)
        during = int(D.searchesSince())
        D.combat(False)
        s.pump(5)
        return during, int(D.searchesSince()) - during

    fdj_own, fdj_after = opened_in_combat(False)
    during, after = opened_in_combat(True)
    after_rows = rows()
    check("combat: the journal opened after a switch while shut is redrawn by us only when combat ends",
          during == fdj_own == 1 and fdj_after == 1 and after == 1 and after_rows == english_rows,
          f"searches on show: FDJ's own {fdj_own} (+{fdj_after} after), with a switch {during} (+{after} after); "
          f"rows after {after_rows[:2]}")
    key(False)
    search("")
    s.open_dungeon("rfk")
    s.set_tab("bosses")
