#!/usr/bin/env python3
"""Map every place a WoW addon puts text on screen: the "map the addon" step of a new UADD module, as a script.

    python3 tools/scan_addon.py <AddonFolder or path> [--kind global --kind font ...]

The addon is read from the WoW AddOns folder ($UADD_ADDONS_DIR, else tools/copy_scan.py's default). Prints to
stdout only, per kind, file:line and a short tag: never the addon's English (a key or a global's name is fine).
Kinds: see KINDS. Parts: tools/scan_lua.py (Lua reading), scan_text.py and scan_more.py (finders), scan_xml.py,
scan_font.py (cmap). Test: python3 -m unittest tools.test_scan_addon.
"""
import argparse
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import scan_more  # noqa: E402
import scan_text  # noqa: E402
import scan_xml  # noqa: E402
from scan_font import cyr_status, game_file  # noqa: E402
from scan_lua import LuaFile  # noqa: E402

KINDS = ["toc", "locale", "global", "text", "font", "gamename", "popup", "menu", "settings", "saved", "copies"]
ABOUT = {"toc": "TOC files vs files present (lesson 29)", "locale": "locale tables and keys",
         "global": "game globals shown as text (<where>)", "text": "text setters and text fields, not from L",
         "font": "fonts: files, objects, Cyrillic", "gamename": "game names from game APIs",
         "popup": "popups and their fields", "menu": "menus, dropdowns, World Map hooks",
         "settings": "Settings / options registrations", "saved": "locale texts written into saved data (lesson 14)",
         "copies": "locale words read at load, outside functions (lesson 15)"}
LANGS = re.compile(r"(deDE|esES|esMX|frFR|itIT|koKR|ptBR|ptPT|ruRU|zhCN|zhTW)")
SHORT = {"de", "es", "fr", "it", "ko", "kr", "pt", "br", "ru", "zh", "cn", "tw", "mx"}
LIBDIR = re.compile(r"(?i)^(libs?|externallibs|libraries|embeds)$")
FOOTER = """What it cannot see:
- text built at run time (format, .., string tables filled in code) and a local that holds a global before a setter
- data tables the addon shows later (lists of names, options tables read by another lib)
- text from other addons and from libraries (files under libs/, folders with their own TOC are not read)
- whether a game font object (GameFontNormal, ...) has Cyrillic, and fonts inside the game archive (game unknown)
- globals read by a built name (_G[prefix .. n]) and calls through variables it cannot follow
- when a registration "in a function" runs (at login or on first open), and code in <!--@debug@ --> blocks
- what runs only in the real client: hooks order, ClassicUA or UALL Forever writing the same text"""


class Ctx:
    def __init__(self, root):
        self.root, self.name = root, root.name
        self.defined, self.locals, self.locale, self.aliases = set(), {}, {"L", "AL"}, {}
        self.saved_vars, self.font_objs, self.ldefs, self.lused, self.lfiles = set(), {}, {}, {}, {}
        self.found, self.seen, self.uses = [], set(), {}
        self.files, self.texts = walk(root), {}  # one walk and one read per file: the game folder is slow
        self.shipped = {r.lower(): root / r for r in self.files if r.lower().endswith((".ttf", ".otf"))}

    def add(self, kind, rel, line, tag, dedupe=None):
        key = (kind,) + (tuple(dedupe) if dedupe else (rel, line, tag))
        if key not in self.seen:
            self.seen.add(key)
            self.found.append((kind, rel, line, tag))

    def game(self, name, rel):
        """A name read as a game global: not defined by the addon, not a locale table, not a known non-text one."""
        return (name not in self.defined and name not in self.locals.get(rel, ()) and name not in self.locale
                and not name.startswith(self.name.upper() + "_") and not scan_text.denied(name))

    def font_path(self, path):
        p = path.replace("\\\\", "/").replace("\\", "/")
        base, low = p.split("/")[-1], p.lower()
        pre = "interface/addons/%s/" % self.name.lower()
        if not low.startswith(pre):
            return "%s %s" % (base, "other addon's file" if low.startswith("interface/addons/") else game_file(p))
        f = self.shipped.get(low[len(pre):])
        return "%s shipped, %s" % (base, "missing" if f is None else "cyrillic=" + cyr_status(f.read_bytes()))

    def font_use(self, obj, rel, line, where):
        self.uses.setdefault((obj, where), [rel, line, 0])[2] += 1


def resolve(arg):
    p = Path(arg)
    if p.is_dir():
        return p.resolve()
    import copy_scan
    d = copy_scan.addons_dir()
    if d is None or not (Path(d) / arg).is_dir():
        sys.exit("scan_addon: no addon folder %r (AddOns: %s)" % (arg, d))
    return Path(d) / arg


def is_lang(rel, text):
    parts = rel.split("/")
    stem = parts[-1].rsplit(".", 1)[0].lower()
    if LANGS.search(rel) or (stem in SHORT and len(parts) > 1 and re.search(r"(?i)loc", parts[-2])):
        return True
    m = re.search(r"NewLocale\([^)]*[\"'](\w{4})[\"']|GetLocale\(\)\s*[~=]=\s*[\"'](\w{4})[\"']", text[:800])
    return bool(m and (m.group(1) or m.group(2)) not in ("enUS", "enGB"))


def walk(root):
    """Every file under root, as a path relative to it."""
    out = []
    for d, _, fs in os.walk(root):
        base = Path(d).relative_to(root).as_posix()
        out += [f if base == "." else base + "/" + f for f in fs]
    return out


def files_of(ctx):
    """{lower rel: rel} of the addon's own .lua/.xml (not under libs/ nor a folder with its own TOC), and the libs."""
    tocdirs = {r.rsplit("/", 1)[0] + "/" for r in ctx.files if r.lower().endswith(".toc") and "/" in r}
    own, lib = {}, {}
    for rel in ctx.files:
        if not rel.lower().endswith((".lua", ".xml")):
            continue
        inlib = any(rel.startswith(t) for t in tocdirs) or any(LIBDIR.match(x) for x in rel.split("/")[:-1])
        (lib if inlib else own)[rel.lower()] = rel
    return own, lib


def read(root, rel, ctx=None):
    if ctx is not None and rel in ctx.texts:
        return ctx.texts[rel]
    text = (root / rel).read_bytes().decode("utf-8", "replace")
    if ctx is not None:
        ctx.texts[rel] = text
    return text


def tocs(root, ctx, allf):
    """Files the TOCs load (XML includes followed), and toc findings."""
    loaded = {}
    for toc in sorted(r for r in ctx.files if "/" not in r and r.lower().endswith(".toc")):
        n_listed = 0
        for n, line in enumerate(read(root, toc, ctx).splitlines(), 1):
            s = line.strip()
            m = re.match(r"##\s*SavedVariables(?:PerCharacter)?\s*:\s*(.*)", s)
            if m:
                ctx.saved_vars.update(x.strip() for x in m.group(1).split(",") if x.strip())
            if not s or s.startswith("##"):
                continue
            if s.startswith("#"):
                if re.search(r"(?i)\.(lua|xml)$", s):
                    ctx.add("toc", toc, n, "commented out: %s" % s.lstrip("# ").replace("\\", "/"))
                continue
            entry = s.replace("\\", "/")
            rx = re.compile(re.sub(r"\\\[\w+\\\]", ".*", re.escape(entry.lower())) + "$")
            hits = [r for r in allf if rx.fullmatch(r)]
            if not hits:
                ctx.add("toc", toc, n, "listed, missing: %s" % entry)
            n_listed += 1
            for h in hits:
                follow(ctx, allf, h, loaded, toc)
        ctx.add("toc", toc, 1, "lists %d files" % n_listed)
    return loaded


def follow(ctx, allf, low, loaded, by):
    if low in loaded:
        return
    loaded[low] = by
    if low.endswith(".xml"):
        base = low.rsplit("/", 1)[0] + "/" if "/" in low else ""
        for _, f in scan_xml.loads(read(ctx.root, allf[low], ctx)):
            parts = []
            for x in (base + f.replace("\\", "/").lower()).split("/"):
                if x == "..":
                    parts = parts[:-1]
                elif x and x != ".":
                    parts.append(x)
            target = "/".join(parts)
            if target in allf:
                follow(ctx, allf, target, loaded, by)


def scan(root):
    ctx = Ctx(root)
    own, lib = files_of(ctx)
    loaded = tocs(root, ctx, {**own, **lib})
    for low, rel in sorted(own.items()):
        if low not in loaded:
            ctx.add("toc", rel, 1, "not loaded by any TOC")
    todo = [own[x] for x in sorted(own) if x in loaded] or sorted(own.values())
    luas = []  # (rel, LuaFile, is_lang)
    for rel in todo:
        text = read(root, rel, ctx)
        if rel.lower().endswith(".xml"):
            ctx.defined |= scan_xml.names(text)
            luas += [(rel, LuaFile(s), False) for s in scan_xml.scripts(text)]
        else:
            luas.append((rel, LuaFile(text), is_lang(rel, text)))
    for _ in range(2):  # twice: locale tables named in one file are read in another
        for rel, lf, _lang in luas:
            scan_text.pass1(lf, rel, ctx)
    ctx.defined -= {"L", "AL"}
    for rel in todo:
        if rel.lower().endswith(".xml"):
            scan_xml.scan(read(root, rel, ctx), rel, ctx)
    finders = (scan_text.find_text, scan_text.find_fonts, scan_more.find_gamenames, scan_more.find_popups,
               scan_more.find_menus, scan_more.find_settings, scan_more.find_saved, scan_more.find_copies)
    for rel, lf, lang in luas:
        if not lang and not ctx.ldefs.get(rel):
            for f in finders:
                f(lf, rel, ctx)
        elif not lang:
            scan_text.find_text(lf, rel, ctx)
            scan_text.find_fonts(lf, rel, ctx)
    for low, p in sorted(ctx.shipped.items()):
        ctx.add("font", p.relative_to(root).as_posix(), 1, "ships %s cyrillic=%s" % (p.name, cyr_status(p.read_bytes())))
    for (obj, where), (rel, line, n) in sorted(ctx.uses.items(), key=lambda x: (x[1][0], x[1][1])):
        st = ctx.font_objs.get(obj, "game object, Cyrillic unknown")
        ctx.add("font", rel, line, "%s on %s x%d: %s" % (obj, where, n, st))
    langs = {rel for rel, _, lang in luas if lang}
    for rel, keys in sorted(ctx.ldefs.items()):
        if rel not in langs:
            ctx.add("locale", rel, 1, "defines %d keys" % len(keys))
    if langs:
        ctx.add("locale", sorted(langs)[0], 1, "%d other-language locale files (skipped)" % len(langs))
    for name, keys in sorted(ctx.lused.items()):
        ctx.add("locale", "*", 0, "%s: %d keys used in %d files" % (name, len(keys), len(ctx.lfiles[name])))
    return ctx


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("addon")
    ap.add_argument("--kind", action="append", choices=KINDS)
    a = ap.parse_args(argv)
    root = resolve(a.addon)
    ctx = scan(root)
    print("scan_addon: %s" % root.name)
    for kind in a.kind or KINDS:
        rows = sorted((r for r in ctx.found if r[0] == kind), key=lambda r: (r[1], r[2]))
        print("== %s: %d  (%s)" % (kind, len(rows), ABOUT[kind]))
        for _, rel, line, tag in rows:
            print("%s:%d %s" % (rel, line, tag))
    print(FOOTER)


if __name__ == "__main__":
    main()
