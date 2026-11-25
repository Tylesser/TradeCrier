local addonName, ns = ...

-- Tylesser - Trade Crier: the options page (Esc > Options > AddOns) and /crier.

local T = ns.T
local C = ns.crier

local WIDTH = 560
local INSERT_INDENT = 92 -- the insert buttons start right of "Put in a link:"
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

local function Refresh()
  if not view then
    return
  end
  local settings, char = C.Settings(), C.Char()
  if not view.message:HasFocus() and view.message:GetText() ~= char.message then
    view.message:SetText(char.message)
  end
  local text, unknown = C.Expand(char.message)
  view.preview:SetText(text ~= "" and text or "(nothing yet)")
  local long = #text > C.MAX_LENGTH
  view.count:SetText(("%d / %d"):format(#text, C.MAX_LENGTH))
  if long then
    view.count:SetTextColor(1, 0.3, 0.3)
  else
    view.count:SetTextColor(T.MUTED[1], T.MUTED[2], T.MUTED[3])
  end
  view.unknown:SetText(#unknown > 0 and (table.concat(unknown, ", ") .. " matched none of your professions.") or "")
  view.status:SetText(C.StatusText())
  view.interval:SetText(settings.interval .. " minutes")
  view.channel:SetText(C.ChannelDef(settings.channel).name)
  for _, check in ipairs(view.checks) do
    check:SetChecked((check.char and char or settings)[check.key] and true or false)
  end
  view.key:SetText(view.capturing and "Press a key" or (settings.key or "Not set"))
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

local function Insert(word)
  local box = view.message
  box:SetFocus()
  box:Insert(word)
end

local function Build()
  view = {}
  panel.view = view
  local left = 24
  local top = -120

  local messageLabel = Label(panel, "Your message")
  messageLabel:SetPoint("TOPLEFT", left, top)
  local box = CreateFrame("EditBox", "TradeCrierMessageBox", panel, "InputBoxTemplate")
  box:SetSize(WIDTH, 22)
  box:SetPoint("TOPLEFT", messageLabel, "BOTTOMLEFT", 6, -8)
  box:SetAutoFocus(false)
  box:SetMaxLetters(C.MAX_LENGTH)
  T.EditBox(box)
  box:SetScript("OnTextChanged", function(self, userInput)
    if userInput then
      C.Char().message = self:GetText()
      Refresh()
      C.Refresh()
    end
  end)
  box:SetScript("OnEnterPressed", box.ClearFocus)
  box:SetScript("OnEscapePressed", box.ClearFocus)
  view.message = box
  C.WatchLinks(function()
    return view and view.message
  end)

  view.insertRow = CreateFrame("Frame", nil, panel)
  view.insertRow:SetPoint("TOPLEFT", box, "BOTTOMLEFT", -6, -12)
  view.insertRow:SetSize(WIDTH, 20)
  view.insertLabel = Muted(Label(view.insertRow, "Put in a link:", "small"))
  view.insertLabel:SetPoint("TOPLEFT", 0, -4)
  view.inserts = {}
  for index = 1, 6 do
    local button = T.Button(panel, 96, 20, "")
    button:SetScript("OnClick", function(self)
      Insert(self.word)
    end)
    view.inserts[index] = button
  end
  view.insertAll = T.Button(panel, 110, 20, "All professions")
  view.insertAll:SetScript("OnClick", function()
    Insert("<professions>")
  end)
  view.noProfessions = Muted(Label(view.insertRow, "(none of your professions has a link yet)", "small"))
  view.noProfessions:SetPoint("TOPLEFT", INSERT_INDENT, -4)

  local hint = Muted(Label(panel, "<Tailoring> becomes your Tailoring link when it is posted, <professions> all of them. "
    .. "Professions you gather with (and Fishing) have no link. Shift-click an item or a recipe while the box has the "
    .. "cursor to put its link in.", "small"))
  hint:SetPoint("TOPLEFT", view.insertRow, "BOTTOMLEFT", 0, -10)
  hint:SetWidth(WIDTH)
  hint:SetWordWrap(true)

  local previewLabel = Label(panel, "In chat it reads")
  previewLabel:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -14)
  view.count = Label(panel, "", "small")
  view.count:SetPoint("LEFT", previewLabel, "RIGHT", 10, 0)
  view.preview = Label(panel, "", "small")
  view.preview:SetPoint("TOPLEFT", previewLabel, "BOTTOMLEFT", 0, -6)
  view.preview:SetWidth(WIDTH)
  view.preview:SetWordWrap(true)
  view.unknown = Label(panel, "", "small")
  view.unknown:SetTextColor(1, 0.5, 0.3)
  view.unknown:SetPoint("TOPLEFT", view.preview, "BOTTOMLEFT", 0, -4)
  view.unknown:SetWidth(WIDTH)

  view.status = Label(panel, "")
  view.status:SetPoint("TOPLEFT", view.unknown, "BOTTOMLEFT", 0, -12)
  view.status:SetWidth(WIDTH)
  local post = T.Button(panel, 110, 22, "Post now", true)
  post:SetPoint("TOPLEFT", view.status, "BOTTOMLEFT", 0, -8)
  post:SetScript("OnClick", function()
    C.Post()
    Refresh()
  end)
  local postNote = Muted(Label(panel, "The game sends a Trade chat message only when you click or press a key, so the "
    .. "button by your character lights up when it's time and you post with one click.", "small"))
  postNote:SetPoint("LEFT", post, "RIGHT", 10, 0)
  postNote:SetWidth(WIDTH - 120)
  postNote:SetWordWrap(true)

  -- timing and channel
  local every = Label(panel, "Post every")
  every:SetPoint("TOPLEFT", post, "BOTTOMLEFT", 0, -22)
  local less = T.Button(panel, 22, 20, "-")
  less:SetPoint("LEFT", every, "RIGHT", 10, 0)
  view.interval = Label(panel, "", "small")
  view.interval:SetPoint("LEFT", less, "RIGHT", 8, 0)
  view.interval:SetWidth(70)
  view.interval:SetJustifyH("CENTER")
  local more = T.Button(panel, 22, 20, "+")
  more:SetPoint("LEFT", view.interval, "RIGHT", 8, 0)
  local function Step(direction)
    local settings = C.Settings()
    local list = C.INTERVALS
    local at = 1
    for index, minutes in ipairs(list) do
      if minutes <= settings.interval then
        at = index
      end
    end
    settings.interval = list[math.max(1, math.min(#list, at + direction))]
    Refresh()
    C.Refresh()
  end
  less:SetScript("OnClick", function() Step(-1) end)
  more:SetScript("OnClick", function() Step(1) end)
  view.less, view.more = less, more
  local channelLabel = Label(panel, "Channel")
  channelLabel:SetPoint("LEFT", more, "RIGHT", 30, 0)
  view.channel = T.Button(panel, 130, 20, "")
  view.channel:SetPoint("LEFT", channelLabel, "RIGHT", 10, 0)
  view.channel:SetScript("OnClick", function()
    local settings = C.Settings()
    settings.channel = settings.channel == "trade" and "services" or "trade"
    Refresh()
    C.Refresh()
  end)

  -- checks
  view.checks = {}
  local anchor = every
  for index, option in ipairs({
    { "paused", "Pause on this character", true },
    { "sound", "Play a sound when it's time to post" },
    { "remind", "Say in chat when it's time to post" },
    { "onlyCities", "Only show the button in cities" },
    { "locked", "Lock the button in place" },
  }) do
    local check = T.Check(panel, option[2])
    check.key, check.char = option[1], option[3]
    check:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", index == 1 and -4 or 0, index == 1 and -12 or -2)
    check:SetScript("OnClick", function(self)
      local on = self:GetChecked() and true or false
      if self.char then
        C.Char()[self.key] = on
      else
        C.Settings()[self.key] = on
      end
      Refresh()
      C.Refresh()
    end)
    view.checks[#view.checks + 1] = check
    anchor = check
  end

  -- the key
  local keyLabel = Label(panel, "Post key")
  keyLabel:SetPoint("TOPLEFT", every, "BOTTOMLEFT", 320, -16)
  view.key = T.Button(panel, 110, 22, "")
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
      C.Say(("%s did \"%s\"; while it posts, that comes back when you clear it here."):format(name, before))
    end
    Refresh()
  end)
  local keyHint = Muted(Label(panel, "Click, then press a key. Escape or right-click clears it.", "small"))
  keyHint:SetPoint("TOPLEFT", keyLabel, "BOTTOMLEFT", 0, -10)
  keyHint:SetWidth(WIDTH - 320)
  keyHint:SetWordWrap(true)
  local reset = T.Button(panel, 150, 22, "Put the button back")
  reset:SetPoint("TOPLEFT", keyHint, "BOTTOMLEFT", 0, -14)
  reset:SetScript("OnClick", C.ResetPlace)
end

local function CreateOptions()
  panel = CreateFrame("Frame")
  panel.name = ns.TITLE
  T.OptionsPage(panel, "Trade Crier",
    "Your message with your profession links in Trade chat, again every few minutes while you are in a city.")
  panel:SetScript("OnShow", function()
    if not view then
      Build()
    end
    Refresh()
  end)
  if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
    local category = Settings.RegisterCanvasLayoutCategory(panel, ns.TITLE)
    Settings.RegisterAddOnCategory(category)
    ns.optionsCategory = category
  end
  ns.panel = panel
end

function ns.OpenOptions()
  if ns.optionsCategory and Settings and Settings.OpenToCategory then
    local id = ns.optionsCategory.GetID and ns.optionsCategory:GetID() or ns.optionsCategory.ID
    Settings.OpenToCategory(id)
  end
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
  T.AddCompartment({ text = ns.TITLE, onClick = ns.OpenOptions, tooltip = { "Click to open the options." } })
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
    C.Say("/crier opens the options. /crier post posts your message now, /crier pause | resume, /crier status, "
      .. "/crier reset puts the button back, /crier feedback.")
  end
end
