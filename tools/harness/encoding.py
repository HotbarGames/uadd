"""C_EncodingUtil for the harness: Base64, Deflate/Zlib and CBOR, done in Python.

The Lua state runs with latin-1 string conversion, so any Lua string (even binary) crosses into
Python unchanged as one character per byte. `b()` and `s()` convert between that and bytes.
"""
import base64
import struct
import zlib


def b(text):
    return text.encode("latin-1") if isinstance(text, str) else bytes(text)


def s(data):
    return data.decode("latin-1")


def decompress(data, method=None):
    raw = b(data)
    for wbits in (15, -15, 31):   # zlib, raw deflate, gzip
        try:
            return s(zlib.decompress(raw, wbits))
        except zlib.error:
            continue
    return None


def compress(data, method=None, level=None):
    lvl = -1 if level is None else int(level)
    if method in (1, "zlib"):
        return s(zlib.compress(b(data), lvl))
    c = zlib.compressobj(lvl, zlib.DEFLATED, -15)
    return s(c.compress(b(data)) + c.flush())


class _Cbor:
    def __init__(self, data):
        self.d, self.i = data, 0

    def take(self, n):
        out = self.d[self.i:self.i + n]
        self.i += n
        return out

    def arg(self, info):
        if info < 24:
            return info
        size = {24: 1, 25: 2, 26: 4, 27: 8}[info]
        return int.from_bytes(self.take(size), "big")

    def item(self):
        first = self.d[self.i]
        self.i += 1
        major, info = first >> 5, first & 31
        if major == 0:
            return self.arg(info)
        if major == 1:
            return -1 - self.arg(info)
        if major in (2, 3):
            data = self.take(self.arg(info))
            return s(data)
        if major == 4:
            return [self.item() for _ in range(self.arg(info))]
        if major == 5:
            n = self.arg(info)
            return {self.key(): self.item() for _ in range(n)} if n else {}
        if major == 6:
            self.arg(info)
            return self.item()
        if info == 20:
            return False
        if info == 21:
            return True
        if info in (22, 23):
            return None
        if info == 25:
            return _half(self.take(2))
        if info == 26:
            return struct.unpack(">f", self.take(4))[0]
        if info == 27:
            return struct.unpack(">d", self.take(8))[0]
        raise ValueError(f"CBOR: unsupported simple value {info}")

    def key(self):
        k = self.item()
        return k


def _half(two):
    h = int.from_bytes(two, "big")
    sign, exp, frac = (h >> 15) & 1, (h >> 10) & 31, h & 1023
    if exp == 0:
        v = frac * 2 ** -24
    elif exp == 31:
        v = float("inf") if frac == 0 else float("nan")
    else:
        v = (1 + frac / 1024) * 2 ** (exp - 15)
    return -v if sign else v


def install(lua):
    """Defines C_EncodingUtil in the Lua state."""
    def to_lua(v):
        if isinstance(v, list):
            t = lua.table()
            for i, x in enumerate(v, 1):
                if x is not None:
                    t[i] = to_lua(x)
            return t
        if isinstance(v, dict):
            t = lua.table()
            for k, x in v.items():
                if x is not None:
                    t[k] = to_lua(x)
            return t
        return v

    def deserialize(data):
        return to_lua(_Cbor(b(data)).item())

    def decode64(text):
        try:
            return s(base64.b64decode(b(text)))
        except ValueError:
            return None

    def encode64(data):
        return base64.b64encode(b(data)).decode("ascii")

    make = lua.eval("""function(dec, enc, decomp, comp, deser)
        C_EncodingUtil = {
            DecodeBase64 = function(t) return dec(t) end,
            EncodeBase64 = function(t) return enc(t) end,
            DecompressString = function(t, m) return decomp(t, m) end,
            CompressString = function(t, m, l) return comp(t, m, l) end,
            DeserializeCBOR = function(t) return deser(t) end,
            SerializeCBOR = function() error("SerializeCBOR is not modelled by the harness", 2) end,
        }
    end""")
    make(decode64, encode64, decompress, compress, deserialize)
