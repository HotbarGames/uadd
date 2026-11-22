"""tools/drift.py's extraction for UADD_WowheadQuickLink (Wowhead Quick Link has no licence file: all rights reserved,
so our data holds hashes only). The texts the generator would translate, from tools/wql_source.py. Standard library
only."""
import wql_source


def extract(path):
    return [("L", key, en, (where[0][0] if where else "built key")) for key, en, _, where, _ in wql_source.source(path)[0]]
