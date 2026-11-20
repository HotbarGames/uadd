"""Loads WoW addons into a Lua 5.1 state with the harness stubs, the way the client does.

One `Client` is one game session: a fresh Lua state, every addon's files run in TOC order, then
ADDON_LOADED per addon, saved variables restored from the previous session (a /reload).
"""
import os
import re
import xml.etree.ElementTree as ET

import encoding
import tipfont

HERE = os.path.dirname(os.path.abspath(__file__))
STUBS = ["wow_core.lua", "wow_lua.lua", "wow_widgets.lua", "wow_api.lua", "wow_widgets2.lua", "wow_focus.lua",
         "wow_frames.lua",
         "wow_api2.lua", "wow_frames2.lua", "wow_fontfam.lua", "wow_api3.lua", "wow_load.lua"]
FRAME_TAGS = {"Frame", "Button", "CheckButton", "EditBox", "ScrollFrame", "Slider", "StatusBar",
              "GameTooltip", "MessageFrame", "ScrollingMessageFrame", "Cooldown", "Model",
              "PlayerModel", "ColorSelect", "SimpleHTML"}


def lua_runtime():
    """Returns the lupa Lua 5.1 module, or None when it is not installed."""
    try:
        from lupa import lua51
    except ImportError:
        return None
    return lua51


def read_text(path):
    with open(path, "rb") as f:
        data = f.read()
    if data.startswith(b"\xef\xbb\xbf"):
        data = data[3:]
    return data.decode("latin-1")   # bytes as-is: the Lua state converts strings with latin-1


def txt(v):
    """A Lua string (latin-1 bytes) as real text."""
    return v.encode("latin-1").decode("utf-8", errors="replace") if isinstance(v, str) else v


def lua_str(text):
    """Real text as the Lua state sees it (UTF-8 bytes)."""
    return text.encode("utf-8").decode("latin-1")


def parse_toc(path):
    """Returns (metadata dict, list of files) from a .toc."""
    meta, files = {}, []
    for line in read_text(path).split("\n"):   # not splitlines(): latin-1 text has odd separators
        line = line.rstrip("\r \t")
        if line.startswith("##"):
            key, sep, value = line[2:].partition(":")
            if sep:
                meta[key.strip()] = value.strip()
        elif line and not line.startswith("#"):
            files.append(line.strip())
    return meta, files


def find_toc(folder, name, flavor):
    for candidate in (f"{name}_{flavor}.toc", f"{name}.toc"):
        p = os.path.join(folder, candidate)
        if os.path.isfile(p):
            return p
    raise FileNotFoundError(f"no TOC for {name} in {folder}")


def local_tag(tag):
    return tag.split("}")[-1]


class Addon:
    def __init__(self, name, folder, flavor):
        self.name, self.folder = name, folder
        self.toc = find_toc(folder, name, flavor)
        self.meta, self.files = parse_toc(self.toc)

    def list_field(self, key):
        v = self.meta.get(key, "")
        return [x.strip() for x in v.split(",") if x.strip()]

    @property
    def saved(self):
        return self.list_field("SavedVariables") + self.list_field("SavedVariablesPerCharacter")


class Client:
    """A game session. `addons` is a list of Addon in load order."""

    def __init__(self, addons, saved_text=None, locale="enUS"):
        lua51 = lua_runtime()
        if lua51 is None:
            raise RuntimeError("lupa (Lua 5.1) is not installed")
        self.lua = lua51.LuaRuntime(unpack_returned_tuples=True, encoding="latin-1")
        self.addons = addons
        run_stub = self.lua.eval("function(c, n) return assert(loadstring(c, n))() end")
        for stub in STUBS:
            run_stub(read_text(os.path.join(HERE, stub)), "@harness/" + stub)
        encoding.install(self.lua)
        self.H = self.lua.globals().HARNESS
        self.H.locale = locale
        self.H.tipReport = tipfont.report           # the tooltip font check (wow_fontfam.lua)
        for i, a in enumerate(addons, 1):
            meta = self.lua.table_from(a.meta)
            lower = self.lua.table_from({k.lower(): v for k, v in a.meta.items()})
            self.H.addons[a.name] = self.lua.table_from({"meta": meta, "metaLower": lower})
            self.H.addonOrder[i] = a.name
        self.saved_text = saved_text or {}
        self.file_count = 0

    # ── running files ──────────────────────────────────────────────────────────────────────────
    def run_lua(self, addon, rel):
        path = os.path.join(addon.folder, *rel.replace("\\", "/").split("/"))
        if not os.path.isfile(path):
            self.lua.globals().HARNESS.report("missing file", f"{addon.name}/{rel}")
            return
        self.file_count += 1
        self.H.runFile(addon.name, rel.replace("\\", "/"), read_text(path))

    def run_xml(self, addon, rel):
        path = os.path.join(addon.folder, *rel.replace("\\", "/").split("/"))
        if not os.path.isfile(path):
            self.H.report("missing file", f"{addon.name}/{rel}")
            return
        base = os.path.dirname(rel.replace("\\", "/"))
        text = re.sub(r"<!--.*?-->", "", read_text(path), flags=re.S)
        text = re.sub(r'\s[A-Za-z]+:[A-Za-z]+="[^"]*"', '', text)  # xsi:... without xmlns:xsi
        try:
            root = ET.fromstring(text)
        except ET.ParseError as e:
            self.H.report('xml ' + addon.name + '/' + rel, str(e))
            return
        for el in root:
            self.xml_element(addon, base, el, rel)

    def xml_element(self, addon, base, el, rel):
        tag = local_tag(el.tag)
        if tag in ("Script", "Include"):
            f = el.get("file")
            if f:
                child = f.replace("\\", "/")
                child = f"{base}/{child}" if base else child
                (self.run_xml if child.lower().endswith(".xml") else self.run_lua)(addon, child)
            elif tag == "Script" and (el.text or "").strip():
                self.H.runSnippet(addon.name, rel, el.text)
        elif tag in FRAME_TAGS and el.get("name") and el.get("virtual") != "true":
            name = el.get("name").replace("$parent", "")
            self.H.xmlFrame(tag, name, el.get("parent"), el.get("hidden") == "true",
                            el.get("autoFocus") == "false")

    def run_addon_files(self, addon):
        state = self.H.addons[addon.name]
        state.loading = True
        for rel in addon.files:
            if rel.lower().endswith(".xml"):
                self.run_xml(addon, rel)
            else:
                self.run_lua(addon, rel)
        state.loading = False
        state.loaded = True

    # ── a session ─────────────────────────────────────────────────────────────────────────────
    def start(self):
        """Loads every addon in order, firing ADDON_LOADED after each, then logs in.

        Saved variables arrive like in the client: right before the addon's ADDON_LOADED, or
        before its first file with LoadSavedVariablesFirst."""
        for a in self.addons:
            first = a.meta.get("LoadSavedVariablesFirst") == "1"
            if first:
                self.H.loadSaved(self.saved_text.get(a.name, ""), a.name)
            self.run_addon_files(a)
            if not first:
                self.H.loadSaved(self.saved_text.get(a.name, ""), a.name)
            self.H.fire("ADDON_LOADED", a.name)
        self.H.loggedIn = True
        self.H.fire("PLAYER_LOGIN")
        self.H.fire("PLAYER_ENTERING_WORLD", True, False)
        self.H.fire("ZONE_CHANGED_NEW_AREA")

    def dump_saved(self):
        """Returns {addon: Lua source of its saved variables}, as written on logout."""
        self.H.fire("PLAYER_LOGOUT")
        return {a.name: self.H.dumpSaved(self.lua.table_from(a.saved)) for a in self.addons if a.saved}

    # ── helpers for the flow ──────────────────────────────────────────────────────────────────
    def errors(self):
        out = []
        errs = self.H.errorList()
        for i in range(1, int(self.H.count(errs)) + 1):
            e = errs[i]
            out.append((txt(e.where), txt(e.msg), txt(e.tb)))
        return out

    def chat(self):
        return [txt(x) for x in self.lines(self.H.chat)]

    def lines(self, lua_table):
        return [lua_table[i] for i in range(1, int(self.H.count(lua_table)) + 1)]

    def ev(self, code):
        return self.lua.eval(code)

    def slash(self, text):
        self.H.call("/uadd " + text, self.lua.globals().SlashCmdList.UADD, text, self.lua.globals().ChatFrame1EditBox)
