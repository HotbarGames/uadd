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
  * A bare line with a list of one-word names ("<name>, <name>") stays as it is: they may be players.
  * Long odd lines of each split shape take under 5 ms each, nothing remembered.
"""
import hashtext
from loader import lua_str, txt

ZONE, ZONE_UK, ZONE_NONE = "Quixbury Hollow", "Квіксова Балка", "Blorp Fen"
ITEM, ITEM_UK, ITEM_NONE = "Wobbly Vest", "Хиткий жилет", "Blorpy Vest"
ITEM2, ITEM2_UK = "Quixy Thread", "Квіксова нитка"
NPC, NPC_UK = "Gobbix Quill", "Ґоббікс Перо"
GUILD = "<Wobble Club>"
ACCENT, GREY = "|cff66ccff", "|cff8a93a6"
PLAYERS = (("Thrallix", "Тралікс"), ("Jainix", "Джейнікс"))
SLOW = (("coloured label", ACCENT + "a" * 10240), ("step and grey zones", ("x  " + GREY + "-  ") * 640),
        ("link", "|H" * 5120 + "a"), ("wide gap", "a" + " " * 10240 + "b"), ("quoted note", "a" * 10240 + ': "'))
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
    # A bare line with a list is never names: players may be named as NPCs (lesson 13).
    for a, b in PLAYERS:
        C.names(lua_str(a), lua_str(b))
    for i, sep in enumerate((", ", " or ", " / ")):
        line = sep.join(a for a, _ in PLAYERS)
        got = put(f"s12{i}", line)
        check(f"screens: a bare list of one-word names stays as it is ({sep.strip()})", got == line, got)
    # Long odd lines, nothing remembered (a name UALL Forever makes wait is never cached): no pattern with
    # two lazy runs may take the square of the line (docs/LESSONS2.md lesson 22).
    for name, text in SLOW:
        ms = C.slow(lua_str(text))
        check(f"screens: a 10 KB line of the {name} shape takes under 5 ms", ms < 5, f"{ms:.1f} ms")
