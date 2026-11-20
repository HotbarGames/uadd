-- Made by tools/make_wp_text.py build from Waypoint UI 1.7.5. Do not edit: change the review files
-- (local/waypointui/NN.txt) and build again. Only hashes of the English (UADD/Hash.lua) and our
-- Ukrainian. sort: what each slot holds, v value, f free name (tools/wp_rules.py SORTS).
local _, ns = ...
local G = UADD and UADD.Glossary and UADD.Glossary.Text or function() return nil end
local M = ns.WP or { exact = {}, templates = {} }
ns.WP = M
local E, T = M.exact, M.templates
