CREATE OR REPLACE FUNCTION public.staff_world_integrity_audit_v21(p_date date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare
  v_date date:=coalesce(p_date,current_date);
  v_active int;
  v_former int;
  v_doubles int;
  v_agents int;
  v_immortal int;
  v_orphans int;
  v_retired_active_assignments int;
  v_overdue_retiring int;
  v_rep20 int;
  v_rep20_share numeric;
  v_status text:='healthy';
  v_issues jsonb:='[]'::jsonb;
begin
  select count(*)::int into v_active
  from public.staff_profiles where active=true;

  select count(*)::int into v_former
  from public.staff_profiles
  where active=true and former_player_id is not null;

  select count(*)::int into v_doubles
  from public.staff_profiles
  where active=true and primary_role='Coach double';

  select count(*)::int into v_agents
  from public.staff_profiles
  where active=true and public.staff_role_group(primary_role)='agent';

  select count(*)::int into v_immortal
  from public.staff_profiles
  where active=true and retirement_year is null;

  select count(*)::int into v_orphans
  from public.player_staff_assignments psa
  left join public.staff_profiles sp on sp.id=psa.staff_profile_id
  left join public.players p on p.id=psa.player_id
  where psa.active=true
    and (
      sp.id is null
      or sp.active=false
      or p.id is null
      or p.career_status<>'active'
    );

  select count(*)::int into v_retired_active_assignments
  from public.player_staff_assignments psa
  join public.staff_profiles sp on sp.id=psa.staff_profile_id
  where psa.active=true
    and (
      sp.market_status='retired'
      or sp.operational_status='retired'
      or sp.active=false
    );

  select count(*)::int into v_overdue_retiring
  from public.staff_profiles sp
  where sp.active=true
    and sp.operational_status='retiring'
    and sp.retirement_year is not null
    and sp.retirement_year<extract(year from v_date)::int;

  select count(*)::int into v_rep20
  from public.staff_profiles
  where active=true and reputation=20;

  v_rep20_share:=case when v_active>0 then round(v_rep20*100.0/v_active,2) else 0 end;

  if v_immortal>0 then
    v_issues:=v_issues||jsonb_build_array(jsonb_build_object('code','staff_without_retirement','count',v_immortal));
  end if;
  if v_orphans>0 then
    v_issues:=v_issues||jsonb_build_array(jsonb_build_object('code','orphan_staff_assignments','count',v_orphans));
  end if;
  if v_retired_active_assignments>0 then
    v_issues:=v_issues||jsonb_build_array(jsonb_build_object('code','retired_staff_still_assigned','count',v_retired_active_assignments));
  end if;
  if v_overdue_retiring>0 then
    v_issues:=v_issues||jsonb_build_array(jsonb_build_object('code','overdue_retiring_staff','count',v_overdue_retiring));
  end if;
  if v_active<5000 then
    v_issues:=v_issues||jsonb_build_array(jsonb_build_object('code','staff_supply_low','count',v_active,'floor',5000));
  end if;
  if v_doubles<1100 then
    v_issues:=v_issues||jsonb_build_array(jsonb_build_object('code','doubles_coach_supply_low','count',v_doubles,'target',1200));
  end if;
  if v_agents<400 then
    v_issues:=v_issues||jsonb_build_array(jsonb_build_object('code','agent_supply_low','count',v_agents,'target',450));
  end if;
  if v_former<800 then
    v_issues:=v_issues||jsonb_build_array(jsonb_build_object('code','former_player_staff_supply_low','count',v_former,'target',1500));
  end if;
  if v_rep20_share>5 then
    v_issues:=v_issues||jsonb_build_array(jsonb_build_object('code','staff_reputation_saturation','count',v_rep20,'share_pct',v_rep20_share,'limit_pct',5));
  end if;

  if jsonb_array_length(v_issues)>0 then v_status:='warning'; end if;

  return jsonb_build_object(
    'ok',v_status='healthy',
    'status',v_status,
    'date',v_date,
    'active_staff',v_active,
    'active_former_player_staff',v_former,
    'active_doubles_coaches',v_doubles,
    'active_agents',v_agents,
    'staff_without_retirement',v_immortal,
    'orphan_staff_assignments',v_orphans,
    'retired_staff_still_assigned',v_retired_active_assignments,
    'overdue_retiring_staff',v_overdue_retiring,
    'reputation_20',v_rep20,
    'reputation_20_share_pct',v_rep20_share,
    'issues',v_issues,
    'model','CB-STAFF-WORLD-INTEGRITY-v21'
  );
end;
$function$;

revoke all on function public.staff_world_integrity_audit_v21(date) from public,anon,authenticated;
grant execute on function public.staff_world_integrity_audit_v21(date) to service_role;
