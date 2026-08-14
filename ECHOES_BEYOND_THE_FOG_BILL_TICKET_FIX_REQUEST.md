# Echoes Beyond the Fog: Bill ticket fallback fix request

## Owner and affected consumer

- Owning mod: **Echoes Beyond the Fog**
- Manifest ID: `echoes_beyond_the_fog`
- Current installed version: `2.2.0`
- Owned surface: the `BILLS_HOUSE` talk overrides for
  `TEXT_BILLSHOUSE_BILL_SS_TICKET` and
  `TEXT_BILLSHOUSE_BILL_CHECK_OUT_MY_RARE_POKEMON`, plus the
  `fog:base_bill_chat` command in `main.lua`.
- Affected mod: **Gen1 Bill S.S. Ticket Repair**
- Manifest ID/version: `gen1_bill_ss_ticket_repair` `0.1.0`
- Blocked use case: after the repair reconstructs human Bill, talking to him
  must reach the engine-owned S.S. Ticket script and award `S_S_TICKET`.

## Verified failure

Gen1Recomp's base handler for
`BILLS_HOUSE/TEXT_BILLSHOUSE_BILL_SS_TICKET` is a script row list (a Lua
table), not a callback function. `MapScripts.baseTalk` deliberately supports
both row lists and functions.

Echoes 2.2.0 registers the higher-priority winning talk handler. Its
`fog:base_bill_chat` command obtains the base handler and then unconditionally
executes:

```lua
base(ctx.game, ctx.overworld, ctx.npc, function()
  runner:resume()
end)
```

That is valid only when `type(base) == "function"`. For Bill's ticket handler,
it attempts to call a table. The stock rows containing `give_item
S_S_TICKET` and `set_flag EVENT_GOT_SS_TICKET` therefore never run.

The installed Yellow save corroborates the failure state:

- `EVENT_BILL_SAID_USE_CELL_SEPARATOR = true`
- `EVENT_USED_CELL_SEPARATOR_ON_BILL = true`
- `EVENT_MET_BILL = true`
- `EVENT_MET_BILL_2 = true`
- human `BILLSHOUSE_BILL1` visible and monster Bill hidden
- no `S_S_TICKET` in the Bag or item PC
- no `EVENT_GOT_SS_TICKET`

The existing Echoes test hides the defect by mocking `MapScripts.baseTalk` to
return a function only. The repair ZIP's own state-repair test passes; it does
not and should not own another mod's single-winner talk override.

## Smallest owner-side change

Make `fog:base_bill_chat` preserve both supported base-talk shapes:

- If the base handler is a function, invoke it with the existing completion
  callback/yield behavior.
- If the base handler is a row-list table, execute those rows through the
  current `ScriptRunner` and current context (for example,
  `ctx.runner:exec(base, ctx)` if that remains the supported engine surface).
- If the handler is absent or has an unsupported type, return safely and log a
  useful warning rather than throwing.

Keep the fallback dynamic through `MapScripts.baseTalk`; do not copy Bill's
vanilla dialogue or item-award rows into Echoes.

## Ownership boundary and non-goals

- Echoes continues to own only its conditional quest conversation.
- The engine continues to own Bill's vanilla S.S. Ticket behavior.
- Gen1 Bill S.S. Ticket Repair continues to own only interrupted-save state
  reconstruction and missing-ticket restoration for saves that already carry
  `EVENT_GOT_SS_TICKET`.
- Do not make the repair mod auto-award an unclaimed ticket, override Echoes'
  talk handler, or duplicate the vanilla Bill script.
- Do not alter Widescreen UI, world geometry, Pikachu staging, or unrelated
  Echoes quest progression.

## Required semantics and compatibility

- Preserve Echoes' current priority and single-winner talk ownership while it
  has quest content to present.
- Every `vanilla` branch must execute the complete engine base handler for
  either supported representation: function or row list.
- Blocking dialogue and choices must retain correct coroutine/yield behavior.
- Missing/invalid base handlers must fail closed without granting items or
  changing flags.
- Maintain Gen1Recomp `>=0.1.38 <2.0.0` compatibility unless the row-list
  execution API requires an honestly documented higher engine floor.
- Preserve Red, Blue, and Yellow behavior and load-order independence.

## Acceptance tests

1. Extend the Echoes test so `MapScripts.baseTalk` returns a representative
   row-list table. Drive the `vanilla` branch and assert that the rows execute
   rather than being called as a function.
2. Retain a function-shaped base-handler test and assert its callback/yield
   path still completes.
3. With Bill repaired (`EVENT_MET_BILL_2 = true`) but the ticket unclaimed,
   talking to `BILLSHOUSE_BILL1` must add exactly one `S_S_TICKET` and set
   `EVENT_GOT_SS_TICKET`.
4. Talking again must not duplicate the ticket.
5. Before the Echoes quest is available, Bill's ticket conversation must fall
   through to vanilla. When Echoes is available/active/completed, its existing
   branches must remain unchanged.
6. Run the exact Lua 5.1 test suite and audit a flat root-only release ZIP.

## Versioning and returned artifacts

- Bump Echoes Beyond the Fog from `2.2.0` to a new patch version in its
  manifest, README/changelog, and source metadata.
- No dependency-floor bump is expected if the existing ScriptRunner surface is
  valid across the declared engine range; otherwise document and apply the
  smallest accurate floor.
- Return changed files, the new version, exact tests run/results, the flat
  release ZIP, its package audit, and the finalized function/table fallback
  contract.

