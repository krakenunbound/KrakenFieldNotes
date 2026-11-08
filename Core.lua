-- Kraken Field Notes: notes about other players, with a good / neutral / bad rating
-- shown wherever you meet them again: over their nameplate, on your target frame,
-- on their paper doll when you inspect them, in their tooltip and beside their chat.

local ADDON, FN = ...
_G.KrakenFieldNotes = FN

FN.VERSION = "3.1.1"

-- The three ratings: label, colour and the symbol drawn for them.
FN.RATINGS = {
    good = { label = "Good", r = 0.25, g = 1.0, b = 0.3, hex = "40ff4d",
             icon = "Interface\\RaidFrame\\ReadyCheck-Ready" },
    neutral = { label = "Neutral", r = 1.0, g = 0.8, b = 0.3, hex = "ffcc4d",
                icon = "Interface\\Buttons\\UI-GuildButton-PublicNote-Up" },
    bad = { label = "Bad", r = 1.0, g = 0.25, b = 0.25, hex = "ff4040",
            icon = "Interface\\RaidFrame\\ReadyCheck-NotReady" },
}
FN.RATING_ORDER = { "good", "neutral", "bad" }

local DEFAULTS = {
    notes = {},
    settings = { nameplates = true, target = true, inspect = true, tooltip = true, chat = true,
                 ignored = true, autonote = true },
}

function FN.Say(msg)
    print("|cffffb347Kraken Field Notes:|r " .. msg)
end

-- Anything the client hands back may be a secret value (Forever), which can't be
-- compared or used as a key. Those read as "unknown".
function FN.Plain(value)
    if type(issecretvalue) == "function" and issecretvalue(value) then return nil end
    return value
end
local Plain = FN.Plain

local function Safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if ok then return Plain(a), Plain(b), Plain(c) end
end
FN.Safe = Safe

local function UniqueNames()
    return Safe(RegionalUniqueNamesEnabled) == true
end

local function OwnRealm()
    local realm = Safe(GetNormalizedRealmName) or Safe(GetRealmName) or ""
    return (realm:gsub("%s", ""))
end

---------------------------------------------------------------- names
-- The full name as the game spells it: "Prime Arnold" on Forever (first name and
-- surname), "Name-Realm" for another realm elsewhere, plain "Name" otherwise.
function FN.FullName(name, second)
    name, second = Plain(name), Plain(second)
    if type(name) ~= "string" or name == "" or name == (Plain(UNKNOWNOBJECT) or "Unknown") then return nil end
    if type(second) == "string" and second ~= "" then
        if UniqueNames() then return name .. " " .. second end
        if second:gsub("%s", "") ~= OwnRealm() then return name .. "-" .. second end
    end
    return name
end

-- The identity two spellings share: case-insensitive, "-" and " " alike, our own
-- realm suffix dropped. "Prime Arnold", "prime-arnold" and "Prime-Arnold-<realm>"
-- are one key.
function FN.Key(name)
    name = Plain(name)
    if type(name) ~= "string" or name == "" then return nil end
    name = name:lower()
    local realm = OwnRealm():lower()
    if realm ~= "" and name:sub(-(#realm + 1)) == "-" .. realm then name = name:sub(1, -(#realm + 2)) end
    name = name:gsub("[%-%s]+", " "):match("^%s*(.-)%s*$")
    return name ~= "" and name or nil
end

function FN.UnitIsOtherPlayer(unit)
    if not unit then return false end
    return Safe(UnitExists, unit) == true and Safe(UnitIsPlayer, unit) == true
end

function FN.UnitFullName(unit)
    if not unit then return nil end
    local ok, name, second = pcall(UnitName, unit)
    if not ok then return nil end
    return FN.FullName(name, second)
end

---------------------------------------------------------------- notes
local byGuid = {}   -- [guid] = key, rebuilt at load

local function Index()
    wipe(byGuid)
    for key, rec in pairs(FN.db.notes) do
        if type(rec.guids) == "table" then
            for guid in pairs(rec.guids) do byGuid[guid] = key end
        end
    end
end

function FN.Get(key)
    local rec = key and FN.db and FN.db.notes[key]
    if rec and ((rec.text and rec.text ~= "") or rec.rating) then return rec end
end

-- The note for a unit: by its GUID first (survives renames, and is readable when the
-- name isn't), then by name. Learns the GUID of a note found by name.
function FN.ForUnit(unit)
    if not FN.db or not FN.UnitIsOtherPlayer(unit) then return nil end
    local guid = Safe(UnitGUID, unit)
    if guid and byGuid[guid] then
        local rec = FN.Get(byGuid[guid])
        if rec then return rec, byGuid[guid] end
    end
    local key = FN.Key(FN.UnitFullName(unit))
    local rec = FN.Get(key)
    if rec and guid then
        rec.guids = rec.guids or {}
        if not rec.guids[guid] then rec.guids[guid] = true; byGuid[guid] = key end
    end
    return rec, key
end

function FN.ForName(name)
    local key = FN.Key(name)
    return FN.Get(key), key
end

-- Saves (or, with no text and no rating, erases) the note for `name`.
function FN.Set(name, text, rating, guid)
    local key = FN.Key(name)
    if not key then return nil end
    text = strtrim(text or "")
    if rating ~= "good" and rating ~= "bad" and rating ~= "neutral" then rating = nil end
    local prev = FN.db.notes[key]
    if text == "" and not rating then
        if prev and prev.guids then for g in pairs(prev.guids) do byGuid[g] = nil end end
        FN.db.notes[key] = nil
    else
        local rec = prev or { created = time(), guids = {} }
        rec.name = Plain(name) or rec.name
        rec.text, rec.rating, rec.updated = text, rating or "neutral", time()
        if guid then rec.guids = rec.guids or {}; rec.guids[guid] = true; byGuid[guid] = key end
        FN.db.notes[key] = rec
    end
    FN.Changed()
    return key
end

-- Everything that shows a marker redraws when a note changes.
local listeners = {}
function FN.OnChange(fn) listeners[#listeners + 1] = fn end
function FN.Changed()
    for _, fn in ipairs(listeners) do pcall(fn) end
end

function FN.Rating(rec)
    return FN.RATINGS[rec and rec.rating or "neutral"] or FN.RATINGS.neutral
end

-- "|T...|t" for a rating's symbol, sized for text.
function FN.IconText(rec, size)
    return ("|T%s:%d:%d|t"):format(FN.Rating(rec).icon, size or 14, size or 14)
end

---------------------------------------------------------------- load
local function CopyDefaults(src, dst)
    for k, v in pairs(src) do
        if dst[k] == nil then
            dst[k] = type(v) == "table" and {} or v
            if type(v) == "table" then CopyDefaults(v, dst[k]) end
        elseif type(v) == "table" and type(dst[k]) == "table" then
            CopyDefaults(v, dst[k])
        end
    end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, _, name)
    if name ~= ADDON then return end
    KrakenFieldNotesDB = KrakenFieldNotesDB or {}
    CopyDefaults(DEFAULTS, KrakenFieldNotesDB)
    FN.db = KrakenFieldNotesDB
    Index()
    FN.InitEditor()
    FN.InitMarkers()
    FN.InitIgnore()
    FN.InitCommands()
    self:UnregisterEvent("ADDON_LOADED")
end)
