-- Made by tools/make_wql_text.py build from Wowhead Quick Link 2.16.10. Do not edit: change the review files
-- (local/wql/review_NN.txt) and build again. Only hashes and our Ukrainian.
-- T: <kind>.<hash> (UADD.Hash of the English) = Ukrainian. S: what each slot of a template holds, in order:
-- t our text (the header, the link type).
local _, ns = ...
local T = ns.AL or {}; ns.AL = T
local S = ns.SORT or {}; ns.SORT = S
T["Pop.0028a5f8"] = "%s: посилання\nCTRL-C, щоб скопіювати"
S["Pop.0028a5f8"] = "t"
T["Code.0cf88a3b"] = "Закрити"
T["Head.2228878c"] = "Wowhead: %s"
S["Head.2228878c"] = "t"
T["Type.0dfaa637"] = "завдання"
T["Type.0e1c1865"] = "закляття"
T["Type.7c871214"] = "предмет"
T["Type.0af404ae"] = "досягнення"
T["Type.f9b18269"] = "репутація"
T["Type.918009b0"] = "валюта"
T["Code.95cb26ed"] = "Створити посилання Wowhead"
T["Code.e49fab7b"] = "Створити посилання Raider.IO"
T["Code.62c3ca66"] = "Початок URL"
T["Code.69fa1a2d"] = "Кінець URL"
T["Code.54d63e75"] = "Wowhead Quick Link: налаштування"
T["Code.b0a39822"] = "Підсумкова URL-адреса"
