"""XML for tools/scan_addon.py: files an XML loads, names it defines, text= and KeyValue globals, fonts (Font,
FontFamily, font=, inherits= on text elements), dropdown templates, and its inline Lua (scripts keep their lines).
"""
import html
import re

from scan_lua import caps, letters

TAG = re.compile(r"<([A-Za-z]\w*)((?:\s+[\w:]+\s*=\s*(?:\"[^\"]*\"|'[^']*'))*)\s*/?>", re.S)
ATTR = re.compile(r"([\w:]+)\s*=\s*(?:\"([^\"]*)\"|'([^']*)')")
SCRIPT = re.compile(r"<(On\w+|Script|PostClick|PreClick)\b([^>]*?)(?<!/)>(.*?)</\1\s*>", re.S)
FAMILY = re.compile(r"<FontFamily\b([^>]*)>(.*?)</FontFamily\s*>", re.S)
MEMBER = re.compile(r"<Member\b([^>]*)>.*?<Font\b([^>]*?)/?>", re.S)
TEXT_TAGS = {"FontString", "ButtonText", "NormalFont", "HighlightFont", "DisabledFont", "NormalText", "EditBox",
             "SimpleHTML", "CheckButtonText"}
DROPDOWN = re.compile(r"UIDropDownMenuTemplate|DropdownButton|DropDownMenuTemplate|DropdownTemplate")


def uncomment(text):
    return re.sub(r"<!--.*?-->", lambda m: re.sub(r"[^\n]", " ", m.group()), text, flags=re.S)


def attrs(s):
    return {m.group(1): m.group(2) if m.group(2) is not None else m.group(3) for m in ATTR.finditer(s)}


def lineno(text, pos):
    return text.count("\n", 0, pos) + 1


def loads(text):
    """Files a TOC-loaded XML pulls in: [(kind, path)] for <Script file> and <Include file>."""
    out = []
    for m in TAG.finditer(uncomment(text)):
        if m.group(1) in ("Script", "Include"):
            f = attrs(m.group(2)).get("file")
            if f:
                out.append((m.group(1), f))
    return out


def names(text):
    """Global names the XML makes (frames and font objects), so they are not taken for game globals."""
    out = set()
    for m in TAG.finditer(uncomment(text)):
        n = attrs(m.group(2)).get("name", "")
        if n and "$" not in n:
            out.add(n)
    return out


def scripts(text):
    """Inline Lua: [(text with the script at its own lines)]: the start is padded with newlines."""
    text = uncomment(text)
    out = []
    for m in SCRIPT.finditer(text):
        if m.group(1) == "Script" and "file" in attrs(m.group(2)):
            continue
        body = html.unescape(m.group(3))
        out.append("\n" * (lineno(text, m.start(3)) - 1) + body)
    return out


def scan(text, rel, ctx):
    text = uncomment(text)
    fam_spans = []
    for m in FAMILY.finditer(text):
        fam_spans.append(m.span())
        name = attrs(m.group(1)).get("name", "?")
        for mm in MEMBER.finditer(m.group(2)):
            alpha = attrs(mm.group(1)).get("alphabet", "?")
            path = attrs(mm.group(2)).get("font", "")
            st = ctx.font_path(path) if path else "no font file"
            if alpha in ("roman", "russian"):
                ctx.add("font", rel, lineno(text, m.start(2) + mm.start()), "FontFamily %s %s: %s" % (name, alpha, st))
            ctx.font_objs.setdefault(name, st if alpha == "roman" else ctx.font_objs.get(name, st))
    for m in TAG.finditer(text):
        tag, a, line = m.group(1), attrs(m.group(2)), lineno(text, m.start())
        inside = any(s <= m.start() < e for s, e in fam_spans)
        txt = a.get("text")
        if txt:
            if any(txt in keys for keys in ctx.ldefs.values()):
                ctx.add("text", rel, line, "<%s text> L key %s (the addon looks it up)" % (tag, txt))
            elif caps(txt) and ctx.game(txt, rel):
                ctx.add("global", rel, line, "%s <%s text>" % (txt, tag), dedupe=(rel, txt, tag, line))
            elif letters(txt) and not re.fullmatch(r"[A-Z0-9_]+", txt):
                ctx.add("text", rel, line, "<%s text> literal(%d)" % (tag, len(txt)))
        if tag == "KeyValue" and a.get("type") == "global" and caps(a.get("value", "")) and \
                ctx.game(a["value"], rel):
            ctx.add("global", rel, line, "%s <KeyValue %s>" % (a["value"], a.get("key", "?")))
        if tag == "Font" and not inside:
            path = a.get("font", "")
            st = ctx.font_path(path) if path.lower().endswith((".ttf", ".otf")) else \
                ("from object " + path if path else "inherits " + a.get("inherits", "-"))
            if a.get("name"):
                ctx.font_objs[a["name"]] = st
            ctx.add("font", rel, line, "Font object %s: %s" % (a.get("name", "?"), st))
        elif tag in TEXT_TAGS or tag.endswith(("Text", "Font")):
            obj = a.get("inherits") or a.get("style") or a.get("font")
            if obj and obj.lower().endswith((".ttf", ".otf")):
                ctx.add("font", rel, line, "<%s font> %s" % (tag, ctx.font_path(obj)))
            elif obj and "Font" in obj:
                ctx.font_use(obj, rel, line, "<%s>" % tag)
        if DROPDOWN.search(a.get("inherits", "")):
            ctx.add("menu", rel, line, "<%s inherits %s>" % (tag, a["inherits"]))
