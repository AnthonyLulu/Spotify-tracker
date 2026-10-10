# World single-event QA 2026, after stage-only alternate optimization V74

On 2026-10-10, the actual public `materialize_next_world_tournament_alternates`
was temporarily replaced **on isolated free Supabase staging only** with
the version from merged PR #74. Production database / game saves were
never touched. The original SQL body remains archived in the repo.

The stage QA function `probe_world_draw_verified_v75(tournament_id)`
calls actual `simulate_world_qualifying_full` and
`simulate_world_knockout_tournament_full` and measures the actual
`world_tournament_matches` and `world_tournament_simulations` records.
Its SQL forces full transaction rollback. It no longer expects the
nonexistent `winner_id` key in the response: the actual engine
returns `champion_id`, which is compared to the persisted tournament
winner and the actual final-match winner.

## Measured probes

| Circuit, event ID | Qualification matches | Main matches | Scored | Invalid | Champion persisted | Result |
|---|---:|---:|---:|---:|---|---|
| ATP250 Brisbane 65 | 12 | 31 | 31 | 0 | id 3207 = final winner | **Pass** |
| Challenger 75 Nouméa 906 | 18 | 31 | 31 | 0 | id 2207989 = final winner | **Pass when isolated** |
| ITF M25 Chapel Hill 199 | n/a | n/a | n/a | n/a | n/a | **Timeout, NOT validated** |

The Challenger probe intermittently hit PostgreSQL
`deadlock detected` during overlapping staging activity. It later
passed cleanly in an isolated sequential run; **concurrent retry
idempotence is not certified**. Zero save/career/test rows persisted
after the rollback probes.

Important realism defect: the stage Challenger champion currently
resolves to **Carlos Alcaraz**. That is not an endorsement of his
eligibility for Challenger 75. The stage 2025 initial player rankings
are historically inconsistent (191/200 canonical ATP identities,
8 uncertain archival profiles, 1 generated homonym, world ranks
misaligned). This remains P0 #54 before any certification.

ITF's separate bottleneck appears in `player_rank_at_date` called
across the broad 31k-player pool by
`simulate_world_knockout_tournament_full` via
`tournament_entry_eligibility`. The short-circuit alternate fix
does not solve that full-draw expensive scan. Do not repeatedly
stress staging or claim that the entire `run_unified_circuit_window`
passes. A safely bounded candidate shortlist must preserve
real ITF specialist eligibility, current merit, and historical ranks.

**Bottom line:** real ATP and Challenger main draws are now confirmed
to finish with scores and persistent champions *within rollback*
on isolated staging. Integrated multi-circuit, managed Match Center,
authentic 2025 ATP seed, 2050 history and cross-year save/load remain
open. No production migration applied.

Related #10, #54, #73, PR #74.
