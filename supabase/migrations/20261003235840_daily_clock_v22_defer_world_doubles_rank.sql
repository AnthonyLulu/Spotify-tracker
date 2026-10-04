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
  v_improvements int:=0;
  v_niggles int:=0;
  v_acceptance jsonb;
  v_qualifying jsonb;
  v_singles jsonb;
  v_doubles_q jsonb;
  v_doubles jsonb;
  v_pending_decisions int:=0;
  v_pending_matches int:=0;
  v_tournament_days int:=0;
  v_stop_reason text:=null;
  v_week_start date;
begin
  if not pg_try_advisory_xact_lock(2200261201) then
    return jsonb_build_object(
      'ok',false,
      'reason','clock_busy',
      'retryable',true,
      'model','CB-DAILY-CLOCK-v22'
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
  v_to:=v_from+1;

  if extract(year from v_to)::int>extract(year from v_from)::int
     and coalesce(v_current.season_year,extract(year from v_from)::int)<extract(year from v_to)::int
  then
    return jsonb_build_object(
      'ok',false,
      'requires_rollover',true,
      'from_date',v_from,
      'next_date',v_to,
      'new_year',extract(year from v_to)::int,
      'model','CB-DAILY-CLOCK-v22'
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
    v_plan:=coalesce(
      p_today_plan->(v_player_id::text),
      jsonb_build_object('morning','Repos','afternoon','Repos','intensity','Léger')
    );

    v_report:=public.apply_managed_training_day_v22(
      v_to,
      v_player_id,
      coalesce(v_plan->>'morning','Repos'),
      coalesce(v_plan->>'afternoon','Repos'),
      coalesce(v_plan->>'intensity','Normal'),
      coalesce(p_difficulty,'normal')
    );

    v_training:=v_training||jsonb_build_array(v_report);
    v_improvements:=v_improvements+coalesce((v_report->>'attribute_improvements')::int,0);
    if coalesce((v_report->>'training_niggle')::boolean,false) then
      v_niggles:=v_niggles+1;
    end if;
  end loop;

  -- Daily tournament layer: only the progressive ATP/ITF/doubles windows.
  -- The much heavier global junior/team ecosystem stays on the weekly checkpoint.
  v_acceptance:=public.refresh_world_acceptance_window(v_from,v_to);
  v_qualifying:=public.simulate_world_qualifying_window(v_from,v_to);
  v_singles:=public.advance_world_tournament_window(v_from,v_to);
  v_doubles_q:=public.simulate_world_doubles_qualifying_window(v_from,v_to);
  -- ATP doubles rankings and the full doubles world are weekly systems.
  -- Managed doubles matches stay interactive in the Match Center; the world refresh
  -- runs on the weekly checkpoint to avoid recalculating the entire ranking every day.
  v_doubles:=jsonb_build_object(
    'deferred',true,
    'reason','weekly_checkpoint',
    'from',v_from,
    'to',v_to,
    'model','CB-DOUBLES-DAILY-DEFER-v22'
  );

  update public.career_state
  set career_date=v_to,
      week=v_week,
      season_year=extract(year from v_to)::int,
      updated_at=now()
  where id='demo';

  select count(*)::int
  into v_pending_decisions
  from public.inbox_items i
  where i.decision_status='pending'
    and coalesce(i.game_date,v_to)<=v_to;

  select count(*)::int
  into v_pending_matches
  from public.world_tournament_matches m
  where m.winner_id is null
    and exists(
      select 1
      from public.academy_roster ar
      where ar.status='active'
        and ar.player_id is not null
        and (ar.player_id=m.player_a_id or ar.player_id=m.player_b_id)
    );

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
      'model','CB-DAILY-CLOCK-v22'
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
    'tournament_days',v_tournament_days,
    'stop_reason',v_stop_reason,
    'world_daily',jsonb_build_object(
      'acceptance',v_acceptance,
      'qualifying',v_qualifying,
      'singles',v_singles,
      'doubles_qualifying',v_doubles_q,
      'doubles',v_doubles
    ),
    'model','CB-DAILY-CLOCK-v22'
  );
end;
$function$;

revoke all on function public.advance_career_day_v22(jsonb,text) from public,anon,authenticated;
grant execute on function public.advance_career_day_v22(jsonb,text) to service_role;
