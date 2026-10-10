-- Stage-only, read-only reconstruction parity gate.
-- Never invoke against production. Exports counts and hashes, not table rows.
-- Run under a role permitted to read cb_e2e_reconstruction_20261010.
WITH actual_functions AS (
  SELECT n.nspname AS source_schema,
    p.proname||'('||pg_get_function_identity_arguments(p.oid)||')' AS object_name,
    md5(pg_get_functiondef(p.oid)) AS digest
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname IN ('public','court_boss_private') AND p.prokind IN ('f','p')
), function_gate AS (
  SELECT COUNT(*) AS expected,
    COUNT(*) FILTER (WHERE af.object_name IS NULL) AS missing,
    COUNT(*) FILTER (WHERE af.object_name IS NOT NULL AND af.digest<>md5(b.definition->>'sql')) AS drifted
  FROM cb_e2e_reconstruction_20261010.blueprint b
  LEFT JOIN actual_functions af ON af.source_schema=b.source_schema AND af.object_name=b.object_name
  WHERE b.object_type='function'
), column_gate AS (
  SELECT COUNT(*) AS expected,
    COUNT(*) FILTER (WHERE a.attname IS NULL) AS missing,
    COUNT(*) FILTER (WHERE a.attname IS NOT NULL
      AND pg_catalog.format_type(a.atttypid,a.atttypmod)<>x.column_def->>'data_type') AS type_drift
  FROM cb_e2e_reconstruction_20261010.blueprint b
  CROSS JOIN LATERAL jsonb_array_elements(b.definition->'columns') x(column_def)
  LEFT JOIN pg_attribute a ON a.attrelid=to_regclass(format('%I.%I',b.source_schema,b.object_name))
    AND a.attname=x.column_def->>'name' AND NOT a.attisdropped
  WHERE b.object_type='table'
), constraint_gate AS (
  SELECT COUNT(*) AS expected,
    COUNT(*) FILTER (WHERE k.oid IS NULL) AS missing,
    COUNT(*) FILTER (WHERE k.oid IS NOT NULL AND pg_get_constraintdef(k.oid,true)<>x.constraint_def->>'ddl') AS drifted
  FROM cb_e2e_reconstruction_20261010.blueprint b
  CROSS JOIN LATERAL jsonb_array_elements(b.definition->'constraints') x(constraint_def)
  LEFT JOIN pg_constraint k ON k.conrelid=to_regclass(format('%I.%I',b.source_schema,b.object_name))
    AND k.conname=x.constraint_def->>'name'
  WHERE b.object_type='table'
), object_gate AS (
 SELECT b.object_type,COUNT(*) expected,
 COUNT(*) FILTER (WHERE to_regclass(format('%I.%I',b.source_schema,b.object_name)) IS NULL) missing
 FROM cb_e2e_reconstruction_20261010.blueprint b
 WHERE b.object_type IN ('table','view','index','sequence')
 GROUP BY b.object_type
)
SELECT jsonb_build_object(
  'is_2050_certified',false,
  'table_columns',(SELECT row_to_json(column_gate) FROM column_gate),
  'constraints',(SELECT row_to_json(constraint_gate) FROM constraint_gate),
  'functions',(SELECT row_to_json(function_gate) FROM function_gate),
  'objects',(SELECT jsonb_object_agg(object_type,jsonb_build_object('expected',expected,'missing',missing)) FROM object_gate),
  'unrestored_triggers',(SELECT COUNT(*) FROM cb_e2e_reconstruction_20261010.blueprint b
    WHERE b.object_type='trigger'
      AND NOT EXISTS (SELECT 1 FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace
        WHERE n.nspname=b.source_schema AND c.relname||'.'||t.tgname=b.object_name AND NOT t.tgisinternal)),
  'checkpoint_tables',(SELECT COUNT(*) FROM cb_e2e_checkpoint_20261010.snapshot_manifest WHERE item_kind='table'),
  'original_rows_preserved',cb_e2e_reconstruction_20261010.verify_original_fixture_columns()
) AS stage_gate;
