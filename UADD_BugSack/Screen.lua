-- UADD - BugSack: its window. Made with its English in (the table swapped back for that one call), then walked:
-- each text of ours on our font, put back when off, only where ours still shows (lesson 23). The session label is
-- turned as a whole line; the text area only its "no bugs" line (an error text stays as it is); option tooltips
-- (made while its table was English) turned when shown. Edit boxes are never walked (lesson 13).

local _, ns = ...
local U = UADD
local CYR = ns.CYR
local EN, UK, ENL, H, T = ns.EN, ns.UK, ns.ENL, ns.H, ns.AL
local Guard = ns.Guard
local DEPTH = 8

-- ── Fonts: ours on a text that shows our words, its own back after ──────────────────────────

local saved = {}
local function CyrOn(fs)
    local path = U.CyrFontPath()
    local _, s, f = fs:GetFont()
    if not path or not s then return false end
    if not saved[fs] then saved[fs] = U.SaveFont(fs) end
    fs:SetFont(path, s, f or "")
    return U.IsCyrFont((fs:GetFont()))
end
local function FontBack(fs)
    local o = saved[fs]
    if o then saved[fs] = nil U.FontBack(fs, o) end
end
ns.saved, ns.CyrOn, ns.FontBack = saved, CyrOn, FontBack

-- A button sets its label's font object again on a state change: ours again then (lesson 32).
local fhooked = setmetatable({}, { __mode = "k" })
local fixing = false
-- Its own font is saved again only when it set one (ours gone): a hover that left ours on would save ours.
local function Fresh(fs)
    local ok, path = pcall(fs.GetFont, fs)
    if not (ok and U.IsCyrFont(path)) then saved[fs] = nil end
end
local function Refix(fs)
    if fixing then return end
    fixing = true
    local t = U.Plain(fs:GetText())
    if ns.WordsWanted() and t and UK[t] then Fresh(fs) pcall(CyrOn, fs) end
    fixing = false
end
ns.Refix = Refix
local BUTTON_FONT = { "SetNormalFontObject", "SetHighlightFontObject", "SetDisabledFontObject", "Enable", "Disable",
    "SetEnabled", "LockHighlight", "UnlockHighlight" }
local function HookFont(fs, btn)
    if fhooked[fs] then return end
    fhooked[fs] = true
    local fix = Guard(function() ns.Refix(fs) end)
    pcall(hooksecurefunc, fs, "SetFontObject", fix)
    if not btn then return end
    for _, m in ipairs(BUTTON_FONT) do
        if type(btn[m]) == "function" then pcall(hooksecurefunc, btn, m, fix) end
    end
    if btn.HookScript then
        pcall(btn.HookScript, btn, "OnEnter", fix)
        pcall(btn.HookScript, btn, "OnLeave", fix)
    end
end

-- ── The session label ────────────────────────────────────────────────────────────────────────

local sess, sessFs = setmetatable({}, { __mode = "k" }), setmetatable({}, { __mode = "k" })
local inSet = false
local function SetSession(btn, s)
    inSet = true
    pcall(btn.SetText, btn, s)
    inSet = false
end
local function OnSession(btn, text)
    if inSet then return end
    local t = U.Plain(text) or U.Plain(btn:GetText())
    local fs = btn.GetFontString and btn:GetFontString()
    if not t or not fs then return end
    if ns.WordsWanted() then
        local uk = ns.ToUk(t)
        if uk and CyrOn(fs) then SetSession(btn, uk)
        elseif uk then FontBack(fs)
        elseif t:find(CYR) then
            if not CyrOn(fs) then
                local en = ns.ToEn(t)
                if en then SetSession(btn, en) end
                FontBack(fs)
            end
        else FontBack(fs) end
    else
        local en = ns.ToEn(t)
        if en then SetSession(btn, en) end
        FontBack(fs)
    end
end
ns.OnSession = OnSession
local function Session(btn)
    if sess[btn] then return ns.OnSession(btn) end
    if btn.GetName and btn:GetName() then return end
    local t = U.Plain(btn.GetText and btn:GetText())
    local fs = btn.GetFontString and btn:GetFontString()
    if not t or not fs or not ns.SessionShape(t) then return end
    sess[btn], sessFs[fs] = true, true
    hooksecurefunc(btn, "SetText", Guard(function(self, text) ns.OnSession(self, U.Plain(text)) end))
    if btn.HookScript then
        btn:HookScript("OnEnter", Guard(function(self) ns.OnSession(self) end))
        btn:HookScript("OnLeave", Guard(function(self) ns.OnSession(self) end))
    end
    ns.OnSession(btn)
end

-- ── Its text area: only its "no bugs" line is ours; an error text stays as it is ────────────

local taHooked, taBusy = false, false
local function TAFix(ta, text)
    if taBusy then return end
    local uk, en = T["L." .. H.nobugs], ENL[H.nobugs]
    if not uk or not en then return end
    local t = U.Plain(text) or U.Plain(ta:GetText())
    taBusy = true
    if ns.WordsWanted() and (t == uk or t == en) and CyrOn(ta) then
        if t == en then ta:SetText(uk) end
    else
        if t == uk then ta:SetText(en) end
        FontBack(ta)
    end
    taBusy = false
end
ns.TAFix = TAFix
local function TextArea()
    local ta = rawget(_G, ns.TEXT)
    if type(ta) ~= "table" or not ta.GetText or not ta.SetText then return end
    if not taHooked then
        taHooked = true
        hooksecurefunc(ta, "SetText", Guard(function(self, text) ns.TAFix(self, U.Plain(text)) end))
        hooksecurefunc(ta, "SetFontObject", Guard(function(self)
            if taBusy then return end
            saved[self] = nil      -- its own font object now (its font size): ours on top of that one
            ns.TAFix(self)
        end))
    end
    ns.TAFix(ta)
end

-- ── Tooltips its options keep in English (made while its table was English) ─────────────────

local tipHooked = setmetatable({}, { __mode = "k" })
local function Tip(self)
    if not ns.WordsWanted() then return end
    local tt = rawget(_G, "GameTooltip")
    if type(tt) ~= "table" or not tt.GetOwner or tt:GetOwner() ~= self then return end
    local changed = false
    for i = 1, math.min(tt:NumLines() or 0, 30) do
        local line = rawget(_G, "GameTooltipTextLeft" .. i)
        local t = line and U.Plain(line:GetText())
        local uk = t and EN[t]
        if uk then line:SetText(uk) changed = true end
    end
    if changed then tt:Show() end
end
ns.Tip = Tip
local function HookTip(f)
    if tipHooked[f] or not f.HookScript or not f.GetScript then return end
    local ok, has = pcall(f.GetScript, f, "OnEnter")
    if not ok or not has then return end
    tipHooked[f] = true
    f:HookScript("OnEnter", Guard(function(self) ns.Tip(self) end))
end

-- ── Its window ───────────────────────────────────────────────────────────────────────────────

-- Its frames and texts; an edit box is never walked (the filter box holds what the player typed, lesson 13).
local function Walk(f, depth, out, seen)
    if depth > DEPTH or seen[f] then return end
    seen[f] = true
    if f.GetObjectType and f:GetObjectType() == "EditBox" then return end
    out.frames[#out.frames + 1] = f
    for _, r in ipairs(U.Regions(f)) do
        if r.GetObjectType and r:GetObjectType() == "FontString" then out.fs[#out.fs + 1] = { r, f } end
    end
    for _, c in ipairs(U.Children(f)) do Walk(c, depth + 1, out, seen) end
end

local shown = 0
function ns.Shown() return shown end
function ns.Apply(want)
    local w = rawget(_G, ns.FRAME)
    if type(w) ~= "table" then return end
    local out, n = { frames = {}, fs = {} }, 0
    Walk(w, 0, out, {})
    for _, f in ipairs(out.frames) do
        if f.GetObjectType and f:GetObjectType() == "Button" then Session(f) end
        if want then HookTip(f) end
    end
    for _, p in ipairs(out.fs) do
        local fs, owner = p[1], p[2]
        if not sessFs[fs] then
            local now = U.Plain(fs:GetText())
            local btn = owner.GetFontString and owner:GetFontString() == fs and owner or nil
            local set = btn or fs
            if want then
                local uk = now and EN[now]
                if uk and CyrOn(fs) then set:SetText(uk) HookFont(fs, btn) n = n + 1
                elseif now and UK[now] and CyrOn(fs) then HookFont(fs, btn) n = n + 1 end
            else
                local en = now and UK[now]
                if en then set:SetText(en) end
                FontBack(fs)
            end
        end
    end
    shown = n
    TextArea()
end

-- Its window is made on first open: made with its English in, then ours walked on (its tooltips keep the words
-- of that moment, so they are English and turned when shown).
local wrapped = {}
function ns.Wrap(name)
    local A = ns.A
    local orig = type(A) == "table" and A[name]
    if type(orig) ~= "function" or wrapped[name] then return end
    wrapped[name] = orig
    A[name] = function(...)
        if rawget(_G, ns.FRAME) or not ns.AnySwapped() then return orig(...) end
        pcall(ns.Words, false)
        local ok, r1, r2 = pcall(orig, ...)
        U.SafeCall(ns.Sync)
        if not ok then error(r1, 0) end
        return r1, r2
    end
end
