"""The games of flow_att.py: an English (or German) client with the Attune stand-in
(tools/harness/attune) run on the real libraries of the installed Attune (its embeds.xml), UADD and
UADD_Attune, and the same player actions for every game, so a game without the module can be compared.
"""
import os

import session
from loader import Addon, Client, read_text, txt

HERE = os.path.dirname(os.path.abspath(__file__))
REAL = "/mnt/c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/Attune"
STAND_IN = Addon("Attune", os.path.join(HERE, "attune"), session.FLAVOR)
MODULE = "UADD_Attune"
SAVED = ("AttuneLang", "Attune_Data", "Attune_DB", "TreeExpandStatus", "AttuneLastViewed")


def module_there():
    return os.path.isfile(os.path.join(session.REPO, MODULE, MODULE + ".toc"))


def libraries_there():
    return os.path.isfile(os.path.join(REAL, "embeds.xml"))


def addon(name):
    return Addon(name, os.path.join(session.REPO, name), session.FLAVOR)


class AttClient(Client):
    """Runs the installed Attune's libraries and its own enUS words (read only, so the repo keeps none of
    its English) before the stand-in's own files."""

    def run_addon_files(self, a):
        if a.name == "Attune":
            self.H.addons[a.name].loading = True
            real = Addon("Attune", REAL, session.FLAVOR)
            self.run_xml(real, "embeds.xml")
            self.run_lua(real, "Locales/enUS.lua")
        super().run_addon_files(a)


def game(module=True, attune=True, locale="enUS"):
    addons = ([STAND_IN] if attune else []) + [addon("UADD")] + ([addon(MODULE)] if module else [])
    c = AttClient(addons, None, locale)
    c.lua.execute(read_text(os.path.join(HERE, "flow_att.lua")))
    c.lua.execute(read_text(os.path.join(HERE, "flow_att_ui.lua")))
    c.start()
    c.H.pump(60)
    c.H.att.wait(4)            # the module's name collect after login (UALL not there yet)
    return c, c.H.att


def errors(c, check, step):
    errs = c.errors()
    check(f"{step}: no Lua errors", not errs, "; ".join(f"{w}: {m[:160]}" for w, m, _ in errs[:3]))


def snaps(M):
    return {n: txt(M.snap(n)) for n in SAVED}


def player(M):
    """What a player does in every game, in this order. Returns the texts seen on the way."""
    seen = {}
    M.open()
    M.expand("World of Warcraft")
    M.wait(0.1)
    for v in ("RAIDS", "COMPLETED", "Will not do"):
        M.expand(v)
    M.wait(0.1)
    M.select("20")
    M.wait(0.1)
    for sid in ("30", "40", "20"):
        M.hover(sid)
        M.wait(0.05)
        seen["tip" + sid] = txt(M.tipTexts("tip"))
        seen["status" + sid] = txt(M.text("status"))
        if sid == "30":
            seen["giver"] = txt(M.tipTexts("giver"))
        M.leave(sid)
    M.click("RAIDS")
    M.click("COMPLETED")
    M.click("Will not do")
    M.click("World of Warcraft")
    M.click("30")
    for k in ("node", "type"):                 # made on this select, after the names: its first draw
        seen[k + "115"] = txt(M.text(k, "115"))
    M.wait(0.1)
    M.hover("30")
    M.wait(0.05)
    seen["tipKill"] = txt(M.tipTexts("tip"))
    M.leave("30")
    M.bags(1)
    M.wait(0.1)
    M.hoverRow(1)
    seen["tipRow"] = txt(M.tipTexts("tip"))
    M.surveyEnter()
    seen["surveyStatus"] = txt(M.text("status"))
    M.slash("help")
    M.slash("survey")
    seen["results"] = (txt(M.text("results", "head1")), txt(M.text("results", "head2")))   # a frame made now
    M.call("Attune_ShowSurveyMenu")
    M.call("Attune_ShowQuestRewards", 7848)
    M.call("Attune_ShowQuestDetail", 7848)
    M.siCall("SyncShown", "Friend")
    M.siCall("SyncOver", 3)
    M.call("Attune_MarkStepDone", "20", "30")
    M.call("Attune_MarkStepDone", "20", "50")
    M.slash("export")
    M.call("Attune_ShowWebsiteURL", "quest=7848")
    M.siCall("AskSync", "Friend")
    M.siCall("SyncFrom", "Other")
    M.wait(0.1)
    M.ldbHover()
    seen["ldb"] = txt(M.tipTexts("ldb"))
    M.ldbLeave()
    M.settings("tab1")
    M.wait(0.1)
    M.settingsEnter()
    seen["acd"] = txt(M.tipTexts("acd"))
    M.settings("tab2")
    M.wait(0.1)
    seen["settings2"] = txt(M.settingsTexts())
    M.wait(0.1)
    return seen
