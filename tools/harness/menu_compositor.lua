-- A stand-in for the game's menus (Blizzard_Menu: MenuUtil.CreateContextMenu, Menu.GetManager) with
-- the part that broke UADD in the game: the compositor (docs/LESSONS3.md lesson 38).
--
-- The client lends a menu's buttons and FontStrings out with a new metatable: __index is a function
-- that forbids some methods, __newindex a side TABLE that takes every write. Reading a forbidden key
-- ("SetFont" on a FontString; CreateFontString and the like on a frame) gives "Use of function
-- 'SetFont' is disallowed. (Index)", and calling what comes back gives "(Call)". Here both throw AND
-- are kept in HARNESS.compositor.bad, so a pcall around them hides nothing. When the menu closes,
-- each region gets its own metatable back and its default font object again (SetToDefaults).
-- Opt-in: a flow loads this before the game starts (flow_tomtom_menu.py).

local H = HARNESS
local C = { bad = {}, opens = 0 }
H.compositor = C

local BLOCKED = {
    FontString = { SetFont = true },
    Frame = { CreateTexture = true, CreateFontString = true, CreateMaskTexture = true,
        CreateAnimationGroup = true, CreateLine = true, SetForbidden = true },
}
local wrapped = {}        -- region -> its own metatable, while the menu has it

local function Where()
    local tb = debug.traceback("", 3)
    return tb:match("(AddOns/UADD[^\n]-:%d+)") or tb:match("\n%s*([^\n]+)") or "?"
end

local function Forbid(key, how)
    local msg = how == "Index" and ("Use of function '%s' is disallowed. (Index)"):format(key)
        or ("Use of function '%s' is disallowed (Call)."):format(key)
    C.bad[#C.bad + 1] = msg .. " at " .. Where()
    error(msg, 3)
end

-- Region r as the compositor lends it out.
function C.wrap(r)
    if wrapped[r] then return r end
    local own = getmetatable(r)
    local blocked = BLOCKED[rawget(r, "__type") == "FontString" and "FontString" or "Frame"]
    local values = {}
    wrapped[r] = own
    setmetatable(r, {
        __index = function(t, k)
            if blocked[k] then
                Forbid(k, "Index")
                return function() Forbid(k, "Call") end   -- the client's stub (kept for its message)
            end
            local v = values[k]
            if v ~= nil then return v end
            local i = own and own.__index
            if type(i) == "function" then return i(t, k) end
            if type(i) == "table" then return i[k] end
            return nil
        end,
        __newindex = values,
        __tostring = own and own.__tostring,
    })
    return r
end

function C.lent(r) return wrapped[r] ~= nil end

local function Release(r)
    local own = wrapped[r]
    if own == nil then return end
    wrapped[r] = nil
    setmetatable(r, own)
    if rawget(r, "__type") == "FontString" then
        r:SetFontObject(C.default)
        r:SetTextColor(1, 1, 1, 1)
        r:SetText(nil)
    end
end

-- ── The menu frame and its pooled buttons ─────────────────────────────────────────────────────

C.default = rawget(_G, "GameFontHighlightSmall") or CreateFont("HarnessMenuFont")
local menu = CreateFrame("Frame", nil, UIParent)
menu:SetPoint("CENTER")
menu:Hide()
C.menu = menu
local pool = {}

local function Button(i)
    local b = pool[i]
    if not b then
        b = CreateFrame("Button", nil, menu)
        b:SetPoint("TOPLEFT", menu, "TOPLEFT", 0, -16 * i)
        b.fontString = b:CreateFontString(nil, "OVERLAY")
        b.fontString:SetPoint("LEFT", b, "LEFT")
        b.fontString:SetFontObject(C.default)
        b:SetFontString(b.fontString)             -- the button's text is that FontString (no lazy one)
        pool[i] = b
    end
    return b
end

function C.close()
    for _, b in ipairs(pool) do
        Release(b.fontString)
        Release(b)
        b:Hide()
    end
    menu:Hide()
    C.openMenu = nil
end

-- ── Element descriptions (rootDescription and the rest) ───────────────────────────────────────

local Desc = {}
local DescMt = { __index = function(_, k) return Desc[k] or function(self) return self end end }
local function NewDesc(text) return setmetatable({ text = text, items = {}, inits = {} }, DescMt) end
local function Add(self, text)
    local d = NewDesc(text)
    self.items[#self.items + 1] = d
    return d
end
Desc.CreateButton, Desc.CreateTitle, Desc.CreateCheckbox, Desc.CreateRadio = Add, Add, Add, Add
function Desc:AddInitializer(fn) self.inits[#self.inits + 1] = fn end

local function Open(root)
    C.close()
    menu:Show()
    for i, d in ipairs(root.items) do
        local b = Button(i)
        C.wrap(b)
        C.wrap(b.fontString)
        b:Show()
        b.fontString:SetText(d.text)                         -- the default initializer
        for _, init in ipairs(d.inits) do init(b, d, menu) end
    end
    C.openMenu = menu
    C.opens = C.opens + 1
end

-- The rows of the open menu: their FontStrings, in order.
function C.rows()
    local out = {}
    for i, b in ipairs(pool) do if b.__shown then out[i] = b.fontString end end
    return out
end

MenuUtil = rawget(_G, "MenuUtil") or {}
function MenuUtil.CreateContextMenu(owner, generator)
    local root = NewDesc()
    generator(owner, root)
    Open(root)
    return menu
end

local manager = { GetOpenMenu = function() return C.openMenu end, CloseMenus = function() C.close() end }
Menu = rawget(_G, "Menu") or {}
Menu.GetManager = function() return manager end
