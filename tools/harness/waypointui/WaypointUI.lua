-- Not Waypoint UI: a small stand-in for tools/harness/flow_wp.py (UADD_WaypointUI). It has only the parts the
-- module touches, built the way the installed addon builds them:
--   * the ui-kit Text: a frame with a child font string (frame.__Text). Its SetText calls the raw font string
--     method kept at load, fits the frame (FitContent), then fires the frame event "OnTextChanged";
--     SetFormattedText fires "OnFormattedTextChanged". HookEvent adds a handler once.
--   * the roots: WUIWaypointFrame (its Footer: InfoText, DistanceText, ArrivalTimeText), WUIPinpointFrame,
--     WUINavigatorFrame, WUISharedPrompt, WUISharedInputPrompt, WUISettingFrame (built on its first show; a
--     tab adds Text frames later).
--   * its font objects: WUIFooterFont, WUIPinpointFont and the ui-font ones (WaypointUIFont_<n>, not global),
--     with SetFontFile / SetFontFlags that call SetFont, and FontHandler.UpdateFonts.
-- It holds no English of Waypoint UI's: the flow gives the texts (WaypointUIStandInFeed), read from the installed
-- addon at test time. With no feed (flow_focus, chaos) it shows made-up words.
local feed = rawget(_G, "WaypointUIStandInFeed") or {}
local missing = feed.missing or {}
local S = { texts = {}, fonts = { ui = {} }, throw = nil, fits = 0, built = 0 }
WaypointUIStandIn = S

local probe = UIParent:CreateFontString()
local Method_SetText = probe.SetText             -- the raw method, kept at load as the ui-kit does
probe:Hide()

-- throw: "fit" fails in FitContent after the text is drawn, "set" fails before; only for a text with
-- non-ASCII bytes, so the addon's own English always works and only another text trips it.
local function Odd(t) return type(t) == "string" and t:find("[\128-\255]") ~= nil end

local TextMixin = {}
function TextMixin:HookEvent(event, func)
    local r = self.uk_eventRegistry
    r[event] = r[event] or {}
    for _, f in ipairs(r[event]) do if f == func then return end end
    table.insert(r[event], func)
end
function TextMixin:TriggerEvent(event, ...)
    local list = self.uk_eventRegistry[event]
    if not list then return end
    for i = 1, #list do list[i](self, ...) end
end
function TextMixin:FitContent()
    S.fits = S.fits + 1
    if S.throw == "fit" and Odd(self.__Text:GetText()) then error("stand-in: FitContent failed") end
end
function TextMixin:SetText(...)
    if S.throw == "set" and Odd((...)) then error("stand-in: SetText failed") end
    Method_SetText(self.__Text, ...)
    self:FitContent()
    self:TriggerEvent("OnTextChanged", ...)
end
function TextMixin:SetFormattedText(...)
    self.__Text:SetFormattedText(...)
    self:FitContent()
    self:TriggerEvent("OnFormattedTextChanged", ...)
end
function TextMixin:GetText() return self.__Text:GetText() end

local function NewText(parent, font, text, name)
    local f = CreateFrame("Frame", nil, parent)
    f.uk_eventRegistry = {}
    for k, v in pairs(TextMixin) do f[k] = v end
    f.__Text = f:CreateFontString()
    f.__Text:SetFontObject(font)
    if text then f:SetText(text) end
    if name then S.texts[name] = f end
    return f
end
S.NewText = NewText

-- ── Fonts (Fonts.lua, packages/ui-font) ──────────────────────────────────────────────────────────
local FontObjectMixin = {}
function FontObjectMixin:SetFontFile(path)
    local _, height, flags = self:GetFont()
    self:SetFont(path, height, flags)
end
function FontObjectMixin:SetFontFlags(flags)
    local path, height = self:GetFont()
    self:SetFont(path, height, flags)
end

local function NewFont(name, size, global)
    local o = CreateFont(name)
    for k, v in pairs(FontObjectMixin) do o[k] = v end
    o:SetFont((GameFontNormal:GetFont()), size, "")
    if not global then _G[name] = nil end
    return o
end
S.fonts.footer = NewFont("WUIFooterFont", 8, true)
S.fonts.pinpoint = NewFont("WUIPinpointFont", 10, true)
for i = 1, 3 do S.fonts.ui[i] = NewFont("WaypointUIFont_" .. i, 8 + 2 * i) end

-- Its settings' font choice (nil: the game font) and the two outline settings.
FontHandler = { fontPath = nil, footerFlags = "", pinpointFlags = "" }
function FontHandler.UpdateFonts()
    local p = FontHandler.fontPath or (GameFontNormal:GetFont())
    S.fonts.footer:SetFontFile(p)
    S.fonts.footer:SetFontFlags(FontHandler.footerFlags)
    S.fonts.pinpoint:SetFontFile(p)
    S.fonts.pinpoint:SetFontFlags(FontHandler.pinpointFlags)
    for _, o in ipairs(S.fonts.ui) do o:SetFontFile(p) end
end

-- ── Roots ────────────────────────────────────────────────────────────────────────────────────────
local function Root(name)
    if missing[name] then return nil end
    return CreateFrame("Frame", name, UIParent)
end

local wp = Root("WUIWaypointFrame")
if wp then
    wp.Footer = CreateFrame("Frame", nil, wp)
    wp.Footer.InfoText = NewText(wp.Footer, S.fonts.footer, feed.info or "Zorp", "info")
    wp.Footer.DistanceText = NewText(wp.Footer, S.fonts.footer, "12 yds", "dist")
    wp.Footer.ArrivalTimeText = NewText(wp.Footer, S.fonts.footer, "12s", "time")
end
-- One tick of the waypoint: distance and arrival time, both set every time, as its OnUpdate does.
function S.Tick(dist, time)
    wp.Footer.DistanceText:SetText(dist)
    wp.Footer.ArrivalTimeText:SetText(time)
end

local pin = Root("WUIPinpointFrame")
if pin then NewText(CreateFrame("Frame", nil, pin), S.fonts.pinpoint, feed.pin or "Zorp\nBlatter", "pin") end
local nav = Root("WUINavigatorFrame")
if nav then NewText(nav, S.fonts.ui[1], feed.nav or "Zorp", "nav") end

local prompt = Root("WUISharedPrompt")
if prompt then
    NewText(prompt, S.fonts.ui[2], nil, "prompt")
    local b = CreateFrame("Button", nil, prompt)
    NewText(b, S.fonts.ui[1], feed.button or "Zorp", "button")
end
-- Its replace prompt: the template filled with the name of what would be replaced.
function S.Prompt(template, name)
    S.texts.prompt:SetText(template:format(name))
    prompt:Show()
end

local input = Root("WUISharedInputPrompt")
if input then
    NewText(input, S.fonts.ui[2], feed.input or "Zorp", "input")
    -- Frames that look like a Text but are not whole: no font string, one with no GetText, one that throws.
    local odd = { { __Text = nil }, { __Text = {} }, { __Text = { GetText = function() error("stand-in: odd") end } } }
    for _, o in ipairs(odd) do
        local f = CreateFrame("Frame", nil, input)
        f.HookEvent, f.SetText, f.__Text = TextMixin.HookEvent, function() end, o.__Text
        f.uk_eventRegistry = {}
    end
end

-- Settings: made on the first show (its own OnShow runs before any hook added later); S.Tab adds a page.
local settings = Root("WUISettingFrame")
if settings then
    settings:Hide()
    settings.Content = CreateFrame("Frame", nil, settings)
    settings:SetScript("OnShow", function(self)
        if S.built > 0 then return end
        S.built = 1
        for i, en in ipairs(feed.settings or { "Zorp", "Blatter" }) do
            local row = CreateFrame("Frame", nil, CreateFrame("Frame", nil, self.Content))
            NewText(row, S.fonts.ui[(i % 3) + 1], en, "set" .. i)
        end
        NewText(self.Content, S.fonts.ui[3], feed.setUnits or "250 m", "setUnits")
    end)
end
function S.Tab(en, key)
    local page = CreateFrame("Frame", nil, settings.Content)
    return NewText(CreateFrame("Frame", nil, page), S.fonts.ui[1], en, key)
end
function S.OpenSettings() settings:Show() end
function S.CloseSettings() settings:Hide() end
