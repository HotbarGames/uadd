"""Finds the addons and builds game sessions for the flow checks."""
import os
import time

from loader import Addon, Client

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DEFAULT_ADDONS = "/mnt/c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns"
FLAVOR = "Forever"
# The client's order: dependencies first, the rest alphabetically.
ORDER = ["QuestieDB", "Questie", "UADD", "UALLF", "UADD_Questie"]
THIRD_PARTY = ["QuestieDB", "Questie", "UALLF"]


def addons_dir():
    return os.environ.get("UADD_ADDONS_DIR", DEFAULT_ADDONS)


def missing_addons():
    d = addons_dir()
    return [n for n in THIRD_PARTY if not os.path.isdir(os.path.join(d, n))]


def load_addons():
    d = addons_dir()
    out = []
    for name in ORDER:
        folder = os.path.join(REPO, name) if name.startswith("UADD") else os.path.join(d, name)
        out.append(Addon(name, folder, FLAVOR))
    return out


_ADDONS = None


def addons():
    global _ADDONS
    if _ADDONS is None:
        _ADDONS = load_addons()
    return _ADDONS


def session(saved=None, locale="enUS", ready_frames=4000):
    """Starts a session and pumps frames until Questie says it is ready (or the frame limit)."""
    c = Client(addons(), saved, locale)
    t0 = time.time()
    c.start()
    c.load_seconds = time.time() - t0
    c.ev("function(n) return HARNESS.pump(n, function() return Questie and Questie.API and Questie.API.isReady end, 0.05) end")(ready_frames)
    c.ready_frames = c.H.frameNo
    return c


def cyr_boxes(client):
    """The guard: shown FontStrings whose Ukrainian text is in a font without Ukrainian letters
    (squares in the game), as "frame font: text" lines. client: a loader.Client.
    UALL Forever's own windows (UALLF...) are left out: that Ukrainian is UALL's, not UADD's."""
    from loader import txt
    lines = [txt(x) for x in client.lines(client.H.cyrBoxes(200))]
    return [x for x in lines if not x.startswith("UALLF")]
