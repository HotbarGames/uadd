-- Lua side of the Questie 12.8 options control checks (flow_controls.py): row titles, descriptions,
-- container titles, slider texts, a dropdown's value and its menu entries get our Cyrillic font at
-- their own size and flags (UADD_Questie/ControlFont.lua); the old font comes back exactly.
local H = HARNESS
local F = H.flow

local CYR = "[\208-\210]"
local function AF() return H.ns.UADD_Questie.ControlFont end   -- its Original: the font from before ours
local function Engine() return QuestieLoader:ImportModule("QuestieOptionsEngine") end
local function l10n(s) return QuestieLoader:ImportModule("l10n")(s) end
local function IsCyr(fs) return UADD.IsCyrFont((fs:GetFont())) end
local function HasCyr(fs) local t = fs:GetText() return type(t) == "string" and t:find(CYR) ~= nil end
local function Font(fs) local p, s, fl = fs:GetFont() return ("%s %s %s"):format(tostring(p), tostring(s), tostring(fl)) end

local function Strings(frame, out)
    for _, r in ipairs({ frame:GetRegions() }) do
        if r:GetObjectType() == "FontString" then out[#out + 1] = r end
    end
    for _, c in ipairs({ frame:GetChildren() }) do
        if rawget(c, "itemData") == nil then Strings(c, out) end
    end
    return out
end

local function Kind(control, fs)
    local w, item = control.widget, control.itemData or {}
    if fs == control.titleFrame then return item.type == "container" and "container" or "title" end
    if fs == control.descriptionFrame then return "description" end
    if type(w) == "table" and (fs == w.Text or fs == w.Low or fs == w.High) then
        return rawget(w, "SetupMenu") and "dropdown" or "slider"
    end
    return "other"
end

-- Every control FontString with Ukrainian text on a canvas: { fs, kind, control }. A row's title
-- and description are on a wrapper frame parented to the row's parent, not to the row
-- (QuestieOptionsControls.lua:101-106), so the row's own references come first; a container's
-- walk reaches its rows' wrappers too, and those texts keep the row's kind.
local function Texts(canvas)
    local out, seen = {}, {}
    local function Add(fs, control)
        if fs and not seen[fs] and HasCyr(fs) then
            seen[fs] = true
            out[#out + 1] = { fs, Kind(control, fs), control }
        end
    end
    for _, control in ipairs(canvas.controls or {}) do
        Add(rawget(control, "titleFrame"), control)
        Add(rawget(control, "descriptionFrame"), control)
    end
    for _, control in ipairs(canvas.controls or {}) do
        for _, fs in ipairs(Strings(control, {})) do Add(fs, control) end
    end
    return out
end

local function Built(canvas)
    canvas:Show()
    H.pump(400, function() return canvas.UpdateScrollLayout ~= nil end, 0.05)
    H.pump(20, nil, 0.05)                      -- HeaderFont's Look comes 0.1 s later
end

-- Is one text right: in our font, at the size and flags it had (AF.Original)?
local function Right(fs)
    local p, s, fl, _ = AF().Original(fs)
    local cp, cs, cfl = fs:GetFont()
    return IsCyr(fs) and p ~= nil and not UADD.IsCyrFont(p) and s == cs and (fl or "") == (cfl or "")
end

local function Blizz(key) return rawget(_G, "QuestieOptionsTab_Blizz_" .. key) end

-- Builds every settings-panel tab; per kind: texts in our font at their size / all Ukrainian texts.
-- Then only the general tab stays shown. Returns "kind ok/n ..." and up to 3 wrong ones.
function F.controlFonts()
    local counts, bad = {}, {}
    for key in pairs(Engine().tabs) do
        local canvas = Blizz(key)
        if canvas then
            Built(canvas)
            for _, t in ipairs(Texts(canvas)) do
                local c = counts[t[2]] or { 0, 0 }
                counts[t[2]] = c
                c[2] = c[2] + 1
                if Right(t[1]) then c[1] = c[1] + 1
                elseif #bad < 3 then bad[#bad + 1] = ("%s/%s %s: %s"):format(key, t[2], Font(t[1]), t[1]:GetText():sub(1, 40)) end
            end
            if key ~= "general" then canvas:Hide() end
        end
    end
    local parts = {}
    for _, k in ipairs({ "title", "description", "container", "slider", "dropdown", "other" }) do
        if counts[k] then parts[#parts + 1] = ("%s %d/%d"):format(k, counts[k][1], counts[k][2]) end
    end
    return table.concat(parts, ", "), table.concat(bad, "; ")
end

-- The general tab again after its scroll box laid it out anew and its texts were set up again as a
-- reused frame is (font object first, then the text); a dropdown's value set again. All still ours?
function F.controlRecycle()
    local canvas = Blizz("general")
    canvas:Hide()
    Built(canvas)
    canvas.UpdateScrollLayout()
    local n, ok = 0, 0
    for _, t in ipairs(Texts(canvas)) do
        local fs, text = t[1], t[1]:GetText()
        fs:SetFontObject(fs:GetFontObject() or "GameFontNormal")
        fs:SetText(text)
        if t[2] == "dropdown" then t[3].widget:GenerateMenu() end
        n = n + 1
        if Right(fs) then ok = ok + 1 end
    end
    return ok, n
end

-- A Questie dropdown's menu: Ukrainian entries in our font while open; once closed, its entry frames
-- shown by another addon get their own font back, and another addon's Ukrainian is left alone.
function F.controlMenu()
    local drop
    for key in pairs(Engine().tabs) do
        local canvas = Blizz(key)
        for _, control in ipairs(canvas and canvas.controls or {}) do
            local w = control.widget
            if not drop and type(w) == "table" and rawget(w, "SetupMenu") then
                w:OpenMenu()
                local m = w.menu
                for _, e in ipairs(m and m.entries or {}) do
                    if e:IsShown() and HasCyr(e.fontString) then drop = w break end
                end
                if not drop then w:CloseMenu() end
            end
        end
    end
    if not drop then return false, "no Questie dropdown with Ukrainian entries" end
    local m, open, cyr = drop.menu, 0, 0
    for _, e in ipairs(m.entries) do
        if e:IsShown() and HasCyr(e.fontString) then
            cyr = cyr + 1
            if Right(e.fontString) then open = open + 1 end
        end
    end
    drop:CloseMenu()
    local other, left = 0, 0
    for i, e in ipairs(m.entries) do
        e.fontString:SetFontObject("GameFontHighlightSmall")
        e.fontString:SetText(i == 1 and "\208\134\208\189\209\136\208\181" or "Other addon")   -- "Інше"
        if not IsCyr(e.fontString) then
            if i == 1 then left = 1 else other = other + 1 end
        end
    end
    local ok = cyr > 0 and open == cyr and other == #m.entries - 1 and left == 1
    return ok, ("open %d/%d ours; after close: %d/%d English own font, other addon's Ukrainian left %s")
        :format(open, cyr, other, #m.entries - 1, left == 1 and "alone" or "changed")
end

-- One Ukrainian row title of the general tab, and the font it had before ours.
local function Sample()
    for _, t in ipairs(Texts(Blizz("general"))) do
        if t[2] == "title" and Right(t[1]) then return t[1] end
    end
end

local function Exact(fs, want)
    local p, s, fl = fs:GetFont()
    return p == want[1] and s == want[2] and fl == want[3] and fs:GetFontObject() == want[4]
end

-- The show-original key held: a text Questie sets now is English and has exactly its own font; let
-- go, Ukrainian again in ours. Then combat: an English text set in combat keeps ours until it ends.
function F.controlShift()
    local fs = Sample()
    if not fs then return false, "no Ukrainian row title" end
    local text, want = fs:GetText(), { AF().Original(fs) }
    F.key("SHIFT", true)
    F.wait(0.5)
    fs:SetText(l10n("General"))
    local english = fs:GetText() == "General" and Exact(fs, want)
    F.key("SHIFT", false)
    F.wait(0.5)
    fs:SetText(l10n("General"))
    local back = HasCyr(fs) and Right(fs) and fs:GetFont() ~= want[1] and select(2, fs:GetFont()) == want[2]
    H.combat = true
    fs:SetText("General")
    local held = IsCyr(fs)
    H.combat = false
    H.fire("PLAYER_REGEN_ENABLED")
    local after = Exact(fs, want)
    fs:SetText(text)
    local ok = english and back and held and after and Right(fs)
    return ok, ("held: English %s; let go: ours %s; combat: kept %s, after %s"):format(
        tostring(english), tostring(back), tostring(held), tostring(after))
end

-- Questie 12.13's own window: its search label, and a search that builds the shown tab again with no
-- OnShow (QuestieOptionsEngine.lua:532-574). Returns the label's font ok, then ok/n of the rebuilt tab's
-- Ukrainian texts in our font (and whether its content was swapped), the search cleared after.
function F.controlSearch()
    local E = Engine()
    E:ShowFrame()
    H.pump(20, nil, 0.05)
    local label = E.popup and E.popup.searchLabel
    local labelOk = label ~= nil and HasCyr(label) and Right(label)
    local canvas = rawget(_G, "QuestieOptionsTab_Popup_general")
    if not canvas then return labelOk, 0, 0, false end
    Built(canvas)
    local old = canvas.content
    E:SetSearchText(l10n("General"))
    H.pump(400, function() return canvas.content ~= old end, 0.05)
    H.pump(20, nil, 0.05)
    local n, ok = 0, 0
    for _, t in ipairs(Texts(canvas)) do
        n = n + 1
        if Right(t[1]) then ok = ok + 1 end
    end
    local swapped = canvas.content ~= old
    E:SetSearchText("")
    H.pump(20, nil, 0.05)
    E:HideFrame()
    return labelOk, ok, n, swapped
end

-- Before "/uadd questie off": every control text in our font now, with the font it had before.
function F.controlSnapshot()
    local canvas = Blizz("general")
    Built(canvas)
    H.controlSnap = {}
    for _, t in ipairs(Texts(canvas)) do
        if Right(t[1]) then H.controlSnap[#H.controlSnap + 1] = { t[1], { AF().Original(t[1]) } } end
    end
    return #H.controlSnap
end

-- After it. The font follows the text: a shown text that still shows Ukrainian keeps a Cyrillic font (a Latin one
-- there is a box). Then English set on each (as Questie draws it after a reload): exactly its old font object,
-- file, size and flags again. Returns (Ukrainian ok, English ok, n, the first wrong one).
function F.controlAfterOff()
    local cyr, ok, bad = 0, 0, nil
    for _, s in ipairs(H.controlSnap or {}) do
        local fs = s[1]
        if not (HasCyr(fs) and fs:IsVisible()) or IsCyr(fs) then cyr = cyr + 1
        elseif not bad then bad = "Ukrainian in " .. Font(fs) end
        fs:SetText("General")
        if Exact(fs, s[2]) then ok = ok + 1
        elseif not bad then bad = "English in " .. Font(fs) .. " want " .. tostring(s[2][1]) .. " " .. tostring(s[2][2]) end
    end
    return cyr, ok, #(H.controlSnap or {}), bad or ""
end
