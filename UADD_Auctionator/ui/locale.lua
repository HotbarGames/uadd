-- Auctionator texts in Ukrainian:
--   ns.UA      keyed by Auctionator's own locale key (the name after AUCTIONATOR_L_, as in Locales/enUS.lua);
--   ns.UA_MADE (at the end) texts Auctionator joins in its code from its locale texts.
-- The English it writes straight in its code (slash command help, chat lines) is in ui/text.lua, by hash.
-- No English here: tools/make_auc_text.py review writes local/auctionator.txt with the English beside it.
-- A text keeps the same %s / %d slots in the same order, %% for a real %, the same |c........|r colour
-- codes and \n breaks (written \\n where Auctionator writes \\n), and the same leading or trailing spaces.
-- "-- LONG" marks a short label (button, tab, column) that is much longer than the English.
-- "-- compared by Auctionator" marks a text the addon compares with what it reads back (a column header that
--   names a hidden column, "any" in a search, the search box, "Yes" in the Owned and Undercut columns).
--   It works in Ukrainian as long as this table sets it before Auctionator reads it.
-- Lines with a glossary word use a plain key (KEY = G"id") instead of ["KEY"]: the same Lua table entry,
--   but tools/glossary.py then does not take the key for English text.
-- Number-safe forms where Ukrainian would change the word with the number: "%s дн.", "Оброблено предметів:
--   %s", "%s хв %s с", "12 год" (Forever changes 12/24/48 to 2/8/24 in the duration buttons; "год" fits all).
-- Weekdays and months: Auctionator writes "weekday, month day"; Words.lua turns the whole date round to
--   "Вівторок, 25 лютого", so the months are in the "of" form (січня, лютого) and the weekdays capitalised.
--
-- Kept in English on purpose (not in this file):
--   AUCTIONATOR, DISCORD (names); NUMBER_SEPARATOR (data: "," inside numbers); UNDERCUT_UNKNOWN ("?") and
--   ITEM_NAME_X_ITEM_LEVEL_X ("%s (%s)") have no words.
--   Keys no code on any client reads: CONFIG_SCANNING, CONFIG_SCAN_SETTINGS, BUG_REPORT, BUG_TOOLTIP_HEADER,
--   BUG_TOOLTIP_TEXT, ROADMAP, ROADMAP_TOOLTIP_TEXT, TRANSLATORS_HELP, TOO_MANY_SEARCH_RESULTS,
--   LIST_DELETE_ERROR, LIST_ADD_ERROR, CANNOT_AUCTION, DELETE_LIST_NONE_SELECTED, ADD_TERM_TO_LIST_DIALOG,
--   SAVE_AS, CREATE, ADD_ITEM, SORT, SHOPPING_LIST, SELECT_SHOPPING_LIST, SAVE_THIS_LIST_AS,
--   OPEN_IN_SHOPPING_TAB, RESULTS_STACK_SIZE_COLUMN, LIST_ADD_ITEM_HEADER, BUYING, ADD_FAVOURITE,
--   REMOVE_FAVOURITE, CONFIG_SELLING_IGNORE_ITEM_LEVEL, POSTING_SETTINGS_COLON.
--   The names /auctionator and /atr and every command word after them, config option names, the
--   "Auctionator: " chat prefix, "WoW: " in the version line, translator and author names, game names
--   (items, expansions) inside a sentence, and Blizzard's own texts.
-- Keys only the Classic auction house uses (stacks, chain buy, load more...) are translated too, in case
--   that code runs on Forever.
-- Over the 300-line budget on purpose: it is one flat table of data.
local _, ns = ...
-- G"id" takes a word from the shared base, UADD/glossary/*.lua (see docs/GLOSSARY.md).
local G = UADD and UADD.Glossary and UADD.Glossary.Text or function() return nil end
ns.UA = {
    -- Settings: basic options
    ["CONFIG_BASIC_OPTIONS_CATEGORY"] = "Основні налаштування",
    ["CONFIG_BASIC_OPTIONS_TEXT"] = "Основні налаштування: які можливості Auctionator увімкнути.",
    ["CONFIG_AUTO_LIST_SEARCH"] = "Автоматично шукати предмети зі списку покупок.",
    ["CONFIG_AUTO_LIST_SEARCH_TOOLTIP_HEADER"] = "Автоматичний пошук за списком",
    ["CONFIG_AUTO_LIST_SEARCH_TOOLTIP_TEXT"] = "Коли ви вибираєте список, на аукціоні одразу шукаються всі його пункти. Якщо це налаштування вимкнено, увесь список можна перевірити кнопкою «Пошук» на бічній панелі списків покупок.",
    ["CONFIG_SHOPPING_LIST_MISSING_TERMS"] = "Показувати в результатах пункти списку покупок, для яких нічого не знайдено.",
    ["CONFIG_SHOPPING_LIST_MISSING_TERMS_TOOLTIP_HEADER"] = "Пошуки без результатів",
    ["CONFIG_SHOPPING_LIST_MISSING_TERMS_TOOLTIP_TEXT"] = "Якщо за пошуковим запитом нічого не знайдено, у результати додається рядок із нульовою кількістю, щоб це було видно.",
    ["CONFIG_CHAT_LOG"] = "Показувати ваші нові лоти в чаті",
    ["CONFIG_CHAT_LOG_TOOLTIP_HEADER"] = "Лоти в чаті",
    ["CONFIG_CHAT_LOG_TOOLTIP_TEXT"] = "Якщо це налаштування вимкнено, ваші лоти не перевірятимуться, щоб знайти нові.",
    ["CONFIG_AUTOSCAN"] = "Запускати автосканування, коли відкривається аукціон.",
    ["CONFIG_AUTOSCAN_TOOLTIP_HEADER"] = "Автосканування",
    ["CONFIG_AUTOSCAN_TOOLTIP_TEXT"] = "Запускати повне сканування, коли відкривається аукціон. Якщо вимкнено, повне сканування можна запустити кнопкою «Повне сканування» на аукціоні.",
    ["CONFIG_AUTOSCAN_INTERVAL_HEADER"] = "Інтервал між автоскануваннями",
    ["CONFIG_AUTOSCAN_INTERVAL"] = "Скільки хвилин чекати між автоскануваннями",
    ["CONFIG_AUTOSCAN_INTERVAL_TOOLTIP_HEADER"] = "Затримка автосканування",
    ["CONFIG_AUTOSCAN_INTERVAL_TOOLTIP_TEXT"] = "Типово сканування не запускається щоразу, коли ви відкриваєте аукціон. Воно чекає, доки від останнього сканування мине заданий час.",
    ["CONFIG_ALTERNATE_SCAN"] = "Типово використовувати повільніший запасний режим сканування",
    ["CONFIG_ALTERNATE_SCAN_HEADER"] = "Запасний режим сканування",
    ["CONFIG_ALTERNATE_SCAN_TEXT"] = "Швидкий режим сканування може спричиняти роз'єднання з сервером, коли той завантажений. Це налаштування вмикає повільніший спосіб, з яким роз'єднання менш імовірне.",

    ["CONFIG_DEVELOPER"] = "Для розробників",
    ["CONFIG_DEBUG"] = "Увімкнути або вимкнути налагоджувальні повідомлення.",
    ["CONFIG_DEBUG_TOOLTIP_HEADER"] = "Налагодження Auctionator",
    ["CONFIG_DEBUG_TOOLTIP_TEXT"] = "Це для розробників: налагоджувальні повідомлення виводяться в чат.",

    ["CONFIG_SHOPPING_CATEGORY"] = "Покупки",
    ["CONFIG_SHOPPING_TEXT"] = "Налаштування вкладки «Покупки».",
    ["CONFIG_CANCELLING_CATEGORY"] = "Скасування",
    ["CONFIG_CANCELLING_TEXT"] = "Налаштування вкладки «Скасування».",

    -- Settings: tooltips
    CONFIG_TOOLTIPS_CATEGORY = G"ui.tooltips",
    ["CONFIG_TOOLTIPS_TEXT"] = "Які дані з аукціону показувати в підказках предметів: у сумках та деінде.",
    ["CONFIG_MAIL_TOOLTIP"] = "Показувати в підказках аукціонну ціну вкладень у пошті",
    ["CONFIG_PET_TOOLTIP"] = "Показувати в підказках аукціонну ціну вихованців у клітках",
    ["CONFIG_VENDOR_TOOLTIP"] = "Показувати в підказках ціну продажу торговцеві",
    ["CONFIG_AUCTION_TOOLTIP"] = "Показувати в підказках аукціонну ціну предметів",
    ["CONFIG_AUCTION_AGE_TOOLTIP"] = "Показувати, скільки днів тому ціну бачили на аукціоні (до 21 дня)",
    ["CONFIG_ENCHANT_TOOLTIP"] = "Показувати в підказках орієнтовну вартість розчаклування предмета (лише WoD, Legion, BfA і Shadowlands)",
    ["CONFIG_ENCHANT_GENERIC_TOOLTIP"] = "Показувати в підказках орієнтовну вартість розчаклування предметів",
    ["CONFIG_PROSPECT_TOOLTIP"] = "Показувати в підказках руди орієнтовну вартість просіювання (ювелірство)",
    ["CONFIG_MILL_TOOLTIP"] = "Показувати в підказках трав орієнтовну вартість розтирання (накреслення)",
    ["CONFIG_STACK_TOOLTIP"] = "Показувати ціну стосу, лише коли затиснуто Shift.",
    ["STACK_TOOLTIP_TOOLTIP_HEADER"] = "Ціни стосів",
    ["STACK_TOOLTIP_TOOLTIP_TEXT"] = "Якщо ввімкнено, ціну стосу видно лише із затиснутою клавішею Shift. Якщо вимкнено, ціни стосів видно завжди.",

    -- Duration: Forever replaces the numbers 12/24/48 with 2/8/24, so keep the digits and "год".
    ["DEFAULT_AUCTION_DURATION"] = "Типова тривалість лоту",
    ["AUCTION_DURATION_12"] = "12 год",
    ["AUCTION_DURATION_24"] = "24 год",
    ["AUCTION_DURATION_48"] = "48 год",

    -- Settings: undercut
    ["CONFIG_UNDERCUT_SCAN_NOT_LIFO"] = "Перевіряти спорядження й вихованців під час пошуку перебитих лотів",
    ["CONFIG_UNDERCUT_SCAN_NOT_LIFO_TOOLTIP_HEADER"] = "Перебиті лоти: спорядження й вихованці",
    ["CONFIG_UNDERCUT_SCAN_NOT_LIFO_TOOLTIP_TEXT"] = "Залиште ввімкненим, щоб пошук перебитих лотів перевіряв і лоти зі спорядженням та вихованцями. Вимкніть, щоб їх пропускати.",
    ["CONFIG_CANCEL_UNDERCUT_SHORTCUT"] = "Скасувати наступний перебитий лот:",
    ["CONFIG_CANCEL_UNDERCUT_SHORTCUT_TOOLTIP_TEXT"] = "Клацніть і натисніть клавіші, які хочете використовувати. Це сполучення діє лише на вкладці «Скасування» і не заважає іншим призначенням цих клавіш.",
    ["CONFIG_UNDERCUT_ITEMS_AHEAD_CLASSIC"] = "Скільки предметів може бути попереду ваших лотів, перш ніж вони вважатимуться перебитими (до 50)",
    ["CONFIG_UNDERCUT_ITEMS_AHEAD"] = "Скільки предметів може бути попереду ваших лотів, перш ніж вони вважатимуться перебитими",

    ["UNDERCUT_PREFERENCE"] = "Як знижувати ціну",
    ["PERCENTAGE"] = "Відсоток",
    ["SET_VALUE"] = "Фіксована сума",
    ["PERCENTAGE_SUFFIX"] = "% зниження",
    ["SET_VALUE_SUFFIX"] = "зниження",
    ["PERCENTAGE_TOOLTIP_HEADER"] = "Відсоток зниження",
    ["PERCENTAGE_TOOLTIP_TEXT"] = "На скільки відсотків знизити ціну продажу. Наприклад, 5 означає, що ваш предмет буде виставлено на 5% дешевше за поточну найнижчу ціну.",
    ["UNDERCUT_TOOLTIP_HEADER"] = "Сума зниження",
    ["UNDERCUT_TOOLTIP_TEXT"] = "На яку суму знизити ціну продажу.",

    CONFIG_ADVANCED_CATEGORY = G"ui.advanced",
    ["CONFIG_ADVANCED_TEXT"] = "Змінюйте це, лише якщо знаєте, що робите",
    ["CONFIG_QUANTITIES_CATEGORY"] = "Продаж: кількість",
    ["CONFIG_QUANTITIES_TEXT"] = "Типова кількість для виставлення в різних категоріях предметів.",
    ["CONFIG_SELLING_ALL_ITEMS_CATEGORY"] = "Продаж: усі предмети",

    -- Info tab
    ["AUTHOR_HEADER"] = "Автор",
    ["PAST_AUTHOR_HEADER"] = "Колишній автор",
    ["TRANSLATORS_HEADER"] = "Перекладачі",
    ["VERSION_HEADER"] = "Версія",
    ["OPEN_ADDON_OPTIONS"] = "Відкрити налаштування",
    ["SUPPORT_HEADER"] = "Підтримка",
    ["DISCORD_TOOLTIP_HEADER"] = "Приєднуйтеся до нас у Discord!",
    ["DISCORD_TOOLTIP_TEXT"] = "У нас активна спільнота користувачів Auctionator, яка допоможе відповісти на ваші запитання.",
    ["TRANSLATORS_GERMAN"] = "Німецька",
    ["TRANSLATORS_BRAZIL_PORTUGUEUSE"] = "Бразильська португальська",
    ["TRANSLATORS_TRADITIONAL_CHINESE"] = "Традиційна китайська",
    ["TRANSLATORS_SIMPLIFIED_CHINESE"] = "Спрощена китайська",
    ["TRANSLATORS_SPANISH"] = "Іспанська",
    ["TRANSLATORS_LATIN_SPANISH"] = "Латиноамериканська іспанська", -- LONG
    ["TRANSLATORS_FRENCH"] = "Французька",
    ["TRANSLATORS_ITALIAN"] = "Італійська",
    ["TRANSLATORS_KOREAN"] = "Корейська",
    ["TRANSLATORS_RUSSIAN"] = "Російська",
    ["TRANSLATORS_TURKISH_INFO"] = "Турецька (окремо)",
    ["TRANSLATORS_ROMANIAN_INFO"] = "Румунська (окремо)",

    -- Chat: your new lots. The first %s is the item link (with " xN").
    ["STACK_AUCTION_INFO"] = "%s за %s (%s за штуку)",
    ["BIDDING_AUCTION_INFO"] = "%s, ставка %s",
    ["BUYOUT_AUCTION_INFO"] = "%s, викуп %s",
    ["MULTIPLE_STACKS_AUCTION_INFO"] = "%s %s, усього %s",

    -- Full scan
    ["STARTING_FULL_SCAN"] = "Починаю повне сканування.",
    ["STARTING_FULL_SCAN_REPLICATE"] = "Починаю повне сканування (режим повної копії).",
    ["STARTING_FULL_SCAN_SUMMARY"] = "Починаю повне сканування (режим зведення).",
    ["FULL_SCAN_IN_PROGRESS"] = "Триває повне сканування.",
    ["FULL_SCAN_FAILED"] = "Не вдалося завершити повне сканування.",
    ["FULL_SCAN_FAILED_REPLICATE"] = "Не вдалося завершити повне сканування (режим повної копії).",
    ["FULL_SCAN_FAILED_SUMMARY"] = "Не вдалося завершити повне сканування (режим зведення).",
    ["NEXT_SCAN_MESSAGE"] = "Повне сканування можна буде запустити через %s хв %s с.",
    ["FINISHED_PROCESSING"] = "Оброблено предметів: %s.",

    ["TOO_SMALL_PERCENTAGE"] = "%% має бути >= 0 (вказано %s)",
    ["TOO_BIG_PERCENTAGE"] = "%% має бути <= 100 (вказано %s)",

    -- Tooltip price lines (label on the left, price on the right)
    ["AUCTION"] = "Аукціон",
    ["AUCTION_AGE"] = "Давність ціни",
    ["AUCTION_MEAN"] = "Середня на аукціоні",
    ["X_DAYS"] = "%s дн.",
    ["UNKNOWN"] = "невідомо",
    VENDOR = G"npc.vendor",
    ["DISENCHANT"] = "Розчаклування",
    ["PROSPECT"] = "Просіювання",
    ["MILL"] = "Розтирання",
    ["TOTAL_ITEMS_COLORED"] = "Усього |cFFAAAAFF предметів: %s|r",

    -- Shopping lists
    ["DELETE_LIST_CONFIRM"] = "Ви ТОЧНО хочете видалити «%s»?",
    ["CREATE_LIST_DIALOG"] = "Введіть назву нового списку покупок:",
    ["RENAME_LIST_CONFIRM"] = "Введіть нову назву для «%s»:",
    ["MAKE_PERMANENT_CONFIRM"] = "Щоб зробити «%s» постійним, дайте йому нову назву:",
    ["MAKE_PERMANENT"] = "Зробити постійним",
    ["RENAME"] = "Перейменувати",
    DELETE = G"ui.delete",
    ["EDIT_ITEM"] = "Змінити пункт",
    SEARCH = G"ui.search",
    ["SEARCH_OPTIONS"] = "Параметри пошуку",
    ["ADD_TO_LIST"] = "Додати до списку",
    ["SEARCH_ALL"] = "Шукати все",
    ["EXPORT"] = "Експорт",
    IMPORT = G"ui.import",
    SHOPPING_LISTS = G"auction.shopping_lists",
    ["RECENT_SEARCHES"] = "Нещодавні пошуки",
    ["NO_LIST"] = "без списку",
    ["NEW_LIST"] = "Новий список",
    ["COPY_NO_LIST_SELECTED"] = "Не вдалося скопіювати предмет: не вибрано список покупок",
    ["COPY_ITEM_ADDED"] = "Скопійовано %s до %s",
    ["COPY_TO_LIST"] = "Скопіювати предмет до активного списку покупок",
    ["EXTENDED_SEARCH_ACTIVE_TEXT"] = "%розширений пошук%", -- compared by Auctionator

    -- Tabs
    ["SHOPPING_TAB"] = "Покупки",
    ["SHOPPING_TAB_HEADER_2"] = "Auctionator - Покупки",
    ["INFO_TAB_HEADER"] = "Auctionator - Інформація",
    ["SELLING_TAB"] = "Продаж",
    ["SELLING_TAB_HEADER"] = "Auctionator - Продаж",
    ["CANCELLING_TAB"] = "Скасування",
    ["CANCELLING_TAB_HEADER"] = "Auctionator - Скасування",
    ["BID_EXISTING_ON_OWNED_AUCTION"] = "На цей лот уже зробили ставку, тож скасування коштуватиме вам застави, а також:",

    -- Search results and their columns
    ["FETCHING_ITEM_INFO"] = "Отримання даних про предмет...",
    ["LIST_SEARCH_START"] = "Пошук предметів зі списку %s...",
    ["LIST_SEARCH_STATUS"] = "Пошук предмета %s/%s у списку\\n %s",
    ["RESULTS_PRICE_COLUMN"] = "Ціна", -- compared by Auctionator
    ["RESULTS_NAME_COLUMN"] = "Назва", -- compared by Auctionator
    ["RESULTS_AVAILABLE_COLUMN"] = "Доступно", -- compared by Auctionator
    RESULTS_STACK_PRICE_COLUMN = G"auction.stack_price", -- compared by Auctionator
    ITEM_LEVEL_COLUMN = G"game.item_level", -- compared by Auctionator; its column header: ns.UA_HEAD
    SELLERS_COLUMN = G"auction.sellers", -- compared by Auctionator
    ["SELLERS_OVERFLOW_TEXT"] = "%s та ще %s",
    ["OWNED_COLUMN"] = "Ваш?", -- compared by Auctionator
    ["IS_TOP_COLUMN"] = "Перший?", -- compared by Auctionator
    ["YOU_COLUMN"] = "Ви?", -- compared by Auctionator

    FULL_SCAN_BUTTON = G"auction.full_scan", -- LONG

    -- Shopping list item dialog (extended search)
    ["LIST_EDIT_ITEM_HEADER"] = "Зміна пункту списку покупок",
    ["LIST_EXTENDED_SEARCH_HEADER"] = "Розширений пошук",
    ["SEARCH_TERM"] = "Пошуковий запит",
    ["SEARCH_TERM_COLON"] = "Пошуковий запит:",
    ["EXACT_SEARCH"] = "Точний пошук",
    ["ITEM_CLASS"] = "Клас предмета",
    ITEM_LEVEL = G"game.item_level", -- compared by Auctionator; its column header: ns.UA_HEAD
    LEVEL = G"game.level", -- compared by Auctionator
    PRICE = G"auction.buyout_price", -- set twice in enUS.lua (the later one counts) -- compared by Auctionator
    ["DATE"] = "Дата", -- compared by Auctionator
    ["CRAFTED_LEVEL"] = "Рівень виробу",
    ["TIER"] = "Ранг", -- Auctionator adds " %1" after it in a gsub: no % here
    ["EXPANSION"] = "Доповнення",
    ["MIN"] = "Мін.",
    ["MAX"] = "Макс.",
    CANCEL = G"ui.cancel",
    ["RESET_ALL"] = "Скинути все",
    ["LIST_IMPORT_HEADER"] = "Імпорт списків покупок",
    ["LIST_EXPORT_HEADER"] = "Експорт списків покупок",
    ["EXPORT_AS"] = "Експортувати як:",
    ["EXPORT_STRING"] = "Рядок для поширення",
    ["EXPORT_WHISPER"] = "Шепнути гравцеві",
    CLOSE = G"ui.close",
    ["COPY_TEXT_HEADER"] = "Копіювати текст",
    ["SELECT_ALL"] = "Вибрати все",
    ["UNSELECT_ALL"] = "Зняти вибір",
    ["CONFIRM_X_TOTAL_PRICE_X"] = "Підтвердити: %s за штуку, разом %s",
    ["NO_LONGER_AVAILABLE"] = "Уже недоступно",
    ["X_PRICE_HISTORY"] = "Історія цін: %s",
    ["NO_ITEM_INFO_SPECIFIED"] = "Не вказано даних про предмет.",
    ["BUY_STACK"] = "Купити стос",
    ["NONE_LEFT"] = "Не лишилося",
    ["BUY"] = "Купити",
    ["REFRESH"] = "Оновити",

    ["ANY_LOWER"] = "не задано", -- compared by Auctionator
    ["ANY_UPPER"] = "Усі",
    ["NO_RESULTS"] = "Нічого не знайдено.",

    -- Cancelling tab and its columns
    ["UNDERCUT_SCAN"] = "Пошук перебитих",
    ["CANCEL_UNDERCUT"] = "Скасувати перебитий", -- LONG
    ["NAME"] = "Назва", -- compared by Auctionator
    QUANTITY = G"auction.quantity", -- compared by Auctionator
    ["UNIT_PRICE"] = "Ціна за шт.", -- compared by Auctionator
    ["UPPER_UNIT_PRICE"] = "Макс. ціна за шт.", -- compared by Auctionator -- LONG
    TIME_LEFT = G"auction.time_left", -- compared by Auctionator
    IS_UNDERCUT = G"auction.undercut_state", -- compared by Auctionator
    ["UNDERCUT_PRICE"] = "Ціна конкурента", -- compared by Auctionator
    ["ITEMS_AHEAD"] = "Попереду", -- compared by Auctionator
    UNDERCUT_YES = G"ui.yes", -- compared by Auctionator
    UNDERCUT_NO = G"ui.no",
    UNDERCUT_BID = G"auction.bid",
    ["YOU"] = "Ви",

    -- Dates: "weekday, month day"
    ["MONTH_1"] = "січня",
    ["MONTH_2"] = "лютого",
    ["MONTH_3"] = "березня",
    ["MONTH_4"] = "квітня",
    ["MONTH_5"] = "травня",
    ["MONTH_6"] = "червня",
    ["MONTH_7"] = "липня",
    ["MONTH_8"] = "серпня",
    ["MONTH_9"] = "вересня",
    ["MONTH_10"] = "жовтня",
    ["MONTH_11"] = "листопада",
    ["MONTH_12"] = "грудня",
    ["DAY_1"] = "Неділя",
    ["DAY_2"] = "Понеділок",
    ["DAY_3"] = "Вівторок",
    ["DAY_4"] = "Середа",
    ["DAY_5"] = "Четвер",
    ["DAY_6"] = "П'ятниця",
    ["DAY_7"] = "Субота",
    ["TODAY"] = "Сьогодні",

    -- List names: "Imported (temporary)", "<addon> (temporary)"
    ["TEMPORARY_LOWER_CASE"] = "тимчасовий",
    ["IMPORTED"] = "Імпортований",

    -- Settings: profile
    ["CONFIG_PROFILE_CATEGORY"] = "Профіль",
    ["CONFIG_PROFILE_TEXT"] = "Окремі налаштування для кожного персонажа.",
    ["CONFIG_PROFILE_TOGGLE"] = "Застосовувати налаштування лише до цього персонажа",
    ["PROFILE_TOGGLE_TOOLTIP_HEADER"] = "Окремі налаштування персонажа",
    ["PROFILE_TOGGLE_TOOLTIP_TEXT"] = "Зміни налаштувань Auctionator стосуватимуться лише цього персонажа.",

    -- Selling tab
    BUYOUT_PRICE = G"auction.buyout_price", -- compared by Auctionator
    BID_PRICE = G"auction.bid", -- compared by Auctionator
    ["BIDDER"] = "Учасник торгів", -- compared by Auctionator
    DURATION = G"auction.duration",
    POST = G"auction.post", -- button 194 px
    ["SKIP"] = "Пропустити", -- button 80 px -- LONG
    ["PREVIOUS"] = "Попередній",
    ["DEPOSIT"] = "Застава:",
    ["TOTAL_PRICE"] = "Загальна ціна:",
    ["TOTAL_PRICE_PLAIN"] = "Загальна ціна",
    ["CONFIRM_POST_LOW_PRICE"] = "Ціна на %s здається трохи низькою. Справді виставити за такою ціною?",
    ["CONFIRM_POST_BELOW_VENDOR"] = "Торговцеві це можна продати дорожче. Справді виставити за такою ціною?",
    ["CONFIRM_POST_PRICE_DROP"] = "Ціна за штуку %s — це велике падіння ціни. Справді виставити за такою ціною?",
    ["POST_ATTEMPT_FAILED"] = "Остання спроба виставити не вдалася. Спробуйте ще раз.",

    -- Buying dialogs
    ["PAYING_X"] = "Ви платите %s за один предмет",
    ["CAREFUL_CAPS"] = "ОБЕРЕЖНО",
    ["PRICE_VARIES_WARNING"] = "Ціни дуже різняться між предметами.",
    ["UNIT_PRICE_RANGE"] = "Ціна за штуку: %s - %s",
    ["PRICE_INCREASED"] = "Ціна зросла!",
    ["ENTER_QUANTITY_TO_CONFIRM_PURCHASE"] = "Щоб підтвердити покупку, введіть кількість: %s",
    ["BUY_NOW"] = "Купити зараз",
    ["CONFIRM_PURCHASE_OF_X_FOR_X"] = "Підтвердити покупку %s за %s?",
    ["TOTAL_OF_X_FOR_UNIT_PRICE_OF_X"] = "Усього %s за ціною %s за штуку",

    -- Settings: default tab (after a drop-down with the tab name)
    ["DEFAULT_TAB"] = "Типова вкладка",
    ["DEFAULT_TAB_TEXT"] = "відкривається першою",
    ["NONE"] = "Жодна", -- a choice in the tab list

    ["CONFIG_SMALL_TABS"] = "Малі вкладки на аукціоні (діє, коли знову відкриєте аукціон)",
    ["CONFIG_SMALL_TABS_TOOLTIP_HEADER"] = "Малі вкладки",
    ["CONFIG_SMALL_TABS_TOOLTIP_TEXT"] = "Коли багато аддонів додають вкладки до аукціону, вони можуть виходити за край вікна. Це налаштування робить вкладки меншими, щоб вони вміщалися.",

    -- Crafting window
    ["CRAFTING_INFO"] = "Про виготовлення",
    ["CONFIG_CRAFTING_INFO_SHOW"] = "Показувати вартість виготовлення у вікні професії",
    ["CONFIG_CRAFTING_INFO_SHOW_TOOLTIP_HEADER"] = "Додаткові дані у вікні професії",
    ["CONFIG_CRAFTING_INFO_SHOW_TOOLTIP_TEXT"] = "У вікні професії видно, скільки коштує виготовити предмет. Вимкніть, щоб не показувати вартість.",
    ["CONFIG_CRAFTING_INFO_SHOW_COST"] = "Показувати вартість реагентів з аукціону й у торговців",
    ["CONFIG_CRAFTING_INFO_SHOW_COST_TOOLTIP_HEADER"] = "Про виготовлення: вартість",
    ["CONFIG_CRAFTING_INFO_SHOW_COST_TOOLTIP_TEXT"] = "Увімкніть, щоб бачити вартість виготовлення за рецептом, коли ви його переглядаєте.",
    ["CONFIG_CRAFTING_INFO_SHOW_CHEAPEST_QUALITIES_COST"] = "Рахувати вартість реагентів за найдешевшою якістю на аукціоні",
    ["CONFIG_CRAFTING_INFO_SHOW_CHEAPEST_QUALITIES_COST_TOOLTIP_HEADER"] = "Про виготовлення: найдешевша якість",
    ["CONFIG_CRAFTING_INFO_SHOW_CHEAPEST_QUALITIES_COST_TOOLTIP_TEXT"] = "Увімкніть, щоб бачити вартість виготовлення за рецептом із реагентами найдешевшої якості. Типово Auctionator спершу бере реагенти з ваших сумок, а це значення їх не враховує.",
    ["CONFIG_CRAFTING_INFO_SHOW_PROFIT"] = "Показувати прибуток від виготовлення з реагентами з аукціону й від торговців",
    ["CONFIG_CRAFTING_INFO_SHOW_PROFIT_TOOLTIP_HEADER"] = "Про виготовлення: прибуток",
    ["CONFIG_CRAFTING_INFO_SHOW_PROFIT_TOOLTIP_TEXT"] = "Увімкніть, щоб бачити прибуток від виготовлення за рецептом, коли ви його переглядаєте.",

    -- Settings: selling
    ["CONFIG_SELLING_CATEGORY"] = "Продаж",
    ["CONFIG_SELLING_TEXT"] = "Налаштування вкладки «Продаж»",
    ["CONFIG_SELLING_SHORTCUTS_CATEGORY"] = "Продаж: клавіші",
    ["CONFIG_SELLING_SHORTCUTS_TEXT"] = "Клавіші й кнопки миші на вкладці «Продаж»",
    ["CONFIG_SELLING_SHOW_BID_PRICE"] = "Показувати поле ставки, коли виставляєте предмет (потрібне перезавантаження)",
    ["CONFIG_SELLING_SHOW_BID_PRICE_TOOLTIP_HEADER"] = "Поле ставки",
    ["CONFIG_SELLING_SHOW_BID_PRICE_TOOLTIP_TEXT"] = "Чи показувати поле ставки, коли ви виставляєте предмет.",
    ["CONFIG_SELLING_CONFIRM_LOW_PRICE"] = "Підтверджувати виставлення за незвично низькою ціною",
    ["CONFIG_SELLING_CONFIRM_LOW_PRICE_TOOLTIP_HEADER"] = "Підтвердження низької ціни",
    ["CONFIG_SELLING_CONFIRM_LOW_PRICE_TOOLTIP_TEXT_2"] = "Перед виставленням предмета за незвично низькою ціною з'являється вікно підтвердження.",
    ["CONFIG_SELLING_SPLIT_PANELS"] = "Показувати поточні й минулі ціни на окремих панелях",
    ["CONFIG_SELLING_SPLIT_PANELS_TOOLTIP_HEADER"] = "Розділені панелі",
    ["CONFIG_SELLING_SPLIT_PANELS_TOOLTIP_TEXT"] = "Зазвичай минулі ціни — на окремій вкладці всередині вкладки «Продаж». Із цим налаштуванням поточні ціни видно завжди, а минулі — на панелі під ними.",
    ["CONFIG_BAG_COLLAPSED"] = "Розділи сумки спочатку згорнуті (потрібне перезавантаження)",
    ["CONFIG_BAG_COLLAPSED_TOOLTIP_HEADER"] = "Згорнуті розділи сумки",
    ["CONFIG_BAG_COLLAPSED_TOOLTIP_TEXT"] = "Якщо ввімкнено, розділи сумки спочатку згорнуті, а не розгорнуті.",
    -- These three follow a drop-down with a click ("Left Click ..."):
    ["CONFIG_SELLING_BAG_SELECT_SHORTCUT"] = "на предметі в сумці переносить його на вкладку «Продаж»",
    ["CONFIG_SELLING_CANCEL_SHORTCUT"] = "на вашому лоті скасовує його",
    ["CONFIG_SELLING_BUY_SHORTCUT"] = "на чужому лоті купує його",
    ["CONFIG_BAG_SHOW_SELLING_BAG"] = "Показувати список предметів у сумці (потрібне перезавантаження)",
    ["CONFIG_BAG_SHOW_SELLING_BAG_TOOLTIP_HEADER"] = "Список предметів у сумці",
    ["CONFIG_BAG_SHOW_SELLING_BAG_TOOLTIP_TEXT"] = "Якщо вимкнено, панель предметів у сумці буде прихована.",
    ["CONFIG_SELLING_ICON_SIZE"] = "Розмір значків сумки (потрібне перезавантаження)",
    ["CONFIG_SELLING_ICON_SIZE_TOOLTIP_HEADER"] = "Розмір значків",
    ["CONFIG_SELLING_ICON_SIZE_TOOLTIP_TEXT"] = "Тут можна зробити значки предметів сумки на вкладці «Продаж» більшими (до 50) або меншими (до 10). Типовий розмір — 42.",
    ["CONFIG_SELLING_AUTO_SELECT_NEXT"] = "Автоматично вибирати наступний предмет у сумці",
    ["CONFIG_SELLING_AUTO_SELECT_NEXT_TOOLTIP_HEADER"] = "Автовибір предмета",
    ["CONFIG_SELLING_AUTO_SELECT_NEXT_TOOLTIP_TEXT"] = "Після виставлення автоматично вибирати наступний предмет у сумці.",
    ["CONFIG_SELLING_AUTO_SELECT_STACK_REMAINDER"] = "Вибирати неповні стоси, коли всі повні вже виставлено.",
    ["CONFIG_SELLING_AUTO_SELECT_STACK_REMAINDER_TOOLTIP_HEADER"] = "Автовибір неповного стосу",
    ["CONFIG_SELLING_AUTO_SELECT_STACK_REMAINDER_TOOLTIP_TEXT"] = "Після виставлення брати неповний стос (якщо він є) як наступний предмет. Нових пошуків це не запускає.",
    ["CONFIG_SELLING_MISSING_FAVOURITES"] = "Завжди показувати предмети з обраного та власних груп, навіть якщо їх немає в сумці.",
    ["CONFIG_SELLING_MISSING_FAVOURITES_TOOLTIP_HEADER"] = "Видно відсутні предмети з обраного та власних груп",
    ["CONFIG_SELLING_MISSING_FAVOURITES_TOOLTIP_TEXT"] = "Показувати предмети з обраного та власних груп у списку сумки, навіть коли самих предметів у сумці немає.",
    ["CONFIG_SELLING_POSSESSED_FAVOURITES_FIRST"] = "В обраному та власних групах ставити першими предмети, що є в сумці",
    ["CONFIG_SELLING_POSSESSED_FAVOURITES_FIRST_TOOLTIP_HEADER"] = "Спершу наявні предмети з обраного та власних груп",
    ["CONFIG_SELLING_POSSESSED_FAVOURITES_FIRST_TOOLTIP_TEXT"] = "В обраному та власних групах предмети, що є у вашій сумці, стоять на початку списку.",
    ["CONFIG_SELLING_RESELECT_ITEM"] = "Знову вибирати останній предмет для виставлення, коли відкривається вкладка «Продаж»",
    ["CONFIG_SELLING_RESELECT_ITEM_TOOLTIP_HEADER"] = "Знову вибирати попередній предмет",
    ["CONFIG_SELLING_RESELECT_ITEM_TOOLTIP_TEXT"] = "Коли ви закриваєте вкладку «Продаж» і відкриваєте її знову, у тому самому сеансі чи пізніше (навіть після виходу з гри), знову вибирається предмет, який ви збиралися виставити.",
    -- These four follow nothing and come before a key-binding button:
    ["CONFIG_SELLING_POST_SHORTCUT"] = "Виставити поточний предмет:",
    ["CUSTOM_KEYBOARD_SHORTCUTS"] = "Власні сполучення клавіш",
    ["CONFIG_SELLING_POST_SHORTCUT_TOOLTIP_TEXT"] = "Клацніть і натисніть клавіші, які хочете використовувати. Це сполучення діє лише на вкладці «Продаж» і не заважає іншим призначенням цих клавіш.",
    ["CONFIG_SELLING_SKIP_SHORTCUT"] = "Пропустити вибраний предмет:",
    ["CONFIG_SELLING_PREV_SHORTCUT"] = "Повернутися до попереднього предмета:",
    ["CONFIG_SAVE_LAST_DURATION_AS_DEFAULT"] = "Зберігати останню використану тривалість як типову",
    ["CONFIG_SAVE_LAST_DURATION_AS_DEFAULT_TOOLTIP_HEADER"] = "Замінювати типову тривалість останньою використаною",
    ["CONFIG_SAVE_LAST_DURATION_AS_DEFAULT_TOOLTIP_TEXT"] = "Замінювати типову тривалість останньою використаною",
    ["CONFIG_BAG"] = "Сумка",

    -- Bag list in the Selling tab
    HIDE = G"ui.hide",
    UNHIDE = G"ui.show",
    ["UNHIDE_ALL"] = "Показати всі",
    ["CONFIRM_UNHIDE_ALL"] = "Справді показати всі сховані предмети?",
    ["UNHIDE_ALL_HIDDEN_ITEMS"] = "Показати всі приховані предмети",
    FAVOURITES = G"ui.favourites",
    ["FAVOURITES_GROUP"] = "Група обраного",

    -- Click choices in the shortcut drop-downs
    LEFT_CLICK = G"ui.left_click",
    RIGHT_CLICK = G"ui.right_click",
    ["ALT_LEFT_CLICK"] = "Alt + лівий клік",
    ["ALT_RIGHT_CLICK"] = "Alt + правий клік",
    ["SHIFT_LEFT_CLICK"] = "Shift + лівий клік",
    ["SHIFT_RIGHT_CLICK"] = "Shift + правий клік",
    DISABLED = G"ui.disabled",

    -- Settings: prices for all items
    ["GEAR_VENDOR_PRICE_MULTIPLIER"] = "Множник ціни торговця для спорядження",
    ["CONFIG_SELLING_DEFAULT_QUANTITY_SUFFIX"] = "0 — максимальна кількість",
    ["CONFIG_SELLING_DEFAULT_QUANTITY_TOOLTIP_HEADER"] = "Типова кількість для виставлення",
    ["CONFIG_SELLING_DEFAULT_QUANTITY_TOOLTIP_TEXT"] = "Тут можна змінити типову кількість, яку виставляєте за раз. Поставте 0, щоб брати найбільшу можливу кількість.",
    ["CONFIG_SELLING_GEAR_VENDOR_PRICE_MULTIPLIER_SUFFIX"] = "0 — без ціни",
    ["CONFIG_SELLING_GEAR_VENDOR_PRICE_MULTIPLIER_TOOLTIP_HEADER"] = "Типова ціна спорядження за ціною торговця",
    ["CONFIG_SELLING_GEAR_VENDOR_PRICE_MULTIPLIER_TOOLTIP_TEXT"] = "Тут можна задати типову ціну спорядження як множник ціни торговця. Це діє для будь-якого спорядження, ціни якого Auctionator не знає. Поставте 0, щоб не задавати ціну.",
    ["CONFIG_MATCHING"] = "Як автоматично вибирати ціну предмета",
    ["CONFIG_MATCHING_ITEM_ID_AND_LEVEL"] = "Той самий рівень і той самий ID предмета чи вихованця",
    ["CONFIG_MATCHING_ITEM_ID"] = "Той самий ID предмета чи вихованця",
    ["CONFIG_MATCHING_ITEM_NAME_AND_LEVEL"] = "Той самий ID, назва й рівень предмета чи вихованця",
    ["CONFIG_MATCHING_ITEM_NAME"] = "Той самий ID і назва предмета чи вихованця (рівень не важливий)",
    ["CONFIG_SELLING_IGNORE_ITEM_SUFFIX"] = "Не зважати на суфікс чи назву предмета, коли шукаються схожі лоти",

    ["DEFAULT_LIST_HEADER"] = "Типовий список покупок",
    ["REAGENT_SEARCH"] = "Пошук реагентів",

    -- Cancelling tab total and Selling tab mini tabs
    ["TOTAL_ON_SALE"] = "Усього на продажу: %s",
    ["TOTAL_PENDING"] = "(%s в очікуванні)",
    ["CURRENT_PRICES"] = "Поточні ціни",
    ["PRICE_HISTORY"] = "Історія цін",
    ["REALM_HISTORY"] = "Історія сервера",
    ["YOUR_HISTORY"] = "Ваша історія",
    ["EXPORT_RESULTS"] = "Експортувати результати",

    -- Crafting window lines (Auctionator adds " " and the price after each)
    ["TO_CRAFT_COLON"] = "Виготовлення:",
    ["CHEAPEST_QUALITY_COST_COLON"] = "Найдешевша якість:",
    ["PROFIT_COLON"] = "Прибуток:",
    ["REAGENTS_VALUE_COLON"] = "Вартість реагентів:",
    ["PROFIT_WARNING_AGE"] = "(дані про ціни старші за 10 днів)",
    ["PROFIT_WARNING_MISSING"] = "(немає даних про ціни)",
    ["PROFIT_WARNING_NOT_EXACT_ITEM"] = "(ціна не саме для цього предмета)",
    ["SEARCH_FOR_QUANTITY"] = "Пошук потрібної кількості",

    -- Classic auction house (stacks, pages)
    ["SCANNING_PAGE_X"] = "Сканую сторінку %s...",
    ["WAITING_AT_MOST_X_LONGER"] = "Чекаю ще щонайбільше %s с...",
    ["STACK_OF"] = "стос по",
    STACK_PRICE = G"auction.stack_price",
    ["MAX_COLON_X"] = "Макс.: %s",
    ["HISTORY"] = "Історія",
    ["CURRENT"] = "Поточні",
    ["SERVER_TOOK_TOO_LONG"] = "Сервер надто довго не відповідав. Можливо, ваша дія не спрацювала.",
    ["STARTING_PRICE_PERCENTAGE_SUFFIX"] = "% від ціни стосу",
    ["STARTING_PRICE_PERCENTAGE"] = "Початкова ціна",
    ["STARTING_PRICE_PERCENTAGE_TOOLTIP_HEADER"] = "Початкова ставка",
    ["STARTING_PRICE_PERCENTAGE_TOOLTIP_TEXT"] = "Цей відсоток задає типову початкову ставку для всіх лотів, які ви виставляєте. Наприклад, 95 при ціні стосу 10s дасть ставку 9s50c.",
    ["STACK_BID_PRICE"] = "Ставка за стос",
    ["ERROR_REOPEN_AUCTION_HOUSE"] = "Не вдалося виконати дію. Закрийте аукціон і відкрийте знову.",
    ["X_STACK_OF_X"] = "%s стос по %s",
    ["X_STACKS_OF_X"] = "Стосів: %s, по %s",
    ["BID_ONLY_AVAILABLE"] = "лише ставка",
    ["BUYING_X_FOR_X"] = "Купую %s за %s",
    ["BRACKETS_X_EACH"] = "(%s за штуку)",
    ["ALREADY_PURCHASED_X"] = "Уже куплено: %s",
    ["PRICE_INCREASE_WARNING_2"] = "Ціна зросла на %s. Продовжити?",
    ["CONTINUE"] = "Продовжити",
    ["STOP"] = "Зупинити",
    ["PURCHASED_X_XX"] = "Куплено %s x%s",
    ["DEFAULT_STACK_SIZES"] = "Типові розміри стосів",
    ["CONFIG_SELLING_TBC_ALL_ITEMS"] = "Типові налаштування виставлення для всіх предметів.",
    ["CONFIG_RESET_STACK_SIZE_MEMORY"] = "Забути запам'ятані розміри стосів",
    ["CHAIN_BUY"] = "Купувати поспіль",
    ["CHAIN_BUY_TOOLTIP_HEADER"] = "Кілька покупок поспіль",
    ["CHAIN_BUY_TOOLTIP_TEXT"] = "Коли покупки за поточною ціною й розміром стосу закінчено, вибирати наступну ціну й розмір стосу.",
    ["LOAD_HIGHER_PRICES"] = "Завантажити вищі ціни",
    ["STOP_LOADING_NOW"] = "Зупинити завантаження",
    ["LOAD_MORE_RESULTS"] = "Завантажити ще",
    ["CONFIG_SHOPPING_ALWAYS_LOAD_MORE"] = "Завжди завантажувати всі доступні результати.",
    ["CONFIG_SHOPPING_ALWAYS_LOAD_MORE_TOOLTIP_HEADER"] = "Завжди завантажувати все",
    ["CONFIG_SHOPPING_ALWAYS_LOAD_MORE_TOOLTIP_TEXT"] = "Щоб пошук ішов швидше, деякі сторінки пропускаються, а найнижча ціна все одно точна. Це налаштування не пропускає жодної сторінки, тож видно всі можливі результати.",
    ["CONFIG_SELLING_GREY_POST_BUTTON"] = "Робити кнопку виставлення сірою (вимкненою), коли виставлення може не вдатися",
    ["CONFIG_SELLING_GREY_POST_BUTTON_TOOLTIP_HEADER"] = "Сіра кнопка виставлення",
    ["CONFIG_SELLING_GREY_POST_BUTTON_TOOLTIP_TEXT"] = "Коли виставлення може не вдатися, кнопка стає сірою (вимкненою). Вимкніть це налаштування, щоб не чекати, доки кнопка ввімкнеться, і пробувати виставити раніше.",

    ["CONFIG_SHOPPING_ALWAYS_CONFIRM_QUANTITY"] = "Завжди вводити кількість двічі, купуючи товари на вкладці «Покупки»",
    ["CONFIG_SHOPPING_ALWAYS_CONFIRM_QUANTITY_TOOLTIP_HEADER"] = "Підтверджувати кількість щоразу",
    ["CONFIG_SHOPPING_ALWAYS_CONFIRM_QUANTITY_TOOLTIP_TEXT"] = "Типово кількість підтверджують один раз. З цим налаштуванням її треба ввести вдруге, щоб підтвердити покупку.",

    -- Bag item menu: %s is a group name ("Обране")
    ["ADD_TO_X"] = "Додати до «%s»",
    ["REMOVE_FROM_X"] = "Прибрати з «%s»",

    -- Info tab: donating
    ["CONTRIBUTE_HEADER"] = "|cff04cca4Розробку веде працьовита людина (без ШІ)|r",
    ["CONTRIBUTE_TOOLTIP_HEADER"] = "Про пожертви",
    ["CONTRIBUTE_TOOLTIP_TEXT"] = "На розробку й підтримку Auctionator витрачено десятки тисяч годин. Пожертва — один зі способів підтримувати аддон і надалі.",
    ["DONATE"] = "Підтримати",
}

-- Texts Auctionator makes in its code from its own locale texts. Words.lua makes their English the same
-- way, from Auctionator's AUCTIONATOR_L_* globals.
ns.UA_MADE = {
    -- Cancelling tab total: TOTAL_ON_SALE .. " " .. TOTAL_PENDING
    { join = { "TOTAL_ON_SALE", "TOTAL_PENDING" }, uk = "Усього на продажу: %s (%s в очікуванні)" },
    -- Forever's duration buttons: AUCTION_DURATION_12 with "12" made "2", AUCTION_DURATION_24 with "24" made "8"
    { key = "AUCTION_DURATION_12", from = "12", to = "2", uk = "2 год" },
    { key = "AUCTION_DURATION_24", from = "24", to = "8", uk = "8 год" },
}

-- Column headers only: a shorter word where the results table's column is narrow (docs/LESSONS.md, lesson 5).
-- Rows.lua puts it on a column header; the same English anywhere else (a search range, a tooltip line,
-- the column menu) keeps its ns.UA text. By locale key; Words.lua reads the English from Auctionator's
-- globals. tools/test_auc_headers.py checks every column header's length against its English.
ns.UA_HEAD = {
    ITEM_LEVEL_COLUMN = G"game.item_level_short",   -- Buy and Selling lists
    ITEM_LEVEL = G"game.item_level_short",          -- Shopping list (a 70 px column)
}

-- Bag group titles on the Selling tab: the game's item class names, by their Enum.ItemClass name.
-- Words.lua reads the English from GetItemClassInfo at run time.
ns.UA_CLASS = {
    Weapon = G"gear.weapon",
    Armor = G"gear.armor",
    Container = G"item.bag",
    Consumable = G"item.consumable",
    Tradegoods = G"vendor.trade_goods",
    Projectile = G"gear.projectile",
    Quiver = G"item.quiver",
    Recipe = G"item.recipe",
    Reagent = G"item.reagent_class",
    Miscellaneous = G"item.misc",
    Questitem = G"game.quest",
    Key = G"item.key",
}
