-- Read-only structure inventory for an isolated P0 rebuild gate.
-- Every output value is an object identifier or an md5 digest of its definition.
-- Never exports table rows, saved games, service keys, or SQL function bodies.
SELECT json_build_object(
 'tables',COALESCE((
   SELECT json_agg(json_build_object(
    'name',n.nspname||'.'||c.relname,
    'hash',md5(
      COALESCE((SELECT string_agg(
        a.attname||':'||format_type(a.atttypid,a.atttypmod)||':'||a.attnotnull::text||
        ':'||COALESCE(pg_get_expr(d.adbin,d.adrelid),''),
        ';' ORDER BY a.attnum)
       FROM pg_attribute a LEFT JOIN pg_attrdef d
         ON d.adrelid=a.attrelid AND d.adnum=a.attnum
       WHERE a.attrelid=c.oid AND a.attnum>0 AND NOT a.attisdropped),'')||'|'||
      COALESCE((SELECT string_agg(pg_get_constraintdef(k.oid,true),
                        ';' ORDER BY k.conname)
       FROM pg_constraint k WHERE k.conrelid=c.oid),'')||'|'||
      c.relrowsecurity::text||':'||c.relforcerowsecurity::text
    ))
    ORDER BY n.nspname,c.relname)
   FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
   WHERE n.nspname IN ('public','court_boss_private') AND c.relkind IN ('r','p')
 ),'[]'::json),
 'views',COALESCE((
   SELECT json_agg(json_build_object(
    'name',n.nspname||'.'||c.relname,
    'hash',md5(pg_get_viewdef(c.oid,true))
   ) ORDER BY n.nspname,c.relname)
   FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
   WHERE n.nspname IN ('public','court_boss_private') AND c.relkind IN ('v','m')
 ),'[]'::json),
 'functions',COALESCE((
   SELECT json_agg(json_build_object(
    'name',n.nspname||'.'||p.proname||'('||pg_get_function_identity_arguments(p.oid)||')',
    'hash',md5(pg_get_functiondef(p.oid))
   ) ORDER BY n.nspname,p.proname,pg_get_function_identity_arguments(p.oid))
   FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname IN ('public','court_boss_private') AND p.prokind IN ('f','p')
 ),'[]'::json),
 'indexes',COALESCE((
   SELECT json_agg(json_build_object(
    'name',n.nspname||'.'||c.relname,
    'hash',md5(pg_get_indexdef(c.oid))
   ) ORDER BY n.nspname,c.relname)
   FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
   WHERE n.nspname IN ('public','court_boss_private') AND c.relkind='i'
 ),'[]'::json),
 'triggers',COALESCE((
   SELECT json_agg(json_build_object(
    'name',n.nspname||'.'||c.relname||'.'||t.tgname,
    'hash',md5(pg_get_triggerdef(t.oid,true))
   ) ORDER BY n.nspname,c.relname,t.tgname)
   FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid
   JOIN pg_namespace n ON n.oid=c.relnamespace
   WHERE n.nspname IN ('public','court_boss_private') AND NOT t.tgisinternal
 ),'[]'::json)
);
