-- Lua helpers for flow_litemount_globals.py: the game globals LiteMount shows on its own frames (page names, its
-- buttons, the binding dropdowns, four condition names; the stand-in's litemount/Globals.lua). Runs after
-- flow_litemount.lua, on the same HARNESS.litemount.
local H = HARNESS
local M = H.litemount
local MOD = "UADD_LiteMount"
local function Lc() return H.ns[MOD].Locale end
local function S() return rawget(_G, "LiteMountStandIn") end

-- One more fix cut out per mutant, as in flow_litemount.lua (in memory only).
local CUTS = {
    gpages = { "Screen.lua", "    U.SafeCall(GlobalMaps)\n", "" },
    gback = { "Screen.lua", "            gEn[uk] = en", "" },
    gbuttons = { "Screen.lua", '"ADD", "DELETE", "EDIT",', "" },
    gbind = { "Copies.lua", '    if n:find("^%d+$") then return uk .. " " .. n end\n', "" },
    gbindback = { "Copies.lua", "    pcall(BindingBack)\n", "" },
    gcond = { "Tables.lua", " or Lc.GlobalBack(c)", "" },
    gfields = { "Tables.lua", "if want and c.name == en then c.name = uk", "if false then" },
    gcyr = { "Locale.lua", "(Cyr(g) and not any)", "false" },
}
local runFile = H.runFile
function H.runFile(addon, path, code)
    local c = M.cut and CUTS[M.cut]
    if addon == MOD and c and path == c[1] then
        local a, b = code:find(c[2], 1, true)
        if a then code, M.wasCut = code:sub(1, a - 1) .. c[3] .. code:sub(b + 1), true end
    end
    return runFile(addon, path, code)
end

-- A global's text and our word for it (nil when we have none).
local function G(g)
    local en = rawget(_G, g)
    return en, type(en) == "string" and Lc().Extra(g, en) or nil
end
-- want "uk": our word, "en": the global's text; nil when we have no word.
local function Want(g, want)
    local en, uk = G(g)
    if not uk then return nil end
    return want == "uk" and uk or en
end

local PAGES = { { "rules", "BRAWL_TOOLTIP_RULES" }, { "falling", "STRING_ENVIRONMENTAL_DAMAGE_FALLING" } }
-- The Rules and Falling pages: .name, the title and the settings category, each page " | "-joined.
function M.pages()
    local out = {}
    for _, p in ipairs(PAGES) do
        local f = S().globalPages[p[1]]
        out[#out + 1] = table.concat({ tostring(f.name), tostring(f.Title:GetText()),
            tostring(f.category:GetName()) }, " | ")
    end
    return table.concat(out, " || ")
end
function M.pagesExpect(want)
    local out = {}
    for _, p in ipairs(PAGES) do
        local w = Want(p[2], want)
        if not w then return nil end
        out[#out + 1] = table.concat({ w, w, w }, " | ")
    end
    return table.concat(out, " || ")
end

-- Every button text built from a global (litemount/Globals.lua S.texts), in order.
function M.buttons()
    local out = {}
    for _, t in ipairs(S().texts) do out[#out + 1] = tostring(t[1]:GetText()) end
    return table.concat(out, " | ")
end
function M.buttonsExpect(want)
    local out = {}
    for _, t in ipairs(S().texts) do
        local w = Want(t[2], want)
        if not w then return nil end
        out[#out + 1] = w
    end
    return table.concat(out, " | ")
end
-- The texts of the buttons named by one global.
function M.buttonsOf(g)
    local out = {}
    for _, t in ipairs(S().texts) do if t[2] == g then out[#out + 1] = tostring(t[1]:GetText()) end end
    return table.concat(out, " | ")
end
function M.setButtons(g, s) for _, t in ipairs(S().texts) do if t[2] == g then t[1]:SetText(s) end end end

-- The binding dropdowns: the shown text, then its four radios; rules first (picked 1), then advanced (picked 2).
local BIND = { { "rules", 1 }, { "advanced", 2 } }
function M.bind()
    local out = {}
    for _, b in ipairs(BIND) do
        local d = S().bind[b[1]]
        out[#out + 1] = tostring(d.dd.Text:GetText()) .. " | " .. table.concat(d.radios, " | ")
    end
    return table.concat(out, " || ")
end
-- word: the text before the number (nil: our word for want "uk", else KEY_BINDING).
function M.bindExpect(want, word)
    word = word or Want("KEY_BINDING", want)
    if not word then return nil end
    local out = {}
    for _, b in ipairs(BIND) do
        local r = {}
        for i = 1, 4 do r[i] = word .. " " .. i end
        out[#out + 1] = word .. " " .. b[2] .. " | " .. table.concat(r, " | ")
    end
    return table.concat(out, " || ")
end
function M.bindTheirs()
    for _, b in ipairs(BIND) do
        if rawget(S().bind[b[1]].dd, "menuGenerator") ~= S().bindingGenerator then return false end
    end
    return true
end

-- Rule lines with a condition named by a global. A known place shows "<name> (<id>)": its name is English
-- (a game name we do not have), so that line is whole English, on and off.
local CONDS = { { "instance:531", "INSTANCE", " : 531" }, { "instance:249", "INSTANCE", " : Wobbly Keep (249)", true },
    { "level:60", "LEVEL", " : 60" }, { "map:9999", "BRAWL_TOOLTIP_MAP", "" },
    { "map:249", "BRAWL_TOOLTIP_MAP", " : Wobbly Keep (249)", true }, { "falling", "STRING_ENVIRONMENTAL_DAMAGE_FALLING", "" } }
function M.conds()
    local out = {}
    for _, c in ipairs(CONDS) do out[#out + 1] = tostring(S().ruleLine(c[1])) end
    return table.concat(out, " | ")
end
function M.condsExpect(want)
    local out = {}
    for _, c in ipairs(CONDS) do
        local w = Want(c[2], c[4] and "en" or want)
        if not w then return nil end
        out[#out + 1] = w .. c[3]
    end
    return table.concat(out, " | ")
end
