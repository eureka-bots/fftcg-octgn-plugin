# Repository Guidance

- When editing card data under `sets/`, read [CARD_DATA_MAPPING.md](CARD_DATA_MAPPING.md) first. Treat it as the implementation-oriented guide for mapping `Abilities` to `AbilitiesContainer`.
- Verify proposed mappings against the relevant script handlers and existing card data; do not infer support from printed text or copy an unverified pattern.
- After set XML changes, validate the XML and run `.\tools\Build.ps1 -ValidateOnly`.

## Authorized Card-Image Sourcing

- For standard numbered cards, the full card code is the `SetNumber` plus a rarity suffix. The XML `SetNumber` omits this suffix; observed mappings are Common `C`, Rare `R`, Hero `H`, Legend `L`, and Starter `S`. Verify any new rarity against a known source URL before bulk downloads. Promo numbers such as `PR-008` already form their code and do not use this suffix.
- Japanese numbered-set images use `https://www.square-enix-shop.com/jp/ff-tcg/card/cimg/large/opus{set-number}/{card-code}.png`; promos use `https://www.square-enix-shop.com/jp/ff-tcg/card/cimg/large/pr/{promo-code}.png`. Promo exceptions may use an original card code under `/pr/` (for example, `1-027H`) or a variant suffix (for example, `PR-079_n.png`); verify each exception rather than assuming a universal fallback.
- English images use `https://fftcg.cdn.sewest.net/images/cards/full/{card-code}_eg.jpg`. For authorized downloads, validate the downloaded JPEG, convert it to PNG, and save it under the card UUID in `sets/<set-name>/Cards/en/`. Save Japanese PNGs under the UUID in `Cards/ja/`.
- Before a bulk download, verify representative URLs and map each `SetNumber` and rarity to the card UUID from `set.xml`. Preserve UUID filenames, check for existing files, and report unavailable URLs instead of silently omitting cards.
- After adding English PNGs for a set, run `.\tools\Round-CardImages.ps1 -SetNames '<set-directory>'` before building the image pack. It uses the tracked alpha-only mask at `tools/assets/english-card-alpha-mask.png`, derived from the rounded English Opus III reference. It preserves RGB and dimensions, stages and validates the full update before replacing files, and stops if image dimensions differ from the mask.
