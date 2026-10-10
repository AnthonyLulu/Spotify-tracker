-- ISOLATED STAGE ONLY; no production migration.
-- Real World + managed daily engine, 2025-12-31 through 2026-01-04.
-- Final exception forces full game-state rollback; errors also rollback.
-- This intentionally does NOT fake the weekly world API's full simulation.
CREATE OR REPLACE FUNCTION cb_e2e_reconstruction_20261010.probe_jan2026_multiday_v58()
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path TO ''
AS $cb_probe_jan_multiday$
DECLARE
  r jsonb:='{}'::jsonb;
  x jsonb:='{}'::jsonb;
  first_tick jsonb:='{}'::jsonb;
  last_tick jsonb:='{}'::jsonb;
  boundary jsonb:='{}'::jsonb;
  dates jsonb:='[]'::jsonb;
  audit jsonb:='{}'::jsonb;
  report jsonb:='{}'::jsonb;
  started_at timestamptz:=pg_catalog.clock_timestamp();
  d date;
  current_date_in_game date;
  n integer;
  err text;
BEGIN
 IF (SELECT count(*) FROM public.career_state)<>0 OR
    (SELECT count(*) FROM public.game_saves)<>0 OR
    (SELECT count(*) FROM public.newgen_name_reference)<>0 OR
    (SELECT count(*) FROM public.career_event_log)<>0 OR
    (SELECT count(*) FROM public.players WHERE career_status='active' AND game_world_rank IS NULL)<>0
 THEN RAISE EXCEPTION 'Stage is not exclusively available for real daily replay'; END IF;
 BEGIN
   INSERT INTO public.newgen_name_reference(
     country,kind,value,popularity_rank,gender,source,source_url,license
   )
   SELECT country,kind,value,popularity_rank,gender,source,null::text,license
   FROM cb_e2e_reconstruction_20261010.licensed_name_seed;
   PERFORM public.refresh_newgen_name_parts();
   INSERT INTO public.career_state(
     id,player_name,country,career_date,week,singles_rank,doubles_rank,
     points,age,current_ability,potential,form,fitness,morale,fatigue,
     budget,season_year,managed_player_id,career_focus
   )
   SELECT 'demo',p.name,p.country,date '2025-12-31',5,2000,2200,
     0,p.age,p.current_ability,p.potential,p.form,p.fitness,p.morale,p.fatigue,
     25000,2025,p.id,p.career_focus
   FROM public.players p WHERE p.id=1000001;
   r:=public.rollover_season_daily_v22(2026);
   IF coalesce((r->>'ok')::boolean,false) IS DISTINCT FROM true THEN
     RAISE EXCEPTION 'Actual yearly rollover failed: %',left(r::text,500);
   END IF;
   -- EXACT real daily API RPC, not a test stub. Last tick Jan 4, the
   -- first Sunday; the following Jan 4->5 attempt must stop for weekly.
   FOR d IN SELECT pg_catalog.generate_series(date '2025-12-31',date '2026-01-03','1 day'::interval)::date LOOP
     x:=public.advance_career_day_v26('{}'::jsonb,'normal',d);
     IF coalesce((x->>'ok')::boolean,false) IS DISTINCT FROM true
        OR (x->>'date')::date<>d+1
        OR coalesce((x->>'already_applied')::boolean,false)=true
     THEN RAISE EXCEPTION 'Unexpected real day tick %: %',d,left(x::text,450); END IF;
     IF jsonb_array_length(coalesce(x->'training','[]'::jsonb))<1
     THEN RAISE EXCEPTION 'Managed training missing for day %',d+1; END IF;
     IF d=date '2025-12-31' THEN first_tick:=x; END IF;
     last_tick:=x;
     x:=public.advance_career_day_v26('{}'::jsonb,'normal',d);
     IF coalesce((x->>'already_applied')::boolean,false) IS DISTINCT FROM true
     THEN RAISE EXCEPTION 'Retry doubled the real daily tick %: %',d,left(x::text,350); END IF;
     dates:=dates||pg_catalog.jsonb_build_array(d+1);
   END LOOP;
   SELECT career_date INTO current_date_in_game FROM public.career_state WHERE id='demo';
   IF current_date_in_game<>date '2026-01-04' THEN
      RAISE EXCEPTION 'Real daily clock drifted to %',current_date_in_game;
   END IF;
   boundary:=public.advance_career_day_v26('{}'::jsonb,'normal',date '2026-01-04');
   IF coalesce((boundary->>'ok')::boolean,false)=true
      OR boundary->>'reason'<>'weekly_checkpoint_required'
      OR (boundary->>'checkpoint_date')::date<>date '2026-01-04'
   THEN RAISE EXCEPTION 'Sunday weekly checkpoint was bypassed: %',left(boundary::text,400);
   END IF;
   SELECT count(*) INTO n FROM public.career_event_log
   WHERE event_type='daily_tick_commit_v25'
     AND (payload->>'from_date')::date BETWEEN date '2025-12-31' AND date '2026-01-03';
   IF n<>4 THEN RAISE EXCEPTION 'Expected 4 unique daily commits, got %',n; END IF;
   audit:=public.world_integrity_guard_v18(date '2026-01-04');
   IF coalesce((audit->>'ok')::boolean,false) IS DISTINCT FROM true
   THEN RAISE EXCEPTION 'Actual global guard not green at Jan 4: %',left(audit::text,500); END IF;
   report:=pg_catalog.jsonb_build_object(
     'ok',true,'rolled_back',true,'model','CB-JAN-2026-REAL-DAILY-v58',
     'start','2025-12-31','finish',current_date_in_game,
     'ticks',4,'already_applied_retries',4,'distinct_commits',n,
     'dates',dates,'sunday_checkpoint',boundary->>'checkpoint_date',
     'weekly_not_faked',true,'world_guard_ok',audit->'ok',
     'adult_players',audit->'active_adults',
     'junior_singles',r->'newgens'->'junior_display_pool',
     'junior_doubles',r->'newgens'->'junior_doubles_pool',
     'first_training',jsonb_array_length(first_tick->'training'),
     'last_training',jsonb_array_length(last_tick->'training'),
     'elapsed_ms',EXTRACT(epoch FROM pg_catalog.clock_timestamp()-started_at)*1000
   );
   RAISE EXCEPTION 'CB_REAL_MULTIDAY_ROLLBACK';
 EXCEPTION WHEN OTHERS THEN
   GET STACKED DIAGNOSTICS err=MESSAGE_TEXT;
   IF err='CB_REAL_MULTIDAY_ROLLBACK' THEN RETURN report; END IF;
   RETURN pg_catalog.jsonb_build_object(
     'ok',false,'rolled_back',true,'error',left(err,950),
     'partial_dates',dates,'elapsed_ms',
     EXTRACT(epoch FROM pg_catalog.clock_timestamp()-started_at)*1000
   );
 END;
END;
$cb_probe_jan_multiday$;
REVOKE ALL ON FUNCTION cb_e2e_reconstruction_20261010.probe_jan2026_multiday_v58()
 FROM PUBLIC,anon,authenticated;
