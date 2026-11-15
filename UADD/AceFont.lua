-- Our Cyrillic font on single FontStrings, with the old font kept and put back exactly; and on
-- that base, the options windows that AceConfigDialog builds for one addon (by its appName).
--
-- Why: the client's standard fonts (GameFontHighlightSmall, GameFontNormalSmall, ...) have no
-- "і", "ї", "є", "ґ" on an English client, so Ukrainian words show boxes. Shared font objects are
-- never changed: only the one FontString gets our font file, at the same size and flags.
--
-- AceGUI keeps released widgets in a pool and gives them to any addon's window. So:
--   * after AceConfigDialog:FeedGroup(appName, ...) for an app we serve, every widget it made
--     (check boxes, headings, buttons, labels, a dropdown's label and its selected value, the tree
--     and tab buttons, the window title) gets our font on each FontString that shows Cyrillic;
--   * the lists of its dropdowns get it when one opens (AceGUI:SetFocus, called right after);
--   * a widget's old fonts go back exactly when it is released (AceGUI:Release), when its text has no
--     Cyrillic any more (SetText, SetLabel, ...), and on Stop(appName) ("/uadd ... off");
--   * if someone sets a font on such a FontString while it still shows our text, ours goes back on.
-- Nothing is put on in combat and nothing runs per frame. The hooks cannot be removed; with the
-- app off they only put fonts back.

local A = {}
UADD.AceFont = A

local CYR = "[\208-\210]"   -- the first byte of a Cyrillic letter in UTF-8 (А-я, і, ї, є, ґ)
local rec = {}              -- FontString -> { path, size, flags, object, app, widget }: its font before ours
local hookedFs = {}         -- FontString -> true once its SetFont and SetFontObject are hooked
local hookedW = {}          -- AceGUI widget -> true once its text setters are hooked
local apps = {}             -- appName -> function: true while we serve that app
local busy = false          -- up while we set a font ourselves
local focusHooked, feedHooked, releaseHooked

local function InCombat() return InCombatLockdown and InCombatLockdown() end
local function HasCyr(fs)
    local t = UADD.Plain(fs:GetText())
    return type(t) == "string" and t:find(CYR) ~= nil
end

local ApplyWidget

local function OnFont(fs)
    if busy then return end
    local r = rec[fs]
    rec[fs] = nil                                    -- their font now: nothing of ours to put back
    if not r or not r.widget or InCombat() then return end
    if type(r.widget) == "function" then UADD.SafeCall(r.widget, fs) else UADD.SafeCall(ApplyWidget, r.widget) end
end

-- Our font file on one FontString, same size and flags; its own font is kept to put back.
-- `app` names the owner (for Stop and Count); `widget`, when given, gets ours back after a reset:
-- an AceGUI widget, or a function(fs) that decides again for that one FontString.
function A.Set(fs, app, widget)
    local path = UADD.CyrFontPath and UADD.CyrFontPath()
    if not path or type(fs) ~= "table" or not fs.GetFont then return end
    if not hookedFs[fs] then
        hookedFs[fs] = true
        hooksecurefunc(fs, "SetFont", OnFont)
        hooksecurefunc(fs, "SetFontObject", OnFont)
    end
    local p, size, flags = fs:GetFont()
    if not p or UADD.IsCyrFont(p) then return end    -- ours already, or a font with our letters
    rec[fs] = { path = p, size = size, flags = flags, object = fs:GetFontObject(), app = app, widget = widget }
    busy = true
    local ok = pcall(fs.SetFont, fs, path, size or 12, flags or "")
    busy = false
    if not ok then rec[fs] = nil end
end

-- One FontString's own font back, exactly: the font object, then the file, size and flags (only
-- when they differ, so a font that was only inherited is not pinned). The colour is kept.
function A.Back(fs)
    local old = fs and rec[fs]
    if not old then return end
    rec[fs] = nil
    busy = true
    pcall(function()
        if old.object and fs:GetFontObject() ~= old.object then
            local r, g, b, a = fs:GetTextColor()
            fs:SetFontObject(old.object)
            if r then fs:SetTextColor(r, g, b, a) end
        end
        local p, size, flags = fs:GetFont()
        if p ~= old.path or size ~= old.size or flags ~= old.flags then
            fs:SetFont(old.path, old.size, old.flags)
        end
    end)
    busy = false
end

-- Every font of `app` back.
function A.Stop(app)
    for fs, r in pairs(rec) do
        if r.app == app then A.Back(fs) end
    end
end

-- For the checks: the font one FontString had before ours (path, size, flags, font object), or nil.
function A.Original(fs)
    local r = rec[fs]
    if r then return r.path, r.size, r.flags, r.object end
end

-- For the status lines and the checks: FontStrings of `app` in our font now; with `kind`, only
-- those of widgets whose AceGUI type matches it (a Lua pattern).
function A.Count(app, kind)
    local n = 0
    for fs, r in pairs(rec) do
        local w = r.widget
        if r.app == app and UADD.IsCyrFont((fs:GetFont()))
            and (not kind or type(w) == "table" and type(w.type) == "string" and w.type:find(kind)) then
            n = n + 1
        end
    end
    return n
end

-- ── AceConfigDialog windows ───────────────────────────────────────────────────────────────────

local function IsFs(v)
    return type(v) == "table" and type(v.GetObjectType) == "function" and v:GetObjectType() == "FontString"
end

-- The app a widget belongs to (a dropdown item: its dropdown's), while we serve it; else nil.
local function AppOf(w)
    local u = type(w) == "table" and rawget(w, "userdata")
    if type(u) ~= "table" then return nil end
    local name = u.appName
    if not name and type(u.obj) == "table" and type(u.obj.userdata) == "table" then name = u.obj.userdata.appName end
    local on = name and apps[name]
    return on and on() and name or nil
end

-- The FontStrings a widget owns: its fields, and the text of its tree or tab buttons.
local function Strings(w)
    local out = {}
    for _, v in pairs(w) do if IsFs(v) then out[#out + 1] = v end end
    for _, key in ipairs({ "buttons", "tabs" }) do
        for _, b in ipairs(type(rawget(w, key)) == "table" and w[key] or {}) do
            local fs = type(b) == "table" and (IsFs(b.text) and b.text or b.GetFontString and b:GetFontString())
            if IsFs(fs) then out[#out + 1] = fs end
        end
    end
    return out
end

local function Release(w)
    for _, fs in ipairs(Strings(w)) do A.Back(fs) end
end

local SETTERS = { "SetText", "SetLabel", "SetTitle", "SetValue", "RefreshTree", "BuildTabs" }

local function HookWidget(w)
    if hookedW[w] then return end
    hookedW[w] = true
    for _, name in ipairs(SETTERS) do
        if type(w[name]) == "function" then
            hooksecurefunc(w, name, function(self) UADD.SafeCall(ApplyWidget, self) end)
        end
    end
end

-- One widget as it should be now: ours on its Cyrillic texts while we serve its app, its own else.
ApplyWidget = function(w)
    local app = AppOf(w)
    if not app then return Release(w) end
    if InCombat() then return end
    HookWidget(w)
    for _, fs in ipairs(Strings(w)) do
        if HasCyr(fs) then A.Set(fs, app, w) else A.Back(fs) end
    end
end

local function Walk(w, depth)
    if type(w) ~= "table" or depth > 30 then return end
    ApplyWidget(w)
    for _, c in ipairs(type(rawget(w, "children")) == "table" and w.children or {}) do Walk(c, depth + 1) end
end

-- AceGUI:SetFocus(widget): a dropdown calls it right after it opened its list.
local function OnFocus(widget)
    if InCombat() or not AppOf(widget) or not widget.open then return end
    local list = type(widget.pullout) == "table" and widget.pullout.items
    for _, item in ipairs(type(list) == "table" and list or {}) do
        if type(item) == "table" then ApplyWidget(item) end
    end
end

-- Hooks AceGUI:SetFocus, AceGUI:Release and AceConfigDialog:FeedGroup, again if a newer library
-- replaced them. Release, not each widget's OnRelease: some widgets (CheckBox, Heading) have none.
function A.Hook()
    local okG, gui = pcall(LibStub, "AceGUI-3.0", true)
    if okG and type(gui) == "table" and type(gui.SetFocus) == "function" and gui.SetFocus ~= focusHooked then
        hooksecurefunc(gui, "SetFocus", function(_, widget) UADD.SafeCall(OnFocus, widget) end)
        focusHooked = gui.SetFocus
    end
    if okG and type(gui) == "table" and type(gui.Release) == "function" and gui.Release ~= releaseHooked then
        hooksecurefunc(gui, "Release", function(_, widget)
            if type(widget) == "table" then UADD.SafeCall(Release, widget) end
        end)
        releaseHooked = gui.Release
    end
    local okD, acd = pcall(LibStub, "AceConfigDialog-3.0", true)
    if okD and type(acd) == "table" and type(acd.FeedGroup) == "function" and acd.FeedGroup ~= feedHooked then
        hooksecurefunc(acd, "FeedGroup", function(_, appName, _, container)
            if apps[appName] then UADD.SafeCall(Walk, container, 0) end
        end)
        feedHooked = acd.FeedGroup
    end
end

-- Serve `appName`'s AceConfigDialog windows while `isOn()` is true.
function A.Register(appName, isOn)
    apps[appName] = isOn
    if LibStub then A.Hook() end
end
