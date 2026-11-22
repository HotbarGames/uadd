-- UADD.DateUk(text): a date or time line an addon wrote with English month and weekday names, in Ukrainian.
-- Only a closed list of words is known: the 12 months and 7 weekdays, full and short ("November", "Nov",
-- "Sunday", "Sun"), in the case the game's date functions write them. Any other word in the line (AM, PM, "th",
-- a name) gives nil: the line stays English as it was (no half lines). A line with no letters at all is given
-- back as it is.
--   * A month after a day number ("12 November") or before one ("November 12", "Nov 12, 2026") is the genitive
--     form after the day: "12 листопада", "12 лист. 2026". A month with no day ("November 2026") is the
--     nominative: "листопад 2026".
--   * A weekday is in small letters ("неділя"), with a capital when it starts the line ("Неділя, 12 листопада").
--   * "May" is both the full and the short form: it gets the full words (травень, травня).
-- Errors, a secret string or a value that is no string give nil.

local U = UADD
local find, sub, match = string.find, string.sub, string.match
local concat = table.concat

-- English -> { nominative, genitive }
local MONTHS = {
    January = { "січень", "січня" }, February = { "лютий", "лютого" }, March = { "березень", "березня" },
    April = { "квітень", "квітня" }, May = { "травень", "травня" }, June = { "червень", "червня" },
    July = { "липень", "липня" }, August = { "серпень", "серпня" }, September = { "вересень", "вересня" },
    October = { "жовтень", "жовтня" }, November = { "листопад", "листопада" }, December = { "грудень", "грудня" },
    Jan = { "січ.", "січ." }, Feb = { "лют.", "лют." }, Mar = { "бер.", "бер." }, Apr = { "квіт.", "квіт." },
    Jun = { "черв.", "черв." }, Jul = { "лип.", "лип." }, Aug = { "серп.", "серп." }, Sep = { "вер.", "вер." },
    Oct = { "жовт.", "жовт." }, Nov = { "лист.", "лист." }, Dec = { "груд.", "груд." },
}
-- English -> { in a line, at its start }
local DAYS = {
    Sunday = { "неділя", "Неділя" }, Monday = { "понеділок", "Понеділок" }, Tuesday = { "вівторок", "Вівторок" },
    Wednesday = { "середа", "Середа" }, Thursday = { "четвер", "Четвер" }, Friday = { "п'ятниця", "П'ятниця" },
    Saturday = { "субота", "Субота" },
    Sun = { "нд", "Нд" }, Mon = { "пн", "Пн" }, Tue = { "вт", "Вт" }, Wed = { "ср", "Ср" }, Thu = { "чт", "Чт" },
    Fri = { "пт", "Пт" }, Sat = { "сб", "Сб" },
}
U.DATE_MONTHS, U.DATE_DAYS = MONTHS, DAYS

local function Turn(s)
    local out, at, i, n = {}, 1, 1, #s
    while i <= n do
        local a, b = find(s, "%a+", i)
        if not a then break end
        local w = sub(s, a, b)
        local m, d = MONTHS[w], DAYS[w]
        if not m and not d then return nil end
        local before = sub(s, at, a - 1)
        if d then
            out[#out + 1] = before
            out[#out + 1] = d[a == 1 and 2 or 1]
            at = b + 1
        else
            local day = match(s, "^ (%d%d?)", b + 1)
            if day and find(s, "^%d", b + 2 + #day) then day = nil end      -- a year, not a day
            if day then
                -- "November 12" / "Nov 12, 2026": the day first, the genitive after it
                out[#out + 1] = before
                out[#out + 1] = day .. " " .. m[2]
                at = b + 2 + #day
                local y = match(s, "^, (%d%d%d%d)", at)
                if y and not find(s, "^%d", at + 6) then
                    out[#out + 1] = " " .. y
                    at = at + 6
                end
            else
                out[#out + 1] = before
                out[#out + 1] = find(before, "%d%s*$") and m[2] or m[1]
                at = b + 1
            end
        end
        i = at
    end
    out[#out + 1] = sub(s, at)
    return concat(out)
end

function U.DateUk(text)
    local s = U.Plain and U.Plain(text) or (type(text) == "string" and text or nil)
    if type(s) ~= "string" then return nil end
    local ok, uk = pcall(Turn, s)
    if ok and type(uk) == "string" then return uk end
    return nil
end
