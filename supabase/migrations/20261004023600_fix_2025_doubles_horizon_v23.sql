-- Court Boss V23.7: historical baseline uses 2026 doubles rules
CREATE OR REPLACE FUNCTION public.world_25y_validation_v20(
  p_start_year integer DEFAULT 2025,
  p_end_year integer DEFAULT 2050
)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  v_base jsonb;
  v_doubles jsonb;
  v_doubles_audit_date date;
begin
  v_base:=public.world_25y_validation_v19(p_start_year,p_end_year);
  v_doubles_audit_date:=case
    when p_start_year<=2025 then date '2026-01-01'
    else make_date(p_start_year,1,1)
  end;
  v_doubles:=public.doubles_entry_rules_audit_v20(v_doubles_audit_date);

  return jsonb_build_object(
    'ok',
      coalesce((v_base->>'ok')::boolean,false)
      and coalesce((v_doubles->>'ok')::boolean,false),
    'start_year',p_start_year,
    'end_year',p_end_year,
    'base_v19',v_base,
    'doubles_v20',v_doubles,
    'model','CB-WORLD-25Y-VALIDATION-v23.7'
  );
end;
$function$;

revoke all on function public.world_25y_validation_v20(integer,integer) from public,anon,authenticated;
grant execute on function public.world_25y_validation_v20(integer,integer) to service_role;
