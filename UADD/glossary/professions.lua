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
