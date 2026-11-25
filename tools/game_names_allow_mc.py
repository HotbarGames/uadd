"""Mastercraft texts read by a person for tools/test_game_names.py (the part of ALLOW from 2026-11-23, 2.1.1).

{key of the English: key of the Ukrainian that was read}. Each Ukrainian below was read: every game name in
it is ClassicUA's word (UALL Forever's where ClassicUA lacks it), and the check flags it only because it
compares with UALL Forever alone, or takes a plain word for a name. A change of the Ukrainian is read again.
No English of the addon goes here (it is all rights reserved).
"""

MC_ALLOW_2111 = {
    # Zones, NPCs and books, ClassicUA's words (zone.lua, npc, quest files): Степи, Багрянокряжжя, Грабіжна
    # Бухта, Терниста долина, Заболоття, печера Тельґена, височина Араті, Чорноскельні надра, Палаюче Ядро,
    # Випалена ущелина, Бруднолипка трясовина, Зачумлені землі, Пристроблях; Брікк Майструвач, Балая Лок'Вейн,
    # Дранг, Нет Пеґл, Морок'рел, Смикль Жерлиця, Трентон Світломолот, «Експерт ... - я і окунь».
    "92:423d9e48": "162:c057024e",
    "230:f6872c14": "468:b31ebd15",
    "37:4423a644": "57:8e54f7a4",
    "55:c46cec9b": "121:40e01659",
    "47:d27dadb9": "100:341da4aa",
    "99:3b93a50f": "196:6e8996c1",
    "67:2af3ca91": "119:d932b8b5",
    "72:e039cc34": "109:a564b09a",
    "90:0afc1ed7": "158:3ea40345",
    "28:adad703a": "61:3038ddc1",
    "86:e3b515fc": "197:e6dc467d",
    "79:bebc95ae": "148:de23afed",
    "125:2ccca90a": "279:becdf714",
    "89:c35045fa": "182:734de4b3",
    "95:89de792c": "218:8278755b",
    "198:692f5c08": "338:a471a5ca",
    "104:baa154dc": "228:e0cef885",
    "78:017a494b": "240:87a10e2c",
    "91:f17eb86e": "165:0014171c",
    # Gathering items, metals and parts, ClassicUA's words (item.lua): душирість, королекров, життєкорінь,
    # Кадґарів вус, пурпуровий лотос, льодошапка, ясносрібло, мітрил, олово, залізо, торій, шорсткий і масивний
    # шліфувальний камінь, рулон рунічної тканини, безбарвне зілля, велика й мала магічна субстанція; азеротій
    # and важкий торій are UALL Forever's smelting names.
    "220:6871a3ba": "414:1043f685",
    "60:54306841": "112:94b28204",
    "40:6787f21b": "74:a56f5100",
    "47:6462dfef": "80:eae2f8df",
    "40:d61c4f09": "78:647f0808",
    "39:b32d9565": "66:e8b0ff34",
    "71:4f421a75": "120:206ba0e5",
    "56:400ea0d1": "92:f4c88fb6",
    "81:400834d0": "164:c732c3c5",
    "82:224895ae": "146:f9e46c9d",
    "114:88284f58": "240:5864ae96",
    "107:4638fd93": "209:22eec0f4",
    "195:fe6dcbd9": "368:18cf3d34",
    "71:eb2d9b36": "142:9b71bf45",
    "186:2d6eb06d": "336:ff0ec1c1",
    "291:1342644c": "579:e4996b4d",
    # Item suffixes (ClassicUA «з чарами зцілення», «з мавпи»), the fishing bot (ClassicUA and UALL Forever
    # agree), a rogue spell and class (ClassicUA, class.lua).
    "151:7981bad7": "257:ffd214b6",
    "192:b13bad2e": "363:45ff5aad",
    "22:79dca48d": "30:70b2e22e",
    "41:b44929ed": "117:ec784db1",
    # Events and Forever's own words: «Зимова Покрова» and «Місячний фестиваль» (ClassicUA), «смачнориба»
    # (ClassicUA), «Рибальський Фестиваль» (UALL Forever's UI.lua event name, place left out), «Прихильність
    # Крамаря» (UALL Forever; the short form is «Прихильність»), «Спадкове дерево», «Бойова Ватага».
    "120:32c0eef7": "248:3d0a735d",
    "12:6ee5f7cd": "63:aaeaa63e",
    "38:13a031e0": "125:01998422",
    "82:9f8c656c": "149:1ef8e164",
    "99:96655fa5": "158:52d027c5",
    "36:f3e5524d": "73:c49def9c",
    "269:adbb7c06": "432:444e74ff",
    "41:edbe5a88": "58:bba11738",
    "23:f45b08fa": "38:0124a759",
    "147:0f60827f": "255:8c2a8196",
    "256:84ee82a3": "496:57cf0f48",
    "16:834baebe": "42:fe2add23",
    "157:e40f2c97": "288:01118a28",
    "16:6462ad0c": "43:16c15bbf",
    "9:ce6ea5ea": "80:169c2828",
    "27:0f57aa52": "116:ba6bc4de",
    "104:3c2c0b1b": "180:0715d5f1",
    "62:d500384f": "113:85a4b5cf",
    "8:02c5c6cc": "79:21f146ca",
    "25:36493773": "61:1a3fba8f",
    "116:5667a53c": "266:2180fd71",
    "162:00e44cd6": "304:381cd5b7",
    # Plain words, no game name: the server's region and ruleset labels.
    "175:677d56f1": "321:54e7b9ba",
    "160:5b47c4bc": "287:4692649d",
    # The crates said without their name; a vendor neither addon names said without it, places as ClassicUA has them.
    "52:11e40698": "102:25920fbf",
    "159:ceddb19d": "316:d160948e",
}
