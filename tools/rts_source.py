"""Reads Road to Sixty's texts for UADD_RoadToSixty: a thin config over tools/lua_literals.py.

Road to Sixty is all rights reserved: nothing here names its English. v1 scope only (design section 12): the map
window, the History and Characters panel, the options, the minimap tooltip, the Stats screen, the prints and the
popups. Left out and English: the later parts (gear screens, friends, the pops, the per-kind journal lines),
diagnostics, the friends channel protocol, machine keys, and its What's New (lesson 43, tools/news_texts.py): the
frame, its entries (WhatsNewData.lua, never read) and its changelog print. WhatsNew.lua is read only for its /rts
help line (a Command line, shown with the other commands) and for texts it shares with another file.
`python3 tools/rts_source.py all` prints every literal of those files and why it is left out (for a look,
never into a tracked file); with no argument it prints the rows.
"""
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import hashtext as H  # noqa: E402
import lua_literals as LL  # noqa: E402
import news_texts as N  # noqa: E402
import rts_rules as R  # noqa: E402

FOLDER, TOC = "RoadToSixty", "RoadToSixty.toc"
# The v1 files in TOC order. Journal and FriendsPanel only inside INCLUDE.
V1 = ["Core.lua", "Map.lua", "Panel.lua", "Options.lua", "MinimapButton.lua", "WhatsNew.lua", "Screens.lua",
      "Style.lua", "StatsScreen.lua", "Range.lua", "LevelShot.lua", "Journal.lua", "LevelChat.lua",
      "FriendsPanel.lua"]
# Line ranges (first, last) left out: later parts, diagnostics, game globals, the sync lines.
EXCLUDE = {
    "Core.lua": [(160, 182), (393, 408)],       # error prints (diagnostics); the moved-journey login print
    "Map.lua": [(1058, 1072), (2712, 2732)],    # sync marks; performance diagnostics
    "Panel.lua": [(358, 412), (510, 680)],      # journal kinds and filters; per-kind lines (later)
    "Options.lua": [(176, 192)],                # diagnostics line
    "Style.lua": [(150, 180)],                  # journal kind keys
    "StatsScreen.lua": [(680, 705), (1605, 1735)],   # equipment slot names (game globals); the Life page (later)
}
INCLUDE = {"Journal.lua": [(758, 780)], "FriendsPanel.lua": [(15, 30)]}     # /rts stats; the remove-friend popup


def addon_dir(arg=None):
    return LL.addon_dir(arg, FOLDER)


def version(addon):
    return LL.toc_version(addon, TOC)


def wanted(f, line):
    inc = INCLUDE.get(f)
    if inc is not None and not any(a <= line <= b for a, b in inc):
        return False
    return not any(a <= line <= b for a, b in EXCLUDE.get(f, []))


def source(addon):
    """(rows, why). rows: (key, English, batch, [(file, line)], note) in batch order; why: {reason: count}."""
    addon = Path(addon)
    if not (addon / TOC).is_file():
        return [], {}
    found, why, helps = {}, {}, set()
    for f in V1:
        if not (addon / f).is_file():
            continue
        for en, line, left, ctx in LL.literals(addon / f):
            key = "Code." + H.djb2(en)
            if not wanted(f, line):
                reason = "outside v1"
            else:
                kept, reason = (False, left.split(" ")[0]) if left else R.keep(key, en, ctx)
                if kept:
                    if N.is_news(f) and ctx == "Command":
                        helps.add(key)           # a /rts help line that opens the news: ours, like the others
                    if key in found:
                        found[key][3].append((f, line))
                    else:
                        found[key] = [key, en, R.batch_of(f), [(f, line)], R.note(key, f, ctx)]
                    continue
            why[reason] = why.get(reason, 0) + 1
    rows = [r for r in found.values() if r[0] in helps or not N.news_only(r[3])]
    if len(rows) < len(found):
        why["news (What's New)"] = len(found) - len(rows)
    return R.split(sorted(rows, key=lambda r: r[2])), why


if __name__ == "__main__":
    a = addon_dir(sys.argv[2] if len(sys.argv) > 2 else None)
    if len(sys.argv) > 1 and sys.argv[1] == "all":
        for f in V1:
            for en, line, left, ctx in LL.literals(a / f):
                print(f, line, H.djb2(en), left or ("KEEP" if wanted(f, line) else "outside"), ctx, repr(en)[:90])
    else:
        rs, w = source(a)
        for r in rs:
            print(r[2], r[0], repr(r[1])[:80], r[3][:2], r[4][:40])
        print(w)
