-- Lua helpers for flow_wp.py, on the Waypoint UI stand-in (tools/harness/waypointui). Reached from Python as
-- HARNESS.wp. Run before the game starts.
local H = HARNESS
local M = {}
H.wp = M

M.CUSTOM = "Interface\\AddOns\\WaypointUI\\Fonts\\standin.ttf"     -- a font from its list, no Cyrillic
H.fontFiles[M.CUSTOM:lower()] = true

-- The proof that a step has teeth: with M.cut set, Screen.lua runs without one fix (this run's copy, in memory
-- only; the module's file is never changed). fault: lesson 26 (its SetText failing after it drew ours);
-- cache: lesson 12 (each frame's last answer); busy: our own SetText runs our handler again.
local CUTS = {
    busy = { { "    busy = true\n    local ok, err", "local ok, err", "    local ok, err" } },
    fault = { { "    if not ok then U.Fault(", "return ok or TextOf(f) == text\n", "    return ok\n" },
              { "            if TextOf(f) ~= en then pcall(", "its SetText failed first\n", "" } },
    cache = { { "    local uk                ", "st.ken, st.kuk, st.klook = text, uk, st.look end\n",
                "    local uk = st.look(text)\n" } },
}
M.cut, M.wasCut = nil, false
local runFile = H.runFile
function H.runFile(addon, path, code)
    if addon == "UADD_WaypointUI" and path == "Screen.lua" and M.cut then
        local all = true
        for _, c in ipairs(CUTS[M.cut]) do
            local a = code:find(c[1], 1, true)
            local b = a and select(2, code:find(c[2], a, true))
            if a and b then code = code:sub(1, a - 1) .. c[3] .. code:sub(b + 1) else all = false end
        end
        M.wasCut = all
    end
    return runFile(addon, path, code)
end

WaypointUIStandInFeed = { settings = {}, missing = {} }
function M.feed(k, v) WaypointUIStandInFeed[k] = v end
function M.feedSetting(en) local t = WaypointUIStandInFeed.settings t[#t + 1] = en end
function M.miss(name) WaypointUIStandInFeed.missing[name] = true end

local function S() return rawget(_G, "WaypointUIStandIn") end
local function NS() return H.ns.UADD_WaypointUI end
M.S = S
function M.fits() return S().fits end
function M.gamePath() return (GameFontNormal:GetFont()) end
function M.loaded() return S() ~= nil and NS() ~= nil and NS().Words ~= nil end
function M.on() return NS().On() and true or false end
function M.text(name) local f = S().texts[name] return f and f:GetText() end
function M.set(name, t) S().texts[name]:SetText(t) return S().texts[name]:GetText() end
function M.setRaw(name, t) S().texts[name].__Text:SetText(t) end   -- the addon writes its font string itself
function M.count() local n, uk = NS().Screen.Count() return n, uk end
function M.words() return NS().Words.Count() end
function M.Text(t) return NS().Text(t) end
function M.Units(t) return NS().Units(t) end
function M.Pinpoint(t) return NS().Pinpoint(t) end
function M.throw(mode) S().throw = mode end

-- Our Ukrainian for a whole text, straight from the module's data.
function M.want(key)
    local uk = NS().WP.exact[key]
    return uk and UADD.Plural(uk, true)
end
-- A template filled by hand from its record (uk: pieces, numbers are slots).
function M.fill(id, a)
    for _, rec in ipairs(NS().WP.templates) do
        if rec.id == id then
            local out = {}
            for _, p in ipairs(rec.uk) do out[#out + 1] = type(p) == "number" and tostring(a) or p end
            return UADD.Plural(table.concat(out), true)
        end
    end
end
function M.prompt(template, name) S().Prompt(template, name) return M.text("prompt") end

-- The footer: n ticks with the same two lines; how many unit look-ups they cost (the distance pattern runs
-- once per Units call that is not cached).
function M.ticks(n, dist, time)
    local match, calls = string.match, 0
    string.match = function(s, p, ...)                              -- luacheck: ignore
        if p == "^(%d[%d,]*) yds$" then calls = calls + 1 end
        return match(s, p, ...)
    end
    local ok, err = pcall(function() for _ = 1, n do S().Tick(dist, time) end end)
    string.match = match                                            -- luacheck: ignore
    if not ok then error(err) end
    return calls, M.text("dist"), M.text("time")
end

-- Fonts: (path, size, flags) of one of its font objects: footer, pinpoint, ui1..ui3.
local function Obj(which)
    local f = S().fonts
    return f[which] or f.ui[tonumber(which:match("%d+$") or 0)]
end
function M.font(which) return Obj(which):GetFont() end
function M.cyr(which) return UADD.IsCyrFont((Obj(which):GetFont())) and true or false end
function M.updateFonts(path, footerFlags, pinFlags)
    FontHandler.fontPath = path
    FontHandler.footerFlags, FontHandler.pinpointFlags = footerFlags or "", pinFlags or ""
    FontHandler.UpdateFonts()
end
M.backs = 0
function M.after()                                  -- after login: count U.FontBack on its footer font
    local back = UADD.FontBack
    UADD.FontBack = function(o, was)
        if o == S().fonts.footer then M.backs = M.backs + 1 end
        return back(o, was)
    end
end

function M.open() S().OpenSettings() end
function M.close() S().CloseSettings() end
function M.tab(en, key) S().Tab(en, key) return M.text(key) end

function M.focus() return GetCurrentKeyBoardFocus() end
function M.lastChat(n)
    local out = {}
    for i = math.max(1, #H.chat - n + 1), #H.chat do out[#out + 1] = H.chat[i] end
    return table.concat(out, " | ")
end
function M.chats() return #H.chat end
function M.key(down)
    H.keys.SHIFT = down
    H.fire("MODIFIER_STATE_CHANGED", "LSHIFT", down and 1 or 0)
    M.wait(0.4)
end
function M.wait(seconds) for _ = 1, math.ceil(seconds / 0.05 - 1e-6) do H.step(0.05) end end
function M.uadd(msg) return H.call("/uadd " .. msg, SlashCmdList.UADD, msg) end

-- The slowest of three runs of fn(text), in ms.
function M.slow(fn, text)
    local f, worst = NS()[fn] or function(t) return M.set("input", t) end, 0
    for _ = 1, 3 do
        local t0 = debugprofilestop()
        f(text)
        worst = math.max(worst, debugprofilestop() - t0)
    end
    return worst
end
