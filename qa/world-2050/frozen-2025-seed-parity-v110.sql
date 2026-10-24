-- Court Boss P0 initial-world seed parity v110 (isolated stage ONLY).
-- READ ONLY: proves frozen synthetic adult identity+attribute parity and rank plan
-- exist *before* any new-world replay. It does NOT certify a 2025 ATP event ledger
-- or undo corrupted 2026 title/match/recovery side effects.
BEGIN READ ONLY;
SET LOCAL statement_timeout='20000ms';
WITH synth AS MATERIALIZED (
  SELECT s.slot,s.snapshot_date,p.id AS player_id,
         p.name AS actual_name,p.country AS actual_country,
         p.birth_date AS actual_birth,p.data_source,
         p.game_generated,a.player_id AS attr_player_id,
         to_jsonb(a) @> (to_jsonb(sa)-'slot') AS attributes_match,
         (p.name=s.player_name AND p.country=s.country
          AND p.birth_date=s.birth_date) AS identity_match
  FROM cb_e2e_reconstruction_20261010.synthetic_adult_seed_v1 s
  LEFT JOIN public.players p ON p.id=1000000+s.slot
  LEFT JOIN public.player_attributes a ON a.player_id=p.id
  LEFT JOIN cb_e2e_reconstruction_20261010.synthetic_adult_attributes_v1 sa ON sa.slot=s.slot
), synth_check AS (
 SELECT count(*) AS seed_rows,
 count(*) FILTER(WHERE player_id IS NULL) missing_players,
 count(*) FILTER(WHERE identity_match IS DISTINCT FROM true) identity_mismatches,
 count(*) FILTER(WHERE data_source IS DISTINCT FROM 'ISOLATED-2025-SYNTHETIC-V1'
                        OR game_generated IS DISTINCT FROM true) provenance_mismatches,
 count(*) FILTER(WHERE attr_player_id IS NULL OR attributes_match IS DISTINCT FROM true) attribute_mismatches,
 count(*) FILTER(WHERE snapshot_date IS DISTINCT FROM DATE '2025-12-01') date_mismatches
 FROM synth
), rank_check AS (
 SELECT count(*) AS rows_total,count(distinct r.player_id) AS unique_ids,
  count(distinct r.assigned_rank) AS unique_ranks,
  count(*) FILTER(WHERE p.id IS NULL) missing_ranked_players,
  count(*) FILTER(WHERE p.id IS NOT NULL AND r.data_source IS DISTINCT FROM p.data_source) provenance_mismatches,
  count(*) FILTER(WHERE p.id IS NOT NULL AND r.assigned_rank IS DISTINCT FROM p.game_world_rank) evolved_ranks
 FROM cb_e2e_reconstruction_20261010.world_rank_seed_plan_v1 r
 LEFT JOIN public.players p ON p.id=r.player_id
), atp_check AS (
 SELECT (SELECT count(*) FROM cb_e2e_reconstruction_20261010.atp_20251201_reference_v1) reference_profiles,
 (SELECT count(*) FROM cb_e2e_reconstruction_20261010.atp_2025_ledger_bridge_v1) bridge_rows,
 (SELECT count(*) FROM cb_e2e_reconstruction_20261010.atp_2025_ledger_bridge_v1 b
  LEFT JOIN public.players p ON p.id=b.stage_player_id WHERE p.id IS NULL) orphan_bridge,
 (SELECT count(*) FROM public.atp_ranking_baseline_2025_12_01) top200_matched
)
SELECT jsonb_build_object(
 'environment','ISOLATED_STAGE_ONLY',
 'snapshot_date','2025-12-01',
 'mode','READ_ONLY_SEED_PARITY_NOT_REPLAY',
 'synthetic_seed_count',s.seed_rows,
 'synthetic_missing_players',s.missing_players,
 'synthetic_identity_mismatches',s.identity_mismatches,
 'synthetic_source_mismatches',s.provenance_mismatches,
 'synthetic_attribute_mismatches',s.attribute_mismatches,
 'synthetic_snapshot_date_mismatches',s.date_mismatches,
 'initial_rank_plan_rows',r.rows_total,
 'initial_rank_unique_players',r.unique_ids,
 'initial_rank_unique_positions',r.unique_ranks,
 'initial_rank_missing_players',r.missing_ranked_players,
 'initial_rank_source_mismatches',r.provenance_mismatches,
 'rank_positions_evolved_since_seed',r.evolved_ranks,
 'atp_2025_reference_profiles',a.reference_profiles,
 'atp_2025_ledger_bridge_rows',a.bridge_rows,
 'atp_bridge_missing_stage_players',a.orphan_bridge,
 'provisional_top200_reference_rows',a.top200_matched,
 'seed_identity_attributes_reproducible',
  (s.seed_rows=24435 AND s.missing_players=0 AND s.identity_mismatches=0
   AND s.provenance_mismatches=0 AND s.attribute_mismatches=0
   AND s.date_mismatches=0 AND r.rows_total=26456
   AND r.unique_ids=r.rows_total AND r.unique_ranks=r.rows_total
   AND r.missing_ranked_players=0 AND r.provenance_mismatches=0
   AND a.reference_profiles=2205 AND a.orphan_bridge=0),
 'can_delete_live_2026_world',false,
 'independent_verified_external_backup_available',false,
 'unified_world_replay_certified',false,
 '2050_certified',false
) AS frozen_world_seed_receipt
FROM synth_check s,rank_check r,atp_check a;
COMMIT;
