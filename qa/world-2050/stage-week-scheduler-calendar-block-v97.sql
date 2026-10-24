-- P0 2026-10-24 staging-only fail-closed calendar eligibility filter v97.
-- No production deployment and NO DELETE of contaminated results.
-- Existing weeks with cancelled event effects remain invalid until restored/replayed.
BEGIN;
SET LOCAL statement_timeout='15000ms';
DO $stage_only$
BEGIN
 IF to_regclass('cb_e2e_checkpoint_20261010.players') IS NULL
    OR to_regclass('cb_e2e_reconstruction_20261010.world_week_jobs_v1') IS NULL
 THEN
  RAISE EXCEPTION 'Not the existing isolated E2E staging checkpoint';
 END IF;
 IF EXISTS (SELECT 1 FROM public.career_state)
    OR EXISTS (SELECT 1 FROM public.game_saves)
    OR EXISTS (SELECT 1 FROM public.game_save_slots)
 THEN
  RAISE EXCEPTION 'Cannot mutate stage functions with active careers or saves';
 END IF;
END
$stage_only$;
CREATE OR REPLACE FUNCTION cb_e2e_reconstruction_20261010.begin_world_week_v2(p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE v_key text; v_existing boolean; v_count int; v_completed int;
BEGIN
 IF p_from<date '2026-01-04' OR p_to>date '2026-12-31'
   OR p_to-p_from<>7 OR extract(isodow from p_from)::int<>7
 THEN
   RETURN pg_catalog.jsonb_build_object('ok',false,'reason','invalid_QA_window');
 END IF;
 IF p_from>date '2026-01-04' AND NOT EXISTS(SELECT 1 FROM cb_e2e_reconstruction_20261010.world_week_jobs_v1 prior WHERE prior.to_date=p_from AND prior.status='completed') THEN RETURN pg_catalog.jsonb_build_object('ok',false,'reason','previous_week_not_complete'); END IF;
 IF EXISTS(SELECT 1 FROM public.career_state)
   OR EXISTS(SELECT 1 FROM public.game_saves)
   OR EXISTS(SELECT 1 FROM public.game_save_slots)
 THEN RETURN pg_catalog.jsonb_build_object('ok',false,'reason','stage_session_not_isolated');END IF;
 IF NOT pg_catalog.pg_try_advisory_xact_lock(94832021)
 THEN RETURN pg_catalog.jsonb_build_object('ok',false,'reason','world_engine_busy');END IF;
 v_key:='WORLD-SINGLES:'||p_from::text||':'||p_to::text;
 SELECT true INTO v_existing FROM cb_e2e_reconstruction_20261010.world_week_jobs_v1 j WHERE j.job_key=v_key FOR UPDATE;
 IF NOT coalesce(v_existing,false) THEN
   INSERT INTO cb_e2e_reconstruction_20261010.world_week_jobs_v1(job_key,from_date,to_date)
    VALUES(v_key,p_from,p_to);
   INSERT INTO cb_e2e_reconstruction_20261010.world_week_items_v1(job_key,tournament_id,seq)
   SELECT v_key,t.id,pg_catalog.row_number() over(order by t.end_date,t.id)::int
   FROM public.tournaments t
   JOIN public.tournament_format_rules fr ON fr.circuit=t.circuit AND fr.category=t.category
      AND fr.main_draw_size=coalesce(t.singles_draw_size,t.draw_size)
   WHERE t.singles AND coalesce(t.is_active,true)
     AND coalesce(t.end_date,t.start_date)>p_from
     AND coalesce(t.end_date,t.start_date)<=p_to
     AND t.circuit IN ('ATP','Challenger','ITF')
     AND t.name !~* '(cancelled|canceled|postponed|abandoned|annul[ée])'
     AND t.category NOT IN ('United Cup','Laver Cup','Davis Cup','Junior Davis Cup')
     AND fr.format_type='knockout'
     AND NOT EXISTS(SELECT 1 FROM public.world_tournament_states ws WHERE ws.tournament_id=t.id)
     AND NOT EXISTS(SELECT 1 FROM public.world_qualifying_states wq WHERE wq.tournament_id=t.id)
   ON CONFLICT DO NOTHING;
   UPDATE cb_e2e_reconstruction_20261010.world_week_jobs_v1 j
      SET expected_items=(SELECT count(*) FROM cb_e2e_reconstruction_20261010.world_week_items_v1 i WHERE i.job_key=v_key)
   WHERE j.job_key=v_key;
 END IF;
 SELECT expected_items,completed_items INTO v_count,v_completed
 FROM cb_e2e_reconstruction_20261010.world_week_jobs_v1 WHERE job_key=v_key;
 RETURN pg_catalog.jsonb_build_object('ok',true,'job_key',v_key,'expected',v_count,'completed',v_completed,'existing',coalesce(v_existing,false));
END;
$function$

CREATE OR REPLACE FUNCTION cb_e2e_reconstruction_20261010.step_world_week_v2(p_key text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare j record; item record; r jsonb; n integer; m integer; pt integer; rank_repair jsonb; rank_integrity jsonb;
begin
 -- Fail closed before any mutations, including for already-started jobs.
 if exists (
   select 1
   from cb_e2e_reconstruction_20261010.world_week_items_v1 i
   join public.tournaments t on t.id=i.tournament_id
   where i.job_key=p_key
     and (coalesce(t.is_active,false)=false
          or t.name ~* '(cancelled|canceled|postponed|abandoned|annul[ée])')
 ) then
   return pg_catalog.jsonb_build_object(
     'ok',false,'reason','invalid_calendar_events',
     'calendar_semantics_ok',false,
     'certifies_full_unified_week',false
   );
 end if;
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

COMMIT;
-- Minimal proof: do NOT process further contaminated events.
SELECT cb_e2e_reconstruction_20261010.step_world_week_v2(
 'WORLD-SINGLES:2026-03-22:2026-03-29'
) AS cancelled_calendar_blocked;
