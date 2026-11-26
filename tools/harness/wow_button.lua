-- A Button's font object per state, as the client switches them (docs/LESSONS4.md lesson 46).
-- A button keeps a font object for each state: normal, highlight (under the mouse), disabled. On a state change the
-- client puts that state's object on the button's label by itself: no Lua method of the label runs, so no hook of an
-- addon sees it, and under the mouse it comes after the button's OnEnter script. Modelled here:
--   * Set{Normal,Highlight,Disabled}FontObject, Enable, Disable, SetEnabled, LockHighlight, UnlockHighlight and
--     H.hover / H.unhover (the mouse: its script first, then the switch) put the state's object on the label through
--     the class's own SetFontObject: a hand-set file stays (as in the client), boxes.lua still looks.
--   * A state with no object leaves the label's object as it is.
--   * The game's button templates give the states the game's objects, and the label the normal one.
--   * PanelTemplates_SelectTab / DeselectTab / TabResize as the game's (a selected tab is disabled).
--   * H.glyphWidths (a flow sets it): GetUnboundedStringWidth by letters as drawn (a letter the drawn file lacks is a
--     box of one width; on a button's label a font family draws its Latin member, boxes.lua). Off, the old width.
-- Loaded after wow_load.lua (it wraps H.applyTemplate).
local H = HARNESS
local W = H.Widget
local STATES = { "Normal", "Highlight", "Disabled" }
local BIG = { "GameFontNormal", "GameFontHighlight", "GameFontDisable" }
local TAB = { "GameFontNormalSmall", "GameFontHighlightSmall", "GameFontHighlightSmall" }
local SMALL = { "GameFontNormalSmall", "GameFontHighlightSmall", "GameFontDisableSmall" }
local TEMPLATES = { UIPanelButtonTemplate = BIG, UIPanelButtonTemplate2 = BIG, GameMenuButtonTemplate = BIG,
    UIPanelDynamicResizeButtonTemplate = BIG, SharedButtonTemplate = BIG, MagicButtonTemplate = BIG,
    PanelTabButtonTemplate = TAB, CharacterFrameTabButtonTemplate = TAB, TabButtonTemplate = TAB,
    PanelTopTabButtonTemplate = TAB, OptionsButtonTemplate = SMALL, UIMenuButtonStretchTemplate = SMALL }
for name, size in pairs({ GameFontNormal = 12, GameFontHighlight = 12, GameFontDisable = 12, GameFontNormalSmall = 10,
    GameFontHighlightSmall = 10, GameFontDisableSmall = 10 }) do
    if not rawget(_G, name) then CreateFont(name):SetFont("Fonts\\FRIZQT__.TTF", size, "") end
end

local function Want(b)
    if rawget(b, "__disabled") then return rawget(b, "__fontDisabled") end
    if rawget(b, "__over") or rawget(b, "__lit") then return rawget(b, "__fontHighlight") end
    return rawget(b, "__fontNormal")
end
local function Switch(b)
    local fs, o = rawget(b, "__fs"), Want(b)
    if type(fs) == "table" and o ~= nil and rawget(fs, "__fontObject") ~= o then W.SetFontObject(fs, o) end
end
H.buttonSwitch = Switch

for _, s in ipairs(STATES) do
    local set = W["Set" .. s .. "FontObject"]
    W["Set" .. s .. "FontObject"] = function(self, o)
        if type(o) == "string" then o = rawget(_G, o) end
        set(self, o)
        Switch(self)
        if H.boxMark then H.boxMark(self) end
    end
end
for _, m in ipairs({ "Enable", "Disable", "SetEnabled" }) do
    local was = W[m]
    W[m] = function(self, ...)
        local r = { was(self, ...) }
        Switch(self)
        return unpack(r)
    end
end
function W:LockHighlight() rawset(self, "__lit", true) Switch(self) end
function W:UnlockHighlight() rawset(self, "__lit", nil) Switch(self) end

-- The mouse over a button and off it: its OnEnter / OnLeave script, then the client's switch.
local function Mouse(b, over, script)
    rawset(b, "__over", over or nil)
    local fn = b.__scripts and b.__scripts[script]
    if fn then H.call(script .. " (mouse)", fn, b) end
    Switch(b)
end
function H.hover(b) Mouse(b, true, "OnEnter") end
function H.unhover(b) Mouse(b, false, "OnLeave") end

local apply = H.applyTemplate
function H.applyTemplate(w, template)
    apply(w, template)
    if type(template) ~= "string" or (w.__type ~= "Button" and w.__type ~= "CheckButton") then return end
    for part in template:gmatch("[^,%s]+") do
        local st = TEMPLATES[part]
        if st then
            local fs = rawget(w, "__fs") or w:CreateFontString()
            rawset(w, "__fs", fs)
            if part:find("Tab") and rawget(w, "Text") == nil then w.Text = fs end
            for i, s in ipairs(STATES) do rawset(w, "__font" .. s, rawget(_G, st[i])) end
            Switch(w)
            return
        end
    end
end

if rawget(_G, "PanelTemplates_SelectTab") == nil then
    function PanelTemplates_SelectTab(tab)
        tab:Disable()
        tab:SetDisabledFontObject(GameFontHighlightSmall)
    end
    function PanelTemplates_DeselectTab(tab) tab:Enable() end
    -- The tab fitted to the text it shows now (__fitText: which text it was fitted to, for the checks).
    function PanelTemplates_TabResize(tab, padding, absoluteSize, minWidth, maxWidth)
        local t = tab.Text or tab:GetFontString()
        local w = absoluteSize or ((t and t:GetStringWidth() or 0) + (padding or 24))
        if maxWidth and w > maxWidth then w = maxWidth end
        if minWidth and w < minWidth then w = minWidth end
        tab:SetWidth(w + 20)
        rawset(tab, "__fitText", t and t:GetText() or false)
    end
end

-- ── Widths by letters as drawn (H.glyphWidths) ──────────────────────────────────────────────────
local function CyrFile(p)
    p = type(p) == "string" and p:lower():gsub("/", "\\") or ""
    return p:find("_cyr%.ttf$") ~= nil or p:find("\\arialn%.ttf$") ~= nil
end
local WIDE = { ["\209\136"] = true, ["\209\137"] = true, ["\208\182"] = true, ["\209\142"] = true, ["\208\188"] = true,
    ["\208\168"] = true, ["\208\169"] = true, ["\208\150"] = true, ["\208\174"] = true, ["\208\156"] = true }
local NARROW = { ["\209\150"] = true, ["\209\151"] = true, ["\208\134"] = true, ["\208\135"] = true }
-- Does the font this text is drawn in now have Cyrillic letters?
local function DrawsCyr(fs)
    local f = rawget(fs, "__font")
    local path = type(f) == "table" and f[1]
    if CyrFile(path) then return true end
    if rawget(fs, "__hand") then return false end
    local p = rawget(fs, "__parent")
    local label = type(p) == "table" and rawget(p, "__fs") == fs
    local family = H.boxFamily
    return not label and family ~= nil and family(rawget(fs, "__fontObject")) or false
end
H.drawsCyr = DrawsCyr
local old = W.GetUnboundedStringWidth
function W:GetUnboundedStringWidth()
    if not H.glyphWidths then return old(self) end
    local fs = rawget(self, "__fs") or self
    local t = rawget(fs, "__text")
    if type(t) ~= "string" then return 0 end
    t = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local f = rawget(fs, "__font")
    local scale, cyr, w = (type(f) == "table" and tonumber(f[2]) or 12) / 12, DrawsCyr(fs), 0
    for ch in t:gmatch("[%z\1-\127\192-\255][\128-\191]*") do
        if #ch == 1 then
            w = w + ((ch == "i" or ch == "l" or ch == " ") and 3 or (ch == "W" or ch == "M") and 11 or 6)
        elseif ch:find("^[\208\209\210]") then
            w = w + (not cyr and 9 or NARROW[ch] and 3 or WIDE[ch] and 9 or 6.5)
        else
            w = w + 6
        end
    end
    return w * scale
end
