-- Court Boss v56: remove client-callable EXECUTE on internal SECURITY DEFINER RPCs.
-- Existing triggers continue firing as database triggers. The privileged Edge
-- service role retains explicit EXECUTE for the one read helper it calls.
DO $hardening$
DECLARE
  fn text;
  signature text;
  target_oid oid;
BEGIN
  FOREACH fn IN ARRAY ARRAY[
    'cb_awards_year_rollover_trigger',
    'cb_live_match_stat_lines_trigger',
    'cb_stat_record_breakthrough_trigger',
    'cb_world_match_stat_lines_trigger',
    'laver_cup_captain_context',
    'laver_cup_history_stamp_captains',
    'laver_cup_roster_captain_guard'
  ] LOOP
    signature := format('public.%I(%s)', fn,
      CASE WHEN fn='laver_cup_captain_context' THEN 'integer' ELSE '' END);
    target_oid := to_regprocedure(signature);
    IF target_oid IS NULL THEN
      RAISE EXCEPTION 'Refusing partial privilege hardening, missing function %', signature;
    END IF;
    IF NOT (SELECT prosecdef FROM pg_proc WHERE oid=target_oid) THEN
      RAISE EXCEPTION 'Function is no longer SECURITY DEFINER: %', signature;
    END IF;
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon, authenticated', signature);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role', signature);

    IF has_function_privilege('anon',target_oid,'EXECUTE')
        OR has_function_privilege('authenticated',target_oid,'EXECUTE')
        OR NOT has_function_privilege('service_role',target_oid,'EXECUTE') THEN
      RAISE EXCEPTION 'Unexpected role grants on %', signature;
    END IF;
  END LOOP;
END
$hardening$;
