# Tylesser - Trade Crier

A message with the character's profession links in Trade chat, again every few minutes while in a city (started
2026-11-26, the user's request). **WoW Forever only** (Interface 16001), like Codex. Workspace conventions in
`E:/Games/Wow/CLAUDE.md`.

- **Crier.lua is Codex's `Modules/Crier/Crier.lua`, byte for byte** (`tc_test.lua` checks). Change it in one and
  copy it to the other. It reads its host from `ns.crier` (C): `DB`, `CharDB`, `Say`, `BUTTON_NAME`, `Look`,
  `Accent`, `OpenOptions`, `COMMAND`, `BRAND`, optional `OnRefresh(state)`. Here `Host.lua` (TradeCrierDB account,
  TradeCrierCharDB per character, start at PLAYER_LOGIN); in Codex `Modules/Crier/Module.lua`.
- **Never post from a timer.** `SendChatMessage` to a channel needs a hardware event (Forever's docs: HasRestrictions;
  the rule since 8.2.5). The post button's OnClick, its override binding (`SetOverrideBindingClick` to
  `C.BUTTON_NAME`, out of combat) and `/crier post` (the Enter key) are the only senders. The user agreed to this
  design (button + key) on 2026-11-26.
- Channels by zone channel ID (Forever's ChatChannels DB2 on wago.tools): 2 Trade, 42 Trade (Services); matched among
  `GetChannelList()` entries with `C_ChatInfo.GetChannelInfoFromIdentifier(name).zoneChannelID`, the shortcut name as
  a fallback. Profession links: `C_SpellBook.GetSpellBookItemTradeSkillLink(spellOffset + i, Player)` (as
  Blizzard_ProfessionsBook). `<Name>` / `<professions>` codes (also `{Name}`; the game's Friz Quadrata draws { } like a link's [ ], seen in the bench) expand at post time; 255 letters max after expansion.
- Messages (2026-11-26): up to 8 per character, each with its own seconds (30 at least), on/off and icon (picked, or
  the first profession it links). A button per message (`TradeCrierButton`, `..2`, ...) in the bar
  `TradeCrierButtonBar`; the key clicks `TradeCrierButtonKey`, which posts `C.NextMessage()`. 1.0's single `message` + `interval` minutes move
  into the list on first use. Details in Codex's CLAUDE.md (Modules/Crier).
- Cities (2026-11-27, GitHub issue #1): `message.city` = an area ID from `C.CITIES` (the six AreaTable rows flagged
  as capitals on Forever: 1519 Stormwind, 1537 Ironforge, 1657 Darnassus, 1637 Orgrimmar, 1638 Thunder Bluff, 1497
  Undercity; names from `C_Map.GetAreaInfo`, English as fallback) or a zone name (a city with Trade chat not in the
  list, offered while you are there); compared with `GetRealZoneText()` (never when secret). Another city's message
  is "elsewhere": no button, skipped by `C.NextMessage`, `C.Post(i)` refuses it; only those = state "elsewhere".
  `C.ShowCityPicker` / `C.CityButton` / `C.PaintCityButton` live in Crier.lua so both hosts' rows share them. The
  teleport icons (SpellMisc of Teleport: <city>, files checked in Forever's list) are also icon choices.
- Channel and hours per message (2026-11-27): `message.channel` (C.CHANNELS key, nil = the account's; `C.MessageChannel`,
  used by Post / State / tooltips) and `message.hours = { from, to }` (local hours, `to` excluded, from > to past
  midnight; `C.Hour`, `C.InItsHours`, state "later"). The city button's list is `C.WhereWhenChoices` (headings City /
  Channel / Time of day, `C.HOURS` presets) and stays open on a pick. Messages are per character already, so there is
  no character condition.
- Buyers in Trade chat (2026-11-28, the user's request): **CrierWatch.lua is Codex's `Modules/Crier/CrierWatch.lua`,
  byte for byte**, loaded after Crier.lua (CrierLocales.lua holds its texts, also shared). `C.StartWatch` (from
  `C.Start`) listens to CHAT_MSG_CHANNEL (zoneChannelID 2/42, 1/26 with `watchMore`; text, sender and guid may be
  secret in chat messaging lockdown: skipped) and learns `C.Char().products[itemID] = professionID` from the own
  profession window (TRADE_SKILL_SHOW / LIST_UPDATE, C_TradeSkillUI like Codex Professions; classic API fallback;
  max 2000). `C.MatchRequest`: a request word (`settings.requestWords`, nil = the translated default) and an item
  link / keyword / profession stem / item name; adverts (|Htrade:, wts, lfw) skipped. Rows in `C.Char().requests`
  (20, an hour, one per sender per 5 min); `C.ShowRequests` (window from `C.PickerPanel`), `/crier requests`.
  `C.Whisper` = `ChatFrameUtil.SendTellWithMessage` (opens the box only, never sends). Settings `watch` (off),
  `watchMore`, `watchSound`, `watchChat`, `keywords`, `requestWords`, `reply` in the account DB. Both hosts' option
  pages build the part from `C.WATCH_CHECKS` / `C.WATCH_BOXES`.
- `Options.lua`: the options page (T kit, in a scroll frame since the message list grows) and `/crier`.
- Test: `node tools/harness/run.js tc_test.lua E:/Games/Wow/Addons/TradeCrier` (from tools/harness).
- GitHub Tylesser/TradeCrier, CurseForge 1831458, Wago BKpEyRGE (slug tylesser-trade-crier), all made 2026-11-26.
