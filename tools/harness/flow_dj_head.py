"""The dungeon header's level line and the quest giver lines, in the DJ module flow.

Checked: the level ("Рів." and the range FDJ wrote) and the red notes beside it (some loot listed,
no loot listed, quests still being found) in Ukrainian, in a font with Ukrainian letters, no longer
than the English plus two letters (they share a row with the title: docs/LESSONS.md, lesson 5);
the exact English with Shift held and with "/uadd dj off", Ukrainian again on release and on
"/uadd dj on". Quest giver lines ("Name, Town, Zone"): all Ukrainian when UALL names every part,
else exactly English (docs/LESSONS.md lesson 6; also made-up lines with one unknown name, commas and
wide dash), the zone parts UALL names are in Ukrainian, and Belnistrasz's line on Razorfen Downs. The journal's English is read from it while the flow runs, never kept here.
Ends on the Razorfen Kraul boss list. The Lua helpers are in flow_dj_head.lua."""
import os
import re

from flow_dj_screen import triple
from loader import lua_str, read_text, txt

HERE = os.path.dirname(os.path.abspath(__file__))
CYR = re.compile("[А-Яа-яІіЇїЄєҐґ]")
HELD = 0.3
KEYS = ("dungeonMeta", "stockadeItemsTBD", "questsTBD")
BELNISTRASZ = ("Belnistrasz, Razorfen Downs", "Belnistrasz", "Razorfen Downs")
MADE_UP = "Wobbly Gizmo Hollow"     # a place nobody has a name for


def head(D):
    """{key: (text, shown, cyrillic font)} for the level line and its two notes."""
    out = {}
    for line in txt(D.head()).split("\n"):
        key, text, shown, cyr = line.split("\t")
        out[key] = (None if text == "nil" else text, shown == "true", cyr == "true")
    return out


def page(s, D, shortcut, tab):
    s.open_dungeon(shortcut)
    s.set_tab(tab)
    s.pump(5)
    return head(D)


def pages(s, D):
    """The bosses tab of Razorfen Downs (some loot listed) and the quests tab of Alcaz Prison."""
    return {"rfd": page(s, D, "rfd", "bosses"), "alcaz": page(s, D, "alcaz", "quests")}


def held(s, M, D):
    M.key(True)
    M.wait(HELD)
    s.pump(5)
    got = head(D)
    M.key(False)
    M.wait(HELD)
    s.pump(5)
    return got


def no_cyr(h):
    return all(not CYR.search(t or "") for t, _, _ in h.values())


def run(s, check, facts):
    s.lua.execute(read_text(os.path.join(HERE, "flow_dj_head.lua")))
    D, M, uk = s.H.djh, s.M, s.H.ns.UADD_DungeonJournal.Head.WORDS
    words = {k: txt(uk[k]) for k in ("level", "itemsSome", "itemsNone", "quests")}

    on = pages(s, D)
    rfd, alcaz = on["rfd"], on["alcaz"]
    meta = rfd["dungeonMeta"][0] or ""
    check("head: the level line in Ukrainian", re.fullmatch(r"Рів\. \d+\S*", meta) is not None, meta)
    check("head: the loot note in Ukrainian", rfd["stockadeItemsTBD"][:2] == (words["itemsSome"], True),
          rfd["stockadeItemsTBD"])
    check("head: the quests note in Ukrainian", alcaz["questsTBD"][:2] == (words["quests"], True), alcaz["questsTBD"])
    fonts = [k for h in on.values() for k, (t, shown, cyr) in h.items() if shown and CYR.search(t or "") and not cyr]
    check("head: in a font with Ukrainian letters", not fonts, fonts)

    some, none = triple(D.tbdKeys(), 2)
    note = txt(D.lootNote(none))
    check("head: the no-loot note in Ukrainian", note == words["itemsNone"], note)

    alcaz_held = held(s, M, D)
    check("head: Shift held gives English", no_cyr(alcaz_held), alcaz_held)
    check("head: Ukrainian again on release", head(D) == alcaz, head(D))

    s.uadd("dj off")
    off = pages(s, D)
    meta_en = off["rfd"]["dungeonMeta"][0] or ""
    check("/uadd dj off: the level line and notes in English", all(no_cyr(h) for h in off.values()), off)
    same = all(alcaz_held[k][:2] == off["alcaz"][k][:2] for k in KEYS)   # text and shown; fonts: flow_dj_module
    check("head: Shift held is the exact English", same,
          f"{alcaz_held} vs off {off['alcaz']}")
    check("head: the level keeps FDJ's range", meta.split(" ", 1)[1:] == meta_en.split(" ", 1)[1:],
          f"{meta!r} / {meta_en!r}")
    en = {"level": meta_en, "itemsSome": off["rfd"]["stockadeItemsTBD"][0] or txt(D.lootNote(some)),
          "itemsNone": txt(D.lootNote(none)), "quests": off["alcaz"]["questsTBD"][0]}
    ukt = {"level": meta, "itemsSome": words["itemsSome"], "itemsNone": words["itemsNone"], "quests": words["quests"]}
    long = {k: (ukt[k], en[k]) for k in en if len(ukt[k]) > len(en[k] or "") + 2}
    check("head: as short as the English (2 letters more at most)", not long, long)

    s.uadd("dj on")
    again = pages(s, D)
    check("/uadd dj on: the level line and notes in Ukrainian again", again == on, again)

    lines, changed, kept, bad, zones = triple(D.givers(), 5)
    check("givers: every name known and all Ukrainian, else exactly English", not txt(bad), txt(bad))
    check("givers: zone parts UALL names are in Ukrainian", int(zones) > 0, f"{int(zones)} zone parts")
    facts["dj_giver_lines"] = (f"{int(changed)} of {int(lines)} changed; {int(kept)} kept whole English for a name "
                               f"UALL lacks; {int(zones)} zone parts in Ukrainian")

    got, npc, zone = (txt(x) for x in triple(D.giver(*(lua_str(x) for x in BELNISTRASZ)), 3))
    want = f"{npc or BELNISTRASZ[1]}, {zone or BELNISTRASZ[2]}"
    check("givers: Belnistrasz's line on Razorfen Downs", zone is not None and got == want, f"{got!r} want {want!r}")
    for line in (f"{BELNISTRASZ[1]}, {MADE_UP}", f"{MADE_UP}, {BELNISTRASZ[2]}", f"{BELNISTRASZ[0]} — {MADE_UP}"):
        shown = txt(D.free(lua_str(line)))
        check(f"givers: a known name beside an unknown one stays whole English ({line})", shown == line, shown)
    s.open_dungeon("rfk")                  # ends where flow_dj_words left it
    s.set_tab("bosses")
