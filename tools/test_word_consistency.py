"""Tests for tools/word_consistency.py, on made-up texts only (no addon's English).

python3 -m unittest tools.test_word_consistency
"""
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import hashtext as H  # noqa: E402
import word_consistency as W  # noqa: E402


def entry(gid, en, uk):
    return {"id": gid, "en": [en] if isinstance(en, str) else list(en), "uk": uk, "note": "", "where": "test"}


def p(module, en, uk, key=None, gid=None):
    return W.Pair(module, key, en, uk, gid, "test")


class Stems(unittest.TestCase):
    def test_forms_of_one_word_match(self):
        for a, b in [("сумка", "сумках"), ("сумки", "Сумкою"), ("лейер", "лейера"), ("вхід", "входу"),
                     ("уміння", "вміння"), ("точка", "точки"), ("показати", "показувати")]:
            self.assertTrue(W.stem_match(a, b), (a, b))

    def test_other_words_do_not_match(self):
        for a, b in [("лейер", "шар"), ("трекер", "облік"), ("сховати", "приховати"), ("запити", "прохання")]:
            self.assertFalse(W.stem_match(a, b), (a, b))

    def test_same_forms(self):
        self.assertTrue(W.same_forms("Хост", "хоста"))
        self.assertTrue(W.same_forms("Продає: %s", "продає %s"))
        self.assertTrue(W.same_forms("не в мережі", "Не у мережі"))
        self.assertFalse(W.same_forms("Трекер предметів", "облік предметів"))
        self.assertFalse(W.same_forms("Звіт", "Звіт про помилки"))

    def test_norm(self):
        self.assertEqual(W.norm("  Wobbly   Gizmo:  "), "wobbly gizmo")
        self.assertEqual(W.norm("%d gizmos..."), W.norm("%s Gizmos"))


class Data(unittest.TestCase):
    LUA = (
        'local T, E, B, L = {}, {}, {}, {}\n'
        'T["GIZMO_KEY"] = "Штука"\n'
        'E["11:aaaa1111"] = G"ui.save"\n'
        'L.Wobble = "Хитання"\n'
        'L.Plain = "not ours"\n'
        'L.Joined = "Частина " .. "друга"\n'
        'ns.X = { exact = { ["5:bbbb2222"] = "Вимкнено" },\n'
        '  templates = { { len = { 6 }, hash = { "%s", "%s" }, uk = { "Рівень ", 1 } } } }\n'
        'T[#T + 1] = { id = "7:cccc3333", hash = { "00001505" }, uk = { "Ціль: ", 1 } }\n'
        'B.src["config:Shade"] = "%s"\n'
        'B.config = { ["Shade"] = "Відтінок" }\n'
    )

    def parse(self):
        tpl = H.djb2("Gizmo level "), H.djb2("")
        alias_hash = H.key("Pick a shade")
        lua = self.LUA % (tpl + (alias_hash,))
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / "Data.lua"
            path.write_text(lua, encoding="utf-8")
            return W.parse_data([path], {"ui.save": "Зберегти"})

    def test_parse_data(self):
        terms, alias = self.parse()
        self.assertEqual(terms["GIZMO_KEY"][0][0], "Штука")
        self.assertEqual(terms["11:aaaa1111"][0][:2], ("Зберегти", "ui.save"))
        self.assertEqual(terms["Wobble"][0][0], "Хитання")
        self.assertNotIn("Plain", terms)        # no Cyrillic: not ours
        self.assertNotIn("Joined", terms)       # "a" .. "b": not one whole text
        self.assertEqual(terms["5:bbbb2222"][0][0], "Вимкнено")
        self.assertEqual(terms["7:cccc3333"][0][0], "Ціль: %s")
        self.assertIn(H.key("Pick a shade"), alias)

    def test_pair_by_key_hash_template_and_alias(self):
        terms, alias = self.parse()
        terms[H.key("Gizmo depot")] = [("Склад штук", None, "x")]
        rows = [("GIZMO_KEY", "Gizmo", None), (None, "Gizmo depot", None), (None, "Gizmo level %d", None),
                (None, "Pick a shade", None), (None, "Nobody has this", None), (None, "In a review", "Огляд")]
        got = {pr.en: pr.uk for pr in W.pair("UADD_Fake", rows, terms, alias)}
        self.assertEqual(got, {"Gizmo": "Штука", "Gizmo depot": "Склад штук", "Gizmo level %d": "Рівень %s",
                               "Pick a shade": "Відтінок", "In a review": "Огляд"})

    def test_read_review(self):
        text = ('#1 label  [GIZMO_KEY]\nEN: Gizmo\nUA: Штука\n\n'
                'EN: "Wobbly \\"one\\""\nUA: G"ui.save"\n\n'
                '== LABEL Shade\nen: Pick a shade\nuk: Відтінок\n')
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / "review_01.txt"
            path.write_text(text, encoding="utf-8")
            rows = W.read_review(path, {"ui.save": "Зберегти"})
        self.assertEqual(rows, [("GIZMO_KEY", "Gizmo", "Штука"), (None, 'Wobbly "one"', "Зберегти"),
                                ("Shade", "Pick a shade", "Відтінок")])


class Kind1(unittest.TestCase):
    PAIRS = [
        p("UADD_Fake", "Gizmo cart", "Візок", "A"), p("UADD_Fake", "Gizmo Cart:", "Тачка", "B"),
        p("UADD_Fake", "Wobble", "Хитання", "C"), p("UADD_Fake", "wobble.", "хитання", "D"),
        p("UADD_Fake", "Sprocket", "Зірочка", "E"), p("UADD_Fake", "sprocket", "зірочки", "F"),
        p("UADD_Fake", "Layer", "Лейер", "G", "srv.layer"), p("UADD_Fake", "Layer", "Шар", "H", "map.layer"),
        p("UADD_Other", "Gizmo cart", "Візок", "I"),
    ]

    def test_words_forms_and_meanings(self):
        cases = {c[2]: c for c in W.kind1(self.PAIRS)}
        cart, sprocket = H.djb2("gizmo cart"), H.djb2("sprocket")
        self.assertEqual(set(cases), {cart, sprocket})   # Wobble: same text; Layer: two glossary meanings
        self.assertFalse(cases[cart][5])
        self.assertTrue(cases[sprocket][5])             # other forms only
        self.assertEqual([c[2] for c in W.strict_cases(W.kind1(self.PAIRS))], [cart])

    def test_allow(self):
        allow = {("UADD_Fake", H.djb2("gizmo cart")): "context differs"}
        self.assertEqual(W.strict_cases(W.kind1(self.PAIRS, allow)), [])


class Kind2(unittest.TestCase):
    ENTRIES = [entry("srv.layer", "Layer", "Лейер"), entry("map.layer", "Layer", "Шар"),
               entry("ui.save", "Save", "Зберегти")]

    def run2(self, pairs):
        return {c[1]: c for c in W.kind2(pairs, self.ENTRIES)}

    def test_label_with_other_words_across_modules(self):
        got = self.run2([p("UADD_A", "Gizmo", "Штука"), p("UADD_B", "Gizmo", "Річ")])
        self.assertEqual(set(got["Gizmo"][2]), {"штука", "річ"})

    def test_against_the_glossary(self):
        got = self.run2([p("UADD_A", "Save", "Зберегти"), p("UADD_B", "Save", "Записати")])
        self.assertIn("glossary ui.save", got["Save"][2]["зберегти"])

    def test_forms_of_one_word_are_one(self):
        self.assertEqual(self.run2([p("UADD_A", "Blue", "синій"), p("UADD_B", "Blue", "синя")]), {})

    def test_two_glossary_meanings_are_not_merged(self):
        pairs = [p("UADD_A", "Layer", "Лейер", gid="srv.layer"), p("UADD_B", "Layer", "Шар")]
        self.assertEqual(self.run2(pairs), {})
        got = self.run2(pairs + [p("UADD_C", "Layer", "Пласт"), p("UADD_D", "Layer", "Ярус")])
        self.assertEqual(set(got["Layer"][2]), {"пласт", "ярус"})

    def test_long_or_slotted_text_is_no_label(self):
        self.assertEqual(self.run2([p("UADD_A", "Gizmo %s", "Штука %s"), p("UADD_B", "Gizmo %s", "Річ %s")]), {})
        self.assertEqual(self.run2([p("UADD_A", "One two three four", "А"), p("UADD_B", "One two three four",
                                                                             "Б")]), {})


class Kind3(unittest.TestCase):
    ENTRIES = [entry("srv.layer", "Layer", "Лейер"), entry("quest.quest", "Quest", "Завдання"),
               entry("quest.log", "Quest Log", "Журнал завдань"), entry("gear.back", "Back", "Спина"),
               entry("item.bag", "Bag", "Торба"), entry("vendor.bags", "Bags", "Сумки"),
               entry("ui.show", "Show", "Показати"), entry("prof.node", "Node", "Точка збору")]

    def run3(self, pairs, ui=False):
        return {k: [x.en for x in v] for k, v in W.kind3(pairs, self.ENTRIES, ui).items()}

    def test_term_without_its_word(self):
        got = self.run3([p("UADD_A", "Change layer now", "Змінити шар зараз")])
        self.assertEqual(got, {("UADD_A", "srv.layer"): ["Change layer now"]})

    def test_a_form_of_the_word_is_fine(self):
        self.assertEqual(self.run3([p("UADD_A", "Change the layer", "Змінити лейер"),
                                    p("UADD_A", "No layers", "Без лейерів")]), {})

    def test_one_word_of_several_is_enough(self):
        self.assertEqual(self.run3([p("UADD_A", "Nodes on map", "Точки на карті")]), {})

    def test_longer_term_shadows_shorter(self):
        self.assertEqual(self.run3([p("UADD_A", "Open Quest Log", "Відкрити журнал")]), {})

    def test_plural_has_its_own_meaning(self):
        self.assertEqual(self.run3([p("UADD_A", "Open all bags", "Відкрити всі сумки")]), {})

    def test_plain_word_in_a_sentence_is_skipped(self):
        self.assertEqual(self.run3([p("UADD_A", "Please bring it back to the camp", "Принесіть це в табір")]), {})
        got = self.run3([p("UADD_A", "Show the Back slot on this page", "Комірка плаща на цій сторінці")])
        self.assertEqual(list(got), [("UADD_A", "gear.back")])

    def test_ui_words_only_on_request(self):
        pairs = [p("UADD_A", "Show gizmo", "Штука")]
        self.assertEqual(self.run3(pairs), {})
        self.assertEqual(list(self.run3(pairs, ui=True)), [("UADD_A", "ui.show")])

    def test_text_without_cyrillic_is_skipped(self):
        self.assertEqual(self.run3([p("UADD_A", "Change layer now", "%s")]), {})


class Report(unittest.TestCase):
    def test_restricted_english_is_never_printed(self):
        pairs = [p("UADD_Fake", "Wobbly gizmo cart", "Візок", "A"), p("UADD_Fake", "Wobbly gizmo cart", "Тачка")]
        lines = []
        W.report(pairs, [], out=lines.append)
        text = "\n".join(lines)
        self.assertNotIn("Wobbly", text)
        self.assertIn("h:" + H.djb2("wobbly gizmo cart"), text)
        self.assertIn(H.key("Wobbly gizmo cart"), text)
        lines.clear()
        W.report(pairs, [], english=True, out=lines.append)
        self.assertIn("Wobbly", "\n".join(lines))


if __name__ == "__main__":
    unittest.main()
