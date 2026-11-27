# Changelog

## 1.5.0

- **Clearer options page**: thin lines separate the messages, the chat preview and the channel, button and key settings.
- **Tylesser settings window**: the options now open in a window of their own with room for everything, every Tylesser addon you have listed on its left. Options > AddOns has one **Tylesser** entry that opens it.

## 1.4.0

- **In your language**: German, French, Spanish, Russian and Brazilian Portuguese game clients now show the addon in their language (other clients stay in English). Russian clients get the game's own font for headings, since the addon's fonts have no Cyrillic letters.
- **A channel and a time of day per message**: the city button's list now also picks the channel a message goes to (Trade or Trade (Services), or the one set for all) and the time of day it is for (mornings, afternoons, evenings or nights, by your clock). Outside its hours a message's button hides and the post key skips it. The list stays open, so you can set all three at once.

## 1.3.0

- **A message for one city only**: the new city button next to a message's icon picks the city it is for (or any city). Its button then shows only there, and the post key skips it elsewhere, so you can write a different message for each city you trade in.
- **City icons**: the icon picker has the six capitals' teleport icons, so a message's button can show which city it is for.
  ([#1](https://github.com/Tylesser/TradeCrier/issues/1))

## 1.2.0

- **A button per message** by your character, each with its own icon, countdown and glow. Click the one you want to post; the post key still posts the one that has waited longest. The buttons sit side by side (or in a column: "Stack the buttons in a column"), and dragging any of them moves them all.

## 1.1.0

- **Several messages** (up to 8 per character), **each with its own time in seconds** (30 at least): a message goes out again only once its time has passed, and the button posts the one that has waited longest. Untick a message to keep it without posting it. Your message and your time from 1.0 become the first message.
- **An icon per message**: click a message's icon to pick another. Until you do, it shows the profession the message links. The button shows the icon of the message that goes next.
- The options page scrolls.

## 1.0.1

- Trade Crier: no more Lua error every frame while a post is due (the button's glow).

## 1.0.0

- First version: write a message with your profession links once, and a button by your character lights up every few minutes while you are in a city with Trade chat. One click (or a key you pick, or `/crier post`) posts it.
