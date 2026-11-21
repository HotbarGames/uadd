-- Made by tools/make_wtw_text.py build from WhatTheWhisper 1.0.0. Do not edit: change the review files
-- (local/whatthewhisper/review_NN.txt) and build again. Only hashes and our Ukrainian.
-- T: key = Ukrainian (L.<hash>: UADD.Hash of an enUS locale key; X.<hash>: UADD.Hash of a text drawn
-- without its locale table; Day.<n>: a weekday, Sunday = 1). S: what each slot of a template holds, in
-- order: v value, f free (kept as it is), n game name (the line stays English), t our text.
local _, ns = ...
local T = ns.AL or {}; ns.AL = T
local S = ns.SORT or {}; ns.SORT = S
