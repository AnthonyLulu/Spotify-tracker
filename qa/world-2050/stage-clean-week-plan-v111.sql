-- P0 semantic calendar replay plan from frozen staged tournament schedule.
-- READ-ONLY; NEVER repairs any contaminated match. Scope: first 12 world singles weeks 2026.
BEGIN READ ONLY;
SET LOCAL statement_timeout='18000ms';
WITH weeks AS (
 SELECT d::date AS from_date,(d + interval '7 days')::date AS to_date
 FROM generate_series(date '2026-01-04',date '2026-03-22',interval '7 days') d
), raw_schedule AS (
 SELECT w.from_date,w.to_date,t.id,t.name,
  (coalesce(t.is_active,false)=false OR t.name ~* '(cancelled|canceled|postponed|abandoned|annul[ée])') AS invalid
 FROM weeks w
 JOIN public.tournaments t ON t.singles
 AND coalesce(t.end_date,t.start_date)>w.from_date
 AND coalesce(t.end_date,t.start_date)<=w.to_date
 JOIN public.tournament_format_rules fr
 ON fr.circuit=t.circuit AND fr.category=t.category
 AND fr.main_draw_size=coalesce(t.singles_draw_size,t.draw_size)
 WHERE t.circuit IN ('ATP','Challenger','ITF')
 AND t.category NOT IN ('United Cup','Laver Cup','Davis Cup','Junior Davis Cup')
 AND fr.format_type='knockout'
), due AS (
 SELECT w.from_date,w.to_date,
 count(DISTINCT r.id)::int calendar_total,
 count(DISTINCT r.id) FILTER(WHERE NOT r.invalid)::int eligible_clean,
 count(DISTINCT r.id) FILTER(WHERE r.invalid)::int excluded_invalid,
 (SELECT count(*)::int
  FROM cb_e2e_reconstruction_20261010.world_week_jobs_v1 j
  JOIN cb_e2e_reconstruction_20261010.world_week_items_v1 i ON i.job_key=j.job_key
  WHERE j.from_date=w.from_date AND j.to_date=w.to_date) old_job_events,
 (SELECT count(*)::int
  FROM cb_e2e_reconstruction_20261010.world_week_jobs_v1 j
  JOIN cb_e2e_reconstruction_20261010.world_week_items_v1 i ON i.job_key=j.job_key
  JOIN public.tournaments t ON t.id=i.tournament_id
  WHERE j.from_date=w.from_date AND j.to_date=w.to_date
  AND (coalesce(t.is_active,false)=false
       OR t.name ~* '(cancelled|canceled|postponed|abandoned|annul[ée])')) old_job_invalid
 FROM weeks w LEFT JOIN raw_schedule r ON r.from_date=w.from_date
 GROUP BY w.from_date,w.to_date
), known_bad AS (
 SELECT t.id,t.name,t.end_date,i.job_key,i.status
 FROM public.tournaments t
 JOIN cb_e2e_reconstruction_20261010.world_week_items_v1 i ON i.tournament_id=t.id
 WHERE (coalesce(t.is_active,false)=false
       OR t.name ~* '(cancelled|canceled|postponed|abandoned|annul[ée])')
 AND i.job_key IN (SELECT j.job_key FROM cb_e2e_reconstruction_20261010.world_week_jobs_v1 j
                   WHERE j.from_date>=date '2026-01-04' AND j.to_date<=date '2026-03-29')
), counts AS (
 SELECT count(*) AS weeks_seen,sum(excluded_invalid) AS exclusions,
 min(from_date) FILTER(WHERE excluded_invalid>0) AS first_invalid_week_start,
 min(to_date) FILTER(WHERE excluded_invalid>0) AS first_invalid_week_end,
 sum(old_job_invalid) AS historical_job_invalid
 FROM due
)
SELECT jsonb_build_object(
 'scope','ISOLATED_STAGE_WORLD_SINGLES_CALENDAR_ONLY',
 'mode','READ_ONLY_DO_NOT_REPLAY',
 'weeks',c.weeks_seen,
 'first_invalid_week_start',c.first_invalid_week_start,
 'first_invalid_week_end',c.first_invalid_week_end,
 'excluded_in_planned_replay',c.exclusions,
 'historical_invalid_job_rows',c.historical_job_invalid,
 'invalid_already_played',(SELECT count(*) FROM known_bad WHERE status='completed'),
 'invalid_not_played',(SELECT count(*) FROM known_bad WHERE status='pending'),
 'schedule', (SELECT coalesce(jsonb_agg(to_jsonb(d) ORDER BY from_date),'[]'::jsonb) FROM due d),
 'invalid_events',(SELECT coalesce(jsonb_agg(to_jsonb(b) ORDER BY end_date,id),'[]'::jsonb) FROM known_bad b),
 'may_write_results',false,
 'external_restored_backup_verified',false,
 'certified_to_2050',false
) AS clean_replay_receipt FROM counts c;
COMMIT;
