-- Staging-only, read-only singles checkpoint and resume progress audit.
-- Evaluate exactly ONE expensive strict receipt: the last COMPLETED week,
-- never the newest in-progress job. No replay or certification of 2050.
BEGIN READ ONLY;
SET LOCAL statement_timeout='15000ms';
WITH job_chain AS MATERIALIZED (
 SELECT j.*, lag(to_date) over(order by from_date) previous_end
 FROM cb_e2e_reconstruction_20261010.world_week_jobs_v1 j
), item_stats AS MATERIALIZED (
 SELECT job_key,count(*) AS items_seen,
 count(*) filter (where status='completed') AS items_done,
 coalesce(sum(matches_added),0) AS matches,
 coalesce(sum(ranking_rows_added),0) AS awards
 FROM cb_e2e_reconstruction_20261010.world_week_items_v1
 GROUP BY job_key
), job_state AS MATERIALIZED (
 SELECT j.*,coalesce(i.items_seen,0) AS actual_items,
 coalesce(i.items_done,0) AS actual_done,
 coalesce(i.matches,0) AS matches,coalesce(i.awards,0) AS awards
 FROM job_chain j LEFT JOIN item_stats i USING(job_key)
), last_finished AS MATERIALIZED (
 SELECT job_key,to_date FROM job_state
 WHERE status='completed' AND completed_items=expected_items
   AND actual_items=expected_items AND actual_done=expected_items
 ORDER BY to_date DESC LIMIT 1
), strict_receipt AS MATERIALIZED (
 SELECT cb_e2e_reconstruction_20261010.verify_persisted_singles_week_v80(job_key) AS receipt
 FROM last_finished
), summary AS (
 SELECT count(*) AS weeks_started,
 count(*) FILTER (WHERE status='completed' AND completed_items=expected_items
  AND actual_items=expected_items AND actual_done=expected_items) AS weeks_fully_persisted,
 count(*) FILTER (WHERE status<>'completed') AS weeks_unfinished,
 coalesce(bool_and(previous_end IS NULL OR previous_end=from_date),false) AS dates_contiguous,
 min(from_date) AS first_week_start,
 max(to_date) FILTER (WHERE status='completed') AS latest_week_end,
 coalesce(sum(actual_done) FILTER (WHERE status='completed'),0) AS finished_tournaments,
 coalesce(sum(matches) FILTER (WHERE status='completed'),0) AS finished_matches,
 coalesce(sum(awards) FILTER (WHERE status='completed'),0) AS finished_awards
 FROM job_state
)
SELECT jsonb_build_object(
 'scope','isolated_world_singles_only',
 'weeks_started',s.weeks_started,
 'weeks_fully_persisted',s.weeks_fully_persisted,
 'weeks_unfinished',s.weeks_unfinished,
 'no_missing_week_dates',s.dates_contiguous,
 'from_date',s.first_week_start,
 'last_completed_week_end',s.latest_week_end,
 'completed_tournaments',s.finished_tournaments,
 'completed_matches',s.finished_matches,
 'completed_point_awards',s.finished_awards,
 'in_progress',(
   SELECT coalesce(jsonb_agg(jsonb_build_object(
     'job_key',job_key,'expected',expected_items,
     'committed_items',actual_done,'matches',matches,'point_awards',awards
   ) ORDER BY from_date),'[]'::jsonb)
   FROM job_state WHERE status<>'completed'
 ),
 'last_finished_strict_receipt_ok',coalesce(
   (r.receipt->>'ok')::boolean=true
   AND r.receipt->>'scope'='world_singles_only'
   AND (r.receipt->>'nested_guard_ok')::boolean=true
   AND (r.receipt->>'outer_guard_ok')::boolean=true
   AND (r.receipt->>'ranking_integrity_ok')::boolean=true
   AND (r.receipt->>'ranking_duplicates')::int=0
   AND (r.receipt->>'duplicate_match_effects')::int=0
   AND (r.receipt->>'invalid_event_rows')::int=0,
   false
 ),
 'all_started_weeks_completed',s.weeks_started=s.weeks_fully_persisted,
 'certifies_every_historical_week_integrity',false,
 'full_unified_circuits_certified',false,
 '2050_certified',false
) AS progress_receipt
FROM summary s LEFT JOIN strict_receipt r ON true;
COMMIT;
