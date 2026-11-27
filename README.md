# Tylesser - Trade Crier

A World of Warcraft addon for **WoW Forever** that keeps your **crafting ads in Trade chat**. Write your messages once
with your **profession links**, and while you are in a city with Trade chat each message's button by your character
**lights up when it is ready**: one click posts it. It is also a module of [Tylesser - Codex](https://tylesser.com/codex/).

## Features

- **Your messages with your profession links** (up to 8 per character): `<Tailoring>` becomes your Tailoring link when it is posted,
  `<professions>` all of them, so other players can click it and see every recipe you know. Buttons on the options
  page put them in for you, and Shift-clicking an item or a recipe puts its link in too.
- **Each message has its own time** in seconds (30 at least, 600 for a new one): it goes out again only once that
  time has passed.
- **A button per message**, with its own icon, countdown and glow: click the one you want to post. The post key posts
  the one that has waited longest. Side by side or in a column; drag any of them to move them all. A sound or a
  chat line when one is ready, if you like. Untick a message to keep it without posting it. Posts go to
  **Trade** or **Trade (Services)**.
- **An icon per message**: until you pick one, a message takes the icon of the profession it links (`<Tailoring>` = Tailoring's).
  The picker also has the capitals' teleport icons.
- **Where and when**, if you like: the button next to a message's icon picks the city it is for, the channel it goes to (Trade or Trade (Services)) and the time of day (mornings, afternoons, evenings or nights). Its button shows only then.
- **One click posts it.** The game only sends a Trade chat message when you click or press a key, so the addon never
  posts on its own: click the button, press the key you picked, or type `/crier post`.
- **Only where it makes sense**: the button shows in the capital cities (where Trade chat is), and you can pause it
  per character.
- Shows how long each message is with its links (the game takes 255 letters) and what it will look like in chat.

## Usage

- `/crier`, or Esc > Options > AddOns > **Tylesser** > Open Tylesser settings. The options open in Tylesser's own settings window.
- Click a message's button to post it, right-click for the options, Shift-right-click to pause, drag to move the buttons.
- `/crier post` posts the message that has waited longest, `/crier pause` / `/crier resume`, `/crier status`, `/crier reset` puts the buttons back.

Please keep to your realm's Trade chat rules: a post every few minutes is plenty, so keep the times long.

Languages: English, German, French, Spanish (Spain and Mexico), Russian and Brazilian Portuguese, following your game client.

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
