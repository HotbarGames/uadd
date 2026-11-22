-- Harness stand-in for Road to Sixty (not the addon): same global frame names, made-up English.
-- Its `ns` is private, as in the addon: nothing here is reachable except by frame name, print, tooltip and popup.
-- S.T        the made-up texts by role (the flow reads them; real English is fed at run time by H2)
-- S.Count(n) "<n> zone(s)" the English way; S.When(d, m) a date with an English month; S.Glued(zone) "Entered <zone>"
-- S.Calls    how many SetText calls the stand-in made, by key (a count for the cache step)
RoadToSixtyDB = RoadToSixtyDB or { runs = { { name = "Quix", level = 12, zone = "Zorpvale" } }, note = "kept" }
RoadToSixtyCache = RoadToSixtyCache or {}
RoadToSixtyCharDB = RoadToSixtyCharDB or { journal = { "Entered Zorpvale" } }

local S = { Calls = 0, Settext = {} }
RTSStandIn = S

S.T = {
    title = "Wobbly Journey Map", tabA = "Zorp tab", tabB = "Quix tab", tabC = "Flim tab",
    button = "Gizmo go", info = "Rank %d - %s - %s", news = "Whatsit Fresh", newsHead = "Fixed gizmos",
    compare = "Flim compare", options = "Road to Sixty", optHead = "Wobbly options", optCheck = "Show the gizmo",
    optButton = "Reset gizmos", mini = "Zorp Journey", tipLine = "Click for the gizmo map",
    say = "Gizmo saved", glued = "Entered %s", count = "%d zone%s", reset = "Reset all gizmo data?",
    -- shaped as the addon's: the name, then "?", then more lines (so the whole text is one multi-line template)
    del = "Delete the gizmo %s?\n\nIts wobbly data goes too.", rem = "Remove friend %s?\n\nThe gizmo stays.", yes = "Yes gizmo", no = "No gizmo",
}
S.MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }
S.DAYS = { "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun" }

-- Every text goes through here, so a count of SetText calls is one place.
function S.Put(fs, text, key)
    S.Calls = S.Calls + 1
    S.Settext[key or fs] = (S.Settext[key or fs] or 0) + 1
    fs:SetText(text)
end

function S.Count(n) return string.format(S.T.count, n, n == 1 and "" or "s") end
function S.When(d, m) return S.DAYS[(d - 1) % 7 + 1] .. " " .. d .. " " .. S.MONTHS[m] end
function S.Glued(zone) return string.format(S.T.glued, zone) end
function S.Info(level, zone, played) return string.format(S.T.info, level, zone, played) end
