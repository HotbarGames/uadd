-- The UALL Forever oracle lives in the core now (UADD/uall.lua, QuestVariants.lua, Routes.lua),
-- shared with the other modules. Questie's files keep reading it as ns.UALL.
local _, ns = ...
ns.UALL = UADD.UALL
