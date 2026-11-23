"""UADD_Mastercraft: the lines the owner's screenshots showed English (2026-11-20), on the stand-in, in a
game of their own (called from flow_mastercraft.run). The English comes from the installed addon by hash
key; the game names are made up and given UALL Forever's Ukrainian here (flow_mc_code.lua C.names).

  * A list of game names with counts in a slot ("2 <item>, <item>": the mats of a step) takes every name
    from UALL Forever; one name it lacks keeps the whole line English.
  * A line that is only a game name (a fish, an item with " x10" after it, the zone under the character,
    after the player's guild tag, which stays as it is) takes UALL Forever's name.
  * A gathering step "<game name> - <our words>" (a template made from the guide's data), also inside
    "Level <profession>: <step>" and the guide's coloured "<label>:  <step>  - <zones>" line.
  * Parts joined with "  -  " (the cooking card: a colour hint, a vendor with its price) and with Home's
    grey dot; a skill after a rank ("<rank>  286 / 300"); "<count>x <fish>".
  * A guide step's row title "<recipe>   <count in grey>" (one SetText, the row reused) takes the recipe's
    name from UALL Forever (an enchant: its spell; in its own colour, kept); a recipe it lacks, or one that is
    "not now", keeps the row English (asked again later), and so do two recipes or a list of herbs.
  * A bare line with a list of one-word names ("<name>, <name>") stays as it is: they may be players.
  * Long odd lines of each split shape take under 5 ms each, nothing remembered.
"""
import clock
import hashtext
from loader import lua_str, txt

ZONE, ZONE_UK, ZONE_NONE = "Quixbury Hollow", "Квіксова Балка", "Blorp Fen"
ITEM, ITEM_UK, ITEM_NONE = "Wobbly Vest", "Хиткий жилет", "Blorpy Vest"
ITEM2, ITEM2_UK = "Quixy Thread", "Квіксова нитка"
ITEM3, ITEM3_UK, SPELL, SPELL_UK = "Quixy Gloves", "Квіксові рукавиці", "Wobble Ward", "Хитка оберега"
NPC, NPC_UK = "Gobbix Quill", "Ґоббікс Перо"
GUILD = "<Wobble Club>"
ACCENT, GREY = "|cff66ccff", "|cff8a93a6"
PLAYERS = (("Thrallix", "Тралікс"), ("Jainix", "Джейнікс"))
SLOW = (("coloured label", ACCENT + "a" * 10240), ("step and grey zones", ("x  " + GREY + "-  ") * 640),
        ("link", "|H" * 5120 + "a"), ("wide gap", "a" + " " * 10240 + "b"), ("quoted note", "a" * 10240 + ': "'),
        ("recipe and count", "a" + " " * 10240 + GREY + "x5|r"), ("many counts", "a " + (GREY + "x5|r") * 640),
        ("count after colours", "a " + GREY * 1000 + "x5|r"))
KEYS = {"mats": "23:8233d78b", "level": "12:fa0b1e27", "named": "23:ba3c123a", "vendor": "10:27784c65",
        "until": "15:6e3f6556", "missing": "12:f5381934", "now": "3:0b880d79", "likely": "6:c0cf8a0f"}


def run(check, F, src):
    import flow_mc_code
    en = {hashtext.key(e): e for e, _ in src}
    miss = [k for k, key in KEYS.items() if key not in en]
    check("screens: each text read from the installed Mastercraft by its key", not miss, miss)
    if miss:
        return
    E = {k: en[key] for k, key in KEYS.items()}
    c, M, C = flow_mc_code._game(F)
    for a, b in ((ZONE, ZONE_UK), (ITEM, ITEM_UK), (ITEM2, ITEM2_UK), (NPC, NPC_UK)):
        C.names(lua_str(a), lua_str(b))

    def want(k):
        return txt(C.want(lua_str(KEYS[k])))

    def fill(k, *vals):
        return txt(C.fill(lua_str(KEYS[k]), *map(lua_str, vals)))

    def put(name, text):
        C.text(lua_str(name))
        return txt(C.set(lua_str(name), lua_str(text)))

    # Lists of game names with counts.
    mats = E["mats"] % (53, 150, f"2 {ITEM}, {ITEM2}")
    got = put("s1", mats)
    ok = fill("mats", "53", "150", f"2 {ITEM_UK}, {ITEM2_UK}")
    check("screens: a list of mats with counts takes each name from UALL Forever", got == ok, got)
    bad = E["mats"] % (53, 150, f"2 {ITEM}, 2 {ITEM_NONE}")
    got = put("s2", bad)
    check("screens: one name UALL Forever lacks keeps the mats line English", got == bad, got)
    # A line that is only a game name.
    for i, (a, b) in enumerate(((f"{ITEM} x10", f"{ITEM_UK} x10"), (ITEM2, ITEM2_UK),
                                (f"{GUILD}   {ZONE}", f"{GUILD}   {ZONE_UK}"),
                                (f"{ITEM_NONE} x10", f"{ITEM_NONE} x10"),
                                (f"{GUILD}   {ZONE_NONE}", f"{GUILD}   {ZONE_NONE}"))):
        got = put(f"s3{i}", a)
        check(f"screens: a bare game name line {i + 1} (the guild tag kept)", got == b, got)
    # A gathering step made into a template, alone, in "Level %s: %s", and in the guide's "Now" line.
    step, step_uk = E["named"] % ITEM, fill("named", ITEM_UK)
    got = put("s4", step)
    check("screens: a gathering step takes its name from UALL Forever", got == step_uk and step_uk, got)
    got = put("s5", E["level"] % (ZONE, step))
    check("screens: Level <profession>: <step>", got == fill("level", ZONE_UK, step_uk), got)
    now = f"{ACCENT}{E['now']}:|r  {step}  {GREY}-  {ZONE}, {ZONE}|r"
    got = put("s6", now)
    ok = f"{ACCENT}{want('now')}:|r  {step_uk}  {GREY}-  {ZONE_UK}, {ZONE_UK}|r"
    check("screens: the guide's coloured label, step and zones", got == ok, got)
    bad = f"{ACCENT}{E['now']}:|r  {step}  {GREY}-  {ZONE}, {ZONE_NONE}|r"
    got = put("s7", bad)
    check("screens: a zone UALL Forever lacks keeps that line English", got == bad, got)
    # Joined parts, a skill after a rank, a fish count.
    cook = f"{E['until'] % 290}  -  {E['vendor'] % (NPC + ' - 2g')}"
    got = put("s8", cook)
    ok = f"{fill('until', '290')}  -  {fill('vendor', NPC_UK + ' - 2g')}"
    check("screens: the cooking card's parts joined with '  -  ' (a vendor and its price)", got == ok, got)
    home = f"{E['missing']}  {GREY}·|r  {mats}"
    got = put("s9", home)
    ok = f"{want('missing')}  {GREY}—|r  {fill('mats', '53', '150', f'2 {ITEM_UK}, {ITEM2_UK}')}"
    check("screens: Home's parts joined with a grey dot", got == ok, got)
    got = put("s10", E["likely"] + "  286 / 300")
    check("screens: a skill after a rank", got == want("likely") + "  286 / 300", got)
    got = put("s11", f"2x {ITEM}")
    check("screens: <count>x <fish>", got == f"2x {ITEM_UK}", got)
    # A guide step's row title: the recipe, a gap (open row 3 spaces, closed 2) and its count in grey, on one
    # row reused for the next step; a recipe UALL Forever lacks keeps the row English (the owner, 2026-11-20).
    for i, (title, uk, n, wide) in enumerate(((ITEM, ITEM_UK, 51, True), (ITEM2, ITEM2_UK, 25, False),
                                              (ITEM_NONE, ITEM_NONE, 10, True))):
        got = txt(C.step(lua_str("row"), lua_str(title), n, wide))
        ok = f"{uk}{'   ' if wide else '  '}{GREY}x{n}|r"
        check(f"screens: a guide step's row title {i + 1} (recipe, count in grey, a reused row)", got == ok, got)
    # The same rows: an enchant (only a spell's name), a recipe in its own colour, a name that is "not now" (never
    # remembered: Ukrainian once it answers), and two recipes or a list of herbs (whole English, on purpose).
    C.names(lua_str(SPELL), lua_str(SPELL_UK), lua_str("Spell"))
    C.names(lua_str(ITEM3), lua_str(ITEM3_UK))
    white = "|cffffffff"
    for i, (title, uk) in enumerate(((SPELL, SPELL_UK), (f"{white}{ITEM}|r", f"{white}{ITEM_UK}|r"),
                                     (f"{white}{ITEM_NONE}|r", f"{white}{ITEM_NONE}|r"),
                                     (f"{ITEM} + {ITEM2}", f"{ITEM} + {ITEM2}"), (f"{ITEM}, {ITEM2}", f"{ITEM}, {ITEM2}"))):
        got = txt(C.step(lua_str("row"), lua_str(title), 5, True))
        ok = f"{uk}   {GREY}x5|r"
        check(f"screens: a guide step's row title {i + 4} (a spell, colours, two names: whole line)", got == ok, got)
    C.hold(lua_str(ITEM3), True)
    got = txt(C.step(lua_str("row"), lua_str(ITEM3), 7, False))
    check("screens: a step whose recipe is 'not now' stays English", got == f"{ITEM3}  {GREY}x7|r", got)
    C.hold(lua_str(ITEM3), False)
    got = txt(C.step(lua_str("row"), lua_str(ITEM3), 7, False))
    check("screens: the same step once the recipe answers (nothing remembered)", got == f"{ITEM3_UK}  {GREY}x7|r", got)
    # A bare line with a list is never names: players may be named as NPCs (lesson 13).
    for a, b in PLAYERS:
        C.names(lua_str(a), lua_str(b))
    for i, sep in enumerate((", ", " or ", " / ")):
        line = sep.join(a for a, _ in PLAYERS)
        got = put(f"s12{i}", line)
        check(f"screens: a bare list of one-word names stays as it is ({sep.strip()})", got == line, got)
    # Long odd lines, nothing remembered (a name UALL Forever makes wait is never cached): no pattern with
    # two lazy runs may take the square of the line (docs/LESSONS2.md lesson 22).
    times = [(name, C.slow(lua_str(text))) for name, text in SLOW]
    limit, ref = clock.bound(5)                 # 5 ms stretched by the load seen now (clock.py)
    for name, ms in times:
        check(f"screens: a 10 KB line of the {name} shape takes under 5 ms", ms < limit,
              f"{ms:.1f} ms, {clock.note(limit, ref)}")
    # The craft orders board and its cards (Mastercraft 2.0.8), in a game of their own.
    import flow_mc_orders
    flow_mc_orders.run(check, F, src)
    import flow_mc_shots                         # the shots of 2026-11-23: lines glued in code
    flow_mc_shots.run(check, F, src)
