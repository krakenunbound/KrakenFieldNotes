-- Kraken Field Notes: the rating symbol wherever a noted player shows up.
--
-- Nameplates: Forever uses the modern nameplate frames. A symbol is added over the
-- player's name on every nameplate that isn't forbidden (C_NamePlate.GetNamePlateForUnit
-- without includeForbidden returns only the ones addons may touch; friendly plates in
-- instances are forbidden). Plates are recycled between units, so every add and
-- remove re-decides the symbol.
--
-- Nothing here is a secure frame or changes one: symbols are our own small frames
-- anchored to Blizzard's, which addons may do at any time, combat included.

local ADDON, FN = ...
local Safe, Plain = FN.Safe, FN.Plain

local function Setting(key) return FN.db and FN.db.settings[key] end

local function Tooltip(owner, rec, hint, ignored, name)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    if rec then
        local r = FN.Rating(rec)
        GameTooltip:AddLine(FN.IconText(rec, 16) .. " Field Note: " .. (rec.name or ""), r.r, r.g, r.b)
    else
        GameTooltip:AddLine(name or "Field Note", 1, 1, 1)
    end
    if ignored then GameTooltip:AddLine(("|T%s:14:14|t Ignored"):format(FN.IGNORED_ICON), 1, 0.4, 0.4) end
    if rec and rec.text and rec.text ~= "" then GameTooltip:AddLine(rec.text, 1, 1, 1, true) end
    if hint then GameTooltip:AddLine(hint, 0.6, 0.6, 0.6) end
    GameTooltip:Show()
end

-- A marker frame with up to two symbols: the rating, and "ignored". With one, it's
-- centred; with both, side by side.
local function MakeSymbols(frame, size)
    frame.size = size
    frame.icon = frame:CreateTexture(nil, "OVERLAY")
    frame.ignore = frame:CreateTexture(nil, "OVERLAY")
    frame.ignore:SetTexture(FN.IGNORED_ICON)
end

local function PaintSymbols(frame, rec, ignored)
    local size = frame.size
    frame.icon:ClearAllPoints()
    frame.ignore:ClearAllPoints()
    if rec then frame.icon:SetTexture(FN.Rating(rec).icon); frame.icon:Show() else frame.icon:Hide() end
    if ignored then frame.ignore:Show() else frame.ignore:Hide() end
    frame.icon:SetSize(size, size)
    frame.ignore:SetSize(size, size)
    if rec and ignored then
        frame:SetSize(size * 2 + 2, size)
        frame.icon:SetPoint("LEFT", frame, "LEFT", 0, 0)
        frame.ignore:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
    else
        frame:SetSize(size, size)
        frame.icon:SetPoint("CENTER", frame, "CENTER", 0, 0)
        frame.ignore:SetPoint("CENTER", frame, "CENTER", 0, 0)
    end
    if rec or ignored then frame:Show() else frame:Hide() end
end

---------------------------------------------------------------- nameplates
local plateUnits = {}   -- [unit token] = true while a plate shows that unit

-- The unit frame inside a plate is taken from a pool each time the plate gets a unit,
-- so the symbol is re-anchored on every update, never left on a frame now showing
-- somebody else.
local function PlateMarker(plate)
    local m = plate.KrakenFieldNotesMarker
    if not m then
        m = CreateFrame("Frame", nil, plate)
        MakeSymbols(m, 20)
        m:Hide()
        plate.KrakenFieldNotesMarker = m
    end
    local uf = plate.UnitFrame
    local anchor = uf and ((uf.name and uf.name:IsShown() and uf.name) or uf.HealthBarsContainer or uf) or plate
    m:ClearAllPoints()
    m:SetPoint("BOTTOM", anchor, "TOP", 0, 2)
    m:SetFrameLevel(((uf or plate):GetFrameLevel() or 0) + 20)
    return m
end

local function UpdatePlate(unit)
    if not C_NamePlate or not C_NamePlate.GetNamePlateForUnit then return end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    plate = ok and plate or nil
    if not plate or (plate.IsForbidden and plate:IsForbidden()) then return end
    local on = Setting("nameplates")
    local rec = on and FN.ForUnit(unit) or nil
    local ignored = on and Setting("ignored") and FN.UnitIgnored(unit) or false
    if rec or ignored then
        PaintSymbols(PlateMarker(plate), rec, ignored)
    elseif plate.KrakenFieldNotesMarker then
        plate.KrakenFieldNotesMarker:Hide()
    end
end
FN.UpdatePlate = UpdatePlate

local function UpdateAllPlates()
    for unit in pairs(plateUnits) do UpdatePlate(unit) end
end

---------------------------------------------------------------- target frame
local targetBadge

local function TargetAnchor()
    local tf = _G.TargetFrame
    if not tf then return nil end
    local container = tf.TargetFrameContainer
    return (container and container.Portrait) or tf.portrait or tf
end

local function UpdateTarget()
    if not targetBadge then
        local tf = _G.TargetFrame
        if not tf then return end
        targetBadge = CreateFrame("Button", "KrakenFieldNotesTargetBadge", tf)
        MakeSymbols(targetBadge, 24)
        targetBadge:SetPoint("TOPRIGHT", TargetAnchor(), "TOPRIGHT", 4, 4)
        targetBadge:SetFrameLevel((tf:GetFrameLevel() or 0) + 30)
        targetBadge:SetScript("OnEnter", function(self)
            local rec = FN.ForUnit("target")
            local ignored = FN.UnitIgnored("target")
            if rec or ignored then
                Tooltip(self, rec, rec and "Click to edit." or "Click to write a note.", ignored, FN.UnitFullName("target"))
            end
        end)
        targetBadge:SetScript("OnLeave", function() GameTooltip:Hide() end)
        targetBadge:SetScript("OnClick", function() FN.EditUnit("target") end)
        targetBadge:Hide()
    end
    local on = Setting("target")
    local rec = on and FN.ForUnit("target") or nil
    local ignored = on and Setting("ignored") and FN.UnitIgnored("target") or false
    PaintSymbols(targetBadge, rec, ignored)
end
FN.UpdateTarget = UpdateTarget

---------------------------------------------------------------- inspect (paper doll)
local inspectPanel

local function UpdateInspect()
    local frame = _G.InspectFrame
    if not frame or not frame:IsShown() then return end
    if not inspectPanel then
        local p = CreateFrame("Button", "KrakenFieldNotesInspectPanel", frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
        p:SetSize(220, 70)
        p:SetPoint("TOPLEFT", frame, "TOPRIGHT", 2, -28)
        if p.SetBackdrop then
            p:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
            p:SetBackdropColor(0, 0, 0, 0.85)
        end
        p.icon = p:CreateTexture(nil, "OVERLAY")
        p.icon:SetSize(22, 22)
        p.icon:SetPoint("TOPLEFT", 8, -8)
        p.head = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        p.head:SetPoint("LEFT", p.icon, "RIGHT", 6, 0)
        p.text = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        p.text:SetPoint("TOPLEFT", p.icon, "BOTTOMLEFT", 0, -4)
        p.text:SetPoint("RIGHT", -8, 0)
        p.text:SetJustifyH("LEFT")
        p.text:SetMaxLines(3)
        p:SetScript("OnClick", function()
            local unit = _G.InspectFrame and _G.InspectFrame.unit
            if unit then FN.EditUnit(unit) end
        end)
        inspectPanel = p
    end
    local unit = frame.unit
    local rec = Setting("inspect") and unit and FN.ForUnit(unit)
    local ignored = Setting("ignored") and unit and FN.UnitIgnored(unit)
    local tag = ignored and ("  |T%s:14:14|t |cffff6666Ignored|r"):format(FN.IGNORED_ICON) or ""
    if rec then
        local r = FN.Rating(rec)
        inspectPanel.icon:SetTexture(r.icon)
        inspectPanel.head:SetText(("Field Note: |cff%s%s|r"):format(r.hex, r.label) .. tag)
        inspectPanel.text:SetText((rec.text and rec.text ~= "" and rec.text or "(no text)") .. "\n|cff999999Click to edit.|r")
        inspectPanel:Show()
    elseif unit and Setting("inspect") and FN.UnitIsOtherPlayer(unit) then
        inspectPanel.icon:SetTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Disabled")
        inspectPanel.head:SetText("Field Note" .. tag)
        inspectPanel.text:SetText("|cff999999No note yet. Click to write one.|r")
        inspectPanel:Show()
    else
        inspectPanel:Hide()
    end
end
FN.UpdateInspect = UpdateInspect

local function HookInspect()
    local frame = _G.InspectFrame
    if not frame or frame.KrakenFieldNotesHooked then return end
    frame.KrakenFieldNotesHooked = true
    frame:HookScript("OnShow", function() C_Timer.After(0, UpdateInspect) end)
end

---------------------------------------------------------------- tooltip
local function OnTooltipUnit(tooltip)
    if not Setting("tooltip") or tooltip ~= GameTooltip then return end
    local ok, _, unit = pcall(tooltip.GetUnit, tooltip)
    unit = ok and Plain(unit) or nil
    local rec = unit and FN.ForUnit(unit)
    local ignored = unit and Setting("ignored") and FN.UnitIgnored(unit)
    if ignored then tooltip:AddLine(("|T%s:14:14|t Ignored"):format(FN.IGNORED_ICON), 1, 0.4, 0.4) end
    if not rec then return end
    local r = FN.Rating(rec)
    tooltip:AddLine(FN.IconText(rec) .. " " .. r.label .. (rec.text and rec.text ~= "" and (": " .. rec.text) or ""), r.r, r.g, r.b, true)
end

---------------------------------------------------------------- chat
-- The rating symbol in front of a noted player's chat messages. A message filter
-- rather than a rewrite of the chat frame: it only adds to the text it's handed,
-- and skips anything the client keeps secret.
local CHAT_EVENTS = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE", "CHAT_MSG_WHISPER",
    "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_CHANNEL",
}

local function ChatFilter(_, _, msg, author, ...)
    if not Setting("chat") then return false end
    msg, author = Plain(msg), Plain(author)
    if type(msg) ~= "string" or type(author) ~= "string" then return false end
    local rec = FN.ForName(author)
    if not rec then return false end
    return false, FN.IconText(rec) .. " " .. msg, author, ...
end

---------------------------------------------------------------- right-click menu
local MENUS = { "PLAYER", "PARTY", "RAID_PLAYER", "TARGET", "FOCUS", "FRIEND", "FRIEND_OFFLINE", "ENEMY_PLAYER",
    "CHAT_ROSTER", "GUILD", "GUILD_OFFLINE", "COMMUNITIES_GUILD_MEMBER", "COMMUNITIES_WOW_MEMBER",
    "RECENT_ALLY", "RECENT_ALLY_OFFLINE", "PVP_SCOREBOARD", "RAID" }

local function MenuName(contextData)
    if type(contextData) ~= "table" then return nil end
    local unit = Plain(contextData.unit)
    if unit and FN.UnitIsOtherPlayer(unit) then return FN.UnitFullName(unit), Safe(UnitGUID, unit), unit end
    local name = Plain(contextData.name)
    if type(name) ~= "string" or name == "" then return nil end
    if name:find("[%s%-]") then return name end
    return FN.FullName(name, Plain(contextData.server))
end

local menusHooked = false
local function HookMenus()
    if menusHooked or not (Menu and Menu.ModifyMenu) then return end
    menusHooked = true
    for _, which in ipairs(MENUS) do
        pcall(Menu.ModifyMenu, "MENU_UNIT_" .. which, function(_, root, contextData)
            local name, guid, unit = MenuName(contextData)
            if not name or FN.Key(name) == FN.Key(FN.UnitFullName("player")) then return end
            local rec = unit and FN.ForUnit(unit) or FN.ForName(name)
            root:CreateDivider()
            root:CreateButton((rec and (FN.IconText(rec) .. " Edit Field Note...") or "Field Note..."), function()
                if unit then FN.EditUnit(unit) else FN.Edit(name, guid) end
            end)
        end)
    end
end

---------------------------------------------------------------- wiring
function FN.InitMarkers()
    FN.OnChange(function()
        UpdateAllPlates()
        UpdateTarget()
        UpdateInspect()
    end)

    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, OnTooltipUnit)
    end
    if ChatFrame_AddMessageEventFilter then
        for _, event in ipairs(CHAT_EVENTS) do ChatFrame_AddMessageEventFilter(event, ChatFilter) end
    end
    HookMenus()
    HookInspect()

    local events = CreateFrame("Frame")
    for _, e in ipairs({ "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_TARGET_CHANGED",
        "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD", "UNIT_NAME_UPDATE", "INSPECT_READY", "ADDON_LOADED" }) do
        events:RegisterEvent(e)
    end
    events:SetScript("OnEvent", function(_, event, arg1)
        if event == "NAME_PLATE_UNIT_ADDED" then
            arg1 = Plain(arg1)
            if arg1 then
                plateUnits[arg1] = true
                UpdatePlate(arg1)
                -- Again next frame, once Blizzard's own handler has fitted the plate's unit frame.
                C_Timer.After(0, function() if plateUnits[arg1] then UpdatePlate(arg1) end end)
            end
        elseif event == "NAME_PLATE_UNIT_REMOVED" then
            arg1 = Plain(arg1)
            if arg1 then
                plateUnits[arg1] = nil
                local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, arg1)
                if ok and plate and plate.KrakenFieldNotesMarker then plate.KrakenFieldNotesMarker:Hide() end
            end
        elseif event == "PLAYER_TARGET_CHANGED" then
            UpdateTarget()
        elseif event == "UNIT_NAME_UPDATE" then
            arg1 = Plain(arg1)
            if arg1 and plateUnits[arg1] then UpdatePlate(arg1) end
            if arg1 == "target" then UpdateTarget() end
        elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ENTERING_WORLD" then
            -- Names that were secret in the fight are readable again.
            UpdateAllPlates()
            UpdateTarget()
        elseif event == "INSPECT_READY" then
            HookInspect()
            C_Timer.After(0, UpdateInspect)
        elseif event == "ADDON_LOADED" then
            if arg1 == "Blizzard_InspectUI" then HookInspect() end
            if arg1 == "Blizzard_Menu" or arg1 == "Blizzard_UnitPopup" then HookMenus() end
        end
    end)
    UpdateTarget()
end
