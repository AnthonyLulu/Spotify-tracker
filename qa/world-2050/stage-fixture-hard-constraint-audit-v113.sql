-- Stage-only, read-only structural calendar constraint receipt.
BEGIN READ ONLY;
SET LOCAL statement_timeout='10000ms';
SELECT jsonb_build_object(
 'environment','isolated-2025-2050-stage',
 'constraint_name','cb_stage_no_play_cancelled_postponed_v113',
 'constraint_present',(SELECT count(*)=1
 FROM pg_catalog.pg_constraint c
 JOIN pg_catalog.pg_class t ON t.oid=c.conrelid
 JOIN pg_catalog.pg_namespace n ON n.oid=t.relnamespace
 WHERE n.nspname='public' AND t.relname='tournaments'
 AND c.conname='cb_stage_no_play_cancelled_postponed_v113'),
 'constraint_validated',(SELECT bool_and(c.convalidated)
 FROM pg_catalog.pg_constraint c
 JOIN pg_catalog.pg_class t ON t.oid=c.conrelid
 JOIN pg_catalog.pg_namespace n ON n.oid=t.relnamespace
 WHERE n.nspname='public' AND t.relname='tournaments'
 AND c.conname='cb_stage_no_play_cancelled_postponed_v113'),
 'bad_active_or_null_rows',(SELECT count(*) FROM public.tournaments
 WHERE coalesce(is_active,true)
 AND coalesce(name,'') ~* '(cancelled|canceled|postponed|abandoned|annul[ée])'),
 'known_inactive_invalid_fixtures',(SELECT count(*) FROM public.tournaments
 WHERE coalesce(is_active,false)=false
 AND coalesce(name,'') ~* '(cancelled|canceled|postponed|abandoned|annul[ée])'
 AND end_date BETWEEN date '2026-01-01' AND date '2050-12-31'),
 'stage_game_saves',(SELECT count(*) FROM public.game_saves),
 'guard_does_not_repair_historical_results',true,
 'not_full_calendar_status_certification',true,
 '2050_certified',false
) AS structural_calendar_receipt;
COMMIT;
