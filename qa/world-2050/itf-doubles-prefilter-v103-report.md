# Private stage-only M15/M25 doubles candidate prefilter v103 — 24 October 2026

## Actual implementation

The isolated `court-boss-e2e-2025-2050` database now has two new *private* staging routines derived with exact SQL-source MD5 gates:
- `cb_e2e_reconstruction_20261010.select_itf_doubles_prefilter_v103(bigint,bigint,integer)`, limited to 256 pairs by default (maximum 400). It retains the actual `ai_player_commits_to_doubles_tournament`, injury, schedule, player-focus and merit checks on the candidate shortlist.
- `cb_e2e_reconstruction_20261010.simulate_world_doubles_one_event_prefilter_v103(date,date,bigint)`, the original full draw engine limited to a specific tournament ID and calling the private selector for M15/M25.

The original `public.select_itf_doubles_field_v20`, `public.simulate_world_doubles_tournaments`, and private baseline v102 remain unchanged. Both new functions are `SECURITY INVOKER`, and runtime permission inspection confirmed `anon_can_run=false` and `authenticated_can_run=false`. Installation dry-run/ROLLBACK succeeded, then installation COMMIT succeeded.

## Actual test results and remaining correctness gates

- Isolated transaction created a 200-pair season pool with the original `refresh_world_doubles_partnerships_fast` routine and rolled it back. Returned `filled=200,active_pairs=200`, while the original 2025 race pair seed is absent in the stage (`seeded_from_2025=0`). **No pair state was persisted**.
- Original single-event v102 function timed out after 18 seconds inside `select_itf_doubles_field_v20` / `ai_player_commits_to_doubles_tournament`. Entire transaction rolled back.
- A v103 preview containing the new 256-pair candidate cap was attempted. The **existing singles world writer held advisory lock 94832021**, so the transaction correctly refused execution. **No v103 match/result has been validated yet.**
- Therefore **do not merge this candidate selection into production** as tournament realism is not established. It may exclude a deserved direct acceptance/wildcard from outside the candidate pool. Compare strict selection against uncapped source on a controlled fixture, and independently check draws, champion, ranking points, player commitments, and save/load before full-world certification.

## P0 next steps

Continue with isolated 2026 double M15/ATP tests only when singles worker isn't active, prove score+points from an entire draw and correct 2025 world pair continuity. Then implement one-event batches for ATP/Challenger doubles, junior singles/doubles, NCAA and Davis Cup with strict receipts and synced daily checkpoints. Real 2025-2050 simulation and production save/load remain **not certified**.
