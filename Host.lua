local addonName, ns = ...

-- Tylesser - Trade Crier: what Crier.lua (shared with Codex's Modules/Crier) needs from its host. Settings in
-- TradeCrierDB (account: timing, channel, button, key) and TradeCrierCharDB (this character: the message, paused,
-- the last post). Starts at PLAYER_LOGIN.

local T = ns.T
local C = {}
ns.crier = C

ns.TITLE = "Tylesser - Trade Crier"
ns.PREFIX = T.Prefix("Trade Crier")
C.BRAND = "Trade Crier"
C.BUTTON_NAME = "TradeCrierButton"
C.COMMAND = "/crier"

function C.DB()
  if type(TradeCrierDB) ~= "table" then
    TradeCrierDB = {}
  end
  return TradeCrierDB
end

function C.CharDB()
  if type(TradeCrierCharDB) ~= "table" then
    TradeCrierCharDB = {}
  end
  return TradeCrierCharDB
end

function C.Say(text)
  print(ns.PREFIX .. text)
end

function C.Accent()
  return T.GOLD
end

-- The button: a dark slot with a bronze border, as the other Tylesser addons' buttons.
function C.Look(button)
  local fill = button:CreateTexture(nil, "BACKGROUND")
  fill:SetAllPoints()
  fill:SetColorTexture(0.06, 0.05, 0.07, 0.9)
  T.Outline(button, 0, T.BRONZE, 1)
  local hover = button:CreateTexture(nil, "HIGHLIGHT")
  hover:SetPoint("TOPLEFT", 2, -2)
  hover:SetPoint("BOTTOMRIGHT", -2, 2)
  hover:SetColorTexture(T.GOLD[1], T.GOLD[2], T.GOLD[3], 0.2)
  button.label:SetTextColor(T.GOLD[1], T.GOLD[2], T.GOLD[3])
end

function C.OpenOptions()
  if ns.OpenOptions then
    ns.OpenOptions()
  end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
  C.Start()
end)
