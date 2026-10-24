-- Court Boss stage-only calendar corruption inventory. Read-only, never repairs or deletes.
-- Accurate technical trace: all cancelled/postponed events with persisted simulation records.
BEGIN READ ONLY;
SET LOCAL statement_timeout = '15000ms';
WITH invalid AS MATERIALIZED (
  SELECT t.id,t.name,t.start_date,t.end_date,t.is_active
  FROM public.tournaments t
  WHERE t.name ~* '(cancelled|canceled|postponed|abandoned|annul[ée])'
  AND EXISTS(SELECT 1 FROM public.world_tournament_simulations w WHERE w.tournament_id=t.id)
), impacts AS MATERIALIZED (
  SELECT i.id,i.name,i.start_date,i.end_date,i.is_active,
  (SELECT count(*)::int FROM public.world_tournament_matches m
   WHERE m.tournament_id=i.id) match_rows_all,
  (SELECT count(*)::int FROM public.world_tournament_matches m
   WHERE m.tournament_id=i.id AND m.winner_id IS NOT NULL
     AND coalesce(m.is_qualifying,false)=false) main_completed,
  (SELECT count(*)::int FROM public.world_ranking_points r
   WHERE r.tournament_id=i.id) point_awards,
  (SELECT count(*)::int FROM public.court_boss_match_stat_lines c
   WHERE c.tournament_id=i.id) match_stat_rows,
  (SELECT count(*)::int FROM public.player_titles pt
   WHERE pt.tournament_name=i.name AND pt.title_date=i.end_date
     AND pt.origin='game' AND pt.event_type='singles') title_rows
  FROM invalid i
), checks AS (
 SELECT count(*) AS invalid_simulated_events,
 coalesce(sum(match_rows_all),0) AS total_match_rows,
 coalesce(sum(main_completed),0) AS completed_main_matches,
 coalesce(sum(point_awards),0) AS award_rows,
 coalesce(sum(match_stat_rows),0) AS stat_rows,
 coalesce(sum(title_rows),0) AS title_rows,
 coalesce(jsonb_agg(to_jsonb(impacts) ORDER BY end_date,id),'[]'::jsonb) AS event_evidence
 FROM impacts
)
SELECT jsonb_build_object(
 'environment','ISOLATED_E2E_ONLY','as_of','2026-10-24',
 'status','STOP_RESTORE_NOT_AUTHORIZED',
 'user_saves',(SELECT count(*) FROM public.game_saves),
 'save_slots',(SELECT count(*) FROM public.game_save_slots),
 'active_careers',(SELECT count(*) FROM public.career_state),
 'checkpoint_exists',to_regclass('cb_e2e_checkpoint_20261010.players') IS NOT NULL,
 'weekly_jobs',(SELECT count(*) FROM cb_e2e_reconstruction_20261010.world_week_jobs_v1),
 'weekly_jobs_completed',(SELECT count(*) FROM cb_e2e_reconstruction_20261010.world_week_jobs_v1 WHERE status='completed'),
 'invalid_simulated_events',c.invalid_simulated_events,
 'all_match_rows',c.total_match_rows,
 'completed_main_matches',c.completed_main_matches,
 'match_stat_rows',c.stat_rows,
 'ranking_award_rows',c.award_rows,
 'titles',c.title_rows,
 'events',c.event_evidence,
 'safe_to_delete_ledger_only',false,
 'independent_verified_backup_known',false,
 '2050_certified',false
) AS forensic_report FROM checks c;
COMMIT;
