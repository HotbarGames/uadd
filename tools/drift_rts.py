"""tools/drift.py's extraction for UADD_RoadToSixty (Road to Sixty has no licence file: all rights reserved, so our
data holds hashes only). The texts the generator would translate, from tools/rts_source.py. Standard library only."""
import rts_source


def extract(path):
    return [("L", key, en, (where[0][0] if where else "built key")) for key, en, _, where, _ in rts_source.source(path)[0]]
