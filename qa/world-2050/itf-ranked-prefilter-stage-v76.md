# P0 ITF full-draw candidate prefilter experiment, 10 October 2026

This is an isolated **QA copy only**, not a deployed game-engine change.
ITF M25 Chapel Hill's production-derived real full-draw routine
timed out while repeatedly evaluating per-player
`tournament_entry_eligibility → player_rank_at_date` for a 31,831
active-player staging world. ATP and Challenger match results were
already certified in rollback-only PR #75.

A new **conservative superset** candidate filter is applied before the
expensive LATERAL eligibility call in
`cb_e2e_reconstruction_20261010.simulate_world_knockout_tournament_full_qa_v76`.
It retains any player with a current `game_world_rank`, a
`ranking`, or **any historically qualifying `ranking_history` row**
dated no later than the tournament start, within the event-specific
rank range. The existing detailed entry-date rank, age, medical,
calendar, probability, score, form and tournament result rules
remain unchanged after the prefilter.

Measured READ-ONLY 2026 stage fixture:
- Active adult profiles: 31,831
- Current fallback rank in M25 #150–7000: 6,851
- Candidate superset retained: 7,354
- Eligible-band players incorrectly filtered out: **0**
- Historical ranking-history rows in this staging fixture: **0**

Important caveat: the zero-missed stage result does **not** certify
date-specific historical parity when real ranking histories are
present. That must be separately tested with non-empty history before
production migration is allowed. The full dated ITF draw and scores
are also separately tested; do not call this ITF fix green until the
actual v76 probe returns complete, scored match data with a persisted
champion and no timeout.

No production saves, SQL migrations or live users are touched by
this experiment. Stage data are rolled back by the probe.
