local addonName, ns = ...

-- Trade Crier (2026-11-26, the user's request): your own messages with your profession links in Trade chat, each
-- again after its own time (in seconds, the user's wish 2026-11-26) while you are in a city. This file is shared byte
-- for byte by the standalone addon (TradeCrier/Crier.lua) and Codex (Modules/Crier/Crier.lua); change both together.
--
-- The host fills ns.crier (C) before this file loads:
--   C.DB()          account settings (filled with C.DEFAULTS here)
--   C.CharDB()      this character's (C.CHAR_DEFAULTS: the messages, paused, the last post)
--   C.Say(text)     a chat line with the host's prefix
--   C.BUTTON_NAME   the post button's frame name (the key binding clicks it)
--   C.Look(button)  the button's frame in the host's style; C.Accent() = { r, g, b } for its glow
--   C.OpenOptions() the options page
--
-- Posting: the game sends an addon's message to a channel only inside a click or key press (Forever's API marks
-- SendChatMessage HasRestrictions; the rule since patch 8.2.5). Nothing here ever posts from a timer: the button
-- lights when a post is due, and the player's click on it, its key or "/crier post" sends the message.
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
  locked = false, -- the button can't be dragged
  scale = 1,
  -- key = "F9", pos = { point, x, y }
}
C.CHAR_DEFAULTS = {
  paused = false,
  -- messages = { { text, every = seconds, off = true or nil, icon = path or nil (automatic), last = time() }, ... }
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

-- What a message is on its own: "empty", "off", "long" or "ok", and its text as posted (and the unknown codes).
function C.MessageState(message)
  local text, unknown = C.Expand(message.text)
  if text == "" then
    return "empty", text, unknown
  elseif message.off then
    return "off", text, unknown
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

-- "message" (nothing to post), "long", "paused", "nochannel", "lockdown", "wait", "due".
function C.State()
  local char = C.Char()
  if not C.NextMessage() then
    for _, message in ipairs(C.Messages()) do
      if C.MessageState(message) == "long" then
        return "long"
      end
    end
    return "message"
  elseif char.paused then
    return "paused"
  elseif not C.FindChannel() then
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
  local channel = C.ChannelDef(C.Settings().channel).name
  if state == "message" then
    return "Write a message first."
  elseif state == "long" then
    return ("Your message is too long with its links; the game takes %d letters."):format(C.MAX_LENGTH)
  elseif state == "paused" then
    return "Paused on this character."
  elseif state == "nochannel" then
    return ("No %s chat here: it is in the capital cities."):format(channel)
  elseif state == "lockdown" then
    return "The game doesn't let addons send chat right now."
  end
  local index = C.NextMessage()
  local which = #C.Messages() > 1 and index and (" (message %d)"):format(index) or ""
  if state == "wait" then
    return ("Next post in %s%s."):format(C.Clock(C.NextIn()), which)
  end
  return ("Time to post%s in %s: click the button%s."):format(which, channel,
    C.Settings().key and (" or press " .. C.Settings().key) or "")
end

-- Posting (only from a click or a key press) -------------------------------------------------------------

-- Sends the next message (C.NextMessage) once its time has come. Returns true, or false and why (also said in
-- chat).
function C.Post()
  local function No(why)
    C.Say(why)
    return false, why
  end
  local char = C.Char()
  local index, message, wait = C.NextMessage()
  if not index then
    if C.State() == "long" then
      return No(("Your message is too long with its links; the game takes %d letters. Make it shorter."):format(
        C.MAX_LENGTH))
    end
    return No("Write a message first: " .. (C.COMMAND or "the options page") .. ".")
  end
  local text, unknown = C.Expand(message.text)
  local id, name = C.FindChannel()
  if not id then
    return No(("No %s chat here: it is in the capital cities."):format(C.ChannelDef(C.Settings().channel).name))
  end
  if C.Locked() then
    return No("The game doesn't let addons send chat right now.")
  end
  if wait > 0 then
    return No(("Next post in %s%s."):format(C.Clock(wait),
      #C.Messages() > 1 and (" (message %d)"):format(index) or ""))
  end
  local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
  if type(send) ~= "function" then
    return No("The game has no way to send chat here.")
  end
  local ok, err = pcall(send, text, "CHANNEL", nil, id)
  if not ok then
    return No("The game didn't send it: " .. tostring(err))
  end
  message.last = Now()
  char.lastPost = message.last
  C.notified = false
  if #unknown > 0 then
    C.Say(("Posted, but %s matched none of your professions."):format(table.concat(unknown, ", ")))
  end
  C.lastChannel = name
  C.Refresh()
  return true
end

-- The button ---------------------------------------------------------------------------------------------

local button

local function SavePlace()
  local point, _, _, x, y = button:GetPoint(1)
  C.Settings().pos = { point or "CENTER", math.floor((x or 0) + 0.5), math.floor((y or 0) + 0.5) }
end

function C.PlaceButton()
  if not button then
    return
  end
  local pos = C.Settings().pos
  button:ClearAllPoints()
  if type(pos) == "table" then
    button:SetPoint(pos[1] or "CENTER", UIParent, pos[1] or "CENTER", pos[2] or 0, pos[3] or 0)
  else
    button:SetPoint("CENTER", UIParent, "CENTER", 0, -180)
  end
  button:SetScale(C.Settings().scale or 1)
end

function C.ResetPlace()
  C.Settings().pos = nil
  C.PlaceButton()
end

local function ShowTooltip(self)
  if not GameTooltip then
    return
  end
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:AddLine(C.BRAND or "Trade Crier")
  GameTooltip:AddLine(C.StatusText(), 1, 1, 1, true)
  local _, message = C.NextMessage()
  local text = message and C.Expand(message.text) or ""
  if text ~= "" then
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(text, 0.85, 0.85, 0.85, true)
  end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("Click: post it when it's time" .. (C.Settings().key and (" (or " .. C.Settings().key .. ")") or ""),
    0.6, 0.6, 0.6)
  GameTooltip:AddLine("Right-click: options. Shift-right-click: pause", 0.6, 0.6, 0.6)
  if not C.Settings().locked then
    GameTooltip:AddLine("Drag: move", 0.6, 0.6, 0.6)
  end
  GameTooltip:Show()
end

-- The glow frame's own OnUpdate: `self` is the glow (1.0.0 asked for self.glow here and erred every frame while a
-- post was due, the user's error 2026-11-26).
local function Pulse(self, elapsed)
  self.phase = (self.phase or 0) + elapsed
  self:SetAlpha(0.55 + 0.45 * math.sin(self.phase * 4))
end

local function MakeButton()
  button = CreateFrame("Button", C.BUTTON_NAME, UIParent)
  button:SetSize(C.SIZE, C.SIZE)
  button:SetFrameStrata("MEDIUM")
  button:SetClampedToScreen(true)
  button:SetMovable(true)
  button:EnableMouse(true)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:RegisterForDrag("LeftButton")
  button.icon = button:CreateTexture(nil, "ARTWORK")
  button.icon:SetPoint("TOPLEFT", 2, -2)
  button.icon:SetPoint("BOTTOMRIGHT", -2, 2)
  button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  -- the glow: a pulsing frame round the button while a post is due
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
    C.Post()
  end)
  button:SetScript("OnDragStart", function(self)
    if not C.Settings().locked then
      self:StartMoving()
    end
  end)
  button:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SavePlace()
  end)
  button:SetScript("OnEnter", ShowTooltip)
  button:SetScript("OnLeave", function()
    if GameTooltip then
      GameTooltip:Hide()
    end
  end)
  C.button = button
  C.PlaceButton()
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
local picker

-- A small grid of icons beside `anchor` for message `index`: "Auto" first, then C.IconChoices(). A click picks and
-- closes it; `after` runs after a pick (the page repaints). Clicking the anchor again or Escape closes it.
function C.ShowIconPicker(anchor, index, after)
  if picker and picker:IsShown() and picker.index == index and picker.anchor == anchor then
    picker:Hide()
    return
  end
  if not picker then
    picker = CreateFrame("Frame", C.BUTTON_NAME .. "IconPicker", UIParent)
    picker:SetFrameStrata("DIALOG")
    picker:SetClampedToScreen(true)
    picker:EnableMouse(true)
    local fill = picker:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(0.05, 0.05, 0.06, 0.96)
    local accent = C.Accent and C.Accent() or { 1, 0.82, 0 }
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
      local line = picker:CreateTexture(nil, "BORDER")
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
    picker.cells = {}
    if type(UISpecialFrames) == "table" then
      table.insert(UISpecialFrames, picker:GetName())
    end
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
      cell.auto:SetText("Auto")
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

-- A post just became due: the sound and the chat line, once per round.
local function Notify()
  if C.notified then
    return
  end
  C.notified = true
  local settings = C.Settings()
  if settings.sound and PlaySound and SOUNDKIT and SOUNDKIT.TELL_MESSAGE then
    PlaySound(SOUNDKIT.TELL_MESSAGE)
  end
  if settings.remind then
    C.Say(C.StatusText())
  end
end

-- Shows, hides and repaints the button for the current state.
function C.Refresh()
  if not C.started then
    return
  end
  if not button then
    MakeButton()
  end
  local settings = C.Settings()
  local state = C.State()
  local show = not (settings.onlyCities and (state == "nochannel"))
  button:SetShown(show)
  local _, upcoming = C.NextMessage()
  button.icon:SetTexture(upcoming and C.MessageIcon(upcoming) or C.MessageIcon(C.Messages()[1]))
  local due = state == "due"
  button.glow:SetShown(due)
  button.icon:SetDesaturated(state == "paused" or state == "message" or state == "long")
  if state == "wait" then
    button.label:SetText(C.Clock(C.NextIn()))
  elseif due then
    button.label:SetText("Post")
  elseif state == "paused" then
    button.label:SetText("Paused")
  else
    button.label:SetText("")
  end
  if due and show then
    Notify()
  end
  if C.OnRefresh then
    C.OnRefresh(state)
  end
end

function C.SetPaused(paused)
  C.Char().paused = paused and true or false
  C.Say(paused and "Paused on this character." or "Posting again.")
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

-- The key clicks the button (an override binding: the player's own binding of that key comes back when it's
-- cleared). Not in a fight: then it's set after the fight.
function C.ApplyKey()
  if not button then
    return
  end
  if InCombatLockdown and InCombatLockdown() then
    C.keyPending = true
    return
  end
  C.keyPending = false
  if ClearOverrideBindings then
    ClearOverrideBindings(button)
  end
  local key = C.Settings().key
  if key and SetOverrideBindingClick then
    SetOverrideBindingClick(button, true, key, C.BUTTON_NAME, "LeftButton")
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
  MakeButton()
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
      if button and (button:IsShown() or C.State() ~= "nochannel") then
        C.Refresh()
      end
    end)
  end
  C.ApplyKey()
  C.Refresh()
end

-- /crier post (typed: the Enter key is the key press the game wants), pause, resume.
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
  end
  return false
end
