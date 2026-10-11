# Court Boss: resumable world-week E2E prototype (2026-10-10)

**QA ONLY. Do not deploy these files as a production migration.**

This is the isolated Supabase `court-boss-e2e-2025-2050` implementation of a durable, idempotent, one-tournament-per-transaction world simulator. The schema `cb_e2e_reconstruction_20261010` and real 2025 ranking ledger are required.

## Tested behavior

- Window 2026-01-04 to 2026-01-11: **15 / 15 events persisted** across ATP, Challenger and ITF singles.
- **767 scored matches**, including qualifying, **284 earned-ranking rows**.
- No invalid winner/loser pairing or duplicate draw slots in the completed world week.
- Final ATP ranking: Carlos Alcaraz #1, Jannik Sinner #2.
- A repeated completed-week call returned `already_completed=true` without new results.
- A timeout during the run did not reset completed tournament checkpoints.
- The next week (2026-01-11 to 2026-01-18) has separately persisted checkpoints and is a remaining endurance test.

## Design

`begin_world_week_v1(from,to)` freezes the list of eligible tournaments.
`step_world_week_v2(job_key)` acquires the world lock, simulates **one** outstanding tournament, writes the match and ranking ledgers, and atomically marks its checkpoint committed. Failed database statements roll back as one transaction. Ranking/race refresh is deferred to the final step, avoiding a full-ranking recalculation after every event.

## Pre-release blockers

1. This is singles-only. The current live `run_unified_circuit_window` also orchestrates Davis Cup, junior, doubles, NCAA, qualifying/acceptance, and cross-circuit conflicts.
2. Save/load must preserve or invalidate the week-job identity after restoring a snapshot; never blindly reuse an old completed job.
3. The frontend `court-boss-live` must request and resume steps with visible progress. The existing `/api/simulate` is still one monolithic weekly call.
4. Run multiple seasons with every world circuit and actual mobile save/reload before enabling this path in production.

Do not replace live weekly simulation until all four gates are met.
