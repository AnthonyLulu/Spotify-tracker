-- Stage-only, rollback-only proof of the REAL global AI recovery code.
CREATE OR REPLACE FUNCTION cb_e2e_reconstruction_20261010.probe_world_recovery_once_v60()
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path TO ''
AS $cb_probe_recovery$
DECLARE
 first_result jsonb:='{}'::jsonb;
 second_result jsonb:='{}'::jsonb;
 first_fatigue integer;
 second_fatigue integer;
 n integer;
 outcome jsonb:='{}'::jsonb;
 err text;
BEGIN
 IF (SELECT count(*) FROM public.career_state)<>0
    OR (SELECT count(*) FROM public.game_saves)<>0
    OR EXISTS(SELECT 1 FROM public.career_event_log WHERE event_type='world_weekly_recovery_v60')
 THEN RAISE EXCEPTION 'World recovery QA: stage has an active career, save or prior marker'; END IF;
 BEGIN
   UPDATE public.players SET fatigue=80,fitness=60 WHERE id=1;
   IF NOT FOUND THEN RAISE EXCEPTION 'Expected archived junior fixture id=1'; END IF;
   first_result:=public.apply_world_recovery_week(date '2026-01-11',2);
   SELECT fatigue INTO first_fatigue FROM public.players WHERE id=1;
   second_result:=public.apply_world_recovery_week(date '2026-01-11',99);
   SELECT fatigue INTO second_fatigue FROM public.players WHERE id=1;
   SELECT count(*) INTO n FROM public.career_event_log
   WHERE event_type='world_weekly_recovery_v60' AND event_date=date '2026-01-11';
   IF coalesce((first_result->>'already_applied')::boolean,true)<>false
     OR coalesce((first_result->>'updated_players')::integer,0)<1
     OR coalesce((second_result->>'already_applied')::boolean,false)<>true
     OR coalesce((second_result->>'updated_players')::integer,-1)<>0
     OR first_fatigue>=80
     OR first_fatigue<>second_fatigue
     OR n<>1
   THEN RAISE EXCEPTION 'Recovery once audit failed: first %, second %, fatigue % → %, markers %',
     left(first_result::text,250),left(second_result::text,250),first_fatigue,second_fatigue,n;
   END IF;
   outcome:=pg_catalog.jsonb_build_object(
      'ok',true,'rolled_back',true,'model','CB-WORLD-RECOVERY-ONCE-v60',
      'first',first_result,'second',second_result,
      'fatigue_before',80,'fatigue_after_first',first_fatigue,
      'fatigue_after_retry',second_fatigue,'marker_count',n
   );
   RAISE EXCEPTION 'CB_WORLD_RECOVERY_FORCE_ROLLBACK';
 EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS err=MESSAGE_TEXT;
    IF err='CB_WORLD_RECOVERY_FORCE_ROLLBACK' THEN RETURN outcome; END IF;
    RETURN pg_catalog.jsonb_build_object('ok',false,'rolled_back',true,'error',left(err,700));
 END;
END;
$cb_probe_recovery$;
REVOKE ALL ON FUNCTION cb_e2e_reconstruction_20261010.probe_world_recovery_once_v60()
 FROM PUBLIC,anon,authenticated;
