-- Plural forms for any module: our Ukrainian may hold {one|few|many}, e.g. "5 {гравець|гравці|гравців}".
-- The form is picked by the last number before the mark (colour codes and icons do not count).
-- A mark with no number before it takes "many" when final is true; otherwise it is kept as it is.
--   U.PluralForm(num)     1 (one), 2 (few) or 3 (many) for a number written as text ("21", "1,250", "2.5")
--   U.Plural(uk, final)   uk with every mark picked
local U = UADD

function U.PluralForm(num)
    if not num then return 3 end
    local whole, frac = num:match("^([%d,]*)%.?(%d*)$")
    if frac and frac:find("[1-9]") then return 2 end
    local n = tonumber((whole or num):gsub(",", ""), 10)
    if not n then return 3 end
    local ten, hundred = n % 10, n % 100
    if ten == 1 and hundred ~= 11 then return 1 end
    if ten >= 2 and ten <= 4 and (hundred < 12 or hundred > 14) then return 2 end
    return 3
end

local function LastNumber(s)
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
    local last
    for n in s:gmatch("%d[%d,%.]*") do last = n end
    return last and (last:gsub("[,%.]+$", "")) or nil
end

function U.Plural(uk, final)
    if type(uk) ~= "string" or not uk:find("{", 1, true) then return uk end
    return (uk:gsub("(){([^{}|]*)|([^{}|]*)|([^{}|]*)}", function(at, one, few, many)
        local num = LastNumber(uk:sub(1, at - 1))
        if not num and not final then return nil end
        local k = U.PluralForm(num)
        return k == 1 and one or k == 2 and few or many
    end))
end
