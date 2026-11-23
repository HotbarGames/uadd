-- UADD - LootTriage: our font on a text of its window, its menus and the panel row, and its own font back.
--
-- Our font on a text, read back; true when it can draw Cyrillic now (lessons 2, 18, 38, 44). Its own font is saved
-- first, never while ours is on; a Cyrillic font OBJECT of ours goes on (no file pinned: menu rows, game labels);
-- only where that does not take, and never on a menu row, the file by hand (U.CyrOnOwn). fonted[fs]: the record
-- U.FontBack gives back, or true for a font that had our letters already (nothing to give back).

local _, ns = ...
local U = UADD
local F = { fonted = {} }
ns.Fonts = F
local fonted = F.fonted

local function IsCyr(fs) local ok, p = pcall(fs.GetFont, fs) return ok and U.IsCyrFont(p) end

function F.On(fs)
    if IsCyr(fs) then
        fonted[fs] = fonted[fs] or true
        return true
    end
    local okS, was = pcall(U.SaveFont, fs)
    if not okS or type(was) ~= "table" then return false end
    local ok, took = pcall(U.CyrOnLocked, fs)
    if not (ok and took) and not U.Locked(fs) then ok, took = pcall(U.CyrOnOwn, fs, was) end
    if ok and took and IsCyr(fs) then fonted[fs] = was return true end
    pcall(U.FontBack, fs, was)                    -- whole English, never half a font
    fonted[fs] = nil
    return false
end

-- Its own font back, only while ours is on (a font set on it since is its own: left as it is).
function F.Off(fs)
    local was = fonted[fs]
    if not was then return end
    fonted[fs] = nil
    if type(was) == "table" and IsCyr(fs) then pcall(U.FontBack, fs, was) end
end
