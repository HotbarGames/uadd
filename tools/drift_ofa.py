"""tools/drift.py's extraction for UADD_OneForAll (GPL-3.0-or-later; our data is keyed by hashes, so no tracked
English). The texts the generator would translate, from tools/ofa_source.py. Standard library only."""
import ofa_source


def extract(path):
    return [("L", key, en, (where[0][0] if where else "built key")) for key, en, _, where, _ in ofa_source.source(path)[0]]
