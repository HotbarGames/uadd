-- Lua helpers for flow_mastercraft.py, on the Mastercraft stand-in (tools/harness/mastercraft). Reached
-- from Python as HARNESS.mc. Run before the game starts.
local H = HARNESS
local M = {}
H.mc = M

-- In the game every frame of a kind shares one method table (getmetatable(f).__index), and Screen.lua
-- hooks CreateFontString there. The harness looks methods up through a function instead, so the
-- module is shown the table the function reads (H.Widget). Only UADD_Mastercraft sees this.
local realMeta = getmetatable
local SHARED = { __index = H.Widget }
getmetatable = function(x)
    if type(x) == "table" and rawget(x, "__type") ~= nil and rawget(x, 0) == x then
        local info = debug.getinfo(2, "S")
        if info and info.source and info.source:find("AddOns/UADD_Mastercraft/", 1, true) then return SHARED end
    end
    return realMeta(x)
end

MastercraftStandInFeed = { load = {}, later = {} }
function M.feed(where, name, text, how, size, width)
    local t = MastercraftStandInFeed[where]
    t[#t + 1] = { name = name, text = text, how = how ~= "" and how or nil, size = size, width = width }
end

local function S() return rawget(_G, "MastercraftStandIn") end
local function NS() return H.ns.UADD_Mastercraft end
M.S = S
function M.loaded() return S() ~= nil and NS() ~= nil end
function M.on() return NS().On() end
function M.uk(t) return NS().Words.Translate(t) end
function M.upper(t) return NS().Words.Upper(t) end
function M.count() return NS().Words.Count() end
function M.fontCount() return NS().Screen.Count() end
function M.hooked() return NS().Screen.Hooked() end

-- A made-up name the halves check puts in a game-name slot: UALL Forever's Ukrainian for it.
function M.names(en, uk)
    for _, k in ipairs({ "Text", "Zone", "Npc", "Item" }) do
        local old = UADD[k]
        UADD[k] = function(s, ...)
            if s == en then return uk end
            if old then return old(s, ...) end
        end
    end
end

-- Our Ukrainian for a whole text, straight from the module's data.
function M.want(key)
    local uk = NS().MC.exact[key]
    return uk and UADD.Plural(uk, true)
end

-- A template filled by hand from its record (data: uk list, numbers are slots), every slot a value.
function M.fill(id, a, b, c)
    local vals = { a, b, c }
    for _, rec in ipairs(NS().MC.templates) do
        if rec.id == id then
            local out = {}
            for _, p in ipairs(rec.uk) do out[#out + 1] = type(p) == "number" and vals[p] or p end
            return UADD.Plural(table.concat(out), true)
        end
    end
end

function M.snap()
    local out = {}
    for name, fs in pairs(S().texts) do out[name] = fs:GetText() or "" end
    return out
end

-- (path, size) of a stand-in text, whether that font is UADD's Cyrillic one, and mcPath / mcSize.
function M.font(name)
    local fs = S().texts[name]
    local p, s = fs:GetFont()
    return p, s, UADD.IsCyrFont(p) and true or false, fs.mcPath, fs.mcSize
end

-- Fonts read back: Cyrillic text in our font, English text in Mastercraft's own (mcPath).
function M.fonts()
    local good, bad, wrong = 0, 0, 0
    for _, fs in pairs(S().texts) do
        local p = fs:GetFont()
        local cyr = (fs:GetText() or ""):find("[\208-\210]") ~= nil
        if cyr and UADD.IsCyrFont(p) then good = good + 1
        elseif cyr then bad = bad + 1
        elseif p ~= fs.mcPath then wrong = wrong + 1 end
    end
    return good, bad, wrong
end

function M.later()
    S().Later()
    M.wait(0.2)
end

-- A tooltip line from the stand-in's code, and the same line from here (not Mastercraft's).
function M.tip(left, right)
    GameTooltipTextLeft1:SetText("") GameTooltipTextRight1:SetText("")
    S().Tip(left, right)
    return GameTooltipTextLeft1:GetText(), GameTooltipTextRight1:GetText(),
        UADD.IsCyrFont((GameTooltipTextLeft1:GetFont())) and true or false
end
function M.tipOther(left)
    GameTooltipTextLeft1:SetText("")
    GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    GameTooltip:AddLine(left)
    return GameTooltipTextLeft1:GetText() or ""
end

-- A chat line from the stand-in (its blue name first), or one without the name; the line shown.
function M.print(text) S().Print(text) return H.chat[#H.chat] end
function M.say(text) DEFAULT_CHAT_FRAME:AddMessage(text) return H.chat[#H.chat] end
function M.lastChat(n)
    local out = {}
    for i = math.max(1, #H.chat - n + 1), #H.chat do out[#out + 1] = H.chat[i] end
    return table.concat(out, " | ")
end

function M.key(down)
    H.keys.SHIFT = down
    H.fire("MODIFIER_STATE_CHANGED", "LSHIFT", down and 1 or 0)
    M.wait(0.4)                         -- UADD/Original.lua switches once the key is held a while
end
function M.wait(seconds) for _ = 1, math.ceil(seconds / 0.05 - 1e-6) do H.step(0.05) end end
function M.uadd(msg) return H.call("/uadd " .. msg, SlashCmdList.UADD, msg) end
