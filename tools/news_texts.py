"""What's New, News and changelog texts: UADD never translates them (lesson 43, docs/LESSONS4.md).

Our update always comes after the addon's, so players have seen its news in English already, and each news line
would cost drift work on every update for nothing. So these texts stay the addon's own English (on, held, off),
the extractors and generators leave them out, and drift does not list them.

  is_news(rel)       a file of the addon that holds only news (WhatsNew.lua, News.lua, Changelog.lua, ...)
  news_only(where)   a text whose every place [(file, line), ...] is in such a file
  drop(rows)         generator rows [key, English, batch, where, note] without the news-only ones
  news_row(mod, r)   a drift row (tag, key, English, where) of news: its file, or a text in TEXTS
TEXTS: per module, texts outside a news file that only a news window or an update chat line shows. By English
for a licence-allowed addon, by the key our data uses (a hash) for the others: never another addon's English.
A label in another window that only opens the news ("What's new" in a menu) is not news: it stays ours.
A fixed one-line chat notice that a new version is out, or that the addon was updated to X, is not news either:
it tells no changes, so it stays ours (KEEP), also when the addon keeps it in its news file.
Standard library only.
"""
import re

FILE = re.compile(r"(?i)(?:^|/)(?:whats?_?new[^/]*|news|changelog[^/]*)\.(?:lua|xml)$")

TEXTS = {
    "UADD_ForeverQuestPins": {"What is new in %s:"},                    # its login header, in Setup.lua (GPL-3.0)
}
# KEEP: per module, texts that sit in a news file but show elsewhere (or are a one-line update notice), so they
# stay ours and drift lists them. By key, or by English for a licence-allowed addon, as in TEXTS.
KEEP = {
    "UADD_RoadToSixty": {"Code.77d053bb"},                              # its /rts help line that opens the news
    # its two update chat lines, printed from Map/News.lua (MIT)
    "UADD_OpenMap": {"Updated to %s: see What's new in the OpenMap menu.",
                     "OpenMap %s is out (you have %s). Update through CurseForge."},
}


def is_news(rel):
    return bool(rel) and bool(FILE.search(str(rel)))


def news_only(where):
    return bool(where) and all(is_news(w[0]) for w in where)


def drop(rows):
    return [r for r in rows if not news_only(r[3])]


def news_row(mod, row):
    tag, key, en, where = row[:4]
    kept = KEEP.get(mod, ())
    if tag == "!" or en in kept or (key is not None and key in kept):
        return False
    names = TEXTS.get(mod, ())
    return is_news(where) or en in names or (key is not None and key in names)
