"""Mock-client test for Kraken Field Notes (lupa). Usage: python -I tests/kfn_harness.py ."""
import sys, os
from lupa import LuaRuntime

ADDON = sys.argv[1]
FILES = ["Core.lua", "Editor.lua", "Markers.lua", "Ignore.lua"]

MOCK = r'''
NOW = 0
function GetTime() return NOW end
SECRET = setmetatable({}, {__name = "secret"})
function issecretvalue(v) return v == SECRET end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function strtrim(s) return (s or ""):match("^%s*(.-)%s*$") end
function time() return 1000 + NOW end
tinsert = table.insert
UISpecialFrames = {}
PRINTS = {}
function print(...) local p = {} for i = 1, select("#", ...) do p[#p+1] = tostring((select(i, ...))) end PRINTS[#PRINTS+1] = table.concat(p, " ") end
TIMERS = {}
C_Timer = { After = function(d, fn) TIMERS[#TIMERS+1] = {at = NOW + d, fn = fn} end }
function Advance(to)
  while true do
    table.sort(TIMERS, function(a, b) return a.at < b.at end)
    local n = TIMERS[1]; if not n or n.at > to then break end
    table.remove(TIMERS, 1); NOW = n.at; n.fn()
  end
  NOW = to
end
-- frames
FRAMES = {}
local function region()
  local r = { shown = true, points = {} }
  function r:SetText(t) self.text = t end
  function r:GetText() return self.text end
  function r:SetTexture(t) self.texture = t end
  function r:SetTextColor(...) self.color = {...} end
  function r:Show() self.shown = true end
  function r:Hide() self.shown = false end
  function r:IsShown() return self.shown end
  function r:SetPoint(p, rel, rp, x, y) self.points[#self.points+1] = {p, rel, rp, x, y} end
  function r:ClearAllPoints() self.points = {} end
  function r:GetFrameLevel() return rawget(self, "level") or 1 end
  function r:SetFrameLevel(l) self.level = l end
  setmetatable(r, {__index = function(_, k)
    if type(k) == "string" and (k:find("^Set") or k:find("^Enable") or k:find("^Register") or k:find("^Start")
        or k:find("^Stop") or k:find("^Unregister")) then return function() end end
  end})
  return r
end
function CreateFrame(kind, name, parent, template)
  local f = region()
  f.kind, f.parent, f.events, f.scripts, f.hooks = kind, parent, {}, {}, {}
  function f:RegisterEvent(e) self.events[e] = true end
  function f:UnregisterEvent(e) self.events[e] = nil end
  function f:SetScript(n, fn) self.scripts[n] = fn end
  function f:HookScript(n, fn) self.hooks[n] = fn end
  function f:CreateTexture() return region() end
  function f:CreateFontString() return region() end
  function f:GetText() return self.text end
  function f:SetText(t) self.text = t end
  function f:SetFocus() end
  function f:Show() self.shown = true; if self.hooks.OnShow then self.hooks.OnShow(self) end end
  FRAMES[#FRAMES+1] = f
  if name then _G[name] = f end
  return f
end
function Fire(e, ...) for _, f in ipairs(FRAMES) do if f.events[e] and f.scripts.OnEvent then f.scripts.OnEvent(f, e, ...) end end end
UIParent = region()
SlashCmdList = {}
-- the world: units by token
UNITS = {}
function RegionalUniqueNamesEnabled() return UNIQUE end
UNIQUE = true
function GetNormalizedRealmName() return "CAMWOW" end
function GetRealmName() return "CAMWOW" end
function UnitExists(u) return UNITS[u] ~= nil or u == "player" end
function UnitIsPlayer(u) return u == "player" or (UNITS[u] ~= nil and UNITS[u].player ~= false) end
function UnitName(u) if u == "player" then return "Selene", "Evernight" end local x = UNITS[u]; if x then return x.secret and SECRET or x.name, x.secret and SECRET or x.second end end
function UnitGUID(u) if u == "player" then return "Player-1-SELF" end local x = UNITS[u]; return x and x.guid end
-- nameplates: plate bases and a pool of unit frames, as Blizzard's driver does
PLATES, FORBIDDEN = {}, {}
local pool = {}
local function UnitFrameFromPool()
  local uf = table.remove(pool) or CreateFrame("Button")
  uf.name = uf.name or region(); uf.HealthBarsContainer = uf.HealthBarsContainer or region()
  return uf
end
function ShowPlate(token, plateId)
  local base = PLATES[plateId] or CreateFrame("Frame"); PLATES[plateId] = base
  if base.UnitFrame then pool[#pool+1] = base.UnitFrame end
  base.UnitFrame = UnitFrameFromPool(); base.token = token
  Fire("NAME_PLATE_UNIT_ADDED", token)
  return base
end
-- The same plate base, handed a brand-new unit frame (as when the pool gives it another one).
function ShowPlateNewFrame(token, plateId)
  local base = PLATES[plateId] or CreateFrame("Frame"); PLATES[plateId] = base
  local uf = CreateFrame("Button"); uf.name = region(); uf.HealthBarsContainer = region()
  base.UnitFrame = uf; base.token = token
  Fire("NAME_PLATE_UNIT_ADDED", token)
  return base
end
function HidePlate(token) Fire("NAME_PLATE_UNIT_REMOVED", token) end
C_NamePlate = { GetNamePlateForUnit = function(token)
  if FORBIDDEN[token] then return nil end
  for _, base in pairs(PLATES) do if base.token == token then return base end end
end }
-- target frame and inspect
TargetFrame = CreateFrame("Frame", "TargetFrame")
TargetFrame.TargetFrameContainer = { Portrait = region() }
-- tooltip and chat
TOOLTIP_CALLS = {}
GameTooltip = region()
function GameTooltip:AddLine(t) self.lines = self.lines or {}; self.lines[#self.lines+1] = t end
function GameTooltip:GetUnit() return "Prime Arnold", self.unit end
Enum = { TooltipDataType = { Unit = 2 } }
TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn) TOOLTIP_CALLS[kind] = fn end }
CHAT_FILTERS = {}
function ChatFrame_AddMessageEventFilter(event, fn) CHAT_FILTERS[event] = fn end
-- menus
MENUS = {}
Menu = { ModifyMenu = function(tag, fn) MENUS[tag] = fn end }
function NewMenu()
  local root = { buttons = {} }
  function root:CreateDivider() end
  function root:CreateButton(text, fn) self.buttons[#self.buttons+1] = { text = text, fn = fn } end
  return root
end
BackdropTemplateMixin = {}
function Press(text)
  for _, f in ipairs(FRAMES) do
    local label = rawget(f, "label")
    local t = rawget(f, "text") or (label and rawget(label, "text"))
    local click = rawget(f, "scripts") and f.scripts.OnClick
    if t == text and click then click(f); return true end
  end
  return false
end
function Raw(t, k) return rawget(t, k) end
-- the ignore list
IGNORES = {}   -- array of names, as the server keeps it
GUID_OF = { ["Player-1-PRIME"] = "Prime Arnold", ["Player-1-TESS"] = "Tess Brightwater", ["Player-1-SYL"] = "Sylvara Windroot", ["Player-1-GRIM"] = "Grim Ashveil" }
local function ignoredName(n) for _, x in ipairs(IGNORES) do if x:lower() == n:lower() then return true end end return false end
C_FriendList = {
  GetNumIgnores = function() return #IGNORES end,
  GetIgnoreName = function(i) return IGNORES[i] end,
  IsIgnored = function(token)
    local u = UNITS[token]
    if u then return u.name ~= nil and not u.secret and ignoredName(u.name .. " " .. (u.second or "")) end
    return ignoredName(token)
  end,
  IsIgnoredByGuid = function(g) local n = GUID_OF[g]; return n ~= nil and ignoredName(n) end,
}
function Ignore(name) IGNORES[#IGNORES+1] = name; Fire("IGNORELIST_UPDATE") end
function Unignore(name) for i, x in ipairs(IGNORES) do if x == name then table.remove(IGNORES, i) end end Fire("IGNORELIST_UPDATE") end
function GetRealZoneText() return "Elwynn Forest" end
function GetServerTime() return 5000 + NOW end
function date() return "2026-11-07 14:32" end
'''

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(MOCK)
ns = lua.eval("{}")
for f in FILES:
    lua.eval("function(s, n) return assert(load(s, '@' .. n)) end")(open(os.path.join(ADDON, f), encoding="utf-8").read(), f)("KrakenFieldNotes", ns)
lua.execute('Fire("ADDON_LOADED", "KrakenFieldNotes"); Fire("PLAYER_LOGIN"); Fire("PLAYER_ENTERING_WORLD")')

results = []
def check(name, cond):
    results.append(bool(cond)); print(("PASS " if cond else "FAIL ") + name)
run = lua.execute
ev = lua.eval
said = lambda text: any(text in p for p in ev("PRINTS").values())
BAD, GOOD, NEUTRAL = "ReadyCheck-NotReady", "ReadyCheck-Ready", "PublicNote-Up"

# 1. Target Prime Arnold, /fn, rate Bad, write a note, save
run('UNITS.target = { name = "Prime", second = "Arnold", guid = "Player-1-PRIME" }; Fire("PLAYER_TARGET_CHANGED")')
check("1 Target badge hidden before any note", ev("KrakenFieldNotesTargetBadge.shown") is False)
run('SlashCmdList.KRAKENFIELDNOTES("")')
check("1 /fn opens the editor for 'Prime Arnold'", ev("KrakenFieldNotesEditor.shown") is True)
run('KrakenFieldNotesEditorBox:SetText("Ninja-looted the chest in Deadmines.")')
# press Bad, then Save (buttons are the frames created after the editor)
run('Press("Bad"); Press("Save")')
rec = ev('KrakenFieldNotesDB.notes["prime arnold"]')
check("1 Saved under 'prime arnold' with name, rating and text", rec is not None and rec.name == "Prime Arnold" and rec.rating == "bad" and "Deadmines" in rec.text)
check("1 Remembers their GUID", ev('KrakenFieldNotesDB.notes["prime arnold"].guids["Player-1-PRIME"]') is True)
check("1 Target badge now shows the Bad symbol", ev("KrakenFieldNotesTargetBadge.shown") is True and BAD in ev("KrakenFieldNotesTargetBadge.icon.texture"))

# 2. Their nameplate shows the symbol, over the name
run('UNITS.nameplate1 = { name = "Prime", second = "Arnold", guid = "Player-1-PRIME" }; P1 = ShowPlate("nameplate1", 1)')
m = ev("P1.KrakenFieldNotesMarker")
check("2 Nameplate gets a Bad symbol", m is not None and m.shown and BAD in m.icon.texture)
check("2 Anchored over the plate's name", ev("P1.KrakenFieldNotesMarker.points[1][2] == P1.UnitFrame.name"))

# 3. The plate is recycled for somebody without a note: symbol hidden
run('HidePlate("nameplate1"); UNITS.nameplate1 = { name = "Tess", second = "Brightwater", guid = "Player-1-TESS" }; ShowPlate("nameplate1", 1); Advance(1)')
check("3 Recycled plate for an un-noted player hides the symbol", ev("P1.KrakenFieldNotesMarker.shown") is False)
# a different plate base gets Prime, with a unit frame from the pool
run('UNITS.nameplate2 = { name = "Prime", second = "Arnold", guid = "Player-1-PRIME" }; P2 = ShowPlate("nameplate2", 2); Advance(2)')
check("3 Symbol follows Prime to the new plate, anchored to its current unit frame",
      ev("P2.KrakenFieldNotesMarker.shown") is True and ev("P2.KrakenFieldNotesMarker.points[1][2] == P2.UnitFrame.name"))

# the same plate shows Prime again with a different unit frame: the symbol must move with it
run('HidePlate("nameplate2"); ShowPlateNewFrame("nameplate2", 2); Advance(2.5)')
check("3 Same plate, new unit frame: the symbol is re-anchored to it",
      ev("P2.KrakenFieldNotesMarker.shown") is True and ev("P2.KrakenFieldNotesMarker.points[1][2] == P2.UnitFrame.name"))

# 4. A forbidden plate (friendly plate in an instance): nothing, no error
run('FORBIDDEN.nameplate3 = true; UNITS.nameplate3 = { name = "Prime", second = "Arnold", guid = "Player-1-PRIME" }; ShowPlate("nameplate3", 3); Advance(3)')
check("4 Forbidden plates are left alone", ev("Raw(PLATES[3], 'KrakenFieldNotesMarker')") is None)

# 5. Secret names in combat: found by GUID; unknown GUID waits for the fight to end
run('UNITS.nameplate4 = { secret = true, guid = "Player-1-PRIME" }; ShowPlate("nameplate4", 4); Advance(4)')
check("5 Secret name, known GUID: still marked", ev("PLATES[4].KrakenFieldNotesMarker.shown") is True)
run('KrakenFieldNotesDB.notes["sylvara windroot"] = { name = "Sylvara Windroot", rating = "good", text = "Buffed me twice." }')
run('UNITS.nameplate5 = { secret = true, guid = "Player-1-SYL" }; ShowPlate("nameplate5", 5); Advance(5)')
check("5 Secret name, unknown GUID: no symbol yet, no error", ev("Raw(PLATES[5], 'KrakenFieldNotesMarker')") is None)
run('UNITS.nameplate5 = { name = "Sylvara", second = "Windroot", guid = "Player-1-SYL" }; Fire("PLAYER_REGEN_ENABLED")')
check("5 After the fight it is marked Good", ev("PLATES[5].KrakenFieldNotesMarker.shown") is True and GOOD in ev("PLATES[5].KrakenFieldNotesMarker.icon.texture"))

# 6. Inspect (paper doll)
run('InspectFrame = CreateFrame("Frame", "InspectFrame"); InspectFrame.shown = false; Fire("ADDON_LOADED", "Blizzard_InspectUI")')
run('InspectFrame.unit = "target"; InspectFrame:Show(); Advance(6)')
p = ev("KrakenFieldNotesInspectPanel")
check("6 Inspecting a noted player shows the note beside the paper doll", p is not None and p.shown and "Bad" in p.head.text and "Deadmines" in p.text.text)
run('UNITS.target = { name = "Tess", second = "Brightwater", guid = "Player-1-TESS" }; InspectFrame:Show(); Advance(7)')
check("6 An un-noted player offers to write one", "No note yet" in ev("KrakenFieldNotesInspectPanel.text.text"))
run('UNITS.target = { name = "Prime", second = "Arnold", guid = "Player-1-PRIME" }')

# 7. Tooltip
run('GameTooltip.unit = "nameplate1"; GameTooltip.lines = {}; UNITS.nameplate1 = { name = "Prime", second = "Arnold", guid = "Player-1-PRIME" }; TOOLTIP_CALLS[2](GameTooltip)')
lines = list(ev("GameTooltip.lines").values())
check("7 Tooltip shows the rating and the note", len(lines) == 1 and "Bad: Ninja-looted" in lines[0])

# 8. Chat: symbol before their messages, in either spelling; secrets untouched
f = ev('CHAT_FILTERS.CHAT_MSG_SAY')
r1 = f(None, "CHAT_MSG_SAY", "anyone selling linen?", "Prime-Arnold")
r2 = f(None, "CHAT_MSG_SAY", "hello", "Prime Arnold")
r3 = f(None, "CHAT_MSG_SAY", "hi", "Tess-Brightwater")
r4 = f(None, "CHAT_MSG_SAY", ev("SECRET"), "Prime-Arnold")
check("8 Their chat gets the Bad symbol", r1[0] is False and BAD in r1[1] and r1[1].endswith("anyone selling linen?"))
check("8 'Prime Arnold' and 'Prime-Arnold' are the same person", BAD in r2[1])
check("8 Others' chat is untouched", r3 is False or (isinstance(r3, tuple) and len(r3) == 1))
check("8 A secret message is left alone", r4 is False or (isinstance(r4, tuple) and len(r4) == 1))

# 9. Right-click menu, from a chat name (no unit): name + surname
root = ev("NewMenu()")
ev('MENUS.MENU_UNIT_FRIEND')(None, root, lua.eval('{ name = "Sylvara", server = "Windroot" }'))
btns = list(root.buttons.values())
check("9 Menu offers 'Edit Field Note...' for a noted player", len(btns) == 1 and "Edit Field Note" in btns[0].text)
btns[0].fn()
check("9 It opens the editor on 'Sylvara Windroot'", ev("KrakenFieldNotesEditor.shown") is True and "Buffed me twice." == ev("KrakenFieldNotesEditorBox.text"))
root2 = ev("NewMenu()")
ev('MENUS.MENU_UNIT_SELF') and ev('MENUS.MENU_UNIT_SELF')(None, root2, lua.eval('{ unit = "player" }'))
ev('MENUS.MENU_UNIT_PLAYER')(None, root2, lua.eval('{ name = "Selene", server = "Evernight" }'))
check("9 No Field Note entry on yourself", len(list(root2.buttons.values())) == 0)

# 10. /fn good, /fn list, /fn show nameplates, erase
run('SlashCmdList.KRAKENFIELDNOTES("good")')
check("10 /fn good re-rates the target and keeps the text", ev('KrakenFieldNotesDB.notes["prime arnold"].rating') == "good" and "Deadmines" in ev('KrakenFieldNotesDB.notes["prime arnold"].text'))
check("10 Nameplate symbol switches to Good at once", GOOD in ev("P2.KrakenFieldNotesMarker.icon.texture"))
run('SlashCmdList.KRAKENFIELDNOTES("list")')
check("10 /fn list shows both players", said("2 noted players") and said("Prime Arnold") and said("Sylvara Windroot"))
run('SlashCmdList.KRAKENFIELDNOTES("show nameplates")')
check("10 /fn show nameplates turns nameplate symbols off", ev("P2.KrakenFieldNotesMarker.shown") is False)
run('SlashCmdList.KRAKENFIELDNOTES("show nameplates")')
run('SlashCmdList.KRAKENFIELDNOTES("Prime Arnold")')
run('Press("Erase")')
check("10 Erase removes the note and every symbol", ev('KrakenFieldNotesDB.notes["prime arnold"]') is None
      and ev("P2.KrakenFieldNotesMarker.shown") is False and ev("KrakenFieldNotesTargetBadge.shown") is False)

# 11. A realm-based client: Name-Realm for other realms, plain name for ours
run('UNIQUE = false')
check("11 Other realm keeps its realm", ev('KrakenFieldNotes.FullName("Bob", "Stormrage")') == "Bob-Stormrage")
check("11 Own realm is dropped", ev('KrakenFieldNotes.FullName("Bob", "CAMWOW")') == "Bob" and ev('KrakenFieldNotes.Key("Bob-CAMWOW")') == "bob")


# 12. Ignored players: the silence symbol, alone or beside the rating
run('Advance(30)')   # past the login settling time
run('UNITS.nameplate6 = { name = "Grim", second = "Ashveil", guid = "Player-1-GRIM" }; P6 = ShowPlate("nameplate6", 6); Advance(31)')
check("12 Un-noted, not ignored: no symbol", ev("Raw(P6, 'KrakenFieldNotesMarker')") is None)
run('Fire("CHAT_MSG_SAY", "lol noobs, go back to retail", "Grim Ashveil"); Fire("CHAT_MSG_CHANNEL", "WTS gold cheap www", "Grim-Ashveil", "", "2. Trade - City", "", "", 2, 2, "Trade - City")')
run('Fire("CHAT_MSG_SAY", SECRET, "Grim Ashveil")')
run('Ignore("Grim Ashveil"); Advance(32)')
rec = ev('KrakenFieldNotesDB.notes["grim ashveil"]')
check("12 Ignoring someone writes a note, rated Bad", rec is not None and rec.rating == "bad")
check("12 The note says when and where", rec is not None and "Ignored 2026-11-07 14:32 in Elwynn Forest." in rec.text)
check("12 ...and what they'd said, channel by channel", rec is not None and '(say) "lol noobs, go back to retail"' in rec.text and '(Trade - City) "WTS gold cheap www"' in rec.text)
check("12 A secret chat line isn't recorded", rec is not None and rec.text.count('"') == 4)
check("12 Chat says the note was made", said("Noted why you ignored Grim Ashveil"))
check("12 Their nameplate shows Bad and Ignored side by side",
      ev("P6.KrakenFieldNotesMarker.icon.shown") is True and ev("P6.KrakenFieldNotesMarker.ignore.shown") is True)
print("  note:", rec.text if rec else None)
run('KrakenFieldNotesDB.notes["grim ashveil"] = nil; KrakenFieldNotes.Changed()')
check("12 Ignored with no note: the ignored symbol alone", ev("P6.KrakenFieldNotesMarker.shown") is True
      and ev("P6.KrakenFieldNotesMarker.icon.shown") is False and ev("P6.KrakenFieldNotesMarker.ignore.shown") is True)
run('GameTooltip.unit = "nameplate6"; GameTooltip.lines = {}; TOOLTIP_CALLS[2](GameTooltip)')
check("12 Tooltip says Ignored", any("Ignored" in l for l in ev("GameTooltip.lines").values()))
run('UNITS.target = { name = "Grim", second = "Ashveil", guid = "Player-1-GRIM" }; Fire("PLAYER_TARGET_CHANGED")')
check("12 Target frame shows the ignored symbol", ev("KrakenFieldNotesTargetBadge.shown") is True and ev("KrakenFieldNotesTargetBadge.ignore.shown") is True)
run('Unignore("Grim Ashveil")')
check("12 Unignored: the symbol goes away", ev("P6.KrakenFieldNotesMarker.shown") is False and ev("KrakenFieldNotesTargetBadge.shown") is False)

# 13. A good note stays Good when you later ignore them; the reason is added below
run('KrakenFieldNotesDB.notes["tess brightwater"] = { name = "Tess Brightwater", rating = "good", text = "Healed me through Hogger." }')
run('Fire("CHAT_MSG_WHISPER", "give me 50g or else", "Tess Brightwater"); Ignore("Tess Brightwater"); Advance(33)')
rec = ev('KrakenFieldNotesDB.notes["tess brightwater"]')
check("13 Existing rating kept, old text kept, reason appended", rec.rating == "good" and rec.text.startswith("Healed me through Hogger.\n")
      and '(whisper) "give me 50g or else"' in rec.text)

# 14. Ignored on another character (Kraken Ignore Sync's shared list)
run('KrakenIgnoreSync_DB = { entries = { ["sylvara-windroot"] = { name = "Sylvara Windroot", added = 100, addedBy = "Alt-CAMWOW" } } }; KrakenFieldNotes.Changed()')
check("14 Ignored on another character shows as ignored here", ev("PLATES[5].KrakenFieldNotesMarker.ignore.shown") is True)
run('Ignore("Sylvara Windroot"); Advance(34)')
check("14 Ignore Sync copying it over writes no duplicate note", ev('KrakenFieldNotesDB.notes["sylvara windroot"].text') == "Buffed me twice.")
run('KrakenIgnoreSync_DB.entries["sylvara-windroot"].removed = 200; Unignore("Sylvara Windroot")')
check("14 Unignored everywhere: no ignored symbol", ev("PLATES[5].KrakenFieldNotesMarker.ignore.shown") is False)

# 15. The ignore list arriving at login isn't you ignoring people; autonote can be turned off
l2 = LuaRuntime(unpack_returned_tuples=True); l2.execute(MOCK)
ns2 = l2.eval("{}")
for f in FILES:
    l2.eval("function(s, n) return assert(load(s, '@' .. n)) end")(open(os.path.join(ADDON, f), encoding="utf-8").read(), f)("KrakenFieldNotes", ns2)
l2.execute('Fire("ADDON_LOADED", "KrakenFieldNotes"); Fire("PLAYER_LOGIN"); Advance(2); IGNORES = {"Old Grudge", "Another One"}; Fire("IGNORELIST_UPDATE"); Advance(4); Ignore("Late Arrival"); Advance(25)')
check("15 Ignores loaded at login (even in pieces) get no notes", l2.eval("next(KrakenFieldNotesDB.notes)") is None)
l2.execute('SlashCmdList.KRAKENFIELDNOTES("show autonote"); Ignore("New Pest"); Advance(26)')
check("15 With autonote off, ignoring writes nothing", l2.eval("next(KrakenFieldNotesDB.notes)") is None)
l2.execute('SlashCmdList.KRAKENFIELDNOTES("show autonote"); Ignore("Third Pest"); Advance(27)')
check("15 Back on, it does", l2.eval('KrakenFieldNotesDB.notes["third pest"] ~= nil'))

print(f"\n{sum(results)}/{len(results)} passed")
sys.exit(0 if all(results) else 1)
