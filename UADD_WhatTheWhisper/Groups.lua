-- A group thread's name stays English (lesson 14).
-- Its GroupChat.Label names a party, raid, guild ... thread with a word of its locale table, and that name is
-- kept in the thread and saved into its history (and its export file). Most of those words are STAY (Swap.lua),
-- but one is drawn elsewhere too (a profile row), so it is ours in its table. The wrap gives such a name its
-- English back: ours read back to its key, or, when two keys share ours, that one call run with its English in
-- (Swap.WithEnglish). A channel's own name and any text that is not ours pass as they are.
-- Repair: a group thread named with ours before this (an older UADD) gets its English back, in the thread and in
-- its saved record, only while the module is on and only when ours is exactly the word for its own label.
-- Its own errors still reach it; ours are reported and counted (lesson 19) and give its own name. Plain pcall:
-- it must keep working after an off for errors. No English of it is stored here.

local _, ns = ...
local U = UADD
local G = {}
ns.Groups = G

local labels              -- { orig = its Label, fn = ours } while ours wraps it

local function Report(err)
    err = tostring(err)
    pcall(U.ReportError, err)
    if type(U.Fault) == "function" then pcall(U.Fault, "wtw", err) end
end

local function GroupChat()
    local a = ns.Swap.Addon()
    local GC = a and a.GroupChat
    return type(GC) == "table" and GC or nil
end

local function Channel(id)
    local GC = GroupChat()
    return GC and type(GC.Target) == "function" and GC.Target(id) == "CHANNEL"
end

-- Its English for a name it gave the thread `id`, or the name as it is.
local function Back(orig, name, id)
    local W = ns.Swap
    if not W.On() or type(name) ~= "string" then return name end
    local k = W.English(name)
    if k == nil and not W.Ours(name) then return name end
    if Channel(id) then return name end
    if k then return k end
    local en = W.WithEnglish(orig, id)
    return type(en) == "string" and en or name
end

function G.Install()
    local GC = GroupChat()
    if labels or not GC or type(GC.Label) ~= "function" then return end
    local orig = GC.Label
    local function fn(id, ...)
        local name = orig(id, ...)
        local ok, en = pcall(Back, orig, name, id)
        if ok then return en end
        Report(en)
        return name
    end
    labels = { orig = orig, fn = fn }
    GC.Label = fn
end

-- Off: its own function back, unless someone wrapped it after us (ours then only passes its English through).
function G.Remove()
    local GC = GroupChat()
    if labels and GC and GC.Label == labels.fn then
        GC.Label = labels.orig
        labels = nil
    end
end

-- The English for one of its group threads named with ours, or nil.
local function Fixed(id, name)
    local W, GC = ns.Swap, GroupChat()
    if type(id) ~= "string" or type(name) ~= "string" or not GC or not W.Ours(name) then return nil end
    if type(GC.IsGroupID) ~= "function" or not GC.IsGroupID(id) or Channel(id) then return nil end
    local en = W.WithEnglish(labels and labels.orig or GC.Label, id)
    if type(en) == "string" and en ~= name and W.Translate(en) == name then return en end
    return nil
end

local function Repair()
    if not ns.On() then return 0 end
    local a, n = ns.Swap.Addon(), 0
    ns.Swap.Build()
    local CM, H = a and a.ConversationManager, a and a.History
    local ok, convs = U.SafeCall(type(CM) == "table" and CM.All)
    for id, conv in pairs(ok and type(convs) == "table" and convs or {}) do
        local en = type(conv) == "table" and conv.isGroup and Fixed(id, conv.name)
        if en then conv.name, n = en, n + 1 end
    end
    local ok2, recs = U.SafeCall(type(H) == "table" and H.AllRecords)
    for id, rec in pairs(ok2 and type(recs) == "table" and recs or {}) do
        local en = type(rec) == "table" and Fixed(id, rec.n)
        if en then rec.n, n = en, n + 1 end
    end
    return n
end

-- Thread names and saved records it put back to English (for the checks).
function G.Repair()
    local ok, n = pcall(Repair)
    if ok then return n end
    Report(n)
    return 0
end
