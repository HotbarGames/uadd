"""The steps of flow_litemount.py, each on a running game (c, M = flow_litemount._game). The English is the installed
LiteMount's own (its Localization.lua, run by the stand-in); the Ukrainian is the module's data, plus TESTS for the
keys the data has no word for yet. Each step returns whether its first sub-check passed (the one its mutant must
break); STEPS names them."""
import os
import re
import sys

import halves
from loader import lua_str, txt

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import halves_cover  # noqa: E402

# Test words, only for keys the module's data has no word for (flow_litemount.lua M.test): so each step reaches
# its texts with the 3-key stub data too. With the real data its own words are checked.
TESTS = {
    "LM_NEW_GROUP": "Нова група", "LM_CREATE_PROFILE_GROUP": "Профіль", "LM_CREATE_GLOBAL_GROUP": "Спільна",
    "LM_RENAME_GROUP": "Перейменувати групу", "LM_DELETE_GROUP": "Видалити групу",
    "LM_NEW_PROFILE": "Новий профіль", "LM_RESET_PROFILE": "Скинути профіль",
    "LM_EQUIPMENT_SLOT": "Комірка спорядження", "LM_NOT_FORMAT": "Не %s", "LM_GROUP": "Група",
    "LM_MOUNTED": "Верхи", "LM_LIMIT_MOUNTS": "Обмежити", "LM_LIMITSET_DESCRIPTION": "Опис обмеження",
    "LM_CURRENT_PROFILE": "Поточний профіль", "LM_LIST_VIEW": "Список", "LM_MODEL_VIEW": "Моделі",
    "LM_MACRO_EXP": "Пояснення макросу", "LM_IMPORT_PROFILE": "Імпорт профілю", "Import": "Імпорт",
    "BINDING_1": "Клавіша LiteMount 1", "BINDING_2": "Клавіша LiteMount 2", "BINDING_3": "Клавіша LiteMount 3",
    "BINDING_4": "Клавіша LiteMount 4",
    "LM_HIDDEN": "Приховані", "LM_ZONEMATCH": "З поточної зони", "LM_PRIORITY": "Пріоритет",
    "LM_COPY_TARGETS_MOUNT": "Копіювати маунта цілі", "LM_MOUNTSPECIAL_TIMER": "Запускати %s у спокої",
    "LM_ERR_BAD_ACTION": "Хибна дія '%s'", "LM_ERR_BAD_RULE": "Хибне правило '%s': %s",
}
STEPS = {
    "login": "1 at login: panel texts, titles, settings categories, macro help, Import button, condition, action, "
             "sort key, filter and \"Not\" lines, L ours",
    "tabs": "1 Mounts tabs fitted again to our words",
    "spoiled": "1 spoiled words not used (a % spec or an escape the English lacks)",
    "popups": "2 its 7 dialog texts and 4 key binding names ours",
    "falling": "3 Falling dropdown: our word in its radio and on the dropdown (menuGenerator), English while held",
    "hold": "4 hold key: every text English while held, ours again on release",
    "changed": "5 off and the hold key never write English over a text LiteMount changed since (lesson 23)",
    "filter": "3 Mounts filter menu: our 4 words (menuGenerator), English while held and off, a group named like "
              "one stays as typed, its generator back when off",
    "whole": "3 Mounts filter menu whose generator throws part-way: that opening whole English, the next no error",
    "general": "3 General page: option names ours, English while held and off, ours again (lesson 15)",
    "default": "3 an option or tooltip line glued to a game global (DEFAULT, MOUNT, OPTIONS_MENU, KEY_BUTTON1, TOTAL+COLLECTED) is whole "
               "English while it is English, whole Ukrainian when it is Cyrillic, English while held and off (lesson 15)",
    "announce": "3 General page: \"Announce via\" (CHAT + our word) whole English while CHAT is English; the word alone ours",
    "uidebug": "3 the uidebug chat line (BUG_CATEGORY5 + our word) whole English while it is English; debug's ours",
    "rules": "3 rule errors whole Ukrainian, or whole English while held and off (compiled sets dropped)",
    "names": "6 the player's names (a group in its list, a typed profile name, a mount, a rule's argument button "
             "and the add box's Name, each named like its words) stay as typed (lesson 13)",
    "profile": "6 the Profiles panel's current profile name stays as typed (lesson 13)",
    "status": "7 status line says it is on",
    "off": "8 off: every text English, L clean; on again: ours",
    "focus": "9 the keyboard is free after login (lesson 16)",
    "faults": "10 five errors turn it off, English back",
    "ruRU": "a Russian client: nothing changed, status says it does not work",
    "noL": "no LiteMount.LM.L: nothing changed, status says it waits",
    "code": "the installed LiteMount builds its Falling dropdown, current profile label, filter menu, General page, "
            "rule errors, rule argument button and glued lines as the stand-in does",
}
# Known module bugs: the step passes while the bug is there and fails once it is fixed (then take the entry out).
KNOWN_BUGS = {}
# The installed code the stand-in copies (file, a short code line it must hold).
CODE = (("UI/Falling.lua", "slot = L.LM_EQUIPMENT_SLOT"),
        ("UI/Falling.lua", "rootDescription:CreateRadio(text, IsSelected, SetSelected)"),
        ("UI/Falling.lua", "self.Dropdown:SetupMenu(BindingGenerator)"),
        ("UI/Profiles.lua", "self.CurrentProfile:SetText(currentProfile)"),
        ("UI/Profiles.xml", 'parentKey="CurrentProfile"'),
        ("UI/MountsFilter.lua", "text = L.LM_HIDDEN"),
        ("UI/MountsFilter.lua", "text = L.LM_ZONEMATCH"),
        ("UI/MountsFilter.lua", "text = L.LM_GROUP"),
        ("UI/MountsFilter.lua", "local subMenu = rootDescription:CreateButton(info.text)"),
        ("UI/MountsFilter.lua", "rootDescription:CreateCheckbox(info.text, info.checked, set)"),
        ("UI/MountsFilter.lua", "self.FilterDropdown:SetupMenu(DropdownGenerate)"),
        ("UI/General.lua", "SettingsRegistrar:AddRegistrant(function () self:Register() end)"),
        ("UI/General.lua", "string.format(L.LM_MOUNTSPECIAL_TIMER, EMOTE171_CMD1),"),
        ("UI/General.lua", "            L.LM_COPY_TARGETS_MOUNT,"),
        ("RuleSet.lua", "LM.PrintError(L.LM_ERR_BAD_RULE, info.line, info.err)"),
        ("Options.lua", "self.cachedRuleSets['user'..n] = LM.RuleSet:Compile(self:GetRules(n))"),
        ("UI/RuleEdit.lua", "self.ArgDropDown:SetText(text)"))


def cyr(s): return re.search("[Ѐ-ӿ]", s or "") is not None  # noqa: E704
def tx(v): return txt(v) if v is not None else None  # noqa: E704


def cmp(M, want, only=None):
    ok, n, bad = M.compare(lua_str(want), only and lua_str(only))
    return bool(ok), int(n), tx(bad) or ""


def uadd(M, msg): M.uadd(lua_str(msg))  # noqa: E704
def press(M, on): (M.hold(on), M.wait(1))  # noqa: E704  (the hold key down or up, then a second)


def code(check, root, more=()):
    miss = []
    for f, line in CODE + tuple(more):
        p = os.path.join(root, f)
        body = open(p, encoding="utf-8", errors="replace").read() if os.path.isfile(p) else ""
        if line not in body:
            miss.append(f"{f}: {line}")
    check(STEPS["code"], not miss, "; ".join(miss))


def login(check, M):
    ok, n, bad = cmp(M, "uk")
    ok = ok and M.written() > 0
    check(STEPS["login"], ok, f"{n} texts, {M.written()} in L; {bad[:300]}")
    check(STEPS["tabs"], M.resized() > 0, M.resized())
    return ok


def spoiled(check, M):
    got = {k: tx(M.L(lua_str(k))) for k in ("LM_PROFILES", "LM_GROUPS")}
    ok = all(M.word(lua_str(k)) is None and v and not cyr(v) for k, v in got.items())
    check(STEPS["spoiled"], ok, got)
    return ok


def popups(check, M):
    a = cmp(M, "uk", "^dialog")
    b = cmp(M, "uk", "^key binding")
    ok = a[0] and b[0] and a[1] == 7 and b[1] == 4
    check(STEPS["popups"], ok, f"dialogs {a[1]} {a[2][:160]}; bindings {b[1]} {b[2][:160]}")
    return ok


def falling(check, M):
    w, en = tx(M.word(lua_str("LM_EQUIPMENT_SLOT"))), tx(M.en(lua_str("LM_EQUIPMENT_SLOT")))
    M.showAdd()
    r1, radios, gen = tx(M.radioText()), tx(M.radios()), tx(M.generator())
    press(M, True)
    r2 = tx(M.radioText())
    press(M, False)
    r3 = tx(M.radioText())
    M.hideAdd()
    ok = bool(w) and r1 == w and w in radios and en not in radios and gen == "function" and r2 == en and r3 == w
    check(STEPS["falling"], ok, (r1, radios, gen, r2, r3))
    return ok


def _ways(M, now):
    """now() at login, held, released, off, on again."""
    out = [now()]
    for on in (True, False):
        press(M, on)
        out.append(now())
    for msg in ("litemount off", "litemount on"):
        uadd(M, msg)
        out.append(now())
    return out


def filter_menu(check, M):
    hidden = tx(M.en(lua_str("LM_HIDDEN")))
    M.group(lua_str(hidden))                       # a group the player named like one of its words
    uk, en = tx(M.filterExpect(lua_str("uk"))), tx(M.filterExpect(lua_str("en")))
    theirs = []

    def now():
        top, sub = (tx(x) for x in M.filterOpen())
        theirs.append(bool(M.filterIsTheirs()))
        return top, sub
    got = _ways(M, now)
    tops, subs = [g[0] for g in got], [g[1] for g in got]
    ok = bool(uk) and uk != en and tops == [uk, en, uk, en, uk] and all(hidden in s.split(" | ") for s in subs)
    ok = ok and theirs[3] is True and theirs[4] is False
    check(STEPS["filter"], ok, {"want": (uk, en), "tops": tops, "subs": subs[0], "theirs": theirs})
    return ok


def general(check, M):
    uk, en = tx(M.generalExpect(lua_str("uk"))), tx(M.generalExpect(lua_str("en")))
    got = _ways(M, lambda: tx(M.generalNames()))
    ok = bool(uk) and uk != en and got == [uk, en, uk, en, uk]
    check(STEPS["general"], ok, {"want": (uk[:80] if uk else uk, en[:80]), "got": [g[:60] for g in got]})
    return ok


def rules(check, M):
    uk, en = tx(M.ruleExpect(lua_str("uk"))), tx(M.ruleExpect(lua_str("en")))
    got = _ways(M, lambda: tx(M.ruleError()))
    ok = bool(uk) and uk != en and got == [uk, en, uk, en, uk]
    check(STEPS["rules"], ok, {"want": (uk, en), "got": got})
    return ok


def hold(check, M):
    before = cmp(M, "uk")
    press(M, True)
    held, left, shown = cmp(M, "en"), M.left(), M.shown()
    press(M, False)
    after = cmp(M, "uk")
    ok = shown is True and before[0] and held[0] and left == 0 and after[0]
    check(STEPS["hold"], ok, f"before {before[1]} {before[2][:120]}; held {held[1]} {held[2][:200]} (L left {left}); "
                             f"after {after[1]} {after[2][:120]}")
    return ok


def changed(check, M):
    def now(): return [tx(x) for x in M.changedNow()]  # noqa: E704
    M.change(True)
    want = now()
    press(M, True)
    held = now()
    press(M, False)
    uadd(M, "litemount off")
    off = now()
    uadd(M, "litemount on")
    on = now()
    M.change(False)
    uadd(M, "litemount off")
    uadd(M, "litemount on")
    ok = held == want and off == want and on == want and not any(cyr(x) for x in want)
    check(STEPS["changed"], ok, {"set": want, "held": held, "off": off, "on": on})
    return ok


def names(check, M):
    # names a player may pick, each the English of a word the panels swap
    g, p, m, a, t = (tx(M.en(lua_str(k))) for k in ("LM_GROUPS", "LM_PROFILES", "LM_PRIORITY", "LM_PRIORITY",
                                                     "LM_CONDITIONS"))
    M.names(lua_str(g), lua_str(p), lua_str(m), lua_str(a), lua_str(t))
    M.profile(lua_str(p))
    panes = [lua_str(x) for x in ("groups", "mounts", "profiles", "edit", "add")]
    M.showAll(*panes)
    press(M, True)
    press(M, False)
    uadd(M, "litemount off")
    uadd(M, "litemount on")
    M.showAll(*panes)
    got = [tx(x) for x in M.namesNow()]
    ok = got == [g, p, m, a, t]
    check(STEPS["names"], ok, got)
    prof = tx(M.profileNow())
    bug = KNOWN_BUGS.get("profile")
    if bug:
        check(STEPS["profile"] + " (known bug)", prof != p,
              f"KNOWN BUG, {bug}: '{p}' shows '{prof}'" if prof != p else "fixed now: take it out of KNOWN_BUGS")
    else:
        check(STEPS["profile"], prof == p, prof)
    return ok


def status(check, c, M):
    uadd(M, "litemount")
    said = "\n".join(c.chat()[-4:])
    ok = "увімкнено: LiteMount українською" in said
    check(STEPS["status"], ok, said[-200:])
    return ok


def off(check, c, M):
    uadd(M, "litemount off")
    said = "\n".join(c.chat()[-3:])
    en, left = cmp(M, "en"), M.left()
    uadd(M, "litemount on")
    uk = cmp(M, "uk")
    ok = en[0] and left == 0 and "вимкнено. LiteMount знову англійською." in said
    check(STEPS["off"], ok and uk[0], f"off {en[1]} {en[2][:200]} (L left {left}); on {uk[1]} {uk[2][:120]}")
    return ok


def focus(check, M):
    f = M.focus()
    check(STEPS["focus"], f is None, "" if f is None else "a box holds the keyboard")
    return f is None


def faults(check, c, M):
    M.wait(4)
    M.throw(5)
    for _ in range(5):
        M.showAll(lua_str("groups"))
    M.wait(0.3)
    M.throw(0)
    en, left = cmp(M, "en"), M.left()
    said = "\n".join(c.chat()[-8:])
    ok = not M.on() and "вимкнено до кінця сесії" in said and en[0] and left == 0
    check(STEPS["faults"], ok, (M.on(), en[1], en[2][:200], left, said[-200:]))
    return ok


def templates(M):
    """The halves check's templates: each L key with a %s slot that has our word (M.half builds it as LiteMount does)."""
    tps = []
    for k in (tx(M.templateKeys()) or "").split("\n"):
        en = k and tx(M.en(lua_str(k)))
        kinds = halves_cover.kinds(en) if en else []
        if "s" not in kinds:
            continue
        free = {i: "Zorp" for i, kd in enumerate(kinds, 1) if kd == "s"} if M.isFree(lua_str(k)) else None
        good = {1: tx(M.word(lua_str("LM_MOUNTED")))} if k == "LM_NOT_FORMAT" else None
        tps.append(halves.tpl(k, en, free=free, good=good))
    return tps
