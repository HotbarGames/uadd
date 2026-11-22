-- Made by tools/make_rts_text.py build from Road to Sixty 1.20.12. Do not edit: change the review files
-- (local/rts/review_NN.txt) and build again. Only hashes and our Ukrainian.
-- T: key = Ukrainian (Code.<hash>: UADD.Hash of one string literal of Road to Sixty's code). S: what each
-- slot of a template holds, in order: v value, f free (kept as it is), n game name, t our text.
local _, ns = ...
local T = ns.RTS or {}; ns.RTS = T
local S = ns.SORT or {}; ns.SORT = S
