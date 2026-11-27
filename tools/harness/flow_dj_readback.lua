-- The journal's SetFont that reads our file back (docs/LESSONS5.md lesson 48), for flow_dj_readback.py.
-- A text on the journal's window, drawn as the journal draws its quest page's class line: its text, its font
-- object again, then SetFont with the file and the size its GetFont gives (with ours on: our Cyrillic file).
-- It draws again on each redraw of the journal (the hold key, off), in the language of that moment.
local H = HARNESS
local M = {}
H.djrb = M

local function ns() return H.ns.UADD_DungeonJournal end
local function FDJ() return rawget(_G, "ForeverDungeonJournal_NS") end

M.UK, M.EN = "Хиткий ґаджет", "Wobbly gizmo"
M.size = 16

-- The journal's own draw, run from a chunk in its folder.
local Draw = assert(loadstring([[
    local M = ...
    return function()
        local fs, fdj = M.fs, rawget(_G, "ForeverDungeonJournal_NS")
        if not fs then return end
        local uk = fdj and fdj.GetLanguage and fdj.GetLanguage() == "ukUA"
        fs:SetText(uk and M.UK or M.EN)
        fs:SetFontObject(M.object)
        local font, size = fs:GetFont()
        if font and size then fs:SetFont(font, M.size, "") end
        M.draws = (M.draws or 0) + 1
    end]], "@AddOns/ForeverDungeonJournal/Core/Journal.lua"))(M)

-- The text, with Ukrainian on it and only its font object (as the journal makes it); our look puts ours on.
function M.make()
    M.object = rawget(_G, "ForeverDJ_GameFontNormalSmall") or GameFontNormalSmall
    local fs = ForeverDungeonJournalFrame:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(M.object)
    fs:SetText(M.UK)
    fs:Show()
    M.fs = fs
    M.own = { fs:GetFont() }
    local fdj = FDJ()
    -- the journal draws again on each of its redraws (the hold key's light one, off's English click)
    for _, name in ipairs({ "RelocalizeLootFilter", "RefreshQuestTracker" }) do
        if type(fdj[name]) == "function" then hooksecurefunc(fdj, name, Draw) end
    end
    ns().Screen.Schedule()
    return M.own[1], M.own[2], M.own[3] or ""
end

function M.draw(size)
    M.size = size
    Draw()
end

-- Now: its text, file, size, flags; whether the file is ours; what the module remembers (file, size, flags).
function M.now()
    local fs = M.fs
    local p, s, fl = fs:GetFont()
    local rp, rs, rfl = ns().Fonts.Original(fs)
    return fs:GetText(), p, s, fl or "", UADD.IsCyrFont(p), rp, rs, rfl
end

-- Cyrillic on it in a file without Cyrillic (boxes in the game)?
function M.box()
    local t = M.fs:GetText() or ""
    return t:find("[\208\209][\128-\191]") ~= nil and not UADD.IsCyrFont((M.fs:GetFont()))
end
