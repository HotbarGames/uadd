-- Attune texts in Ukrainian, keyed by Attune's own words, never by its English (see Words.lua):
--   ns.UA           by Attune's locale key (Locales/enUS.lua: Lang["key"] = ...). A key that is an English
--                   sentence itself is in data/hashed.lua (ns.UA_KEYHASH), by its hash.
--   ns.UA_CATEGORY  by a category's locale key: the tree shows the value as it is, the options in sentence case.
--   ns.UA_GLUED     by the locale key of a word Attune glues to a number or a name: { shape, Ukrainian }. The
--                   shape is the line with {} where AttuneLang[key] goes, %s where the number or name goes.
--   ns.UA_STEP_TYPE by a raw step TYPE value, display labels only (Attune itself compares the raw value).
--   English Attune writes in its code, not in its locale: data/hashed.lua (ns.UA_TEXTHASH).
--   tools/make_att_text.py review shows each text next to Attune's English (from the installed addon).
-- This module only changes what is shown. It never writes AttuneLang or Attune_Data: Attune bakes some of
--   these texts into its data at load and compares them later.
-- A text keeps the same ##TOKEN## slots, %s / %d slots in the same order, %% for a real %, the same
--   |c........|r colour codes and \n breaks, and the same leading or trailing spaces.
-- "-- LONG" marks a short label (button, column, node line) that is much longer than the English.
-- "-- compared by Attune" marks a text Attune reads back or stores; it is safe here only because this
--   table is used on the display side.
-- Lines with a glossary word use a plain key (KEY = G"id") where the key is a Lua name, so tools/glossary.py
--   does not take the key for English text.
-- Number-safe forms where Ukrainian would change the word with the number: "Пропущено допусків: 3",
--   "Персонажів: 5", "(гравців: 5)".
-- Names glued after a word use a colon or a dash, so they need no case: "Шанований: Argent Dawn",
--   "Убити — Westfall". Game names inside sentences are the UALL ones, in «» and in the nominative.
--
-- Kept in English on purpose (not in this file): the category, class and tree values Attune stores and
--   compares (their shown labels come from ns.UA_CATEGORY and from UALL); the step TYPE values; the
--   AttuneCompleteGuild line (other players read it in guild chat); profession names (compared with the
--   game's); zone, faction, item, raid and dungeon names (from UALL); slash words, the website address,
--   the addon, author and guild names; keys no code reads and the Q1_/Q2_/N1_/N2_/I_/O_ id keys.
local _, ns = ...
-- G"id" takes a word from the shared base, UADD/glossary/*.lua (see docs/GLOSSARY.md).
local G = UADD and UADD.Glossary and UADD.Glossary.Text or function() return nil end
ns.UA = {
    -- Main window
    Credits = "Величезна подяка моїй гільдії |cffffd100<Berserker>|r за підтримку й розуміння, поки я тестую аддон.\n\nЯкщо побачите мене в грі, киньте мені |cffffd100/hug|r!\n\nCixi Delmont / Gaya Greyhoof",
    Zoom = G"map.zoom",
    ["Pan_DESC"] = "Затисніть кнопку миші й тягніть, щоб посунути ланцюжок. Shift і коліщатко миші посувають його по горизонталі.",
    ["Version"] = "Attune v##VERSION## від Cixi Delmont / Gaya Greyhoof.",
    ["Splash"] = "v##VERSION## від Cixi Delmont / Gaya Greyhoof. Введіть /attune, щоб почати.",
    Survey = G"ui.survey",
    ["Guild"] = G"game.guild",
    Party = G"game.group",
    Raid = G"game.raid",
    Close = G"ui.close",
    ["Results"] = "Результати",
    ["Not in a guild"] = "Не в гільдії",
    Character = G"game.character",
    Characters = G"game.characters",
    Class = G"game.class",
    ["Guild members"] = "Учасники гільдії",
    ["All results"] = "Усі результати",
    ["Minimum level"] = "Мінімальний рівень",
    ["Starts at"] = G"quest.started_by",
    Attunes = G"game.attunements",
    ["Attuned alts"] = "Альти з допуском",
    ["GeneralSettings"] = "Загальні налаштування",
    ["SurveySettings"] = "Налаштування опитувань",
    ["Survey Log"] = "Журнал опитувань",

    -- Minimap button tooltip
    LeftClick = G"ui.left_click",
    ["OpenAttune"] = "    Відкрити Attune",
    RightClick = G"ui.right_click",
    ["OpenSettings"] = "  Відкрити налаштування",
    ["Addon disabled"] = "Аддон вимкнено",

    -- Chat messages
    ["StartAutoGuildSurvey"] = "Надсилання автоматичного тихого опитування гільдії",
    ["SendingDataTo"] = "Надсилання даних Attune гравцю |cffffd100##NAME##|r",
    ["NewVersionAvailable"] = "Вийшла |cffffd100нова версія|r Attune, обов'язково оновіть аддон!",
    ["CompletedStep"] = "Виконано: ##TYPE## |cffe4e400##STEP##|r (допуск |cffe4e400##NAME##|r).",
    ["AttuneComplete"] = "Допуск |cffe4e400##NAME##|r отримано!",
    ["SendingSurveyWhat"] = "Надсилання опитування (##WHAT##)",
    ["SendingGuildSilentSurvey"] = "Надсилання тихого опитування гільдії",
    ["ReceivedDataFromName"] = "Отримано дані від |cffffd100##NAME##|r",
    ["ExportingData"] = "Експорт даних Attune. Персонажів: ##COUNT##",
    ["ReceivedRequestFrom"] = "Отримано запит на опитування від |cffffd100##FROM##|r", -- compared by Attune: stored as built text in the Survey Log
    -- /attune help: survey, export and /attune are command words, so they stay English
    ["Help1"] = "Цей аддон показує ваш прогрес у допусках і дає змогу його експортувати",
    ["Help2"] = "Введіть |cfffff700/attune|r, щоб почати.",
    ["Help3"] = "Щоб перевірити прогрес гільдії, натисніть |cfffff700Опитування|r і зберіть дані.",
    ["Help4"] = "Тоді ви отримаєте дані про прогрес від кожного учасника гільдії, у якого є цей аддон.",
    ["Help5"] = "Коли даних буде досить, натисніть |cfffff700export|r, щоб експортувати прогрес гільдії",
    ["Help6"] = "Дані можна завантажити на |cfffff700https://warcraftratings.com/attune/upload|r",
    ["Survey_DESC"] = "Запустити опитування про допуски (для гравців з аддоном)",
    ["Toggle_DESC"] = "Перемкнути між допусками й результатами опитування",

    -- Sync, roles and status
    ["My Toons"] = "Мої персонажі",
    ["ResetToon_TEXT"] = "Скинути прогрес",
    ["ResetToon_DESC"] = "Видалити всі збережені результати допусків персонажа, за якого ви граєте. Прогрес, який аддон ще може визначити, буде скановано знову.",
    ["ResetToon_CONF"] = "Справді скинути результати цього персонажа?",
    ["ResetToon_DONE"] = "Результати цього персонажа видалено.",
    ["No Target"] = "У вас немає цілі",
    ["No Response From"] = "Немає відповіді від ##PLAYER##",
    ["Sync Request From"] = "Новий запит на синхронізацію Attune від:\n\n##PLAYER##",
    ["Could be slow"] = "Залежно від обсягу ваших даних це може тривати дуже довго",
    ["Accept"] = G"ui.accept",
    ["Reject"] = G"ui.reject",
    ["Busy right now"] = "##PLAYER## зараз не може відповісти, спробуйте пізніше",
    ["Sending Sync Request"] = "Надсилання запиту на синхронізацію гравцю ##PLAYER##",
    ["Request rejected"] = "Запит відхилено",
    ["Sync over"] = "Синхронізацію завершено за ##DURATION##",
    -- Status and role labels (shown only; Attune stores and compares the raw words)
    Main = G"game.main_character",
    Alt = G"game.alt",
    Tank = G"role.tank",
    Healer = G"role.healer",
    ["Melee DPS"] = G"role.melee_dps",
    ["Ranged DPS"] = G"role.ranged_dps",
    ["Bank"] = "Банк",

    -- Quest rewards panel
    ["External link"] = "Посилання на онлайн-базу даних",
    ["Quest rewards"] = "Нагороди за завдання",
    ["No item rewards"] = "За це завдання не дають предметів.",
    ["Loading rewards"] = "Завантаження нагород...",
    ["Show link"] = "Показати посилання",
    ["Experience reward"] = "+%s досвіду",

    -- Character progression attunes
    ["Initiate_Desc"] = "Перше випробування героя.",
    ["Intermediate_Desc"] = "Шлях стає крутішим.",
    ["Veteran_Desc"] = "Справжнє випробування ветерана.",
    ["Creatures killed"] = "Убито істот",
    ["Quests completed"] = "Виконано завдань",
    ["Honorable kills"] = "Почесні вбивства",
    ["5-player dungeons"] = "Підземелля на 5 гравців",
    ["Times camped"] = "Розбито таборів",
    ["Cooking skill"] = "Навичка кулінарії",
    ["Fishing skill"] = "Навичка риболовлі",
    ["First Aid skill"] = "Навичка першої допомоги",
    ["ProfessionsAt"] = "2 професії на рівні ##SKILL##",
    ["NoProfessionYet"] = "Ви ще не вивчили жодної основної професії.",
    ["Target"] = "Ціль",
    ["SendingSurveyTo"] = "Надсилання опитування: ##TO##",

    -- Options
    ["MinimapButton_TEXT"] = "Показувати кнопку біля мінікарти",
    ["MinimapButton_DESC"] = "Кнопка біля мінікарти, щоб швидко відкрити вікно аддона або налаштування.",
    ["PlaySounds_TEXT"] = "Відтворювати звуки",
    ["PlaySounds_DESC"] = "Звук, коли ви виконуєте крок, завершуєте допуск, перемикаєте вигляд або отримуєте запит на синхронізацію.",
    ["DeadminesAsDM_TEXT"] = "DM — це «Мертві Копальні»",
    ["DeadminesAsDM_DESC"] = "Показувати «Мертві Копальні» як DM, а «Лютопащ» — повною назвою.",
    ["FullMap_TEXT"] = "Показувати, хто видає завдання, на великій карті",
    ["FullMap_DESC"] = "Коли ви клацаєте завдання, відкривається карта світу з тим, хто його видає, замість карти на бічній панелі. Тоді бічну панель заповнюють нагороди за завдання.",
    ["ShowAllClassQuests_TEXT"] = "Показувати класові завдання всіх класів",
    ["ShowAllClassQuests_DESC"] = "Показувати класові завдання кожного класу. Якщо вимкнено, у списку лише завдання вашого класу.",
    ["ShowCharacterProgression_TEXT"] = "Показувати допуски «Розвиток персонажа»",
    ["ShowCharacterProgression_DESC"] = "Показувати допуски «Розвиток персонажа» у списку й у вікні «Attune: далі».",
    ["Categories"] = "Категорії",
    ["Categories_DESC"] = "Виберіть, які категорії показувати в списку, у вигляді значків і у вікні «Attune: далі».",
    ["ShowCategory_DESC"] = "Показувати цю категорію в списку, у вигляді значків і у вікні «Attune: далі».",
    ["NextSteps_TEXT"] = "Показувати вікно «Attune: далі»",
    ["NextSteps_DESC"] = "Невелике вікно з наступним кроком кожного допуску. Першими йдуть найближчі до вашого рівня. Тягніть заголовок, щоб посунути вікно, а кут — щоб змінити розмір.",
    ["NextSteps_TITLE"] = "Attune: далі",
    ["NextSteps_EMPTY"] = "Зараз нема чого робити",
    ["NextSteps_DRAG"] = "Тягніть, щоб посунути",
    ["NextSteps_MIN"] = "Згорнути",
    ["NextSteps_RESTORE"] = "Розгорнути",
    ["NextSteps_LATER"] = "Наступний допуск з ##LEVEL## рівня",
    ["NextSteps_MISSED_ONE"] = "Задовисокий рівень для 1 допуску",
    ["NextSteps_MISSED"] = "Задовисокий рівень для допусків: ##COUNT##",
    ["IconView_TEXT"] = "Показувати список Attune значками",
    ["IconView_DESC"] = "Значки ліворуч замість списку. Клацніть значок, щоб відкрити цей допуск.",
    ["TreeView_TIP"] = "Показати список",
    ["IconView_TIP"] = "Показати значки",
    ["TreeScale_TEXT"] = "Розмір тексту в списку",
    ["TreeScale_DESC"] = "Розмір тексту й значків у списку допусків. Якщо назви обрізано, потягніть край списку.",
    ["TreeScale_Normal"] = "Звичайний",
    ["TreeScale_Large"] = "Великий",
    ["TreeScale_Larger"] = "Дуже великий",
    ["ArchiveCompleted_TEXT"] = "Архівувати виконані допуски",
    ["ArchiveCompleted_DESC"] = "Переносити виконані допуски в категорію «Виконано» внизу.",
    ["WillNotDo_TIP"] = "Сховати цей допуск із вікна «Attune: далі» й тримати його внизу списку.",
    ["ClassQuest_Desc"] = "Виконайте цей ланцюжок класових завдань.",
    ["AutoSurvey_TEXT"] = "Автоматично опитувати гільдію під час входу",
    ["AutoSurvey_DESC"] = "Щоразу, коли ви входите в гру, аддон опитує гільдію.",
    ["ShowSurveyed_TEXT"] = "Повідомляти, коли мене опитують",
    ["ShowSurveyed_DESC"] = "Повідомлення в чаті, коли ви отримуєте запит на опитування (і відповідаєте на нього).",
    ["ShowResponses_TEXT"] = "Показувати відповіді на мої опитування",
    ["ShowResponses_DESC"] = "Повідомлення в чаті про кожну відповідь на опитування.",
    ["ShowSetMessages_TEXT"] = "Повідомляти про виконані кроки",
    ["ShowSetMessages_DESC"] = "Повідомлення в чаті, коли крок або допуск виконано.",
    ["AnnounceToGuild_TEXT"] = "Оголошувати в чаті гільдії",
    ["AnnounceToGuild_DESC"] = "Надсилати повідомлення в чат гільдії (англійською), коли допуск виконано.",
    ["ShowOther_TEXT"] = "Показувати інші повідомлення в чаті",
    ["ShowOther_DESC"] = "Усі інші звичайні повідомлення в чаті (привітання, надсилання опитування, доступне оновлення тощо).",
    ["ShowGuildies_TEXT"] = "Показувати учасників гільдії на кожному кроці.               Найбільше в списку",
    ["ShowGuildies_DESC"] = "Показує в підказці кроку список учасників гільдії, які зараз на цьому кроці допуску.\nЗа потреби змініть, скільки учасників щонайбільше показувати на кожному кроці.",
    ["ClearAll_TEXT"] = "Видалити ВСІ результати",
    ["ClearAll_DESC"] = "Видалити всі зібрані дані про інших гравців.",
    ["ClearAll_CONF"] = "Справді видалити ВСІ результати?",
    ["DelNonGuildies_TEXT"] = "Видалити гравців поза гільдією",
    ["DelNonGuildies_DESC"] = "Видалити всі зібрані дані про гравців поза вашою гільдією.",
    ["DelNonGuildies_CONF"] = "Справді видалити всіх, хто не в гільдії?",
    ["DelNonGuildies_DONE"] = "Усі результати поза вашою гільдією видалено.",

    -- Attunement descriptions
    ["MC_Desc"] = "Цей допуск потрібен усім учасникам рейду, щоб увійти в рейдове підземелля, якщо тільки вони не заходять через «Глибини Блекрок».",
    ["Ony_Desc"] = "Щоб увійти в рейдове підземелля, кожен учасник рейду повинен мати в сумці «Амулет Драконячого Вогню».",
    ["BWL_Desc"] = "Цей допуск потрібен усім учасникам рейду, щоб увійти в рейдове підземелля, якщо тільки вони не заходять через «Верхній Шпиль Блекрока».",
    ["All_Desc"] = "Цей допуск потрібен усім учасникам рейду, щоб увійти в рейдове підземелля.",
    ["AQ_Desc"] = "Це має виконати лише один гравець на сервері, щоб відчинилася «Брама Ан'Кіражу».",
    ["OnlyOne_Desc"] = "Цей ключ потрібен лише одному гравцеві в групі. Браму також може відчинити розбійник, у якого «Зламування замків» 350.",
    ["DungeonQuest_Desc"] = "Візьміть ці завдання, перш ніж уперше зайти в підземелля.\nЦе не повний список завдань цього підземелля, а лише початки ланцюжків.\nМожуть бути й наступні завдання, але їх тут не обов'язково вказано.",
    ["Dal_Desc"] = "Щоб увійти в підземелля, ключ потрібен лише одному гравцеві в групі.",
    ["SK_Desc"] = "Цей ключ відчиняє крила Зброярні й Собору підземелля «Багряний Монастир». Він також відчиняє ворота в «живу» частину підземелля «Стратгольм».\n\nЩоб відчинити ці двері, ключ потрібен лише одному гравцеві в групі.",
    ["TD_Desc"] = "«Фоліант Даларану» викликає «Лін Знехтувана» — необов'язкового боса в підземеллі «Місто Даларан».\n\nДля виклику досить одного фоліанта.",
    ["MC2_Desc"] = "Потрібно, щоб викликати боса «Мажордом Екзекутус». У підземеллі «Розплавлене Ядро» біля кожного боса, крім «Люцифрон» і «Барон Геддон», на землі є руни. Їх треба загасити, щоб з'явився Мажордом.",
    ["CSB_Desc"] = "Ідіть за записками континентами «Калімдор» і «Східні Королівства», щоб отримати «Затишний Спальний Мішок».",

    -- Step graph and tooltips
    ["Reach level"] = "Досягти рівня", -- compared by Attune: baked into step names as "Reach level 20"
    Attuned = G"quest.state_complete",
    ["Not attuned"] = "Не виконано",
    ["AttuneColors"] = "Синій: виконано\nЧервоний: не виконано",
    ["Minimum Level"] = "Це мінімальний рівень, з якого доступні завдання.",
    ["NPC Not Found"] = "Не знайдено даних про НІП",
    Level = G"game.level",
    ["Exalted with"] = "Звеличений:", -- compared by Attune: baked into step names before the faction
    ["Revered with"] = "Поважаний:", -- compared by Attune: baked into step names before the faction
    ["Honored with"] = "Шанований:", -- compared by Attune: baked into step names before the faction
    ["Neutral with"] = "Нейтральний:", -- compared by Attune: baked into step names before the faction
    ["Inside"] = G"map.inside",
    ["OR"] = "АБО",
    ["Required level"] = "Потрібен рівень",
    ["Requires level"] = "Потрібен рівень",
    ["Attunement or key"] = "Допуск або ключ",
    Reputation = G"game.reputation",
    ["in"] = "—", -- between a step type and a zone: "Убити — Westfall" needs no case
    ["Unknown Reputation"] = "Невідома репутація", -- compared by Attune: stored as a faction name
    ["Current progress"] = "Поточний прогрес",
    ["Completion"] = "Виконано",
    ["Solo quest"] = "Завдання для одного гравця",
    ["Party quest"] = "Групове завдання (гравців: ##NB##)",
    ["Raid quest"] = "Рейдове завдання (гравців: ##NB##)",

    -- NPC rank and kind: "Рівень 60 еліта Драконід" (the elite ranks are nouns with no gender)
    Elite = G"npc.rank_elite",
    Boss = G"npc.rank_boss",
    ["Rare Elite"] = G"npc.rank_rare_elite",
    ["Dragonkin"] = "Драконід",
    Troll = G"race.troll",
    ["Ogre"] = "Огр",
    Orc = G"race.orc",
    ["Half-Orc"] = "Напіворк",
    Human = G"race.human",
    Dwarf = G"race.dwarf",
    ["Mechanical"] = "Механічний",
    ["Arakkoa"] = "Аракоа",
    ["Ethereal"] = "Ефіріал",
    ["Blood Elf"] = G"race.blood_elf",
    ["Elemental"] = "Елементаль",
    ["Shiny thingy"] = "Блискуча штучка",
    ["Naga"] = "Нага",
    ["Demon"] = "Демон",
    ["Gronn"] = "Гронн",
    Tauren = G"race.tauren",
    ["Qiraji"] = "Кіраж",
    Gnome = G"race.gnome",
    ["Broken"] = "Зламаний",
    Draenei = G"race.draenei",
    Undead = G"race.undead",
    ["Gorilla"] = "Горила",
    ["Shark"] = "Акула",
    ["Chimaera"] = "Химера",
    ["Wisp"] = "Вогник",
    ["Night-Elf"] = "Нічний ельф",
    ["Quillboar"] = "Кабанолюд",
    ["Giant"] = "Велетень",
    ["Beast"] = "Звір",
}

-- Categories, by locale key. The tree shows the value (RAIDS), the options list it in sentence case.
ns.UA_CATEGORY = {
    RAIDS = G"game.raids",
    KEYS = "Ключі й доступ",
    MISC = "Різне",
    HEROICS = "Героїчні",
    DUNGEONS = G"game.dungeon",
    CHARACTER = "Розвиток персонажа",
    CLASSES = "Класи",
    Archived = G"quest.state_complete",
    WillNotDo = "Не робитиму",
}

-- Tooltip lines Attune glues from a locale word and a number or name: { shape, Ukrainian }.
ns.UA_GLUED = {
    ["Current progress"] = { "{}: %s/%s", "Поточний прогрес: %s/%s" },
    Completion = { "{}: %s%%", "Виконано: %s%%" },
    ["Requires level"] = { "{} %s", "Потрібен рівень %s" },
    Level = { "{} %s", G"game.level_n" },
    ["Reach level"] = { "{} %s", "Досягти рівня %s" },
    ["in"] = { "%s {} %s", "%s — %s" },
    ["Exalted with"] = { "{} %s", "Звеличений: %s" },
    ["Revered with"] = { "{} %s", "Поважаний: %s" },
    ["Honored with"] = { "{} %s", "Шанований: %s" },
    ["Neutral with"] = { "{} %s", "Нейтральний: %s" },
    ["NPC Not Found"] = { "{} (ID %s)", "Не знайдено даних про НІП (ID %s)" },
}

-- Step TYPE values (Attune compares the raw English). Display labels only, for the node type line and the
-- CompletedStep chat line; leave the value itself alone.
ns.UA_STEP_TYPE = {
    Quest = G"game.quest",
    ["Pick Up"] = "Взяти",
    ["Turn In"] = "Здати",
    ["Kill"] = "Убити",
    ["Interact"] = G"step.interact",
    Item = G"game.item",
    Level = G"game.level",
    ["Stat"] = "Статистика",
    Prof = G"game.professions",
}
