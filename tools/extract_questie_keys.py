"""List Questie's English UI keys: every `["key"] = { ["enUS"] = ... }` in its Localization files.

python3 tools/extract_questie_keys.py                         print JSON to stdout
python3 tools/extract_questie_keys.py --out data/questie-keys.json
python3 tools/extract_questie_keys.py --questie "/path/to/AddOns/Questie"

The Questie folder defaults to $QUESTIE_DIR, then the Forever client's AddOns folder seen from WSL.
Output: {"questieVersion": "...", "count": n, "keys": {"<key>": "<file it is in>"}}, keys sorted.
The key is the exact text Questie passes to l10n(), escapes decoded (\\n is a real newline).
Standard library only. Reads Questie's files, never writes them.
"""
import argparse
import json
import os
import re
import sys
from pathlib import Path

DEFAULT_QUESTIE = "/mnt/c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/Questie"

ESCAPES = {ord("a"): 7, ord("b"): 8, ord("f"): 12, ord("n"): 10, ord("r"): 13, ord("t"): 9, ord("v"): 11,
           ord("\\"): 92, ord('"'): 34, ord("'"): 39, ord("\n"): 10}

STR, SYM = "str", "sym"


def _long_bracket(data, i):
    """At data[i] == '[': the level of a long bracket ([[ or [==[), or -1."""
    j = i + 1
    while j < len(data) and data[j] == ord("="):
        j += 1
    if j < len(data) and data[j] == ord("["):
        return j - i - 1
    return -1


def tokens(data):
    """Lua tokens from bytes: (STR, decoded text) for string literals, (SYM, char) for [ ] = { } ,
    and (SYM, "x") for anything else. Comments are skipped. Good enough for data tables."""
    i, n = 0, len(data)
    while i < n:
        c = data[i]
        if c in b" \t\r\n":
            i += 1
        elif data.startswith(b"--", i):
            i += 2
            if i < n and data[i] == ord("[") and _long_bracket(data, i) >= 0:
                level = _long_bracket(data, i)
                end = data.find(b"]" + b"=" * level + b"]", i)
                i = n if end < 0 else end + level + 2
            else:
                end = data.find(b"\n", i)
                i = n if end < 0 else end + 1
        elif c in (ord('"'), ord("'")):
            out, i = bytearray(), i + 1
            while i < n and data[i] != c:
                if data[i] == ord("\\") and i + 1 < n:
                    e = data[i + 1]
                    if e in ESCAPES:
                        out.append(ESCAPES[e])
                        i += 2
                    elif chr(e).isdigit():
                        m = re.match(rb"\d{1,3}", data[i + 1:i + 4])
                        out.append(int(m.group()) & 255)
                        i += 1 + len(m.group())
                    else:
                        out.append(e)
                        i += 2
                else:
                    out.append(data[i])
                    i += 1
            i += 1
            yield STR, out.decode("utf-8", "replace")
        elif c == ord("[") and _long_bracket(data, i) >= 0:
            level = _long_bracket(data, i)
            start = i + level + 2
            if data.startswith(b"\r\n", start):
                start += 2
            elif data.startswith(b"\n", start):
                start += 1
            end = data.find(b"]" + b"=" * level + b"]", start)
            end = n if end < 0 else end
            yield STR, data[start:end].decode("utf-8", "replace")
            i = end + level + 2
        elif chr(c) in "[]={},":
            yield SYM, chr(c)
            i += 1
        else:
            yield SYM, "x"
            i += 1


def keyed_tables(data):
    """Yield (key, table_keys) for every `["key"] = { ... }`: table_keys are the string keys
    written as ["k"] = directly inside that table."""
    def bracket_key(seq):
        """seq = the four tokens [ STR ] = ; returns the string, else None."""
        if len(seq) == 4 and seq[0] == (SYM, "[") and seq[1][0] == STR and seq[2] == (SYM, "]") \
                and seq[3] == (SYM, "="):
            return seq[1][1]
        return None

    stack, last = [], []
    for tok in tokens(data):
        last = (last + [tok])[-5:]
        if tok == (SYM, "{"):
            stack.append({"key": bracket_key(last[:-1]), "keys": set()})
        elif tok == (SYM, "}"):
            if stack:
                frame = stack.pop()
                if frame["key"] is not None:
                    yield frame["key"], frame["keys"]
        elif tok == (SYM, "=") and stack:
            key = bracket_key(last[-4:])
            if key is not None:
                stack[-1]["keys"].add(key)


def extract(questie):
    root = Path(questie) / "Localization" / "Translations"
    if not root.is_dir():
        sys.exit(f"extract_questie_keys: no Localization/Translations folder in {questie}")
    keys = {}
    for path in sorted(root.rglob("*.lua")):
        rel = path.relative_to(Path(questie)).as_posix()
        for key, inner in keyed_tables(path.read_bytes()):
            if "enUS" in inner:
                keys.setdefault(key, rel)
    return {"questieVersion": questie_version(questie), "count": len(keys),
            "keys": {k: keys[k] for k in sorted(keys)}}


def questie_version(questie):
    for toc in sorted(Path(questie).glob("*.toc")):
        m = re.search(r"^## Version:\s*(\S+)", toc.read_text(encoding="utf-8", errors="replace"), re.M)
        if m:
            return m.group(1)
    return None


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--questie", default=os.environ.get("QUESTIE_DIR", DEFAULT_QUESTIE))
    ap.add_argument("--out", help="write the JSON here instead of printing it")
    args = ap.parse_args(argv)
    result = extract(args.questie)
    text = json.dumps(result, indent=1, ensure_ascii=False) + "\n"
    if args.out:
        Path(args.out).parent.mkdir(parents=True, exist_ok=True)
        Path(args.out).write_text(text, encoding="utf-8", newline="\n")
        print(f"{args.out}: {result['count']} keys from Questie {result['questieVersion']}", file=sys.stderr)
    else:
        sys.stdout.write(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
