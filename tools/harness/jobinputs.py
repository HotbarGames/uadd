"""What a harness job read: the recorder behind jobcache.py (docs/LESSONS4.md lesson 41, its "again" case).

`install()` (once, in run.py's process, before the flows are imported) puts hooks in place; what they see goes
into the Inputs that `to()` names, or nowhere. A forked job starts an Inputs of its own. Seen are:
  * files opened (Python's audit hook) and files served from loader's memo (loader.WATCH, text or "is a file");
  * directories listed (audit hook);
  * existence checks and stats: no audit event, so os.stat, os.lstat, os.access and pathlib's go through a wrapper
    (os.path.exists, isfile, isdir, getmtime... and glob call os.stat and os.lstat by name);
  * modules imported (builtins.__import__, importlib.import_module, spec_from_file_location), also when they were loaded before the fork;
  * what nobody can follow (a program run, a socket, a file written): `bad`, so the job is never kept.
Not seen: a file that Lua itself opens (io, loadfile): no Lua of ours does (tools/test_jobcache.py looks).
"""
import builtins
import importlib.util
import os
import pathlib
import sys

SKIP = ("/proc/", "/dev/", "/sys/")             # the machine, not an input of a check
STDLIB = tuple(p + "/" for p in {os.path.dirname(os.__file__), *(
    q for q in sys.path if q.endswith(("site-packages", "dist-packages")))})   # keyed by version (jobcache.py)
BAD_EVENTS = {"subprocess.Popen", "os.system", "os.posix_spawn", "os.exec", "os.fork", "os.forkpty", "os.spawn",
              "socket.connect", "socket.bind", "pty.spawn", "ctypes.dlopen", "sqlite3.connect", "os.remove",
              "os.rename", "os.mkdir", "os.rmdir", "os.symlink", "os.link", "os.truncate", "os.utime",
              "shutil.copyfile", "shutil.move", "shutil.rmtree", "tempfile.mkstemp", "tempfile.mkdtemp"}
WRITE = os.O_WRONLY | os.O_RDWR | os.O_CREAT | os.O_TRUNC | os.O_APPEND


class Inputs:
    """files, stats, dirs: absolute paths; code: .py files Python itself opened to import them; mods: (importer,
    module) names; bad: why the job can not be kept (or empty)."""

    def __init__(self):
        self.files, self.stats, self.dirs, self.code, self.mods, self.bad = set(), set(), set(), set(), set(), set()

    def add(self, other):
        for k in ("files", "stats", "dirs", "code", "mods", "bad"):
            getattr(self, k).update(getattr(other, k))
        return self


_SINK = None
_INSTALLED = False


def to(sink):
    """From now on what is read goes into `sink` (an Inputs), or nowhere (None). Returns the sink before."""
    global _SINK
    old, _SINK = _SINK, sink
    return old


def _path(p):
    """The absolute path, or None for a file descriptor or a path that is never an input."""
    if isinstance(p, int) or p is None:
        return None
    p = os.fsdecode(p) if not isinstance(p, str) else p
    if not os.path.isabs(p) or "/." in p or "//" in p:
        p = os.path.abspath(p)
    if p.startswith(SKIP) or p.startswith(STDLIB) or p.endswith(".pyc") or p.endswith("/__pycache__"):
        return None
    return p


def _note(kind, p):
    sink = _SINK
    if sink is not None:
        try:
            p = _path(p)
        except Exception:
            sink.bad.add(f"a path that can not be named: {p!r}")
            return
        if p is not None:
            getattr(sink, kind).add(p)


def _audit(event, args):
    sink = _SINK
    if sink is None:
        return
    if event == "open":
        p, mode, flags = args
        if isinstance(p, int):                  # a descriptor: its own open was seen
            return
        writes = any(c in (mode or "") for c in "wax+") or (isinstance(flags, int) and flags & WRITE)
        if not writes:
            _note("code" if sys._getframe(1).f_code.co_filename.startswith("<frozen importlib") else "files", p)
        elif str(p) != os.devnull and "__pycache__" not in str(p):
            sink.bad.add(f"wrote {p}")
    elif event in ("os.listdir", "os.scandir"):
        if sys._getframe(1).f_code.co_filename.startswith("<frozen importlib"):
            return                              # import looks a name up: the Graph finds it again by the same name
        _note("dirs", args[0] if args and args[0] is not None else ".")
        if args and isinstance(args[0], int):
            sink.bad.add("listed a folder by its descriptor")
    elif event in BAD_EVENTS:
        if not any("__pycache__" in str(a) for a in args):      # Python writing its own .pyc
            sink.bad.add(f"{event} {str(args[0])[:80] if args else ''}")


def _watched(fn):
    def call(path, *a, **k):
        _note("stats", path)
        if k.get("dir_fd") is not None and _SINK is not None:
            _SINK.bad.add("a stat by descriptor")
        return fn(path, *a, **k)
    call.__name__, call.__wrapped__ = fn.__name__, fn
    return call


def _importer(real):
    def call(name, globals=None, locals=None, fromlist=(), level=0):
        if _SINK is not None and not str((globals or {}).get("__file__")).startswith(STDLIB):
            if level:
                _SINK.bad.add(f"a relative import ({name})")
            _SINK.mods.add(((globals or {}).get("__name__", "?"), name))
        return real(name, globals, locals, fromlist, level)
    return call


def install():
    """Puts the hooks in place, once. They cost nothing much while the sink is None."""
    global _INSTALLED
    if _INSTALLED:
        return
    _INSTALLED = True
    import loader
    sys.addaudithook(_audit)
    for name in ("stat", "lstat", "access", "readlink"):
        setattr(os, name, _watched(getattr(os, name)))
    for name in ("stat", "lstat"):              # pathlib may hold os.stat itself (3.10): its methods instead
        real = getattr(pathlib.Path, name)

        def method(self, *a, _real=real, **k):
            _note("stats", self)
            return _real(self, *a, **k)
        setattr(pathlib.Path, name, method)
    builtins.__import__ = _importer(builtins.__import__)
    real_mod = importlib.import_module

    def import_module(name, package=None):
        if _SINK is not None:
            _SINK.mods.add((sys._getframe(1).f_globals.get("__name__", "?"), name))
        return real_mod(name, package)
    importlib.import_module = import_module
    real_spec = importlib.util.spec_from_file_location

    def spec_from_file_location(name, location=None, **k):
        if _SINK is not None and location:
            _SINK.mods.add((sys._getframe(1).f_globals.get("__name__", "?"),
                            os.path.splitext(os.path.basename(location))[0]))
        return real_spec(name, location, **k)
    importlib.util.spec_from_file_location = spec_from_file_location
    loader.WATCH = _note
