# Bounded-vs-full world alternate candidate order (isolated stage)

## Measured read-only comparison, 10 October 2026

Using the **actual** `public.tournament_candidate_player_ids`
on the isolated populated staging world, compared exactly the first
128 sorted candidates by `effective_rank ASC, current_ability DESC,
player_id ASC` for requested limits 500 vs 2,000.

| Upcoming event | Circuit | Limit 500 rows | Limit 2,000 rows | First 128 order/rank differences | First extra full-pool position |
|---|---|---:|---:|---:|---:|
| Adelaide International (#4) | ATP 250 | 500 | 913 | **0** | 501 |
| Nonthaburi 2 (#928) | Challenger 75 | 500 | 1,105 | **0** | 501 |
| Winston-Salem (#174) | ITF M25 | 500 | 798 | **0** | 501 |

The comparison tests **raw-candidate ranking order only**.
`materialize_next_world_tournament_alternates` also applies
`ai_player_commits_to_tournament`, direct calendar conflict and
previously committed entry exclusion. The final number of actual
ranked candidates needed can exceed 128 when rejected players or
existing alternates are skipped. A future ranking-history seed can
also reorder candidates relative to the 500 top-up pool.

**NO blanket change from 2,000 to 500 in production is approved**.
A safe follow-up needs a staged adaptive 500→2,000 widening or an
equivalent exact-result proof, including populated historical
rankings, managed entries, withdrawals, and already-filled holes.
The fail-closed query deliberately labels final-alternate parity
as `false`.

## Separate real weekly world results

The isolated world-week job `WORLD-SINGLES:2026-01-04:2026-01-11`
completed **15/15** tournaments with a persisted `completed`
status, measured **767 world match rows** over those dates,
zero rows missing winner, loser, or score, and **284 ranking points
award rows across 15 tournaments** (`world_ranking_points`,
aggregate 4,181 points). The event-step journal's total recorded
main-draw match count was 461. These readings are from the isolated
stage, not production or a mobile managed Match Center session.
The historical ATP Top200 and 2025 per-tournament expiry remain
uncertified, and the user's production game saves were not touched.
