# Card Data Mapping Guide

This guide is the implementation-oriented reference for mapping printed card text in `Abilities` to automation metadata in `AbilitiesContainer`. It is intended for human authors and AI-assisted card-data work.

## Authority and safety rules

1. Treat the printed `Abilities` text as the source of truth for what the card does. Treat `AbilitiesContainer` as a request to existing OCTGN script handlers, not as a second copy of the rules text.
2. Before adding an entry, inspect the relevant handler and confirm it supports the ability's trigger, timing, condition, target, amount, and duration. Use representative entries elsewhere in `sets/` only as examples; older data can be incomplete or incorrect.
3. Map each distinct ability separately. Do not infer automation for a whole card from one supported ability.
4. Prefer a partial mapping only when the handler provides that partial behavior without changing the printed effect. Otherwise leave the unsupported ability unautomated. Never make a selector broader than the printed target just to get an entry.
5. Preserve existing entries when adding new ones. Separate entries with `][`; do not add extra separators at the beginning or end.
6. Validate the edited XML and run `.\tools\Build.ps1 -ValidateOnly` after changing set data.

## Handler source map

Check these implementations before authoring mappings:

- `scripts/script_cardLogic.py`: `cardLogic_ability_find` and related ability-container parsing.
- `scripts/script_powerLogic.py`: numbered power boost parsing, recalculation, and manual toggles.
- `scripts/script_searchLogic.py`: search locations, filter fields, and comparison operations.
- `scripts/script_showRules.py`: whether power boost actions appear and the labels used in the card menu.
- `definition.xml`: card actions that invoke handlers.

Paths are relative to the game directory `285a8cdb-1d02-4edd-a9de-1ade9d5a4f43/`.

## General format

`AbilitiesContainer` is a string containing one or more handler-specific entries. Most entries have their own format; there is no universal field layout. The `][` sequence separates entries. Preserve the format and ordering of existing entries on the card.

Card identity and property conventions that affect data generation:

- Keep `Abilities`, `SpecialAbilities`, `AbilitiesContainer`, and `EXBurst` consistent. Preserve OCTGN markup in rich-text properties.
- For a Limit Break card, append ` (LB)` to its imported card name, include `LimitBreak|<cost>`, and include `AlternateName|<base name>` in the container.
- `EXBurst` is `TRUE` or `FALSE` based on the printed card. It is not conditional on whether the effect has automation.

## Supported mappings

### Search helpers

`SearchForCard1`, `SearchForCard2`, and `SearchForCard3` expose a search/selection helper. The structure is:

`SearchForCardN|<menu label>|<Player or Opponent>_<location>_<filter expression>`

Examples of locations include `Deck` and `BreakZone`. A filter expression is one or more `field,operation,value` clauses joined with `AND`; for example:

`SearchForCard1|Search your Break Zone for a Forward of cost 2 or less|Player_BreakZone_Type,Is,ForwardANDCP,LessThanOrEqualTo,2`

The helper presents matching cards. It does not by itself add a card to hand, play it, or complete another movement described by the printed ability. Use a separate handler only if its implementation performs that action.

The filter fields and operations are defined by `script_searchLogic.py`; they are not arbitrary. Before using a field or operation, verify that the `searchLogic_factor_*` implementation supports it. In particular, check whether a condition uses printed power or current total power; these are different tests.

### Reveal helpers

`RevealCards1` and `RevealCards2` expose the top cards and optionally highlight cards matching filters:

`RevealCardsN|Quantity|<count>|<filter expression>`

Use `N/A` when the ability does not distinguish a subset of the revealed cards for highlighting. Add filters only to visually mark revealed cards that match the filter; highlighting does not select those cards or move them. A reveal helper does not resolve the subsequent choice, movement, play, or return-to-bottom steps unless a separate handler explicitly implements them.

### Named Special actions

For each named action exposed in `SpecialAbilities`, add the corresponding `SpecialAbility1`, `SpecialAbility2`, or `SpecialAbility3` entry in the same order. Keep the name and cost consistent with the displayed action. This exposes the clickable action; it does not automatically resolve its effect.

### Priming

The Priming mechanic has dedicated handlers; inspect `cardLogic_prime_dominant` and the play-cost logic before mapping it.

- A card that can Prime into an Eikon uses `Prime_Dominant|<Eikon name>|<CP vector>`. The vector has nine slash-separated values: Fire, Ice, Wind, Earth, Lightning, Water, Light, Dark, then generic CP. For example, `Prime_Dominant|Ifrit (XVI)|1/0/0/0/0/0/0/0/1` means 1 Fire CP and 1 generic CP.
- A Priming target Eikon uses `Prime_Eikon|N/A`. The Prime action on the Dominant performs the cost check, target selection, and zone/card replacement; `Prime_Eikon` identifies the related Eikon for menus and replacement handling.
- `Primecast|AoE|<search expression>` lets a matching active card's effect bypass the colored-CP requirement while Priming. The filter is evaluated against the Dominant being primed, so it must match only the Dominants covered by the printed effect. For example, Torgal's `Primecast|AoE|Player_CardToPlay_Type,Is,ForwardANDOnlyJobs,In,Eikon/Dominant` restricts the effect to Eikon and Dominant Forwards.
- A rule that Priming costs can be paid with CP of any Element is a `Primecast` mapping, not a `Swiftcast` mapping. `Swiftcast` handles ordinary casting costs; use it only if the printed rule also changes those costs.
- `Prime_Dominant` stores a fixed cost vector. It does not represent a conditional alternate or reduced Priming cost; do not assume the ordinary `CostReduction` handler changes Prime costs.
- These entries do not automate separate triggered abilities that happen when a card is priming or when it Primes into an Eikon. Add their other mappings only if a separate handler implements the trigger and effect.

### Power changes

Numbered power boost entries use this structure:

`PowerBoost_<1st|2nd|3rd>|<Auto|Manual>|<state>|<condition>|<target>|<amount>|<multiplier>|<menu description>`

Use only a numbered slot that is available on the card and supported by the Power menu.

- `Auto|ACTIVE` is for supported modifiers whose applicability can be determined from current game state. On power recalculation, the handler rechecks the condition, finds the target cards, and applies the amount; it does not detect event triggers such as “When this Forward attacks.” Use `Manual|OFF` for a supported triggered boost that needs a player action. `DISABLED` turns an auto entry off.
- `Manual|OFF` exposes a Power-menu toggle for a player-triggered effect. Activating it sets the entry to `ON`; it applies the configured amount to its target. The handler does not detect the printed trigger or track an “until end of turn” duration. The players must activate it when appropriate and deactivate it when the effect expires.
- The condition is either `N/A` or a search expression, such as `Player_Table_Name,Is,Serah`. The target is `ThisCard` or a search expression, such as `Player_Table_TypeContainer,Is,Forward`.
- `Single` applies the configured amount once to each selected target. `Size` multiplies the amount by the number of cards matched by the condition. `SizePer_<N>` multiplies it by the integer number of complete groups of N matched cards. `Counter_<marker name>` multiplies it by the total number of the named marker on the targets. Confirm multiplier behavior in the handler before using it.
- The target selector returns every matching card. It does not represent a player choosing exactly one card. Do not encode “choose 1” effects using a group selector.
- Auto boosts are recalculated by `powerLogic_powerBoost_calculate`; only active cards and Forwards in the handler's supported control context are processed. Do not assume every card zone, owner, or timing is supported.
- Manual boosts modify the handler's permanent-power component; auto boosts are added through its recalculated temporary-power component. “Permanent” here describes internal bookkeeping, not the card effect's rules duration: manual toggles do not expire themselves, so the player must turn them off when a temporary effect ends. Avoid manual mappings when their toggle/reversal behavior cannot safely represent the printed effect.
- A boost entry handles power only. It does not implement other text on the card, such as Brave, Haste, damage, choosing a target, or triggering an attack ability.

Examples:

```text
PowerBoost_1st|Auto|ACTIVE|Player_Table_Name,Is,Serah|ThisCard|2000|Single|Noel gains +2000 power
PowerBoost_1st|Auto|ACTIVE|N/A|Player_Table_TypeContainer,Is,Forward|1000|Single|Forwards gain +1000 power
PowerBoost_1st|Manual|OFF|N/A|ThisCard|4000|Single|Garland gains +4000 power
```

The first entry models a conditionally boosted source card. The second models a group aura and targets every matching Forward. The third is a manual toggle example; it does not automatically know when Garland attacks or when the turn ends.

### Hand-only discard abilities

`DiscardAbility|N/A` exposes the “Discard to Use Ability” action for a card in hand. It runs the card through the play/cast flow in discard-ability mode and moves it to the Break Zone; it does not resolve the printed effect or model additional costs, targets, or a different destination. Treat it as a discard/action shortcut, not as general automation for hand-only abilities. Do not use it when the card's printed cost or destination differs from this behavior.

### Other implemented handler families

These keys are also used by numbered sets. They are specialized data consumed by existing game logic, not general-purpose effect descriptions. Confirm the exact code path before using a key; many handle only a particular timing or cost pattern.

| Keys | What the handler supports | Important limit |
|---|---|---|
| `ActivateCards1`, `ActivateCards2` | Activate every card matching the supplied table filter. | Does not ask the player to choose a subset. The selector must match only the printed targets. |
| `CountCards1` | Display the number of cards matching a selector. | Reports a count; it does not use that count to resolve another effect. |
| `CostReduction`, `CheaperOnMyTurn` | Apply supported self or field-wide casting-cost reductions, including conditions the cost logic can evaluate. | Does not cover arbitrary event-driven or temporary reductions. `CheaperOnMyTurn` is a fixed own-turn reduction. |
| `Swiftcast`, `FourLords` | Permit a card to pass a supported colored-CP requirement. | These do not pay CP, reduce the numeric cost, or provide general “cast at any time” behavior. |
| `PayWithCrystal`, `PaidWithCrystalColorless` | Offer a Crystal as an alternative cost reduction when casting a card and apply the associated colorless-payment rule. | Not a general Crystal payment for activated abilities. |
| `AutoGainCrystal` | Automatically gain Crystal for implemented trigger patterns, such as supported play, EX Burst, phase, or matching-card events. | Only triggers explicitly handled in the script work; do not infer support for an arbitrary “when” condition. |
| `Counter`, `AutoCounter`, `IncrementCounter` | Track a named marker in response to supported card-play events; `AutoCounter` can derive the amount from a supported selector or quantity, and `IncrementCounter` adjusts its increment. | Does not implement arbitrary counter triggers or what an ability later does when counters are spent. |
| `StartOfTurnCounter`, `EndOfTurnCounter` | Add a configured marker at the beginning of a turn or at turn end, to this card or cards matching a selector. | These implement only the phase-based counter placement described by their fields. |
| `CanDullForElement`, `CanDullCopyElement`, `BackupsCanDullForAnyElement`, `BackupsCanDullForMoreElements` | Change which CP elements a Backup can produce when dulled. | Use the supported comma-separated element values and selectors; these do not automate unrelated abilities on that Backup. |
| `InnerStrength`, `Beastmaster` | Supply power when a supported effect turns a card into a Forward; `Beastmaster` applies to matching cards. | They do not themselves turn a card into a Forward or implement the trigger that does so. |
| `Warp`, `Rewarp` | Expose the Warp/Rewarp action and its supported delayed return flow. | Use the cost-vector and state conventions in existing entries; this is not a generic delayed-effect handler. |
| `Vanish` | Track a card's temporary disappearance and return it after the configured count. | Only the implemented counter/timing behavior is automatic. |
| `DoesNotActivate` | Prevent a card from activating during the normal turn-ready step. | Does not prevent activation caused by other effects. |
| `BecomesElementOnPlay` | Add the configured element when a card is played. | Only models that element change; other entry effects need separate support. |
| `CanSwap` | Expose the card-swap action. | Does not resolve unrelated abilities printed on the card. |
| `GlobalSpecial` | Let a matching card use another card's Special action, with supported Crystal or hand-discard costs. | The Special effect still follows the normal Special-action behavior; this is not a general hand-ability handler. |
| `AllowFloodOfLight`, `AllowFloodOfDark`, `CauseFloodOfLight`, `CauseFloodOfDark` | Handle exceptions to the Light/Dark character restrictions. | These are game-rule flags, not effect resolvers. |
| `LimitBreak`, `AlternateName` | Apply Limit Break cost/action behavior and treat an alternate name as equivalent for the game's name check. | Keep the printed card name and the `AlternateName` value consistent; see the Limit Break convention above. |
| `BannedInFormat` | Exclude a card in the configured deck format. | This is deck/format validation metadata, not an in-game ability. |

`SpecialAbility1`–`SpecialAbility3` expose the named action and process their supported CP, dull, and discard costs; they do not resolve the printed Special effect. `SearchForCard1`–`SearchForCard3` and `RevealCards1`–`RevealCards2` are described above. `Prime_Dominant`, `Prime_Eikon`, `Primecast`, and `PowerBoost_1st`, `PowerBoost_2nd`, and `PowerBoost_3rd` are described in their dedicated sections.

## Leave unsupported effects unmapped

Do not invent an entry when an ability needs behavior the handlers do not provide. Examples include:

- Selecting exactly one target when the available selector applies to every match.
- Automatically reacting to an event when no handler observes that event.
- Applying a temporary effect with a duration the handler cannot track.
- Resolving a multi-step effect (choose, deal damage, break, move, or play a card) when available helpers only expose a search or toggle.
- Mapping a power boost whose condition, target, timing, or magnitude cannot be represented without changing the printed effect.

Record unsupported rules in `Abilities` as printed; do not make a misleading container entry to suggest that they are automated.
