"""Reads the installed LootTriage for tools/make_lt_text.py: every string literal its code shows to the player.
Which texts are kept and how: tools/lt_rules.py. Nothing here names its English (no licence: all rights reserved).

LootTriage has no locale table. Every text is keyed Code.<hash>: UADD.Hash of one string literal as Lua reads it
(escapes decoded). A text the code glues with `..` is one row per literal piece; a format template is one row
with its %s/%d slots. A literal is left out by where it stands: an argument of a call that takes no text
(SKIP_CALLS), a compare (== / ~=), a table key ([...] and the field names in HIDDEN_FIELDS), a key-like word
(camelCase or with "_"), then by tools/lt_rules.py (no words, names kept, code values by hash).
"""
import os
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import hashtext as H  # noqa: E402
import luatok  # noqa: E402
import lt_rules as R  # noqa: E402
import news_texts as NT  # noqa: E402

ADDON_DIRS = ["/mnt/c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns",
              "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns"]
TOC = "LootTriage.toc"
NO_TEXT = {"QuestItems.lua", "Sorting.lua"}     # data and bag moves: nothing shown
S, N, Y = luatok.STR, luatok.NAME, luatok.SYM
SKIP_CALLS = {
    "CreateFrame", "NewFrame", "SetPoint", "SetScript", "HookScript", "RegisterEvent", "UnregisterEvent",
    "SetAtlas", "SetTexture", "SetNormalTexture", "SetPushedTexture", "SetHighlightTexture", "SetDisabledTexture",
    "SetCheckedTexture", "SetFontObject", "SetDrawLayer", "SetFrameStrata", "SetBlendMode", "SetGradient",
    "SetJustifyH", "SetJustifyV", "RegisterForDrag", "RegisterForClicks", "hooksecurefunc", "CreateFontString",
    "CreateTexture", "CreateAnimationGroup", "CreateAnimation", "GetAddOnMetadata", "IsAddOnLoaded", "LoadAddOn",
    "GetAddOnInfo", "UnitClass", "UnitRace", "UnitLevel", "UnitFactionGroup", "match", "gmatch", "find", "gsub",
    "select", "type", "rawget", "ArrowButton", "New", "GetCVar", "SetCVar", "GetCVarBool", "PlaySound",
    "SetPropagateKeyboardInput", "SetAttribute", "GetAttribute", "Mixin", "CreateFromMixins", "SetTextureSliceMargins",
    "SetObeyStepOnDrag", "EnableMouse", "SetMovable", "SetClampedToScreen", "SetVertexColor", "TrivialRange",
    "SetNormalAtlas", "SetPushedAtlas", "SetDisabledAtlas", "SetHighlightAtlas", "SetOwner", "RegisterCallback",
    "IsEventRegistered", "RegisterAddOnSetting", "RegisterVerticalLayoutCategory", "SetFont",
}
HIDDEN_FIELDS = {"key", "kind", "button", "version", "atlas", "texture", "icon", "font", "event", "setting", "var",
                 "anchor", "point", "layer", "template", "id", "type", "sound", "value", "db"}
KEYLIKE = re.compile(r"^(?:[A-Za-z][A-Za-z0-9]*(?:_[A-Za-z0-9_]*|[a-z0-9][A-Z][A-Za-z0-9]*)|[A-Z][A-Z0-9_]+"
                     r"|[A-Za-z0-9]+(?:-[A-Za-z0-9]+)+)$")    # a key, a CONSTANT, an atlas-name
PATH = "\\"     # a texture path (a backslash as Lua reads it)


def addon_dir(arg=None):
    if arg:
        return Path(arg)
    base = os.environ.get("UADD_ADDONS_DIR") or next((d for d in ADDON_DIRS if os.path.isdir(d)), ADDON_DIRS[0])
    return Path(base) / "LootTriage"


def version(addon):
    toc = Path(addon) / TOC
    m = re.search(r"^## Version:\s*(\S+)", toc.read_text(encoding="utf-8-sig", errors="replace"), re.M) \
        if toc.is_file() else None
    return m.group(1) if m else "?"


def files(addon):
    """The .lua files its TOC loads, in TOC order (all .lua when the TOC lists none)."""
    toc = Path(addon) / TOC
    names = [ln.strip().replace("\\", "/") for ln in toc.read_text(encoding="utf-8-sig", errors="replace").split("\n")
             if ln.strip().lower().endswith(".lua") and not ln.startswith("#")] if toc.is_file() else []
    return [n for n in names if (Path(addon) / n).is_file()] or sorted(p.name for p in Path(addon).glob("*.lua"))


def literals(path):
    """[(value, line, why left out or '', context)] of every string literal of one file."""
    t, out, stack = list(luatok.tokens(luatok.read(path))), [], []
    at = lambda j: t[j][:2] if 0 <= j < len(t) else (None, None)  # noqa: E731
    for i, (kind, value, line) in enumerate(t):
        if kind == Y and value == "(":
            stack.append(t[i - 1][1] if i and t[i - 1][0] == N else None)
            continue
        if kind == Y and value == ")":
            stack and stack.pop()
            continue
        if kind != S:
            continue
        call = stack[-1] if stack else None
        p1, p2, n1, n2 = at(i - 1), at(i - 2), at(i + 1), at(i + 2)
        ctx = call or ""
        why = ""
        if call in SKIP_CALLS:
            why = "call " + call
        elif (p1 == (Y, "=") and p2[0] == Y and p2[1] in "=~<>") or (n1[0] == Y and n1[1] in "=~" and n2 == (Y, "=")):
            why = "compare"
        elif p1 == (Y, "[") and n1 == (Y, "]"):
            why = "table key"
        elif p1 == (Y, "=") and p2[0] == N:
            ctx = p2[1] + "="
            if p2[1] in HIDDEN_FIELDS:
                why = "field " + p2[1]
        elif t[i - 1][:2] == (Y, "=") and p2 == (Y, "]"):
            ctx = "[...]="
        if not why and KEYLIKE.match(value):
            why = "key-like"
        if not why and PATH in value:
            why = "path"
        out.append((value, line, why, ctx))
    return out


def source(addon):
    """(rows, why). rows: (key, English, batch, [(file, line)], note) in batch order; why: {reason: count} of
    the literals left out. A text shown only in its What's New (WhatsNew.lua) is no row: UADD leaves it English
    (lesson 43, tools/news_texts.py); one shown there and elsewhere is a row, its batch and note from elsewhere."""
    addon = Path(addon)
    if not (addon / TOC).is_file():
        return [], {}
    found, real, why = {}, set(), {}
    for f in files(addon):
        if f in NO_TEXT:
            continue
        news = NT.is_news(f)
        for en, line, left, ctx in literals(addon / f):
            key = "Code." + H.djb2(en)
            kept, reason = (False, left) if left else R.keep(key, en)
            if not kept:
                reason = reason.split(" ")[0] if left else reason
                why[reason] = why.get(reason, 0) + 1
                continue
            if key not in found:
                found[key] = [key, en, R.batch_of(f), [], R.note(key, f, ctx)]
            found[key][3].append((f, line))
            if not news and key not in real:               # its first place outside the news names its batch
                real.add(key)
                found[key][2], found[key][4] = R.batch_of(f), R.note(key, f, ctx)
    rows = NT.drop(list(found.values()))
    rows = sorted(rows, key=lambda r: r[2])               # stable: file and line order inside a batch
    return R.split(rows), why


if __name__ == "__main__":      # prints the English: for a look, never into a tracked file
    a = addon_dir(sys.argv[2] if len(sys.argv) > 2 else None)
    if len(sys.argv) > 1 and sys.argv[1] == "all":
        for f in files(a):
            for en, line, left, ctx in literals(a / f):
                print(f, line, H.djb2(en), left or "KEEP", ctx, repr(en)[:90])
    else:
        rs, w = source(a)
        for r in rs:
            print(r[2], r[0], repr(r[1])[:80], r[3][:2], r[4][:40])
        print(w)
