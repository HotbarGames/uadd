-- UADD glossary: words first needed by the OpenMap module (UADD_OpenMap):
-- map pins, waypoints, zoom, floors, the quill and the map's own layers.
-- One line per meaning. Rules: docs/GLOSSARY.md.
local E = UADD.Glossary.Add

E{ id = "map.pin", en = "Map pin", uk = "Позначка", note = "a pin the player drops on the map; not «пін», not «шпилька»" }
E{ id = "map.pins", en = "Pins", uk = "Позначки", note = "plural of map.pin; OpenMap's tab and button" }
E{ id = "map.drop_pin", en = "Drop a pin", uk = "Поставити позначку", note = "the action; key binding and menu item" }
E{ id = "map.waypoint", en = "Waypoint", uk = "Точка маршруту", note = "the one tracked point the arrow leads to" }
E{ id = "map.zoom", en = "Zoom", uk = "Наближення", note = "how far in the map is; «масштаб» is the window's scale" }
E{ id = "map.deepest_zoom", en = "Deepest zoom", uk = "Найбільше наближення", note = "slider: how far in the map can go" }
E{ id = "map.floor", en = "Floor %d", uk = "Поверх %d", note = "a level of a dungeon's map" }
E{ id = "map.layer", en = "Layer", uk = "Шар", note = "a drawn layer of the map, not a server layer (that is game.server_layer, «лейер»)" }
E{ id = "map.coordinates", en = "Coordinates", uk = "Координати", note = "x, y on the map" }
E{ id = "map.continent", en = "Continent", uk = "Континент", note = "Kalimdor, Eastern Kingdoms: the map level above a zone" }
E{ id = "map.unexplored", en = "Unexplored areas", uk = "Недосліджені місця", note = "parts of a zone the character has not visited" }
E{ id = "map.fog_of_war", en = "Fog of war", uk = "Туман війни", note = "the same idea as map.unexplored, in other addons" }
E{ id = "map.flight_path", en = "Flight path", uk = "Шлях польоту", note = "a learned flight point or route" }
E{ id = "map.flight_masters", en = "Flight masters", uk = "Майстри польотів", note = "plural of npc.flight_master; could move next to it" }
E{ id = "map.boats", en = "Boats", uk = "Кораблі", note = "boat routes between continents" }
E{ id = "map.zeppelins", en = "Zeppelins", uk = "Цепеліни", note = "zeppelin routes between continents" }
E{ id = "map.quill", en = "Quill", uk = "Перо", note = "OpenMap's drawing tool as a whole; its Pen tool is «Олівець»" }
E{ id = "map.notes", en = "Map notes", uk = "Нотатки на карті", note = "painted areas with a text note" }
E{ id = "map.zone_levels", en = "Zone levels", uk = "Рівні зон", note = "the level range shown on each zone" }
E{ id = "map.arrow", en = "Arrow", uk = "Стрілка", note = "drawing tool: a pointing arrow. Not the ammo (that is gear.arrow)" }
E{ id = "map.pinpoint", en = "Pinpoint", uk = "Мітка", note = "Waypoint UI: how the waypoint shows once the player is close. The owner's choice, 2026-11-20 (not «Точна позначка»). Not map.pin («Позначка»)" }
E{ id = "map.navigator", en = "Navigator", uk = "Навігатор", note = "Waypoint UI: the arrow at the screen's edge while the target is off-screen. The owner's choice, 2026-11-20 (not «Покажчик»)" }
E{ id = "map.pathfinding", en = "Pathfinding", uk = "Прокладання маршруту", note = "Waypoint UI: building a route to the target. The owner's choice, 2026-11-20 (not «Пошук шляху»)" }
E{ id = "map.context_icon", en = "Context Icon", uk = "Значок цілі", note = "Waypoint UI: the icon above the target (diamond or circle). The owner's choice, 2026-11-20 (not «Контекстний значок»)" }
E{ id = "map.beam", en = "Beam", uk = "Промінь", note = "Waypoint UI: the light beam above the waypoint" }
E{ id = "map.waypoint_arrow", en = { "Crazy Arrow", "Waypoint Arrow" }, uk = "Стрілка", note = "TomTom's on-screen arrow that points to the waypoint. Not the drawing tool (map.arrow), not the ammo (gear.arrow)" }
E{ id = "map.coord_block", en = "Coordinate Block", uk = "Блок координат", note = "TomTom's small movable box that shows the player's x, y" }
E{ id = "map.paste_window", en = "Paste window", uk = "Вікно вставки", note = "TomTom's window where /way lines are pasted; never the English name in a Ukrainian line" }
E{ id = "quest.super_tracked", en = "Super-tracked quest", uk = "Пріоритетне завдання", note = "the one quest the game's own quest arrow follows" }
E{ id = "map.find_me", en = "Find me", uk = "Знайти мене", note = "button: move the map to the player" }
E{ id = "map.classic_map", en = "Classic", uk = "Класична", note = "welcome-page choice of map look: the classic full map (карта, feminine). Not a style name (ui.classic_look)" }
E{ id = "map.teleports", en = "Teleports", uk = "Телепорти", note = "Teleports as a history filter (Road to Sixty, 2026-11-27)." }
E{ id = "map.flight_paths", en = "Flight paths", uk = "Шляхи польоту", note = "plural of map.flight_path (Road to Sixty filter, 2026-11-27)" }
