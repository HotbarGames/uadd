"""The Lua string-literal reader the key-by-hash generators share in spirit (tools/lt_source.py and
tools/dci_source.py each carry the same logic; moving them onto this file is a backlog item).

literals(path, ...) lists every string literal of one .lua file with the reason it is not a shown text (an
argument of a call that takes no text, a compare, a table key, a field that holds a code value, a key-like word,
a texture path) and its context (the call or the field it stands in). The caller's config decides the sets.
Nothing here names an addon or its English.
"""
import os
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import luatok  # noqa: E402

ADDON_DIRS = ["/mnt/c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns",
              "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns"]
S, N, Y = luatok.STR, luatok.NAME, luatok.SYM

# Calls whose arguments are never a shown text (frames, textures, events, API lookups, string patterns).
SKIP_CALLS = {
    "CreateFrame", "NewFrame", "SetPoint", "SetScript", "HookScript", "RegisterEvent", "UnregisterEvent",
    "SetAtlas", "SetTexture", "SetNormalTexture", "SetPushedTexture", "SetHighlightTexture", "SetDisabledTexture",
    "SetCheckedTexture", "SetFontObject", "SetDrawLayer", "SetFrameStrata", "SetBlendMode", "SetGradient",
    "SetJustifyH", "SetJustifyV", "RegisterForDrag", "RegisterForClicks", "hooksecurefunc", "CreateFontString",
    "CreateTexture", "CreateAnimationGroup", "CreateAnimation", "GetAddOnMetadata", "IsAddOnLoaded", "LoadAddOn",
    "GetAddOnInfo", "UnitClass", "UnitRace", "UnitLevel", "UnitFactionGroup", "match", "gmatch", "find", "gsub",
    "select", "type", "rawget", "GetCVar", "SetCVar", "GetCVarBool", "PlaySound", "SetPropagateKeyboardInput",
    "SetAttribute", "GetAttribute", "Mixin", "CreateFromMixins", "SetTextureSliceMargins", "SetObeyStepOnDrag",
    "EnableMouse", "SetMovable", "SetClampedToScreen", "SetVertexColor", "SetNormalAtlas", "SetPushedAtlas",
    "SetDisabledAtlas", "SetHighlightAtlas", "SetOwner", "RegisterCallback", "IsEventRegistered", "SetFont",
}
# Table fields that hold a code value (a key, an event, a texture), never a text.
HIDDEN_FIELDS = {"key", "kind", "button", "version", "atlas", "texture", "icon", "font", "event", "setting", "var",
                 "anchor", "point", "layer", "template", "id", "type", "sound", "value", "db"}
KEYLIKE = re.compile(r"^(?:[A-Za-z][A-Za-z0-9]*(?:_[A-Za-z0-9_]*|[a-z0-9][A-Z][A-Za-z0-9]*)|[A-Z][A-Z0-9_]+"
                     r"|[A-Za-z0-9]+(?:-[A-Za-z0-9]+)+)$")    # a key, a CONSTANT, an atlas-name
PATH = "\\"     # a texture path (a backslash as Lua reads it)


def addon_dir(arg, folder):
    """`arg` when given, else <installed AddOns dir or $UADD_ADDONS_DIR>/<folder>."""
    if arg:
        return Path(arg)
    base = os.environ.get("UADD_ADDONS_DIR") or next((d for d in ADDON_DIRS if os.path.isdir(d)), ADDON_DIRS[0])
    return Path(base) / folder


def toc_version(addon, toc):
    """The `## Version:` of its TOC, or "?"."""
    path = Path(addon) / toc
    m = re.search(r"^## Version:\s*(\S+)", path.read_text(encoding="utf-8-sig", errors="replace"), re.M) \
        if path.is_file() else None
    return m.group(1) if m else "?"


def toc_files(addon, toc):
    """The .lua files its TOC loads, in TOC order (all .lua when the TOC lists none)."""
    path = Path(addon) / toc
    names = [ln.strip().replace("\\", "/") for ln in path.read_text(encoding="utf-8-sig", errors="replace").split("\n")
             if ln.strip().lower().endswith(".lua") and not ln.startswith("#")] if path.is_file() else []
    return [n for n in names if (Path(addon) / n).is_file()] or sorted(p.name for p in Path(addon).glob("*.lua"))


def literals(path, skip_calls=SKIP_CALLS, hidden_fields=HIDDEN_FIELDS):
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
        if call in skip_calls:
            why = "call " + call
        elif (p1 == (Y, "=") and p2[0] == Y and p2[1] in "=~<>") or (n1[0] == Y and n1[1] in "=~" and n2 == (Y, "=")):
            why = "compare"
        elif p1 == (Y, "[") and n1 == (Y, "]"):
            why = "table key"
        elif p1 == (Y, "=") and p2[0] == N:
            ctx = p2[1] + "="
            if p2[1] in hidden_fields:
                why = "field " + p2[1]
        elif t[i - 1][:2] == (Y, "=") and p2 == (Y, "]"):
            ctx = "[...]="
        if not why and KEYLIKE.match(value):
            why = "key-like"
        if not why and PATH in value:
            why = "path"
        out.append((value, line, why, ctx))
    return out
