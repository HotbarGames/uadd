-- UADD glossary: core game words (quest, NPC, item, zone, level...), factions, classes, races.
-- One line per meaning. Rules: docs/GLOSSARY.md.
local E = UADD.Glossary.Add

-- Core concepts
E{ id = "game.quest", en = { "Quest", "Quests" }, uk = "Завдання", note = "A quest (one or many: the Ukrainian word is the same). Also a tab or heading." }
E{ id = "game.quest_log", en = "Quest Log", uk = "Журнал завдань", note = "The game's quest log window." }
E{ id = "game.npc", en = { "NPC", "NPCs" }, uk = "НІП", note = "Non-player character (one or many). Our fixed short word: НІП." }
E{ id = "game.item", en = "Item", uk = "Предмет", note = "One thing in bags or loot." }
E{ id = "game.items", en = "Items", uk = "Предмети", note = "Many items; also a tab or heading." }
E{ id = "game.object", en = "Object", uk = "Об'єкт", note = "A clickable thing in the world: a chest, a sign, a plant. Not 'the goal' (game.objective)." }
E{ id = "game.objects", en = "Objects", uk = "Об'єкти", note = "Many world objects; also a tab or heading." }
E{ id = "game.objective", en = "Objective", uk = "Ціль", note = "One step a quest asks for (kill 10 boars). Careful: ціль is also 'target'." }
E{ id = "game.objectives", en = "Objectives", uk = "Цілі", note = "The steps of a quest; also a heading." }
E{ id = "game.zone", en = "Zone", uk = "Зона", note = "An area of the world map (Elwynn Forest). Zone names themselves come from UALLF." }
E{ id = "game.server_layer", en = "Layer", uk = "Лейер", note = "A copy of the server's world: players on another layer do not see you (LayerSwap). Owner's word, 2026-11-18, for now: keep it one term so it can be swapped. Not «шар»: that is a drawn map layer (map.layer)." }
E{ id = "game.mount", en = "Mount", uk = "Маунт", note = "A creature or machine you ride or fly on (LiteMount). The owner's word, 2026-11-20: маунт, маунта, маунти, маунтів, на маунті. Not «їздова тварина» (UALL Forever) or «верхове створіння» (ClassicUA): a mechanostrider is no animal. RareScanner's older texts still say «їздові тварини»." }
E{ id = "game.mount_summon", en = "Summon", uk = "Викликати", note = "Call a mount (LiteMount): «викликати маунта», animate accusative. lead's choice 2026-11-20." }
E{ id = "game.mount_family", en = "Family", uk = "Родина", note = "LiteMount: a group of mounts with one model (all mechanostriders). Not a pet family. lead's choice 2026-11-20." }
E{ id = "game.mount_flag", en = "Flag", uk = "Прапор", note = "LiteMount: a tag on a mount (Fly, Swim, Favorite). Not Questie's bit flags («Прапорці»). lead's choice 2026-11-20." }
E{ id = "game.level", en = "Level", uk = "Рівень", note = "Character, NPC or quest level (a number). Not sound volume." }
E{ id = "game.level_n", en = "Level %s", uk = "Рівень %s", note = "Level with its number." }
E{ id = "game.item_level", en = "Item Level", uk = "Рівень предмета", note = "An item's level (a number): a heading, a search range, a tooltip line. A narrow column header: game.item_level_short." }
E{ id = "game.item_level_short", en = "Item Level", uk = "Рівень", note = "Short form for a narrow column header (Auctionator's result lists: the column is about items); the full form is game.item_level." }
E{ id = "game.experience", en = "Experience", uk = "Досвід", note = "Experience points (XP)." }
E{ id = "game.reputation", en = "Reputation", uk = "Репутація", note = "Standing with a faction." }
E{ id = "game.health", en = "Health", uk = "Здоров'я", note = "Hit points of a character or NPC." }
E{ id = "game.spell", en = { "Spell", "Spells" }, uk = "Закляття", note = "A spell or ability you cast (one or many: same word). UALL's word (about 1190 uses against 12 of «заклинання»)." }
E{ id = "game.cooldown", en = "Cooldown", uk = "Перезарядка", note = "The wait before a spell or item can be used again." }
E{ id = "game.class", en = "Class", uk = "Клас", note = "Character class (warrior, mage...). Also a category of class quests." }
E{ id = "game.group", en = { "Group", "Party" }, uk = "Група", note = "A party of up to five players; a group quest tag; the party chat channel." }
E{ id = "game.raid", en = "Raid", uk = "Рейд", note = "A big group, a raid instance, a raid quest tag." }
E{ id = "game.dungeon", en = { "Dungeon", "Dungeons" }, uk = "Підземелля", note = "Five-player instance (one or many: same word); a dungeon quest tag." }
E{ id = "game.instance", en = "Instance", uk = "Підземелля", note = "A private copy of a dungeon or raid." }
E{ id = "game.scenario", en = "Scenario", uk = "Сценарій", note = "Scenario: a short instanced story for a few players." }
E{ id = "game.scenarios", en = "Scenarios", uk = "Сценарії", note = "Many scenarios; a category." }
E{ id = "game.battlegrounds", en = "Battlegrounds", uk = "Поля бою", note = "PvP battlegrounds; a category." }
E{ id = "game.pvp", en = "PvP", uk = "ПвП", note = "Player against player (Комплекти ПвП). Owner's choice 2026-11-23, OneForAll; Latin PvP is banned there." }
E{ id = "game.achievements", en = "Achievements", uk = "Досягнення", note = "Achievements; also a tab or heading." }
E{ id = "game.professions", en = "Professions", uk = "Професії", note = "Trade skills; a category or heading." }
E{ id = "game.recipes", en = "Recipes", uk = "Рецепти", note = "Profession recipes (patterns, plans, formulas)." }
E{ id = "game.event", en = "Event", uk = "Подія", note = "A world or holiday event; an event quest tag." }
E{ id = "game.events", en = "Events", uk = "Події", note = "Many world or holiday events; a category." }
E{ id = "game.map", en = "Map", uk = "Карта", note = "The world map; also the map settings tab." }
E{ id = "game.world_map", en = "World Map", uk = "Карта світу", note = "The game's world map window." }
E{ id = "game.minimap", en = "Minimap", uk = "Мінікарта", note = "The small round map; also the minimap settings tab. Owner chose мінікарта over мінімапа (2026-11-13)." }
E{ id = "game.nameplates", en = "Nameplates", uk = "Таблички імен", note = "The name bars over units' heads." }
E{ id = "game.battle_pets", en = "Battle Pets", uk = "Бойові вихованці", note = "Pet battle pets; a category." }
E{ id = "game.pet_battle", en = "Pet Battle", uk = "Битва вихованців", note = "A pet battle; an event or quest type." }

-- Factions
E{ id = "game.alliance", en = "Alliance", uk = "Альянс", note = "The Alliance faction." }
E{ id = "game.horde", en = "Horde", uk = "Орда", note = "The Horde faction." }

-- Classes
E{ id = "class.warrior", en = "Warrior", uk = "Воїн", note = "Class name." }
E{ id = "class.paladin", en = "Paladin", uk = "Паладин", note = "Class name." }
E{ id = "class.shaman", en = "Shaman", uk = "Шаман", note = "Class name." }
E{ id = "class.rogue", en = "Rogue", uk = "Розбійник", note = "Class name." }
E{ id = "class.mage", en = "Mage", uk = "Маг", note = "Class name." }
E{ id = "class.druid", en = "Druid", uk = "Друїд", note = "Class name." }
E{ id = "class.priest", en = "Priest", uk = "Жрець", note = "Class name." }
E{ id = "class.hunter", en = "Hunter", uk = "Мисливець", note = "Class name." }
E{ id = "class.warlock", en = "Warlock", uk = "Чорнокнижник", note = "Class name." }
E{ id = "class.death_knight", en = "Death Knight", uk = "Лицар смерті", note = "Class name." }
E{ id = "class.monk", en = "Monk", uk = "Монах", note = "Class name." }

-- Playable races (the race name, not the male/female voice names)
E{ id = "race.human", en = "Human", uk = "Людина", note = "Race name." }
E{ id = "race.orc", en = "Orc", uk = "Орк", note = "Race name." }
E{ id = "race.dwarf", en = "Dwarf", uk = "Дворф", note = "Race name." }
E{ id = "race.night_elf", en = "Night Elf", uk = "Нічний ельф", note = "Race name." }
E{ id = "race.undead", en = "Undead", uk = "Нежить", note = "Race name (the Forsaken)." }
E{ id = "race.tauren", en = "Tauren", uk = "Таурен", note = "Race name." }
E{ id = "race.gnome", en = "Gnome", uk = "Гном", note = "Race name." }
E{ id = "race.troll", en = "Troll", uk = "Троль", note = "Race name." }
E{ id = "race.goblin", en = "Goblin", uk = "Гоблін", note = "Race name." }
E{ id = "race.draenei", en = "Draenei", uk = "Дреней", note = "Race name." }
E{ id = "race.blood_elf", en = "Blood Elf", uk = "Ельф крові", note = "Race name." }
E{ id = "race.worgen", en = "Worgen", uk = "Ворген", note = "Race name." }
E{ id = "race.pandaren", en = "Pandaren", uk = "Пандарен", note = "Race name." }

-- Attunes, standings, roles, NPC ranks (first used by UADD_Attune)
E{ id = "game.attunement", en = "Attunement", uk = "Допуск", note = "Access to a raid or dungeon earned by a quest chain; one chain in Attune." }
E{ id = "game.attunements", en = { "Attunes", "Attunements" }, uk = "Допуски", note = "Many attunements; a list title or column." }
E{ id = "game.step", en = "Step", uk = "Крок", note = "One step of a quest chain or attunement." }
E{ id = "game.character", en = "Character", uk = "Персонаж", note = "One of the player's characters; a column header." }
E{ id = "game.characters", en = "Characters", uk = "Персонажі", note = "Many characters; a list title." }
E{ id = "game.alt", en = "Alt", uk = "Альт", note = "A player's second (alternative) character." }
E{ id = "game.main_character", en = "Main", uk = "Основний", note = "A player's main character (a status label), not 'main menu'." }
E{ id = "rep.honored", en = "Honored", uk = "Шанований", note = "Reputation standing, as UALL names it." }
E{ id = "rep.revered", en = "Revered", uk = "Поважаний", note = "Reputation standing, as UALL names it." }
E{ id = "rep.exalted", en = "Exalted", uk = "Звеличений", note = "Reputation standing, as UALL names it." }
E{ id = "role.tank", en = "Tank", uk = "Танк", note = "Group role that takes the hits." }
E{ id = "role.healer", en = "Healer", uk = "Цілитель", note = "Group role that heals." }
E{ id = "role.melee_dps", en = "Melee DPS", uk = "Ближній бій", note = "Group role: damage dealer in melee; short form for narrow columns." }
E{ id = "role.ranged_dps", en = "Ranged DPS", uk = "Дальній бій", note = "Group role: damage dealer at range; short form for narrow columns." }
E{ id = "npc.rank_elite", en = "Elite", uk = "еліта", note = "NPC rank before the creature kind. A noun, so it has no gender and reads right next to any kind word: 'Рівень 60 еліта Людина'. A quest tag is quest.tag_elite." }
E{ id = "npc.rank_rare_elite", en = "Rare Elite", uk = "рідкісна еліта", note = "NPC rank before the creature kind (Attune). Noun, no gender, like npc.rank_elite. A map filter label is map.filter_rare_elite." }
E{ id = "map.filter_rare_elite", en = "Rare Elite", uk = "Рідкісний елітний", note = "Map filter label for rare elite NPCs (OpenMap); an adjective, read as a type of NPC. An NPC rank before a kind word is npc.rank_rare_elite." }
E{ id = "map.filter_rare", en = "Rare", uk = "Рідкісний", note = "Map filter label for rare NPCs (OpenMap). Not item quality (gear.quality_rare)." }
E{ id = "step.interact", en = "Interact", uk = "Взаємодіяти", note = "Attune step type; a verb like the other step types (Убити, Взяти, Здати). Questie's icon name is icon.interact." }
E{ id = "icon.interact", en = "Interact", uk = "Взаємодія", note = "Name of the Questie map icon for objectives where you interact with an object or NPC; a noun like 'Розмова'. A step type is step.interact." }
E{ id = "npc.rank_boss", en = "Boss", uk = "Бос", note = "NPC rank: a dungeon or raid boss." }
E{ id = "ui.survey", en = "Survey", uk = "Опитування", note = "Asking guild or group members for their progress; a button or tab." }

-- Mastercraft (lead's choices 2026-11-19)
E{ id = "game.rested_xp", en = "Rested XP", uk = "Досвід відпочинку", note = "Bonus experience stored while resting; the same as UADD_ForeverXPBar ships. lead's choice 2026-11-19, Mastercraft." }
E{ id = "game.camping", en = "Camping", uk = "Табір", note = "UALL Forever's camp system (its quests: «Табірна наука 101: ...»). Never «чатування»: that is waiting at a spawn. lead's choice 2026-11-19, Mastercraft." }
E{ id = "game.crafting", en = "Crafting", uk = "Ремесло", note = "Forever's quest category for crafting quests (Questie's event list), and Bagnon's bag filter. ClassicUA's word; UALL Forever says «Виготовлення»." }
E{ id = "game.camp_item", en = "camp item", uk = "похідний предмет", note = "The item of the camp system, as UALL Forever names it. lead's choice 2026-11-19, Mastercraft." }

-- What's Training? (lead's choices 2026-11-19)
E{ id = "game.spellbook", en = "Spellbook", uk = "Книга заклять", note = "The game's spellbook window, as UALL Forever names it. lead's choice 2026-11-19, What's Training?." }
E{ id = "game.grimoire", en = "Grimoire", uk = "Гримуар", note = "A warlock pet's spell tome. lead's choice 2026-11-19, What's Training?." }
E{ id = "game.train", en = "Train", uk = "Вивчити", note = "Learn a spell or skill from a trainer (a button, an action). lead's choice 2026-11-19, What's Training?." }
-- Speedy AutoLoot (lead's choices 2026-11-20; each is UALL Forever's own word)
E{ id = "game.auto_loot", en = "Auto Loot", uk = "Автозбір здобичі", note = "Taking all loot at once, as the game's setting does. lead's choice 2026-11-20, Speedy AutoLoot." }
E{ id = "game.inventory", en = "Inventory", uk = "Інвентар", note = "Your bags as a whole (\"inventory is full\"). lead's choice 2026-11-20, Speedy AutoLoot." }
E{ id = "game.bind_on_pickup", en = "Bind on Pickup", uk = "Прив'язується при отриманні", note = "An item that binds when you loot it. lead's choice 2026-11-20, Speedy AutoLoot." }
E{ id = "game.need_greed", en = "Need/Greed", uk = "Потреба/Жадібність", note = "The group loot roll. Neither UALL Forever nor ClassicUA names it (checked 2026-11-22). lead's choice, DeleteCheapestItem Reloaded." }
E{ id = "game.bag_slot", en = "slot", uk = "комірка", note = "One place in a bag (many: комірки), as LootTriage says it. Not a gear slot. 2026-11-22." }
E{ id = "game.loot_display", en = "Loot Display", uk = "Показ здобичі", note = "Speedy AutoLoot's list of what you just looted. lead's choice 2026-11-20, Speedy AutoLoot." }
-- OneForAll (lead's choices 2026-11-23)
E{ id = "game.pet", en = { "Pet", "Pets" }, uk = "Вихованець", note = "A hunter's or warlock's pet (many: вихованці). ClassicUA's word; UALL Forever says «улюбленець», banned in UADD_OneForAll. lead's choice 2026-11-23, OneForAll." }
E{ id = "game.pet_ability", en = "Ability", uk = "Вміння", note = "A pet's ability (Bite, Claw). Not a profession's skill (game.skill_points). lead's choice 2026-11-23, OneForAll." }
E{ id = "game.pet_family", en = "Family", uk = "Родина", note = "A hunter pet's family (cats, wolves). Not game.mount_family. lead's choice 2026-11-23, OneForAll." }
E{ id = "game.pet_diet", en = "Diet", uk = "Раціон", note = "What a hunter pet eats (meat, fish). Neither UALL Forever nor ClassicUA names it. lead's choice 2026-11-23, OneForAll." }
E{ id = "game.stable", en = "Stable", uk = "Стайня", note = "Where a hunter keeps extra pets. UALL Forever's word. lead's choice 2026-11-23, OneForAll." }
E{ id = "game.tame", en = "Tame", uk = "Приборкати", note = "Make a beast your pet (UALL Forever: Tame Beast «Приборкання звіра»). lead's choice 2026-11-23, OneForAll." }
E{ id = "game.pet_trainer", en = "Pet Trainer", uk = "Тренер вихованців", note = "NPC who teaches hunter pets. Not npc.trainer_battle_pet. lead's choice 2026-11-23, OneForAll." }
E{ id = "game.training_points", en = "Training Points", uk = "Очки навчання", note = "A hunter pet's points to learn abilities; short form after a number «оч. навч.». lead's choice 2026-11-23, OneForAll." }
E{ id = "game.spell_rank", en = "Rank", uk = "Ранг", note = "A spell's or ability's rank (Rank 3). Not a profession rank (prof.rank_*). lead's choice 2026-11-23, OneForAll." }
E{ id = "game.skill_points", en = "Skill", uk = "Навичка", note = "A profession's skill points (150/300). Not a pet ability (game.pet_ability). lead's choice 2026-11-23, OneForAll." }
E{ id = "game.skill_up", en = "Skill-Up", uk = "Підвищення навички", note = "A craft that raises your profession skill. lead's choice 2026-11-23, OneForAll." }
E{ id = "game.crafting_list", en = "Crafting List", uk = "Список ремесла", note = "OneForAll's list of things to craft. lead's choice 2026-11-23, OneForAll." }
E{ id = "game.durability", en = "Durability", uk = "Міцність", note = "Gear wear. UALL Forever's word. lead's choice 2026-11-23, OneForAll." }
E{ id = "game.disenchant", en = "Disenchant", uk = "Розчаклування", note = "A label for the enchanting action (UALL Forever's verb: «Розчаклувати»). lead's choice 2026-11-23, OneForAll." }
E{ id = "game.bind_on_equip", en = "Bind on Equip", uk = "Прив'язується при одяганні", note = "An item that binds when you put it on. Pairs with game.bind_on_pickup. lead's choice 2026-11-23, OneForAll." }
E{ id = "game.talent_trees", en = "Talent Trees", uk = "Дерева талантів", note = "The three talent trees of a class (UALL Forever: Talents «Таланти»). lead's choice 2026-11-23, OneForAll." }
E{ id = "game.buff", en = { "Buff", "Buffs" }, uk = "Баф", note = "A helpful aura on you (many: бафи). «бафф» is banned in UADD_OneForAll. lead's choice 2026-11-23, OneForAll." }
E{ id = "game.death_roll", en = "Death Roll", uk = "Смертельний кидок", note = "A /roll game for gold between players. lead's choice 2026-11-23, OneForAll." }
E{ id = "game.tic_tac_toe", en = "Tic Tac Toe", uk = "Хрестики-нулики", note = "The game, played in OneForAll's guild games. lead's choice 2026-11-23, OneForAll." }
E{ id = "item.junk_list", en = "junk list", uk = "список мотлоху", note = "The items you mark to sell as junk (item.junk «Мотлох»). lead's choice 2026-11-23, OneForAll." }
E{ id = "gear.armory", en = "Armory", uk = "Арсенал", note = "OneForAll's gear window. lead's choice 2026-11-23, OneForAll." }
E{ id = "gear.planner", en = "Gear Planner", uk = "Планувальник спорядження", note = "OneForAll's tab to plan gear. lead's choice 2026-11-23, OneForAll." }
E{ id = "gear.value", en = "Gear Value", uk = "Цінність спорядження", note = "How good an item is for your spec, as one number. lead's choice 2026-11-23, OneForAll." }
E{ id = "gear.pre_raid", en = "Pre Raid", uk = "Перед рейдом", note = "Gear to get before raiding (a list name). lead's choice 2026-11-23, OneForAll." }
E{ id = "gear.cheap_upgrades", en = "Cheap Upgrades", uk = "Дешеві покращення", note = "Better gear that costs little (a list name; gear.upgrade «Покращення»). lead's choice 2026-11-23, OneForAll." }
E{ id = "ui.wishlist", en = "Wishlist", uk = "Список бажань", note = "Items you want, kept in a list. lead's choice 2026-11-23, OneForAll." }
E{ id = "ui.quality_of_life", en = "Quality of Life", uk = "Зручності", note = "A tab of small helpers. lead's choice 2026-11-23, OneForAll." }
E{ id = "ui.lock_frame", en = "Lock", uk = "Закріпити", note = "Button: stop a window from moving. Not ui.locked (closed, «Замкнено»). lead's choice 2026-11-23, OneForAll." }
E{ id = "ui.social", en = "Social", uk = "Спілкування", note = "A tab for chat, guild and friends. lead's choice 2026-11-23, OneForAll." }
E{ id = "ui.info_bar", en = "Info bar", uk = "Інфопанель", note = "A thin bar of facts (gold, time, FPS). lead's choice 2026-11-23, OneForAll." }
E{ id = "ui.unit_frames", en = "Unit Frames", uk = "Рамки істот", note = "The player, target and party frames. lead's choice 2026-11-23, OneForAll." }
