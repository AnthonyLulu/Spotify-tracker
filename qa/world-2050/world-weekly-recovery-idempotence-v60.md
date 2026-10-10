# World AI recovery exactly once per weekly checkpoint (P0 V60)

The legacy `simulate_world_week` invokes
`apply_world_recovery_week(p_date,p_week)` on each API call.
The previous definition subtracted recovery from player fatigue and
raised fitness on **every call**, with no idempotency guard. A network
retry or reloaded weekly checkpoint could recover the same AI roster
twice. This is independent from managed-player daily recovery debt.

## Safe V60 implementation

- Re-entrant world-week advisory transaction lock `94832021`,
  identical to `simulate_world_week`'s existing lock.
- Before updating players, inspect `career_event_log` for exactly
  one `world_weekly_recovery_v60` marker for the **snapshot date**.
- If present: return `already_applied=true`,
  `updated_players=0` and the original affected-player count.
- On the first call: perform the existing, unchanged world recovery
  calculations, then add the marker **inside the same SQL
  transaction**, before returning. A rollback removes both the
  fatigue changes and the marker.
- Add a small partial unique index on the existing
  `career_event_log(event_date)` for this specific event type.
  Avoid introducing another table outside the save/load snapshot.
- Use invoker authorization inherited from the original helper;
  explicit direct EXECUTE only for `service_role`.

## Actual isolated Supabase test (rolled back)

On 10 October 2026, real `apply_world_recovery_week` was invoked
twice at 2026-01-11 with different week numbers to ensure the
date is the idempotency identity. An existing archived junior
fixture was temporarily set to fatigue=80 and fitness=60:

- First call: **1801 actual AI players** updated,
  `already_applied=false`, tested fatigue **80→69**.
- Repeated call: **0 players** updated,
  `already_applied=true`, original updated count 1801,
  fatigue **69→69**.
- Journal marker count remained **1**.
- Forced exception rolled back the entire trial; 85 original
  fixture tables and real production data were not changed.

## Remaining P0 and release constraints

This fixes **only** global weekly recovery, not the idempotence
of all the dozens of other RPC calls made by the weekly
`/api/simulate` endpoint. 2025–2050 full daily replay
remains blocked by real 2025 ranking identities and ATP
event-by-event provenance, 2026 doubles/entry pools, full
isolated Edge Function integration and independent backup.

The migration is committed to the game branch but **must
be separately staged and deployed** to the production
database in a controlled window. A production partial-index
build may consume scarce disk IO; no production DDL executed.
