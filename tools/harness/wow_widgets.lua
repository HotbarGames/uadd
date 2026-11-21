-- Harness widgets: CreateFrame and the object methods addons use. Core methods behave like the
-- client (text, colour, font, scripts, events, shown state); any other method is a logged no-op.
-- A method that is missing when OUR code calls it is recorded in HARNESS.ourMissing.
local H = HARNESS

local Widget = {}
H.Widget = Widget
local all = {}           -- every widget, in creation order
local updaters = {}      -- widgets with an OnUpdate script
function H.updaters() local r = {} for f in pairs(updaters) do r[#r + 1] = f end
    table.sort(r, function(a, b) return a.__id < b.__id end) return r end
function H.scriptOf(f, name) return rawget(f, "__scripts") and f.__scripts[name] end
H.unknownMethods = {}

local mt = {}
mt.__index = function(self, k)
    local m = Widget[k]
    if m ~= nil then return m end
    if type(k) ~= "string" or not k:match("^%u") then return nil end
    -- Unknown key: nil, like a field nobody set. Record who asked (a missing method then errors).
    local key = tostring(rawget(self, "__type")) .. ":" .. k
    local ours = H.calledFromOurs(2)
    if ours then H.ourMissing[key] = ours end
    H.unknownMethods[key] = (H.unknownMethods[key] or 0) + 1
    return nil
end
mt.__tostring = function(self) return "widget:" .. tostring(self.__name or self.__type) end

local seq = 0
function H.newWidget(kind, name, parent, template)
    seq = seq + 1
    local w = setmetatable({ __type = kind, __id = seq, __shown = true, __scripts = {}, __events = {},
        __points = {}, __children = {}, __regions = {}, __alpha = 1, __w = 0, __h = 0,
        __level = 1, __strata = "MEDIUM" }, mt)
    w[0] = w                                -- the userdata slot real widgets have
    if type(name) == "string" then
        name = name:gsub("%$parent", parent and parent.__name or "")
        w.__name = name
        rawset(_G, name, w)
    end
    if parent then w:SetParent(parent) end
    all[#all + 1] = w
    if template and H.applyTemplate then H.applyTemplate(w, template) end
    return w
end

-- ── Region basics ─────────────────────────────────────────────────────────────────────────────
function Widget:GetName() return self.__name end
function Widget:GetDebugName() return self.__name or ("<" .. self.__type .. ">") end
function Widget:GetObjectType() return self.__type end
function Widget:IsObjectType(t) return t == self.__type or t == "Frame" or t == "Region" or t == "ScriptObject" end
function Widget:IsForbidden() return false end
function Widget:SetParent(p)
    if self.__parent then self.__parent.__children[self] = nil end
    self.__parent = p
    if p then p.__children[self] = true end
end
function Widget:GetParent() return self.__parent end
function Widget:Show() self.__shown, self.__showed = true, true if self.__scripts.OnShow then H.call("OnShow", self.__scripts.OnShow, self) end end
function Widget:Hide() local was = self.__shown self.__shown = false
    if was and self.__scripts.OnHide then H.call("OnHide", self.__scripts.OnHide, self) end end
function Widget:SetShown(v) if v then self:Show() else self:Hide() end end
function Widget:IsShown() return self.__shown end
function Widget:IsVisible()
    local f = self
    while f do if not f.__shown then return false end f = f.__parent end
    return true
end
function Widget:SetAlpha(a) self.__alpha = a end
function Widget:GetAlpha() return self.__alpha end
function Widget:GetEffectiveAlpha() return self.__alpha end
function Widget:SetWidth(v) self.__w = v end
function Widget:SetHeight(v) self.__h = v end
function Widget:SetSize(w, h) self.__w, self.__h = w, h or w end
function Widget:GetWidth() return self.__w end
function Widget:GetHeight() return self.__h end
function Widget:GetSize() return self.__w, self.__h end
function Widget:SetPoint(...) self.__points[#self.__points + 1] = { ... } end
function Widget:ClearAllPoints() self.__points = {} end
function Widget:GetNumPoints() return #self.__points end
function Widget:GetPoint(i) local p = self.__points[i or 1] if p then return unpack(p) end end
function Widget:SetAllPoints() end
function Widget:GetLeft() return 0 end
function Widget:GetRight() return self.__w end
function Widget:GetTop() return self.__h end
function Widget:GetBottom() return 0 end
function Widget:GetCenter() return self.__w / 2, self.__h / 2 end
function Widget:GetScale() return 1 end
function Widget:GetEffectiveScale() return 1 end
function Widget:SetFrameLevel(v) self.__level = v end
function Widget:GetFrameLevel() return self.__level end
function Widget:SetFrameStrata(v) self.__strata = v end
function Widget:GetFrameStrata() return self.__strata end
function Widget:GetChildren() local r = {} for c in pairs(self.__children) do if c.__type ~= "FontString" and c.__type ~= "Texture" then r[#r + 1] = c end end
    table.sort(r, function(a, b) return a.__id < b.__id end) return unpack(r) end
function Widget:GetRegions() local r = {} for c in pairs(self.__children) do if c.__type == "FontString" or c.__type == "Texture" then r[#r + 1] = c end end
    table.sort(r, function(a, b) return a.__id < b.__id end) return unpack(r) end
function Widget:GetNumChildren() return select("#", self:GetChildren()) end
function Widget:IsMouseOver() return false end
function Widget:SetID(v) self.__idv = v end
function Widget:GetID() return self.__idv or 0 end

-- ── Scripts and events ────────────────────────────────────────────────────────────────────────
function Widget:SetScript(name, fn)
    self.__scripts[name] = fn
    if name == "OnUpdate" then updaters[self] = fn and true or nil end
end
function Widget:GetScript(name) return self.__scripts[name] end
function Widget:HasScript(name) return true end
function Widget:HookScript(name, fn)
    local old = self.__scripts[name]
    if not old then self:SetScript(name, fn) return end
    self:SetScript(name, function(...) old(...) return fn(...) end)
end
function Widget:RegisterEvent(e)
    if type(e) ~= "string" or e == "" then error("RegisterEvent: bad event", 2) end
    self.__events[e] = true H.register(self, e) return true
end
function Widget:RegisterUnitEvent(e) return self:RegisterEvent(e) end
function Widget:UnregisterEvent(e) self.__events[e] = nil H.unregister(self, e) end
function Widget:UnregisterAllEvents() for e in pairs(self.__events) do H.unregister(self, e) end self.__events = {} end
function Widget:RegisterAllEvents() H.allEvents[#H.allEvents + 1] = self end
function Widget:IsEventRegistered(e) return self.__events[e] == true end

-- ── Creating children ─────────────────────────────────────────────────────────────────────────
function Widget:CreateFontString(name, layer, inherits)
    local fs = H.newWidget("FontString", name, self)
    fs.__text, fs.__color = nil, { 1, 0.82, 0, 1 }
    fs.__font = { "Fonts\\FRIZQT__.TTF", 12, "" }
    if inherits and H.applyTemplate then H.applyTemplate(fs, inherits) end
    return fs
end
function Widget:CreateTexture(name) return H.newWidget("Texture", name, self) end
function Widget:CreateMaskTexture(name) return H.newWidget("Texture", name, self) end
function Widget:CreateLine(name) return H.newWidget("Texture", name, self) end
function Widget:CreateAnimationGroup(name) return H.newWidget("AnimationGroup", name, self) end
function Widget:CreateAnimation(kind, name) return H.newWidget("Animation", name, self) end

-- ── Text (FontString, and Buttons through their font string) ─────────────────────────────────
H.textLog = {}           -- { fs, text } of every SetText, for "did our probe leave a trace?"
H.fontFiles = { ["fonts\\frizqt__.ttf"] = true, ["fonts\\frizqt___cyr.ttf"] = true,
    ["fonts\\arialn.ttf"] = true, ["fonts\\skurri.ttf"] = true, ["fonts\\morpheus.ttf"] = true,
    ["fonts\\2002.ttf"] = true }

local function textTarget(self)
    if self.__type == "FontString" or self.__type == "EditBox" then return self end
    if not self.__fs then self.__fs = self:CreateFontString() end
    return self.__fs
end
function Widget:SetText(t)
    local fs = textTarget(self)
    if t ~= nil then t = tostring(t) end
    fs.__text = t
    H.textLog[#H.textLog + 1] = { fs, t }
end
function Widget:GetText() return textTarget(self).__text end
function Widget:ClearText() self:SetText(nil) end
function Widget:SetFormattedText(f, ...) self:SetText(string.format(f, ...)) end
function Widget:SetTextColor(r, g, b, a) textTarget(self).__color = { r, g, b, a or 1 } end
function Widget:GetTextColor() return unpack(textTarget(self).__color or { 1, 1, 1, 1 }) end
function Widget:SetVertexColor(r, g, b, a) self.__vcolor = { r, g, b, a or 1 } end
function Widget:GetVertexColor() return unpack(self.__vcolor or { 1, 1, 1, 1 }) end
function Widget:SetFont(path, size, flags)
    local fs = textTarget(self)
    if type(path) ~= "string" or not H.fontFiles[path:lower()] then return false end
    fs.__font = { path, size, flags or "" }
    return true
end
function Widget:GetFont() local f = textTarget(self).__font if f then return f[1], f[2], f[3] end end
function Widget:SetFontObject(o)
    local fs = textTarget(self)
    if type(o) == "string" then o = rawget(_G, o) end   -- the client takes a font object's name too
    fs.__fontObject = o
    if type(o) == "table" and rawget(o, "__font") then fs.__font = { unpack(o.__font) } end
end
function Widget:GetFontObject() return textTarget(self).__fontObject end
function Widget:CopyFontObject(o) self:SetFontObject(o) end
function Widget:GetStringWidth() local t = textTarget(self).__text return t and #t * 6 or 0 end
function Widget:GetStringHeight() return 12 end
function Widget:GetUnboundedStringWidth() return self:GetStringWidth() end
function Widget:GetNumLines() return 1 end
function Widget:IsTruncated() return false end
function Widget:GetFontString() return textTarget(self) end
function Widget:SetFontString(fs) self.__fs = fs end

-- Window title helpers (PortraitFrameMixin and friends).
function Widget:SetTitle(t) self.__titleFs = self.__titleFs or self:CreateFontString() self.__titleFs:SetText(t) end
function Widget:GetTitleText() self.__titleFs = self.__titleFs or self:CreateFontString() return self.__titleFs end

-- ── Misc. frame kinds ─────────────────────────────────────────────────────────────────────────
function Widget:SetChecked(v) self.__checked = v and true or false end
function Widget:GetChecked() return self.__checked end
function Widget:SetValue(v) self.__value = v end
function Widget:GetValue() return self.__value or 0 end
function Widget:SetMinMaxValues(a, b) self.__min, self.__max = a, b end
function Widget:GetMinMaxValues() return self.__min or 0, self.__max or 1 end
function Widget:IsEnabled() return self.__disabled ~= true end
function Widget:Enable() self.__disabled = false end
function Widget:Disable() self.__disabled = true end
function Widget:SetEnabled(v) self.__disabled = not v end
function Widget:GetNumLines() return 0 end
function Widget:NumLines() return self.__lines or 0 end
function Widget:SetOwner(owner) self.__owner = owner self.__lines = 0 end
function Widget:GetOwner() return self.__owner end
function Widget:ClearLines() self.__lines = 0 end
function Widget:AddLine() self.__lines = (self.__lines or 0) + 1 end
function Widget:AddDoubleLine() self.__lines = (self.__lines or 0) + 1 end
function Widget:IsOwned(f) return self.__owner == f end
-- Questie catches errors in its own coroutines and only prints them (Questie.Error, ThreadLib.lua:120):
-- such a line counts as a Lua error too, or a broken Questie build would pass unseen.
function Widget:AddMessage(msg)
    msg = tostring(msg)
    H.chat[#H.chat + 1] = msg
    if H.secret and H.secret[msg] then return end               -- the client draws a secret line; no string op on it here
    if msg:find("|cffff0000[ERROR]|r", 1, true) then H.errors[#H.errors + 1] = { where = "Questie.Error", msg = msg, tb = "" } end
end
function Widget:Play() end
function Widget:Stop() end
function Widget:IsPlaying() return false end
function Widget:SetToplevel() end
function Widget:SetFixedFrameStrata() end
function Widget:SetFixedFrameLevel() end
function Widget:SetAutoFocus() end
function Widget:SetMultiLine() end
function Widget:SetMaxLetters() end
function Widget:ClearFocus() end
function Widget:SetFocus() end
function Widget:HasFocus() return false end
function Widget:SetMovable() end
function Widget:EnableMouse() end
function Widget:SetClampedToScreen() end
function Widget:RegisterForDrag() end
function Widget:RegisterForClicks() end
function Widget:SetBackdrop() end
function Widget:SetTexture(t) self.__tex = t return true end
function Widget:GetTexture() return self.__tex end
function Widget:SetAtlas(a) self.__atlas = a return true end
function Widget:SetTexCoord() end
function Widget:SetJustifyH() end
function Widget:SetJustifyV() end
function Widget:SetWordWrap() end
function Widget:SetNonSpaceWrap() end
function Widget:SetMaxLines() end
function Widget:SetDrawLayer() end
function Widget:SetBlendMode() end
function Widget:SetDesaturated() end
function Widget:SetColorTexture() end
function Widget:SetHitRectInsets() end

function H.widgets() return all end

-- Font objects: a FontString-like table, global under its name.
function CreateFont(name)
    local f = H.newWidget("Font", name)
    f.__font, f.__color = { "Fonts\\FRIZQT__.TTF", 12, "" }, { 1, 1, 1, 1 }
    f.__fs = f
    -- In the client a font object's SetFont gives back nothing, even when the file took:
    -- only GetFont tells. (A FontString's SetFont here still says true or false.)
    f.SetFont = function(self, path, size, flags) Widget.SetFont(self, path, size, flags) end
    return f
end

H.frameTypes = { Frame = 1, Button = 1, CheckButton = 1, EditBox = 1, ScrollFrame = 1, Slider = 1,
    StatusBar = 1, GameTooltip = 1, MessageFrame = 1, ScrollingMessageFrame = 1, Cooldown = 1,
    Model = 1, PlayerModel = 1, DressUpModel = 1, ModelScene = 1, ColorSelect = 1, SimpleHTML = 1,
    Minimap = 1, MovieFrame = 1, Browser = 1, OffScreenFrame = 1, FogOfWarFrame = 1, UnitPositionFrame = 1 }

function CreateFrame(kind, name, parent, template, id)
    for k in pairs(H.frameTypes) do if type(kind) == "string" and k:lower() == kind:lower() then kind = k end end
    if type(kind) ~= "string" or not H.frameTypes[kind] then
        error("CreateFrame: Unknown frame type '" .. tostring(kind) .. "'", 2)
    end
    local f = H.newWidget(kind, name, parent, template)
    if id then f:SetID(id) end
    return f
end
