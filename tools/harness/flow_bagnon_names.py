"""UADD_Bagnon: the game's own words in Bagnon come from UALL Forever (UADD_Bagnon/Game.lua), on the Bagnon
stand-ins with the parts flow_bagnon_names.lua adds (the frame list, the frame settings page, three tooltips).
UALL Forever is a stand-in too (UADD.UALL.Text answers from a table), so each case is set here:

  1. A word it has: the frame list, the "Display" header, the "Never" choice, the Help page's name and title,
     the Money check, the search and money tooltips and the right-click "Options" line show its Ukrainian.
  2. A word it lacks ("Bank") stays English; "Always" stays English; the title bar's line with Bagnon's own
     English before "Search" stays whole English (no half line).
  3. "Not now" at load (the Help name): asked again a little later, then Ukrainian.
  4. The hold key and "/uadd bagnon off": the game's English everywhere; key up and "on": Ukrainian again.
"""
import os

import flow_bagnon as fb
from loader import read_text, txt

HERE = os.path.dirname(os.path.abspath(__file__))
UK = {"Search": "Пошук", "Display": "Показ", "Never": "Ніколи", "Inventory": "Інвентар", "Help": "Довідка",
      "Money": "Гроші", "Options": "Параметри"}
CYR = ("Ѐ", "ӿ")


def _cyr(s):
    return any(CYR[0] <= ch <= CYR[1] for ch in (s or ""))


class NamesClient(fb.BgnClient):
    """The stand-ins plus the parts that show the game's words; UALL Forever's stand-in after UADD loads."""

    def run_addon_files(self, a):
        if a.name == fb.LATER:
            self.H.bgnNames.stub()
        super().run_addon_files(a)
        if a.name == "Bagnon":
            self.H.bgnNames.core()
        elif a.name == fb.LATER:
            self.H.bgnNames.config()


def _game():
    c = NamesClient([fb._stand_in("Bagnon"), fb._addon("UADD"), fb._addon(fb.MODULE), fb._stand_in(fb.LATER)],
                    None, "enUS")
    c.lua.execute(read_text(os.path.join(HERE, "flow_bagnon.lua")))
    c.lua.execute(read_text(os.path.join(HERE, "flow_bagnon_names.lua")))
    N = c.H.bgnNames
    for en, uk in UK.items():
        N.say(en, uk.encode(), en == "Help")          # the Help name: "not now" at load
    return c, c.H.bgn, N


def _seen(N):
    page = N.page()
    out = {"frames": [txt(x) for x in N.frameNames().values()], "header": txt(page.header),
           "never": txt(page.never), "always": txt(page.always), "help": txt(N.conf("Help") or ""),
           "helpTitle": txt(N.helpTitle() or ""), "money": txt(N.conf("Money") or "")}
    for what in ("Search", "Money", "title"):
        out["tip:" + what] = [txt(x) for x in N.hover(what).values()]
    return out


def run(check, facts):
    c, M, N = _game()
    c.start()
    c.H.pump(5)
    first = txt(N.conf("Help") or "")
    check("names 3: a word UALL Forever has not now stays English at first", first == "Help", first)
    N.say("Help", UK["Help"].encode())                # UALL Forever is ready now
    M.wait(3)
    c.H.pump(5)
    on = _seen(N)
    # 1. Words UALL Forever has.
    check("names 1: frame list from UALL Forever (Inventory)", on["frames"][0] == UK["Inventory"], on["frames"])
    check("names 1: header and choice from UALL Forever", on["header"] == UK["Display"] and on["never"] == UK["Never"],
          (on["header"], on["never"]))
    check("names 3: Help name after 'not now', page title too", on["help"] == UK["Help"]
          and on["helpTitle"].startswith(UK["Help"] + "  "), (on["help"], on["helpTitle"]))
    check("names 1: Money check label", on["money"] == UK["Money"], on["money"])
    check("names 1: search and money tooltips", on["tip:Search"] == [UK["Search"]]
          and on["tip:Money"][0] == UK["Money"], (on["tip:Search"], on["tip:Money"]))
    title = on["tip:title"]
    check("names 1: the right-click line: icon and UALL Forever's word", len(title) == 3
          and title[2].endswith(" " + UK["Options"]) and not _cyr(title[2][:-len(UK["Options"])]), title)
    # 2. Words it lacks, and lines with other English in them.
    check("names 2: a word UALL Forever lacks stays English (Bank)", on["frames"][1] == "Bank", on["frames"])
    check("names 2: 'Always' stays English", on["always"] == "Always", on["always"])
    check("names 2: the title bar's drag line stays whole English", len(title) > 1 and not _cyr(title[1])
          and title[1].endswith(" Search"), title[1:2])
    asked = {txt(k): int(v) for k, v in N.asked.items()}
    check("names: UALL Forever asked for each game word shown", all(asked.get(w) for w in UK), asked)
    # 4. The hold key, off and on.
    english = {"frames": ["Inventory", "Bank"], "header": "Display", "never": "Never", "help": "Help",
               "money": "Money", "tip:Search": ["Search"],
               "helpTitle": "Help" + on["helpTitle"][len(UK["Help"]):]}

    def same(want):
        now = _seen(N)
        return [k for k, v in want.items() if now[k] != v], now
    for step, act, want in (("hold key down", lambda: M.key(True), english),
                            ("hold key up", lambda: M.key(False), on),
                            ("/uadd bagnon off", lambda: M.uadd("bagnon off"), english),
                            ("/uadd bagnon on", lambda: M.uadd("bagnon on"), on)):
        act()
        c.H.pump(5)
        bad, now = same(want)
        check(f"names 4: {step}: the game's {'English' if want is english else 'words from UALL Forever'}",
              not bad, [(k, now[k]) for k in bad][:3])
    errs = c.errors()
    check("names: no Lua errors", not errs, "; ".join(f"{w}: {m[:160]}" for w, m, _ in errs[:3]))
