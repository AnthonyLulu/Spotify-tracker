-- P0: staging-only structural guard for cancelled/postponed tournament fixtures.
-- NEVER apply to production: isolated DB may contain intentionally synthetic QA fixtures.
-- Existing results and game data are never deleted, reset or rewritten.
BEGIN;
SET LOCAL lock_timeout='3000ms';
SET LOCAL statement_timeout='14000ms';
DO $preflight$
BEGIN
 IF to_regclass('cb_e2e_checkpoint_20261010.players') IS NULL
    OR to_regclass('cb_e2e_reconstruction_20261010.world_week_jobs_v1') IS NULL
 THEN RAISE EXCEPTION 'Refuse: staging-only original E2E checkpoint not detected'; END IF;
 IF EXISTS (SELECT 1 FROM public.game_saves)
    OR EXISTS (SELECT 1 FROM public.game_save_slots)
    OR EXISTS (SELECT 1 FROM public.career_state)
 THEN RAISE EXCEPTION 'Refuse: stage has private game saves or live careers'; END IF;
 IF EXISTS (
  SELECT 1 FROM public.tournaments
  WHERE coalesce(is_active,true)
    AND coalesce(name,'') ~* '(cancelled|canceled|postponed|abandoned|annul[ée])'
 ) THEN RAISE EXCEPTION 'Refuse: invalid existing active fixture must be audited first'; END IF;
 IF EXISTS (SELECT 1 FROM pg_catalog.pg_constraint
            WHERE conname='cb_stage_no_play_cancelled_postponed_v113')
 THEN RAISE EXCEPTION 'Refuse: constraint already installed, do not create duplicate'; END IF;
END;
$preflight$;
-- check is_active IS NULL as active too: old selectors defaulted null to true.
ALTER TABLE public.tournaments
 ADD CONSTRAINT cb_stage_no_play_cancelled_postponed_v113
 CHECK (NOT (
   coalesce(is_active,true)
   AND coalesce(name,'') ~* '(cancelled|canceled|postponed|abandoned|annul[ée])'
 )) NOT VALID;
ALTER TABLE public.tournaments
 VALIDATE CONSTRAINT cb_stage_no_play_cancelled_postponed_v113;
COMMIT;
