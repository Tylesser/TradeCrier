local addonName, ns = ...
local L = ns.L

-- Tylesser - Trade Crier: the options page (Esc > Options > AddOns) and /crier. The page scrolls: the message list
-- grows a row per message.

local T = ns.T
local C = ns.crier

local WIDTH = 560
local INSERT_INDENT = 92 -- the insert buttons start right of "Put in a link:"
local ROW = 28 -- one message row
local BASE_HEIGHT = 620 -- the page below and above the message rows (with the lines between its groups)
local panel, view

local function Label(parent, text, size)
  local label = parent:CreateFontString(nil, "OVERLAY", size == "small" and "GameFontHighlightSmall" or "GameFontNormal")
  label:SetText(text or "")
  label:SetJustifyH("LEFT")
  return label
end

local function Muted(label)
  label:SetTextColor(T.MUTED[1], T.MUTED[2], T.MUTED[3])
  return label
end

-- A row's state on its right: when it goes next, or why it doesn't.
local function RowState(message)
  local state = C.MessageState(message)
  if state == "empty" then
    return "", T.MUTED
  elseif state == "off" then
    return L["off"], T.MUTED
  elseif state == "long" then
    return L["too long"], { 1, 0.3, 0.3 }
  elseif state == "elsewhere" then
    return L["elsewhere"], T.MUTED
  elseif state == "later" then
    return L["later"], T.MUTED
  end
  local wait = C.WaitFor(message)
  if wait > 0 then
    return L["in %s"]:format(C.Clock(wait)), T.MUTED
  end
  return L["ready"], T.GOLD
end

local function Refresh()
  if not view then
    return
  end
  local settings, char = C.Settings(), C.Char()
  local messages = C.Messages()
  if not messages[view.active] then
    view.active = 1
  end
  for index, row in ipairs(view.rows) do
    local message = messages[index]
    row:SetShown(message ~= nil)
    if message then
      if not row.box:HasFocus() and row.box:GetText() ~= message.text then
        row.box:SetText(message.text)
      end
      if not row.every:HasFocus() then
        row.every:SetText(tostring(message.every))
      end
      row.on:SetChecked(not message.off)
      row.pick.icon:SetTexture(C.MessageIcon(message))
      row.pick.icon:SetDesaturated(message.off and true or false)
      C.PaintCityButton(row.city, message)
      local text, color = RowState(message)
      row.state:SetText(text)
      row.state:SetTextColor(color[1], color[2], color[3])
      local number = index == view.active and T.GOLD or T.MUTED
      row.number:SetTextColor(number[1], number[2], number[3])
    end
  end
  view.rowHolder:SetHeight(#messages * ROW)
  view.add:SetShown(#messages < C.MAX_MESSAGES)
  view.content:SetHeight(BASE_HEIGHT + #messages * ROW)

  local _, text, unknown = C.MessageState(messages[view.active])
  view.previewLabel:SetText(#messages > 1 and L["Message %d in chat reads"]:format(view.active) or L["In chat it reads"])
  view.preview:SetText(text ~= "" and text or L["(nothing yet)"])
  view.count:SetText(("%d / %d"):format(#text, C.MAX_LENGTH))
  if #text > C.MAX_LENGTH then
    view.count:SetTextColor(1, 0.3, 0.3)
  else
    view.count:SetTextColor(T.MUTED[1], T.MUTED[2], T.MUTED[3])
  end
  view.unknown:SetText(#unknown > 0 and L["%s matched none of your professions."]:format(table.concat(unknown, ", ")) or "")
  view.status:SetText(C.StatusText())
  view.channel:SetText(C.ChannelName(settings.channel))
  for _, check in ipairs(view.checks) do
    check:SetChecked((check.char and char or settings)[check.key] and true or false)
  end
  view.key:SetText(view.capturing and L["Press a key"] or (settings.key or L["Not set"]))
  -- one insert button per profession that has a link, in rows that fit the page
  local professions = C.Linkable()
  for index, button in ipairs(view.inserts) do
    local profession = professions[index]
    button:SetShown(profession ~= nil)
    if profession then
      button.word = "<" .. profession.name .. ">"
      button:SetText(profession.name)
    end
  end
  view.insertAll:SetShown(#professions > 1)
  view.noProfessions:SetShown(#professions == 0)
  local buttons = {}
  for _, button in ipairs(view.inserts) do
    buttons[#buttons + 1] = button
  end
  buttons[#buttons + 1] = view.insertAll
  C.FlowButtons(view.insertRow, buttons, WIDTH, INSERT_INDENT, 6, 20)
end
ns.RefreshOptions = Refresh

local function Changed()
  Refresh()
  C.Refresh()
end

local function ActiveBox()
  local row = view.rows[view.active] or view.rows[1]
  return row.box
end

local function Insert(word)
  local box = ActiveBox()
  box:SetFocus()
  box:Insert(word)
end

-- One message row: on/off, its icon, its city, the text, its seconds, when it goes next, remove.
local function MessageRow(parent, index)
  local row = CreateFrame("Frame", nil, parent)
  row:SetSize(WIDTH, ROW)
  row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW)
  row.number = Label(row, tostring(index), "small")
  row.number:SetPoint("LEFT", 0, 0)
  row.number:SetWidth(14)
  row.on = T.Check(row)
  row.on:SetPoint("LEFT", 14, 0)
  row.on:SetHitRectInsets(0, 0, 0, 0)
  row.on:SetScript("OnClick", function(self)
    local message = C.Messages()[index]
    if message then
      message.off = not self:GetChecked() or nil
      Changed()
    end
  end)
  row.remove = T.Button(row, 20, 20, "X")
  row.remove:SetPoint("RIGHT", 0, 0)
  row.remove:SetScript("OnClick", function()
    row.box:ClearFocus()
    C.RemoveMessage(index)
    Changed()
  end)
  row.state = Label(row, "", "small")
  row.state:SetPoint("RIGHT", row.remove, "LEFT", -6, 0)
  row.state:SetWidth(60)
  local unit = Muted(Label(row, L["s"], "small"))
  unit:SetPoint("RIGHT", row.state, "LEFT", -8, 0)
  row.every = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
  row.every:SetSize(50, 20)
  row.every:SetPoint("RIGHT", unit, "LEFT", -6, 0)
  row.every:SetAutoFocus(false)
  row.every:SetNumeric(true)
  row.every:SetMaxLetters(5)
  row.every:SetJustifyH("CENTER")
  T.EditBox(row.every)
  row.every:SetScript("OnTextChanged", function(self, userInput)
    local message = C.Messages()[index]
    local seconds = tonumber(self:GetText())
    -- while typing ("3" on the way to "300") only a number that is already allowed is kept
    if userInput and message and seconds and seconds >= C.MIN_EVERY then
      message.every = C.ClampEvery(seconds)
      Changed()
    end
  end)
  row.every:SetScript("OnEditFocusLost", function(self)
    local message = C.Messages()[index]
    if message then
      message.every = C.ClampEvery(tonumber(self:GetText()) or message.every)
      self:SetText(tostring(message.every))
      Changed()
    end
  end)
  row.every:SetScript("OnEnterPressed", row.every.ClearFocus)
  row.every:SetScript("OnEscapePressed", row.every.ClearFocus)
  local every = Muted(Label(row, L["every"], "small"))
  every:SetPoint("RIGHT", row.every, "LEFT", -10, 0)
  row.box = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
  row.box:SetHeight(20)
  -- its icon (the button shows the icon of the message that goes next): picked, or its profession's
  row.pick = CreateFrame("Button", nil, row)
  row.pick:SetSize(22, 22)
  row.pick:SetPoint("LEFT", row.on, "RIGHT", 4, 0)
  row.pick.icon = row.pick:CreateTexture(nil, "ARTWORK")
  row.pick.icon:SetAllPoints()
  row.pick.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  local pickHover = row.pick:CreateTexture(nil, "HIGHLIGHT")
  pickHover:SetAllPoints()
  pickHover:SetColorTexture(1, 1, 1, 0.2)
  row.pick:SetScript("OnClick", function(self)
    C.ShowIconPicker(self, index, Refresh)
  end)
  -- the city it is for (TradeCrier issue #1): any, or one where its button shows
  row.city = C.CityButton(row, index, Refresh)
  row.city:SetPoint("LEFT", row.pick, "RIGHT", 4, 0)
  row.box:SetPoint("LEFT", row.city, "RIGHT", 10, 0)
  row.box:SetPoint("RIGHT", every, "LEFT", -10, 0)
  row.box:SetAutoFocus(false)
  row.box:SetMaxLetters(C.MAX_LENGTH)
  T.EditBox(row.box)
  row.box:SetScript("OnTextChanged", function(self, userInput)
    local message = C.Messages()[index]
    if userInput and message then
      message.text = self:GetText()
      view.active = index
      Changed()
    end
  end)
  row.box:SetScript("OnEditFocusGained", function()
    if view.active ~= index then
      view.active = index
      Refresh()
    end
  end)
  row.box:SetScript("OnEnterPressed", row.box.ClearFocus)
  row.box:SetScript("OnEscapePressed", row.box.ClearFocus)
  C.WatchLinks(function()
    return row:IsShown() and row.box or nil
  end)
  return row
end

local function Build()
  view = { active = 1 }
  panel.view = view
  local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, T.OPTIONS_TOP)
  scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -30, 14)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(WIDTH + 20, BASE_HEIGHT)
  scroll:SetScrollChild(content)
  view.scroll, view.content = scroll, content
  local left = 10

  local messageLabel = Label(content, L["Your messages"])
  messageLabel:SetPoint("TOPLEFT", left, -4)
  local messageHint = Muted(Label(content, L["Each message has its own button by your character, with its icon, its own countdown and its own time in seconds (%d at least): it lights up when that message is ready, and a click posts it. The post key posts the one that has waited longest. Click an icon here to pick another; until you do, a message shows the profession it links. Untick a message to keep it without posting it."]:format(
    C.MIN_EVERY), "small"))
  messageHint:SetPoint("TOPLEFT", messageLabel, "BOTTOMLEFT", 0, -4)
  messageHint:SetWidth(WIDTH)
  messageHint:SetWordWrap(true)
  view.rowHolder = CreateFrame("Frame", nil, content)
  view.rowHolder:SetPoint("TOPLEFT", messageHint, "BOTTOMLEFT", 0, -6)
  view.rowHolder:SetSize(WIDTH, ROW)
  view.rows = {}
  for index = 1, C.MAX_MESSAGES do
    view.rows[index] = MessageRow(view.rowHolder, index)
  end
  view.message = view.rows[1].box
  view.add = T.Button(content, 130, 20, L["Add a message"])
  view.add:SetPoint("TOPLEFT", view.rowHolder, "BOTTOMLEFT", 0, -4)
  view.add:SetScript("OnClick", function()
    local index = C.AddMessage()
    if index then
      view.active = index
      Changed()
      view.rows[index].box:SetFocus()
    end
  end)

  view.insertRow = CreateFrame("Frame", nil, content)
  view.insertRow:SetPoint("TOPLEFT", view.add, "BOTTOMLEFT", 0, -12)
  view.insertRow:SetSize(WIDTH, 20)
  view.insertLabel = Muted(Label(view.insertRow, L["Put in a link:"], "small"))
  view.insertLabel:SetPoint("TOPLEFT", 0, -4)
  view.inserts = {}
  for index = 1, 6 do
    local button = T.Button(content, 96, 20, "")
    button:SetScript("OnClick", function(self)
      Insert(self.word)
    end)
    view.inserts[index] = button
  end
  view.insertAll = T.Button(content, 110, 20, L["All professions"])
  view.insertAll:SetScript("OnClick", function()
    Insert("<professions>")
  end)
  view.noProfessions = Muted(Label(view.insertRow, L["(none of your professions has a link yet)"], "small"))
  view.noProfessions:SetPoint("TOPLEFT", INSERT_INDENT, -4)

  local hint = Muted(Label(content, L["<Tailoring> becomes your Tailoring link when it is posted, <professions> all of them. Professions you gather with (and Fishing) have no link. The buttons put the link into the message you last clicked; shift-click an item or a recipe while a box has the cursor to put its link in."], "small"))
  hint:SetPoint("TOPLEFT", view.insertRow, "BOTTOMLEFT", 0, -10)
  hint:SetWidth(WIDTH)
  hint:SetWordWrap(true)

  -- lines between the page's groups (2026-11-28, the user's request: the sections ran together)
  local previewLine = T.Divider(content, WIDTH, 13)
  previewLine:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -6)
  view.previewLabel = Label(content, L["In chat it reads"])
  view.previewLabel:SetPoint("TOPLEFT", previewLine, "BOTTOMLEFT", 0, -6)
  view.count = Label(content, "", "small")
  view.count:SetPoint("LEFT", view.previewLabel, "RIGHT", 10, 0)
  view.preview = Label(content, "", "small")
  view.preview:SetPoint("TOPLEFT", view.previewLabel, "BOTTOMLEFT", 0, -6)
  view.preview:SetWidth(WIDTH)
  view.preview:SetWordWrap(true)
  view.unknown = Label(content, "", "small")
  view.unknown:SetTextColor(1, 0.5, 0.3)
  view.unknown:SetPoint("TOPLEFT", view.preview, "BOTTOMLEFT", 0, -4)
  view.unknown:SetWidth(WIDTH)

  view.status = Label(content, "")
  view.status:SetPoint("TOPLEFT", view.unknown, "BOTTOMLEFT", 0, -12)
  view.status:SetWidth(WIDTH)
  local post = T.Button(content, 110, 22, L["Post now"], true)
  post:SetPoint("TOPLEFT", view.status, "BOTTOMLEFT", 0, -8)
  post:SetScript("OnClick", function()
    C.Post()
    Refresh()
  end)
  local postNote = Muted(Label(content, L["The game sends a Trade chat message only when you click or press a key, so a message's button by your character lights up when it's ready and you post it with one click. Post now sends the one that has waited longest."], "small"))
  postNote:SetPoint("LEFT", post, "RIGHT", 10, 0)
  postNote:SetWidth(WIDTH - 120)
  postNote:SetWordWrap(true)

  -- the channel
  local buttonsLine = T.Divider(content, WIDTH, 13)
  buttonsLine:SetPoint("TOPLEFT", post, "BOTTOMLEFT", 0, -10)
  local channelLabel = Label(content, L["Channel"])
  channelLabel:SetPoint("TOPLEFT", buttonsLine, "BOTTOMLEFT", 0, -8)
  view.channel = T.Button(content, 130, 20, "")
  view.channel:SetPoint("LEFT", channelLabel, "RIGHT", 10, 0)
  view.channel:SetScript("OnClick", function()
    local settings = C.Settings()
    settings.channel = settings.channel == "trade" and "services" or "trade"
    Changed()
  end)

  -- checks
  view.checks = {}
  local anchor = channelLabel
  for index, option in ipairs({
    { "paused", L["Pause on this character"], true },
    { "sound", L["Play a sound when it's time to post"] },
    { "remind", L["Say in chat when it's time to post"] },
    { "onlyCities", L["Only show the button in cities"] },
    { "locked", L["Lock the buttons in place"] },
    { "column", L["Stack the buttons in a column"] },
  }) do
    local check = T.Check(content, option[2])
    check.key, check.char = option[1], option[3]
    check:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", index == 1 and -4 or 0, index == 1 and -12 or -2)
    check:SetScript("OnClick", function(self)
      local on = self:GetChecked() and true or false
      if self.char then
        C.Char()[self.key] = on
      else
        C.Settings()[self.key] = on
      end
      Changed()
    end)
    view.checks[#view.checks + 1] = check
    anchor = check
  end

  -- the key
  local keyLabel = Label(content, L["Post key"])
  keyLabel:SetPoint("TOPLEFT", channelLabel, "BOTTOMLEFT", 320, -16)
  view.key = T.Button(content, 110, 22, "")
  view.key:SetPoint("LEFT", keyLabel, "RIGHT", 10, 0)
  view.key:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  view.key:SetScript("OnClick", function(self, mouse)
    if mouse == "RightButton" then
      view.capturing = false
      self:EnableKeyboard(false)
      C.SetKey(nil)
    else
      view.capturing = not view.capturing
      self:EnableKeyboard(view.capturing)
    end
    Refresh()
  end)
  view.key:SetScript("OnKeyDown", function(self, key)
    if not view.capturing then
      return
    end
    local name = C.KeyName(key)
    if name == nil then
      return -- a modifier alone: wait for the key
    end
    view.capturing = false
    self:EnableKeyboard(false)
    local before = C.SetKey(name or nil)
    if before then
      C.Say(L["%s did \"%s\"; while it posts, that comes back when you clear it here."]:format(name, before))
    end
    Refresh()
  end)
  local keyHint = Muted(Label(content, L["Click, then press a key. Escape or right-click clears it."], "small"))
  keyHint:SetPoint("TOPLEFT", keyLabel, "BOTTOMLEFT", 0, -10)
  keyHint:SetWidth(WIDTH - 320)
  keyHint:SetWordWrap(true)
  local reset = T.Button(content, 150, 22, L["Put the buttons back"])
  reset:SetPoint("TOPLEFT", keyHint, "BOTTOMLEFT", 0, -14)
  reset:SetScript("OnClick", C.ResetPlace)
end

local function CreateOptions()
  panel = CreateFrame("Frame")
  panel.name = ns.TITLE
  T.OptionsPage(panel, "Trade Crier",
    L["Your messages with your profession links in Trade chat, each again after its own time while you are in a city."])
  panel:SetScript("OnShow", function()
    if not view then
      Build()
    end
    Refresh()
  end)
  -- shown in Tylesser's own settings window (Tylesser.lua T.RegisterOptions, 2026-11-28)
  ns.optionsCategory = ns.T.RegisterOptions(panel, ns.TITLE)
  ns.panel = panel
end

function ns.OpenOptions()
  ns.T.OpenOptions(ns.optionsCategory)
end

-- the page follows the button's state (the countdown, a post made with the key)
C.OnRefresh = function()
  if panel and panel:IsVisible() then
    Refresh()
  end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
  CreateOptions()
  T.AddCompartment({ text = ns.TITLE, onClick = ns.OpenOptions, tooltip = { L["Click to open the options."] } })
end)

SLASH_TYLESSERTRADECRIER1 = "/crier"
SLASH_TYLESSERTRADECRIER2 = "/tradecrier"
SlashCmdList.TYLESSERTRADECRIER = function(msg)
  local command = strtrim(msg or ""):lower()
  if command == "" or command == "options" then
    ns.OpenOptions()
  elseif command == "feedback" then
    T.ShowFeedback()
  elseif not C.Command(command) then
    C.Say(L["/crier opens the options. /crier post posts the message that has waited longest, /crier pause | resume, /crier status, /crier reset puts the buttons back, /crier feedback."])
  end
end
