"""Name matching for make_dj_prose.py: which UALLF names a text holds. The rules that turn a
name into a placeholder are in dj_prose_src.py. Split out of make_dj_prose.py."""
import re
from pathlib import Path

ADDONS = Path("/mnt/c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns")
UALLF_DIR = ADDONS / "UALLF"

ZONE_SKIP = {"Horde", "Alliance"}

KEY_RE = re.compile(r'^\s*\["((?:[^"\\]|\\.)*)"\]\s*=', re.M)
ID_RE = re.compile(r'^\s*\[(\d+)\]\s*=', re.M)


def uallf_keys(name, id_keys=False):
    text = (UALLF_DIR / name).read_text("utf-8", "replace")
    if id_keys:
        return {int(m) for m in ID_RE.findall(text)}
    return {re.sub(r'\\(.)', r'\1', m) for m in KEY_RE.findall(text)}


def uallf_quest_titles():
    """English quest title -> id: UALLF keys questTitles by English and quests by id, both with
    the Ukrainian title; joined on it (the lowest id where Horde and Alliance share a title)."""
    text = (UALLF_DIR / "Quests.lua").read_text("utf-8", "replace")
    by_uk, s = {}, r'"((?:[^"\\]|\\.)*)"'
    for qid, uk in re.findall(r'^\s*\[(\d+)\] = \{.*?\btitle = ' + s, text, re.M):
        by_uk.setdefault(uk, []).append(int(qid))
    pairs = re.findall(r'^\s*\[' + s + r'\] = ' + s, text[text.find("ns.questTitles"):], re.M)
    return {re.sub(r'\\(.)', r'\1', en): min(by_uk[uk]) for en, uk in pairs if by_uk.get(uk)}


def person(s):
    head = s.split(",")[0].strip()
    if head and head[0].isupper() and not any(c in head for c in ":(") and " the " not in head:
        return head
    return None


def places(s):
    return [p.strip() for p in s.split(",")[1:] if p.strip()]


class Names:
    """English name -> (kind, id) for NPCs, items and zones UALLF has;
    quest titles are kept apart and only used where the text marks a quest."""

    def __init__(self):
        self.npcs = uallf_keys("NpcNames.lua")
        self.items = uallf_keys("Items.lua")
        self.zones = uallf_keys("World.lua")
        self.quest_ids = uallf_keys("Quests.lua", id_keys=True)
        self.known = {}          # name -> (kind, id); npc / item / zone only
        self.quests = {}         # quest title -> id, only ids UALLF has
        self.titles = set()      # every FDJ quest title (UALLF or not)
        self.missing = {}        # name -> kind  (FDJ name UALLF lacks)
        self.other_seen = set()  # names FDJ uses as NPC / place / item

    def add(self, kind, name, ident=None):
        if not isinstance(name, str):
            return
        name = name.strip()
        if len(name) < 3:
            return
        have = {"npc": self.npcs, "item": self.items, "zone": self.zones}
        if kind == "quest":
            self.titles.add(name)
            if ident in self.quest_ids:
                self.quests.setdefault(name, ident)
            else:
                self.missing.setdefault(name, kind)
            # A title that is also an NPC / place / item name reads as that thing when no quest is meant.
            for other, pool in (("npc", self.npcs), ("zone", self.zones), ("item", self.items)):
                if name in pool and name not in self.known:
                    self.known[name] = (other, None)
                    break
            return
        self.other_seen.add(name)
        if name in self.known:
            return
        if name in have[kind]:
            self.known[name] = (kind, ident)
            self.missing.pop(name, None)
        else:
            self.missing.setdefault(name, kind)

    def singular(self, run):
        """'Red Silk Bandanas' -> ('item', 'Red Silk Bandana') when UALLF has the singular."""
        def forms(w):
            out = [w[:-3] + "man"] if w.endswith("men") else []
            if w.endswith("ies"):
                out.append(w[:-3] + "y")
            if w.endswith("es"):
                out.append(w[:-2])
            if w.endswith("s") and not w.endswith("ss"):
                out.append(w[:-1])
            return out
        words = run.split(" ")
        tries = [" ".join(words[:-1] + [f]) for f in forms(words[-1])]
        if "of" in words[1:]:
            k = words.index("of")
            tries += [" ".join(words[:k - 1] + [f] + words[k:]) for f in forms(words[k - 1])]
        for t in tries:
            for kind, pool in (("item", self.items), ("npc", self.npcs)):
                if t in pool:
                    return kind, t
        return None

    def pure_title(self, t):
        """A quest title that is not also the name of an NPC, item or place."""
        if t in self.known or t in self.other_seen:
            return False
        core = t[4:] if t.startswith("The ") else t
        if core in self.known or core in self.other_seen or self.singular(t):
            return False
        return True

    def is_name(self, s):
        """Is s (or s without a leading "The ") a known name, quest title or seen name?"""
        for t in (s, s[4:] if s.startswith("The ") else None):
            if t and (t in self.known or t in self.titles or t in self.other_seen):
                return True
        return False

    def add_uallf_extras(self):
        # Zones straight from UALLF; multi-word Title Case NPCs/items too.
        title = re.compile(r"^[A-Z][\w'-]*( (of|the|de|von|[A-Z][\w'-]*))+$")
        for z in self.zones:
            # Skip faction words, lower-case keys, and "Auberdine, Darkshore" pairs (parts match alone).
            pair = z.split(", ")
            if len(pair) == 2 and all(p in self.zones for p in pair):
                continue
            if len(z) >= 4 and z[0].isupper() and z not in ZONE_SKIP and z not in self.known:
                self.known[z] = ("zone", None)
        # Quest titles FDJ does not list ("Delivery to Ridgewell"), by their UALLF id.
        for t, qid in uallf_quest_titles().items():
            if t not in self.titles:
                self.titles.add(t)
                self.quests[t] = qid
        for kind, pool in (("npc", self.npcs), ("item", self.items)):
            for n in pool:
                if n not in self.known and title.match(n):
                    self.known[n] = (kind, None)

    def index(self):
        """First 3 letters -> candidate names (titles and known names), longest first."""
        idx = {}
        for n in set(self.known) | self.titles:
            idx.setdefault(n[:3], []).append(n)
        for lst in idx.values():
            lst.sort(key=len, reverse=True)
        self.idx = idx
