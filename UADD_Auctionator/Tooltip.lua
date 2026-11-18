-- Auctionator's lines in tooltips, in Ukrainian. Two kinds:
--   * Price lines it adds to item tooltips anywhere (bags, mail, merchant, auction house):
--       "Vendor |cff.. x5|r"   |cffffffff12g 30s|r      (AddDoubleLine: label, count, price)
--       "Auction Age"          |cffffffff3 days|r  or  unknown
--       "Total |cFFAAAAFF 7 items|r"   (several items at once)
--     GameTooltip's and ItemRefTooltip's own AddDoubleLine is hooked (hooksecurefunc on those two
--     frames): right after a line is added, its label is looked up in a small table (LABEL, the
--     English of seven locale keys), so another addon's line is never changed. Only the label, the
--     word "unknown" and "%s days" change; the count, prices and item names stay. Cheap (one
--     pattern and one lookup), so it also runs in combat. This also catches lines Auctionator adds
--     later, when item data arrives.
--   * Tooltips over Auctionator's own frames (buttons, settings, the info tab): while the owner is
--     inside one of them (Screen.Inside) and the tooltip shows no item, every line Words.lua knows
--     changes when the tooltip shows. Not in combat.
-- A changed line gets UADD's Cyrillic font (UADD/AceFont.lua, that one line only); the tooltip is
-- laid out again one frame later. The fonts go back exactly when the tooltip is cleared or hides.
-- The hold key puts the English back on a shown tooltip.

local _, ns = ...
local T = {}
ns.Tooltip = T

local CYR = "[\208-\210]"
local LABELS = { "VENDOR", "AUCTION", "AUCTION_MEAN", "AUCTION_AGE", "DISENCHANT", "PROSPECT", "MILL" }
local LABEL = {}           -- English label -> its locale key
local hooked, guard = {}, false
local tips = {}            -- tooltip -> { app = AceFont name, lines = { fs -> { en, uk } }, layout = pending }

local function Each(tip, fn)
    local name = tip:GetName()
    for i = 1, (tip.NumLines and tip:NumLines()) or 0 do
        for _, side in ipairs({ "Left", "Right" }) do
            local fs = rawget(_G, name .. "Text" .. side .. i)
            if type(fs) == "table" and fs.GetText then fn(fs) end
        end
    end
end

local function Layout(tip)
    local t = tips[tip]
    if t.layout then return end
    t.layout = true
    C_Timer.After(0, function()
        t.layout = false
        if not tip:IsVisible() then return end
        guard = true
        pcall(tip.Show, tip)
        guard = false
    end)
end

local function Put(tip, fs, en, uk)
    local t = tips[tip]
    guard = true
    pcall(fs.SetText, fs, uk)
    guard = false
    t.lines[fs] = { en = en, uk = uk }
    UADD.AceFont.Set(fs, t.app)
end

-- "unknown  " or "|cffffffffunknown  |r" or "|cffffffff3 days|r" in Ukrainian, or nil.
local function Right(r)
    local code, inner = r:match("^(|c%x%x%x%x%x%x%x%x)(.-)|r$")
    local body = inner or r
    local word, pad = body:match("^(.-)(%s*)$")
    local uk = ns.Words.Key("UNKNOWN", word) or ns.Words.Key("X_DAYS", word)
    if not uk then return nil end
    return code and (code .. uk .. pad .. "|r") or (uk .. pad)
end

-- The line just added, if it is one of Auctionator's price lines.
local function OnDouble(tip)
    if not ns.WordsWanted() or not tips[tip] then return end
    local n = tip:NumLines() or 0
    local name = tip:GetName()
    local left, right = rawget(_G, name .. "TextLeft" .. n), rawget(_G, name .. "TextRight" .. n)
    if type(left) ~= "table" or type(right) ~= "table" then return end
    local l, r = UADD.Plain(left:GetText()), UADD.Plain(right:GetText())
    if not l or not r then return end            -- no text, or a secret one (combat): leave it
    local label, rest = l:match("^(.-)(|[cA].*)$")
    if not label then label, rest = l, "" end
    local key = LABEL[label]
    if key then
        local ukLabel = ns.Words.Key(key, label)
        local ukRight = Right(r)
        if not ukLabel and not ukRight then return end
        if not (r:sub(1, 2) == "|c" or ukRight) then return end   -- not a price, "unknown" or days
        if ukLabel then Put(tip, left, l, ukLabel .. rest) end
        if ukRight then Put(tip, right, r, ukRight) end
    else
        local uk = ns.Words.Key("TOTAL_ITEMS_COLORED", l)
        if not uk then return end
        Put(tip, left, l, uk)
    end
    Layout(tip)
end

-- Every line we know (the tooltip is over Auctionator's frame and shows no item).
local function Translate(tip)
    local t, any = tips[tip], false
    Each(tip, function(fs)
        local s = UADD.Plain(fs:GetText())
        local had = t.lines[fs]
        if not s then t.lines[fs] = nil return end
        if had and s == had.uk then return end
        local en = (had and s == had.en) and had.en or s
        local uk = type(en) == "string" and not en:find(CYR) and ns.Words.Text(en)
        if uk then Put(tip, fs, en, uk) any = true else t.lines[fs] = nil UADD.Missed("auctionator", en, fs) end
    end)
    return any
end

local function Ours(tip)
    if tip.GetItem and tip:GetItem() then return false end
    return tip.GetOwner and ns.Screen.Inside(tip:GetOwner()) or false
end

local function OnShow(tip)
    if guard or not ns.WordsWanted() or (InCombatLockdown and InCombatLockdown()) then return end
    if Ours(tip) and Translate(tip) then Layout(tip) end
end

local function Clear(tip)
    if guard then return end
    local t = tips[tip]
    if not t then return end
    wipe(t.lines)
    UADD.AceFont.Stop(t.app)
end

-- Every tooltip line back to its own font; what we put in is forgotten (the lines are reused).
function T.Stop()
    for tip in pairs(tips) do Clear(tip) end
end

-- The hold key on a shown tooltip: English back (show) or our words again.
function T.Sync(show)
    for tip, t in pairs(tips) do
        if tip:IsVisible() then
            if show then
                guard = true
                for fs, l in pairs(t.lines) do
                    if UADD.Plain(fs:GetText()) == l.uk then pcall(fs.SetText, fs, l.en) end
                end
                guard = false
                UADD.AceFont.Stop(t.app)
                Layout(tip)
            elseif ns.WordsWanted() then
                local any = false
                for fs, l in pairs(t.lines) do
                    if UADD.Plain(fs:GetText()) == l.en then Put(tip, fs, l.en, l.uk) any = true end
                end
                if Ours(tip) and Translate(tip) then any = true end
                if any then Layout(tip) end
            end
        end
    end
end

function T.Install()
    wipe(LABEL)
    for _, key in ipairs(LABELS) do
        local en = ns.Words.English(key)
        if en then LABEL[en] = key end
    end
    for i, name in ipairs({ "GameTooltip", "ItemRefTooltip" }) do
        local tip = rawget(_G, name)
        if type(tip) == "table" and tip.HookScript and not hooked[tip] then
            hooked[tip] = true
            tips[tip] = { app = "AUCTip" .. i, lines = {}, layout = false }
            hooksecurefunc(tip, "AddDoubleLine", function(self) UADD.SafeCall(OnDouble, self) end)
            hooksecurefunc(tip, "Show", function(self) UADD.SafeCall(OnShow, self) end)
            pcall(tip.HookScript, tip, "OnTooltipCleared", function(self) Clear(self) end)
            tip:HookScript("OnHide", function(self) Clear(self) end)
        end
    end
end

-- For the checks: tooltip lines in our words, and in our font, now.
function T.Count()
    local n, f = 0, 0
    for _, t in pairs(tips) do
        for fs, l in pairs(t.lines) do if UADD.Plain(fs:GetText()) == l.uk then n = n + 1 end end
        f = f + UADD.AceFont.Count(t.app)
    end
    return n, f
end
