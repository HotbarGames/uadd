-- Made by tools/make_sal_text.py build from Speedy AutoLoot 126. Do not edit: change the review files
-- (local/sal/review_NN.txt) and build again. Only hashes and our Ukrainian.
-- T: Code.<hash> (UADD.Hash of the English) = Ukrainian. S: what each slot of a template holds, in order:
-- v value, f free (kept as it is), n game name (the line stays English), t our text.
local _, ns = ...
local T = ns.AL or {}; ns.AL = T
local S = ns.SORT or {}; ns.SORT = S
T["Code.2dd276b5"] = "display -|r |cffEEE4AEУвімкнути або вимкнути показ здобичі. Типово: вимкнено|r"
T["Code.7d2cef0f"] = "anchor -|r |cffEEE4AEПоказати або сховати рамку, щоб пересунути показ здобичі|r"
T["Code.e052f5f6"] = "fish -|r |cffEEE4AEВимкнути звук, коли витягуєш рибу. Типово: вимкнено|r"
T["Code.f6eb3301"] = "sound -|r |cffEEE4AEГрати звук, коли інвентар повний під час збору здобичі. Типово: вимкнено|r,"
T["Code.d47d98db"] = "set (SoundID) -|r |cffEEE4AEВибрати звук (його номер, SoundID). Типово: 44321|r"
T["Code.cc7fd69a"] = "set (SoundID) -|r |cffEEE4AEВибрати звук (його номер, SoundID). Типово: 139|r"
T["Code.cfcf14d8"] = "bop -|r |cffEEE4AEАвтоматично підтверджувати предмети, що прив'язуються при отриманні, коли ти без групи. Типово: вимкнено|r"
T["Code.0a88fafd"] = "auto -|r |cffEEE4AEУвімкнути автозбір здобичі для всіх персонажів (старий спосіб)|r"
T["Code.ebee466e"] = "|cffB6B6B6Звук, коли витягуєш рибу, вимкнено."
T["Code.01ed432f"] = "|cff37DB33Звук, коли витягуєш рибу, увімкнено."
T["Code.26d303d5"] = "|cffB6B6B6Автозбір здобичі для всіх персонажів вимкнено."
T["Code.0e1a47f6"] = "|cff37DB33Автозбір здобичі для всіх персонажів увімкнено."
T["Code.94516ab1"] = "|cffB6B6B6Без звуку, коли інвентар повний."
T["Code.edff8d23"] = "|cff37DB33Буде звук, коли інвентар повний."
T["Code.d1e44faf"] = "Звук вибрано:|r |cff37DB33%s|r"
S["Code.d1e44faf"] = "v"
T["Code.7e467945"] = "|cffFF0000У бою не можна пересувати показ здобичі."
T["Code.dc17fa33"] = "|cff37DB33Показ здобичі увімкнено."
T["Code.507419b2"] = "|cffB6B6B6Показ здобичі вимкнено."
T["Code.bf913ef2"] = "|cffB6B6B6Автоматично підтверджувати здобич без групи: вимкнено."
T["Code.4680e173"] = "|cff37DB33Автоматично підтверджувати здобич без групи: увімкнено."
T["Code.350de479"] = "Показ здобичі"
T["Code.3078a0a6"] = "Епічний зразок"
T["Code.27d0902e"] = "Звичайний зразок"
