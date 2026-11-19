"""The texts flow_whatstraining.py feeds the What's Training? stand-in: its English read from the installed
addon (tools/make_wt_text.py source), what the module ships (UADD_WhatsTraining/data), real texts picked
for each path, and the templates for the half-translation check (halves_mods.wt).
"""
import os
import re
import sys

import session
from halves import tpl
from halves_cover import kinds

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import hashtext  # noqa: E402

MODULE = "UADD_WhatsTraining"
DATA = os.path.join(session.REPO, MODULE, "data")
CYR = re.compile(r"[Ѐ-ӿ]")
NAME = "Quix"
ROLES = ("label", "colour", "spaces", "button", "button2", "long", "later", "later2", "tip", "tip2", "tip3",
         "own", "own2", "chat")


def module_there():
    return os.path.isfile(os.path.join(session.REPO, MODULE, MODULE + ".toc"))


def shipped():
    """(exact keys {key: uk}, templates {id: [sort letters]}) parsed from the module's data files."""
    exact, temps = {}, {}
    for name in sorted(os.listdir(DATA)):
        with open(os.path.join(DATA, name), encoding="utf-8") as f:
            for line in f:
                m = re.match(r'E\["([^"]+)"\] = "(.*)"$', line.rstrip("\n"))
                if m:
                    exact[m.group(1)] = m.group(2)
                m = re.match(r'T\[#T \+ 1\] = \{ id = "([^"]+)".*sort = \{([^}]*)\}', line)
                if m:
                    temps[m.group(1)] = re.findall(r'"(\w)"', m.group(2))
    return exact, temps


def rows():
    """What's Training?'s English: [(en, kind)], or [] when it is not installed."""
    try:
        import make_wt_text as mk
        d = mk.addon_dir()
        if not os.path.isdir(d):
            return []
        return [(en, kind) for en, kind, _, _, _ in mk.source(d)[0]]
    except Exception:
        return []


def title(exact):
    """The main window's title (its locale key TAB_TEXT) from the installed addon, when we ship Cyrillic
    Ukrainian for it; else None."""
    try:
        import make_wt_text as mk
        names = mk.source(mk.addon_dir())[1]
    except Exception:
        return None
    en = next((e for e, k in names.items() if k == "TAB_TEXT"), None)
    return en if en and CYR.search(exact.get(hashtext.key(en), "")) else None


def picks(src, exact, temps):
    """Real texts for each path: single-line English we ship Cyrillic Ukrainian for (reused across the
    paths when there are few); a template of numbers only, when one is shipped. None: nothing shipped."""
    def ours(en):
        uk = exact.get(hashtext.key(en), "")
        return CYR.search(uk) and "{" not in uk
    plain = sorted({en for en, kind in src if kind == "exact" and "|" not in en and "%" not in en
                    and en == en.strip() and ours(en)}, key=lambda e: (len(e), e))
    if not plain:
        return None
    short = [e for e in plain if len(e) <= 40] or plain
    p = {role: short[i % len(short)] for i, role in enumerate(ROLES)}
    p["long"] = plain[-1]
    tpl_ = [en for en, kind in src if kind == "template" and hashtext.key(en) in temps
            and set(kinds(en)) == {"d"} and set(temps[hashtext.key(en)]) == {"v"}
            and "|" not in en and len(en) < 80]
    p["tpl"] = tpl_[0] if tpl_ else None
    p["n"] = len(plain)
    return p


def templates(src, temps):
    """The half-translation check's templates: each shipped template line (a multi-line text's lines
    alone), real English. Slots by the data's sort (tools/wt_rules.py): n a game name (the made-up name
    UALL Forever "knows", flow_whatstraining.lua M.names), t our text, v a value; no free slots."""
    lines = {hashtext.key(x): x for en, kind in src if "template" in kind for x in en.split("\n")}
    return [tpl(k, x, {}, {i: NAME for i, s in enumerate(temps[k], 1) if s == "n"})
            for k, x in lines.items() if k in temps]
