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
- `Options.lua`: the options page (T kit) and `/crier`.
- Test: `node tools/harness/run.js tc_test.lua E:/Games/Wow/Addons/TradeCrier` (from tools/harness).
- GitHub Tylesser/TradeCrier, CurseForge 1831458, Wago BKpEyRGE (slug tylesser-trade-crier), all made 2026-11-26.
