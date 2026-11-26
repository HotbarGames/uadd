"""flow_bs.py's step 8: the game crash of 2026-11-26 (docs/LESSONS4.md lesson 47), on the BugSack stand-in.

BugSack's text area is an edit box. In the client an edit box's GetFontObject gives its own nameless font record
(tools/harness/wow_widgets2.lua acts it out); put back on the box, the record inherits from itself and the client
recurses until the game dies (here H.Crash: the run fails). The steps: the no-bugs line ours, then an error text (its
own font and object back), the player's font size between, off and on, the hold key.
"""
from flow_pawn_game import cyr
from loader import lua_str, txt


def crash(check, c, M, E, A):
    bad = []
    for size in ("GameFontNormal", "GameFontHighlightSmall", "GameFontHighlight"):
        M.bugs(0)
        M.fontSize(lua_str(size))
        no = txt(M.bugs(0)[0])
        err_now, err = (txt(x) for x in M.bugs(1))
        ours, obj = M.textFont()
        if not cyr(no) or err_now != err or ours or txt(obj) != size:
            bad.append((size, cyr(no), err_now == err, ours, txt(obj)))
    for how in ("off", "on"):
        M.bugs(0)
        M.uadd("bs " + how)
        M.bugs(1)
    M.bugs(0)
    M.key(True)
    M.bugs(1)
    M.key(False)
    M.bugs(0)
    ours_no = M.textFont()[0]
    M.bugs(1)
    ours, obj = M.textFont()
    M.bugs(0)
    if not ours_no or ours or txt(obj) != "GameFontHighlight":
        bad.append(("last", ours_no, ours, txt(obj)))
    bad = [("crash", txt(x)) for x in M.crashes().values()] + bad
    check("8 text area: the no-bugs line ours, then an error text in its own font and object again (font sizes, "
          "off/on, held); no font object ever inherits from itself (no client crash)", not bad, bad[:4])
    return not bad
