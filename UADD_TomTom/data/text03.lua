-- Made by tools/make_tt_text.py build from TomTom v4.4.1-release. Do not edit: change the review files
-- (local/tomtom/NN.txt) and build again. Only hashes of the English (UADD/Hash.lua) and our
-- Ukrainian. sort: what each slot holds, v value, f free name, n game name, t our text, w spaces, or a
-- recipe "a SEP b" for slots that touch (tools/tt_rules.py GROUPS).
-- S: templates put into TomTom.L itself (slots v and f only, no plural). K: texts that stay English in
-- TomTom.L because they also show in another addon's bar (its font has no Ukrainian letters).
local _, ns = ...
local G = UADD and UADD.Glossary and UADD.Glossary.Text or function() return nil end
local M = ns.TT or { exact = {}, templates = {}, swap = {}, keep = {} }
ns.TT = M
local E, T, S, K = M.exact, M.templates, M.swap, M.keep
