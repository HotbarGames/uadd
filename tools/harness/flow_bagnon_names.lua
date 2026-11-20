-- Lua helpers for flow_bagnon_names.py: the parts of Bagnon that show the game's own words, shaped like
-- BagBrother where UADD_Bagnon/Game.lua touches them (our code, no Bagnon text). Reached as HARNESS.bgnNames.
--   * N.core(), right after the Bagnon stand-in's files: the game's words (global strings), the frame registry
--     as BagBrother's frames.lua has it (entries with a name; a window takes its entry's place when made), and
--     in each window a search button, a money line and a title bar with tooltips built as its tipped.lua does.
--   * N.config(), right after the Bagnon_Config stand-in's files: the frame settings page reads the frame names,
--     the "Display" header and the "Never" choice each time it shows (frameOptions.lua, optionsPanel.lua).
--   * N.stub(), right after UADD's files: a stand-in for UALL Forever's answers (UADD.UALL.Text).
local H = HARNESS
local N = { names = {}, later = {}, asked = {} }
H.bgnNames = N
local NAME = "Bagnon"

SEARCH, DISPLAY, NEVER, ALWAYS, OPTIONS = "Search", "Display", "Never", "Always", "Options"
INVENTORY_TOOLTIP, BANK = "Inventory", "Bank"
local MARK = { ["|L"] = "|A:NPE_LeftClick:14:14|a", ["|R"] = "|A:NPE_RightClick:14:14|a" }
local function Markup(s) return (s:gsub("(%|%u+)", MARK)) end

local function Text(parent)
    local fs = parent:CreateFontString(nil, "ARTWORK")
    fs:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    return fs
end

local function Tip(owner, lines)
    local t = GameTooltip
    t:SetOwner(owner, "ANCHOR_RIGHT")
    for i, s in ipairs(lines) do
        t:AddLine(s)
        local fs = _G["GameTooltipTextLeft" .. i]
        fs:SetText(s)
        fs:Show()
    end
    t:Show()
end

function N.stub()
    UADD.UALL.Text = function(en)
        N.asked[en] = (N.asked[en] or 0) + 1
        if N.later[en] then return nil, true end
        return N.names[en]
    end
end
function N.say(en, uk, later) N.names[en] = uk N.later[en] = later or nil end

function N.core()
    local A = rawget(_G, NAME)
    local F, L = A.Frames, LibStub("AceLocale-3.0"):GetLocale(NAME)
    F.Registry = { { id = "inventory", name = INVENTORY_TOOLTIP }, { id = "bank", name = BANK } }
    local new = F.New
    function F:Get(id) for i, f in ipairs(self.Registry) do if f.id == id then return f, i end end end
    function F:New(id)
        local e, i = self:Get(id)
        local f = new(self, id)
        table.remove(self.Registry)
        f.name = e and e.name
        if i then self.Registry[i] = f else table.insert(self.Registry, f) end
        f.Search, f.Money = CreateFrame("Button", nil, f), CreateFrame("Button", nil, f)
        f.Search:SetScript("OnEnter", function(self) Tip(self, { SEARCH }) end)
        f.Money:SetScript("OnEnter", function(self) Tip(self, { MONEY, "Quix 12g" }) end)
        f.Title:SetScript("OnEnter", function(self)
            Tip(self, { self.text:GetText(), Markup(format("|L %s   |L|L %s", L.Drag, SEARCH)), Markup("|R " .. OPTIONS) })
        end)
        return f
    end
    function F:Show(id)
        local f = self:Get(id)
        if not (f and rawget(f, 0)) then f = self:New(id) end
        f:Show()
        return f
    end
    function F:Update() for _, f in ipairs(self.Registry) do if f.Update then f:Update() end end end
end

function N.config()
    local p = rawget(_G, NAME).FrameOptions
    p.frameFs, p.header, p.choiceFs = Text(p), Text(p), Text(p)
    function p:Add(class, text)
        if class == "Header" then self.header:SetText(text) end
        return {}
    end
    function p:AddChoice(data)
        self.choices = {}
        for i, e in ipairs(data) do self.choices[i] = e.text end
        self.choiceFs:SetText(data[1].text)
    end
    function p:Populate()
        self:Add("DropChoice", "Frame")
        self.frameNames = {}
        for i, f in ipairs(rawget(_G, NAME).Frames.Registry) do self.frameNames[i] = f.name end
        self.frameFs:SetText(self.frameNames[1])
        self:Add("Header", DISPLAY)
        self:AddChoice({ arg = "bagBreak", { key = 0, text = NEVER }, { key = 2, text = ALWAYS } })
    end
    local upd = p.UpdateChildren
    p.UpdateChildren = function(self, ...) upd(self, ...) self:Populate() end
end

-- What the player sees.
local function A() return rawget(_G, NAME) end
function N.frameNames()
    local out = {}
    for i, f in ipairs(A().Frames.Registry) do out[i] = f.name end
    return out
end
function N.page()
    local p = A().FrameOptions
    p:Hide() p:Show()
    return { frames = p.frameFs:GetText(), header = p.header:GetText(), never = p.choiceFs:GetText(),
             always = p.choices and p.choices[2] }
end
function N.helpTitle() return A().Help.title end
function N.conf(k)
    local t = LibStub("AceLocale-3.0").apps["Bagnon_Config"]
    return t and rawget(t, k)
end
function N.hover(what)
    local f = A().Frames:Show("inventory")
    local b = what == "title" and f.Title or f[what]
    b:GetScript("OnEnter")(b)
    local out = {}
    for i = 1, GameTooltip:NumLines() do out[i] = _G["GameTooltipTextLeft" .. i]:GetText() end
    return out
end
