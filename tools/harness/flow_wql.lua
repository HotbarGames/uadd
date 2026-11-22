-- Lua helpers for flow_wql.py, on the Wowhead Quick Link stand-in (tools/harness/wowheadquicklink): the installed
-- addon's own Lua files run after the stand-in's Shim.lua. Reached from Python as HARNESS.wql. Run before the game
-- starts: it gives the harness StaticPopup1..4 that format their text as the game does. No English of the addon
-- here: it writes its words itself; we only point the mouse at things, run its key binding and /wql, and read back.
local H = HARNESS
local M = {}
H.wql = M

local MOD, POPUP, CONFIG = "UADD_WowheadQuickLink", "WowheadQuickLinkUrl", "WowheadQuickLinkConfig_Frame"
local CYR = "[\208-\211][\128-\191]"

local function NS() return H.ns[MOD] end

-- The proof that a step has teeth: with M.cut set, one module file runs without one fix (in memory only).
local CUTS = {}
M.cut, M.wasCut = nil, false
function M.addCut(name, file, old, new) CUTS[name] = { file, old, new } end
local runFile = H.runFile
function H.runFile(addon, path, code)
    local c = M.cut and CUTS[M.cut]
    if addon == MOD and c and path == c[1] then
        local a, b = code:find(c[2], 1, true)
        if a then code, M.wasCut = code:sub(1, a - 1) .. c[3] .. code:sub(b + 1), true end
    end
    return runFile(addon, path, code)
end

-- ── The game's popups ────────────────────────────────────────────────────────────────────────
-- StaticPopup1..4: a text and buttons. StaticPopup_Show formats the text with its two arguments, then runs the
-- dialog's OnShow with its data, as the game does (this harness popup has no edit box: its OnShow leaves early).
local pops = {}
for i = 1, 4 do
    local d = _G["StaticPopup" .. i]
    if not rawget(d, "button1") then
        d.text = d:CreateFontString("StaticPopup" .. i .. "Text", "ARTWORK", "GameFontHighlight")
        for b = 1, 4 do
            local btn = CreateFrame("Button", "StaticPopup" .. i .. "Button" .. b, d)
            btn:GetFontString():SetFontObject(GameFontNormal)
            d["button" .. b] = btn
        end
    end
    d:Hide()
    pops[i] = d
end
function StaticPopup_Show(which, a1, a2, data)
    local info = StaticPopupDialogs[which]
    if not info then return end
    local d = pops[1]
    for _, p in ipairs(pops) do if p.which == which or not p:IsShown() then d = p break end end
    d.which = which
    d.text:SetText(string.format(info.text, a1 or "", a2 or ""))
    for b = 1, 4 do d["button" .. b]:SetText(info["button" .. b]) end
    d:Show()
    if info.OnShow then info.OnShow(d, data) end
    return d
end
function StaticPopup_Hide(which) for _, p in ipairs(pops) do if p.which == which then p:Hide() end end end

-- ── What the mouse points at ─────────────────────────────────────────────────────────────────
-- One focus per kind of link its strategies know (made-up ids). enchant: a link type it has no word for (the
-- whole popup stays English); azerite: a header left English on purpose; npc: a Questie frame's NPC.
M.KINDS = { "quest", "spell", "currency", "achievement", "faction", "link", "npc", "enchant", "azerite", "item" }
local FOCI = {
    quest = function() return { questID = 5 } end,
    spell = function() return { spellID = 5 } end,
    item = function() return { itemID = 5 } end,
    currency = function() return { currencyID = 5 } end,
    achievement = function() return { id = 5, dateCompleted = 1 } end,
    link = function() return { itemLink = "|Hitem:4711:0|h" } end,
    faction = function() return { index = 1, standingText = "x" } end,
    npc = function() return { GetName = function() return "QuestieFrame1" end, data = { npcData = { id = 5 } } } end,
    enchant = function() return { itemLink = "|Henchant:5:0|h" } end,
    azerite = function() return { essenceID = 5 } end,
}

local function Shown()
    for _, d in ipairs(pops) do if d:IsShown() and d.which == POPUP then return d end end
end
-- The shown link popup: its text, its button's text, and the font files of both.
function M.popup()
    local d = Shown()
    if not d then return nil end
    local b = d.button1:GetFontString()
    return d.text:GetText(), b:GetText(), (d.text:GetFont()), (b:GetFont())
end

-- Its key binding with the mouse on a thing of that kind: the popup it shows.
function M.link(kind)
    StaticPopup_Hide(POPUP)
    local focus, was = FOCI[kind](), GetMouseFoci
    GetMouseFoci = function() return { focus } end
    H.call("wql " .. kind, RunWowheadQuickLink)
    GetMouseFoci = was
    return M.popup()
end

-- ── The /wql window ──────────────────────────────────────────────────────────────────────────
local function W() return rawget(_G, CONFIG).standIn end
-- Its box takes the keyboard (autoFocus), and Shift held while typing is no hold key: the player clicks out first.
function M.wql()
    H.call("/wql", SlashCmdList.WOWHEAD_QUICK_LINK, "")
    local f = GetCurrentKeyBoardFocus()
    if f then f:ClearFocus() end
end
-- What the player typed in both boxes (the addon writes its URL from it), then the URL line set to `url`.
function M.type(text, url)
    WowheadQuickLinkConfig_EditBoxPrefix:SetText(text)
    WowheadQuickLinkConfig_EditBoxSuffix:SetText(text)
    if url then W().url:SetText(url) end
end

-- Everything a player can read: S the popup shown now (before any new one), P and B each kind's popup text and
-- button, W the /wql window's texts, K the two key binding names.
function M.snap()
    local out = {}
    out["S:text"], out["S:button"] = M.popup()
    for _, k in ipairs(M.KINDS) do out["P:" .. k], out["B:" .. k] = M.link(k) end
    for k, fs in pairs(W()) do out["W:" .. k] = fs:GetText() end
    out["K:1"], out["K:2"] = BINDING_NAME_WOWHEAD_QUICK_LINK_NAME, BINDING_NAME_WOWHEAD_QUICK_LINK_RAIDERIO_NAME
    return out
end

-- A text shows Cyrillic exactly when our font is on it: (bad, n with ours). Each kind's popup, then the window.
function M.fonts()
    local bad, n = {}, 0
    local function one(where, text, path)
        local cyr, ours = (text or ""):find(CYR) ~= nil, UADD.IsCyrFont(path) and true or false
        if ours then n = n + 1 end
        if cyr ~= ours then bad[#bad + 1] = where .. ": " .. tostring(text) end
    end
    for _, k in ipairs(M.KINDS) do
        local t, b, ft, fb = M.link(k)
        one("P:" .. k, t, ft)
        one("B:" .. k, b, fb)
    end
    -- The labels; not the URL line and what was typed (never ours: drawn in the chat font, Cyrillic or not).
    for k, fs in pairs(W()) do
        if k ~= "url" and k ~= "typedP" and k ~= "typedS" then one("W:" .. k, fs:GetText(), (fs:GetFont())) end
    end
    return bad, n
end

-- The half-line check's path: the text through its real popup. raw: the popup shows `text` itself (its text "%s"
-- for a moment); else `text` is the header. A popup left English gives the input back.
function M.tr(text, raw)
    local info = StaticPopupDialogs[POPUP]
    local tpl = info.text
    if raw then info.text = "%s" end
    StaticPopup_Hide(POPUP)
    local ok = pcall(StaticPopup_Show, POPUP, text, nil, "x")
    info.text = tpl
    local got = ok and M.popup() or nil
    StaticPopup_Hide(POPUP)
    if not raw and got == tpl:format(text) then return text end
    return got
end

-- Texts of this module the missed-text tool wrote down.
function M.missed()
    local db = rawget(_G, "UADD_DB")
    local m = type(db) == "table" and type(db.missed) == "table" and db.missed.mods or {}
    local mod, n = m.wql or {}, 0
    for _, list in ipairs({ mod.texts or {}, mod.names or {} }) do for _ in pairs(list) do n = n + 1 end end
    return n
end
function M.shown() return NS().Shown() end
function M.saved()
    local n = 0
    for _ in pairs(NS().saved) do n = n + 1 end
    return n
end

function M.feed(code) assert((loadstring or load)(code))() end
function M.wait(seconds) for _ = 1, math.ceil(seconds / 0.05 - 1e-6) do H.step(0.05) end end
function M.uadd(msg) return H.call("/uadd " .. msg, SlashCmdList.UADD, msg) end
function M.key(down)
    H.keys.SHIFT = down
    H.fire("MODIFIER_STATE_CHANGED", "LSHIFT", down and 1 or 0)
    M.wait(0.4)                         -- UADD/Original.lua switches once the key is held a while
end
