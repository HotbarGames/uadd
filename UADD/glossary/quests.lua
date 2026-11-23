-- UADD glossary: quest states, quest tags, quest phrases, quest tracker actions, ID labels.
-- One line per meaning. Rules: docs/GLOSSARY.md.
-- Short state and tag words are neuter: they describe "завдання" (Доступне, Елітне, Щоденне).
local E = UADD.Glossary.Add

-- Quest states
E{ id = "quest.state_complete", en = { "Complete", "Completed" }, uk = "Виконано", note = "State: the quest is done. A label, a checkbox or a history line." }
E{ id = "quest.state_incomplete", en = "Incomplete", uk = "Невиконане", note = "State: the quest is taken but not done yet." }
E{ id = "quest.state_failed", en = "Failed", uk = "Провалено", note = "State: the quest failed (time ran out, escort died)." }
E{ id = "quest.state_accepted", en = "Accepted", uk = "Прийнято", note = "State or history line: the quest was taken." }
E{ id = "quest.state_abandoned", en = "Abandoned", uk = "Покинуто", note = "State or history line: the quest was dropped." }
E{ id = "quest.state_available", en = "Available", uk = "Доступне", note = "State: the quest can be taken now." }
E{ id = "quest.state_unavailable", en = "Unavailable", uk = "Недоступне", note = "State: the quest cannot be taken now." }
E{ id = "quest.state_active", en = "Active", uk = "Активне", note = "State: the quest is in the quest log now." }
E{ id = "quest.state_hidden", en = "Hidden", uk = "Сховане", note = "State: the player hid this quest in the addon." }

-- Quest tags (the type of a quest)
E{ id = "quest.tag_daily", en = "Daily", uk = "Щоденне", note = "Quest tag: can be done once a day." }
E{ id = "quest.tag_weekly", en = "Weekly", uk = "Щотижневе", note = "Quest tag: can be done once a week." }
E{ id = "quest.tag_monthly", en = "Monthly", uk = "Щомісячне", note = "Quest tag: can be done once a month." }
E{ id = "quest.tag_repeatable", en = "Repeatable", uk = "Повторюване", note = "Quest tag: can be done again and again." }
E{ id = "quest.tag_elite", en = "Elite", uk = "Елітне", note = "Quest tag: needs a group (elite enemies)." }
E{ id = "quest.tag_heroic", en = "Heroic", uk = "Героїчне", note = "Quest tag: heroic dungeon quest." }
E{ id = "quest.tag_legendary", en = "Legendary", uk = "Легендарне", note = "Quest tag. Not item quality: a legendary item is 'Легендарний'." }
E{ id = "quest.tag_epic", en = "Epic", uk = "Епічне", note = "Quest tag. Not item quality: an epic item is 'Епічний'." }
E{ id = "quest.tag_escort", en = "Escort", uk = "Супровід", note = "Quest tag: walk an NPC somewhere and keep it alive." }
E{ id = "quest.tag_world_event", en = "World Event", uk = "Світова подія", note = "Quest tag: part of a world or holiday event." }

-- Quest lists
E{ id = "quest.available_quests", en = { "Available Quests", "Available quests" }, uk = "Доступні завдання", note = "Quests the player can take now; a list or a setting." }
E{ id = "quest.completed_quests", en = "Completed Quests", uk = "Виконані завдання", note = "Quests the player has done; a list." }
E{ id = "quest.repeatable_quests", en = "Repeatable Quests", uk = "Повторювані завдання", note = "Quests that can be done again; a list or a setting." }
E{ id = "quest.trivial_quest", en = "Trivial Quest", uk = "Просте завдання", note = "A grey quest: far below the player's level." }
E{ id = "quest.trivial_quests", en = "Trivial Quests", uk = "Прості завдання", note = "Grey quests: far below the player's level." }

-- Messages about a quest
E{ id = "quest.msg_accepted", en = "Quest accepted", uk = "Завдання прийнято", note = "Message or setting: a quest was taken." }
E{ id = "quest.msg_abandoned", en = "Quest abandoned", uk = "Завдання покинуто", note = "Message or setting: a quest was dropped." }
E{ id = "quest.msg_completed", en = "Quest completed", uk = "Завдання виконано", note = "Message or setting: a quest was done." }
E{ id = "quest.msg_objective_completed", en = { "Objective Complete", "Objective completed" }, uk = "Ціль виконано", note = "Message, setting or sound name: one quest objective is done." }

-- Quest details
E{ id = "quest.level", en = "Quest Level", uk = "Рівень завдання", note = "The level of a quest." }
E{ id = "quest.started_by", en = { "Started by", "Starts at" }, uk = "Видає", note = "Tooltip label before the NPC or item that gives the quest." }
E{ id = "quest.ended_by", en = "Ended by", uk = "Приймає", note = "Tooltip label before the NPC that takes the finished quest." }

-- Quest starts on the map (first used by UADD_ForeverQuestPins)
E{ id = "quest.start_pin", en = { "Quest start pin", "Quest start" }, uk = "Значок початку завдання", note = "Forever Quest Pins: the icon an addon draws where a quest is given; plural «значки початку завдань». A map icon (map.map_pins), not a pin the player drops (map.pin «Позначка»). lead's choice 2026-11-20." }
E{ id = "quest.breadcrumb", en = { "Breadcrumb quest", "Breadcrumb" }, uk = "Вступне завдання", note = "A short quest that sends you to another quest giver; a skipped one is «пропущене вступне завдання». Never «хлібні крихти». lead's choice 2026-11-20, Forever Quest Pins." }
E{ id = "quest.follow_up", en = "Follow-up quest", uk = "Наступне завдання", note = "The quest a breadcrumb (quest.breadcrumb) leads to, or the next in a chain." }
E{ id = "game.spawn_point", en = { "Spawn point", "Spawn location" }, uk = "Місце появи", note = "Where an NPC or object appears; UALL Forever's words (місце появи). Not game.camping." }
E{ id = "game.war_effort", en = { "AQ war effort", "War effort" }, uk = "Воєнні зусилля Ан'Кіражу", note = "The server-wide collection before the gates of Ahn'Qiraj open; UALL Forever's and ClassicUA's words." }

-- Quest tracker (the list of quests on screen) and its menu
E{ id = "quest.tracker", en = "Tracker", uk = "Трекер", note = "The quest tracker: the list of quests at the side of the screen." }
E{ id = "quest.untrack", en = "Untrack Quest", uk = "Прибрати завдання з трекера", note = "Menu action: stop showing the quest in the tracker." }
E{ id = "quest.abandon", en = "Abandon Quest", uk = "Покинути завдання", note = "Menu action: drop the quest from the quest log." }
E{ id = "map.show_on_map", en = "Show on Map", uk = "Показати на карті", note = "Menu action: open the map at this quest or place." }

-- ID labels (for players who look up ids)
E{ id = "id.quest", en = "Quest ID", uk = "ID завдання", note = "Label before a quest's number id." }
E{ id = "id.npc", en = "NPC ID", uk = "ID НІП", note = "Label before an NPC's number id." }
E{ id = "id.item", en = "Item ID", uk = "ID предмета", note = "Label before an item's number id." }
E{ id = "id.object", en = "Object ID", uk = "ID об'єкта", note = "Label before a world object's number id." }
E{ id = "id.spell", en = "Spell ID", uk = "ID заклинання", note = "Label before a spell's number id." }
