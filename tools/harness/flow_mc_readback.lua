-- Lua helpers for flow_mc_readback.py (docs/LESSONS5.md lesson 48, last rule): Mastercraft's fitters set a size
-- by SetFont with the font GetFont gives, so while our font is on they hand our Cyrillic file to its SetFont
-- wrappers, which keep that file and use it again later. Reached from Python as HARNESS.mcRead. Run before the
-- game starts. Two strings shaped like Mastercraft's own, on the stand-in (tools/harness/mastercraft):
--   * "loc", like its ns.Text: its SetFont keeps the file in mcPath; its SetText puts a font with other letters
--     on for a name in another alphabet (mcScript) and, after it, mcPath again;
--   * the hub tile's first line, like its ns.RawText: its SetFont keeps the file in a local of its own (no mc*
--     field), its SetText the same alphabet swap with that kept file.
-- Its own file here is not the game's default one, so a give-back of "the default" is told from its own.
local H = HARNESS
local R = {}
H.mcRead = R

local OWN, SCRIPT = "Fonts\\MORPHEUS.TTF", "Fonts\\2002.TTF"
R.OWN, R.SCRIPT = OWN, SCRIPT
local function S() return rawget(_G, "MastercraftStandIn") end
local function NS() return H.ns.UADD_Mastercraft end
local function Other(t) return type(t) == "string" and t:find("\206", 1, true) ~= nil end   -- Greek letters

local strings = {}

-- Like its ns.Text (Locale.lua LocalizeFontString), on a stand-in string made now (found on the next frame).
local frame
function R.loc(name, text)
    if not frame then frame = CreateFrame("Frame", nil, MastercraftFrame) end
    local fs = S().Text(frame, name, 12)
    local set, font = rawget(fs, "mcSetText"), rawget(fs, "mcSetFont")
    fs.mcPath, fs.mcSize, fs.mcFlags = OWN, 12, ""
    font(fs, OWN, 12, "")
    fs.SetFont = function(self, p, s, f)
        self.mcPath = p
        self.mcSize, self.mcFlags = s, f
        return font(self, self.mcScript or self.mcPath, s, f)
    end
    fs.SetText = function(self, t)
        rawset(self, "mcRaw", t)
        if Other(t) then
            self.mcScript = SCRIPT
            font(self, SCRIPT, self.mcSize, self.mcFlags)
        elseif self.mcScript then
            self.mcScript = nil
            font(self, self.mcPath, self.mcSize, self.mcFlags)
        end
        return set(self, t)
    end
    strings[name] = fs
    fs:SetText(text)
    H.step(0.05) H.step(0.05)
end

-- Like its ns.RawText, on the stand-in hub's tile line (Raw.lua marks it on the next frame).
function R.raw(empty, text)
    S().Hub(empty)
    local fs = S().hub.tile.l1
    local set, font = fs.SetText, fs.SetFont
    local base = { OWN, 11, "" }
    font(fs, OWN, 11, "")
    fs.SetFont = function(self, p, s, fl)
        base = { p, s, fl }
        if self.mcScript then return font(self, self.mcScript, s, fl) end
        return font(self, p, s, fl)
    end
    fs.SetText = function(self, t)
        if Other(t) then
            if self.mcScript ~= SCRIPT then font(self, SCRIPT, base[2], base[3]) end
            self.mcScript = SCRIPT
        elseif self.mcScript then
            self.mcScript = nil
            font(self, base[1], base[2], base[3])
        end
        return set(self, t)
    end
    strings.raw = fs
    fs:SetText(text)
    H.step(0.05) H.step(0.05)
end

-- Its fitter: a new size with the font read back (Mastercraft's own call, never UADD's).
function R.readBack(name, size)
    local fs = strings[name]
    local p, _, f = fs:GetFont()
    fs:SetFont(p, size, f)
    H.step(0.05)
end
function R.set(name, text) strings[name]:SetText(text) H.step(0.05) end
-- A language switch: it sets each string's kept font again (Locale.lua), then its text.
function R.again(name)
    local fs = strings[name]
    fs:SetFont(rawget(fs, "mcPath") or OWN, rawget(fs, "mcSize") or 12, rawget(fs, "mcFlags") or "")
    H.step(0.05)
end

-- text, file, size, its kept mcPath ("" when none), Cyrillic in the text, the file is UADD's Cyrillic one.
function R.state(name)
    local fs = strings[name]
    local p, s = fs:GetFont()
    local t = fs:GetText() or ""
    return t, p or "", s or 0, rawget(fs, "mcPath") or "", (UADD.Plain(t) or t):find("[\208-\210]") ~= nil,
        UADD.IsCyrFont(p) and true or false
end

function R.want(key)
    local uk = NS().MC.exact[key]
    return uk and UADD.Plural(uk, true) or ""
end
