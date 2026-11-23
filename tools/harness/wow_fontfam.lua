-- Font families on the game's tooltip lines (docs/LESSONS2.md lesson 18).
-- In the client GameTooltipText and GameTooltipHeaderText are font FAMILIES: one file per alphabet, a
-- Cyrillic one too, while GetFont shows only FRIZQT__.TTF. A line that follows its font object shows
-- UALL Forever's Ukrainian; fs:SetFont(path) pins the line to that one Latin file (boxes) until a
-- SetFontObject. Here: the lines of the game's tooltips start on those objects; SetFont pins a line
-- (its font object stays: GetFontObject still gives it back), SetFontObject unpins it.
-- The check, on lines UADD's code pinned that were not pinned before ours: UADD puts the old font back
-- with SetFontObject ("back"), never by pinning the old file ("bad"); and when a tooltip is cleared (its
-- OnTooltipCleared, run through GetScript or ClearLines / SetOwner) no such line is still pinned by
-- UADD ("checked" for each line looked at, "bad" for a pin left).
local H = HARNESS
local W = H.Widget

if not rawget(_G, "GameTooltipText") then CreateFont("GameTooltipText"):SetFont("Fonts\\FRIZQT__.TTF", 12, "") end
H.tipNames = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "EmbeddedItemTooltip",
    "SettingsTooltip", "GameTooltipItemTooltip" }
for _, name in ipairs(H.tipNames) do
    for i = 1, 8 do
        for _, side in ipairs({ "Left", "Right" }) do
            local fs = rawget(_G, name .. "Text" .. side .. i)
            if fs then
                W.SetFontObject(fs, (i == 1 and side == "Left") and GameTooltipHeaderText or GameTooltipText)
                fs.__tipLine = true
            end
        end
    end
end

-- The UADD file that called (the first addon frame up the stack is one of ours), or nil.
local function OursAt()
    for level = 3, 12 do
        local info = debug.getinfo(level, "S")
        if not info then return nil end
        local src = info.source or ""
        if src:find("^@AddOns/UADD[^/]*/") then return src end
        if src:find("^@AddOns/") then return nil end
    end
    return nil
end

local function report(kind, detail)
    if type(H.tipReport) == "function" or type(H.tipReport) == "userdata" then H.tipReport(kind, detail or "") end
end

local setFont, setObject = W.SetFont, W.SetFontObject
W.SetFont = function(self, path, size, flags)
    if rawget(self, "__type") ~= "FontString" or not rawget(self, "__tipLine") then
        return setFont(self, path, size, flags)
    end
    local before, obj = rawget(self, "__pinned"), rawget(self, "__fontObject")
    local ok = setFont(self, path, size, flags)
    if not ok then return ok end
    local src = OursAt()
    local cyr = UADD and UADD.IsCyrFont and UADD.IsCyrFont(path)
    local pin = rawget(self, "__ourPin")
    if src and pin and not cyr and pin.had and not pin.before then
        -- UADD "put back" the old font by pinning its Latin file: the font family is lost (the bug)
        report("bad", tostring(self:GetName()) .. " put back as a pinned file " .. tostring(path) .. " by " .. src)
    end
    if src then
        if not pin then
            rawset(self, "__ourPin", { had = obj ~= nil, before = before ~= nil, src = src })
            if cyr then report("put") end
        end
        rawset(self, "__pinned", "ours")
    else
        rawset(self, "__ourPin", nil)
        rawset(self, "__pinned", "other")
    end
    if H.setFontClearsObject then rawset(self, "__fontObject", nil) end
    return ok
end
-- H.tipKeepsFile: as in the client (lesson 44), a file set by hand on a line stays over SetFontObject; the
-- object is set, GetFont still gives the file. A Latin file pinned by UADD then still counts as "bad".
W.SetFontObject = function(self, o)
    local keep = H.tipKeepsFile and rawget(self, "__tipLine") and rawget(self, "__pinned") and { self:GetFont() }
    setObject(self, o)
    if rawget(self, "__type") ~= "FontString" then return end
    if keep and keep[1] then
        setFont(self, keep[1], keep[2], keep[3])
        if rawget(self, "__ourPin") and OursAt() then report("back") end
        rawset(self, "__ourPin", nil)
        rawset(self, "__pinned", "kept")
        return
    end
    if rawget(self, "__ourPin") and OursAt() then report("back") end      -- UADD gave the family back
    rawset(self, "__pinned", nil)
    rawset(self, "__ourPin", nil)
end

local function Lines(tip)
    local out, name = {}, tip.GetName and tip:GetName()
    if not name then return out end
    for i = 1, 8 do
        for _, side in ipairs({ "Left", "Right" }) do
            local fs = rawget(_G, name .. "Text" .. side .. i)
            if fs then out[#out + 1] = fs end
        end
    end
    return out
end

-- Runs a tooltip's OnTooltipCleared script, then looks at each line UADD had pinned.
local function Cleared(tip, fn, ...)
    local ours = {}
    for _, fs in ipairs(Lines(tip)) do
        local p = rawget(fs, "__ourPin")
        if p and p.had and not p.before then ours[fs] = p end
    end
    local r = { fn(tip, ...) }
    for fs, p in pairs(ours) do
        report("checked")
        if rawget(fs, "__ourPin") and rawget(fs, "__pinned") == "ours" then
            local path, size = fs:GetFont()
            report("bad", tostring(fs:GetName()) .. " pinned to " .. tostring(path) .. " " .. tostring(size)
                .. " (first pin: " .. tostring(p.src) .. ")")
        end
    end
    return unpack(r)
end

local getScript = W.GetScript
W.GetScript = function(self, name)
    local fn = getScript(self, name)
    if name ~= "OnTooltipCleared" or type(fn) ~= "function" or rawget(self, "__type") ~= "GameTooltip" then return fn end
    return function(tip, ...) return Cleared(tip, fn, ...) end
end

-- As in the client: ClearLines and SetOwner clear the tooltip (OnTooltipCleared runs).
local clearLines, setOwner = W.ClearLines, W.SetOwner
local function Fire(self)
    local fn = rawget(self, "__type") == "GameTooltip" and self:GetScript("OnTooltipCleared")
    if fn then fn(self) end
end
W.ClearLines = function(self, ...) clearLines(self, ...) Fire(self) end
W.SetOwner = function(self, ...) setOwner(self, ...) Fire(self) end
