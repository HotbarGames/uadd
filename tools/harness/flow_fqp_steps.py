"""The steps of flow_fqp.py, each on a running game (c, M = flow_fqp._game). The English is the installed Forever
Quest Pins' own (its L keys, read by drift_fqp.extract, found here by hash); the Ukrainian is the module's data.
Each step returns whether its first sub-check passed (the one its mutant must break); STEPS names them."""
import os
import re
import sys
from pathlib import Path

import halves
import session
from loader import lua_str, txt

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import drift_fqp  # noqa: E402
import halves_cover  # noqa: E402
import hashtext  # noqa: E402

CRUMB, GONE = "59:c29df838", "13:8d5be727"          # the breadcrumb sentence; the abandoned-quest chat line
GOLD, DIM, END = "|cffffd100", "|cff9d9d9d", "|r"
TAG = "Forever Quest Pins:|r "
KNOWN = {"Quix Hunt": "Полювання Квікса", "Zorp Trail": "Стежка Зорпа", "Blatter Vale": "Долина Блаттер"}
STRANGER = "Wobble Moor"                             # a name UADD.UALL does not know
STEPS = {
    "login": "1 at login: World Map menu, setup window, settings page, tips and What's New ours",
    "spoiled": "1 spoiled words not used (a % spec or an escape the English lacks)",
    "menu": "2 World Map menu ours, off gives its English, on gives ours back",
    "hold": "3 hold key: menu, setup window, breadcrumb dialog, tips, What's New and L English, back on release",
    "hold canvas": "3 hold canvas (level range label): English while held, ours on release",
    "names": "4 names: breadcrumb and abandoned lines ours only when every name is known (UADD.UALL), "
             "else whole English; root stubs change nothing; no Lc.NAMES key in L; a What's New line that "
             "quotes quest names stays English, the others ours",
    "untitled": "4 untitled quest (its L[\"Quest \"] is our word): a breadcrumb or abandoned line that is not ours "
                "is whole English (\"Quest 5\"), off too; ours when every name is known (lesson 27)",
    "off": "5 off: menu, setup window, breadcrumb dialog, tips, What's New and L English again",
    "off canvas": "5 off canvas (level range label): English again",
    "on": "5 on again: all ours, status line says so",
    "tree": "6 settings tree: the names of its 5 pages under the main one ours, English while held and off, "
            "ours again",
    "labels": "6 tracker sort and filter names (its settings drop-downs, its tracker menu) ours, English while "
              "held and off, ours again",
    "tracker menu": "6 tracker right-click menu ours, English while held and off, ours again",
    "faults": "5 five errors turn it off, English back",
    "tips": "5 tips back after 5 errors",
}


def cyr(s): return re.search("[Ѐ-ӿ]", s or "") is not None  # noqa: E704
def bare(s): return re.sub(r"\|c[0-9a-fA-F]{8}|\|r", "", s or "")  # noqa: E704
def latin(s): return re.search("[A-Za-z]", bare(s)) is not None  # noqa: E704
def gold(s): return GOLD + s + END  # noqa: E704


def keys():
    """{hash: English} for every L key of the installed Forever Quest Pins that has a slot."""
    rows = drift_fqp.extract(Path(session.addons_dir()) / "ForeverQuestPins")
    return {hashtext.key(r[2]): r[2] for r in rows if "%" in r[2]}


def fill(en, *vals):
    out = en
    for v in vals:
        out = out.replace("%s", v.replace("%", "%%"), 1)
    return out.replace("%%", "%")


def body_en(K, t1, t2, zone=None):
    return fill(K[CRUMB], gold(t1), gold(t2) + (" " + DIM + "(" + zone + ")" + END if zone else ""))


def gone_en(K, title): return "|cff33ff99" + TAG + fill(K[GONE], title)  # noqa: E704


def counts(M):
    """Cyrillic counts of each place: menu, setup, crumb, canvas, tips, news, L; and the totals they reach."""
    _, n, menu = M.menu()
    tshown, tips = M.tips()
    lines, news, _ = M.news()
    return {"menu": menu, "setup": M.scan("setup")[1], "crumb": M.scan("crumb")[1], "canvas": M.scan("canvas")[1],
            "tips": tips, "news": news, "left": M.left()}, {"menu": n, "tips": tshown, "news": lines}


def login(check, M):
    got, full = counts(M)
    miss = {w: txt(M.scan(w)[2]) for w in ("setup", "canvas")}
    news_miss = M.news()[2]                  # What's New lines we have a word for that show English
    ok = (M.there("canvas") and full["menu"] > 0 and got["menu"] == full["menu"] and got["setup"] > 0
          and got["canvas"] > 0 and not any(miss.values()) and got["tips"] == full["tips"] > 0
          and got["news"] > 0 and news_miss == 0)
    check(STEPS["login"], ok, (got, full, {k: v[:120] for k, v in miss.items() if v}))
    return ok


def spoiled(check, M):
    a, b = M.badKeys()
    ok = bool(a and b) and all(M.L(k) in (None, k) and M.word(k) is None for k in (a, b))
    check(STEPS["spoiled"], ok, (txt(a), txt(b)))
    return ok


def menu(check, M):
    _, n, on1 = M.menu()
    M.uadd(lua_str("foreverquestpins off"))
    _, _, off = M.menu()
    left = M.left()
    M.uadd(lua_str("foreverquestpins on"))
    _, _, on2 = M.menu()
    ok = n > 0 and on1 == n and off == 0 and left == 0 and on2 == n
    check(STEPS["menu"], ok, f"{n} items: on {on1}, off {off} (L left {left}), on again {on2}")
    return ok


def hold(check, M):
    before, full = counts(M)
    label0 = txt(M.label())
    M.hold(True)
    M.wait(1)
    held, label = counts(M), txt(M.label())
    M.hold(False)
    M.wait(1)
    after, label2 = counts(M)[0], txt(M.label())
    held = held[0]
    ok = (M.shown() is False and all(held[k] == 0 for k in ("menu", "setup", "crumb", "tips", "news", "left"))
          and all(after[k] == before[k] for k in ("menu", "setup", "crumb", "tips", "news", "left")))
    check(STEPS["hold"], ok, (before, held, after))
    okc = bool(label0) and cyr(label0) and not cyr(label) and cyr(label2) and held["canvas"] == 0 \
        and after["canvas"] == before["canvas"]
    check(STEPS["hold canvas"], okc, (label0, label, label2, before["canvas"], held["canvas"], after["canvas"]))
    return {"hold": ok, "hold canvas": okc}


def names(check, c, M, K):
    M.known(True)
    full, half, nozone = body_en(K, "Quix Hunt", "Zorp Trail", "Blatter Vale"), \
        body_en(K, "Quix Hunt", "Zorp Trail", STRANGER), body_en(K, "Quix Hunt", "Zorp Trail")
    got = {}
    for name, en in (("full", full), ("stranger", half), ("no zone", nozone)):
        M.setBody(lua_str(en))
        got[name] = txt(M.body())
    for name, title in (("gone", "Quix Hunt"), ("gone stranger", STRANGER)):
        M.say(lua_str(gone_en(K, title)))
        got[name] = c.chat()[-1]
    M.rootOnly()
    M.setBody(lua_str(full))
    got["root"] = txt(M.body())
    M.say(lua_str(gone_en(K, "Quix Hunt")))
    got["root gone"] = c.chat()[-1]
    M.known(True)
    # What's New: a line that quotes quest names (game names, lesson 9) stays English; the others are ours.
    news = txt(M.newsLines()).split("\n")
    news_ok = bool(news) and all(cyr(t) != ('"' in t) for t in news)
    got["news"] = " / ".join(t[:40] for t in news)
    ours = [got[k] for k in ("full", "no zone")] + [got["gone"].replace(TAG, "")]
    ok = (all(cyr(t) and not latin(t) for t in ours) and all(v in got["full"] for v in KNOWN.values())
          and got["stranger"] == half and got["gone stranger"] == gone_en(K, STRANGER)
          and got["root"] == full and got["root gone"] == gone_en(K, "Quix Hunt") and M.namesWritten() == 0
          and news_ok)
    check(STEPS["names"], ok, {k: v[:90] for k, v in got.items()} | {"names in L": M.namesWritten()})
    return ok


def untitled(check, c, M, K):
    """A quest with no title: Forever Quest Pins puts our L["Quest "] word and its id into the line (lesson 27)."""
    M.known(True)
    q, en = txt(M.word(lua_str("Quest "))) + "5", "Quest 5"
    got = {}
    M.setBody(lua_str(body_en(K, q, STRANGER)))
    got["stranger"] = txt(M.body())
    M.setBody(lua_str(body_en(K, q, "Zorp Trail", "Blatter Vale")))
    got["ours"] = txt(M.body())
    M.uadd(lua_str("foreverquestpins off"))
    got["off"] = txt(M.body())
    M.uadd(lua_str("foreverquestpins on"))
    got["on"] = txt(M.body())
    old = M.setUk(lua_str(K[GONE]), None)    # no word for the abandoned line: it stays English
    M.say(lua_str(gone_en(K, q)))
    got["gone"] = c.chat()[-1]
    M.setUk(lua_str(K[GONE]), old)
    M.say(lua_str(gone_en(K, q)))
    got["gone ours"] = c.chat()[-1].replace(TAG, "")
    ok = (got["stranger"] == body_en(K, en, STRANGER) and got["off"] == body_en(K, en, "Zorp Trail", "Blatter Vale")
          and got["gone"] == gone_en(K, en))
    oks = all(cyr(got[k]) and not latin(got[k]) and q in got[k] for k in ("ours", "on", "gone ours"))
    check(STEPS["untitled"], ok and oks, {k: v[:90] for k, v in got.items()})
    return ok


def off(check, c, M, K):
    M.known(True)
    en = body_en(K, "Quix Hunt", "Zorp Trail", "Blatter Vale")
    M.setBody(lua_str(en))
    on1 = txt(M.body())
    before, full = counts(M)
    M.uadd(lua_str("foreverquestpins off"))
    got, label, body = counts(M)[0], txt(M.label()), txt(M.body())
    ok = cyr(on1) and body == en and all(got[k] == 0 for k in ("menu", "setup", "crumb", "tips", "news", "left"))
    check(STEPS["off"], ok, (got, body[:80]))
    okc = got["canvas"] == 0 and bool(label) and not cyr(label)
    check(STEPS["off canvas"], okc, (got["canvas"], label))
    M.uadd(lua_str("foreverquestpins on"))
    again = counts(M)[0]
    M.uadd(lua_str("foreverquestpins"))
    said = "\n".join(c.chat()[-4:])
    oks = all(again[k] == before[k] for k in before) and cyr(txt(M.label())) and \
        "увімкнено: Forever Quest Pins українською" in said
    check(STEPS["on"], oks, (before, again, said[-160:]))
    return {"off": ok, "off canvas": okc}


def pages(check, M):
    """Its settings pages under the main one (Forever Quest Pins 1.1): their names in the tree, and the tracker's
    sort and filter names, read from tables its Config.lua fills at load; on, held, released, off, on again."""
    def look():
        names, n = M.catNames()
        labels, nl, lc = M.trackerLabels()
        menu, nm, mc = M.trackerMenu()
        return {"tree": (n, txt(names)[:120]), "labels": (lc, nl, txt(labels)[:120]),
                "tracker menu": (mc, nm, txt(menu)[:120])}
    count, built = M.pages()
    got = {"on": look()}
    M.hold(True)
    M.wait(1)
    got["held"] = look()
    M.hold(False)
    M.wait(1)
    got["released"] = look()
    M.uadd(lua_str("foreverquestpins off"))
    got["off"] = look()
    M.uadd(lua_str("foreverquestpins on"))
    got["on again"] = look()
    full = {"tree": count, "labels": got["on"]["labels"][1], "tracker menu": got["on"]["tracker menu"][1]}
    out = {}
    for step in ("tree", "labels", "tracker menu"):
        ok = (full[step] > 0 and all(got[w][step][0] == full[step] for w in ("on", "released", "on again"))
              and all(got[w][step][0] == 0 for w in ("held", "off")))
        if step == "tree":
            ok = ok and count == built == 5
        check(STEPS[step], ok, {w: got[w][step] for w in got} | {"pages": (count, built)})
        out[step] = ok
    return out


def faults(check, c, M):
    M.wait(4)
    M.menuThrow(True)
    for _ in range(5):
        M.menu()
    M.wait(0.3)
    M.menuThrow(False)
    got = counts(M)[0]
    said = "\n".join(c.chat()[-8:])
    ok = not M.on() and "вимкнено до кінця сесії" in said and got["menu"] == 0 and got["left"] == 0 \
        and got["news"] == 0 and got["setup"] == 0 and got["canvas"] == 0
    check(STEPS["faults"], ok, (M.on(), got, said[-200:]))
    shown, tips = M.tips()
    okt = shown > 0 and tips == 0
    check(STEPS["tips"], okt, f"{tips} of {shown} tooltips still Cyrillic")
    return {"faults": ok, "tips": okt}


def templates(M, K):
    """The halves check's templates: each text as Forever Quest Pins builds it (M.half reads "path")."""
    g = {1: "Quix Hunt", 2: "Zorp Trail", 3: "Blatter Vale"}
    crumb = K[CRUMB].replace("%s", gold("%s"))
    a, _, b = crumb.rpartition(gold("%s"))
    zoned = a + gold("%s") + " " + DIM + "(%s)" + END + b
    tps = [halves.tpl("crumb", crumb, good=g, path="crumb"), halves.tpl("crumb zone", zoned, good=g, path="crumb"),
           halves.tpl("chat gone", "|cff33ff99" + TAG + K[GONE], good=g, path="chat")]
    head = M.head()
    if head:
        tps.append(halves.tpl("chat head", GOLD + TAG + txt(head), free={1: "Quix"}, path="chat"))
    tps += [halves.tpl(k, en, path=en) for k, en in sorted(K.items())
            if k not in (CRUMB, GONE) and "s" in halves_cover.kinds(en)]
    return tps
