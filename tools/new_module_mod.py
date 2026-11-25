"""One module as tools/new_module_reg.py sees it: its names, key, short and licence, read from its files."""
import re
from functools import lru_cache
from pathlib import Path


def section(text, start, end="\x00"):
    i = text.find(start)
    return text[i:text.find(end, i + 1) if text.find(end, i + 1) > 0 else len(text)] if i >= 0 else ""


@lru_cache(maxsize=4)
def flows(root):
    """{flow name: its code}."""
    return {p.stem: p.read_text(encoding="utf-8") for p in sorted((root / "tools" / "harness").glob("flow*.py"))}


class Mod:
    """One module, read from its TOC, its code and its flow's "new_module:" line."""

    def __init__(self, root, folder, **given):
        self.root, self.folder, self.name = Path(root), folder, folder[5:]
        toc = (self.root / folder / (folder + ".toc")).read_text(encoding="utf-8")
        title = re.search(r"^## Title:\s*UADD - (.+?)\s*$", toc, re.M)
        self.title = title.group(1) if title else self.name
        deps = re.search(r"^## OptionalDeps:\s*(.+)$", toc, re.M)
        deps = [d.strip() for d in deps.group(1).split(",")] if deps else []
        self.targets = [d for d in deps if d not in ("UALLF", "ClassicUA")] or [self.name]
        self.target, self.key, self.short, self.licence, self.author = self.targets[0], None, None, None, ""
        self._flow_line()
        for k, v in given.items():
            if v:
                setattr(self, k, v)
        self.key = self.key or self._key() or self.short
        drift = re.search(rf'"{folder}":\s*\("(\w+)"',
                          (self.root / "tools" / "drift_sources.py").read_text(encoding="utf-8"))
        if drift and drift.group(1) not in self.targets:
            self.targets.insert(0, drift.group(1))
        self.titles = [self.title, *self.targets, self.name]

    def _key(self):
        code = "\n".join(p.read_text(encoding="utf-8") for p in sorted((self.root / self.folder).glob("*.lua")))
        x = re.search(r'RegisterModule\("(\w+)"', code) or re.search(r'\bKEY\b[^=\n"]*=\s*"(\w+)"', code)
        return x.group(1) if x else None

    def _flow_line(self):
        want = f"new_module: {self.folder} "
        s = next((s for s in flows(self.root).values() if want in s), None)
        if s:
            for k, v in re.findall(r"(\w+)=(\S+)", s.split(want, 1)[1].split("\n", 1)[0]):
                setattr(self, k, v)

    def restricted(self):
        """Is the addon all rights reserved? By the licence given, else by the list copy_scan.py has it in."""
        if self.licence:
            return self.licence in ("arr", "none")
        allowed = section((self.root / "tools" / "copy_scan.py").read_text(encoding="utf-8"), "\nALLOWED = {", "}")
        return not any(f'"{x}"' in allowed for x in self.targets)
