-- Court Boss isolated QA ONLY. Install a narrowly scoped clone of the
-- EXISTING world doubles engine with one extra tournament-id filter.
-- No production function is replaced and no public tournament is modified.
-- The checksum pins the exact reviewed 2026-10-24 stage source definition.
BEGIN;
SET LOCAL statement_timeout = '15000ms';
DO $install$
DECLARE
 source_function text;
 definition text;
 original_header constant text :=
 'CREATE OR REPLACE FUNCTION public.simulate_world_doubles_tournaments(p_from_date date, p_to_date date)';
 staging_header constant text :=
 'CREATE OR REPLACE FUNCTION cb_e2e_reconstruction_20261010.simulate_world_doubles_one_event_v102(p_from_date date, p_to_date date, p_tournament_id bigint)';
 old_selector constant text := 'where doubles=true and coalesce(is_active,true)=true';
 new_selector constant text := 'where id=p_tournament_id and doubles=true and coalesce(is_active,true)=true';
BEGIN
 IF to_regclass('cb_e2e_checkpoint_20261010.players') IS NULL
 OR to_regclass('cb_e2e_reconstruction_20261010.world_week_jobs_v1') IS NULL
 OR EXISTS(SELECT 1 FROM public.career_state)
 OR EXISTS(SELECT 1 FROM public.game_saves)
 OR EXISTS(SELECT 1 FROM public.game_save_slots)
 THEN RAISE EXCEPTION 'Refuse staging doubles clone: no protected isolated empty-career fixture'; END IF;

 SELECT pg_get_functiondef('public.simulate_world_doubles_tournaments(date,date)'::regprocedure)
 INTO source_function;
 IF md5(source_function)<>'c24ae419a0cee59fffe2fc57a8c1c7ae'
 OR (length(source_function)-length(replace(source_function,original_header,'')))/length(original_header)<>1
 OR (length(source_function)-length(replace(source_function,old_selector,'')))/length(old_selector)<>1
 OR (length(source_function)-length(replace(source_function,'SECURITY DEFINER','')))/length('SECURITY DEFINER')<>1
 THEN
  RAISE EXCEPTION 'Refuse staging doubles clone: source function definition drift';
 END IF;
 definition:=replace(source_function,original_header,staging_header);
 definition:=replace(definition,old_selector,new_selector);
 definition:=replace(definition,'SECURITY DEFINER','SECURITY INVOKER');
 EXECUTE definition;
 EXECUTE 'REVOKE ALL ON FUNCTION cb_e2e_reconstruction_20261010.simulate_world_doubles_one_event_v102(date,date,bigint) FROM PUBLIC';
 -- Even if inherited permissions change later, this experimental QA function
 -- must never be callable by a client-facing role.
 IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname='anon') THEN
  EXECUTE 'REVOKE ALL ON FUNCTION cb_e2e_reconstruction_20261010.simulate_world_doubles_one_event_v102(date,date,bigint) FROM anon';
 END IF;
 IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname='authenticated') THEN
  EXECUTE 'REVOKE ALL ON FUNCTION cb_e2e_reconstruction_20261010.simulate_world_doubles_one_event_v102(date,date,bigint) FROM authenticated';
 END IF;
 IF NOT EXISTS(
  SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='cb_e2e_reconstruction_20261010'
   AND p.proname='simulate_world_doubles_one_event_v102'
   AND p.pronargs=3 AND NOT p.prosecdef
   AND strpos(pg_get_functiondef(p.oid),'where id=p_tournament_id and doubles=true')>0
 ) THEN
   RAISE EXCEPTION 'Refuse staging doubles clone: verify invoker and event selector failed';
 END IF;
END $install$;
COMMIT;
SELECT pg_catalog.jsonb_build_object(
 'environment','isolated_staging',
 'function','cb_e2e_reconstruction_20261010.simulate_world_doubles_one_event_v102',
 'event_scoped',true,'security_invoker',true,
 'source_md5','c24ae419a0cee59fffe2fc57a8c1c7ae',
 'production_function_untouched',true,
 'executes_any_matches_now',false,
 '2050_certified',false
) AS installed_stage_doubles_engine;
