"""Waypoint UI's texts for flow_wp.py, read from the installed Waypoint UI at test time (it has no licence file:
none of its English is committed). Which texts have our Ukrainian is read from UADD_WaypointUI/data/*.lua, so
the flow picks only shipped ones while translators are still at work."""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import hashtext  # noqa: E402
import make_wp_text  # noqa: E402
import wp_rules  # noqa: E402

MODULE = "UADD_WaypointUI"
REPO = make_wp_text.ROOT
SETTINGS = 4                    # rows its settings build on first show


def module_there():
    return (REPO / MODULE / f"{MODULE}.toc").is_file()


def rows():
    """[(English, locale key)] of the installed Waypoint UI; [] when it is not installed."""
    addon = make_wp_text.addon_dir()
    if not (addon / make_wp_text.LOCALE).is_file():
        return []
    return [(r[0], r[3]) for r in make_wp_text.source(addon)[0]]


def shipped():
    """({exact key: True when its Ukrainian is a plain string}, {template id: sorts}) in our data."""
    exact, temps = {}, {}
    for f in sorted((REPO / MODULE / "data").glob("*.lua")):
        s = f.read_text(encoding="utf-8")
        for m in re.finditer(r'^E\["([^"]+)"\] = (.)', s, re.M):
            exact[m.group(1)] = m.group(2) == '"'
        for m in re.finditer(r'id = "([^"]+)".*?sort = \{([^}]*)\}', s):
            temps[m.group(1)] = re.findall(r'"([^"]*)"', m.group(2))
    return exact, temps


def picks(src, exact, temps):
    """Real texts for each step, or None when too few are shipped. Plain one-line texts with a plain string
    in our data, shortest first; the replace prompts by their locale keys."""
    key = hashtext.key
    one = sorted({en for en, k in src if "%" not in en and "\n" not in en and exact.get(key(en))
                  and not wp_rules.stays(k) and len(en) < 50 and re.search("[A-Za-z]{3}", en)},
                 key=lambda x: (len(x), x))
    if len(one) < SETTINGS + 6:
        return None
    p = {"n": len(one), "settings": one[:SETTINGS]}
    p["tab"], p["button"], p["input"], p["grey"], p["nav"], p["info"] = one[SETTINGS:SETTINGS + 6]
    p["tab2"] = one[SETTINGS + 6] if len(one) > SETTINGS + 6 else p["tab"]
    p["prompts"] = [(key(en), en) for en, k in src if k.endswith("_REPLACEPROMPT") and key(en) in temps]
    p["capital"] = next((en for en in one if not re.search(r"\b[a-z]", en)), one[0])
    return p


def templates(src, temps, name):
    """The halves templates: every shipped template of the installed Waypoint UI, its slots by our data's
    sort (f free; v a value gets no made-up English)."""
    import halves
    out, seen = [], set()
    for en, _ in src:
        k = hashtext.key(en)
        if "%" not in en or k not in temps or k in seen:
            continue
        seen.add(k)
        out.append(halves.tpl(k, en, {i: name for i, x in enumerate(temps[k], 1) if x == "f"}))
    return out
