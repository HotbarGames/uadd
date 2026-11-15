-- Extra generic WoW API stubs for loading the Dungeon Journal. Loaded after the harness stubs,
-- before any addon. Only additions: nothing here replaces a harness definition, and nothing
-- fakes the addon's own logic. flow_dj.py lists the names in DJ_STUBS in its summary.
local H = HARNESS
H.djStubs = H.djStubs or {}

local function stub(name, value)
    if rawget(_G, name) == nil then
        rawset(_G, name, value)
        H.djStubs[#H.djStubs + 1] = name
    end
end

-- (filled in below, after a run showed which ones the journal needs)
