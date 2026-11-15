"""Loads the real Dungeon Journal (with UALLF) and reads back the text it draws.

Usage: python3 tools/harness/flow_dj.py        (needs lupa and the Forever AddOns folder;
UADD_ADDONS_DIR overrides the folder, as for run.py)

`DJSession` is the part to build tests on: it starts a game with ForeverDungeonJournal and UALLF,
and offers texts(), plain_texts(), has(), open_dungeon(), set_tab(), quest_rows(), click_quest(),
switch_language() and the SetText log. `run()` plays the whole walk-through and returns
(checks, summary). Exit code 0 = all passed, 1 = a check failed, 2 = cannot run here.
"""
import collections
import json
import os
import re
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import loader  # noqa: E402
import session  # noqa: E402
from loader import Addon, Client, read_text, txt, lua_str  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
JOURNAL = "ForeverDungeonJournal"
FRAME = "ForeverDungeonJournalFrame"
ADDONS = ["UALLF", JOURNAL]          # the client loads them alphabetically
EXTRA_LUA = ["wow_api_dj.lua", "dj_load.lua"]

Check = collections.namedtuple("Check", "name ok detail")

_COLOR = re.compile(r"\|c[0-9a-fA-F]{8}|\|r|\|T.*?\|t|\|A.*?\|a|\|H.*?\|h|\|h")


def plain(s):
    """A text without colour codes, inline textures and hyperlink markup."""
    return _COLOR.sub("", s)


def missing_addons():
    d = session.addons_dir()
    return [n for n in ADDONS if not os.path.isdir(os.path.join(d, n))]


class DJSession:
    """One game session with the Dungeon Journal loaded and logged in."""

    def __init__(self, saved=None, locale="enUS", addons=None):
        """addons: a list of Addon in load order (default: UALLF and the journal from the game)."""
        d = session.addons_dir()
        addons = addons or [Addon(n, os.path.join(d, n), session.FLAVOR) for n in ADDONS]
        self.client = Client(addons, saved, locale)
        self.lua = self.client.lua
        for name in EXTRA_LUA:
            self.lua.execute(read_text(os.path.join(HERE, name)))
        self.H = self.client.H
        self.DJ = self.H.dj
        self.seen_errors = 0
        t0 = time.time()
        self.client.start()
        self.load_seconds = time.time() - t0
        self.pump(60)

    # ── plumbing ──────────────────────────────────────────────────────────────────────────────
    def pump(self, frames=30):
        self.H.pump(frames)

    def listing(self, t):
        return [t[i] for i in range(1, int(self.H.count(t)) + 1)]

    def new_errors(self):
        """Lua errors since the last call: list of (where, message)."""
        errs = self.client.errors()[self.seen_errors:]
        self.seen_errors += len(errs)
        return [(w, m) for w, m, _ in errs]

    def swallowed(self):
        """Errors the journal's own pcalls hid (usually a missing stub or a harness gap)."""
        return [txt(x) for x in self.listing(self.DJ.swallowed)]

    @property
    def chat(self):
        return self.client.chat()

    # ── widgets ───────────────────────────────────────────────────────────────────────────────
    def widget(self, name):
        return self.lua.globals()[name]

    @property
    def frame(self):
        return self.widget(FRAME)

    def is_open(self):
        f = self.frame
        return bool(f is not None and f.IsVisible(f))

    def click(self, widget, button="LeftButton", frames=30):
        self.DJ.click(widget, button)
        self.pump(frames)

    # ── reading text ──────────────────────────────────────────────────────────────────────────
    def texts(self, root=None):
        """All visible strings under `root` (a widget, or a global name; default the journal
        window), in creation order, as real text. Colour codes are kept."""
        if isinstance(root, str):
            root = self.widget(root)
        root = root if root is not None else self.frame
        return [txt(x) for x in self.listing(self.DJ.visible(root))]

    def plain_texts(self, root=None):
        return [plain(t) for t in self.texts(root)]

    def texts_at(self, root=None):
        """Like texts(), as (text, name of the nearest named frame) pairs."""
        if isinstance(root, str):
            root = self.widget(root)
        root = root if root is not None else self.frame
        return [(txt(e.text), e.at) for e in self.listing(self.DJ.visibleDetailed(root))]

    def has(self, text, root=None):
        """True when some visible string (colour codes removed) equals or contains `text`."""
        return any(text in t for t in self.plain_texts(root))

    def log_mark(self):
        return int(self.DJ.logMark())

    def log_since(self, mark):
        """Every non-empty text set by SetText / SetFormattedText since `mark`."""
        return [txt(x) for x in self.listing(self.DJ.logSince(mark))]

    # ── the journal ───────────────────────────────────────────────────────────────────────────
    def slash(self, msg=""):
        self.DJ.slash(msg)
        self.pump(40)

    def open_dungeon(self, shortcut="rfk"):
        """Opens the window on a dungeon page with the addon's own /dj shortcut."""
        self.slash(shortcut)

    def set_tab(self, name):
        """name: 'quests', 'bosses' or 'map'."""
        self.click(getattr(self.frame, name + "Tab"))

    def quest_rows(self):
        """The quest list: [{id, name, meta, shown, button}]"""
        out = []
        for r in self.listing(self.DJ.questRows()):
            out.append({"id": r.id, "name": txt(r.name), "meta": txt(r.meta), "shown": bool(r.shown), "button": r.button})
        return out

    def click_quest(self, name):
        for r in self.quest_rows():
            if r["name"] == name:
                self.click(r["button"])
                return True
        return False

    def language_labels(self):
        return [txt(o.label) for o in self.listing(self.DJ.languageOptions())]

    def current_language_label(self):
        return txt(self.DJ.selectedLanguageText())

    def switch_language(self, label):
        """Opens the dropdown and picks `label` ('English', 'Русский', ...)."""
        self.click(self.frame.languageSelectorButton)
        for o in self.listing(self.DJ.languageOptions()):
            if txt(o.label) == label:
                self.click(o.button)
                return True
        return False

    def saved_language(self):
        db = self.widget("ForeverDungeonJournalDB")
        return txt(db["language"]) if db is not None else None


def uniq(items):
    seen, out = set(), []
    for x in items:
        if x not in seen:
            seen.add(x)
            out.append(x)
    return out


def run():
    """Plays the walk-through. Returns (checks, summary dict)."""
    checks = []

    def check(name, ok, detail=""):
        checks.append(Check(name, bool(ok), detail))
        return bool(ok)

    s = DJSession()
    screens = {}

    def shot(name, **extra):
        screens[name] = {"texts": uniq(s.plain_texts()), **extra}

    errs = s.new_errors()
    check("loads without Lua errors", not errs, "; ".join(f"{w}: {m[:160]}" for w, m in errs[:3]))
    check("window frame and /dj command exist", s.frame is not None and s.lua.globals().SlashCmdList.FOREVERDUNGEONJOURNAL is not None)

    # 1. open with /dj (the toggle), close, open again on a dungeon page
    s.slash("")
    opened = s.is_open()
    check("/dj opens the window", opened)
    shot("home")
    s.slash("")
    check("/dj again closes it", not s.is_open())
    s.slash("rfk")
    check("/dj rfk opens the Razorfen Kraul page", s.is_open() and s.has("Razorfen Kraul"))

    # 2. bosses tab
    s.set_tab("bosses")
    bosses = uniq(s.plain_texts())
    shot("rfk_bosses")
    check("Bosses tab lists Charlga Razorflank", "Charlga Razorflank" in bosses)
    check("Bosses tab lists Roogug with his loot", "Roogug" in bosses and "Geomancer Headdress" in bosses)

    # 3. quest list
    s.set_tab("quests")
    rows = s.quest_rows()
    names = [r["name"] for r in rows]
    shot("rfk_quests", quest_rows=[{"id": r["id"], "name": r["name"], "meta": plain(r["meta"] or "")} for r in rows])
    check("quest list shows Blueleaf Tubers", "Blueleaf Tubers" in names, str(names))
    check("quest list has 5 rows", len([r for r in rows if r["shown"]]) == 5, str(len(rows)))

    # 4. one quest's detail
    before = set(s.plain_texts())
    target = next((n for n in names if n != "Blueleaf Tubers"), None)
    clicked = target is not None and s.click_quest(target)
    after = uniq(s.plain_texts())
    shot("rfk_quest_detail", quest=target)
    check("clicking a quest changes the detail page", clicked and set(after) != before and target in after, str(target))
    s.click_quest("Blueleaf Tubers")
    detail = uniq(s.plain_texts())
    shot("rfk_quest_detail_blueleaf", quest="Blueleaf Tubers")
    check("Blueleaf Tubers detail has its objective", any("Mebok Mizzyrix" in t for t in detail)
          and any("Objective" == t for t in detail))

    # 5. language dropdown
    labels = s.language_labels()
    check("language dropdown has 10 languages", len(labels) == 10 and "English" in labels and "Русский" in labels, str(labels))
    s.set_tab("bosses")
    en_bosses = uniq(s.plain_texts())
    mark = s.log_mark()
    switched = s.switch_language("Русский")
    ru = uniq(s.plain_texts())
    set_in_ru = uniq(s.log_since(mark))
    shot("rfk_bosses_ru", language=s.current_language_label(), saved=s.saved_language())
    check("switching to Русский changes the page", switched and ru != en_bosses
          and s.current_language_label() == "Русский" and s.saved_language() == "ruRU")
    check("SetText log records the redraw", len(set_in_ru) > 5, str(len(set_in_ru)))
    s.switch_language("English")
    back = uniq(s.plain_texts())
    shot("rfk_bosses_en_again", language=s.current_language_label(), saved=s.saved_language())
    check("switching back to English restores the texts", back == en_bosses, f"{len(back)} vs {len(en_bosses)}")

    errs = s.new_errors()
    check("no Lua errors while navigating", not errs, "; ".join(f"{w}: {m[:160]}" for w, m in errs[:3]))
    hidden = s.swallowed()
    check("no errors hidden by the addon's pcall", not hidden, "; ".join(h[:160] for h in hidden[:3]))

    summary = {
        "screens": screens,
        "stubs_added": [txt(x) for x in s.listing(s.H.djStubs)],
        "swallowed_errors": hidden,
        "load_seconds": round(s.load_seconds, 1),
    }
    return checks, summary


def main():
    if loader.lua_runtime() is None:
        print("cannot run: lupa is not installed (pip install lupa)")
        return 2
    missing = missing_addons()
    if missing:
        print("cannot run: missing addons: " + ", ".join(missing))
        return 2
    t0 = time.time()
    checks, summary = run()
    bad = [c for c in checks if not c.ok]
    for c in checks:
        print(("ok    " if c.ok else "FAIL  ") + c.name + (f"  [{c.detail}]" if c.detail else ""))
    print(json.dumps(summary, ensure_ascii=False, indent=1))
    print(f"{len(checks) - len(bad)}/{len(checks)} passed in {time.time() - t0:.0f} s")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
