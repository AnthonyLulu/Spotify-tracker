-- Court Boss V23.5: correct the long-horizon retirement window
-- A validation beginning in 2026 must include 2026 retirements before evaluating 2027.
-- Only the historical 2025 baseline skips directly to the first simulated 2026 season.

CREATE OR REPLACE FUNCTION public.world_25y_validation_v19(
  p_start_year integer DEFAULT 2025,
  p_end_year integer DEFAULT 2050
)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  v_stress jsonb;
  v_calendar jsonb;
  v_guard jsonb;
  v_entries jsonb;
  v_calendar_duplicate_groups int:=0;
  v_ok boolean;
  v_audit_date date;
  v_stress_start int;
  v_range_start date;
  v_range_end date;
begin
  if p_end_year<=p_start_year or p_end_year-p_start_year>80 then
    return jsonb_build_object('ok',false,'reason','invalid_horizon');
  end if;

  v_audit_date:=case
    when p_start_year=2025 then date '2025-12-01'
    else make_date(p_start_year,1,1)
  end;
  v_stress_start:=case when p_start_year<=2025 then 2026 else p_start_year end;
  v_range_start:=make_date(p_start_year,1,1);
  v_range_end:=make_date(p_end_year+1,1,1);

  v_stress:=public.living_world_stress_test_v16(v_stress_start,p_end_year,250,2000);
  v_calendar:=public.living_world_horizon_test_v14(p_start_year,p_end_year);
  v_guard:=public.world_integrity_guard_v18(v_audit_date);
  v_entries:=public.tournament_entry_rules_audit_v19(v_audit_date);

  select count(*)::int into v_calendar_duplicate_groups
  from (
    select t.circuit,t.category,t.start_date,t.country,lower(t.name),count(*)
    from public.tournaments t
    where t.start_date>=v_range_start
      and t.start_date<v_range_end
      and coalesce(t.is_active,true)
    group by 1,2,3,4,5
    having count(*)>1
  ) x;

  v_ok:=coalesce((v_stress->>'ok')::boolean,false)
        and coalesce((v_calendar->>'ok')::boolean,false)
        and coalesce((v_guard->>'ok')::boolean,false)
        and coalesce((v_entries->>'ok')::boolean,false)
        and v_calendar_duplicate_groups=0;

  return jsonb_build_object(
    'ok',v_ok,
    'start_year',p_start_year,
    'end_year',p_end_year,
    'seasons',p_end_year-p_start_year+1,
    'supply_and_retirement_stress',v_stress,
    'calendar_horizon',v_calendar,
    'calendar_duplicate_groups',v_calendar_duplicate_groups,
    'current_world_guard',v_guard,
    'entry_rules',v_entries,
    'model','CB-WORLD-25Y-VALIDATION-v23.5'
  );
end;
$function$;

revoke all on function public.world_25y_validation_v19(integer,integer) from public,anon,authenticated;
grant execute on function public.world_25y_validation_v19(integer,integer) to service_role;
