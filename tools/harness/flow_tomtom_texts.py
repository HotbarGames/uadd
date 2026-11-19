"""TomTom's texts for flow_tomtom.py, read from the installed TomTom at test time (TomTom is All Rights
Reserved: none of its English is committed). Which texts have our Ukrainian is read from
UADD_TomTom/data/*.lua, so the flow picks only shipped ones while translators are still at work."""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import hashtext  # noqa: E402
import make_tt_text  # noqa: E402
import tt_rules  # noqa: E402

MODULE = "UADD_TomTom"
REPO = make_tt_text.ROOT
# Templates each step needs, by id (length:hash of the English).
DIST = "13:125050c3"        # "%d ..." the distance, with a plural
DIST_S = "13:f092c972"      # "%s ..." the distance as a text (in TomTom.L ours)
COORDS = "15:cd6e0f70"      # "%s (%.2f, %.2f)": no word to find it by; Module.lua reads it by its shape
REMOVED = "28:882067da"     # a plural and a zone
LOCAL = "19:a8669b8c"       # /way local: indent (w), title, coords, map id (slash.lua:28)
ADDED = "51:0e87e895"       # "added a waypoint": title, " - ", coords as one group, then a zone
UNKNOWN = "16:765b3390"     # what TomTom puts for a waypoint with no title (stays English in L: keep list)
# Real sample values for value slots that hold a text, not a number (tools/tt_rules.py says what each holds).
SAMPLE = {"51:0e87e895": {2: " - ", 3: "41.50, 22.25"}, "52:88bde84b": {2: " - ", 3: "41.50, 22.25"}}
SETTINGS = ("page", "row", "tip", "text", "label", "button", "color", "colorTip")


def module_there():
    return (REPO / MODULE / f"{MODULE}.toc").is_file()


def rows():
    """[(en, kind, section, file)] of the installed TomTom; [] when it is not installed."""
    addon = make_tt_text.addon_dir()
    if not (addon / make_tt_text.LOCALE).is_file():
        return []
    src = make_tt_text.source(addon)
    src = src[0] if isinstance(src, tuple) else src
    return [(r[0], r[1], r[2], r[-1]) for r in src]


def shipped():
    """(exact keys, {template id: sorts}, keep keys) in our data."""
    exact, temps, keep = set(), {}, set()
    for f in sorted((REPO / MODULE / "data").glob("*.lua")):
        s = f.read_text(encoding="utf-8")
        exact |= set(re.findall(r'^E\["([^"]+)"\]', s, re.M))
        keep |= set(re.findall(r'^K\["([^"]+)"\]', s, re.M))
        for m in re.finditer(r'id = "([^"]+)".*?sort = \{([^}]*)\}', s):
            temps[m.group(1)] = re.findall(r'"([^"]*)"', m.group(2))   # a letter, or a group's recipe
    return exact, temps, keep


def popups():
    """{which: {field: en}} of TomTom's pop-ups whose fields are locale keys (text, button1, button2)."""
    addon, out = make_tt_text.addon_dir(), {}
    for p in sorted(addon.rglob("*.lua")):
        s = p.read_text(encoding="utf-8", errors="replace")
        for m in re.finditer(r'StaticPopupDialogs\[\s*"(\w+)"\s*\]\s*=\s*\{(.*?)\n\s*\}', s, re.S):
            fields = dict(re.findall(r'\b(text|button1|button2)\s*=\s*(?:[\w.]+\s+or\s+)?L\["([^"\\]+)"\]',
                                     m.group(2)))
            if fields:
                out[m.group(1)] = fields
    return out


def stay():
    """The locale keys TomTom's slash commands and its name use: never ours."""
    st = tt_rules.STAY
    return sorted(st if not isinstance(st, dict) else st.keys())


def picks(src, exact, temps, keep):
    """Real texts for each step: shipped exact texts of TomTom.L, a code text, the templates by id."""
    def key(en): return hashtext.key(en)  # noqa: E704
    loc = [en for en, _, sec, _ in src if sec == "enUS" and "%" not in en and "\n" not in en
           and key(en) in exact and key(en) not in keep and len(en) < 60]
    code = [en for en, _, sec, _ in src if sec != "enUS" and "%" not in en and key(en) in exact
            and key(en) not in keep]
    loc = sorted(set(loc), key=lambda x: (len(x), x))
    by_id = {key(en): en for en, _, _, _ in src if "%" in en}
    need = len(SETTINGS) + 5
    if len(loc) < need:
        return None
    p = {"n": len(loc), "L": loc[0]}
    p.update(zip(SETTINGS, loc[1:1 + len(SETTINGS)]))
    rest = loc[1 + len(SETTINGS):]
    p["late_page"], p["late_row"], p["paste_title"], p["paste_button"] = rest[:4]
    p["option"] = code[0] if code else rest[4] if len(rest) > 4 else p["L"]
    for name, tid in (("dist", DIST), ("dist_s", DIST_S), ("coords", COORDS), ("removed", REMOVED),
                      ("local", LOCAL), ("added", ADDED)):
        p[name] = by_id.get(tid) if tid in temps or tid == COORDS else None
    p["unknown"] = next((en for en, _, _, _ in src if key(en) == UNKNOWN), None)
    p["popups"] = {w: f for w, f in popups().items() if all(key(en) in exact for en in f.values())}
    p["stay"] = stay()
    p["t_good"] = loc[0]
    return p


def templates(src, temps, good_t, name):
    """The halves templates: every shipped template of the installed TomTom, its slots by our data's
    sort (f free, b blank, n a game name, t one of our texts, v a value). A w slot holds TomTom's own
    indent and nothing else (slash.lua), so it gets that, never made-up English, and no glued text."""
    import halves
    out, seen = [], set()
    for en, _, _, _ in src:
        k = hashtext.key(en)
        if "%" not in en or k not in temps or k in seen:
            continue
        seen.add(k)
        s = temps[k]
        def by(c, v): return {i: v for i, x in enumerate(s, 1) if x == c}  # noqa: E704,B023
        out.append(halves.tpl(k, en, {**by("f", name), **by("b", "s"), **by("w", "   ")},
                              {**by("n", name), **by("t", good_t), **SAMPLE.get(k, {})},
                              blank=set(by("b", 1)) | set(by("w", 1))))
    return out
