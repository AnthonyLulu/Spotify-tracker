-- Read-only P0 unified-world coverage gate. Uses the last completed world-singles
-- checkpoint, never assumes a currently running tournament week is complete.
-- Alternative NCAA/Davis/junior systems may have separate evidence requirements.
-- This counts persisted results; no live worlds, user saves or draws are mutated.
BEGIN READ ONLY;
SET LOCAL statement_timeout='15000ms';
WITH bounds AS MATERIALIZED (
 SELECT date '2026-01-04' as from_date,
        max(to_date) AS through_date
 FROM cb_e2e_reconstruction_20261010.world_week_jobs_v1
 WHERE status='completed' AND completed_items=expected_items
), calendar AS MATERIALIZED (
 SELECT t.id,t.circuit,t.category,t.singles,t.doubles
 FROM public.tournaments t CROSS JOIN bounds b
 WHERE coalesce(t.is_active,true)
 AND coalesce(t.end_date,t.start_date)>b.from_date
 AND coalesce(t.end_date,t.start_date)<=b.through_date
), single_results AS MATERIALIZED (
 SELECT DISTINCT w.tournament_id FROM public.world_tournament_simulations w
 JOIN calendar c ON c.id=w.tournament_id WHERE w.winner_id IS NOT NULL
), doubles_results AS MATERIALIZED (
 SELECT DISTINCT w.tournament_id FROM public.world_doubles_tournament_simulations w
 JOIN calendar c ON c.id=w.tournament_id
), coverage AS (
 SELECT
 count(*) FILTER (WHERE c.circuit IN ('ATP','Challenger','ITF') AND c.singles)::int AS mens_singles_planned,
 count(*) FILTER (WHERE c.circuit IN ('ATP','Challenger','ITF') AND c.singles
                  AND sr.tournament_id IS NOT NULL)::int AS mens_singles_persisted,
 count(*) FILTER (WHERE c.circuit IN ('ATP','Challenger','ITF') AND c.doubles)::int AS mens_doubles_planned,
 count(*) FILTER (WHERE c.circuit IN ('ATP','Challenger','ITF') AND c.doubles
                  AND dr.tournament_id IS NOT NULL)::int AS mens_doubles_persisted,
 count(*) FILTER (WHERE c.circuit='Junior' AND c.singles)::int AS junior_singles_planned,
 count(*) FILTER (WHERE c.circuit='Junior' AND c.singles
                  AND sr.tournament_id IS NOT NULL)::int AS junior_singles_world_simulations
 FROM calendar c
 LEFT JOIN single_results sr ON sr.tournament_id=c.id
 LEFT JOIN doubles_results dr ON dr.tournament_id=c.id
)
SELECT jsonb_build_object(
 'environment','isolated_stage_only',
 'period_start',b.from_date,
 'last_completed_singles_checkpoint',b.through_date,
 'mens_singles_planned',c.mens_singles_planned,
 'mens_singles_persisted',c.mens_singles_persisted,
 'mens_doubles_planned',c.mens_doubles_planned,
 'mens_doubles_persisted',c.mens_doubles_persisted,
 'junior_singles_planned',c.junior_singles_planned,
 'junior_singles_world_simulations',c.junior_singles_world_simulations,
 'davis_ties',(
   SELECT count(*) FROM public.davis_ties d
   WHERE d.tie_date>b.from_date AND d.tie_date<=b.through_date),
 'davis_scored_rubbers',(
   SELECT count(*) FROM public.davis_rubbers r JOIN public.davis_ties d ON d.id=r.tie_id
   WHERE d.tie_date>b.from_date AND d.tie_date<=b.through_date
     AND nullif(r.score,'') IS NOT NULL),
 'junior_doubles_scored_matches',(
   SELECT count(*) FROM public.world_junior_doubles_matches r
   JOIN calendar t ON t.id=r.tournament_id WHERE nullif(r.score,'') IS NOT NULL),
 'ncaa_individual_simulations_in_calendar',(
   SELECT count(*) FROM public.ncaa_individual_simulations n
   JOIN calendar t ON t.id=n.tournament_id),
 'world_doubles_gap',c.mens_doubles_planned-c.mens_doubles_persisted,
 'world_singles_only_not_full_unified',true,
 'all_mens_doubles_in_calendar_simulated',
    c.mens_doubles_planned=c.mens_doubles_persisted,
 'cross_circuit_2050_certified',false,
 'real_mobile_save_load_2050_certified',false
) AS multi_circuit_coverage
FROM bounds b CROSS JOIN coverage c;
COMMIT;
