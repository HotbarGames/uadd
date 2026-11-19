-- Made by tools/make_wt_text.py build from What's Training? 11.4.9. Do not edit: change the review files
-- (local/whatstraining/NN.txt) and build again. Only hashes of the English (UADD/Hash.lua) and our
-- Ukrainian. sort: what each slot holds, v value, n game name, t our text.
local _, ns = ...
local G = UADD and UADD.Glossary and UADD.Glossary.Text or function() return nil end
local M = ns.WT or { exact = {}, templates = {} }
ns.WT = M
local E, T = M.exact, M.templates
