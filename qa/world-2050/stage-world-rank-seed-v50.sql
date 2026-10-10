-- ISOLATED E2E ONLY: manually reconstruct the 2025 supplemental rank seed.
-- DO NOT add this file to supabase/migrations; it is NOT a production migration.
-- Preconditions: existing 85-table checkpoint, no game saves/careers,
-- exactly 5,375 archived contiguous world ranks, plus exactly 26,456 new
-- stage-only ATP/synthetic profiles without game_world_rank.
DO $cb_e2e_rank_guard$
BEGIN
 IF (SELECT count(*) FROM public.career_state)<>0
    OR (SELECT count(*) FROM public.game_saves)<>0
    OR (SELECT count(*) FROM public.players p WHERE p.career_status='active'
          AND p.game_world_rank IS NULL
          AND EXISTS(SELECT 1 FROM cb_e2e_checkpoint_20261010.players c WHERE c.id=p.id))<>0
    OR (SELECT count(*) FROM public.players p WHERE p.career_status='active'
          AND p.game_world_rank IS NULL
          AND p.data_source NOT IN ('ISOLATED-ATP-2025-12-01-CC-BY-NC-SA-4.0','ISOLATED-2025-SYNTHETIC-V1'))<>0
    OR (SELECT count(*) FROM public.players WHERE career_status='active' AND game_world_rank IS NULL)<>26456
    OR (SELECT count(*) FROM public.players WHERE career_status='active' AND game_world_rank IS NOT NULL)<>5375
    OR (SELECT count(DISTINCT game_world_rank) FROM public.players WHERE career_status='active')<>5375
    OR (SELECT min(game_world_rank) FROM public.players WHERE career_status='active')<>1
    OR (SELECT max(game_world_rank) FROM public.players WHERE career_status='active')<>5375
    OR to_regclass('cb_e2e_reconstruction_20261010.world_rank_seed_plan_v1') IS NOT NULL
 THEN RAISE EXCEPTION 'Unsafe stage rank seed preflight: inputs, ranks or users have changed'; END IF;
END $cb_e2e_rank_guard$;

CREATE TABLE cb_e2e_reconstruction_20261010.world_rank_seed_plan_v1 AS
WITH pending AS (
 SELECT id AS player_id, data_source, ranking AS atp_reference_rank,
        coalesce(ranking_current,false) AS imported_marked_official,
        row_number() over (
          ORDER BY CASE WHEN data_source='ISOLATED-ATP-2025-12-01-CC-BY-NC-SA-4.0'
                        THEN 0 ELSE 1 END,
                   source_ranking ASC NULLS LAST,
                   itf_ranking ASC NULLS LAST,
                   junior_ranking ASC NULLS LAST,
                   ncaa_rank ASC NULLS LAST, id
        )::integer AS rank_offset
 FROM public.players p
 WHERE p.career_status='active' AND p.game_world_rank IS NULL
   AND p.data_source IN ('ISOLATED-ATP-2025-12-01-CC-BY-NC-SA-4.0','ISOLATED-2025-SYNTHETIC-V1')
   AND NOT EXISTS (SELECT 1 FROM cb_e2e_checkpoint_20261010.players c WHERE c.id=p.id)
)
SELECT player_id, 5375 + rank_offset AS assigned_rank,
       data_source,atp_reference_rank,imported_marked_official
FROM pending;
ALTER TABLE cb_e2e_reconstruction_20261010.world_rank_seed_plan_v1
 ADD CONSTRAINT stage_world_rank_seed_player_pk PRIMARY KEY(player_id);
ALTER TABLE cb_e2e_reconstruction_20261010.world_rank_seed_plan_v1
 ADD CONSTRAINT stage_world_rank_seed_assigned_unique UNIQUE(assigned_rank);
REVOKE ALL ON TABLE cb_e2e_reconstruction_20261010.world_rank_seed_plan_v1 FROM PUBLIC,anon,authenticated;

DO $cb_validate$
BEGIN
 IF (SELECT count(*) FROM cb_e2e_reconstruction_20261010.world_rank_seed_plan_v1)<>26456
    OR (SELECT min(assigned_rank) FROM cb_e2e_reconstruction_20261010.world_rank_seed_plan_v1)<>5376
    OR (SELECT max(assigned_rank) FROM cb_e2e_reconstruction_20261010.world_rank_seed_plan_v1)<>31831
    OR (SELECT count(*) FROM cb_e2e_reconstruction_20261010.world_rank_seed_plan_v1 WHERE imported_marked_official)<>2021
 THEN RAISE EXCEPTION 'Stage rank plan not consistent with frozen seed'; END IF;
END $cb_validate$;

-- Resumable bounded writes, never more than 1,500 rows in one call.
CREATE OR REPLACE FUNCTION cb_e2e_reconstruction_20261010.apply_world_rank_seed_batch_v1(p_limit integer DEFAULT 1000)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE changed_count integer:=0; remaining_count integer:=0; collision_count integer:=0;
BEGIN
 IF p_limit IS NULL OR p_limit<1 OR p_limit>1500 THEN
   RAISE EXCEPTION 'Stage rank batch size outside safe range (1..1500)';
 END IF;
 IF (SELECT count(*) FROM public.career_state)<>0
    OR (SELECT count(*) FROM public.game_saves)<>0
    OR (SELECT count(*) FROM cb_e2e_reconstruction_20261010.world_rank_seed_plan_v1)<>26456
 THEN RAISE EXCEPTION 'Stage rank batch refused: missing seed plan, active career or save'; END IF;
 SELECT count(*) INTO collision_count
 FROM cb_e2e_reconstruction_20261010.world_rank_seed_plan_v1 plan
 JOIN public.players p ON p.game_world_rank=plan.assigned_rank
 WHERE p.id<>plan.player_id;
 IF collision_count<>0 THEN
   RAISE EXCEPTION 'Reserved stage rank collision with another player: %',collision_count;
 END IF;
 WITH batch AS (
   SELECT plan.player_id,plan.assigned_rank,plan.data_source
   FROM cb_e2e_reconstruction_20261010.world_rank_seed_plan_v1 plan
   JOIN public.players p ON p.id=plan.player_id
   WHERE p.game_world_rank IS NULL AND p.career_status='active' AND p.data_source=plan.data_source
   ORDER BY plan.assigned_rank LIMIT p_limit
 ), applied AS (
   UPDATE public.players p
   SET game_world_rank=b.assigned_rank,
       -- Isolated supplemental ATP snapshot has tied and colliding source ranks.
       -- Keep p.ranking unchanged as the reference; do not mirror it into the
       -- unique in-game ranking on subsequent refreshes.
       ranking_current=CASE WHEN b.data_source='ISOLATED-ATP-2025-12-01-CC-BY-NC-SA-4.0'
                            THEN false ELSE p.ranking_current END
   FROM batch b WHERE p.id=b.player_id AND p.game_world_rank IS NULL
   RETURNING p.id
 )
 SELECT count(*) INTO changed_count FROM applied;
 SELECT count(*) INTO remaining_count
 FROM cb_e2e_reconstruction_20261010.world_rank_seed_plan_v1 plan
 JOIN public.players p ON p.id=plan.player_id WHERE p.game_world_rank IS NULL;
 RETURN pg_catalog.jsonb_build_object('ok',true,'batch_updated',changed_count,
   'remaining',remaining_count,'complete',remaining_count=0,'stage_only',true);
END;
$function$;
REVOKE ALL ON FUNCTION cb_e2e_reconstruction_20261010.apply_world_rank_seed_batch_v1(integer) FROM PUBLIC,anon,authenticated;

-- Intentional: do not automatically call the batch writer from this script.
-- A trusted stage operator can execute:
-- SELECT cb_e2e_reconstruction_20261010.apply_world_rank_seed_batch_v1(1500);
-- until it returns complete=true, under a strictly serial test schedule.
