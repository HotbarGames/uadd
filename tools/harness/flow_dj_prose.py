"""The journal's long texts (UADD_DungeonJournal/Prose.lua) in the DJ module flow.

A small stand-in Ukrainian table is made from the journal's live English (keys by Prose.Key), so
these checks do not depend on the translators' files. Checked: the quest page shows the Ukrainian
objective, note and warning with a UALL name filled in; a name UALL lacks stays English; Shift and
"/uadd dj off" give FDJ's own text exactly
(its own language there is Russian, so FDJ's Russian or the English); a translation of an older English text is not used; the
cut note (its closing first-quest line taken off; in combat it waits, then one redraw) and the
tracker's objective line. With the shipped data: every quest field we give is still the
translation of the journal's live English (FDJ.LocalizeQuestField does not compare it).
The Lua helpers are in flow_dj_prose.lua."""
import os

from loader import read_text, txt

HERE = os.path.dirname(os.path.abspath(__file__))


def run(s, check):
    s.lua.execute(read_text(os.path.join(HERE, "flow_dj_prose.lua")))
    D, M = s.H.djp, s.M
    nq, nt = D.shipped()
    check("prose: the shipped data matches the journal's English", nq > 0 and nt > 0,
          f"{nq} quests, {nt} texts")
    found, have, shown = D.templates()
    check("prose: the %s warnings found by hash in the journal and shown in Ukrainian",
          have > 0 and found == have and shown == have, f"{found} found, {shown} shown, of {have}")
    nf, bad = D.live()
    check("prose: every quest field we give still matches the journal's live English",
          nf > 0 and not txt(bad), f"{nf} fields; differ: {txt(bad) or 'none'}")
    w = D.setup()
    want = {k: txt(w[k]) for k in ("objective", "note", "warning", "cutEn", "cutUk", "enObjective",
                                    "enNote", "enWarning", "driftEn", "npc", "npcUk", "dungeon")}
    qid, drift_id = w["id"], w["driftId"]
    fields = [f for f in ("objective", "note", "warning") if want[f]]
    got = {f: txt(D.field(qid, f, w["en" + f.capitalize()])) for f in fields}
    check("prose: quest fields in Ukrainian (stand-in table)",
          len(fields) >= 2 and all(got[f] == want[f] for f in fields), f"quest {qid}: {got}")
    check("prose: a UALL name filled in, a name UALL lacks stays English",
          want["objective"] and want["npcUk"] in want["objective"] and (not want["note"] or D.UNKNOWN in want["note"]),
          f"{want['npc']} -> {want['npcUk']}")

    D.open(w["dungeon"], qid)
    M.wait(0.3)
    on_page = {f: bool(D.shown(w[f])) for f in fields}
    check("prose: the quest page shows them", all(on_page.values()), on_page)
    check("prose: the tracker's objective line in Ukrainian", txt(D.tracker(qid)) == want["objective"],
          txt(D.tracker(qid)))
    if drift_id:
        drift = txt(D.field(drift_id, "objective", w["driftEn"]))
        line = txt(D.tracker(drift_id))
        check("prose: a translation of an older English is not used", drift == want["driftEn"]
              and line == "Speak with someone", f"{drift_id}: {drift!r}; tracker {line!r}")

    if want["cutEn"]:
        shown = txt(D.note(w["cutEn"]))
        check("prose: the cut note in Ukrainian", shown == want["cutUk"], repr(shown[:80]))
        D.restoreNotes()
        check("prose: the cut note's English put back exactly", txt(D.note(None)) == want["cutEn"])
        during, lights = D.noteInCombat(w["cutEn"])
        check("prose: the cut note stays English in combat, the page is redrawn once after",
              txt(during) == want["cutEn"] and lights == 1, f"{txt(during)[:40]!r}; redraws {lights}")
        D.note(w["cutEn"])
    else:
        check("prose: the journal has a note it cuts", False, "none found")

    M.key(True)
    M.wait(0.3)
    held = {f: txt(D.field(qid, f, w["en" + f.capitalize()])) for f in fields}
    own = {f: txt(D.own(qid, f, w["en" + f.capitalize()])) for f in fields}
    lang = txt(M.language())
    page = bool(D.shown("UADDTEST"))
    note = txt(D.note(None))
    check("prose: Shift held gives FDJ's own texts exactly",
          lang != "ukUA" and held == own and not page
          and "UADDTEST" not in (note or "") and txt(D.note(w["cutEn"])) == want["cutEn"],
          f"{lang}: {held} vs {own}; page has ours: {page}; note {note!r:.60}")
    M.key(False)
    M.wait(0.3)
    check("prose: Ukrainian again on release", all(txt(D.field(qid, f, w["en" + f.capitalize()])) == want[f]
                                                   for f in fields))

    D.note(w["cutEn"])
    s.uadd("dj off")
    off = {f: txt(D.field(qid, f, w["en" + f.capitalize()])) for f in fields}
    own = {f: txt(D.own(qid, f, w["en" + f.capitalize()])) for f in fields}
    note = txt(D.note(None))
    check("/uadd dj off: FDJ's own long texts exactly",
          off == own and not D.shown("UADDTEST")
          and "UADDTEST" not in (note or "") and txt(D.note(w["cutEn"])) == want["cutEn"]
          and "UADDTEST" not in (txt(D.tracker(qid)) or ""), f"{off} vs {own}; note {note!r:.60}")
    s.uadd("dj on")
    check("/uadd dj on: the long texts in Ukrainian again", txt(D.field(qid, "objective", w["enObjective"]))
          == want["objective"])
    D.restore()
