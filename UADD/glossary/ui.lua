-- UADD glossary: words of addon windows (buttons, tabs, settings). One line per meaning. Rules: docs/GLOSSARY.md.
local E = UADD.Glossary.Add

-- Buttons and actions
E{ id = "ui.close", en = "Close", uk = "Закрити", note = "Button that closes a window. Not 'near' (that is 'Поруч')." }
E{ id = "ui.back", en = "Back", uk = "Назад", note = "Button that returns to the previous page. Not the gear slot (that is gear.cloak)." }
E{ id = "ui.cancel", en = "Cancel", uk = "Скасувати", note = "Button that stops an action and closes the dialog." }
E{ id = "ui.ok", en = { "OK", "Okay" }, uk = "Гаразд", note = "Button that agrees and closes the dialog." }
E{ id = "ui.yes", en = "Yes", uk = "Так", note = "Answer button in a yes/no dialog." }
E{ id = "ui.no", en = "No", uk = "Ні", note = "Answer button in a yes/no dialog." }
E{ id = "ui.enable", en = "Enable", uk = "Увімкнути", note = "Action: turn a feature on." }
E{ id = "ui.disable", en = "Disable", uk = "Вимкнути", note = "Action: turn a feature off." }
E{ id = "ui.show", en = "Show", uk = "Показати", note = "Action: make a frame or icon visible." }
E{ id = "ui.hide", en = "Hide", uk = "Сховати", note = "Action: make a frame or icon invisible. Not 'a hiding place'." }
E{ id = "ui.reset", en = "Reset", uk = "Скинути", note = "Action: put settings or a frame back to the start values." }
E{ id = "ui.delete", en = "Delete", uk = "Видалити", note = "Button that removes something for good (a profile, a note)." }
E{ id = "ui.import", en = "Import", uk = "Імпорт", note = "Button or tab that loads data from somewhere else." }
E{ id = "ui.search", en = "Search", uk = "Пошук", note = "Search button, search box label or search tab." }
E{ id = "ui.reload_ui", en = "Reload UI", uk = "Перезавантажити інтерфейс", note = "Button or action that runs /reload." }
E{ id = "ui.reload_ui_short", en = "Reload UI", uk = "Перезавантажити", note = "Short form for a narrow pop-up button; the full form is ui.reload_ui." }
E{ id = "ui.dont_show_again", en = "Don't show again", uk = "Більше не показувати", note = "Checkbox or button on a notice." }
E{ id = "ui.more_info", en = "More Info", uk = "Докладніше", note = "Link or label that leads to more details." }

-- Things an addon makes or is
E{ id = "ui.macro", en = { "Macro", "Macros" }, uk = "Макрос", note = "A game macro (/macro); many: макроси. UALL: «Загальні макроси» (first used by UADD_AutoPotion)." }
E{ id = "ui.addon", en = { "Addon", "AddOn", "Addons" }, uk = "Аддон", note = "A game addon (many: аддони); used by every module." }

-- States
E{ id = "ui.enabled", en = "Enabled", uk = "Увімкнено", note = "State: a feature is on. Also a choice in a drop-down." }
E{ id = "ui.disabled", en = "Disabled", uk = "Вимкнено", note = "State: a feature is off. Also a choice in a drop-down." }
E{ id = "ui.time_active", en = "Active", uk = "Активність", note = "A kind of play time in a time breakdown (next to Travelling, Idle, Flying), not a quest state (quest.state_active)." }

-- Messages
E{ id = "ui.error", en = "Error", uk = "Помилка", note = "Title or tag of an error message." }
E{ id = "ui.warning", en = "Warning", uk = "Попередження", note = "Title or tag of a warning message." }
E{ id = "ui.information", en = "Information", uk = "Інформація", note = "Title or tag of an info message." }

-- Settings windows: tabs and groups
E{ id = "ui.settings", en = { "Settings", "Options" }, uk = "Налаштування", note = "Noun: the settings window, tab or menu entry of an addon." }
E{ id = "ui.options_tab", en = "Options", uk = "Параметри", note = "An Options tab or page inside a window that is itself called Settings, so the two names differ." }
E{ id = "ui.general", en = "General", uk = "Загальне", note = "Name of the first, general settings tab." }
E{ id = "ui.advanced", en = "Advanced", uk = "Розширені", note = "Name of the advanced settings tab (short for 'advanced settings')." }
E{ id = "ui.advanced_settings", en = { "Advanced Options", "Advanced Settings" }, uk = "Розширені налаштування", note = "Heading of the advanced settings group." }
E{ id = "ui.appearance", en = "Appearance", uk = "Вигляд", note = "Settings group about how something looks." }
E{ id = "ui.sounds", en = "Sounds", uk = "Звуки", note = "Settings group about sounds." }
E{ id = "ui.tooltips", en = "Tooltips", uk = "Підказки", note = "The small pop-up text boxes on mouse-over; also the settings tab about them." }
E{ id = "ui.icons", en = "Icons", uk = "Значки", note = "Small pictures (on maps, frames); also the settings tab about them." }
E{ id = "ui.background_color", en = "Background Color", uk = "Колір фону", note = "Colour of a frame's background." }
E{ id = "ui.font", en = "Font", uk = "Шрифт", note = "Typeface setting." }
E{ id = "ui.font_size", en = "Font Size", uk = "Розмір шрифту", note = "Text size setting." }
E{ id = "ui.size", en = "Size", uk = "Розмір", note = "How big a frame or icon is." }
E{ id = "ui.scale", en = "Scale", uk = "Масштаб", note = "Scale slider of a frame (x0.5 .. x2)." }

-- Mouse
E{ id = "ui.left_click", en = "Left Click", uk = "Лівий клік", note = "Mouse action, in tooltips that list what a click does." }
E{ id = "ui.right_click", en = "Right Click", uk = "Правий клік", note = "Mouse action, in tooltips that list what a click does." }

-- The addon's own button on the minimap (LibDBIcon). Not the quest pins on the minimap: see map.minimap_pins.
E{ id = "ui.minimap_button", en = { "Minimap Button", "Minimap Icon" }, uk = "Кнопка на мінікарті", note = "The addon's own round button at the edge of the minimap." }
E{ id = "ui.show_minimap_button", en = "Show Minimap Button", uk = "Кнопка на мінікарті", note = "Checkbox that shows or hides the addon's minimap button. The label names the thing." }
E{ id = "ui.hide_minimap_button", en = "Hide Minimap Button", uk = "Сховати кнопку на мінікарті", note = "Action (for example Ctrl+Right Click) that hides the addon's minimap button." }

-- Map pins an addon draws
E{ id = "map.map_pins", en = "Map Icons", uk = "Значки на карті", note = "Markers an addon draws on the world map (quests, NPCs, nodes)." }
E{ id = "ui.addon_compartment", en = "Addon Compartment", uk = "Меню аддонів", note = "The game's button by the minimap that lists addons. Not «відсік», not «панель»." }
E{ id = "ui.data_feed", en = "Data feed", uk = "Стрічка даних", note = "A LibDataBroker (LDB) feed that a panel addon (Titan Panel, Bazooka) shows." }
E{ id = "map.minimap_pins", en = "Minimap Icons", uk = "Значки на мінікарті", note = "Markers an addon draws on the minimap. Not the addon's own button (ui.minimap_button)." }

-- Profiles (AceDB-style profile pages)
E{ id = "ui.profiles", en = "Profiles", uk = "Профілі", note = "Saved sets of settings; also the profiles tab." }
E{ id = "ui.profile_default", en = "Default", uk = "Типовий", note = "Name of the default profile (masculine: профіль). For 'default value' use another entry." }
E{ id = "ui.default_value", en = "Default", uk = "Типово", note = "By default: the value a setting has before you change it ('Default: 12'). Not the profile name (ui.profile_default)." }
E{ id = "ui.profile_new", en = "New", uk = "Новий", note = "Button or box that makes a new profile (masculine: профіль)." }
E{ id = "ui.profile_copy_from", en = "Copy From", uk = "Копіювати з", note = "Drop-down: copy settings from another profile." }
E{ id = "ui.profile_current", en = "Current Profile:", uk = "Поточний профіль:", note = "Label before the name of the profile in use." }
E{ id = "ui.profile_existing", en = "Existing Profiles", uk = "Наявні профілі", note = "Drop-down with the saved profiles." }
E{ id = "ui.profile_reset", en = "Reset Profile", uk = "Скинути профіль", note = "Button: put the current profile back to defaults." }
E{ id = "ui.profile_delete", en = "Delete a Profile", uk = "Видалити профіль", note = "Heading or drop-down for deleting a profile." }
E{ id = "ui.profile_manage", en = "Manage Profiles", uk = "Керування профілями", note = "Heading of the profiles page." }
E{ id = "ui.classic_look", en = "Classic", uk = "Класика", note = "Name of a look in a list of styles or themes (bar text layout, level card theme). A noun, so it fits any gender. Not the OpenMap map choice (map.classic_map)." }
