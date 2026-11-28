local addonName, ns = ...
local L = ns.L

-- Buyers in Trade chat (2026-11-28, the user's request): other players' messages asking for something you can make
-- ("LF tailor", "WTB [Mooncloth Robe]") give a chat line, a sound if you like, and a row in a small list of recent
-- requests with a Whisper button. This file is shared byte for byte by the standalone addon (TradeCrier/CrierWatch.lua)
-- and Codex (Modules/Crier/CrierWatch.lua), after Crier.lua; change both together.
--
-- What counts: a message in Trade or Trade (Services) (General and LookingForGroup too, if the player wants) with a
-- request word (C.RequestWords: "lf", "wtb", "need", ... in the client's language, or the player's own list) and
-- one of: a link to an item one of your professions makes (C.Char().products, learned while the profession window
-- is open), the name of one of your professions (from the game, GetProfessionInfo: only the start of its first word
-- has to match, "tailor" for Tailoring), the name of an item you make, or one of the player's own keywords.
-- Skipped: your own messages, adverts (a profession link in the message, or "wts" / "lfw"), and a sender already
-- listed in the last C.REPEAT_SECONDS. The game may hand addons chat as secret values (CHAT_MSG_CHANNEL is
-- SecretInChatMessagingLockdown in Forever's ChatInfoDocumentation): such a message is skipped untouched.
-- Never sends anything: Whisper only opens the chat box with "/w name " and the reply (ChatFrameUtil.SendTellWithMessage).
-- Channels by zoneChannelID (never secret): 2 Trade, 42 Trade (Services), 1 General, 26 LookingForGroup (Forever's
-- ChatChannels table on wago.tools).

local C = ns.crier

C.WATCH_DEFAULTS = {
  watch = false, -- off until the player switches it on
  watchMore = false, -- General and LookingForGroup too
  watchSound = true,
  watchChat = true, -- a chat line per request
  keywords = "",
  -- requestWords, reply: nil = the default in the client's language (C.DefaultRequestWords, C.DefaultReply)
}
for key, value in pairs(C.WATCH_DEFAULTS) do
  C.DEFAULTS[key] = value
end
C.WATCH_ZONES = { [2] = true, [42] = true }
C.MORE_ZONES = { [1] = true, [26] = true }
C.MAX_PRODUCTS = 2000 -- items a character's recipes make
C.MAX_REQUESTS = 20 -- rows the list keeps
C.REPEAT_SECONDS = 300 -- a sender is listed once in this time
C.KEEP_SECONDS = 3600 -- rows older than this go
C.FIRST_AID = 129 -- skill line: its name ("First") is too common a word to match
C.ADVERT_WORDS = { "wts", "lfw" }

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

local function Readable(value)
  return value ~= nil and (not canaccessvalue or canaccessvalue(value))
end

local function PlainString(value)
  if type(value) == "string" and Readable(value) and value ~= "" then
    return value
  end
end

-- Lower case, also for Cyrillic and the accented Latin letters (string.lower only knows A-Z).
function C.Lower(text)
  text = tostring(text or ""):lower()
  text = text:gsub("\208\129", "\209\145") -- Ё
  text = text:gsub("\208([\144-\175])", function(c)
    local b = c:byte()
    if b < 160 then
      return "\208" .. string.char(b + 32)
    end
    return "\209" .. string.char(b - 32)
  end)
  text = text:gsub("\195([\128-\158])", function(c)
    local b = c:byte()
    if b == 151 then -- the multiplication sign
      return nil
    end
    return "\195" .. string.char(b + 32)
  end)
  return text
end

-- The words of a message as " word word ": links keep their text, colours go, punctuation becomes a space.
function C.PlainWords(text)
  text = tostring(text or "")
  text = text:gsub("|H.-|h(.-)|h", "%1"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", " ")
  text = C.Lower(text):gsub("[%p%c]", " "):gsub("%s+", " ")
  return " " .. text:match("^%s*(.-)%s*$") .. " "
end

-- "a, b c, d" -> { "a", "b c", "d" } (lower case, as C.PlainWords writes them)
function C.SplitWords(text)
  local out = {}
  for part in tostring(text or ""):gmatch("[^,;\n]+") do
    local word = C.PlainWords(part):match("^%s*(.-)%s*$")
    if word ~= "" then
      out[#out + 1] = word
    end
  end
  return out
end

function C.DefaultRequestWords()
  return L["lf, wtb, need, looking for, who can, anyone can##request words"]
end

function C.DefaultReply()
  return L["Hi! I can make that for you: <professions>"]
end

function C.RequestWordsText()
  local text = C.Settings().requestWords
  return type(text) == "string" and text ~= "" and text or C.DefaultRequestWords()
end

function C.ReplyText()
  local text = C.Settings().reply
  return type(text) == "string" and text ~= "" and text or C.DefaultReply()
end

-- Sets a text option; the default (or nothing) is stored as nil, so another client language keeps its own.
function C.SetWatchText(key, text)
  text = tostring(text or ""):match("^%s*(.-)%s*$")
  local settings = C.Settings()
  if key == "requestWords" then
    settings.requestWords = (text ~= "" and text ~= C.DefaultRequestWords()) and text or nil
  elseif key == "reply" then
    settings.reply = (text ~= "" and text ~= C.DefaultReply()) and text or nil
  elseif key == "keywords" then
    settings.keywords = text
  end
end

function C.WatchText(key)
  if key == "requestWords" then
    return C.RequestWordsText()
  elseif key == "reply" then
    return C.ReplyText()
  end
  return C.Settings().keywords or ""
end

-- What each host's options page shows for this part: the checks, then the text boxes.
C.WATCH_CHECKS = {
  { key = "watch", label = "Watch Trade chat for buyers" },
  { key = "watchMore", label = "Also General and LookingForGroup" },
  { key = "watchSound", label = "Play a sound for a request" },
  { key = "watchChat", label = "Say each request in chat" },
}
C.WATCH_BOXES = {
  { key = "requestWords", label = "Request words", hint = "A request needs one of these words, separated by commas." },
  { key = "keywords", label = "Your keywords", hint = "Words that also mean you, like bs, lw or crusader, separated by commas." },
  { key = "reply", label = "Reply", hint = "Whisper puts this in the chat box; <professions> and <Tailoring> become your links. Nothing is sent until you press Enter." },
}
-- A zone channel's short name in the client's language ("General"), from the game; `fallback` when it answers nothing.
function C.ZoneChannelName(zoneChannelID, fallback)
  local name = C_ChatInfo and Ask(C_ChatInfo.GetChannelShortcutForChannelID, zoneChannelID)
  return PlainString(name) or fallback
end

-- Read when shown, so a Locales file loaded after this one still counts.
function C.WatchLabel(text)
  local shown = {
    ["Watch Trade chat for buyers"] = L["Watch Trade chat for buyers"],
    ["Also General and LookingForGroup"] = L["Also %s and %s"]:format(C.ZoneChannelName(1, "General"),
      C.ZoneChannelName(26, "LookingForGroup")),
    ["Play a sound for a request"] = L["Play a sound for a request"],
    ["Say each request in chat"] = L["Say each request in chat"],
    ["Request words"] = L["Request words"],
    ["Your keywords"] = L["Your keywords"],
    ["Reply"] = L["Reply##whisper"],
    ["A request needs one of these words, separated by commas."] = L["A request needs one of these words, separated by commas."],
    ["Words that also mean you, like bs, lw or crusader, separated by commas."] = L["Words that also mean you, like bs, lw or crusader, separated by commas."],
    ["Whisper puts this in the chat box; <professions> and <Tailoring> become your links. Nothing is sent until you press Enter."] = L["Whisper puts this in the chat box; <professions> and <Tailoring> become your links. Nothing is sent until you press Enter."],
  }
  return shown[text] or text
end

-- What your professions make -------------------------------------------------------------------------------

function C.Products()
  local char = C.Char()
  if type(char.products) ~= "table" then
    char.products = {}
  end
  return char.products
end

function C.ProductCount()
  local count = 0
  for _ in pairs(C.Products()) do
    count = count + 1
  end
  return count
end

local nameIndex -- { { name = "mooncloth robe", itemID }, ... } or nil (to build)
local nameIndexTime = 0

-- Replaces what profession `prof` makes with `itemIDs` (up to C.MAX_PRODUCTS in all).
function C.StoreProducts(prof, itemIDs)
  local products = C.Products()
  for itemID, owner in pairs(products) do
    if owner == prof then
      products[itemID] = nil
    end
  end
  local count = C.ProductCount()
  for _, itemID in ipairs(itemIDs) do
    if count >= C.MAX_PRODUCTS then
      break
    end
    if not products[itemID] then
      products[itemID] = prof
      count = count + 1
    end
  end
  nameIndex = nil
end

-- Your own profession window (not one opened from a link, a guild list or an NPC): what its learned recipes make.
function C.LearnProducts()
  local ui = C_TradeSkillUI
  if type(ui) == "table" and ui.GetRecipeSchematic and (ui.GetAllRecipeIDs or ui.GetFilteredRecipeIDs) then
    if ui.IsTradeSkillReady and not Ask(ui.IsTradeSkillReady) then
      return false
    end
    for _, name in ipairs({ "IsTradeSkillLinked", "IsTradeSkillGuild", "IsNPCCrafting", "IsTradeSkillGuildMember" }) do
      if ui[name] and Ask(ui[name]) then
        return false
      end
    end
    local info = ui.GetBaseProfessionInfo and Ask(ui.GetBaseProfessionInfo)
    local prof = type(info) == "table" and (info.professionID or info.professionName)
    if not prof or prof == 0 or prof == "" then
      return false
    end
    local recipes = (ui.GetAllRecipeIDs and Ask(ui.GetAllRecipeIDs)) or Ask(ui.GetFilteredRecipeIDs) or {}
    local found = {}
    for _, recipeID in ipairs(recipes) do
      local recipe = ui.GetRecipeInfo and Ask(ui.GetRecipeInfo, recipeID)
      if type(recipe) == "table" and recipe.learned and not recipe.isDummyRecipe and not recipe.isGatheringRecipe
        and not recipe.isRecraft and not recipe.isSalvageRecipe then
        local schematic = Ask(ui.GetRecipeSchematic, recipeID, false)
        local itemID = type(schematic) == "table" and schematic.outputItemID
        if type(itemID) == "number" and itemID > 0 then
          found[#found + 1] = itemID
        end
      end
    end
    if #found > 0 then
      C.StoreProducts(prof, found)
      return true
    end
    return false
  end
  -- the classic window
  if type(GetNumTradeSkills) == "function" and type(GetTradeSkillItemLink) == "function" then
    local prof = type(GetTradeSkillLine) == "function" and Ask(GetTradeSkillLine)
    if type(prof) ~= "string" or prof == "" or prof == "UNKNOWN" then
      return false
    end
    local found = {}
    for index = 1, Ask(GetNumTradeSkills) or 0 do
      local _, kind = Ask(GetTradeSkillInfo, index)
      if kind ~= "header" then
        local link = Ask(GetTradeSkillItemLink, index)
        local itemID = type(link) == "string" and tonumber(link:match("item:(%d+)"))
        if itemID then
          found[#found + 1] = itemID
        end
      end
    end
    if #found > 0 then
      C.StoreProducts(prof, found)
      return true
    end
  end
  return false
end

local function ItemName(itemID)
  local name = C_Item and C_Item.GetItemNameByID and Ask(C_Item.GetItemNameByID, itemID)
  if not name and type(GetItemInfo) == "function" then
    name = Ask(GetItemInfo, itemID)
  end
  return PlainString(name)
end

-- The names of what you make, for requests without a link. Names the game hasn't loaded yet are asked for and
-- the list is built again a little later.
local function NameIndex()
  if nameIndex and (not nameIndex.missing or Now() - nameIndexTime < 30) then
    return nameIndex
  end
  nameIndex, nameIndexTime = {}, Now()
  for itemID in pairs(C.Products()) do
    local name = ItemName(itemID)
    if name then
      local words = C.PlainWords(name)
      if #words >= 7 then -- " abcd " and longer: short names match too much
        nameIndex[#nameIndex + 1] = { words = words, itemID = itemID, name = name }
      end
    else
      nameIndex.missing = true
      if C_Item and C_Item.RequestLoadItemDataByID then
        Ask(C_Item.RequestLoadItemDataByID, itemID)
      end
    end
  end
  return nameIndex
end

-- Your professions' names as they start a word in a request: the first word without its last four letters
-- (four at least), "tailo" for Tailoring, "black" ... "blacksmit" for Blacksmithing.
function C.ProfessionStems()
  local out = {}
  if type(GetProfessions) ~= "function" or type(GetProfessionInfo) ~= "function" then
    return out
  end
  local prof1, prof2, arch, fish, cook = Ask(GetProfessions)
  for _, index in ipairs({ prof1 or false, prof2 or false, cook or false }) do
    if index then
      local name, _, _, _, _, _, skillLine = Ask(GetProfessionInfo, index)
      name = PlainString(name)
      if name and skillLine ~= C.FIRST_AID then
        local first = C.PlainWords(name):match("^ (%S+)")
        if first then
          local letters = {}
          for letter in first:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
            letters[#letters + 1] = letter
          end
          local keep = math.max(4, #letters - 4)
          if #letters >= 4 then
            out[#out + 1] = { stem = table.concat(letters, "", 1, math.min(keep, #letters)), name = name }
          end
        end
      end
    end
  end
  return out
end

-- Matching ---------------------------------------------------------------------------------------------------

local function HasPhrase(words, phrase)
  return words:find(" " .. phrase .. " ", 1, true) ~= nil
end

-- What a message asks you for, as shown in the list (an item link, a profession or a keyword), or nil.
function C.MatchRequest(text)
  if type(text) ~= "string" or text == "" then
    return nil
  end
  if text:find("|Htrade:", 1, true) then
    return nil -- someone else's advert
  end
  local words = C.PlainWords(text)
  for _, word in ipairs(C.ADVERT_WORDS) do
    if HasPhrase(words, word) then
      return nil
    end
  end
  local asks = false
  for _, phrase in ipairs(C.SplitWords(C.RequestWordsText())) do
    if HasPhrase(words, phrase) then
      asks = true
      break
    end
  end
  if not asks then
    return nil
  end
  local products = C.Products()
  for itemID in text:gmatch("|Hitem:(%d+)") do
    if products[tonumber(itemID)] then
      local link = text:match("|c%x+|Hitem:" .. itemID .. "[^|]*|h.-|h|r")
        or text:match("|Hitem:" .. itemID .. "[^|]*|h.-|h")
      return link or ItemName(tonumber(itemID)) or itemID, "item"
    end
  end
  for _, keyword in ipairs(C.SplitWords(C.Settings().keywords)) do
    if HasPhrase(words, keyword) then
      return keyword, "keyword"
    end
  end
  for _, profession in ipairs(C.ProfessionStems()) do
    if words:find(" " .. profession.stem, 1, true) then
      return profession.name, "profession"
    end
  end
  for _, entry in ipairs(NameIndex()) do
    if words:find(entry.words, 1, true) then
      return entry.name, "name"
    end
  end
  return nil
end

-- The list ------------------------------------------------------------------------------------------------

function C.Requests()
  local char = C.Char()
  if type(char.requests) ~= "table" then
    char.requests = {}
  end
  local list = char.requests
  for index = #list, 1, -1 do
    local entry = list[index]
    if type(entry) ~= "table" or type(entry.time) ~= "number" or Now() - entry.time > C.KEEP_SECONDS then
      table.remove(list, index)
    end
  end
  return list
end

function C.ClearRequests()
  C.Char().requests = {}
  if C.RefreshRequests then
    C.RefreshRequests()
  end
end

local function ShortName(name)
  if type(Ambiguate) == "function" then
    return Ask(Ambiguate, name, "short") or name
  end
  return (name:gsub("%-.*$", ""))
end

local function IsMe(name, guid)
  if Readable(guid) and type(guid) == "string" and guid ~= "" and UnitGUID then
    local mine = Ask(UnitGUID, "player")
    if Readable(mine) and mine == guid then
      return true
    end
  end
  local me = UnitName and Ask(UnitName, "player")
  return Readable(me) and me == ShortName(name)
end

-- A chat line from one of the watched channels. Returns the new list row, or nil.
function C.OnChannelMessage(text, sender, zoneChannelID, guid)
  local settings = C.Settings()
  if not settings.watch then
    return nil
  end
  if not (C.WATCH_ZONES[zoneChannelID] or (settings.watchMore and C.MORE_ZONES[zoneChannelID])) then
    return nil
  end
  text, sender = PlainString(text), PlainString(sender)
  if not text or not sender or IsMe(sender, guid) then
    return nil
  end
  local list = C.Requests()
  for _, entry in ipairs(list) do
    if entry.name == sender and Now() - entry.time < C.REPEAT_SECONDS then
      return nil
    end
  end
  local what, kind = C.MatchRequest(text)
  if not what then
    return nil
  end
  local entry = { name = sender, text = text, what = what, kind = kind, time = Now(), zone = zoneChannelID }
  table.insert(list, 1, entry)
  while #list > C.MAX_REQUESTS do
    table.remove(list)
  end
  if settings.watchChat then
    local who = ("|Hplayer:%s|h[%s]|h"):format(sender, ShortName(sender))
    C.Say(L["%s is looking for %s: %s"]:format(who, what, text))
    if not C.watchHinted then
      C.watchHinted = true
      C.Say(L["Click the name to whisper, or type %s for the list."]:format((C.COMMAND or "/crier") .. " requests"))
    end
  end
  if settings.watchSound and PlaySound and SOUNDKIT and SOUNDKIT.UI_BNET_TOAST then
    PlaySound(SOUNDKIT.UI_BNET_TOAST)
  end
  if C.RefreshRequests then
    C.RefreshRequests()
  end
  return entry
end

-- Opens the chat box with a whisper to `name` and the reply in it. Sends nothing.
function C.Whisper(name)
  name = PlainString(name)
  if not name then
    return false
  end
  local reply = (C.Expand(C.ReplyText()))
  if type(ChatFrameUtil) == "table" and type(ChatFrameUtil.SendTellWithMessage) == "function" then
    return (pcall(ChatFrameUtil.SendTellWithMessage, name, reply))
  elseif type(ChatFrame_OpenChat) == "function" then
    return (pcall(ChatFrame_OpenChat, "/w " .. name .. " " .. reply))
  end
  return false
end

function C.WatchStatus()
  local count = C.ProductCount()
  if count == 0 then
    return L["Open each of your profession windows once so Trade Crier learns what you make."]
  end
  return L["Knows %d items your recipes make. Open a profession window again after learning recipes."]:format(count)
end

function C.Ago(seconds)
  seconds = math.max(0, math.floor(seconds or 0))
  if seconds < 60 then
    return L["now"]
  end
  return L["%d min"]:format(math.floor(seconds / 60))
end

-- The list window: name, how long ago, what, the message, Whisper. Escape or X closes it, drag to move.
local ROWS, ROW_HEIGHT, WIDTH = 10, 34, 460
local window

local function MakeButton(parent, width, height, text)
  local button = CreateFrame("Button", nil, parent)
  button:SetSize(width, height)
  button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  button.label:SetPoint("CENTER")
  button.label:SetText(text)
  button.SetText = function(self, value)
    self.label:SetText(value)
  end
  button.GetText = function(self)
    return self.label:GetText()
  end
  if C.Look then
    C.Look(button)
  end
  return button
end

function C.RefreshRequests()
  if not window or not window:IsShown() then
    return
  end
  local list = C.Requests()
  for index, row in ipairs(window.rows) do
    local entry = list[index]
    row:SetShown(entry ~= nil)
    if entry then
      row.name:SetText(ShortName(entry.name))
      row.age:SetText(C.Ago(Now() - entry.time))
      row.what:SetText(entry.what)
      row.text:SetText(entry.text)
      row.entry = entry
    end
  end
  window.empty:SetShown(#list == 0)
  window:SetHeight(44 + math.max(1, math.min(#list, ROWS)) * ROW_HEIGHT + 30)
end

function C.ShowRequests()
  if not window then
    window = C.PickerPanel(C.BUTTON_NAME .. "Requests")
    window:SetSize(WIDTH, 120)
    window:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    window:SetMovable(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    local accent = C.Accent and C.Accent() or { 1, 0.82, 0 }
    window.title = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    window.title:SetPoint("TOPLEFT", 12, -10)
    window.title:SetText(L["Buyers in Trade chat"])
    window.title:SetTextColor(accent[1], accent[2], accent[3])
    window.close = MakeButton(window, 20, 20, "x")
    window.close:SetPoint("TOPRIGHT", -8, -6)
    window.close:SetScript("OnClick", function()
      window:Hide()
    end)
    window.clear = MakeButton(window, 70, 20, L["Clear"])
    window.clear:SetPoint("RIGHT", window.close, "LEFT", -6, 0)
    window.clear:SetScript("OnClick", C.ClearRequests)
    window.empty = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    window.empty:SetPoint("TOPLEFT", 12, -44)
    window.empty:SetWidth(WIDTH - 24)
    window.empty:SetJustifyH("LEFT")
    window.empty:SetText(L["No requests yet. They show here while Trade Crier watches Trade chat."])
    window.rows = {}
    for index = 1, ROWS do
      local row = CreateFrame("Frame", nil, window)
      row:SetSize(WIDTH - 24, ROW_HEIGHT - 2)
      row:SetPoint("TOPLEFT", 12, -38 - (index - 1) * ROW_HEIGHT)
      row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      row.name:SetPoint("TOPLEFT", 0, -2)
      row.name:SetWidth(110)
      row.name:SetJustifyH("LEFT")
      row.age = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
      row.age:SetPoint("TOPLEFT", 112, -2)
      row.age:SetWidth(50)
      row.age:SetJustifyH("LEFT")
      row.what = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      row.what:SetPoint("TOPLEFT", 164, -2)
      row.what:SetWidth(WIDTH - 24 - 164 - 80)
      row.what:SetJustifyH("LEFT")
      row.what:SetWordWrap(false)
      row.text = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
      row.text:SetPoint("TOPLEFT", 0, -17)
      row.text:SetWidth(WIDTH - 24 - 80)
      row.text:SetJustifyH("LEFT")
      row.text:SetWordWrap(false)
      row.whisper = MakeButton(row, 72, 22, L["Whisper##button"])
      row.whisper:SetPoint("RIGHT", 0, 0)
      row.whisper:SetScript("OnClick", function()
        if row.entry then
          C.Whisper(row.entry.name)
        end
      end)
      window.rows[index] = row
    end
    window:SetScript("OnShow", C.RefreshRequests)
  end
  window:Show()
  C.RefreshRequests()
  C.requestsWindow = window
  return window
end

-- Start --------------------------------------------------------------------------------------------------

local LEARN_EVENTS = { "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_DATA_SOURCE_CHANGED",
  "NEW_RECIPE_LEARNED" }

-- From C.Start (Crier.lua), once.
function C.StartWatch()
  if C.watchEvents then
    return
  end
  C.watchEvents = CreateFrame("Frame")
  C.watchEvents:RegisterEvent("CHAT_MSG_CHANNEL")
  for _, event in ipairs(LEARN_EVENTS) do
    C.watchEvents:RegisterEvent(event)
  end
  local learnPending = false
  C.watchEvents:SetScript("OnEvent", function(_, event, ...)
    if event == "CHAT_MSG_CHANNEL" then
      local text, sender, _, _, _, _, zoneChannelID, _, _, _, _, guid = ...
      if C.Settings().watch then
        C.OnChannelMessage(text, sender, zoneChannelID, guid)
      end
      return
    end
    -- the window fires several updates while it fills: learn once, a moment later
    if learnPending then
      return
    end
    learnPending = true
    local function Learn()
      learnPending = false
      C.LearnProducts()
    end
    if C_Timer and C_Timer.After then
      C_Timer.After(0.5, Learn)
    else
      Learn()
    end
  end)
end
