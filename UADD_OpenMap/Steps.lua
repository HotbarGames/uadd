-- One step of a look over OpenMap's windows (Screen.lua), guarded on its own. One text that cannot be changed
-- (its hook refused, as on a forbidden frame) must stop neither the look over the rest of the window nor that
-- text's own font: the first error is raised once the look is done. With one error for the whole look, the
-- dungeon view's other texts kept our words in a font without Cyrillic until the next look (boxes; chaos,
-- install part-way, 2026-11-26).

local _, ns = ...
local T = {}
ns.Steps = T

local CYR = "[\208\209]"
local failed               -- the first error in this look

-- A new look: no error yet.
function T.Begin() failed = nil end

function T.Try(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then failed = failed or err end
end

-- The Cyrillic font on one text: on every text of a root marked `all`, else once it shows Ukrainian letters.
function T.FixText(g, r)
    local t = UADD.Plain(g:GetText())
    if r.all or (type(t) == "string" and t:find(CYR)) then ns.Fonts.Fix(g, false) end
end

-- The look is done (`ok`, `err`: from its own pcall): the error that stopped it, else its first step's error.
function T.Raise(ok, err)
    if ok then err = failed end
    failed = nil
    if err ~= nil then error(err, 0) end
end
