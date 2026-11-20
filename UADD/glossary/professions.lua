-- UADD glossary: professions, their trainers, skill ranks, weapon skills.
-- One line per meaning. Rules: docs/GLOSSARY.md.
local E = UADD.Glossary.Add

-- Professions (and secondary skills)
E{ id = "prof.alchemy", en = "Alchemy", uk = "Алхімія", note = "Profession name." }
E{ id = "prof.blacksmithing", en = "Blacksmithing", uk = "Ковальство", note = "Profession name." }
E{ id = "prof.enchanting", en = "Enchanting", uk = "Зачарування", note = "Profession name." }
E{ id = "prof.engineering", en = "Engineering", uk = "Інженерія", note = "Profession name." }
E{ id = "prof.herbalism", en = "Herbalism", uk = "Травництво", note = "Profession name." }
E{ id = "prof.inscription", en = "Inscription", uk = "Каліграфія", note = "Profession name." }
E{ id = "prof.jewelcrafting", en = "Jewelcrafting", uk = "Ювелірна справа", note = "Profession name." }
E{ id = "prof.leatherworking", en = "Leatherworking", uk = "Шкірництво", note = "Profession name." }
E{ id = "prof.mining", en = "Mining", uk = "Гірництво", note = "Profession name." }
E{ id = "prof.skinning", en = "Skinning", uk = "Здирання шкур", note = "Profession name." }
E{ id = "prof.tailoring", en = "Tailoring", uk = "Кравецтво", note = "Profession name." }
E{ id = "prof.archaeology", en = "Archaeology", uk = "Археологія", note = "Secondary skill name." }
E{ id = "prof.cooking", en = "Cooking", uk = "Кулінарія", note = "Secondary skill name." }
E{ id = "prof.first_aid", en = "First Aid", uk = "Перша допомога", note = "Secondary skill name." }
E{ id = "prof.fishing", en = "Fishing", uk = "Риболовля", note = "Secondary skill name." }

-- Trainers (NPCs who teach)
E{ id = "npc.class_trainer", en = "Class Trainer", uk = "Наставник класу", note = "NPC who teaches class spells." }
E{ id = "npc.profession_trainers", en = "Profession Trainers", uk = "Наставники професій", note = "NPCs who teach professions; a map filter." }
E{ id = "npc.trainer_alchemy", en = "Alchemy Trainer", uk = "Наставник алхімії", note = "NPC who teaches this profession." }
E{ id = "npc.trainer_blacksmithing", en = "Blacksmithing Trainer", uk = "Наставник ковальства", note = "NPC who teaches this profession." }
E{ id = "npc.trainer_enchanting", en = "Enchanting Trainer", uk = "Наставник зачарування", note = "NPC who teaches this profession." }
E{ id = "npc.trainer_engineering", en = "Engineering Trainer", uk = "Наставник інженерії", note = "NPC who teaches this profession." }
E{ id = "npc.trainer_herbalism", en = "Herbalism Trainer", uk = "Наставник травництва", note = "NPC who teaches this profession." }
E{ id = "npc.trainer_inscription", en = "Inscription Trainer", uk = "Наставник каліграфії", note = "NPC who teaches this profession." }
E{ id = "npc.trainer_jewelcrafting", en = "Jewelcrafting Trainer", uk = "Наставник ювелірної справи", note = "NPC who teaches this profession." }
E{ id = "npc.trainer_leatherworking", en = "Leatherworking Trainer", uk = "Наставник шкірництва", note = "NPC who teaches this profession." }
E{ id = "npc.trainer_mining", en = "Mining Trainer", uk = "Наставник гірництва", note = "NPC who teaches this profession." }
E{ id = "npc.trainer_skinning", en = "Skinning Trainer", uk = "Наставник здирання шкур", note = "NPC who teaches this profession." }
E{ id = "npc.trainer_tailoring", en = "Tailoring Trainer", uk = "Наставник кравецтва", note = "NPC who teaches this profession." }
E{ id = "npc.trainer_archaeology", en = "Archaeology Trainer", uk = "Наставник археології", note = "NPC who teaches this skill." }
E{ id = "npc.trainer_cooking", en = "Cooking Trainer", uk = "Наставник кулінарії", note = "NPC who teaches this skill." }
E{ id = "npc.trainer_first_aid", en = "First Aid Trainer", uk = "Наставник першої допомоги", note = "NPC who teaches this skill." }
E{ id = "npc.trainer_fishing", en = "Fishing Trainer", uk = "Наставник риболовлі", note = "NPC who teaches this skill." }
E{ id = "npc.trainer_riding", en = "Riding Trainer", uk = "Наставник їзди верхи", note = "NPC who teaches riding." }
E{ id = "npc.trainer_portal", en = "Portal Trainer", uk = "Наставник порталів", note = "NPC who teaches mages portal spells." }
E{ id = "npc.trainer_battle_pet", en = "Battle Pet Trainer", uk = "Наставник бойових вихованців", note = "NPC for pet battles." }

-- Skill ranks of a profession. "Master" here is the rank, not a master of anything else.
E{ id = "prof.rank_apprentice", en = "Apprentice", uk = "Учень", note = "Profession rank (1-75)." }
E{ id = "prof.rank_journeyman", en = "Journeyman", uk = "Підмайстер", note = "Profession rank (75-150)." }
E{ id = "prof.rank_expert", en = "Expert", uk = "Знавець", note = "Profession rank (150-225)." }
E{ id = "prof.rank_artisan", en = "Artisan", uk = "Ремісник", note = "Profession rank (225-300)." }
E{ id = "prof.rank_master", en = "Master", uk = "Майстер", note = "Profession rank (300-375). Not a master looter or a master volume." }
E{ id = "prof.rank_grand_master", en = "Grand Master", uk = "Великий майстер", note = "Profession rank (375-450)." }
E{ id = "prof.rank_illustrious", en = "Illustrious Grand Master", uk = "Славетний великий майстер", note = "Profession rank (450-525)." }
E{ id = "prof.rank_zen_master", en = "Zen Master", uk = "Майстер дзен", note = "Profession rank (525-600)." }

E{ id = "weapon.skill", en = { "Weapon Skill", "Weapon Skills" }, uk = "Навичка зброї", note = "A skill in using one kind of weapon (plural «Навички зброї»). lead's choice 2026-11-19, What's Training?." }

-- Weapon skills (plural: the kind of weapon)
E{ id = "weapon.one_handed_swords", en = "One-Handed Swords", uk = "Одноручні мечі", note = "Weapon skill." }
E{ id = "weapon.one_handed_maces", en = "One-Handed Maces", uk = "Одноручні булави", note = "Weapon skill." }
E{ id = "weapon.one_handed_axes", en = "One-Handed Axes", uk = "Одноручні сокири", note = "Weapon skill." }
E{ id = "weapon.two_handed_swords", en = "Two-Handed Swords", uk = "Дворучні мечі", note = "Weapon skill." }
E{ id = "weapon.two_handed_maces", en = "Two-Handed Maces", uk = "Дворучні булави", note = "Weapon skill." }
E{ id = "weapon.two_handed_axes", en = "Two-Handed Axes", uk = "Дворучні сокири", note = "Weapon skill." }
E{ id = "weapon.fist_weapons", en = "Fist Weapons", uk = "Кастети", note = "Weapon skill." }
E{ id = "weapon.daggers", en = "Daggers", uk = "Кинджали", note = "Weapon skill." }
E{ id = "weapon.thrown", en = "Thrown", uk = "Метальна зброя", note = "Weapon skill: throwing weapons." }
E{ id = "weapon.bows", en = "Bows", uk = "Луки", note = "Weapon skill." }
E{ id = "weapon.crossbows", en = "Crossbows", uk = "Арбалети", note = "Weapon skill." }
E{ id = "weapon.guns", en = "Guns", uk = "Вогнепальна зброя", note = "Weapon skill." }
E{ id = "weapon.staves", en = "Staves", uk = "Палиці", note = "Weapon skill: two-handed staves." }
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
E{ id = "prof.digsite", en = "Digsite", uk = "Місце розкопок", note = "An Archaeology dig spot. GatherMate2 text agent, 2026-11-20." }
E{ id = "game.expansion", en = "Expansion", uk = "Доповнення", note = "A game expansion (its name stays English). GatherMate2 text agent, 2026-11-20." }
E{ id = "ui.filters", en = "Filters", uk = "Фільтри", note = "A settings page or group of filters. GatherMate2 text agent, 2026-11-20." }
E{ id = "ui.maintenance", en = "Maintenance", uk = "Обслуговування", note = "A settings page for cleanup and database tools. GatherMate2 text agent, 2026-11-20." }
E{ id = "ui.faq", en = "FAQ", uk = "Запитання", note = "Page name; as a title: «Поширені запитання». GatherMate2 text agent, 2026-11-20." }
E{ id = "ui.merge", en = "Merge", uk = "Об'єднати", note = "Action: join imported data with yours. GatherMate2 text agent, 2026-11-20." }
E{ id = "ui.overwrite", en = "Overwrite", uk = "Перезаписати", note = "Action: replace your data with the imported. GatherMate2 text agent, 2026-11-20." }
E{ id = "ui.yards", en = "yards", uk = "ярдів", note = "Distance unit after a number (1 ярд, 2 ярди, 5 ярдів). GatherMate2 text agent, 2026-11-20." }
