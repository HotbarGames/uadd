"""UADD_Auctionator: column headers (Rows.lua). Run by flow_auc.py on the open auction house.

  * a header made at load and one made later: Ukrainian at once;
  * a narrow column's header with a short form in ui/locale.lua's ns.UA_HEAD (docs/LESSONS.md,
    lesson 5): the short form, made at load or later, from either locale key; the same English
    in a roomy place (a stand-in for the Shopping item dialog's range title) keeps the full words;
  * Shift: the headers' exact English (held: called while the key is held).
"""
from loader import txt


def _eq(check, name, got, want):
    got = txt(got)
    check(name, got == want, f"{got!r} | want {want!r}")


def surfaces(check, M, u, uo):
    _eq(check, "header made at load in Ukrainian", M.text("header", "name"), uo("Name"))
    M.header("price", "Price")                      # a header made now: no step
    _eq(check, "header made later: Ukrainian at once", M.text("header", "price"), uo("Price"))
    short = txt(M.head("ITEM_LEVEL_COLUMN"))
    check("ns.UA_HEAD: a short form, shorter than ns.UA", 0 < len(short) < len(u("ITEM_LEVEL_COLUMN")),
          f"{short!r} vs {u('ITEM_LEVEL_COLUMN')!r}")
    _eq(check, "narrow header made at load: its short form", M.text("header", "ilvl"), txt(M.head("ITEM_LEVEL")))
    M.header("ilvlColumn", M.en("ITEM_LEVEL_COLUMN"))   # the Buy and Selling lists' key, made now
    _eq(check, "narrow header made later: its short form", M.text("header", "ilvlColumn"), short)
    _eq(check, "same English in a roomy place: full words", M.text("text", "ilvlRange"), u("ITEM_LEVEL"))


def held(check, M):
    _eq(check, "Shift: header exact English", M.text("header", "price"), "Price")
    _eq(check, "Shift: narrow header exact English", M.text("header", "ilvl"), txt(M.en("ITEM_LEVEL")))
