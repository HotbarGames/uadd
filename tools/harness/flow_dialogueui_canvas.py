"""DialogueUI's page in the game's options (Options > AddOns > Dialogue UI), in flow_dialogueui.py's
games A, B and E: a nameless canvas whose button is set once and whose instruction line is set on
each show (its first OnShow replaces itself with SetScript). Checked: the page found, its button and
line in Ukrainian (the line's English read from the installed DialogueUI: it is all rights reserved,
so its English is never kept in the repo), in a font with Ukrainian letters, also when shown again,
with the hold key, off and on. Game E makes the page after login (docs/LESSONS.md, lesson 2: late
windows). Each function takes F, the flow_dialogueui module, for its helpers."""
import os
import re

import session
from loader import read_text


def instruction():
    """The options page's instruction line in English, read from the installed DialogueUI. None when
    it is not installed."""
    path = os.path.join(session.addons_dir(), "DialogueUI", "Locales", "enUS.lua")
    if not os.path.isfile(path):
        return None
    m = re.search(r'L\["Instruction Open Settings"\]\s*=\s*"([^"\\]*)"', read_text(path))
    return m.group(1) if m else None


def canvas(F, c, M, check, step):
    """Open the page, check it, show it again, hold Shift, off and on, close it."""
    line = instruction()
    if line:
        M.setL("Instruction Open Settings", line)
    M.openCanvas()
    M.wait(F.WAIT)
    check(f"{step}: the options page found", M.canvasFound())
    F._is(M, check, "canvasButton", step, "'Open Settings' button in Ukrainian")
    if line:
        F._is(M, check, "canvasText", step, "instruction line (set on the first show) in Ukrainian")
    else:
        check(f"{step}: instruction line (note: DialogueUI not installed, its English unknown)", True)
    boxes = session.cyr_boxes(c)
    check(f"{step}: options page in a font with Ukrainian letters", not boxes, boxes[:3])
    M.closeCanvas()
    M.wait(F.WAIT)
    M.openCanvas()                      # shown again: its OnShow is now the bare instruction setter
    M.wait(0.05)
    if line:
        F._is(M, check, "canvasText", step + " shown again", "instruction line in Ukrainian at once")
    M.key(True)
    M.wait(F.HELD)
    F._all_en(c, M, check, step + ", Shift held", fonts="shown")
    M.key(False)
    M.wait(F.HELD)
    F._is(M, check, "canvasButton", step + ", Shift let go", "button in Ukrainian again")
    M.uadd("dialogueui off")
    M.wait(0.3)
    F._all_en(c, M, check, step + ", off")
    M.uadd("dialogueui on")
    M.wait(F.WAIT)
    F._is(M, check, "canvasButton", step + ", on again", "button in Ukrainian again")
    M.closeCanvas()
    M.wait(F.WAIT)


def game_e(F, check):
    """The options page made after login: found when Options opens."""
    c, M = F._game([F.STAND_IN, F._uadd(), F._module()], late_canvas=True)
    M.wait(F.WAIT)
    M.makeCanvas()
    canvas(F, c, M, check, "options page made late")
    F._errors(c, check, "options page made late")
