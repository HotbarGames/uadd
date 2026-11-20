-- Lua helpers for flow_sal.py, on the Speedy AutoLoot stand-in (tools/harness/speedyautoloot): the installed
-- addon's own files run after the stand-in's Shim.lua. Reached from Python as HARNESS.sal. Run before the game
-- starts. No English here: the addon writes its words itself; we only run its /sal commands and read back.
local H = HARNESS
local M = {}
H.sal = M

local CYR = "[\208-\210]"
local TEST = "\208\162\208\181\209\129\209\130"          -- a Cyrillic test word
local ANCHOR = "SpeedyAutoLoot_LootDisplayAnchor"
local FNAME = "|cffEEE4AESpeedy AutoLoot:|r "
-- The /sal commands in order; each toggle twice, so a run leaves the settings as they were.
local RUN = { "", "fish", "fish", "auto", "auto", "sound", "sound", "set 139", "display", "display", "COMBAT",
    "bop", "bop" }

local function NS() return H.ns.UADD_SpeedyAutoLoot end
local function Anchor() return rawget(_G, ANCHOR) end

function M.sal(msg) return H.call("/sal " .. msg, SlashCmdList.SPEEDYAUTOLOOT, msg) end

-- The frame that holds the loot entries (anchored to the anchor), and its entries with a shown text.
local function Holder()
    local a = Anchor()
    for _, c in ipairs({ UIParent:GetChildren() }) do
        if c ~= a and c.GetPoint and select(2, c:GetPoint(1)) == a then return c end
    end
end
local function Entries()
    local out, h = {}, Holder()
    for i, b in ipairs(h and { h:GetChildren() } or {}) do
        local fs = b.Text
        if type(fs) == "table" and b:IsShown() and fs:GetText() and fs:GetText() ~= "" then out[i] = { b, fs } end
    end
    return out
end

-- The anchor on: the test entries posted and shown (one comes each 0.15 s).
function M.show(on)
    M.sal("anchor")
    M.wait(1)
    return Anchor():IsShown() == (on and true or false)
end

-- Everything the module may change: C chat lines of one run of RUN, A the anchor's label, T the shown entries
-- (P: the addon marks it a test entry).
function M.snap()
    local out, from = {}, #H.chat
    for _, cmd in ipairs(RUN) do
        if cmd == "COMBAT" then
            H.combat = true
            M.sal("anchor")
            H.combat = false
        else
            M.sal(cmd)
        end
    end
    for i = from + 1, #H.chat do out["C:" .. (i - from)] = H.chat[i] end
    out["A:label"] = Anchor().text:GetText()
    for i, e in pairs(Entries()) do out[(e[1].isPermanent and "P:" or "T:") .. i] = e[2]:GetText() end
    return out
end

-- A text shows Cyrillic exactly when our font is on it: (bad, n with ours). The anchor's label and the entries.
function M.fonts()
    local bad, n = {}, 0
    local list = { Anchor().text }
    for _, e in pairs(Entries()) do list[#list + 1] = e[2] end
    for _, fs in ipairs(list) do
        local t = fs:GetText() or ""
        local cyr, ours = t:find(CYR) ~= nil, UADD.IsCyrFont((fs:GetFont())) and true or false
        if ours then n = n + 1 end
        if cyr ~= ours then bad[#bad + 1] = t end
    end
    return bad, n
end

-- Work the chat hook does on a line that is not the addon's: calls of Translate, UADD.Hash and UADD.Plain.
-- (on a foreign line, on one of the addon's lines)
function M.cheap()
    local W, n = NS().Words, 0
    local t, h, p = W.Translate, UADD.Hash, UADD.Plain
    local function count(f) return function(...) n = n + 1 return f(...) end end
    W.Translate, UADD.Hash, UADD.Plain = count(t), count(h), count(p)
    DEFAULT_CHAT_FRAME:AddMessage(TEST .. ", Quix")
    DEFAULT_CHAT_FRAME:AddMessage("|cffEEE4AEQuix:|r " .. TEST)
    local foreign = n
    n = 0
    M.sal("fish")
    M.sal("fish")
    local ours = n
    W.Translate, UADD.Hash, UADD.Plain = t, h, p
    return foreign, ours
end

-- One chat line the addon writes after its name, as the chat shows it (the half-line check).
function M.tr(text)
    DEFAULT_CHAT_FRAME:AddMessage(FNAME .. text)
    local got = H.chat[#H.chat]
    if got:sub(1, #FNAME) ~= FNAME then return nil end
    return got:sub(#FNAME + 1)
end

function M.count() return NS().ChatName.Count() + NS().ChatHelp.Count() + NS().Display.Count() end
function M.saved()
    local n = 0
    for _ in pairs(NS().Display.saved) do n = n + 1 end
    return n
end
function M.key(down)
    H.keys.SHIFT = down
    H.fire("MODIFIER_STATE_CHANGED", "LSHIFT", down and 1 or 0)
    M.wait(0.4)                         -- UADD/Original.lua switches once the key is held a while
end
function M.wait(seconds) for _ = 1, math.ceil(seconds / 0.05 - 1e-6) do H.step(0.05) end end
function M.uadd(msg) return H.call("/uadd " .. msg, SlashCmdList.UADD, msg) end
function M.last() return H.chat[#H.chat] end
