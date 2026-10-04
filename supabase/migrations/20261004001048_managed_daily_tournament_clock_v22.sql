CREATE OR REPLACE FUNCTION public.advance_managed_tournament_world_day_v22(p_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  r record;
  v_q jsonb;
  v_main jsonb;
  v_doubles jsonb:='{}'::jsonb;
  v_rows jsonb:='[]'::jsonb;
begin
  for r in
    select distinct e.tournament_id,t.name,t.qualifying_start_date,t.qualifying_end_date,
           t.main_draw_start_date,t.start_date,t.end_date
    from public.entries e
    join public.tournaments t on t.id=e.tournament_id
    where e.player_id in (
      select cs.managed_player_id from public.career_state cs where cs.id='demo'
      union
      select ar.player_id from public.academy_roster ar
      where ar.status='active' and ar.player_id is not null and ar.source_youth_id is null
    )
      and coalesce(e.status,'entered') not in ('withdrawn','declined','rejected','completed')
      and p_date between coalesce(t.qualifying_start_date,t.main_draw_start_date,t.start_date) and t.end_date
  loop
    v_q:=null; v_main:=null;
    if r.qualifying_start_date is not null
       and p_date between r.qualifying_start_date and coalesce(r.qualifying_end_date,r.qualifying_start_date)
    then
      v_q:=public.advance_world_qualifying_tournament(r.tournament_id,p_date);
    end if;
    if p_date>=coalesce(r.main_draw_start_date,r.start_date) then
      v_main:=public.advance_world_knockout_tournament(r.tournament_id,p_date);
    end if;
    v_rows:=v_rows||jsonb_build_array(jsonb_build_object(
      'tournament_id',r.tournament_id,'name',r.name,
      'qualifying',v_q,'main',v_main
    ));
  end loop;

  v_doubles:=public.reserve_managed_doubles_live_matches_v22(p_date);

  return jsonb_build_object(
    'ok',true,'date',p_date,'events',v_rows,
    'count',jsonb_array_length(v_rows),
    'doubles',v_doubles,
    'model','CB-MANAGED-TOURNAMENT-WORLD-DAY-v22'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.managed_due_matches_v22(p_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare
  r record;
  v_primary bigint;
  v_wins int;
  v_loss boolean;
  v_draw int;
  v_bracket int;
  v_rounds int;
  v_qdraw int;
  v_qslots int;
  v_qrounds int;
  v_main_wins int;
  v_idx int;
  v_code text;
  v_phase text;
  v_schedule jsonb;
  v_match_date date;
  v_matches jsonb:='[]'::jsonb;
begin
  select managed_player_id into v_primary
  from public.career_state where id='demo';

  -- Singles.
  for r in
    select distinct e.player_id,e.tournament_id,e.entry_method,t.name,t.circuit,t.category,
           t.singles_draw_size,t.draw_size,t.qualifying_draw_size,
           t.qualifying_start_date,t.qualifying_end_date,t.main_draw_start_date,t.start_date,t.end_date
    from public.entries e
    join public.tournaments t on t.id=e.tournament_id
    where e.player_id in (
      select v_primary
      union
      select ar.player_id from public.academy_roster ar
      where ar.status='active' and ar.player_id is not null and ar.source_youth_id is null
    )
      and coalesce(e.status,'entered') not in ('withdrawn','declined','rejected','completed')
      and p_date between coalesce(t.qualifying_start_date,t.main_draw_start_date,t.start_date) and t.end_date
      and not exists(
        select 1 from public.tournament_runs tr
        where tr.tournament_id=e.tournament_id and tr.managed_player_id=e.player_id
      )
  loop
    select exists(
      select 1 from public.live_match_sessions s
      where s.tournament_id=r.tournament_id and s.managed_player_id=r.player_id
        and s.status='committed'
        and coalesce(s.stats->'_meta'->>'match_type','singles')<>'doubles'
        and (
          coalesce(s.stats->'_retirement'->>'winner','')='opponent'
          or s.user_sets<s.opponent_sets
        )
    ) into v_loss;
    if v_loss then continue; end if;

    select count(*)::int into v_wins
    from public.live_match_sessions s
    where s.tournament_id=r.tournament_id and s.managed_player_id=r.player_id
      and s.status='committed'
      and coalesce(s.stats->'_meta'->>'match_type','singles')<>'doubles'
      and (
        coalesce(s.stats->'_retirement'->>'winner','')='user'
        or s.user_sets>s.opponent_sets
      );

    v_draw:=greatest(8,coalesce(r.singles_draw_size,r.draw_size,32));
    v_bracket:=case when v_draw<=8 then 8 when v_draw<=16 then 16 when v_draw<=32 then 32
                    when v_draw<=64 then 64 when v_draw<=128 then 128 else 256 end;
    v_rounds:=case v_bracket when 8 then 3 when 16 then 4 when 32 then 5 when 64 then 6 when 128 then 7 else 8 end;

    v_phase:='main';
    v_qrounds:=0;
    if coalesce(r.entry_method,'')='qualifying'
       or coalesce(r.entry_method,'')='protected_qualifying'
       or coalesce(r.entry_method,'') like '%_qualifying'
    then
      select greatest(1,coalesce(fr.qualifier_count,1))
      into v_qslots
      from public.tournament_format_rules fr
      where fr.circuit=r.circuit and fr.category=r.category
        and fr.main_draw_size=v_draw
      limit 1;
      v_qslots:=greatest(1,coalesce(v_qslots,1));
      v_qdraw:=greatest(1,coalesce(r.qualifying_draw_size,v_qslots));
      v_qrounds:=case
        when v_qdraw<=v_qslots*2 then 1
        when v_qdraw<=v_qslots*4 then 2
        when v_qdraw<=v_qslots*8 then 3
        when v_qdraw<=v_qslots*16 then 4
        else 5 end;
    end if;

    if v_qrounds>0 and v_wins<v_qrounds then
      v_phase:='qualifying';
      v_code:='Q'||(v_wins+1)::text;
    else
      v_main_wins:=greatest(0,v_wins-v_qrounds);
      if v_main_wins>=v_rounds then continue; end if;
      v_idx:=v_main_wins+1;
      v_code:=case
        when v_idx=v_rounds then 'F'
        when v_idx=v_rounds-1 then 'SF'
        when v_idx=v_rounds-2 then 'QF'
        when v_idx=v_rounds-3 then 'R16'
        when v_idx=v_rounds-4 then 'R32'
        when v_idx=v_rounds-5 then 'R64'
        when v_idx=v_rounds-6 then 'R128'
        else 'R256' end;
    end if;

    v_schedule:=public.managed_tournament_match_date_v22(
      r.tournament_id,r.player_id,v_code,v_phase,'singles'
    );
    v_match_date:=nullif(v_schedule->>'match_date','')::date;
    if v_match_date is not null and v_match_date<=p_date then
      v_matches:=v_matches||jsonb_build_array(jsonb_build_object(
        'discipline','singles','player_id',r.player_id,'tournament_id',r.tournament_id,
        'tournament_name',r.name,'round',v_code,'phase',v_phase,
        'match_date',v_match_date,'overdue',v_match_date<p_date,'schedule',v_schedule
      ));
    end if;
  end loop;

  -- Doubles.
  for r in
    select distinct e.player_id,e.partner_id,e.tournament_id,e.entry_method,t.name,
           t.doubles_draw_size,t.main_draw_start_date,t.start_date,t.end_date
    from public.managed_doubles_entries e
    join public.tournaments t on t.id=e.tournament_id
    where e.player_id in (
      select v_primary
      union
      select ar.player_id from public.academy_roster ar
      where ar.status='active' and ar.player_id is not null and ar.source_youth_id is null
    )
      and coalesce(e.status,'entered') not in ('withdrawn','declined','rejected','completed')
      and p_date between coalesce(t.main_draw_start_date,t.start_date) and t.end_date
      and not exists(
        select 1 from public.doubles_runs dr
        where dr.tournament_id=e.tournament_id and dr.managed_player_id=e.player_id
      )
  loop
    select exists(
      select 1 from public.live_match_sessions s
      where s.tournament_id=r.tournament_id and s.managed_player_id=r.player_id
        and s.status='committed'
        and coalesce(s.stats->'_meta'->>'match_type','')='doubles'
        and s.user_sets<s.opponent_sets
    ) into v_loss;
    if v_loss then continue; end if;

    select count(*)::int into v_wins
    from public.live_match_sessions s
    where s.tournament_id=r.tournament_id and s.managed_player_id=r.player_id
      and s.status='committed'
      and coalesce(s.stats->'_meta'->>'match_type','')='doubles'
      and s.user_sets>s.opponent_sets;

    v_draw:=greatest(4,coalesce(r.doubles_draw_size,16));
    v_bracket:=case when v_draw<=4 then 4 when v_draw<=8 then 8 when v_draw<=16 then 16
                    when v_draw<=32 then 32 else 64 end;
    v_rounds:=case v_bracket when 4 then 2 when 8 then 3 when 16 then 4 when 32 then 5 else 6 end;
    if v_wins>=v_rounds then continue; end if;
    v_idx:=v_wins+1;
    v_code:=case
      when v_idx=v_rounds then 'F'
      when v_idx=v_rounds-1 then 'SF'
      when v_idx=v_rounds-2 then 'QF'
      when v_idx=v_rounds-3 then 'R16'
      when v_idx=v_rounds-4 then 'R32'
      else 'R64' end;

    v_schedule:=public.managed_tournament_match_date_v22(
      r.tournament_id,r.player_id,v_code,'main','doubles'
    );
    v_match_date:=nullif(v_schedule->>'match_date','')::date;
    if v_match_date is not null and v_match_date<=p_date then
      v_matches:=v_matches||jsonb_build_array(jsonb_build_object(
        'discipline','doubles','player_id',r.player_id,'partner_id',r.partner_id,
        'tournament_id',r.tournament_id,'tournament_name',r.name,
        'round',v_code,'phase','main','match_date',v_match_date,
        'overdue',v_match_date<p_date,'schedule',v_schedule
      ));
    end if;
  end loop;

  return jsonb_build_object(
    'ok',true,'date',p_date,'count',jsonb_array_length(v_matches),
    'matches',v_matches,'model','CB-MANAGED-DUE-MATCHES-v22'
  );
end;
$function$;

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

  select last_weekly_checkpoint_date
  into v_last_checkpoint
  from public.career_clock_state_v22
  where id='demo';

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
      'model','CB-DAILY-CLOCK-v22'
    );
  end if;

  v_due:=public.managed_due_matches_v22(v_from);
  v_due_count:=coalesce((v_due->>'count')::int,0);
  if v_due_count>0 then
    return jsonb_build_object(
      'ok',false,'reason','pending_match','date',v_from,
      'stop_reason','match','retryable',false,
      'due_matches',v_due,
      'model','CB-DAILY-CLOCK-v22'
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

    if exists(
      select 1
      from jsonb_array_elements(coalesce(v_due->'matches','[]'::jsonb)) x
      where coalesce((x->>'player_id')::bigint,0)=v_player_id
    ) then
      v_plan:=jsonb_build_object(
        'morning','Récupération',
        'afternoon','Repos',
        'intensity','Léger',
        'automatic_match_day',true
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
    'due_matches',v_due,
    'tournament_days',v_tournament_days,
    'stop_reason',v_stop_reason,
    'world_daily',v_world_daily||jsonb_build_object('managed_tournaments',v_managed_world),
    'model','CB-DAILY-CLOCK-v22'
  );
end;
$function$;
