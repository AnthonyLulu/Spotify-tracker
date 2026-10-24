-- P0 READ-ONLY safety gate for frozen ATP 2025 points-to-defend.
-- Staging-only. No guessed 2025 event dates, no smoothing of fictional points.
-- This gate must be RED while 2025 estimated snapshot carryovers
-- collapse on the same 2026-11-30 expiration date.
BEGIN READ ONLY;
SET LOCAL statement_timeout='10000ms';
WITH historical_seed AS (
 SELECT count(*) total_rows,count(distinct source_player_id) distinct_players,
 count(distinct rank) distinct_ranks
 FROM public.atp_ranking_baseline_2025_12_01
), expiry AS (
 SELECT count(*) FILTER (WHERE source_season=2025 AND is_estimated=true
  AND rank_category='Reconciliation'
  AND drop_date=DATE '2026-11-30') AS synthetic_cliff_rows,
 count(distinct player_id) FILTER (WHERE source_season=2025 AND is_estimated=true
  AND rank_category='Reconciliation'
  AND drop_date=DATE '2026-11-30') AS synthetic_cliff_players,
 coalesce(sum(points) FILTER (WHERE source_season=2025 AND is_estimated=true
  AND rank_category='Reconciliation'
  AND drop_date=DATE '2026-11-30'),0) AS synthetic_cliff_points,
 count(*) FILTER (WHERE source_season=2025 AND rank_category<>'Reconciliation'
  AND is_estimated=false) AS sourced_non_estimated_events,
 count(*) FILTER (WHERE source_season=2025 AND is_estimated=true) AS estimated_2025_rows
 FROM public.atp_defending_points_ledger
)
SELECT jsonb_build_object(
 'scope','isolated_stage_2025_atp',
 'historical_reference_rows',s.total_rows,
 'distinct_player_ids',s.distinct_players,
 'distinct_ranks',s.distinct_ranks,
 'expected_reference_rows',200,
 'sourced_2025_per_event_rows',e.sourced_non_estimated_events,
 'estimated_2025_rows',e.estimated_2025_rows,
 'unjustified_cliff_date','2026-11-30',
 'unjustified_cliff_rows',e.synthetic_cliff_rows,
 'unjustified_cliff_players',e.synthetic_cliff_players,
 'unjustified_cliff_points',e.synthetic_cliff_points,
 '2025_seed_and_expiry_certified',
  (s.total_rows=200 AND s.distinct_players=200 AND s.distinct_ranks=200
   AND e.synthetic_cliff_rows=0 AND e.estimated_2025_rows=0),
 'may_certify_2025_to_2050_world',false
) AS atp_2025_expiry_gate
FROM historical_seed s CROSS JOIN expiry e;
COMMIT;
