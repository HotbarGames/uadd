"""Show-original key and font-safe text checks (flow_original.lua).

Holding UALLF's "show original" key (Shift unless UALLF says otherwise) for 0.25 s shows Questie
in English: the tracker exactly as Questie draws it, quest names, Questie's own strings and the
title of a map pin tooltip. Letting go gives the Ukrainian back at once. A quick tap or a key held
while typing switches nothing. The tracker is redrawn once per change, never in combat.

flow.py calls hold, pin, combat, other_key, hidden and perf; hold also runs timing, and combat runs
combat_in_throttle.

The letter after a quest's level must be one the font can draw: A Vengeful Fate (1102) gets
its tag name from Questie's list through l10n("Dungeon"), which is Ukrainian, and Questie takes
its first byte: half a letter, a box on screen. It must show "[34D]".
"""
import re

from loader import txt
from flow_tracker import draw, plain

# Seconds to hold the key so the core switches (it waits 0.25 s).
HELD = 0.3

# Basic Latin, Latin-1, Cyrillic and the punctuation our texts use.
ALLOWED = re.compile("[\t\n\x20-\x7e\xa0-\xffЀ-ӿ«»—–‘’“”„…•№]*")


def font_safe(text):
    return ALLOWED.fullmatch(text) is not None


class Original:
    def __init__(self, f, tracker):
        self.f = f
        self.T = tracker

    def dungeon(self, c, step, name=None):
        f = self.f
        tag_id, tag_name, letter, lines = c.F.dungeon()
        lines = [plain(txt(x)) for x in c.lines(lines)]
        name = name or txt(c.H.ns.UADD_Questie.Names.maps.Quest[1102] or "A Vengeful Fate")
        f.check(f"{step}: 1102 tag name is Ukrainian (the case that drew a box)",
                tag_id == 81 and not txt(tag_name).isascii(), f"{tag_id} {txt(tag_name)!r}")
        f.check(f"{step}: dungeon letter is D", txt(letter) == "D", repr(txt(letter)))
        f.check(f"{step}: tracker shows [34D] and the name", f"[34D] {name}" in lines, str(lines))
        tags = [x for x in lines if re.match(r"\[\d+[^\]]*\]", x) and not re.match(r"\[\d+[+DRHSACW]*\]", x)]
        f.check(f"{step}: every level tag is Latin", not tags, str(tags))

    def font_safe(self, c, step):
        """Every tracker line and every name we passed to QuestieDB: letters the font draws."""
        lines, _ = draw(c)
        names = [txt(x) for x in c.lines(c.F.publishedNames())]
        bad = [x for x in [plain(y) for y in lines] + names if not font_safe(x)]
        self.f.check(f"{step}: tracker and passed names hold only drawable letters", not bad,
                     f"{len(bad)}: {bad[:4]}")

    def hold(self, c, step, qid, en):
        f, T = self.f, self.T
        c.F.spyRefresh()
        c.F.key("SHIFT", True)
        f.check(f"{step}: key down, nothing yet", c.F.refreshes == 0, str(c.F.refreshes))
        c.F.wait(HELD)
        f.check(f"{step}: key held, tracker redrawn once", c.F.refreshes == 1, str(c.F.refreshes))
        lines, _ = draw(c)
        f.check(f"{step}: held, tracker exactly Questie's English", lines == T.english,
                str([plain(x) for x in lines][:6]))
        name, general = (txt(x) for x in c.F.shown(qid))
        f.check(f"{step}: held, quest name and Questie text English",
                en in name and general == "General", f"{name!r} {general!r}")
        c.F.key("SHIFT", False)
        f.check(f"{step}: key up redraws once more", c.F.refreshes == 2, str(c.F.refreshes))
        lines, _ = draw(c)
        f.check(f"{step}: let go, tracker Ukrainian again", lines == T.ukrainian,
                str([plain(x) for x in lines][:6]))
        name, general = (txt(x) for x in c.F.shown(qid))
        f.check(f"{step}: let go, quest name and Questie text Ukrainian",
                en not in name and general != "General", f"{name!r} {general!r}")
        self.timing(c, step)

    def timing(self, c, step):
        """English only after the key is held 0.25 s, never while typing; back at once on release,
        also when the release never reaches the game (Alt-Tab) or comes with combat."""
        f, F, H = self.f, c.F, c.H

        def held():
            return bool(H.ns.UADD_Questie.Original.held)

        F.spyRefresh()
        F.toldReset()
        F.key("SHIFT", True)
        F.wait(0.1)
        F.key("SHIFT", False)
        F.wait(0.4)
        f.check(f"{step}: a quick tap switches nothing",
                F.toldText() == "" and F.refreshes == 0 and not held(), f"{F.toldText()!r} {F.refreshes}")

        F.toldReset()
        F.key("SHIFT", True)
        F.wait(0.2)
        early, early_held = F.toldText(), held()
        F.wait(0.1)
        f.check(f"{step}: English only after 0.25 s held",
                early == "" and not early_held and F.toldText() == "T" and held(),
                f"{early!r} {early_held} {F.toldText()!r} {held()}")
        F.key("SHIFT", False)
        f.check(f"{step}: let go, Ukrainian at once", F.toldText() == "TF" and not held(), F.toldText())

        F.toldReset()
        F.focus = True
        F.key("SHIFT", True)
        F.wait(0.4)
        typing = F.toldText()
        F.key("SHIFT", False)
        F.focus = None
        f.check(f"{step}: typing in chat, no switch", typing == "" and F.toldText() == "", typing)

        F.toldReset()
        F.key("SHIFT", True)
        F.wait(HELD)
        polling = F.polling()
        F.keySilent("SHIFT", False)
        F.wait(0.3)
        f.check(f"{step}: key let go outside the game, the poll lets go",
                polling and F.toldText() == "TF" and not held() and not F.polling(),
                f"{polling} {F.toldText()!r} {held()} {F.polling()}")

        F.toldReset()
        F.key("SHIFT", True)
        F.wait(HELD)
        F.keySilent("SHIFT", False)
        H.fire("PLAYER_REGEN_ENABLED")
        f.check(f"{step}: combat change checks the key", F.toldText() == "TF" and not held(), F.toldText())

    def hidden(self, c, step):
        """A hidden tracker is not redrawn by the key; the first time it shows again it is redrawn
        once, in the language of that moment."""
        f, F, T = self.f, c.F, self.T

        def shown():
            return [txt(x) for x in c.lines(F.trackerLines())]

        draw(c)
        F.spyRefresh()
        F.showTracker(False)
        F.key("SHIFT", True)
        F.wait(HELD)
        F.key("SHIFT", False)
        F.wait(0.3)
        f.check(f"{step}: tracker hidden, the key redraws nothing", F.refreshes == 0, str(F.refreshes))
        F.showTracker(True)
        F.wait(0.3)
        lines = shown()
        f.check(f"{step}: shown again, redrawn once, Ukrainian", F.refreshes == 1 and lines == T.ukrainian,
                f"{F.refreshes} {[plain(x) for x in lines][:4]}")
        F.showTracker(False)
        F.key("SHIFT", True)
        F.wait(HELD)
        F.showTracker(True)
        F.wait(0.3)
        lines = shown()
        f.check(f"{step}: shown while the key is held, English", lines == T.english,
                str([plain(x) for x in lines][:4]))
        F.key("SHIFT", False)
        F.wait(0.3)
        lines = shown()
        f.check(f"{step}: then let go, Ukrainian", lines == T.ukrainian, str([plain(x) for x in lines][:4]))

    def perf(self, c, step):
        """/uadd perf prints the last key down and up time of each module; /uadd lists it."""
        F = c.F
        F.key("SHIFT", True)
        F.wait(HELD)
        F.key("SHIFT", False)
        before = len(c.chat())
        c.slash("perf")
        out = c.chat()[before:]
        row = [x for x in out if "Questie" in x and re.search(r"\d+\.\d\d / \d+\.\d\d", x)]
        ok = row and any("разом" in x for x in out) and not any("помилка" in x for x in out)
        self.f.check(f"{step}: /uadd perf prints each module's down / up time", ok, str(out[:4]))
        before = len(c.chat())
        c.slash("")
        self.f.check(f"{step}: /uadd lists /uadd perf", any("/uadd perf" in x for x in c.chat()[before:]))

    def pin(self, c, step):
        down, up = txt(c.F.pinTooltip(True)), txt(c.F.pinTooltip(False))
        self.f.check(f"{step}: map pin tooltip rebuilt in English, then Ukrainian",
                     down == "General" and up not in ("General", "None"), f"{down!r} {up!r}")

    def combat(self, c, step):
        f = self.f
        c.F.spyRefresh()
        c.H.combat = True
        c.F.key("SHIFT", True)
        c.F.wait(HELD)
        f.check(f"{step}: no redraw in combat", c.F.refreshes == 0, str(c.F.refreshes))
        c.H.combat = False
        c.H.fire("PLAYER_REGEN_ENABLED")
        f.check(f"{step}: redrawn after combat", c.F.refreshes == 1, str(c.F.refreshes))
        c.F.key("SHIFT", False)
        f.check(f"{step}: let go after combat, redrawn", c.F.refreshes == 2, str(c.F.refreshes))
        self.combat_in_throttle(c, step)

    def combat_in_throttle(self, c, step):
        """Let go within 0.1 s of the English redraw: Questie puts our redraw off, then combat
        starts and Questie drops it. The tracker must be drawn again when combat ends."""
        f, F, H, T = self.f, c.F, c.H, self.T
        F.spyRefresh()
        F.wait(0.3)
        F.key("SHIFT", True)
        F.wait(HELD)
        F.key("SHIFT", False)
        H.combat = True
        F.wait(0.3)
        lines = [txt(x) for x in c.lines(F.trackerLines())]
        f.check(f"{step}: combat in Questie's throttle, its redraw dropped (the case)",
                F.refreshes == 2 and lines == T.english, f"{F.refreshes} {[plain(x) for x in lines][:4]}")
        H.combat = False
        H.fire("PLAYER_REGEN_ENABLED")
        F.wait(0.3)
        lines = [txt(x) for x in c.lines(F.trackerLines())]
        f.check(f"{step}: combat in Questie's throttle, Ukrainian after combat",
                F.refreshes == 3 and lines == T.ukrainian, f"{F.refreshes} {[plain(x) for x in lines][:4]}")

    def combat_key(self, c, step):
        """In a fight the key does nothing (the default): a fight that starts with the English shown gives
        the Ukrainian back once; a fight that ends with the key held shows the English at once.
        /uadd combat off: the key works in a fight as before; /uadd combat on: back to the default."""
        f, F, H = self.f, c.F, c.H
        F.toldReset()
        F.key("SHIFT", True)
        F.wait(HELD)
        H.combat = True
        H.fire("PLAYER_REGEN_DISABLED")
        starts = F.toldText()
        F.key("SHIFT", False)
        F.key("SHIFT", True)
        F.wait(HELD)
        during = F.toldText()
        H.combat = False
        H.fire("PLAYER_REGEN_ENABLED")
        ends = F.toldText()
        F.key("SHIFT", False)
        f.check(f"{step}: fight starts with English shown, Ukrainian back once", starts == "TF", starts)
        f.check(f"{step}: the key in a fight does nothing", during == "TF", during)
        f.check(f"{step}: fight ends with the key held, English at once; let go, Ukrainian",
                ends == "TFT" and F.toldText() == "TFTF", f"{ends!r} {F.toldText()!r}")

        c.slash("combat off")
        saved = c.lua.globals().UADD_DB.keyInCombat
        F.toldReset()
        H.combat = True
        H.fire("PLAYER_REGEN_DISABLED")
        F.key("SHIFT", True)
        F.wait(HELD)
        off = F.toldText()
        F.key("SHIFT", False)
        H.combat = False
        H.fire("PLAYER_REGEN_ENABLED")
        c.slash("combat on")
        back = c.lua.globals().UADD_DB.keyInCombat
        f.check(f"{step}: /uadd combat off, the key works in a fight; on, default again",
                saved is True and off == "T" and F.toldText() == "TF" and back is None,
                f"{saved} {off!r} {F.toldText()!r} {back}")
        said = " ".join(c.chat()[-2:])
        f.check(f"{step}: /uadd combat says the setting", "бою" in said, said[-120:])

    def other_key(self, c, step):
        """UALLF's key is CTRL: Shift does nothing, Ctrl works. NONE: no key at all."""
        f = self.f
        c.F.setOriginalKey("CTRL")
        c.F.key("SHIFT", True)
        c.F.wait(HELD)
        shift = c.H.ns.UADD_Questie.Original.held
        c.F.key("SHIFT", False)
        c.F.key("CTRL", True)
        c.F.wait(HELD)
        ctrl = c.H.ns.UADD_Questie.Original.held
        c.F.key("CTRL", False)
        after = c.H.ns.UADD_Questie.Original.held
        f.check(f"{step}: UALLF key Ctrl: Shift ignored, Ctrl shows English",
                not shift and ctrl and not after, f"{shift} {ctrl} {after}")
        c.F.setOriginalKey("NONE")
        c.F.key("SHIFT", True)
        c.F.wait(HELD)
        none = c.H.ns.UADD_Questie.Original.held
        c.F.key("SHIFT", False)
        f.check(f"{step}: UALLF key none: nothing switches", not none, str(none))
        c.F.setOriginalKey(None)
