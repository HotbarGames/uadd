"""More UADD_Attune checks on the Attune stand-in (tools/harness/attune/Extra.lua), run by flow_att.py
in game A after the names:

  * texts Attune sets and measures before they are inside its windows are Ukrainian when measured:
    the header label of a pick (an AceGUI Label, text set before AddChild), the "Will not do" check box
    and the icon view's section header (both on their first draw);
  * one bag update (Attune_NextFrameRefresh, which calls Attune_NextFrameLayout) walks the Next window
    at most twice: once at once, once on the next frame;
  * another addon's AceGUI widget, made while Attune's windows show (it may be one Attune gave back to
    the pool), starts no walk and keeps its English;
  * Shift: a text a player typed that reads like our words stays as typed (no guess of its English);
    ours show their exact English.
"""
import re

from loader import txt

HELD = 0.4                      # the hold key counts after 0.25 s
CYR = re.compile("[Ѐ-ӿ]")


def _walks(c):
    return c.lua.eval("UADD.AttuneScreen.Walks()")


def _text(c, expr):
    return txt(c.lua.eval(expr))


def measured(check, c, M):
    ua = txt(M.ua("Required level"))
    for key, now, want in (
            ("head", "AttuneStandIn.headLabel.label:GetText()", ua),
            ("skip", "AttuneSkipCheck.text:GetText()", None),
            ("icon", "AttuneStandIn.iconHeader.text:GetText()", None)):
        seen, width = txt(M.si(key + "Seen")), M.si(key + "W")
        ok = (isinstance(seen, str) and bool(CYR.search(seen)) and seen == _text(c, now)
              and (want is None or seen == want) and width == len(seen.encode("utf-8")) * 6)
        check(f"measured in Ukrainian: {key} ({seen!r}, {width} px)", ok, (seen, width, _text(c, now)))


def walks_per_bag(check, c, M):
    M.wait(0.2)
    w0 = _walks(c)
    M.bags(1)
    M.wait(0.1)
    n = _walks(c) - w0
    check(f"one bag update: at most 2 walks ({n})", n <= 2, n)
    return n


_PAGE = 'LibStub("AceConfigDialog-3.0").BlizOptions.Attune.Attune.frame'


def foreign(check, c, M):
    # Attune's main window shows; its settings page (shown in the stand-in's options frame) is hidden
    # for the check, since a new widget while that page shows is meant to start a look.
    M.open()
    c.lua.execute(f'HARNESS.att.page = {_PAGE}:IsShown() {_PAGE}:Hide()')
    M.wait(0.2)
    w0 = _walks(c)
    c.lua.execute('local g = LibStub("AceGUI-3.0"):Create("Label") g:SetText("Required level") HARNESS.att.foreign = g')
    M.wait(0.1)
    n, t = _walks(c) - w0, _text(c, "HARNESS.att.foreign.label:GetText()")
    check("another addon's AceGUI widget: no walk, its text English", n == 0 and t == "Required level", (n, t))
    c.lua.execute('LibStub("AceGUI-3.0"):Release(HARNESS.att.foreign) HARNESS.att.foreign = nil')
    c.lua.execute(f'if HARNESS.att.page then {_PAGE}:Show() end HARNESS.att.page = nil')


def typed(check, c, M):
    M.select("20")
    M.siCall("Typed", True)
    M.select("20")
    M.wait(0.1)
    M.key(True)
    M.wait(HELD)
    got = (_text(c, "AttuneStandIn.typed:GetText()"), _text(c, "AttuneStandIn.headLabel.label:GetText()"))
    check("Shift held: a typed text like ours stays as typed, ours exact English",
          got == ("Потрібен рівень", "Required level"), got)
    M.key(False)
    M.wait(0.1)
    M.siCall("Typed", False)


def run(check, c, M):
    """Returns the walks of one bag update."""
    measured(check, c, M)
    n = walks_per_bag(check, c, M)
    foreign(check, c, M)
    typed(check, c, M)
    return n
