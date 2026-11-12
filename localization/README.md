# Localization

The build supports English by default and Japanese through the `ja` catalog. Select a language when building from the repository root:

```powershell
.\tools\Build.ps1 -Language ja
```

Localization is applied to a temporary staging copy; source scripts and `definition.xml` remain unchanged. The English catalog is also used as the default reference catalog.

## What is localized

- **Game definition menus** - `definition-menu-map.json` maps source `menu` labels in `definition.xml` to catalog keys. It covers the distinct menu labels, including fallback labels for actions that use `getName`.
- **Dynamic menus** - `dynamic-label-map.json` maps markers in `script_showRules.py`. These cover play/cast choices, playmat and damage-zone toggles, boss-fight controls, reveal/prime actions, and element labels.
- **Prompts and choices** - `dynamic-prompt-map.json` maps prompt markers in `script_cardLogic.py`, including play/cast cost checks, Backup CP-or-dull choices, and Break Zone removal.
- **Displayed dynamic values** - `dynamic-value-map.json` maps deck-format and card-type names used in player-facing text. Canonical values used by game logic are preserved.
- **Player-facing messages** - `user-message-map.json` maps chat messages, prompts, and normal-use whispers in the card, game, and power scripts. Debug whispers are intentionally not translated.

Japanese card data is currently available for Sets 1–30 and 9B Promos in `sets/ja/`. The build matches records by the base `SetNumber`, localizes the card name, printed job, abilities, and Special abilities in the staged set, and retains hidden internal English names and jobs for game-logic searches. The 9B promo entries PR-086 and PR-178 reuse the Japanese data for 11-073H and 20-003H, respectively, after verifying their English names, jobs, and abilities match. Sets without a matching data file remain in English.

Card names, ability and counter names, and other values taken from card or set properties are not translated by the message and menu mappings above; they require localized set data.

## Catalogs and mappings

`en.json` and `ja.json` provide the text for stable localization keys. The JSON maps associate source strings or script markers with those keys:

- `definition-menu-map.json`
- `dynamic-label-map.json`
- `dynamic-prompt-map.json`
- `dynamic-value-map.json`
- `user-message-map.json`
- `sets/ja/<source-set-folder>.json` for Japanese card data

When adding or changing mapped content, update the relevant catalog(s) and preserve any `{}` formatting placeholders. The build stops if a required translation is missing or a required dynamic marker is absent.
