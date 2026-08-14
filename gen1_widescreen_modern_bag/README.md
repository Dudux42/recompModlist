# Widescreen Modern Bag

Current development version: **0.1.0-alpha.5**.

Widescreen Modern Bag is a six-pocket, icon-driven Bag presented exclusively
by Gen1 Widescreen UI. It deliberately does not reproduce Modern Bag's
Favorites, pins, search, machine filters, or automatic sorting.

## Dependency

Requires `gen1_widescreen_ui >= 0.1.0-alpha.14.25 <0.2.0` and Bag Provider API
v2. If that runtime contract is unavailable, this mod does not patch
`BagMenu`.

## Pockets

1. Medicine
2. Poke Balls
3. TM / HM
4. Battle Items
5. Key Items
6. Items

Medicine opens by default. Left and Right change pockets with wraparound, and
each pocket remembers its cursor and scroll position for the current Bag
session. Unknown inventory items safely enter Items unless live metadata or a
registered override gives them a more specific pocket.

## Controls and ordering

- **A** uses the engine-owned field/battle item action.
- **B** returns.
- **Left/Right** changes pocket.
- **SELECT** marks an item for movement; move to another row and press SELECT
  again to swap the two items exactly like the vanilla Bag. The engine's Bag
  order table is changed, so the result persists normally.
- **START** explicitly applies the next sort to the current pocket:
  Alphabetical, Type, then Quantity. Nothing is sorted automatically when the
  Bag opens, when a quantity changes, or when an item is acquired.

Type sorting uses plain pocket-specific groups. Medicine uses HP recovery,
status recovery, revival, PP recovery, vitamins, and level items. Quantity
sorts highest first with alphabetical ties.

TM/HM is intentionally fixed: HMs appear first by number, followed by TMs by
number. START sorting and manual movement are disabled in that pocket.

## Information panel

Every selected item supplies a plain-language description, quantity, pocket,
and icon to Widescreen's right panel. TM/HM details include the taught move,
type, Physical/Special/Status class, power when relevant, accuracy, PP, and a
plain explanation of what the move does. Machine parameters appear one per
line with bold labels,
regular values and a colored type badge through the Widescreen-owner extension
in alpha 14.25. They do not display damage formulas or internal effect IDs.
Every supported item and Poke Ball has a dedicated concise description; the
generic fallback is reserved for unknown third-party items.

The 55 Gen 1 TM/HM move explanations use original concise wording based on
the [Pokemon Database Generation I move index](https://pokemondb.net/move/generation/1)
and its individual move pages, with Generation I-specific behavior retained.

Only Battle Items receive contextual availability text. Outside battle they
are labeled battle-only. During battle the panel explains that the item is in
the correct context while leaving the final legality/effect check to the
engine.

## Inventory and compatibility

Distinct-item capacity is expanded to a large finite value. Valid stacks may
grow beyond 99 up to a serialization-safe finite integer. Invalid IDs,
fractional/non-positive quantities, malformed state, and unusual calls
delegate to the engine's original `Bag.add` implementation.

Field and battle item use, targeting, teaching, throwing, tossing, evolution,
consumption, and external gameplay restrictions remain engine- or gameplay-
mod-owned. This mod conflicts with `modern_bag`.

## Item icons

The package contains 70 dedicated individual item icons plus shared TM and HM
icons, all deterministic 32x32 RGBA builds from the user-supplied strips.
Unknown third-party items receive Widescreen's visible category fallback.
`item_icons.lua` exposes resolver, coverage-audit, and cache-invalidation APIs.

See `ASSET_PROVENANCE.md`. Upstream authorship and redistribution permission
for the supplied art still require confirmation before public distribution.

Bag Provider API v2 displays and validates the provider-owned selected row in
item-action and confirmation modals. Controller and pointer selection use the
same semantic action path.

No build is installed automatically. The user imports any delivered flat ZIP
through the launcher.
