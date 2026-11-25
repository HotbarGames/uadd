"""UADD_Auctionator: the crafting window's price text (ns.UA_MADE `lines`). Run by flow_auc_items.py.

Auctionator (Source_Mainline/CraftingInfo/Professions.lua) glues one text: up to three lines, each a label, a
space and money in its own colour; the profit line may end in a warning. Its labels are read from the installed
Auctionator and put in its AUCTIONATOR_L_ globals for a while. Each mix of lines is whole Ukrainian, the money
and its colour kept; unknown English in a money slot, or a warning that is not ours, keeps the whole text English.
"""
import itertools

from loader import lua_str, txt

KEYS = ("TO_CRAFT_COLON", "PROFIT_COLON", "CHEAPEST_QUALITY_COST_COLON")
WARNINGS = ("PROFIT_WARNING_AGE", "PROFIT_WARNING_MISSING", "PROFIT_WARNING_NOT_EXACT_ITEM")
ICON = "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t"
WHITE, RED = f"|cffffffff35{ICON}|r", f"|cffff2020-16{ICON}|r"
PRICE = {"TO_CRAFT_COLON": WHITE, "PROFIT_COLON": RED, "CHEAPEST_QUALITY_COST_COLON": WHITE}
UNKNOWN = "Wobbly gizmo"


def run(check, c, M):
    import make_auc_text as A
    name = "craft price: each mix of lines whole Ukrainian, or whole English"
    addon = A.addon_dir()
    if not (addon / "Locales" / "enUS.lua").is_file():
        return check(f"{name} (Auctionator not installed)", True, "")
    real, g, W = A.read_enus(addon)[0], c.lua.globals(), c.H.ns.UADD_Auctionator.Words
    en = {k: real[k][0] for k in KEYS + WARNINGS}
    uk = {k: txt(M.ua(lua_str(k))) for k in en}
    saved = {k: g["AUCTIONATOR_L_" + k] for k in en}

    def made(of, keys, price):
        return "\n".join(f"{of[k]} {price[k]}" for k in keys)

    def got(text):
        out = W.Text(lua_str(text))
        return out and txt(out)
    bad, n = [], 0
    try:
        for k, v in en.items():
            g["AUCTIONATOR_L_" + k] = lua_str(v)
        W.Build()
        for size in (1, 2, 3):
            for keys in itertools.combinations(KEYS, size):
                tails = [None] + (list(WARNINGS) if "PROFIT_COLON" in keys else [])
                for w in tails:
                    eng, our = (dict(PRICE, PROFIT_COLON=RED + (f" {of[w]}" if w else "")) for of in (en, uk))
                    text, want = made(en, keys, eng), made(uk, keys, our)
                    n += 1
                    if got(text) != want:
                        bad.append((text, got(text), want))
                for k in keys:                       # one money slot with English we do not know
                    for odd in (UNKNOWN, f"{PRICE[k]} ({UNKNOWN})", f"{PRICE[k]} {UNKNOWN}"):
                        text = made(en, keys, dict(PRICE, **{k: odd}))
                        n += 1
                        if got(text) not in (None, text):
                            bad.append((text, got(text), "whole English"))
    finally:
        for k, v in saved.items():
            g["AUCTIONATOR_L_" + k] = v
        W.Build()
    check(f"{name} ({n})", n and not bad, bad[:3])
