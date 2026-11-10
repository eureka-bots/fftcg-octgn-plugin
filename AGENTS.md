# Repository Guidance

- When editing card data under `sets/`, read [CARD_DATA_MAPPING.md](CARD_DATA_MAPPING.md) first. Treat it as the implementation-oriented guide for mapping `Abilities` to `AbilitiesContainer`.
- Verify proposed mappings against the relevant script handlers and existing card data; do not infer support from printed text or copy an unverified pattern.
- After set XML changes, validate the XML and run `.\tools\Build.ps1 -ValidateOnly`.
