# P0 calendar semantics: cancelled ITF fixtures incorrectly played (24 Oct 2026)

## Environment and evidence

**ONLY** Supabase isolated stage `court-boss-e2e-2025-2050` (`sozrygjxjotozrsenred`). Production game, 119 user saves, and Render UI are outside this exercise.

The old v80 receipt checks persisted matches, unique ranks, duplicate side effects and award counts, **but not tournament cancellation/postponement status**. Some 2026 ITF fixtures are marked `is_active=true` despite literal `(CANCELLED)`/`(POSTPONED)` in the name. This made the world simulator award points for events that should not be played.

Read-only DB proof:

| Week ended | Invalid event IDs | State | Main draw matches | Award rows |
| --- | --- | --- | ---: | ---: |
| 2026-03-01 | 496 (M15 Heraklion Cancelled) | Completed | 31 | 16 |
| 2026-03-08 | 654 (Antalya Cancelled) | Completed | 31 | 16 |
| 2026-03-15 | 491 (Antalya Cancelled) | Completed | 31 | 16 |
| 2026-03-22 | 285 (Fujairah Postponed), 366 (Antalya Cancelled) | Completed | 62 | 32 |
| 2026-03-29 | 228 (Antalya Cancelled), 311 (Fujairah Postponed) | First completed, second pending | 31 | 16 |

**Total: six invalid events already played, 186 main-draw matches and 96 award rows.** One further postponed event in the running 2026-03-22→03-29 week has not been simulated. The old "11/11 verified weeks" statement applied to technical receipt integrity only; **four completed weeks are NOT sports-calendar certified**.

## Implemented in isolated stage

1. `stage-calendar-semantic-gate-v96.sql` defines a STABLE, invoker-rights receipt checker, which short-circuits invalid calendars before calling v80. It returns `ok:false`, reason `invalid_calendar_events`, full invalid event IDs, and never claims 2050 certification. Stage read-only proofs: four completed contaminated weeks plus one running contaminated week are rejected; the clean 2026-02-15→02-22 week passes.
2. `stage-week-scheduler-calendar-block-v97.sql` patches stage-only `begin_world_week_v2` to exclude cancelled/postponed title markers and reject an invalid previous week; `step_world_week_v2` stops all writes for any existing job containing invalid events. An explicit stage call for the contaminated current week returns `ok:false, reason:invalid_calendar_events`.
3. `resumable-singles-weeks-v85.mjs` now refuses any receipt not stating `calendar_semantics_ok:true` and `cancelled_event_rows:0`. Regression tests updated.

These safe gates are **not a historical cleanup**. This patch never deletes tournaments, recorded matches, ranking awards, game stats, H2H or other effects.

## Required for meaningful replay

- Identify the earliest corrupted pre-2026-03-01 checkpoint and obtain a separately tested backup before restoring/replaying staging. The stage checkpoint from 2026-10-10 is stored in the same database and is **not** a physically independent database backup.
- Prove all side effects of invalid matches are removed together: brackets, qualifying, draws, match history, rankings/points, H2H, fatigue, finance, titles, awards, generated news. Never delete only `world_ranking_points`: this would leave invisible historical state corruption.
- Freeze a correctly sourced 2025-12-01 calendar and inactive event registry for all future seasons; calendar event status should be a semantic enum rather than a title regex alone. The current regex is a fail-closed emergency guard against obvious bad event names.
- Rerun earlier weeks and v96 receipts after data-safe recovery, then resume ATP/Challenger/ITF weekly tests. Do not expand to WTA, doubles, Davis, juniors, NCAA or 2050 before their real multi-circuit replay gates are built.

**Verdict:** 2050 **NOT CERTIFIED**, historical ATP 2025 source still provisional, stage world needs fixture-status rebuild.
