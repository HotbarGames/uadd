-- Not Mastercraft: its window's language button and list, for tools/harness/flow_mc_lang.py. None of
-- Mastercraft's code or words: only the shape UADD_Mastercraft/Language.lua relies on. The flow runs this
-- file before the game starts (Mastercraft.toc is the main stand-in's); the window is made by S.Build().
--   * MastercraftDB.settings.lang: its saved language; only S.SetLanguage writes it (S.writes lists each).
--   * The window: made on first open, hidden, filled, its own OnShow set after it was made, then shown.
--   * The button: .code (a font string), :Paint, .menu (a frame with .rows and :Paint). Each row: .code,
--     .flag, .label, .tick, .hl; a click sets that language, a known code only.
--   * Its font strings (S.texts) show a stand-in "German" (a "[de] " mark) when the language is "de".

local S = { texts = {}, writes = {}, buttons = {} }
MastercraftLangStandIn = S
if type(MastercraftDB) ~= "table" then MastercraftDB = {} end
if type(MastercraftDB.settings) ~= "table" then MastercraftDB.settings = {} end

local PATH = "Fonts\\FRIZQT__.TTF"
local INFO = { en = { code = "EN", name = "English" }, de = { code = "DE", name = "Deutsch" },
    fr = { code = "FR", name = "Fr" }, uk = { code = "UK", name = "Uk" }, zh = { code = "ZH", name = "Zh" } }
local ROW_H, PAD, W = 26, 7, 160
S.INFO, S.ROW_H = INFO, ROW_H
S.zhOK = false                -- a language it knows but cannot draw without its font: it shows English, no row

-- The language it draws in: a code it does not know, or one it cannot draw, is English.
local function Settings() return MastercraftDB.settings end
function S.Lang()
    local l = Settings().lang
    if l == "zh" and not S.zhOK then return "en" end
    return INFO[l] and l or "en"
end
function S.L(t)
    if type(t) == "string" and S.Lang() == "de" then return "[de] " .. t end
    return t
end

-- A font string as Mastercraft makes its own (mcSetText, mcRaw, ...), shown in the current language.
local function Text(parent)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    local set, font = fs.SetText, fs.SetFont
    fs.mcSetText, fs.mcSetFont = set, font
    fs.mcPath, fs.mcSize, fs.mcFlags = PATH, 12, ""
    font(fs, PATH, 12, "")
    fs.SetText = function(self, t)
        rawset(self, "mcRaw", t)
        -- in another language it sets that language's font itself (here: its own, mcPath)
        if S.Lang() ~= "en" and type(t) == "string" then font(self, self.mcPath, self.mcSize, self.mcFlags) end
        return set(self, S.L(t))
    end
    fs.SetFont = function(self, p, s, f)
        self.mcPath, self.mcSize, self.mcFlags = p, s, f or ""
        return font(self, p, s, f)
    end
    return fs
end

-- Like its SetLanguage: a code it knows (else "en"), saved, every font string set again, the button.
function S.SetLanguage(lang)
    lang = INFO[lang] and lang or "en"
    Settings().lang = lang
    S.writes[#S.writes + 1] = lang
    for _, fs in ipairs(S.texts) do
        fs:SetFont(fs.mcPath, fs.mcSize, fs.mcFlags)
        if rawget(fs, "mcRaw") ~= nil then fs:SetText(fs.mcRaw) end
    end
    for _, b in ipairs(S.buttons) do b:Paint() end         -- its LANGUAGE_CHANGED
end

-- Its saved language changed with nothing drawn again (as a setting that is read the next time a text is set).
function S.SaveOnly(lang) Settings().lang = lang end

-- The list. shape: "noPaint" (no menu:Paint), "noCode" (a row's code is not a string).
local function Menu(button, codes, shape)
    local menu = CreateFrame("Frame", nil, button)
    menu:SetSize(W, PAD * 2 + ROW_H * #codes)
    menu:SetPoint("TOPRIGHT", button, "BOTTOMRIGHT", 0, -4)
    menu:Hide()
    menu.rows = {}
    for i, code in ipairs(codes) do
        local r = CreateFrame("Button", nil, menu)
        r:SetSize(W - 10, ROW_H - 2)
        r:SetPoint("TOPLEFT", 5, -(PAD + (i - 1) * ROW_H + 1))
        r.code = (shape == "noCode" and i == 1) and 1 or code
        r.hl = r:CreateTexture(nil, "BACKGROUND")
        r.hl:SetTexture("Interface\\AddOns\\Mastercraft\\media\\row-hl")
        r.hl:SetAllPoints()
        r.hl:SetVertexColor(1, 0.74, 0.36, 0.22)
        r.flag = r:CreateTexture(nil, "ARTWORK")
        r.flag:SetTexture("Interface\\AddOns\\Mastercraft\\media\\flag-" .. code)
        r.flag:SetSize(20, 13)
        r.flag:SetPoint("LEFT", 7, 0)
        r.label = r:CreateFontString(nil, "OVERLAY")
        r.label:SetFont(PATH, 12, "")
        r.label:SetPoint("LEFT", 35, 0)
        r.label:SetText(INFO[code].name)
        r.tick = r:CreateTexture(nil, "OVERLAY")
        r.tick:SetTexture("Interface\\AddOns\\Mastercraft\\media\\check-mark")
        r.tick:SetSize(20, 20)
        r.tick:SetPoint("RIGHT", -6, 0)
        r:SetScript("OnEnter", function(self) menu:Paint(self) end)
        r:SetScript("OnLeave", function() menu:Paint() end)
        r:SetScript("OnClick", function(self)
            menu:Hide()
            if S.Lang() == self.code then return end
            S.SetLanguage(self.code)
        end)
        menu.rows[i] = r
    end
    if shape ~= "noPaint" then
        function menu:Paint(hover)
            local cur = S.Lang()
            for _, r in ipairs(self.rows) do
                local on, lit = r.code == cur, hover == r
                r.tick:SetShown(on)
                r.hl:SetShown(lit)
                if on then r.label:SetTextColor(1, 0.86, 0.45)
                elseif lit then r.label:SetTextColor(1, 0.95, 0.85)
                else r.label:SetTextColor(0.945, 0.898, 0.784) end
            end
        end
    end
    menu:SetScript("OnShow", function(self) if self.Paint then self:Paint() end button:Paint() end)
    menu:SetScript("OnHide", function() button:Paint() end)
    button:SetScript("OnClick", function() menu:SetShown(not menu:IsShown()) end)
    return menu
end

-- The window, as on its first open. opt: texts (English, one font string each), codes, shape.
function S.Build(opt)
    opt = opt or {}
    local frame = CreateFrame("Frame", "MastercraftFrame", UIParent)
    frame:SetSize(940, 580)
    frame:Hide()
    local holder = CreateFrame("Frame", nil, frame)
    S.texts = {}
    for i, raw in ipairs(opt.texts or {}) do
        local fs = Text(holder)
        fs:SetText(raw)
        S.texts[i] = fs
    end
    local lang = CreateFrame("Button", nil, holder)
    lang:SetSize(58, 22)
    lang.code = lang:CreateFontString(nil, "OVERLAY")
    lang.code:SetFont(PATH, 11, "")
    function lang:Paint()
        self.code:SetText(INFO[S.Lang()].code)
    end
    lang.menu = Menu(lang, opt.codes or { "en", "de" }, opt.shape)
    lang:Paint()
    S.buttons[#S.buttons + 1] = lang
    frame:SetScript("OnShow", function() end)      -- its own OnShow, set after the window was made
    S.frame, S.lang = frame, lang
    frame:Show()
    return frame
end

-- Children of the list that are not its rows (an entry someone added).
function S.Extra(menu)
    menu = menu or S.lang.menu
    local rows, out = {}, {}
    for _, r in ipairs(menu.rows) do rows[r] = true end
    for _, k in ipairs({ menu:GetChildren() }) do if not rows[k] then out[#out + 1] = k end end
    return out
end

-- A click the way the game does it: PreClick, OnClick, PostClick.
function S.Click(w)
    for _, s in ipairs({ "PreClick", "OnClick", "PostClick" }) do
        local fn = w:GetScript(s)
        if fn then fn(w, "LeftButton", false) end
    end
end

function S.Row(code)
    for _, r in ipairs(S.lang.menu.rows) do if r.code == code then return r end end
end
