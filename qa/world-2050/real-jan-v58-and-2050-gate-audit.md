# P0 Real-world 2025–2050 acceptance, stage checkpoint: 10 Oct 2026

## Real **engine** test, not a mock

The stage-only SQL `stage-jan-2026-multiday-rollback-v58.sql`
ran against the actual 31,831-active-player isolated Supabase world.
It used the real `rollover_season_daily_v22(2026)`, real
`advance_career_day_v26`, and real `world_integrity_guard_v18`.

Verified output:

- `ok: true`, `rolled_back: true`, approximately **58.0 s**
- exact consecutive days **2026-01-01, 02, 03, 04**
- **4 distinct daily commits**, **4 same-day idempotent replays**
- at least one managed training report for each day
- **2000 junior singles**, **2000 junior doubles** after rollover
- **world guard green** at 2026-01-04; 27,868 active adult players
  at that instant (actual lifecycle/retirement changes occur in
  rolled-back transaction, so not persisted)
- a fresh attempt to advance from Jan 4 to Jan 5 explicitly returned
  `weekly_checkpoint_required`; **weekly simulation was not faked**
  or silently marked complete
- no game save/active career/newgen reference rows left in staging
  after rollback.

### Measured performance blocker and bounded experiment

Without session-local name array caching, the expanded Jan rollover
attempt hit SQLSTATE 57014 in `cb_generated_player_name` while
re-aggregating and sorting surname lists for repeatedly generated
juniors, before a daily tick could begin. Once the stage-only
`cb_prime_newgen_name_pools_v1` cache was added, rollover finished
and the **four consecutive real days** passed in ~58 seconds.

The experiment inserts a *transaction-local temporary cache* of
first/last-name arrays grouped by source country and keeps the
original deterministic generator's collision rejection. It is not
a deployed production patch. The stage has an intentional additional
function-body drift relative to production, which precludes strict
byte-identical backend parity until audited and migrated separately.
The old staging functions are preserved verbatim in
`stage-name-pool-original-definitions-v58.sql` for reversibility.

### Read-only 2025→2050 gate: **RED**

Ran the real `world_25y_validation_v20(2025,2050)` on the same
isolated stage.

- Full result `ok: false` (do NOT mark certified)
- calendar horizon rules `ok: true`, no duplicate or rotation errors
- structural retirement and renewal projection `ok: true`
- **minimum projected adult headroom 1353** above 24,000, peak
  *current-roster* retirements 2047 in 2028
- 2026 entry-rules audit `ok: false`: 0 ranked ATP commitment
  candidates, 0 ITF-only candidate players in this isolated fixture
- 2026 doubles entry audit `ok: false`: 0 seeded Masters 1000
  automatic teams, despite category-format rules themselves passing.
- Historical ATP seed remains false: 2025 top-200 canonical identity
  mismatch, 2,021 synthetic all-at-once reconciliation expiries,
  no per-tournament 2025 points.

These 25-year projections are **read-only formula and calendar
validations**, *not* 25 years of actual daily career history.
The full real replay requires a certified world seed, independent
backup, true weekly pipeline adapter and verified managed Match
Center/save/load transactions.

The next real integration checkpoint must execute the actual
`/api/simulate` weekly transaction (not merely call
`mark_weekly_checkpoint_v22`) in isolation and test rollback/
idempotence. Do not attempt 25 full game years in production.
