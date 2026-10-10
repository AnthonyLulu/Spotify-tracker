-- QA stage only. Run after schema.sql; do not merge into production.
CREATE OR REPLACE FUNCTION cb_e2e_reconstruction_20261010.begin_world_week_v1(p_from date,p_to date)
RETURNS jsonb LANGUAGE plpgsql SET search_path TO ''
AS $$
DECLARE k text; j record;
BEGIN
 IF p_from<date '2026-01-01' OR p_to>date '2026-01-31'
  OR p_to<=p_from OR p_to-p_from>8 THEN
  RETURN jsonb_build_object('ok',false,'reason','invalid_qa_window');END IF;
 IF EXISTS(SELECT 1 FROM public.career_state)
  OR EXISTS(SELECT 1 FROM public.game_save_slots) THEN
  RETURN jsonb_build_object('ok',false,'reason','active_session');END IF;
 IF NOT pg_catalog.pg_try_advisory_xact_lock(94832021) THEN
  RETURN jsonb_build_object('ok',false,'reason','busy');END IF;
 k:='WORLD-SINGLES:'||p_from::text||':'||p_to::text;
 INSERT INTO cb_e2e_reconstruction_20261010.world_week_jobs_v1(job_key,from_date,to_date)
 VALUES(k,p_from,p_to) ON CONFLICT DO NOTHING;
 INSERT INTO cb_e2e_reconstruction_20261010.world_week_items_v1(job_key,tournament_id,seq)
 SELECT k,t.id, row_number() OVER(ORDER BY t.end_date,t.id)::int
 FROM public.tournaments t
 JOIN public.tournament_format_rules fr ON fr.circuit=t.circuit
  AND fr.category=t.category AND fr.main_draw_size=coalesce(t.singles_draw_size,t.draw_size)
 WHERE t.singles AND coalesce(t.is_active,true) AND fr.format_type='knockout'
  AND t.circuit IN ('ATP','Challenger','ITF')
  AND t.end_date>p_from AND t.end_date<=p_to
 ON CONFLICT DO NOTHING;
 UPDATE cb_e2e_reconstruction_20261010.world_week_jobs_v1 q SET
  expected_items=(SELECT count(*) FROM cb_e2e_reconstruction_20261010.world_week_items_v1 i WHERE i.job_key=k)
 WHERE q.job_key=k AND q.expected_items=0;
 SELECT * INTO j FROM cb_e2e_reconstruction_20261010.world_week_jobs_v1 WHERE job_key=k;
 RETURN jsonb_build_object('ok',true,'job_key',k,'expected',j.expected_items,'completed',j.completed_items);
END $$;
REVOKE ALL ON FUNCTION cb_e2e_reconstruction_20261010.begin_world_week_v1(date,date) FROM PUBLIC,anon,authenticated;
