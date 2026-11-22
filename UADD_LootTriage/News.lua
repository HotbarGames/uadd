-- UADD - LootTriage: its What's New dialog.
--
-- The dialog has no name and one text. It is found as a child of UIParent (dialog strata, one font string,
-- the diamond border) after a click on one of the two buttons that open it. A post-hook on that text's SetText
-- puts ours in at once, line by line, so the addon's next step (it reads the text's height to size the
-- dialog, lesson 26) measures ours. A line we cannot do stays English; a line with no small letters (its
-- version line, a blank) stays as it is. Our font is read back; when it cannot draw Cyrillic, the English goes
-- back. Off and the hold key give the English back while the text is still ours (lesson 23).

local _, ns = ...
local U = UADD
local N = {}
ns.News = N

local W = ns.Words
local find, sub, match, concat = string.find, string.sub, string.match, table.concat
local fs, rec, busy = nil, nil, false
local watched = {}

local function Wanted() return ns.WordsWanted() end

local function One(line)
    if line == "" then return line end
    local uk = W.Translate(line)
    if uk then return uk end
    if sub(line, 1, 2) == "- " then
        local rest = sub(line, 3)
        uk = W.Translate(rest)
        if uk then return "- " .. uk end
        local name, what = match(rest, "^(|c%x%x%x%x%x%x%x%x[^|]*|r) (.+)$")
        local a, b = name and W.Translate(name), what and W.Translate(what)
        if a and b then return "- " .. a .. " " .. b end
    end
    return line
end

local function Ours(text)
    local out, i, any = {}, 1, false
    while true do
        local p = find(text, "\n", i, true)
        local line = sub(text, i, p and p - 1 or #text)
        local uk = One(line)
        if uk ~= line then any = true end
        out[#out + 1] = uk
        if not p or #out > 400 then break end
        i = p + 1
    end
    return any and concat(out, "\n") or nil
end

local function Set(text)
    busy = true
    pcall(fs.SetText, fs, text)
    busy = false
end

-- Its size for the text it shows now, as the addon's own page call sizes it after its SetText (the same widths,
-- wider when too tall for the screen, then the height): for a swap made after that call (a toggle, the first find).
local function Fit()
    local f = fs and fs.GetParent and fs:GetParent()
    if not f or not f.IsShown or not f:IsShown() or not UIParent then return end
    f:SetWidth(480)
    fs:SetWidth(440)
    if fs:GetStringHeight() + 73 > UIParent:GetHeight() - 145 then
        f:SetWidth(720)
        fs:SetWidth(680)
    end
    f:SetHeight(fs:GetStringHeight() + 73)
end

local function OnSet(self, text)
    if busy or self ~= fs then return end
    rec = nil
    if not Wanted() or type(text) ~= "string" or #text > 20000 then return end
    local uk = Ours(text)
    if not uk then return end
    Set(uk)
    if ns.Screen.Font(fs) then rec = { en = text, uk = uk } return end
    Set(text)
    ns.Screen.Unfont(fs)
end

local function IsDialog(f)
    if type(f) ~= "table" or (f.IsForbidden and f:IsForbidden()) then return nil end
    if not f.GetFrameStrata or f:GetFrameStrata() ~= "FULLSCREEN_DIALOG" then return nil end
    local one, border
    for _, r in ipairs(U.Regions(f)) do
        local kind = r.GetObjectType and r:GetObjectType()
        if kind == "FontString" then
            if one then return nil end
            one = r
        elseif kind == "Texture" and r.GetAtlas and r:GetAtlas() == "UI-DiamondDialogBox-Border" then
            border = true
        end
    end
    return border and one or nil
end

local function Find()
    if fs then return fs end
    for _, c in ipairs(U.Children(UIParent)) do
        local ok, one = pcall(IsDialog, c)                -- a forbidden or odd child is skipped
        if ok and one then
            fs = one
            hooksecurefunc(one, "SetText", ns.Guard(OnSet))
            OnSet(one, one:GetText())
            if rec then pcall(Fit) end                    -- it was sized for its English before we came
            break
        end
    end
    return fs
end

-- A button that opens it: after its click, the dialog is there.
function N.Watch(button)
    if type(button) ~= "table" or watched[button] or not button.HookScript then return end
    watched[button] = true
    button:HookScript("OnClick", ns.Guard(Find))
end

-- The panel's own button for it sits on the panel's Defaults button.
function N.Install()
    local list = SettingsPanel and SettingsPanel.Container and SettingsPanel.Container.SettingsList
    local d = list and list.Header and list.Header.DefaultsButton
    if d then
        for _, c in ipairs(U.Children(d)) do
            local ok, yes = pcall(function()
                return not (c.IsForbidden and c:IsForbidden()) and c.GetText and c:GetText() == GAMEMENU_NEW_BUTTON
            end)
            if ok and yes then N.Watch(c) end
        end
    end
    Find()
end

function N.Sync()
    if not fs then return end
    local t = fs:GetText()
    local was = t
    if Wanted() then
        if not (rec and t == rec.uk) then OnSet(fs, t) end
    else
        if rec and t == rec.uk then Set(rec.en) end
        rec = nil
        ns.Screen.Unfont(fs)
    end
    if fs:GetText() ~= was then pcall(Fit) end            -- another text: the dialog sized again, as the addon does
end
