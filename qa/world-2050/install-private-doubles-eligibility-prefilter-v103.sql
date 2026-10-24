-- Private, isolated-stage experiment ONLY: reduce costly AI player eligibility
-- calls with a deterministic doubles-partnership candidate shortlist.
-- Crucially, the original match engine and ITF selectors remain unchanged.
-- A 256-pair pilot is NOT equivalent to a full 2,000-pair official entry list.
BEGIN;
SET LOCAL statement_timeout='15000ms';
DO $install$
DECLARE
 field_original text;
 field_copy text;
 engine_original text;
 engine_copy text;
 selector_old constant text := 'from public.world_doubles_partnerships w';
 selector_new constant text :=
 'from (select * from public.world_doubles_partnerships z
   where z.season=v_year and z.active=true
   order by coalesce(z.race_rank,999999),z.pair_strength desc,z.id
   limit greatest(64,least(p_candidate_cap,400))) w';
BEGIN
 IF to_regclass('cb_e2e_checkpoint_20261010.players') IS NULL
 OR EXISTS(SELECT 1 FROM public.career_state)
 OR EXISTS(SELECT 1 FROM public.game_saves)
 OR EXISTS(SELECT 1 FROM public.game_save_slots) THEN
  RAISE EXCEPTION 'Refuse private prefilter install outside isolated empty-save stage';
 END IF;
 SELECT pg_get_functiondef('public.select_itf_doubles_field_v20(bigint,bigint)'::regprocedure) INTO field_original;
 IF md5(field_original)<>'fe2cd96f4e47940c0bf7a08fc06ab21f'
 OR (length(field_original)-length(replace(field_original,selector_old,'')))/length(selector_old)<>2
 THEN RAISE EXCEPTION 'Refuse private prefilter install: original ITF selector source drift'; END IF;
 field_copy:=replace(field_original,
  'CREATE OR REPLACE FUNCTION public.select_itf_doubles_field_v20(p_tournament_id bigint, p_managed_player_id bigint DEFAULT NULL::bigint)',
  'CREATE OR REPLACE FUNCTION cb_e2e_reconstruction_20261010.select_itf_doubles_prefilter_v103(p_tournament_id bigint, p_managed_player_id bigint DEFAULT NULL::bigint, p_candidate_cap integer DEFAULT 256)');
 IF field_copy=field_original THEN RAISE EXCEPTION 'Selector header not replaced'; END IF;
 field_copy:=replace(field_copy,selector_old,selector_new);
 EXECUTE field_copy;
 EXECUTE 'REVOKE ALL ON FUNCTION cb_e2e_reconstruction_20261010.select_itf_doubles_prefilter_v103(bigint,bigint,integer) FROM PUBLIC';

 SELECT pg_get_functiondef('cb_e2e_reconstruction_20261010.simulate_world_doubles_one_event_v102(date,date,bigint)'::regprocedure) INTO engine_original;
 IF md5(engine_original)<>'ffbbc55adec78b6912beffc762e333a2'
 OR strpos(engine_original,'public.select_itf_doubles_field_v20(t.id,v_managed)')=0 THEN
  RAISE EXCEPTION 'Refuse private prefilter install: one-event stage engine drift';
 END IF;
 engine_copy:=replace(engine_original,
  'CREATE OR REPLACE FUNCTION cb_e2e_reconstruction_20261010.simulate_world_doubles_one_event_v102(p_from_date date, p_to_date date, p_tournament_id bigint)',
  'CREATE OR REPLACE FUNCTION cb_e2e_reconstruction_20261010.simulate_world_doubles_one_event_prefilter_v103(p_from_date date, p_to_date date, p_tournament_id bigint)');
 IF engine_copy=engine_original THEN RAISE EXCEPTION 'Engine header not replaced'; END IF;
 engine_copy:=replace(engine_copy,'public.select_itf_doubles_field_v20(t.id,v_managed)',
 'cb_e2e_reconstruction_20261010.select_itf_doubles_prefilter_v103(t.id,v_managed,256)');
 EXECUTE engine_copy;
 EXECUTE 'REVOKE ALL ON FUNCTION cb_e2e_reconstruction_20261010.simulate_world_doubles_one_event_prefilter_v103(date,date,bigint) FROM PUBLIC';

 IF NOT EXISTS(SELECT 1 FROM pg_proc WHERE oid=
 'cb_e2e_reconstruction_20261010.simulate_world_doubles_one_event_prefilter_v103(date,date,bigint)'::regprocedure
 AND prosecdef=false) THEN
  RAISE EXCEPTION 'Refuse staging prefilter: engine unexpectedly SECURITY DEFINER';
 END IF;
END $install$;
COMMIT;
SELECT jsonb_build_object('stage_only',true,'installed',true,
 'private_one_event_engine',true,'pilot_candidate_cap',256,
 'original_selector_modified',false,'original_match_engine_modified',false,
 'full_draw_accuracy_certified',false,'2050_certified',false) AS receipt;
