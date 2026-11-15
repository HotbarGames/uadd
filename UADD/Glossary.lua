-- UADD: the shared word base. One entry per meaning, not per English text.
-- Modules read a word with UADD.Glossary.Text("ui.settings"). The words are in glossary/*.lua.
-- How to add a word or decide "same meaning": docs/GLOSSARY.md. Checked by tools/glossary.py.
UADD = UADD or {}

local G = UADD.Glossary or {}
UADD.Glossary = G
G.entries = G.entries or {} -- id -> { id, en = { ... }, uk, note }
G.order = G.order or {}     -- ids, in the order they were added
G.missing = G.missing or {} -- id -> true, for ids a module asked for that are not here
G.duplicates = G.duplicates or {} -- ids added twice (the first one is kept)

-- Add one entry: { id = "ui.close", en = "Close" or { "Close", ... }, uk = "Закрити", note = "..." }
function G.Add(e)
    if type(e) ~= "table" or type(e.id) ~= "string" or type(e.uk) ~= "string" then
        return
    end
    if G.entries[e.id] then
        G.duplicates[#G.duplicates + 1] = e.id
        return
    end
    if type(e.en) == "string" then
        e.en = { e.en }
    end
    G.entries[e.id] = e
    G.order[#G.order + 1] = e.id
end

-- The Ukrainian text for a meaning id, or nil (and the id is noted in G.missing).
function G.Text(id)
    local e = G.entries[id]
    if e then
        return e.uk
    end
    G.missing[id] = true
    return nil
end
