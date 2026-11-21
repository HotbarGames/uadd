"""Time bounds that other load on the PC cannot break (docs/LESSONS3.md, lesson 22 again).

"Under 5 ms" failed on fine code while other programs kept all cores busy: even CPU time (os.clock,
process_time) grows when cores are shared (shared caches, hyper-threading, a lower clock, a slower core).
So each bound is measured against a reference job: fixed pure Lua string work (split, lower, join, gsub,
plain find over a 10 KB line) in the same Lua 5.1 (lupa) the checks run, timed with os.clock right after the
checked code. Load slows the reference and the checked code alike, so a fine path stays under its bound,
and a path that takes the square of the line (220-400 ms on 10 KB) still fails by far.

  bound(5)   -> (bound in ms, reference in ms): 5 ms times the reference's slowdown against REF_MS,
                never under 5 ms, never over CAP times 5 ms (a broken reference hides no slow path)
  note(b, r) -> "bound 5.0 ms, reference 1.52 ms", for the check's detail

  python3 tools/harness/clock.py    prints the reference now (to set REF_MS again on another PC)
"""
import statistics

REF_MS = 1.25    # the reference job on an idle PC, set a bit low (a high one is flaky): under load (12-28 on
                 # 8 cores, 2026-11-21) it took 1.9-2.8 ms, and Mastercraft's slowest hard text 2.6-3.3x that
CAP = 8          # the most load may stretch a bound: 5 ms -> 40 ms
RUNS = 7         # reference runs per bound; their median counts
REPS = 4         # the job's loops per run

_JOB = r"""
local line = string.rep("Quix went to Orgrimmar, got 7 gold: fine. ", 240)    -- about 10 KB
local lower, gsub, find, sub, concat, gmatch, clock = string.lower, string.gsub, string.find, string.sub,
    table.concat, string.gmatch, os.clock
return function(reps)
    local t0, n = clock(), 0
    for _ = 1, reps do
        local out = {}
        for w in gmatch(line, "[^ ]+") do out[#out + 1] = lower(w) end
        local g = gsub(concat(out, " "), "%d+", "#")
        local i = 1
        while true do
            local a = find(g, ",", i, true)
            if not a then break end
            n, i = n + 1, a + 1
        end
        n = n + #sub(g, 2, -2)
    end
    return (clock() - t0) * 1000, n
end
"""
_job = None


def sample():
    """One run of the reference job now, in ms. A check may take one between its timings (halves.slowest),
    so the reference sees the same load as the checked code."""
    global _job
    if _job is None:
        from lupa import lua51
        _job = lua51.LuaRuntime().execute(_JOB)
        _job(1)                                   # warm up
    return _job(REPS)[0]


def reference(runs=RUNS):
    """The reference job's time now, in ms: the median of `runs` runs."""
    return statistics.median(sample() for _ in range(runs))


def bound(base_ms=5.0, ref=None):
    """(bound in ms, reference in ms): base_ms stretched by the load seen now, from 1x to CAP x.
    ref: None (run the job now), a list of samples taken during the check (their median) or a time."""
    ref = reference() if ref is None else statistics.median(ref) if isinstance(ref, list) else ref
    return base_ms * min(CAP, max(1.0, ref / REF_MS)), ref


def note(b, ref):
    return f"bound {b:.1f} ms, reference {ref:.2f} ms"


if __name__ == "__main__":
    import os
    xs = sorted(sample() for _ in range(200))
    print(f"reference: min {xs[0]:.2f}, median {xs[100]:.2f}, max {xs[-1]:.2f} ms (REF_MS {REF_MS}); "
          f"bound now {bound()[0]:.1f} ms; load {os.getloadavg()[0]:.1f}")
