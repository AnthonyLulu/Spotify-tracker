-- Stage-only documented performance fix (already applied on 2026-10-24).
-- DO NOT deploy automatically to production. Stage project: court-boss-e2e-2025-2050.
-- Rationale: leaderboard future_no1 CTE previously full-scanned ~126k ranking_history rows.
DO $$
BEGIN
 IF to_regclass('cb_e2e_checkpoint_20261010.players') IS NULL
  OR to_regclass('cb_e2e_reconstruction_20261010.world_week_jobs_v1') IS NULL
  OR (SELECT count(*) FROM public.career_state)<>0
  OR (SELECT count(*) FROM public.game_saves)<>0
  OR (SELECT count(*) FROM public.game_save_slots)<>0
 THEN
  RAISE EXCEPTION 'Refusing stage-only legacy index: isolated zero-save checkpoint not found';
 END IF;
END $$;
CREATE INDEX IF NOT EXISTS cb_e2e_legacy_rank_history_no1_date_v96
ON public.ranking_history(snapshot_date,player_id)
WHERE ranking=1;

-- Read-only plan probe. Expected: Index Only Scan using the stage-only index.
EXPLAIN (FORMAT TEXT, COSTS TRUE)
SELECT rh.player_id,count(*)
FROM public.ranking_history rh
WHERE rh.snapshot_date>DATE '2025-12-01'
 AND rh.snapshot_date<=DATE '2026-03-29'
 AND rh.ranking=1
GROUP BY rh.player_id;
