"""UALLF's reverse mode (UALLFSettingsDB.reverseOriginal) for the show-original key.

With reverse on, UADD shows English unless the key is held; holding it 0.25 s gives Ukrainian.
Without UALLF loaded, or with reverse off, the key works as before (flow_original.py).
flow.py calls reverse (with the Original checks object) and reverse_login.
"""
from loader import txt
from flow_original import HELD


def reverse(O, c, step):
    """UALLF's reverse mode (UALLFSettingsDB.reverseOriginal): English unless the key is held.
    Held 0.25 s: Ukrainian; let go: English at once; a quick tap: nothing. Off again, or UALLF not
    loaded: as before."""
    f, F, H = O.f, c.F, c.H

    def held():
        return bool(H.ns.UADD_Questie.Original.held)

    F.toldReset()
    F.setReverse(True)
    F.key("SHIFT", False)                       # the next key change follows the new setting
    turned_on = (F.toldText(), held(), F.polling())
    F.key("SHIFT", True)
    F.wait(0.1)
    F.key("SHIFT", False)
    F.wait(0.4)
    tap = F.toldText()
    F.key("SHIFT", True)
    F.wait(HELD)
    down = (F.toldText(), held(), F.polling())
    F.key("SHIFT", False)
    up = (F.toldText(), held(), F.polling())
    f.check(f"{step}: reverse on: English without the key", turned_on == ("T", True, False), str(turned_on))
    f.check(f"{step}: reverse: a quick tap switches nothing", tap == "T", tap)
    f.check(f"{step}: reverse: key held, Ukrainian; let go, English at once",
            down == ("TF", False, True) and up == ("TFT", True, False), f"{down} {up}")

    F.toldReset()
    F.key("SHIFT", True)
    F.wait(HELD)
    H.combat = True
    H.fire("PLAYER_REGEN_DISABLED")
    fight = F.toldText()
    F.key("SHIFT", False)
    H.combat = False
    H.fire("PLAYER_REGEN_ENABLED")
    f.check(f"{step}: reverse: a fight lets the key go, English", fight == "FT" and held(),
            f"{F.toldText()!r} {held()}")

    F.toldReset()
    F.hideUALLF(True)
    F.key("SHIFT", False)
    gone = (F.toldText(), held())
    F.key("SHIFT", True)
    F.wait(HELD)
    gone_down = held()
    F.key("SHIFT", False)
    F.hideUALLF(False)
    F.key("SHIFT", False)
    f.check(f"{step}: reverse set but UALLF not loaded: as without UALLF",
            gone == ("F", False) and gone_down and F.toldText() == "FTFT" and held(),
            f"{gone} {gone_down} {F.toldText()!r}")

    F.toldReset()
    F.setReverse(None)
    F.key("SHIFT", False)
    f.check(f"{step}: reverse off again: Ukrainian", F.toldText() == "F" and not held(), F.toldText())
    O.hold(c, f"{step}, reverse off again", 867, "Harpy Raiders")

def reverse_login(f):
    """Reverse mode saved in UALLF: English from the start, Questie too once it is ready."""
    c = f.start({"UALLF": '\nUALLFSettingsDB = UALLFSettingsDB or {}\nUALLFSettingsDB.reverseOriginal = true\n'})
    c.F.wait(0.3)
    en = txt(c.F.l10n("General"))
    shown = bool(c.lua.globals().UADD.originalShown)
    held = bool(c.H.ns.UADD_Questie.Original.held)
    c.F.key("SHIFT", True)
    c.F.wait(HELD)
    uk = txt(c.F.l10n("General"))
    c.F.key("SHIFT", False)
    back = txt(c.F.l10n("General"))
    f.check("reverse at login: English from the start, Questie too",
            shown and held and en == "General", f"{shown} {held} {en!r}")
    f.check("reverse at login: key held, Ukrainian; let go, English",
            uk != "General" and back == "General", f"{uk!r} {back!r}")
