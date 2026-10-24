-- QA only: exactly one world draw, including qualifiers; weekly ranking refresh is deferred.
CREATE OR REPLACE FUNCTION cb_e2e_reconstruction_20261010.simulate_world_event_batch_fast_v2(p_ids bigint[],p_asof date)
RETURNS jsonb LANGUAGE plpgsql SET search_path TO ''
AS $$
DECLARE t record;q jsonb;r jsonb;was_simulated boolean;before_matches int;after_matches int;before_points int;after_points int;
BEGIN
 IF array_length(p_ids,1) IS DISTINCT FROM 1 OR p_asof<date '2026-01-01' OR p_asof>date '2026-12-31'
 THEN RETURN jsonb_build_object('ok',false,'reason','invalid_qa_batch');END IF;
 PERFORM pg_catalog.pg_advisory_xact_lock(94832021);
 SELECT id,name,circuit,category,end_date INTO t FROM public.tournaments WHERE id=p_ids[1];
 IF t.id IS NULL OR t.circuit NOT IN ('ATP','Challenger','ITF') OR t.end_date>p_asof
 THEN RETURN jsonb_build_object('ok',false,'reason','invalid_event');END IF;
 was_simulated:=EXISTS(SELECT 1 FROM public.world_tournament_simulations WHERE tournament_id=t.id);
 IF was_simulated THEN
  RETURN jsonb_build_object('ok',true,'new_events',0,'previously_simulated',1,'tournament_id',t.id);
 END IF;
 IF EXISTS(SELECT 1 FROM public.world_tournament_states WHERE tournament_id=t.id)
  OR EXISTS(SELECT 1 FROM public.world_qualifying_states WHERE tournament_id=t.id)
  OR EXISTS(SELECT 1 FROM public.entries e WHERE e.tournament_id=t.id AND e.status NOT IN ('withdrawn','declined','rejected')
     AND e.player_id IN (SELECT managed_player_id FROM public.career_state WHERE id='demo'))
 THEN RAISE EXCEPTION 'Managed tournament cannot be auto-simulated: %',t.id;END IF;
 SELECT count(*) INTO before_matches FROM public.world_tournament_matches WHERE tournament_id=t.id;
 SELECT count(*) INTO before_points FROM public.world_ranking_points WHERE tournament_id=t.id;
 q:=public.simulate_world_qualifying_full(t.id,t.end_date-7);
 r:=public.simulate_world_knockout_tournament_full(t.id,p_asof);
 IF coalesce((r->>'ok')::boolean,false) IS DISTINCT FROM true
 THEN RAISE EXCEPTION 'World draw failed for tournament %: %',t.id,left(r::text,250);END IF;
 SELECT count(*) INTO after_matches FROM public.world_tournament_matches WHERE tournament_id=t.id;
 SELECT count(*) INTO after_points FROM public.world_ranking_points WHERE tournament_id=t.id;
 RETURN jsonb_build_object('ok',true,'new_events',1,'previously_simulated',0,
  'tournament_id',t.id,'matches_added',after_matches-before_matches,
  'points_rows_added',after_points-before_points,'ranking',jsonb_build_object('deferred_until_week_complete',true));
END $$;
REVOKE ALL ON FUNCTION cb_e2e_reconstruction_20261010.simulate_world_event_batch_fast_v2(bigint[],date) FROM PUBLIC,anon,authenticated;
