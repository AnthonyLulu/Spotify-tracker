-- FM/TM-style intraday career clock: match time, session adaptation, sleep, jet lag and rest windows.
-- Applied to Supabase as migration 20261004135731.

alter table public.player_training_load_profiles
  add column if not exists local_utc_offset numeric not null default 0,
  add column if not exists jet_lag_hours numeric not null default 0,
  add column if not exists sleep_debt numeric not null default 0,
  add column if not exists last_sleep_hours numeric not null default 8,
  add column if not exists last_sleep_quality numeric not null default 100,
  add column if not exists last_match_start_minute integer,
  add column if not exists last_match_end_minute integer,
  add column if not exists last_match_time_label text,
  add column if not exists last_match_is_night boolean not null default false;

CREATE OR REPLACE FUNCTION public.country_utc_offset_v26(p_country text, p_city text DEFAULT NULL::text)
 RETURNS numeric
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO ''
AS $function$
declare
  c text:=upper(trim(coalesce(p_country,'')));
  city text:=lower(trim(coalesce(p_city,'')));
begin
  -- City overrides for the few countries where the tennis calendar spans
  -- several materially different time zones.
  if c in ('USA','US') then
    if city ~ '(los angeles|indian wells|san diego|san francisco|san jose|las vegas|seattle|portland)' then return -8; end if;
    if city ~ '(phoenix|scottsdale)' then return -7; end if;
    if city ~ '(denver|colorado)' then return -7; end if;
    if city ~ '(dallas|houston|austin|san antonio|chicago|memphis|new orleans)' then return -6; end if;
    return -5;
  end if;
  if c='CAN' then
    if city ~ '(vancouver|victoria)' then return -8; end if;
    if city ~ '(calgary|edmonton)' then return -7; end if;
    if city ~ '(winnipeg)' then return -6; end if;
    return -5;
  end if;
  if c='AUS' then
    if city ~ '(perth)' then return 8; end if;
    if city ~ '(adelaide)' then return 9.5; end if;
    return 10;
  end if;
  if c='BRA' then
    if city ~ '(manaus)' then return -4; end if;
    return -3;
  end if;
  if c='RUS' then
    if city ~ '(vladivostok)' then return 10; end if;
    if city ~ '(yekaterinburg|ekaterinburg)' then return 5; end if;
    return 3;
  end if;

  return case
    when c in ('GBR','IRL','POR','ISL') then 0
    when c in ('FRA','ESP','ITA','GER','BEL','NED','SUI','AUT','NOR','SWE','DEN','CZE','POL','CRO','SRB','SLO','SVK','HUN','BIH','MNE','ALB') then 1
    when c in ('FIN','ROU','BUL','GRE','UKR','ISR','EGY','RSA','ZIM','BOT','RWA') then 2
    when c in ('TUR','KSA','QAT','BRN','KUW','KEN','ETH','TAN','UGA') then 3
    when c in ('UAE','OMA','GEO','ARM','AZE') then 4
    when c in ('PAK','UZB') then 5
    when c='IND' then 5.5
    when c in ('NEP') then 5.75
    when c in ('KAZ') then 6
    when c in ('THA','VIE','INA') then 7
    when c in ('CHN','HKG','TPE','SGP','MAS') then 8
    when c in ('JPN','KOR') then 9
    when c='NZL' then 12
    when c in ('ARG','URU') then -3
    when c in ('CHI','PAR','BOL') then -4
    when c in ('COL','PER','ECU') then -5
    when c in ('MEX','CRC','GUA','HON','NCA','SLV') then -6
    when c in ('DOM','PUR','VEN') then -4
    when c in ('MAR','TUN','ALG') then 1
    when c in ('NGR','GHA','TOG','CIV') then 0
    when c in ('REU','MRI') then 4
    else 0
  end;
end;
$function$;

CREATE OR REPLACE FUNCTION public.match_minute_label_v26(p_minute integer)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
  select lpad(((greatest(0,coalesce(p_minute,0))/60)%24)::text,2,'0')
      ||':'||
      lpad((greatest(0,coalesce(p_minute,0))%60)::text,2,'0');
$function$;

CREATE OR REPLACE FUNCTION public.managed_match_time_v26(p_tournament_id bigint, p_player_id bigint, p_round_code text, p_event_type text, p_phase text, p_match_date date, p_world_match_id bigint DEFAULT NULL::bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare
  t public.tournaments%rowtype;
  l public.player_training_load_profiles%rowtype;
  v_event text:=lower(coalesce(p_event_type,'singles'));
  v_round text:=upper(coalesce(p_round_code,''));
  v_seed int;
  v_slots int[];
  v_minute int;
  v_original int;
  v_required int:=0;
  v_prev_end_abs int;
  v_next_start_abs int;
  v_rest_hours numeric:=null;
  v_adjusted boolean:=false;
  v_band text;
begin
  select * into t from public.tournaments where id=p_tournament_id;
  if not found then
    return jsonb_build_object('ok',false,'reason','tournament_not_found');
  end if;

  -- Singles owns the earlier court windows; doubles is biased later so a
  -- player alive in both draws does not get impossible same-hour tickets.
  if v_event='doubles' then
    v_slots:=array[960,1050,1170,1260]; -- 16:00 / 17:30 / 19:30 / 21:00
  elsif coalesce(t.circuit,'')='Junior' or coalesce(t.circuit,'')='ITF' then
    v_slots:=case when coalesce(t.indoor,false)
      then array[660,780,900,1020]
      else array[630,750,870,990]
    end;
  elsif v_round='F' then
    v_slots:=case
      when coalesce(t.category,'')='Grand Chelem' then array[900,1170]
      when coalesce(t.indoor,false) then array[960,1140]
      else array[900,1080]
    end;
  else
    v_slots:=case when coalesce(t.indoor,false)
      then array[720,870,1020,1170]
      else array[660,810,960,1140]
    end;
  end if;

  v_seed:=abs(hashtext(
    'managed-time-v26|'||p_tournament_id::text||'|'||coalesce(p_player_id,0)::text||'|'||
    coalesce(p_world_match_id,0)::text||'|'||v_round||'|'||v_event||'|'||coalesce(p_match_date,current_date)::text
  ));
  v_minute:=v_slots[1+mod(v_seed,cardinality(v_slots))];
  v_original:=v_minute;

  select * into l
  from public.player_training_load_profiles
  where player_id=p_player_id;

  if l.player_id is not null and l.last_match_date is not null and l.last_match_end_minute is not null then
    if p_match_date=l.last_match_date then
      -- Same-day singles/doubles turnaround. Two hours is the hard floor.
      v_required:=120;
      v_prev_end_abs:=l.last_match_end_minute;
      v_next_start_abs:=v_minute;
      if v_next_start_abs<v_prev_end_abs+v_required then
        v_minute:=least(1320,v_prev_end_abs+v_required); -- latest 22:00 start
        v_adjusted:=true;
      end if;
      v_rest_hours:=round(((v_minute-v_prev_end_abs)/60.0)::numeric,2);
    elsif p_match_date=l.last_match_date+1 then
      -- Overnight rest: singles gets the stricter floor, doubles slightly less.
      v_required:=case when v_event='doubles' then 720 else 960 end; -- 12h / 16h
      v_prev_end_abs:=l.last_match_end_minute;
      v_next_start_abs:=1440+v_minute;
      if v_next_start_abs<v_prev_end_abs+v_required then
        v_minute:=least(1320,v_prev_end_abs+v_required-1440);
        v_adjusted:=true;
      end if;
      v_rest_hours:=round(((1440+v_minute-v_prev_end_abs)/60.0)::numeric,2);
    end if;
  end if;

  v_band:=case
    when v_minute<780 then 'morning'
    when v_minute<1080 then 'afternoon'
    else 'evening'
  end;

  return jsonb_build_object(
    'ok',true,
    'match_minute',v_minute,
    'match_time',public.match_minute_label_v26(v_minute),
    'original_match_minute',v_original,
    'original_match_time',public.match_minute_label_v26(v_original),
    'session_band',v_band,
    'rest_adjusted',v_adjusted,
    'rest_hours_before',v_rest_hours,
    'minimum_rest_minutes',v_required,
    'night_session',v_minute>=1140,
    'model','CB-MANAGED-INTRADAY-TIME-v26'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.managed_intraday_plan_v26(p_date date, p_player_id bigint, p_morning text DEFAULT 'Repos'::text, p_afternoon text DEFAULT 'Repos'::text, p_intensity text DEFAULT 'Normal'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare
  v_due jsonb;
  v_match jsonb;
  v_schedule jsonb;
  v_minute int;
  v_morning text:=coalesce(p_morning,'Repos');
  v_afternoon text:=coalesce(p_afternoon,'Repos');
  v_evening text:='Libre';
  v_intensity text:=coalesce(p_intensity,'Normal');
  v_cancelled jsonb:='[]'::jsonb;
  v_match_day boolean:=false;
  x jsonb;
begin
  v_due:=public.managed_due_matches_v22(p_date);

  for x in select value from jsonb_array_elements(coalesce(v_due->'matches','[]'::jsonb))
  loop
    if coalesce((x->>'player_id')::bigint,0)=p_player_id
       or (
         coalesce(x->>'discipline','')='doubles'
         and coalesce((x->>'partner_id')::bigint,0)=p_player_id
       )
    then
      v_match:=x;
      exit;
    end if;
  end loop;

  if v_match is null then
    return jsonb_build_object(
      'ok',true,'date',p_date,'player_id',p_player_id,'match_day',false,
      'morning',v_morning,'afternoon',v_afternoon,'evening',v_evening,
      'intensity',v_intensity,'cancelled',v_cancelled,
      'model','CB-MANAGED-INTRADAY-PLAN-v26'
    );
  end if;

  v_match_day:=true;
  v_schedule:=coalesce(v_match->'schedule','{}'::jsonb);
  v_minute:=coalesce((v_schedule->>'match_minute')::int,900);

  if v_minute<780 then
    v_cancelled:=v_cancelled
      ||jsonb_build_array(jsonb_build_object('slot','morning','planned',v_morning,'reason','early_match'))
      ||jsonb_build_array(jsonb_build_object('slot','afternoon','planned',v_afternoon,'reason','post_match_recovery'));
    v_morning:='Échauffement';
    v_afternoon:='Récupération';
    v_evening:='Repos';
    v_intensity:='Léger';
  elsif v_minute<1080 then
    if v_morning in ('Endurance','Match play','Déplacements') then
      v_cancelled:=v_cancelled||jsonb_build_array(
        jsonb_build_object('slot','morning','planned',v_morning,'reason','protect_match_readiness')
      );
      v_morning:='Récupération';
    end if;
    v_cancelled:=v_cancelled||jsonb_build_array(
      jsonb_build_object('slot','afternoon','planned',v_afternoon,'reason','match_window')
    );
    v_afternoon:='Échauffement';
    v_evening:='Récupération';
    v_intensity:='Léger';
  else
    if v_morning in ('Endurance','Match play','Déplacements') then
      v_cancelled:=v_cancelled||jsonb_build_array(
        jsonb_build_object('slot','morning','planned',v_morning,'reason','night_match_load_control')
      );
      v_morning:='Service';
    end if;
    v_cancelled:=v_cancelled||jsonb_build_array(
      jsonb_build_object('slot','afternoon','planned',v_afternoon,'reason','pre_match_recovery')
    );
    v_afternoon:='Récupération';
    v_evening:='Match';
    v_intensity:='Léger';
  end if;

  return jsonb_build_object(
    'ok',true,'date',p_date,'player_id',p_player_id,'match_day',v_match_day,
    'discipline',v_match->>'discipline','tournament_id',v_match->>'tournament_id',
    'tournament_name',v_match->>'tournament_name','round',v_match->>'round',
    'match_minute',v_minute,'match_time',v_schedule->>'match_time',
    'session_band',v_schedule->>'session_band','night_session',coalesce((v_schedule->>'night_session')::boolean,false),
    'rest_hours_before',v_schedule->'rest_hours_before',
    'morning',v_morning,'afternoon',v_afternoon,'evening',v_evening,
    'intensity',v_intensity,'cancelled',v_cancelled,
    'competitive_load_owner','match_center',
    'model','CB-MANAGED-INTRADAY-PLAN-v26'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.managed_tournament_match_date_v22(p_tournament_id bigint, p_player_id bigint, p_round_code text, p_phase text DEFAULT 'main'::text, p_event_type text DEFAULT 'singles'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare
  t public.tournaments%rowtype;
  r public.tournament_format_rules%rowtype;
  v_phase text:=lower(coalesce(p_phase,'main'));
  v_event text:=lower(coalesce(p_event_type,'singles'));
  v_code text:=upper(coalesce(p_round_code,''));
  v_is_qual boolean:=false;
  v_start date;
  v_end date;
  v_span int:=0;
  v_draw int:=0;
  v_bracket int:=0;
  v_rounds int:=1;
  v_idx int:=1;
  v_q_slots int:=1;
  v_base date;
  v_next_base date;
  v_shift int:=0;
  v_date date;
  v_gap int:=0;
  v_time jsonb:='{}'::jsonb;
begin
  select * into t
  from public.tournaments
  where id=p_tournament_id;

  if t.id is null then
    return jsonb_build_object('ok',false,'reason','tournament_not_found');
  end if;

  v_is_qual:=v_phase='qualifying'
    or v_code ~ '^Q[0-9]+$'
    or v_code ~ '^DQ(?:[0-9]+|F)$';

  if v_is_qual then
    v_start:=coalesce(t.qualifying_start_date,t.start_date-1);
    v_end:=coalesce(t.qualifying_end_date,v_start);

    if v_event='doubles' and v_code like 'DQ%' then
      v_rounds:=2;
      v_idx:=case when v_code='DQF' then 2 else 1 end;
    else
      select * into r
      from public.tournament_format_rules fr
      where fr.circuit=t.circuit
        and fr.category=t.category
        and fr.main_draw_size=coalesce(t.singles_draw_size,t.draw_size)
      limit 1;

      v_draw:=greatest(1,coalesce(t.qualifying_draw_size,r.qualifying_draw_size,1));
      v_q_slots:=greatest(1,coalesce(r.qualifier_count,1));

      -- qualifying rounds are small, use threshold math without floating-point
      -- edge cases at exact powers of two.
      if v_draw<=v_q_slots then v_rounds:=1;
      elsif v_draw<=v_q_slots*2 then v_rounds:=1;
      elsif v_draw<=v_q_slots*4 then v_rounds:=2;
      elsif v_draw<=v_q_slots*8 then v_rounds:=3;
      elsif v_draw<=v_q_slots*16 then v_rounds:=4;
      else v_rounds:=5;
      end if;

      if v_code ~ '^Q[0-9]+$' then
        v_idx:=greatest(1,least(v_rounds,substring(v_code from 2)::int));
      else
        v_idx:=1;
      end if;
    end if;
  else
    v_start:=coalesce(t.main_draw_start_date,t.start_date);
    v_end:=coalesce(t.end_date,v_start);

    if v_event='doubles' then
      v_draw:=greatest(4,coalesce(t.doubles_draw_size,16));
    else
      v_draw:=greatest(2,coalesce(t.singles_draw_size,t.draw_size,32));
    end if;

    v_bracket:=case
      when v_draw<=4 then 4
      when v_draw<=8 then 8
      when v_draw<=16 then 16
      when v_draw<=32 then 32
      when v_draw<=64 then 64
      when v_draw<=128 then 128
      else 256
    end;
    v_rounds:=case v_bracket
      when 4 then 2 when 8 then 3 when 16 then 4 when 32 then 5
      when 64 then 6 when 128 then 7 else 8 end;

    v_idx:=case
      when v_code='F' then v_rounds
      when v_code='SF' then greatest(1,v_rounds-1)
      when v_code='QF' then greatest(1,v_rounds-2)
      when v_code='R16' then greatest(1,v_rounds-3)
      when v_code='R32' then greatest(1,v_rounds-4)
      when v_code='R64' then greatest(1,v_rounds-5)
      when v_code='R128' then greatest(1,v_rounds-6)
      when v_code='R256' then greatest(1,v_rounds-7)
      else 1
    end;
  end if;

  v_span:=greatest(0,v_end-v_start);
  v_base:=v_start+
    case
      when v_rounds<=1 then 0
      else round((v_idx-1)::numeric*v_span/greatest(1,v_rounds-1))::int
    end;

  v_next_base:=v_start+
    case
      when v_rounds<=1 or v_idx>=v_rounds then v_span
      else round(v_idx::numeric*v_span/greatest(1,v_rounds-1))::int
    end;

  v_gap:=greatest(0,v_next_base-v_base);
  if v_idx<v_rounds and v_gap>=2 then
    v_shift:=mod(abs(hashtext(
      'managed-order-v22|'||t.id::text||'|'||coalesce(p_player_id,0)::text||'|'||v_code||'|'||v_event
    )),2);
  end if;

  v_date:=least(v_end,v_base+v_shift);

  v_time:=public.managed_match_time_v26(
    t.id,p_player_id,v_code,v_event,
    case when v_is_qual then 'qualifying' else 'main' end,
    v_date,null
  );

  return jsonb_build_object(
    'ok',true,
    'tournament_id',t.id,
    'player_id',p_player_id,
    'event_type',v_event,
    'phase',case when v_is_qual then 'qualifying' else 'main' end,
    'round_code',v_code,
    'round_index',v_idx,
    'rounds_count',v_rounds,
    'match_date',v_date,
    'base_round_date',v_base,
    'next_round_base_date',case when v_idx<v_rounds then v_next_base else null end,
    'event_start',v_start,
    'event_end',v_end,
    'order_shift_days',v_shift,
    'match_minute',v_time->'match_minute',
    'match_time',v_time->>'match_time',
    'session_band',v_time->>'session_band',
    'night_session',v_time->'night_session',
    'rest_adjusted',v_time->'rest_adjusted',
    'rest_hours_before',v_time->'rest_hours_before',
    'minimum_rest_minutes',v_time->'minimum_rest_minutes',
    'model','CB-MANAGED-TOURNAMENT-DAY-v26'
  );
end;
$function$;

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
  v_post_match_debt numeric:=0;
  v_travel_debt numeric:=0;
  v_recovery_debt numeric:=0;
  v_debt_training_mult numeric:=1;
  v_hard_slots int:=0;
  v_overreach_penalty int:=0;
  v_recovery_pressure numeric:=0;
  v_week int:=1;
  v_last_training_date date;
  v_existing_training jsonb;
  v_intraday jsonb:='{}'::jsonb;
  v_effective_intensity text:=coalesce(p_intensity,'Normal');
  v_match_minute int:=null;
  v_evening text:='Libre';
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
  where p.id=p_player_id
  for update;

  if not found then
    return jsonb_build_object('ok',false,'reason','player_not_found','player_id',p_player_id);
  end if;

  v_intraday:=public.managed_intraday_plan_v26(
    v_date,p_player_id,v_sessions[1],v_sessions[2],v_effective_intensity
  );
  v_sessions:=array[
    coalesce(v_intraday->>'morning',v_sessions[1]),
    coalesce(v_intraday->>'afternoon',v_sessions[2])
  ];
  v_evening:=coalesce(v_intraday->>'evening','Libre');
  v_effective_intensity:=coalesce(v_intraday->>'intensity',v_effective_intensity);
  v_match_minute:=nullif(v_intraday->>'match_minute','')::int;

  select last_training_date
  into v_last_training_date
  from public.player_training_load_profiles
  where player_id=p_player_id
  for update;

  if v_last_training_date is not null and v_last_training_date>=v_date then
    select cel.payload
    into v_existing_training
    from public.career_event_log cel
    where cel.event_type='daily_training_v22'
      and cel.entity_type='player'
      and cel.entity_id=p_player_id
      and cel.event_date=v_date
    order by cel.id desc
    limit 1;

    return coalesce(v_existing_training,'{}'::jsonb)||jsonb_build_object(
      'ok',true,
      'already_applied',true,
      'date',v_date,
      'player_id',p_player_id,
      'player_name',v_player.name,
      'model','CB-DAILY-TRAINING-v29'
    );
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
  v_intensity_mult:=case lower(coalesce(v_effective_intensity,'normal'))
    when 'léger' then .78
    when 'leger' then .78
    when 'light' then .78
    when 'élevé' then 1.16
    when 'eleve' then 1.16
    when 'high' then 1.16
    else 1
  end;

  v_competitive_match_day:=coalesce((v_intraday->>'match_day')::boolean,false);

  -- Recovery/travel are owned by apply_managed_recovery_day_v24 before training.
  -- Training only reads the remaining debt to scale adaptation and overreach risk.
  select
    coalesce(post_match_recovery_debt,0),
    coalesce(travel_recovery_debt,0)
  into v_post_match_debt,v_travel_debt
  from public.player_training_load_profiles
  where player_id=p_player_id;
  v_post_match_debt:=coalesce(v_post_match_debt,0);
  v_travel_debt:=coalesce(v_travel_debt,0);
  v_recovery_debt:=greatest(0,v_post_match_debt+v_travel_debt);
  v_recovery_pressure:=greatest(0,least(1,v_recovery_debt/30.0));
  v_debt_training_mult:=greatest(.58,least(1,1-v_recovery_debt*.014));
  v_hard_slots:=
    (case when v_sessions[1] in ('Endurance','Match play','Déplacements') then 1 else 0 end)
    +(case when v_sessions[2] in ('Endurance','Match play','Déplacements') then 1 else 0 end);

  for v_slot in 1..2 loop
    v_session:=v_sessions[v_slot];
    v_load_base:=case
      when v_competitive_match_day and lower(v_session) in ('échauffement','echauffement','match') then 0
      when v_session in ('Endurance','Match play','Déplacements') then 3*(1+v_recovery_pressure*.22)
      when v_session in ('Service','Retour','Coup droit','Revers','Double') then 2*(1+v_recovery_pressure*.10)
      when v_session='Récupération' then 0
      else 0
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
      *v_debt_training_mult;
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
    -- Match Center owns the competitive load. Only an allowed pre-match
    -- session (typically a light technical hit before a night match) can add
    -- a small training load here.
    v_fatigue_after:=greatest(0,least(100,
      v_fatigue_before+round(greatest(0,least(3,v_load*.45)))::int
    ));
    v_fitness_after:=greatest(40,least(100,
      v_fitness_before-case when v_load>=4 then 1 else 0 end
    ));
    v_form_after:=v_form_before;
    v_morale_after:=v_morale_before;
    v_injury_risk:=0;
    v_training_niggle:=false;
  else
    v_fatigue_after:=greatest(0,least(100,
      v_fatigue_before
      +round(greatest(0,least(6,v_load*.78)))::int
    ));
    v_fitness_after:=greatest(40,least(100,
      v_fitness_before
      +case
        when v_load>=7 then -2
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

    if v_recovery_debt>0 and v_hard_slots>0 then
      v_overreach_penalty:=least(4,greatest(0,
        ceil(v_recovery_debt*.045*v_hard_slots*v_intensity_mult)::int
      ));
      v_fatigue_after:=least(100,v_fatigue_after+v_overreach_penalty);
      v_fitness_after:=greatest(40,v_fitness_after-ceil(v_overreach_penalty*.50)::int);
    end if;

    v_injury_risk:=greatest(0,least(35,
        greatest(0,v_fatigue_after-55)*.20
        +greatest(0,v_load-5)*2.1
        +greatest(0,coalesce(v_dev.injury_proneness,10)-10)*.55
        +greatest(0,v_recovery_debt-6)*.16
        +v_overreach_penalty*1.8
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

  if v_training_niggle then
    if not exists(
      select 1 from public.injuries i
      where i.player_id=p_player_id
        and lower(coalesce(i.status,''))='active'
        and i.injury_type='Gêne musculaire'
        and i.started_at=v_date
    ) then
      insert into public.injuries(
        player_id,injury_type,severity,started_at,expected_return,aggravation_risk,treatment,status
      ) values(
        p_player_id,'Gêne musculaire','minor',v_date,v_date+2,
        greatest(8,least(35,round(v_injury_risk)::int)),
        'Récupération active','active'
      );
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

  update public.player_training_load_profiles
  set last_training_date=v_date,
      updated_at=now()
  where player_id=p_player_id;

  if not found then
    raise exception 'training load profile missing for managed player %',p_player_id;
  end if;

  insert into public.career_event_log(
    event_date,week,system,event_type,entity_type,entity_id,summary,payload
  ) values(
    v_date,v_week,'training','daily_training_v22','player',p_player_id,
    coalesce(v_player.name,'Joueur')||' · '||v_sessions[1]||' / '||v_sessions[2],
    jsonb_build_object(
      'morning',v_sessions[1],
      'afternoon',v_sessions[2],
      'intensity',coalesce(v_effective_intensity,'Normal'),
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
      'intraday',v_intraday,
      'evening',v_evening,
      'match_minute',v_match_minute,
      'match_time',case when v_match_minute is null then null else public.match_minute_label_v26(v_match_minute) end,
      'recovery_owner','CB-DAILY-RECOVERY-v24',
      'post_match_debt',round(v_post_match_debt,2),
      'travel_debt',round(v_travel_debt,2),
      'recovery_debt',round(v_recovery_debt,2),
      'post_match_recovery_debt',round(v_post_match_debt,2),
      'travel_recovery_debt',round(v_travel_debt,2),
      'recovery_pressure',round(v_recovery_pressure,3),
      'training_debt_multiplier',round(v_debt_training_mult,3),
      'recovery_gain_multiplier',round(v_debt_training_mult,3),
      'overreach_penalty',v_overreach_penalty,
      'model','CB-DAILY-TRAINING-v29'
    )
  );

  return jsonb_build_object(
    'ok',true,
    'date',v_date,
    'player_id',p_player_id,
    'player_name',v_player.name,
    'morning',v_sessions[1],
    'afternoon',v_sessions[2],
    'intensity',coalesce(v_effective_intensity,'Normal'),
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
    'intraday',v_intraday,
    'evening',v_evening,
    'match_minute',v_match_minute,
    'match_time',case when v_match_minute is null then null else public.match_minute_label_v26(v_match_minute) end,
    'recovery_owner','CB-DAILY-RECOVERY-v29',
    'post_match_debt',round(v_post_match_debt,2),
    'travel_debt',round(v_travel_debt,2),
    'recovery_debt',round(v_recovery_debt,2),
    'post_match_recovery_debt',round(v_post_match_debt,2),
    'travel_recovery_debt',round(v_travel_debt,2),
    'recovery_pressure',round(v_recovery_pressure,3),
    'training_debt_multiplier',round(v_debt_training_mult,3),
    'recovery_gain_multiplier',round(v_debt_training_mult,3),
    'overreach_penalty',v_overreach_penalty,
    'development_multiplier',round((v_personal_base*v_age_mult*v_phase_mult*v_difficulty_mult)::numeric,3),
    'model','CB-DAILY-TRAINING-v29'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.apply_managed_recovery_day_v24(p_date date, p_player_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_date date:=coalesce(p_date,current_date);
  v_primary bigint;
  v_player public.players%rowtype;
  v_load public.player_training_load_profiles%rowtype;
  v_recovery_attr numeric:=10;
  v_natural numeric:=10;
  v_medical numeric:=10;
  v_fitness_staff numeric:=10;
  v_protocol text:='Récupération active';
  v_physio int:=2;
  v_travel_tolerance numeric:=10;
  v_target_country text;
  v_target_city text;
  v_home text;
  v_from_country text;
  v_from_region text;
  v_to_region text;
  v_travel_load numeric:=0;
  v_protocol_bonus numeric:=0;
  v_recovery_points int:=0;
  v_fitness_delta int:=0;
  v_fatigue_before int:=0;
  v_fitness_before int:=0;
  v_fatigue_after int:=0;
  v_fitness_after int:=0;
  v_post_debt_before numeric:=0;
  v_travel_debt_before numeric:=0;
  v_post_debt_after numeric:=0;
  v_travel_debt_after numeric:=0;
  v_injury public.injuries%rowtype;
  v_risk_drop int:=0;
  v_recovered boolean:=false;
  v_orphan_status_cleared boolean:=false;
  v_restrict boolean:=false;
  v_recommendation text:='Normal';
  v_week int:=1;
  v_result jsonb;
  v_from_offset numeric:=0;
  v_to_offset numeric:=0;
  v_jet_lag_before numeric:=0;
  v_jet_lag_after numeric:=0;
  v_sleep_debt_before numeric:=0;
  v_sleep_debt_after numeric:=0;
  v_sleep_hours numeric:=8;
  v_sleep_quality numeric:=100;
  v_sleep_start_minute int:=1380;
  v_late_finish_penalty numeric:=0;
  v_circadian_penalty numeric:=0;
begin
  select managed_player_id into v_primary from public.career_state where id='demo';
  if p_player_id is null then p_player_id:=v_primary; end if;

  if p_player_id is null or not (
    p_player_id=coalesce(v_primary,-1)
    or exists(select 1 from public.academy_roster where player_id=p_player_id and status='active' and source_youth_id is null)
  ) then
    return jsonb_build_object('ok',false,'reason','player_not_managed','player_id',p_player_id);
  end if;

  select * into v_player from public.players where id=p_player_id for update;
  if not found then return jsonb_build_object('ok',false,'reason','player_not_found','player_id',p_player_id); end if;
  v_home:=v_player.country;

  select * into v_load from public.player_training_load_profiles where player_id=p_player_id for update;
  if not found then
    insert into public.player_training_load_profiles(
      player_id,as_of_date,phase,intensity,technical_share,tactical_share,physical_share,mental_share,
      recovery_share,recovery_days,injury_load_modifier,development_modifier,reason,source_label,current_country,updated_at
    ) values(
      p_player_id,v_date,'balanced',10,20,20,20,20,20,1,1,1,
      'Profil initial récupération','Court Boss · managed recovery V24',v_home,now()
    )
    returning * into v_load;
  end if;

  if v_load.last_recovery_date is not null and v_load.last_recovery_date>=v_date then
    return jsonb_build_object(
      'ok',true,'already_applied',true,'date',v_date,'player_id',p_player_id,
      'fatigue',v_player.fatigue,'fitness',v_player.fitness,'model','CB-DAILY-RECOVERY-v29'
    );
  end if;

  select coalesce(pa.recovery,10),coalesce(pa.natural_fitness,10)
  into v_recovery_attr,v_natural
  from public.player_attributes pa where pa.player_id=p_player_id;

  select coalesce(mp.protocol,'Récupération active'),coalesce(mp.physio_hours,2)
  into v_protocol,v_physio
  from public.player_medical_plans mp where mp.player_id=p_player_id;
  if not found then
    v_protocol:='Récupération active'; v_physio:=2;
  end if;

  select
    max(sp.medical_rating*coalesce(public.staff_effectiveness_multiplier(sp.id),1)),
    max(sp.fitness_rating*coalesce(public.staff_effectiveness_multiplier(sp.id),1))
  into v_medical,v_fitness_staff
  from public.player_staff_assignments psa
  join public.staff_profiles sp on sp.id=psa.staff_profile_id
  where psa.player_id=p_player_id and psa.active=true and sp.active=true;

  -- No dedicated staff assignment: fall back to the best active academy staff.
  -- Do not coalesce before this test, otherwise "no row" becomes rating 10
  -- and the fallback is silently skipped.
  if coalesce(v_medical,0)<=0 or coalesce(v_fitness_staff,0)<=0 then
    select
      max(sp.medical_rating*coalesce(public.staff_effectiveness_multiplier(sp.id),1)),
      max(sp.fitness_rating*coalesce(public.staff_effectiveness_multiplier(sp.id),1))
    into v_medical,v_fitness_staff
    from public.staff s join public.staff_profiles sp on sp.id=s.profile_id
    where sp.active=true;
  end if;
  v_medical:=coalesce(v_medical,10);
  v_fitness_staff:=coalesce(v_fitness_staff,10);

  select coalesce(travel_tolerance,10)
  into v_travel_tolerance
  from public.player_season_plans
  where player_id=p_player_id and season=extract(year from v_date)::int;
  v_travel_tolerance:=coalesce(v_travel_tolerance,10);

  select q.country,q.city into v_target_country,v_target_city
  from (
    select t.country,t.city,coalesce(t.qualifying_start_date,t.main_draw_start_date,t.start_date) event_start
    from public.entries e join public.tournaments t on t.id=e.tournament_id
    where e.player_id=p_player_id
      and coalesce(e.status,'entered') in ('entered','accepted','main','qualifying','alternate')
      and t.end_date>=v_date
      and coalesce(t.qualifying_start_date,t.main_draw_start_date,t.start_date)<=v_date+2
    union all
    select t.country,t.city,coalesce(t.main_draw_start_date,t.start_date)
    from public.managed_doubles_entries e join public.tournaments t on t.id=e.tournament_id
    where p_player_id in (e.player_id,e.partner_id)
      and coalesce(e.status,'entered') in ('entered','accepted','main','qualifying','alternate')
      and t.end_date>=v_date
      and coalesce(t.main_draw_start_date,t.start_date)<=v_date+2
  ) q
  where q.country is not null
  order by q.event_start
  limit 1;

  if v_target_country is null
     and coalesce(v_load.current_country,v_home) is distinct from v_home
     and v_load.last_match_date is not null
     and v_load.last_match_date<=v_date-1
  then
    v_target_country:=v_home;
  end if;

  v_from_country:=coalesce(v_load.current_country,v_home);
  if v_target_country is not null and v_from_country is distinct from v_target_country then
    v_from_region:=public.country_region_v24(v_from_country);
    v_to_region:=public.country_region_v24(v_target_country);
    v_travel_load:=case
      when v_from_region=v_to_region then 2
      when (v_from_region='EUR' and v_to_region='MEA') or (v_from_region='MEA' and v_to_region='EUR') then 4
      when (v_from_region='NAM' and v_to_region='SAM') or (v_from_region='SAM' and v_to_region='NAM') then 4
      when 'OTHER' in (v_from_region,v_to_region) then 5
      else 7 end;
    v_travel_load:=round(greatest(1,least(9,v_travel_load*(1.18-v_travel_tolerance*.025)))::numeric,1);
  end if;

  v_from_offset:=case
    when v_load.current_country is null then public.country_utc_offset_v26(v_from_country,null)
    else coalesce(v_load.local_utc_offset,public.country_utc_offset_v26(v_from_country,null))
  end;
  v_to_offset:=case
    when v_target_country is not null then public.country_utc_offset_v26(v_target_country,v_target_city)
    else v_from_offset
  end;

  v_jet_lag_before:=coalesce(v_load.jet_lag_hours,0);
  v_jet_lag_after:=greatest(0,v_jet_lag_before-1.5);
  if v_travel_load>0 then
    v_jet_lag_after:=greatest(
      v_jet_lag_after,
      abs(v_to_offset-v_from_offset)*greatest(.55,1.15-v_travel_tolerance*.03)
    );
  end if;

  v_sleep_debt_before:=coalesce(v_load.sleep_debt,0);
  if v_load.last_match_date=v_date-1 and v_load.last_match_end_minute is not null then
    v_sleep_start_minute:=greatest(1380,v_load.last_match_end_minute+90);
    v_sleep_hours:=greatest(4,least(9,(1920-v_sleep_start_minute)/60.0));
    v_late_finish_penalty:=greatest(0,(v_load.last_match_end_minute-1320)/60.0);
  else
    v_sleep_hours:=greatest(6,least(9,8.4-v_jet_lag_after*.12));
    v_late_finish_penalty:=0;
  end if;

  v_sleep_debt_after:=greatest(
    0,
    v_sleep_debt_before*.58
    +greatest(0,8-v_sleep_hours)
    +greatest(0,v_jet_lag_after-2)*.10
  );
  v_sleep_quality:=greatest(30,least(100,
    100
    -v_sleep_debt_after*8
    -v_jet_lag_after*4.5
    -v_late_finish_penalty*5
  ));
  v_circadian_penalty:=least(2.2,v_sleep_debt_after*.18+v_jet_lag_after*.10);


  v_protocol_bonus:=case v_protocol
    when 'Repos complet' then 1.5
    when 'Physio intensive' then 1.2
    when 'Récupération active' then .8
    when 'Maintien de forme' then .2
    else .5 end;

  v_fatigue_before:=coalesce(v_player.fatigue,18);
  v_fitness_before:=coalesce(v_player.fitness,90);
  v_post_debt_before:=coalesce(v_load.post_match_recovery_debt,0);
  v_travel_debt_before:=coalesce(v_load.travel_recovery_debt,0);

  v_recovery_points:=greatest(1,least(7,round(
    3
    +(v_recovery_attr-10)*.16
    +(v_natural-10)*.10
    +(v_medical-10)*.07
    +(v_fitness_staff-10)*.05
    +v_protocol_bonus
    +least(1.0,v_physio*.08)
    -least(1.4,(v_post_debt_before+v_travel_debt_before)/24.0)
    -v_circadian_penalty
  )::int));

  v_fitness_delta:=case
    when coalesce(v_player.injury_status,'Fit')<>'Fit' then 0
    when v_recovery_points>=5 then 2
    else 1 end
    -case when v_travel_load>=6 then 2 when v_travel_load>=3 then 1 else 0 end
    -case when v_sleep_quality<50 then 2 when v_sleep_quality<68 then 1 else 0 end;

  v_fatigue_after:=greatest(0,least(100,
    v_fatigue_before
    +round(v_travel_load)::int
    +round(v_sleep_debt_after*.35+v_jet_lag_after*.15)::int
    -v_recovery_points
  ));
  v_fitness_after:=greatest(25,least(100,v_fitness_before+v_fitness_delta));

  v_post_debt_after:=greatest(0,v_post_debt_before-v_recovery_points*.90-1);
  v_travel_debt_after:=greatest(0,v_travel_debt_before+v_travel_load-v_recovery_points*.55);

  select * into v_injury
  from public.injuries
  where player_id=p_player_id and lower(coalesce(status,''))='active'
  order by started_at desc,id desc limit 1;

  -- Legacy training niggles used to set injury_status without creating an injury row.
  -- Clear that orphan state once so recovery/fitness cannot be frozen forever.
  if v_injury.id is null and coalesce(v_player.injury_status,'Fit')<>'Fit' then
    update public.players set injury_status='Fit' where id=p_player_id;
    if p_player_id=coalesce(v_primary,-1) then
      update public.career_state set injury_status='Fit',updated_at=now() where id='demo';
    end if;
    v_player.injury_status:='Fit';
    v_orphan_status_cleared:=true;
  end if;

  if v_injury.id is not null then
    v_restrict:=true;
    v_risk_drop:=greatest(1,least(6,
      1+floor(greatest(0,v_medical-10)/4.0)::int
      +case v_protocol when 'Physio intensive' then 2 when 'Repos complet' then 2 when 'Récupération active' then 1 else 0 end
    ));
    update public.injuries
    set aggravation_risk=greatest(0,coalesce(aggravation_risk,0)-v_risk_drop),
        treatment=v_protocol
    where id=v_injury.id;

    if v_injury.expected_return<=v_date then
      update public.injuries set status='recovered' where id=v_injury.id;
      v_recovered:=true;
      v_restrict:=false;
      update public.players set injury_status='Fit' where id=p_player_id;
    else
      update public.players set injury_status=v_injury.injury_type where id=p_player_id;
    end if;
  end if;

  if not v_recovered then
    update public.players
    set fatigue=v_fatigue_after,fitness=v_fitness_after
    where id=p_player_id;
  else
    update public.players
    set fatigue=v_fatigue_after,fitness=v_fitness_after,injury_status='Fit'
    where id=p_player_id;
  end if;

  if p_player_id=coalesce(v_primary,-1) then
    update public.career_state
    set fatigue=v_fatigue_after,
        fitness=v_fitness_after,
        injury_status=(select injury_status from public.players where id=p_player_id),
        updated_at=now()
    where id='demo';
  end if;

  update public.player_training_load_profiles
  set as_of_date=v_date,
      current_country=coalesce(v_target_country,current_country,v_home),
      post_match_recovery_debt=v_post_debt_after,
      travel_recovery_debt=v_travel_debt_after,
      local_utc_offset=v_to_offset,
      jet_lag_hours=round(v_jet_lag_after,2),
      sleep_debt=round(v_sleep_debt_after,2),
      last_sleep_hours=round(v_sleep_hours,2),
      last_sleep_quality=round(v_sleep_quality,1),
      last_recovery_date=v_date,
      last_travel_date=case when v_travel_load>0 then v_date else last_travel_date end,
      last_travel_from=case when v_travel_load>0 then v_from_country else last_travel_from end,
      last_travel_to=case when v_travel_load>0 then v_target_country else last_travel_to end,
      phase=case when v_restrict then 'medical_recovery' when v_post_debt_after>=10 then 'post_match' when v_travel_debt_after>=5 then 'travel_recovery' else phase end,
      reason=case when v_travel_load>0 then 'Voyage '||coalesce(v_from_country,'?')||' → '||coalesce(v_target_country,'?')
                  when v_restrict then 'Récupération médicale'
                  when v_post_debt_after>0 then 'Récupération post-match'
                  else reason end,
      source_label='Court Boss · daily recovery V29',
      updated_at=now()
  where player_id=p_player_id;

  v_recommendation:=case
    when v_restrict then 'Repos médical'
    when v_fatigue_after>=72 or v_post_debt_after>=16 or v_sleep_quality<48 then 'Repos'
    when v_fatigue_after>=52 or v_post_debt_after>=8 or v_travel_debt_after>=5 or v_sleep_quality<70 or v_jet_lag_after>=4 then 'Récupération'
    else 'Normal' end;

  v_week:=case
    when extract(year from v_date)::int=2025 then greatest(1,((v_date-date '2025-12-01')/7)+1)
    else greatest(1,((v_date-make_date(extract(year from v_date)::int,1,1))/7)+1)
  end;

  v_result:=jsonb_build_object(
    'ok',true,'already_applied',false,'date',v_date,'player_id',p_player_id,
    'fatigue_before',v_fatigue_before,'fatigue_after',v_fatigue_after,'fatigue_recovered',v_recovery_points,
    'fitness_before',v_fitness_before,'fitness_after',v_fitness_after,
    'post_match_debt_before',round(v_post_debt_before,2),'post_match_debt_after',round(v_post_debt_after,2),
    'travel_debt_before',round(v_travel_debt_before,2),'travel_debt_after',round(v_travel_debt_after,2),
    'travel_applied',v_travel_load>0,'travel_load',v_travel_load,'travel_from',v_from_country,'travel_to',v_target_country,
    'utc_offset_before',v_from_offset,'utc_offset_after',v_to_offset,
    'jet_lag_before',round(v_jet_lag_before,2),'jet_lag_after',round(v_jet_lag_after,2),
    'sleep_hours',round(v_sleep_hours,2),'sleep_quality',round(v_sleep_quality,1),
    'sleep_debt_before',round(v_sleep_debt_before,2),'sleep_debt_after',round(v_sleep_debt_after,2),
    'late_finish_penalty',round(v_late_finish_penalty,2),'circadian_penalty',round(v_circadian_penalty,2),
    'staff_medical_rating',round(v_medical,1),'staff_fitness_rating',round(v_fitness_staff,1),
    'recovery_attribute',v_recovery_attr,'natural_fitness',v_natural,'protocol',v_protocol,
    'medical_training_restriction',v_restrict,'injury_recovered',v_recovered,'orphan_status_cleared',v_orphan_status_cleared,'aggravation_risk_drop',v_risk_drop,
    'recommended_session',v_recommendation,
    'last_match_minutes',v_load.last_match_minutes,
    'last_match_load',round(coalesce(v_load.last_match_load,0),2),
    'last_match_heat_load',round(coalesce(v_load.last_match_heat_load,0),2),
    'last_match_wind_load',round(coalesce(v_load.last_match_wind_load,0),2),
    'last_match_humidity_load',round(coalesce(v_load.last_match_humidity_load,0),2),
    'last_match_delay_minutes',coalesce(v_load.last_match_delay_minutes,0),
    'last_match_conditioning_score',round(coalesce(v_load.last_match_conditioning_score,10),2),
    'model','CB-DAILY-RECOVERY-v29'
  );

  insert into public.career_event_log(event_date,week,system,event_type,entity_type,entity_id,summary,payload)
  values(
    v_date,v_week,'recovery','daily_recovery_v24','player',p_player_id,
    coalesce(v_player.name,'Joueur')||' · récupération '||v_recovery_points::text||' pt'||case when v_travel_load>0 then ' · voyage' else '' end,
    v_result
  );

  return v_result;
end
$function$;

CREATE OR REPLACE FUNCTION public.seed_live_match_recovery_v24(p_session_id bigint, p_player_id bigint, p_effect text, p_match_date date, p_tournament_id bigint, p_metrics jsonb DEFAULT '{}'::jsonb, p_role_multiplier numeric DEFAULT 1)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_existing jsonb;
  v_session public.live_match_sessions%rowtype;
  v_player public.players%rowtype;
  v_country text;
  v_city text;
  v_home text;
  v_round text:='Match';
  v_event text:='singles';
  v_phase text:='main';
  v_time jsonb:='{}'::jsonb;
  v_match_start_minute int:=900;
  v_match_end_minute int:=990;
  v_local_offset numeric:=0;
  v_minutes int:=greatest(30,least(360,coalesce(nullif(p_metrics->>'duration_minutes','')::int,90)));
  v_fatigue_add numeric:=greatest(0,coalesce(nullif(p_metrics->>'fatigue_added','')::numeric,8));
  v_heat numeric:=greatest(0,coalesce(nullif(p_metrics->>'heat_load','')::numeric,0));
  v_wind numeric:=greatest(0,coalesce(nullif(p_metrics->>'wind_load','')::numeric,0));
  v_humidity numeric:=greatest(0,coalesce(nullif(p_metrics->>'humidity_load','')::numeric,0));
  v_delay_minutes numeric:=greatest(0,coalesce(nullif(p_metrics->>'environment_delay_minutes','')::numeric,0));
  v_stamina numeric:=10;
  v_recovery_attr numeric:=10;
  v_natural numeric:=10;
  v_athleticism numeric:=10;
  v_conditioning numeric:=10;
  v_conditioning_mult numeric:=1;
  v_mult numeric:=greatest(.5,least(1.2,coalesce(p_role_multiplier,1)));
  v_load numeric;
  v_payload jsonb;
begin
  if p_session_id is null or p_player_id is null or coalesce(p_effect,'')='' then
    raise exception 'recovery seed payload incomplete';
  end if;

  select * into v_session
  from public.live_match_sessions
  where id=p_session_id
  for update;
  if not found then raise exception 'live session % not found',p_session_id; end if;

  v_round:=coalesce(v_session.stats->'_meta'->>'round','Match');
  v_event:=case
    when coalesce(v_session.stats->'_meta'->>'match_type','singles')='doubles' then 'doubles'
    else 'singles'
  end;
  v_phase:=case when left(v_round,1)='Q' then 'qualifying' else 'main' end;

  select payload into v_existing
  from public.live_match_effect_commits_v23
  where session_id=p_session_id and effect=p_effect;

  if v_existing is not null then
    return v_existing||jsonb_build_object('ok',true,'already_applied',true,'model','CB-RECOVERY-v29');
  end if;

  select * into v_player from public.players where id=p_player_id;
  if not found then raise exception 'recovery player % not found',p_player_id; end if;
  v_home:=v_player.country;

  select
    coalesce(pa.stamina,10),coalesce(pa.recovery,10),
    coalesce(pa.natural_fitness,10),coalesce(pa.athleticism,10)
  into v_stamina,v_recovery_attr,v_natural,v_athleticism
  from public.player_attributes pa
  where pa.player_id=p_player_id;
  v_stamina:=coalesce(v_stamina,10);
  v_recovery_attr:=coalesce(v_recovery_attr,10);
  v_natural:=coalesce(v_natural,10);
  v_athleticism:=coalesce(v_athleticism,10);
  v_conditioning:=round((v_stamina*.40+v_recovery_attr*.25+v_natural*.20+v_athleticism*.15)::numeric,2);
  v_conditioning_mult:=greatest(.86,least(1.12,1.07-(v_conditioning-10)*.018));

  if coalesce(p_tournament_id,0)>0 then
    select country,city into v_country,v_city
    from public.tournaments where id=p_tournament_id;
  end if;
  v_country:=coalesce(v_country,v_home);
  v_local_offset:=public.country_utc_offset_v26(v_country,v_city);

  if coalesce(p_tournament_id,0)>0 then
    v_time:=public.managed_match_time_v26(
      p_tournament_id,p_player_id,v_round,v_event,v_phase,
      coalesce(p_match_date,current_date),null
    );
    v_match_start_minute:=coalesce((v_time->>'match_minute')::int,900);
  else
    v_match_start_minute:=coalesce(nullif(p_metrics->>'match_start_minute','')::int,900);
  end if;
  v_match_end_minute:=v_match_start_minute+v_minutes+round(v_delay_minutes)::int;

  v_load:=round(greatest(4,least(32,
    (
      v_fatigue_add*1.05
      +v_minutes/42.0
      +v_heat*.60
      +v_wind*.35
      +v_humidity*.45
      +least(1.4,v_delay_minutes/70.0)
    )*v_mult*v_conditioning_mult
  ))::numeric,2);

  insert into public.player_training_load_profiles(
    player_id,as_of_date,phase,intensity,technical_share,tactical_share,physical_share,mental_share,
    recovery_share,recovery_days,injury_load_modifier,development_modifier,reason,source_label,
    current_country,last_match_date,last_match_session_id,last_match_minutes,last_match_load,
    post_match_recovery_debt,last_match_heat_load,last_match_wind_load,last_match_humidity_load,
    last_match_delay_minutes,last_match_conditioning_score,
    local_utc_offset,last_match_start_minute,last_match_end_minute,last_match_time_label,last_match_is_night,
    updated_at
  )
  values(
    p_player_id,coalesce(p_match_date,current_date),'post_match',10,20,20,20,20,20,1,1,1,
    'Charge post-match live','Court Boss · post-match recovery V29',
    v_country,coalesce(p_match_date,current_date),p_session_id,v_minutes,v_load,
    v_load,v_heat,v_wind,v_humidity,round(v_delay_minutes)::int,v_conditioning,
    v_local_offset,v_match_start_minute,v_match_end_minute,
    public.match_minute_label_v26(v_match_start_minute),v_match_start_minute>=1140,
    now()
  )
  on conflict(player_id) do update set
    as_of_date=excluded.as_of_date,
    phase='post_match',
    reason='Charge post-match live',
    source_label='Court Boss · post-match recovery V29',
    current_country=coalesce(excluded.current_country,public.player_training_load_profiles.current_country),
    last_match_date=excluded.last_match_date,
    last_match_session_id=excluded.last_match_session_id,
    last_match_minutes=excluded.last_match_minutes,
    last_match_load=excluded.last_match_load,
    post_match_recovery_debt=least(60,coalesce(public.player_training_load_profiles.post_match_recovery_debt,0)+excluded.post_match_recovery_debt),
    last_match_heat_load=excluded.last_match_heat_load,
    last_match_wind_load=excluded.last_match_wind_load,
    last_match_humidity_load=excluded.last_match_humidity_load,
    last_match_delay_minutes=excluded.last_match_delay_minutes,
    last_match_conditioning_score=excluded.last_match_conditioning_score,
    local_utc_offset=excluded.local_utc_offset,
    last_match_start_minute=excluded.last_match_start_minute,
    last_match_end_minute=excluded.last_match_end_minute,
    last_match_time_label=excluded.last_match_time_label,
    last_match_is_night=excluded.last_match_is_night,
    updated_at=now();

  v_payload:=jsonb_build_object(
    'ok',true,'already_applied',false,'player_id',p_player_id,'match_date',coalesce(p_match_date,current_date),
    'duration_minutes',v_minutes,'fatigue_added',v_fatigue_add,'recovery_load',v_load,
    'heat_load',v_heat,'wind_load',v_wind,'humidity_load',v_humidity,
    'environment_delay_minutes',round(v_delay_minutes)::int,
    'match_start_minute',v_match_start_minute,
    'match_start_time',public.match_minute_label_v26(v_match_start_minute),
    'match_end_minute',v_match_end_minute,
    'match_end_time',public.match_minute_label_v26(v_match_end_minute),
    'night_session',v_match_start_minute>=1140,
    'local_utc_offset',v_local_offset,
    'intraday_schedule',v_time,
    'conditioning_score',v_conditioning,'conditioning_multiplier',round(v_conditioning_mult,3),
    'country',v_country,'role_multiplier',v_mult,
    'model','CB-RECOVERY-v29'
  );

  insert into public.live_match_effect_commits_v23(session_id,effect,payload)
  values(p_session_id,p_effect,v_payload);

  return v_payload;
end
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
  v_intraday jsonb:='{}'::jsonb;
begin
  if not pg_try_advisory_xact_lock(2200261201) then
    return jsonb_build_object(
      'ok',false,
      'reason','clock_busy',
      'retryable',true,
      'model','CB-DAILY-CLOCK-v26'
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
      'model','CB-DAILY-CLOCK-v26'
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
      'model','CB-DAILY-CLOCK-v26'
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
      'model','CB-DAILY-CLOCK-v26'
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

    v_intraday:=public.managed_intraday_plan_v26(
      v_to,
      v_player_id,
      coalesce(v_plan->>'morning','Repos'),
      coalesce(v_plan->>'afternoon','Repos'),
      coalesce(v_plan->>'intensity','Normal')
    );

    if coalesce((v_intraday->>'match_day')::boolean,false) then
      v_plan:=jsonb_build_object(
        'morning',coalesce(v_intraday->>'morning','Repos'),
        'afternoon',coalesce(v_intraday->>'afternoon','Repos'),
        'intensity',coalesce(v_intraday->>'intensity','Léger'),
        'automatic_match_day',true,
        'intraday',v_intraday
      );
    elsif coalesce((v_recovery->>'medical_training_restriction')::boolean,false) then
      v_plan:=jsonb_build_object(
        'morning','Récupération',
        'afternoon','Repos',
        'intensity','Léger',
        'automatic_medical_restriction',true,
        'intraday',v_intraday
      );
    else
      v_plan:=v_plan||jsonb_build_object('intraday',v_intraday);
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
    v_report:=v_report||jsonb_build_object(
      'recovery',v_recovery,
      'intraday',coalesce(v_report->'intraday',v_plan->'intraday',v_intraday),
      'evening',coalesce(v_report->>'evening',v_plan->'intraday'->>'evening','Libre')
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
      'model','CB-DAILY-CLOCK-v26'
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
    'model','CB-DAILY-CLOCK-v26'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.advance_career_day_v26(p_today_plan jsonb DEFAULT '{}'::jsonb, p_difficulty text DEFAULT 'normal'::text, p_expected_from_date date DEFAULT NULL::date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_current public.career_state%rowtype;
  v_existing jsonb;
  v_result jsonb;
  v_result_date date;
  v_week int;
begin
  -- Serialize all day transitions, including retries arriving just after a
  -- successful commit whose HTTP response was lost.
  perform pg_advisory_xact_lock(2200261201);

  select * into v_current
  from public.career_state
  where id='demo'
  for update;

  if not found then
    return jsonb_build_object('ok',false,'reason','career_missing','model','CB-DAILY-CLOCK-v26');
  end if;

  if p_expected_from_date is not null then
    select cel.payload->'result'
    into v_existing
    from public.career_event_log cel
    where cel.event_type='daily_tick_commit_v25'
      and coalesce(cel.payload->>'from_date','')=p_expected_from_date::text
    order by cel.id desc
    limit 1;

    if v_existing is not null then
      return v_existing||jsonb_build_object(
        'ok',true,
        'already_applied',true,
        'idempotent_replay',true,
        'expected_from_date',p_expected_from_date,
        'model','CB-DAILY-CLOCK-v26'
      );
    end if;

    if coalesce(v_current.career_date,date '2025-12-01')<>p_expected_from_date then
      return jsonb_build_object(
        'ok',false,
        'reason','stale_day_request',
        'retryable',false,
        'expected_from_date',p_expected_from_date,
        'current_date',v_current.career_date,
        'model','CB-DAILY-CLOCK-v26'
      );
    end if;
  end if;

  v_result:=public.advance_career_day_v22(
    coalesce(p_today_plan,'{}'::jsonb),
    coalesce(p_difficulty,'normal')
  );

  if coalesce((v_result->>'ok')::boolean,false)=true
     and nullif(v_result->>'date','') is not null
  then
    v_result_date:=(v_result->>'date')::date;
    v_week:=coalesce((v_result->>'week')::int,1);

    insert into public.career_event_log(
      event_date,week,system,event_type,entity_type,entity_id,summary,payload
    ) values(
      v_result_date,v_week,'clock','daily_tick_commit_v25','career',null,
      'Commit journée idempotent '||coalesce(p_expected_from_date::text,(v_result->>'from_date'),'')||' → '||v_result_date::text,
      jsonb_build_object(
        'from_date',coalesce(p_expected_from_date::text,v_result->>'from_date'),
        'to_date',v_result_date,
        'result',v_result
      )
    );
  end if;

  return coalesce(v_result,'{}'::jsonb)||jsonb_build_object(
    'expected_from_date',p_expected_from_date,
    'model','CB-DAILY-CLOCK-v26'
  );
end;
$function$;

revoke execute on function public.country_utc_offset_v26(text,text) from public, anon, authenticated;
grant execute on function public.country_utc_offset_v26(text,text) to service_role;
revoke execute on function public.match_minute_label_v26(integer) from public, anon, authenticated;
grant execute on function public.match_minute_label_v26(integer) to service_role;
revoke execute on function public.managed_match_time_v26(bigint,bigint,text,text,text,date,bigint) from public, anon, authenticated;
grant execute on function public.managed_match_time_v26(bigint,bigint,text,text,text,date,bigint) to service_role;
revoke execute on function public.managed_intraday_plan_v26(date,bigint,text,text,text) from public, anon, authenticated;
grant execute on function public.managed_intraday_plan_v26(date,bigint,text,text,text) to service_role;
revoke execute on function public.managed_tournament_match_date_v22(bigint,bigint,text,text,text) from public, anon, authenticated;
grant execute on function public.managed_tournament_match_date_v22(bigint,bigint,text,text,text) to service_role;
revoke execute on function public.apply_managed_training_day_v22(date,bigint,text,text,text,text) from public, anon, authenticated;
grant execute on function public.apply_managed_training_day_v22(date,bigint,text,text,text,text) to service_role;
revoke execute on function public.apply_managed_recovery_day_v24(date,bigint) from public, anon, authenticated;
grant execute on function public.apply_managed_recovery_day_v24(date,bigint) to service_role;
revoke execute on function public.seed_live_match_recovery_v24(bigint,bigint,text,date,bigint,jsonb,numeric) from public, anon, authenticated;
grant execute on function public.seed_live_match_recovery_v24(bigint,bigint,text,date,bigint,jsonb,numeric) to service_role;
revoke execute on function public.advance_career_day_v22(jsonb,text) from public, anon, authenticated;
grant execute on function public.advance_career_day_v22(jsonb,text) to service_role;
revoke execute on function public.advance_career_day_v26(jsonb,text,date) from public, anon, authenticated;
grant execute on function public.advance_career_day_v26(jsonb,text,date) to service_role;
