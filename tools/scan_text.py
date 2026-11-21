"""Finders for tools/scan_addon.py, part 1: the names an addon defines (pass 1), locale keys, game globals shown
as text, text setters with a non-L argument, and fonts set in Lua.

Each finder takes (lf, rel, ctx): a scan_lua.LuaFile, the file's path in the addon, and scan_addon.Ctx.
"""
import re

from scan_lua import NAME, STR, SYM, KEYWORDS, caps, letters

LOCALE_RHS = re.compile(r"GetLocale|\bL\b|Locale|Localiz|L10n")
DENY_PRE = ("LE_", "NUM_", "MAX_", "WOW_PROJECT", "SOUNDKIT", "INVSLOT_", "BOOKTYPE_", "UIDROPDOWNMENU_", "LOOT_SLOT",
            "ITEM_QUALITY", "STATICPOPUP_", "BINDING_HEADER_", "SLASH_", "COMBATLOG_", "BANK_", "REAGENTBANK_", "CAMERA_")
DENY_SUF = ("_COLOR", "_COLORS", "_CONTAINER", "_FONT", "_TEXTURE", "_ID", "_INDEX", "_TCOORDS", "_ATLAS", "_PATH",
            "_FRAME", "_FILE", "_PER_GOLD", "_PER_SILVER", "_ORDER", "_COORDS", "_MASK", "_FLAG", "_FLAGS", "_SLOTS",
            "_HEIGHT", "_WIDTH", "_SIZE", "_OFFSET", "_LEVEL", "_TIME", "_DURATION")
DENY = {"GAME_LOCALE", "PI", "BAG_BUTTON", "TOOLTIP_DEFAULT_BACKGROUND_COLOR", "BACKPACK_CONTAINER"}
SETTERS = {"SetText": (0,), "SetFormattedText": (0,), "AddLine": (0,), "AddDoubleLine": (0, 1), "SetTitle": (0,),
           "SetLabel": (0,), "GameTooltip_SetTitle": (1,), "GameTooltip_AddNormalLine": (1,),
           "GameTooltip_AddHighlightLine": (1,), "GameTooltip_AddInstructionLine": (1,),
           "GameTooltip_AddErrorLine": (1,), "GameTooltip_AddColoredLine": (1,), "SetTextToFit": (0,)}
SHOWN_CALLS = set(SETTERS) | {"format", "AddMessage", "print", "SetTooltip", "CreateButton", "CreateCheckbox",
                              "CreateRadio", "CreateTitle", "CreateSettingsListSectionHeaderInitializer", "tinsert",
                              "insert", "SetHeader", "SetPrompt", "Popup", "Toggle", "UIDropDownMenu_SetText", "Show",
                              "StaticPopup_Show", "ShowTooltip", "SetDescription"}
TEXT_KEYS = {"text", "title", "tooltip", "tooltipText", "tooltipTitle", "label", "desc", "name", "header", "subText",
             "button1", "button2", "button3", "button4", "displayName", "tooltipOnButton", "headerText"}


def denied(name):
    return name in DENY or name.startswith(DENY_PRE) or name.endswith(DENY_SUF)


def free_name(lf, i):
    """Token i is a plain name read as a variable: not after . or :, not a table key, not a keyword."""
    t = lf.toks[i]
    return (t.kind == NAME and t.val not in KEYWORDS and not (lf.is_sym(i - 1, ".") or lf.is_sym(i - 1, ":"))
            and not lf.is_sym(i - 1, "::"))


def locale_ref(lf, i, ctx):
    """(key, end) when tokens at i are L.KEY or L["key"] for a locale table L; else None. A key with spaces is …."""
    if not (lf.toks[i].kind == NAME and lf.toks[i].val in ctx.locale and free_name(lf, i)):
        return None
    if lf.is_sym(i + 1, ".") and lf.v(i + 2) and lf.toks[i + 2].kind == NAME:
        return lf.v(i + 2), i + 3
    if lf.is_sym(i + 1, "[") and i + 2 < len(lf.toks):
        t = lf.toks[i + 2]
        key = t.val if t.kind == STR and re.fullmatch(r"[\w.-]{1,60}", t.val) else ("…" if t.kind == STR else "?")
        return key, lf.close.get(i + 1, i + 2) + 1
    return None


def pass1(lf, rel, ctx):
    """Names this file defines (addon globals, file locals), locale tables, API aliases, locale keys defined."""
    toks, loc = lf.toks, ctx.locals.setdefault(rel, set())
    for i, t in enumerate(toks):
        if t.kind != NAME or t.val in KEYWORDS:
            continue
        prev = lf.v(i - 1)
        if prev == "local" or (prev == "function" and lf.v(i - 2) == "local") or prev == "for":
            loc.add(t.val)
            j = i + 1
            while lf.is_sym(j, ",") and j + 1 < len(toks) and toks[j + 1].kind == NAME:
                loc.add(toks[j + 1].val)
                j += 2
            if prev == "local" and lf.is_sym(j, "="):
                rhs = lf.src(j + 1, lf.rhs_end(j + 1), 200)
                if LOCALE_RHS.search(rhs) and re.search(r"GetLocale|\.L\b|Locale|Localiz|L10n", rhs):
                    ctx.locale.add(t.val)
                if re.fullmatch(r"[A-Za-z_]\w*\.[A-Za-z_]\w*", rhs):
                    ctx.aliases.setdefault(rel, {})[t.val] = rhs
        elif prev == "function" and not lf.is_sym(i + 1, ".") and not lf.is_sym(i + 1, ":"):
            ctx.defined.add(t.val)
        elif free_name(lf, i) and lf.is_sym(i + 1, "=") and not (lf.frames[i] and lf.frames[i][-1][0] == "{"):
            ctx.defined.add(t.val)
        elif t.val == "_G" and lf.is_sym(i + 1, "[") and lf.v(i + 2) and toks[i + 2].kind == STR:
            ctx.defined.add(toks[i + 2].val)
        elif t.val == "_G" and lf.is_sym(i + 1, ".") and lf.is_sym(i + 3, "="):
            ctx.defined.add(lf.v(i + 2))
        if t.val in ctx.locale and free_name(lf, i):
            r = locale_ref(lf, i, ctx)
            if r and lf.is_sym(r[1], "="):
                ctx.ldefs.setdefault(rel, set()).add(r[0])
        if t.val == "function":  # its parameters are locals
            j = i + 1
            while j < len(toks) and (toks[j].kind == NAME or lf.v(j) in (".", ":")):
                j += 1
            if lf.is_sym(j, "("):
                loc.update(toks[a].val for a, b in lf.args(j) if b - a == 1 and toks[a].kind == NAME)


def classify(lf, a, b, ctx, rel):
    """(class, detail) of the expression in tokens a..b-1: none, lit, global, L, L+, var, expr."""
    if a >= b:
        return "none", ""
    t = lf.toks[a]
    if b - a == 1 and t.kind == STR:
        return ("lit", "literal(%d)" % len(t.val)) if letters(t.val) else ("none", "")
    if b - a == 1 and t.kind == NAME and caps(t.val) and ctx.game(t.val, rel):
        return "global", t.val
    if b - a == 1 and t.kind == NAME and t.val in ("nil", "true", "false"):
        return "none", ""
    r = locale_ref(lf, a, ctx)
    if r and r[1] == b:
        return "L", r[0]
    if any(locale_ref(lf, j, ctx) for j in range(a, b)):
        return "L+", lf.src(a, b)
    if all(x.kind == NAME or (x.kind == SYM and x.val == ".") for x in lf.toks[a:b]):
        return "var", lf.src(a, b)
    if all(x.kind in ("num", SYM) for x in lf.toks[a:b]):
        return "none", ""
    return "expr", lf.src(a, b)


def show(cls, det):
    return {"lit": det, "global": "G:" + det, "L": "L." + det, "var": "var:" + det, "expr": "expr:" + det,
            "L+": "L+:" + det}.get(cls, cls)


def find_text(lf, rel, ctx):
    """Locale keys used, game globals in shown places, setters and text fields with a non-L argument."""
    toks = lf.toks
    for i, t in enumerate(toks):
        r = locale_ref(lf, i, ctx)
        if r and not lf.is_sym(r[1], "="):
            ctx.lused.setdefault(t.val, set()).add(r[0])
            ctx.lfiles.setdefault(t.val, set()).add(rel)
        if t.kind == NAME and caps(t.val) and free_name(lf, i) and ctx.game(t.val, rel):
            where = global_ctx(lf, i, ctx)
            if where:
                ctx.add("global", rel, lf.line(i), "%s <%s>" % (t.val, where), dedupe=(rel, t.val, where))
    for o, callee, last in lf.calls():
        if last in SETTERS and toks[o].val == "(":
            parts = lf.args(o)
            for n in SETTERS[last]:
                if n < len(parts):
                    cls, det = classify(lf, parts[n][0], parts[n][1], ctx, rel)
                    if cls in ("lit", "var", "expr"):
                        ctx.add("text", rel, lf.line(o), "%s %s" % (last, show(cls, det)))
    for i, t in enumerate(toks):  # text = "..." in tables and x.text = "..."
        if t.kind == NAME and t.val in TEXT_KEYS and lf.is_sym(i + 1, "=") and i + 2 < len(toks):
            in_table = lf.frames[i] and lf.frames[i][-1][0] == "{" and lf.v(i - 1) in ("{", ",", ";")
            if in_table or lf.is_sym(i - 1, "."):
                b = lf.rhs_end(i + 2) if not in_table else next(
                    (y for x, y in lf.args(lf.frames[i][-1][1]) if x <= i < y), lf.rhs_end(i + 2))
                cls, det = classify(lf, i + 2, b, ctx, rel)
                if cls == "lit":
                    ctx.add("text", rel, lf.line(i), "%s%s= %s" % ("{" if in_table else ".", t.val, det))


def global_ctx(lf, i, ctx):
    """Where a game global at token i is shown, or None when it is not used as text (a compare, a call, a target)."""
    if lf.is_sym(i + 1, "(") or lf.is_sym(i + 1, "=") or lf.is_sym(i + 1, ".") or lf.is_sym(i + 1, ":"):
        return None
    if lf.v(i - 1) in ("==", "~=") or lf.v(i + 1) in ("==", "~=", "<", ">", "<=", ">=", "+", "-", "*", "/"):
        return None
    if lf.v(i - 1) in ("<", ">", "<=", ">=", "+", "-", "*", "/", "#", "not", "and", "if", "elseif", "while"):
        return None
    if lf.is_sym(i + 1, "["):
        return "names table"
    if lf.is_sym(i - 1, "=") and i >= 2:
        j = lf.chain_start(i - 1)
        lhs = lf.src(j, i - 1, 60)
        if locale_ref(lf, j, ctx):
            return "L=" if j else "L="
        if lhs.startswith("_G["):
            return "_G[]="
        key = lf.v(i - 2)
        if key in TEXT_KEYS and lf.is_sym(i - 3, "."):
            return "." + key + "="
    fr = lf.frames[i]
    if fr:
        kind, o, callee, _, key, owner = fr[-1]
        if kind == "{" and key in TEXT_KEYS:
            return "{%s=}" % key
        if kind == "(" and callee:
            last = re.findall(r"[A-Za-z_]\w*", callee)[-1]
            if last in SHOWN_CALLS or last.startswith(("Create", "Register", "Add", "Set")):
                return last + "()"
        if kind == "{":
            return "{[k]=}" if key else "{list}"
    for w in ("return", "or", ".."):
        if lf.v(i - 1) == w or (w != "return" and lf.v(i + 1) == w):
            return w
    if lf.is_sym(i - 1, "=") and lf.v(lf.chain_start(i - 1) - 1) == "local":
        return "local="
    return "other"


def find_fonts(lf, rel, ctx):
    toks = lf.toks
    for o, callee, last in lf.calls():
        parts = lf.args(o) if toks[o].val == "(" else []
        first = parts[0] if parts else (o + 1, o + 1)
        if last == "SetFont" and parts:
            t = toks[first[0]]
            if first[1] - first[0] == 1 and t.kind == STR:
                ctx.add("font", rel, lf.line(o), "SetFont %s" % ctx.font_path(t.val))
            else:
                ctx.add("font", rel, lf.line(o), "SetFont %s" % show(*classify(lf, first[0], first[1], ctx, rel)))
        elif last == "CreateFont" and parts and toks[first[0]].kind == STR:
            ctx.add("font", rel, lf.line(o), "CreateFont %s (its file: the SetFont on it)" % toks[first[0]].val)
            ctx.font_objs.setdefault(toks[first[0]].val, "made in Lua")
        elif last in ("SetFontObject", "CopyFontObject", "SetNormalFontObject", "SetHighlightFontObject") and parts:
            name = lf.src(first[0], first[1], 50)
            ctx.font_use(name.strip('"'), rel, lf.line(o), last)
        elif last == "Register" and len(parts) >= 3 and toks[parts[0][0]].kind == STR and \
                toks[parts[0][0]].val.lower() == "font" and toks[parts[2][0]].kind == STR:
            ctx.add("font", rel, lf.line(o), "SharedMedia font %s" % ctx.font_path(toks[parts[2][0]].val))
