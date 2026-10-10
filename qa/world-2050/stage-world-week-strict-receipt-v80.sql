-- P0 QA: single-week receipt from PERSISTED real singles match/point records.
-- Isolated stage only. Scope is WORLD-SINGLES, not full NCAA/Davis/Junior.
-- Fail closed when nested base_integrity is red even if world_guard.ok=true.
CREATE OR REPLACE FUNCTION cb_e2e_reconstruction_20261010.verify_persisted_singles_week_v80(
 p_job_key text
)
RETURNS jsonb
LANGUAGE sql STABLE SECURITY INVOKER SET search_path TO ''
AS $receipt$
WITH job AS MATERIALIZED (
 SELECT j.* FROM cb_e2e_reconstruction_20261010.world_week_jobs_v1 j
 WHERE j.job_key=p_job_key
),
events AS MATERIALIZED (
 SELECT i.tournament_id,i.status,i.matches_added,i.ranking_rows_added,
  (SELECT count(*)::int FROM public.world_tournament_matches m
   WHERE m.tournament_id=i.tournament_id
     AND coalesce(m.is_qualifying,false)=false) AS actual_main,
  (SELECT count(*)::int FROM public.world_tournament_matches m
   WHERE m.tournament_id=i.tournament_id
     AND coalesce(m.is_qualifying,false)=false
     AND m.winner_id IS NOT NULL AND m.loser_id IS NOT NULL
     AND m.winner_id<>m.loser_id
     AND m.winner_id IN(m.player_a_id,m.player_b_id)
     AND m.loser_id IN(m.player_a_id,m.player_b_id)
     AND coalesce(length(trim(m.score)),0)>0) AS actual_scored,
  (SELECT count(*)::int FROM public.world_ranking_points w
   WHERE w.tournament_id=i.tournament_id) AS actual_points,
  (SELECT count(*)::int FROM public.world_tournament_simulations s
   WHERE s.tournament_id=i.tournament_id AND s.winner_id IS NOT NULL) AS champions
 FROM cb_e2e_reconstruction_20261010.world_week_items_v1 i
 JOIN job j ON j.job_key=i.job_key
),
rollup AS MATERIALIZED (
 SELECT count(*)::int AS item_count,
  count(*) FILTER(WHERE e.status='completed')::int AS done_items,
  coalesce(sum(e.matches_added),0)::int AS expected_main_matches,
  coalesce(sum(e.actual_main),0)::int AS main_matches,
  coalesce(sum(e.actual_scored),0)::int AS committed_matches,
  coalesce(sum(e.ranking_rows_added),0)::int AS expected_point_rows,
  coalesce(sum(e.actual_points),0)::int AS actual_point_rows,
  count(*) FILTER(WHERE e.matches_added IS DISTINCT FROM e.actual_main
    OR e.actual_main IS DISTINCT FROM e.actual_scored
    OR e.ranking_rows_added IS DISTINCT FROM e.actual_points
    OR e.champions<>1)::int AS invalid_event_rows
 FROM events e
),
duplicate_rows AS MATERIALIZED (
 SELECT coalesce(sum(x.n-1),0)::int duplicate_match_effects
 FROM (
  SELECT m.tournament_id,m.round_no,m.match_no,count(*)::int n
  FROM public.world_tournament_matches m
  JOIN events e ON e.tournament_id=m.tournament_id
  WHERE coalesce(m.is_qualifying,false)=false
  GROUP BY m.tournament_id,m.round_no,m.match_no
  HAVING count(*)>1
 ) x
),
integrity AS MATERIALIZED (
 SELECT public.world_integrity_guard_v18(j.to_date) audit
 FROM job j
)
SELECT pg_catalog.jsonb_build_object(
 'ok',
   (j.status='completed' AND j.expected_items>0
    AND j.completed_items=j.expected_items
    AND r.item_count=j.expected_items
    AND r.done_items=j.expected_items
    AND r.invalid_event_rows=0
    AND r.main_matches=r.expected_main_matches AND r.committed_matches=r.main_matches
    AND r.actual_point_rows=r.expected_point_rows AND r.actual_point_rows>0
    AND d.duplicate_match_effects=0
    AND coalesce((g.audit->>'ok')::boolean,false)
    AND coalesce((g.audit->'base_integrity'->>'ok')::boolean,false)
    AND coalesce((g.audit->'base_integrity'->>'duplicate_active_world_ranks')::int,-1)=0
    AND NOT EXISTS(SELECT 1 FROM public.career_state)
   ),
 'scope','world_singles_only',
 'world_run_id',j.job_key,
 'checkpoint_date',j.to_date,
 'status',j.status,
 'tournaments_expected',j.expected_items,
 'tournaments_completed',r.done_items,
 'world_simulation_committed',(r.invalid_event_rows=0 AND r.done_items=j.expected_items
   AND r.committed_matches=r.expected_main_matches),
 'checkpoint_persisted',(j.status='completed' AND j.completed_items=j.expected_items),
 'ranking_integrity_ok',
   (coalesce((g.audit->>'ok')::boolean,false)
    AND coalesce((g.audit->'base_integrity'->>'ok')::boolean,false)
    AND coalesce((g.audit->'base_integrity'->>'duplicate_active_world_ranks')::int,-1)=0),
 'matches_due',r.expected_main_matches,
 'matches_committed',r.committed_matches,
 'managed_matches_pending',0,
 'duplicate_match_effects',d.duplicate_match_effects,
 'point_awards_expected',r.expected_point_rows,
 'point_awards_recorded',r.actual_point_rows,
 'invalid_event_rows',r.invalid_event_rows,
 'ranking_duplicates',g.audit->'base_integrity'->'duplicate_active_world_ranks',
 'outer_guard_ok',g.audit->'ok',
 'nested_guard_ok',g.audit->'base_integrity'->'ok',
 'certifies_full_unified_week',false,
 'model','CB-STAGE-SINGLES-STRICT-RECEIPT-v80'
)
FROM job j CROSS JOIN rollup r CROSS JOIN duplicate_rows d CROSS JOIN integrity g;
$receipt$;
REVOKE ALL ON FUNCTION cb_e2e_reconstruction_20261010.verify_persisted_singles_week_v80(text)
FROM PUBLIC,anon,authenticated;
