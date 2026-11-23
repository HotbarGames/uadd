-- UADD.Walk(spec): a module's windows, walked from their roots, each text of theirs swapped for ours by a SetText
-- hook. Made from the DeleteCheapestItem Reloaded and BugSack modules' screens, for any module whose addon builds
-- its texts in code and keeps them private (one walker per module; the module gives the roots and the words).
--   * Each FontString met gets SetText and SetFormattedText hooks once (and SetFontObject, for the font). They do
--     nothing while off or held unless ours shows on it now. A Button gets SetText hooks too (it draws into its
--     label without the label's SetText) and its font state methods (lesson 32, SetEnabled too).
--   * Each FontString keeps its last English and our answer for it: the same text asks no lookup (lesson 12).
--   * Off and the hold key put the English back only where ours still shows (lesson 23), then the font.
--   * Hooks go on only while the module is on (lesson 37): off only gives things back.
--   * Our font: UADD's Cyrillic font object (U.CyrOnLocked), read back (lesson 2); the label's own font is saved
--     first (U.SaveFont, never while ours is on: lesson 32) and put back with U.FontBack (lesson 18). A text whose
--     font cannot be made Cyrillic keeps its English.
--   * No walk in combat (lesson 36); none into text boxes, tooltips, forbidden or protected frames, menu rows
--     (U.Locked, lesson 38). Hooks run under a pcall that reports and counts (U.Fault: lesson 19), so they work
--     again after an "on". Any error leaves the English as it was.
-- spec fields:
--   key       the module's key for U.Fault (its /uadd name)
--   On()      true while the module is on; Wanted() (optional) true while ours should show (default: on, not held)
--   roots     a list of global frame names, or a function giving a list of frames
--   Lookup(en, fs)   our Ukrainian for a whole English text (U.Plain'd), or nil; a second value false: not kept
--   skip      a set of frame names not walked (the player's own names: lesson 13), or a function(frame, name)
--   prefix    a frame name prefix (or a list): a new frame so named, or under a known frame, starts a walk
--   font      true: put UADD's Cyrillic font on each text of ours (false: the addon's font draws Cyrillic)
--   hints     true: in a text box, its hint FontStrings only (a placeholder the addon sets), never the typed text
--   depth, maxFrames, title   walk depth (12), frames one walk visits at most (4000), the name for /uadd perf

local U = UADD
local find = string.find
local F = U.WalkFrames                       -- WalkFrames.lua: the frame questions, each under a pcall
local CYR, BUTTON_FONT, Forbidden, Label, Name, Kind = F.CYR, F.BUTTON_FONT, F.Forbidden, F.Label, F.Name, F.Kind

function U.Walk(spec)
    local W = {}
    local key, On = spec.key, spec.On
    local Wanted = spec.Wanted or function() return On() and not U.originalShown end
    local DEPTH, MAX = spec.depth or 12, spec.maxFrames or 4000
    local weak = { __mode = "k" }
    local rec = setmetatable({}, weak)       -- FontString -> { en, uk } while it shows ours
    local last = setmetatable({}, weak)      -- FontString -> { en, uk or false }: its last lookup
    local hooked = setmetatable({}, weak)    -- FontStrings with our hooks
    local buttons = setmetatable({}, weak)   -- Buttons with our hooks
    local known = setmetatable({}, weak)     -- frames met on a walk
    local saved = setmetatable({}, weak)     -- FontString -> its own font (U.SaveFont)
    local fonted = setmetatable({}, weak)    -- FontStrings with our font on
    local shown = {}                          -- roots with our OnShow hook
    local busy, fixing, pending, capped, frameHook, origHook, count = false, false, false, false, false, false, 0

    local function Fault(err)
        pcall(U.ReportError, tostring(err))
        if key then pcall(U.Fault, key, err) end
    end
    local function Guard(fn)
        return function(...)
            local ok, err = pcall(fn, ...)
            if not ok then Fault(err) end
        end
    end
    local function Cyr(fs)
        local ok, path = pcall(fs.GetFont, fs)
        return ok and U.IsCyrFont(path)
    end

    -- Our font on fs, read back; true when it can draw Cyrillic now.
    local function Font(fs)
        if not spec.font then return true end
        if Cyr(fs) then
            if saved[fs] then fonted[fs] = true end   -- ours, still on (or put on again by a hover)
            return true
        end
        local ok, was = pcall(U.SaveFont, fs)          -- fresh: the label's font now is not ours (lesson 32)
        if ok and type(was) == "table" then saved[fs] = was end
        fixing = true
        local okOn, on = pcall(U.CyrOnLocked, fs)
        fixing = false
        if okOn and on and Cyr(fs) then fonted[fs] = true return true end
        if saved[fs] then                              -- a file set by hand keeps over the object: ours by hand (44)
            fixing = true
            local okOwn, own = pcall(U.CyrOnOwn, fs, saved[fs])
            if okOwn and own and Cyr(fs) then fixing = false fonted[fs] = true return true end
            pcall(U.FontBack, fs, saved[fs])
            fixing = false
        end
        saved[fs], fonted[fs] = nil, nil
        return false
    end
    local function Unfont(fs)
        if not fonted[fs] then return end
        fonted[fs] = nil
        fixing = true
        local ok, err = pcall(U.FontBack, fs, saved[fs])
        fixing = false
        saved[fs] = nil
        if not ok then Fault(err) end
    end

    local function Text(fs)
        local ok, t = pcall(fs.GetText, fs)
        if not ok then return nil, false end
        return U.Plain(t), true
    end
    -- SetText through pcall; what shows counts, not whether it threw (lesson 26).
    local function Put(fs, t)
        busy = true
        local ok, err = pcall(fs.SetText, fs, t)
        busy = false
        if not ok then Fault(err) end
        return Text(fs) == t
    end

    local function Look(fs, t)
        local l = last[fs]
        if l and l.en == t then return l.uk or nil end
        local ok, uk, keep = pcall(spec.Lookup, t, fs)
        if not ok then Fault(uk) return nil end
        if type(uk) ~= "string" or uk == "" or uk == t then uk = nil end
        if keep ~= false then last[fs] = { en = t, uk = uk or false } end
        return uk
    end

    -- One text as it should be now: ours (font read back) or the addon's English.
    local function Apply(fs)
        if busy then return end
        local t, ok = Text(fs)
        if not ok then return end
        local r = rec[fs]
        if Wanted() then
            if r and t == r.uk then
                if Font(fs) then return end
                Put(fs, r.en)                           -- the font cannot draw it now: the English, no boxes
                rec[fs] = nil
                Unfont(fs)
                return
            end
            rec[fs] = nil
            if not t or t == "" then Unfont(fs) return end
            if find(t, CYR) then return end             -- another addon's Ukrainian, or a name: left as it is
            local uk = Look(fs, t)
            if not uk then Unfont(fs) return end
            if Put(fs, uk) and Font(fs) then
                rec[fs] = { en = t, uk = uk }
                count = count + 1
                return
            end
            if Text(fs) ~= t then Put(fs, t) end
            Unfont(fs)
        else
            if r and t == r.uk then Put(fs, r.en) end   -- only while it is still ours (lesson 23)
            rec[fs] = nil
            Unfont(fs)                                  -- the English first, then its font
        end
    end

    local OnSet = Guard(function(fs)
        if busy or (not rec[fs] and not fonted[fs] and not Wanted()) then return end
        Apply(fs)
    end)
    -- The addon set a font again while ours shows: that font is its own now; ours goes on over it.
    local function Refix(fs)
        if fixing or busy or not rec[fs] or not spec.font then return end
        if Wanted() then
            if not Font(fs) then Apply(fs) end
        end
    end
    local OnFont = Guard(Refix)

    local function Hook(fs)
        if type(fs) ~= "table" or Forbidden(fs) or U.Locked(fs) then return end
        if not hooked[fs] and On() then
            hooked[fs] = true
            hooksecurefunc(fs, "SetText", OnSet)
            if fs.SetFormattedText then hooksecurefunc(fs, "SetFormattedText", OnSet) end
            if spec.font and fs.SetFontObject then hooksecurefunc(fs, "SetFontObject", OnFont) end
        end
        if hooked[fs] then Apply(fs) end
    end

    local OnButton = Guard(function(b)
        local fs = Label(b)
        if not fs then return end
        if On() then Hook(fs) elseif hooked[fs] then Apply(fs) end
    end)
    local OnButtonFont = Guard(function(b)
        local fs = Label(b)
        if fs then Refix(fs) end
    end)
    local function HookButton(b)
        if buttons[b] or not On() or type(b.GetFontString) ~= "function" then return end
        buttons[b] = true
        hooksecurefunc(b, "SetText", OnButton)
        if b.SetFormattedText then hooksecurefunc(b, "SetFormattedText", OnButton) end
        if spec.font then
            for _, m in ipairs(BUTTON_FONT) do
                if type(b[m]) == "function" then hooksecurefunc(b, m, OnButtonFont) end
            end
            if b.HookScript then
                pcall(b.HookScript, b, "OnEnter", OnButtonFont)
                pcall(b.HookScript, b, "OnLeave", OnButtonFont)
            end
        end
    end

    local function Walk(f, depth, seen)
        if depth > DEPTH or Forbidden(f) then return end
        if seen.n >= MAX then
            if not capped and U.debug then U.Print((spec.title or key or "?") .. ": обхід вікна зупинився на " .. MAX .. " рамках") end
            capped = true
            return
        end
        seen.n = seen.n + 1
        if F.Skip(spec, f, Name(f)) or F.Protected(f) then return end
        local kind = Kind(f)
        if kind == "EditBox" and spec.hints then for _, r in ipairs(F.Hints(f, hooked)) do Hook(r) end return end
        if kind == "EditBox" or type(f.AddLine) == "function" then return end   -- a text box; a tooltip (U.TipLines)
        known[f] = true
        if kind == "Button" or kind == "CheckButton" then
            HookButton(f)
            OnButton(f)
        end
        for _, r in ipairs(U.Regions(f)) do
            if not Forbidden(r) and Kind(r) == "FontString" then Hook(r) end
        end
        for _, c in ipairs(U.Children(f)) do Walk(c, depth + 1, seen) end
    end

    -- Off walks only the texts it already knows: it never hooks anything new.
    local function WalkAll()
        if not On() then
            for fs in pairs(hooked) do Apply(fs) end
            return
        end
        local seen = { n = 0 }
        for _, f in ipairs(F.Roots(spec)) do
            if not Forbidden(f) then
                if not shown[f] and f.HookScript then
                    shown[f] = true
                    pcall(f.HookScript, f, "OnShow", Guard(function() if On() then W.Later() end end))
                end
                Walk(f, 0, seen)
            end
        end
    end
    local SafeWalk = Guard(WalkAll)

    local function Run()
        if U.AfterCombat(Run) then return end
        pending = false
        if On() then SafeWalk() end
    end
    -- One walk on the next frame, after combat.
    function W.Later()
        if pending then return end
        pending = true
        if C_Timer and C_Timer.After then C_Timer.After(0, Run) else Run() end
    end

    -- The game made a frame: a part of the windows? (its name, or a parent we know; no lookup)
    local function OnNewFrame(_, name, parent)
        if not On() then return end
        name = U.Plain(name)
        if name then
            if not F.Starts(spec, name) then return end
        elseif type(parent) ~= "table" or not known[parent] then
            return
        end
        W.Later()
    end

    -- The hold key: the English where ours shows; ours again on release.
    local Original = Guard(function(show)
        if show then
            for fs in pairs(rec) do Apply(fs) end
        elseif On() then
            for fs in pairs(hooked) do Apply(fs) end
        end
    end)

    function W.Install()
        if not On() then return end
        if not origHook then origHook = true U.OnOriginal(Original, spec.title) end
        if not frameHook then frameHook = U.OnNewFrame(OnNewFrame) end
        pending = true
        Run()
    end
    -- On: walk again; off: the English back where ours shows, then the fonts.
    function W.Sync()
        if On() then W.Install() else SafeWalk() end
    end
    function W.Remove()
        for fs in pairs(rec) do U.SafeCall(Apply, fs) end
        for fs in pairs(fonted) do U.SafeCall(Unfont, fs) end
    end
    function W.Walk(f) if On() then local g = Guard(Walk) g(f, 0, { n = 0 }) end end
    function W.Forget() for fs in pairs(last) do last[fs] = nil end end
    function W.Count() return count end
    function W.Shown() local n = 0 for _ in pairs(rec) do n = n + 1 end return n end
    function W.Known(f) return known[f] == true end
    function W.Ours(fs) return rec[fs] end
    W.Apply, W.Hook, W.Original = Guard(Apply), Guard(Hook), Original
    return W
end
