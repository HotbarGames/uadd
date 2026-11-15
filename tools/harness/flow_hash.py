"""UADD/Hash.lua, texts by hash, in a game with only UADD loaded (through its .toc).

The data is made by tools/hashtext.py from the English and Ukrainian below (test texts in the
forms the modules' addons use) and run as an addon file. Checks: exact hits and misses, every slot
kind, templates that start or end with a slot, two slots side by side or with a short text between,
backtracking, a wrong slot kind, a text that only shares a template's start, the best of several
templates (and the next one when the best is refused), a template inside a template, secret
strings, and speed: 10,000 lookups on mixed texts under SPEED_BUDGET_MS, misses making no garbage.
"""
import collections
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))      # tools/, for hashtext

import hashtext as HT  # noqa: E402
import session  # noqa: E402
from loader import Addon, Client, lua_str, read_text, txt  # noqa: E402

Check = collections.namedtuple("Check", "name ok detail")
SPEED_ROUNDS = 100                 # x 100 texts = 10,000 lookups
SPEED_BUDGET_MS = 250              # for all of them in the harness's plain Lua 5.1 (about 50 ms here)

EXACT = {"Buy All": "Купити все", "Cancel": "Скасувати", "Level": "Рівень",
         "Line one\nLine two": "Рядок один\nРядок два", "|cffffd100Gold|r": "|cffffd100Золото|r"}
# (English, Ukrainian, options for hashtext.template)
TEMPLATES = [
    ("Level %d of %d", "Рівень %d з %d", {}),
    ("Rested: %.1f%%", "Відпочинок: %.1f%%", {}),
    ("|cff%02x%02x%02xCompleted|r", "|cff%02x%02x%02xВиконано|r", {}),
    ("Level %d%s%.1f%%", "Рівень %d%s%.1f%%", {}),
    ("%s XP/hr", "%s досв./год", {}),
    ("Sold by %s", "Продає %s", {}),
    ("%1$s gets %2$d gold", "%2$d золота отримує %1$s", {}),
    ("Received data from |cffffd100##NAME##|r", "Отримано дані від |cffffd100##NAME##|r",
     {"one_line": ("NAME",)}),
    ("Completed ##TYPE## ##STEP## for ##NAME##.", "##NAME##: виконано ##STEP## (##TYPE##).", {}),
    ("Press [KEY:PC:SPACE] to continue", "Натисніть [KEY:PC:SPACE], щоб продовжити", {}),
    ("%s: %d items", "%s: %d предм.", {}),
    ("%s, %s", "%s і %s", {"min_lit": 2}),       # under MIN_LIT: only when asked
    ("%s quests", "%s завдань", {}),
    ("Daily %s quests", "Щоденних завдань: %s", {}),
    ("Leveling in: %s (%s)", "Рівень через: %s (%s)", {}),
    ("Hex %x end", "Шістн. %x кін.", {}),
]
# (text, Ukrainian wanted or None, what it shows)
CASES = [
    ("Buy All", "Купити все", "exact hit"),
    ("Buy all", None, "exact miss, same length"),
    ("Buy Alll", None, "exact miss, a length no text has"),
    ("Line one\nLine two", "Рядок один\nРядок два", "exact with a line break"),
    ("|cffffd100Gold|r", "|cffffd100Золото|r", "exact with a colour code"),
    ("Level 5 of 60", "Рівень 5 з 60", "d slots"),
    ("Level -1,234 of 60", "Рівень -1,234 з 60", "d slot: sign and thousands"),
    ("Level five of 60", None, "d slot refuses letters"),
    ("Level 5 of", None, "shares the start only"),
    ("Level up!", None, "shares a prefix only"),
    ("Rested: 12.5%", "Відпочинок: 12.5%", "f slot and %%"),
    ("Rested: 12.5x%", None, "f slot refuses a letter"),
    ("|cffa0ff10Completed|r", "|cffa0ff10Виконано|r", "x2 slots side by side"),
    ("|cffa0ff1Completed|r", None, "x2 slots: one digit short"),
    ("|cffa0fg10Completed|r", None, "x2 slot refuses a non-hex letter"),
    ("Level 12 + 45.5%", "Рівень 12 + 45.5%", "d, s and f side by side"),
    ("1,234 XP/hr", "1,234 досв./год", "starts with a slot"),
    ("Sold by Grimtotem Trader", "Продає Grimtotem Trader", "ends with a slot"),
    ("Arthas gets 50 gold", "50 золота отримує Arthas", "%1$s %2$d: Ukrainian in another order"),
    ("Received data from |cffffd100Thrall|r", "Отримано дані від |cffffd100Thrall|r", "a ##NAME## place"),
    ("Received data from |cffffd100Thr\nall|r", None, "a one-line place refuses a line break"),
    ("Completed quest Kill Ten for Onyxia.", "Onyxia: виконано Kill Ten (quest).", "places in another order"),
    ("Press |TInterface\\Keys\\Space:16|t to continue", "Натисніть |TInterface\\Keys\\Space:16|t, щоб продовжити",
     "a [KEY:..] picture"),
    ("Press SPACE to continue", None, "a key slot refuses plain text"),
    ("Note: see: 5 items", "Note: see: 5 предм.", "backtracking: the first ': ' is not the one"),
    ("A, B", "A і B", "two slots with a short text between"),
    ("Daily 5 quests", "Щоденних завдань: 5", "the longer template wins"),
    ("Weekly 5 quests", "Weekly 5 завдань", "the shorter one where only it fits"),
    ("Hex 1aF end", "Шістн. 1aF кін.", "x slot"),
    ("", None, "the empty text"),
]


def data_text():
    temps = [HT.template(en, uk, **opt) for en, uk, opt in TEMPLATES]
    return HT.write_lua(EXACT, temps, "hashTest", ["Test data for flow_hash.py."])


def speed_data(rng):
    """400 exact texts and 200 templates, and 100 texts to look up: a third exact hits, a third
    template hits, a third misses (near misses of a template, and bare numbers)."""
    words = ["Auction", "Price", "Stack", "Seller", "Bid", "Quest", "Raid", "Level", "Gold", "Item"]
    exact = {"%s %s %d" % (rng.choice(words), rng.choice(words), i): "Текст %d" % i for i in range(400)}
    shapes = [(rng.choice(words), rng.choice(words)) for _ in range(200)]
    temps = [HT.template("%s %d: %%s for %%d (%s)" % (a, i, b), "Шаблон %d: %%s за %%d" % i)
             for i, (a, b) in enumerate(shapes)]
    ex, texts = list(exact), []
    for i in range(34):
        n = rng.randrange(200)
        a, b = shapes[n]
        texts.append(ex[rng.randrange(len(ex))])
        texts.append("%s %d: Thing %d for %d (%s)" % (a, n, i, 10 * i, b))     # a template hit
        texts.append("%s %d: Thing %d for many (%s)" % (a, n, i, b))           # a near miss
    texts = texts[:-3] + [str(rng.randrange(10 ** 6))]
    return exact, temps, texts


def run(check, facts):
    c = Client([Addon("UADD", os.path.join(session.REPO, "UADD"), session.FLAVOR)])
    c.lua.execute(read_text(os.path.join(HERE, "flow_hash.lua")))
    c.start()
    M = c.H.hash
    idx = M.load(lua_str(data_text()), "hashTest")
    n_exact, n_temp = idx.Count(idx)
    check("index holds every text", (n_exact, n_temp) == (len(EXACT), len(TEMPLATES)), f"{n_exact} {n_temp}")
    for text, want, what in CASES:
        got = M.text(idx, lua_str(text))
        got = txt(got) if got is not None else None
        check(f"{what}: {text!r}", got == want, f"got {got!r}, want {want!r}")
    _slots(check, M, idx)
    _secret(check, M, idx)
    _speed(check, facts, c, M)
    errs = c.errors()
    check("no Lua errors", not errs, "; ".join(f"{w}: {m[:160]}" for w, m, _ in errs[:3]))


def _slots(check, M, idx):
    id_, caps, rank = M.match(idx, lua_str("Level 12 + 45.5%"))
    check("Match gives the captures", txt(caps) == "12| + |45.5", repr(caps))
    check("Match's id is the English's key", id_ == HT.key("Level %d%s%.1f%%"), repr(id_))
    got = M.text(idx, lua_str("Leveling in: 1,234 XP/hr (Daily 5 quests)"), True)
    check("a template inside a template", txt(got) == "Рівень через: 1,234 досв./год (Щоденних завдань: 5)",
          repr(txt(got)))
    best = M.match(idx, lua_str("Daily 5 quests"))
    nxt = M.match(idx, lua_str("Daily 5 quests"), best[2])
    check("after the best comes the next", nxt[0] == HT.key("%s quests") and txt(nxt[1]) == "Daily 5", repr(nxt))
    got = M.text(idx, lua_str("Daily 5 quests"), True, True)
    check("a refused Fill: nothing else fits", got is None, repr(got))


def _secret(check, M, idx):
    for s in ("Buy All", "Level 5 of 60", "1,234 XP/hr"):
        ok, none, detail = M.secret(idx, lua_str(s))
        check(f"secret {s!r}: nil everywhere, no error", ok and none, txt(detail))


def _speed(check, facts, c, M):
    rng = random.Random(7)
    exact, temps, texts = speed_data(rng)
    idx = M.load(lua_str(HT.write_lua(exact, temps, "speed")), "speed")
    ms, hits, kb, misses = M.speed(idx, c.lua.table_from([lua_str(t) for t in texts]), SPEED_ROUNDS)
    facts["hash_speed_ms_10k"] = round(ms, 1)
    facts["hash_speed_hits"] = hits
    check(f"10,000 lookups under {SPEED_BUDGET_MS} ms", ms < SPEED_BUDGET_MS, f"{ms:.1f} ms")
    check("the mix has hits and misses", 0 < hits < SPEED_ROUNDS * len(texts), f"{hits} hits")
    per = kb * 1024 / max(1, misses * SPEED_ROUNDS)     # a table or string per miss would be 16+ bytes
    check("misses make no garbage", per < 1, f"{kb:.2f} KB over {misses * SPEED_ROUNDS} misses")


def run_checks():
    """Every check of this file. Returns (checks, facts)."""
    checks, facts = [], {}

    def check(name, ok, detail=""):
        checks.append(Check("hash: " + name, bool(ok), str(detail)))
    run(check, facts)
    return checks, facts


if __name__ == "__main__":       # alone: python3 tools/harness/flow_hash.py
    cs, fs = run_checks()
    for x in cs:
        print(("ok    " if x.ok else "FAIL  ") + x.name + (f"  [{x.detail}]" if x.detail else ""))
    print(fs)
    print(f"{sum(x.ok for x in cs)}/{len(cs)} passed")
    sys.exit(0 if all(x.ok for x in cs) else 1)
