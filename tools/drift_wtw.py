"""tools/drift.py's extraction for UADD_WhatTheWhisper (WhatTheWhisper has no licence file: all rights reserved, so
our data holds hashes only). The texts the generator would translate, from tools/wtw_source.py. Standard library only."""
import wtw_source


def extract(path):
    return [("L", key, en, live[0][0]) for key, en, _, live, _ in wtw_source.source(path)[0]]
