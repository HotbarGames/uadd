"""tools/drift.py's extraction for UADD_GearQuestForever (GearQuest Forever has no licence: all rights reserved, so
our data holds hashes only). The texts the generator would translate, from tools/gq_source.py: its locale keys
(L.<hash>) and its guide's whole pages (X.<hash>). Standard library only."""
import gq_source


def where_of(where):
    return where[0][0] if where else "built key"


def extract(path):
    rows = gq_source.source(path)[0] + gq_source.x_rows(path)[0]
    return [("L", key, en, where_of(where)) for key, en, _, where, _ in rows]
