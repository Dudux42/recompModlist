# Gen1 Widescreen UI — structured Bag machine-detail request

Requested by: `gen1_widescreen_modern_bag`  
Date: 2026-08-12  
Current presenter baseline: `gen1_widescreen_ui 0.1.0-alpha.14.24`, Bag
Provider API v2.

## Ownership boundary

This is a request for the Gen1 Widescreen UI owner. Modern Bag must not patch,
draw over, or release a modified Widescreen UI. Widescreen owns Bag drawing,
fonts, type badges, validation and responsive layout. Modern Bag owns machine
semantics and supplies values resolved from live game data.

## Requested presentation

For a selected TM or HM, render the right panel as one parameter per line:

- **MOVE:** regular move name
- **TYPE:** colored type badge
- **CATEGORY:** regular Physical, Special or Status value
- **POWER:** regular number, or `--` for Status moves
- **ACCURACY:** regular percentage, or `Varies`
- **PP:** regular number
- **DESCRIPTION:** regular plain-language explanation of what the move does

Labels must appear bold; values must use regular weight. Do not display damage
formulas, internal effect IDs or unexplained engine terminology.

### Multiline description follow-up (2026-08-12)

The first alpha 14.25 presentation fits every value to one line, causing long
move descriptions such as Bide to end in `..`. The provider already supplies
the complete sentence. Widescreen should treat the `DESCRIPTION` parameter as
multiline content:

- Keep MOVE, TYPE, CATEGORY, POWER, ACCURACY and PP on one line each.
- Draw the bold `DESCRIPTION:` label once.
- Word-wrap its regular-weight value across the remaining panel width and
  vertical space using measured font widths.
- Continuation lines may begin at the panel's normal left edge beneath the
  label, maximizing readable width.
- Do not flatten embedded line breaks or pass this value through a one-line
  ellipsis helper.
- Bound drawing to the right panel. If an unknown third-party description is
  still too long, clip only after all available description lines are used.

No new provider data or gameplay lookup is required for this follow-up.

## Proposed optional API v2 row model

```lua
detail = {
  kind = "machine",
  typeId = "NORMAL",
  parameters = {
    { label="MOVE", value="Mega Punch" },
    { label="CATEGORY", value="Physical" },
    { label="POWER", value="80" },
    { label="ACCURACY", value="85%" },
    { label="PP", value="20" },
    { label="DESCRIPTION", value="The user delivers a powerful punch." },
  },
}
```

The exact schema is the Widescreen owner's decision. It should be optional so
existing API v2 providers remain valid. Validate bounded string fields and
keep invalid provider snapshots opaque under the existing failure contract.

## Acceptance criteria

1. Ordinary item descriptions remain unchanged.
2. TM/HM parameters render on separate lines without clipping at 640x360.
   DESCRIPTION word-wraps over multiple lines and uses the remaining vertical
   space; Bide's complete supplied sentence is visible without `..`.
3. Parameter labels are visibly bold and values visibly regular.
4. The move type uses Widescreen's existing colored type-badge helper.
5. Provider values remain authoritative; Widescreen performs no move lookup or
   gameplay calculation.
6. Controller, pointer, modal focus and native-layer suppression regressions
   continue to pass.
7. The contract document states the new dependency floor that consumers must
   declare before they emit this model.
