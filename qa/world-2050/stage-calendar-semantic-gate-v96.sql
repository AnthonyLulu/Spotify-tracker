-- P0 v96: isolated stage semantic gate for CANCELLED/POSTPONED tournaments.
-- This file DOES NOT repair or delete previously played events. Those weeks stay RED.
-- Execute ONLY against court-boss-e2e-2025-2050 with original stage checkpoint intact.
-- Never apply this QA-only procedure to court-boss production.
BEGIN;
SET LOCAL statement_timeout='10000ms';
DO $stage_only$
BEGIN
 IF to_regclass('cb_e2e_reconstruction_20261010.world_week_items_v1') IS NULL
    OR to_regclass('cb_e2e_checkpoint_20261010.players') IS NULL THEN
  RAISE EXCEPTION 'v96 must run only inside original isolated reconstructed stage';
 END IF;
END;
$stage_only$;
CREATE OR REPLACE FUNCTION cb_e2e_reconstruction_20261010.verify_persisted_singles_week_v96(p_job_key text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path TO ''
AS $fn$
DECLARE n_invalid integer; invalid_events jsonb; old_receipt jsonb;
BEGIN
 IF p_job_key IS NULL OR p_job_key !~ '^WORLD-SINGLES:2026-[0-9]{2}-[0-9]{2}:2026-[0-9]{2}-[0-9]{2}$' THEN
  RETURN pg_catalog.jsonb_build_object('ok',false,'reason','invalid_week_key',
    'calendar_semantics_ok',false,'certifies_full_unified_week',false);
 END IF;
 SELECT count(*)::integer,
        coalesce(pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object('tournament_id',t.id,'name',t.name,'status',i.status)
          ORDER BY i.seq), '[]'::jsonb)
 INTO n_invalid,invalid_events
 FROM cb_e2e_reconstruction_20261010.world_week_items_v1 i
 JOIN public.tournaments t ON t.id=i.tournament_id
 WHERE i.job_key=p_job_key AND
  (coalesce(t.is_active,false)=false
    OR t.name ~* '(cancelled|canceled|postponed|abandoned|annul[ée])');
 IF n_invalid>0 THEN
  RETURN pg_catalog.jsonb_build_object(
   'ok',false,'reason','invalid_calendar_events',
   'world_run_id',p_job_key,'scope','world_singles_only',
   'calendar_semantics_ok',false,
   'cancelled_event_rows',n_invalid,
   'invalid_calendar_events',invalid_events,
   'certifies_full_unified_week',false,
   '2050_certified',false
  );
 END IF;
 old_receipt:=cb_e2e_reconstruction_20261010.verify_persisted_singles_week_v80(p_job_key);
 RETURN old_receipt||pg_catalog.jsonb_build_object(
   'calendar_semantics_ok',true,
   'cancelled_event_rows',0,
   'certifies_full_unified_week',false
 );
END;
$fn$;
REVOKE ALL ON FUNCTION cb_e2e_reconstruction_20261010.verify_persisted_singles_week_v96(text) FROM PUBLIC,anon,authenticated;
COMMIT;
-- Verification samples: should be ok=false for old contaminated weeks.
SELECT
 j.job_key,
 r.receipt->>'reason' AS reason,
 (r.receipt->>'calendar_semantics_ok')::boolean AS calendar_semantics_ok,
 coalesce((r.receipt->>'cancelled_event_rows')::integer,0) AS excluded_events,
 (r.receipt->>'ok')::boolean AS certified
FROM cb_e2e_reconstruction_20261010.world_week_jobs_v1 j
CROSS JOIN LATERAL (SELECT cb_e2e_reconstruction_20261010.verify_persisted_singles_week_v96(j.job_key) receipt) r
WHERE j.from_date >= date '2026-02-22'
ORDER BY j.from_date;
