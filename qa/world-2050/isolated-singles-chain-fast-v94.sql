-- ATP/Challenger/ITF singles: cheap persisted-chain audit, isolated stage only.
-- One expensive final integrity receipt, not one per historical week.
-- This is NOT per-week replay certification of other circuits or 2050.
BEGIN READ ONLY;
SET LOCAL statement_timeout='15000ms';
WITH job_chain AS MATERIALIZED (
 SELECT j.*,lag(to_date) over(order by from_date) previous_end
 FROM cb_e2e_reconstruction_20261010.world_week_jobs_v1 j
), item_stats AS (
 SELECT job_key,count(*) item_count,count(*) FILTER(where status='completed') items_completed,
        coalesce(sum(matches_added),0) matches,coalesce(sum(ranking_rows_added),0) awards
 FROM cb_e2e_reconstruction_20261010.world_week_items_v1
 GROUP BY job_key
), result_rows AS (
 SELECT j.*,coalesce(i.item_count,0) items_seen,
        coalesce(i.items_completed,0) actual_completed,
        coalesce(i.matches,0) matches,coalesce(i.awards,0) awards
 FROM job_chain j LEFT JOIN item_stats i USING(job_key)
), latest AS MATERIALIZED (
 SELECT cb_e2e_reconstruction_20261010.verify_persisted_singles_week_v80(
  (SELECT job_key FROM result_rows ORDER BY to_date DESC LIMIT 1)
 ) as r
), summary AS (
 SELECT count(*) weeks,
 count(*) filter(where status='completed' and expected_items=completed_items
     and items_seen=expected_items and actual_completed=expected_items) completely_persisted,
 coalesce(bool_and(previous_end IS NULL OR previous_end=from_date),false) contiguous,
 min(from_date) first_start,max(to_date) last_end,
 coalesce(sum(actual_completed),0) tournaments,
 coalesce(sum(matches),0) matches,
 coalesce(sum(awards),0) awards
 FROM result_rows
)
SELECT jsonb_build_object(
 'scope','isolated_2026_singles_persisted_chain_plus_last_week_strict_guard',
 'weeks',s.weeks,'weeks_fully_persisted',s.completely_persisted,
 'no_missing_week_dates',s.contiguous,
 'from_date',s.first_start,'through_date',s.last_end,
 'tournaments',s.tournaments,'matches',s.matches,'awards',s.awards,
 'latest_strict_receipt_ok',((l.r->>'ok')::boolean=true AND (l.r->>'nested_guard_ok')::boolean=true
  AND (l.r->>'ranking_integrity_ok')::boolean=true AND (l.r->>'ranking_duplicates')::int=0
  AND (l.r->>'duplicate_match_effects')::int=0),
 'certifies_all_historical_week_integrity',false,
 'full_unified_circuits_certified',false,
 '2050_certified',false
) receipt FROM summary s CROSS JOIN latest l;
COMMIT;
