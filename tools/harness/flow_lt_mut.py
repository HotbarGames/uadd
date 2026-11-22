"""Mutants for UADD_LootTriage (flow_lt.py): each cuts one fix out of one module file, in memory only, on a
fresh game, and wants a named step to FAIL; without the cut that step passes. Steps flow_lt.steps lacks are here
(names "m..."). A mutant whose step fails even without the cut is reported as "base fails now" and not counted.
No English of LootTriage here (no licence): every text is read at run time, as flow_lt.py does.
Alone: python3 tools/harness/flow_lt_mut.py
"""
import gc
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import flow_lt as F  # noqa: E402
from flow_pawn_game import cyr  # noqa: E402
from loader import lua_str, txt  # noqa: E402

ZORP = "Зорп"                      # the made-up Ukrainian game name of flow_lt.lua
LINKED = {"Code.13c59ccc": 2, "Code.8ffcf1a4": 1, "Code.64358fe7": 1}   # its templates with a link: its slot
SUFFIX = ("Code.7866be7e", "Code.673bcf4b")             # pieces of ours in brackets (a quest line's tail)

# The cut lives in the Lua state from the start: H.runFile runs one module file without one fix.
CUT_LUA = r"""
local H = HARNESS
local cut = { wasCut = false }
H.ltcut = cut
local runFile = H.runFile
function H.runFile(addon, path, code)
    if addon == "UADD_LootTriage" and cut.file and path == cut.file then
        local a, b = code:find(cut.old, 1, true)
        if a then code, cut.wasCut = code:sub(1, a - 1) .. cut.new .. code:sub(b + 1), true end
    end
    return runFile(addon, path, code)
end
"""


def game(cut=None):
    """flow_lt.game() with one fix cut out (file, old, new), or a plain game. Returns (c, M, cut table)."""
    real = F.Client
    box = {}

    def client(*a, **k):
        c = real(*a, **k)
        c.lua.execute(CUT_LUA)
        t = c.H.ltcut
        if cut:
            t.file, t.old, t.new = (lua_str(x) for x in cut)
        box["t"] = t
        return c
    F.Client = client
    try:
        c, M = F.game()
    finally:
        F.Client = real
    return c, M, box["t"]


def fill(t, vals):
    it = iter(vals)
    return re.sub(r"%[sd]", lambda m: next(it, ""), t)


def piece(en):
    return en.get("Code.ca207745", "").replace("%d", "7")


def linked(en, name, rest=None):
    """{key: line} for its templates with a link: the link named name, the other slot our piece (or rest)."""
    out = {}
    for k, at in LINKED.items():
        if k in en:
            v = [rest if rest is not None else piece(en)] * 2
            v[at - 1] = F_link(name)
            out[k] = fill(en[k], v)
    return out


def F_link(name):
    return "|cff1eff00|Hitem:4711::::::::60:::::|h[" + name + "]|h|r"


def tr(M, s):
    return txt(M.tr(lua_str(s)))


def ours_tip(M):
    """A tooltip line of its own file that comes out ours (English, Ukrainian)."""
    for r in F.rows():
        if {f for f, _ in r[3]} & set(F.TIPS) and "%" not in r[1] and "\n" not in r[1]:
            o = tr(M, r[1])
            if cyr(o):
                return r[1], o
    return None, None


# ── Steps flow_lt.steps lacks: (q, c, M, E, en) ─────────────────────────────────────────────────

def m_link(q, c, M, E, en):
    known = {k: tr(M, s) for k, s in linked(en, M.ITEM).items()}
    lost = {k: (s, tr(M, s)) for k, s in linked(en, "Quix Gizmo").items()}
    q("m1 a link UALL lacks: line whole English; one it knows: ours",
      any(cyr(o) and ZORP in o for o in known.values()) and lost and all(o == s for s, o in lost.values()),
      [o for _, o in lost.values()][:2])


def m_quest(q, c, M, E, en):
    tail = next((en[k] for k in SUFFIX if k in en and "%" not in en[k]), None)
    head = next((r[1] for r in F.rows() if {f for f, _ in r[3]} & set(F.TIPS) and "%" not in r[1]
                 and r[1].startswith("LootTriage: ")), None)   # a quest line follows a line with its prefix
    lost ="  Quix Wobbly Hunt" + (tail or "")
    out = lines = None
    if head and tail:
        lines = F.lines(M.tip(lua_str(head), lua_str(lost), lua_str("  " + txt(M.QUEST) + tail)))
        out = lines[1]
    q("m2 an unknown quest with our tail in brackets: line whole English; a known one ours",
      tail and out == lost and cyr(lines[2]) and ZORP in lines[2], lines)


def m_font(q, c, M, E, en):
    c.lua.execute("UADD.AceFont.Set = function() end")
    M.uadd("lt off")
    M.uadd("lt on")
    S = F.snap(M)
    bad, n = M.fonts()
    bad = [txt(b) for b in bad.values()]
    same = {k: S[k] for k in S if k[0] in "WXDC" and S[k] != E[k]}
    m = F.menu(M, True)
    M.closeMenu()
    q("m4 our font cannot be set: its window, dropdown, menu and What's New stay English",
      not same and not bad and m and all(not cyr(t) for t, _, _ in m), bad[:3] or list(same)[:5] or m)


def m_blocks(q, c, M, E, en):
    line, _ = ours_tip(M)
    s = (line or "") + "\n\nQuix wobbly gizmo."
    out = tr(M, s)
    q("m8 a tip with one block not ours: whole English", line and out == s, out[:200])


def m_late(q, c, M, E, en):
    c.lua.execute(r"""
        local A = UADD.UALL
        local item = A.Item
        A.Item = function(name, ...)
            if name == "Quix Later" then return LtMutLate and "\208\151\208\190\209\128\208\191" or nil end
            return item(name, ...)
        end""")
    got = []
    for k, s in linked(en, "Quix Later").items():
        c.lua.execute("LtMutLate = false")
        a = tr(M, s)
        c.lua.execute("LtMutLate = true")
        got.append((s, a, tr(M, s)))
    q("m9 a route that answers late: first show English, the next ours",
      got and all(a == s for s, a, _ in got) and any(cyr(b) and ZORP in b for _, _, b in got),
      [b for _, _, b in got][:2])


def m_ends(q, c, M, E, en):
    outs = [(s, tr(M, s)) for k, s in linked(en, M.ITEM, rest="").items() if LINKED[k] == 1]
    q("m10 a link with its number left out: ours", outs and any(cyr(o) and ZORP in o for _, o in outs)
      and all(F.whole(o, s) for s, o in outs), [o for _, o in outs][:2])


def m_row(q, c, M, E, en):
    r = M.drawRow()
    was = txt(r.Text.GetText(r.Text))
    M.uadd("lt off")
    b = r.Button.GetFontString(r.Button)
    now = (txt(r.Text.GetText(r.Text)), txt(b.GetText(b)))
    M.uadd("lt on")
    q("m11 a drawn panel row: English right after off", cyr(was) and now == (E["R:text"], E["R:button"]),
      (was, now))


def m_again(q, c, M, E, en):
    M.wait(4)                                    # past the settle time: an error counts (as flow_lt step 12)
    M.fault(5)
    for _ in range(3):
        M.lt("")
    M.wait(0.3)                                  # U.TurnOff runs one frame later
    was = M.on()
    M.uadd("lt on")
    w = M.stand().win
    w.Refresh()                                  # its own redraw: its English on every label
    now = [txt(x.fs.GetText(x.fs)) for x in w.labels.values()]
    q("m12 off for errors, then on: its next redraw ours (lesson 19)", not was and now and all(cyr(x) for x in now),
      now[:3])


NEW = {"m1": m_link, "m2": m_quest, "m4": m_font, "m8": m_blocks, "m9": m_late, "m10": m_ends, "m11": m_row,
       "m12": m_again}

# cut -> (file, the fix as it is, without it, the step it must break: flow_lt.steps's name or a NEW key).
MUTANTS = {
    "link": ("Slots.lua", 'if k == "link" then return Link(sl.en) end', 'if k == "link" then return sl.en end', "m1"),
    "quest": ("Words.lua", '        local uk = R.Quest(nil, title)\n        if type(uk) ~= "string" or not find(uk, CYR) '
              'then return nil end\n        return "  " .. uk .. suffix', '        return "  " .. title .. suffix',
              "3 quest line by UALL's name"),
    "questmiss": ("Words.lua", 'if type(uk) ~= "string" or not find(uk, CYR) then return nil end\n        return "  " .. uk',
                  'return "  " .. (type(uk) == "string" and find(uk, CYR) and uk or title)', "m2"),
    "maybe": ("Words.lua", 'function W.Maybe(s)\n    if type(s) ~= "string" then return false end',
              "function W.Maybe(s)\n    do return true end", "4 lines not its own cost nothing"),
    "font": ("Screen.lua", "if Font(fs) then rec[fs] = { en = t, uk = uk }", "if true then rec[fs] = { en = t, uk = uk }", "m4"),
    "newsfont": ("News.lua", "if ns.Screen.Font(fs) then rec = {", "if true then rec = {", "m4"),
    "refresh": ("Screen.lua", 'hooksecurefunc(c, "Refresh", ns.Guard(WalkAll))', 'hooksecurefunc(c, "Refresh", U.Safe("lt", WalkAll))',
                "m12"),
    "renamed": ("Screen.lua", "        if r and t == r.uk then fs:SetText(r.en) end", "        if r then fs:SetText(r.en) end",
                "7 a text it renamed itself stays (lesson 23)"),
    "values": ("Screen.lua", "for k, v in pairs(c) do e[k] = v end", "", "8 choices ours, values the same"),
    "choices": ("Screen.lua", "if row.choices == r.mine then row.choices = r.orig end", "", "8 off: its own choices back"),
    "blocks": ("Words.lua", "if not hit then return nil end", "if not hit then hit, to = parts[a], a end", "m8"),
    "asked": ("Words.lua", "    if not P.asked then", "    if true then", "m9"),
    "ends": ("Slots.lua", "if c[3] then table.insert(ends, 1, c[2] + 1) end", "", "m10"),
    "panel": ("Screen.lua", '\n        elseif d[k] ~= v and type(d[k]) == "string" and d[k]:find(CYR) then d[k] = v end',
              " end", "6 off: English as without it"),
    "row": ("Screen.lua", "if t == uk then fs:SetText(e) end", "if false then fs:SetText(e) end", "m11"),
    "forbidden": ("Screen.lua", "return not Forbidden(c) and type(c.Refresh)", "return type(c.Refresh)", "1 its window ours"),
    "menu": ("Menu.lua", "    if installed then return end\n", "    do return end\n",
             "14 its dropdown's menu: our names in our Cyrillic font"),
    "canfont": ("Screen.lua", "if not ns.Menu.CanFont() then return list end", "", "m4"),
    "owner": ("Screen.lua", "if Forbidden(o) then break end", "", "15 a tooltip with a forbidden owner: no error, no fault"),
    "newslabel": ("News.lua", "if t == en then l.en = en lab:SetText(NEW_UK) end", "",
                  "16 its New buttons: ours in our font, the button sized to it, the global not written"),
    "newsrefont": ("News.lua", "pcall(A.Set, lab, APP, Relabel)", "pcall(A.Set, lab, APP)",
                   "16 New button hover sets its font object: ours stays"),
    "newsglobal": ("News.lua", 'if type(g) ~= "string" or g == "" or find(g, CYR) then', 'if type(g) ~= "string" or g == "" then',
                   "16 the game's word already Cyrillic: left as it is, the global too"),
}


def reach(step, cut, E, en):
    """Runs the step on a fresh game (with the cut, or none): (its result True/False/None, detail, was it cut)."""
    got = {}

    def q(name, ok, detail=""):
        got.setdefault(name, (bool(ok), str(detail)))
    c, M, t = game(cut)
    try:
        if step in NEW:
            NEW[step](q, c, M, E, en)
        else:
            F.steps(q, c, M, E, F.snap(M), en)
    except Exception as e:                       # a Lua error in the step: it did not pass
        got.setdefault("__error", (False, str(e)[:200]))
    name = next(iter(got)) if step in NEW else step
    ok, detail = got.get(name, got.get("__error", (None, "not reached")))
    was = bool(t.wasCut)
    del c, M, t
    gc.collect()
    return ok, detail, was


def mutants(check, E=None, en=None):
    if not F.module_there() or not F.installed():
        return check("mutants (skipped: LootTriage or the module not there)", True, "")
    en = en if en is not None else F.english()
    if E is None:
        c, M = F.game(module=False)
        E = F.snap(M)
        del c, M
    base = {}
    for step in dict.fromkeys(m[3] for m in MUTANTS.values()):
        base[step] = reach(step, None, E, en)[:2]
        if step in NEW:
            check(f"mutant base: step '{step}' passes without a cut", base[step][0],
                  "" if base[step][0] else base[step][1][:300])
    for cut, (path, old, new, step) in MUTANTS.items():
        name = f"mutant {cut} ({path} without that fix, in memory only): step '{step}' fails"
        if base[step][0] is not True:
            check(name + " - base fails now (H2), not counted", True, "base: " + base[step][1][:200])
            continue
        ok, detail, was = reach(step, (path, old, new), E, en)
        check(name, was and ok is False, "cut not found" if not was else "it passed" if ok else
              "not reached: " + detail[:200] if ok is None else "")


def run_checks():
    checks = []

    def check(name, ok, detail=""):
        checks.append(F.Check("lt: " + name, bool(ok), str(detail)))
    mutants(check)
    return checks


if __name__ == "__main__":       # alone: python3 tools/harness/flow_lt_mut.py
    cs = run_checks()
    for x in cs:
        print(("ok    " if x.ok else "FAIL  ") + x.name + (f"  [{x.detail[:300]}]" if x.detail else ""))
    print(f"{sum(x.ok for x in cs)}/{len(cs)} passed")
    sys.exit(0 if all(x.ok for x in cs) else 1)
