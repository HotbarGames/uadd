"""UADD_LayerSwap/data/words.lua: built from LayerSwap's texts and our Ukrainian, and read back.

The same format and code as tools/fxpb_words.py (a second copy of that module is loaded here, so its
BLANK and FREE tables are LayerSwap's own); only the header of the data file and the table name differ.
Used by tools/make_lsw_data.py.
"""
import importlib.util
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
_spec = importlib.util.spec_from_file_location("_lsw_words_base", HERE / "fxpb_words.py")
_W = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_W)

# Slots that hold an English plural ending or a plural-only word (" player" / " players", "is" / "are"):
# our Ukrainian keeps the slot (so the slots still match) and Words.lua fills it with "". Our Ukrainian
# picks its own form with a {one|few|many} mark (UADD_LayerSwap/Words.lua). Template key -> slot numbers.
BLANK = {"27:2b29e09b": [2], "41:d966f4b3": [2], "60:9b650cba": [2], "62:cb90be94": [2], "74:7c7d5474": [2],
    "75:5ee10f42": [2]}
# Slots that hold a name the player or the game made (a player, a guild, a zone): Words.lua keeps any
# English there. Every other %s must hold a number, a time or one of the addon's own texts.
# Never a slot that only holds a colour code or a clock (IsValue takes those): a free slot at the start
# or end of a text would also take what LayerSwap glues before or after it (docs/LESSONS.md, lesson 7).
FREE = {"103:4881e899": [2], "105:86995f42": [1, 2], "112:2e1f0ac2": [1], "152:cc668940": [1],
    "158:7c53154f": [1, 2], "21:9d2b4088": [1], "26:ce1bba90": [1, 2], "27:9360dd7a": [1], "31:cf102b97": [1],
    "32:43c0159b": [1], "35:c6216a1c": [2], "37:9cc94fd1": [1, 2], "37:a004abe1": [1], "39:6f835a39": [1],
    "41:0841de4e": [1], "41:2f1f067d": [1], "43:1da9442c": [1], "44:ccbe7f3b": [1], "45:33fc677f": [1],
    "45:41e7b0ba": [1], "46:74058d06": [2], "47:4d8503e8": [1, 2], "50:f8679165": [1],
    "51:475e88e9": [1], "51:ae24864f": [1], "52:5e7a5b9a": [1], "52:91df784d": [1], "53:ec051d9c": [1],
    "54:a23173ce": [1], "61:0408ca50": [1], "63:ce5139a0": [1], "65:7772b1d4": [1],
    "69:cdd2e3f2": [2], "78:4ac7b9c2": [1], "79:3eb71500": [1], "9:839e061f": [1]}
_W.BLANK, _W.FREE = BLANK, FREE

KEY, VALUE, LINE = _W.KEY, _W.VALUE, _W.LINE
unlua, text_of, specs, template_text, own, signature = _W.unlua, _W.text_of, _W.specs, _W.template_text, _W.own, _W.signature
build, read, ukrainian, overlay = _W.build, _W.read, _W.ukrainian, _W.overlay


def write(data, version):
    """The text of data/words.lua."""
    lines = _W.write(data, version).split("\n")
    head = ["-- Made by tools/make_lsw_data.py from LayerSwap %s. Do not edit: change the review file" % version,
            "-- (local/layerswap.txt) and run the tool again. No English here: only hashes of it (UADD/Hash.lua)",
            "-- and our Ukrainian. Words.lua builds its tables from it. Over the 300-line budget on purpose: data."]
    body = lines[3:]
    body[body.index("ns.FXPB = {")] = "ns.LSW = {"
    return "\n".join(head + body)
