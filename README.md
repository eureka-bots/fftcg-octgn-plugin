# Final Fantasy TCG for OCTGN

Play Final Fantasy TCG online using OCTGN. The game plugin and card image packs are separate downloads; install both to play with card images.

- 日本語プレイヤーガイド: [README.ja.md](README.ja.md)
- Plugin development and contribution guide: [DEVELOPMENT.md](docs/DEVELOPMENT.md)
- OCTGN: [octgn.net](https://www.octgn.net/)

## Download and Install

### Game plugin

In OCTGN, open **Games Manager**, find **Final Fantasy TCG** in the available games, and click **Install**. Wait for installation to finish.

### Card image pack

Download the English (`en`) image pack from the [distribution folder](https://drive.google.com/drive/u/0/folders/1-iuTjSH1AWa7XC_9IeIV9d697vBoAuYd). For Japanese cards, see the [Japanese guide](README.ja.md).

In OCTGN's **Games Manager**, click **Add Image Packs**, select the `.o8c` file, and wait for installation to finish. Do not extract the archive.

## Quick Start: Playing a Game

This guide covers OCTGN controls, not the FFTCG rules.

1. Create or join a **Final Fantasy TCG** game in OCTGN and load your deck.
2. At the table, each player presses **Tab** (or selects **Game... > Go to Next Phase**) and chooses the deck format. Once both players are ready, OCTGN announces a die roll to determine who goes first.
3. The first player presses **Tab** again and chooses **Yes** when asked if they are going first.
4. Draw your opening hand using **Deck > Draw... > Draw 5 Cards/Mulligan** (or **F12**). Press it again to mulligan and draw five new cards.
5. Once both players have finished drawing or mulliganing, the first player presses **Tab** again to begin the first turn.

### Turns and Common Actions

- The active player advances phases with **Tab**: **Active Phase** (your cards ready), **Draw Phase**, **Main Phase 1**, **Attack Phase**, **Main Phase 2**, then **End Phase**. The first player's first Draw Phase draws one card; later Draw Phases draw two automatically. After End Phase, press **Tab** again to pass the turn. You cannot end your turn with more than five cards in hand.
- Right-click a card to open its actions. From your hand, use **Play or Cast** to play a card. To generate CP, use **Discard (and gain CP)** on a hand card (two CP of its element), or **Dull and Gain CP** on a Backup (one CP of an available element).
- Use **Dull/Activate** to track a Forward, Backup, or Monster's state. For battle markers, right-click a Forward and choose **Battle... > Attack**, **Party Attack**, or **Defend**. These actions mark and announce the battle action; they do not automatically dull cards or resolve every battle step.
- To take damage, use **Deck > Take Damage**. It moves the top card of your deck to the Damage Zone and notifies you if that card has EX Burst; resolve its effect according to the card text.
- Some card effects are automated or prompted by the game, but not every printed ability resolves automatically. Follow the card text and resolve any remaining effects manually.

### Hotkeys

Hotkeys are strongly recommended to keep games moving and reduce menu navigation. Start with **Tab**, **F12**, **Ctrl+X**, and **Alt+A / Alt+P / Alt+D** for common turn and battle actions. Card and deck shortcuts are contextual; use them when the relevant card or group is the action target.

| Key | Action |
|---|---|
| **Tab** | Go to the next phase |
| **F1**–**F6** | Jump directly to a phase: F1 Active, F2 Draw, F3 Main 1, F4 Attack, F5 Main 2, F6 End |
| **F7** | Pass control to opponent |
| **Alt+X** | Roll D6 |
| **Ctrl+R** | Declare Reaction |
| **Alt+A** / **Alt+P** / **Alt+D** | Attack / Party Attack / Defend |
| **Ctrl+X** | Discard a hand card and gain 2 CP of its element |
| **Ctrl+1** / **Ctrl+2** | Add / subtract 1000 damage from the selected Forward |
| **Ctrl+Q** / **Ctrl+W** | Add / subtract 1000 power from the selected Forward |
| **Alt+Q** | Declare Ability |
| **Alt+S** | Remove Highlights |
| **Alt+T** | Target / untarget the selected card |
| **Alt+C** | On the table: Calculate Power of Forwards. On a card: Add Default Counter |
| **Ctrl+C** | Remove Default Counter from the selected card |
| **Ctrl+S** | Shuffle the deck |
| **Ctrl+D** | Draw one card |
| **F12** | Draw an opening hand of five cards / mulligan |

Use **Tab** for normal turn progression. **F1**–**F6** jump directly to a phase and may skip the processing of intervening phases. **F7** passes control immediately, regardless of the current phase; normally, use **Tab** after the End Phase to pass the turn.

## Troubleshooting

- If card images are missing, install the matching language's `.o8c` file with **Add Image Packs**.
