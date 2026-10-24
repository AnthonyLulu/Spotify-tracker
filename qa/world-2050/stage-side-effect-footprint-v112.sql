-- Replay forensics: observable write footprint of previously simulated cancelled/postponed tournaments.
-- Stage-only READ ONLY. Training/injury rows are *coincidences of player membership*,
-- NOT necessarily caused by cancelled matches. No DELETE, cleanup, reset, replay.
BEGIN READ ONLY;
SET LOCAL statement_timeout='15000ms';
WITH bad_events AS MATERIALIZED (
 SELECT t.id,t.name,t.end_date
 FROM public.tournaments t
 WHERE (coalesce(t.is_active,false)=false
        OR t.name ~* '(cancelled|canceled|postponed|abandoned|annul[ée])')
 AND EXISTS (SELECT 1 FROM public.world_tournament_simulations w
             WHERE w.tournament_id=t.id)
), games AS MATERIALIZED (
 SELECT m.id,m.tournament_id,m.player_a_id,m.player_b_id
 FROM public.world_tournament_matches m
 JOIN bad_events t ON t.id=m.tournament_id
), participants AS MATERIALIZED (
 SELECT DISTINCT a.player_id
 FROM (
  SELECT player_a_id AS player_id FROM games
  UNION ALL SELECT player_b_id AS player_id FROM games
 ) a WHERE a.player_id IS NOT NULL
)
SELECT jsonb_build_object(
 'scope','ISOLATED_STAGE_ONLY',
 'mode','OBSERVATIONAL_NOT_CAUSAL',
 'invalid_simulated_events',(SELECT count(*) FROM bad_events),
 'invalid_event_ids',(SELECT coalesce(jsonb_agg(id ORDER BY id),'[]'::jsonb) FROM bad_events),
 'direct_match_rows',(SELECT count(*) FROM games),
 'distinct_players_touched_by_invalid_matches',(SELECT count(*) FROM participants),
 'direct_recorded_match_stats',(SELECT count(*) FROM public.court_boss_match_stat_lines s WHERE s.tournament_id IN (SELECT id FROM bad_events)),
 'direct_ranking_points_awards',(SELECT count(*) FROM public.world_ranking_points p WHERE p.tournament_id IN (SELECT id FROM bad_events)),
 'direct_player_titles',(SELECT count(*) FROM bad_events t JOIN public.player_titles pt
    ON pt.tournament_name=t.name AND pt.title_date=t.end_date
    AND pt.origin='game' AND pt.event_type='singles'),
 'participants_with_training_load_state',(SELECT count(*) FROM participants p JOIN public.player_training_load_profiles l ON l.player_id=p.player_id),
 'participants_with_any_injury_history',(SELECT count(DISTINCT p.player_id) FROM participants p JOIN public.injuries i ON i.player_id=p.player_id),
 'injuries_causally_attributed_to_invalid_matches',false,
 'world_state_may_be_repaired_by_selective_deletion',false,
 'independently_restored_backup_verified',false,
 'world_2050_certified',false
) AS side_effect_audit;
COMMIT;
