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
-- U.ChatHook(o): the one wrap of the main chat window's AddMessage, shared by every module (below).
-- U.ChatLines(o) -> { Install, Restore, Count, Active }, on U.ChatHook. A line changes when it starts with
-- o.prefix (kept, the rest translated) or, with no prefix, when the call came from o.from and we have
-- Ukrainian for the whole line. The cheap tests come first: the game's and other addons' lines never reach
-- Translate or its cache (lesson 12).

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

-- U.ChatHook(o) -> { Start, Stop, Active, Count }: the one wrap of the main chat window's AddMessage that
-- every module shares (lesson 35). A chat line reaches o.line(msg) only when a cheap test says it may be
-- ours: one of o.marks (a string at byte 1, or { text, at }) is there, or o.maybe(msg) is true (no Translate
-- in it). o.line returns the new line, or nil / msg to leave it. Every chat line of the game passes here
-- (a BG floods it): a byte and a plain compare per mark, nothing else for a line that is not ours.
--   * Each o.line runs under U.SafeCall: an error is reported and counted (lesson 19), the line goes on as it
--     came. A line is passed on exactly once, also when our code fails; a line our own report prints is
--     passed through as it is.
--   * The wrap goes on with the first Start and comes off when no hook is on and nobody wrapped after us
--     (otherwise it stays in their chain and lets every line through as it is).
--   * In an instance (a BG) the wrap is off: the field we set taints the game's chat path, and there every
--     line is secret, so the game's own compares throw "tainted by UADD". Our lines stay English there. It
--     goes on again outside (PLAYER_ENTERING_WORLD, ZONE_CHANGED_NEW_AREA). Wrapped after us: we pass all.
local hooks, nLive = {}, 0
local chat, had, base, busy = nil, nil, nil, false     -- had: the frame's own field (nil: its method)
local inside = false                                     -- in an instance: no wrap, no line of ours
local byte, sub = string.byte, string.sub

local function InInstance()
    local f = rawget(_G, "IsInInstance")
    if type(f) ~= "function" then return false end
    local ok, yes = pcall(f)
    return ok and (yes == true or yes == 1)
end
U.InInstance = InInstance                                -- also the print handler's gate (UADD/Print.lua)

local function Could(h, msg)
    local m = h.marks
    for i = 1, #m do
        local k = m[i]
        if byte(msg, k.at) == k.b and sub(msg, k.at, k.to) == k.text then return true end
    end
    if not h.maybe then return false end
    local ok, yes = pcall(h.maybe, msg)
    return ok and yes == true
end

local function Pick(msg)
    if not U.Plain(msg) then return nil end
    for i = 1, #hooks do
        local h = hooks[i]
        if h.live and Could(h, msg) then
            local ok, out = U.SafeCall(h.line, msg)
            if ok and type(out) == "string" and out ~= msg then h.count = h.count + 1 return out end
        end
    end
end

local function Wrapped(self, msg, ...)
    if self == chat and nLive > 0 and not inside and not busy and type(msg) == "string" then
        busy = true
        local ok, out = pcall(Pick, msg)
        busy = false
        if ok and type(out) == "string" then msg = out end
    end
    return base(self, msg, ...)
end
U.ChatWrapped = Wrapped                                  -- for the checks

local function Wrap()
    if chat then return true end                         -- wrapped already (maybe under a later wrapper)
    inside = InInstance()
    if inside then return false end                      -- never in an instance (see above)
    local f = rawget(_G, "DEFAULT_CHAT_FRAME")
    if type(f) ~= "table" or type(f.AddMessage) ~= "function" then return false end
    chat, had, base = f, rawget(f, "AddMessage"), f.AddMessage
    f.AddMessage = Wrapped   -- taints this one field: so it is off in instances, where lines are secret
    return true
end

-- force: off while hooks are on (an instance). Wrapped after us: we stay in their chain, passing all.
local function Unwrap(force)
    if (nLive > 0 and not force) or not chat or rawget(chat, "AddMessage") ~= Wrapped then return end
    chat.AddMessage = had                                -- had nil: the field is gone, the method shows
    chat, had, base = nil, nil, nil
end

-- In an instance: off. Outside, with a hook on: on again.
local function Sync()
    inside = InInstance()
    if inside then Unwrap(true) elseif nLive > 0 then Wrap() end
end
U.ChatSync = Sync                                        -- for the checks
do
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    ev:SetScript("OnEvent", function() pcall(Sync) end)
end

function U.ChatHook(o)
    local h = { marks = {}, maybe = o.maybe, line = o.line, live = false, count = 0 }
    for _, m in ipairs(o.marks or {}) do
        local text, at = m, 1
        if type(m) == "table" then text, at = m[1], m[2] or 1 end
        if type(text) == "string" and #text > 0 then
            h.marks[#h.marks + 1] = { text = text, at = at, to = at + #text - 1, b = byte(text, 1) }
        end
    end
    hooks[#hooks + 1] = h
    local H = {}
    function H.Start()
        if h.live then Wrap() return end
        if not Wrap() and not inside then return end    -- in an instance: on, wrapped when we leave it
        h.live, nLive = true, nLive + 1
    end
    function H.Stop()
        if h.live then h.live, nLive = false, nLive - 1 end
        Unwrap()
    end
    function H.Active() return h.live and chat ~= nil end
    function H.Count() return h.count end
    return H
end

-- U.ChatLines(o) -> { Install, Restore, Count }, on U.ChatHook. With o.prefix: the line starts with it (and
-- holds o.mark at byte o.markAt, when given); the rest goes to Translate and the prefix stays. With no prefix:
-- the line has no player or channel link and no Cyrillic, W.Maybe says it may be one of ours (a hash, no
-- cache), then the stack says o.from wrote it; only then Translate.
function U.ChatLines(o)
    local W, prefix = o.words, o.prefix
    local N = prefix and #prefix or 0
    local function Line(msg)
        if not o.wanted() then return nil end
        if prefix then
            if sub(msg, 1, N) ~= prefix then return nil end
            local uk = W.Translate(sub(msg, N + 1))
            return uk and prefix .. uk or nil
        end
        if not From(o.from) then return nil end
        return W.Translate(msg)
    end
    local marks, maybe = {}, nil
    if prefix then
        marks[1] = o.mark and { o.mark, o.markAt or 1 } or prefix
    elseif W.Maybe then                                  -- no Maybe: no line without a prefix is tried
        maybe = function(msg)
            if msg:find("|Hplayer", 1, true) or msg:find("|Hchannel", 1, true) or msg:find(CYR) then return false end
            return W.Maybe(msg) and true or false
        end
    end
    local hook = U.ChatHook({ marks = marks, maybe = maybe, line = Line })
    return { Install = hook.Start, Restore = hook.Stop, Count = hook.Count, Active = hook.Active }
end
