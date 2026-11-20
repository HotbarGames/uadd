-- Item names in Scrap's junk list (Scrap_Merchant), from UALL Forever (docs/LESSONS.md, lesson 9: game names are
-- its, never ours).
--   * Each row of the list shows an item's name as the game gives it (English on this client). Right after Scrap
--     fills the rows (its list's update), a row's name gets UALL Forever's Ukrainian for it (UADD.UALL.Item). A
--     name it lacks stays English, whole. "Not now": asked again at the list's next update.
--   * Only the rows. Item tooltips are the game's; a chat line with an item link stays English (scrap_rules STAY).
--   * Our font (Fonts.lua) on each row we name, read back there; the game's font back with the English.
--   * Off and the hold key: each name we changed goes back to its English, while the row still shows ours.
--   * Stays as it is: the "Scrap" tab on the merchant window and the window's title, the addon's own name.

local _, ns = ...
local U = UADD
local I = {}
ns.Items = I

local CYR = "[\208-\210]"
local put = setmetatable({}, { __mode = "k" })   -- a row's FontString -> { English, Ukrainian }
local hooked = {}
local count = 0

local function List()
    local a = rawget(_G, "Scrap")
    local v = type(a) == "table" and a.Visualizer or rawget(_G, "ScrapVisualizer")
    local s = type(v) == "table" and rawget(v, "Scroll")
    return type(s) == "table" and s or nil
end

local function Uk(en)
    local A = U.UALL
    if type(A) ~= "table" or type(A.Item) ~= "function" then return nil end
    local uk = A.Item(en)
    return type(uk) == "string" and uk:find(CYR) and uk or nil
end

local function Font(fs) if ns.Fonts and ns.Fonts.Decide then U.SafeCall(ns.Fonts.Decide, fs) end end

local function Row(b, on)
    local fs = type(b) == "table" and b.Text
    if type(fs) ~= "table" or not fs.GetText then return end
    local cur, rec = fs:GetText(), put[fs]
    if rec and cur ~= rec[1] and cur ~= rec[2] then rec, put[fs] = nil, nil end  -- the row shows another item now
    if not on then
        if rec and cur == rec[2] then fs:SetText(rec[1]) Font(fs) end
        return
    end
    if rec then
        if cur == rec[1] then fs:SetText(rec[2]) end
        Font(fs)
        count = count + 1
        return
    end
    if type(cur) ~= "string" or cur == "" or cur:find(CYR) then return end
    local uk = Uk(cur)
    if uk then
        put[fs] = { cur, uk }
        fs:SetText(uk)
        Font(fs)
        count = count + 1
    end
end

-- UALL Forever's names in (on) or the game's English back (off), in every row; hooks the list's update once.
function I.Set(on)
    local s = List()
    if not s then return end
    if not hooked[s] and type(s.update) == "function" then
        hooked[s] = true
        hooksecurefunc(s, "update", function() if ns.On() then U.SafeCall(I.Set, ns.WordsWanted()) end end)
    end
    count = 0
    for _, b in ipairs(type(s.buttons) == "table" and s.buttons or {}) do Row(b, on) end
end

function I.Count() return count end
