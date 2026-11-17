-- Helpers for flow_openmap_popup.py: StaticPopup1..4 filled by StaticPopup_Show as the game does,
-- and OpenMap's questions defined as OpenMap defines them. Reached from Python as HARNESS.omp.
local H = HARNESS
local M = {}
H.omp = M

local pops = {}
for i = 1, 4 do
    local d = _G["StaticPopup" .. i]
    if not rawget(d, "text") then
        d.text = d:CreateFontString("StaticPopup" .. i .. "Text", "ARTWORK", "GameFontHighlight")
    end
    d.text.GetHeight = function(self) local t = self:GetText() or "" return 12 * math.ceil(#t / 40) end
    for b = 1, 3 do
        if not rawget(d, "button" .. b) then
            local btn = CreateFrame("Button", "StaticPopup" .. i .. "Button" .. b, d)
            btn:GetFontString():SetFontObject(GameFontNormal)
            d["button" .. b] = btn
        end
    end
    d:Hide()
    pops[i] = d
end

-- The game's StaticPopup_Show, run before the hook UADD_OpenMap put on the old one.
local hooked = StaticPopup_Show
StaticPopup_Show = function(which, a1, a2, data)
    local info = StaticPopupDialogs[which]
    if info then
        local d = pops[1]
        for _, p in ipairs(pops) do if p.which == which or not p:IsShown() then d = p break end end
        d.which, d.data = which, data
        d.text:SetText(info.text:format(a1, a2))
        for b = 1, 3 do
            d["button" .. b]:SetText(info["button" .. b])
            d["button" .. b]:SetShown(info["button" .. b] ~= nil)
        end
        d:Show()
        d:SetHeight(60 + d.text:GetHeight())
    end
    return hooked(which, a1, a2, data)
end

-- OpenMap's questions: the buttons and the report's text read from L as its files load (English
-- then, so written out here); the other texts from L as it asks.
local L = OpenMap.L
StaticPopupDialogs.OPENMAP_PINS_SHARED = { text = "%s", button1 = "Add them", button2 = "Ignore" }
StaticPopupDialogs.OPENMAP_PINS_CLEAR = { text = "%s", button1 = "Delete", button2 = CANCEL or "Cancel" }
StaticPopupDialogs.OPENMAP_REPORT_NOTE = {
    text = "|cffffd100Report, step 2 of 2:|r what's wrong?\n|cffaaaaaa"
        .. "(the map, the menu, a setting ... anything: a sentence is plenty)|r",
    hasEditBox = true, button1 = "Continue", button2 = CANCEL or "Cancel",
}
StaticPopupDialogs.OTHER_ADDON_QUESTION = { text = "Sell everything grey?", button1 = "Okay" }

local KEY   -- the ClassicUI Forever question, as our word list has it
for en in pairs(UADD.OpenMapLocale.entries) do
    if en:find("^ClassicUI Forever's World map option is on") then KEY = en end
end
function M.classicKey() return KEY end

function M.shared(from, lines, n)
    StaticPopup_Show("OPENMAP_PINS_SHARED", L["%s shared %d map pin(s) with you:"]:format(from, n)
        .. "\n|cffffffff" .. lines .. "|r")
end
function M.clear(n) StaticPopup_Show("OPENMAP_PINS_CLEAR", L["Delete all %d map pins?"]:format(n)) end
function M.report() StaticPopup_Show("OPENMAP_REPORT_NOTE") end
function M.classic()
    StaticPopupDialogs.OPENMAP_CLASSICUI_MAP = { text = L[KEY], button1 = YES or "Yes", button2 = NO or "No" }
    StaticPopup_Show("OPENMAP_CLASSICUI_MAP")
end
function M.other() StaticPopup_Show("OTHER_ADDON_QUESTION") end

function M.of(which) for i, p in ipairs(pops) do if p.which == which and p:IsShown() then return i end end end
function M.hide(i) pops[i]:Hide() end
function M.hideAll() for _, p in ipairs(pops) do p:Hide() end end

local function Parts(i)
    local d = pops[i]
    return { d.text, d.button1:GetFontString(), d.button2:GetFontString() }
end

-- Text and button labels, tab-joined.
function M.texts(i)
    local out = {}
    for k, fs in ipairs(Parts(i)) do out[k] = fs:GetText() or "" end
    return table.concat(out, "\t")
end

-- Each part's font: "path size flags", tab-joined.
function M.fonts(i)
    local out = {}
    for k, fs in ipairs(Parts(i)) do
        local p, size, flags = fs:GetFont()
        out[k] = tostring(p) .. " " .. tostring(size) .. " " .. tostring(flags or "")
    end
    return table.concat(out, "\t")
end

-- Each part in a font with Ukrainian letters: "1" or "0" per part.
function M.cyr(i)
    local out = ""
    for _, fs in ipairs(Parts(i)) do out = out .. (UADD.IsCyrFont((fs:GetFont())) and "1" or "0") end
    return out
end

function M.heights(i) return pops[i]:GetHeight(), pops[i].text:GetHeight() end
function M.count() return UADD.OpenMapPopup.Count() end
