# Widescreen Grid Box

Current build: **0.1.0-alpha.1**

Widescreen Grid Box replaces Bill's list-based Pokemon storage actions with
semantic 5x4 Box navigation, a six-slot Party drawer, and atomic Move Pokemon
operations. Gen1 Widescreen UI owns every rendered pixel and input hit region;
this mod owns storage navigation and mutations only.

## Requirements

- Gen1Recomp `>=0.1.83 <0.2.0`, Red/Blue/Yellow only.
- Gen1 Widescreen UI `>=0.1.0-alpha.14.31 <0.2.0`.
- Conflicts with Advanced Box System because both replace Bill's PC storage.

## Behavior

- Root order: Withdraw, Deposit, Move Pokemon, Change Box, Yellow Print Box,
  See Ya. Release is absent.
- Browsing any of 12 Boxes never changes the active capture Box.
- Boxes remain dense native arrays with 20-Pokemon capacity; no shadow save or
  sparse layout is created.
- Pickup is non-mutating. Placement validates current identity and commits a
  transfer, reorder, or swap atomically.
- A boxed Pokemon receives native `Stats.ensure` only when entering the party.
- Yellow's sleeping-starter restriction and deposited-Pikachu happiness path
  are preserved.
- CHANGE BOX and PRINT BOX reuse the engine's native callbacks.

## Current integration limitation

Widescreen UI alpha 14.31 publishes Storage Provider API v1, but its renderer
does not yet draw the validated ACTIVE box state, a PARTY button, target-state
distinctions, species/gender detail, or disabled reasons. The semantic snapshot
already supplies these values where the v1 schema permits. Final visual audit
and release acceptance wait for the Widescreen owner to complete that generic
presenter surface; this mod does not patch Widescreen internals.

No Pokemon artwork or Advanced Box System source/assets are included.
