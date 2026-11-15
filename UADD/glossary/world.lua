-- UADD glossary: town services (NPC roles), what vendors sell, holidays and world events, auction house words.
-- One line per meaning. Rules: docs/GLOSSARY.md.
local E = UADD.Glossary.Add

-- Town services: NPC roles and service objects
E{ id = "npc.townsfolk", en = "Townsfolk", uk = "Міські служби", note = "All town service NPCs together (bank, inn, trainers); a map filter." }
E{ id = "npc.auctioneer", en = "Auctioneer", uk = "Аукціоніст", note = "NPC role: auction house." }
E{ id = "npc.banker", en = "Banker", uk = "Банкір", note = "NPC role: bank." }
E{ id = "npc.battlemaster", en = "Battlemaster", uk = "Розпорядник битв", note = "NPC role: queues for battlegrounds." }
E{ id = "npc.flight_master", en = "Flight Master", uk = "Майстер польотів", note = "NPC role: flight paths." }
E{ id = "npc.innkeeper", en = "Innkeeper", uk = "Корчмар", note = "NPC role: inn, hearthstone." }
E{ id = "npc.spirit_healer", en = "Spirit Healer", uk = "Цілитель душ", note = "NPC role: brings a dead player back at the graveyard." }
E{ id = "npc.stable_master", en = "Stable Master", uk = "Конюх", note = "NPC role: keeps hunter pets." }
E{ id = "npc.vendor", en = "Vendor", uk = "Торговець", note = "NPC who sells things." }
E{ id = "npc.vendors", en = "Vendors", uk = "Торговці", note = "Many vendors; a heading." }
E{ id = "npc.weapon_master", en = "Weapon Master", uk = "Майстер зброї", note = "NPC role: teaches weapon skills." }
E{ id = "npc.transmogrifier", en = "Transmogrifier", uk = "Трансмогрифікатор", note = "NPC role: changes how gear looks." }
E{ id = "npc.arcane_reforger", en = "Arcane Reforger", uk = "Таємний перековувач", note = "NPC role: reforging." }
E{ id = "npc.barber", en = "Barber", uk = "Перукар", note = "NPC role: barber shop." }
E{ id = "obj.mailbox", en = "Mailbox", uk = "Поштова скринька", note = "World object: the mailbox." }
E{ id = "obj.meeting_stone", en = "Meeting Stone", uk = "Камінь зустрічей", note = "World object at a dungeon entrance." }
E{ id = "obj.meeting_stones", en = "Meeting Stones", uk = "Камені зустрічей", note = "Many meeting stones; a map filter." }

-- What a vendor sells (vendor type). Nouns, not actions: "Drink" is drinks for sale, not "to drink".
E{ id = "vendor.ammo", en = "Ammo", uk = "Набої", note = "Vendor type: arrows and bullets." }
E{ id = "vendor.bags", en = "Bags", uk = "Сумки", note = "Vendor type: bags." }
E{ id = "vendor.drink", en = "Drink", uk = "Напої", note = "Vendor type: drinks." }
E{ id = "vendor.food", en = "Food", uk = "Їжа", note = "Vendor type: food." }
E{ id = "vendor.pet_food", en = "Pet Food", uk = "Їжа для вихованців", note = "Vendor type: food for hunter pets." }
E{ id = "vendor.poisons", en = "Poisons", uk = "Отрути", note = "Vendor type: rogue poisons." }
E{ id = "vendor.potions", en = "Potions", uk = "Зілля", note = "Vendor type: potions." }
E{ id = "vendor.reagents", en = "Reagents", uk = "Реагенти", note = "Vendor type: spell reagents." }
E{ id = "vendor.repair", en = "Repair", uk = "Ремонт", note = "Vendor type: repairs gear. Noun (the service)." }
E{ id = "vendor.trade_goods", en = "Trade Goods", uk = "Ремісничі товари", note = "Vendor type: profession materials." }

-- Holidays and world events
E{ id = "event.darkmoon_faire", en = "Darkmoon Faire", uk = "Ярмарок Темного Місяця", note = "Monthly fair event." }
E{ id = "event.lunar_festival", en = "Lunar Festival", uk = "Місячний фестиваль", note = "Holiday (new year)." }
E{ id = "event.love_is_in_the_air", en = "Love is in the Air", uk = "Кохання в повітрі", note = "Holiday (February)." }
E{ id = "event.noblegarden", en = "Noblegarden", uk = "Шляхетний сад", note = "Holiday (spring, eggs)." }
E{ id = "event.childrens_week", en = "Children's Week", uk = "Дитячий тиждень", note = "Holiday (orphans)." }
E{ id = "event.midsummer", en = "Midsummer", uk = "Свято Сонцестояння", note = "Holiday (Midsummer Fire Festival)." }
E{ id = "event.brewfest", en = "Brewfest", uk = "Свято пива", note = "Holiday (autumn)." }
E{ id = "event.harvest_festival", en = "Harvest Festival", uk = "Свято врожаю", note = "Holiday (autumn)." }
E{ id = "event.hallows_end", en = "Hallow's End", uk = "Хелловін", note = "Holiday (October)." }
E{ id = "event.day_of_the_dead", en = "Day of the Dead", uk = "День мертвих", note = "Holiday (November)." }
E{ id = "event.pilgrims_bounty", en = "Pilgrim's Bounty", uk = "Щедрість пілігрима", note = "Holiday (November)." }
E{ id = "event.winter_veil", en = "Winter Veil", uk = "Зимовий Покров", note = "Holiday (December)." }
E{ id = "event.pirates_day", en = "Pirates' Day", uk = "День піратів", note = "Holiday (September)." }

-- Auction house (first used by Auctionator). A lot is one thing put up for sale: "ваші лоти".
E{ id = "auction.house", en = "Auction House", uk = "Аукціон", note = "The auction house: the place and its window ('на аукціоні'). Not one lot (auction.lot)." }
E{ id = "auction.lot", en = "Auction", uk = "Лот", note = "One item or stack put up for sale on the auction house ('your auctions' = 'ваші лоти'). Not the place (auction.house)." }
E{ id = "auction.bid", en = { "Bid", "Bid Price" }, uk = "Ставка", note = "A bid on a lot (noun): a column, an input or a state. Fits 'Bid Price' too." }
E{ id = "auction.buyout", en = "Buyout", uk = "Викуп", note = "Buying a lot at once for its fixed price (noun)." }
E{ id = "auction.buyout_price", en = "Buyout Price", uk = "Ціна викупу", note = "The fixed price that buys a lot at once; a column or input." }
E{ id = "auction.unit_price", en = "Unit Price", uk = "Ціна за штуку", note = "Price of one item in a stack or lot. A narrow column may say 'Ціна за шт.'." }
E{ id = "auction.deposit", en = "Deposit", uk = "Застава", note = "The fee the auction house keeps when you post a lot; lost if you cancel it." }
E{ id = "auction.duration", en = "Duration", uk = "Тривалість", note = "How long a lot stays up (12, 24 or 48 hours)." }
E{ id = "auction.post", en = "Post", uk = "Виставити", note = "Button: put an item up for sale on the auction house. Not a forum post." }
E{ id = "auction.undercut", en = "Undercut", uk = "Зниження", note = "How much below the lowest price you post (noun, a setting). Someone posting cheaper than you is auction.undercut_state." }
E{ id = "auction.undercut_state", en = "Undercut?", uk = "Перебито?", note = "Column: someone posted the same item cheaper than your lot ('ваш лот перебили')." }
E{ id = "auction.shopping_list", en = "Shopping List", uk = "Список покупок", note = "A saved list of searches to run on the auction house." }
E{ id = "auction.shopping_lists", en = "Shopping Lists", uk = "Списки покупок", note = "Many shopping lists; a tab or heading." }
E{ id = "auction.full_scan", en = "Full Scan", uk = "Повне сканування", note = "Reading every lot on the auction house to record prices; a button or message." }
E{ id = "auction.stack", en = "Stack", uk = "Стос", note = "Many of the same item in one bag slot or one lot." }
E{ id = "auction.stack_size", en = "Stack Size", uk = "Розмір стосу", note = "How many items are in one stack." }
E{ id = "auction.stack_price", en = "Stack Price", uk = "Ціна стосу", note = "Price of a whole stack (one item: auction.unit_price)." }
E{ id = "auction.time_left", en = "Time Left", uk = "Лишилося", note = "Column: how long a lot stays up. The cells hold the time, so the header is one word." }
E{ id = "auction.quantity", en = "Quantity", uk = "Кількість", note = "How many items: a column or an input." }
E{ id = "auction.sellers", en = { "Seller(s)", "Sellers" }, uk = "Продавці", note = "Column: who put the lots up." }
