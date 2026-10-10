CREATE OR REPLACE FUNCTION cb_e2e_reconstruction_20261010.step_world_week_v2(p_key text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare j record; item record; r jsonb; n integer; m integer; pt integer; rank_repair jsonb; rank_integrity jsonb;
begin
 if not pg_catalog.pg_try_advisory_xact_lock(94832021) then
   return pg_catalog.jsonb_build_object('ok',false,'retryable',true,'reason','busy');
 end if;
 if exists(select 1 from public.career_state) or exists(select 1 from public.game_save_slots) then
   return pg_catalog.jsonb_build_object('ok',false,'reason','stage_not_isolated');
 end if;
 select * into j from cb_e2e_reconstruction_20261010.world_week_jobs_v1 where job_key=p_key for update;
 if not found then return pg_catalog.jsonb_build_object('ok',false,'reason','unknown_job');end if;
 if j.status='completed' then return pg_catalog.jsonb_build_object('ok',true,'done',true,'already_completed',true,'completed',j.completed_items);end if;
 select * into item from cb_e2e_reconstruction_20261010.world_week_items_v1
 where job_key=p_key and status='pending' order by seq limit 1 for update;
 if not found then
   -- Finish the exact same ATP ranking refresh, then repair depth-only world
   -- rank collisions atomically BEFORE marking the weekly job completed.
   -- The top-level world guard ignored nested duplicate_rank failures.
   -- This staging test explicitly checks the nested guard and refuses to
   -- certify the week if any duplicate or official rank mismatch persists.
   IF NOT pg_catalog.pg_try_advisory_xact_lock(94830000) THEN
     RAISE EXCEPTION 'week finalization rank-repair lock busy';
   END IF;
   perform public.refresh_world_rankings(j.to_date);
   rank_repair:=public.refresh_game_world_ranks();
   rank_integrity:=public.living_world_integrity_audit_v16(j.to_date);
   IF coalesce((rank_integrity->>'ok')::boolean,false) IS DISTINCT FROM true
      OR coalesce((rank_integrity->>'duplicate_active_world_ranks')::int,-1)<>0
      OR EXISTS(
        SELECT 1 FROM public.players p
        WHERE p.career_status='active' AND p.ranking_current=true
          AND p.ranking IS NOT NULL AND p.game_world_rank IS DISTINCT FROM p.ranking
      )
   THEN
     RAISE EXCEPTION 'world-week rank integrity red after recovery: %',left(rank_integrity::text,600);
   END IF;
   perform public.refresh_world_race(j.to_date);
   perform public.refresh_world_nextgen_race(j.to_date);
   update cb_e2e_reconstruction_20261010.world_week_jobs_v1
   set status='completed',updated_at=now() where job_key=p_key;
   return pg_catalog.jsonb_build_object('ok',true,'done',true,'completed',j.completed_items,'rank_repair',rank_repair,'nested_integrity_ok',true);
 end if;
 r:=cb_e2e_reconstruction_20261010.simulate_world_event_batch_fast_v2(array[item.tournament_id]::bigint[],j.to_date);
 if coalesce((r->>'ok')::boolean,false) is distinct from true then
   raise exception 'world event failed: %',left(r::text,400);
 end if;
 select count(*) into m from public.world_tournament_matches where tournament_id=item.tournament_id and winner_id is not null and coalesce(is_qualifying,false)=false;
 select count(*) into pt from public.world_ranking_points where tournament_id=item.tournament_id;
 if m<1 or pt<1 or not exists(select 1 from public.world_tournament_simulations where tournament_id=item.tournament_id and winner_id is not null)
 then raise exception 'unverified tournament result: %',item.tournament_id;end if;
 update cb_e2e_reconstruction_20261010.world_week_items_v1 set status='completed',matches_added=m,ranking_rows_added=pt,completed_at=now()
 where job_key=p_key and tournament_id=item.tournament_id;
 n:=j.completed_items+1;
 update cb_e2e_reconstruction_20261010.world_week_jobs_v1
 set completed_items=n,status='running',updated_at=now() where job_key=p_key;
 return pg_catalog.jsonb_build_object('ok',true,'tournament_id',item.tournament_id,'matches',m,'point_rows',pt,'completed',n,'total',j.expected_items,'done',n=j.expected_items);
end
$function$
;
REVOKE ALL ON FUNCTION cb_e2e_reconstruction_20261010.step_world_week_v2(text) FROM PUBLIC,anon,authenticated;
