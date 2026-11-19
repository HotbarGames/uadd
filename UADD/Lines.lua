-- UADD: our words on the tooltip lines and chat lines one addon adds, each line whole (UADD/Words.lua).
-- Shared by the modules that find whole lines (UADD_WhatsTraining; UADD_Mastercraft keeps its own copy).
--
-- U.TipLines(o) -> { Install, Restore, Count }. o.tips: the game's tooltips (by name) the addon adds
-- lines to; o.own: the addon's own tooltip frames (by name), where every line is the addon's; o.from: a
-- pattern its files match in debugstack ("AddOns[/\\]WhatsTraining[/\\]"); o.words (U.NewWords);
-- o.wanted(): our words now?; o.missed: the U.Missed key.
--   * Post-hooks on AddLine, AddDoubleLine and SetText. A line changes only when we have Ukrainian for
--     it and (on the game's tooltips) the call came from the addon's code: the stack is looked at only
--     then, so a line of the game or another addon that reads the same stays as it is.
--   * That line gets UADD's Cyrillic font at its size (read back, lesson 2); the tooltip's own font comes
--     back when it is cleared. No Cyrillic font: the line stays English (no boxes).
--   * Off or the hold key: new lines stay English (a tooltip already shown changes when shown again).
--
-- U.ChatLines(o) -> { Install, Restore, Count, Wrapped }. The main chat window's AddMessage is wrapped
-- once. A line changes when it starts with o.prefix (kept, the rest translated) or, with no prefix, when
-- we have Ukrainian for the whole line and the call came from o.from. "Off" puts the game's own back
-- when nobody wrapped it after us (otherwise the wrapper stays and lets every line through as it is).

local U = UADD
local CYR = "[\208-\210]"

local function From(pattern)
    local ok, st = pcall(debugstack, 3, 14, 0)
    if not ok or type(st) ~= "string" then return false end
    return st:find(pattern) ~= nil
end
U.CalledFrom = From

function U.TipLines(o)
    local T, W = {}, o.words
    local changed, hookedTip, own, count = {}, {}, {}, 0

    local function Line(tip, side, i)
        local name = tip.GetName and tip:GetName()
        return name and _G[name .. "Text" .. side .. i] or nil
    end

    local function Put(tip, fs, uk)
        if not fs or not U.Plain(uk) then return end
        if not uk:find(CYR) then fs:SetText(uk) return end
        local path = U.CyrFontPath()
        local p, s, f = fs:GetFont()
        if not path or not s then return end
        changed[tip] = changed[tip] or {}
        if not changed[tip][fs] then changed[tip][fs] = { p, s, f } end
        fs:SetFont(path, s, f or "")
        if not U.IsCyrFont((fs:GetFont())) then return end
        fs:SetText(uk)
        count = count + 1
    end

    local function Redo(tip, left, right)
        if not o.wanted() then return end
        left, right = U.Plain(left), U.Plain(right)     -- nil for a secret text: left as it is
        local l = left and W.Translate(left) or nil
        local r = right and W.Translate(right) or nil
        local mine = own[tip]
        if not l and not r then
            if left and U.MissedOn() and left:find("%a%a%a") and (mine or From(o.from)) then
                U.Missed(o.missed, left)
            end
            return
        end
        if not mine and not From(o.from) then return end
        local i = tip:NumLines()
        if l then Put(tip, Line(tip, "Left", i), l) end
        if r then Put(tip, Line(tip, "Right", i), r) end
    end

    local function Cleared(tip)
        local list = changed[tip]
        if not list then return end
        changed[tip] = nil
        for fs, was in pairs(list) do
            if was[1] and was[2] then pcall(fs.SetFont, fs, was[1], was[2], was[3] or "") end
        end
    end

    local function HookTip(tip, mine)
        if type(tip) ~= "table" or not tip.AddLine then return end
        if mine then own[tip] = true end
        if hookedTip[tip] then return end
        hookedTip[tip] = true
        hooksecurefunc(tip, "AddLine", function(self, text) U.SafeCall(Redo, self, text) end)
        hooksecurefunc(tip, "AddDoubleLine", function(self, a, b) U.SafeCall(Redo, self, a, b) end)
        hooksecurefunc(tip, "SetText", function(self, text) U.SafeCall(Redo, self, text) end)
        if tip.HookScript then tip:HookScript("OnTooltipCleared", function(self) U.SafeCall(Cleared, self) end) end
    end

    -- Again after login and when the addon's windows show: its own tooltips can be made late.
    function T.Install()
        for _, name in ipairs(o.tips or {}) do HookTip(rawget(_G, name), false) end
        for _, name in ipairs(o.own or {}) do HookTip(rawget(_G, name), true) end
    end
    function T.Restore() for tip in pairs(changed) do Cleared(tip) end end
    function T.Count() return count end
    return T
end

function U.ChatLines(o)
    local C, W = {}, o.words
    local prefix = o.prefix
    local N = prefix and #prefix or 0
    local frame, orig, count = nil, nil, 0

    local function Wrapped(self, msg, ...)
        if self == frame and type(msg) == "string" and o.wanted() then
            if prefix then
                if msg:sub(1, N) == prefix then
                    local ok, uk = pcall(W.Translate, msg:sub(N + 1))
                    if ok and uk then msg, count = prefix .. uk, count + 1 end
                end
            else
                local ok, uk = pcall(W.Translate, msg)
                if ok and uk and From(o.from) then msg, count = uk, count + 1 end
            end
        end
        return orig(self, msg, ...)
    end
    C.Wrapped = Wrapped

    function C.Install()
        if orig then return end
        local f = DEFAULT_CHAT_FRAME
        if type(f) ~= "table" or type(f.AddMessage) ~= "function" then return end
        frame, orig = f, f.AddMessage
        f.AddMessage = Wrapped
    end

    function C.Restore()
        if orig and frame and rawget(frame, "AddMessage") == Wrapped then
            frame.AddMessage = orig
            frame, orig = nil, nil
        end
    end

    function C.Count() return count end
    return C
end
