-- More of the stand-in (OpenMap.lua): lines built the way OpenMap builds them, from L's words (ours
-- while UADD_OpenMap is on) and its own parts: its version, a zone name the game gives in English,
-- a player's note. Written for the checks, not taken from OpenMap. For flow_openmap_built.py.
--   * the News window's top title: L's words, then the version in colour ("v0.8.9", or "dev");
--   * the note editor's title (OpenMapNoteEditor): a new note, or note #3, then the zone;
--   * the pin editor's title (OpenMapPinEditor): the pin, the zone, x and y, who shared it;
--   * a row of the pin list (OpenMapPins): the zone, the player's note in white, then what it is;
--   * a tooltip over the dock: L["To"] and the zone;
--   * a pin's tooltip: the player's note, the zone with x and y, who shared it.

local S, L = OpenMapStandIn, OpenMap.L
local Text = S.Text

local function Frame(name)
    local f = rawget(_G, name)
    if f then return f end
    f = CreateFrame("Frame", name, UIParent)
    f.title = Text(f, 14)
    return f
end

-- d = { version, zone, from (who shared the pin), note (the player's own) }
function S.OpenBuilt(d)
    S.OpenNews()
    S.building = true
    local n = S.news
    n.top = n.top or Text(n, 14)
    local notes, pin, pins = Frame("OpenMapNoteEditor"), Frame("OpenMapPinEditor"), S.pins
    notes.old = notes.old or Text(notes, 14)
    pins.row = pins.row or Text(pins, 12)
    S.building = false
    n.top:SetText(L["What's new in OpenMap"] .. "  |cff998866" .. d.version .. "|r")
    notes.title:SetText(L["New note"] .. " · " .. d.zone)
    notes.old:SetText(L["Note"] .. " #" .. 3 .. " · " .. d.zone)
    pin.title:SetText(("%s · %s  %.1f, %.1f%s"):format(L["Map pin"], d.zone, 45.2, 30.1,
        "  |cff99ccff" .. L["Shared by %s"]:format(d.from) .. "|r"))
    pins.row:SetText(d.zone .. " · |cffffffff" .. d.note .. "|r" .. " |cffe6c27a(" .. L["drawing"] .. ")|r"
        .. " |cff80f070(" .. L["followed"] .. ")|r")
    notes:Show()
    pin:Show()
    pins:Show()
end

-- The texts, by short name.
function S.BuiltTexts()
    local notes, pin = _G.OpenMapNoteEditor, _G.OpenMapPinEditor
    return { top = S.news.top:GetText(), new = notes.title:GetText(), old = notes.old:GetText(),
        pin = pin.title:GetText(), row = S.pins.row:GetText() }
end

function S.CloseBuilt()
    _G.OpenMapNoteEditor:Hide()
    _G.OpenMapPinEditor:Hide()
    S.pins:Hide()
    S.news:Hide()
end

-- The dock's tooltip: L["To"] and the zone. Its line while shown.
function S.DockTip(zone)
    GameTooltip:SetOwner(S.view.side.rows[1], "ANCHOR_RIGHT")
    local t = L["To"] .. " " .. zone
    GameTooltip:AddLine(t)
    local fs = _G.GameTooltipTextLeft1
    fs:SetFont(STANDARD_TEXT_FONT, 12, "")
    fs:SetText(t)
    fs:Show()
    GameTooltip:Show()
    t = fs:GetText()
    GameTooltip:Hide()
    return t
end

-- A pin's tooltip: its note (the player's own, or L["Map pin"] when empty), the zone with x and y,
-- who shared it. The owner holds the pin the way OpenMap's do: a map pin as .data (on the World
-- Map), a pin list row as .pin (`how`: "data" or "pin"). Its lines while shown.
function S.PinTip(note, zone, from, how)
    local parent = how == "data" and WorldMapFrame or S.pins
    S.pinOwner = S.pinOwner or {}
    local owner = S.pinOwner[how] or CreateFrame("Button", nil, parent)
    S.pinOwner[how] = owner
    owner.data, owner.pin = nil, nil
    owner[how] = { note = note, map = 1, from = from }
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    local lines = { note ~= "" and note or L["Map pin"], ("%s  %.1f, %.1f"):format(zone, 45.2, 30.1),
        L["Shared by %s"]:format(from) }
    for i, t in ipairs(lines) do
        GameTooltip:AddLine(t)
        local fs = _G["GameTooltipTextLeft" .. i]
        fs:SetFont(STANDARD_TEXT_FONT, 12, "")
        fs:SetText(t)
        fs:Show()
    end
    GameTooltip:Show()
    local out = {}
    for i = 1, #lines do out[i] = _G["GameTooltipTextLeft" .. i]:GetText() end
    GameTooltip:Hide()
    return out
end
