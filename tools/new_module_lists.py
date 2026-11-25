"""Small text edits for tools/new_module_reg.py: an entry put into a list as that list is written."""
import re

MARK = "TODO(" + "new_module)"          # in two parts, so this file does not trip the guard on the mark
LICENCES = {"gpl": "GPL-3.0", "mit": "MIT"}


class Gap(Exception):
    """The place this edit looks for is not there."""


def licence_name(m):
    return LICENCES.get(m.licence, m.licence or "")


def before(text, pattern, new):
    """new put before the first match of pattern (re.M)."""
    x = re.search(pattern, text, re.M)
    if not x:
        raise Gap(f"no {pattern}")
    return text[:x.start()] + new + text[x.start():]


def after_line(text, pattern, line):
    """line put after the last line that matches pattern."""
    xs = list(re.finditer(pattern, text, re.M))
    if not xs:
        raise Gap(f"no {pattern}")
    return text[:xs[-1].end()] + "\n" + line + text[xs[-1].end():]


def join_last(text, marker, name):
    """"A, B and C <marker>" gets name: "A, B, C and name <marker>" (the last place the marker stands)."""
    at = text.rfind(marker)
    a = text.rfind(" and ", 0, at)
    if at < 0 or a < 0 or at - a > 80:
        raise Gap(f"no list before {marker}")
    return f"{text[:a]}, {text[a + 5:at].rstrip()} and {name} {text[at:]}"


def put_entry(text, start, end, entry, indent, width=118):
    """entry put last in the Python list or dict that opens with start, on its last line when it fits.
    The closing bracket on a line of its own, or a comma after the last entry, gives valid code too."""
    a = text.find(start)
    b = text.find(end, a)
    if a < 0 or b < 0:
        raise Gap(f"no {start}")
    head = text[:b]
    body = head.rstrip()
    gap = head[len(body):]
    comma = "" if body.endswith(",") else ","
    if "\n" in gap:                      # the closing bracket stands on its own line
        return f"{body}{comma}\n{' ' * indent}{entry},\n{gap.rsplit(chr(10), 1)[1]}{text[b:]}"
    line = text[text.rfind("\n", 0, b) + 1:b]
    fits = len(line) + len(entry) + 3 <= width
    if not comma:                        # a comma after the last entry, the bracket on the same line
        return f"{body}{' ' if fits else chr(10) + ' ' * indent}{entry},{gap}{text[b:]}"
    return text[:b] + (", " if fits else ",\n" + " " * indent) + entry + text[b:]


def entry(text, names, flags=re.M | re.I):
    """Is one of names a whole entry of a list in text: after a line start, a bullet or heading mark, a comma, a colon,
    "and" or bold marks, and before a comma, full stop, colon, bracket, 's, "and", bold marks or the line end.
    "Bug" is not in "BugSack, Road to Sixty"; "Road" is not "Road to Sixty"."""
    return any(re.search(r"(?:^|,|:|\band\b|\*\*|^[-#*]+)[ \t]*" + re.escape(n) + r"[ \t]*(?=$|,|\.|:|\(|'s\b|\band\b|\*\*)",
                         text, flags) for n in names)


def cmd_safe(text):
    """text for an echo line inside a cmd.exe if-block of a .bat file: ( ) & | < > ^ and % made harmless."""
    return re.sub(r"([()&|<>^])", r"^\1", text.replace("%", "%%"))


def broken_python(texts):
    """[(file, why)] for each .py text that does not compile."""
    out = []
    for rel, text in texts.items():
        if rel.endswith(".py"):
            try:
                compile(text, rel, "exec")
            except (SyntaxError, ValueError) as e:
                out.append((rel, f"{type(e).__name__}: {e}"))
    return out


def wrap(text, lead, limit=380):
    """A line over the limit is cut after a comma; the rest starts with lead. Table rows are left."""
    out = []
    for line in text.split("\n"):
        while len(line) > limit and not line.startswith("|") and ", " in line[:limit]:
            cut = line.rfind(", ", 0, limit) + 1
            out.append(line[:cut])
            line = lead + line[cut:].lstrip()
        out.append(line)
    return "\n".join(out)
