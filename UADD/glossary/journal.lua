-- UADD glossary: words first needed by the Dungeon Journal module (UADD_DungeonJournal):
-- bosses and loot, quest tracking, item stats, spell schools, gear slots, dungeon wing names.
-- One line per meaning. Rules: docs/GLOSSARY.md.
local E = UADD.Glossary.Add

-- Dungeons, bosses, loot
E{ id = "game.dungeon_journal", en = "Dungeon Journal", uk = "Журнал підземель", note = "The journal of dungeons, bosses and loot; a window title." }
E{ id = "game.bosses", en = "Bosses", uk = "Боси", note = "The bosses of a dungeon; a tab or heading." }
E{ id = "game.loot", en = "Loot", uk = "Здобич", note = "Items that drop from bosses and monsters; a tab or heading." }
E{ id = "game.trash_loot", en = "Trash Drops", uk = "Здобич зі звичайних ворогів", note = "Loot from a dungeon's ordinary (non-boss) monsters; a row in the boss list." }
E{ id = "ui.favourites", en = { "Favourites", "Favorites" }, uk = "Обране", note = "The items a player marked to keep an eye on; a button and window title." }
E{ id = "game.raids", en = "Raids", uk = "Рейди", note = "Raid instances, many; a list title or icon label." }
E{ id = "game.reward", en = "Reward", uk = "Нагорода", note = "What a quest gives; a heading." }
E{ id = "game.rewards", en = "Rewards", uk = "Нагороди", note = "Many rewards; a heading." }
E{ id = "game.entrance", en = "Entrance", uk = "Вхід", note = "Map label: the way into a dungeon or a cave." }
E{ id = "game.resistances", en = "Resistances", uk = "Опори", note = "Resistance to spell schools (fire, frost...); a filter heading." }
E{ id = "map.route", en = "Route", uk = "Маршрут", note = "A drawn path on the map that leads to a place; a button." }

-- Quests
E{ id = "quest.turn_in", en = "Turn in", uk = "Здати", note = "Action or label: hand in a finished quest." }
E{ id = "quest.quest_giver", en = "Quest giver", uk = "Видає завдання", note = "The NPC who gives a quest; a map pin label." }
E{ id = "quest.track", en = "Track", uk = "Стежити", note = "Button: start showing quests and progress on screen." }
E{ id = "quest.tracking", en = "Tracking", uk = "Відстежується", note = "State of that button: these quests are shown on screen now." }
E{ id = "quest.description", en = "Description", uk = "Опис", note = "The story text of a quest; a heading." }

-- Small UI words
E{ id = "ui.done", en = "Done", uk = "Готово", note = "Button that ends an edit mode." }
E{ id = "ui.copy", en = "Copy", uk = "Копіювати", note = "Button: copy a text or link." }
E{ id = "ui.clear", en = "Clear", uk = "Очистити", note = "Button: untick or empty all choices." }
E{ id = "ui.notes", en = "Notes", uk = "Примітки", note = "Extra hints written by the addon; a heading." }
E{ id = "ui.locked", en = "Locked", uk = "Замкнено", note = "State: a page or feature is not open yet." }
E{ id = "ui.coming_soon", en = "Coming Soon", uk = "Незабаром", note = "Label on something that is not ready yet." }
E{ id = "ui.not_bound", en = "Not Bound", uk = "Не призначено", note = "Key binding state: no key is set." }
E{ id = "ui.report_bug", en = "Report a Bug", uk = "Повідомити про помилку", note = "Button or title: tell the authors about a bug." }
E{ id = "ui.version_n", en = "Version: %s", uk = "Версія: %s", note = "Addon version with its number." }
E{ id = "ui.language_n", en = "Language: %s", uk = "Мова: %s", note = "The current language with its name." }

-- Item stats (as in item filters and tooltips)
E{ id = "stat.strength", en = "Strength", uk = "Сила", note = "Item stat." }
E{ id = "stat.agility", en = "Agility", uk = "Спритність", note = "Item stat." }
E{ id = "stat.stamina", en = "Stamina", uk = "Витривалість", note = "Item stat." }
E{ id = "stat.intellect", en = "Intellect", uk = "Інтелект", note = "Item stat." }
E{ id = "stat.spirit", en = "Spirit", uk = "Дух", note = "Item stat." }
E{ id = "stat.attack_power", en = "Attack Power", uk = "Сила атаки", note = "Item stat." }
E{ id = "stat.spell_damage", en = "Spell Damage", uk = "Шкода від заклять", note = "Item stat: more damage from spells." }
E{ id = "stat.healing", en = "Healing", uk = "Зцілення", note = "Item stat: stronger heals." }
E{ id = "stat.crit", en = "Critical Strike", uk = "Критичний удар", note = "Item stat: chance of a critical hit." }
E{ id = "stat.hit", en = "Hit", uk = "Влучання", note = "Item stat: chance to hit. Not 'a blow'." }

-- Spell schools (resistance filters)
E{ id = "school.fire", en = "Fire", uk = "Вогонь", note = "Spell school; also its resistance." }
E{ id = "school.frost", en = "Frost", uk = "Мороз", note = "Spell school; also its resistance." }
E{ id = "school.nature", en = "Nature", uk = "Природа", note = "Spell school; also its resistance." }
E{ id = "school.shadow", en = "Shadow", uk = "Тінь", note = "Spell school; also its resistance." }
E{ id = "school.arcane", en = "Arcane", uk = "Таємна магія", note = "Spell school; also its resistance." }
E{ id = "school.holy", en = "Holy", uk = "Святість", note = "Spell school." }

-- Gear kinds and slots (loot filter buttons, and the type line under each loot item: "Two-Hand, Axe").
-- The game's own words (UALL) where it has them; "Back" and "Finger" are the slots, not "назад"/"палець".
E{ id = "gear.armor", en = "Armor", uk = "Броня", note = "Gear kind: armor pieces." }
E{ id = "gear.weapon", en = { "Weapon", "Weapons" }, uk = "Зброя", note = "Gear kind: weapons (one or many: same word)." }
E{ id = "gear.ring", en = { "Ring", "Finger" }, uk = "Каблучка", note = "Gear slot: finger ring." }
E{ id = "gear.neck", en = "Neck", uk = "Шия", note = "Gear slot: the neck (amulets)." }
E{ id = "gear.trinket", en = "Trinket", uk = "Дрібничка", note = "Gear slot: trinket." }
E{ id = "gear.cloak", en = { "Cloak", "Back" }, uk = "Плащ", note = "Gear slot: cloak (back)." }
E{ id = "gear.head", en = "Head", uk = "Голова", note = "Gear slot: helmets." }
E{ id = "gear.shoulder", en = "Shoulder", uk = "Плечі", note = "Gear slot: shoulder pads." }
E{ id = "gear.chest", en = "Chest", uk = "Нагрудник", note = "Gear slot: chest armor." }
E{ id = "gear.shirt", en = "Shirt", uk = "Сорочка", note = "Gear slot: shirt." }
E{ id = "gear.wrist", en = "Wrist", uk = "Зап'ястя", note = "Gear slot: bracers." }
E{ id = "gear.hands", en = "Hands", uk = "Кисті", note = "Gear slot: gloves." }
E{ id = "gear.waist", en = "Waist", uk = "Пояс", note = "Gear slot: belts." }
E{ id = "gear.legs", en = "Legs", uk = "Ноги", note = "Gear slot: leg armor." }
E{ id = "gear.feet", en = "Feet", uk = "Стопи", note = "Gear slot: boots." }
E{ id = "gear.cloth", en = "Cloth", uk = "Тканина", note = "Armor type of an item: cloth. Not the trade good." }
E{ id = "gear.leather", en = "Leather", uk = "Шкіра", note = "Armor type of an item: leather. Not the trade good." }
E{ id = "gear.mail", en = "Mail", uk = "Кольчуга", note = "Armor type of an item: mail. Not letters." }
E{ id = "gear.plate", en = "Plate", uk = "Лати", note = "Armor type of an item: plate." }
E{ id = "gear.two_hand", en = "Two-Hand", uk = "Дворучна", note = "How a weapon is held: in both hands (agrees with зброя)." }
E{ id = "gear.one_hand", en = "One-Hand", uk = "Одноручна", note = "How a weapon is held: in either hand (agrees with зброя)." }
E{ id = "gear.main_hand", en = "Main Hand", uk = "Основна рука", note = "Weapon slot: the main hand only." }
E{ id = "gear.off_hand", en = "Off Hand", uk = "Друга рука", note = "Weapon slot: the off hand only." }
E{ id = "gear.held_off_hand", en = { "Held In Off-hand", "Held In Off-Hand" }, uk = "У другій руці", note = "Item slot: a book or orb held in the off hand." }
E{ id = "gear.ranged", en = "Ranged", uk = "Дальній бій", note = "Weapon slot: bows, guns, wands." }
E{ id = "gear.axe", en = "Axe", uk = "Сокира", note = "Weapon type of an item." }
E{ id = "gear.mace", en = "Mace", uk = "Булава", note = "Weapon type of an item." }
E{ id = "gear.sword", en = "Sword", uk = "Меч", note = "Weapon type of an item." }
E{ id = "gear.dagger", en = "Dagger", uk = "Кинджал", note = "Weapon type of an item." }
E{ id = "gear.staff", en = "Staff", uk = "Посох", note = "Weapon type of an item. Not the people at work." }
E{ id = "gear.polearm", en = "Polearm", uk = "Древкова зброя", note = "Weapon type of an item." }
E{ id = "gear.fist_weapon", en = "Fist Weapon", uk = "Кулачна зброя", note = "Weapon type of an item." }
E{ id = "gear.shield", en = "Shield", uk = "Щит", note = "Item type: shield. Not the spell." }
E{ id = "gear.bow", en = "Bow", uk = "Лук", note = "Weapon type of an item." }
E{ id = "gear.gun", en = "Gun", uk = "Рушниця", note = "Weapon type of an item." }
E{ id = "gear.crossbow", en = "Crossbow", uk = "Арбалет", note = "Weapon type of an item." }
E{ id = "gear.wand", en = "Wand", uk = "Чарівна паличка", note = "Weapon type of an item." }
E{ id = "gear.thrown", en = "Thrown", uk = "Метальна зброя", note = "Weapon type of an item (as weapon.thrown, the skill)." }
E{ id = "gear.relic", en = "Relic", uk = "Реліквія", note = "Item slot: relic (librams, totems, idols)." }
E{ id = "gear.libram", en = "Libram", uk = "Фоліант", note = "Relic type for paladins." }
E{ id = "gear.totem", en = "Totem", uk = "Тотем", note = "Relic type for shamans." }
E{ id = "gear.idol", en = "Idol", uk = "Ідол", note = "Relic type for druids." }
E{ id = "gear.projectile", en = "Projectile", uk = "Боєприпаси", note = "Item class: arrows and bullets." }
E{ id = "gear.arrow", en = "Arrow", uk = "Стріла", note = "Ammo type: arrows for bows." }
E{ id = "gear.bullet", en = "Bullet", uk = "Куля", note = "Ammo type: bullets for guns." }

-- Item kinds (the same type line): bags, recipes, consumables
E{ id = "item.bag", en = "Bag", uk = "Торба", note = "Item type: a bag." }
E{ id = "item.quiver", en = "Quiver", uk = "Сагайдак", note = "Item type: a bag for arrows." }
E{ id = "item.ammo_pouch", en = "Ammo Pouch", uk = "Сумка для набоїв", note = "Item type: a bag for bullets." }
E{ id = "item.recipe", en = "Recipe", uk = "Рецепт", note = "Item type: teaches a profession recipe; one item." }
E{ id = "item.leatherworking_recipe", en = "Leatherworking Recipe", uk = "Рецепт шкірництва", note = "Item type: a leatherworking pattern." }
E{ id = "item.blueprint", en = "Blueprint", uk = "Креслення", note = "Item type: an engineering schematic." }
E{ id = "item.consumable", en = "Consumable", uk = "Витратний предмет", note = "Item type: used up when used." }
E{ id = "item.potion", en = "Potion", uk = "Зілля", note = "Item type: a potion." }
E{ id = "item.food", en = "Food", uk = "Їжа", note = "Item type: food (vendor.food is what a vendor sells)." }
E{ id = "item.drink", en = "Drink", uk = "Напій", note = "Item type: one drink (vendor.drink is the vendor kind)." }
E{ id = "item.quest", en = "Quest Item", uk = "Предмет завдання", note = "Item type: needed for a quest." }
E{ id = "item.key", en = "Key", uk = "Ключ", note = "Item type: opens a door or chest. Not a keyboard key." }
E{ id = "item.reagent", en = "Crafting Reagent", uk = "Реагент для ремесла", note = "Item type: used to make other items." }
E{ id = "item.reagent_class", en = "Reagent", uk = "Реагент", note = "Item class on its own (Righteous Orb, Skin of Shadow): a reagent for spells or crafting." }
E{ id = "item.misc", en = "Miscellaneous", uk = "Різне", note = "Item type: anything else." }

-- Dungeon wings with no game name of their own. Shown after the dungeon name and a colon,
-- "<dungeon>: <wing>", so the word stands alone in the nominative and agrees with nothing.
E{ id = "wing.living", en = "Living", uk = "Живі", note = "Stratholme wing of the living (Scarlet side): 'Стратгольм: Живі'." }
E{ id = "wing.undead", en = "Undead", uk = "Нежить", note = "Stratholme wing of the undead (Baron's side): 'Стратгольм: Нежить'." }
