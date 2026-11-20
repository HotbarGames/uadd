"""ClassicUA as the first source of game names (UADD/uall_cua.lua, docs/LESSONS2.md lesson 25).

The harness loads the installed ClassicUA (its Camelot TOC, as on Forever), UALL Forever (UALLF) and UADD. Some of
ClassicUA's files fail here, so its own zone-text hooks are never placed. The SetText hook on ZoneTextString and
SubZoneTextString is therefore a HARNESS STAND-IN, loaded under ClassicUA's chunk name as the client would name it.
It does what ClassicUA's Forever zone hook does, through ClassicUA's real options (can_lookup / can_translate) and
its real glossary (entries.get_glossary_text). The real hook on the real widgets is checked only in the game.

Cases: both addons, ClassicUA only, UALLF only, neither; ClassicUA's options off one by one; a stand-in that
throws; another addon's hook that writes Cyrillic; text that must not be asked; the game's zone text never
written; before login and in combat; a bounded cache; the public API (Providers, HasProvider, ProviderSig,
RouteOff). Skipped with a note when ClassicUA or UALLF is not installed.

python3 tools/harness/flow_classicua.py
"""
import collections
import os
import sys

import session
from loader import Addon, Client, lua_str, txt

STAND_IN = "harness stand-in for ClassicUA's zone hook (real options and glossary)"
# (route, English): game names; the glossary decides which ones ClassicUA has
SAMPLES = (("Zone", "Elwynn Forest"), ("Zone", "Durotar"), ("Npc", "Thrall"), ("Item", "Linen Cloth"),
           ("Spell", "Fireball"), ("Text", "Kobold Camp Cleanup"), ("Zone", "Zz Nowhere Qq"))
REFUSED = ("[Durotar]", "Durotar (1-10)", "Durotar|cffffff00 (1-10)|r", "Elwynn\nForest", " Durotar", "Durotar ",
           "", "x" * 121)

HOOK = r'''
local ns = HARNESS.ns.ClassicUA
local options, entries = ns.use("options"), ns.use("entries")
STAND = { calls = 0, throw = ... }
function STAND.gloss(en) return entries.get_glossary_text(en, en, "zone") end
local allowed = true
local function zone(text)
    if not options.can_lookup("translate_zone") then return text end
    local uk = entries.get_glossary_text(text, text, "zone")
    return options.can_translate("translate_zone") and uk or text
end
local function hook(self, text)
    STAND.calls = STAND.calls + 1
    if STAND.throw then error("stand-in hook broke") end
    if not allowed or type(text) ~= "string" then return end
    local name, rest = text:match("^(.-)(|c.*)$")
    name = name or text
    local uk = zone(name)
    if uk ~= name then allowed = false self:SetText(uk .. (rest or "")) allowed = true end
end
for _, n in ipairs({ "ZoneTextString", "SubZoneTextString" }) do hooksecurefunc(_G[n], "SetText", hook) end
'''
OTHER = r'''
local busy = false
hooksecurefunc(ZoneTextString, "SetText", function(self, t)
    if busy or type(t) ~= "string" or t:find("[\208-\210]") then return end
    busy = true self:SetText("Інша назва") busy = false
end)
'''
SPY = r'''
SPY = { n = 0 }
hooksecurefunc(ZoneTextString, "SetText", function(self) if self == ZoneTextString then SPY.n = SPY.n + 1 end end)
'''


def missing():
    d = session.addons_dir()
    return [a for a in ("ClassicUA", "UALLF") if not d or not os.path.isdir(os.path.join(d, a))]


def run_as(c, addon, code, *args):
    """Runs code under the chunk name the client gives an addon's file."""
    f = c.lua.eval('function(code, name, ...) local f = assert(loadstring(code, name)) return f(...) end')
    return f(lua_str(code), lua_str(f"@AddOns/{addon}/HarnessStandIn.lua"), *args)


def game(cua=True, uallf=True, throw=False, pump=2.0, hook=True):
    d = session.addons_dir()
    ads = ([Addon("ClassicUA", os.path.join(d, "ClassicUA"), "Camelot")] if cua else []) + \
          ([Addon("UALLF", os.path.join(d, "UALLF"), session.FLAVOR)] if uallf else []) + \
          [Addon("UADD", os.path.join(session.REPO, "UADD"), session.FLAVOR)]
    c = Client(ads, None, "enUS")
    c.start()
    if cua and hook:
        run_as(c, "ClassicUA", HOOK, throw)
    c.early = state(c)
    c.early_ask = ask(c, "Zone", "Durotar") if cua else None
    if pump:
        wait(c, pump)
    return c


def wait(c, seconds):
    c.lua.execute(f"HARNESS.pump({int(seconds / 0.05 + 0.5)}, function() return false end, 0.05)")


def ask(c, route, en):
    """(Ukrainian or None, wait) from UADD.UALL.<route>."""
    f = c.lua.eval('function(r, en) local ua, w = UADD.UALL[r](en) return ua, w and true or false end')
    ua, w = f(lua_str(route), lua_str(en))
    return (txt(ua) if ua is not None else None), bool(w)


def state(c):
    r, b, ch = c.lua.globals().UADD.UALL.cua.State()
    return {"ready": bool(r), "broken": bool(b), "chosen": bool(ch)}


def providers(c):
    return [txt(x) for x in c.lua.globals().UADD.UALL.Providers().values()]


def calls(c):
    return int(c.lua.globals().STAND.calls)


def gloss(c, en):
    g = c.lua.globals().STAND.gloss(lua_str(en))
    return txt(g) if g is not None else None


def cap(en, ua):
    return ua[:1].upper() + ua[1:] if ua and en[:1].isupper() else ua


def uadd_errors(c):
    return [str(e[1])[:160] for e in c.errors() if "UADD" in str(e[1])]


def run(check, facts):
    ref = game(cua=False)                                     # UALLF alone: its answers, as before ClassicUA
    uallf = {en: ask(ref, r, en)[0] for r, en in SAMPLES}
    check("UALLF only: Providers is UALLF, no ClassicUA part in the signatures",
          providers(ref) == ["UALLF"] and txt(ref.lua.globals().UADD.UALL.ProviderSig()) == "", providers(ref))
    check("UALLF only: answers as before", uallf["Durotar"] and uallf["Thrall"], uallf)
    del ref

    c = game(cua=False, uallf=False)
    U = c.lua.globals().UADD.UALL
    check("neither: no provider, no name (as before)",
          providers(c) == [] and not U.IsAvailable() and ask(c, "Zone", "Durotar")[0] is None, providers(c))
    del c, U

    c = game()                                                # both
    U = c.lua.globals().UADD.UALL
    check("both: before the zone hooks are on, a name waits", not c.early["ready"] and c.early_ask == (None, True),
          f"{c.early} {c.early_ask}")
    run_as(c, "Spy", SPY)
    c.lua.globals().ZoneTextString.SetText(c.lua.globals().ZoneTextString, lua_str("Spy Zone"))
    c.lua.execute("SPY.n = 0")
    got, want = {}, {}
    for r, en in SAMPLES:
        g = gloss(c, en)
        want[en] = cap(en, g) if g and g != en else uallf[en]
        got[en] = ask(c, r, en)[0]
    facts["both"] = got
    check("both: Providers is ClassicUA then UALLF",
          providers(c) == ["ClassicUA", "UALLF"] and U.HasProvider(lua_str("ClassicUA")), providers(c))
    check("both: ClassicUA's word first, UALLF's where ClassicUA has none", got == want, f"got {got} want {want}")
    check("both: some names come from ClassicUA", any(gloss(c, en) not in (None, en) for _, en in SAMPLES))
    check("both: a capital first letter, as the English has", all(not v or v[:1] == v[:1].upper() for v in got.values()
                                                                  if v), got)
    sig = txt(U.ProviderSig())
    check("both: ProviderSig names ClassicUA and its version", sig.startswith("ClassicUA=") and sig != "ClassicUA=nil",
          sig)
    zs = c.lua.globals().ZoneTextString
    check("the game's zone text is never written by a lookup",
          int(c.lua.globals().SPY.n) == 0 and txt(zs.GetText(zs)) == "Spy Zone",
          f"{int(c.lua.globals().SPY.n)} writes, now {txt(zs.GetText(zs))!r}")
    o = c.lua.globals().ClassicUA_Options
    differs = [en for _, en in SAMPLES if got[en] != uallf[en]]     # ClassicUA and UALLF say it differently
    for key, value in (("disable_all_translation", True), ("translate_zone", False), ("dev_mode", True)):
        old = o[key]
        o[key] = value
        seen = {en: ask(c, r, en)[0] for r, en in SAMPLES if en in differs}
        ok = providers(c) == ["UALLF"] and not U.cua.Active() and seen == {en: uallf[en] for en in differs}
        o[key] = old
        check(f"ClassicUA option {key}={value}: not asked, UALLF answers", ok and differs, f"{providers(c)} {seen}")
    c.lua.execute('UALLFSettingsDB = UALLFSettingsDB or {} UALLFSettingsDB["world.zones"] = false')
    check("UALLF zones off, ClassicUA on: the route is on; ClassicUA's miss is no name, not a wait",
          not U.RouteOff(lua_str("zones")) and ask(c, "Zone", "Zz Elsewhere Qq") == (None, False))
    o["disable_all_translation"] = True
    check("UALLF zones off, ClassicUA off: the route is off", bool(U.RouteOff(lua_str("zones"))))
    o["disable_all_translation"] = False
    c.lua.execute('UALLFSettingsDB["world.zones"] = nil')
    c.lua.execute("ClassicUA_Options = 'broken'")
    check("ClassicUA_Options not a table: not active", providers(c) == ["UALLF"], providers(c))
    c.lua.globals().ClassicUA_Options = o
    check("both: no UADD error", not uadd_errors(c), uadd_errors(c)[:3])
    del c, U, o, zs

    c = game(uallf=False)                                     # ClassicUA alone, with another addon's hook
    run_as(c, "OtherUA", OTHER)
    U = c.lua.globals().UADD.UALL
    check("ClassicUA only: Providers is ClassicUA", providers(c) == ["ClassicUA"] and U.IsAvailable(), providers(c))
    g = gloss(c, "Durotar")
    check("ClassicUA only: its word", ask(c, "Zone", "Durotar")[0] == cap("Durotar", g), g)
    check("another addon's Cyrillic is not taken as ClassicUA's", ask(c, "Zone", "Zz Nowhere Qq") == (None, False))
    n = calls(c)                                              # no UALLF here, so every hook call is UADD's
    refused = [ask(c, "Zone", en) for en in REFUSED]
    check("refused text is never asked from ClassicUA",
          calls(c) == n and all(U.cua.Fit(lua_str(en)) is None for en in REFUSED)
          and all(r == (None, False) for r in refused), f"{calls(c) - n} calls {refused}")
    n = calls(c)
    ask(c, "Zone", "Durotar")
    check("a cached name asks nothing again", calls(c) == n)
    c.H.combat = True
    in_combat = ask(c, "Zone", "Westfall")
    c.H.combat = False
    check("in combat a new name waits, after combat it is asked",
          in_combat == (None, True) and ask(c, "Zone", "Westfall")[0], in_combat)
    c.lua.execute('for i = 1, 4100 do UADD.UALL.Zone("Zz Place " .. i) end')
    size = int(U.cua.CacheSize())
    check("the cache stays bounded (4000)", 0 < size <= 4000, size)
    check("ClassicUA only: no UADD error", not uadd_errors(c), uadd_errors(c)[:3])
    del c, U

    c = game(uallf=False, hook=False)                         # ClassicUA's hook comes on 4 s late
    first = ask(c, "Zone", "Durotar")
    run_as(c, "ClassicUA", HOOK, False)
    wait(c, 4)
    g = gloss(c, "Durotar")
    late = ask(c, "Zone", "Durotar")
    check("a ClassicUA hook that comes on late: a first miss is not kept, a later try finds it",
          first == (None, False) and late[0] == cap("Durotar", g) and not state(c)["broken"], f"{first} {late}")
    del c

    c = game(throw=True)                                      # a ClassicUA hook that throws
    before = len(c.errors())
    got = {en: ask(c, r, en)[0] for r, en in SAMPLES}
    for _ in range(2):                                        # the tries left, TRY_GAP (3 s) apart
        wait(c, 4)
        got = {en: ask(c, r, en)[0] for r, en in SAMPLES}
    st, new = state(c), [str(e[1]) for e in c.errors()[before:]]
    check("a throwing ClassicUA hook: UADD stops asking it after 3 tries, UALLF answers each time",
          st["broken"] and providers(c) == ["UALLF"] and got == uallf and len(new) <= 3 * 6, f"{st} {got} {len(new)}")
    check("a throwing ClassicUA hook: the errors are its own, none is UADD's",
          new and all("stand-in hook broke" in e for e in new) and not uadd_errors(c), f"{len(new)} {new[:2]}")
    facts["hook"] = STAND_IN


Check = collections.namedtuple("Check", "name ok detail")


def run_checks():
    """Every check of this file. Returns (checks, facts)."""
    checks, facts = [], {}

    def check(name, ok, detail=""):
        checks.append(Check("cua: " + name, bool(ok), str(detail)))
    gone = missing()
    if gone:
        facts["skipped"] = "not installed: " + ", ".join(gone)
        return checks, facts
    check("report: the ClassicUA zone hook here is a " + STAND_IN, True)
    run(check, facts)
    return checks, facts


if __name__ == "__main__":       # alone: python3 tools/harness/flow_classicua.py
    cs, fs = run_checks()
    for x in cs:
        print(("ok    " if x.ok else "FAIL  ") + x.name + (f"  [{x.detail}]" if x.detail else ""))
    for k, v in fs.items():
        print(f"{k}: {v}")
    print(f"{sum(x.ok for x in cs)}/{len(cs)} passed")
    sys.exit(0 if all(x.ok for x in cs) else 1)
