-- P0 v98: isolated-stage ONLY canonical freeze of explicitly cancelled/postponed ITF fixtures, 2026-2050.
-- Reversible flag correction with original values preserved in a private staging audit table.
-- Does NOT delete or clean the six previously simulated bad events: semantic certification remains RED.
BEGIN;
SET LOCAL statement_timeout='20000ms';
DO $stage_guard$
DECLARE n integer;
BEGIN
 IF to_regclass('cb_e2e_checkpoint_20261010.players') IS NULL
 OR to_regclass('cb_e2e_reconstruction_20261010.world_week_jobs_v1') IS NULL THEN
  RAISE EXCEPTION 'v98 is only for the original isolated E2E staging environment';
 END IF;
 IF EXISTS(SELECT 1 FROM public.career_state) OR EXISTS(SELECT 1 FROM public.game_saves)
 OR EXISTS(SELECT 1 FROM public.game_save_slots) THEN
  RAISE EXCEPTION 'Cannot change stage tournament status while a user career/save exists';
 END IF;
 SELECT count(*) INTO n FROM public.tournaments t
 WHERE t.circuit='ITF' AND t.start_date BETWEEN date '2026-01-01' AND date '2050-12-31'
 AND t.name ~* '(cancelled|canceled|postponed|abandoned|annul[ée])';
 IF n<>375 THEN RAISE EXCEPTION 'Frozen v98 ITF cancelled event count drift: %',n; END IF;
 IF EXISTS(SELECT 1 FROM public.tournaments t
 WHERE t.start_date BETWEEN date '2026-01-01' AND date '2050-12-31'
 AND t.name ~* '(cancelled|canceled|postponed|abandoned|annul[ée])'
 AND t.circuit <> 'ITF') THEN
  RAISE EXCEPTION 'Unexpected non-ITF cancelled event; manual review required';
 END IF;
END;
$stage_guard$;
CREATE TABLE IF NOT EXISTS cb_e2e_reconstruction_20261010.itf_cancelled_original_status_v98(
 tournament_id bigint PRIMARY KEY,
 original_is_active boolean NOT NULL,
 tournament_name text NOT NULL,
 event_start date NOT NULL
);
REVOKE ALL ON cb_e2e_reconstruction_20261010.itf_cancelled_original_status_v98 FROM PUBLIC,anon,authenticated;
DO $audit_guard$
DECLARE n integer;
BEGIN
 SELECT count(*) INTO n FROM cb_e2e_reconstruction_20261010.itf_cancelled_original_status_v98;
 IF n NOT IN (0,375) THEN
  RAISE EXCEPTION 'Existing v98 backup has unexpected row count: %',n;
 END IF;
 IF n=0 THEN
  INSERT INTO cb_e2e_reconstruction_20261010.itf_cancelled_original_status_v98
   (tournament_id,original_is_active,tournament_name,event_start)
  SELECT t.id,coalesce(t.is_active,true),t.name,t.start_date
  FROM public.tournaments t
  WHERE t.circuit='ITF' AND t.start_date BETWEEN date '2026-01-01' AND date '2050-12-31'
  AND t.name ~* '(cancelled|canceled|postponed|abandoned|annul[ée])';
 END IF;
 IF (SELECT count(*) FROM cb_e2e_reconstruction_20261010.itf_cancelled_original_status_v98)<>375
 OR EXISTS(
  SELECT 1 FROM cb_e2e_reconstruction_20261010.itf_cancelled_original_status_v98 b
  LEFT JOIN public.tournaments t ON t.id=b.tournament_id
  WHERE t.id IS NULL OR t.name IS DISTINCT FROM b.tournament_name
    OR t.start_date IS DISTINCT FROM b.event_start
    OR t.circuit <> 'ITF'
 ) THEN RAISE EXCEPTION 'v98 source fixture backup mismatch'; END IF;
END;
$audit_guard$;
-- Only explicitly cancelled/postponed event IDs that were saved in the audit snapshot.
UPDATE public.tournaments t SET is_active=false
WHERE t.is_active=true AND t.id IN (
 SELECT b.tournament_id FROM cb_e2e_reconstruction_20261010.itf_cancelled_original_status_v98 b
);
DO $post_guard$
BEGIN
 IF (SELECT count(*) FROM cb_e2e_reconstruction_20261010.itf_cancelled_original_status_v98)<>375
 OR EXISTS(
  SELECT 1 FROM cb_e2e_reconstruction_20261010.itf_cancelled_original_status_v98 b
  JOIN public.tournaments t ON t.id=b.tournament_id WHERE t.is_active IS DISTINCT FROM false
 ) THEN RAISE EXCEPTION 'v98 cancelled fixtures still marked active'; END IF;
END;
$post_guard$;
COMMIT;
SELECT pg_catalog.jsonb_build_object(
 'environment','isolated_staging_only',
 'cancelled_itf_fixtures',(SELECT count(*) FROM cb_e2e_reconstruction_20261010.itf_cancelled_original_status_v98),
 'cancelled_itf_still_active',(SELECT count(*) FROM cb_e2e_reconstruction_20261010.itf_cancelled_original_status_v98 b JOIN public.tournaments t ON t.id=b.tournament_id WHERE t.is_active=true),
 'previous_status_preserved',true,'historical_results_repaired',false,'2050_certified',false
) AS status_receipt;
