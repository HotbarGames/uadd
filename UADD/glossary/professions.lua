-- UADD glossary: professions, their trainers, skill ranks, weapon skills.
-- One line per meaning. Rules: docs/GLOSSARY.md.
local E = UADD.Glossary.Add

-- Professions (and secondary skills). Game names: UALL Forever's word wins (tools/test_glossary_uallf.py).
E{ id = "prof.alchemy", en = "Alchemy", uk = "Алхімія", note = "Profession name." }
E{ id = "prof.blacksmithing", en = "Blacksmithing", uk = "Ковальство", note = "Profession name." }
E{ id = "prof.enchanting", en = "Enchanting", uk = "Накладання чарів", note = "Profession name (of: накладання чарів). Not an item's enchantment (gear.enchant «Зачарування»). UALL Forever's word; owner 2026-11-20." }
E{ id = "prof.engineering", en = "Engineering", uk = "Інженерія", note = "Profession name." }
E{ id = "prof.herbalism", en = "Herbalism", uk = "Травництво", note = "Profession name." }
E{ id = "prof.inscription", en = "Inscription", uk = "Накреслення", note = "Profession name. UALL Forever's word; owner 2026-11-20." }
E{ id = "prof.jewelcrafting", en = "Jewelcrafting", uk = "Ювелірство", note = "Profession name. UALL Forever's word; owner 2026-11-20." }
E{ id = "prof.leatherworking", en = "Leatherworking", uk = "Шкіряна справа", note = "Profession name (of: шкіряної справи). UALL Forever's word; owner 2026-11-20." }
E{ id = "prof.mining", en = "Mining", uk = "Гірнича справа", note = "Profession name (of: гірничої справи). UALL Forever's word; owner 2026-11-20." }
E{ id = "prof.skinning", en = "Skinning", uk = "Білування", note = "Profession name (of: білування). UALL Forever's word; owner 2026-11-20." }
E{ id = "prof.tailoring", en = "Tailoring", uk = "Кравецтво", note = "Profession name." }
E{ id = "prof.archaeology", en = "Archaeology", uk = "Археологія", note = "Secondary skill name." }
E{ id = "prof.cooking", en = "Cooking", uk = "Кулінарія", note = "Secondary skill name." }
E{ id = "prof.first_aid", en = "First Aid", uk = "Перша допомога", note = "Secondary skill name." }
E{ id = "prof.fishing", en = "Fishing", uk = "Риболовля", note = "Secondary skill name." }

-- Trainers (NPCs who teach)
-- The NPC titles are UALL Forever's NpcNames.lua words, as they show over the NPC (owner 2026-11-20). Where it
-- has no title for that English, the nearest one it has, or its most common pattern («Учитель» + profession).
E{ id = "npc.class_trainer", en = "Class Trainer", uk = "Класовий тренер", note = "NPC who teaches class spells (до класового тренера). UALL Forever's word; owner 2026-11-20." }
E{ id = "npc.profession_trainers", en = "Profession Trainers", uk = "Вчителі професій", note = "NPCs who teach professions; a map filter. UALL Forever's word; owner 2026-11-20." }
E{ id = "npc.trainer_alchemy", en = "Alchemy Trainer", uk = "Вчитель Алхімії", note = "NPC who teaches this profession. UALL Forever's word; owner 2026-11-20." }
E{ id = "npc.trainer_blacksmithing", en = "Blacksmithing Trainer", uk = "Вчитель Ковальства", note = "NPC who teaches this profession. UALL Forever's word (its Blacksmith Trainer); owner 2026-11-20." }
E{ id = "npc.trainer_enchanting", en = "Enchanting Trainer", uk = "Учитель Накладання Чарів", note = "NPC who teaches this profession. UALL Forever's word; owner 2026-11-20." }
E{ id = "npc.trainer_engineering", en = "Engineering Trainer", uk = "Інструктор Інженерії", note = "NPC who teaches this profession. UALL Forever's word; owner 2026-11-20." }
E{ id = "npc.trainer_herbalism", en = "Herbalism Trainer", uk = "Учитель Травництва", note = "NPC who teaches this profession. UALL Forever's word; owner 2026-11-20." }
E{ id = "npc.trainer_inscription", en = "Inscription Trainer", uk = "Учитель Накреслення", note = "NPC who teaches this profession. UALL Forever has no title: its pattern; owner 2026-11-20." }
E{ id = "npc.trainer_jewelcrafting", en = "Jewelcrafting Trainer", uk = "Учитель Ювелірства", note = "NPC who teaches this profession. UALL Forever has no title: its pattern; owner 2026-11-20." }
E{ id = "npc.trainer_leatherworking", en = "Leatherworking Trainer", uk = "Учитель Шкіряної Справи", note = "NPC who teaches this profession. UALL Forever's word; owner 2026-11-20." }
E{ id = "npc.trainer_mining", en = "Mining Trainer", uk = "Інструктор Гірничої Справи", note = "NPC who teaches this profession. UALL Forever's word; owner 2026-11-20." }
E{ id = "npc.trainer_skinning", en = "Skinning Trainer", uk = "Тренер Білування", note = "NPC who teaches this profession. UALL Forever's word; owner 2026-11-20." }
E{ id = "npc.trainer_tailoring", en = "Tailoring Trainer", uk = "Тренер Кравецтва", note = "NPC who teaches this profession. UALL Forever's word; owner 2026-11-20." }
E{ id = "npc.trainer_archaeology", en = "Archaeology Trainer", uk = "Учитель Археології", note = "NPC who teaches this skill. UALL Forever has no title: its pattern; owner 2026-11-20." }
E{ id = "npc.trainer_cooking", en = "Cooking Trainer", uk = "Учитель Кулінарії", note = "NPC who teaches this skill. UALL Forever's word; owner 2026-11-20." }
E{ id = "npc.trainer_first_aid", en = "First Aid Trainer", uk = "Учитель Першої Допомоги", note = "NPC who teaches this skill. UALL Forever's word; owner 2026-11-20." }
E{ id = "npc.trainer_fishing", en = "Fishing Trainer", uk = "Учитель Рибальства", note = "NPC who teaches this skill. UALL Forever's word; owner 2026-11-20." }
E{ id = "npc.trainer_riding", en = "Riding Trainer", uk = "Тренер Верхової Їзди", note = "NPC who teaches riding. UALL Forever's word (its Horse Riding Trainer); owner 2026-11-20." }
E{ id = "npc.trainer_portal", en = "Portal Trainer", uk = "Наставник Порталів", note = "NPC who teaches mages portal spells. UALL Forever's word; owner 2026-11-20." }
E{ id = "npc.trainer_battle_pet", en = "Battle Pet Trainer", uk = "Наставник бойових вихованців", note = "NPC for pet battles." }

-- Skill ranks of a profession. "Master" here is the rank, not a master of anything else.
E{ id = "prof.rank_apprentice", en = "Apprentice", uk = "Учень", note = "Profession rank (1-75)." }
E{ id = "prof.rank_journeyman", en = "Journeyman", uk = "Підмайстер", note = "Profession rank (75-150)." }
E{ id = "prof.rank_expert", en = "Expert", uk = "Експерт", note = "Profession rank (150-225). UALL Forever's word; owner 2026-11-20." }
E{ id = "prof.rank_artisan", en = "Artisan", uk = "Ремісник", note = "Profession rank (225-300)." }
E{ id = "prof.rank_master", en = "Master", uk = "Майстер", note = "Profession rank (300-375). Not a master looter or a master volume." }
E{ id = "prof.rank_grand_master", en = "Grand Master", uk = "Грандмайстер", note = "Profession rank (375-450). UALL Forever's word; owner 2026-11-20." }
E{ id = "prof.rank_illustrious", en = "Illustrious Grand Master", uk = "Славетний грандмайстер", note = "Profession rank (450-525). UALL Forever's words (Illustrious, Grand Master); owner 2026-11-20." }
E{ id = "prof.rank_zen_master", en = "Zen Master", uk = "Дзен-майстер", note = "Profession rank (525-600). UALL Forever's word; owner 2026-11-20." }

E{ id = "weapon.skill", en = { "Weapon Skill", "Weapon Skills" }, uk = "Володіння зброєю", note = "The game's skill group for using kinds of weapons (also the plural). UALL Forever's word; owner 2026-11-20." }

-- Weapon skills (plural: the kind of weapon)
E{ id = "weapon.one_handed_swords", en = "One-Handed Swords", uk = "Одноручні мечі", note = "Weapon skill." }
E{ id = "weapon.one_handed_maces", en = "One-Handed Maces", uk = "Одноручні булави", note = "Weapon skill." }
E{ id = "weapon.one_handed_axes", en = "One-Handed Axes", uk = "Одноручні сокири", note = "Weapon skill." }
E{ id = "weapon.two_handed_swords", en = "Two-Handed Swords", uk = "Дворучні мечі", note = "Weapon skill." }
E{ id = "weapon.two_handed_maces", en = "Two-Handed Maces", uk = "Дворучні булави", note = "Weapon skill." }
E{ id = "weapon.two_handed_axes", en = "Two-Handed Axes", uk = "Дворучні сокири", note = "Weapon skill." }
E{ id = "weapon.fist_weapons", en = "Fist Weapons", uk = "Кулачна зброя", note = "Weapon skill. UALL Forever's word; owner 2026-11-20." }
E{ id = "weapon.daggers", en = "Daggers", uk = "Кинджали", note = "Weapon skill." }
E{ id = "weapon.thrown", en = "Thrown", uk = "Метальна зброя", note = "Weapon skill: throwing weapons." }
E{ id = "weapon.bows", en = "Bows", uk = "Луки", note = "Weapon skill." }
E{ id = "weapon.crossbows", en = "Crossbows", uk = "Арбалети", note = "Weapon skill." }
E{ id = "weapon.guns", en = "Guns", uk = "Вогнепальна зброя", note = "Weapon skill." }
E{ id = "weapon.staves", en = "Staves", uk = "Посохи", note = "Weapon skill: two-handed staves. UALL Forever's word; owner 2026-11-20." }
E{ id = "weapon.polearms", en = "Polearms", uk = "Древкова зброя", note = "Weapon skill." }

-- Mastercraft (lead's choices 2026-11-19)
E{ id = "prof.guide", en = "Guide", uk = "Посібник", note = "A profession guide (leveling steps). lead's choice 2026-11-19, Mastercraft." }
E{ id = "prof.lure", en = "Lure", uk = "приманка", note = "Fishing lure. Never «принада». lead's choice 2026-11-19, Mastercraft." }
E{ id = "prof.fishing_pole", en = "Fishing pole", uk = "вудка", note = "The fishing rod item. lead's choice 2026-11-19, Mastercraft." }
E{ id = "prof.bobber", en = "Bobber", uk = "поплавок", note = "The float on the fishing line. lead's choice 2026-11-19, Mastercraft." }
E{ id = "prof.network", en = "Network", uk = "Мережа", note = "Mastercraft tab or heading: crafters who share with each other. lead's choice 2026-11-19, Mastercraft." }
E{ id = "prof.shop", en = "Shop", uk = "Крамниця", note = "A crafter's shop (what a crafter offers to make). lead's choice 2026-11-19, Mastercraft." }
E{ id = "prof.item_tracker", en = "Item tracker", uk = "Трекер предметів", note = "List of items to collect, with counts. lead's choice 2026-11-19, Mastercraft." }
E{ id = "prof.trade_board", en = "Trade board", uk = "Торгова дошка", note = "Board where crafters and buyers post requests. lead's choice 2026-11-19, Mastercraft." }

-- GatherMate2 (lead's choices 2026-11-20)
E{ id = "prof.node", en = "Node", uk = "Точка збору", note = "A spot to gather from (herb, vein, fish pool); many: «точки збору». lead's choice 2026-11-20, GatherMate2." }
E{ id = "prof.node_treasure", en = "Treasure", uk = "Скарби", note = "Kind of node: chests and treasure. lead's choice 2026-11-20, GatherMate2." }
E{ id = "prof.node_herbs", en = "Herb Bushes", uk = "Кущі трав", note = "Kind of node for Herbalism. lead's choice 2026-11-20, GatherMate2." }
E{ id = "prof.node_veins", en = "Mineral Veins", uk = "Рудні жили", note = "Kind of node for Mining. lead's choice 2026-11-20, GatherMate2." }
E{ id = "prof.node_fish", en = "Fishes", uk = "Рибні місця", note = "Kind of node for Fishing: pools. lead's choice 2026-11-20, GatherMate2." }
E{ id = "prof.node_gas", en = "Gas Clouds", uk = "Газові хмари", note = "Kind of node for Engineering. lead's choice 2026-11-20, GatherMate2." }
E{ id = "prof.node_timber", en = "Timber", uk = "Деревина", note = "Kind of node: logging. lead's choice 2026-11-20, GatherMate2." }
E{ id = "ui.database", en = "Database", uk = "База даних", note = "Where an addon keeps its saved data. lead's choice 2026-11-20, GatherMate2." }
E{ id = "ui.cleanup", en = "Cleanup", uk = "Очищення", note = "Removing old or double data. lead's choice 2026-11-20, GatherMate2." }
E{ id = "ui.radius", en = "Radius", uk = "Радіус", note = "A distance setting. lead's choice 2026-11-20, GatherMate2." }
E{ id = "ui.database_locking", en = "Database Locking", uk = "Блокування бази даних", note = "Stops changes to saved data. lead's choice 2026-11-20, GatherMate2." }
E{ id = "prof.digsite", en = "Digsite", uk = "Розкопки", note = "An Archaeology dig spot (of: розкопок). UALL Forever's word; owner 2026-11-20." }
E{ id = "game.expansion", en = "Expansion", uk = "Доповнення", note = "A game expansion (its name stays English). GatherMate2 text agent, 2026-11-20." }
E{ id = "ui.filters", en = "Filters", uk = "Фільтри", note = "A settings page or group of filters. GatherMate2 text agent, 2026-11-20." }
E{ id = "ui.maintenance", en = "Maintenance", uk = "Обслуговування", note = "A settings page for cleanup and database tools. GatherMate2 text agent, 2026-11-20." }
E{ id = "ui.faq", en = "FAQ", uk = "Запитання", note = "Page name; as a title: «Поширені запитання». GatherMate2 text agent, 2026-11-20." }
E{ id = "ui.merge", en = "Merge", uk = "Об'єднати", note = "Action: join imported data with yours. GatherMate2 text agent, 2026-11-20." }
E{ id = "ui.overwrite", en = "Overwrite", uk = "Перезаписати", note = "Action: replace your data with the imported. GatherMate2 text agent, 2026-11-20." }
E{ id = "ui.yards", en = "yards", uk = "ярдів", note = "Distance unit after a number (1 ярд, 2 ярди, 5 ярдів). GatherMate2 text agent, 2026-11-20." }
