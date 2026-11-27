"""What's New, News and changelog texts: UADD never translates them (lesson 43, docs/LESSONS4.md).

Our update always comes after the addon's, so players have seen its news in English already, and each news line
would cost drift work on every update for nothing. So these texts stay the addon's own English (on, held, off),
the extractors and generators leave them out, and drift does not list them.

  is_news(rel)       a file of the addon that holds only news (WhatsNew.lua, News.lua, Changelog.lua, ...)
  news_only(where)   a text whose every place [(file, line), ...] is in such a file
  drop(rows)         generator rows [key, English, batch, where, note] without the news-only ones
  news_row(mod, r)   a drift row (tag, key, English, where) of news: its file, or a text in TEXTS
TEXTS: per module, texts outside a news file that only a news window or an update chat line shows. By English
for a licence-allowed addon, by the key our data uses (a hash) for the others: never another addon's English.
A label in another window that only opens the news ("What's new" in a menu) is not news: it stays ours.
A fixed one-line chat notice that a new version is out, or that the addon was updated to X, is not news either:
it tells no changes, so it stays ours (KEEP), also when the addon keeps it in its news file.
Mastercraft keeps its news in the locale tables (Locales/ru.lua), under headings that say "What's new", and its
window in Help.lua (WHATS_NEW, /mc new): no news file by name. mc_news(rows, addon) finds them: a text under
such a heading that no other Mastercraft file (not Locales/, not Help.lua) also shows. TEXTS holds their keys
(hashtext.key of the English, as our data keys it) so drift, which has no headings, skips them too;
`python3 tools/news_texts.py mc-keys` prints the keys of the installed addon, and make_mc_text.py fails while
TEXTS lacks one.
Standard library only.
"""
import re
import sys
from pathlib import Path

FILE = re.compile(r"(?i)(?:^|/)(?:whats?_?new[^/]*|news|changelog[^/]*)\.(?:lua|xml)$")

# Modules whose TEXTS and KEEP are keys of the English (hashtext.key), matched also on a row's English.
HASHED = ("UADD_Mastercraft",)
MC_HEAD = re.compile(r"(?i)what'?s new|changelog")
MC_MIXED = ("Settings, What's new, error report, confirm",)    # a section of many topics: only its sub-headings count

# Mastercraft 2.1.3: keys (hashtext.key) of the texts mc_news finds; regenerate with `mc-keys`. Keys only: its
# English is all rights reserved and never goes in this repo.
MC_KEYS = """
    100:ff84ba3d 103:7e238482 104:ab374c99 106:fbc824bb 107:777f68de 107:90cc70d4
    107:e383903b 116:5667a53c 117:41969ebd 119:b809c383 119:c01d4ad5 11:7b8d0ffd
    121:42ff4719 122:a1330bd4 122:dda79e18 125:9c5b739b 125:e4c49c8c 129:25194a75
    12:08ad750a 130:4fd50651 131:5bf695b0 133:a5c41af3 134:1ffbd47a 134:f798ef9c
    138:394abd9a 13:f57c1145 140:a2a3b660 140:e1402c2f 142:68405c5a 143:df39cb03
    143:feef257e 144:48affb56 144:b534de49 147:0f60827f 147:5bf13047 147:775aa05f
    147:cc08e8d3 148:4a565954 148:87b3173f 149:af2480c9 14:6a9ce763 14:71549482
    14:c7c8fcd9 150:0eb9ed7f 151:459907d0 151:f2a2460b 152:027516e4 153:56213435
    153:564d42b2 153:e9f7b537 154:0eafbdf4 154:936bebec 156:dff31bc9 157:67ca7d41
    157:e40f2c97 159:4267a9aa 15:10578155 15:10cdb7fa 15:326bf56f 15:36b70853
    160:5b47c4bc 162:00e44cd6 162:4ed9e9b3 162:68cbeced 162:f1e40133 164:75f5c042
    164:b93e2e44 169:3b2011aa 16:05117fcd 16:72471091 16:78ff7868 16:a5db92cf
    16:bbf357fe 171:03e9e974 171:609702f9 171:d5a48b83 172:71d3de8f 172:886945f3
    174:077057a9 174:474d5a96 175:cf383e2e 176:9b14c0e9 177:428c4f3e 177:8336fb76
    178:bcd8389a 179:a5850ebf 17:6bd0c2b1 17:7ab57e71 180:a892d025 180:ade3970b
    182:d3383bd4 186:18fb8b48 186:2d6eb06d 187:0317fd92 187:3a509e35 189:b4a67d80
    189:d5bc17e2 18:0826a73e 18:1014e58b 18:60e4e1b4 18:8538caf9 18:9cb41406
    18:a9ec225f 18:be11ff1b 18:c7c29570 18:d10d5f12 191:5e1d5a58 192:c604a615
    193:0bcc0001 193:68753118 194:5aa6881c 194:afcb396c 194:d7dacabd 197:6a23e133
    199:07db4827 199:d6edf23e 19:841a60ea 19:a330b889 200:7c9a959e 202:8d579666
    206:660ea668 209:8cfbf95f 20:0445afdd 20:3a58769a 20:44ca2c4c 20:52662cac
    20:608b7a7c 20:8121b85a 20:e5242020 210:e1b03b3c 216:cc831241 217:da730489
    218:9fa38d00 219:2d9842b5 21:7192c995 21:a7ac395a 222:0dd389cf 224:c5f70f57
    225:c88c3a25 226:e1b6836c 228:5b720ac1 22:28e81b23 22:4f5fad68 22:55edad58
    22:5834a5da 22:9d021cd4 22:d82ae840 22:f4c087d0 230:c4d68fad 230:f6872c14
    23:13549031 23:1e9f44b0 23:6c84ee00 23:7de753ab 23:84fa0df8 23:b39a0f63
    23:d7246b71 23:ef7c6967 23:f45b08fa 241:f6dadfee 249:4c0bdac7 24:3ac52d23
    24:603e0f44 24:6caf3d55 24:9f59a226 24:e8f04f38 24:f1de71c0 24:fc8161f3
    254:0abbc00e 256:84ee82a3 25:0b337535 25:37a611b6 25:7a0c2c43 25:b39320b2
    25:c5502551 262:3f9f5a59 265:7fd27bdc 265:b8b6b6e6 268:d1203557 26:0fb1bba9
    26:0fdf82fa 26:10a0512d 26:2b88bf1d 26:371354a8 26:3aa47d4b 26:5976d00e
    26:89089048 26:ee57e4e7 275:859b4c93 275:ef70c15f 276:cbbaf064 27:4610f09a
    27:7a5ce31d 27:8c4ea9ad 27:ed134011 27:fc8291d1 285:4e735b86 289:bcfd5216
    28:0efd9852 28:32ddf6b6 28:4590833e 28:5175f44d 28:880e6d2a 28:9aa63da4
    28:a64c28b1 28:f8c05fa8 290:5ee824cc 290:eabe11ca 291:1342644c 29:ce048316
    29:e6691e84 29:ece3b6b1 29:fdccce5b 30:131e17b4 30:9d60b636 30:fb9fb1ed
    314:0e749cb3 31:aec2296f 32:754ed31d 32:828a35de 32:c8106202 330:031aa649
    33:79819b55 33:fd592867 34:24cd80b3 35:64856479 35:cb9db41a 35:fa8949ac
    369:6adb0849 36:4efa5b39 36:80346ab2 36:8eaf3994 39:c88a9963 44:f12fe122
    44:f334b869 53:637fe955 54:f87a0a08 58:d8a47478 5:0d2d5324 60:d1570092
    65:6c62b2b9 65:d3e71ff9 65:dcc2995c 66:058b0121 73:f7c6881a 75:418543ce
    75:ace380f0 79:ae4cbe08 7:14ff1d25 82:e0275da6 84:886d8902 84:9ccc506e
    89:b14b76e5 8:05fa0083 8:323b4a83 93:c72699cd 95:eb6692d5 96:510326d3
"""

TEXTS = {
    "UADD_ForeverQuestPins": {"What is new in %s:"},                    # its login header, in Setup.lua (GPL-3.0)
    "UADD_Mastercraft": set(MC_KEYS.split()),                           # its What's New texts, by key (Help.lua, /mc new)
}
# KEEP: per module, texts that sit in a news file but show elsewhere (or are a one-line update notice), so they
# stay ours and drift lists them. By key, or by English for a licence-allowed addon, as in TEXTS.
KEEP = {
    "UADD_RoadToSixty": {"Code.77d053bb"},                              # its /rts help line that opens the news
    # its two update chat lines, printed from Map/News.lua (MIT)
    "UADD_OpenMap": {"Updated to %s: see What's new in the OpenMap menu.",
                     "OpenMap %s is out (you have %s). Update through CurseForge."},
}


def is_news(rel):
    return bool(rel) and bool(FILE.search(str(rel)))


def news_only(where):
    return bool(where) and all(is_news(w[0]) for w in where)


def drop(rows):
    return [r for r in rows if not news_only(r[3])]


def news_row(mod, row):
    tag, key, en, where = row[:4]
    kept = KEEP.get(mod, ())
    names = TEXTS.get(mod, ())
    hk = None
    if mod in HASHED:
        import hashtext
        hk = hashtext.key(en)
    if tag == "!" or en in kept or (key is not None and key in kept) or (hk is not None and hk in kept):
        return False
    return (is_news(where) or en in names or (key is not None and key in names)
            or (hk is not None and hk in names))


_PIECE = re.compile(r"%[-+ #0-9.$]*[a-zA-Z]|\|n|\|c[0-9a-fA-F]{8}|\|r|\\n|\n")


def _mc_code(addon):
    """Mastercraft's Lua outside Locales/ and Help.lua (the news window), quotes unescaped."""
    parts = []
    for p in sorted(Path(addon).rglob("*.lua")):
        rel = p.relative_to(addon).parts
        if "Locales" in rel or p.name == "Help.lua":
            continue
        parts.append(p.read_text(encoding="utf-8", errors="replace").replace('\\"', '"').replace("\\'", "'"))
    return "\n".join(parts)


def mc_news(rows, addon):
    """The English of the `rows` ((en, kind, section, sub, file) of tools/mc_text_lib.source) that only
    Mastercraft's news window shows: under a heading that says what's new or changelog, and no other file of
    the addon (not Locales/, not Help.lua) has the text as a literal. A text a settings page or tooltip also
    shows stays ours."""
    code = _mc_code(addon)
    out = set()
    for en, _kind, sec, sub, _f in rows:
        head = sub if sec in MC_MIXED else sec + " / " + sub
        if not MC_HEAD.search(head):
            continue
        probe = max(_PIECE.split(en), key=len)
        shown = (f'"{probe}"' in code or f"'{probe}'" in code) if len(probe) < 8 else probe[:40] in code
        if not shown:
            out.add(en)
    return out


def _main(argv):
    if argv[1:] != ["mc-keys"]:
        print(__doc__)
        return 2
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import hashtext
    import make_mc_text as M
    import mc_text_lib as L
    addon = M.addon_dir()
    news = mc_news(L.source(addon), addon)
    for k in sorted(hashtext.key(e) for e in news):
        print(k)
    return 0


if __name__ == "__main__":
    sys.exit(_main(sys.argv))
