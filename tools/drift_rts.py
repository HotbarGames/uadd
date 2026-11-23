"""tools/drift.py's extraction for UADD_RoadToSixty (Road to Sixty has no licence file: all rights reserved, so our
data holds hashes only). The texts the generator would translate, from tools/rts_source.py. Standard library only.
A text's place is its first place outside a news file (lesson 43, tools/news_texts.py)."""
import news_texts as N
import rts_source


def where_of(where):
    return next((w[0] for w in where if not N.is_news(w[0])), where[0][0] if where else "built key")


def extract(path):
    return [("L", key, en, where_of(where)) for key, en, _, where, _ in rts_source.source(path)[0]]
