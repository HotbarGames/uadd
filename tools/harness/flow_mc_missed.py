"""UADD_Mastercraft: lines the game log of missed texts (/uadd missed, 2026-11-23) showed English, in a game of
their own (called from flow_mc_code2.run; mutants from mc_prove.py). Each line is glued in Mastercraft's code (Rows.lua):
every part is ours or a game name (ClassicUA, UALL Forever), and one unknown part keeps the whole line English. The
English comes from the installed addon by hash key (made-up names and a few short labels are here)."""
import gc
import os

import clock
import hashtext
import session
from loader import Client, lua_str, read_text, txt

HERE = os.path.dirname(os.path.abspath(__file__))
KEYS = {"now": "3:0b880d79", "skill": "8:c6a9166d", "lost": "11:0b2215f1", "drops": "11:ea053b9b",
        "lvl": "8:1898a046", "bags": "10:69c07182", "bank": "10:69c07261", "quest": "9:3ae14509",
        "sold": "10:166ad36a", "vendor": "10:27784c65", "needs": "16:f39b25e1", "learn": "27:347a4657",
        "scan": "67:b7b36fd0", "profit": "53:f82331de", "starred": "7:addb0f7a", "ah": "32:25dd4c26"}
ZONE, ZONE_UK, ZONE2, ZONE2_UK = "Quixbury Hollow", "Квіксова Балка", "Wobble Fen", "Хитка Драговина"
NPC, NPC_UK, NPC2, NPC2_UK = "Gobbix Quill", "Ґоббікс Перо", "Zim Quill", "Зім Перо"
ITEM, ITEM_UK, QUEST, QUEST_UK = "Wobbly Vest", "Хиткий жилет", "The Wobbly Kid", "Хиткий малий"
NO_NPC, NO_ZONE, NO_ITEM = "Blorp Quill", "Blorp Fen", "Blorpy Vest"
P1, P2 = "Thrallix", "Jainix"                        # players, though a route knows NPCs named like them
GREY, GOLD, STAR, BRAND = "|cff8a93a6", "|cffffd140", "|cffffd140*|r ", "|cff4da6ffMastercraft|r  "
FAVOR = "Прихильність Крамаря"
NODE = "|cffff8026125|r  |cffffd933150|r"
# 10 KB lines of each new shape, nothing remembered (lesson 22)
SLOW = (("sold by", "Sold by " + "a - " * 2560), ("vendor", "Vendor: " + "Aa / " * 2048), ("drop", "Drop: " + "a (" * 3400),
        ("creature", "a, level 2 - " + "b: " * 3400), ("zones", "Wobble Fen, " * 850), ("learn", "Learn " + " (1.1, " * 1400),
        ("colours", "|cffffffffa.|r " * 640), ("recipe, who", "a x1" + ("  " + GREY + "(") * 780),
        ("marks", "> " * 5120 + "a"), ("numbers", "Aa " * 3400 + ":  |cff"))
# name -> (file, the fix, what it was before, the step that must fail then)
MUTANTS = {
    "credits slot": ("data/text13.lua", 'sort = { "f", "f", "e" }', 'sort = { "f", "f", "t" }', "a vendor UALL Forever lacks"),
    "unknown zone": ("Rows.lua", "One(SHORT[z], ZONE) or nil", "One(SHORT[z], ZONE) or z", "a zone UALL Forever lacks"),
    "short zone": ("Rows.lua", "One(z, ZONE) or SHORT[z] and One(SHORT[z], ZONE)", "One(z, ZONE)", "a zone written short"),
    "unknown vendor": ("Rows.lua", "if not npc then return nil end\n", "npc = npc or part\n", "two vendors, one unknown"),
    "players": ("Rows.lua", 'return not v:find("%f[%a]%l%a")', "return true", "a phrase where players go"),
    "two players": ("Rows.lua", "return wide and (", "return (", "two players with NPCs' names"),
    "quest": ("Rows.lua", "if not (ua and lv and t) then return nil end", "if not (lv and t) then return nil end\n"
              "        ua = ua or title", "a quest UALL Forever lacks"),
    "owner": ("Words.lua", "if own then return own end", "", "a player's counts"),
    "count": ("Words.lua", "(%d+%-?%d* ?x? )", "(%d+%-?%d*x? )", "<count> x <item>"),
    "tooltip gate": ("Tooltip.lua", "if ns.Rows.Could(s) then return true end", "", "tooltip: a starred recipe"),
    "capitals": ("Glue.lua", "if CAPS[s] then return H.Upper(CAPS[s]) end", "", "the favour heading"),
}


def _game(F, cut=None):
    c = Client([F._stand_in(), F._addon("UADD"), F._addon(F.MODULE)], None, "enUS")
    c.lua.execute(read_text(os.path.join(HERE, "flow_mastercraft.lua")))
    c.lua.execute(read_text(os.path.join(HERE, "flow_mc_code.lua")))
    if cut:
        import mc_prove
        c.lua.execute(mc_prove.CUT_LUA)
        m = c.H.mccut
        m.addon, m.file, m.old, m.new = map(lua_str, (F.MODULE,) + tuple(cut))
        c.H.boxQuiet = True
    c.start()
    c.H.pump(60)
    return c, c.H.mcCode


def steps(check, F, src, cut=None):
    en = {hashtext.key(e): e for e, _ in src}
    miss = [k for k, key in KEYS.items() if key not in en]
    check("missed: each text read from the installed Mastercraft by its key", not miss, miss)
    if miss:
        return False
    E = {k: en[key] for k, key in KEYS.items()}
    c, C = _game(F, cut)
    for a, b in ((ZONE, ZONE_UK), (ZONE2, ZONE2_UK), (NPC, NPC_UK), (NPC2, NPC2_UK), (ITEM, ITEM_UK),
                 ("Artisan", "Майстер"), (P1, "Тралікс"), (P2, "Джейнікс"), ("The Barrens", "Степи")):
        C.names(lua_str(a), lua_str(b))
    C.names(lua_str(QUEST), lua_str(QUEST_UK), lua_str("Text"))

    def want(k):
        return txt(C.want(lua_str(KEYS[k])))

    def fill(k, *vals):
        return txt(C.fill(lua_str(KEYS[k]), *map(lua_str, vals)))

    n = [0]

    def put(text):
        n[0] += 1
        C.text(lua_str("mi%d" % n[0]))
        return txt(C.set(lua_str("mi%d" % n[0]), lua_str(text)))

    def ours(what, text, ok):
        got = put(text)
        check(f"missed: {what}", got == ok and got != text, f"{got} / wanted {ok}")

    def same(what, text):
        got = put(text)
        check(f"missed: {what}: whole English", got == text, got)

    def tip(what, text, ok):
        got = txt(C.tip(lua_str(text)))
        check(f"missed: tooltip: {what}", got == ok, f"{got} / wanted {ok}")

    sold, vendor = fill("sold", ""), fill("vendor", "")
    low = fill("lvl", "")
    low = low[0].lower() + low[1:]
    # who sells it, and where (with the vendor's side): never our words around an unknown name
    ours("<vendor> (A) - <zone>", f"Sold by {NPC} (A) - {ZONE}", f"{sold}{NPC_UK} (А) - {ZONE_UK}")
    ours("<vendor> (H) - <zone>", f"Sold by {NPC} (H) - {ZONE}", f"{sold}{NPC_UK} (О) - {ZONE_UK}")
    ours("a zone written short", f"Sold by {NPC} - Barrens", f"{sold}{NPC_UK} - Степи")
    same("a vendor UALL Forever lacks", f"Sold by {NO_NPC} - {ZONE}")
    same("a vendor UALL Forever lacks, with its side", f"Sold by {NO_NPC} (A) - {ZONE}")
    same("a zone UALL Forever lacks", f"Sold by {NPC} - {NO_ZONE}")
    same("a vendor with more English after it", f"Sold by {NPC} - {ZONE} - wobbly stock")
    ours("two vendors and the trade hub's favour", f"Vendor: {NPC} (A) / {NPC2} (H) - 30 Merchant's Favor",
         f"{vendor}{NPC_UK} (А) / {NPC2_UK} (О) - {FAVOR}: 30")
    ours("one vendor of a side and a price", f"Vendor: {NPC} / {NPC2} (H) - 44s", f"{vendor}{NPC_UK} / {NPC2_UK} (О) - 44s")
    same("two vendors, one unknown", f"Vendor: {NPC} (A) / {NO_NPC} (H) - 30 Merchant's Favor")
    same("a vendor with English for a price", f"Vendor: {NPC} (A) - needs wobbles")
    # a row: our words, a gap, a skill, a gap, the source
    row, row_uk = f"|cffffb833{E['lost']}|r  {GREY}{E['skill']}|r  ", f"|cffffb833{want('lost')}|r  {GREY}%s|r  "
    skill = fill("skill", "175")
    ours("a not-learned row with a vendor", row % 175 + f"Vendor: {NPC} (A) - 4s", row_uk % skill + f"{vendor}{NPC_UK} (А) - 4s")
    drops = want("drops")
    ours("a not-learned row with a drop", row % 175 + f"Drop: {NPC} ({ZONE}) 0.31%",
         row_uk % skill + f"{drops} {NPC_UK} ({ZONE_UK}) 0.31%")
    same("a row with an unknown creature", row % 175 + f"Drop: {NO_NPC} ({ZONE}) 0.31%")
    same("a row with a drop in an unknown zone", row % 175 + f"Drop: {NPC} ({NO_ZONE}) 0.31%")
    ours("a drop under a percent", f"Drop: {NPC} ({ZONE}) <0.1%", f"{drops} {NPC_UK} ({ZONE_UK}) <0.1%")
    # a creature, its levels and zone
    ours("a creature, levels, zone", f"{NPC}, level 21-22 - {ZONE}: 0.31%", f"{NPC_UK}, {low}21-22 - {ZONE_UK}: 0.31%")
    same("a creature in an unknown zone", f"{NPC}, level 21-22 - {NO_ZONE}: 0.31%")
    same("a creature UALL Forever lacks", f"{NO_NPC}, level 50 - {ZONE}: 11%")
    # marks, counts
    ours("a > mark", "> " + E["ah"], "> " + want("ah"))
    same("a > mark before English", "> Zzz qqq")
    ours("<count> x <item>", f"  2 x {ITEM}", f"  2 x {ITEM_UK}")
    same("<count> x an unknown item", f"  2 x {NO_ITEM}")
    ours("a starred recipe", f"  {STAR}{ITEM} {GREY}x1|r", f"  {STAR}{ITEM_UK} {GREY}x1|r")
    same("a starred recipe UALL Forever lacks", f"  {STAR}{NO_ITEM} {GREY}x1|r")
    src_en, src_uk = f"{E['skill'] % 240}  -  Quest: {QUEST}", f"{fill('skill', '240')}  -  {fill('quest', QUEST_UK)}"
    ours("the addon's name, a skill and a quest", BRAND + src_en, BRAND + src_uk)
    same("the addon's name, a skill, an unknown quest", f"{BRAND}{E['skill'] % 240}  -  Quest: Blorp Kid")
    ours("a skill and two vendors", f"{E['skill'] % 240}  -  Vendor: {NPC} / {NPC2} (H) - 44s",
         f"{fill('skill', '240')}  -  {vendor}{NPC_UK} / {NPC2_UK} (О) - 44s")
    # a quest's level; a zone's levels; a node's skills
    q = f"{GOLD}%s|r   |cff5c6373%s|r"
    ours("a quest, its level and need", q % (QUEST, "level 60" + E["needs"] % 50),
         q % (QUEST_UK, low + "60" + fill("needs", "50")))
    same("a quest UALL Forever lacks", q % ("Blorp Kid", "level 60" + E["needs"] % 50))
    ours("a zone's levels", f"{ZONE}{GREY} (42-55)|r", f"{ZONE_UK}{GREY} (42-55)|r")
    same("an unknown zone's levels", f"{NO_ZONE}{GREY} (42-55)|r")
    ours("a node's skills", "Herbalism:  " + NODE, put("Herbalism") + ":  " + NODE)
    same("a node of an unknown profession", "Blorping:  " + NODE)
    ours("a trainer with coordinates", f"{E['learn'] % ('Artisan', 35, NPC, ZONE)} (63.4, 20.8)",
         fill("learn", "Майстер", "35", NPC_UK, ZONE_UK) + " (63.4, 20.8)")
    same("a trainer in an unknown zone with coordinates", f"{E['learn'] % ('Artisan', 35, NPC, NO_ZONE)} (63.4, 20.8)")
    ours("a list of zones", f"{ZONE}, {ZONE2}, {ZONE}  +2", f"{ZONE_UK}, {ZONE2_UK}, {ZONE_UK}  +2")
    same("a list with an unknown zone", f"{ZONE}, {NO_ZONE}, {ZONE2}")
    same("two players with NPCs' names", f"{P1}, {P2}")
    # two sentences; players' names kept
    profit = E["profit"] % (58, 104)
    ours("two sentences on one line", f"|cffffb833{E['scan']}|r {profit}",
         f"|cffffb833{want('scan')}|r {fill('profit', '58', '104')}")
    same("two sentences, one unknown", f"|cffffb833Zzz qqq.|r {profit}")
    prof = f"  {GREY}(%s)|r"
    ours("a recipe and who knows it", f"{ITEM} x4{prof % 'Tailoring'}  {GREY}{P1}, {P2}|r",
         f"{ITEM_UK} x4{prof % put('Tailoring')}  {GREY}{P1}, {P2}|r")
    ours("a recipe and its star", f"{ITEM} x4{prof % 'Tailoring'}  {GOLD}{E['starred']}|r",
         f"{ITEM_UK} x4{prof % put('Tailoring')}  {GOLD}{want('starred')}|r")
    same("a phrase where players go", f"{ITEM} x4{prof % 'Tailoring'}  {GREY}{P1} and wobbles|r")
    same("a recipe UALL Forever lacks and who knows it", f"{NO_ITEM} x4{prof % 'Tailoring'}  {GREY}{P1}|r")
    counts = put(E["bags"] % 13 + ", " + E["bank"] % 5)
    ours("a player's counts", f"|cff3fc7eb{P1}|r  {GREY}{E['bags'] % 13}, {E['bank'] % 5}|r", f"|cff3fc7eb{P1}|r  {GREY}{counts}|r")
    same("a player's counts with English", f"|cff3fc7eb{P1}|r  {GREY}{E['bags'] % 13}, 5 wobbly|r")
    got = put("MERCHANT'S FAVOR")
    check("missed: the favour heading", got == FAVOR.upper(), got)
    # the same rows in a tooltip (Tooltip.lua's cheap gate lets them through)
    tip("a starred recipe", f"  {STAR}{ITEM} {GREY}x1|r", f"  {STAR}{ITEM_UK} {GREY}x1|r")
    tip("a starred recipe UALL Forever lacks", f"  {STAR}{NO_ITEM} {GREY}x1|r", "")
    tip("a recipe and its count", f"  {ITEM} {GREY}x1|r", f"  {ITEM_UK} {GREY}x1|r")
    tip("<count> x <item>", f"  2 x {ITEM}", f"  2 x {ITEM_UK}")
    tip("the addon's name, a skill and a quest", BRAND + src_en, BRAND + src_uk)
    tip("a node's skills", "Herbalism:  " + NODE, put("Herbalism") + ":  " + NODE)
    tip("a creature, levels, zone", f"{NPC}, level 21-22 - {ZONE}: 0.31%", f"{NPC_UK}, {low}21-22 - {ZONE_UK}: 0.31%")
    tip("a creature UALL Forever lacks", f"{NO_NPC}, level 21-22 - {ZONE}: 0.31%", "")
    if not cut:
        times = [(name, C.slow(lua_str(text))) for name, text in SLOW]
        limit, ref = clock.bound(5)                 # 5 ms stretched by the load seen now (clock.py)
        for name, ms in times:
            check(f"missed: a 10 KB line of the {name} shape takes under 5 ms", ms < limit,
                  f"{ms:.1f} ms, {clock.note(limit, ref)}")
    return bool(c.H.mccut.wasCut) if cut else True


def run(check, F, src):
    steps(check, F, src)
    gc.collect()


def mutants(check, F, src):
    for name, (f, old, new, step) in MUTANTS.items():
        n = read_text(os.path.join(session.REPO, F.MODULE, *f.split("/"))).count(old)
        if n != 1:
            check(f"mutant {name}: its fix is in {f} once", False, f"found {n} times")
            continue
        got = []
        was = steps(lambda what, ok, detail="": got.append((what, ok)), F, src, (f, old, new))
        gc.collect()
        bad = [w for w, ok in got if not ok]
        check(f"mutant {name}: {f} fix cut, '{step}' fails", was and any(step in w for w in bad), f"cut={was}; failed: {bad}")