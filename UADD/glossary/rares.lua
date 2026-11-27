-- UADD glossary: words first needed by the RareScanner module (UADD_RareScanner):
-- rares, treasures and events it finds, its explorer, its filters and collections.
-- One line per meaning. Rules: docs/GLOSSARY.md.
local E = UADD.Glossary.Add

-- What it finds and how it shows them
E{ id = "rare.entity", en = "Entity", uk = "Об'єкт", note = "RareScanner's word for anything it tracks: a rare NPC, a treasure or an event (many: об'єкти). Same word as game.object, wider meaning." }
E{ id = "rare.vignettes", en = { "Vignettes", "Ingame icons" }, uk = "Ігрові позначки", note = "The game's own small map and minimap marks for rares and treasures. Not the addon's icons (map.map_pins, «значки»)." }
E{ id = "rare.guidance_icons", en = "Guidance icons", uk = "Позначки-підказки", note = "Small icons that show where to go to reach a rare or treasure (a cave entrance, a path)." }
E{ id = "rare.not_discovered", en = "Not discovered", uk = "Невідкритий", note = "A rare, treasure or event not found yet; its map icon is red. Agrees with the noun (невідкриті скарби)." }
E{ id = "rare.sighting", en = "Sighting", uk = "Спостереження", note = "One time a rare NPC was seen (by you or another player)." }
E{ id = "rare.repeatable", en = "Repeatable", uk = "Що з'являється знову", note = "A rare or treasure that comes back after you kill or loot it. Not the quest tag (quest.tag_repeatable, «Повторюване»)." }
E{ id = "rare.main_button", en = "Main button", uk = "Головна кнопка", note = "RareScanner's big pop-up button that shows a found rare and targets it." }
E{ id = "rare.miniature", en = "Miniature", uk = "Мініатюра", note = "The small 3D model of the found NPC next to the main button." }
E{ id = "rare.display_id", en = "Display ID", uk = "ID моделі", note = "The number of a 3D model in the game's data." }

-- The explorer: collections and loot
E{ id = "rare.explorer", en = "Explorer", uk = "Провідник", note = "RareScanner's explorer window: lists rares and their loot by zone." }
E{ id = "rare.missing", en = "Missing", uk = "Незібраний", note = "A collectible (mount, pet, toy, appearance) you do not have yet. Not «відсутній». Agrees with the noun (незібрані предмети)." }
E{ id = "rare.unobtained", en = "Unobtained", uk = "Ще не здобутий", note = "Loot you have not got yet." }
E{ id = "rare.drop_chance", en = "Drop chance", uk = "Шанс випадіння", note = "How likely an item drops from a rare (a percent)." }
E{ id = "rare.custom_items", en = "Custom items", uk = "Власні предмети", note = "Items the player added to their own list to watch for." }
E{ id = "rare.equipable", en = "Equipable", uk = "Можна вдягти", note = "A loot filter: items your character can wear." }
E{ id = "rare.quality", en = "Quality", uk = "Якість", note = "An item's quality (common, rare, epic): a loot filter." }
E{ id = "rare.covenant", en = "Covenant", uk = "Ковенант", note = "A Shadowlands covenant (a filter for its rares)." }
E{ id = "rare.renown", en = "Renown", uk = "Слава", note = "Renown with a faction or covenant (a level)." }

-- Settings and filters
E{ id = "ui.category", en = { "Category", "Subcategory" }, uk = "Категорія", note = "A group in a list or a filter (many: категорії; a subcategory: підкатегорія)." }
E{ id = "ui.unfilter", en = "Unfilter", uk = "Зняти фільтр", note = "Action: stop filtering something (all: зняти всі фільтри)." }
E{ id = "ui.search_box", en = "Search box", uk = "Поле пошуку", note = "The box where you type what to search for. The button or tab: ui.search." }
E{ id = "ui.rescan", en = "Rescan", uk = "Пересканувати", note = "Button: scan again." }
E{ id = "ui.backup", en = "Backup", uk = "Копія", note = "A saved copy of settings or data." }
E{ id = "ui.unknown", en = "Unknown", uk = "Невідомо", note = "A value the addon does not know (a state, a time). Agrees as needed (невідомий НІП)." }
E{ id = "ui.ambience", en = "Ambience", uk = "Атмосфера", note = "The game's ambient sound channel (a sound setting)." }
E{ id = "map.transport", en = "Transport", uk = "Транспорт", note = "Boats, zeppelins and portals as a map filter." }
E{ id = "map.inside", en = "Inside", uk = "Усередині", note = "A rare or treasure inside a cave or a building (not on the open map). Attune uses the same word." }
E{ id = "rare.wanted", en = "Wanted", uk = "Розшукуваний", note = "A rare NPC the player marked as wanted (RareScanner 1.60.1.13). Agrees as needed (розшукувані НІПи)." }
E{ id = "rare.host", en = "Host", uk = "Господар", note = "The player who found a wanted rare and invites others to it (RareScanner)." }
E{ id = "rare.mobs", en = "Rare mobs", uk = "Рідкісні монстри", note = "Rare creatures as a group (OpenMap and Road to Sixty use it)." }
