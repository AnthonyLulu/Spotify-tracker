-- Isolated-stage QA ONLY. No production migration.
-- Never compete with an active world-week batch, and ALWAYS roll back.
CREATE OR REPLACE FUNCTION cb_e2e_reconstruction_20261010.probe_rank_collision_repair_v81()
RETURNS jsonb
LANGUAGE plpgsql SECURITY INVOKER SET search_path TO ''
AS $rank_repair$
DECLARE
 before_duplicates int;
 after_duplicates int;
 after_second_duplicates int;
 unranked_after int;
 retired_ranked_after int;
 official_count_before int;
 official_rank_hash_before text;
 official_count_after int;
 official_rank_hash_after text;
 first_run jsonb;
 second_run jsonb;
 report jsonb:='{}'::jsonb;
 err text;
 started timestamptz:=pg_catalog.clock_timestamp();
BEGIN
 IF EXISTS(SELECT 1 FROM cb_e2e_reconstruction_20261010.world_week_jobs_v1 j
           WHERE j.status='running')
    OR EXISTS(SELECT 1 FROM public.game_saves)
    OR EXISTS(SELECT 1 FROM public.game_save_slots)
    OR EXISTS(SELECT 1 FROM public.career_state)
    OR NOT pg_catalog.pg_try_advisory_xact_lock(94832021)
    OR NOT pg_catalog.pg_try_advisory_xact_lock(94830000)
 THEN
   RETURN pg_catalog.jsonb_build_object(
     'ok',false,'rolled_back',true,
     'blocked_by_active_week_or_user_save',true,
     'model','CB-WORLD-RANK-REPAIR-PROBE-v81');
 END IF;
 SELECT coalesce(sum(n-1),0)::int INTO before_duplicates FROM (
  SELECT count(*)::int n FROM public.players p
  WHERE p.career_status='active' AND p.game_world_rank IS NOT NULL
   AND coalesce(p.data_source,'') NOT ILIKE 'hidden duplicate merged into %'
  GROUP BY p.game_world_rank HAVING count(*)>1
 ) duplicates;
 SELECT count(*)::int,
  md5(coalesce(string_agg(p.id::text||':'||p.ranking::text,'|' ORDER BY p.id),''))
 INTO official_count_before,official_rank_hash_before
 FROM public.players p
 WHERE p.career_status='active' AND p.ranking_current=true
   AND p.ranking IS NOT NULL
   AND coalesce(p.data_source,'') NOT ILIKE 'hidden duplicate merged into %';
 BEGIN
  first_run:=public.refresh_game_world_ranks();
  SELECT coalesce(sum(n-1),0)::int INTO after_duplicates FROM (
   SELECT count(*)::int n FROM public.players p
   WHERE p.career_status='active' AND p.game_world_rank IS NOT NULL
    AND coalesce(p.data_source,'') NOT ILIKE 'hidden duplicate merged into %'
   GROUP BY p.game_world_rank HAVING count(*)>1
  ) duplicates;
  SELECT count(*)::int,
   md5(coalesce(string_agg(p.id::text||':'||p.ranking::text,'|' ORDER BY p.id),''))
  INTO official_count_after,official_rank_hash_after
  FROM public.players p
  WHERE p.career_status='active' AND p.ranking_current=true
    AND p.ranking IS NOT NULL
    AND coalesce(p.data_source,'') NOT ILIKE 'hidden duplicate merged into %';

  second_run:=public.refresh_game_world_ranks();
  SELECT coalesce(sum(n-1),0)::int INTO after_second_duplicates FROM (
   SELECT count(*)::int n FROM public.players p
   WHERE p.career_status='active' AND p.game_world_rank IS NOT NULL
    AND coalesce(p.data_source,'') NOT ILIKE 'hidden duplicate merged into %'
   GROUP BY p.game_world_rank HAVING count(*)>1
  ) duplicates;
  SELECT count(*)::int INTO unranked_after
  FROM public.players p WHERE p.career_status='active'
   AND p.game_world_rank IS NULL
   AND coalesce(p.data_source,'') NOT ILIKE 'hidden duplicate merged into %';
  SELECT count(*)::int INTO retired_ranked_after
  FROM public.players p WHERE p.career_status='retired'
   AND p.game_world_rank IS NOT NULL;

  report:=pg_catalog.jsonb_build_object(
   'ok',before_duplicates>0 AND after_duplicates=0
     AND after_second_duplicates=0 AND unranked_after=0
     AND retired_ranked_after=0
     AND official_count_before=official_count_after
     AND official_rank_hash_before=official_rank_hash_after
     AND coalesce((second_run->>'collision_repaired')::int,-1)=0
     AND coalesce((second_run->>'official_rank_updates')::int,-1)=0,
   'before_duplicates',before_duplicates,
   'after_duplicates',after_duplicates,
   'after_second_duplicates',after_second_duplicates,
   'official_player_count',official_count_after,
   'official_ranks_unchanged',official_rank_hash_before=official_rank_hash_after,
   'unranked_after',unranked_after,
   'retired_ranked_after',retired_ranked_after,
   'first_run',first_run,'second_run',second_run,
   'rolled_back',true,
   'duration_ms',round((extract(epoch FROM pg_catalog.clock_timestamp()-started)*1000)::numeric),
   'model','CB-WORLD-RANK-REPAIR-PROBE-v81');
  RAISE EXCEPTION 'CB_RANK_REPAIR_V81_FORCED_ROLLBACK';
 EXCEPTION WHEN OTHERS THEN
  GET STACKED DIAGNOSTICS err=MESSAGE_TEXT;
  IF err='CB_RANK_REPAIR_V81_FORCED_ROLLBACK' THEN RETURN report; END IF;
  RETURN pg_catalog.jsonb_build_object('ok',false,'rolled_back',true,
   'error',left(err,600),'model','CB-WORLD-RANK-REPAIR-PROBE-v81');
 END;
END;
$rank_repair$;
REVOKE ALL ON FUNCTION cb_e2e_reconstruction_20261010.probe_rank_collision_repair_v81()
FROM PUBLIC,anon,authenticated;
