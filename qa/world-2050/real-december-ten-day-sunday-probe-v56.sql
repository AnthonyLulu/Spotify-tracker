-- ISOLATED STAGE ONLY, rollback-only real world + day simulation.
-- Never execute on production; created under QA not migration.
-- Requires stage source data and no active career, no saves, with
-- exclusive advisory locks for daily and weekly world engine.
-- On 2026-10-10 returned 10 daily commits, 1 real weekly checkpoint,
-- world weekly 1,800 recovered players, 0 duplicate last-day events.
CREATE OR REPLACE FUNCTION cb_e2e_reconstruction_20261010.probe_real_ten_day_week_v9()
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
 d date:='2025-12-01';
 last_date date:='2025-12-11';
 tick jsonb:='{}'::jsonb;
 weekly jsonb:='{}'::jsonb;
 checkpoint jsonb:='{}'::jsonb;
 retry jsonb:='{}'::jsonb;
 outcome jsonb:='{}'::jsonb;
 fail text;
 n_days integer:=0;
 n_checkpoints integer:=0;
 n_commits integer:=0;
 n_other integer:=0;
BEGIN
 IF (SELECT count(*) FROM public.career_state)<>0
    OR (SELECT count(*) FROM public.game_saves)<>0
    OR (SELECT count(*) FROM public.players WHERE career_status='active' AND game_world_rank IS NULL)<>0
    OR (SELECT count(*) FROM public.players WHERE id=1000001 AND data_source='ISOLATED-2025-SYNTHETIC-V1')<>1
    OR NOT pg_catalog.pg_try_advisory_xact_lock(2200261201)
    OR NOT pg_catalog.pg_try_advisory_xact_lock(94832021)
 THEN
   RAISE EXCEPTION 'Stage isolated career/world busy or seed unready; refused';
 END IF;
 BEGIN
  INSERT INTO public.career_state(
   id,player_name,country,career_date,week,singles_rank,doubles_rank,
   points,age,current_ability,potential,form,fitness,morale,fatigue,
   budget,season_year,managed_player_id,career_focus
  )
  SELECT 'demo',p.name,p.country,d,1,2000,2200,
   0,p.age,p.current_ability,p.potential,p.form,p.fitness,p.morale,p.fatigue,
   25000,2025,p.id,p.career_focus
  FROM public.players p WHERE p.id=1000001;
  WHILE d<last_date LOOP
    tick:=public.advance_career_day_v26('{}'::jsonb,'normal',d);
    IF coalesce((tick->>'ok')::boolean,false) IS DISTINCT FROM true
       AND (tick->>'reason'='weekly_checkpoint_required'
           OR coalesce((tick->>'checkpoint_required')::boolean,false)=true)
    THEN
      IF d<>date '2025-12-07' OR n_checkpoints<>0 THEN
        RAISE EXCEPTION 'Unexpected weekly checkpoint date %, response %',d,tick;
      END IF;
      weekly:=public.simulate_world_week(1,d);
      checkpoint:=public.mark_weekly_checkpoint_v22(d);
      IF (checkpoint->>'ok')::boolean IS DISTINCT FROM true THEN
        RAISE EXCEPTION 'Real weekly checkpoint was not persisted: %',checkpoint;
      END IF;
      n_checkpoints:=n_checkpoints+1;
      tick:=public.advance_career_day_v26('{}'::jsonb,'normal',d);
    END IF;
    IF coalesce((tick->>'ok')::boolean,false) IS DISTINCT FROM true THEN
      RAISE EXCEPTION 'Real daily tick blocked on %: %',d,tick;
    END IF;
    IF (tick->>'date')::date IS DISTINCT FROM d+1 THEN
      RAISE EXCEPTION 'Date skipped or repeated %: %',d,tick;
    END IF;
    d:=d+1;
    n_days:=n_days+1;
    IF n_days>10 THEN RAISE EXCEPTION 'Daily probe bounds exceeded'; END IF;
  END LOOP;
  retry:=public.advance_career_day_v26('{}'::jsonb,'normal',date '2025-12-10');
  IF coalesce((retry->>'already_applied')::boolean,false) IS DISTINCT FROM true
  THEN RAISE EXCEPTION 'Last day replay was not idempotent: %',retry; END IF;
  SELECT count(*) INTO n_commits FROM public.career_event_log
  WHERE event_type='daily_tick_commit_v25'
   AND (payload->>'from_date')::date BETWEEN date '2025-12-01' AND date '2025-12-10';
  SELECT count(*) INTO n_other FROM public.career_event_log
  WHERE event_type='daily_tick_commit_v25'
   AND (payload->>'from_date')='2025-12-10';
  IF n_commits<>10 OR n_other<>1 OR n_checkpoints<>1 THEN
    RAISE EXCEPTION 'Unexpected 10-day journal or checkpoint count: %, %, %',
      n_commits,n_other,n_checkpoints;
  END IF;
  outcome:=pg_catalog.jsonb_build_object(
   'ok',true,'rolled_back',true,'start_date','2025-12-01',
   'end_date',d,'days',n_days,'weekly_checkpoints',n_checkpoints,
   'daily_commit_count',n_commits,'last_day_entries',n_other,
   'idempotent_retry',retry->>'already_applied',
   'real_weekly_world',weekly,
   'real_weekly_checkpoint',checkpoint,
   'last_tick',tick
  );
  RAISE EXCEPTION 'CB_E2E_TEN_DAY_FORCE_ROLLBACK';
 EXCEPTION WHEN OTHERS THEN
  GET STACKED DIAGNOSTICS fail=MESSAGE_TEXT;
  IF fail='CB_E2E_TEN_DAY_FORCE_ROLLBACK' THEN RETURN outcome; END IF;
  RETURN pg_catalog.jsonb_build_object('ok',false,'rolled_back',true,
    'last_attempt_date',d,'days_before_failure',n_days,
    'weekly_checkpoints',n_checkpoints,'error',left(fail,900));
 END;
END;
$function$;
REVOKE ALL ON FUNCTION cb_e2e_reconstruction_20261010.probe_real_ten_day_week_v9() FROM PUBLIC,anon,authenticated;
