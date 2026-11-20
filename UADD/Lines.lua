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
--   * That line gets UADD's Cyrillic font at its size (read back, lesson 2); the tooltip's own font object
--     comes back when it is cleared (U.FontBack, lesson 18). No Cyrillic font: the line stays English.
--   * Off or the hold key: new lines stay English (a tooltip already shown changes when shown again).
--
-- U.ChatLines(o) -> { Install, Restore, Count, Wrapped }. The main chat window's AddMessage is wrapped
-- once. A line changes when it starts with o.prefix (kept, the rest translated) or, with no prefix, when
-- the call came from o.from and we have Ukrainian for the whole line. The source is looked at first: the
-- game's and other addons' lines never reach Translate or its cache (lesson 12). "Off" puts the game's own back
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
        local _, s, f = fs:GetFont()
        if not path or not s then return end
        changed[tip] = changed[tip] or {}
        if not changed[tip][fs] then changed[tip][fs] = U.SaveFont(fs) end
        fs:SetFont(path, s, f or "")
        if not U.IsCyrFont((fs:GetFont())) then return end
        fs:SetText(uk)
        count = count + 1
    end

    -- On the game's tooltips every line of the game passes here: the source comes before any translate
    -- work (lesson 12). Cheapest first: could it be ours at all (no lookup, no cache growth), then our
    -- words, then the stack (a template can match a unit's name that has no Ukrainian: no stack look then).
    -- Words with no Maybe: no line of the game's tooltips is tried (the worst is an English line; never
    -- every line of the game sent to Translate). The addon's own tooltips are tried as they are.
    local Maybe = W.Maybe or function() return false end
    local function Redo(tip, left, right)
        if not o.wanted() then return end
        left, right = U.Plain(left), U.Plain(right)     -- nil for a secret text: left as it is
        local mine = own[tip]
        local missed = left and U.MissedOn() and left:find("%a%a%a")
        local tryL = left and (mine or Maybe(left))
        local tryR = right and (mine or Maybe(right))
        if not tryL and not tryR and not missed then return end
        local l = tryL and W.Translate(left) or nil
        local r = tryR and W.Translate(right) or nil
        if not l and not r then
            if missed and (mine or From(o.from)) then U.Missed(o.missed, left) end
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
        for fs, was in pairs(list) do pcall(U.FontBack, fs, was) end   -- its font object, not a pinned file
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
    local Maybe = W.Maybe or function() return false end   -- no Maybe: no line without the prefix is tried
    local frame, base, live, count = nil, nil, false, 0   -- base: the AddMessage we wrapped; kept for good

    -- Our Ukrainian for a chat line, or nil. Every chat line of the game passes here: the cheapest tests
    -- first, no stack look for a line that cannot be ours (lesson 12).
    local function Ours(self, msg)
        if self ~= frame or not o.wanted() then return nil end
        if prefix then
            if msg:sub(1, N) ~= prefix then return nil end
            local uk = W.Translate(msg:sub(N + 1))
            if uk then count = count + 1 return prefix .. uk end
            return nil
        end
        if msg:find("|Hplayer", 1, true) or msg:find("|Hchannel", 1, true) or msg:find(CYR) then return nil end
        if not Maybe(msg) or not From(o.from) then return nil end
        local uk = W.Translate(msg)
        if uk then count = count + 1 end
        return uk
    end

    -- Never loses a line: any error, a msg that is not a string, or off passes it on as it came.
    local function Wrapped(self, msg, ...)
        if live and type(msg) == "string" then
            local ok, uk = pcall(Ours, self, msg)
            if ok and type(uk) == "string" then return base(self, uk, ...) end
        end
        return base(self, msg, ...)
    end
    C.Wrapped = Wrapped

    function C.Install()
        live = true
        if frame then return end                  -- wrapped already (maybe under a later wrapper)
        local f = DEFAULT_CHAT_FRAME
        if type(f) ~= "table" or type(f.AddMessage) ~= "function" then live = false return end
        frame, base = f, f.AddMessage
        f.AddMessage = Wrapped
    end

    -- Someone wrapped after us: ours stays under theirs and lets every line through as it is.
    function C.Restore()
        live = false
        if frame and rawget(frame, "AddMessage") == Wrapped then
            frame.AddMessage = base
            frame = nil
        end
    end

    function C.Count() return count end
    return C
end
