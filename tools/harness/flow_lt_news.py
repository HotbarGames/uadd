"""Step 16 of flow_lt.py: the game's word (GAMEMENU_NEW_BUTTON, which ClassicUA alone leaves English) on
LootTriage's two New buttons, its window's and the one on the game's Settings panel. Ours in our font, also
through its hover (it sets the label's font object again, lesson 32); the window button sized to it (lesson 5);
English on the hold key and off; the global never written; one already Cyrillic left as it is.
Run from flow_lt.steps, on game A; it leaves the game as it found it.
"""
from loader import lua_str, txt

NEW_UK = "Що нового"
NEW_CYR = "Новинки"                  # the game's word as another addon may have put it into Ukrainian


def labels(M):
    """((text, in our font) window, (text, in our font) panel, the window button's width left over, the global)."""
    a, b, w, g = M.newsLabels()
    one = lambda x: tuple(txt(x).split("\t"))  # noqa: E731
    return one(a), one(b), w, txt(g)


def steps(check, M, E):
    en = E["N"]
    ours = (NEW_UK, "1")
    a, b, w, g = labels(M)
    check("16 its New buttons: ours in our font, the button sized to it, the global not written",
          a == ours and b == ours and w == 0 and g == en, (a, b, w, g))
    M.hoverNews(True)
    h = labels(M)[0]
    M.hoverNews(False)
    check("16 New button hover sets its font object: ours stays", h == ours and labels(M)[0] == ours,
          (h, labels(M)[0]))
    M.key(True)
    k = labels(M)
    M.key(False)
    r = labels(M)
    check("16 New buttons, hold key: English; released: ours", k[0][0] == en and k[1][0] == en and k[2] == 0
          and r[0] == ours and r[1] == ours, (k, r))
    M.uadd("lt off")
    o = labels(M)
    M.uadd("lt on")
    check("16 New buttons, off: English, the button sized back; on: ours", o[0] == (en, "0") and o[1] == (en, "0")
          and o[2] == 0 and labels(M)[0] == ours, (o, labels(M)))
    M.uadd("lt off")
    M.newsGlobal(lua_str(NEW_CYR))
    M.uadd("lt on")
    y = labels(M)
    M.uadd("lt off")
    M.newsGlobal(lua_str(en))
    M.uadd("lt on")
    check("16 the game's word already Cyrillic: left as it is, the global too",
          y[0][0] == NEW_CYR and y[1][0] == NEW_CYR and y[3] == NEW_CYR and labels(M)[0] == ours, y)
