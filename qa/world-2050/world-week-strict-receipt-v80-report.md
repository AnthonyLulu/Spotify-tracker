# 15 actual completed singles tournaments, nested integrity RED

The stage-only world-week job 2026-01-04 → 2026-01-11 is
`status=completed`, 15/15 tournament items. Its persisted per-event
main draw counts reconcile **461/461 valid completed matches**;
the combined match table contains **767 match records** (qualifying
and main), with 0 missing winner/loser/score. Its per-event ranking
awards reconcile **284/284** rows with a total of 4,181 points.

**Critical false green:** `world_integrity_guard_v18('2026-01-11')`
has `ok=true` but nested `base_integrity.ok=false` and 2,031
duplicate `game_world_rank` extras. Direct `GROUP BY game_world_rank
HAVING count(*)>1` gives exactly 2,031 positions each occupied twice.
The collisions include synthetic junior ID 2 and Alcaraz #1, synthetic
junior ID 802 and Sinner #2. The existing ATP
`refresh_world_rankings` updates `game_world_rank` for newly
ranked official ATP players but does not call existing
`refresh_game_world_ranks()` to relocate displaced lower-level
players.

New isolated SQL receipt `verify_persisted_singles_week_v80`
requires both outer and nested world guard success, zero duplicate
world ranks, and matches the tournament journal against persisted
scores, champions, and awarded points. **Expected current receipt:
`ok=false` despite 15/15 tournaments**. That is correct and
prevents a false 2025–2050 pass.

The receipt intentionally identifies `scope=world_singles_only`,
`certifies_full_unified_week=false`; it cannot certify Davis Cup,
NCAA, juniors, doubles, managed Match Center, or save/load.

Corrective world-rank reassignments must be tested in an isolated
forced-rollback transaction AFTER any concurrently active world-week
job finishes, then wired into the world ranking refresh with
idempotence and historical Top200 checks. The real 2025-12-01
ATP per-event history and source license remain RED. No production
database, paid service or saved game modified.
