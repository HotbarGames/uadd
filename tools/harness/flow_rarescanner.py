"""UADD_RareScanner on a stand-in for RareScanner (tools/harness/rarescanner). RareScanner is All Rights
Reserved: the stand-in holds none of its English. RsClient runs the installed RareScanner's LibStub,
CallbackHandler, AceLocale, AceConfigRegistry and its enUS locale file (read only) before the stand-in,
so every word comes from RareScanner's own locale table. The expected Ukrainian is the module's data
(ns.AL); until that is built, flow_rarescanner.lua gives it a few made-up lines (M.data).

  * Game A (English client): stand-in, UADD, UADD_RareScanner. 1 The locale table holds ours; a key with
    a game-name slot and CHAT_NOTIFICATION_RARE stay English (never half). 2 Words read at load (settings
    table, page name, pop-ups, explorer tooltip) are ours; a finished line with slots too; a name that is
    not RareScanner's stays. 3 Fonts read back (the scanner button, a pop-up). 4 Hold key and "/uadd
    rarescanner off" give the English back exactly, "on" ours again. 5 No half-translated line. 6 Load
    is fast. No Lua errors.
  * Game B: no RareScanner (the module waits).
"""
import os
import re
import sys
from types import SimpleNamespace

import halves_mods
import session

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import make_bgn_text  # noqa: E402
import rs_rules as R  # noqa: E402
from flow import Check  # noqa: E402
from loader import Addon, Client, lua_str, read_text, txt  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
MODULE = "UADD_RareScanner"
TARGET = "RareScanner"
REAL = ("ExternalLibs/LibStub/LibStub.lua", "ExternalLibs/CallbackHandler-1.0/CallbackHandler-1.0.lua",
        "ExternalLibs/AceLocale-3.0/AceLocale-3.0.lua",
        "ExternalLibs/AceConfig-3.0/AceConfigRegistry-3.0/AceConfigRegistry-3.0.lua",
        "Locales/RareScanner-enUS.lua")
BAKED = ("page", "row", "desc", "value", "category", "title", "dialog", "scan", "tip")
LOAD_MS = 20


def addon_dir():
    base = os.environ.get("UADD_ADDONS_DIR") or next(
        (d for d in make_bgn_text.ADDON_DIRS if os.path.isdir(d)), make_bgn_text.ADDON_DIRS[0])
    return os.path.join(base, TARGET)


def installed():
    return all(os.path.isfile(os.path.join(addon_dir(), *r.split("/"))) for r in REAL)


def module_there():
    return os.path.isfile(os.path.join(session.REPO, MODULE, MODULE + ".toc"))


class RsClient(Client):
    """Runs the installed RareScanner's libraries and enUS locale (read only) before the stand-in."""

    def run_addon_files(self, a):
        if a.name == TARGET:
            self.H.addons[a.name].loading = True
            real = SimpleNamespace(name=a.name, folder=addon_dir())
            for rel in REAL:
                self.run_lua(real, rel)
        super().run_addon_files(a)


def _game(names):
    addons = [Addon(TARGET, os.path.join(HERE, "rarescanner"), session.FLAVOR)] if TARGET in names else []
    addons += [Addon(n, os.path.join(session.REPO, n), session.FLAVOR) for n in ("UADD", MODULE)]
    c = RsClient(addons, None, "enUS")
    c.lua.execute(read_text(os.path.join(HERE, "flow_rarescanner.lua")))
    M = c.H.rs
    c.start()
    c.H.pump(60)
    return c, M


def _errors(c, check, step):
    errs = c.errors()
    check(f"{step}: no Lua errors", not errs, "; ".join(f"{w}: {m[:160]}" for w, m, _ in errs[:3]))


def _baked(M):
    b = M.baked()
    return {k: txt(b[k]) for k in BAKED + ("other",)}


def game_a(check, facts):
    c, M = _game([TARGET])
    # 1. The locale table.
    w = lambda k: txt(M.want(k))  # noqa: E731
    plain = [k for k in ("SOUND", "DISPLAY", "EXPLORER_FILTERS", "EXPLORER_SCAN_NOT_DONE")]
    bad = [k for k in plain if txt(M.L(k)) != w(k)]
    check("1 locale table: ours for plain words", not bad, bad)
    check("1 locale table: ours for a template with a value slot",
          txt(M.L("EXPLORER_CUSTOM_ITEMS_TOOLTIP_ID")) == w("EXPLORER_CUSTOM_ITEMS_TOOLTIP_ID"), "")
    en_alarm, en_chat = txt(M.english("ALARM_MESSAGE")), txt(M.english("CHAT_NOTIFICATION_RARE"))
    check("1 a template with a game-name slot stays English (no half line)",
          txt(M.L("ALARM_MESSAGE")) == en_alarm and not any("Ѐ" <= ch <= "ӿ" for ch in en_alarm),
          txt(M.L("ALARM_MESSAGE")))
    line = txt(M.line("ALARM_MESSAGE", "Quixwood Stalker"))
    check("1 its line is all English with an English name", line == en_alarm.replace("%s", "Quixwood Stalker"),
          line)
    check("1 STAY: CHAT_NOTIFICATION_RARE stays English (sent to other players)",
          txt(M.L("CHAT_NOTIFICATION_RARE")) == en_chat and "[%s]" in en_chat, txt(M.L("CHAT_NOTIFICATION_RARE")))
    stay_bad = list(M.stayed().values())
    stay_cyr = [k for k in M.stay.values() if any("Ѐ" <= ch <= "ӿ" for ch in txt(M.L(k)))]
    stay_en = [k for k in M.stay.values() if M.L(k) is None]
    check("1 STAY keys (chat line; names kept in saved data) stay English",
          not stay_bad and not stay_cyr and not stay_en and sorted(M.stay.values()) == sorted(R.STAY),
          (stay_bad, stay_cyr, stay_en))
    facts["swapped"], facts["stand_in"] = int(M.swapped()), len(list(M.used.keys()))
    # 2. Words read at load.
    on = _baked(M)
    eng = [k for k in BAKED if not any("Ѐ" <= ch <= "ӿ" for ch in on[k])]
    check("2 read at load: settings, page name, pop-ups, explorer tooltip all ours", not eng,
          [(k, on[k][:60]) for k in eng])
    check("2 a finished line with four slots (the filter pop-up) is ours as a whole",
          on["dialog"].startswith(w("EXPLORER_FILTERING_DIALOG").split("%s")[0]) and "Filters" not in on["dialog"],
          on["dialog"][:80])
    check("2 a name that is not RareScanner's text stays as it is", on["other"] == "Quixwood Vale", on["other"])
    # 3. Fonts read back.
    shown = txt(M.show("EXPLORER_SCAN_NOT_DONE"))
    text, cyr = M.spawn("RS_SCAN")
    check("3 fonts: the scanner button and a pop-up show ours in our font",
          shown == w("EXPLORER_SCAN_NOT_DONE") and M.titleCyr() and txt(text) == w("EXPLORER_SCAN_NOT_DONE") and cyr,
          (shown, M.titleCyr(), txt(text), cyr))
    facts["fonts"] = int(M.fonts())
    # 4. Hold key, off, on.
    M.key(True)
    down = _baked(M)
    held = txt(M.L("SOUND"))
    M.key(False)
    base_sound = txt(M.english("SOUND"))
    check("4 hold key down: RareScanner's English (table and words read at load)",
          held == base_sound and all(not any("Ѐ" <= ch <= "ӿ" for ch in down[k]) for k in BAKED),
          [(k, down[k][:40]) for k in BAKED if any("Ѐ" <= ch <= "ӿ" for ch in down[k])])
    check("4 hold key up: ours again", _baked(M) == on and txt(M.L("SOUND")) == w("SOUND"), "")
    M.uadd("rarescanner off")
    off = _baked(M)
    check("4 /uadd rarescanner off: English back exactly, no font of ours",
          off == down and txt(M.L("SOUND")) == base_sound and not M.titleCyr() and int(M.fonts()) == 0,
          ([k for k in BAKED if off[k] != down[k]], int(M.fonts())))
    M.uadd("rarescanner on")
    check("4 /uadd rarescanner on: ours again", _baked(M) == on and txt(M.L("SOUND")) == w("SOUND"), "")
    later(check, M, w)
    # 5. No half-translated line.
    halves_mods.rs(check, M)
    span = "|cff00ffcc1h 5m|r"                  # RSTimeUtils.FormatShortDuration's own English units
    half = []
    for key in (k for k, s in R.SORTS.items() if "u" in s):
        args = [span if c == "s" else 5 for c in re.findall(r"%[-+ #0]*\d*\.?\d*([a-z])", txt(M.english(key)))]
        if _cyr(txt(M.line(key, *args))):
            half.append(key)
    check("5 a time span in RareScanner's English units: the line stays all English", not half, half)
    old = M.set("EXPLORER_FILTER_COLLECTIONS", None)
    eng = txt(M.L("EXPLORER_FILTERING_DESC")) == txt(M.english("EXPLORER_FILTERING_DESC"))
    M.set("EXPLORER_FILTER_COLLECTIONS", old)
    check("5 a template whose t word is not ours stays English", eng and _cyr(txt(M.L("EXPLORER_FILTERING_DESC"))), "")
    # 6. Load is fast: the module's own start and stop.
    ms = float(M.time(20))
    facts["load_ms"] = round(ms, 2)
    check(f"6 load: start and stop under {LOAD_MS} ms", ms < LOAD_MS, f"{ms:.2f} ms")
    _errors(c, check, "game A")


def _cyr(s):
    return any("Ѐ" <= ch <= "ӿ" for ch in s)


def later(check, M, w):
    """7 Words set after load: the explorer's labels (set once, when it first opens) and a page built by a
    function (built on first use, again after an import) follow the hold key, off and on both ways."""
    def ex():
        e = M.explorer()
        return {"rescan": txt(e["rescan"]), "tip": txt(e["tip"]), "scan": txt(e["scan"]), "manual": e["manual"]}

    def npcs():
        n = M.npcs()
        return txt(n["page"]), txt(n["row"])
    english = (txt(M.english("DISPLAY")), txt(M.english("EXPLORER_FILTERS")))
    ours = ex()
    check("7 explorer opened: its labels are ours, and its own compare still holds",
          ours["rescan"] == w("EXPLORER_RESCANN") and ours["scan"] == w("EXPLORER_SCAN_MANUAL") and _cyr(ours["tip"])
          and ours["manual"], ours)
    check("7 a page built by a function: ours", npcs() == (w("DISPLAY"), w("EXPLORER_FILTERS")), npcs())
    M.key(True)
    held, held_n = ex(), npcs()
    M.key(False)
    check("7 hold key down: explorer labels and the built page in English",
          not any(_cyr(v) for k, v in held.items() if k != "manual") and held["manual"] and held_n == english,
          (held, held_n))
    check("7 hold key up: ours again", ex() == ours and npcs() == (w("DISPLAY"), w("EXPLORER_FILTERS")), "")
    M.uadd("rarescanner off")
    off, off_n = ex(), npcs()
    M.rebuild()
    rebuilt_off = npcs()
    M.uadd("rarescanner on")
    check("7 /uadd rarescanner off: explorer labels and the built page English, as on hold",
          off == held and off_n == english and rebuilt_off == english, (off, off_n, rebuilt_off))
    M.rebuild()
    again = npcs()
    M.uadd("rarescanner off")
    after = npcs()
    M.uadd("rarescanner on")
    check("7 on again, page built again (an import): ours; off: English",
          ex() == ours and again == (w("DISPLAY"), w("EXPLORER_FILTERS")) and after == english, (again, after))


def game_b(check):
    c, M = _game([])
    out = " ".join(c.chat())
    c.slash("rarescanner")
    out = " ".join(c.chat())
    check("game B (no RareScanner): the module waits", "RareScanner" in out and "чекає" in out, out[-160:])
    _errors(c, check, "game B")


def run(check, facts):
    if not module_there() or not installed():
        halves_mods.rs(check, None)
        facts["note"] = "RareScanner or the module not there: skipped"
        return
    game_a(check, facts)
    game_b(check)


def run_checks():
    """Every check of this file. Returns (checks, facts)."""
    checks, facts = [], {}

    def check(name, ok, detail=""):
        checks.append(Check("rs: " + name, bool(ok), str(detail)))
    run(check, facts)
    return checks, facts


if __name__ == "__main__":       # alone: python3 tools/harness/flow_rarescanner.py
    cs, fs = run_checks()
    for x in cs:
        print(("ok    " if x.ok else "FAIL  ") + x.name + (f"  [{x.detail}]" if x.detail else ""))
    print(fs)
    print(f"{sum(x.ok for x in cs)}/{len(cs)} passed")
    sys.exit(0 if all(x.ok for x in cs) else 1)
