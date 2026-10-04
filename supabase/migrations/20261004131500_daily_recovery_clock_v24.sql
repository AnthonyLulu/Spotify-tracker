CREATE OR REPLACE FUNCTION public.advance_career_day_v22(p_today_plan jsonb DEFAULT '{}'::jsonb, p_difficulty text DEFAULT 'normal'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_current public.career_state%rowtype;
  v_from date;
  v_to date;
  v_week int;
  v_weekly_due boolean;
  v_day_index int;
  v_player_id bigint;
  v_plan jsonb;
  v_training jsonb:='[]'::jsonb;
  v_report jsonb;
  v_recovery jsonb:='{}'::jsonb;
  v_improvements int:=0;
  v_niggles int:=0;
  v_world_daily jsonb:=jsonb_build_object(
    'mode','weekly_checkpoint',
    'deferred',true,
    'reason','world_simulation_batched_weekly'
  );
  v_pending_decisions int:=0;
  v_pending_matches int:=0;
  v_tournament_days int:=0;
  v_stop_reason text:=null;
  v_week_start date;
  v_last_checkpoint date;
  v_due jsonb:='{}'::jsonb;
  v_due_count int:=0;
  v_managed_world jsonb:='{}'::jsonb;
begin
  if not pg_try_advisory_xact_lock(2200261201) then
    return jsonb_build_object(
      'ok',false,
      'reason','clock_busy',
      'retryable',true,
      'model','CB-DAILY-CLOCK-v24'
    );
  end if;

  select * into v_current
  from public.career_state
  where id='demo'
  for update;

  if not found then
    return jsonb_build_object('ok',false,'reason','career_missing');
  end if;

  v_from:=coalesce(v_current.career_date,date '2025-12-01');

  select last_weekly_checkpoint_date
  into v_last_checkpoint
  from public.career_clock_state_v22
  where id='demo';

  v_due:=public.managed_due_matches_v22(v_from);
  v_due_count:=coalesce((v_due->>'count')::int,0);
  if v_due_count>0 then
    -- A loaded save can resume directly on match day before the daily world layer
    -- has reserved its exact bracket slot. Re-run only the managed tournament
    -- layer for the current date, then rebuild the ticket before stopping time.
    v_managed_world:=public.advance_managed_tournament_world_day_v22(v_from);
    v_due:=public.managed_due_matches_v22(v_from);
    v_due_count:=coalesce((v_due->>'count')::int,0);
    return jsonb_build_object(
      'ok',false,'reason','pending_match','date',v_from,
      'stop_reason','match','retryable',false,
      'due_matches',v_due,
      'world_daily',jsonb_build_object('managed_tournaments',v_managed_world),
      'model','CB-DAILY-CLOCK-v24'
    );
  end if;

  -- A Sunday checkpoint must never run while a managed match is still due.
  -- Resolve every match scheduled on the current date first, then close the week.
  if extract(isodow from v_from)::int=7
     and coalesce(v_last_checkpoint,date '1900-01-01')<v_from
  then
    return jsonb_build_object(
      'ok',false,
      'reason','weekly_checkpoint_required',
      'checkpoint_required',true,
      'checkpoint_date',v_from,
      'from_date',greatest(make_date(extract(year from v_from)::int,1,1),v_from-6),
      'stop_reason','weekly_checkpoint',
      'model','CB-DAILY-CLOCK-v24'
    );
  end if;

  v_to:=v_from+1;
  v_due:=public.managed_due_matches_v22(v_to);

  if extract(year from v_to)::int>extract(year from v_from)::int
     and coalesce(v_current.season_year,extract(year from v_from)::int)<extract(year from v_to)::int
  then
    return jsonb_build_object(
      'ok',false,
      'requires_rollover',true,
      'from_date',v_from,
      'next_date',v_to,
      'new_year',extract(year from v_to)::int,
      'model','CB-DAILY-CLOCK-v24'
    );
  end if;

  v_week:=case
    when extract(year from v_to)::int=2025
      then greatest(1,((v_to-date '2025-12-01')/7)+1)
    else greatest(1,((v_to-make_date(extract(year from v_to)::int,1,1))/7)+1)
  end;
  v_day_index:=extract(isodow from v_to)::int;
  v_weekly_due:=v_day_index=7;
  v_week_start:=greatest(
    make_date(extract(year from v_to)::int,1,1),
    v_to-(v_day_index-1)
  );

  for v_player_id in
    select distinct x.player_id
    from (
      select v_current.managed_player_id as player_id
      union all
      select ar.player_id
      from public.academy_roster ar
      where ar.status='active'
        and ar.player_id is not null
        and ar.source_youth_id is null
    ) x
    where x.player_id is not null
  loop
    v_recovery:=public.apply_managed_recovery_day_v24(v_to,v_player_id);
    if coalesce((v_recovery->>'ok')::boolean,false)=false then
      raise exception 'daily recovery failed for player %: %',v_player_id,coalesce(v_recovery->>'reason','unknown');
    end if;

    v_plan:=coalesce(
      p_today_plan->(v_player_id::text),
      jsonb_build_object('morning','Repos','afternoon','Repos','intensity','Léger')
    );

    if exists(
      select 1
      from jsonb_array_elements(coalesce(v_due->'matches','[]'::jsonb)) x
      where coalesce((x->>'player_id')::bigint,0)=v_player_id
         or (
           coalesce(x->>'discipline','')='doubles'
           and coalesce((x->>'partner_id')::bigint,0)=v_player_id
         )
    ) then
      v_plan:=jsonb_build_object(
        'morning','Échauffement',
        'afternoon','Match',
        'intensity','Léger',
        'automatic_match_day',true
      );
    elsif coalesce((v_recovery->>'medical_training_restriction')::boolean,false) then
      v_plan:=jsonb_build_object(
        'morning','Récupération',
        'afternoon','Repos',
        'intensity','Léger',
        'automatic_medical_restriction',true
      );
    end if;

    v_report:=public.apply_managed_training_day_v22(
      v_to,
      v_player_id,
      coalesce(v_plan->>'morning','Repos'),
      coalesce(v_plan->>'afternoon','Repos'),
      coalesce(v_plan->>'intensity','Normal'),
      coalesce(p_difficulty,'normal')
    );

    if coalesce((v_plan->>'automatic_match_day')::boolean,false) then
      v_report:=v_report||jsonb_build_object(
        'automatic_match_day',true,
        'competitive_load_owner','match_center'
      );
    elsif coalesce((v_plan->>'automatic_medical_restriction')::boolean,false) then
      v_report:=v_report||jsonb_build_object(
        'automatic_medical_restriction',true,
        'training_owner','medical_staff'
      );
    end if;
    v_report:=v_report||jsonb_build_object('recovery',v_recovery);
    v_training:=v_training||jsonb_build_array(v_report);
    v_improvements:=v_improvements+coalesce((v_report->>'attribute_improvements')::int,0);
    if coalesce((v_report->>'training_niggle')::boolean,false) then
      v_niggles:=v_niggles+1;
    end if;
  end loop;

  -- The global world remains batched weekly, but tournaments containing managed
  -- players advance on their real calendar every day. AI matches in that event
  -- progress while the managed match remains pending for the Match Center.
  v_managed_world:=public.advance_managed_tournament_world_day_v22(v_to);

  update public.career_state
  set career_date=v_to,
      week=v_week,
      season_year=extract(year from v_to)::int,
      updated_at=now()
  where id='demo';

  insert into public.career_clock_state_v22(id,last_daily_date,updated_at)
  values('demo',v_to,now())
  on conflict(id) do update
  set last_daily_date=excluded.last_daily_date,
      updated_at=excluded.updated_at;

  select count(*)::int
  into v_pending_decisions
  from public.inbox_items i
  where i.decision_status='pending'
    and coalesce(i.game_date,v_to)<=v_to;

  v_due:=public.managed_due_matches_v22(v_to);
  v_pending_matches:=coalesce((v_due->>'count')::int,0);

  select count(distinct t.id)::int
  into v_tournament_days
  from public.tournaments t
  join public.entries e on e.tournament_id=t.id
  join public.academy_roster ar on ar.player_id=e.player_id and ar.status='active'
  where e.status in ('accepted','entered','main','qualifying','alternate')
    and v_to between coalesce(t.qualifying_start_date,t.start_date) and t.end_date;

  if v_pending_matches>0 then
    v_stop_reason:='match';
  elsif v_pending_decisions>0 then
    v_stop_reason:='decision';
  elsif v_niggles>0 then
    v_stop_reason:='medical';
  elsif v_improvements>0 then
    v_stop_reason:='training_progress';
  elsif v_tournament_days>0 then
    v_stop_reason:='tournament';
  elsif v_weekly_due then
    v_stop_reason:='weekly_checkpoint';
  end if;

  insert into public.career_event_log(
    event_date,week,system,event_type,entity_type,entity_id,summary,payload
  ) values(
    v_to,v_week,'clock','daily_tick_v22','career',null,
    'Journée du '||to_char(v_to,'YYYY-MM-DD')||' validée',
    jsonb_build_object(
      'from_date',v_from,
      'date',v_to,
      'day_index',v_day_index,
      'weekly_checkpoint_due',v_weekly_due,
      'stop_reason',v_stop_reason,
      'training_players',jsonb_array_length(v_training),
      'training_improvements',v_improvements,
      'training_niggles',v_niggles,
      'model','CB-DAILY-CLOCK-v24'
    )
  );

  return jsonb_build_object(
    'ok',true,
    'from_date',v_from,
    'date',v_to,
    'week',v_week,
    'day_index',v_day_index,
    'weekly_checkpoint_due',v_weekly_due,
    'week_start_date',v_week_start,
    'training',v_training,
    'training_improvements',v_improvements,
    'training_niggles',v_niggles,
    'pending_decisions',v_pending_decisions,
    'pending_matches',v_pending_matches,
    'due_matches',v_due,
    'tournament_days',v_tournament_days,
    'stop_reason',v_stop_reason,
    'world_daily',v_world_daily||jsonb_build_object('managed_tournaments',v_managed_world),
    'model','CB-DAILY-CLOCK-v24'
  );
end;
$function$;

revoke all on function public.advance_career_day_v22(jsonb,text) from public,anon,authenticated;
grant execute on function public.advance_career_day_v22(jsonb,text) to service_role;
