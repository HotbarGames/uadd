"""The flow checks: real UADD files next to the real Questie, QuestieDB and UALLF, in one game.

`run()` plays a few sessions (first login with names shown live, /reload, every /uadd command,
off and on again, combat) and returns a list of Check(name, ok, detail). Any Lua error anywhere
fails its step.
"""
import collections
import os
import time

import flow_controls
import session
from flow_dropdown import dropdown
from flow_live import Live
from flow_header import BLIZZ_TAB, OPTIONS_TITLE, POPUP_TAB, header, late_header
from flow_original import Original
from flow_reverse import reverse, reverse_login
from flow_routes import ARNAK, route_off
from flow_tracker import DEFAULT_FONT, Tracker, old_fonts
from loader import read_text, txt, lua_str

Check = collections.namedtuple("Check", "name ok detail")
HERE = os.path.dirname(os.path.abspath(__file__))

L10N = {
    "General": "Загальне",
    "General Options": OPTIONS_TITLE,
    "Show Minimap Button": "Кнопка на мінікарті",
    "Auto Accept Quests": "Автоприйняття завдань",
    "Auto Complete": "Автоздача",
}
COMMANDS = ["", "questie", "questie on", "questie rebuild", "questie test", "questie nonsense", "nonsense"]
# Globals our files may write: our own, the slash command and Questie's documented override.
OUR_WRITES = {"UADD", "UADD_DB", "SLASH_UADD1", "QUESTIE_LOCALES_OVERRIDE"}


class Flow:
    def __init__(self):
        self.checks = []
        self.facts = {}

    def check(self, name, ok, detail=""):
        self.checks.append(Check(name, bool(ok), detail))
        return ok

    def start(self, saved=None):
        c = session.session(saved)
        c.lua.execute(read_text(os.path.join(HERE, "flow.lua")))
        c.lua.execute(read_text(os.path.join(HERE, "flow_tracker.lua")))
        c.lua.execute(read_text(os.path.join(HERE, "flow_live.lua")))
        c.lua.execute(read_text(os.path.join(HERE, "flow_original.lua")))
        c.lua.execute(read_text(os.path.join(HERE, "flow_dropdown.lua")))
        c.lua.execute(read_text(os.path.join(HERE, "flow_controls.lua")))
        c.F = c.H.flow
        c.F.spyReset()
        c.seen_errors = 0
        return c

    def no_errors(self, c, step):
        errs = c.errors()[c.seen_errors:]
        c.seen_errors += len(errs)
        detail = "; ".join(f"{w}: {m}" for w, m, _ in errs[:3])
        return self.check(f"{step}: no Lua errors", not errs, detail)

    def collect(self, c):
        t0 = time.time()
        frames, idle = c.F.collect(200000)
        return idle, time.time() - t0, frames


def _ok_text(got, want):
    return txt(got) == want, f"{txt(got)!r} (want {want!r})"


def run():
    f = Flow()

    # 1-2. First login: every addon loads, Questie becomes ready, Questie speaks Ukrainian.
    t0 = time.time()
    c = f.start()
    f.facts["load_seconds"] = round(time.time() - t0, 1)
    f.check("login: Questie ready", c.ev("Questie.API.isReady"), f"{c.ready_frames} frames")
    f.no_errors(c, "login")
    for key, want in L10N.items():
        f.check(f"l10n {key!r}", *_ok_text(c.F.l10n(lua_str(key)), want))

    # 3. Lookups through ns.UALL.
    U = c.H.ns.UADD_Questie.UALL
    f.check("UALL.IsAvailable()", U.IsAvailable())
    c.F.spy()
    res = c.F.lookups(12)
    for kind in ("zone", "npc", "item", "quest", "spell"):
        r = res[kind]
        f.check(f"UALL {kind}: UALLF text for samples", r.asked > 0 and r.same == r.asked,
                f"{r.same}/{r.asked}" + (f", e.g. {txt(r.bad)}" if r.bad else ""))
    zone, npc, item, quest, kept, n, spell, touched = c.F.madeUp()
    f.check("UALL: made-up names give nil", not (zone or npc or item or quest or spell),
            f"zone={txt(zone)} npc={txt(npc)} item={txt(item)} quest={txt(quest)} spell={txt(spell)}")
    one, frost, none, wait = c.F.castingBar()
    f.check("UALL spell: a bar whose unit casts is not borrowed", one == frost and bool(one),
            f"{txt(one)} (UALLF: {txt(frost)})")
    f.check("UALL spell: every unit casting: nil, 'not now'", (none, wait) == (False, True), f"{txt(none)} {wait}")
    f.check("UALL: Blizzard font strings keep text and colour", kept == n, f"{kept}/{n}")
    f.check("UALL: no Blizzard font string is written to (another addon's hook saw no call on it)",
            touched == 0, f"{touched} calls")
    f.check("UALL: an answer in combat is nil, 'not now'", c.F.combatLookup("Zzyzx Combat Rock") == (False, True))
    c.H.combat = False
    arnak, twin, twin_wait, npc, npc_wait, pair, style, same = c.F.variants()
    f.check("UALL quest: spelling variant found", *_ok_text(arnak, ARNAK))
    f.check("UALL quest: two variants, different words: skipped", not (twin or twin_wait),
            f"{txt(twin)} {twin_wait}")
    f.check("UALL quest: variant that is an NPC name: skipped", not (npc or npc_wait), f"{txt(npc)} {npc_wait}")
    f.check("UALL quest: two variants, one answer: taken", pair)
    f.check("UALL quest: same words in two styles: closest English wins", style)
    f.check("UALL quest: case, marks, quotes and dashes do not change the meaning", same)
    f.no_errors(c, "lookups")

    # 3b. Questie's tracker before any names are known: exactly Questie's English.
    T, live = Tracker(f), Live(f)
    T.baseline(c)
    live.english(c, "before names")
    c.F.addExtraQuest()
    live.extra(c, "before names", after=False)
    f.no_errors(c, "tracker before names")

    # 4. The background collection finishes and reaches QuestieDB.
    idle, secs, frames = f.collect(c)
    N = c.H.ns.UADD_Questie.Names
    counts = {k: int(N.counts[k]) for k in ("Quest", "Npc", "Item", "zones")}
    totals = {k: int(c.F.total(k)) for k in ("Quest", "Npc", "Item")}
    f.facts.update(collect_seconds=round(secs, 1), collect_frames=int(frames), counts=counts, totals=totals,
                   set_correction_calls=int(c.F.setCorrection))
    f.check("names: collection finishes", idle, f"{frames} frames, {secs:.1f} s")
    f.check("names: every kind found some", all(counts.values()), str(counts))
    f.check("names: SetCorrection called", c.F.setCorrection >= 3, str(c.F.setCorrection))
    live.first(c, c.chat)          # 4a. shown in this session: no /reload
    live.extra(c, "live", after=True)
    f.check("font: tracker fonts left as Questie's", list(c.F.fonts()) == [DEFAULT_FONT] * 4, str(list(c.F.fonts())))
    qid, uk, en = c.F.ukQuest()
    f.check("names: QuestieDB has a Ukrainian quest name", qid, f"{qid}: {txt(en)} -> {txt(uk)}")
    f.check("names: quest found by a spelling variant", *_ok_text(c.F.questName(5147), ARNAK))
    T.stays_english(c, "collection")       # UALL Forever translates the tracker, not UADD
    f.no_errors(c, "collection")
    O = Original(f, T)                           # 4c. the "[34D]" letter; the show-original key
    O.dungeon(c, "collection")
    O.font_safe(c, "collection")
    O.hold(c, "show original", 867, "Harpy Raiders")
    O.pin(c, "show original")
    O.combat_key(c, "show original, combat key")
    O.other_key(c, "show original")
    reverse(O, c, "show original, UALLF reverse")
    O.perf(c, "show original")
    f.no_errors(c, "show original")
    header(f, c, "first login", BLIZZ_TAB, True)
    header(f, c, "first login", POPUP_TAB, True, popup=True)
    late_header(f, c, "first login")
    dropdown(f, c, "first login")
    flow_controls.first(f, c, "first login")
    f.no_errors(c, "options header")

    # 4b. /reload: the saved names are back before Questie builds its data, no new collection.
    saved = c.dump_saved()
    c2 = f.start(saved)
    f.check("reload: Questie ready", c2.ev("Questie.API.isReady"))
    f.check("reload: no second collection", c2.H.ns.UADD_Questie.Names.Progress() is None)
    f.check("reload: QuestieDB name Ukrainian", *_ok_text(c2.F.questName(qid), txt(uk)))
    T.stays_english(c2, "reload")
    live.same_after_reload(c2)
    f.no_errors(c2, "reload")
    reverse_login(f)                           # UALLF reverse mode saved: English from the start
    old_fonts(f, saved)                        # the old UADD's tracker fonts go back

    # 5. Every /uadd command. The rebuild runs without the Questie function the live path needs.
    for cmd in COMMANDS:
        before = len(c2.chat())
        if cmd == "questie rebuild":
            live.fallback(c2, lambda: (c2.slash(cmd), f.check("rebuild: finishes", f.collect(c2)[0])))
        else:
            c2.slash(cmd)
        f.no_errors(c2, f"/uadd {cmd}".strip())
        f.check(f"/uadd {cmd}: replies".replace("  ", " "), len(c2.chat()) > before)
    live.failures(c2, lambda: f.collect(c2))     # 5b. stuck rebuild, Questie not started, end fails
    f.no_errors(c2, "live path failures")

    # 6. Off + reload = English; on + reload = Ukrainian again.
    header(f, c2, "before off", BLIZZ_TAB, True)
    controls_before = flow_controls.snapshot(c2)
    c2.slash("questie off")
    header(f, c2, "off", BLIZZ_TAB, False)
    flow_controls.after_off(f, c2, controls_before, "off")
    T.stays_english(c2, "off", on=False)
    O.dungeon(c2, "off")
    c2.F.key("SHIFT", True)
    f.check("off: show-original key does nothing", not c2.H.ns.UADD_Questie.Original.held
            and txt(c2.F.l10n(lua_str("General"))) == "General")
    c2.F.key("SHIFT", False)
    f.no_errors(c2, "off")
    c3 = f.start(c2.dump_saved())
    f.check("off+reload: l10n English", *_ok_text(c3.F.l10n(lua_str("General")), "General"))
    f.check("off+reload: QuestieDB name English", *_ok_text(c3.F.questName(qid), txt(en)))
    T.stays_english(c3, "off+reload", on=False)
    header(f, c3, "off+reload", BLIZZ_TAB, False)
    c3.slash("questie on")
    f.no_errors(c3, "off+reload")
    c4 = f.start(c3.dump_saved())
    f.check("on+reload: l10n Ukrainian", *_ok_text(c4.F.l10n(lua_str("General")), L10N["General"]))
    f.check("on+reload: QuestieDB name Ukrainian", *_ok_text(c4.F.questName(qid), txt(uk)))
    T.stays_english(c4, "on+reload")
    c4.slash("questie rebuild")                  # off while collecting: Questie is not rebuilt
    c4.ev("function(n) return HARNESS.pump(n, nil, 0.05) end")(20)
    c4.slash("questie off")
    c4.F.collect(400)
    f.check("off while collecting: no rebuild, no 'ready'", c4.F.resets == 0
            and not any("назви готові" in x for x in c4.chat()), str(c4.F.resets))
    f.no_errors(c4, "on+reload")

    # 7. Combat pauses the collection; it goes on after combat.
    c5 = f.start()
    c5.F.fillLog()
    N5 = c5.H.ns.UADD_Questie.Names
    c5.ev("function(N) return HARNESS.pump(2000, function() local a = N.Progress() return a and a > 0 end, 0.05) end")(N5)
    # UALLF shows English while its key (Shift) is held, so UALL says "not now": the collection
    # waits on the same name instead of saving it as a miss, then goes on.
    pump = c5.ev("function(n) return HARNESS.pump(n, nil, 0.05) end")
    c5.H["keys"].SHIFT = True
    held = N5.Progress()
    pump(400)
    f.check("shift held: collection waits", N5.Progress() == held, f"{held} -> {N5.Progress()}")
    c5.H["keys"].SHIFT = False
    pump(60)
    f.check("shift released: collection goes on", N5.Progress()[0] > held[0], str(N5.Progress()))
    c5.H.combat = True
    asked = N5.Progress()
    pump(400)
    paused = N5.Progress()
    f.check("combat: collection pauses", paused is not None and paused[0] == asked[0], f"{asked} -> {paused}")
    c5.H.combat = False
    c5.F.combatAtFinish()                        # 7b. ...and ends in combat: Questie waits too
    idle, _, _ = f.collect(c5)
    f.check("combat: collection resumes and finishes", idle)
    f.check("combat: same counts after combat", {k: int(N5.counts[k]) for k in counts} == counts)
    pump(200)
    f.check("combat at the end: no rebuild in combat", c5.H.combat and c5.F.resets == 0, str(c5.F.resets))
    c5.H.combat = False
    c5.H.fire("PLAYER_REGEN_ENABLED")
    c5.F.settle()
    f.check("after combat: Questie rebuilt once", c5.F.resets == 1, str(c5.F.resets))
    live.shown(c5, "after combat")
    # 7c. A rebuild that ends in combat, then /uadd questie off before combat is over: no rebuild.
    c5.slash("questie rebuild")
    c5.F.combatAtFinish()
    f.collect(c5)
    c5.slash("questie off")
    c5.H.combat = False
    c5.H.fire("PLAYER_REGEN_ENABLED")
    pump(200)
    f.check("off while waiting for combat to end: no rebuild", c5.F.resets == 1, str(c5.F.resets))
    f.no_errors(c5, "combat")

    # 7d. A part of UALLF's translation switched off: that kind stays English, no stall.
    for key in ("world.zones", "interface.storage", "interface.loot", "gossip"):
        route_off(f, key, (qid, uk, en), counts)

    # 8. Globals our files read but nobody defines, and globals they write.
    for name, cl in (("first login", c), ("combat session", c5)):
        missing = [txt(x) for x in cl.lines(cl.H.listOf(cl.H.ourMissing))]
        f.check(f"globals: none undefined ({name})", not missing, ", ".join(missing))
        boxes = session.cyr_boxes(cl)
        f.check(f"guard: no Ukrainian text in a font without Ukrainian letters ({name})", not boxes, boxes[:3])
    writes = {txt(x) for x in c.lines(c.H.ourWriteList())}
    f.check("globals: only our own written", writes <= OUR_WRITES, ", ".join(sorted(writes - OUR_WRITES)))
    f.facts["globals_written"] = sorted(writes)
    return f
