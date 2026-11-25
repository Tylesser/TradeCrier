# Tylesser - Trade Crier

A World of Warcraft addon for **WoW Forever** that keeps your **crafting ad in Trade chat**. Write your message once
with your **profession links**, and while you are in a city with Trade chat a button by your character **lights up
every few minutes**: one click posts it. It is also a module of [Tylesser - Codex](https://tylesser.com/codex/).

## Features

- **Your message with your profession links**: `<Tailoring>` becomes your Tailoring link when it is posted,
  `<professions>` all of them, so other players can click it and see every recipe you know. Buttons on the options
  page put them in for you, and Shift-clicking an item or a recipe puts its link in too.
- **A post every few minutes** (3 to 60, 10 by default) in **Trade** or **Trade (Services)**: the button shows the
  time left and glows when it's time, and can play a sound or say so in chat.
- **One click posts it.** The game only sends a Trade chat message when you click or press a key, so the addon never
  posts on its own: click the button, press the key you picked, or type `/crier post`.
- **Only where it makes sense**: the button shows in the capital cities (where Trade chat is), and you can pause it
  per character.
- Shows how long the message is with its links (the game takes 255 letters) and what it will look like in chat.

## Usage

- Esc > Options > AddOns > **Tylesser - Trade Crier**, or `/crier`.
- Click the button to post, right-click for the options, Shift-right-click to pause, drag to move it.
- `/crier post` posts now, `/crier pause` / `/crier resume`, `/crier status`, `/crier reset` puts the button back.

Please keep to your realm's Trade chat rules: a post every few minutes is plenty.

## Feedback

Found a bug or have an idea? Click **Feedback** on the options page or type `/crier feedback` in game to get the
link, or go straight to [tylesser.com/feedback](https://tylesser.com/feedback/#tradecrier).

No GitHub account? Join the [Tylesser Discord](https://discord.gg/n2rEB6mRxF) and post in #bug-reports or #ideas with the addon's tag; each post is copied to GitHub and the bot answers with the link.

## Installation

Install from CurseForge or Wago, or download the latest zip from [Releases](https://github.com/Tylesser/TradeCrier/releases) and extract it to `Interface/AddOns`. The folder must be named `TradeCrier`.

## Releasing (maintainers)

Releases are built by [BigWigsMods/packager](https://github.com/BigWigsMods/packager). Push a version tag to publish to GitHub Releases, CurseForge and Wago Addons:

```
git tag v1.0.0
git push origin v1.0.0
```

## License

[MIT](LICENSE)
