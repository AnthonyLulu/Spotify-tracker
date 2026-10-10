-- STAGE ONLY: exact DDL of V3 isolated fixture integrity check, verified 2026-10-10.
-- Do not execute in production. No fixture row changes; security invoker.
-- 85 original tables, two auditable tournament flags, 52,912 added player/attribute rows.
-- Strictly fails on all unapproved original-row or checkpoint changes.
CREATE OR REPLACE FUNCTION cb_e2e_reconstruction_20261010.verify_original_fixture_rows_v3()
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE
  r record;
  added_cols text[];
  baseline_rows bigint;
  current_rows bigint;
  missing_rows bigint;
  checkpoint_digest text;
  checked integer:=0;
  approved integer:=0;
  extra_total bigint:=0;
  extra_tables jsonb:='[]'::jsonb;
  projection text;
BEGIN
  IF pg_catalog.to_regclass('cb_e2e_checkpoint_20261010.snapshot_manifest') IS NULL
     OR pg_catalog.to_regclass('cb_e2e_reconstruction_20261010.calendar_duplicate_adjustments') IS NULL
  THEN RAISE EXCEPTION 'Isolated checkpoint or adjustment audit missing'; END IF;
  SELECT count(*) INTO approved
  FROM cb_e2e_checkpoint_20261010.tournaments s
  JOIN public.tournaments t ON t.id=s.id
  JOIN cb_e2e_reconstruction_20261010.calendar_duplicate_adjustments j
    ON j.tournament_id=s.id
  WHERE s.id IN (132,133)
    AND s.is_active IS TRUE AND t.is_active IS FALSE
    AND j.old_active IS TRUE AND j.new_active IS FALSE
    AND s.name=t.name AND j.tournament_name=s.name;
  IF approved<>2 OR
      (SELECT count(*) FROM cb_e2e_reconstruction_20261010.calendar_duplicate_adjustments)<>2
  THEN RAISE EXCEPTION 'Unapproved or incomplete isolated calendar overrides'; END IF;
  FOR r IN SELECT source_schema,source_name,row_count,content_md5
    FROM cb_e2e_checkpoint_20261010.snapshot_manifest
    WHERE source_schema='public' AND item_kind='table' ORDER BY source_name
  LOOP
    IF pg_catalog.to_regclass(pg_catalog.format('%I.%I','cb_e2e_checkpoint_20261010',r.source_name)) IS NULL
       OR pg_catalog.to_regclass(pg_catalog.format('%I.%I',r.source_schema,r.source_name)) IS NULL
    THEN RAISE EXCEPTION 'Fixture table unavailable: %',r.source_name; END IF;
    EXECUTE pg_catalog.format(
      'SELECT count(*)::bigint, md5(coalesce(string_agg(md5(to_jsonb(x)::text), '''' ORDER BY md5(to_jsonb(x)::text)), '''')) FROM %I.%I x',
      'cb_e2e_checkpoint_20261010',r.source_name)
      INTO baseline_rows,checkpoint_digest;
    IF baseline_rows IS DISTINCT FROM r.row_count
       OR checkpoint_digest IS DISTINCT FROM r.content_md5
    THEN RAISE EXCEPTION 'Checkpoint digest/count changed: %',r.source_name; END IF;
    SELECT coalesce(array_agg(a.attname ORDER BY a.attnum),ARRAY[]::text[])
      INTO added_cols
    FROM pg_catalog.pg_attribute a
    WHERE a.attrelid=pg_catalog.to_regclass(pg_catalog.format('%I.%I',r.source_schema,r.source_name))
      AND a.attnum>0 AND NOT a.attisdropped
      AND NOT EXISTS (
        SELECT 1 FROM pg_catalog.pg_attribute b
        WHERE b.attrelid=pg_catalog.to_regclass(pg_catalog.format('%I.%I','cb_e2e_checkpoint_20261010',r.source_name))
          AND b.attname=a.attname AND b.attnum>0 AND NOT b.attisdropped
      );
    projection:=CASE WHEN r.source_name='tournaments'
      THEN 'CASE WHEN p.id IN (132,133) THEN pg_catalog.jsonb_set(to_jsonb(p)-$1::text[], ''{is_active}'', ''true''::jsonb) ELSE to_jsonb(p)-$1::text[] END'
      ELSE 'to_jsonb(p)-$1::text[]' END;
    EXECUTE pg_catalog.format(
      'SELECT count(*)::bigint FROM (
         SELECT to_jsonb(s) AS r FROM %I.%I s
         EXCEPT ALL SELECT %s AS r FROM %I.%I p
       ) diff',
      'cb_e2e_checkpoint_20261010',r.source_name,projection,r.source_schema,r.source_name)
      INTO missing_rows USING added_cols;
    IF missing_rows<>0 THEN
      RAISE EXCEPTION 'Original fixture data lost or changed in %: %',r.source_name,missing_rows;
    END IF;
    EXECUTE pg_catalog.format('SELECT count(*)::bigint FROM %I.%I',r.source_schema,r.source_name)
      INTO current_rows;
    IF current_rows<r.row_count THEN
      RAISE EXCEPTION 'Original fixture row count decreased: %',r.source_name;
    END IF;
    IF current_rows>r.row_count THEN
      extra_total:=extra_total+(current_rows-r.row_count);
      extra_tables:=extra_tables || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object('table',r.source_name,'new_rows',current_rows-r.row_count));
    END IF;
    checked:=checked+1;
  END LOOP;
  IF checked<>85 THEN RAISE EXCEPTION 'Fixture table count drift: % (expected 85)',checked; END IF;
  RETURN pg_catalog.jsonb_build_object(
    'ok',true,'checkpoint_verified',true,'original_rows_preserved_except_explicit_overrides',true,
    'checked_tables',checked,'authorized_calendar_overrides',approved,
    'new_rows_in_existing_fixture_tables',extra_total,
    'tables_with_new_rows',extra_tables);
END;
$function$

REVOKE ALL ON FUNCTION cb_e2e_reconstruction_20261010.verify_original_fixture_rows_v3() FROM PUBLIC, anon, authenticated;
