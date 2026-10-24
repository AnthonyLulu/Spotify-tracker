-- P0 checkpoint drift triage: do not assume original player rows are missing.
-- READ ONLY in the original protected isolated E2E stage.
BEGIN READ ONLY;
SET LOCAL statement_timeout='18000ms';
WITH c AS (
 SELECT
 count(*) AS checkpoint_players,
 count(p.id) AS still_present,
 count(*) FILTER(WHERE p.id IS NULL) AS original_players_missing,
 count(*) FILTER(WHERE p.id IS NOT NULL AND p.name IS DISTINCT FROM s.name) AS name_drift,
 count(*) FILTER(WHERE p.id IS NOT NULL AND p.country IS DISTINCT FROM s.country) AS country_drift,
 count(*) FILTER(WHERE p.id IS NOT NULL AND p.birth_date IS DISTINCT FROM s.birth_date) AS dob_drift,
 count(*) FILTER(WHERE p.id IS NOT NULL AND p.data_source IS DISTINCT FROM s.data_source) AS provenance_drift,
 count(*) FILTER(WHERE p.id IS NOT NULL AND p.game_world_rank IS DISTINCT FROM s.game_world_rank) AS rank_drift,
 count(*) FILTER(WHERE p.id IS NOT NULL AND p.ranking IS DISTINCT FROM s.ranking) AS official_rank_drift,
 count(*) FILTER(WHERE p.id IS NOT NULL AND p.fitness IS DISTINCT FROM s.fitness) AS fitness_drift,
 count(*) FILTER(WHERE p.id IS NOT NULL AND p.fatigue IS DISTINCT FROM s.fatigue) AS fatigue_drift,
 count(*) FILTER(WHERE p.id IS NOT NULL AND p.form IS DISTINCT FROM s.form) AS form_drift
 FROM cb_e2e_checkpoint_20261010.players s
 LEFT JOIN public.players p ON p.id=s.id
), affected AS (
 SELECT DISTINCT x.player_id FROM (
  SELECT m.player_a_id AS player_id FROM public.world_tournament_matches m
  WHERE m.tournament_id IN (496,654,491,285,366,228)
  UNION ALL
  SELECT m.player_b_id AS player_id FROM public.world_tournament_matches m
  WHERE m.tournament_id IN (496,654,491,285,366,228)
 ) x WHERE x.player_id IS NOT NULL
)
SELECT jsonb_build_object(
 'checkpoint','cb_e2e_checkpoint_20261010.players',
 'checkpoint_players',c.checkpoint_players,
 'original_players_still_present',c.still_present,
 'original_players_missing',c.original_players_missing,
 'name_drift',c.name_drift,'country_drift',c.country_drift,
 'date_of_birth_drift',c.dob_drift,'provenance_drift',c.provenance_drift,
 'world_rank_drift',c.rank_drift,'official_rank_drift',c.official_rank_drift,
 'fitness_drift',c.fitness_drift,'fatigue_drift',c.fatigue_drift,'form_drift',c.form_drift,
 'cancelled_event_distinct_participants',(SELECT count(*) FROM affected),
 'participants_with_original_checkpoint',(SELECT count(*) FROM affected a JOIN cb_e2e_checkpoint_20261010.players p ON p.id=a.player_id),
 'safe_to_restore_individual_rows',false,
 'backup_independent',false,
 'world_2050_certified',false
) AS checkpoint_drift_receipt FROM c;
COMMIT;
