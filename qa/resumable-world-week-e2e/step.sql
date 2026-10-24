-- QA only: one transaction commits one world tournament and its durable cursor.
CREATE OR REPLACE FUNCTION cb_e2e_reconstruction_20261010.step_world_week_v2(p_key text)
RETURNS jsonb LANGUAGE plpgsql SET search_path TO ''
AS $$
DECLARE j record;i record;r jsonb;m int;p int;n int;
BEGIN
 IF NOT pg_catalog.pg_try_advisory_xact_lock(94832021)
 THEN RETURN jsonb_build_object('ok',false,'retryable',true,'reason','busy');END IF;
 IF EXISTS(SELECT 1 FROM public.career_state) OR EXISTS(SELECT 1 FROM public.game_save_slots)
 THEN RETURN jsonb_build_object('ok',false,'reason','stage_not_isolated');END IF;
 SELECT * INTO j FROM cb_e2e_reconstruction_20261010.world_week_jobs_v1 WHERE job_key=p_key FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'reason','job_not_found');END IF;
 IF j.status='completed' THEN RETURN jsonb_build_object('ok',true,'done',true,'already_completed',true,'completed',j.completed_items);END IF;
 SELECT * INTO i FROM cb_e2e_reconstruction_20261010.world_week_items_v1
 WHERE job_key=p_key AND status='pending' ORDER BY seq LIMIT 1 FOR UPDATE;
 IF NOT FOUND THEN
  PERFORM public.refresh_world_rankings(j.to_date);
  PERFORM public.refresh_world_race(j.to_date);
  PERFORM public.refresh_world_nextgen_race(j.to_date);
  UPDATE cb_e2e_reconstruction_20261010.world_week_jobs_v1
   SET status='completed',updated_at=now() WHERE job_key=p_key;
  RETURN jsonb_build_object('ok',true,'done',true,'completed',j.completed_items);
 END IF;
 r:=cb_e2e_reconstruction_20261010.simulate_world_event_batch_fast_v2(array[i.tournament_id]::bigint[],j.to_date);
 IF coalesce((r->>'ok')::boolean,false) IS DISTINCT FROM true
 THEN RAISE EXCEPTION 'World tournament step failed: %',left(r::text,350);END IF;
 SELECT count(*) INTO m FROM public.world_tournament_matches
 WHERE tournament_id=i.tournament_id AND winner_id IS NOT NULL AND coalesce(is_qualifying,false)=false;
 SELECT count(*) INTO p FROM public.world_ranking_points WHERE tournament_id=i.tournament_id;
 IF m<1 OR p<1 OR NOT EXISTS(SELECT 1 FROM public.world_tournament_simulations
   WHERE tournament_id=i.tournament_id AND winner_id IS NOT NULL)
 THEN RAISE EXCEPTION 'Unproven world event completion: %',i.tournament_id;END IF;
 UPDATE cb_e2e_reconstruction_20261010.world_week_items_v1
 SET status='completed',matches_added=m,ranking_rows_added=p,completed_at=now()
 WHERE job_key=p_key AND tournament_id=i.tournament_id;
 n:=j.completed_items+1;
 UPDATE cb_e2e_reconstruction_20261010.world_week_jobs_v1
 SET completed_items=n,updated_at=now() WHERE job_key=p_key;
 RETURN jsonb_build_object('ok',true,'tournament_id',i.tournament_id,
  'matches',m,'point_rows',p,'completed',n,'total',j.expected_items,
  'done',false,'ready_to_finalize',n=j.expected_items);
END $$;
REVOKE ALL ON FUNCTION cb_e2e_reconstruction_20261010.step_world_week_v2(text) FROM PUBLIC,anon,authenticated;
