-- Court Boss v65: game starts 2025-12-01 but the playable doubles ATP calendar
-- starts in 2026. A health audit on launch must inspect the 2026 entry rules,
-- not flag all non-existent 2025 tournaments as unhealthy.
-- Original requested date is preserved for world, staff and general health.
DO $fix$
DECLARE
  definition text;
  original text := 'public.doubles_entry_rules_audit_v20(p_date)';
  replacement text := 'public.doubles_entry_rules_audit_v20(greatest(p_date, DATE ''2026-01-01''))';
  occurrences integer;
BEGIN
  SELECT pg_get_functiondef('public.career_system_health(date)'::regprocedure)
    INTO definition;
  occurrences := (length(definition)-length(replace(definition,original,'')))/length(original);
  IF occurrences<>2 THEN
    RAISE EXCEPTION 'Unexpected career health function: expected two doubles audits, got %',occurrences;
  END IF;
  definition := replace(definition,original,replacement);
  EXECUTE definition;
END $fix$;
