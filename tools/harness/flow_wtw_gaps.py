"""Step 8 of flow_wtw.py (UADD_WhatTheWhisper, Gaps.lua), on game A after login: the labels its enUS table lacks
(the profile panel's rows, settings captions) and the History page's size line. Its cuts are in flow_wtw_steps.py."""
import flow_wtw as F
from flow_pawn_game import cyr, diff
from loader import lua_str, txt

STEP = ("8 labels its enUS lacks (profile rows, also a panel shown again and a popout made later; settings captions) "
        "and the size line in B, KB, MB: ours on, English held and off; another unit: the whole line English")
SIZE_UA = "Орієнтовний розмір: "


def gaps(check, c, M, E, A):
    rows = sorted(k for k in E if k.startswith("R:main:"))
    caps = sorted(k for k in E if k.startswith("S:cap:"))
    keys = rows + caps + ["S:size"]
    ours = [k for k in rows + caps if A.get(k) != E.get(k) and cyr(A.get(k) or "")]
    gap_row = "Рівень" in [A.get(k) for k in rows]
    first = [] if A.get("S:size") == SIZE_UA + "456 Б" else [("456", A.get("S:size"))]
    bad = []

    def now():
        s = F.snap(M)
        return {k: s.get(k) for k in keys}

    def same(tag, want):
        d = diff({k: want.get(k) for k in keys}, now())
        if d:
            bad.append((tag, d[:2]))

    M.key(True)
    same("hold", E)
    M.key(False)
    same("release", A)
    M.hidePanel()                   # its Refresh skips a hidden panel and runs again when it shows
    M.key(True)
    M.showPanel()
    same("hidden held, shown", E)
    M.hidePanel()
    M.key(False)
    M.showPanel()
    same("hidden released, shown", A)
    sizes = []
    for n, want in ((1536, SIZE_UA + "1.5 КБ"), (3 * 1024 * 1024, SIZE_UA + "3.0 МБ")):
        M.bytes(n)
        sizes.append((n, F.snap(M).get("S:size"), want))
    M.raw(lua_str("3 GB"))
    sizes.append(("3 GB", F.snap(M).get("S:size"), txt(M.sizeEn(lua_str("3 GB")))))
    M.key(True)
    M.bytes(1536)
    sizes.append(("held", F.snap(M).get("S:size"), txt(M.sizeEn(lua_str("1.5 KB")))))
    M.key(False)
    M.bytes(456)
    sizes = [s for s in sizes if s[1] != s[2]]
    M.popout(7)                      # made after ours was in: ours, English held
    s = F.snap(M)
    pop = [k for k in rows if s.get("R:pop7:" + k[7:]) != A[k]]
    M.key(True)
    s = F.snap(M)
    pop += [("held", k) for k in rows if s.get("R:pop7:" + k[7:]) != E[k]]
    M.key(False)
    M.closePopout(7)
    M.uadd("wtw off")
    same("off", E)
    M.uadd("wtw on")
    same("on", A)
    ok = gap_row and bool(caps) and len(ours) == len(rows + caps) and not first and not bad and not sizes and not pop
    check(f"{STEP} ({len(rows)} rows, {len(caps)} captions)", ok,
          (gap_row, [k for k in rows + caps if k not in ours][:3], first, bad[:3], sizes[:3], pop[:3]))
    return ok
