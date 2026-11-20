#!/usr/bin/env python3
"""Set one version in every TOC and name the changelog's Unreleased section after it.

    python3 tools/bump_version.py 1.2.0

Changes `## Version:` in UADD/UADD.toc and each UADD_*/UADD_*.toc, and `## Unreleased` in
UADD/CHANGELOG.md to `## <version>`. Line ends and everything else stay as they are.
Exits 1 and changes nothing when the version is malformed or the changelog has no Unreleased section.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
VERSION_LINE = re.compile(rb"^(## Version:[ \t]*)[^\r\n]*", re.M)
UNRELEASED = re.compile(rb"^## Unreleased(?=[ \t]*\r?$)", re.M)   # `$` alone misses CRLF line ends


def tocs(root):
    yield root / "UADD" / "UADD.toc"
    for d in sorted(root.glob("UADD_*")):
        toc = d / (d.name + ".toc")
        if toc.is_file():
            yield toc


def plan(root, version):
    """Return [(path, new bytes)] for every file that changes, or raise ValueError."""
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        raise ValueError(f"not a version like 1.2.0: {version!r}")
    v = version.encode()
    out = []
    for toc in tocs(root):
        old = toc.read_bytes()
        new, n = VERSION_LINE.subn(lambda m: m.group(1) + v, old, count=1)
        if n == 0:
            raise ValueError(f"no '## Version:' line in {toc.relative_to(root)}")
        if new != old:
            out.append((toc, new))
    log = root / "UADD" / "CHANGELOG.md"
    old = log.read_bytes()
    if re.search(rb"^## " + re.escape(v) + rb"[ \t]*\r?$", old, re.M):
        raise ValueError(f"CHANGELOG.md already has a {version} section")
    new, n = UNRELEASED.subn(b"## " + v, old, count=1)
    if n == 0:
        raise ValueError("CHANGELOG.md has no '## Unreleased' section")
    out.append((log, new))
    return out


def main(argv):
    if len(argv) != 2:
        print(__doc__.strip())
        return 1
    try:
        changes = plan(ROOT, argv[1])
    except ValueError as e:
        print(f"bump_version: {e}")
        return 1
    for path, data in changes:
        path.write_bytes(data)
        print(f"{path.relative_to(ROOT)}")
    print(f"{len(changes)} file(s) now say {argv[1]}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
