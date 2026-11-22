"""Saved name caches never freeze words found without ClassicUA (docs/LESSONS4.md lesson 40).

1. Every module file that keeps a saved name cache (`db.cache = { sig = ... }`) builds its signature with
   `ProviderSig()` and saves no task marked `unsaved` or `partial`.
2. The core runner (UADD/Collector.lua) asks nothing while ClassicUA is not settled (`C.Settled()` before the
   lookup), marks a task unsaved when the name sources changed while it ran (`job.psig`), and uall_cua.lua
   exports `Settled`.
3. The Dungeon Journal collects once more when the signature changed by the end of a collection.
The mutant tests take each fix out (in memory) and want the check to fail.

python3 -m unittest tools.test_name_caches
"""
import glob
import os
import re
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)

SAVES = re.compile(r"db\.cache\s*=\s*\{\s*sig\s*=")
SIG_FN = re.compile(r"function\s+\w+\.Signature\s*\(\).*?\nend", re.S)
KEEPS = re.compile(r"if\s+task\.partial\s+then.*?elseif\s+not\s+task\.unsaved\s+then\s+job\.cache\[", re.S)


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def code(text):
    """Lua without its comments, so a fix named only in a comment does not count."""
    text = re.sub(r"--\[(=*)\[.*?\]\1\]", "", text, flags=re.S)
    return re.sub(r"--[^\n]*", "", text)


def cache_files():
    return sorted(p for p in glob.glob(os.path.join(REPO, "UADD_*", "*.lua")) if SAVES.search(code(read(p))))


def cache_problems(name, text):
    text = code(text)
    out = []
    sig = SIG_FN.search(text)
    if not sig or "ProviderSig" not in sig.group(0):
        out.append(f"{name}: its Signature() does not add ProviderSig()")
    if not KEEPS.search(text):
        out.append(f"{name}: a task marked partial or unsaved can be saved")
    return out


def collector_problems(text):
    text = code(text)
    out = []
    if not re.search(r"if\s+C\.Settled\(\)\s+then\s+ok\s*,\s*key\s*,\s*uk\s*,\s*wait\s*=\s*pcall\(task\.lookup", text):
        out.append("Collector.lua: the lookup is not gated by C.Settled()")
    if not re.search(r"C\.ProviderSig\(\)\s*~=\s*job\.psig\s+then\s+task\.unsaved\s*=\s*true", text):
        out.append("Collector.lua: a task is not marked unsaved when the name sources changed")
    if not re.search(r"j\.psig\s*=\s*1\s*,\s*0\s*,\s*0\s*,\s*C\.ProviderSig\(\)|j\.psig\s*=\s*C\.ProviderSig\(\)", text):
        out.append("Collector.lua: Start does not note the name sources (job.psig)")
    return out


def cua_problems(text):
    text = code(text)
    return [] if re.search(r"U\.cua\s*=\s*\{[^}]*\bSettled\s*=", text, re.S) else \
        ["uall_cua.lua: U.cua has no Settled"]


def dj_problems(text):
    text = code(text)
    ok = re.search(r"db\.cache\.sig\s*~=\s*sig", text) and re.search(r"C_Timer\.After\([^\n]*Collect", text) \
        and re.search(r"N\.Start\(\s*db\s*,\s*all\s*,\s*Done\s*\)", text)
    return [] if ok else ["UADD_DungeonJournal/Module.lua: no new collection when the signature changed"]


COLLECTOR = os.path.join(REPO, "UADD", "Collector.lua")
CUA = os.path.join(REPO, "UADD", "uall_cua.lua")
DJ = os.path.join(REPO, "UADD_DungeonJournal", "Module.lua")


class NameCaches(unittest.TestCase):
    def test_some_caches_found(self):
        names = [os.path.basename(os.path.dirname(p)) for p in cache_files()]
        for m in ("UADD_DungeonJournal", "UADD_Questie", "UADD_Attune"):
            self.assertIn(m, names)

    def test_caches_sign_their_sources(self):
        probs = [x for p in cache_files() for x in cache_problems(os.path.relpath(p, REPO), read(p))]
        self.assertEqual(probs, [])

    def test_collector_waits_and_marks(self):
        self.assertEqual(collector_problems(read(COLLECTOR)) + cua_problems(read(CUA)), [])

    def test_dj_collects_again(self):
        self.assertEqual(dj_problems(read(DJ)), [])


class Mutants(unittest.TestCase):
    def test_signature_without_sources(self):
        p = os.path.join(REPO, "UADD_Questie", "Names.lua")
        text = read(p).replace("ProviderSig", "Provider" + "Gone")
        self.assertTrue(cache_problems("q", text))

    def test_saves_unsaved(self):
        p = os.path.join(REPO, "UADD_Attune", "Names.lua")
        text = read(p).replace("elseif not task.unsaved then", "else")
        self.assertTrue(cache_problems("a", text))

    def test_no_settle_wait(self):
        text = read(COLLECTOR).replace("if C.Settled() then", "if true then")
        self.assertTrue(collector_problems(text))

    def test_no_psig_compare(self):
        text = read(COLLECTOR).replace("~= job.psig then", "~= nil and false then")
        self.assertTrue(collector_problems(text))

    def test_settled_only_in_comment(self):
        text = re.sub(r"Settled\s*=\s*function", "-- Settled = function", read(CUA))
        self.assertTrue(cua_problems(text))

    def test_dj_no_rerun(self):
        text = read(DJ).replace("C_Timer.After(1, function() if db and db.enabled then U.SafeCall(Collect",
                                "(function() if db and db.enabled then U.SafeCall(Collect")
        self.assertTrue(dj_problems(text))


if __name__ == "__main__":
    unittest.main()
