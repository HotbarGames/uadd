"""UADD_Mastercraft: the craft orders board and its cards (Mastercraft 2.0.8), on the stand-in, in a game of
their own (called from flow_mc_code2.run). Every cell there is a raw string (no mc* fields) and many glue
our words to a player's name, a note or money in code, so Raw.lua gives each one a reader (mcWords).

The English comes from the installed addon by hash key. The board's words may not be in our data yet (they
are translated apart from this code), so a few get made-up Ukrainian here (flow_mc_code.lua C.teach): the
checks test the readers and the hooks, not the words.

  * A board row: the profession with its skill, the materials, the age (one line or two), "you" on your own
    order; the recipe name and another buyer's name stay as they are, even a player named like our word.
  * The post card's line under the recipe; a recipe found while posting stays as it is (a game name).
  * The offer card: "<label>: <buyer>", the parts after wide gaps, the buyer's note in quotes on its own
    line (kept as typed); one part we lack keeps the whole text English.
  * Your order's card, and an offer on it (the crafter's note in quotes, wide gaps inside it kept).
  * The deal card: who, the recipe line kept, price with a tip, materials, when; one line we lack keeps it
    all English. Off gives the English back, on ours again, in a Cyrillic font. A card glued into one line
    (a name with more text after it) stays English. Items on its materials line: UALL Forever's name for
    every one, or the whole card English (held and off too).
  * The new-order toast: a named window made late (one of Mastercraft's own strings).
  * Odd input to each reader leaves the text English, and a 10 KB line takes under 5 ms.
"""
import time

import clock
import hashtext
from loader import lua_str, txt

ITEM, ITEM_UK = "Wobbly Vest", "Хиткий жилет"
STRANGER = "Zorp Gizmo"                        # an item UALL Forever and ClassicUA have no name for
WHO, NOTE = "Thrallix-Quixmoor", '"Wobbly   bags, ask me"'
GOLD = "5|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"
TIP = "75|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t"
KEYS = {"buyer": "5:0ceb89ec", "tip": "3:0b882632", "price": "5:0de6f778", "mats": "9:55c2e867",
        "when": "4:7c8e8c57", "crafter": "7:3a3ece0c", "you": "3:0b883c42", "h": "4:7c730776",
        "min": "6:6552e032", "all": "16:ab6884aa", "asked": "8:5e94e301", "now": "3:0b880d79",
        "closes": "12:9c9ca49d", "prof": "9:468c47ae", "toast": "41:ea904d2c"}
UK = {"buyer": "Покупець", "tip": "Чайові", "price": "Ціна", "mats": "Матеріали", "when": "Коли",
      "crafter": "Майстер", "you": "Ви", "all": "Усе приносить покупець", "asked": "Як просили", "now": "Зараз",
      "prof": "Кравецтво"}
ODD = ("", '"', '   "', '""', "x: ", ": ", "\n\n\n", "   ", "1 h  20 min", "1 h\n\n20 min", '"   "   "')


def run(check, F, src):
    import flow_mc_code
    en = {hashtext.key(e): e for e, _ in src}
    miss = [k for k, key in KEYS.items() if key not in en]
    check("orders: each text read from the installed Mastercraft by its key", not miss, miss)
    if miss:
        return
    E = {k: en[key] for k, key in KEYS.items()}
    c, M, C = flow_mc_code._game(F)
    C.names(lua_str(ITEM), lua_str(ITEM_UK))
    for k, uk in UK.items():
        C.teach(lua_str(E[k]), lua_str(uk))
    h, m = E["h"] % 1, E["min"] % 20
    C.teach(lua_str(h), lua_str("1 год"))
    C.teach(lua_str(m), lua_str("20 хв"))
    closes = E["closes"] % "2h 5m"
    C.teach(lua_str(closes), lua_str("Закриється за 2h 5m"))
    C.orders()

    def put(card, field, text):
        return txt(C.ordSet(lua_str(card), lua_str(field), lua_str(text)))

    def bad(cases):
        return [(card, field, got) for card, field, text, exp in cases if (got := put(card, field, text)) != exp]
    U = UK
    row = [("row", "sub", f"{E['prof']} 150", f"{U['prof']} 150"), ("row", "mats", E["all"], U["all"]),
           ("row", "age", f"{h} {m}", "1 год 20 хв"), ("row", "age", f"{h}\n{m}", "1 год\n20 хв"),
           ("row", "age", m, "20 хв"), ("row", "name", ITEM, ITEM), ("row", "tip", GOLD, GOLD)]
    b = bad(row)
    check("orders: a board row: profession and skill, materials, age on one line or two (recipe kept)",
          not b and C.ordCyr(lua_str("row"), lua_str("age")), b[:2])
    mine = txt(C.ordBuyer(lua_str(E["you"]), True))
    other = txt(C.ordBuyer(lua_str(E["you"]), False))
    name = txt(C.ordBuyer(lua_str(WHO), False))
    check("orders: the buyer cell: «you» on your own order; a player named like it, and any buyer, as they are",
          (mine, other, name) == (U["you"], E["you"], WHO), (mine, other, name))
    got = put("post", "selSub", f"{E['prof']} 300")
    check("orders: the post card's line under the recipe", got == f"{U['prof']} 300", got)
    sug = f"{ITEM}  |cff8a93a6{E['prof']} 300|r"
    got = put("sug", "text", sug)
    check("orders: a recipe found while posting (the recipe, then its profession) stays as it is, never half",
          got == sug and not C.ordCyr(lua_str("sug"), lua_str("text")), got)
    info = f"{E['buyer']}: {WHO}   {E['all']}   {E['tip']} {TIP}"
    info_uk = f"{U['buyer']}: {WHO}   {U['all']}   {U['tip']} {TIP}"
    gap = f"{E['buyer']}: {WHO}   Wobbly gizmo   {E['tip']} {TIP}"
    b = bad([("offer", "info", info, info_uk), ("offer", "info", f"{info}\n{NOTE}", f"{info_uk}\n{NOTE}"),
             ("offer", "info", gap, gap), ("offer", "info", f"Wobbly: {WHO}   {E['all']}", f"Wobbly: {WHO}   {E['all']}"),
             ("offer", "item", f"{ITEM}  x2", f"{ITEM}  x2")])
    check("orders: the offer card: label and buyer, the parts, the note kept; a part we lack: all English", not b, b[:2])
    mi = f"{E['all']}   {E['tip']} {TIP}   {closes}"
    sub = f"{E['prof']} 150   {E['asked']}   {E['now']}"
    sub_uk = f"{U['prof']} 150   {U['asked']}   {U['now']}"
    b = bad([("mine", "info", mi, f"{U['all']}   {U['tip']} {TIP}   Закриється за 2h 5m"),
             ("mrow", "sub", sub, sub_uk), ("mrow", "sub", f"{sub}   {NOTE}", f"{sub_uk}   {NOTE}"),
             ("mrow", "sub", f"{sub}   Wobbly", f"{sub}   Wobbly"), ("mrow", "name", f"{WHO}  {GOLD}", f"{WHO}  {GOLD}")])
    check("orders: your order's card and an offer on it (the crafter's note kept as typed, gaps and all)",
          not b, b[:2])
    body = "\n".join((f"{E['crafter']}: {WHO}", f"{ITEM}  x2", f"{E['price']}: {GOLD}  + {E['tip']} {TIP}",
                      f"{E['mats']}: {E['all']}", f"{E['when']}: {E['now']}"))
    body_uk = "\n".join((f"{U['crafter']}: {WHO}", f"{ITEM}  x2", f"{U['price']}: {GOLD}  + {U['tip']} {TIP}",
                         f"{U['mats']}: {U['all']}", f"{U['when']}: {U['now']}"))
    odd = body.replace(f"{E['when']}: {E['now']}", f"{E['when']}: Wobbly later")
    b = bad([("deal", "body", body, body_uk)])
    cyr = C.ordCyr(lua_str("deal"), lua_str("body"))
    b += bad([("deal", "body", odd, odd)])
    check("orders: the deal card: who, the recipe line kept, price and tip, materials, when; a line we lack: "
          "all English", not b and cyr and not C.ordCyr(lua_str("deal"), lua_str("body")), (b[:2], cyr))
    M.uadd("mastercraft off")
    off = (txt(C.ordGet(lua_str("deal"), lua_str("body"))), txt(C.ordGet(lua_str("row"), lua_str("sub"))))
    M.uadd("mastercraft on")
    on = (txt(C.ordGet(lua_str("deal"), lua_str("body"))), txt(C.ordGet(lua_str("row"), lua_str("sub"))))
    check("orders: off: Mastercraft's English on the board and cards; on: ours again",
          off == (odd, f"{E['prof']} 150") and on == (odd, f"{U['prof']} 150"), (off, on))
    put("deal", "body", body)
    M.uadd("mastercraft off")
    off = txt(C.ordGet(lua_str("deal"), lua_str("body")))
    M.uadd("mastercraft on")
    on = txt(C.ordGet(lua_str("deal"), lua_str("body")))
    check("orders: off and on again with a card in Ukrainian", (off, on) == (body, body_uk), (off, on))
    glued(check, put, E, body)
    mats(check, M, C, put, E, body, body_uk)
    toast = E["toast"] % (ITEM, TIP)
    C.teach(lua_str(toast), lua_str(f"Нове замовлення: {ITEM_UK} - {TIP}"))
    got = txt(C.toast(lua_str(toast)))
    check("orders: the new-order toast (a window made late) is reached", got == f"Нове замовлення: {ITEM_UK} - {TIP}",
          got)
    odd_bad = [(k, t, got) for k in ("piece", "age", "gaps", "info", "deal") for t in ODD
               if (got := txt(C.read(lua_str(k), lua_str(t)))) != ""]
    check("orders: odd input to each reader leaves the text English", not odd_bad, odd_bad[:3])
    slow = []
    for k, t in (("piece", "a " * 5120), ("gaps", "a   " * 2560), ("info", ": a" * 3400), ("deal", "a: b\n" * 2048),
                 ("piece", "a" + " " * 10240 + "5"), ("info", '"' * 10240), ("age", "1 " * 5120)):
        best = None
        for _ in range(3):
            t0 = time.process_time()          # CPU time (load still slows it: clock.py stretches the bound)
            C.read(lua_str(k), lua_str(t))
            ms = (time.process_time() - t0) * 1000
            best = ms if best is None else min(best, ms)
        slow.append((k, round(best, 1)))
    limit, ref = clock.bound(5)
    slow = [s for s in slow if s[1] >= limit]
    check("orders: a 10 KB line through each reader takes under 5 ms", not slow, f"{slow} {clock.note(limit, ref)}")
    F._errors(c, check, "orders game")


def glued(check, put, E, body):
    """A card's lines glued into one (the chaos test's "word swapped"): the name part then takes more text
    after it, English we lack too. A name is one word, so each such cell stays whole English."""
    one = " ".join(body.split()).replace(ITEM, f"{ITEM} {STRANGER}")
    cases = [("deal", "body", one), ("deal", "body", f"{E['crafter']}: {WHO}\n{STRANGER}\n{E['when']}: {E['now']}"),
             ("deal", "body", f"{E['crafter']}: {WHO}\n{ITEM}  x2"),
             ("offer", "info", f"{E['buyer']}: {WHO} {STRANGER}   {E['all']}")]
    b = [(card, field, got) for card, field, text in cases if (got := put(card, field, text)) != text]
    check("orders: a card glued into one line, a recipe line without its count, a name with more after it: "
          "all English", not b, b[:2])


def mats(check, M, C, put, E, body, body_uk):
    """Item names on the deal card's materials line are game names: UALL Forever's (or ClassicUA's) for
    every one, else the whole card stays English, also on the hold key and off and on again."""
    line = f"{E['mats']}: {E['all']}"
    known, known_uk = body.replace(line, f"{E['mats']}: 2 {ITEM}"), body_uk.replace(f"{UK['mats']}: {UK['all']}",
                                                                                    f"{UK['mats']}: 2 {ITEM_UK}")
    lack = body.replace(line, f"{E['mats']}: 2 {ITEM}, 1 {STRANGER}")

    def card():
        return txt(C.ordGet(lua_str("deal"), lua_str("body")))

    def walk():
        seen = [card()]
        M.key(True)
        seen.append(card())
        M.key(False)
        seen.append(card())
        M.uadd("mastercraft off")
        seen.append(card())
        M.uadd("mastercraft on")
        return seen + [card()]
    put("deal", "body", lack)
    got = walk()
    check("orders: an item we have no name for on the materials line: the whole card English, held, off, on",
          got == [lack] * 5 and not C.ordCyr(lua_str("deal"), lua_str("body")), got[:2])
    put("deal", "body", known)
    got = walk()
    check("orders: every item named on the materials line: ours (UALL Forever's name), English held and off",
          got == [known_uk, known, known_uk, known, known_uk], got)
