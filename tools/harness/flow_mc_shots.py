"""UADD_Mastercraft: the lines the owner's shots of 2026-11-23 showed English (called from flow_mc_code2.run).
Every line is glued in Mastercraft's code, so it has no key of its own: each part is ours or a game name
(UALL Forever, ClassicUA first), and a part with no Ukrainian leaves the whole line English.

  * The two specialization cards (spell names) and the all-caps "NOW" button.
  * A number in another colour than its key's ("N of M recipes make a profit").
  * "<text> (<duration> ago)", "<text> about <money>", counts joined with a comma.
  * "<npc> (level N, <zone>): P%", "<item> x4 (<profession>)".
  * Parts joined with two spaces: a cooldown chip and its time, a row's "Drop: <npc>".
The English comes from the installed addon by hash key (a few made-up names and short labels are here).
"""
from loader import lua_str, txt
import hashtext

KEYS = {"profit": "53:f82331de", "ah": "34:c42e5a73", "worth": "38:e3d3d1b0", "bags": "10:69c07182",
        "bank": "10:69c07261", "skill": "8:c6a9166d", "lost": "11:0b2215f1", "drops": "11:ea053b9b",
        "elem": "20:56ec5932", "now": "3:0b880d79", "lvl": "8:1898a046"}
ZONE, ZONE_UK, NPC, NPC_UK, NPC2 = "Quixbury Hollow", "Квіксова Балка", "Gobbix Quill", "Ґоббікс Перо", "Blorp Quill"
ITEM, ITEM_UK = "Wobbly Vest", "Хиткий жилет"
TR = (("Iron to Gold", "Залізо на Золото"), ("Mithril to Truesilver", "Міфрил на Істинне срібло"))
MONEY = "12g 5s"


def run(check, F, src):
    import flow_mc_code
    en = {hashtext.key(e): e for e, _ in src}
    miss = [k for k, key in KEYS.items() if key not in en]
    check("shots 3: each text read from the installed Mastercraft by its key", not miss, miss)
    if miss:
        return
    E = {k: en[key] for k, key in KEYS.items()}
    c, M, C = flow_mc_code._game(F)
    for a, b in ((ZONE, ZONE_UK), (NPC, NPC_UK), (ITEM, ITEM_UK)):
        C.names(lua_str(a), lua_str(b))
    C.names(lua_str("Armorsmith"), lua_str("Бронник"), lua_str("Spell"))
    for a, b in TR:
        C.names(lua_str("Transmute: " + a), lua_str("Трансмутація: " + b), lua_str("Spell"))

    def want(k):
        return txt(C.want(lua_str(KEYS[k])))

    def fill(k, *vals):
        return txt(C.fill(lua_str(KEYS[k]), *map(lua_str, vals)))

    n = [0]

    def put(text):
        n[0] += 1
        name = "sh%d" % n[0]
        C.text(lua_str(name))
        return txt(C.set(lua_str(name), lua_str(text)))

    def same(what, text):
        got = put(text)
        check(f"shots 3: {what} stays whole English", got == text, got)

    got = put("Armorsmith")
    check("shots 3: a specialization card takes its spell name from UALL Forever", got == "Бронник", got)
    same("a specialization UALL Forever lacks", "Weaponsmith")
    got = put("NOW")
    check("shots 3: the all-caps button", got == want("now").upper() and got != "NOW", got)
    # a number in another colour than the key's
    for i, col in enumerate(("eef0f5", "ffd100")):
        got = put(E["profit"].replace("3dc773", col) % (58, 104))
        ok = fill("profit", "58", "104").replace("3dc773", col)
        check(f"shots 3: a recipes-with-profit line in another colour {i + 1}", got == ok and got != ok.upper(), got)
    # a duration after a money line, and "about <money>"
    dur = put("21h 24m")
    check("shots 3: the duration alone has Ukrainian units", dur != "21h 24m", dur)
    got = put(E["ah"] % MONEY + " (21h 24m ago)")
    check("shots 3: <text> (<duration> ago)", got == fill("ah", MONEY) + f" ({dur} тому)", got)
    same("a duration with an open bracket", E["ah"] % MONEY + " (21h 24m ago")
    got = put(E["worth"] % (18, MONEY))
    check("shots 3: <count> are worth about <money>", got == fill("worth", "18", MONEY), got)
    same("a worth line with a word of English as its value", E["worth"] % (18, "wobbly"))
    # counts joined with a comma
    got = put(E["bags"] % 13 + ", " + E["bank"] % 5)
    bank = fill("bank", "5")
    if bank.startswith("У"):  # after a comma our word goes on in small letters
        bank = "у" + bank[1:]
    check("shots 3: counts joined with a comma", got == fill("bags", "13") + ", " + bank, got)
    same("a count list with one part of English", E["bags"] % 13 + ", 5 wobbly")
    # an npc, its level and zone, and a percent
    lvl = fill("lvl", "37")
    got = put(f"{NPC} (level 37, {ZONE}): 71%")
    check("shots 3: <npc> (level N, <zone>): P%", got == f"{NPC_UK} ({lvl[0].lower() + lvl[1:]}, {ZONE_UK}): 71%", got)
    same("a level line with a zone UALL Forever lacks", f"{NPC} (level 37, Blorp Fen): 71%")
    same("a level line with an npc UALL Forever lacks", f"{NPC2} (level 37, {ZONE}): 71%")
    # an item and its profession
    prof = put("Tailoring")
    got = put(f"{ITEM} x4 (Tailoring)")
    check("shots 3: <item> x4 (<profession>)", prof != "Tailoring" and got == f"{ITEM_UK} x4 ({prof})", got)
    same("an item UALL Forever lacks with its profession", f"{NPC2} x4 (Tailoring)")
    # a cooldown chip: a group, or transmute names, then the time, joined with two spaces
    hours = put("23 hours")
    got = put(E["elem"] + "  23 hours")
    check("shots 3: a cooldown group and its time", got == want("elem") + "  " + hours and hours != "23 hours", got)
    one = put("1 hour")
    got = put(", ".join(a for a, _ in TR) + "  1 hour")
    check("shots 3: transmute names and their time", got == ", ".join(b for _, b in TR) + "  " + one, got)
    same("a transmute UALL Forever lacks", TR[0][0] + ", Iron to Wobbly  1 hour")
    same("a chip with a word of English before its time", "Zzz qqq  1 hour")
    # a recipe row: our words, a gap, a skill, a gap and where it drops (no key: our "Drops from:")
    head = want("lost") + "  " + fill("skill", "300")
    got = put(E["lost"] + "  " + E["skill"] % 300 + "  Drop: " + NPC)
    check("shots 3: a not-learned row with its drop", got == head + "  " + want("drops") + " " + NPC_UK, got)
    same("a not-learned row with an npc UALL Forever lacks", E["lost"] + "  " + E["skill"] % 300 + "  Drop: " + NPC2)
