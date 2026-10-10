-- STAGING ONLY: real unified ATP/Challenger/ITF/doubles/junior/etc engine.
-- Self-rolled-back subtransaction: absolutely no durable game mutations.
-- Forbidden in production. No cloned game_save data touched.
CREATE OR REPLACE FUNCTION cb_e2e_reconstruction_20261010.probe_real_unified_world_window_v1(
 p_from date DEFAULT '2026-01-04', p_to date DEFAULT '2026-01-06'
)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path TO ''
AS $cb_unified_probe$
DECLARE
  outcome jsonb:='{}'::jsonb;
  circuit jsonb:='{}'::jsonb;
  original int;
  after_count int;
  won int;
  scored int;
  unplayed int;
  invalid int;
  effects jsonb:='{}'::jsonb;
  err text;
  started timestamptz:=pg_catalog.clock_timestamp();
BEGIN
 IF p_from<'2026-01-01' OR p_to>'2026-01-15' OR p_to<=p_from OR p_to-p_from>8
   OR (SELECT count(*) FROM public.career_state)<>0
   OR (SELECT count(*) FROM public.game_saves)<>0
   OR (SELECT count(*) FROM public.career_event_log)<>0
   OR NOT pg_catalog.pg_try_advisory_xact_lock(2200261201)
   OR NOT pg_catalog.pg_try_advisory_xact_lock(94832021)
   OR NOT pg_catalog.pg_try_advisory_xact_lock(94832030)
 THEN RAISE EXCEPTION 'QA-only isolated world window refused or staging busy'; END IF;
 SELECT count(*) INTO original FROM public.world_tournament_matches;
 BEGIN
   circuit:=public.run_unified_circuit_window(p_from,p_to);
   SELECT count(*) INTO after_count FROM public.world_tournament_matches;
   SELECT count(*) INTO won FROM public.world_tournament_matches
     WHERE winner_id IS NOT NULL AND simulated_on BETWEEN p_from AND p_to;
   SELECT count(*) INTO scored FROM public.world_tournament_matches
     WHERE winner_id IS NOT NULL AND coalesce(length(trim(score)),0)>0
       AND simulated_on BETWEEN p_from AND p_to;
   SELECT count(*) INTO unplayed FROM public.world_tournament_matches
     WHERE winner_id IS NULL AND simulated_on BETWEEN p_from AND p_to;
   SELECT count(*) INTO invalid FROM public.world_tournament_matches
     WHERE simulated_on BETWEEN p_from AND p_to
       AND winner_id IS NOT NULL AND (
         loser_id IS NULL OR winner_id=loser_id OR
         winner_id NOT IN (player_a_id,player_b_id) OR
         loser_id NOT IN (player_a_id,player_b_id));
   effects:=pg_catalog.jsonb_build_object(
     'inserted_matches',after_count-original,
     'played_matches',won,'scored_matches',scored,'unplayed_matches',unplayed,'invalid_results',invalid);
   outcome:=pg_catalog.jsonb_build_object(
     'ok',coalesce((circuit->>'ok')::boolean,false) AND invalid=0 AND won>0 AND scored=won,
     'world_matches_evidence_ready',won>0 AND scored=won AND invalid=0,
     'rolled_back',true,
     'from',p_from,'to',p_to,'engine','run_unified_circuit_window',
     'world_matches',effects,
     'integrity',circuit->'integrity',
     'atp_world',circuit->'world_tournaments',
     'world_progressive',circuit->'progressive_world',
     'world_qualifying',circuit->'world_qualifying',
     'junior_world',circuit->'junior_world',
     'world_doubles',circuit->'world_doubles',
     'elapsed_ms',pg_catalog.round((extract(epoch from pg_catalog.clock_timestamp()-started)*1000)::numeric));
   RAISE EXCEPTION 'CB_UNIFIED_WORLD_QA_FORCE_ROLLBACK';
 EXCEPTION WHEN OTHERS THEN
   GET STACKED DIAGNOSTICS err=MESSAGE_TEXT;
   IF err='CB_UNIFIED_WORLD_QA_FORCE_ROLLBACK' THEN RETURN outcome; END IF;
   RETURN pg_catalog.jsonb_build_object('ok',false,'rolled_back',true,
     'engine','run_unified_circuit_window','error',left(err,900),
     'elapsed_ms',pg_catalog.round((extract(epoch from pg_catalog.clock_timestamp()-started)*1000)::numeric));
 END;
END;
$cb_unified_probe$;
REVOKE ALL ON FUNCTION cb_e2e_reconstruction_20261010.probe_real_unified_world_window_v1(date,date)
 FROM PUBLIC,anon,authenticated;
