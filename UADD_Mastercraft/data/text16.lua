-- Made by tools/make_mc_text.py build from Mastercraft 2.0.7. Do not edit: change the review files
-- (local/mastercraft/NN.txt) and build again. No English here: only hashes of it (UADD/Hash.lua) and
-- our Ukrainian. sort: what each slot holds, v value, f free name, n game name, t our text, b blank.
local _, ns = ...
local G = UADD and UADD.Glossary and UADD.Glossary.Text or function() return nil end
local M = ns.MC or { exact = {}, templates = {} }
ns.MC = M
local E, T = M.exact, M.templates
T[#T + 1] = { id = "8:05fa0083", len = { 0, 6 }, hash = { "00001505", "5ae23b5a" }, kinds = { "d" }, uk = { 1, " {слот|слоти|слотів}" }, sort = { "v" } }
T[#T + 1] = { id = "8:06609611", len = { 0, 6 }, hash = { "00001505", "5b48d0e8" }, kinds = { "d" }, uk = { 1, " {ярд|ярди|ярдів}" }, sort = { "v" } }
T[#T + 1] = { id = "8:1898a046", len = { 6, 0 }, hash = { "c08d2fdd", "00001505" }, kinds = { "d" }, uk = { "Рівень ", 1 }, sort = { "v" } }
T[#T + 1] = { id = "8:36aace4d", len = { 1, 5 }, hash = { "0002b5d0", "0a791bd9" }, kinds = { "d" }, uk = { "+", 1, " {альт|альти|альтів}" }, sort = { "v" } }
T[#T + 1] = { id = "8:36b16f4c", len = { 1, 5 }, hash = { "0002b5d0", "0a7fbcd8" }, kinds = { "d" }, uk = { "+ ще ", 1 }, sort = { "v" } }
T[#T + 1] = { id = "8:3e6e7a4d", len = { 6, 0 }, hash = { "d146dc24", "00001505" }, kinds = { "d" }, uk = { "Уміння ", 1 }, sort = { "v" } }
T[#T + 1] = { id = "8:5e213f5b", len = { 6, 0 }, hash = { "b7365563", "00001505" }, kinds = { "s" }, uk = { "Тут: ", 1 }, sort = { "n" } }
T[#T + 1] = { id = "8:77945e60", len = { 6, 0 }, hash = { "d0dbef28", "00001505" }, kinds = { "s" }, uk = { "Продає: ", 1 }, sort = { "n" } }
T[#T + 1] = { id = "8:af7d18cf", len = { 6, 0 }, hash = { "d12541d7", "00001505" }, kinds = { "s" }, uk = { "Від ", 1 }, sort = { "v" } }
T[#T + 1] = { id = "8:c6225049", len = { 6, 0 }, hash = { "ac4252d1", "00001505" }, kinds = { "s" }, uk = { "Коштує ", 1 }, sort = { "v" } }
T[#T + 1] = { id = "8:c6a9166d", len = { 6, 0 }, hash = { "1bebf044", "00001505" }, kinds = { "d" }, uk = { "уміння ", 1 }, sort = { "v" } }
T[#T + 1] = { id = "8:c966558c", len = { 6, 0 }, hash = { "c52e2b54", "00001505" }, kinds = { "s" }, uk = { "Потрібно: ", 1 }, sort = { "n" } }
T[#T + 1] = { id = "8:f333f433", len = { 6, 0 }, hash = { "e1e5f43b", "00001505" }, kinds = { "s" }, uk = { "Зона: ", 1 }, sort = { "n" } }
T[#T + 1] = { id = "8:f6ba9ff6", len = { 6, 0 }, hash = { "c538d33e", "00001505" }, kinds = { "s" }, uk = { "Далі: ", 1 }, sort = { "n" } }
T[#T + 1] = { id = "8:ffcefa80", len = { 6, 0 }, hash = { "1b810348", "00001505" }, kinds = { "s" }, uk = { "продає ", 1 }, sort = { "n" } }
T[#T + 1] = { id = "92:eb1ddb3d", len = { 0, 90 }, hash = { "00001505", "80cd5ac5" }, kinds = { "s" }, uk = { "Гравця ", 1, " заблоковано на 7 днів: порушено роботу Майстрів. Розблокувати: Майстри > Заблоковані. Повідомити: /mc report" }, sort = { "f" } }
T[#T + 1] = { id = "93:63c6bf26", len = { 10, 81 }, hash = { "fa3685f5", "0282fabe" }, kinds = { "s" }, uk = { "|cffffd140", 1, "|r закидає й підсікає, поки відкрита панель риболовлі. Змінити: Налаштування > Рибалка." }, sort = { "f" } }
T[#T + 1] = { id = "93:64b0396d", len = { 13, 6, 66 }, hash = { "efa0dc43", "92a9b1ac", "09b539f2" }, kinds = { "d", "d" }, uk = { "Раз на тиждень, ", 1, ":00 - ", 2, ":00 за часом сервера. Календар гри показує цей день, коли він близько." }, sort = { "v", "v" } }
T[#T + 1] = { id = "94:0b4ce59c", len = { 19, 10, 30, 9, 18 }, hash = { "60db61ba", "10912e2e", "e8828de9", "f15bb4e9", "998c6072" }, kinds = { "d", "d", "d", "d" }, uk = { "Сканування цін завершено за ", 1, " с: ", 2, " предметів на аукціоні - виставлено ", 3, " з ваших ", 4, " предметів." }, sort = { "v", "v", "v", "v" } }
T[#T + 1] = { id = "94:5a382989", len = { 6, 17, 67 }, hash = { "a6aa95e0", "d5c2658e", "cd974493" }, kinds = { "d", "d" }, uk = { "Приблизно ", 1, " {раз|рази|разів} виготовити, щоб досягти ", 2, " - зелені рецепти не дають очко щоразу, тому враховано запас." }, sort = { "v", "v" } }
T[#T + 1] = { id = "94:e3bea9b1", len = { 0, 92 }, hash = { "00001505", "a34c2b39" }, kinds = { "s" }, uk = { 1, " Ті самі матеріали, що й у рецепті у вашій грі (перевірено, коли ви відкривали вікно професій)." }, sort = { "n" } }
T[#T + 1] = { id = "99:192c7ce4", len = { 10, 87 }, hash = { "fa3685f5", "357d0a7c" }, kinds = { "s" }, uk = { "|cffffd140", 1, "|r теж увімкнено - помічник риболовлі Mastercraft вимкнено. Увімкніть його тут, якщо віддаєте перевагу нашому." }, sort = { "f" } }
T[#T + 1] = { id = "99:b26c4ae7", len = { 5, 92 }, hash = { "0e17e106", "47d2a8ae" }, kinds = { "s" }, uk = { "Показувати точки (", 1, ") на карті й мінікарті. Кожну точку, яку ви збираєте, запам'ятовують усі ваші персонажі." }, sort = { "n" } }
T[#T + 1] = { id = "9:37b67c64", len = { 7, 0 }, hash = { "1716bc2c", "00001505" }, kinds = { "s" }, uk = { "Потрібно: ", 1 }, sort = { "n" } }
T[#T + 1] = { id = "9:3ae14509", len = { 7, 0 }, hash = { "773d1791", "00001505" }, kinds = { "s" }, uk = { "Завдання: ", 1 }, sort = { "n" } }
T[#T + 1] = { id = "9:73f98551", len = { 7, 0 }, hash = { "c338a5d9", "00001505" }, kinds = { "s" }, uk = { "прибуток ", 1 }, sort = { "v" } }
T[#T + 1] = { id = "9:79a5f43b", len = { 7, 0 }, hash = { "56db0292", "00001505" }, kinds = { "d" }, uk = { "Стежити x", 1 }, sort = { "v" } }
T[#T + 1] = { id = "9:861536d4", len = { 0, 7 }, hash = { "00001505", "a029535c" }, kinds = { "s" }, uk = { 1, " вимкнено" }, sort = { "f" } }
T[#T + 1] = { id = "9:861537a4", len = { 0, 7 }, hash = { "00001505", "a029542c" }, kinds = { "s" }, uk = { 1, " увімкнено." }, sort = { "f" } }
T[#T + 1] = { id = "9:94b48e0c", len = { 7, 0 }, hash = { "9e9443d4", "00001505" }, kinds = { "s" }, uk = { "Готово: ", 1 }, sort = { "n" } }
T[#T + 1] = { id = "9:9bcbe438", len = { 6, 1 }, hash = { "1bebf044", "0002b5d0" }, kinds = { "d" }, uk = { "уміння ", 1, "+" }, sort = { "v" } }
T[#T + 1] = { id = "9:a04c3191", len = { 0, 7 }, hash = { "00001505", "923bc748" }, kinds = { "d" }, uk = { "Виробів: ", 1 }, sort = { "v" } }
T[#T + 1] = { id = "9:ad4a4e6c", len = { 0, 7 }, hash = { "00001505", "c75e6af4" }, kinds = { "s" }, uk = { 1, ": готово" }, sort = { "n" } }
T[#T + 1] = { id = "9:bc07cb33", len = { 0, 7 }, hash = { "00001505", "adf760ea" }, kinds = { "d" }, uk = { 1, " у мережі" }, sort = { "v" } }
T[#T + 1] = { id = "9:f30f8372", len = { 7, 0 }, hash = { "26c6a7ba", "00001505" }, kinds = { "s" }, uk = { "Де: ", 1 }, sort = { "n" } }
T[#T + 1] = { id = "9:f9138dca", len = { 0, 7 }, hash = { "00001505", "1327aa52" }, kinds = { "s" }, uk = { 1, " / год" }, sort = { "v" } }
T[#T + 1] = { id = "9:f99cf07d", len = { 6, 1 }, hash = { "c081e377", "0002b5d3" }, kinds = { "s" }, uk = { "Вивчіть ", 1, "." }, sort = { "n" } }
