do $migration$
declare
  v_oid oid;
  v_def text;
  v_old text := 'select managed_player_id into v_managed from career_state where id=''demo'';';
  v_new text := 'v_managed:=coalesce(s.managed_player_id,(select managed_player_id from career_state where id=''demo''));';
begin
  select p.oid into v_oid
  from pg_proc p
  join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public'
    and p.proname='finalize_live_match_analytics'
    and pg_get_function_identity_arguments(p.oid)='p_session_id bigint, p_date date'
  limit 1;

  if v_oid is null then
    raise exception 'finalize_live_match_analytics(bigint,date) not found';
  end if;

  v_def := pg_get_functiondef(v_oid);

  if position(v_new in v_def)>0 then
    return;
  end if;

  if position(v_old in v_def)=0 then
    raise exception 'analytics managed-player source pattern not found';
  end if;

  v_def := replace(v_def,v_old,v_new);
  execute v_def;
end
$migration$;
