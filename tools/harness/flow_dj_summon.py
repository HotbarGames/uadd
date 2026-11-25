"""The lines the journal builds with names in our words (Built.lua), in the DJ module flow.

Checked on the quest with summon help (found in the journal's data): its red line and its button
in Ukrainian when UALL has both names; the whole line in English when the item or the boss name is
missing (made-up names, through the journal's real function); exact English (as with "/uadd dj off")
while Shift is held, Ukrainian again on release; the open page in exact English after "/uadd dj off"
and Ukrainian after "on". Then the half-translation check (halves_mods.dj) on those two lines and on
the joined item's row. Ends on the Razorfen Kraul boss list. The Lua helpers are in flow_dj_summon.lua."""
import os
import re

import flow_dj_home
import halves_mods
from flow_dj_screen import triple
from loader import lua_str, read_text, txt

HERE = os.path.dirname(os.path.abspath(__file__))
CYR = re.compile("[А-Яа-яІіЇїЄєҐґ]")
MADE_UP = "Zorp Blatter"


def run(s, check, facts):
    s.lua.execute(read_text(os.path.join(HERE, "flow_dj_summon.lua")))
    X, M = s.H.djx, s.M
    key, qid, boss, item = triple(X.summonQuest(), 4)
    key, boss, item = txt(key), txt(boss), txt(item)
    en = s.lua.globals().ForeverDungeonJournal_NS.Locales.enUS
    en_note, en_button = txt(en.SUMMON_QUEST_NOTE), txt(en.HOW_TO_SUMMON)

    def open_quest():
        s.open_dungeon(re.sub("[^a-z]", "", key.lower()))
        s.set_tab("quests")
        for r in s.quest_rows():
            if r["id"] == qid:
                s.click(r["button"])
        return shown()

    def shown():
        return tuple(txt(v) for v in triple(X.shown(), 2))

    s.uadd("dj off")
    english = open_quest()
    s.uadd("dj on")
    uk = open_quest()
    want = tuple(txt(v) for v in triple(X.summonWant(lua_str(boss), lua_str(item)), 2))
    facts["dj_summon_names_in_uall"] = want[0] is not None
    check("summon: the quest's red line and button in Ukrainian",
          want[0] is not None and uk == want and all(CYR.search(t or "") for t in uk), f"{uk} vs {want}")
    check("summon: with /uadd dj off the line is the journal's English",
          english[0] is not None and not CYR.search(english[0] + (english[1] or "")), english)

    no_item = tuple(txt(v) for v in triple(X.summon(lua_str(boss), lua_str(MADE_UP)), 2))
    check("summon: an item UALL lacks gives the whole line in English",
          no_item[0] == en_note % (boss, MADE_UP) and no_item[1] == want[1], no_item)
    no_boss = tuple(txt(v) for v in triple(X.summon(lua_str(MADE_UP), lua_str(item)), 2))
    check("summon: a boss UALL lacks gives the line and the button in English",
          no_boss == (en_note % (MADE_UP, item), en_button % MADE_UP), no_boss)

    open_quest()
    M.key(True)
    M.wait(0.3)
    s.pump(5)
    held = shown()
    M.key(False)
    M.wait(0.3)
    s.pump(5)
    check("summon: Shift held gives the exact English", held == english, f"{held} vs {english}")
    check("summon: Ukrainian again on release", shown() == uk, shown())

    s.uadd("dj off")
    off = shown()
    s.uadd("dj on")
    check("summon: /uadd dj off puts the English back on the open page", off == english, f"{off} vs {english}")
    check("summon: /uadd dj on gives the Ukrainian again", shown() == uk, shown())

    halves_mods.dj(check, s)               # made-up English in each slot: never a half-translated line
    flow_dj_home.run(s, check, facts)      # Edit Mode on the home page, glued quest titles
    s.open_dungeon("rfk")                  # back where the module flow goes on
    s.set_tab("bosses")
