"""tools/drift.py's extraction for UADD_OneForAll (GPL-3.0-or-later; our data is keyed by hashes, so no tracked
English). The texts the generator would translate, from tools/ofa_source.py. Standard library only.
A text's place is its first place outside a news file (lesson 43, tools/news_texts.py)."""
import news_texts as N
import ofa_source


def where_of(where):
    return next((w[0] for w in where if not N.is_news(w[0])), where[0][0] if where else "built key")


def extract(path):
    return [("L", key, en, where_of(where)) for key, en, _, where, _ in ofa_source.source(path)[0]]
