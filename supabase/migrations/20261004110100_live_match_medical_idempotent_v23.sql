create or replace function public.apply_live_match_medical_once_v23(
  p_session_id bigint,
  p_managed_player_id bigint,
  p_match_date date,
  p_retirement jsonb
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_existing jsonb;
  v_injured_id bigint:=nullif(p_retirement->>'player_id','')::bigint;
  v_type text:=coalesce(nullif(p_retirement->>'injury_type',''),'Blessure');
  v_severity text:=coalesce(nullif(p_retirement->>'severity',''),'Faible');
  v_days integer:=greatest(2,coalesce(nullif(p_retirement->>'days_out','')::integer,5));
  v_risk integer:=greatest(0,least(100,coalesce(nullif(p_retirement->>'aggravation_risk','')::integer,20)));
  v_expected date:=coalesce(p_match_date,current_date)+greatest(2,coalesce(nullif(p_retirement->>'days_out','')::integer,5));
  v_injury_id bigint;
  v_existing_injury boolean:=false;
  v_fitness_loss integer;
  v_payload jsonb;
begin
  perform 1 from public.live_match_sessions where id=p_session_id for update;
  if not found then raise exception 'live session % not found',p_session_id; end if;

  select payload into v_existing
  from public.live_match_effect_commits_v23
  where session_id=p_session_id and effect='medical';

  if v_existing is not null then
    return v_existing || jsonb_build_object('ok',true,'already_applied',true,'model','CB-LIVE-MEDICAL-v23');
  end if;

  if v_injured_id is null then
    return jsonb_build_object('ok',true,'skipped',true,'reason','no_injured_player','model','CB-LIVE-MEDICAL-v23');
  end if;

  select id into v_injury_id
  from public.injuries
  where player_id=v_injured_id and status in ('active','Active')
  order by started_at desc,id desc
  limit 1;

  if v_injury_id is not null then
    v_existing_injury:=true;
  else
    insert into public.injuries(
      player_id,injury_type,severity,started_at,expected_return,
      aggravation_risk,treatment,status
    ) values(
      v_injured_id,v_type,v_severity,coalesce(p_match_date,current_date),v_expected,
      v_risk,'Évaluation post-match + soins','active'
    )
    returning id into v_injury_id;

    if v_injured_id<>p_managed_player_id then
      v_fitness_loss:=case when v_days>=28 then 20 when v_days>=12 then 14 else 8 end;
      update public.players
      set injury_status=v_type,
          fitness=greatest(20,fitness-v_fitness_loss),
          fatigue=greatest(0,fatigue-5)
      where id=v_injured_id;
      if not found then raise exception 'injured player % missing',v_injured_id; end if;
    end if;
  end if;

  v_payload:=jsonb_build_object(
    'ok',true,
    'already_applied',false,
    'existing',v_existing_injury,
    'injury_id',v_injury_id,
    'player_id',v_injured_id,
    'injury_type',v_type,
    'expected_return',v_expected,
    'model','CB-LIVE-MEDICAL-v23'
  );

  insert into public.live_match_effect_commits_v23(session_id,effect,payload)
  values(p_session_id,'medical',v_payload);

  return v_payload;
end;
$function$;

revoke all on function public.apply_live_match_medical_once_v23(bigint,bigint,date,jsonb) from public,anon,authenticated;
grant execute on function public.apply_live_match_medical_once_v23(bigint,bigint,date,jsonb) to service_role;
