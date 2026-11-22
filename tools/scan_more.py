"""Finders for tools/scan_addon.py, part 2: game-name APIs, popups, menus, Settings registrations, locale texts
written into saved data, and locale words copied at load.

Each finder takes (lf, rel, ctx), like scan_text.
"""
import re

from scan_lua import NAME, STR
from scan_text import classify, locale_ref, show

# API name: (kind of game name, the namespaces it lives in; "" = a plain global).
GAME = {"GetSpellInfo": ("spell", ("", "C_Spell")), "GetSpellName": ("spell", ("C_Spell",)),
        "GetSpellLink": ("spell", ("", "C_Spell")), "GetSpellBookItemName": ("spell", ("",)),
        "GetMountInfoByID": ("mount", ("C_MountJournal",)), "GetDisplayedMountInfo": ("mount", ("C_MountJournal",)),
        "GetMountInfoExtraByID": ("mount", ("C_MountJournal",)), "GetCompanionInfo": ("mount", ("",)),
        "GetItemInfo": ("item", ("", "C_Item")), "GetItemNameByID": ("item", ("C_Item",)),
        "GetZoneText": ("zone", ("",)), "GetRealZoneText": ("zone", ("",)), "GetSubZoneText": ("zone", ("",)),
        "GetMinimapZoneText": ("zone", ("",)), "GetMapInfo": ("map", ("C_Map",)), "GetAreaInfo": ("zone", ("C_Map",)),
        "GetMapNameByID": ("map", ("",)), "GetInstanceInfo": ("zone", ("",)), "UnitName": ("npc", ("",)),
        "GetUnitName": ("npc", ("",)), "GetQuestLogTitle": ("quest", ("",)),
        "GetTitleForQuestID": ("quest", ("C_QuestLog",)), "GetQuestInfo": ("quest", ("",)),
        "GetTitleText": ("quest", ("",)), "GetFactionInfo": ("faction", ("",)), "GetFactionInfoByID": ("faction", ("",)),
        "GetSkillLineInfo": ("skill", ("",)), "TaxiNodeName": ("zone", ("",)), "GetBindLocation": ("zone", ("",))}
DROP = re.compile(r"^(L_)?UIDropDownMenu_|^EasyMenu$|^ToggleDropDownMenu$|^CloseDropDownMenus$")
MENU_METHODS = {"CreateButton", "CreateCheckbox", "CreateRadio", "CreateTitle", "CreateContextMenu",
                "CreateButtonMenu", "SetupMenu", "ModifyMenu", "CreateTemplate", "CreateRadioMenu"}
SETTINGS_NAME = {"RegisterCanvasLayoutCategory": 1, "RegisterCanvasLayoutSubcategory": 2,
                 "RegisterVerticalLayoutCategory": 0, "RegisterVerticalLayoutSubcategory": 1,
                 "RegisterProxySetting": 3, "RegisterAddOnSetting": 5, "CreateCheckbox": 2, "CreateSlider": 2,
                 "CreateDropdown": 2, "CreateControlInitializer": 3, "RegisterAddOnCategory": 0,
                 "CreateSettingsListSectionHeaderInitializer": 0, "InterfaceOptions_AddCategory": 0,
                 "AddToBlizOptions": 1, "RegisterOptionsTable": 0, "OpenToCategory": 0}
MAP_HOOKS = {"HookScript", "SetScript", "AddDataProvider", "RegisterCallback", "AddOverlayFrame",
             "AddCanvasClickHandler"}
POPUP_FIELDS =("text", "subText", "button1", "button2", "button3", "button4", "extraButton")
SAVE_CALL = re.compile(r"\w*DB[.:](?:Set|Add|Save|Insert)\w*$|^(?:t|table\.)insert$")


def ident(s):
    return s if re.fullmatch(r"[\w.-]{1,60}", s) else "…"


def find_gamenames(lf, rel, ctx):
    alias = ctx.aliases.get(rel, {})
    for o, callee, last in lf.calls():
        full = alias.get(callee, callee)
        last = re.findall(r"\w+", full)[-1]
        head = re.sub(r"[.:]?\w+$", "", full)
        if last in GAME and (head in GAME[last][1] or (head == "" and "" in GAME[last][1])):
            note = " (alias %s)" % callee if callee != full else ""
            ctx.add("gamename", rel, lf.line(o), "%s <%s>%s" % (full, GAME[last][0], note))


def popup_fields(lf, o, ctx, rel):
    f = lf.fields(o)
    parts = ["%s=%s" % (k, show(*classify(lf, f[k][0], f[k][1], ctx, rel))) for k in POPUP_FIELDS if k in f]
    return " ".join(parts)


def find_popups(lf, rel, ctx):
    toks = lf.toks
    for i, t in enumerate(toks):
        if t.kind == NAME and t.val == "StaticPopupDialogs" and (lf.is_sym(i + 1, "[") or lf.is_sym(i + 1, ".")):
            end = lf.close.get(i + 1, i + 2) + 1 if lf.is_sym(i + 1, "[") else i + 3
            if lf.is_sym(end, "=") and lf.is_sym(end + 1, "{"):
                name = ident(toks[i + 2].val) if toks[i + 2].kind in (STR, NAME) and end - i <= 4 else "[expr]"
                ctx.add("popup", rel, lf.line(i), "StaticPopupDialogs %s %s" % (name, popup_fields(lf, end + 1, ctx, rel)))
    for o, callee, last in lf.calls():
        parts = lf.args(o) if toks[o].val == "(" else [(o, lf.close.get(o, o) + 1)]
        if re.search(r"Popup(?:\s*:\s*(?:Toggle|New))?$", callee):
            tables = [a for a, b in parts if lf.is_sym(a, "{")]
            if tables:
                lib = "Sushi" if "Sushi" in callee or "' '" in callee or '""' in callee else callee
                ctx.add("popup", rel, lf.line(o), "%s Popup%s %s" % (
                    lib, ":Toggle" if "Toggle" in callee else "", popup_fields(lf, tables[0], ctx, rel)))
        elif last == "StaticPopup_Show" and parts and toks[parts[0][0]].kind == STR:
            ctx.add("popup", rel, lf.line(o), "StaticPopup_Show %s" % ident(toks[parts[0][0]].val))
        elif last == "Register" and "Dialog" in callee and len(parts) >= 2 and lf.is_sym(parts[1][0], "{"):
            ctx.add("popup", rel, lf.line(o), "LibDialog %s" % popup_fields(lf, parts[1][0], ctx, rel))


def find_menus(lf, rel, ctx):
    toks = lf.toks
    for o, callee, last in lf.calls():
        parts = lf.args(o) if toks[o].val == "(" else []
        a = parts[0] if parts else (o + 1, o + 1)
        if callee.startswith("Menu.ModifyMenu") or callee == "Menu.ModifyMenu":
            tag = ident(toks[a[0]].val) if toks[a[0]].kind == STR else lf.src(*a)
            ctx.add("menu", rel, lf.line(o), "Menu.ModifyMenu %s" % tag)
        elif DROP.search(last):
            ctx.add("menu", rel, lf.line(o), last)
        elif last in MENU_METHODS and (callee.startswith("MenuUtil") or ":" in callee):
            arg = show(*classify(lf, a[0], a[1], ctx, rel)) if last.startswith("Create") else ""
            ctx.add("menu", rel, lf.line(o), ("%s %s" % (re.sub(r"^.*[.:]", ":", callee)
                                                          if not callee.startswith("MenuUtil") else callee, arg)).strip())
        elif (callee.startswith("WorldMapFrame") and last in MAP_HOOKS) or (
                last == "hooksecurefunc" and parts and lf.src(*parts[0]).startswith("WorldMapFrame")):
            what = callee
            if last == "hooksecurefunc" and len(parts) > 1:
                p = parts[1][0]
                what = ident(toks[p].val) if toks[p].kind == STR else lf.src(*parts[1])
            ctx.add("menu", rel, lf.line(o), "WorldMapFrame hook %s" % what)
        elif callee in ("CreateFrame", "pcall"):
            # A frame of its own on the World Map (Forever Quest Pins 1.1.3: a filter button and list).
            if callee == "pcall":
                if not parts or lf.src(*parts[0]) != "CreateFrame":
                    continue
                parts = parts[1:]
            if len(parts) > 2 and lf.src(*parts[2]).startswith("WorldMapFrame"):
                n = parts[1][0]
                name = ident(toks[n].val) if toks[n].kind == STR else lf.src(*parts[1])
                ctx.add("menu", rel, lf.line(o), "WorldMapFrame child %s" % name)


def find_settings(lf, rel, ctx):
    toks = lf.toks
    for o, callee, last in lf.calls():
        if last not in SETTINGS_NAME or toks[o].val != "(":
            continue
        if last in ("CreateCheckbox", "CreateSlider", "CreateDropdown", "OpenToCategory") and \
                not callee.startswith("Settings"):
            continue
        parts, n = lf.args(o), SETTINGS_NAME[last]
        arg = show(*classify(lf, *parts[n], ctx, rel)) if n < len(parts) else "-"
        when = "at load" if lf.depth[o] == 0 else "in a function"
        ctx.add("settings", rel, lf.line(o), "%s name=%s (%s)" % (callee.replace(" ", ""), arg, when))


def save_call(lf, o, callee, saved):
    """A call that saves: a db setter, or an insert into a saved variable or a db table."""
    callee = callee.replace(" ", "")
    if not SAVE_CALL.search(callee):
        return False
    if not callee.endswith("insert"):
        return True
    parts = lf.args(o)
    head = lf.src(*parts[0], 80) if parts else ""
    return bool(re.findall(r"\w+", head)[:1] and (re.findall(r"\w+", head)[0] in saved
                                                    or re.search(r"(^|\.)db\w*(\.|\[|$)", head, re.I)))


def find_saved(lf, rel, ctx):
    """Locale texts assigned into saved data, passed to a save call, or held by a local that is saved later."""
    toks, held = lf.toks, {}
    saved = ctx.saved_vars
    for i, t in enumerate(toks):
        r = locale_ref(lf, i, ctx)
        if not r or lf.is_sym(r[1], "="):
            continue
        fr = lf.frames[i]
        if lf.is_sym(i - 1, "=") and i >= 2:
            lhs = lf.src(lf.chain_start(i - 1), i - 1, 80)
            held[lhs] = (r[0], lf.line(i))  # a local or a field that may be saved later
            head = re.findall(r"\w+", lhs)[:1]
            if head and (head[0] in saved or re.search(r"(^|\.)db\w*(\.|\[|$)", lhs, re.I)):
                ctx.add("saved", rel, lf.line(i), "%s = L.%s" % (re.sub(r"\[.*", "[…]", lhs), r[0]))
                continue
        for kind, o, callee, *_ in reversed(fr):
            if kind == "(" and callee and save_call(lf, o, callee, saved):
                ctx.add("saved", rel, lf.line(i), "%s(L.%s)" % (callee.replace(" ", ""), r[0]))
                break
        own = [f for f in fr if f[0] == "{" and f[5]]
        if own and re.search(r"(?i)defaults?$|^DB_|\bdb\b", own[0][5]):
            ctx.add("saved", rel, lf.line(i), "L.%s in defaults %s" % (r[0], own[0][5]))
    for o, callee, last in lf.calls():
        if toks[o].val == "(" and save_call(lf, o, callee, saved):
            for a, b in lf.args(o):
                arg = lf.src(a, b, 80)
                if arg in held:
                    key, line = held[arg]
                    ctx.add("saved", rel, lf.line(o), "%s(%s) holds L.%s from line %d" % (
                        callee.replace(" ", ""), arg, key, line))


def find_copies(lf, rel, ctx):
    """Locale words read at load (outside any function): they keep the words of that moment."""
    seen = {}
    for i, t in enumerate(lf.toks):
        if lf.depth[i]:
            continue
        r = locale_ref(lf, i, ctx)
        if not r or lf.is_sym(r[1], "="):
            continue
        fr = lf.frames[i]
        owner = next((f[5] or f[2] for f in fr if f[5] or f[2]), None)
        if owner is None and lf.is_sym(i - 1, "="):
            owner = lf.src(lf.chain_start(i - 1), i - 1, 60)
        owner = owner or "?"
        if owner not in seen:
            seen[owner] = [lf.line(i), 0]
        seen[owner][1] += 1
    for owner, (line, n) in seen.items():
        ctx.add("copies", rel, line, "%s: %d L word(s) at load" % (owner, n))
