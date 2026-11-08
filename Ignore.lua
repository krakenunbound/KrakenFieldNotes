-- Kraken Field Notes: who you've ignored, and why.
--
-- Ignored: this character's ignore list (C_FriendList, by GUID, unit or name), and,
-- when Kraken Ignore Sync is installed, its account-wide list, so someone ignored on
-- another of your characters shows as ignored here too.
--
-- Why: the last few things each player said in chat are kept for a while (in memory
-- only, never saved). When you ignore someone, a note is written for them at once,
-- rated Bad unless you'd already rated them, with when, where and what they'd said,
-- so you remember why. Ignores that Ignore Sync copies over from another character
-- get no new note: that character wrote it already (notes are account-wide).

local ADDON, FN = ...
local Safe, Plain = FN.Safe, FN.Plain

FN.IGNORED_ICON = "Interface\\Icons\\Spell_Holy_Silence"

local KEEP_LINES = 3          -- per player
local KEEP_SECONDS = 30 * 60  -- how long a line is remembered
local MAX_PEOPLE = 300

---------------------------------------------------------------- is this player ignored?
local function SyncedIgnores()
    local db = rawget(_G, "KrakenIgnoreSync_DB")
    return type(db) == "table" and type(db.entries) == "table" and db.entries or nil
end

local function SyncedEntry(key)
    local entries = SyncedIgnores()
    if not entries or not key then return nil end
    for k, entry in pairs(entries) do
        local name = type(entry) == "table" and entry.name or k
        if FN.Key(name) == key or FN.Key(k) == key then return entry end
    end
end

local function SyncedActive(entry)
    return type(entry) == "table" and (entry.added or 0) > (entry.removed or -1)
end

local function Ask(fn, arg)
    if not (C_FriendList and type(fn) == "function") or arg == nil then return nil end
    local ok, value = pcall(fn, arg)
    return ok and Plain(value) or nil
end

-- true when the player is ignored here or (with Ignore Sync) on any of your characters.
function FN.IsIgnored(unit, name, guid)
    local CF = C_FriendList
    if CF then
        if guid and Ask(CF.IsIgnoredByGuid, guid) == true then return true end
        if unit and Ask(CF.IsIgnored, unit) == true then return true end
        if name and Ask(CF.IsIgnored, name) == true then return true end
    end
    return SyncedActive(SyncedEntry(FN.Key(name)))
end

function FN.UnitIgnored(unit)
    if not FN.UnitIsOtherPlayer(unit) then return false end
    return FN.IsIgnored(unit, FN.UnitFullName(unit), Safe(UnitGUID, unit))
end

---------------------------------------------------------------- what they said
local heard, people = {}, 0   -- [key] = { {at, where, text}, ... }

local CHANNEL_NAMES = {
    CHAT_MSG_SAY = "say", CHAT_MSG_YELL = "yell", CHAT_MSG_EMOTE = "emote", CHAT_MSG_WHISPER = "whisper",
    CHAT_MSG_PARTY = "party", CHAT_MSG_PARTY_LEADER = "party", CHAT_MSG_RAID = "raid", CHAT_MSG_RAID_LEADER = "raid",
    CHAT_MSG_INSTANCE_CHAT = "instance", CHAT_MSG_INSTANCE_CHAT_LEADER = "instance", CHAT_MSG_GUILD = "guild",
    CHAT_MSG_OFFICER = "officer", CHAT_MSG_CHANNEL = "channel",
}

function FN.Heard(event, msg, author, channelName)
    msg, author = Plain(msg), Plain(author)
    if type(msg) ~= "string" or msg == "" or type(author) ~= "string" then return end
    local key = FN.Key(author)
    if not key or key == FN.Key(FN.UnitFullName("player")) then return end
    if not heard[key] then
        if people >= MAX_PEOPLE then wipe(heard); people = 0 end
        heard[key] = {}
        people = people + 1
    end
    local list = heard[key]
    local where = CHANNEL_NAMES[event] or "chat"
    channelName = Plain(channelName)
    if event == "CHAT_MSG_CHANNEL" and type(channelName) == "string" and channelName ~= "" then
        where = channelName:gsub("^%d+%.%s*", "")
    end
    list[#list + 1] = { at = GetTime(), where = where, text = msg:gsub("|", "||") }
    while #list > KEEP_LINES do table.remove(list, 1) end
end

local function RecentLines(key)
    local list = key and heard[key]
    if not list then return nil end
    local out, now = {}, GetTime()
    for _, line in ipairs(list) do
        if now - line.at <= KEEP_SECONDS then out[#out + 1] = ("(%s) \"%s\""):format(line.where, line.text) end
    end
    return #out > 0 and out or nil
end
FN.RecentLines = RecentLines

---------------------------------------------------------------- noticing a new ignore
local known = nil      -- [key] = display name, this character's list as last read
local loginAt = 0
local EARLY = 120      -- seconds after login when a lone new name may still be the list loading

local function CurrentIgnores()
    local list = {}
    local CF = C_FriendList
    local count = CF and Safe(CF.GetNumIgnores) or 0
    for i = 1, tonumber(count) or 0 do
        local name = Safe(CF.GetIgnoreName, i)
        if type(name) == "string" and name ~= "" and name ~= (Plain(UNKNOWN) or "Unknown") then
            local key = FN.Key(name)
            if key then list[key] = name end
        end
    end
    return list
end

local function Stamp()
    local when = type(date) == "function" and date("%Y-%m-%d %H:%M") or "today"
    local zone = Safe(GetRealZoneText) or Safe(GetZoneText)
    return when, (type(zone) == "string" and zone ~= "") and zone or nil
end

-- Writes (or adds to) the note for somebody you just ignored.
function FN.NoteIgnore(name, guid)
    if not FN.db.settings.autonote then return end
    local key = FN.Key(name)
    if not key then return end
    -- Copied over by Ignore Sync from another character: that one wrote the note.
    local synced = SyncedEntry(key)
    local me = (Safe(UnitName, "player") or "") .. "-"
    if synced and type(synced.addedBy) == "string" and synced.addedBy:sub(1, #me) ~= me
        and (synced.added or 0) < (Safe(GetServerTime) or time()) - 5 then
        return
    end
    local when, zone = Stamp()
    local line = ("Ignored %s%s."):format(when, zone and (" in " .. zone) or "")
    local said = RecentLines(key)
    if said then line = line .. " Last said: " .. table.concat(said, " ") end
    if #line > 900 then line = line:sub(1, 897) .. "..." end
    local rec = FN.Get(key)
    local text = rec and rec.text and rec.text ~= "" and (rec.text .. "\n" .. line) or line
    if #text > 1000 then text = text:sub(-1000) end
    FN.Set(rec and rec.name or name, text, rec and rec.rating or "bad", guid)
    FN.Say(("Noted why you ignored %s. /fn %s to add more."):format(rec and rec.name or name, rec and rec.name or name))
end

-- Which new names on the list are you ignoring somebody, rather than the list loading.
-- The server sends the list some time after login (sometimes well after), all at once,
-- and Ignore Sync fills in names from your other characters in a burst. You ignore
-- people one at a time. So:
--   * the first list read is the starting point;
--   * several new names in one update are the list loading, never you;
--   * one new name is you, except in the first two minutes after login, where it
--     counts only if they'd said something (a one-name list loading looks the same).
local function OnIgnoreList()
    local now = CurrentIgnores()
    local before = known
    known = now
    if before then
        local added = {}
        for key, name in pairs(now) do
            if not before[key] then added[#added + 1] = { key = key, name = name } end
        end
        if #added == 1 then
            local one = added[1]
            if GetTime() - loginAt >= EARLY or RecentLines(one.key) then FN.NoteIgnore(one.name) end
        end
    end
    FN.Changed()
end

function FN.InitIgnore()
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_LOGIN")
    events:RegisterEvent("IGNORELIST_UPDATE")
    for event in pairs(CHANNEL_NAMES) do events:RegisterEvent(event) end
    events:SetScript("OnEvent", function(_, event, a1, a2, _, _, _, _, _, _, a9)
        if event == "IGNORELIST_UPDATE" then
            OnIgnoreList()
        elseif event == "PLAYER_LOGIN" then
            -- The list arriving after login isn't you ignoring anyone (see OnIgnoreList).
            -- If nothing arrives at all, the list as it stands two minutes in is the
            -- starting point.
            known, loginAt = nil, GetTime()
            C_Timer.After(EARLY, function() if not known then known = CurrentIgnores() end end)
        else
            FN.Heard(event, a1, a2, a9)
        end
    end)
end
