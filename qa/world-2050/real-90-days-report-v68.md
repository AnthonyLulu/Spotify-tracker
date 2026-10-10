# 90 genuine SQL career days in isolated E2E: 10 Oct 2026

This is a **measured isolated-stage result**, not a 25-year certificate.

Executed `cb_e2e_reconstruction_20261010.probe_real_december_march_v13()`
against the existing free isolated project with no active career/saves.
The function calls real `advance_career_day_v26`, real
`simulate_world_week`, real weekly checkpoint and the full
2025→2026 season rollover in a single transaction that is **forced
to roll back**.

## Measured result

| Check | Observed |
|---|---:|
| Exact start | 2025-12-01 |
| Exact finish | 2026-03-01 |
| Sequential real career days | **90 / 90** |
| Actual Sunday world simulations | **12 / 12** |
| Unique daily journal commits | **90** |
| Real year rollover | 1 (2025→2026) |
| Same-day repeated RPC | `already_applied=true` |
| World integrity guard at end | **`ok=true`** |
| Active adults inside rolled-back world at Mar 1 | **27,916** |
| Total in-function runtime | **85,721 ms** |
| Test state after forced rollback | **clean** |

All **12 world-week numbers** were captured and checked:
December 2025 weeks 1,2,3,4; January 2026 weeks
1,2,3,4; February 2026 weeks 5,6,7,8.

The prior 62-day probe incorrectly passed constant world week 1
for each Sunday in 2026; the new 90-day test now uses the actual
progression. The runtime remains bounded by the first March boundary,
avoiding an expensive full-year transaction on the free database.

**Ranked active-world readings:** 31,830 on four December
checkpoints; 33,626 at eight January/February checkpoints, with
2,000 junior singles and 2,000 junior doubles from the 2026
rollover. Weekly `updated_players` values were
1800,0,0,0,211,0,0,0,0,0,0,0. This field counts world-recovery
updates only; these zeros are **not proof** that tournaments, match
results or all of the AI world advanced. More dedicated
match/entry/injury/Elo verification is still required.

**After rollback verified by actual SELECT:**
`career_state=0`, `game_saves=0`,
`career_event_log=0`, `newgen_name_reference=0`,
`world_tournament_results=0`, 31,831 original-stage active players
and zero missing world ranks. The 85-table fixture archive verifier
returned `ok=true` with only the two previously audited calendar
overrides.

## Remains RED for 2025–2050 acceptance

- The isolated ATP 2025 stage is not historically faithful; initial
  Top200 identity mapping and 2,021 artificial aggregate point
  expiries remain a blocker.
- The stage lacks an independently verified external backup and
  an authenticated isolated Edge Function for real managed
  Match Center, weekly `/api/simulate` and save/load testing.
- This test is not a 90-day *mobile* career or continuous 2050
  world-history replay. Real live match, withdrawals, injuries,
  retirements and 25-year staff/financial consistency have not
  all been certified. 25-year projected checks still report `ok=false`.
- No game saves, production database rows, or production migrations
  were altered or deployed during this test.

Related open tasks: #10, #18, #54.
