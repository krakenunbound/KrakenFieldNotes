-- Kraken Field Notes: the note editor and /fn.

local ADDON, FN = ...

local editor, box, title, current, ratingButtons, chosen

local function PaintRatings()
    for key, btn in pairs(ratingButtons) do
        local r = FN.RATINGS[key]
        if key == chosen then
            btn.label:SetTextColor(r.r, r.g, r.b)
            btn.glow:Show()
        else
            btn.label:SetTextColor(0.6, 0.6, 0.6)
            btn.glow:Hide()
        end
    end
end

local function Build()
    if editor then return end
    local f = CreateFrame("Frame", "KrakenFieldNotesEditor", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    f:SetSize(400, 280)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 8, right = 8, top = 8, bottom = 8 },
        })
    end
    f:Hide()
    tinsert(UISpecialFrames, "KrakenFieldNotesEditor")

    title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, -16)

    -- How you feel about them: three toggles.
    ratingButtons = {}
    local prev
    for i, key in ipairs(FN.RATING_ORDER) do
        local r = FN.RATINGS[key]
        local b = CreateFrame("Button", nil, f)
        b:SetSize(110, 24)
        if prev then b:SetPoint("LEFT", prev, "RIGHT", 8, 0) else b:SetPoint("TOPLEFT", 24, -40) end
        b.glow = b:CreateTexture(nil, "BACKGROUND")
        b.glow:SetAllPoints()
        b.glow:SetColorTexture(r.r, r.g, r.b, 0.2)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(18, 18)
        b.icon:SetPoint("LEFT", 4, 0)
        b.icon:SetTexture(r.icon)
        b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        b.label:SetPoint("LEFT", b.icon, "RIGHT", 4, 0)
        b.label:SetText(r.label)
        b:SetScript("OnClick", function() chosen = key; PaintRatings() end)
        ratingButtons[key] = b
        prev = b
    end

    local scroll = CreateFrame("ScrollFrame", "KrakenFieldNotesEditorScroll", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 22, -74)
    scroll:SetPoint("BOTTOMRIGHT", -40, 48)
    box = CreateFrame("EditBox", "KrakenFieldNotesEditorBox", scroll)
    box:SetMultiLine(true)
    box:SetAutoFocus(true)
    box:SetMaxLetters(1000)
    box:SetFontObject(GameFontHighlight)
    box:SetWidth(330)
    box:SetTextInsets(4, 4, 4, 4)
    box:SetScript("OnEscapePressed", function() f:Hide() end)
    scroll:SetScrollChild(box)

    local function Button(text, point, x, onClick)
        local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        b:SetSize(84, 22)
        b:SetPoint(point, x, 16)
        b:SetText(text)
        b:SetScript("OnClick", onClick)
        return b
    end
    Button("Save", "BOTTOMLEFT", 20, function()
        FN.Set(current.name, box:GetText(), chosen, current.guid)
        f:Hide()
    end)
    Button("Erase", "BOTTOMLEFT", 110, function()
        FN.Set(current.name, "", nil)
        f:Hide()
    end)
    Button("Close", "BOTTOMRIGHT", -20, function() f:Hide() end)
    editor = f
end

-- Opens the editor for a player by full name (and GUID when known).
function FN.Edit(name, guid)
    name = FN.Plain(name)
    if type(name) ~= "string" or name == "" then
        FN.Say("Target a player first, or use /fn First Surname.")
        return
    end
    Build()
    current = { name = name, guid = FN.Plain(guid) }
    local rec = FN.ForName(name)
    chosen = rec and rec.rating or "neutral"
    title:SetText("Field Note: " .. (rec and rec.name or name))
    box:SetText(rec and rec.text or "")
    PaintRatings()
    editor:Show()
    box:SetFocus()
end

function FN.EditUnit(unit)
    unit = unit or "target"
    if not FN.UnitIsOtherPlayer(unit) then
        FN.Say("Target a player first, or use /fn First Surname.")
        return
    end
    local _, key = FN.ForUnit(unit)
    local rec = key and FN.Get(key)
    FN.Edit(rec and rec.name or FN.UnitFullName(unit), FN.Safe(UnitGUID, unit))
end

function FN.InitEditor() end

---------------------------------------------------------------- /fn
local HELP = {
    "/fn - write a note about your target (or right-click a player > Field Note...)",
    "/fn First Surname - write a note about someone by name",
    "/fn good | neutral | bad - rate your target without opening the editor",
    "/fn list - everyone you've noted",
    "/fn show nameplates|target|inspect|tooltip|chat - toggle where markers appear",
    "/fn show ignored - toggle the 'ignored' symbol",
    "/fn show autonote - toggle writing a note when you ignore someone",
}

function FN.InitCommands()
    SLASH_KRAKENFIELDNOTES1 = "/fn"
    SLASH_KRAKENFIELDNOTES2 = "/fieldnotes"
    SlashCmdList.KRAKENFIELDNOTES = function(msg)
        msg = strtrim(msg or "")
        local cmd, rest = msg:match("^(%S*)%s*(.-)$")
        local lower = cmd:lower()
        if msg == "" then
            FN.EditUnit("target")
        elseif lower == "help" then
            for _, line in ipairs(HELP) do FN.Say(line) end
        elseif FN.RATINGS[lower] and rest == "" then
            if not FN.UnitIsOtherPlayer("target") then FN.Say("Target a player first."); return end
            local rec = FN.ForUnit("target")
            local name = rec and rec.name or FN.UnitFullName("target")
            FN.Set(name, rec and rec.text or "", lower, FN.Safe(UnitGUID, "target"))
            FN.Say(("%s rated %s %s."):format(name, FN.IconText({ rating = lower }), FN.RATINGS[lower].label))
        elseif lower == "list" then
            local rows = {}
            for _, rec in pairs(FN.db.notes) do rows[#rows + 1] = rec end
            table.sort(rows, function(a, b) return (a.name or "") < (b.name or "") end)
            FN.Say(#rows .. " noted player" .. (#rows == 1 and "" or "s") .. (#rows > 0 and ":" or "."))
            for _, rec in ipairs(rows) do
                local text = rec.text or ""
                if #text > 60 then text = text:sub(1, 57) .. "..." end
                print(("  %s |cff%s%s|r %s"):format(FN.IconText(rec), FN.Rating(rec).hex, rec.name or "?", text))
            end
        elseif lower == "show" and FN.db.settings[rest:lower()] ~= nil then
            local key = rest:lower()
            FN.db.settings[key] = not FN.db.settings[key]
            FN.Say(("%s: %s."):format(key, FN.db.settings[key] and "on" or "off"))
            FN.Changed()
        else
            FN.Edit(msg)
        end
    end
end
