"""Token helpers of tools/test_hook_guards.py, and its check of text hooks under U.Safe (lesson 19).

safe_hits_in_text: a hook on an addon text's setter or text-change event whose handler goes through U.Safe. After 5
errors U.Safe stays dead for the session, so after "/uadd <x> on" the texts stay wrong. It reads one file at a time:
  - hooksecurefunc(x, "SetText", "SetFormattedText", "SetFont" or "SetFontObject", handler), also through pcall, or a method name taken from a
    list in the file that holds one of them;
  - x:HookEvent("OnTextChanged" or "OnFormattedTextChanged", handler).
A handler goes through U.Safe when it is Safe(...) itself (any name that ends in .Safe, or a local Safe), a name set
to one (local X = U.Safe(...), ns.X = U.Safe(...)), or a function of the file whose body uses either.
A handler made in another file is not followed.
"""
import luatok

OPEN, CLOSE = {"function", "if", "do", "repeat"}, {"end", "until"}
SETTERS = {"SetText", "SetFormattedText", "SetFont", "SetFontObject"}
EVENTS = {"OnTextChanged", "OnFormattedTextChanged"}


def top_strings(toks, j, most=3):
    """String literals among the first `most` top-level arguments that start at toks[j]."""
    out, depth, args = [], 0, 1
    while j < len(toks) and args <= most:
        kind, value, _ = toks[j]
        if kind == luatok.SYM and value in ("(", "{", "["):
            depth += 1
        elif kind == luatok.SYM and value in (")", "}", "]"):
            if depth == 0:
                break
            depth -= 1
        elif kind == luatok.SYM and value == "," and depth == 0:
            args += 1
        elif kind == luatok.STR and depth == 0:
            out.append(value)
        j += 1
    return out


def function_defs(toks):
    """{token index of `function`: (name or None, params, first body index, end index)}."""
    out, n = {}, len(toks)
    for i, (kind, value, _) in enumerate(toks):
        if kind != luatok.NAME or value != "function":
            continue
        j, name, params = i + 1, None, []
        if i >= 3 and toks[i - 1][1] == "=" and toks[i - 2][0] == luatok.NAME and toks[i - 3][1] not in "=~<>":
            name = toks[i - 2][1]                          # F = function(...) / x.F = function(...)
        while j < n and (toks[j][0] == luatok.NAME or toks[j][1] in (".", ":")):
            if toks[j][1] == ":":
                params.append("self")
            elif toks[j][0] == luatok.NAME:
                name = toks[j][1]
            j += 1
        if j >= n or toks[j][1] != "(":
            continue
        j += 1
        while j < n and toks[j][1] != ")":
            if toks[j][0] == luatok.NAME:
                params.append(toks[j][1])
            j += 1
        k, depth = j + 1, 1
        while k < n and depth:
            if toks[k][0] == luatok.NAME and toks[k][1] in OPEN:
                depth += 1
            elif toks[k][0] == luatok.NAME and toks[k][1] in CLOSE:
                depth -= 1
            k += 1
        out[i] = (name, params, j + 1, k)
    return out


def chain_end(toks, j):
    """toks[j] starts a.b.c: (last name, index after it), or (None, j)."""
    name = None
    while j < len(toks) and toks[j][0] == luatok.NAME:
        name, j = toks[j][1], j + 1
        if j < len(toks) and toks[j][1] == ".":
            j += 1
        else:
            break
    return name, j


def args_at(toks, j):
    """[(start, end)] of the call's top-level arguments; toks[j] is the first token of the first one."""
    out, start, depth, blocks = [], j, 0, 0
    while j < len(toks):
        kind, value, _ = toks[j]
        if kind == luatok.NAME:
            blocks += value in OPEN
            blocks -= value in CLOSE
        elif kind == luatok.SYM and value in "({[":
            depth += 1
        elif kind == luatok.SYM and value in ")}]":
            depth -= 1
            if depth < 0:
                break
        elif kind == luatok.SYM and value == "," and depth == 0 and blocks == 0:
            out.append((start, j))
            start = j + 1
        j += 1
    return out + [(start, j)]


def _listed(toks):
    """True when a list of the file ({ "SetText", ... }) names a text setter."""
    return any(t[0] == luatok.STR and t[1] in SETTERS and (toks[i - 1][1] == "{" or toks[i + 1][1] == "}" or
                                                           (toks[i - 1][1] == "," and toks[i - 2][0] == luatok.STR))
               for i, t in enumerate(toks[:-1]) if i > 1)


def _text_hooks(toks):
    """[(line, (start, end) of the handler)] of each hook on a text's setter or text-change event."""
    out, listed = [], _listed(toks)
    for i, (kind, value, line) in enumerate(toks):
        if kind != luatok.NAME or value not in ("hooksecurefunc", "HookEvent") or i + 2 >= len(toks):
            continue
        if toks[i + 1][1] not in ("(", ","):
            continue                                       # hooksecurefunc( or pcall(hooksecurefunc,
        args = args_at(toks, i + 2)
        at = 1 if value == "hooksecurefunc" else 0         # which argument is the method or the event
        if len(args) < at + 2:
            continue
        a, b = args[at]
        one = toks[a] if b - a == 1 else (None, None, 0)
        if (one[0] == luatok.STR and one[1] in (SETTERS if at else EVENTS)) or (at and one[0] == luatok.NAME and listed):
            out.append((line, args[at + 1]))
    return out


def _chain(toks, j):
    """The whole name that starts at toks[j]: "ns.Put" (None in the middle of one)."""
    if toks[j][0] != luatok.NAME or (j and toks[j - 1][1] in (".", ":")):
        return None
    return "".join(t[1] for t in toks[j:chain_end(toks, j)[1]])


def _calls_safe(toks, a, b, names):
    """toks[a:b] calls Safe(...), or uses one of `names`."""
    return any((toks[k][1] == "Safe" and toks[k + 1][1] == "(") or _chain(toks, k) in names
               for k in range(a, min(b, len(toks) - 1)) if toks[k][0] == luatok.NAME)


def safe_hits_in_text(path, text):
    """[(path, line, what)]: a text hook whose handler goes through U.Safe (lesson 19)."""
    toks = list(luatok.tokens(text))
    names = set()
    for i, (kind, value, _) in enumerate(toks):
        if kind != luatok.SYM or value != "=" or i == 0 or i + 2 >= len(toks):
            continue
        fn, after = chain_end(toks, i + 1)
        if fn == "Safe" and after < len(toks) and toks[after][1] == "(" and toks[i - 1][0] == luatok.NAME:
            j = i - 1
            while j > 1 and toks[j - 1][1] == "." and toks[j - 2][0] == luatok.NAME:
                j -= 2
            names.add(_chain(toks, j))
    bodies = {d[0]: d for d in function_defs(toks).values() if d[0]}
    found = []
    for line, (a, b) in _text_hooks(toks):
        fn, after = chain_end(toks, a)
        d = bodies.get(fn) if after == b else None
        if _calls_safe(toks, a, b, names) or (d and _calls_safe(toks, d[2], d[3], names)):
            found.append((path, line, "a text hook under U.Safe: use a Guard (pcall, U.ReportError, U.Fault)"))
    return found
