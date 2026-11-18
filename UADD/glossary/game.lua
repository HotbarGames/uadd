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
E{ id = "game.level", en = "Level", uk = "Рівень", note = "Character, NPC or quest level (a number). Not sound volume." }
E{ id = "game.level_n", en = "Level %s", uk = "Рівень %s", note = "Level with its number." }
E{ id = "game.experience", en = "Experience", uk = "Досвід", note = "Experience points (XP)." }
E{ id = "game.reputation", en = "Reputation", uk = "Репутація", note = "Standing with a faction." }
E{ id = "game.health", en = "Health", uk = "Здоров'я", note = "Hit points of a character or NPC." }
E{ id = "game.class", en = "Class", uk = "Клас", note = "Character class (warrior, mage...). Also a category of class quests." }
E{ id = "game.group", en = { "Group", "Party" }, uk = "Група", note = "A party of up to five players; a group quest tag; the party chat channel." }
E{ id = "game.raid", en = "Raid", uk = "Рейд", note = "A big group, a raid instance, a raid quest tag." }
E{ id = "game.dungeon", en = { "Dungeon", "Dungeons" }, uk = "Підземелля", note = "Five-player instance (one or many: same word); a dungeon quest tag." }
E{ id = "game.instance", en = "Instance", uk = "Підземелля", note = "A private copy of a dungeon or raid." }
E{ id = "game.scenario", en = "Scenario", uk = "Сценарій", note = "Scenario: a short instanced story for a few players." }
E{ id = "game.scenarios", en = "Scenarios", uk = "Сценарії", note = "Many scenarios; a category." }
E{ id = "game.battlegrounds", en = "Battlegrounds", uk = "Поля бою", note = "PvP battlegrounds; a category." }
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
E{ id = "step.interact", en = "Interact", uk = "Взаємодіяти", note = "Attune step type; a verb like the other step types (Убити, Взяти, Здати). Questie's icon name is icon.interact." }
E{ id = "icon.interact", en = "Interact", uk = "Взаємодія", note = "Name of the Questie map icon for objectives where you interact with an object or NPC; a noun like 'Розмова'. A step type is step.interact." }
E{ id = "npc.rank_boss", en = "Boss", uk = "Бос", note = "NPC rank: a dungeon or raid boss." }
E{ id = "ui.survey", en = "Survey", uk = "Опитування", note = "Asking guild or group members for their progress; a button or tab." }
