-- Court Boss V23.4: de-duplicate long-horizon health work
-- Reuse the audits already embedded in world_25y_validation_v20 instead of
-- recomputing world guard, singles rules and doubles rules a second time.

CREATE OR REPLACE FUNCTION public.career_long_term_health_v20(p_date date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  v_date date:=coalesce(p_date,current_date);
  v_start_year int:=extract(year from coalesce(p_date,current_date))::int;
  v_horizon jsonb;
  v_base jsonb;
  v_guard jsonb;
  v_singles jsonb;
  v_doubles jsonb;
  v_ok boolean:=false;
  v_hof bigint:=0;
  v_staff bigint:=0;
  v_players bigint:=0;
begin
  v_horizon:=public.world_25y_validation_v20(v_start_year,v_start_year+25);
  v_base:=coalesce(v_horizon->'base_v19','{}'::jsonb);
  v_guard:=coalesce(v_base->'current_world_guard','{}'::jsonb);
  v_singles:=coalesce(v_base->'entry_rules','{}'::jsonb);
  v_doubles:=coalesce(v_horizon->'doubles_v20','{}'::jsonb);

  select count(*) into v_hof from public.hall_of_fame_candidates;
  select count(*) into v_staff from public.staff_profiles where active=true;
  select count(*) into v_players from public.players where career_status='active';

  v_ok:=
    coalesce((v_guard->>'ok')::boolean,false)
    and coalesce((v_singles->>'ok')::boolean,false)
    and coalesce((v_doubles->>'ok')::boolean,false)
    and coalesce((v_horizon->>'ok')::boolean,false);

  return jsonb_build_object(
    'ok',v_ok,
    'date',v_date,
    'world_guard',v_guard,
    'singles_entry_rules',v_singles,
    'doubles_entry_rules',v_doubles,
    'horizon_25y',v_horizon,
    'economy',public.career_operating_cost_profile_v15(v_date),
    'hall_of_fame_total',v_hof,
    'active_staff_profiles',v_staff,
    'active_players',v_players,
    'model','CB-CAREER-LONG-HORIZON-v23.4'
  );
end;
$function$;

revoke all on function public.career_long_term_health_v20(date) from public,anon,authenticated;
grant execute on function public.career_long_term_health_v20(date) to service_role;
