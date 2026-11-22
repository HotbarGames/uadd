"""tools/drift.py's extraction for UADD_BugSack (BugSack is All Rights Reserved, so our data holds hashes only).
The texts the generator would translate, from tools/bs_source.py. Standard library only."""
import bs_source


def extract(path):
    return [("L", key, en, (where[0][0] if where else "built key")) for key, en, _, where, _ in bs_source.source(path)[0]]
