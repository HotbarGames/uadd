"""tools/drift.py's extraction for UADD_DeleteCheapestItem (DeleteCheapestItem Reloaded's TOC says All Rights
Reserved, so our data holds hashes only). The texts the generator would translate, from tools/dci_source.py.
Standard library only."""
import dci_source


def extract(path):
    return [("L", key, en, (where[0][0] if where else "built key")) for key, en, _, where, _ in dci_source.source(path)[0]]
