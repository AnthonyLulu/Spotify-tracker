CREATE OR REPLACE FUNCTION public.apply_managed_training_day_v22(p_date date, p_player_id bigint, p_morning_session text, p_afternoon_session text, p_intensity text DEFAULT 'Normal'::text, p_difficulty text DEFAULT 'normal'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_date date:=coalesce(p_date,current_date);
  v_player record;
  v_dev record;
  v_attrs jsonb:='{}'::jsonb;
  v_ceilings jsonb:='{}'::jsonb;
  v_primary bigint;
  v_sessions text[]:=array[
    coalesce(nullif(trim(p_morning_session),''),'Repos'),
    coalesce(nullif(trim(p_afternoon_session),''),'Repos')
  ];
  v_slot int;
  v_session text;
  v_targets text[];
  v_attr text;
  v_current numeric;
  v_cap numeric;
  v_old_xp numeric;
  v_total_xp numeric;
  v_gain numeric;
  v_threshold numeric;
  v_spread numeric;
  v_staff_quality numeric:=10;
  v_facility_quality numeric:=1;
  v_personal_base numeric:=1;
  v_age_mult numeric:=1;
  v_condition_mult numeric:=1;
  v_phase_mult numeric:=1;
  v_focus_mult numeric:=1;
  v_difficulty_mult numeric:=1;
  v_intensity_mult numeric:=1;
  v_slot_mult numeric:=1;
  v_training_mult numeric:=1;
  v_age int:=20;
  v_peak int:=25;
  v_decline int:=30;
  v_load numeric:=0;
  v_fatigue_before int:=0;
  v_fitness_before int:=90;
  v_form_before int:=70;
  v_morale_before int:=75;
  v_fatigue_after int:=0;
  v_fitness_after int:=90;
  v_form_after int:=70;
  v_morale_after int:=75;
  v_load_base numeric;
  v_improvements jsonb:='[]'::jsonb;
  v_xp_gains jsonb:='{}'::jsonb;
  v_capped jsonb:='[]'::jsonb;
  v_improved int:=0;
  v_focus text:='mixed';
  v_phase text:='';
  v_injury_risk numeric:=0;
  v_injury_roll int:=0;
  v_training_niggle boolean:=false;
  v_week int:=1;
begin
  select managed_player_id into v_primary
  from public.career_state
  where id='demo';

  if p_player_id is null or not (
    p_player_id=coalesce(v_primary,-1)
    or exists(
      select 1
      from public.academy_roster ar
      where ar.player_id=p_player_id
        and ar.status='active'
        and ar.source_youth_id is null
    )
  ) then
    return jsonb_build_object('ok',false,'reason','player_not_managed','player_id',p_player_id);
  end if;

  select
    p.id,p.name,p.age,p.birth_date,p.current_ability,p.potential,
    p.form,p.fitness,p.morale,p.fatigue,p.injury_status,p.career_focus
  into v_player
  from public.players p
  where p.id=p_player_id;

  if not found then
    return jsonb_build_object('ok',false,'reason','player_not_found','player_id',p_player_id);
  end if;

  select to_jsonb(pa) into v_attrs
  from public.player_attributes pa
  where pa.player_id=p_player_id;

  select *
  into v_dev
  from public.player_development_profiles d
  where d.player_id=p_player_id;

  select coalesce(c.ceilings,'{}'::jsonb)
  into v_ceilings
  from public.player_attribute_ceilings c
  where c.player_id=p_player_id;

  v_attrs:=coalesce(v_attrs,'{}'::jsonb);
  v_ceilings:=coalesce(v_ceilings,'{}'::jsonb);

  select coalesce(avg(level),1)
  into v_facility_quality
  from public.facilities;

  v_age:=coalesce(
    case when v_player.birth_date is not null then extract(year from age(v_date,v_player.birth_date))::int end,
    v_player.age,
    20
  );
  v_peak:=coalesce(v_dev.peak_age,25);
  v_decline:=coalesce(v_dev.decline_start_age,30);
  v_focus:=coalesce(v_player.career_focus,'mixed');
  v_phase:=lower(coalesce(v_dev.development_phase,v_dev.development_context,''));

  v_personal_base:=greatest(.74,least(1.28,
      .72
      +coalesce(v_dev.development_rate,10)*.012
      +coalesce(v_dev.professionalism,10)*.010
      +coalesce(v_dev.coachability,10)*.011
      +coalesce(v_dev.staff_stability,8)*.004
  ));
  v_age_mult:=case
    when v_age<v_peak then 1.05
    when v_age<=v_decline then 1
    else greatest(.68,1-(v_age-v_decline)*.055)
  end;
  v_phase_mult:=case
    when v_phase like '%prospect%' then 1.08
    when v_phase like '%develop%' then 1.05
    when v_phase like '%prime%' then 1
    when v_phase like '%plateau%' then .95
    when v_phase like '%decline%' then .82
    else 1
  end;
  v_difficulty_mult:=case lower(coalesce(p_difficulty,'normal'))
    when 'discovery' then 1.12
    when 'manager' then .94
    when 'hardcore' then .88
    else 1
  end;
  v_intensity_mult:=case lower(coalesce(p_intensity,'normal'))
    when 'léger' then .78
    when 'leger' then .78
    when 'light' then .78
    when 'élevé' then 1.16
    when 'eleve' then 1.16
    when 'high' then 1.16
    else 1
  end;

  for v_slot in 1..2 loop
    v_session:=v_sessions[v_slot];
    v_load_base:=case
      when v_session in ('Endurance','Match play','Déplacements') then 3
      when v_session in ('Service','Retour','Coup droit','Revers','Double') then 2
      when v_session='Récupération' then -.75
      else -1.25
    end;
    v_load:=v_load+v_load_base*v_intensity_mult;

    if v_session in ('Repos','Récupération') then
      continue;
    end if;

    v_targets:=case v_session
      when 'Service' then array['serve_power','serve_precision','first_serve_quality','second_serve_quality','serve_variety','serve_spin','serve_consistency','serve_plus_one','timing']
      when 'Retour' then array['return_game','anticipation','return_aggression','return_consistency','counter_skill','reaction','passing_shot','timing','shot_control']
      when 'Coup droit' then array['forehand','forehand_power','forehand_accuracy','forehand_consistency','topspin','shot_control','timing','shot_selection','serve_plus_one']
      when 'Revers' then array['backhand','backhand_power','backhand_accuracy','backhand_consistency','slice','shot_control','timing','passing_shot']
      when 'Déplacements' then array['movement','speed','acceleration','agility','balance','footwork','athleticism','court_positioning','defensive_skill','defense_to_attack']
      when 'Endurance' then array['stamina','strength','athleticism','natural_fitness','recovery','flexibility','work_rate','rally_tolerance','tenacity']
      when 'Match play' then array['tactics','concentration','composure','fighting_spirit','tenacity','decision_making','shot_selection','shot_control','timing','counter_skill','big_points','consistency','killer_instinct','confidence','determination','court_positioning','transition_game','rally_tolerance','defense_to_attack']
      when 'Double' then array['volley','touch','doubles','half_volley','smash','net_positioning','doubles_communication','poaching','anticipation','transition_game','reaction','timing','footwork','serve_consistency']
      else array[]::text[]
    end;

    select coalesce(max(
      (
        case
          when v_session='Service' then (coalesce(sp.serve_coaching_rating,0)+coalesce(sp.technical_rating,0))/2.0
          when v_session='Retour' then (coalesce(sp.return_coaching_rating,0)+coalesce(sp.tactical_rating,0))/2.0
          when v_session='Double' then (coalesce(sp.doubles_coaching_rating,0)+coalesce(sp.tactical_rating,0)+coalesce(sp.communication_rating,0))/3.0
          when v_session in ('Coup droit','Revers') then (coalesce(sp.technical_rating,0)+coalesce(sp.coach_rating,0))/2.0
          when v_session='Match play' then (coalesce(sp.tactical_rating,0)+coalesce(sp.coach_rating,0))/2.0
          when v_session in ('Déplacements','Endurance') then coalesce(sp.fitness_rating,0)
          else coalesce(sp.coach_rating,10)
        end
      )*coalesce(public.staff_effectiveness_multiplier(sp.id),1)
    ),10)
    into v_staff_quality
    from public.staff s
    join public.staff_profiles sp on sp.id=s.profile_id
    where sp.active=true;

    v_focus_mult:=case
      when v_focus='doubles_only' and v_session in ('Double','Service','Retour','Match play') then 1.12
      when v_focus='doubles_only' then .96
      when v_focus='singles_only' and v_session='Double' then .30
      when v_focus='singles_only' and v_session in ('Service','Retour','Coup droit','Revers','Match play') then 1.08
      when v_focus='singles_priority' and v_session='Double' then .90
      else 1
    end;

    v_condition_mult:=greatest(.70,least(1.08,
      .88+coalesce(v_player.fitness,90)/500.0+coalesce(v_player.morale,75)/700.0-coalesce(v_player.fatigue,15)/550.0
    ));
    v_slot_mult:=case when v_slot=1 then .72 else .62 end;
    v_training_mult:=(.67+v_staff_quality/36.0+v_facility_quality/12.0)
      *v_focus_mult*v_personal_base*v_age_mult*v_condition_mult*v_phase_mult*v_difficulty_mult*v_intensity_mult;
    v_spread:=greatest(.42,least(1,2.4/greatest(1,cardinality(v_targets))));

    foreach v_attr in array v_targets loop
      v_gain:=.52*v_training_mult*v_spread*v_slot_mult;
      v_current:=coalesce((v_attrs->>v_attr)::numeric,10);
      v_cap:=greatest(v_current,least(20,coalesce((v_ceilings->>v_attr)::numeric,20)));
      v_threshold:=(3.35+v_current*.24)
        *case when v_age>v_decline then 1.12 else 1 end
        *case when coalesce(v_dev.coachability,10)<=8 then 1.08 else 1 end;

      select coalesce(xp,0)
      into v_old_xp
      from public.managed_player_training_progress
      where player_id=p_player_id and attribute=v_attr;
      v_old_xp:=coalesce(v_old_xp,0);
      v_total_xp:=v_old_xp+v_gain;

      if v_total_xp>=v_threshold
         and v_current<v_cap
         and coalesce(v_player.current_ability,0)<coalesce(v_player.potential,0)
      then
        execute format(
          'update public.player_attributes set %I=least($1,%I+1) where player_id=$2',
          v_attr,v_attr
        ) using v_cap,p_player_id;
        v_improvements:=v_improvements||jsonb_build_array(
          jsonb_build_object('attribute',v_attr,'from',v_current,'to',least(v_cap,v_current+1),'ceiling',v_cap)
        );
        v_attrs:=jsonb_set(v_attrs,array[v_attr],to_jsonb(least(v_cap,v_current+1)),true);
        v_total_xp:=greatest(0,v_total_xp-v_threshold);
        v_improved:=v_improved+1;
      elsif v_current>=v_cap and v_gain>0 then
        v_capped:=v_capped||jsonb_build_array(
          jsonb_build_object('attribute',v_attr,'value',v_current,'ceiling',v_cap)
        );
      end if;

      insert into public.managed_player_training_progress(player_id,attribute,xp,updated_at)
      values(p_player_id,v_attr,v_total_xp,now())
      on conflict(player_id,attribute)
      do update set xp=excluded.xp,updated_at=excluded.updated_at;

      if p_player_id=coalesce(v_primary,-1) then
        insert into public.user_training_progress(attribute,xp,updated_at)
        values(v_attr,v_total_xp,now())
        on conflict(attribute)
        do update set xp=excluded.xp,updated_at=excluded.updated_at;
      end if;

      v_xp_gains:=jsonb_set(
        v_xp_gains,
        array[v_attr],
        to_jsonb(round((coalesce((v_xp_gains->>v_attr)::numeric,0)+v_gain)::numeric,4)),
        true
      );
    end loop;
  end loop;

  v_fatigue_before:=coalesce(v_player.fatigue,15);
  v_fitness_before:=coalesce(v_player.fitness,90);
  v_form_before:=coalesce(v_player.form,70);
  v_morale_before:=coalesce(v_player.morale,75);

  v_fatigue_after:=greatest(0,least(100,
    v_fatigue_before
    +round(greatest(-4,least(6,(v_load-2.0)*.85)))::int
  ));
  v_fitness_after:=greatest(40,least(100,
    v_fitness_before
    +case
      when v_load<=0 then 2
      when v_load<=3.5 then 1
      when v_load>=6.5 then -2
      when v_load>=5 then -1
      else 0
    end
  ));
  v_form_after:=greatest(35,least(100,
    v_form_before
    +case when v_load between 2.5 and 5.5 then 1 when v_load>=7 then -1 else 0 end
  ));
  v_morale_after:=greatest(35,least(100,
    v_morale_before
    +case
      when v_sessions[1]='Repos' and v_sessions[2]='Repos' then 1
      when v_load between 2 and 5.5 then 1
      when v_load>=7 then -1
      else 0
    end
  ));

  v_injury_risk:=greatest(0,least(35,
      greatest(0,v_fatigue_after-55)*.20
      +greatest(0,v_load-5)*2.1
      +greatest(0,coalesce(v_dev.injury_proneness,10)-10)*.55
      +case lower(coalesce(p_difficulty,'normal')) when 'manager' then 1.5 when 'hardcore' then 3.0 else 0 end
  ));
  v_injury_roll:=mod(abs(hashtext('daily-training-v22|'||p_player_id::text||'|'||v_date::text)),1000);
  if coalesce(v_player.injury_status,'Fit')='Fit'
     and v_injury_roll < round(v_injury_risk*10)
     and v_injury_risk>=4
  then
    v_training_niggle:=true;
  end if;

  update public.players
  set fatigue=v_fatigue_after,
      fitness=case when v_training_niggle then greatest(40,v_fitness_after-4) else v_fitness_after end,
      form=v_form_after,
      morale=v_morale_after,
      injury_status=case when v_training_niggle then 'Gêne musculaire' else injury_status end
  where id=p_player_id;

  if p_player_id=coalesce(v_primary,-1) then
    update public.career_state
    set fatigue=v_fatigue_after,
        fitness=case when v_training_niggle then greatest(40,v_fitness_after-4) else v_fitness_after end,
        form=v_form_after,
        morale=v_morale_after,
        injury_status=case when v_training_niggle then 'Gêne musculaire' else injury_status end,
        updated_at=now()
    where id='demo';
  end if;

  v_week:=case
    when extract(year from v_date)::int=2025
      then greatest(1,((v_date-date '2025-12-01')/7)+1)
    else greatest(1,((v_date-make_date(extract(year from v_date)::int,1,1))/7)+1)
  end;

  insert into public.career_event_log(
    event_date,week,system,event_type,entity_type,entity_id,summary,payload
  ) values(
    v_date,v_week,'training','daily_training_v22','player',p_player_id,
    coalesce(v_player.name,'Joueur')||' · '||v_sessions[1]||' / '||v_sessions[2],
    jsonb_build_object(
      'morning',v_sessions[1],
      'afternoon',v_sessions[2],
      'intensity',coalesce(p_intensity,'Normal'),
      'load',round(v_load,2),
      'fatigue_before',v_fatigue_before,
      'fatigue_after',v_fatigue_after,
      'fitness_before',v_fitness_before,
      'fitness_after',case when v_training_niggle then greatest(40,v_fitness_after-4) else v_fitness_after end,
      'xp_gains',v_xp_gains,
      'improvements',v_improvements,
      'training_niggle',v_training_niggle,
      'model','CB-DAILY-TRAINING-v22'
    )
  );

  return jsonb_build_object(
    'ok',true,
    'date',v_date,
    'player_id',p_player_id,
    'player_name',v_player.name,
    'morning',v_sessions[1],
    'afternoon',v_sessions[2],
    'intensity',coalesce(p_intensity,'Normal'),
    'load',round(v_load,2),
    'fatigue_before',v_fatigue_before,
    'fatigue_after',v_fatigue_after,
    'fitness_before',v_fitness_before,
    'fitness_after',case when v_training_niggle then greatest(40,v_fitness_after-4) else v_fitness_after end,
    'form_after',v_form_after,
    'morale_after',v_morale_after,
    'xp_gains',v_xp_gains,
    'improvements',v_improvements,
    'attribute_improvements',v_improved,
    'capped',v_capped,
    'training_niggle',v_training_niggle,
    'development_multiplier',round((v_personal_base*v_age_mult*v_phase_mult*v_difficulty_mult)::numeric,3),
    'model','CB-DAILY-TRAINING-v22'
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
  perform pg_advisory_xact_lock(2200261201);

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
  v_doubles:=public.simulate_world_doubles_tournaments(v_from,v_to);

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

revoke all on function public.apply_managed_training_day_v22(date,bigint,text,text,text,text) from public,anon,authenticated;
grant execute on function public.apply_managed_training_day_v22(date,bigint,text,text,text,text) to service_role;
revoke all on function public.advance_career_day_v22(jsonb,text) from public,anon,authenticated;
grant execute on function public.advance_career_day_v22(jsonb,text) to service_role;
