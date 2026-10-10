-- STRICTLY isolated staging. This is an opt-in procedure, not a migration.
-- Call ONLY once the v81 forced-rollback validation succeeded, no week running
-- and no user saves/careers exist. Refuse rather than waiting on lock.
CREATE OR REPLACE FUNCTION cb_e2e_reconstruction_20261010.commit_rank_repair_stage_v83()
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path TO ''
AS $cb_stage_repair$
DECLARE
 before_dupes int;
 after_dupes int;
 unranked int;
 retired_ranked int;
 before_official_hash text;
 after_official_hash text;
 official_misranked int;
 first_receipt jsonb;
 retry_receipt jsonb;
 current_base jsonb;
BEGIN
 IF NOT EXISTS (SELECT 1 FROM cb_e2e_reconstruction_20261010.world_week_jobs_v1 WHERE status='completed')
   OR EXISTS (SELECT 1 FROM cb_e2e_reconstruction_20261010.world_week_jobs_v1 WHERE status='running')
   OR EXISTS (SELECT 1 FROM public.game_saves)
   OR EXISTS (SELECT 1 FROM public.game_save_slots)
   OR EXISTS (SELECT 1 FROM public.career_state)
   OR NOT pg_catalog.pg_try_advisory_xact_lock(94832021)
   OR NOT pg_catalog.pg_try_advisory_xact_lock(94830000)
 THEN
    RETURN pg_catalog.jsonb_build_object('ok',false,'reason','stage_busy_or_has_saves','committed',false);
 END IF;
 SELECT coalesce(sum(n-1),0)::int INTO before_dupes FROM (
   SELECT count(*)::int n FROM public.players p
   WHERE p.career_status='active' AND p.game_world_rank IS NOT NULL
   AND coalesce(p.data_source,'') NOT ILIKE 'hidden duplicate merged into %'
   GROUP BY p.game_world_rank HAVING count(*)>1
 ) d;
 SELECT pg_catalog.md5(coalesce(pg_catalog.string_agg(p.id::text||':'||p.ranking::text,'|' ORDER BY p.id),''))
 INTO before_official_hash
 FROM public.players p WHERE p.career_status='active'
 AND p.ranking_current=true AND p.ranking IS NOT NULL
 AND coalesce(p.data_source,'') NOT ILIKE 'hidden duplicate merged into %';

 first_receipt:=public.refresh_game_world_ranks();
 retry_receipt:=public.refresh_game_world_ranks();

 SELECT coalesce(sum(n-1),0)::int INTO after_dupes FROM (
   SELECT count(*)::int n FROM public.players p
   WHERE p.career_status='active' AND p.game_world_rank IS NOT NULL
   AND coalesce(p.data_source,'') NOT ILIKE 'hidden duplicate merged into %'
   GROUP BY p.game_world_rank HAVING count(*)>1
 ) d;
 SELECT pg_catalog.md5(coalesce(pg_catalog.string_agg(p.id::text||':'||p.ranking::text,'|' ORDER BY p.id),''))
 INTO after_official_hash
 FROM public.players p WHERE p.career_status='active'
 AND p.ranking_current=true AND p.ranking IS NOT NULL
 AND coalesce(p.data_source,'') NOT ILIKE 'hidden duplicate merged into %';
 SELECT count(*)::int INTO unranked FROM public.players
 WHERE career_status='active' AND game_world_rank IS NULL
 AND coalesce(data_source,'') NOT ILIKE 'hidden duplicate merged into %';
 SELECT count(*)::int INTO official_misranked FROM public.players
 WHERE career_status='active' AND ranking_current=true AND ranking IS NOT NULL
 AND game_world_rank IS DISTINCT FROM ranking;
 SELECT count(*)::int INTO retired_ranked FROM public.players
 WHERE career_status='retired' AND game_world_rank IS NOT NULL;
 current_base:=public.living_world_integrity_audit_v16(date '2026-01-18');

 IF after_dupes<>0 OR before_official_hash IS DISTINCT FROM after_official_hash
 OR unranked<>0 OR official_misranked<>0 OR retired_ranked<>0
 OR coalesce((retry_receipt->>'collision_repaired')::int,-1)<>0
 OR coalesce((retry_receipt->>'official_rank_updates')::int,-1)<>0
 OR NOT coalesce((current_base->>'ok')::boolean,false)
 THEN
  RAISE EXCEPTION 'staging world-rank repair failed invariant: before %, after %, unranked %, official_misranked %, retired %',
    before_dupes,after_dupes,unranked,official_misranked,retired_ranked;
 END IF;
 RETURN pg_catalog.jsonb_build_object(
 'ok',true,'committed',true,'scope','isolated_staging',
 'before_duplicate_ranks',before_dupes,
 'after_duplicate_ranks',after_dupes,
 'official_rankings_unchanged',true,
 'official_game_rank_mismatches',official_misranked,
 'active_unranked',unranked,
 'retired_with_rank',retired_ranked,
 'first_pass',first_receipt,
 'second_pass',retry_receipt,
 'nested_integrity_ok',(current_base->>'ok')::boolean,
 'model','CB-STAGE-WORLD-RANK-REPAIR-v83');
END
$cb_stage_repair$;
REVOKE ALL ON FUNCTION cb_e2e_reconstruction_20261010.commit_rank_repair_stage_v83()
FROM PUBLIC,anon,authenticated;
