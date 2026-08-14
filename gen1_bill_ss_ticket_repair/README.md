# Gen1 Bill S.S. Ticket Repair

Current build: **0.1.1**

This is a narrowly scoped save repair for Gen1Recomp 0.1.78. It is separate
from Gen1 Widescreen UI because Bill's quest is gameplay state, not UI.

## What was verified

- Red, Blue and Yellow use the same `BILLS_HOUSE` ticket-award script.
- Yellow's only version-specific code in this sequence controls Pikachu's
  reactions and movement.
- Fresh 0.1.78 saves already run the correct shared sequence: Bill exits the
  machine, the human NPC becomes interactable, and talking to him awards
  `S_S_TICKET` before setting `EVENT_GOT_SS_TICKET`.
- The observed failure can survive in a save when an older or interrupted
  machine sequence sets `EVENT_USED_CELL_SEPARATOR_ON_BILL` without the
  completion callback setting `EVENT_MET_BILL_2`.

## Repair behavior

On entering Bill's House, the mod:

1. Detects an interrupted post-machine state.
2. Hides monster Bill, shows human Bill, and restores the shared completion
   flags so his normal engine-owned dialogue awards the ticket.
3. If a legacy save already says the ticket was received but the ticket is in
   neither the Bag nor item PC, restores one copy through the engine Bag API.

It does not replace dialogue, auto-complete an unstarted quest, duplicate a
ticket stored in the PC, or restore the ticket after the S.S. Anne has left.

## Echoes Beyond the Fog compatibility

Version 0.1.1 also repairs the vanilla fallback used by Echoes Beyond the Fog
2.2.0. Echoes owns Bill's conversation while its quest has content to present,
but its fallback treats every engine base talk handler as a Lua callback.
Bill's S.S. Ticket handler is instead a script row list, so the item-award rows
never execute.

This mod intercepts only `fog:base_bill_chat` when its selected vanilla handler
is a row list and executes that list through the active engine ScriptRunner.
Function-shaped fallbacks, Echoes quest branches, and every unrelated script
command continue unchanged. Echoes is optional; no compatibility code runs
when its command is absent.

## Compatibility

- Gen1Recomp `>=0.1.78 <0.2.0` (including the current 0.1.83 runtime)
- Explicitly targets `games: ["gen1"]` (Red, Blue and Yellow)
- No dependency on Gen1 Widescreen UI
- No automatic installation
