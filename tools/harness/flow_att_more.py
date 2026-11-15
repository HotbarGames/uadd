"""The Ukrainian flow_att.py expects on every surface of game A, after the names came: the window, the
tree, the step boxes, the Next window, the panels, the tooltips, the four dialogs, the settings, the
minimap tooltip and the [Attune] chat lines. The Ukrainian is read from the module's ui tables
(ns.UA, ns.UA_CATEGORY, the hashed tables, ns.UA_STEP_TYPE, ns.UA_NOTES) and from the UALL stand-in's answers (flow_att.lua),
never from the module's own answers. What must stay English is read from AttuneLang.
"""
from loader import txt

P = "|cffff00ff[Attune]|r "
VERSION = "16001-40"


class Want:
    """The expected texts. A missing Ukrainian gives a marker that no shown text can equal."""

    def __init__(self, M):
        self.M = M

    def _v(self, v, what, places):
        if v is None:
            return f"<no Ukrainian for {what!r}>"
        s = txt(v)
        for k, x in places.items():
            s = s.replace(f"##{k}##", x)
        return s

    def u(self, key, **places):
        return self._v(self.M.ua(key), key, places)

    def t(self, en):
        return self._v(self.M.uaText(en), en, {})

    def st(self, value):
        return self._v(self.M.stepType(value), value, {})

    def note(self, key):
        return self._v(self.M.note(key), key, {})

    def uk(self, kind, en):
        return self._v(self.M.uk(kind, en), en, {})

    def en(self, key):
        return txt(self.M.lang(key))

    def kind(self, value, zone):
        return f"|cffffd100{self.st(value)}|r|c60808080 {self.u('in')} {self.uk('Zone', zone)}|r"


def read(M, w):
    """One shown text by a place key (popups by their dialog name)."""
    if w[0] == "popup":
        i = M.popupOf(w[1])
        return txt(M.text("popup", i, w[2])) if i else None
    return txt(M.text(*w))


def surfaces(check, M, seen, w, chat):
    def eq(name, got, want):
        check(name, got == want, f"{got!r} | want {want!r}")
    Q = lambda en: w.uk("Quest", en)        # noqa: E731
    N = lambda en: w.uk("Npc", en)          # noqa: E731
    X = lambda en: w.uk("Text", en)         # noqa: E731
    # The window.
    eq("title: the addon name as it is", read(M, ("title",)), "  Attune")
    eq("survey button", read(M, ("survey",)), w.u("Survey"))
    eq("status on the survey button", seen["surveyStatus"], w.u("Survey_DESC"))
    eq("status on a quest box: the quest name", seen["status30"], Q("Attunement to the Core"))
    eq("status on an item box: 'n/m ' kept", seen["status40"], "0/2 " + w.uk("Item", "Core Fragment"))
    eq("status on a level box", seen["status20"], "60/55 " + w.u("Reach level") + " 55")
    # Step boxes (Onyxia's Lair shown) and the box made after the names.
    eq("box: quest name", read(M, ("node", "20")), Q("Warlord's Command"))
    eq("box: NPC name", read(M, ("node", "30")), N("Highlord Omokk"))
    eq("box made late: NPC name on its first draw", seen["node115"], N("Rexxar"))
    eq("box: step type and zone", read(M, ("type", "20")), w.kind("Pick Up", "Badlands"))
    eq("box: Kill type", read(M, ("type", "30")), w.kind("Kill", "Lower Blackrock Spire"))
    eq("box made late: Interact type on its first draw", seen["type115"], w.kind("Interact", "Desolace"))
    # The tree.
    eq("tree: category", read(M, ("tree", "RAIDS")), "|cffA0A0A0" + w.t("Raids") + "|r")
    eq("tree: Completed", read(M, ("tree", "COMPLETED")), "|cff00ff00" + w.t("Completed") + "|r")
    eq("tree: Will not do", read(M, ("tree", "Will not do")), "|cff808080" + w.t("Will not do") + "|r")
    eq("tree: raid name", read(M, ("tree", "20")), X("Molten Core"))
    eq("tree: dungeon name with its levels", read(M, ("tree", "160")), X("Ragefire Chasm") + " (13-16)")
    eq("tree: completed one", read(M, ("tree", "x1")), "|cff00ff00" + X("Molten Core") + "|r")
    eq("tree: the expansion name stays", read(M, ("tree", "World of Warcraft")), "World of Warcraft")
    # The Next window: Attune's short tag kept, the step in Ukrainian.
    eq("Next title", read(M, ("nextTitle",)), w.u("NextSteps_TITLE"))
    eq("Next row: tag kept", read(M, ("next", 1)), "|cffffd100Ony|r  |cffffffff" + Q("Warlord's Command") + "|r")
    eq("Next row: levels and tag kept", read(M, ("next", 2)),
       "|cffaaaaaa13-16|r  |cffffd100RFC|r  |cffffffff" + Q("Warlord's Command") + "|r")
    eq("Next row: later", read(M, ("next", 3)), "|cffaaaaaa" + w.u("NextSteps_LATER", LEVEL="62") + "|r")
    # Panels.
    eq("results list made late: on its first draw", seen["results"], (w.u("Character"), w.u("Results")))
    eq("reward panel title", read(M, ("reward", "title")), w.u("Choose one reward"))
    eq("reward panel line", read(M, ("reward", "line")), w.u("Loading rewards"))
    eq("detail: quest name", read(M, ("detail", "title")), Q("Attunement to the Core"))
    eq("detail: subtitle", read(M, ("detail", "sub")), w.u("Quest rewards"))
    eq("detail: giver", read(M, ("detail", "giver")), w.u("Starts at") + " " + N("Lothos Riftwaker"))
    eq("detail: quest text (Q2) stays English", read(M, ("detail", "body")), w.en("Q2_7848"))
    eq("sync bar", read(M, ("sync",)), w.u("Sync over", DURATION="3s"))
    eq("survey menu: guild", read(M, ("menu", "guild")), w.u("Guild"))
    eq("survey menu: character", read(M, ("menu", "char")), w.u("Character"))
    # Tooltips.
    eq("quest tooltip", seen["tip30"].split("\x01"), [Q("Attunement to the Core"), w.u("Requires level") + " 55\n\n",
       w.u("Party quest", NB="5") + "\n\n", w.en("Q2_7848")])
    eq("item tooltip: the game's own", seen["tip40"], "Core Fragment")
    eq("quest-giver tip", seen["giver"].split("\x01"), ["|cffffffff" + w.u("Starts at") + " |r" + N("Lothos Riftwaker"),
       w.u("Click to show map")])
    eq("NPC tooltip, note from ns.UA_NOTES", seen["tipKill"].split("\x01"), [N("Highlord Omokk"),
       f"{w.u('Level')} 59 {w.u('Elite')} {w.u('Ogre')}\n", "\n" + w.note("N2_9196")])
    eq("Next row tooltip", seen["tipRow"].split("\x01"), [X("Molten Core"), Q("Attunement to the Core"),
       w.st("Pick Up") + " " + w.u("in") + " " + w.uk("Zone", "Blackrock Mountain")])
    eq("minimap tooltip", seen["ldb"].split("\x01"), ["|cFFffffffAttune v" + VERSION + "|r", " ", " ",
       "|cffffd100" + w.u("LeftClick") + "|r" + w.u("OpenAttune") + "\n|cffffd100" + w.u("RightClick") + "|r"
       + w.u("OpenSettings")])
    eq("settings tooltip", seen["acd"].split("\x01"), [w.u("MinimapButton_TEXT"), w.u("MinimapButton_DESC")])
    # The four dialogs; their edit boxes stay English.
    url = "\n\nhttps://warcraftratings.com/attune/upload"
    eq("export dialog (the web address kept)", read(M, ("popup", "EXPORT_ATTUNE_GUILD", "text")),
       w.u("Copy the text below, then upload it to") + url)
    eq("export dialog button", read(M, ("popup", "EXPORT_ATTUNE_GUILD", "button1")), w.u("Close"))
    eq("link dialog", read(M, ("popup", "ATTUNE_SHOW_URL", "text")), w.u("External link"))
    eq("link dialog: the address stays", read(M, ("popup", "ATTUNE_SHOW_URL", "editBox")),
       "https://www.wowhead.com/classic/quest=7848")
    slow = "\n\n" + w.u("Could be slow")
    eq("sync question", read(M, ("popup", "SYNC_CONFIRM", "text")), w.u("Sending Sync Request", PLAYER="Friend") + slow)
    eq("sync request (name kept, two parts)", read(M, ("popup", "SYNC_ATTUNE", "text")),
       w.u("Sync Request From", PLAYER="Other") + slow)
    eq("dialog buttons", (read(M, ("popup", "SYNC_ATTUNE", "button1")), read(M, ("popup", "SYNC_ATTUNE", "button2"))),
       (w.u("Accept"), w.u("Reject")))
    # Chat lines.
    for name, line in (("splash", w.u("Splash", VERSION=VERSION)), ("help", w.u("Help1")),
                       ("step done", w.u("CompletedStep", TYPE=w.st("Pick Up"), STEP=Q("Attunement to the Core"),
                                         NAME=X("Molten Core"))),
                       ("attuned", w.u("AttuneComplete", NAME=X("Molten Core"))),
                       ("export", w.u("ExportingData", COUNT="1"))):
        check(f"chat: {name} line", P + line in chat, f"want {P + line!r}; last: {chat[-1:]!r}")


def settings(check, M, w):
    """The settings pages (the game's Settings): labels in Ukrainian, the Survey Log kept English."""
    M.settings("tab1")
    M.wait(0.1)
    tab1 = txt(M.settingsTexts()).split("\x01")
    for key in ("MinimapButton_TEXT", "ShowOther_TEXT", "GeneralSettings", "Survey Log"):
        check(f"settings: {key}", w.u(key) in tab1, tab1)
    check("settings: URL label", w.t("Database Website URL") in tab1, tab1)
    M.settings("tab2")
    M.wait(0.1)
    tab2 = txt(M.settingsTexts())
    log = w.en("ReceivedRequestFrom").replace("##FROM##", "Someone-Harness")
    check("settings: the survey log stays English", log in tab2, tab2[:200])
