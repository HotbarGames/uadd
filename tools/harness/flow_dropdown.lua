-- Lua side of the dropdown list checks (flow_dropdown.py): the lists of the dropdowns in
-- Questie's older options window get our Cyrillic font on their Ukrainian items while open, and
-- every item has its own font back once released, given plain text, or with the module off.
local H = HARNESS
local F = H.flow

local CYR = "[\208-\210]"

local function Gui() return LibStub("AceGUI-3.0") end
local function HF() return H.ns.UADD_Questie.HeaderFont end
local function IsCyr(fs) return UADD.IsCyrFont((fs:GetFont())) end
local function Font(fs) return { fs:GetFont() } end
local function Same(a, b) return a[1] == b[1] and a[2] == b[2] and a[3] == b[3] end
local function Show(a) return ("%s %s %s"):format(tostring(a[1]), tostring(a[2]), tostring(a[3])) end
local function HasCyr(item)
    local t = item.text and item.text:GetText()
    return type(t) == "string" and t:find(CYR) ~= nil
end

-- The first shown dropdown of Questie's window with Ukrainian items in its list.
local function Find()
    for _, w in ipairs(H.widgets()) do
        local d = w.obj
        if type(d) == "table" and d.type == "Dropdown" and d.userdata.appName == "Questie"
            and d.frame:IsVisible() and d.pullout then
            for _, item in ipairs(d.pullout.items) do
                if HasCyr(item) then return d end
            end
        end
    end
end

local function Click(d) H.call("OnClick", d.button.__scripts.OnClick, d.button, "LeftButton") end
local function Open(d) if not d.open then Click(d) end return d.open end
local function Close(d) if d.open then Click(d) end end

-- How many items with Ukrainian text are in our font / in a font without Ukrainian letters.
local function Count(d)
    local cyr, latin = 0, 0
    for _, item in ipairs(d.pullout.items) do
        if HasCyr(item) then
            if IsCyr(item.text) then cyr = cyr + 1 else latin = latin + 1 end
        end
    end
    return cyr, latin
end

-- Items whose font is not the one they had before (path, size, flags), as text.
local function Changed(orig)
    local bad = {}
    for fs, old in pairs(orig) do
        if not Same(Font(fs), old) then bad[#bad + 1] = Show(Font(fs)) .. " was " .. Show(old) end
    end
    return #bad == 0, table.concat(bad, "; ", 1, math.min(#bad, 3))
end

local function Boxes()
    local n = 0
    for _, line in ipairs(H.cyrBoxes(200)) do
        if line:find("AceGUI30DropDownItem", 1, true) then n = n + 1 end
    end
    return n
end

-- A shown dropdown of `app`; with `value`, one whose closed value (d.text) shows Cyrillic.
local function FindOf(app, value)
    for _, w in ipairs(H.widgets()) do
        local d = w.obj
        if type(d) == "table" and d.type == "Dropdown" and d.userdata.appName == app and d.frame:IsVisible()
            and (not value or HasCyr({ text = d.text })) then
            return d
        end
    end
end

-- Hidden FontStrings still in our font that show one of `words`: parts of released widgets that
-- AceGUI keeps in its pool for any addon (its pools are local, so they are found this way).
-- Returns how many, and their texts.
local function Pooled(words)
    local n, seen = 0, {}
    for _, w in ipairs(H.widgets()) do
        if w.GetObjectType and w:GetObjectType() == "FontString" and not w:IsVisible() and words[w:GetText() or ""]
            and IsCyr(w) then
            n = n + 1
            seen[#seen + 1] = w:GetText()
        end
    end
    return n, table.concat(seen, ", ")
end

-- An options window of our own, served by UADD/AceFont.lua as OpenMap's is (UADD_OpenMap/Module.lua):
-- a Ukrainian header, toggle and select in one tab, a toggle in the other.
local function App(Check)
    local AF, ACD, on = UADD.AceFont, LibStub("AceConfigDialog-3.0"), true
    AF.Register("UADDTest", function() return on end)
    local function Get() return "a" end
    local function Set() end
    LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("UADDTest", { type = "group", childGroups = "tab",
        args = {
            g1 = { type = "group", name = "Перша", order = 1, args = {
                h = { type = "header", name = "Заголовок", order = 1 },
                t = { type = "toggle", name = "Їжак", order = 2, get = Get, set = Set },
                s = { type = "select", name = "Ґанок", order = 3, values = { a = "Єнот", b = "Кіт" }, get = Get, set = Set },
            } },
            g2 = { type = "group", name = "Друга", order = 2, args = {
                t = { type = "toggle", name = "Інше", get = Get, set = Set },
            } },
        } })
    ACD:Open("UADDTest")
    local d = FindOf("UADDTest")
    Check("own app: a select dropdown", d)
    if not d then return end
    Check("own app: the select's label and closed value in our font", IsCyr(d.label) and IsCyr(d.text),
        Show(Font(d.label)) .. " / " .. Show(Font(d.text)))
    Open(d)
    local cyr, latin = Count(d)
    Check("own app: the open select's items in our font", cyr == 2 and latin == 0, cyr .. " ours, " .. latin .. " not")
    Close(d)
    local n1 = AF.Count("UADDTest")
    local first = { ["Заголовок"] = 1, ["Їжак"] = 1, ["Ґанок"] = 1, ["Єнот"] = 1, ["Кіт"] = 1 }
    local all = { ["Перша"] = 1, ["Друга"] = 1, ["Інше"] = 1 }
    for k in pairs(first) do all[k] = 1 end
    ACD:SelectGroup("UADDTest", "g2")                -- drawn again on the next frame
    H.step()
    H.step()
    local p, left = Pooled(first)
    Check("own app: other tab: the first tab's widgets released in their own fonts", p == 0, p .. ": " .. left)
    Check("own app: other tab: its toggle in our font", n1 > 0 and AF.Count("UADDTest", "CheckBox") >= 1,
        n1 .. " before, " .. AF.Count("UADDTest", "CheckBox") .. " check boxes")
    ACD:Close("UADDTest")                            -- AceConfigDialog closes it on the next frame
    H.pump(5, function() return not ACD.OpenFrames["UADDTest"] end)
    p, left = Pooled(all)
    Check("own app: closed: nothing in our font, nothing pooled in it", AF.Count("UADDTest") == 0 and p == 0,
        AF.Count("UADDTest") .. " counted; " .. p .. " hidden: " .. left)
    on = false
end

-- After "off" the font follows the text: Ukrainian (kept until a reload) in a Cyrillic font, never a box; English set
-- (as after the reload; a button's through the button, QuestieOptionsControls.lua:929) in its own font again.
local function Put(fs, text)
    local b = fs:GetParent()
    if type(b) == "table" and b.GetFontString and b:GetFontString() == fs then b:SetText(text) else fs:SetText(text) end
end
local function Follows(fs)
    local t = fs:GetText()
    if type(t) == "string" and t:find("[\208-\210]") and fs:IsVisible() and not IsCyr(fs) then
        return false, "Ukrainian in " .. Show(Font(fs))
    end
    Put(fs, "General")
    return not IsCyr(fs), "English in " .. Show(Font(fs))
end

-- The Ukrainian buttons of Questie's own window ("Моя подорож"), and how many are in our font.
local function Buttons()
    local buttons, inOurs = {}, 0
    for _, control in ipairs(rawget(_G, "QuestieOptionsTab_Popup_general").controls) do
        local fs = control.widget and control.widget.GetFontString and control.widget:GetFontString()
        if fs and HasCyr({ text = fs }) then buttons[#buttons + 1] = fs end
    end
    for _, fs in ipairs(buttons) do if IsCyr(fs) then inOurs = inOurs + 1 end end
    return buttons, inOurs
end

-- Questie 12.12 has no older window (no AceConfigDialog, no QuestieOptions module): only the
-- buttons of its own window and our own options window are left to check.
local function NoOldWindow(Check)
    local shared = { GameFontNormalSmall:GetFont() }
    QuestieLoader:ImportModule("QuestieOptionsEngine"):ShowFrame()
    local buttons, inOurs = Buttons()
    Check("buttons: in our font", #buttons > 0 and inOurs == #buttons, inOurs .. "/" .. #buttons)
    HF().Stop()
    local back, why = 0, ""
    for _, fs in ipairs(buttons) do
        local t = fs:GetText()
        local ok, w = Follows(fs)
        if ok then back = back + 1 elseif why == "" then why = " " .. w end
        Put(fs, t)                                   -- Questie's Ukrainian again, for "on again"
    end
    Check("off: buttons: Ukrainian in Cyrillic font, English in own", back == #buttons, back .. "/" .. #buttons .. why)
    HF().Start()
    Check("on again: buttons in our font", select(2, Buttons()) == #buttons, select(2, Buttons()) .. "/" .. #buttons)
    Check("GameFontNormalSmall unchanged", Same({ GameFontNormalSmall:GetFont() }, shared),
        Show({ GameFontNormalSmall:GetFont() }))
end

-- Returns { name, "1" or "0", detail, ... }. old: Questie still has its older options window.
function F.dropdown(old)
    local out = {}
    local function Check(name, ok, detail)
        out[#out + 1] = name
        out[#out + 1] = ok and "1" or "0"
        out[#out + 1] = tostring(detail or "")
    end
    if not old then
        NoOldWindow(Check)
        App(Check)
        return out
    end
    local ACD = LibStub("AceConfigDialog-3.0")
    local shared = { GameFontNormalSmall:GetFont() }
    if not QuestieConfigFrame:IsShown() then QuestieLoader:ImportModule("QuestieOptions"):ToggleConfigWindow() end
    local d = Find()
    Check("a Questie dropdown with Ukrainian items", d, QuestieConfigFrame:IsShown())
    if not d then return out end

    local orig = {}
    for _, item in ipairs(d.pullout.items) do orig[item.text] = Font(item.text) end
    local first
    for _, item in ipairs(d.pullout.items) do if HasCyr(item) then first = first or item end end

    -- Open: our font on the Ukrainian items, same size and flags; nothing for the guard.
    Check("opens", Open(d))
    local cyr, latin = Count(d)
    local sized = true
    for fs, old in pairs(orig) do
        local p, size, flags = fs:GetFont()
        if size ~= old[2] or flags ~= old[3] then sized = false end
    end
    Check("open: Ukrainian items in our font", cyr > 0 and latin == 0, cyr .. " ours, " .. latin .. " not")
    Check("open: size and flags kept", sized)
    Check("open: guard sees no item", Boxes() == 0, Boxes())
    Check("open: counted", HF().ItemCount() == cyr, HF().ItemCount())

    -- AceGUI or another addon sets a font on the item while it shows our text: ours goes back on.
    first.text:SetFontObject(GameFontNormalSmall)
    Check("font reset while open: ours again", IsCyr(first.text), Show(Font(first.text)))
    -- Plain text on the item: its own font back.
    local was = first.text:GetText()
    first:SetText("Plain")
    Check("plain text: own font back", Same(Font(first.text), orig[first.text]), Show(Font(first.text)))
    first:SetText(was)
    Close(d)

    -- Released (Questie's window is drawn again): every item has its own font back.
    Open(d)
    ACD:Open("Questie", QuestieConfigFrame)
    Check("released: own font back", Changed(orig))
    Check("released: none counted", HF().ItemCount() == 0, HF().ItemCount())
    local pooled = 0
    for item in pairs(Gui().objPools and Gui().objPools["Dropdown-Item-Toggle"] or {}) do
        if item.text and IsCyr(item.text) then pooled = pooled + 1 end
    end
    Check("released: no pooled item in our font", pooled == 0, pooled)

    -- Another addon's dropdown gets the pooled items: Cyrillic text, but no font of ours.
    d = Find()
    Open(d)
    d:SetList({ a = "Plain" })                       -- our items go back to the pool
    local other = Gui():Create("Dropdown")
    other.frame:SetPoint("CENTER")
    other:SetList({ a = "Кіт", b = "Їжак", c = "Ґанок" })
    Open(other)
    local oc = Count(other)
    Check("another addon's dropdown: not our font", oc == 0, oc)
    Close(other)
    Gui():Release(other)
    ACD:Open("Questie", QuestieConfigFrame)          -- Questie's own lists again

    -- In combat nothing is changed.
    d = Find()
    H.combat = true
    Open(d)
    cyr = Count(d)
    Close(d)
    H.combat = false
    Check("combat: nothing changed", cyr == 0, cyr)

    -- "/uadd questie off" while open: own fonts back at once; opening again changes nothing.
    orig = {}
    for _, item in ipairs(d.pullout.items) do orig[item.text] = Font(item.text) end
    -- The Ukrainian buttons of Questie's own window ("Моя подорож"): our font, own font on "off".
    local buttons, inOurs = Buttons()
    Check("buttons: in our font", #buttons > 0 and inOurs == #buttons, inOurs .. "/" .. #buttons)

    local v = FindOf("Questie", true)
    Check("closed dropdown: its Ukrainian value in our font", v and IsCyr(v.text), v and Show(Font(v.text)))
    Open(d)
    local before = HF().ItemCount()
    HF().Stop()
    Check("off: the closed dropdown's value: Ukrainian in a Cyrillic font, English in its own",
        v and Follows(v.text), v and Show(Font(v.text)))
    local back = 0
    for _, fs in ipairs(buttons) do if Follows(fs) then back = back + 1 end end
    Check("off: buttons: Ukrainian in a Cyrillic font, English in their own", back == #buttons, back .. "/" .. #buttons)
    local ok, detail = Changed(orig)
    Check("off: own font back", before > 0 and ok and HF().ItemCount() == 0, before .. " before; " .. detail)
    Close(d)
    Open(d)
    cyr = Count(d)
    Close(d)
    Check("off: opening changes nothing", cyr == 0, cyr)
    HF().Start()

    QuestieConfigFrame:Hide()
    Check("GameFontNormalSmall unchanged", Same({ GameFontNormalSmall:GetFont() }, shared),
        Show({ GameFontNormalSmall:GetFont() }))
    App(Check)
    return out
end
