-- Made by tools/make_mc_text.py build from Mastercraft 2.0.7. Do not edit: change the review files
-- (local/mastercraft/NN.txt) and build again. No English here: only hashes of it (UADD/Hash.lua) and
-- our Ukrainian. sort: what each slot holds, v value, f free name, n game name, t our text, b blank.
local _, ns = ...
local G = UADD and UADD.Glossary and UADD.Glossary.Text or function() return nil end
local M = ns.MC or { exact = {}, templates = {} }
ns.MC = M
local E, T = M.exact, M.templates
