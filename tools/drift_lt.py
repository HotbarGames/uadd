"""tools/drift.py's extraction for UADD_LootTriage (LootTriage has no licence file: all rights reserved, so our data
holds hashes only). The texts the generator would translate, from tools/lt_source.py (its What's New texts are
dropped there: lesson 43). Standard library only."""
import lt_source
import news_texts as N


def extract(path):
    return [("L", key, en, next((w[0] for w in where if not N.is_news(w[0])), where[0][0] if where else "built key"))
            for key, en, _, where, _ in lt_source.source(path)[0]]
