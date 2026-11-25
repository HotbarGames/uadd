"""Which of our Python files a harness job can use (jobcache.py keys its kept results by them)."""
import ast
import hashlib
import os
import re
import types

HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.dirname(HERE)
ROOTS = {"__main__", "run", "jobs", "pool"}    # what they import is every flow: not an input of each job
BY_PATH = {"spec_from_file_location", "SourceFileLoader", "runpy", "exec"}      # runs a Python file it has the path of


class Graph:
    """Which repo modules a module uses: what its top level imports (function bodies: jobinputs.py sees those
    imports when they run), in a file that runs others by their path the file names in it ("fxpb_words.py"), and,
    the other way round, modules that change it as they load (a top-level `steps.STEPS.update(...)`)."""

    def __init__(self, folders=(HERE, TOOLS)):
        self.folders, self._at, self._use, self.back, self._sha = folders, {}, {}, {}, {}

    def path(self, name):
        if name not in self._at:
            found = [p for d in self.folders for p in (os.path.join(d, name + ".py"),
                                                       os.path.join(d, name, "__init__.py")) if os.path.isfile(p)]
            self._at[name] = found[0] if found else None
        return self._at[name]

    def sha(self, name):
        self.uses(name)
        return self._sha[name]

    def uses(self, name):
        if name not in self._use:
            with open(self.path(name), "rb") as f:
                data = f.read()
            self._sha[name] = hashlib.sha1(data).hexdigest()
            self._use[name] = uses = set()
            found, changed = _edges(ast.parse(data))
            uses.update(m for m in found if self.path(m))
            for m in changed:
                if self.path(m):
                    self.back.setdefault(m, set()).add(name)
        return self._use[name]

    def closure(self, seeds, edges=()):
        """{module: sha1 of its file} of everything `seeds` can use. `edges`: {importer: {names}} seen at run time."""
        out, todo, edges = {}, [m for m in seeds if self.path(m)], dict(edges)
        while todo:
            m = todo.pop()
            if m not in out:
                out[m] = self.sha(m)
                if m in ROOTS:
                    continue                # its own file only
                todo +=[x for x in self.uses(m) | self.back.get(m, set()) | set(edges.get(m, ())) if self.path(x)]
        return out


def _top(body):
    """The statements run as the module loads (not in functions, not under `if __name__ == "__main__"`)."""
    for n in body:
        if isinstance(n, ast.If) and "__main__" in ast.dump(n.test):
            continue
        yield n
        if not isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef)):
            for field in ("body", "orelse", "finalbody"):
                yield from _top(getattr(n, field, []))
            for h in getattr(n, "handlers", []):
                yield from _top(h.body)


def _edges(tree):
    """(modules used, modules changed) by the top level of a parsed file."""
    found, names, changed = set(), {}, set()       # names: a name here -> the module it came from
    by_path = any(isinstance(n, (ast.Name, ast.Attribute)) and getattr(n, "id", getattr(n, "attr", "")) in BY_PATH
                  for n in ast.walk(tree))
    for n in ast.walk(tree):
        if isinstance(n, ast.Import):
            names.update({(a.asname or a.name).split(".")[0]: a.name.split(".")[0] for a in n.names})
        elif isinstance(n, ast.ImportFrom):
            names.update({a.asname or a.name: (n.module or "").split(".")[0] for a in n.names})
        elif by_path and isinstance(n, ast.Constant) and isinstance(n.value, str) and re.fullmatch(r"\w+\.py", n.value):
            found.add(n.value[:-3])
    for n in _top(tree.body):
        if isinstance(n, ast.Import):
            found |= {a.name.split(".")[0] for a in n.names}
        elif isinstance(n, ast.ImportFrom):
            found.add((n.module or "").split(".")[0])
        elif isinstance(n, (ast.Expr, ast.For, ast.With, ast.While, ast.AugAssign, ast.Delete)) or (
                isinstance(n, ast.Assign) and any(not isinstance(t, (ast.Name, ast.Tuple)) for t in n.targets)):
            changed |= {names[x.id] for x in ast.walk(n) if isinstance(x, ast.Name) and x.id in names}
    return found, changed


def modules_of(fn, args):
    """The names of the modules a job's function and arguments come from."""
    out = {fn.__module__}
    for a in args:
        out.add(a.__name__ if isinstance(a, types.ModuleType) else getattr(a, "__module__", None) or fn.__module__)
    return out


def edges_of(inputs):
    """{importer: {names}} of the imports seen in the parent (its orchestrators left out)."""
    out = {}
    for importer, name in inputs.mods:
        if importer not in ROOTS:
            out.setdefault(importer, set()).add(name.split(".")[0])
    return out
