local addonName, ns = ...
local L = ns.L

-- Trade Crier (2026-11-26, the user's request): your own messages with your profession links in Trade chat, each
-- again after its own time (in seconds, the user's wish 2026-11-26) while you are in a city. This file is shared byte
-- for byte by the standalone addon (TradeCrier/Crier.lua) and Codex (Modules/Crier/Crier.lua); change both together.
--
-- The host fills ns.crier (C) before this file loads:
--   C.DB()          account settings (filled with C.DEFAULTS here)
--   C.CharDB()      this character's (C.CHAR_DEFAULTS: the messages, paused, the last post)
--   C.Say(text)     a chat line with the host's prefix
--   C.BUTTON_NAME   the first message's button (then ..2, ..3; the bar ..Bar, the key's button ..Key)
--   C.Look(button)  the button's frame in the host's style; C.Accent() = { r, g, b } for its glow
--   C.OpenOptions() the options page
--
-- Posting: the game sends an addon's message to a channel only inside a click or key press (Forever's API marks
-- SendChatMessage HasRestrictions; the rule since patch 8.2.5). Nothing here ever posts from a timer: the button
-- of a message lights when its post is due, and the player's click on it, the key or "/crier post" sends it.
-- Channels: zoneChannelID 2 = "Trade - %s", 42 = "Trade (Services) - %s" (Forever's ChatChannels table on
-- wago.tools), found among the joined channels (GetChannelList) with C_ChatInfo.GetChannelInfoFromIdentifier.
-- Profession links: C_SpellBook.GetSpellBookItemTradeSkillLink on the profession's spellbook slot (spellOffset +
-- button ID, as Blizzard_ProfessionsBook does), so the profession window needn't be open.

local C = ns.crier

C.DEFAULTS = {
  every = 600, -- seconds a new message waits between its posts
  channel = "trade", -- C.CHANNELS key
  sound = false, -- a sound when a post is due
  remind = false, -- a chat line when a post is due
  onlyCities = true, -- the button only where the channel is
  locked = false, -- the buttons can't be dragged
  column = false, -- the buttons above each other (else side by side)
  scale = 1,
  -- key = "F9", pos = { point, x, y }
}
C.CHAR_DEFAULTS = {
  paused = false,
  -- messages = { { text, every = seconds, off = true or nil, icon = path or nil (automatic), last = time(),
  --   city = area ID or zone name or nil (any city), channel = C.CHANNELS key or nil (the one picked for all),
  --   hours = { from, to } or nil (any time) }, ... }
  -- lastPost = time() (any message)
}
C.CHANNELS = {
  { key = "trade", zone = 2, name = "Trade" },
  { key = "services", zone = 42, name = "Trade (Services)" },
}
C.MAX_LENGTH = 255 -- the game's limit for one chat message
C.MIN_EVERY = 30 -- the shortest time a message waits between its posts, in seconds
C.MAX_EVERY = 86400
C.MAX_MESSAGES = 8
C.SIZE = 40
C.ICON = "Interface\\Icons\\INV_Misc_Note_01"
C.ANY_CITY_ICON = "Interface\\Icons\\INV_Misc_Map_01"
C.OTHER_CITY_ICON = "Interface\\Icons\\Ability_TownWatch"

-- The capitals with Trade chat (Forever's AreaTable: the six areas flagged as capitals), by area ID, with the icon of
-- the mage's teleport there (SpellMisc of Teleport: Stormwind ...; the files are in Forever's file list). A message
-- can be for one city only (2026-11-27, TradeCrier issue #1: not everyone travels between the cities). Names come
-- from the game in its own language (C_Map.GetAreaInfo); the English ones only when it answers nothing.
C.CITIES = {
  { area = 1519, name = "Stormwind City", icon = "Interface\\Icons\\Spell_Arcane_TeleportStormWind" },
  { area = 1537, name = "Ironforge", icon = "Interface\\Icons\\Spell_Arcane_TeleportIronForge" },
  { area = 1657, name = "Darnassus", icon = "Interface\\Icons\\Spell_Arcane_TeleportDarnassus" },
  { area = 1637, name = "Orgrimmar", icon = "Interface\\Icons\\Spell_Arcane_TeleportOrgrimmar" },
  { area = 1638, name = "Thunder Bluff", icon = "Interface\\Icons\\Spell_Arcane_TeleportThunderBluff" },
  { area = 1497, name = "Undercity", icon = "Interface\\Icons\\Spell_Arcane_TeleportUnderCity" },
}

local function Fill(target, defaults)
  for key, value in pairs(defaults) do
    if target[key] == nil then
      target[key] = value
    end
  end
  return target
end

function C.Settings()
  return Fill(C.DB(), C.DEFAULTS)
end

function C.Char()
  return Fill(C.CharDB(), C.CHAR_DEFAULTS)
end

-- A time between posts as a message keeps it: whole seconds from C.MIN_EVERY to C.MAX_EVERY.
function C.ClampEvery(seconds)
  seconds = math.floor((tonumber(seconds) or tonumber(C.Settings().every) or 600) + 0.5)
  return math.max(C.MIN_EVERY, math.min(C.MAX_EVERY, seconds))
end

-- This character's messages, never empty (an empty first one to write in). 1.0.x kept one message
-- (char.message) and one account-wide time in minutes (settings.interval): they become the first message.
function C.Messages()
  local char, settings = C.Char(), C.Settings()
  if type(char.messages) ~= "table" then
    char.messages = {}
    if type(char.message) == "string" and char.message ~= "" then
      char.messages[1] = { text = char.message, every = C.ClampEvery((tonumber(settings.interval) or 10) * 60),
        last = char.lastPost }
    end
  end
  char.message = nil
  local list = char.messages
  for index = #list, 1, -1 do
    if type(list[index]) ~= "table" then
      table.remove(list, index)
    end
  end
  if #list == 0 then
    list[1] = { text = "", every = C.ClampEvery(settings.every) }
  end
  for _, message in ipairs(list) do
    message.text = type(message.text) == "string" and message.text or ""
    message.every = C.ClampEvery(message.every)
  end
  return list
end

-- A new empty message at the end; returns its index, or nil at C.MAX_MESSAGES.
function C.AddMessage()
  local list = C.Messages()
  if #list >= C.MAX_MESSAGES then
    return nil
  end
  list[#list + 1] = { text = "", every = C.ClampEvery(C.Settings().every) }
  C.Refresh()
  return #list
end

-- Removes a message (the last one left is only emptied).
function C.RemoveMessage(index)
  local list = C.Messages()
  if not list[index] then
    return
  end
  if #list == 1 then
    list[1].text = ""
    list[1].last = nil
  else
    table.remove(list, index)
  end
  C.Refresh()
end

local function Now()
  return time()
end

local function Ask(fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  local ok, a, b, c, d, e, f, g = pcall(fn, ...)
  if ok then
    return a, b, c, d, e, f, g
  end
end

-- A string we may read and compare (not a secret value), or nil.
local function PlainText(value)
  if type(value) == "string" and (not canaccessvalue or canaccessvalue(value)) and value ~= "" then
    return value
  end
end

-- Cities -------------------------------------------------------------------------------------------------

local function CityDef(city)
  for _, def in ipairs(C.CITIES) do
    if def.area == city then
      return def
    end
  end
end

-- A message's city as the game names it: message.city is an area ID from C.CITIES, or a zone name (a city with
-- Trade chat that isn't in the list, picked while there). Nil = any city.
function C.CityName(city)
  if type(city) == "number" then
    local name = C_Map and PlainText(Ask(C_Map.GetAreaInfo, city))
    local def = CityDef(city)
    return name or (def and def.name)
  end
  return PlainText(city)
end

-- The icon of a message's city: its teleport's, a map for any city, a town for another one.
function C.CityIcon(city)
  local def = type(city) == "number" and CityDef(city)
  if def then
    return def.icon
  end
  return C.CityName(city) and C.OTHER_CITY_ICON or C.ANY_CITY_ICON
end

-- The zone you are in (GetRealZoneText: the city, not the street), or nil.
function C.Here()
  return PlainText(Ask(GetRealZoneText))
end

-- Whether a message may go where you are: it is for any city, or you are in its city.
function C.InItsCity(message)
  local name = message and C.CityName(message.city)
  if not name then
    return true
  end
  return C.Here() == name
end

-- The cities to pick from for a message: any (false), the capitals, then the city you are in and the one picked when
-- they aren't in the list. { { city = value or false, name = text, icon = path }, ... }
function C.CityChoices(message)
  local out = { { city = false, name = L["Any city"], icon = C.ANY_CITY_ICON } }
  local names = {}
  for _, def in ipairs(C.CITIES) do
    local name = C.CityName(def.area)
    names[name] = true
    out[#out + 1] = { city = def.area, name = name, icon = def.icon }
  end
  local extra = {}
  if message and type(message.city) == "string" and C.CityName(message.city) then
    extra[#extra + 1] = message.city
  end
  local here = C.Here()
  if here and C.FindChannel() then
    extra[#extra + 1] = here
  end
  for _, name in ipairs(extra) do
    if not names[name] then
      names[name] = true
      out[#out + 1] = { city = name, name = name, icon = C.OTHER_CITY_ICON }
    end
  end
  return out
end

-- Sets a message's city (nil or false = any city).
function C.SetCity(index, city)
  local message = C.Messages()[index]
  if message then
    message.city = city or nil
    C.Refresh()
  end
end

-- A message's channel (2026-11-27, the user's "do 5"): its own (message.channel, a C.CHANNELS key), else the one
-- picked for all messages.
function C.MessageChannel(message)
  local key = message and message.channel
  if key and C.ChannelDef(key).key == key then
    return key
  end
  return C.Settings().channel
end

function C.SetChannel(index, key)
  local message = C.Messages()[index]
  if message then
    message.channel = key or nil
    C.Refresh()
  end
end

-- Hours (same day): message.hours = { from, to }, local whole hours 0-23; `to` is not included, and from > to runs
-- past midnight (18 to 0 = the evening). The choices offered:
C.HOURS = {
  { from = 6, to = 12, name = "Mornings, 6:00 to 12:00" },
  { from = 12, to = 18, name = "Afternoons, 12:00 to 18:00" },
  { from = 18, to = 0, name = "Evenings, 18:00 to 0:00" },
  { from = 0, to = 6, name = "Nights, 0:00 to 6:00" },
}

local function ValidHours(hours)
  return type(hours) == "table" and type(hours.from) == "number" and type(hours.to) == "number"
    and hours.from ~= hours.to
end

-- A choice's name as shown, in the client's language (read when shown, like C.ChannelName).
function C.HoursName(def)
  local shown = {
    ["Mornings, 6:00 to 12:00"] = L["Mornings, 6:00 to 12:00"],
    ["Afternoons, 12:00 to 18:00"] = L["Afternoons, 12:00 to 18:00"],
    ["Evenings, 18:00 to 0:00"] = L["Evenings, 18:00 to 0:00"],
    ["Nights, 0:00 to 6:00"] = L["Nights, 0:00 to 6:00"],
  }
  return shown[def.name] or def.name
end

function C.HoursText(hours)
  if not ValidHours(hours) then
    return nil
  end
  return L["%d:00 to %d:00"]:format(hours.from, hours.to)
end

-- The local hour now (0-23), or nil.
function C.Hour()
  local ok, now = pcall(date, "*t")
  return ok and type(now) == "table" and tonumber(now.hour) or nil
end

-- Whether a message may go at this hour: it has no hours, or now is inside them.
function C.InItsHours(message)
  local hours = message and message.hours
  if not ValidHours(hours) then
    return true
  end
  local hour = C.Hour()
  if not hour then
    return true
  end
  if hours.from < hours.to then
    return hour >= hours.from and hour < hours.to
  end
  return hour >= hours.from or hour < hours.to
end

function C.SetHours(index, hours)
  local message = C.Messages()[index]
  if message then
    message.hours = ValidHours(hours) and { from = hours.from, to = hours.to } or nil
    C.Refresh()
  end
end

-- Everything the city button's list offers for a message, in order: headings, the cities (C.CityChoices), the
-- channels and the hours. { { kind = "heading" | "city" | "channel" | "hours", name, icon, value, picked } }
function C.WhereWhenChoices(message)
  local out = { { kind = "heading", name = L["City"] } }
  for _, choice in ipairs(C.CityChoices(message)) do
    out[#out + 1] = { kind = "city", name = choice.name, icon = choice.icon, value = choice.city or false,
      picked = (choice.city or nil) == (message and message.city) }
  end
  out[#out + 1] = { kind = "heading", name = L["Channel"] }
  local own = message and message.channel and C.ChannelDef(message.channel).key == message.channel
    and message.channel or nil
  out[#out + 1] = { kind = "channel", value = false, picked = own == nil,
    name = L["As for all (%s)"]:format(C.ChannelName(C.Settings().channel)) }
  for _, def in ipairs(C.CHANNELS) do
    out[#out + 1] = { kind = "channel", value = def.key, name = C.ChannelName(def.key), picked = own == def.key }
  end
  out[#out + 1] = { kind = "heading", name = L["Time of day (your clock)"] }
  local hours = message and ValidHours(message.hours) and message.hours
  out[#out + 1] = { kind = "hours", value = false, name = L["Any time"], picked = not hours }
  local known = false
  for _, def in ipairs(C.HOURS) do
    local picked = hours and hours.from == def.from and hours.to == def.to or false
    known = known or picked
    out[#out + 1] = { kind = "hours", value = { from = def.from, to = def.to }, name = C.HoursName(def),
      picked = picked }
  end
  if hours and not known then
    out[#out + 1] = { kind = "hours", value = { from = hours.from, to = hours.to }, name = C.HoursText(hours),
      picked = true }
  end
  return out
end

-- The message's conditions as lines ("For Ironforge only.", "In Trade (Services).", "Only 18:00 to 0:00."), for
-- tooltips.
function C.ConditionLines(message)
  local lines = {}
  local city = message and C.CityName(message.city)
  if city then
    lines[#lines + 1] = L["For %s only."]:format(city)
  end
  if message and message.channel and C.ChannelDef(message.channel).key == message.channel then
    lines[#lines + 1] = L["In %s."]:format(C.ChannelName(message.channel))
  end
  local hours = message and C.HoursText(message.hours)
  if hours then
    lines[#lines + 1] = L["Only %s."]:format(hours)
  end
  return lines
end

-- Professions --------------------------------------------------------------------------------------------

-- The profession's chat link from its spellbook slots, or nil. The slot whose spell has the profession's own name
-- comes first: a specialisation's spell can sit before it and gives a link named after itself ("[Armorsmith]" for
-- Blacksmithing, the user's screenshot 2026-11-26).
local function TradeLink(offset, count, name)
  local getLink = C_SpellBook and C_SpellBook.GetSpellBookItemTradeSkillLink
  local getName = C_SpellBook and C_SpellBook.GetSpellBookItemName
  local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
  if not getLink or type(offset) ~= "number" then
    return nil
  end
  local first
  for index = 1, math.max(1, math.min(count or 1, 8)) do
    local link = Ask(getLink, offset + index, bank)
    if type(link) == "string" and link ~= "" then
      if Ask(getName, offset + index, bank) == name then
        return link
      end
      first = first or link
    end
  end
  return first
end

-- { { name, icon, rank, maxRank, link or nil }, ... }: primary professions first, then cooking, fishing,
-- archaeology (GetProfessions order without the gaps).
function C.Professions()
  local out = {}
  if type(GetProfessions) ~= "function" or type(GetProfessionInfo) ~= "function" then
    return out
  end
  local prof1, prof2, arch, fish, cook = Ask(GetProfessions)
  for _, index in ipairs({ prof1 or false, prof2 or false, cook or false, fish or false, arch or false }) do
    if index then
      local name, icon, rank, maxRank, numSpells, offset = Ask(GetProfessionInfo, index)
      if type(name) == "string" and name ~= "" then
        out[#out + 1] = { name = name, icon = icon, rank = rank, maxRank = maxRank, link = TradeLink(offset, numSpells, name) }
      end
    end
  end
  return out
end

-- The message as it will be posted: <Tailoring> = that profession's link, <professions> = every profession that
-- has a link ({Tailoring} works too; the game's font draws { } like the [ ] of a link, so the pages show < >).
-- Returns the text and a list of the codes that matched nothing, as written ("<Alchemy>").
function C.Expand(message)
  local byName, links = {}, {}
  for _, profession in ipairs(C.Professions()) do
    byName[profession.name:lower()] = profession
    if profession.link then
      links[#links + 1] = profession.link
    end
  end
  local unknown = {}
  local function Code(open, close)
    return function(word)
      local lower = word:lower():match("^%s*(.-)%s*$")
      if lower == "professions" then
        return table.concat(links, " ")
      end
      local profession = byName[lower]
      if profession then
        return profession.link or profession.name
      end
      unknown[#unknown + 1] = open .. word .. close
      return open .. word .. close
    end
  end
  local text = tostring(message or ""):gsub("{([^{}|]*)}", Code("{", "}")):gsub("<([^<>|]*)>", Code("<", ">"))
  text = text:gsub("[\r\n]+", " "):match("^%s*(.-)%s*$")
  return text, unknown
end

-- Channels -----------------------------------------------------------------------------------------------

function C.ChannelDef(key)
  for _, def in ipairs(C.CHANNELS) do
    if def.key == key then
      return def
    end
  end
  return C.CHANNELS[1]
end

-- A channel's name as shown, in the client's language (def.name stays English; channels are found by zone ID).
-- Read when shown, so a Locales file loaded after this one still counts.
function C.ChannelName(key)
  local name = C.ChannelDef(key).name
  local shown = { ["Trade"] = L["Trade"], ["Trade (Services)"] = L["Trade (Services)"] }
  return shown[name] or name
end

-- The joined channel's number and full name ("Trade - City") for the chosen channel, or nil.
function C.FindChannel(key)
  local def = C.ChannelDef(key or C.Settings().channel)
  if type(GetChannelList) ~= "function" then
    return nil
  end
  local list = { pcall(GetChannelList) } -- every value: id, name, disabled per joined channel
  if not table.remove(list, 1) then
    return nil
  end
  local getInfo = C_ChatInfo and C_ChatInfo.GetChannelInfoFromIdentifier
  -- the game's short name ("Trade") as a fallback when the info call answers nothing
  local short = C_ChatInfo and Ask(C_ChatInfo.GetChannelShortcutForChannelID, def.zone)
  for index = 1, #list, 3 do
    local id, name, disabled = list[index], list[index + 1], list[index + 2]
    if type(id) == "number" and type(name) == "string" and not disabled then
      local info = getInfo and Ask(getInfo, name)
      if type(info) == "table" and info.zoneChannelID == def.zone then
        return id, name
      end
      if type(info) ~= "table" and type(short) == "string" and short ~= ""
        and (name == short or name:sub(1, #short + 3) == short .. " - ") then
        return id, name
      end
    end
  end
end

function C.Locked()
  return C_ChatInfo and Ask(C_ChatInfo.InChatMessagingLockdown) == true
end

-- State --------------------------------------------------------------------------------------------------

-- Seconds until this message may be posted again (0 = now).
function C.WaitFor(message)
  local last = message.last
  if type(last) ~= "number" then
    return 0
  end
  return math.max(0, last + C.ClampEvery(message.every) - Now())
end

-- What a message is on its own: "empty", "off", "elsewhere" (for another city), "later" (for other hours), "long"
-- or "ok", and its text as posted (and the unknown codes).
function C.MessageState(message)
  local text, unknown = C.Expand(message.text)
  if text == "" then
    return "empty", text, unknown
  elseif message.off then
    return "off", text, unknown
  elseif not C.InItsCity(message) then
    return "elsewhere", text, unknown
  elseif not C.InItsHours(message) then
    return "later", text, unknown
  elseif #text > C.MAX_LENGTH then
    return "long", text, unknown
  end
  return "ok", text, unknown
end

-- The message to post next: of those that can go, the one whose time comes first (when several are due, the one
-- that waited longest, then the first in the list). Returns its index, the message and the seconds until it may go
-- (0 = now), or nil.
function C.NextMessage()
  local list = C.Messages()
  local best, bestWait, bestLast
  for index, message in ipairs(list) do
    if C.MessageState(message) == "ok" then
      local wait = C.WaitFor(message)
      local last = type(message.last) == "number" and message.last or -1
      if not best or wait < bestWait or (wait == bestWait and last < bestLast) then
        best, bestWait, bestLast = index, wait, last
      end
    end
  end
  if best then
    return best, list[best], bestWait
  end
end

-- Seconds until the next post is due (0 = due now).
function C.NextIn()
  local _, _, wait = C.NextMessage()
  return wait or 0
end

-- "message" (nothing to post), "elsewhere" (only messages for other cities), "later" (only for other hours),
-- "long", "paused", "nochannel", "lockdown", "wait", "due".
function C.State()
  local char = C.Char()
  local _, nextMessage = C.NextMessage()
  if not nextMessage then
    local elsewhere, later = false, false
    for _, message in ipairs(C.Messages()) do
      local kind = C.MessageState(message)
      if kind == "long" then
        return "long"
      end
      elsewhere = elsewhere or kind == "elsewhere"
      later = later or kind == "later"
    end
    return elsewhere and "elsewhere" or later and "later" or "message"
  elseif char.paused then
    return "paused"
  elseif not C.FindChannel(C.MessageChannel(nextMessage)) then
    return "nochannel"
  elseif C.Locked() then
    return "lockdown"
  elseif C.NextIn() > 0 then
    return "wait"
  end
  return "due"
end

function C.Clock(seconds)
  seconds = math.max(0, math.floor(seconds + 0.5))
  return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

-- One line on what happens next, for the tooltip and the options page.
function C.StatusText()
  local state = C.State()
  local _, nextMessage = C.NextMessage()
  local channel = C.ChannelName(C.MessageChannel(nextMessage))
  if state == "message" then
    return L["Write a message first."]
  elseif state == "long" then
    return L["Your message is too long with its links; the game takes %d letters."]:format(C.MAX_LENGTH)
  elseif state == "elsewhere" then
    local here = C.Here()
    return here and L["No message for %s: yours are for other cities."]:format(here)
      or L["Your messages are for other cities."]
  elseif state == "later" then
    return L["No message for this time of day: yours are for other hours."]
  elseif state == "paused" then
    return L["Paused on this character."]
  elseif state == "nochannel" then
    return L["No %s chat here: it is in the capital cities."]:format(channel)
  elseif state == "lockdown" then
    return L["The game doesn't let addons send chat right now."]
  end
  local index = C.NextMessage()
  local many = #C.Messages() > 1 and index
  if state == "wait" then
    return C.NextPostText(C.NextIn(), many and index)
  end
  local key = C.Settings().key
  if many then
    return key and L["Time to post (message %d) in %s: click its button or press %s."]:format(index, channel, key)
      or L["Time to post (message %d) in %s: click its button."]:format(index, channel)
  end
  return key and L["Time to post in %s: click the button or press %s."]:format(channel, key)
    or L["Time to post in %s: click the button."]:format(channel)
end

-- "Next post in 4:30." or, with several messages, "Next post in 4:30 (message 2)."
function C.NextPostText(seconds, index)
  if index then
    return L["Next post in %s (message %d)."]:format(C.Clock(seconds), index)
  end
  return L["Next post in %s."]:format(C.Clock(seconds))
end

-- Posting (only from a click or a key press) -------------------------------------------------------------

-- Sends message `index`, or with no index the one that has waited longest (C.NextMessage), once its time has come.
-- Returns true, or false and why (also said in chat).
function C.Post(index)
  local function No(why)
    C.Say(why)
    return false, why
  end
  local char = C.Char()
  local list = C.Messages()
  local message, wait
  if index then
    message = list[index]
    local state = message and C.MessageState(message)
    if state == "long" then
      return No(L["Message %d is too long with its links; the game takes %d letters. Make it shorter."]:format(index,
        C.MAX_LENGTH))
    elseif state == "elsewhere" then
      local city = C.CityName(message.city)
      return No(city and L["Message %d is for %s only."]:format(index, city)
        or L["Message %d is for another city only."]:format(index))
    elseif state == "later" then
      local hours = C.HoursText(message.hours)
      return No(hours and L["Message %d goes only from %s."]:format(index, hours)
        or L["Message %d goes only at other hours."]:format(index))
    elseif state ~= "ok" then
      return No(L["Message %d has nothing to post."]:format(index))
    end
    wait = C.WaitFor(message)
  else
    index, message, wait = C.NextMessage()
    if not index then
      local state = C.State()
      if state == "long" then
        return No(L["Your message is too long with its links; the game takes %d letters. Make it shorter."]:format(
          C.MAX_LENGTH))
      elseif state == "elsewhere" or state == "later" then
        return No(C.StatusText())
      end
      return No(C.COMMAND and L["Write a message first: %s."]:format(C.COMMAND)
        or L["Write a message first on the options page."])
    end
  end
  local text, unknown = C.Expand(message.text)
  local channelKey = C.MessageChannel(message)
  local id, name = C.FindChannel(channelKey)
  if not id then
    return No(L["No %s chat here: it is in the capital cities."]:format(C.ChannelName(channelKey)))
  end
  if C.Locked() then
    return No(L["The game doesn't let addons send chat right now."])
  end
  if wait > 0 then
    return No(C.NextPostText(wait, #list > 1 and index))
  end
  local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
  if type(send) ~= "function" then
    return No(L["The game has no way to send chat here."])
  end
  local ok, err = pcall(send, text, "CHANNEL", nil, id)
  if not ok then
    return No(L["The game didn't send it: %s"]:format(tostring(err)))
  end
  message.last = Now()
  char.lastPost = message.last
  if #unknown > 0 then
    C.Say(L["Posted, but %s matched none of your professions."]:format(table.concat(unknown, ", ")))
  end
  C.lastChannel = name
  C.Refresh()
  return true
end

-- The buttons --------------------------------------------------------------------------------------------
-- One button per message that has something to post (the user's wish, 2026-11-26), each with its own countdown and
-- glow; a click posts that message. They sit in a bar (C.holder) that keeps the place; dragging any button moves the
-- bar. The post key clicks a separate invisible button that posts the message that has waited longest.

local holder, keyButton
local buttons = {}
C.buttons = buttons
local GAP, COLUMN_GAP = 8, 18 -- a column leaves room for each button's label under it

local function SavePlace()
  local point, _, _, x, y = holder:GetPoint(1)
  C.Settings().pos = { point or "CENTER", math.floor((x or 0) + 0.5), math.floor((y or 0) + 0.5) }
end

function C.PlaceButton()
  if not holder then
    return
  end
  local pos = C.Settings().pos
  holder:ClearAllPoints()
  if type(pos) == "table" then
    holder:SetPoint(pos[1] or "CENTER", UIParent, pos[1] or "CENTER", pos[2] or 0, pos[3] or 0)
  else
    holder:SetPoint("CENTER", UIParent, "CENTER", 0, -180)
  end
  holder:SetScale(C.Settings().scale or 1)
end

function C.ResetPlace()
  C.Settings().pos = nil
  C.PlaceButton()
end

-- One line on a button's own state, for its tooltip.
local function ButtonStatus(self)
  local state, index = self.state, self.index
  local message = C.Messages()[index]
  local channel = C.ChannelName(C.MessageChannel(message))
  if state == "wait" and message then
    return L["This one can go again in %s."]:format(C.Clock(C.WaitFor(message)))
  elseif state == "due" then
    return L["Ready to post in %s."]:format(channel)
  elseif state == "long" then
    return L["Too long with its links; the game takes %d letters."]:format(C.MAX_LENGTH)
  end
  return C.StatusText()
end

local function ShowTooltip(self)
  if not GameTooltip then
    return
  end
  local settings = C.Settings()
  local many = #C.Messages() > 1
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  local brand = C.BRAND or "Trade Crier"
  GameTooltip:AddLine(many and L["%s: message %d"]:format(brand, self.index) or brand)
  GameTooltip:AddLine(ButtonStatus(self), 1, 1, 1, true)
  local message = C.Messages()[self.index]
  for _, line in ipairs(C.ConditionLines(message)) do
    GameTooltip:AddLine(line, 1, 1, 1, true)
  end
  local text = message and C.Expand(message.text) or ""
  if text ~= "" then
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(text, 0.85, 0.85, 0.85, true)
  end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine(many and L["Click: post this message when it's ready"] or L["Click: post it when it's ready"],
    0.6, 0.6, 0.6)
  if settings.key then
    GameTooltip:AddLine((many and L["%s: posts the one that has waited longest"] or L["%s: posts it too"]):format(
      settings.key), 0.6, 0.6, 0.6)
  end
  GameTooltip:AddLine(L["Right-click: options. Shift-right-click: pause"], 0.6, 0.6, 0.6)
  if not settings.locked then
    GameTooltip:AddLine(L["Drag: move"], 0.6, 0.6, 0.6)
  end
  GameTooltip:Show()
end

-- The glow frame's own OnUpdate: `self` is the glow (1.0.0 asked for self.glow here and erred every frame while a
-- post was due, the user's error 2026-11-26).
local function Pulse(self, elapsed)
  self.phase = (self.phase or 0) + elapsed
  self:SetAlpha(0.55 + 0.45 * math.sin(self.phase * 4))
end

local function MakeBar()
  holder = CreateFrame("Frame", C.BUTTON_NAME .. "Bar", UIParent)
  holder:SetSize(C.SIZE, C.SIZE)
  holder:SetFrameStrata("MEDIUM")
  holder:SetClampedToScreen(true)
  holder:SetMovable(true)
  C.holder = holder
  -- the key's button: never seen, never under the mouse; the key's press clicks it
  keyButton = CreateFrame("Button", C.BUTTON_NAME .. "Key", UIParent)
  keyButton:SetSize(1, 1)
  keyButton:SetPoint("CENTER")
  keyButton:SetAlpha(0)
  keyButton:EnableMouse(false)
  keyButton:RegisterForClicks("LeftButtonUp")
  keyButton:SetScript("OnClick", function()
    C.Post()
  end)
  C.keyButton = keyButton
  C.PlaceButton()
end

-- The button of message `index` (made the first time it is needed).
local function MakeButton(index)
  local button = CreateFrame("Button", index == 1 and C.BUTTON_NAME or (C.BUTTON_NAME .. index), holder)
  button.index = index
  button:SetSize(C.SIZE, C.SIZE)
  button:EnableMouse(true)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:RegisterForDrag("LeftButton")
  button.icon = button:CreateTexture(nil, "ARTWORK")
  button.icon:SetPoint("TOPLEFT", 2, -2)
  button.icon:SetPoint("BOTTOMRIGHT", -2, 2)
  button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  -- the glow: a pulsing frame round the button while its post is due
  button.glow = CreateFrame("Frame", nil, button)
  button.glow:SetPoint("TOPLEFT", -4, 4)
  button.glow:SetPoint("BOTTOMRIGHT", 4, -4)
  button.glow.lines = {}
  local accent = C.Accent and C.Accent() or { 1, 0.82, 0 }
  for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
    local line = button.glow:CreateTexture(nil, "OVERLAY")
    line:SetColorTexture(accent[1], accent[2], accent[3], 1)
    if side == "TOP" or side == "BOTTOM" then
      line:SetPoint(side .. "LEFT")
      line:SetPoint(side .. "RIGHT")
      line:SetHeight(3)
    else
      line:SetPoint("TOP" .. side)
      line:SetPoint("BOTTOM" .. side)
      line:SetWidth(3)
    end
    button.glow.lines[side] = line
  end
  button.glow:Hide()
  button.glow:SetScript("OnUpdate", Pulse)
  button.label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  button.label:SetPoint("TOP", button, "BOTTOM", 0, -3)
  if C.Look then
    C.Look(button)
  end
  button:SetScript("OnClick", function(self, mouse)
    if mouse == "RightButton" then
      if IsShiftKeyDown() then
        C.SetPaused(not C.Char().paused)
      elseif C.OpenOptions then
        C.OpenOptions()
      end
      return
    end
    if self.state == "message" then
      C.Post() -- nothing written yet: says so
    else
      C.Post(self.index)
    end
  end)
  button:SetScript("OnDragStart", function()
    if not C.Settings().locked then
      holder:StartMoving()
    end
  end)
  button:SetScript("OnDragStop", function()
    holder:StopMovingOrSizing()
    SavePlace()
  end)
  button:SetScript("OnEnter", ShowTooltip)
  button:SetScript("OnLeave", function()
    if GameTooltip then
      GameTooltip:Hide()
    end
  end)
  buttons[index] = button
  if index == 1 then
    C.button = button
  end
  return button
end

local function FirstIcon()
  for _, profession in ipairs(C.Professions()) do
    if profession.icon then
      return profession.icon
    end
  end
  return C.ICON
end

-- Icons ---------------------------------------------------------------------------------------------------

-- The icon a message gets when none is picked (the user's wish, 2026-11-26): the profession it links first
-- (<Tailoring> = Tailoring's icon; <professions> = the first profession with a link), else the first profession,
-- else the note.
function C.AutoIcon(message)
  local text = message and message.text or ""
  local byName = {}
  for _, profession in ipairs(C.Professions()) do
    byName[profession.name:lower()] = profession
  end
  local first, firstAt
  for _, pattern in ipairs({ "()<([^<>|]*)>", "(){([^{}|]*)}" }) do
    for at, word in text:gmatch(pattern) do
      local lower = word:lower():match("^%s*(.-)%s*$")
      local icon
      if lower == "professions" then
        local linkable = C.Linkable()[1]
        icon = linkable and linkable.icon
      elseif byName[lower] then
        icon = byName[lower].icon
      end
      if icon and (not firstAt or at < firstAt) then
        first, firstAt = icon, at
      end
    end
  end
  return first or FirstIcon()
end

-- The message's icon: the one picked, or the automatic one.
function C.MessageIcon(message)
  if message and message.icon ~= nil then
    return message.icon
  end
  return C.AutoIcon(message)
end

-- Icons to pick from: your professions' first, then a few for any trade (each one Codex already shows in game).
C.ICON_CHOICES = {
  "INV_Misc_Note_01", "INV_Misc_Note_02", "INV_Scroll_03", "INV_Misc_Book_09", "INV_Misc_Coin_01", "INV_Misc_Coin_02",
  "INV_Misc_Bag_08", "INV_Misc_Bag_10", "INV_Box_02", "INV_Misc_Gem_Ruby_01", "INV_Jewelry_Ring_03", "INV_Misc_Herb_07",
  "INV_Chest_Cloth_17", "INV_Hammer_04", "Trade_BlackSmithing", "INV_Misc_Gear_01", "INV_Misc_Key_03",
  "INV_Misc_GroupNeedMore",
}
for index, name in ipairs(C.ICON_CHOICES) do
  C.ICON_CHOICES[index] = "Interface\\Icons\\" .. name
end
for _, def in ipairs(C.CITIES) do -- the cities' teleports (TradeCrier issue #1)
  C.ICON_CHOICES[#C.ICON_CHOICES + 1] = def.icon
end

function C.IconChoices()
  local out, seen = {}, {}
  for _, profession in ipairs(C.Professions()) do
    if profession.icon and not seen[profession.icon] then
      seen[profession.icon] = true
      out[#out + 1] = profession.icon
    end
  end
  for _, icon in ipairs(C.ICON_CHOICES) do
    if not seen[icon] then
      seen[icon] = true
      out[#out + 1] = icon
    end
  end
  return out
end

-- Sets a message's icon (nil = automatic).
function C.SetIcon(index, icon)
  local message = C.Messages()[index]
  if message then
    message.icon = icon
    C.Refresh()
  end
end

local ICON_CELL, ICON_COLUMNS = 30, 8
local picker, cityPicker

-- A dark box with a thin accent border over the page, closed by Escape: the icon and city pickers.
local function PickerPanel(name)
  local panel = CreateFrame("Frame", name, UIParent)
  panel:SetFrameStrata("DIALOG")
  panel:SetClampedToScreen(true)
  panel:EnableMouse(true)
  local fill = panel:CreateTexture(nil, "BACKGROUND")
  fill:SetAllPoints()
  fill:SetColorTexture(0.05, 0.05, 0.06, 0.96)
  local accent = C.Accent and C.Accent() or { 1, 0.82, 0 }
  for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
    local line = panel:CreateTexture(nil, "BORDER")
    line:SetColorTexture(accent[1], accent[2], accent[3], 0.8)
    if side == "TOP" or side == "BOTTOM" then
      line:SetPoint(side .. "LEFT")
      line:SetPoint(side .. "RIGHT")
      line:SetHeight(1)
    else
      line:SetPoint("TOP" .. side)
      line:SetPoint("BOTTOM" .. side)
      line:SetWidth(1)
    end
  end
  if type(UISpecialFrames) == "table" then
    table.insert(UISpecialFrames, name)
  end
  return panel
end
C.PickerPanel = PickerPanel -- also the buyers' list (CrierWatch.lua)

local CITY_ROW, CITY_WIDTH = 22, 180

-- Where and when message `index` goes, beside `anchor` (C.WhereWhenChoices: its city, channel and time of day,
-- each a list under a heading; 2026-11-27): a click sets that one and marks it, the list stays open so the others
-- can be set too; `after` runs after each pick. Clicking the anchor again or Escape closes it.
local function PaintWhereWhen()
  local message = C.Messages()[cityPicker.index]
  local choices = C.WhereWhenChoices(message)
  local accent = C.Accent and C.Accent() or { 1, 0.82, 0 }
  for slot, choice in ipairs(choices) do
    local row = cityPicker.rows[slot]
    if not row then
      row = CreateFrame("Button", nil, cityPicker)
      row:SetSize(CITY_WIDTH - 12, CITY_ROW)
      row.mark = row:CreateTexture(nil, "BACKGROUND")
      row.mark:SetAllPoints()
      row.mark:SetColorTexture(accent[1], accent[2], accent[3], 0.35)
      row.hover = row:CreateTexture(nil, "HIGHLIGHT")
      row.hover:SetAllPoints()
      row.hover:SetColorTexture(1, 1, 1, 0.12)
      row.icon = row:CreateTexture(nil, "ARTWORK")
      row.icon:SetSize(CITY_ROW - 4, CITY_ROW - 4)
      row.icon:SetPoint("LEFT", 2, 0)
      row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
      row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      row.text:SetPoint("RIGHT", -4, 0)
      row.text:SetJustifyH("LEFT")
      row:SetScript("OnClick", function(self)
        local index = cityPicker.index
        if self.kind == "city" then
          C.SetCity(index, self.value)
        elseif self.kind == "channel" then
          C.SetChannel(index, self.value)
        elseif self.kind == "hours" then
          C.SetHours(index, self.value)
        else
          return
        end
        PaintWhereWhen()
        if cityPicker.after then
          cityPicker.after()
        end
      end)
      cityPicker.rows[slot] = row
    end
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 6, -6 - (slot - 1) * CITY_ROW)
    row.kind, row.value = choice.kind, choice.value
    row.city = choice.kind == "city" and (choice.value or nil) or nil
    row.text:ClearAllPoints()
    row.text:SetPoint("RIGHT", -4, 0)
    if choice.icon then
      row.icon:SetTexture(choice.icon)
      row.icon:Show()
      row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    else
      row.icon:Hide()
      row.text:SetPoint("LEFT", choice.kind == "heading" and 2 or 8, 0)
    end
    row.text:SetText(choice.name)
    if choice.kind == "heading" then
      row.text:SetTextColor(accent[1], accent[2], accent[3])
      row.hover:Hide()
      row:EnableMouse(false)
    else
      row.text:SetTextColor(1, 1, 1)
      row.hover:Show()
      row:EnableMouse(true)
    end
    row.mark:SetShown(choice.picked and true or false)
    row:Show()
  end
  for slot = #choices + 1, #cityPicker.rows do
    cityPicker.rows[slot]:Hide()
  end
  cityPicker:SetSize(CITY_WIDTH, 12 + #choices * CITY_ROW)
end

function C.ShowCityPicker(anchor, index, after)
  if cityPicker and cityPicker:IsShown() and cityPicker.index == index and cityPicker.anchor == anchor then
    cityPicker:Hide()
    return
  end
  if picker then
    picker:Hide()
  end
  if not cityPicker then
    cityPicker = PickerPanel(C.BUTTON_NAME .. "CityPicker")
    cityPicker.rows = {}
  end
  cityPicker.index, cityPicker.anchor, cityPicker.after = index, anchor, after
  PaintWhereWhen()
  cityPicker:ClearAllPoints()
  cityPicker:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
  cityPicker:Show()
  C.cityPicker = cityPicker
end

-- The small button of an options row that shows and picks message `index`'s city (both hosts' pages use it);
-- C.PaintCityButton repaints it.
function C.CityButton(parent, index, after)
  local button = CreateFrame("Button", nil, parent)
  button:SetSize(22, 22)
  button.index = index
  button.icon = button:CreateTexture(nil, "ARTWORK")
  button.icon:SetAllPoints()
  button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  local hover = button:CreateTexture(nil, "HIGHLIGHT")
  hover:SetAllPoints()
  hover:SetColorTexture(1, 1, 1, 0.2)
  button:SetScript("OnClick", function(self)
    C.ShowCityPicker(self, self.index, after)
  end)
  button:SetScript("OnEnter", function(self)
    if not GameTooltip then
      return
    end
    local message = C.Messages()[self.index]
    local lines = C.ConditionLines(message)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(#lines > 0 and L["Where and when"] or L["Any city, any time"])
    for _, line in ipairs(lines) do
      GameTooltip:AddLine(line, 1, 1, 1, true)
    end
    GameTooltip:AddLine(
      L["Click: pick the city, the channel and the time of day for this message. Its button shows only then."],
      0.6, 0.6, 0.6, true)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function()
    if GameTooltip then
      GameTooltip:Hide()
    end
  end)
  return button
end

function C.PaintCityButton(button, message)
  button.icon:SetTexture(C.CityIcon(message and message.city))
  button.icon:SetDesaturated(#C.ConditionLines(message) == 0)
end

-- A small grid of icons beside `anchor` for message `index`: "Auto" first, then C.IconChoices(). A click picks and
-- closes it; `after` runs after a pick (the page repaints). Clicking the anchor again or Escape closes it.
function C.ShowIconPicker(anchor, index, after)
  if picker and picker:IsShown() and picker.index == index and picker.anchor == anchor then
    picker:Hide()
    return
  end
  if cityPicker then
    cityPicker:Hide()
  end
  if not picker then
    picker = PickerPanel(C.BUTTON_NAME .. "IconPicker")
    picker.cells = {}
  end
  picker.index, picker.anchor = index, anchor
  local message = C.Messages()[index]
  local choices = { false } -- false = automatic
  for _, icon in ipairs(C.IconChoices()) do
    choices[#choices + 1] = icon
  end
  local accent = C.Accent and C.Accent() or { 1, 0.82, 0 }
  for slot, choice in ipairs(choices) do
    local cell = picker.cells[slot]
    if not cell then
      cell = CreateFrame("Button", nil, picker)
      cell:SetSize(ICON_CELL - 2, ICON_CELL - 2)
      cell.icon = cell:CreateTexture(nil, "ARTWORK")
      cell.icon:SetPoint("TOPLEFT", 2, -2)
      cell.icon:SetPoint("BOTTOMRIGHT", -2, 2)
      cell.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
      cell.mark = cell:CreateTexture(nil, "BACKGROUND")
      cell.mark:SetAllPoints()
      cell.mark:SetColorTexture(accent[1], accent[2], accent[3], 1)
      local hover = cell:CreateTexture(nil, "HIGHLIGHT")
      hover:SetAllPoints(cell.icon)
      hover:SetColorTexture(1, 1, 1, 0.2)
      cell.auto = cell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      cell.auto:SetPoint("BOTTOM", 0, 2)
      cell.auto:SetText(L["Auto"])
      cell:SetScript("OnClick", function(self)
        C.SetIcon(picker.index, self.choice or nil)
        picker:Hide()
        if picker.after then
          picker.after()
        end
      end)
      picker.cells[slot] = cell
    end
    local column, row = (slot - 1) % ICON_COLUMNS, math.floor((slot - 1) / ICON_COLUMNS)
    cell:ClearAllPoints()
    cell:SetPoint("TOPLEFT", 6 + column * ICON_CELL, -6 - row * ICON_CELL)
    cell.choice = choice
    cell.icon:SetTexture(choice or C.AutoIcon(message))
    cell.auto:SetShown(not choice)
    local picked = message and (choice and message.icon == choice or (not choice and message.icon == nil))
    cell.mark:SetShown(picked and true or false)
    cell:Show()
  end
  for slot = #choices + 1, #picker.cells do
    picker.cells[slot]:Hide()
  end
  local rows = math.ceil(#choices / ICON_COLUMNS)
  picker:SetSize(12 + math.min(#choices, ICON_COLUMNS) * ICON_CELL - 2, 12 + rows * ICON_CELL - 2)
  picker.after = after
  picker:ClearAllPoints()
  picker:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
  picker:Show()
  C.picker = picker
end

-- A message's post just became due: the sound (once however many came due together) and the chat line, once per
-- round (a round ends when that message is posted: its `last` changes).
local notified = setmetatable({}, { __mode = "k" })
local function Notify(due)
  local settings = C.Settings()
  local sound = false
  for _, entry in ipairs(due) do
    local message = entry.message
    local mark = message.last or 0
    if notified[message] ~= mark then
      notified[message] = mark
      sound = true
      if settings.remind then
        C.Say(#C.Messages() > 1 and L["Message %d is ready: click its button."]:format(entry.index) or C.StatusText())
      end
    end
  end
  if sound and settings.sound and PlaySound and SOUNDKIT and SOUNDKIT.TELL_MESSAGE then
    PlaySound(SOUNDKIT.TELL_MESSAGE)
  end
end

-- Shows, hides, places and repaints the buttons for the current state.
function C.Refresh()
  if not C.started then
    return
  end
  if not holder then
    MakeBar()
  end
  local settings = C.Settings()
  local state = C.State()
  local list = C.Messages()
  local barShown = not (settings.onlyCities and state == "nochannel")
  holder:SetShown(barShown)
  -- the messages that get a button; with none, button 1 stays so the bar can be found (right-click: options)
  local shown = {}
  for index, message in ipairs(list) do
    local kind = C.MessageState(message)
    if kind == "ok" or kind == "long" then
      shown[#shown + 1] = { index = index, message = message, kind = kind }
    end
  end
  local placeholder = #shown == 0
  if placeholder then
    shown[1] = { index = 1, message = list[1], kind = "message" }
  end
  local visible = {}
  for _, entry in ipairs(shown) do
    visible[entry.index] = entry
  end
  for index = 1, C.MAX_MESSAGES do
    if visible[index] and not buttons[index] then
      MakeButton(index)
    end
    if buttons[index] then
      buttons[index]:SetShown(visible[index] ~= nil)
    end
  end
  local due = {}
  local column = settings.column
  for place, entry in ipairs(shown) do
    local button = buttons[entry.index]
    button:ClearAllPoints()
    if column then
      button:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -(place - 1) * (C.SIZE + COLUMN_GAP))
    else
      button:SetPoint("TOPLEFT", holder, "TOPLEFT", (place - 1) * (C.SIZE + GAP), 0)
    end
    local own
    if placeholder then
      own = "message"
    elseif entry.kind == "long" then
      own = "long"
    elseif state == "paused" or state == "nochannel" or state == "lockdown" then
      own = state
    else
      own = C.WaitFor(entry.message) > 0 and "wait" or "due"
    end
    button.state = own
    button.icon:SetTexture(C.MessageIcon(entry.message))
    button.icon:SetDesaturated(own == "paused" or own == "message" or own == "long")
    button.glow:SetShown(own == "due")
    if own == "wait" then
      button.label:SetText(C.Clock(C.WaitFor(entry.message)))
    elseif own == "due" then
      button.label:SetText(L["Post"])
    elseif own == "paused" then
      button.label:SetText(L["Paused"])
    elseif own == "long" then
      button.label:SetText(L["Long"])
    else
      button.label:SetText("")
    end
    if own == "due" then
      due[#due + 1] = entry
    end
  end
  local count = #shown
  if column then
    holder:SetSize(C.SIZE, count * (C.SIZE + COLUMN_GAP) - COLUMN_GAP)
  else
    holder:SetSize(count * (C.SIZE + GAP) - GAP, C.SIZE)
  end
  if barShown and #due > 0 then
    Notify(due)
  end
  if C.OnRefresh then
    C.OnRefresh(state)
  end
end

function C.SetPaused(paused)
  C.Char().paused = paused and true or false
  C.Say(paused and L["Paused on this character."] or L["Posting again."])
  C.Refresh()
end

-- The key -------------------------------------------------------------------------------------------------

local MODIFIERS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true,
  LMETA = true, RMETA = true, UNKNOWN = true }

-- A key press as the game names bindings ("SHIFT-F9"); nil for a modifier alone; false for Escape (clear).
function C.KeyName(key)
  if type(key) ~= "string" or MODIFIERS[key] then
    return nil
  end
  if key == "ESCAPE" then
    return false
  end
  local name = key
  if IsShiftKeyDown() then
    name = "SHIFT-" .. name
  end
  if IsControlKeyDown() then
    name = "CTRL-" .. name
  end
  if IsAltKeyDown() then
    name = "ALT-" .. name
  end
  return name
end

-- The key clicks the key button, which posts the message that has waited longest (an override binding: the player's
-- own binding of that key comes back when it's cleared). Not in a fight: then it's set after the fight.
function C.ApplyKey()
  if not keyButton then
    return
  end
  if InCombatLockdown and InCombatLockdown() then
    C.keyPending = true
    return
  end
  C.keyPending = false
  if ClearOverrideBindings then
    ClearOverrideBindings(keyButton)
  end
  local key = C.Settings().key
  if key and SetOverrideBindingClick then
    SetOverrideBindingClick(keyButton, true, key, keyButton:GetName(), "LeftButton")
  end
end

-- Sets the key (nil clears). Returns what the key did before, if anything.
function C.SetKey(key)
  local before = key and GetBindingAction and Ask(GetBindingAction, key) or nil
  C.Settings().key = key or nil
  C.ApplyKey()
  C.Refresh()
  if type(before) == "string" and before ~= "" then
    return before
  end
end

-- The professions that have a chat link (gathering ones and fishing have none): the insert buttons' list.
function C.Linkable()
  local out = {}
  for _, profession in ipairs(C.Professions()) do
    if profession.link then
      out[#out + 1] = profession
    end
  end
  return out
end

-- Lays the shown buttons out in rows inside `holder` (`width` wide), every row starting at `indent` (right of the
-- row's label); each button as wide as its text. The holder gets the rows' height.
function C.FlowButtons(holder, buttons, width, indent, gap, height)
  local x, y = indent, 0
  for _, button in ipairs(buttons) do
    if button:IsShown() then
      local text = button:GetText() or ""
      local label = button.GetFontString and button:GetFontString()
      local measured = label and label.GetStringWidth and label:GetStringWidth() or 0
      local w = math.floor(math.max(tonumber(measured) or 0, #text * 6.5) + 24)
      button:SetWidth(w)
      if x > indent and x + w > width then
        x, y = indent, y + height + gap
      end
      button:ClearAllPoints()
      button:SetPoint("TOPLEFT", holder, "TOPLEFT", x, -y)
      x = x + w + gap
    end
  end
  holder:SetHeight(y + height)
end

-- Links into a box ----------------------------------------------------------------------------------------

-- Shift-clicking an item, recipe or profession puts its link into the box while the box has the cursor.
function C.WatchLinks(getBox)
  C.linkBoxes = C.linkBoxes or {}
  table.insert(C.linkBoxes, getBox)
  if C.linksHooked then
    return
  end
  C.linksHooked = true
  local function OnInsert(link)
    if type(link) ~= "string" then
      return
    end
    for _, get in ipairs(C.linkBoxes) do
      local box = get()
      if box and box:HasFocus() then
        box:Insert(link)
        return
      end
    end
  end
  if type(_G.ChatFrameUtil) == "table" and type(ChatFrameUtil.InsertLink) == "function" then
    hooksecurefunc(ChatFrameUtil, "InsertLink", OnInsert)
  elseif type(_G.ChatEdit_InsertLink) == "function" then
    hooksecurefunc("ChatEdit_InsertLink", OnInsert)
  end
end

-- Start ---------------------------------------------------------------------------------------------------

local EVENTS = { "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "CHANNEL_UI_UPDATE", "CHAT_MSG_CHANNEL_NOTICE",
  "SKILL_LINES_CHANGED", "PLAYER_REGEN_ENABLED" }

-- Once, at login (standalone) or when the Codex module starts.
function C.Start()
  if C.started then
    return
  end
  C.started = true
  C.Settings()
  C.Char()
  MakeBar()
  C.events = CreateFrame("Frame")
  for _, event in ipairs(EVENTS) do
    C.events:RegisterEvent(event)
  end
  C.events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
      if C.keyPending then
        C.ApplyKey()
      end
      return
    end
    -- channels are joined a moment after the zone changes
    C.Refresh()
    if C_Timer and C_Timer.After then
      C_Timer.After(2, C.Refresh)
    end
  end)
  -- the countdown
  if C_Timer and C_Timer.NewTicker then
    C.ticker = C_Timer.NewTicker(1, function()
      if holder and (holder:IsShown() or C.State() ~= "nochannel") then
        C.Refresh()
      end
    end)
  end
  C.ApplyKey()
  C.Refresh()
  if C.StartWatch then
    C.StartWatch() -- buyers in Trade chat (CrierWatch.lua)
  end
end

-- /crier post (typed: the Enter key is the key press the game wants), pause, resume, reset, status, requests.
function C.Command(word)
  word = (word or ""):lower()
  if word == "post" then
    C.Post()
    return true
  elseif word == "pause" then
    C.SetPaused(true)
    return true
  elseif word == "resume" then
    C.SetPaused(false)
    return true
  elseif word == "reset" then
    C.ResetPlace()
    return true
  elseif word == "status" then
    C.Say(C.StatusText())
    return true
  elseif word == "requests" and C.ShowRequests then
    C.ShowRequests()
    return true
  end
  return false
end
