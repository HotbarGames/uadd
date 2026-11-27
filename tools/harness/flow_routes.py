"""Flow checks for a UALLF route the player switched off (places, quests, loot or gossip).

UALLF then shows that kind of name in English, so we do too, and nothing waits for it: the
collection ends as fast as with every route on, the empty kind is saved, the next login uses the
saved copy, and switching the route back on collects the names once more. A route switched off in
the middle of a collection ends that kind at once too, and writes none of its names.
"""
from loader import txt, lua_str

KIND = {"world.zones": "zones", "interface.storage": "Quest", "interface.loot": "Item", "gossip": "Npc"}
FAST = 100             # frames, with the budget lifted (_budget): an off route takes 1; waiting for it took ~2550
READY = "назви готові"
OFF_LINE = "лишаються англійською, бо в налаштуваннях UALL Forever"
SLOW = "довго не відповідав"
# QuestieDB says "WANTED: Arnak Grimtotem"; UALLF has it as "Wanted - Arnak Grimtotem".
ARNAK_EN = "WANTED: Arnak Grimtotem"
ARNAK = "Розшукується — Арнак Ґрімтотем"
# Place names we wrote into Questie's l10n table (our own UI strings are written there too: skipped).
ZONES_WRITTEN = ('function(ns) local t, n = QuestieLoader:ImportModule("l10n").translations, 0 '
                 'for _, name in ipairs(ns.Locale.ZoneNames()) do local e = t[name] '
                 'if not (ns.uiStrings and ns.uiStrings[name] ~= nil) and type(e) == "table" '
                 'and type(e[ns.Locale.LOCALE]) == "string" then n = n + 1 end end return n end')


def _counts(c):
    N = c.H.ns.UADD_Questie.Names
    return {k: int(N.counts[k]) for k in ("Quest", "Npc", "Item", "zones")}


def _zones_written(c):
    return int(c.ev(ZONES_WRITTEN)(c.H.ns.UADD_Questie))


def _budget(c, ms):
    """The collector does BUDGET_MS of real-clock work per frame, so on a busy PC a frame does less and
    the frame count grows with CPU load. A huge budget makes a frame do all work that does not wait:
    the frames left are the waits (Schedule(1) on a "not now"), which is what FAST measures."""
    c.ev("function(ms) UADD.Collector.BUDGET_MS = ms end")(ms)


def _collect(f, c):
    """Collects, then waits for Questie's rebuild, after which the 'ready' line comes."""
    _budget(c, 1e9)
    out = f.collect(c)
    c.F.settle()
    return out


def _said(c, text):
    return sum(text in x for x in c.chat())


def _setting(key, value):
    return f'\nUALLFSettingsDB = UALLFSettingsDB or {{}}\nUALLFSettingsDB["{key}"] = {value}\n'


def _pump_until_asked(c, n):
    c.ev("function(N, n) return HARNESS.pump(200, function() local a = N.Progress() return a and a >= n end, 0.05) end")(
        c.H.ns.UADD_Questie.Names, n)
    return int(c.ev("function(N) return N.Progress() or 0 end")(c.H.ns.UADD_Questie.Names))


def _want(key, counts):
    """With loot or gossip off, 11 quest titles found only by a spelling variant stay English
    (QuestVariants.lua: Elsewhere). Places and quests do not take part in that check."""
    kind = KIND[key]
    want = dict(counts, **{kind: 0})
    if kind in ("Item", "Npc"):
        want["Quest"] -= 11
    return want


def route_off(f, key, quest, counts):
    """`quest`: (id, Ukrainian, English) of a quest UALLF knows by its exact title.
    `counts`: the name counts of a first login with every route on."""
    kind, want = KIND[key], _want(key, counts)
    qid, uk, en = quest

    # 1. Off from the start: a first login.
    c = f.start({"UALLF": _setting(key, "false")})
    idle, secs, frames = _collect(f, c)
    f.check(f"{key} off: collection finishes fast", idle and frames < FAST, f"{frames} frames, {secs:.1f} s")
    saved = sorted(txt(c.F.savedKinds()).split(","))
    f.check(f"{key} off: every kind saved, {kind} too", saved == ["Item", "Npc", "Quest", "zones"], str(saved))
    f.check(f"{key} off: {kind} English, the other kinds as usual", _counts(c) == want,
            f"{_counts(c)} (want {want})")
    want_q = txt(en) if kind == "Quest" else txt(uk)
    f.check(f"{key} off: exact-title quest as UALLF shows it", txt(c.F.questName(qid)) == want_q,
            txt(c.F.questName(qid)))
    want_v = ARNAK if kind == "zones" else ARNAK_EN
    f.check(f"{key} off: spelling-variant quest as expected", txt(c.F.questName(5147)) == want_v,
            txt(c.F.questName(5147)))
    if kind == "zones":
        f.check(f"{key} off: no place name written", _zones_written(c) == 0, str(_zones_written(c)))
    f.check(f"{key} off: one calm line about it, no 'UALL did not answer'",
            _said(c, READY) == 1 and _said(c, OFF_LINE) == 1 and not _said(c, SLOW), " | ".join(c.chat()[-3:]))
    f.no_errors(c, f"{key} off")

    # 2. The next login, nothing changed: the saved copy, no new collection.
    c2 = f.start(c.dump_saved())
    idle, _, frames = _collect(f, c2)
    f.check(f"{key} off, next login: saved names, no new collection",
            idle and not _said(c2, READY) and _counts(c2) == want, f"{frames} frames, {_counts(c2)}")
    f.no_errors(c2, f"{key} off, next login")

    # 3. Switched back on in UALLF, then a login: collected once more, that kind too.
    saved = c2.dump_saved()
    saved["UALLF"] = saved.get("UALLF", "") + _setting(key, "true")
    c3 = f.start(saved)
    idle, secs, frames = _collect(f, c3)
    f.check(f"{key} on again: names collected once, {kind} too",
            idle and _said(c3, READY) == 1 and not _said(c3, OFF_LINE) and _counts(c3) == counts,
            f"{frames} frames, {_counts(c3)} (want {counts})")
    f.no_errors(c3, f"{key} on again")

    # 4. Switched off midway: that kind ends at once, English, and is not saved as empty. An earlier
    # collection already wrote its places into Questie, so for places this runs on a first login.
    if kind == "zones":
        c4 = f.start()
        asked = _pump_until_asked(c4, 30)
    else:
        c4 = c3
        _budget(c4, 6)             # the shipped budget: the job must still be running when it is switched off
        c4.slash("questie rebuild")
        asked = _pump_until_asked(c4, 1)
    c4.F.uallOff(lua_str(key))
    idle, secs, frames = _collect(f, c4)
    cache_n = int(c4.ev(f'function() local n = 0 for _ in pairs(UADD.DB("questie").cache.{kind} or {{}}) do '
                        'n = n + 1 end return n end')())
    old_n = 0 if kind == "zones" else counts[kind]
    f.check(f"{key} off midway: finishes fast, {kind} English, old names kept for 'on'",
            idle and frames < FAST and _counts(c4)[kind] == 0 and cache_n == old_n
            and not _said(c4, SLOW) and _said(c4, OFF_LINE) == 1,
            f"{frames} frames, {_counts(c4)}, saved {kind} {cache_n}")
    if kind == "zones":
        f.check(f"{key} off midway: none of the places asked before it written",
                0 < asked < counts["zones"] and _zones_written(c4) == 0,
                f"asked {asked} of {counts['zones']}, written {_zones_written(c4)}")
    f.no_errors(c4, f"{key} off midway")
