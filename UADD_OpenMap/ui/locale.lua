-- UADD: Ukrainian for every text OpenMap looks up in its locale table (L["..."]).
-- Keys are OpenMap's English texts, whole. This file is data only: it changes nothing by itself.
-- MAP holds texts OpenMap looks up when it shows them. LOADTIME holds texts OpenMap reads once,
-- while its files load (tab names, key bindings, the townsfolk filters, sketch tools and colours,
-- the report popup, every Credits line), so a swap made later never reaches the copy it keeps.
-- MONTHS is not from L: it is OpenMap's own month list, used only when the game has none; the
-- Ukrainian is in the genitive, because it sits in a date ("13 листопада 2026").
--
-- Left out on purpose (tools/test_openmap_strings.py lists them too):
--   "OpenMap"     the addon's name.
--   "%d %s %s"    a date (day, month, year): no words, and the order is already right.
--   Text OpenMap writes without L: the changelog (about 62 items) and the diagnostic lines of
--   /openmap debug and bench (about 25). They stay English.
-- Place names inside a sentence ("Searing Gorge", "Mount Hyjal", "Dire Maul - East") stay English
-- here: names come from UALL. "Dire Maul - East" is typed in a slash command, so it must stay.
-- UADD_OpenMap/Locale.lua puts these in OpenMap's L; Words.lua uses them for texts read earlier.
-- Over the 300-line budget on purpose: it is one flat table of 552 texts.
local _, ns = ...
-- G"id" takes a word from the shared base, UADD/glossary/*.lua (see docs/GLOSSARY.md).
local G = UADD and UADD.Glossary and UADD.Glossary.Text or function() return nil end

local MAP = {
    -- API.lua, Init.lua
    ["Other addons"] = "Інші аддони",
    ["Enable OpenMap"] = "Увімкнути OpenMap",
    ["Open OpenMap's settings"] = "Відкрити налаштування OpenMap",
    ["That isn't available with the Gamepad UI yet."] = "З інтерфейсом геймпада це поки недоступно.",
    ["The map is off."] = "Карту вимкнено.",
    ["Turning OpenMap off takes a reload."] = "Щоб вимкнути OpenMap, треба перезавантажити інтерфейс.",
    ["Takes effect after a /reload."] = "Діє після /reload.",

    -- Bench.lua, Debug.lua (tester texts)
    ["(vsync and the frame cap are off while it runs, and back on after.)"] =
        "(вертикальна синхронізація й обмеження кадрів вимкнені під час тесту, а потім знову ввімкнуться.)",
    ["Bench done: the results are in the box (and kept for the next /reload)."] =
        "Тест завершено: результати в полі (і збережуться до наступного /reload).",
    ["Bench stopped (the map closed, changed, or combat started)."] =
        "Тест зупинено (карту закрито чи змінено або почався бій).",
    ["Bench stopped."] = "Тест зупинено.",
    ["Bench: about three minutes. Leave the mouse alone; /openmap bench again stops it."] =
        "Тест: близько трьох хвилин. Не чіпайте мишу; /openmap bench ще раз зупинить його.",
    ["Not in combat."] = "Не в бою.",
    ["Open the world map over a place where it's slow (a zone or continent), then /openmap bench."] =
        "Відкрийте карту світу там, де вона гальмує (зона чи континент), потім /openmap bench.",
    ["OpenMap bench: Ctrl-A, Ctrl-C to copy"] = "Тест OpenMap: Ctrl-A, Ctrl-C, щоб скопіювати",
    ["%d highlights recorded: saved (OpenMapDB: worldmap, highlights) once you /reload or log out."] =
        "Записано підсвічувань: %d. Збережуться (OpenMapDB: worldmap, highlights), щойно ви зробите /reload або вийдете з гри.",
    ["addons' memory: %s"] = "пам'ять аддонів: %s",
    ["counting ..."] = "рахую ...",
    ["garbage a second: %.1f MB in all, of which %s"] = "сміття за секунду: усього %.1f МБ, з них %s",
    ["Lua memory %.0f MB (%+.1f MB a minute), map pins %d (most: %s %d)"] =
        "Пам'ять Lua %.0f МБ (%+.1f МБ за хвилину), позначок на карті: %d (найбільше: %s %d)",
    ["none to speak of"] = "майже нічого",
    ["Nothing to record here: this client's map has no world of its own."] =
        "Тут нічого записувати: карта цього клієнта не має власного світу.",
    ["OpenMap: zoom update %.1f ms, close-up %.1f ms (worst %.1f)"] =
        "OpenMap: оновлення наближення %.1f мс, зблизька %.1f мс (найгірше %.1f)",
    ["Recording the zones' highlights: a few seconds."] = "Записую підсвічування зон: кілька секунд.",
    ["zone art loaded %d of %d, %d regions placed live, %d to load"] =
        "зображень зон завантажено %d з %d, областей розміщено наживо: %d, ще завантажити: %d",
    ["zoom %.1f, %d textures drawn, %d minimap tiles"] =
        "наближення %.1f, текстур намальовано: %d, фрагментів мінікарти: %d",

    -- Close.lua (up close)
    ["At the closest zoom, how much of the game's minimap is mixed in for detail. The painted map always leads."] =
        "Скільки мінікарти гри домішується для деталей на найбільшому наближенні. Намальована карта завжди головна.",
    ["At the closest zoom, mix in the game's minimap for detail (tree cover, rocks, buildings). Off, the painted map is all you see, however far you zoom."] =
        "На найбільшому наближенні домішувати мінікарту гри для деталей (дерева, скелі, будівлі). Вимкнено: видно лише намальовану карту, хоч як близько наближайте.",
    ["Caves and dungeon entrances"] = "Печери та входи до підземель",
    ["How far in (in times the whole-world view) the minimap's detail starts to mix in: lower comes in sooner, higher later; at 1x it's there from the whole world. Further out than its own tiles can be drawn, smaller copies of it show."] =
        "З якого наближення (у разах від вигляду всього світу) домішуються деталі мінікарти: менше — раніше, більше — пізніше; при 1x вони є вже на всьому світі. Далі, ніж можна намалювати її власні фрагменти, видно її зменшені копії.",
    ["Land no zone map covers (west of Searing Gorge, Mount Hyjal ...) shows the game's minimap of it, tinted like the zones around it, instead of blank paper."] =
        "Землі, яких не покриває карта жодної зони (на захід від Searing Gorge, Mount Hyjal ...), показують мінікарту гри, відтінену як сусідні зони, замість порожнього паперу.",
    ["Minimap detail from zoom"] = "Деталі мінікарти з наближення",
    ["Minimap detail, most opacity"] = "Деталі мінікарти: найбільша непрозорість",
    ["Minimap in the gaps (experimental)"] = "Мінікарта в прогалинах (експеримент)",
    ["Soften and add paper grain"] = "Пом'якшити й додати зернистість",
    ["The minimap's detail over the six major cities' own maps, at half strength at most so the city's plan leads. Off: their own maps alone."] =
        "Деталі мінікарти поверх власних карт шести великих міст, щонайбільше вполовину сили, щоб план міста лишався головним. Вимкнено: лише їхні власні карти.",
    ["The most the minimap's detail ever shows, at any zoom: zooming in past where the painted map has any detail left, it takes over toward this."] =
        "Найбільша видимість деталей мінікарти на будь-якому наближенні: коли ви наближаєте далі, ніж є деталі намальованої карти, мінікарта поступово доходить до цього значення.",
    ["Zoom right in on a cave, mine or crypt, or a dungeon's entrance area, and its map surfaces from underground: Blizzard's own where it drew one, else the game's minimap of it. Over one, the zoom goes on past the deepest zoom."] =
        "Наблизьте печеру, шахту, склеп чи місце біля входу до підземелля, і з-під землі з'явиться його карта: карта Blizzard, якщо вона є, інакше мінікарта гри. Над ним наближення йде далі за найбільше.",
    ["Zoomed in, the painted map runs out of pixels: this softens it and lays paper grain over it. The softening rests while the map moves, so the map is sharp while you zoom or pan and softens a moment after it stops. Off (the default): always sharp."] =
        "Зблизька намальованій карті бракує пікселів: це пом'якшує її й накладає зернистість паперу. Поки карта рухається, пом'якшення чекає, тож під час наближення чи руху карта чітка, а пом'якшується за мить після зупинки. Вимкнено (типово): карта завжди чітка.",
    ["Minimap detail"] = "Деталі мінікарти",
    ["Minimap detail in major cities"] = "Деталі мінікарти у великих містах",
    ["Minimap strength"] = "Сила мінікарти",
    ["Up close"] = "Зблизька",

    -- Compat.lua
    ["%s is also changing the world map. Turn off its world map options (or the addon) so the two don't fight."] =
        "%s теж змінює карту світу. Вимкніть у ньому налаштування карти світу (або сам аддон), щоб вони не заважали одне одному.",
    ["Leatrix Maps: turn off %s there; OpenMap does the same for its map."] =
        "Leatrix Maps: вимкніть там %s; OpenMap робить те саме для своєї карти.",

    -- Dungeons.lua
    ["(placed: click to move it)"] = "(розміщено: клацніть, щоб перемістити)",
    ["%d bosses"] = "Босів: %d",
    ["|cffffd100Right-click|r or |cffffd100Esc|r to go back to the world map"] =
        "|cffffd100Правий клік|r або |cffffd100Esc|r: назад до карти світу",
    ["|cffffd100Step 1 of 2:|r draw where it's wrong (right-drag pans)"] =
        "|cffffd100Крок 1 з 2:|r позначте, де помилка (перетягування правою кнопкою рухає карту)",
    ["A dungeon's map has a Quests tab: with Questie, the quests for it that you can take, marked done or in your log; with Dungeon Journal or NeedRoll, a button that opens them there."] =
        "На карті підземелля є вкладка «Завдання»: з Questie — завдання звідти, які ви можете взяти, з позначками «виконано» чи «у журналі»; з Журналом підземель або NeedRoll — кнопка, що відкриває їх там.",
    ["A dungeon's map lists its bosses, in the game's order, and pins where they are."] =
        "Карта підземелля показує його босів у порядку гри й позначає, де вони.",
    ["Back to %s"] = "Назад: %s",
    ["Back to the world map, where you were"] = "Назад до карти світу, де ви були",
    ["Back to the world map, where you were (or right-click the map, or scroll out)"] =
        "Назад до карти світу, де ви були (або правий клік по карті, або віддаліть коліщатком)",
    ["Boss places saved in OpenMapDB (worldmap, bossPlaced) once you /reload or log out; tools/map-dungeons/bosses.py --import adds them to OpenMap's data."] =
        "Місця босів збережуться в OpenMapDB (worldmap, bossPlaced), щойно ви зробите /reload або вийдете з гри; tools/map-dungeons/bosses.py --import додає їх до даних OpenMap.",
    ["Bosses, quests and loot are in the tabs at the map's edge"] = "Боси, завдання й здобич: у вкладках біля краю карти",
    ["Click to pick one"] = "Клацніть, щоб вибрати",
    ["Click to pick one and open its map"] = "Клацніть, щоб вибрати й відкрити карту",
    ["Click to see it in NeedRoll"] = "Клацніть, щоб побачити в NeedRoll",
    ["Click to see what's inside"] = "Клацніть, щоб побачити, що всередині",
    ["Click to see what's inside (no map of it yet)"] = "Клацніть, щоб побачити, що всередині (карти ще немає)",
    ["click where it is; right-click skips"] = "клацніть, де він; правий клік — пропустити",
    ["Clicking a dungeon entrance opens"] = "Клік по входу до підземелля відкриває",
    ["Draw on this dungeon's map (right-drag pans)"] =
        "Малювати на карті цього підземелля (перетягування правою кнопкою рухає карту)",
    ["Dungeon Journal"] = G"game.dungeon_journal",
    ["Dungeon Journal has no page for this dungeon."] = "У Журналі підземель немає сторінки цього підземелля.",
    ["Dungeon Journal has this dungeon's quests: where each one starts, what it asks and what it gives."] =
        "Завдання цього підземелля є в Журналі підземель: де кожне починається, що треба зробити й що дають.",
    ["Dungeon level ranges"] = "Рівні підземель",
    ["Dungeon maps from the minimap"] = "Карти підземель із мінікарти",
    ["Dungeon maps: bosses"] = "Карти підземель: боси",
    ["Dungeon maps: quests"] = "Карти підземель: завдання",
    ["Dungeon quests from"] = "Завдання підземель з",
    ["Each dungeon entrance's level range under its icon, coloured for your level."] =
        "Рівні кожного входу до підземелля під його значком, колір — за вашим рівнем.",
    ["Every boss gone through: Done, or Undo"] = "Усіх босів пройдено: «Готово» або «Відмінити»",
    ["Floor %d"] = G"map.floor",
    ["Floors"] = "Поверхи",
    ["For loot, we recommend |cffffd100NeedRoll|r, by mikebvs: what every boss drops, what you've collected, and a wishlist, made for WoW Forever."] =
        "Для здобичі радимо |cffffd100NeedRoll|r від mikebvs: що падає з кожного боса, що у вас уже є, і список бажаного. Зроблено для WoW Forever.",
    ["from %d"] = "від %d",
    ["Get it from CurseForge (click, then Ctrl-C):"] = "Візьміть на CurseForge (клацніть, потім Ctrl-C):",
    ["In your quest log"] = "У журналі завдань",
    ["Its Dungeon Journal page"] = "Його сторінку в Журналі підземель",
    ["Its map"] = "Його карту",
    ["Loot"] = G"game.loot",
    ["Map by %s"] = "Карта: %s",
    ["NeedRoll lists dungeon quests too: open it and pick this dungeon."] =
        "NeedRoll теж показує завдання підземель: відкрийте його й виберіть це підземелля.",
    ["NeedRoll lists this dungeon's loot: what every boss drops, what you've collected, and a wishlist."] =
        "NeedRoll показує здобич цього підземелля: що падає з кожного боса, що у вас уже є, і список бажаного.",
    ["Dungeon maps inside dungeons"] = "Карти підземель усередині підземель",
    ["Open a dungeon's map first: /openmap bosses places its bosses on it."] =
        "Спершу відкрийте карту підземелля: /openmap bosses розміщує на ній його босів.",
    ["OpenMap's maps of dungeons and raids: Blizzard's where the client has one, the ones drawn for WoW Forever's where it has none. Off: inside a dungeon the map stays the world map, and an entrance's card opens over it instead."] =
        "Карти підземель і рейдів від OpenMap: карти Blizzard, де вони є в клієнті, а де немає — намальовані для WoW Forever. Вимкнено: у підземеллі лишається карта світу, а поверх неї натомість відкривається картка входу.",
    ["Opening the map in a dungeon shows OpenMap's map of it. To turn that off: OpenMap's menu > Dungeons > Dungeon maps inside dungeons."] =
        "Якщо відкрити карту в підземеллі, буде карта цього підземелля від OpenMap. Щоб це вимкнути: меню OpenMap > Підземелля > Карти підземель усередині підземель.",
    ["Opening the map inside a dungeon or raid shows that dungeon's map. Off: the map opens there as the game's own would, and a dungeon's map still opens from its entrance on the world map. With Dungeon Journal installed, its map is left to it inside a dungeon it has a page for."] =
        "Якщо відкрити карту в підземеллі чи рейді, буде карта цього підземелля. Вимкнено: там відкривається звичайна карта гри, а карта підземелля так само відкривається з його входу на карті світу. Якщо встановлено Журнал підземель, то в підземеллі, для якого в ньому є сторінка, карту показує він.",
    ["Or right-click the map, or press Escape"] = "Або правий клік по карті, або Escape",
    ["Placed by you (/openmap bosses)"] = "Розміщено вами (/openmap bosses)",
    ["Questie lists no quests for it that you can take."] = "У Questie немає завдань звідси, які ви можете взяти.",
    ["Saved too (OpenMapDB: worldmap, entrances) once you /reload or log out."] =
        "Теж збережеться (OpenMapDB: worldmap, entrances), щойно ви зробите /reload або вийдете з гри.",
    ["See the Loot tab for loot"] = "Здобич — у вкладці «Здобич»",
    ["Shift-click: where it is, on NeedRoll's map"] = "Shift-клік: де це, на карті NeedRoll",
    ["Skip"] = "Пропустити",
    ["Stand in the portal and say which: /openmap entrance Dire Maul - East (the name as OpenMap lists it)."] =
        "Станьте в портал і вкажіть який: /openmap entrance Dire Maul - East (назва, як її показує OpenMap).",
    ["The first installed"] = "Перший установлений",
    ["There's no map of this dungeon to show here."] = "Тут немає карти цього підземелля.",
    ["This dungeon's loot is in the game's Adventure Guide."] = "Здобич цього підземелля є в довіднику пригод гри.",
    ["Where OpenMap has one, a dungeon's map built from the game's own minimap pictures (what the minimap draws inside) instead of its drawn map. Dungeons with no other map use it anyway."] =
        "Де OpenMap має таку, карта підземелля, складена із зображень мінікарти гри (те, що мінікарта малює всередині), замість намальованої карти. Підземелля без іншої карти й так її використовують.",
    ["Where the Quests tab's quests come from, when you have more than one of these addons. The first installed: Questie, then Dungeon Journal, then NeedRoll."] =
        "Звідки беруться завдання у вкладці «Завдання», коли у вас кілька таких аддонів. Перший установлений: Questie, потім Журнал підземель, потім NeedRoll.",
    ["With a gamepad, that map opens once you're out of combat."] = "З геймпадом ця карта відкриється, щойно ви вийдете з бою.",
    ["With Dungeon Journal installed, an entrance can open that dungeon's page in it instead of its map (its map still opens where Dungeon Journal has no page for it)."] =
        "Якщо встановлено Журнал підземель, вхід може відкривати сторінку підземелля в ньому замість карти (карта все одно відкриється, якщо в Журналі підземель немає сторінки).",
    ["With Questie, Dungeon Journal or NeedRoll, this dungeon's quests are here."] =
        "З Questie, Журналом підземель або NeedRoll тут будуть завдання цього підземелля.",
    ["WoW Forever has no map of this dungeon yet."] = "У WoW Forever ще немає карти цього підземелля.",
    ["Back"] = G"ui.back",
    ["Bosses"] = G"game.bosses",
    ["Cancel"] = G"ui.cancel",
    ["Click to open its map"] = "Клацніть, щоб відкрити карту",
    ["Click to see loot in NeedRoll"] = "Клацніть, щоб побачити здобич у NeedRoll",
    ["Completed"] = G"quest.state_complete",
    ["done"] = "виконано",
    ["Dungeon"] = G"game.dungeon",
    ["Dungeon maps"] = "Карти підземель",
    ["in your log"] = "у журналі",
    ["Next"] = "Далі",
    ["Open in Dungeon Journal"] = "Відкрити в Журналі підземель",
    ["Open NeedRoll"] = "Відкрити NeedRoll",
    ["Reading Questie's quests..."] = "Читаю завдання з Questie...",
    ["The game lists no bosses for it."] = "Гра не знає тут босів.",
    ["Where you are isn't on the world map here."] = "Вашого місця тут немає на карті світу.",
    ["Quests"] = G"game.quest",
    ["The quest log can't be opened or closed in combat."] = "У бою не можна відкрити чи закрити журнал завдань.",
    ["Raid"] = G"game.raid",
    ["Undo"] = "Відмінити",
    ["Done"] = G"ui.done",
    ["Clear"] = G"ui.clear",

    -- Extras.lua
    ["A bar along the map's foot: your position, and the zone and position under the cursor."] =
        "Смуга внизу карти: ваші координати, а також зона й координати під курсором.",
    ["A map addon brings its own HereBeDragons (%s), which OpenMap doesn't know: its pins keep the game's own placement."] =
        "Аддон карти має власну HereBeDragons (%s), якої OpenMap не знає: його позначки лишаються там, де їх ставить гра.",
    ["Hovering a zone shows its level range, coloured for your level, and if you know Fishing, the skill at which every cast there lands."] =
        "Якщо навести на зону, видно її рівні (колір — за вашим рівнем), а якщо ви знаєте рибальство, то й навичку, з якою там ловиться з кожного закидання.",
    ["How much the map fades while you walk or ride, so you can see where you're going. 0% keeps it solid. It never fades while the mouse is over it."] =
        "Наскільки карта стає прозорою, поки ви йдете чи їдете, щоб бачити дорогу. 0% лишає її непрозорою. Коли миша над картою, вона не блякне.",
    ["Other addons' icons rest while zooming"] = "Значки інших аддонів зникають під час наближення",
    ["Questie's icons (and other addons' map icons) are hidden while the map zooms and back as soon as it stops. Each one is laid out again on every frame of a zoom, and with Questie's hundreds that costs a lot of frame rate."] =
        "Значки Questie (і значки інших аддонів на карті) ховаються, поки карта наближається, і повертаються, щойно вона зупиниться. Кожен значок розміщується заново в кожному кадрі наближення, а із сотнями значків Questie це сильно знижує частоту кадрів.",
    ["The frame rate at most while the map is open (0: off). A big map draws many layers over the whole screen every frame; 60 halves the graphics card's work at 120 fps, for a smooth enough map. The game's own frame rate setting comes back as the map closes."] =
        "Найбільша частота кадрів, поки карта відкрита (0 — вимкнено). Велика карта щокадру малює багато шарів на весь екран; 60 удвічі зменшує роботу відеокарти при 120 кадрах/с, а карта лишається досить плавною. Коли карта закривається, повертається налаштування частоти кадрів самої гри.",
    ["Coordinates"] = G"map.coordinates",
    ["Fade while moving"] = "Прозорість у русі",
    ["Map frame rate cap"] = "Обмеження кадрів карти",
    ["Zone levels"] = G"map.zone_levels",

    -- Flights.lua
    ["%d stops"] = "пересадок: %d",
    ["1 stop"] = "1 пересадка",
    ["about %s"] = "близько %s",
    ["Click, then click another flight master: the route and its time"] =
        "Клацніть, потім клацніть іншого майстра польотів: маршрут і час",
    ["Click: show the route"] = "Клік: показати маршрут",
    ["From %s: about %s"] = "Звідки: %s, близько %s",
    ["Learned"] = "Вивчено",
    ["Learned flight paths forgotten for this character: talk to a flight master to learn the ones you have again."] =
        "Вивчені шляхи польотів цього персонажа забуто: поговоріть із майстром польотів, щоб знову вивчити ті, що у вас є.",
    ["needs flight masters you haven't learned"] = "потрібні невивчені майстри польотів",
    ["No flight route from %s to %s."] = "Немає маршруту польоту: %s — %s.",
    ["Not learned"] = "Не вивчено",

    -- Friends.lua
    ["Friend"] = "Друг",
    ["Friends and guild"] = "Друзі й гільдія",
    ["Not now"] = "Не зараз",
    ["Only your guild and friends, never from a dungeon, raid or battleground. OpenMap's menu: More, Sharing."] =
        "Лише вашій гільдії й друзям, ніколи з підземелля, рейду чи поля бою. Меню OpenMap: «Більше», «Поширення».",
    ["Share where I am"] = "Показувати, де я",
    ["Updated %d s ago"] = "Оновлено %d с тому",
    ["Your friends and guild members who use OpenMap can show on your map as a dot where they stand. Share where you are, so they see you on theirs?"] =
        "Ваші друзі й члени гільдії з OpenMap можуть бути на вашій карті точкою там, де вони стоять. Показувати їм, де ви, щоб вони бачили вас на своїй?",
    ["Your friends who are online: a badge on the zone each is in, with who's there (as the friends list shows it), or a class-coloured dot where they stand for those who use OpenMap and share where they are."] =
        "Ваші друзі в мережі: значок на зоні, де кожен із них, і хто там (як у списку друзів), або точка кольору класу там, де стоять ті, хто має OpenMap і показує, де він.",
    ["Your guild members who are online: a badge on the zone each is in, with who's there (as the guild roster shows it), or a class-coloured dot where they stand for those who use OpenMap and share where they are."] =
        "Члени вашої гільдії в мережі: значок на зоні, де кожен із них, і хто там (як у списку гільдії), або точка кольору класу там, де стоять ті, хто має OpenMap і показує, де він.",
    ["Your guild, and your friends who use OpenMap, see you as a dot where you stand on their map, sent every few seconds while you move. Never from inside a dungeon, raid or battleground. Off, they see only your zone, as the friends list and guild roster show it."] =
        "Ваша гільдія й друзі з OpenMap бачать вас точкою на своїй карті там, де ви стоїте; поки ви рухаєтеся, це надсилається кожні кілька секунд. Ніколи з підземелля, рейду чи поля бою. Вимкнено: вони бачать лише вашу зону, як у списку друзів і гільдії.",
    ["... and %d more"] = "... і ще %d",
    ["Friends on the map"] = "Друзі на карті",
    ["Guild"] = "Гільдія",
    ["Guild members on the map"] = "Члени гільдії на карті",
    ["Share where you are"] = "Показувати, де ви",

    -- Launcher.lua
    ["A button on the minimap's edge that opens the map and its menu (right-click: this window). Drag it round the minimap. OpenMap is in the minimap's AddOns list too."] =
        "Кнопка на краю мінікарти, що відкриває карту та її меню (правий клік — це вікно). Перетягуйте її довкола мінікарти. OpenMap є й у списку аддонів на мінікарті.",
    ["Click: the map and its menu"] = "Клік: карта та її меню",
    ["Drag: move it round the minimap"] = "Перетягнути: перемістити довкола мінікарти",
    ["Right-click: the options window"] = "Правий клік: вікно налаштувань",
    ["The OpenMap button and your favourites on the map. Off, the menu opens with /openmap, the minimap button or the minimap's AddOns list."] =
        "Кнопка OpenMap і ваші улюблені на карті. Вимкнено: меню відкривається через /openmap, кнопку на мінікарті або список аддонів на мінікарті.",
    ["Minimap button"] = "Кнопка на мінікарті",
    ["OpenMap button on the map"] = "Кнопка OpenMap на карті",

    -- Nav.lua
    ["Choose one behavior. Center on player: always open on you. Center on player, keep zoom: open on you, at the zoom you closed the map at. Center on your zone: open on the whole zone you're in, wherever you are in it. Always remember: restore your previous position and zoom, even after changing zones. Remember while visible: restore only if your current location is inside the previous view, even across zone boundaries. Otherwise, open on you. Maps opened for a quest still show the quest's area."] =
        "Виберіть одну поведінку. «Центр на гравці»: завжди відкривати на вас. «Центр на гравці, зберегти наближення»: відкривати на вас із тим наближенням, з яким ви закрили карту. «Центр на вашій зоні»: відкривати всю зону, де ви є, хоч би де ви в ній були. «Завжди пам'ятати»: відновлювати попереднє місце й наближення, навіть після зміни зони. «Пам'ятати, поки видно»: відновлювати, лише якщо ви зараз у межах попереднього вигляду, навіть через межі зон. Інакше відкривати на вас. Карти, відкриті для завдання, і далі показують його місце.",
    ["Class-coloured dots for your group anywhere on the stitched map."] =
        "Точки кольору класу для вашої групи будь-де на суцільній карті.",
    ["Click to stop following it"] = "Клацніть, щоб не стежити",
    ["Continent"] = G"map.continent",
    ["Find a place"] = "Знайти місце",
    ["Flight master"] = "Майстер польотів",
    ["Somewhere in %s"] = "Десь у зоні %s",
    ["Waypoint"] = G"map.waypoint",
    ["When reopening the map"] = "Коли карта відкривається знову",
    ["You aren't on the world map here (an instance or a place it doesn't cover)."] =
        "Тут вас немає на карті світу (підземелля чи місце поза нею).",
    ["Zone"] = G"game.zone",
    ["Always remember"] = "Завжди пам'ятати",
    ["Center on player"] = "Центр на гравці",
    ["Center on player, keep zoom"] = "Центр на гравці, зберегти наближення",
    ["Center on your zone"] = "Центр на вашій зоні",
    ["Group"] = G"game.group",
    ["Party and raid members"] = "Члени групи й рейду",
    ["Remember while visible"] = "Пам'ятати, поки видно",
    ["Shift-click: share in chat"] = "Shift-клік: поділитися в чаті",

    -- News.lua
    ["%d changes, newest first."] = "Змін: %d, нові вгорі.",
    ["%d versions"] = "Версій: %d",
    ["click, then Ctrl-C"] = "клацніть, потім Ctrl-C",
    ["Close"] = G"ui.close",
    ["Coming in the next version."] = "Буде в наступній версії.",
    ["Newer"] = "Новіші",
    ["Older"] = "Старіші",
    ["OpenMap is made by |cffe6b85cJi Unit (RP-PvP Horde)|r, and it's open source: join in on GitHub"] =
        "OpenMap створив |cffe6b85cJi Unit (RP-PvP Horde)|r, і це відкритий код: долучайтеся на GitHub",
    ["OpenMap %s is out (you have %s). Update through CurseForge."] =
        "Вийшла OpenMap %s (у вас %s). Оновіть через CurseForge.",
    ["Say when OpenMap has an update"] = "Повідомляти, коли в OpenMap є оновлення",
    ["When a friend, guild member or group member has a newer OpenMap, a line in chat says so, once a session. Your version goes only in messages OpenMap already sends them. Off, nothing is said and your version isn't sent."] =
        "Коли в друга, члена гільдії чи групи новіша OpenMap, у чаті з'явиться рядок про це, раз за сеанс. Вашу версію бачать лише в повідомленнях, які OpenMap їм і так надсилає. Вимкнено: нічого не повідомляється, і ваша версія не надсилається.",
    ["The game's map"] = "Карта гри",
    ["Inside dungeons, open the game's own map instead of OpenMap's dungeon map. Turn it back on any time: OpenMap's menu > Dungeons > Dungeon maps inside dungeons."] =
        "У підземеллях відкривати звичайну карту гри замість карти підземелля від OpenMap. Знову ввімкнути можна будь-коли: меню OpenMap > Підземелля > Карти підземель усередині підземель.",
    ["OpenMap's dungeon maps are off inside dungeons. To turn them back on: OpenMap's menu > Dungeons > Dungeon maps inside dungeons."] =
        "Карти підземель від OpenMap усередині підземель вимкнено. Щоб ввімкнути їх знову: меню OpenMap > Підземелля > Карти підземель усередині підземель.",
    ["place names and quest areas on the controller map, and it reopening as you set"] =
        "назви місць і ділянки завдань на карті для контролера, і повторне відкриття карти, як ви налаштували",
    ["the quest level on OpenMap's quest icons"] = "рівень завдання на значках завдань OpenMap",
    ["Released %s."] = "Випуск: %s.",
    ["Thank you to everyone who has made OpenMap better."] = "Дякуємо всім, хто зробив OpenMap кращим.",
    ["Upcoming"] = "Незабаром",
    ["Updated to %s: see What's new in the OpenMap menu."] = "Оновлено до %s: дивіться «Що нового» в меню OpenMap.",
    ["Versions: |cffffffff%d|r"] = "Версій: |cffffffff%d|r",
    ["What's new in OpenMap"] = "Що нового в OpenMap",
    ["Credits"] = "Подяки",
    ["Unreleased"] = "Ще не вийшло",

    -- Paint.lua (map notes)
    ["(no text)"] = "(без тексту)",
    ["%d notes"] = "Нотаток: %d",
    ["|cffffd100Drag|r paint an area   |cffffd100Click|r a note at a point   |cffffd100Shift-drag|r add to the last   |cffffd100Click a note|r edit   |cffffd100Right-drag|r pan   |cffffd100Ctrl-Z|r undo"] =
        "|cffffd100Тягніть|r зафарбувати   |cffffd100Клік|r нотатка в точці   |cffffd100Shift-тягніть|r додати до останньої   |cffffd100Клік по нотатці|r змінити   |cffffd100Тягніть правою|r рухати   |cffffd100Ctrl-Z|r відмінити",
    ["A bigger brush"] = "Більший пензель",
    ["A smaller brush"] = "Менший пензель",
    ["All the notes as text, to copy and paste where they're needed."] =
        "Усі нотатки текстом, щоб скопіювати й вставити, куди треба.",
    ["Brush %d"] = "Пензель %d",
    ["Click to go there, right-click to edit"] = "Клацніть, щоб перейти; правий клік — змінити",
    ["Enter saves, Escape cancels"] = "Enter — зберегти, Escape — скасувати",
    ["Every note: click one to go there."] = "Усі нотатки: клацніть одну, щоб перейти до неї.",
    ["Export"] = "Експорт",
    ["List"] = "Список",
    ["Map notes work on the world, continent and zone maps."] = "Нотатки працюють на картах світу, континентів і зон.",
    ["Map notes: Ctrl-C to copy them all, then paste them where they're needed"] =
        "Нотатки на карті: Ctrl-C, щоб скопіювати всі, потім вставте, куди треба",
    ["New note"] = "Нова нотатка",
    ["No notes yet: paint an area on the map."] = "Нотаток ще немає: зафарбуйте місце на карті.",
    ["Note"] = "Нотатка",
    ["Notes (%d)"] = "Нотатки (%d)",
    ["Open the world map first."] = "Спершу відкрийте карту світу.",
    ["Remove every note (click twice)"] = "Прибрати всі нотатки (клацніть двічі)",
    ["Save"] = G"ui.save",
    ["Take back the last note (Ctrl-Z)"] = "Відмінити останню нотатку (Ctrl-Z)",
    ["They're also saved in WTF\\Account\\<account>\\SavedVariables\\OpenMap.lua once you /reload or log out."] =
        "Вони також зберігаються у WTF\\Account\\<account>\\SavedVariables\\OpenMap.lua, щойно ви зробите /reload або вийдете з гри.",
    ["What the next note is: paint its area (or click) and say what's there."] =
        "Якою буде наступна нотатка: зафарбуйте її місце (або клацніть) і напишіть, що там.",
    ["Sure?"] = "Точно?",

    -- Panel.lua (the OpenMap menu and the map's buttons)
    ["(the stars in the OpenMap menu put buttons here)"] = "(зірочки в меню OpenMap додають сюди кнопки)",
    ["A star puts that action or setting on the map as a button of its own."] =
        "Зірочка ставить цю дію чи налаштування на карту окремою кнопкою.",
    ["Auto"] = "Авто",
    ["Buttons as edge tabs"] = "Кнопки як вкладки на краю",
    ["Caves underground"] = "Печери під землею",
    ["Click the map..."] = "Клацніть по карті...",
    ["Click, then click the map to add a map pin, with a note if you like (Ctrl-click the map does it any time). Right-click: stop following the waypoint."] =
        "Клацніть, потім клацніть по карті, щоб поставити позначку, за бажання з нотаткою (Ctrl-клік по карті робить це будь-коли). Правий клік: не стежити за точкою маршруту.",
    ["Darken unexplored areas"] = "Затемнити недосліджені місця",
    ["Debug overlay (FPS)"] = "Налагоджувальний шар (FPS)",
    ["Detail"] = "Деталі",
    ["Drag it anywhere round the map's edge."] = "Перетягніть її будь-куди по краю карти.",
    ["Drag to change width and height. The settings scroll when needed."] =
        "Перетягніть, щоб змінити ширину й висоту. Налаштування прокручуються, коли треба.",
    ["Draw on the map in ink: lines, arrows, rings and raid marks, kept for you. A map pin's card can draw on that pin."] =
        "Малюйте на карті чорнилом: лінії, стрілки, кола й рейдові мітки, і вони збережуться. З картки позначки можна малювати на цій позначці.",
    ["Dungeon bosses"] = "Боси підземель",
    ["Dungeon quests"] = "Завдання підземель",
    ["Dungeons"] = G"game.dungeon",
    ["Entrances open Dungeon Journal"] = "Входи відкривають Журнал підземель",
    ["Every map pin: go to one, share them, or add pins from a code someone gave you. Right-click: hide your pins on the map (this goes grey) or show them again."] =
        "Усі позначки: перейдіть до однієї, поділіться ними або додайте позначки з коду, який вам дали. Правий клік: сховати ваші позначки на карті (кнопка посіріє) або знову показати.",
    ["Every slider back to how OpenMap comes: the deepest zoom, the minimap's detail and opacity, and those in Options."] =
        "Усі повзунки до початкових значень OpenMap: найбільше наближення, деталі й непрозорість мінікарти та ті, що в налаштуваннях.",
    ["Fade icons while zooming"] = "Пригасити значки під час наближення",
    ["Favourites are tabs at the window's edge, above the OpenMap tab."] =
        "Улюблені — вкладки на краю вікна, над вкладкою OpenMap.",
    ["Favourites sit in a row beside the OpenMap button, in the map's bottom-left corner."] =
        "Улюблені стоять у ряд біля кнопки OpenMap, у нижньому лівому куті карти.",
    ["Glide to where you are. Middle-click the map to center on you at the current zoom."] =
        "Плавно перейти туди, де ви. Клік середньою кнопкою по карті ставить вас у центр на поточному наближенні.",
    ["Hide unexplored areas"] = "Сховати недосліджені місця",
    ["How far in the minimap's detail starts to mix in: lower comes in sooner, higher later."] =
        "З якого наближення домішуються деталі мінікарти: менше — раніше, більше — пізніше.",
    ["Icons from"] = "Значки з",
    ["Improves performance"] = "Покращує швидкодію",
    ["Level ranges"] = "Діапазони рівнів",
    ["Map notes"] = G"map.notes",
    ["Minimap"] = G"game.minimap",
    ["Minimap detail from"] = "Деталі мінікарти з",
    ["Minimap in the gaps"] = "Мінікарта в прогалинах",
    ["Minimap opacity"] = "Непрозорість мінікарти",
    ["Moving about"] = "Пересування",
    ["Off: click to turn it on"] = "Вимкнено: клацніть, щоб увімкнути",
    ["On: click to turn it off"] = "Увімкнено: клацніть, щоб вимкнути",
    ["Only for this character"] = "Лише для цього персонажа",
    ["OpenMap is in beta: draw on the map where something looks wrong (a dungeon's map too) and tell us about it."] =
        "OpenMap у бета-версії: позначте на карті, де щось не так (і на карті підземелля теж), і розкажіть нам.",
    ["OpenMap's icons on the map at this size: dungeons, flight masters, boats, townsfolk, your pins. Questie's icons have their own size, in Questie's options."] =
        "Значки OpenMap на карті цього розміру: підземелля, майстри польотів, кораблі, міські служби, ваші позначки. Значки Questie мають свій розмір у налаштуваннях Questie.",
    ["Places"] = "Місця",
    ["Put this on the map as a button"] = "Поставити на карту кнопкою",
    ["Questie icons"] = "Значки Questie",
    ["Reopen map (choose one)"] = "Повторне відкриття (виберіть одне)",
    ["Resize the OpenMap menu"] = "Змінити розмір меню OpenMap",
    ["Sharing"] = "Поширення",
    ["Shift-right-click: take it off the map"] = "Shift-правий клік: прибрати з карти",
    ["Show or hide the quest log beside the map, for more room for the map."] =
        "Показати чи сховати журнал завдань біля карти, щоб карті було більше місця.",
    ["Soften and paper grain"] = "Пом'якшення й зернистість",
    ["Take this button off the map"] = "Прибрати цю кнопку з карти",
    ["The map"] = "Карта",
    ["The most the minimap's detail ever shows, at any zoom."] =
        "Найбільша видимість деталей мінікарти на будь-якому наближенні.",
    ["The OpenMap button is hidden. Its menu opens with /openmap, the minimap button or the minimap's AddOns list."] =
        "Кнопку OpenMap сховано. Її меню відкривається через /openmap, кнопку на мінікарті або список аддонів на мінікарті.",
    ["The zoom the icons for places show from: dungeons, boats, zeppelins and flight masters. 1x: from the whole world; higher: only further in. Auto: each from its own zoom. Townsfolk never show further out than their own; your pins, drawings and party always show."] =
        "З якого наближення видно значки місць: підземелля, кораблі, цепеліни й майстри польотів. 1x — з усього світу; більше — лише ближче. «Авто» — кожен зі свого наближення. Міські служби ніколи не видно далі, ніж їхнє власне; ваші позначки, малюнки й групу видно завжди.",
    ["This version's changes (it glows after an update until you've looked)."] =
        "Зміни цієї версії (після оновлення світиться, доки ви не подивитеся).",
    ["Tools"] = "Інструменти",
    ["Townsfolk"] = G"npc.townsfolk",
    ["Townsfolk (needs Questie)"] = "Міські служби (потрібен Questie)",
    ["With the controller, the D-pad's right opens the quest log."] = "З контролером журнал завдань відкриває хрестовина вправо.",
    ["Your guild and friends see you"] = "Гільдія й друзі бачать вас",
    ["Zone highlight on hover"] = "Підсвічування зони під курсором",
    ["Boat and zeppelin routes"] = "Маршрути кораблів і цепелінів",
    ["Boats"] = G"map.boats",
    ["Chat over the full-screen map"] = "Чат поверх карти на весь екран",
    ["Colour matching"] = "Узгодження кольорів",
    ["Ctrl-click drops a pin"] = "Ctrl-клік ставить позначку",
    ["Darkening"] = "Затемнення",
    ["Deepest zoom"] = G"map.deepest_zoom",
    ["Defaults"] = G"ui.defaults",
    ["Dungeons and raids"] = "Підземелля й рейди",
    ["Flight masters"] = G"map.flight_masters",
    ["Fold your buttons away"] = "Згорнути ваші кнопки",
    ["Follow new pins"] = "Стежити за новими позначками",
    ["Full-screen map fills the width"] = "Карта на весь екран — на всю ширину",
    ["Hide world markers in instances"] = "Сховати мітки світу в підземеллях",
    ["How far in the map zooms, in times the whole-world view (cities go half as far again). Past about 48 the art is only enlarged."] =
        "Наскільки карта наближається, у разах від вигляду всього світу (міста — ще в півтора раза). Після приблизно 48 зображення лише збільшується.",
    ["Icon size"] = "Розмір значків",
    ["Load the zone in view"] = "Завантажувати видиму зону",
    ["Map brightness"] = "Яскравість карти",
    ["Map size"] = "Розмір карти",
    ["Only places you've found"] = "Лише знайдені місця",
    ["Pins others share with you"] = "Позначки, якими діляться з вами",
    ["Quests from every zone"] = "Завдання з усіх зон",
    ["Reset size and place"] = "Скинути розмір і місце",
    ["Responsive ocean & border"] = "Гнучкий океан і рамка",
    ["Search, find me, map pins, the quest log, report a problem, options, and what the map shows."] =
        "Пошук, «Знайти мене», позначки, журнал завдань, звіт про проблему, налаштування й те, що показує карта.",
    ["Send new pins to group"] = "Надсилати нові позначки групі",
    ["Auto-add group's pins"] = "Одразу додавати позначки групи",
    ["Take colour out"] = "Знебарвити",
    ["The stars in the OpenMap menu put buttons here; Shift-right-click one to take it off."] =
        "Зірочки в меню OpenMap додають сюди кнопки; Shift-правий клік по кнопці прибирає її.",
    ["Unexplored areas"] = G"map.unexplored",
    ["What's new"] = "Що нового",
    ["Your arrow"] = "Ваша стрілка",
    ["Your buttons"] = "Ваші кнопки",
    ["Your drawings"] = "Ваші малюнки",
    ["Zeppelins"] = G"map.zeppelins",
    ["Report a problem"] = "Повідомити про проблему",

    -- Pins.lua
    ["%d drawn"] = "намальовано: %d",
    ["A pin you drop becomes the waypoint, which other addons route to (Shortest Path Forever). Off, the waypoint is left as it is: the pin's Follow sets it."] =
        "Позначка, яку ви ставите, стає точкою маршруту, до якої інші аддони прокладають шлях (Shortest Path Forever). Вимкнено: точка маршруту лишається як є, її задає «Стежити» на картці позначки.",
    ["A pin you drop goes to your party or raid once its card is closed (those with OpenMap are asked whether to add it)."] =
        "Позначка, яку ви ставите, надсилається вашій групі чи рейду, щойно закриється її картка (тих, у кого є OpenMap, запитають, чи додати).",
    ["%s shared %d map pin(s) with you:"] = "%s ділиться з вами позначками (%d):",
    ["A code to copy and paste anywhere: another player adds it with their OpenMap (Pins, Import)."] =
        "Код, щоб скопіювати й вставити будь-де: інший гравець додасть його у своєму OpenMap («Позначки», «Імпорт»).",
    ["Add the pins"] = "Додати позначки",
    ["Added %d map pin(s) from %s."] = "Додано позначок: %d (від %s).",
    ["Added %d map pin(s) from the code."] = "Додано позначок із коду: %d.",
    ["As a code"] = "Кодом",
    ["Blizzard's waypoint and its arrow on it (and TomTom's, if you use it)."] =
        "Точка маршруту Blizzard і стрілка до неї (і TomTom, якщо ви ним користуєтеся).",
    ["Click to edit its note, follow, share or delete it"] = "Клацніть, щоб змінити нотатку, стежити, поділитися чи видалити",
    ["Click to go there, right-click to open its card"] = "Клацніть, щоб перейти; правий клік — відкрити картку",
    ["Code"] = "Код",
    ["Colour"] = "Колір",
    ["Ctrl-click on the map drops a pin. Turn it off if another addon drops its own pin on Ctrl-click (Map Pin Enhanced): the menu's Drop a pin still works."] =
        "Ctrl-клік по карті ставить позначку. Вимкніть, якщо інший аддон ставить свою позначку на Ctrl-клік (Map Pin Enhanced): «Поставити позначку» в меню однаково працює.",
    ["Delete all %d map pins?"] = "Видалити всі позначки (%d)?",
    ["Delete every map pin (you're asked first). One at a time: Alt-click it."] =
        "Видалити всі позначки (спершу вас запитають). По одній: Alt-клік.",
    ["Draw more"] = "Домалювати",
    ["Draw on the map with the pen, attached to this pin: deleting the pin takes its drawing too."] =
        "Малюйте на карті олівцем, прив'язано до цієї позначки: якщо видалити позначку, малюнок зникне теж.",
    ["Drawing"] = "Малюнок",
    ["drawing"] = "малюнок",
    ["Drawing: the tray is below"] = "Малювання: панель нижче",
    ["Every pin as a code to copy and paste anywhere."] = "Усі позначки кодом, щоб скопіювати й вставити будь-де.",
    ["Every pin at once: as a code to copy, to your party or raid, or to your guild."] =
        "Усі позначки одразу: кодом, вашій групі чи рейду або вашій гільдії.",
    ["Every pin to your guild (those with OpenMap are asked whether to add them)."] =
        "Усі позначки вашій гільдії (тих, у кого є OpenMap, запитають, чи додати їх).",
    ["Every pin to your party or raid (those with OpenMap are asked whether to add them)."] =
        "Усі позначки вашій групі чи рейду (тих, у кого є OpenMap, запитають, чи додати їх).",
    ["followed"] = "відстежується",
    ["Followed (the waypoint)"] = "Відстежується (точка маршруту)",
    ["Import"] = G"ui.import",
    ["Keep the pin as it is (Enter, or the X, too)"] = "Лишити позначку як є (також Enter або X)",
    ["Map pins"] = "Позначки на карті",
    ["Map pins (%d)"] = "Позначки (%d)",
    ["Map pins your group, guild or a player shares with you: you're asked whether to add them. Off, they're ignored."] =
        "Позначки, якими з вами ділиться група, гільдія чи гравець: вас запитають, чи додати їх. Вимкнено: їх ігнорують.",
    ["Map pins your party or raid shares with you are added at once, without asking."] =
        "Позначки, якими з вами ділиться група чи рейд, додаються одразу, без запитання.",
    ["Map pins: Ctrl-C to copy, then paste them anywhere (another player's OpenMap: Pins, Import)."] =
        "Позначки: Ctrl-C, щоб скопіювати, потім вставте будь-де (в OpenMap іншого гравця: «Позначки», «Імпорт»).",
    ["No pins yet: Ctrl-click the map, or the menu's Drop a pin."] =
        "Позначок ще немає: Ctrl-клік по карті або «Поставити позначку» в меню.",
    ["Nothing drawn on it yet"] = "Тут ще нічого не намальовано",
    ["Paste a code of map pins here (Ctrl-V), then Add the pins."] =
        "Вставте сюди код позначок (Ctrl-V), потім «Додати позначки».",
    ["Paste a code of map pins someone gave you."] = "Вставте код позначок, який вам дали.",
    ["Purple"] = "Фіолетовий",
    ["Share all"] = "Поділитися всіма",
    ["Share:"] = "Поділитися:",
    ["Sharing %d map pin(s) with %s (players with OpenMap are asked whether to add them)."] =
        "Надсилаю позначки (%d): %s (гравців з OpenMap запитають, чи додати їх).",
    ["Stop drawing"] = "Припинити малювання",
    ["Target"] = "Ціль",
    ["That isn't a code of map pins (it starts %s)."] = "Це не код позначок (він починається з %s).",
    ["To your group"] = "Вашій групі",
    ["To your guild"] = "Вашій гільдії",
    ["Whispered to your target (if they have OpenMap, they're asked whether to add it)."] =
        "Шепотом вашій цілі (якщо в неї є OpenMap, її запитають, чи додати).",
    ["Your guild (those with OpenMap are asked whether to add it)."] =
        "Ваша гільдія (тих, у кого є OpenMap, запитають, чи додати).",
    ["Your party or raid (those with OpenMap are asked whether to add it)."] =
        "Ваша група чи рейд (тих, у кого є OpenMap, запитають, чи додати).",
    ["Alt-click: delete it"] = "Alt-клік: видалити",
    ["Stop following"] = "Не стежити",
    ["Follow"] = "Стежити",
    ["Shared by %s"] = "Поділився: %s",
    ["Draw on the map"] = "Малювати на карті",
    ["Map pin"] = G"map.pin",

    -- Quests.lua, Report.lua
    ["Click: track this quest and zoom to it"] = "Клік: стежити за завданням і наблизити до нього",
    ["Click: track this quest, zoom to it and show it in the quest log"] =
        "Клік: стежити за завданням, наблизити до нього й показати в журналі завдань",
    ["|cffffd100Step 1 of 2:|r draw where it's wrong (if it's a spot), then Next"] =
        "|cffffd100Крок 1 з 2:|r позначте, де помилка (якщо це конкретне місце), потім «Далі»",
    ["1. Open OpenMap's report page on GitHub (Ctrl-C, then paste in your browser):"] =
        "1. Відкрийте сторінку звітів OpenMap на GitHub (Ctrl-C, потім вставте в браузер):",
    ["2. Paste this code into the report, with a screenshot if you can:"] =
        "2. Вставте цей код у звіт, а якщо можете — і знімок екрана:",
    ["On to saying what's wrong (Escape: no report)"] = "Далі: опишіть, що не так (Escape — без звіту)",
    ["Thanks! The code says where you were looking (and what you drew, if anything), so we can see what you saw."] =
        "Дякуємо! Код показує, куди ви дивилися (і що намалювали, якщо щось), тож ми побачимо те саме, що й ви.",

    -- Routes.lua, Stitch.lua
    ["Neutral"] = "Нейтральний",
    ["Boat"] = "Корабель",
    ["Zeppelin"] = "Цепелін",
    ["Airship"] = "Дирижабль",
    ["Click to go to the other end"] = "Клацніть, щоб перейти до іншого кінця",
    ["To"] = "Куди:",

    -- Sketch.lua (the quill)
    ["|cffffd100Drag|r to draw   |cffffd100Right-drag|r to pan   |cffffd100Ctrl-Z|r undo   |cffffd100Esc|r done"] =
        "|cffffd100Тягніть|r малювати   |cffffd100Тягніть правою|r рухати   |cffffd100Ctrl-Z|r відмінити   |cffffd100Esc|r готово",
    ["Broad"] = "Широка",
    ["Drawing on the pin: %s"] = "Малюнок на позначці: %s",
    ["Drawing on this pin"] = "Малюнок на цій позначці",
    ["Drawings: %d"] = "Малюнків: %d",
    ["Fine"] = "Тонка",
    ["Ink"] = "Чорнило",
    ["Medium"] = "Середня",
    ["Take back the last drawing (Ctrl-Z)"] = "Відмінити останній малюнок (Ctrl-Z)",
    ["Take off every drawing (this pin's, when drawing on one): click twice"] =
        "Прибрати всі малюнки (цієї позначки, якщо малюєте на ній): клацніть двічі",
    ["That's a lot of drawing: take some off (Undo, the eraser, Clear) before drawing more."] =
        "Малюнків забагато: приберіть частину («Відмінити», гумка, «Очистити»), перш ніж малювати далі.",
    ["The quill draws on the world, continent and zone maps."] = "Перо малює на картах світу, континентів і зон.",
    ["Tool"] = "Інструмент",
    ["What you've drawn with the quill (the OpenMap menu's Quill), on the map."] =
        "Те, що ви намалювали пером («Перо» в меню OpenMap), на карті.",
    ["Width"] = "Товщина",
    ["Finish drawing: it's kept (Escape too)"] = "Закінчити малювання: його збережено (також Escape)",

    -- Townsfolk.lua, Welcome.lua, Window.lua
    ["World map: townsfolk and rare mobs come from Questie's database. Install and enable Questie to see them."] =
        "Карта світу: міські служби й рідкісні монстри беруться з бази даних Questie. Установіть і ввімкніть Questie, щоб їх бачити.",
    ["World map: townsfolk and rares need Questie's database, which isn't available."] =
        "Карта світу: для міських служб і рідкісних монстрів потрібна база даних Questie, а вона недоступна.",
    ["Choose your map"] = "Виберіть карту",
    ["Classic"] = G"map.classic_map",
    ["Show the whole map, with dungeon entrances, flight masters, zone levels and favourite buttons."] =
        "Показувати всю карту із входами до підземель, майстрами польотів, рівнями зон і улюбленими кнопками.",
    ["Unexplored areas hidden. No dungeon or flight master icons and no zone levels."] =
        "Недосліджені місця сховано. Без значків підземель і майстрів польотів і без рівнів зон.",
    ["You can change any of it later in OpenMap's menu (its button on the map, or /openmap)."] =
        "Усе це можна змінити пізніше в меню OpenMap (його кнопка на карті або /openmap).",
    ["ClassicUI Forever's World map option is on. It lays out the world map window itself, which is known to cause problems with OpenMap: the window can't be resized or moved, and in combat parts of the map can go missing.\n\nTurn that option off? Your interface will reload."] =
        "У ClassicUI Forever увімкнено параметр «World map». Він сам розставляє вікно карти світу, а це, як відомо, заважає OpenMap: вікно не можна ні пересунути, ні змінити його розмір, а в бою частини карти можуть зникати.\n\nВимкнути цей параметр? Інтерфейс перезавантажиться.",
    ["Drag to move the map"] = "Перетягніть, щоб перемістити карту",
    ["Drag to resize the map"] = "Перетягніть, щоб змінити розмір карти",
    ["Enhance QoL: if its Mover > World Map is on, turn it off. It and OpenMap both size the map, and the map's scale goes wrong."] =
        "Enhance QoL: якщо в ньому ввімкнено Mover > World Map, вимкніть це. І він, і OpenMap змінюють розмір карти, і її масштаб збивається.",
    ["Kept as it is. You can turn it off any time in ClassicUI Forever's options (World map)."] =
        "Залишено як є. Його можна будь-коли вимкнути в налаштуваннях ClassicUI Forever («World map»).",
    ["Keeps the chat windows on show over the map while it's full screen, to keep talking while you look."] =
        "Лишає вікна чату поверх карти на весь екран, щоб ви могли спілкуватися, поки дивитеся.",
    ["MapUtils also changes the world map's zoom and scale: with it and OpenMap both on, the map and Blizzard's quest areas can jump while zooming. Turn one of them off if you see that."] =
        "MapUtils теж змінює наближення й масштаб карти світу: коли ввімкнено і його, і OpenMap, карта й місця завдань Blizzard можуть стрибати під час наближення. Якщо ви таке бачите, вимкніть один із них.",
    ["Scales the whole windowed map. Drag either of its bottom corners to change its width and height, and its title bar to move it."] =
        "Масштабує всю карту у вікні. Тягніть будь-який нижній кут, щоб змінити ширину й висоту, а заголовок — щоб перемістити.",
    ["When maximized, the map takes the screen's whole width instead of keeping Blizzard's shape with bars at the sides."] =
        "Розгорнута карта займає всю ширину екрана, а не зберігає форму Blizzard зі смугами з боків.",

    -- WorldMap.lua (options)
    ["Areas you haven't explored yet: shown as they are, darkened and cooled (and a zone you haven't found at all darkened from every zoom, the continents' too), or hidden like Blizzard's own map (blank parchment until you get there)."] =
        "Місця, які ви ще не дослідили: показано як є, затемнено й охолоджено (а зону, яку ви ще зовсім не знайшли, затемнено на будь-якому наближенні, як і на континентах), або сховано, як на карті Blizzard (порожній пергамент, доки ви туди не дістанетеся).",
    ["Areas you haven't explored yet: shown as they are, or hidden like Blizzard's own map (blank parchment until you get there)."] =
        "Місця, які ви ще не дослідили: показано як є або сховано, як на карті Blizzard (порожній пергамент, доки ви туди не дістанетеся).",
    ["Blizzard's glow on the zone you're pointing at."] = "Підсвічування Blizzard на зоні, на яку ви наводите.",
    ["Boat docks (click one: the other end), and boats' routes when routes are shown."] =
        "Причали кораблів (клік — інший кінець) і маршрути кораблів, коли маршрути показано.",
    ["Brightness of the entire OpenMap map, including explored areas and the sea. Player and quest icons stay bright. 100% restores the original brightness."] =
        "Яскравість усієї карти OpenMap, разом із дослідженими місцями й морем. Значки гравця й завдань лишаються яскравими. 100% повертає початкову яскравість.",
    ["Darken"] = "Затемнити",
    ["Darkening colour"] = "Колір затемнення",
    ["Default colour"] = "Типовий колір",
    ["Dungeon and raid entrances, with their levels (click one: its map)."] =
        "Входи до підземель і рейдів з їхніми рівнями (клік — карта).",
    ["Dungeons, boats and zeppelins only once you've explored where they are, and flight masters only once you've learned them."] =
        "Підземелля, кораблі й цепеліни — лише коли ви дослідили їхнє місце, а майстри польотів — лише коли ви їх вивчили.",
    ["Every slider here (and the OpenMap menu's) back to how OpenMap comes."] =
        "Усі повзунки тут (і в меню OpenMap) до початкових значень OpenMap.",
    ["Filled gaps"] = "Заповнені прогалини",
    ["Highlight the zone under the cursor"] = "Підсвічувати зону під курсором",
    ["How dark unexplored areas are when they're darkened."] = "Наскільки темні недосліджені місця, коли їх затемнено.",
    ["How far each zone's borders move toward a shared palette, so mountains and borders hand over smoothly between zones. Zone interiors keep their own colours."] =
        "Наскільки межі кожної зони наближаються до спільної палітри, щоб гори й межі плавно переходили між зонами. Усередині зони зберігають свої кольори.",
    ["Icons"] = G"ui.icons",
    ["Icons from zoom"] = "Значки з наближення",
    ["In dungeons, raids and battlegrounds, temporarily hide OpenMap's friends, guild, transport and world quest markers. Party and raid members and other addons' maps and markers stay visible. Your marker settings are kept."] =
        "У підземеллях, рейдах і на полях бою тимчасово ховати мітки OpenMap для друзів, гільдії, транспорту й завдань на карті світу. Члени групи й рейду, а також карти й мітки інших аддонів лишаються видимими. Ваші налаштування міток зберігаються.",
    ["Land no zone map covers, painted by hand in the zone maps' style from Blizzard's own art (by Santiago Reyes, used with his permission). Off: blank map paper there."] =
        "Землі, яких не покриває карта жодної зони, намальовані вручну в стилі карт зон на основі зображень Blizzard (автор Santiago Reyes, з його дозволу). Вимкнено: там порожній папір карти.",
    ["Once the map stops moving, it loads the zone or continent you're looking at: its quest areas, coordinates and name, and other addons' icons for it (Questie's, GatherLite's ...). Off, the map keeps the zone it opened on."] =
        "Коли карта зупиняється, вона завантажує зону чи континент, на які ви дивитеся: місця завдань, координати, назву й значки інших аддонів (Questie, GatherLite ...). Вимкнено: карта лишається на зоні, з якою відкрилася.",
    ["OpenMap's icons on the map (dungeons, flight masters, boats, townsfolk, your pins ...) at this size. Questie's icons have their own size, in Questie's options."] =
        "Значки OpenMap на карті (підземелля, майстри польотів, кораблі, міські служби, ваші позначки ...) цього розміру. Значки Questie мають свій розмір у налаштуваннях Questie.",
    ["OpenMap's map with the controller (test)"] = "Карта OpenMap з контролером (тест)",
    ["OpenMap's map with the Gamepad UI (test)"] = "Карта OpenMap з інтерфейсом геймпада (тест)",
    ["Put every slider back to its default?"] = "Повернути всі повзунки до типових значень?",
    ["Reset sliders to defaults"] = "Скинути повзунки",
    ["The colour unexplored areas are darkened with."] = "Колір, яким затемнено недосліджені місця.",
    ["The Gamepad UI is off: OpenMap's map is back."] = "Інтерфейс геймпада вимкнено: карта OpenMap повернулася.",
    ["The Gamepad UI is on, so OpenMap leaves the world map to Blizzard: with OpenMap's map the game blocks the controller's buttons (B to close the map). Turn the Gamepad UI off for OpenMap's map."] =
        "Інтерфейс геймпада ввімкнено, тому OpenMap лишає карту світу Blizzard: з картою OpenMap гра блокує кнопки контролера (B, щоб закрити карту). Вимкніть інтерфейс геймпада, щоб мати карту OpenMap.",
    ["The quests in your log on the map from every zone and at any zoom. Blizzard's map shows a zone's quests only once you've zoomed in on that zone."] =
        "Завдання з вашого журналу на карті з усіх зон і на будь-якому наближенні. Карта Blizzard показує завдання зони, лише коли ви наблизили цю зону.",
    ["The zoom (in times the whole-world view) the map's icons for places show from: dungeons, boats, zeppelins and flight masters (1: from the whole world; higher: only further in). 0 is Auto: each from its own zoom, as it comes. Townsfolk never show further out than their own; your pins, drawings and party always show."] =
        "Наближення (у разах від вигляду всього світу), з якого видно значки місць: підземелля, кораблі, цепеліни й майстри польотів (1 — з усього світу; більше — лише ближче). 0 — «Авто»: кожен зі свого наближення, як задумано. Міські служби ніколи не видно далі, ніж їхнє власне; ваші позначки, малюнки й групу видно завжди.",
    ["This version's changes, and the versions before."] = "Зміни цієї версії й попередніх.",
    ["With the game's Gamepad UI on, OpenMap draws its map over Blizzard's and leaves Blizzard's map as it is, so the controller's buttons keep working. Off: Blizzard's map while the Gamepad UI is on. Still being tried out: if something doesn't work, turn this off and /reload."] =
        "Коли в грі ввімкнено інтерфейс геймпада, OpenMap малює свою карту поверх карти Blizzard і лишає ту як є, тож кнопки контролера працюють. Вимкнено: карта Blizzard, поки ввімкнено інтерфейс геймпада. Ще випробовується: якщо щось не працює, вимкніть це й зробіть /reload.",
    ["With the game's Gamepad UI on, OpenMap's map instead of Blizzard's. The controller's B and full-screen buttons on the map are OpenMap's then, so the game doesn't block them. Still being tried out: if the game blocks something, turn this off and /reload."] =
        "Коли в грі ввімкнено інтерфейс геймпада, карта OpenMap замість карти Blizzard. Кнопка B і кнопка на весь екран тоді належать OpenMap, тож гра їх не блокує. Ще випробовується: якщо гра щось блокує, вимкніть це й зробіть /reload.",
    ["World map: Blizzard's map isn't the expected kind; the seamless map is off."] =
        "Карта світу: карта Blizzard не того типу, що очікувалося; суцільну карту вимкнено.",
    ["World map: Blizzard's map layers aren't the expected ones; the stitched art may cover some map icons."] =
        "Карта світу: шари карти Blizzard не ті, що очікувалися; суцільне зображення може закрити деякі значки.",
    ["Your own arrow on the world map. Off, you find your way old-school, by the land around you; your party still shows, and so does the minimap."] =
        "Ваша стрілка на карті світу. Вимкнено: шукайте дорогу по-старому, за місцевістю навколо; вашу групу все одно видно, і мінікарту теж.",
    ["Zeppelin towers (click one: the other end), and zeppelins' routes when routes are shown."] =
        "Вежі цепелінів (клік — інший кінець) і маршрути цепелінів, коли маршрути показано.",
    ["Zoomed right out, the world map lies on an ocean that fills the window, in a border: the sea, compass roses, sea creatures, ships and the frame round it painted by Santiago Reyes (used with his permission), laid out for the window's shape, wide or tall. The game's own map stays in the middle. Off: no border."] =
        "Коли карту віддалено повністю, карта світу лежить на океані, що заповнює вікно, у рамці: море, рози вітрів, морські створіння, кораблі й рамку довкола намалював Santiago Reyes (з його дозволу), і все розміщено під форму вікна, широку чи високу. Карта самої гри лишається посередині. Вимкнено: без рамки.",
    ["Hide"] = G"ui.hide",
    ["Show"] = G"ui.show",
    ["The Gamepad UI is on: /reload so OpenMap leaves the world map to Blizzard (until then the game may block closing the map with the controller)."] =
        "Інтерфейс геймпада ввімкнено: зробіть /reload, щоб OpenMap лишив карту світу Blizzard (доти гра може не давати закрити карту контролером).",
}

-- Read once while OpenMap loads. "Delete", "Pins", "Quest log", the colours and some townsfolk
-- filters are also looked up later; they live here so there is one copy.
local LOADTIME = {
    -- Panel tabs and key bindings
    ["On the map"] = "На карті",
    ["Look"] = "Вигляд",
    ["More"] = "Більше",
    ["Find me"] = G"map.find_me",
    ["Drop a pin"] = G"map.drop_pin",
    ["Pins"] = G"map.pins",
    ["Quill"] = G"map.quill",
    ["Quest log"] = "Журнал завдань",
    ["The map's menu"] = "Меню карти",
    -- Paint note kinds, pin popup buttons
    ["Fix this"] = "Виправити",
    ["Look into this"] = "Перевірити",
    ["Idea"] = "Ідея",
    ["Delete"] = G"ui.delete",
    ["Add them"] = "Додати",
    ["Ignore"] = "Ігнорувати",
    -- Townsfolk filters
    ["Spirit healers"] = "Цілителі душ",
    ["Rare mobs"] = "Рідкісні монстри",
    ["Vendors"] = G"npc.vendors",
    ["Repair"] = G"vendor.repair",
    ["Innkeepers"] = "Корчмарі",
    ["Bankers"] = "Банкіри",
    ["Mailboxes"] = "Поштові скриньки",
    ["Auctioneers"] = "Аукціоністи",
    ["Stable masters"] = "Конюхи",
    ["Class trainers"] = "Учителі класів",
    ["Profession trainers"] = "Учителі професій",
    ["Rare Elite"] = G"map.filter_rare_elite",
    ["Rare"] = "Рідкісний",
    -- Colours (sketch and pins)
    ["Gold"] = "Золотий",
    ["Red"] = "Червоний",
    ["Green"] = "Зелений",
    ["Blue"] = "Синій",
    ["Black"] = "Чорний",
    ["White"] = "Білий",
    -- Pin sharing targets, as in "Надсилаю позначки (3): ваша група"
    ["your group"] = "ваша група",
    ["your guild"] = "ваша гільдія",
    -- Report popup
    ["Report, step 2 of 2:"] = "Звіт, крок 2 з 2:",
    ["what's wrong?"] = "що не так?",
    ["(the map, the menu, a setting ... anything: a sentence is plenty)"] =
        "(карта, меню, налаштування ... будь-що: досить одного речення)",
    -- Sketch tools
    ["Pen"] = "Олівець",
    ["Draw freely."] = "Малюйте вільно.",
    ["Line"] = "Лінія",
    ["A straight line: drag from one end to the other."] = "Пряма лінія: тягніть від одного кінця до іншого.",
    ["Arrow"] = G"map.arrow",
    ["An arrow: drag from its tail to where it points."] = "Стрілка: тягніть від хвоста туди, куди вона вказує.",
    ["Circle"] = "Коло",
    ["A circle: drag from its middle out."] = "Коло: тягніть від центру назовні.",
    ["Mark"] = "Мітка",
    ["A raid mark: click to set it down. Right-click this button for another mark."] =
        "Рейдова мітка: клацніть, щоб поставити. Правий клік по цій кнопці — інша мітка.",
    ["Erase"] = "Стерти",
    ["Click a drawing to take it off."] = "Клацніть малюнок, щоб прибрати його.",
    -- Credits.lua: headings, then what each person did (lower case: it follows a name)
    ["Made by"] = "Автор",
    ["Programming"] = "Програмування",
    ["Map art"] = "Зображення карти",
    ["Maps painted by hand"] = "Карти, намальовані вручну",
    ["Translations"] = "Переклади",
    ["Libraries"] = "Бібліотеки",
    ["Reports and ideas"] = "Повідомлення й ідеї",
    ["Everyone who reports problems and ideas on CurseForge."] =
        "Усі, хто повідомляє про проблеми й ділиться ідеями на CurseForge.",
    ["If a word reads wrong in your language, say so on CurseForge: it's fixed for the next version."] =
        "Якщо слово вашою мовою звучить неправильно, напишіть про це на CurseForge: у наступній версії його виправлять.",
    ["Hand painted custom art for OpenMap including the sea elements, blank land between zones, and his maps of WoW Forever dungeons."] =
        "Намальовані вручну зображення для OpenMap: море, порожні землі між зонами і його карти підземель WoW Forever.",
    ["the map art is the game's own"] = "зображення карти взято з самої гри",
    ["a dungeon's map opening when you open the map inside it, and one icon for townsfolk who walk about"] =
        "карта підземелля, що відкривається, коли ви відкриваєте карту в ньому, і один значок для міських служб, що ходять туди-сюди",
    ["dungeon and cave maps in every language (they showed green on some languages' clients)"] =
        "карти підземель і печер усіма мовами (у клієнтах деякими мовами вони були зелені)",
    ["flight masters named in your client's language"] = "назви майстрів польотів мовою вашого клієнта",
    ["friends on other numbered realms on the map"] = "друзі з інших нумерованих серверів на карті",
    ["gold-bordered dots for your party and raid"] = "точки із золотою облямівкою для вашої групи й рейду",
    ["how the map reopens, and middle-click to center on you"] =
        "як карта відкривається знову, і клік середньою кнопкою, щоб показати вас у центрі",
    ["map brightness"] = "яскравість карти",
    ["one marker per friend or guildmate, none left over when they join your group, and the newest dungeons' entrances"] =
        "одна мітка на друга чи члена гільдії, без зайвих, коли вони приєднуються до вашої групи, і входи до найновіших підземель",
    ["OpenMap's map with a controller (the Gamepad UI)"] = "карта OpenMap з контролером (інтерфейс геймпада)",
    ["the controller map option turned on in combat, and B by a quest's details"] =
        "налаштування карти для контролера, увімкнене в бою, і кнопка B біля подробиць завдання",
    ["Questie 12.8's icons found on the map"] = "значки Questie 12.8, знайдені на карті",
    ["the map in combat, RareScanner's icons over the map and other map addons' pins"] =
        "карта в бою, значки RareScanner поверх карти й позначки інших аддонів карти",
    ["the map's hitches while panning, found and measured with /openmap bench"] =
        "ривки карти під час пересування, знайдені й виміряні через /openmap bench",
    ["the resizable settings menu, resizing the map with Move Any, and the Titan Panel launcher"] =
        "меню налаштувань зі змінним розміром, зміна розміру карти через Move Any і кнопка в Titan Panel",
    ["the switch for dungeon maps, and separate switches for friends and guild"] =
        "перемикач карт підземель і окремі перемикачі для друзів і гільдії",
    ["the yellow ping hidden with your arrow"] = "жовтий сигнал, схований разом із вашою стрілкою",
    ["zooming about four times smoother, found and measured"] = "наближення приблизно вчетверо плавніше, знайдене й виміряне",
}

-- Not L keys: OpenMap's own month list (News.lua), for dates. Genitive: "13 листопада 2026".
local MONTHS = {
    ["January"] = "січня", ["February"] = "лютого", ["March"] = "березня", ["April"] = "квітня",
    ["May"] = "травня", ["June"] = "червня", ["July"] = "липня", ["August"] = "серпня",
    ["September"] = "вересня", ["October"] = "жовтня", ["November"] = "листопада", ["December"] = "грудня",
}

local locale = { MAP = MAP, LOADTIME = LOADTIME, MONTHS = MONTHS }
if ns then ns.locale = locale end
return locale
