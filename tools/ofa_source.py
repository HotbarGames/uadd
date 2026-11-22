"""Reads OneForAll's texts for UADD_OneForAll: its L keys, its author prose in data, and the literals its code
shows without L. A thin config over tools/lua_literals.py.

OneForAll is GPL-3.0-or-later, so its English may be named here. Pools (OneForAll-design.md):
  L        every key of Locales/deDE.lua (the same set as frFR's), grouped by the file's section comments
  pets     Data/HunterPets.lua desc, effect, why, note: drawn through FLT.LNum, so each number is a %s (sort v)
  boss     Data/Dungeons/*.lua boss descriptions
  summary  Data/DungeonKeys.lua and Data/RaidAttunements.lua summaries
  enchant  Data/Enchants.lua src (where an enchant comes from)
  code     literals its code shows through a text call (SetText, AddLine, labels, ...) and not through L
Left out on purpose: quest notes and book notes (v1), game names in data (they come from UALL Forever and
ClassicUA), GuildGames.lua and ProfessionGuild.lua literals (their wire and parsing; only L there), Locales/.
Derived rows (built from another row's Ukrainian, never reviewed): UPPER (a tile label it shows in capitals) and
COLON (SkillUpUI cuts a colon and adds a full stop).
`python3 tools/ofa_source.py all` prints every code literal and why it is left out; with no argument the rows.
"""
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import hashtext as H  # noqa: E402
import key_text as K  # noqa: E402
import lua_literals as LL  # noqa: E402
import ofa_rules as R  # noqa: E402

FOLDER, TOC = "OneForAll", "OneForAll.toc"
KEY_LINE = re.compile(r'^\s*\["((?:[^"\\]|\\.)*)"\]\s*=')
SECTION = re.compile(r"^\s*--\s*(\S.*?)\s*$")
TEXT_CTX = {"SetText", "AddLine", "AddDoubleLine", "Msg", "check", "check2", "hint", "headerCol", "button",
            "choice", "label=", "group", "row", "text=", "title=", "tip=", "desc="}
CODE_SKIP = {"GuildGames.lua", "ProfessionGuild.lua", "VersionCheck.lua", "QuestShare.lua"}   # wire, parsing
PROSE = [("pets", "Data/HunterPets.lua", {"desc=", "effect=", "why=", "note="}, True),
         ("boss", "Data/Dungeons/*.lua", {"description="}, False),
         ("summary", "Data/DungeonKeys.lua", {"summary="}, False),
         ("summary", "Data/RaidAttunements.lua", {"summary="}, False),
         ("enchant", "Data/Enchants.lua", {"src="}, False)]
GAME_NAMES = re.compile(r"^[^—]+ — [^—]+$")      # "<NPC> — <zone>" labels: game names (UALL Forever, ClassicUA)
TILE = re.compile(r'\btile\(\s*\d+\s*,\s*L\["((?:[^"\\]|\\.)*)"\]')
COLON_KEYS = ["Trade supplies vendors sell these (in every big city):"]
DERIVED = {}       # derived English -> (base key, "upper" | "colon"); filled by source()


def addon_dir(arg=None):
    return LL.addon_dir(arg, FOLDER)


def version(addon):
    return LL.toc_version(addon, TOC)


def lua_unesc(s):
    return re.sub(r'\\(["\\nt])', lambda m: {"n": "\n", "t": "\t"}.get(m.group(1), m.group(1)), s)


def locale_keys(path):
    """[(english, section, line)] of one locale file, in file order."""
    out, section = [], "general"
    for i, line in enumerate(Path(path).read_text(encoding="utf-8", errors="replace").split("\n"), 1):
        m = KEY_LINE.match(line)
        if m:
            out.append((lua_unesc(m.group(1)), section, i))
            continue
        m = SECTION.match(line)
        if m and not line.strip().startswith("---"):
            section = m.group(1)[:60]
    return out


def lnum_key(text):
    """The key FLT.LNum looks up for `text`: % doubled, each number a %s (a trailing full stop kept outside)."""
    def one(m):
        s = m.group(0)
        return "%s." if s.endswith(".") else "%s"
    return re.sub(r"\d[\d.]*", one, text.replace("%", "%%"))


def code_files(addon):
    for p in sorted(list(addon.glob("*.lua")) + list(addon.glob("UI/*.lua"))):
        if p.name not in CODE_SKIP:
            yield p


def source(addon):
    """(rows, why). rows: [key, English, batch, [(file, line)], note] in batch order; why: {reason: count}."""
    addon = Path(addon)
    if not (addon / TOC).is_file():
        return [], {}
    found, why, groups = {}, {}, []
    R.NUMBERED.clear()
    DERIVED.clear()

    def add(en, place, note, pool):
        kept, reason = R.keep(en, pool)
        if not kept:
            why[reason] = why.get(reason, 0) + 1
            return None
        key = "Code." + H.djb2(en)
        if key in found:
            found[key][3].append(place)
            return None
        found[key] = [key, en, 0, [place], note]
        return found[key]

    de = addon / "Locales" / "deDE.lua"
    sections = {}
    for en, section, line in locale_keys(de) if de.is_file() else []:
        if "LNum" in section and K.SLOT.search(en.replace("%%", "")):
            R.NUMBERED.add(en)                   # a data sentence drawn through FLT.LNum: each %s is a number
        r = add(en, ("Locales/deDE.lua", line), "L: " + section, "L")
        if r:
            sections.setdefault(section, []).append(r)
    for section, rows in sections.items():
        groups.append((section, "L", rows))

    for pool, pattern, fields, numbered in PROSE:
        rows = []
        for p in sorted(addon.glob(pattern)):
            for en, line, _, ctx in LL.literals(p):
                if ctx not in fields:
                    continue
                text = lnum_key(en) if numbered else en
                rel = p.relative_to(addon).as_posix()
                if numbered and K.SLOT.search(text.replace("%%", "")):
                    R.NUMBERED.add(text)         # also when the sentence is an L key already
                r = add(text, (rel, line), R.POOL_NOTE[pool], pool)
                if r:
                    rows.append(r)
        groups.append((pool, pool, rows))

    rows = []
    for p in code_files(addon):
        rel = p.relative_to(addon).as_posix()
        for en, line, left, ctx in LL.literals(p):
            if left:
                why[left.split(" ")[0]] = why.get(left.split(" ")[0], 0) + 1
                continue
            if ctx not in TEXT_CTX:
                why["not a text call"] = why.get("not a text call", 0) + 1
                continue
            if GAME_NAMES.match(en):
                why["game names"] = why.get("game names", 0) + 1
                continue
            if not re.match(r"[A-Za-z0-9|%(]", en):
                why["a glued piece"] = why.get("a glued piece", 0) + 1
                continue
            r = add(en, (rel, line), R.POOL_NOTE["code"] + f" ({ctx})", "code")
            if r:
                rows.append(r)
    for en in ("Close", "AM", "PM"):          # game globals CLOSE, TIMEMANAGER_AM/PM shown on its frames
        r = add(en, ("(game global)", 0), "a game global it shows on its own frames (never written)", "L")
        if r:
            rows.append(r)
    groups.append(("code literals", "code", rows))

    sk = addon / "UI" / "SkillUpUI.lua"
    if sk.is_file():
        for en in TILE.findall(sk.read_text(encoding="utf-8", errors="replace")):
            en = lua_unesc(en)
            DERIVED[UI_upper(en)] = ("Code." + H.djb2(en), "upper")
    for en in COLON_KEYS:
        DERIVED[en[:-1] + "."] = ("Code." + H.djb2(en), "colon")
    return R.split(groups), why


def UI_upper(s):
    """OneForAll's UI.Upper (Widgets.lua): ASCII upper case and Latin-1 accents."""
    return "".join(c.upper() if ord(c) < 128 or "à" <= c <= "þ" else c for c in s)


if __name__ == "__main__":
    a = addon_dir(sys.argv[2] if len(sys.argv) > 2 else None)
    if len(sys.argv) > 1 and sys.argv[1] == "all":
        for p in code_files(a):
            for en, line, left, ctx in LL.literals(p):
                print(f"{p.name}:{line}\t{ctx or '-'}\t{left or 'kept?'}\t{en[:80]!r}")
    else:
        rows, why = source(a)
        for key, en, b, places, note in rows:
            print(f"{b:02d}\t{key}\t{places[0][0]}:{places[0][1]}\t{note}\t{en[:80]!r}")
        print(why)
