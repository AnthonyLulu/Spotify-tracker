create or replace function public.managed_post_match_recovery_context_v23(p_date date, p_player_id bigint)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_date date:=coalesce(p_date,current_date);
  v_burden numeric:=0;
  v_duration int:=0;
  v_travel numeric:=0;
  v_matches int:=0;
  v_medical_quality numeric:=10;
  v_physio_hours int:=0;
  v_recovery_attr numeric:=10;
  v_medical_environment numeric:=10;
  v_capacity numeric:=1;
begin
  select
    coalesce(sum(
      case (v_date-mh.match_date)
        when 1 then coalesce((pl.value->>'fatigue_added')::numeric,0)*.72
        when 2 then coalesce((pl.value->>'fatigue_added')::numeric,0)*.34
        when 3 then coalesce((pl.value->>'fatigue_added')::numeric,0)*.14
        else 0
      end
    ),0),
    coalesce(max((mh.match_data->'recovery'->>'duration_minutes')::int),0),
    coalesce(sum(coalesce((pl.value->>'travel_load')::numeric,0)),0),
    count(distinct mh.id)::int
  into v_burden,v_duration,v_travel,v_matches
  from public.match_history mh
  cross join lateral jsonb_array_elements(
    coalesce(mh.match_data->'recovery'->'player_loads','[]'::jsonb)
  ) pl(value)
  where mh.match_date between v_date-3 and v_date-1
    and coalesce(mh.match_data->'recovery'->>'version','')='CB-POST-MATCH-RECOVERY-v23'
    and coalesce((pl.value->>'player_id')::bigint,0)=p_player_id;

  select coalesce(max(
    coalesce(sp.medical_rating,0)*coalesce(public.staff_effectiveness_multiplier(sp.id),1)
  ),10)
  into v_medical_quality
  from public.player_staff_assignments psa
  join public.staff_profiles sp on sp.id=psa.staff_profile_id
  where psa.player_id=p_player_id
    and psa.active=true
    and sp.active=true
    and coalesce(sp.operational_status,'active')<>'retired';

  select coalesce(physio_hours,0)
  into v_physio_hours
  from public.medical_plan
  where id='demo';

  select coalesce((to_jsonb(pa)->>'recovery')::numeric,10)
  into v_recovery_attr
  from public.player_attributes pa
  where pa.player_id=p_player_id;

  select coalesce(medical_environment,10)
  into v_medical_environment
  from public.player_development_profiles
  where player_id=p_player_id;

  v_medical_quality:=coalesce(v_medical_quality,10);
  v_physio_hours:=coalesce(v_physio_hours,0);
  v_recovery_attr:=coalesce(v_recovery_attr,10);
  v_medical_environment:=coalesce(v_medical_environment,10);
  v_capacity:=greatest(.78,least(1.48,
    .72
    +v_recovery_attr*.018
    +v_medical_quality*.014
    +v_medical_environment*.006
    +least(12,v_physio_hours)*.006
  ));

  return jsonb_build_object(
    'ok',true,
    'date',v_date,
    'player_id',p_player_id,
    'recent_matches',v_matches,
    'post_match_burden',round(v_burden,2),
    'recent_match_duration',v_duration,
    'recent_travel_load',round(v_travel,2),
    'medical_quality',round(v_medical_quality,2),
    'physio_hours',v_physio_hours,
    'recovery_attribute',round(v_recovery_attr,2),
    'medical_environment',round(v_medical_environment,2),
    'recovery_capacity',round(v_capacity,3),
    'model','CB-POST-MATCH-RECOVERY-v23'
  );
end;
$function$;

revoke all on function public.managed_post_match_recovery_context_v23(date,bigint) from public,anon,authenticated;
grant execute on function public.managed_post_match_recovery_context_v23(date,bigint) to service_role;

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
  v_competitive_match_day boolean:=false;
  v_recovery_context jsonb:='{}'::jsonb;
  v_post_match_burden numeric:=0;
  v_recovery_capacity numeric:=1;
  v_medical_quality numeric:=10;
  v_recent_match_duration int:=0;
  v_recent_travel_load numeric:=0;
  v_post_match_recovery int:=0;
  v_post_match_overreach int:=0;
  v_recovery_slots int:=0;
  v_hard_slots int:=0;
  v_post_match_training_mult numeric:=1;
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

  v_competitive_match_day:=lower(v_sessions[1]) in ('échauffement','echauffement')
    and lower(v_sessions[2])='match';

  v_recovery_context:=public.managed_post_match_recovery_context_v23(v_date,p_player_id);
  v_post_match_burden:=coalesce((v_recovery_context->>'post_match_burden')::numeric,0);
  v_recovery_capacity:=coalesce((v_recovery_context->>'recovery_capacity')::numeric,1);
  v_medical_quality:=coalesce((v_recovery_context->>'medical_quality')::numeric,10);
  v_recent_match_duration:=coalesce((v_recovery_context->>'recent_match_duration')::int,0);
  v_recent_travel_load:=coalesce((v_recovery_context->>'recent_travel_load')::numeric,0);
  v_recovery_slots:=
    (case when v_sessions[1] in ('Repos','Récupération') then 1 else 0 end)
    +(case when v_sessions[2] in ('Repos','Récupération') then 1 else 0 end);
  v_hard_slots:=
    (case when v_sessions[1] in ('Endurance','Match play','Déplacements') then 1 else 0 end)
    +(case when v_sessions[2] in ('Endurance','Match play','Déplacements') then 1 else 0 end);
  v_post_match_training_mult:=greatest(.60,least(1,1-v_post_match_burden*.025));

  for v_slot in 1..2 loop
    v_session:=v_sessions[v_slot];
    v_load_base:=case
      when v_competitive_match_day and lower(v_session) in ('échauffement','echauffement','match') then 0
      when v_session in ('Endurance','Match play','Déplacements') then 3
      when v_session in ('Service','Retour','Coup droit','Revers','Double') then 2
      when v_session='Récupération' then -.75
      else -1.25
    end;
    v_load:=v_load+v_load_base*v_intensity_mult;

    if v_session in ('Repos','Récupération')
       or (v_competitive_match_day and lower(v_session) in ('échauffement','echauffement','match'))
    then
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
      *v_focus_mult*v_personal_base*v_age_mult*v_condition_mult*v_phase_mult*v_difficulty_mult*v_intensity_mult
      *v_post_match_training_mult;
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

  if v_competitive_match_day then
    -- Competitive load remains owned by Match Center. A previous day's match can
    -- still recover overnight before today's warm-up, scaled by recovery ability
    -- and the assigned medical team.
    v_load:=0;
    v_post_match_recovery:=case
      when v_post_match_burden>0 then least(4,greatest(1,round((1.0+v_post_match_burden*.15)*v_recovery_capacity)::int))
      else 0
    end;
    v_fatigue_after:=greatest(0,v_fatigue_before-v_post_match_recovery);
    v_fitness_after:=least(100,v_fitness_before+least(2,ceil(v_post_match_recovery*.40)::int));
    v_form_after:=v_form_before;
    v_morale_after:=v_morale_before;
    v_injury_risk:=0;
    v_training_niggle:=false;
  else
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

    if v_post_match_burden>0 then
      if v_recovery_slots>0 then
        v_post_match_recovery:=least(6,greatest(1,
          round((v_recovery_slots*.55+v_post_match_burden*.18)*v_recovery_capacity)::int
        ));
        v_fatigue_after:=greatest(0,v_fatigue_after-v_post_match_recovery);
        v_fitness_after:=least(100,v_fitness_after+least(3,ceil(v_post_match_recovery*.45)::int));
      end if;

      if v_hard_slots>0 then
        v_post_match_overreach:=least(4,greatest(0,
          ceil(v_post_match_burden*.08*v_hard_slots*v_intensity_mult-v_recovery_slots*.75)::int
        ));
        v_fatigue_after:=least(100,v_fatigue_after+v_post_match_overreach);
        v_fitness_after:=greatest(40,v_fitness_after-ceil(v_post_match_overreach*.50)::int);
      end if;
    end if;

    v_injury_risk:=greatest(0,least(35,
        greatest(0,v_fatigue_after-55)*.20
        +greatest(0,v_load-5)*2.1
        +greatest(0,coalesce(v_dev.injury_proneness,10)-10)*.55
        +greatest(0,v_post_match_burden-6)*.25
        +v_post_match_overreach*2.2
        +case lower(coalesce(p_difficulty,'normal')) when 'manager' then 1.5 when 'hardcore' then 3.0 else 0 end
    ));
    v_injury_roll:=mod(abs(hashtext('daily-training-v22|'||p_player_id::text||'|'||v_date::text)),1000);
    if coalesce(v_player.injury_status,'Fit')='Fit'
       and v_injury_roll < round(v_injury_risk*10)
       and v_injury_risk>=4
    then
      v_training_niggle:=true;
    end if;
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
      'automatic_match_day',v_competitive_match_day,
      'competitive_load_owner',case when v_competitive_match_day then 'match_center' else 'training' end,
      'post_match_burden',round(v_post_match_burden,2),
      'post_match_recovery',v_post_match_recovery,
      'post_match_overreach',v_post_match_overreach,
      'recovery_capacity',round(v_recovery_capacity,3),
      'medical_quality',round(v_medical_quality,2),
      'recent_match_duration',v_recent_match_duration,
      'recent_travel_load',round(v_recent_travel_load,2),
      'model','CB-DAILY-TRAINING-v23'
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
    'automatic_match_day',v_competitive_match_day,
    'competitive_load_owner',case when v_competitive_match_day then 'match_center' else 'training' end,
    'post_match_burden',round(v_post_match_burden,2),
    'post_match_recovery',v_post_match_recovery,
    'post_match_overreach',v_post_match_overreach,
    'recovery_capacity',round(v_recovery_capacity,3),
    'medical_quality',round(v_medical_quality,2),
    'recent_match_duration',v_recent_match_duration,
    'recent_travel_load',round(v_recent_travel_load,2),
    'development_multiplier',round((v_personal_base*v_age_mult*v_phase_mult*v_difficulty_mult)::numeric,3),
    'model','CB-DAILY-TRAINING-v23'
  );
end;
$function$;

revoke all on function public.apply_managed_training_day_v22(date,bigint,text,text,text,text) from public,anon,authenticated;
grant execute on function public.apply_managed_training_day_v22(date,bigint,text,text,text,text) to service_role;
