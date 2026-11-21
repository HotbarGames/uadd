-- Lua helpers for flow_auc_popup.py: the game's ACCEPT / CANCEL words on Auctionator's StaticPopup questions
-- (the core helper UADD/Popups.lua, UADD_Auctionator/Popup.lua). Runs after flow_auc.lua, on the same HARNESS.auc, before the game starts.
-- The words we want are read from the glossary (UADD.Glossary.Text), never from the module.
local H = HARNESS
local M = H.auc
local P = {}
M.pop = P
local MOD = "UADD_Auctionator"

-- One fix cut out per mutant, in memory only (as in flow_litemount_globals.lua): { addon, file, code, new }.
local CORE = "UADD"
local CUTS = {
    fields = { CORE, "Popups.lua", "if en and v == en then", "if false then" },
    shown = { CORE, "Popups.lua", "if i > 1 then en, uk = Of(s, now) end", "" },
    restore = { CORE, "Popups.lua", "    pcall(Fields, s, false)\n", "" },
    rescan = { CORE, "Popups.lua", "    if uk and installed then Rescan(s) end\n", "" },
    cyr = { CORE, "Popups.lua", ' or en:find(CYR)', "" },
    prefix = { CORE, "Popups.lua", "which:sub(1, #s.prefix):upper() == s.prefix", "which:sub(1, #s.prefix) == s.prefix" },
    ours = { CORE, "Popups.lua", 'if type(which) ~= "string" then return false end', "do return true end" },
    words = { MOD, "Words.lua", "for _, p in ipairs(ns.Popup and ns.Popup.Pairs() or {}) do Add(p[1], p[2]) end", "" },
}
local runFile = H.runFile
function H.runFile(addon, path, code)
    local c = P.cut and CUTS[P.cut]
    if c and addon == c[1] and path == c[2] then
        c = { c[2], c[3], c[4] }
        local a, b = code:find(c[2], 1, true)
        if a then code, P.wasCut = code:sub(1, a - 1) .. c[3] .. code:sub(b + 1), true end
    end
    return runFile(addon, path, code)
end
function P.setCut(cut) P.cut, P.wasCut = cut, nil end

-- The game's globals that Auctionator shows on its frames, as on an English client.
BACK, NOT_BOUND, EMPTY = BACK or "Back", NOT_BOUND or "Not Bound", EMPTY or "Empty"

-- Another addon's question with the same buttons: never ours.
StaticPopupDialogs.OTHERADDON_QUESTION = { text = "", button1 = ACCEPT, button2 = CANCEL }

local WHICH = { "AUCTIONATOR_SELLING_CONFIRM_POST", "AUCTIONATOR_SELLING_CONFIRM_POST_SKIP",
    "AuctionatorConfirmBidPricePopupDialog" }
local CYR = "[\208-\211][\128-\191]"

-- The word a button should show for a global's text: want "uk" -> our glossary word while the global is
-- English, the global itself while it is Cyrillic; "en" -> the global.
local IDS = { ACCEPT = "ui.accept", CANCEL = "ui.cancel" }
local function Word(g, want)
    local en = rawget(_G, g)
    if want == "en" or en:find(CYR) then return en end
    return UADD.Glossary.Text(IDS[g])
end

local function Join(t) local o = {} for i = 1, 3 do o[i] = tostring(t[i]) end return table.concat(o, " / ") end

-- Each of Auctionator's entries: its button1..3 fields.
function P.fields()
    local out = {}
    for _, w in ipairs(WHICH) do
        local d = StaticPopupDialogs[w]
        out[#out + 1] = Join({ d.button1, d.button2, d.button3 })
    end
    return table.concat(out, " || ")
end
function P.fieldsExpect(want)
    local skip = AUCTIONATOR_L_SKIP
    return table.concat({ Join({ Word("ACCEPT", want), Word("CANCEL", want), nil }),
        Join({ Word("ACCEPT", want), skip, Word("CANCEL", want) }),
        Join({ Word("ACCEPT", want), Word("CANCEL", want), nil }) }, " || ")
end

-- The shown dialog's three buttons, and whether each button with text has a Cyrillic font.
local function Buttons()
    local t, cyr = {}, true
    for i = 1, 3 do
        local fs = StaticPopup1["button" .. i]:GetFontString()
        t[i] = fs:GetText()
        if t[i] and t[i]:find(CYR) and not UADD.IsCyrFont((fs:GetFont())) then cyr = false end
    end
    return Join(t), cyr
end
function P.open() return (Buttons()) end
function P.show(n) StaticPopup_Show(WHICH[n]) return Buttons() end
function P.showExpect(n, want)
    local skip = want == "uk" and H.ns[MOD].UA.SKIP or AUCTIONATOR_L_SKIP
    if n == 2 then return Join({ Word("ACCEPT", want), skip, Word("CANCEL", want) }) end
    return Join({ Word("ACCEPT", want), Word("CANCEL", want), nil })
end
function P.which(n) return WHICH[n] end

-- The globals and another addon's entry, as the game set them.
function P.globals() return tostring(rawget(_G, "ACCEPT")) .. " / " .. tostring(rawget(_G, "CANCEL")) end
function P.other()
    local d = StaticPopupDialogs.OTHERADDON_QUESTION
    return tostring(d.button1) .. " / " .. tostring(d.button2)
end
-- Before the game starts: a global set in Ukrainian by another addon.
function P.presetAccept(word) ACCEPT = word end
-- The addon changes a field after us (a new Auctionator, its own option): that is theirs.
function P.theirs(word) StaticPopupDialogs[WHICH[1]].button2 = word end
function P.field(n, f) return StaticPopupDialogs[WHICH[n]][f] end
function P.count() return H.ns[MOD].Popup.FieldCount() end

-- The game's BACK / NOT_BOUND / EMPTY words as Auctionator shows them (alone, NOT_BOUND and EMPTY grey):
-- what Words.lua gives for each, and what the glossary wants ("" when it should stay English).
local GLOBALS3 = { BACK = "ui.back", NOT_BOUND = "ui.not_bound", EMPTY = "ui.empty" }
local function Grey(s) return "|cff808080" .. s .. "|r" end
function P.three()
    local W, out = H.ns[MOD].Words, {}
    for _, g in ipairs({ "BACK", "NOT_BOUND", "EMPTY" }) do
        local en = rawget(_G, g)
        out[#out + 1] = tostring(W.Text(en)) .. " | " .. tostring(W.Text(Grey(en)))
    end
    return table.concat(out, " || ")
end
function P.threeExpect()
    local out = {}
    for _, g in ipairs({ "BACK", "NOT_BOUND", "EMPTY" }) do
        local en, uk = rawget(_G, g), UADD.Glossary.Text(GLOBALS3[g])
        if en:find(CYR) then uk = nil end
        out[#out + 1] = tostring(uk) .. " | " .. tostring(uk and Grey(uk))
    end
    return table.concat(out, " || ")
end
function P.presetBack(word) BACK = word end
