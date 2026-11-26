-- Harness widgets, part 2: methods that only store a value or do nothing visible.
local H = HARNESS
local Widget = H.Widget

-- Pure setters with no effect the addons can observe.
for _, name in ipairs({ "SetMotionScriptsWhileDisabled", "SetPropagateKeyboardInput", "EnableKeyboard",
    "SetVerticalScroll", "SetHorizontalScroll", "UpdateScrollChildRect", "SetOrientation", "SetStatusBarColor",
    "SetObeyStepOnDrag", "SetValueStep", "SetResizable", "SetResizeBounds", "SetMinResize", "SetMaxResize",
    "StartMoving", "StartSizing", "StopMovingOrSizing", "SetUserPlaced", "SetDontSavePosition", "SetIgnoreParentAlpha",
    "SetIgnoreParentScale", "SetScale", "SetFlattensRenderLayers", "SetClipsChildren", "SetShadowColor",
    "SetShadowOffset", "SetSpacing", "SetIndentedWordWrap", "SetTextInsets", "SetHighlightColor", "SetFading",
    "SetFadeDuration", "SetTimeVisible", "SetInsertMode", "SetMaxResize", "SetCountInvisibleLetters",
    "SetHyperlinksEnabled", "SetJustifyH", "SetRotation", "SetSnapToPixelGrid", "SetTexelSnappingBias",
    "SetHorizTile", "SetVertTile", "SetGradient", "SetMask", "AddMaskTexture", "SetStartPoint", "SetEndPoint",
    "SetThickness", "SetFromAlpha", "SetToAlpha", "SetDuration", "SetLooping", "SetOrder", "SetSmoothing",
    "SetStartDelay", "SetOffset", "SetScaleFrom", "SetScaleTo", "SetChange", "SetTarget", "SetChildKey",
    "LockHighlight", "UnlockHighlight", "SetButtonState", "Click", "RegisterForMouse", "SetMouseClickEnabled",
    "SetMouseMotionEnabled", "SetCooldown", "Clear", "SetDrawEdge", "SetDrawSwipe",
    "SetHideCountdownNumbers", "SetReverse", "SetSwipeColor", "SetFrameBuffer", "SetPadding", "SetMinimumWidth",
    "SetAnchorType", "AddTexture", "SetHyperlink", "SetBagItem", "SetInventoryItem", "SetUnit", "SetSpellByID",
    "SetItemByID", "SetQuestLogItem", "SetText_", "FadeOut", "AppendText", "ScrollToBottom", "ScrollToTop",
    "SetBackdropColor", "SetBackdropBorderColor", "ApplyBackdrop", "SetCursor", "SetArrowShown",
    "SetPortraitToAsset", "EnableMouseWheel", "SetCursorPosition", "HighlightText", "SetPortraitTextureRaw", "SetDragTarget" }) do
    if not Widget[name] then Widget[name] = function() end end
end

-- Button textures and font objects: real child regions, so Get* returns what Set* gave.
for _, part in ipairs({ "Normal", "Pushed", "Highlight", "Disabled", "Checked", "DisabledChecked", "Thumb",
    "StatusBar" }) do
    local key = "__tex" .. part
    Widget["Set" .. part .. "Texture"] = function(self, t)
        local tex = rawget(self, key) or self:CreateTexture()
        rawset(self, key, tex)
        if type(t) == "table" then rawset(self, key, t) else tex:SetTexture(t) end
    end
    Widget["Get" .. part .. "Texture"] = function(self)
        local tex = rawget(self, key) or self:CreateTexture()
        rawset(self, key, tex)
        return tex
    end
    Widget["Set" .. part .. "Atlas"] = function(self, a) Widget["Get" .. part .. "Texture"](self):SetAtlas(a) end
end
for _, part in ipairs({ "Normal", "Highlight", "Disabled" }) do
    Widget["Set" .. part .. "FontObject"] = function(self, o) rawset(self, "__font" .. part, o) end
    Widget["Get" .. part .. "FontObject"] = function(self) return rawget(self, "__font" .. part) end
end
function Widget:SetScrollChild(c) rawset(self, "__scrollChild", c) end
function Widget:GetScrollChild() return rawget(self, "__scrollChild") end
function Widget:GetVerticalScroll() return 0 end
function Widget:GetHorizontalScroll() return 0 end
function Widget:GetVerticalScrollRange() return 0 end
function Widget:GetHorizontalScrollRange() return 0 end
function Widget:IsUserPlaced() return false end
function Widget:GetBoundsRect() return 0, 0, self.__w, self.__h end
function Widget:GetRect() return 0, 0, self.__w, self.__h end
function Widget:GetScaledRect() return 0, 0, self.__w, self.__h end
function Widget:IsMouseEnabled() return false end
function Widget:IsMouseMotionFocus() return false end
function Widget:IsDragging() return false end
function Widget:GetButtonState() return "NORMAL" end
function Widget:GetAnimationGroups() return end
function Widget:GetTextWidth() return self:GetStringWidth() end
function Widget:GetPadding() return 0 end
function Widget:GetJustifyH() return "CENTER" end
function Widget:GetJustifyV() return "MIDDLE" end
function Widget:GetSpacing() return 0 end
function Widget:GetShadowColor() return 0, 0, 0, 1 end
function Widget:GetShadowOffset() return 0, 0 end
function Widget:GetCursorPosition() return 0 end
function Widget:GetNumLetters() local t = self:GetText() return t and #t or 0 end
function Widget:GetZoom() return rawget(self, "__zoom") or 0 end
function Widget:SetZoom(z) rawset(self, "__zoom", z) end
function Widget:GetZoomLevels() return 6 end
function Widget:GetPingPosition() return 0, 0 end
function Widget:GetAtlas() return rawget(self, "__atlas") end
function Widget:GetTexCoord() return 0, 1, 0, 1 end
function Widget:GetTextureFilePath() return rawget(self, "__tex") end
function Widget:GetTextureFileID() return 0 end
function Widget:GetDrawLayer() return "ARTWORK", 0 end
function Widget:GetBlendMode() return "BLEND" end
function Widget:IsDesaturated() return false end
function Widget:GetRotation() return 0 end
function Widget:GetHyperlinksEnabled() return false end

TOOLTIP_DEFAULT_COLOR = CreateColor(1, 1, 1)
TOOLTIP_DEFAULT_BACKGROUND_COLOR = CreateColor(0, 0, 0)
C_UIFileAsset = { IsKnownFile = function() return true end }
C_CurrencyInfo = { GetCurrencyInfo = function() return nil end, GetCoinTextureString = function(n) return tostring(n) end,
    GetBasicCurrencyInfo = function() return nil end, GetCurrencyLink = function() return nil end }
for _, name in ipairs({ "SetToFinalAlpha", "SetAlphaFromBoolean" }) do Widget[name] = function() end end
function CloseMenus() end
function Widget:SetAttribute(k, v) local a = rawget(self, "__attr") or {} rawset(self, "__attr", a) a[k] = v end
function Widget:GetAttribute(k) local a = rawget(self, "__attr") return a and a[k] end
function Widget:IsMovable() return rawget(self, "__movable") or false end
function Widget:IsResizable() return false end
function Widget:IsProtected() return false end
function Widget:GetWrappedWidth() return self:GetStringWidth() end
function Widget:SetTextToFit(t) self:SetText(t) end
function Widget:GetValueStep() return 1 end
function Widget:EnableGamePadButton() end
function Widget:GetCanvasScale() return 1 end
function Widget:GetNormalizedCursorPosition() return 0.5, 0.5 end
function Widget:SetPassThroughButtons(...) rawset(self, "__pass", { ... }) end
function Widget:ShouldButtonPassThrough(b)
    for _, x in ipairs(rawget(self, "__pass") or {}) do if x == b then return true end end
    return false
end

-- The guard: shown FontStrings with Ukrainian letters in a font file that has none (the game
-- draws them as squares). The fonts with Ukrainian letters are UADD/Font.lua's list (UADD.IsCyrFont).
-- Returns { "frame font: text", ... }, at most `limit` (default 10). Text that UALL Forever put
-- there (its ns.replacements) is marked "UALLF frame".
-- Skipped: text in a top frame nothing ever placed or showed. AceGUI makes its dropdown lists
-- like that (AceGUIWidget-DropDown.lua: SetPoint and Show() come only when the list opens); the
-- game draws no frame without a point, but frames here start shown, so they only look shown.
local function Unplaced(w)
    local top = w
    while top.__parent and top.__parent ~= UIParent do top = top.__parent end
    return top ~= UIParent and #top.__points == 0 and not top.__showed
end

function H.cyrBoxes(limit)
    local out, isCyr = {}, rawget(_G, "UADD") and UADD.IsCyrFont
    if not isCyr then return out end
    local uall = H.ns.UALLF and H.ns.UALLF.replacements or {}
    for _, w in ipairs(H.widgets()) do
        local t = w.__type == "FontString" and w.__text
        if type(t) == "string" and t:find("[\208\209]") and w:IsVisible() and (w.__alpha or 1) > 0
            and not Unplaced(w) then
            local font = w.__font and w.__font[1]
            if not isCyr(font) and #out < (limit or 10) then
                local p, name = w, nil
                while p and not name do name = p.__name p = p.__parent end
                if uall[w] then name = "UALLF " .. tostring(name) end  -- UALL Forever put this text there
                out[#out + 1] = ("%s %s: %s"):format(name or "?", tostring(font), t:sub(1, 60))
            end
        end
    end
    return out
end

-- As in the client: a font object's new font (SetFont) reaches every line drawn in it now, except a line with
-- a file set by hand (__hand, wow_widgets.lua). Natively: no Lua hook on the line runs; the box check, which
-- wraps Widget's own methods, still looks.
-- As in the client (docs/LESSONS4.md lesson 47): an edit box's GetFontObject gives its own font record, a
-- nameless Font ("Font <UnknownFile:0>" in a crash log) whose GetFontObject is the object set on the box;
-- its getters and setters are the box's. A font object set so that it inherits from itself (the box's own
-- record on the box, or any loop) makes the client recurse in C until the game dies: here H.Crash, and
-- nothing changes.
do
    local getObject = Widget.GetFontObject
    local function Record(box)
        local r = rawget(box, "__record")
        if not r then
            r = H.newWidget("Font")
            r.__fs, r.__boxOf = box, box                 -- its text methods reach the box (textTarget)
            rawset(box, "__record", r)
        end
        return r
    end
    function Widget:GetFontObject()
        if rawget(self, "__type") == "EditBox" then return Record(self) end
        return getObject(self)
    end
    -- The font record a widget draws with: an edit box's record, a button's font string, else the widget.
    local function Node(w)
        if type(w) == "string" then w = rawget(_G, w) end
        if type(w) ~= "table" then return nil end
        if rawget(w, "__type") == "EditBox" then return Record(w) end
        if rawget(w, "__boxOf") then return w end
        return rawget(w, "__fs") or w
    end
    H.fontNode = Node
    -- What it inherits from. CopyFontObject only copies (no link, __copied), though the harness keeps the
    -- object it copied in __fontObject for boxes.lua's families.
    local function Parent(n)
        local t = rawget(n, "__boxOf") or n
        if rawget(t, "__copied") then return nil end
        return Node(rawget(t, "__fontObject"))
    end
    function H.fontLoop(w, o)
        local node, p, seen = Node(w), Node(o), {}
        for _ = 1, 1000 do
            if p == nil then return false end
            if p == node or seen[p] then return true end
            seen[p], p = true, Parent(p)
        end
        return true
    end
end

do
    local setFont, setObject = Widget.SetFont, Widget.SetFontObject
    local copying = false
    function Widget:CopyFontObject(o)
        copying = true
        local ok, err = pcall(self.SetFontObject, self, o)
        copying = false
        if not ok then error(err, 0) end
        local t = rawget(self, "__boxOf") or rawget(self, "__fs") or self
        rawset(t, "__copied", true)
    end
    function Widget:SetFontObject(o)
        if not copying and H.fontLoop(self, o) then
            H.Crash("font object inherits from itself: " .. tostring(self))
        end
        if not copying then
            local t = rawget(self, "__boxOf") or rawget(self, "__fs") or self
            if rawget(t, "__copied") then rawset(t, "__copied", nil) end
        end
        local r = setObject(self, o)
        if type(o) == "string" then o = rawget(_G, o) end
        local fs = rawget(self, "__fs") or self
        if type(o) == "table" and rawget(o, "__type") == "Font" and rawget(fs, "__type") ~= "Font" then
            local users = rawget(o, "__users") or setmetatable({}, { __mode = "k" })   -- lines only, no objects
            rawset(o, "__users", users)
            users[fs] = true
        end
        return r
    end
    function Widget:SetFont(...)
        local r = setFont(self, ...)
        local users = rawget(self, "__type") == "Font" and r and rawget(self, "__users")
        for u in pairs(users or {}) do
            if rawget(u, "__fontObject") == self and not rawget(u, "__hand") then Widget.SetFontObject(u, self) end
        end
        return r
    end
end

-- In the client every frame of a kind shares one method table (getmetatable(f).__index), where the core
-- helper U.WidgetMethods (UADD/Widgets.lua) hooks CreateFontString for U.OnNewFontString. The harness looks
-- methods up through a function, so that one file is shown the table the function reads.
do
    local realMeta, SHARED = getmetatable, { __index = Widget }
    getmetatable = function(x)
        if type(x) == "table" and rawget(x, "__type") ~= nil and rawget(x, 0) == x then
            local info = debug.getinfo(2, "S")
            if info and (info.source or ""):find("AddOns/UADD/Widgets.lua", 1, true) then return SHARED end
        end
        return realMeta(x)
    end
end
