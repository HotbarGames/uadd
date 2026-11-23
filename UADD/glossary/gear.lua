-- UADD glossary: words first needed by the Pawn module (UADD_Pawn): item value scales, stat weights,
-- upgrades, gems and sockets, and the item stats Pawn lists. Stat names are UALL Forever's where it has them.
-- One line per meaning. Rules: docs/GLOSSARY.md.
local E = UADD.Glossary.Add

-- Pawn's own ideas (lead's proposal, 2026-11-20; the owner may change them)
E{ id = "gear.scale", en = "Scale", uk = "Шкала", note = "Pawn: a set of stat weights that gives an item a value. Not the window size («масштаб», UALL's word for UI scale)." }
E{ id = "gear.stat_weight", en = { "Stat weight", "Weight" }, uk = "Вага характеристики", note = "Pawn: how much one point of a stat is worth in a scale (the tab: «Вага»)." }
E{ id = "gear.upgrade", en = "Upgrade", uk = "Покращення", note = "An item better than the one you wear (UALL's word)." }
E{ id = "gear.gem", en = { "Gem", "Gems" }, uk = "Самоцвіт", note = "A gem for an item's socket (many: самоцвіти, UALL's word)." }
E{ id = "gear.socket", en = "Socket", uk = "Гніздо", note = "A slot on an item that holds a gem (many: гнізда)." }
E{ id = "gear.enchant", en = "Enchant", uk = "Зачарування", note = "An enchantment on an item. Not the profession (prof.enchanting «Накладання чарів», owner 2026-11-20)." }
E{ id = "gear.advisor", en = "Advisor", uk = "Порадник", note = "Pawn: the part that marks upgrades in loot, bags and quest rewards." }
E{ id = "gear.stats", en = "Stats", uk = "Характеристики", note = "An item's or a character's stats, together (UALL's word)." }

-- More item stats (UALL Forever's words; the first ones are in journal.lua, stat.*)
E{ id = "stat.armor", en = "Armor", uk = "Броня", note = "Item stat: the armor value. Not the gear kind (gear.armor)." }
E{ id = "stat.spell_power", en = "Spell Power", uk = "Сила заклять", note = "Item stat." }
E{ id = "stat.ranged_attack_power", en = "Ranged Attack Power", uk = "Сила дальнього бою", note = "Item stat." }
E{ id = "stat.haste", en = "Haste", uk = "Поспіх", note = "Item stat." }
E{ id = "stat.expertise", en = "Expertise", uk = "Вправність", note = "Item stat." }
E{ id = "stat.mastery", en = "Mastery", uk = "Майстерність", note = "Item stat." }
E{ id = "stat.versatility", en = "Versatility", uk = "Універсальність", note = "Item stat." }
E{ id = "stat.defense", en = "Defense", uk = "Захист", note = "Item stat (Classic tanks)." }
E{ id = "stat.dodge", en = "Dodge", uk = "Ухиляння", note = "Item stat." }
E{ id = "stat.parry", en = "Parry", uk = "Парирування", note = "Item stat." }
E{ id = "stat.block_chance", en = "Block Chance", uk = "Шанс блокування", note = "Item stat." }
E{ id = "stat.spell_penetration", en = "Spell Penetration", uk = "Проникнення чарів", note = "Item stat." }
E{ id = "stat.movement_speed", en = "Movement Speed", uk = "Швидкість пересування", note = "Item stat." }
E{ id = "stat.mp5", en = "Mana per 5 sec.", uk = "Мана за 5 сек.", note = "Item stat: mana back every 5 seconds." }
-- Stat groups first needed by AutoPotion 4.1.1 (lead's choice, 2026-11-21)
E{ id = "stat.primary", en = "Primary Stat", uk = "Основна характеристика", note = "The class's main stat (strength, agility or intellect). AutoPotion, 2026-11-21." }
E{ id = "stat.health_regen", en = "Health Regen", uk = "Відновлення здоров'я", note = "Health back over time. AutoPotion, 2026-11-21." }
E{ id = "stat.mana_regen", en = "Mana Regen", uk = "Відновлення мани", note = "Mana back over time. AutoPotion, 2026-11-21." }
E{ id = "stat.armor_penetration", en = "Armor Penetration", uk = "Пробиття броні", note = "Item stat. AutoPotion, 2026-11-21." }
E{ id = "stat.resistance", en = "Resistance", uk = "Опір", note = "One resistance to a spell school (many: game.resistances «Опори»). AutoPotion, 2026-11-21." }

-- GearQuest Forever's own features (lead's choices 2026-11-23)
E{ id = "game.spec", en = { "Spec", "spec" }, uk = "спеціалізація", note = "A talent spec of a class. lead's choice 2026-11-23, GearQuest Forever." }
E{ id = "gear.guide", en = "Guide", uk = "Гід", note = "GearQuest's talking guide that shows the way (a person: гіда, гіду). Not prof.guide. lead's choice 2026-11-23, GearQuest Forever." }
E{ id = "gear.hunt", en = { "Hunt", "hunt" }, uk = "Полювання", note = "GearQuest's tracked search for one item. lead's choice 2026-11-23, GearQuest Forever." }
E{ id = "gear.log", en = "Log", uk = "Журнал", note = "GearQuest's main window (its log of gear). lead's choice 2026-11-23, GearQuest Forever." }
E{ id = "gear.simulator", en = "Simulator", uk = "Симулятор", note = "GearQuest's tab that tries gear on. lead's choice 2026-11-23, GearQuest Forever." }
E{ id = "gear.score", en = "Score", uk = "Оцінка", note = "An item's number for your spec in GearQuest. lead's choice 2026-11-23, GearQuest Forever." }
E{ id = "gear.bis", en = "BiS", uk = "БіС", note = "Best in slot: the best item for a slot (Список БіС). Owner's choice 2026-11-23, OneForAll; Latin BiS is banned there." }

-- Item quality and binding (game words; first needed by Simple Item Level, 2026-11-23)
E{ id = "gear.quality_poor", en = "Poor", uk = "Жалюгідний", note = "Item quality 0, grey (UALL Forever's word)." }
E{ id = "gear.quality_common", en = "Common", uk = "Звичайний", note = "Item quality 1, white (UALL Forever's word)." }
E{ id = "gear.quality_uncommon", en = "Uncommon", uk = "Незвичайний", note = "Item quality 2, green (UALL Forever's word)." }
E{ id = "gear.quality_rare", en = "Rare", uk = "Рідкісний", note = "Item quality 3, blue (UALL Forever's word). Not a rare mob (rare.*)." }
E{ id = "gear.quality_epic", en = "Epic", uk = "Епічний", note = "Item quality 4, purple (UALL Forever's word)." }
E{ id = "gear.quality_legendary", en = "Legendary", uk = "Легендарний", note = "Item quality 5, orange. Not the quest tag (quest.tag_legendary «Легендарне»)." }
E{ id = "gear.quality_artifact", en = "Artifact", uk = "Артефакт", note = "Item quality 6 (UALL Forever's word)." }
E{ id = "gear.quality_heirloom", en = "Heirloom", uk = "Реліквія роду", note = "Item quality 7 (UALL Forever's word)." }
E{ id = "gear.soulbound", en = "Soulbound", uk = "Персональний", note = "An item bound to you (ClassicUA's ITEM_SOULBOUND; UALL Forever says «Прив'язаний до душі»: ClassicUA's word first, owner 2026-11-20)." }
