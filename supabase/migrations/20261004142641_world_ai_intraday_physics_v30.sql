-- World AI tournament physics V30.
-- Applied to Supabase as migration 20261004142641.
-- Active tournament players use shared intra-day schedules, sleep, travel,
-- jet lag, real rest windows, per-match load, injury risk and checkpoint recovery.

CREATE OR REPLACE FUNCTION public.world_ai_is_managed_v30(p_player_id bigint)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
  select exists(
    select 1 from public.career_state c
    where c.id='demo' and c.managed_player_id=p_player_id
    union all
    select 1 from public.academy_roster a
    where a.status='active'
      and a.player_id=p_player_id
      and a.source_youth_id is null
  );
$function$;

CREATE OR REPLACE FUNCTION public.world_ai_match_duration_v30(p_score text, p_best_of integer, p_event_type text, p_match_key text)
 RETURNS integer
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO ''
AS $function$
declare
  v_score text:=trim(coalesce(p_score,''));
  v_sets int:=1;
  v_jitter int:=0;
  v_minutes int;
begin
  if upper(v_score) in ('BYE','W/O','DOUBLE W/O') or v_score='' then
    return 0;
  end if;
  v_sets:=greatest(1,cardinality(regexp_split_to_array(v_score,'\s+')));
  v_jitter:=mod(abs(hashtext('ai-duration-v30|'||coalesce(p_match_key,'')||'|'||v_score)),41);
  if lower(coalesce(p_event_type,'singles'))='doubles' then
    v_minutes:=55+v_sets*17+v_jitter;
  else
    v_minutes:=62+v_sets*22+v_jitter+case when coalesce(p_best_of,3)>=5 then 32 else 0 end;
  end if;
  return greatest(45,least(330,v_minutes));
end;
$function$;

CREATE OR REPLACE FUNCTION public.world_ai_effective_match_date_v30(p_tournament_id bigint, p_round_no integer, p_round_code text, p_match_no integer, p_event_type text, p_model_version text, p_is_qualifying boolean, p_simulated_on date)
 RETURNS date
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare
  t public.tournaments%rowtype;
  v_start date;
  v_end date;
  v_span int:=0;
  v_draw int:=0;
  v_bracket int:=0;
  v_rounds int:=1;
  v_idx int:=greatest(1,coalesce(p_round_no,1));
begin
  select * into t from public.tournaments where id=p_tournament_id;
  if not found then return coalesce(p_simulated_on,current_date); end if;

  -- Progressive/live engines already carry the scheduled day.
  if coalesce(p_model_version,'') ilike '%PROGRESSIVE%'
     or coalesce(p_model_version,'') ilike '%LIVE%'
  then
    return coalesce(p_simulated_on,t.start_date,current_date);
  end if;

  if coalesce(p_is_qualifying,false)
     or upper(coalesce(p_round_code,'')) like 'Q%'
     or upper(coalesce(p_round_code,'')) like 'DQ%'
  then
    v_start:=coalesce(t.qualifying_start_date,t.start_date-1);
    v_end:=coalesce(t.qualifying_end_date,v_start);
    if upper(coalesce(p_round_code,'')) in ('Q1','DQ1') then v_idx:=1;
    elsif upper(coalesce(p_round_code,'')) in ('Q2','DQF') then v_idx:=2;
    elsif upper(coalesce(p_round_code,''))='Q3' then v_idx:=3;
    else v_idx:=greatest(1,abs(coalesce(p_round_no,1))); end if;
    v_rounds:=greatest(v_idx,
      case
        when coalesce(t.qualifying_draw_size,0)>=64 then 4
        when coalesce(t.qualifying_draw_size,0)>=32 then 3
        when coalesce(t.qualifying_draw_size,0)>=16 then 2
        else 2
      end
    );
  elsif upper(coalesce(p_round_code,''))='RR' then
    v_start:=coalesce(t.main_draw_start_date,t.start_date);
    v_end:=coalesce(t.end_date,v_start+4);
    return least(v_end,v_start+greatest(0,(coalesce(p_match_no,1)-1)/4));
  elsif upper(coalesce(p_round_code,''))='SF'
        and coalesce(p_model_version,'') ilike '%ROUNDROBIN%' then
    return greatest(coalesce(t.main_draw_start_date,t.start_date),coalesce(t.end_date,t.start_date)-1);
  elsif upper(coalesce(p_round_code,''))='F'
        and coalesce(p_model_version,'') ilike '%ROUNDROBIN%' then
    return coalesce(t.end_date,t.start_date);
  else
    v_start:=coalesce(t.main_draw_start_date,t.start_date);
    v_end:=coalesce(t.end_date,v_start);
    v_draw:=case when lower(coalesce(p_event_type,'singles'))='doubles'
      then greatest(4,coalesce(t.doubles_draw_size,16))
      else greatest(2,coalesce(t.singles_draw_size,t.draw_size,32))
    end;
    v_bracket:=case
      when v_draw<=4 then 4
      when v_draw<=8 then 8
      when v_draw<=16 then 16
      when v_draw<=32 then 32
      when v_draw<=64 then 64
      when v_draw<=128 then 128
      else 256 end;
    v_rounds:=case v_bracket
      when 4 then 2 when 8 then 3 when 16 then 4 when 32 then 5
      when 64 then 6 when 128 then 7 else 8 end;
    v_idx:=greatest(1,least(v_rounds,coalesce(p_round_no,1)));
  end if;

  v_span:=greatest(0,v_end-v_start);
  return least(v_end,
    v_start+case when v_rounds<=1 then 0
      else round((v_idx-1)::numeric*v_span/greatest(1,v_rounds-1))::int end
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.world_ai_shared_schedule_v30(p_tournament_id bigint, p_match_date date, p_round_code text, p_event_type text, p_match_key text, p_world_match_id bigint, p_player_ids bigint[])
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare
  t public.tournaments%rowtype;
  l public.player_training_load_profiles%rowtype;
  v_slots int[];
  v_start int;
  v_original int;
  v_pid bigint;
  v_managed bigint;
  v_req int;
  v_max_req int:=0;
  v_shortfall int:=0;
  v_rest numeric;
  v_min_rest numeric:=null;
  v_sched jsonb;
begin
  select * into t from public.tournaments where id=p_tournament_id;
  if not found then return jsonb_build_object('ok',false,'reason','tournament_not_found'); end if;

  select x into v_managed
  from unnest(coalesce(p_player_ids,'{}'::bigint[])) x
  where public.world_ai_is_managed_v30(x)
  limit 1;

  if v_managed is not null then
    v_sched:=public.managed_match_time_v26(
      p_tournament_id,v_managed,p_round_code,p_event_type,
      case when left(upper(coalesce(p_round_code,'')),1)='Q' then 'qualifying' else 'main' end,
      p_match_date,p_world_match_id
    );
    v_start:=coalesce((v_sched->>'match_minute')::int,900);
  else
    if lower(coalesce(p_event_type,'singles'))='doubles' then
      v_slots:=array[960,1050,1170,1260];
    elsif upper(coalesce(p_round_code,''))='F' then
      v_slots:=case when coalesce(t.category,'')='Grand Chelem'
        then array[900,1170] else array[900,1080] end;
    elsif coalesce(t.circuit,'') in ('Junior','ITF') then
      v_slots:=array[630,750,870,990];
    else
      v_slots:=array[660,810,960,1140];
    end if;
    v_start:=v_slots[1+mod(abs(hashtext(
      'ai-time-v30|'||p_tournament_id::text||'|'||coalesce(p_match_key,'')||'|'||
      coalesce(p_match_date,current_date)::text
    )),cardinality(v_slots))];
  end if;
  v_original:=v_start;

  -- AI-only matches respect every participant's turnaround. Managed matches keep
  -- the live Match Center time as source of truth, while the AI opponent absorbs
  -- any short-rest penalty in its physical state.
  if v_managed is null then
    foreach v_pid in array coalesce(p_player_ids,'{}'::bigint[]) loop
      select * into l from public.player_training_load_profiles where player_id=v_pid;
      if l.player_id is null or l.last_match_date is null or l.last_match_end_minute is null then
        continue;
      end if;
      if l.last_match_date=p_match_date then
        v_req:=l.last_match_end_minute+120;
      elsif l.last_match_date=p_match_date-1 then
        v_req:=l.last_match_end_minute
          +case when lower(coalesce(p_event_type,'singles'))='doubles' then 720 else 960 end
          -1440;
      else
        v_req:=0;
      end if;
      v_max_req:=greatest(v_max_req,v_req);
    end loop;
    if v_max_req>v_start then v_start:=least(1320,v_max_req); end if;
    v_shortfall:=greatest(0,v_max_req-v_start);
  end if;

  foreach v_pid in array coalesce(p_player_ids,'{}'::bigint[]) loop
    select * into l from public.player_training_load_profiles where player_id=v_pid;
    if l.player_id is null or l.last_match_date is null or l.last_match_end_minute is null then
      continue;
    end if;
    if l.last_match_date=p_match_date then
      v_rest:=(v_start-l.last_match_end_minute)/60.0;
    elsif l.last_match_date=p_match_date-1 then
      v_rest:=(1440+v_start-l.last_match_end_minute)/60.0;
    else
      v_rest:=null;
    end if;
    if v_rest is not null then
      v_min_rest:=case when v_min_rest is null then v_rest else least(v_min_rest,v_rest) end;
    end if;
  end loop;

  return jsonb_build_object(
    'ok',true,
    'match_date',p_match_date,
    'match_minute',v_start,
    'match_time',public.match_minute_label_v26(v_start),
    'original_match_minute',v_original,
    'original_match_time',public.match_minute_label_v26(v_original),
    'session_band',case when v_start<780 then 'morning' when v_start<1080 then 'afternoon' else 'evening' end,
    'night_session',v_start>=1140,
    'rest_hours_min',case when v_min_rest is null then null else round(v_min_rest,2) end,
    'rest_shortfall_minutes',v_shortfall,
    'managed_time_source',v_managed is not null,
    'model','CB-WORLD-AI-INTRADAY-TIME-v30'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.apply_world_ai_player_match_v30(p_player_id bigint, p_tournament_id bigint, p_match_date date, p_match_start_minute integer, p_duration_minutes integer, p_event_type text, p_match_key text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  p public.players%rowtype;
  t public.tournaments%rowtype;
  l public.player_training_load_profiles%rowtype;
  v_recovery_attr numeric:=10;
  v_natural numeric:=10;
  v_injury_proneness numeric:=10;
  v_from_country text;
  v_to_country text;
  v_from_offset numeric:=0;
  v_to_offset numeric:=0;
  v_gap_days int:=0;
  v_passive_recovery numeric:=0;
  v_travel_load numeric:=0;
  v_jet numeric:=0;
  v_sleep_debt numeric:=0;
  v_sleep_hours numeric:=8;
  v_sleep_quality numeric:=100;
  v_rest_hours numeric:=null;
  v_required_rest numeric:=0;
  v_shortfall numeric:=0;
  v_circadian numeric:=0;
  v_fatigue_pre int;
  v_fatigue_after int;
  v_fitness_after int;
  v_load numeric;
  v_end_minute int;
  v_risk numeric:=0;
  v_roll int;
  v_injured boolean:=false;
  v_injury_type text:=null;
  v_days_out int:=0;
  v_region_from text;
  v_region_to text;
begin
  if p_player_id is null or p_duration_minutes<=0 then
    return jsonb_build_object('ok',true,'skipped','no_competitive_load');
  end if;
  if public.world_ai_is_managed_v30(p_player_id) then
    return jsonb_build_object('ok',true,'skipped','managed_player','player_id',p_player_id);
  end if;

  select * into p from public.players where id=p_player_id for update;
  if not found then return jsonb_build_object('ok',false,'reason','player_not_found'); end if;
  select * into t from public.tournaments where id=p_tournament_id;
  if not found then return jsonb_build_object('ok',false,'reason','tournament_not_found'); end if;

  select coalesce(a.recovery,10),coalesce(a.natural_fitness,10)
  into v_recovery_attr,v_natural
  from public.player_attributes a where a.player_id=p_player_id;
  v_recovery_attr:=coalesce(v_recovery_attr,10);
  v_natural:=coalesce(v_natural,10);

  select coalesce(d.injury_proneness,10)
  into v_injury_proneness
  from public.player_development_profiles d where d.player_id=p_player_id;
  v_injury_proneness:=coalesce(v_injury_proneness,10);

  insert into public.player_training_load_profiles(
    player_id,as_of_date,phase,intensity,technical_share,tactical_share,physical_share,mental_share,
    recovery_share,recovery_days,injury_load_modifier,development_modifier,reason,source_label,
    current_country,local_utc_offset,updated_at
  ) values(
    p_player_id,p_match_date,'competition',10,20,20,20,20,20,1,1,1,
    'IA · tournoi actif','Court Boss · world AI intraday V30',
    p.country,public.country_utc_offset_v26(p.country,null),now()
  )
  on conflict(player_id) do nothing;

  select * into l
  from public.player_training_load_profiles
  where player_id=p_player_id
  for update;

  v_from_country:=coalesce(l.current_country,p.country);
  v_to_country:=coalesce(t.country,v_from_country);
  v_from_offset:=coalesce(l.local_utc_offset,public.country_utc_offset_v26(v_from_country,null));
  v_to_offset:=public.country_utc_offset_v26(v_to_country,t.city);
  v_gap_days:=case when l.last_match_date is null then 2 else greatest(0,p_match_date-l.last_match_date) end;

  if v_gap_days>0 then
    v_passive_recovery:=least(24,
      v_gap_days*(3.4+greatest(0,v_recovery_attr-10)*.12+greatest(0,v_natural-10)*.08)
    );
    v_jet:=greatest(0,coalesce(l.jet_lag_hours,0)-v_gap_days*1.55);
    v_sleep_debt:=greatest(0,coalesce(l.sleep_debt,0)*power(.58,v_gap_days));
  else
    v_jet:=coalesce(l.jet_lag_hours,0);
    v_sleep_debt:=coalesce(l.sleep_debt,0);
  end if;

  if v_from_country is distinct from v_to_country then
    v_region_from:=public.country_region_v24(v_from_country);
    v_region_to:=public.country_region_v24(v_to_country);
    v_travel_load:=case
      when v_region_from=v_region_to then 2
      when 'OTHER' in (v_region_from,v_region_to) then 5
      else 6.5 end;
    v_jet:=greatest(v_jet,abs(v_to_offset-v_from_offset)*.85);
  end if;

  if l.last_match_date=p_match_date-1 and l.last_match_end_minute is not null then
    v_sleep_hours:=greatest(4,least(9,(1920-greatest(1380,l.last_match_end_minute+90))/60.0));
    v_rest_hours:=(1440+p_match_start_minute-l.last_match_end_minute)/60.0;
    v_required_rest:=case when lower(coalesce(p_event_type,'singles'))='doubles' then 12 else 16 end;
  elsif l.last_match_date=p_match_date and l.last_match_end_minute is not null then
    v_sleep_hours:=coalesce(l.last_sleep_hours,8);
    v_rest_hours:=(p_match_start_minute-l.last_match_end_minute)/60.0;
    v_required_rest:=2;
  else
    v_sleep_hours:=greatest(6,least(9,8.35-v_jet*.10));
  end if;

  if v_rest_hours is not null then
    v_shortfall:=greatest(0,v_required_rest-v_rest_hours);
  end if;

  v_sleep_debt:=greatest(0,v_sleep_debt+greatest(0,8-v_sleep_hours)+greatest(0,v_jet-2)*.08);
  v_sleep_quality:=greatest(28,least(100,100-v_sleep_debt*8-v_jet*4.2-v_shortfall*4.5));
  v_circadian:=v_sleep_debt*.22+v_jet*.13+v_shortfall*.35;

  v_fatigue_pre:=greatest(0,least(100,
    round(coalesce(p.fatigue,20)-v_passive_recovery+v_travel_load+v_circadian)::int
  ));
  v_load:=greatest(4,least(30,
    p_duration_minutes/30.0
    +case when p_match_start_minute>=1140 then 2 else 0 end
    +v_jet*.12+v_sleep_debt*.25+v_shortfall*.8
    +case when lower(coalesce(p_event_type,'singles'))='doubles' then -1 else 0 end
  ));
  v_fatigue_after:=greatest(0,least(100,round(v_fatigue_pre+v_load)::int));
  v_fitness_after:=greatest(35,least(100,
    coalesce(p.fitness,90)
    -1
    -case when v_fatigue_after>=75 then 3 when v_fatigue_after>=60 then 2 else 0 end
    -case when v_sleep_quality<50 then 2 when v_sleep_quality<68 then 1 else 0 end
  ));
  v_end_minute:=p_match_start_minute+p_duration_minutes;

  v_risk:=greatest(0,
    greatest(0,v_fatigue_after-48)*.12
    +greatest(0,p_duration_minutes-100)*.025
    +greatest(0,v_injury_proneness-10)*.28
    +greatest(0,65-v_sleep_quality)*.06
    +v_shortfall*.45
  );
  v_roll:=mod(abs(hashtext('ai-match-injury-v30|'||p_player_id::text||'|'||coalesce(p_match_key,''))),1000);

  if p.injury_status='Fit'
     and not exists(select 1 from public.injuries i where i.player_id=p_player_id and lower(coalesce(i.status,''))='active')
     and v_roll<least(140,round(v_risk*10)::int)
  then
    case mod(abs(hashtext('ai-match-injury-type-v30|'||p_player_id::text||'|'||coalesce(p_match_key,''))),6)
      when 0 then v_injury_type:='Surcharge musculaire';
      when 1 then v_injury_type:='Élongation ischio-jambiers';
      when 2 then v_injury_type:='Douleur épaule';
      when 3 then v_injury_type:='Inflammation poignet';
      when 4 then v_injury_type:='Surcharge lombaire';
      else v_injury_type:='Douleur genou';
    end case;
    v_days_out:=greatest(4,
      5+mod(abs(hashtext('ai-match-days-v30|'||p_player_id::text||'|'||coalesce(p_match_key,''))),15)
      -greatest(0,round(v_recovery_attr-10)::int)/3
    );
    insert into public.injuries(
      player_id,injury_type,severity,started_at,expected_return,aggravation_risk,treatment,status
    ) values(
      p_player_id,v_injury_type,
      case when v_days_out>=16 then 'Modérée' else 'Faible' end,
      p_match_date,p_match_date+v_days_out,
      least(90,20+round(v_risk*2)::int),
      case when v_days_out>=12 then 'Repos + rééducation' else 'Repos + soins' end,
      'active'
    );
    v_injured:=true;
    v_fitness_after:=greatest(35,v_fitness_after-case when v_days_out>=12 then 10 else 6 end);
  end if;

  update public.players
  set fatigue=v_fatigue_after,
      fitness=v_fitness_after,
      injury_status=case when v_injured then v_injury_type else injury_status end
  where id=p_player_id;

  update public.player_training_load_profiles
  set as_of_date=p_match_date,
      phase='post_match',
      intensity=10,
      recovery_days=case when v_fatigue_after>=70 or v_sleep_quality<55 then 2 else 1 end,
      injury_load_modifier=greatest(1,1+v_risk/100),
      reason='IA · charge tournoi intra-journée',
      source_label='Court Boss · world AI intraday V30',
      current_country=v_to_country,
      local_utc_offset=v_to_offset,
      jet_lag_hours=round(v_jet,2),
      sleep_debt=round(v_sleep_debt,2),
      last_sleep_hours=round(v_sleep_hours,2),
      last_sleep_quality=round(v_sleep_quality,1),
      last_match_date=p_match_date,
      last_match_minutes=p_duration_minutes,
      last_match_load=round(v_load,2),
      post_match_recovery_debt=least(60,greatest(0,coalesce(l.post_match_recovery_debt,0)-v_gap_days*6)+v_load),
      travel_recovery_debt=least(30,greatest(0,coalesce(l.travel_recovery_debt,0)-v_gap_days*3)+v_travel_load),
      last_travel_date=case when v_travel_load>0 then p_match_date else l.last_travel_date end,
      last_travel_from=case when v_travel_load>0 then v_from_country else l.last_travel_from end,
      last_travel_to=case when v_travel_load>0 then v_to_country else l.last_travel_to end,
      last_match_start_minute=p_match_start_minute,
      last_match_end_minute=v_end_minute,
      last_match_time_label=public.match_minute_label_v26(p_match_start_minute),
      last_match_is_night=p_match_start_minute>=1140,
      updated_at=now()
  where player_id=p_player_id;

  return jsonb_build_object(
    'ok',true,'player_id',p_player_id,
    'match_date',p_match_date,
    'match_time',public.match_minute_label_v26(p_match_start_minute),
    'end_time',public.match_minute_label_v26(v_end_minute),
    'duration_minutes',p_duration_minutes,
    'fatigue_before',v_fatigue_pre,'fatigue_after',v_fatigue_after,
    'fitness_after',v_fitness_after,
    'match_load',round(v_load,2),
    'sleep_hours',round(v_sleep_hours,2),
    'sleep_quality',round(v_sleep_quality,1),
    'jet_lag_hours',round(v_jet,2),
    'travel_load',round(v_travel_load,2),
    'rest_hours_before',case when v_rest_hours is null then null else round(v_rest_hours,2) end,
    'rest_shortfall_hours',round(v_shortfall,2),
    'injury_risk',round(v_risk,2),
    'injured',v_injured,
    'injury_type',v_injury_type,
    'days_out',v_days_out,
    'model','CB-WORLD-AI-PHYSICS-v30'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.world_ai_intraday_singles_trigger_v30()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_ids bigint[];
  v_sched jsonb;
  v_duration int;
  v_start int;
  v_key text;
  v_states jsonb:='[]'::jsonb;
  v_pid bigint;
  v_state jsonb;
  v_date date;
begin
  if new.winner_id is null
     or upper(coalesce(new.score,'')) in ('BYE','W/O','DOUBLE W/O')
     or coalesce((new.matchup_components->>'ai_intraday_v30_applied')::boolean,false)
  then return new; end if;

  v_ids:=array_remove(array[new.player_a_id,new.player_b_id],null);
  v_key:='S|'||new.tournament_id::text||'|'||new.round_no::text||'|'||new.match_no::text||'|'||new.id::text;
  v_date:=public.world_ai_effective_match_date_v30(
    new.tournament_id,new.round_no,new.round_code,new.match_no,'singles',
    new.model_version,new.is_qualifying,new.simulated_on
  );
  v_sched:=public.world_ai_shared_schedule_v30(
    new.tournament_id,v_date,new.round_code,'singles',v_key,new.id,v_ids
  );
  v_start:=coalesce((v_sched->>'match_minute')::int,900);
  v_duration:=public.world_ai_match_duration_v30(new.score,new.best_of,'singles',v_key);

  foreach v_pid in array v_ids loop
    v_state:=public.apply_world_ai_player_match_v30(
      v_pid,new.tournament_id,v_date,v_start,v_duration,'singles',v_key
    );
    v_states:=v_states||jsonb_build_array(v_state);
  end loop;

  update public.world_tournament_matches
  set simulated_on=v_date,
      matchup_components=coalesce(matchup_components,'{}'::jsonb)||jsonb_build_object(
    'ai_intraday_v30_applied',true,
    'ai_schedule',v_sched,
    'ai_duration_minutes',v_duration,
    'ai_player_states',v_states,
    'ai_physics_model','CB-WORLD-AI-PHYSICS-v30'
  )
  where id=new.id;
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.world_ai_intraday_doubles_trigger_v30()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_a1 bigint; v_a2 bigint; v_b1 bigint; v_b2 bigint;
  v_ids bigint[];
  v_sched jsonb;
  v_duration int;
  v_start int;
  v_key text;
  v_states jsonb:='[]'::jsonb;
  v_pid bigint;
  v_state jsonb;
  v_date date;
  v_pair_a_managed boolean:=false;
  v_pair_b_managed boolean:=false;
begin
  if new.winner_pair_id is null
     or upper(coalesce(new.score,'')) in ('BYE','W/O','DOUBLE W/O')
     or coalesce((new.matchup_components->>'ai_intraday_v30_applied')::boolean,false)
  then return new; end if;

  select player_a_id,player_b_id into v_a1,v_a2
  from public.world_doubles_partnerships where id=new.pair_a_id;
  select player_a_id,player_b_id into v_b1,v_b2
  from public.world_doubles_partnerships where id=new.pair_b_id;

  v_ids:=array_remove(array[v_a1,v_a2,v_b1,v_b2],null);
  v_pair_a_managed:=public.world_ai_is_managed_v30(v_a1) or public.world_ai_is_managed_v30(v_a2);
  v_pair_b_managed:=public.world_ai_is_managed_v30(v_b1) or public.world_ai_is_managed_v30(v_b2);

  v_key:='D|'||new.tournament_id::text||'|'||new.round_no::text||'|'||new.match_no::text||'|'||new.id::text;
  v_date:=public.world_ai_effective_match_date_v30(
    new.tournament_id,new.round_no,new.round_code,new.match_no,'doubles',
    new.model_version,new.is_qualifying,new.simulated_on
  );
  v_sched:=public.world_ai_shared_schedule_v30(
    new.tournament_id,v_date,new.round_code,'doubles',v_key,new.id,v_ids
  );
  v_start:=coalesce((v_sched->>'match_minute')::int,1050);
  v_duration:=public.world_ai_match_duration_v30(new.score,3,'doubles',v_key);

  foreach v_pid in array v_ids loop
    if (v_pair_a_managed and v_pid in (v_a1,v_a2))
       or (v_pair_b_managed and v_pid in (v_b1,v_b2))
    then
      v_state:=jsonb_build_object('ok',true,'player_id',v_pid,'skipped','managed_live_pair');
    else
      v_state:=public.apply_world_ai_player_match_v30(
        v_pid,new.tournament_id,v_date,v_start,v_duration,'doubles',v_key
      );
    end if;
    v_states:=v_states||jsonb_build_array(v_state);
  end loop;

  update public.world_doubles_tournament_matches
  set simulated_on=v_date,
      matchup_components=coalesce(matchup_components,'{}'::jsonb)||jsonb_build_object(
    'ai_intraday_v30_applied',true,
    'ai_schedule',v_sched,
    'ai_duration_minutes',v_duration,
    'ai_player_states',v_states,
    'ai_physics_model','CB-WORLD-AI-PHYSICS-v30'
  )
  where id=new.id;
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.apply_world_ai_checkpoint_recovery_v30(p_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_count int:=0;
begin
  with x as (
    select
      l.player_id,
      greatest(0,p_date-greatest(coalesce(l.as_of_date,l.last_match_date),l.last_match_date))::int as days_rest,
      coalesce(a.recovery,10) recovery,
      coalesce(a.natural_fitness,10) natural_fitness
    from public.player_training_load_profiles l
    left join public.player_attributes a on a.player_id=l.player_id
    where l.source_label='Court Boss · world AI intraday V30'
      and l.last_match_date is not null
      and l.last_match_date between p_date-13 and p_date
      and not public.world_ai_is_managed_v30(l.player_id)
  )
  update public.players p
  set fatigue=greatest(
        8,
        p.fatigue-round(least(
          24,
          x.days_rest*(3.4+greatest(0,x.recovery-10)*.12+greatest(0,x.natural_fitness-10)*.08)
        ))::int
      ),
      fitness=case when coalesce(p.injury_status,'Fit')='Fit'
        then least(100,p.fitness+least(5,x.days_rest))
        else p.fitness end
  from x
  where p.id=x.player_id
    and x.days_rest>0;

  get diagnostics v_count=row_count;

  update public.player_training_load_profiles l
  set as_of_date=p_date,
      jet_lag_hours=greatest(0,l.jet_lag_hours-
        greatest(0,p_date-greatest(coalesce(l.as_of_date,l.last_match_date),l.last_match_date))*1.55
      ),
      sleep_debt=greatest(0,l.sleep_debt*power(
        .58,
        greatest(0,p_date-greatest(coalesce(l.as_of_date,l.last_match_date),l.last_match_date))
      )),
      post_match_recovery_debt=greatest(0,l.post_match_recovery_debt-
        greatest(0,p_date-greatest(coalesce(l.as_of_date,l.last_match_date),l.last_match_date))*6
      ),
      travel_recovery_debt=greatest(0,l.travel_recovery_debt-
        greatest(0,p_date-greatest(coalesce(l.as_of_date,l.last_match_date),l.last_match_date))*3
      ),
      updated_at=now()
  where l.source_label='Court Boss · world AI intraday V30'
    and l.last_match_date is not null
    and l.last_match_date between p_date-13 and p_date
    and not public.world_ai_is_managed_v30(l.player_id)
    and p_date>greatest(coalesce(l.as_of_date,l.last_match_date),l.last_match_date);

  return jsonb_build_object(
    'ok',true,
    'updated_players',v_count,
    'date',p_date,
    'model','CB-WORLD-AI-CHECKPOINT-RECOVERY-v30'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.advance_world_knockout_tournament(p_tournament_id bigint, p_to_date date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  r public.tournament_format_rules%rowtype;
  st public.world_tournament_states%rowtype;
  v_main_start date;
  v_end date;
  v_span integer;
  v_round integer;
  v_round_code text;
  v_round_date date;
  v_match_count integer;
  v_match_no integer;
  v_a bigint;
  v_b bigint;
  v_winner bigint;
  v_loser bigint;
  v_a_name text;
  v_b_name text;
  v_winner_name text;
  v_loser_name text;
  v_match jsonb;
  v_prob numeric;
  v_a_won boolean;
  v_score text;
  v_loser_score text;
  v_loser_wins integer;
  v_loser_bye boolean;
  v_loser_method text;
  v_base_points integer;
  v_qual_points integer;
  v_best_of integer:=3;
  v_rounds_advanced integer:=0;
  v_actual_matches integer:=0;
  v_champion bigint;
  v_finalist bigint;
  v_champion_name text;
  v_finalist_name text;
  v_champion_points integer;
  v_finalist_points integer;
  v_final_prob numeric;
  v_final_components jsonb:='{}'::jsonb;
  v_weight numeric;
  v_a_forfeit boolean:=false;
  v_b_forfeit boolean:=false;
  v_substitutions jsonb:='{}'::jsonb;
  v_managed_player bigint;
  v_managed_match_date date;
begin
  -- One tournament progression transaction at a time. This makes concurrent
  -- commit retries converge on the same bracket state instead of racing.
  perform pg_advisory_xact_lock(
    hashtextextended('court_boss_world_advance:'||p_tournament_id::text,0)
  );
  select * into t from public.tournaments
  where id=p_tournament_id and singles=true and coalesce(is_active,true)=true;
  if t.id is null then
    return jsonb_build_object('skipped','tournament_not_found','tournament_id',p_tournament_id);
  end if;

  select * into st from public.world_tournament_states where tournament_id=t.id;
  if st.tournament_id is null then
    perform public.prepare_world_knockout_tournament(
      t.id,coalesce(t.qualifying_end_date,t.main_draw_start_date,t.start_date,p_to_date)
    );
    select * into st from public.world_tournament_states where tournament_id=t.id;
  end if;
  if st.tournament_id is null then
    return jsonb_build_object('skipped','draw_not_prepared','tournament_id',t.id);
  end if;
  if st.status='completed' then
    return jsonb_build_object('ok',true,'tournament_id',t.id,'status','completed','already_completed',true);
  end if;

  select * into r from public.tournament_format_rules x
  where x.rule_key=st.rule_key limit 1;
  if r.rule_key is null or r.format_type<>'knockout' then
    return jsonb_build_object('skipped','invalid_format_state','tournament_id',t.id);
  end if;

  v_substitutions:=public.apply_world_post_draw_substitutions(t.id,p_to_date);
  select * into st from public.world_tournament_states where tournament_id=t.id;

  v_main_start:=coalesce(t.main_draw_start_date,t.start_date);
  v_end:=coalesce(t.end_date,v_main_start);
  v_span:=greatest(0,v_end-v_main_start);
  v_best_of:=case when t.circuit='ATP' and t.category='Grand Chelem' then 5 else 3 end;

  if p_to_date<v_main_start then
    return jsonb_build_object(
      'ok',true,'tournament_id',t.id,'status',st.status,
      'current_round_no',st.current_round_no,'next_round_date',v_main_start
    );
  end if;

  for v_round in (st.current_round_no+1)..st.rounds_count loop
    v_round_code:=r.rounds[v_round];
    v_round_date:=v_main_start+
      case when st.rounds_count<=1 then 0
           else round((v_round-1)::numeric*v_span/greatest(1,st.rounds_count-1))::int end;
    exit when v_round_date>p_to_date;

    v_match_count:=greatest(1,st.bracket_size/(power(2,v_round)::int));

    for v_match_no in 1..v_match_count loop
      if v_round=1 then
        select player_id into v_a from public.world_tournament_entries
        where tournament_id=t.id and draw_slot=v_match_no*2-1;
        select player_id into v_b from public.world_tournament_entries
        where tournament_id=t.id and draw_slot=v_match_no*2;
      else
        select winner_id into v_a from public.world_tournament_matches
        where tournament_id=t.id and coalesce(is_qualifying,false)=false
          and round_no=v_round-1 and match_no=v_match_no*2-1;
        select winner_id into v_b from public.world_tournament_matches
        where tournament_id=t.id and coalesce(is_qualifying,false)=false
          and round_no=v_round-1 and match_no=v_match_no*2;
      end if;

      if exists(
        select 1 from public.world_tournament_matches
        where tournament_id=t.id and round_no=v_round and match_no=v_match_no
          and coalesce(is_qualifying,false)=false
      ) then
        continue;
      end if;

      if v_a is null and v_b is null then
        insert into public.world_tournament_matches(
          tournament_id,round_no,round_code,match_no,player_a_id,player_b_id,
          winner_id,loser_id,score,best_of,player_a_win_probability,court_speed,
          model_version,matchup_components,simulated_on,is_qualifying
        ) values(
          t.id,v_round,v_round_code,v_match_no,null,null,null,null,'BYE',v_best_of,null,
          coalesce(t.court_speed,case when t.surface ilike 'Terre%' then .68 when t.surface ilike 'Gazon%' then 1.15 when coalesce(t.indoor,false) then 1.18 else 1.0 end),
          'CB-MATCH-v5-PROGRESSIVE','{"bye":true,"empty":true}'::jsonb,v_round_date,false
        );
        continue;
      elsif v_a is null or v_b is null then
        v_winner:=coalesce(v_a,v_b);
        update public.world_tournament_entries
        set had_bye=true
        where tournament_id=t.id and player_id=v_winner;

        insert into public.world_tournament_matches(
          tournament_id,round_no,round_code,match_no,player_a_id,player_b_id,
          winner_id,loser_id,score,best_of,player_a_win_probability,court_speed,
          model_version,matchup_components,simulated_on,is_qualifying
        ) values(
          t.id,v_round,v_round_code,v_match_no,v_a,v_b,v_winner,null,'BYE',v_best_of,null,
          coalesce(t.court_speed,case when t.surface ilike 'Terre%' then .68 when t.surface ilike 'Gazon%' then 1.15 when coalesce(t.indoor,false) then 1.18 else 1.0 end),
          'CB-MATCH-v5-PROGRESSIVE','{"bye":true}'::jsonb,v_round_date,false
        );
        continue;
      end if;

      select name into v_a_name from public.players where id=v_a;
      select name into v_b_name from public.players where id=v_b;

      select exists(
        select 1 from public.tournament_forfeits f
        where f.tournament_id=t.id and f.player_id=v_a
      ) into v_a_forfeit;
      select exists(
        select 1 from public.tournament_forfeits f
        where f.tournament_id=t.id and f.player_id=v_b
      ) into v_b_forfeit;

      if v_a_forfeit or v_b_forfeit then
        if v_a_forfeit and v_b_forfeit then
          insert into public.world_tournament_matches(
            tournament_id,round_no,round_code,match_no,
            player_a_id,player_b_id,winner_id,loser_id,score,best_of,
            player_a_win_probability,court_speed,model_version,matchup_components,
            simulated_on,is_qualifying
          ) values(
            t.id,v_round,v_round_code,v_match_no,
            v_a,v_b,null,null,'DOUBLE W/O',v_best_of,null,
            coalesce(t.court_speed,case when t.surface ilike 'Terre%' then .68 when t.surface ilike 'Gazon%' then 1.15 when coalesce(t.indoor,false) then 1.18 else 1.0 end),
            'CB-MATCH-v6-PROGRESSIVE-WO',
            '{"walkover":true,"double_withdrawal":true}'::jsonb,
            v_round_date,false
          );

          update public.world_tournament_entries e
          set result_code=v_round_code,
              result_label=public.world_tournament_result_label(v_round_code),
              points_awarded=greatest(
                0,
                coalesce((r.points_by_result->>v_round_code)::int,0)+coalesce(e.qualifying_points,0)
              ),
              last_opponent_id=case when e.player_id=v_a then v_b else v_a end,
              last_opponent_name=case when e.player_id=v_a then v_b_name else v_a_name end,
              last_score='W/O',
              simulated_on=v_round_date
          where e.tournament_id=t.id and e.player_id in (v_a,v_b);
        else
          v_winner:=case when v_a_forfeit then v_b else v_a end;
          v_loser:=case when v_a_forfeit then v_a else v_b end;
          v_winner_name:=case when v_a_forfeit then v_b_name else v_a_name end;
          v_loser_name:=case when v_a_forfeit then v_a_name else v_b_name end;

          insert into public.world_tournament_matches(
            tournament_id,round_no,round_code,match_no,
            player_a_id,player_b_id,winner_id,loser_id,score,best_of,
            player_a_win_probability,court_speed,model_version,matchup_components,
            simulated_on,is_qualifying
          ) values(
            t.id,v_round,v_round_code,v_match_no,
            v_a,v_b,v_winner,v_loser,'W/O',v_best_of,null,
            coalesce(t.court_speed,case when t.surface ilike 'Terre%' then .68 when t.surface ilike 'Gazon%' then 1.15 when coalesce(t.indoor,false) then 1.18 else 1.0 end),
            'CB-MATCH-v6-PROGRESSIVE-WO',
            jsonb_build_object(
              'walkover',true,
              'withdrawn_player_id',v_loser,
              'advanced_player_id',v_winner
            ),
            v_round_date,false
          );

          select matches_won,had_bye,entry_method,qualifying_points
          into v_loser_wins,v_loser_bye,v_loser_method,v_qual_points
          from public.world_tournament_entries
          where tournament_id=t.id and player_id=v_loser;

          v_base_points:=coalesce((r.points_by_result->>v_round_code)::int,0);
          if coalesce(v_loser_bye,false) and coalesce(v_loser_wins,0)=0 then
            v_base_points:=coalesce((r.points_by_result->>r.rounds[1])::int,0);
          end if;
          if coalesce(v_loser_method,'') like 'wildcard%'
             and coalesce(v_loser_wins,0)=0
             and t.category in ('Grand Chelem','Masters 1000') then
            v_base_points:=0;
          end if;

          update public.world_tournament_entries
          set result_code=v_round_code,
              result_label=public.world_tournament_result_label(v_round_code),
              points_awarded=greatest(0,v_base_points+coalesce(v_qual_points,0)),
              last_opponent_id=v_winner,
              last_opponent_name=v_winner_name,
              last_score='W/O',
              simulated_on=v_round_date
          where tournament_id=t.id and player_id=v_loser;

          update public.world_tournament_entries
          set simulated_on=v_round_date
          where tournament_id=t.id and player_id=v_winner;
        end if;
        continue;
      end if;

      if exists(
        select 1
        from public.academy_roster ar
        where ar.status='active'
          and ar.player_id in (v_a,v_b)
      ) or exists(
        select 1
        from public.career_state cs
        where cs.id='demo'
          and cs.managed_player_id in (v_a,v_b)
      ) then
        select x.player_id into v_managed_player
        from (
          select ar.player_id,1 as priority
          from public.academy_roster ar
          where ar.status='active' and ar.player_id in (v_a,v_b)
          union all
          select cs.managed_player_id,0
          from public.career_state cs
          where cs.id='demo' and cs.managed_player_id in (v_a,v_b)
        ) x
        order by x.priority,x.player_id
        limit 1;

        v_managed_match_date:=coalesce(
          nullif(
            public.managed_tournament_match_date_v22(
              t.id,v_managed_player,v_round_code,'main','singles'
            )->>'match_date',''
          )::date,
          v_round_date
        );

        insert into public.world_tournament_matches(
          tournament_id,round_no,round_code,match_no,
          player_a_id,player_b_id,winner_id,loser_id,score,best_of,
          player_a_win_probability,court_speed,model_version,matchup_components,
          simulated_on,is_qualifying
        ) values(
          t.id,v_round,v_round_code,v_match_no,
          v_a,v_b,null,null,null,v_best_of,null,
          coalesce(t.court_speed,case when t.surface ilike 'Terre%' then .68 when t.surface ilike 'Gazon%' then 1.15 when coalesce(t.indoor,false) then 1.18 else 1.0 end),
          'CB-MATCH-ENGINE-v6-LIVE-PENDING',
          jsonb_build_object(
            'status','managed_live_pending',
            'managed_player_ids',(
              select coalesce(jsonb_agg(x.player_id),'[]'::jsonb)
              from (
                select distinct ar.player_id
                from public.academy_roster ar
                where ar.status='active' and ar.player_id in (v_a,v_b)
                union
                select cs.managed_player_id
                from public.career_state cs
                where cs.id='demo' and cs.managed_player_id in (v_a,v_b)
              ) x
            )
          ),
          v_managed_match_date,false
        );
        continue;
      end if;

      v_match:=public.player_matchup_probability_v4(
        v_a,v_b,t.surface,v_round_date,
        coalesce(t.court_speed,case when t.surface ilike 'Terre%' then .68 when t.surface ilike 'Gazon%' then 1.15 when coalesce(t.indoor,false) then 1.18 else 1.0 end),
        v_best_of
      );
      v_prob:=greatest(.02,least(.98,coalesce((v_match->>'player_a_probability')::numeric,.5)));
      v_a_won:=random()<v_prob;
      v_winner:=case when v_a_won then v_a else v_b end;
      v_loser:=case when v_a_won then v_b else v_a end;
      v_winner_name:=case when v_a_won then v_a_name else v_b_name end;
      v_loser_name:=case when v_a_won then v_b_name else v_a_name end;
      v_score:=public.world_tournament_score(v_prob,v_a_won,v_best_of);
      v_loser_score:=case when v_loser=v_a then v_score else public.world_invert_tennis_score(v_score) end;

      insert into public.world_tournament_matches(
        tournament_id,round_no,round_code,match_no,
        player_a_id,player_b_id,winner_id,loser_id,score,best_of,
        player_a_win_probability,court_speed,model_version,matchup_components,
        simulated_on,is_qualifying
      ) values(
        t.id,v_round,v_round_code,v_match_no,
        v_a,v_b,v_winner,v_loser,v_score,v_best_of,round(v_prob,4),
        coalesce(t.court_speed,case when t.surface ilike 'Terre%' then .68 when t.surface ilike 'Gazon%' then 1.15 when coalesce(t.indoor,false) then 1.18 else 1.0 end),
        'CB-MATCH-v5-PROGRESSIVE',
        coalesce(v_match->'components','{}'::jsonb)
          ||jsonb_build_object('extended_attributes',coalesce(v_match->'extended_attributes','{}'::jsonb)),
        v_round_date,false
      );
      v_actual_matches:=v_actual_matches+1;

      select matches_won,had_bye,entry_method,qualifying_points
      into v_loser_wins,v_loser_bye,v_loser_method,v_qual_points
      from public.world_tournament_entries
      where tournament_id=t.id and player_id=v_loser;

      v_base_points:=coalesce((r.points_by_result->>v_round_code)::int,0);
      if coalesce(v_loser_bye,false) and coalesce(v_loser_wins,0)=0 then
        v_base_points:=coalesce((r.points_by_result->>r.rounds[1])::int,0);
      end if;
      if coalesce(v_loser_method,'') like 'wildcard%'
         and coalesce(v_loser_wins,0)=0
         and t.category in ('Grand Chelem','Masters 1000') then
        v_base_points:=0;
      end if;

      update public.world_tournament_entries
      set result_code=v_round_code,
          result_label=public.world_tournament_result_label(v_round_code),
          points_awarded=greatest(0,v_base_points+coalesce(v_qual_points,0)),
          last_opponent_id=v_winner,
          last_opponent_name=v_winner_name,
          last_score=v_loser_score,
          simulated_on=v_round_date
      where tournament_id=t.id and player_id=v_loser;

      update public.world_tournament_entries
      set matches_won=matches_won+1,simulated_on=v_round_date
      where tournament_id=t.id and player_id=v_winner;

      -- Physical load is owned by world_ai_intraday_*_v30 trigger.

      perform public.update_h2h_after_match(
        v_winner,v_loser,t.surface,v_round_date,false,
        'Court Boss progressive world draw · '||v_round_code
      );
      v_weight:=case
        when v_round_code='F' then case when t.category='Grand Chelem' then 1.20 when t.category='Masters 1000' then 1.15 else 1.10 end
        when v_round_code='SF' then 1.08
        when v_round_code='QF' then 1.04
        else 1.0 end;
      perform public.update_player_elo_after_match(v_winner,v_loser,t.surface,v_round_date,false,v_weight);

      update public.player_dynamic_ratings d
      set overall_elo=e.overall_elo,hard_elo=e.hard_elo,clay_elo=e.clay_elo,grass_elo=e.grass_elo,
          rating_confidence=greatest(d.rating_confidence,e.confidence),
          last_competitive_match=v_round_date,
          source_label='Court Boss live hybrid Elo · progressive world draw',
          updated_at=now()
      from public.player_elo_ratings e
      where e.player_id=d.player_id and d.player_id in (v_winner,v_loser);
    end loop;

    if exists(
      select 1
      from public.world_tournament_matches m
      where m.tournament_id=t.id
        and coalesce(m.is_qualifying,false)=false
        and m.round_no=v_round
        and m.winner_id is null
        and (
          exists(
            select 1 from public.academy_roster ar
            where ar.status='active'
              and ar.player_id in (m.player_a_id,m.player_b_id)
          )
          or exists(
            select 1 from public.career_state cs
            where cs.id='demo'
              and cs.managed_player_id in (m.player_a_id,m.player_b_id)
          )
        )
    ) then
      return jsonb_build_object(
        'ok',true,'tournament_id',t.id,'name',t.name,
        'status','waiting_managed','current_round_no',st.current_round_no,
        'waiting_round_no',v_round,'waiting_round_code',v_round_code,
        'scheduled_date',(
          select min(m.simulated_on)
          from public.world_tournament_matches m
          where m.tournament_id=t.id
            and coalesce(m.is_qualifying,false)=false
            and m.round_no=v_round
            and m.winner_id is null
            and (
              exists(select 1 from public.academy_roster ar where ar.status='active' and ar.player_id in (m.player_a_id,m.player_b_id))
              or exists(select 1 from public.career_state cs where cs.id='demo' and cs.managed_player_id in (m.player_a_id,m.player_b_id))
            )
        ),'matches_played',v_actual_matches,
        'model','CB-MATCH-v6-MANAGED-DAILY'
      );
    end if;

    update public.world_tournament_states
    set status='live',current_round_no=v_round,last_advanced_on=v_round_date,updated_at=now()
    where tournament_id=t.id;
    v_rounds_advanced:=v_rounds_advanced+1;

    if v_round=st.rounds_count then
      select winner_id,loser_id,player_a_win_probability,matchup_components
      into v_champion,v_finalist,v_final_prob,v_final_components
      from public.world_tournament_matches
      where tournament_id=t.id and round_no=v_round and round_code='F'
        and coalesce(is_qualifying,false)=false
      order by match_no limit 1;

      if v_champion is null or v_finalist is null then
        return jsonb_build_object('skipped','final_missing_players','tournament_id',t.id);
      end if;

      select name into v_champion_name from public.players where id=v_champion;
      select name into v_finalist_name from public.players where id=v_finalist;
      select qualifying_points into v_qual_points from public.world_tournament_entries
      where tournament_id=t.id and player_id=v_champion;
      v_champion_points:=coalesce((r.points_by_result->>'W')::int,0)+coalesce(v_qual_points,0);

      update public.world_tournament_entries
      set result_code='W',result_label='Vainqueur',
          points_awarded=greatest(0,v_champion_points),
          last_opponent_id=v_finalist,last_opponent_name=v_finalist_name,
          last_score=case
            when (select player_a_id from public.world_tournament_matches where tournament_id=t.id and round_code='F' and coalesce(is_qualifying,false)=false limit 1)=v_champion
            then (select score from public.world_tournament_matches where tournament_id=t.id and round_code='F' and coalesce(is_qualifying,false)=false limit 1)
            else public.world_invert_tennis_score((select score from public.world_tournament_matches where tournament_id=t.id and round_code='F' and coalesce(is_qualifying,false)=false limit 1))
          end,
          simulated_on=v_round_date
      where tournament_id=t.id and player_id=v_champion;

      select points_awarded into v_finalist_points from public.world_tournament_entries
      where tournament_id=t.id and player_id=v_finalist;

      update public.world_tournament_entries e
      set prize_awarded=public.tournament_prize_for_result(t.id,e.result_code,'singles'),
          prize_currency=coalesce(t.prize_currency,'USD'),
          prize_is_estimate=coalesce(t.singles_prize_is_estimate,t.prize_breakdown_is_estimate,true)
      where e.tournament_id=t.id;

      insert into public.world_ranking_points(
        player_id,tournament_id,label,earned_date,expiry_date,points,active,source_label
      )
      select e.player_id,t.id,t.name||' · '||e.result_code,
             coalesce(t.end_date,t.start_date),coalesce(t.end_date,t.start_date)+364,
             e.points_awarded,true,
             'Court Boss progressive draw · '||e.result_code||' · '||r.rule_key
      from public.world_tournament_entries e
      where e.tournament_id=t.id and e.points_awarded>0
      on conflict(player_id,tournament_id) do update set
        label=excluded.label,earned_date=excluded.earned_date,expiry_date=excluded.expiry_date,
        points=excluded.points,active=true,source_label=excluded.source_label;

      insert into public.player_tournament_history(
        player_id,season,tournament_id,tournament_name,tournament_date,level,category,surface,
        result_code,result_label,last_opponent,last_score,is_grand_slam,source,event_type
      )
      select e.player_id,extract(year from coalesce(t.end_date,t.start_date))::int,
             t.id::text,t.name,coalesce(t.end_date,t.start_date),
             coalesce(t.level,t.category,t.circuit),t.category,t.surface,
             e.result_code,e.result_label,e.last_opponent_name,e.last_score,
             t.category='Grand Chelem','Court Boss progressive world draw · '||r.rule_key,'singles'
      from public.world_tournament_entries e
      where e.tournament_id=t.id
      on conflict(player_id,event_type,tournament_id) do update set
        season=excluded.season,tournament_name=excluded.tournament_name,tournament_date=excluded.tournament_date,
        level=excluded.level,category=excluded.category,surface=excluded.surface,
        result_code=excluded.result_code,result_label=excluded.result_label,
        last_opponent=excluded.last_opponent,last_score=excluded.last_score,
        is_grand_slam=excluded.is_grand_slam,source=excluded.source;

      insert into public.player_titles(
        player_id,tournament_name,title_date,level,surface,event_type,verified,source_label,origin
      ) values(
        v_champion,t.name,coalesce(t.end_date,t.start_date),
        coalesce(t.category,t.level,t.circuit),t.surface,'singles',false,
        'Court Boss progressive world draw · '||r.rule_key,'game'
      )
      on conflict(player_id,tournament_name,title_date,event_type) do update set
        level=excluded.level,surface=excluded.surface,source_label=excluded.source_label,origin=excluded.origin;

      insert into public.player_final_results(
        player_id,tournament_name,final_date,level,surface,result,opponent_name,source,event_type
      ) values
        (v_champion,t.name,coalesce(t.end_date,t.start_date),coalesce(t.category,t.level,t.circuit),t.surface,'Champion',v_finalist_name,'Court Boss progressive world draw','singles'),
        (v_finalist,t.name,coalesce(t.end_date,t.start_date),coalesce(t.category,t.level,t.circuit),t.surface,'Finaliste',v_champion_name,'Court Boss progressive world draw','singles')
      on conflict(player_id,tournament_name,final_date,result) do update set
        level=excluded.level,surface=excluded.surface,opponent_name=excluded.opponent_name,
        source=excluded.source,event_type=excluded.event_type;

      update public.players p
      set form=greatest(35,least(100,p.form+
            case e.result_code when 'W' then 4 when 'F' then 3 when 'SF' then 2 when 'QF' then 1 else 0 end)),
          morale=greatest(30,least(100,p.morale+
            case e.result_code when 'W' then 5 when 'F' then 3 when 'SF' then 2 when 'QF' then 1 else 0 end))
      from public.world_tournament_entries e
      where e.tournament_id=t.id and p.id=e.player_id;

      insert into public.world_tournament_simulations(
        tournament_id,winner_id,finalist_id,winner_points,finalist_points,simulated_on,
        final_win_probability,court_speed,model_version,matchup_components,
        rule_key,draw_size,bracket_size,rounds_count,matches_simulated,participants_simulated,format_type
      ) values(
        t.id,v_champion,v_finalist,v_champion_points,coalesce(v_finalist_points,0),
        v_round_date,round(coalesce(
          case when (select winner_id from public.world_tournament_matches where tournament_id=t.id and round_code='F' and coalesce(is_qualifying,false)=false limit 1)
                     =(select player_a_id from public.world_tournament_matches where tournament_id=t.id and round_code='F' and coalesce(is_qualifying,false)=false limit 1)
               then v_final_prob else 1-v_final_prob end,.5),4),
        coalesce(t.court_speed,case when t.surface ilike 'Terre%' then .68 when t.surface ilike 'Gazon%' then 1.15 when coalesce(t.indoor,false) then 1.18 else 1.0 end),
        'CB-MATCH-v5-PROGRESSIVE',coalesce(v_final_components,'{}'::jsonb),
        r.rule_key,st.draw_size,st.bracket_size,st.rounds_count,
        (select count(*) from public.world_tournament_matches where tournament_id=t.id and coalesce(is_qualifying,false)=false and loser_id is not null),
        (select count(*) from public.world_tournament_entries where tournament_id=t.id),
        'knockout'
      )
      on conflict(tournament_id) do nothing;

      update public.world_tournament_states
      set status='completed',current_round_no=st.rounds_count,
          last_advanced_on=v_round_date,finalized_on=v_round_date,updated_at=now(),
          metadata=metadata||jsonb_build_object('champion_id',v_champion,'finalist_id',v_finalist)
      where tournament_id=t.id;
    end if;
  end loop;

  select * into st from public.world_tournament_states where tournament_id=t.id;
  return jsonb_build_object(
    'ok',true,'tournament_id',t.id,'name',t.name,'status',st.status,
    'current_round_no',st.current_round_no,'rounds_advanced',v_rounds_advanced,
    'matches_played',v_actual_matches,'last_advanced_on',st.last_advanced_on,
    'model','CB-MATCH-v5-PROGRESSIVE'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.advance_world_qualifying_tournament(p_tournament_id bigint, p_to_date date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  r public.tournament_format_rules%rowtype;
  st public.world_qualifying_states%rowtype;
  v_q_start date;
  v_q_end date;
  v_span integer;
  v_round integer;
  v_round_date date;
  v_next_round_date date;
  v_code text;
  v_match_count integer;
  v_match_no integer;
  v_a bigint;
  v_b bigint;
  v_w bigint;
  v_l bigint;
  v_a_name text;
  v_b_name text;
  v_w_name text;
  v_l_name text;
  v_entry_a text;
  v_entry_b text;
  v_match jsonb;
  v_prob numeric;
  v_awon boolean;
  v_score text;
  v_loss_points integer;
  v_loss_prize numeric;
  v_q_points integer;
  v_rounds_advanced integer:=0;
  v_matches_played integer:=0;
  v_qualifier_count integer:=0;
  v_managed_player bigint;
  v_managed_match_date date;
begin
  -- One tournament progression transaction at a time. This makes concurrent
  -- commit retries converge on the same bracket state instead of racing.
  perform pg_advisory_xact_lock(
    hashtextextended('court_boss_world_advance:'||p_tournament_id::text,0)
  );
  select * into t from public.tournaments
  where id=p_tournament_id and singles=true and coalesce(is_active,true)=true;
  if t.id is null then
    return jsonb_build_object('ok',false,'skipped','tournament_not_found');
  end if;

  select * into st from public.world_qualifying_states where tournament_id=t.id;
  if st.tournament_id is null then
    perform public.prepare_world_qualifying_tournament(
      t.id,coalesce(t.qualifying_signin_date,t.qualifying_start_date,t.start_date-1,p_to_date)
    );
    select * into st from public.world_qualifying_states where tournament_id=t.id;
  end if;

  if st.tournament_id is null then
    if exists(select 1 from public.world_tournament_qualifiers q where q.tournament_id=t.id) then
      return jsonb_build_object(
        'ok',true,'tournament_id',t.id,'status','completed','already_completed',true,
        'qualifiers',(select count(*) from public.world_tournament_qualifiers q where q.tournament_id=t.id)
      );
    end if;
    return jsonb_build_object('ok',false,'skipped','qualifying_draw_not_prepared','tournament_id',t.id);
  end if;

  if st.status='completed' then
    return jsonb_build_object(
      'ok',true,'tournament_id',t.id,'status','completed','already_completed',true,
      'qualifiers',(select count(*) from public.world_tournament_qualifiers q where q.tournament_id=t.id)
    );
  end if;

  select * into r from public.tournament_format_rules fr
  where fr.rule_key=st.rule_key limit 1;
  if r.rule_key is null then
    return jsonb_build_object('ok',false,'skipped','missing_format_rule','tournament_id',t.id);
  end if;

  v_q_start:=coalesce(t.qualifying_start_date,t.start_date-1);
  v_q_end:=coalesce(t.qualifying_end_date,v_q_start);
  v_span:=greatest(0,v_q_end-v_q_start);

  if p_to_date<v_q_start then
    return jsonb_build_object(
      'ok',true,'tournament_id',t.id,'status',st.status,
      'current_round_no',st.current_round_no,'next_round_date',v_q_start
    );
  end if;

  for v_round in (st.current_round_no+1)..st.rounds_count loop
    v_round_date:=v_q_start+
      case when st.rounds_count<=1 then 0
           else round((v_round-1)::numeric*v_span/greatest(1,st.rounds_count-1))::int end;
    exit when v_round_date>p_to_date;

    v_code:='Q'||v_round::text;
    v_match_count:=greatest(1,st.bracket_total/(power(2,v_round)::int));

    if v_round>1 then
      insert into public.world_tournament_matches(
        tournament_id,round_no,round_code,group_name,match_no,
        player_a_id,player_b_id,winner_id,loser_id,score,best_of,
        player_a_win_probability,court_speed,model_version,matchup_components,
        simulated_on,is_qualifying
      )
      select
        t.id,-v_round,v_code,
        'Q Section '||ceil((((m-1)*power(2,v_round)+1)::numeric)/greatest(1,st.section_bracket)::numeric)::int,
        m,
        a.winner_id,b.winner_id,null,null,null,3,null,
        coalesce(t.court_speed,case
          when t.surface ilike 'Terre%' then .68
          when t.surface ilike 'Gazon%' then 1.15
          when coalesce(t.indoor,false) then 1.18 else 1.0 end),
        'CB-MATCH-v6-PROGRESSIVE-Q-SCHEDULED',
        jsonb_build_object('phase','qualifying','status','scheduled'),
        v_round_date,true
      from generate_series(1,v_match_count) m
      left join public.world_tournament_matches a
        on a.tournament_id=t.id and a.is_qualifying=true
       and a.round_no=-(v_round-1) and a.match_no=m*2-1
      left join public.world_tournament_matches b
        on b.tournament_id=t.id and b.is_qualifying=true
       and b.round_no=-(v_round-1) and b.match_no=m*2
      where a.winner_id is not null or b.winner_id is not null
      on conflict(tournament_id,round_no,match_no) do nothing;
    end if;

    for v_match_no in 1..v_match_count loop
      select player_a_id,player_b_id,winner_id
      into v_a,v_b,v_w
      from public.world_tournament_matches
      where tournament_id=t.id and is_qualifying=true
        and round_no=-v_round and match_no=v_match_no;

      if not found then
        continue;
      end if;
      if v_w is not null then
        continue;
      end if;

      if v_a is null and v_b is null then
        update public.world_tournament_matches
        set score='BYE',model_version='CB-MATCH-v6-PROGRESSIVE-Q',
            matchup_components=matchup_components||jsonb_build_object('status','empty-bye'),
            simulated_on=v_round_date
        where tournament_id=t.id and is_qualifying=true
          and round_no=-v_round and match_no=v_match_no;
        continue;
      elsif v_a is null or v_b is null then
        v_w:=coalesce(v_a,v_b);
        update public.world_tournament_matches
        set winner_id=v_w,loser_id=null,score='BYE',
            model_version='CB-MATCH-v6-PROGRESSIVE-Q',
            matchup_components=matchup_components||jsonb_build_object('status','bye'),
            simulated_on=v_managed_match_date
        where tournament_id=t.id and is_qualifying=true
          and round_no=-v_round and match_no=v_match_no;
        continue;
      end if;

      select name into v_a_name from public.players where id=v_a;
      select name into v_b_name from public.players where id=v_b;
      select entry_method into v_entry_a
        from public.world_tournament_qualifying_entries
        where tournament_id=t.id and player_id=v_a;
      select entry_method into v_entry_b
        from public.world_tournament_qualifying_entries
        where tournament_id=t.id and player_id=v_b;

      if exists(
        select 1
        from public.academy_roster ar
        where ar.status='active'
          and ar.player_id in (v_a,v_b)
      ) or exists(
        select 1
        from public.career_state cs
        where cs.id='demo'
          and cs.managed_player_id in (v_a,v_b)
      ) then
        select x.player_id into v_managed_player
        from (
          select ar.player_id,1 as priority
          from public.academy_roster ar
          where ar.status='active' and ar.player_id in (v_a,v_b)
          union all
          select cs.managed_player_id,0
          from public.career_state cs
          where cs.id='demo' and cs.managed_player_id in (v_a,v_b)
        ) x
        order by x.priority,x.player_id
        limit 1;

        v_managed_match_date:=coalesce(
          nullif(
            public.managed_tournament_match_date_v22(
              t.id,v_managed_player,v_code,'qualifying','singles'
            )->>'match_date',''
          )::date,
          v_round_date
        );

        update public.world_tournament_matches
        set model_version='CB-MATCH-ENGINE-v6-LIVE-PENDING-Q',
            matchup_components=coalesce(matchup_components,'{}'::jsonb)
              ||jsonb_build_object(
                'phase','qualifying',
                'status','managed_live_pending'
              ),
            simulated_on=v_round_date
        where tournament_id=t.id and is_qualifying=true
          and round_no=-v_round and match_no=v_match_no;
        continue;
      end if;

      v_match:=public.player_matchup_probability_v4(
        v_a,v_b,t.surface,v_round_date,
        coalesce(t.court_speed,case
          when t.surface ilike 'Terre%' then .68
          when t.surface ilike 'Gazon%' then 1.15
          when coalesce(t.indoor,false) then 1.18 else 1.0 end),
        3
      );
      v_prob:=greatest(.02,least(.98,coalesce((v_match->>'player_a_probability')::numeric,.5)));
      v_awon:=random()<v_prob;
      v_w:=case when v_awon then v_a else v_b end;
      v_l:=case when v_awon then v_b else v_a end;
      v_w_name:=case when v_awon then v_a_name else v_b_name end;
      v_l_name:=case when v_awon then v_b_name else v_a_name end;
      v_score:=public.world_tournament_score(v_prob,v_awon,3);

      update public.world_tournament_matches
      set winner_id=v_w,loser_id=v_l,score=v_score,
          player_a_win_probability=round(v_prob,4),
          model_version='CB-MATCH-v6-PROGRESSIVE-Q',
          matchup_components=coalesce(v_match->'components','{}'::jsonb)
            ||jsonb_build_object(
              'phase','qualifying','status','completed',
              'entry_a',v_entry_a,'entry_b',v_entry_b
            ),
          simulated_on=v_round_date
      where tournament_id=t.id and is_qualifying=true
        and round_no=-v_round and match_no=v_match_no;

      v_matches_played:=v_matches_played+1;
      v_loss_points:=coalesce((r.qualifying_points->>v_code)::int,0);
      v_loss_prize:=public.tournament_prize_for_result(t.id,v_code,'qualifying');

      update public.world_tournament_qualifying_entries
      set result_code=v_code,
          result_label='Qualification · tour '||v_round,
          qualified=false,
          points_awarded=v_loss_points,
          prize_awarded=v_loss_prize,
          prize_currency=coalesce(t.prize_currency,'USD'),
          prize_is_estimate=coalesce(t.qualifying_prize_is_estimate,t.prize_breakdown_is_estimate,true),
          last_opponent_id=v_w,last_opponent_name=v_w_name,
          last_score=case when v_l=v_a then v_score else public.world_invert_tennis_score(v_score) end,
          simulated_on=v_round_date,
          source_label='Court Boss progressive qualifying · '||v_code
      where tournament_id=t.id and player_id=v_l;

      if v_loss_points>0 then
        insert into public.world_ranking_points(
          player_id,tournament_id,label,earned_date,expiry_date,points,active,source_label
        ) values(
          v_l,t.id,t.name||' · '||v_code,
          v_round_date,v_round_date+364,
          v_loss_points,true,'Court Boss progressive qualifying · '||v_code
        )
        on conflict(player_id,tournament_id) do update set
          label=excluded.label,earned_date=excluded.earned_date,expiry_date=excluded.expiry_date,
          points=excluded.points,active=true,source_label=excluded.source_label;
      end if;

      insert into public.player_tournament_history(
        player_id,season,tournament_id,tournament_name,tournament_date,level,category,surface,
        result_code,result_label,last_opponent,last_score,is_grand_slam,source,event_type
      ) values(
        v_l,extract(year from coalesce(t.start_date,v_round_date))::int,
        t.id::text,t.name,v_round_date,
        coalesce(t.level,t.category,t.circuit),t.category,t.surface,
        v_code,'Qualification · tour '||v_round,v_w_name,
        case when v_l=v_a then v_score else public.world_invert_tennis_score(v_score) end,
        t.category='Grand Chelem','Court Boss progressive qualifying','singles'
      )
      on conflict(player_id,event_type,tournament_id) do update set
        result_code=excluded.result_code,result_label=excluded.result_label,
        last_opponent=excluded.last_opponent,last_score=excluded.last_score,
        tournament_date=excluded.tournament_date,source=excluded.source;

      -- Physical load is owned by world_ai_intraday_*_v30 trigger.

      perform public.update_h2h_after_match(
        v_w,v_l,t.surface,v_round_date,false,
        'Court Boss progressive qualifying · '||v_code
      );
      perform public.update_player_elo_after_match(
        v_w,v_l,t.surface,v_round_date,false,.92
      );
    end loop;

    if exists(
      select 1
      from public.world_tournament_matches m
      where m.tournament_id=t.id
        and m.is_qualifying=true
        and m.round_no=-v_round
        and m.winner_id is null
        and (
          exists(
            select 1 from public.academy_roster ar
            where ar.status='active'
              and ar.player_id in (m.player_a_id,m.player_b_id)
          )
          or exists(
            select 1 from public.career_state cs
            where cs.id='demo'
              and cs.managed_player_id in (m.player_a_id,m.player_b_id)
          )
        )
    ) then
      return jsonb_build_object(
        'ok',true,'tournament_id',t.id,'name',t.name,
        'status','waiting_managed','current_round_no',st.current_round_no,
        'waiting_round_no',v_round,'waiting_round_code',v_code,
        'scheduled_date',(
          select min(m.simulated_on)
          from public.world_tournament_matches m
          where m.tournament_id=t.id
            and m.is_qualifying=true
            and m.round_no=-v_round
            and m.winner_id is null
            and (
              exists(select 1 from public.academy_roster ar where ar.status='active' and ar.player_id in (m.player_a_id,m.player_b_id))
              or exists(select 1 from public.career_state cs where cs.id='demo' and cs.managed_player_id in (m.player_a_id,m.player_b_id))
            )
        ),'matches_played',v_matches_played,
        'model','CB-MATCH-v6-MANAGED-DAILY-Q'
      );
    end if;

    update public.world_qualifying_states
    set status='live',current_round_no=v_round,last_advanced_on=v_round_date,updated_at=now()
    where tournament_id=t.id;
    v_rounds_advanced:=v_rounds_advanced+1;

    if v_round<st.rounds_count then
      v_next_round_date:=v_q_start+
        case when st.rounds_count<=1 then 0
             else round(v_round::numeric*v_span/greatest(1,st.rounds_count-1))::int end;
      insert into public.world_tournament_matches(
        tournament_id,round_no,round_code,group_name,match_no,
        player_a_id,player_b_id,winner_id,loser_id,score,best_of,
        player_a_win_probability,court_speed,model_version,matchup_components,
        simulated_on,is_qualifying
      )
      select
        t.id,-(v_round+1),'Q'||(v_round+1)::text,
        'Q Section '||ceil((((m-1)*power(2,v_round+1)+1)::numeric)/greatest(1,st.section_bracket)::numeric)::int,
        m,a.winner_id,b.winner_id,null,null,null,3,null,
        coalesce(t.court_speed,case
          when t.surface ilike 'Terre%' then .68
          when t.surface ilike 'Gazon%' then 1.15
          when coalesce(t.indoor,false) then 1.18 else 1.0 end),
        'CB-MATCH-v6-PROGRESSIVE-Q-SCHEDULED',
        jsonb_build_object('phase','qualifying','status','scheduled'),
        v_next_round_date,true
      from generate_series(1,greatest(1,st.bracket_total/(power(2,v_round+1)::int))) m
      left join public.world_tournament_matches a
        on a.tournament_id=t.id and a.is_qualifying=true
       and a.round_no=-v_round and a.match_no=m*2-1
      left join public.world_tournament_matches b
        on b.tournament_id=t.id and b.is_qualifying=true
       and b.round_no=-v_round and b.match_no=m*2
      where a.winner_id is not null or b.winner_id is not null
      on conflict(tournament_id,round_no,match_no) do nothing;
    end if;

    if v_round=st.rounds_count then
      v_q_points:=coalesce((r.qualifying_points->>'Q')::int,0);

      select count(*) into v_qualifier_count
      from public.world_tournament_matches
      where tournament_id=t.id and is_qualifying=true
        and round_no=-v_round and winner_id is not null;

      if v_qualifier_count<>st.qualifier_slots then
        return jsonb_build_object(
          'ok',false,'skipped','qualifying_section_winner_count_mismatch',
          'tournament_id',t.id,'expected',st.qualifier_slots,'actual',v_qualifier_count
        );
      end if;

      insert into public.world_tournament_qualifiers(
        tournament_id,player_id,qualifier_slot,ranking_at_entry,
        qualifying_points,qualifying_prize,qualifying_start_date,qualifying_end_date,
        source_label,entry_method
      )
      select
        t.id,m.winner_id,
        row_number() over(order by m.match_no)::int,
        qe.ranking_at_entry,v_q_points,0,
        t.qualifying_start_date,t.qualifying_end_date,
        case
          when qe.entry_method='junior_accelerator_qualifying' then 'Court Boss Junior Accelerator qualifying'
          when qe.entry_method='college_accelerator_qualifying' then 'Court Boss College Accelerator qualifying'
          when qe.entry_method='nextgen_accelerator_qualifying' then 'Court Boss Next Gen Accelerator qualifying'
          when qe.entry_method='qualifying_wildcard' then 'Court Boss qualifying wild card'
          else 'Court Boss progressive qualifying'
        end,
        qe.entry_method
      from public.world_tournament_matches m
      join public.world_tournament_qualifying_entries qe
        on qe.tournament_id=t.id and qe.player_id=m.winner_id
      where m.tournament_id=t.id and m.is_qualifying=true
        and m.round_no=-v_round and m.winner_id is not null
      order by m.match_no
      on conflict(tournament_id,player_id) do update set
        qualifier_slot=excluded.qualifier_slot,
        ranking_at_entry=excluded.ranking_at_entry,
        qualifying_points=excluded.qualifying_points,
        qualifying_start_date=excluded.qualifying_start_date,
        qualifying_end_date=excluded.qualifying_end_date,
        source_label=excluded.source_label,
        entry_method=excluded.entry_method;

      update public.world_tournament_qualifying_entries qe
      set result_code='Q',result_label='Qualifié',qualified=true,
          points_awarded=v_q_points,prize_awarded=0,
          simulated_on=v_round_date,
          source_label='Court Boss progressive qualifying · qualified'
      where qe.tournament_id=t.id
        and exists(
          select 1 from public.world_tournament_matches m
          where m.tournament_id=t.id and m.is_qualifying=true
            and m.round_no=-v_round and m.winner_id=qe.player_id
        );

      perform public.refresh_world_tournament_lucky_losers(t.id,0);

      update public.world_qualifying_states
      set status='completed',current_round_no=st.rounds_count,
          last_advanced_on=v_round_date,finalized_on=v_round_date,updated_at=now(),
          metadata=metadata||jsonb_build_object(
            'qualifiers',v_qualifier_count,'completed_on',v_round_date
          )
      where tournament_id=t.id;
    end if;
  end loop;

  select * into st from public.world_qualifying_states where tournament_id=t.id;
  return jsonb_build_object(
    'ok',true,'tournament_id',t.id,'name',t.name,'status',st.status,
    'current_round_no',st.current_round_no,'rounds_advanced',v_rounds_advanced,
    'matches_played',v_matches_played,'last_advanced_on',st.last_advanced_on,
    'qualifiers',(select count(*) from public.world_tournament_qualifiers q where q.tournament_id=t.id),
    'model','CB-MATCH-v6-PROGRESSIVE-Q'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.simulate_world_knockout_tournament_full(p_tournament_id bigint, p_simulated_on date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  r public.tournament_format_rules%rowtype;
  v_managed bigint;
  v_main integer;
  v_bracket integer;
  v_byes integer;
  v_direct integer;
  v_needed integer;
  v_seed_count integer;
  v_min_rank integer:=1;
  v_max_rank integer:=3000;
  v_best_of integer:=3;
  v_rounds integer;
  v_round integer;
  v_round_code text;
  v_current_size integer;
  v_pos integer;
  v_next_pos integer;
  v_a bigint;
  v_b bigint;
  v_winner bigint;
  v_loser bigint;
  v_a_name text;
  v_b_name text;
  v_winner_name text;
  v_loser_name text;
  v_match jsonb;
  v_prob numeric;
  v_a_won boolean;
  v_score text;
  v_loser_score text;
  v_loser_wins integer;
  v_loser_bye boolean;
  v_loser_method text;
  v_base_points integer;
  v_qual_points integer;
  v_champion bigint;
  v_finalist bigint;
  v_champion_name text;
  v_finalist_name text;
  v_champion_points integer;
  v_finalist_points integer;
  v_final_prob numeric;
  v_final_components jsonb:='{}'::jsonb;
  v_matches integer:=0;
  v_participants integer:=0;
  v_pb_count integer:=0;
  v_a_plus_count integer:=0;
  v_ll_vacancies integer:=0;
  v_ll_inserted integer:=0;
  m record;
begin
  select * into t
  from public.tournaments
  where id=p_tournament_id
    and singles=true
    and coalesce(is_active,true)=true;

  if t.id is null then
    return jsonb_build_object('skipped','tournament_not_found_or_not_singles','tournament_id',p_tournament_id);
  end if;

  if coalesce(t.circuit,'') in ('NCAA','Junior','Federation')
     or coalesce(t.category,'') in ('United Cup','Laver Cup','Davis Cup','Junior Davis Cup') then
    return jsonb_build_object('skipped','special_or_team_event','tournament_id',t.id,'category',t.category);
  end if;

  if exists(select 1 from public.world_tournament_simulations s where s.tournament_id=t.id) then
    return jsonb_build_object('skipped','already_simulated','tournament_id',t.id);
  end if;

  select * into r
  from public.tournament_format_rules x
  where x.circuit=t.circuit
    and x.category=t.category
    and x.main_draw_size=coalesce(t.singles_draw_size,t.draw_size)
  limit 1;

  if r.rule_key is null then
    return jsonb_build_object(
      'skipped','missing_format_rule',
      'tournament_id',t.id,'name',t.name,'circuit',t.circuit,'category',t.category,
      'draw_size',coalesce(t.singles_draw_size,t.draw_size)
    );
  end if;

  if r.format_type<>'knockout' then
    return jsonb_build_object('skipped','non_knockout_format','tournament_id',t.id,'rule_key',r.rule_key);
  end if;

  v_main:=r.main_draw_size;
  v_bracket:=r.bracket_size;
  v_byes:=greatest(0,v_bracket-v_main);
  v_seed_count:=least(r.seed_count,v_main);
  v_direct:=greatest(0,v_main-r.qualifier_count-r.wildcard_count-coalesce(r.special_exempt_slots,0)-coalesce(t.late_entry_slots,0));
  v_rounds:=coalesce(array_length(r.rounds,1),0);
  v_best_of:=case when t.circuit='ATP' and t.category='Grand Chelem' then 5 else 3 end;

  select managed_player_id into v_managed
  from public.career_state
  where id='demo';

  if t.category='Grand Chelem' then v_min_rank:=1;v_max_rank:=450;
  elsif t.category='Masters 1000' then v_min_rank:=1;v_max_rank:=380;
  elsif t.category='ATP 500' then v_min_rank:=1;v_max_rank:=500;
  elsif t.category='ATP 250' then v_min_rank:=1;v_max_rank:=700;
  elsif t.category='Challenger 175' then v_min_rank:=20;v_max_rank:=900;
  elsif t.category='Challenger 125' then v_min_rank:=30;v_max_rank:=1200;
  elsif t.category='Challenger 100' then v_min_rank:=40;v_max_rank:=1700;
  elsif t.category='Challenger 75' then v_min_rank:=60;v_max_rank:=2300;
  elsif t.category='Challenger 50' then v_min_rank:=90;v_max_rank:=3500;
  elsif t.category='M25' then v_min_rank:=150;v_max_rank:=7000;
  elsif t.category='M15' then v_min_rank:=201;v_max_rank:=12000;
  end if;

  drop table if exists pg_temp.cb_candidates;
  drop table if exists pg_temp.cb_entries_work;
  drop table if exists pg_temp.cb_pathway_entries;
  drop table if exists pg_temp.cb_performance_byes;
  drop table if exists pg_temp.cb_a_plus_wc;
  drop table if exists pg_temp.cb_bye_slots;
  drop table if exists pg_temp.cb_available_slots;
  drop table if exists pg_temp.cb_round_slots;
  drop table if exists pg_temp.cb_next_slots;

  create temporary table cb_candidates(
    player_id bigint primary key,
    name text,
    country text,
    effective_rank integer,
    selection_score numeric,
    potential integer
  ) on commit drop;

  insert into cb_candidates(player_id,name,country,effective_rank,selection_score,potential)
  select
    p.id,p.name,p.country,
    coalesce((elig.j->>'ranking')::int,999999)::int as effective_rank,
    (
      p.current_ability*.52+p.form*.08+p.fitness*.04-p.fatigue*.04+
      case
        when t.surface ilike 'Terre%' then coalesce(a.clay_affinity,10)*.42
        when t.surface ilike 'Gazon%' then coalesce(a.grass_affinity,10)*.42
        else coalesce(a.hard_affinity,10)*.42
      end+
      coalesce(a.decision_making,a.tactics,10)*.10+
      coalesce(a.consistency,a.concentration,10)*.10+
      coalesce(dp.competitive_drive,10)*.045+
      coalesce(public.player_psychology_modifier(p.id),0)*.45+
      public.ai_tournament_commitment_probability(
        coalesce(case when p.ranking_current then p.ranking end,p.game_world_rank,p.ranking,999999)::int,
        coalesce(sp.plan_type,'tour_regular'),coalesce(sp.target_events,22),
        sp.preferred_surface,t.surface,t.category,p.country,t.country,
        coalesce(p.fatigue,20),coalesce(sp.rest_trigger_fatigue,72)
      )*.06+
      (mod(abs(hashtext('world-entry|'||t.id::text||'|'||p.id::text)),1000)/1000.0)*3.5
    )::numeric as selection_score,
    p.potential
  from public.players p
  left join public.player_attributes a on a.player_id=p.id
  left join public.player_development_profiles dp on dp.player_id=p.id
  cross join lateral (select public.tournament_entry_eligibility(p.id,t.id,'candidate') j) elig
  left join public.player_season_plans sp on sp.player_id=p.id and sp.season=extract(year from t.start_date)::int
  where p.career_status='active'
    and p.id is distinct from v_managed
    and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
    and coalesce(p.career_focus,'mixed')<>'doubles_only'
    and p.injury_status='Fit'
    and coalesce(p.fitness,90)>=48
    and coalesce(p.fatigue,20)<=88
    and coalesce((elig.j->>'ranking')::int,999999) between v_min_rank and v_max_rank
    and (
      t.circuit<>'ATP'
      or p.ranking_current=true
    )
    and coalesce((elig.j->>'eligible')::boolean,false)
    and public.ai_player_commits_to_tournament(p.id,t.id)
    and not (public.player_tournament_calendar_conflict(p.id,t.id,'candidate')->>'conflict')::boolean;

  create temporary table cb_a_plus_wc(
    player_id bigint primary key
  ) on commit drop;

  if coalesce(r.conditional_wildcard_rule,'')='ATP500_A_PLUS'
     and coalesce(r.wildcard_count_max,r.wildcard_count)>r.wildcard_count then
    insert into cb_a_plus_wc(player_id)
    select x.player_id
    from public.tournament_a_plus_wildcard_candidate_ids(t.id) x
    where exists(select 1 from cb_candidates c where c.player_id=x.player_id)
    order by x.ranking_2025,x.current_rank,x.player_id
    limit 1;

    select count(*) into v_a_plus_count from cb_a_plus_wc;
  end if;

  create temporary table cb_entries_work(
    player_id bigint primary key,
    name text not null,
    country text,
    seed integer,
    draw_slot integer,
    entry_method text not null,
    ranking_at_entry integer,
    had_bye boolean not null default false,
    matches_won integer not null default 0,
    result_code text,
    result_label text,
    points_awarded integer not null default 0,
    qualifying_points integer not null default 0,
    last_opponent_id bigint,
    last_opponent_name text,
    last_score text
  ) on commit drop;

  create temporary table cb_pathway_entries(
    player_id bigint primary key,
    entry_method text not null,
    pathway_rank integer,
    priority integer not null
  ) on commit drop;

  if coalesce(r.junior_accelerator_slots,0)>0 then
    insert into cb_pathway_entries(player_id,entry_method,pathway_rank,priority)
    select x.player_id,'junior_accelerator',x.year_end_rank,1
    from public.junior_accelerator_candidate_ids(t.id,'main') x
    limit r.junior_accelerator_slots
    on conflict(player_id) do nothing;
  end if;

  if coalesce(r.college_accelerator_slots,0)>0 then
    insert into cb_pathway_entries(player_id,entry_method,pathway_rank,priority)
    select x.player_id,'college_accelerator',x.year_end_ita_rank,2
    from public.college_accelerator_candidate_ids(t.id) x
    limit r.college_accelerator_slots
    on conflict(player_id) do nothing;
  end if;

  if coalesce(r.nextgen_accelerator_main_slots,0)>0 then
    insert into cb_pathway_entries(player_id,entry_method,pathway_rank,priority)
    select x.player_id,'nextgen_accelerator',x.effective_rank,3
    from public.nextgen_accelerator_candidate_ids(t.id,'main') x
    where not exists(select 1 from cb_pathway_entries pe where pe.player_id=x.player_id)
    limit r.nextgen_accelerator_main_slots
    on conflict(player_id) do nothing;
  end if;

  if coalesce(r.junior_reserved_slots,0)>0 then
    insert into cb_pathway_entries(player_id,entry_method,pathway_rank,priority)
    select x.player_id,'junior_reserved',x.junior_rank,4
    from public.junior_reserved_candidate_ids(t.id) x
    where not exists(select 1 from cb_pathway_entries pe where pe.player_id=x.player_id)
    limit r.junior_reserved_slots
    on conflict(player_id) do nothing;
  end if;

  -- ATP 2026 Challenger 50/75 composition caps all JAS/CAS/Next Gen
  -- accelerator main-draw positions at three total, not three per pathway.
  if t.circuit='Challenger' and t.category in ('Challenger 50','Challenger 75') then
    delete from cb_pathway_entries pe
    where pe.player_id in (
      select z.player_id
      from (
        select
          p2.player_id,
          row_number() over(
            order by
              case
                when p2.entry_method='junior_accelerator' then
                  coalesce((
                    select je.year_end_rank
                    from public.junior_accelerator_entitlements je
                    where je.season=extract(year from t.start_date)::int
                      and je.player_id=p2.player_id
                  ),1)*100
                when p2.entry_method='college_accelerator' then
                  coalesce((
                    select ce.year_end_ita_rank
                    from public.atp_college_accelerator_entitlements ce
                    where ce.season=extract(year from t.start_date)::int
                      and ce.player_id=p2.player_id
                  ),1)*100
                when p2.entry_method='nextgen_accelerator' then
                  greatest(1,coalesce(p2.pathway_rank,500)-350)*7
                else 999999
              end,
              p2.player_id
          ) rn
        from cb_pathway_entries p2
        where p2.entry_method in ('junior_accelerator','college_accelerator','nextgen_accelerator')
      ) z
      where z.rn>3
    );
  end if;

  select greatest(
    0,
    v_main-r.qualifier_count-r.wildcard_count-v_a_plus_count
      -coalesce(r.special_exempt_slots,0)-coalesce(t.late_entry_slots,0)
      -(select count(*) from cb_pathway_entries)
  ) into v_direct;

  insert into cb_entries_work(player_id,name,country,entry_method,ranking_at_entry)
  select pe.player_id,p.name,p.country,pe.entry_method,
         coalesce(case when p.ranking_current then p.ranking end,p.game_world_rank,p.ranking,999999)::int
  from cb_pathway_entries pe
  join public.players p on p.id=pe.player_id
  order by pe.priority,coalesce(pe.pathway_rank,999999),pe.player_id;

  insert into cb_entries_work(player_id,name,country,entry_method,ranking_at_entry)
  select c.player_id,c.name,c.country,'direct',c.effective_rank
  from cb_candidates c
  where not exists(select 1 from cb_entries_work e where e.player_id=c.player_id)
    and not exists(select 1 from cb_a_plus_wc aw where aw.player_id=c.player_id)
    and (public.tournament_entry_eligibility(c.player_id,t.id,'direct')->>'eligible')::boolean
    and not (public.player_tournament_calendar_conflict(c.player_id,t.id,'direct')->>'conflict')::boolean
  order by c.effective_rank asc,c.selection_score desc,c.player_id
  limit v_direct;

  if coalesce(t.late_entry_slots,0)>0 then
    -- ATP 2026 Rulebook 7.04: a Late Entry may only be awarded to a player
    -- ranked better than the original acceptance-list cut.
    insert into cb_entries_work(player_id,name,country,entry_method,ranking_at_entry)
    select c.player_id,c.name,c.country,'late_entry',c.effective_rank
    from cb_candidates c
    where not exists(select 1 from cb_entries_work e where e.player_id=c.player_id)
      and c.effective_rank<coalesce(t.direct_cut,t.projected_direct_cut,0)
      and (public.tournament_entry_eligibility(c.player_id,t.id,'direct')->>'eligible')::boolean
      and not (public.player_tournament_calendar_conflict(c.player_id,t.id,'direct')->>'conflict')::boolean
    order by c.effective_rank asc,c.selection_score desc,c.player_id
    limit t.late_entry_slots;

    -- If nobody uses the LE spot by the deadline, the Rulebook sends the
    -- vacancy to the next eligible player on the original entry list.
    if (
      select count(*) from cb_entries_work where entry_method='late_entry'
    ) < coalesce(t.late_entry_slots,0) then
      insert into cb_entries_work(player_id,name,country,entry_method,ranking_at_entry)
      select c.player_id,c.name,c.country,'direct',c.effective_rank
      from cb_candidates c
      where not exists(select 1 from cb_entries_work e where e.player_id=c.player_id)
        and (public.tournament_entry_eligibility(c.player_id,t.id,'direct')->>'eligible')::boolean
        and not (public.player_tournament_calendar_conflict(c.player_id,t.id,'direct')->>'conflict')::boolean
      order by c.effective_rank asc,c.selection_score desc,c.player_id
      limit greatest(
        0,
        coalesce(t.late_entry_slots,0)
        -(select count(*) from cb_entries_work where entry_method='late_entry')
      );
    end if;
  end if;

  if coalesce(r.special_exempt_slots,0)>0 then
    insert into cb_entries_work(player_id,name,country,entry_method,ranking_at_entry)
    select c.player_id,c.name,c.country,'special_exempt',c.effective_rank
    from cb_candidates c
    where not exists(select 1 from cb_entries_work e where e.player_id=c.player_id)
      and c.effective_rank>coalesce(t.direct_cut,t.projected_direct_cut,0)
      and (public.tournament_entry_eligibility(c.player_id,t.id,'direct')->>'eligible')::boolean
      and exists(
        select 1
        from public.world_tournament_entries pe
        join public.tournaments pt on pt.id=pe.tournament_id
        where pe.player_id=c.player_id
          and pt.id<>t.id
          and pt.start_date<t.start_date
          and coalesce(pt.end_date,pt.start_date)>=coalesce(t.qualifying_start_date,t.start_date)
          and coalesce(pt.end_date,pt.start_date)<=t.start_date
          and pe.result_code in ('W','F','SF')
          and public.tournament_special_exempt_eligible(pt.id,t.id)
      )
    order by c.effective_rank asc,c.selection_score desc,c.player_id
    limit r.special_exempt_slots;
  end if;

  if v_a_plus_count>0 then
    insert into cb_entries_work(player_id,name,country,entry_method,ranking_at_entry)
    select c.player_id,c.name,c.country,'wildcard_a_plus',c.effective_rank
    from cb_candidates c
    join cb_a_plus_wc aw on aw.player_id=c.player_id
    where not exists(select 1 from cb_entries_work e where e.player_id=c.player_id)
    limit 1;
  end if;

  if r.wildcard_count>0 then
    insert into cb_entries_work(player_id,name,country,entry_method,ranking_at_entry)
    select c.player_id,c.name,c.country,'wildcard',c.effective_rank
    from cb_candidates c
    where not exists(select 1 from cb_entries_work e where e.player_id=c.player_id)
      and (public.tournament_entry_eligibility(c.player_id,t.id,'wildcard')->>'eligible')::boolean
    order by
      (c.country is not distinct from t.country) desc,
      c.potential desc,
      c.selection_score desc,
      c.effective_rank asc,
      c.player_id
    limit r.wildcard_count;
  end if;

  if r.qualifier_count>0 then
    insert into cb_entries_work(
      player_id,name,country,entry_method,ranking_at_entry,qualifying_points
    )
    select
      q.player_id,p.name,p.country,
      case
        when q.entry_method='junior_accelerator_qualifying' then 'junior_accelerator_qualifier'
        when q.entry_method='college_accelerator_qualifying' then 'college_accelerator_qualifier'
        when q.entry_method='nextgen_accelerator_qualifying' then 'nextgen_accelerator_qualifier'
        else 'qualifier'
      end,
      coalesce(q.ranking_at_entry,999999),q.qualifying_points
    from public.world_tournament_qualifiers q
    join public.players p on p.id=q.player_id
    where q.tournament_id=t.id
      and not exists(select 1 from cb_entries_work e where e.player_id=q.player_id)
    order by q.qualifier_slot
    limit r.qualifier_count;

    if (
      select count(*) from cb_entries_work
      where entry_method in (
        'qualifier',
        'junior_accelerator_qualifier',
        'college_accelerator_qualifier',
        'nextgen_accelerator_qualifier'
      )
    )<r.qualifier_count then
      insert into cb_entries_work(
        player_id,name,country,entry_method,ranking_at_entry,qualifying_points
      )
      select c.player_id,c.name,c.country,'qualifier',c.effective_rank,
             coalesce((r.qualifying_points->>'Q')::int,0)
      from cb_candidates c
      where not exists(select 1 from cb_entries_work e where e.player_id=c.player_id)
        and (public.tournament_entry_eligibility(c.player_id,t.id,'qualifying')->>'eligible')::boolean
      order by c.effective_rank asc,c.selection_score desc,c.player_id
      limit greatest(
        0,
        r.qualifier_count-(
          select count(*) from cb_entries_work
          where entry_method in (
            'qualifier',
            'junior_accelerator_qualifier',
            'college_accelerator_qualifier',
            'nextgen_accelerator_qualifier'
          )
        )
      );
    end if;
  end if;

  select greatest(0,v_main-count(*)) into v_needed from cb_entries_work;
  if v_needed>0 then
    insert into cb_entries_work(player_id,name,country,entry_method,ranking_at_entry)
    select c.player_id,c.name,c.country,'direct',c.effective_rank
    from cb_candidates c
    where not exists(select 1 from cb_entries_work e where e.player_id=c.player_id)
    order by c.effective_rank asc,c.selection_score desc,c.player_id
    limit v_needed;
  end if;

  select greatest(0,v_main-count(*)) into v_needed from cb_entries_work;
  if v_needed>0 then
    insert into cb_entries_work(player_id,name,country,entry_method,ranking_at_entry)
    select
      p.id,p.name,p.country,'alternate',
      coalesce(case when p.ranking_current then p.ranking end,p.game_world_rank,p.ranking,999999)::int
    from public.players p
    where p.career_status='active'
      and p.id is distinct from v_managed
      and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
      and coalesce(p.career_focus,'mixed')<>'doubles_only'
      and p.injury_status='Fit'
      and coalesce(p.fitness,90)>=45
      and coalesce(p.fatigue,20)<=90
      and not exists(select 1 from cb_entries_work e where e.player_id=p.id)
      and not exists(
        select 1
        from public.world_tournament_entries e
        join public.tournaments ot on ot.id=e.tournament_id
        where e.player_id=p.id
          and daterange(ot.start_date,coalesce(ot.end_date,ot.start_date),'[]')
              && daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
      )
    order by
      coalesce(case when p.ranking_current then p.ranking end,p.game_world_rank,p.ranking,999999),
      p.current_ability desc,p.id
    limit v_needed;
  end if;

  -- After qualifying has started, late main-draw vacancies are filled by Lucky Losers.
  v_ll_vacancies:=public.world_postq_direct_vacancy_count(t.id,v_direct);
  if v_ll_vacancies>0 and coalesce(r.qualifier_count,0)>0 then
    perform public.refresh_world_tournament_lucky_losers(t.id,v_ll_vacancies);

    delete from cb_entries_work e
    where e.player_id in (
      select d.player_id
      from cb_entries_work d
      where d.entry_method='direct'
      order by d.ranking_at_entry desc,d.player_id desc
      limit v_ll_vacancies
    );

    insert into cb_entries_work(
      player_id,name,country,entry_method,ranking_at_entry,qualifying_points
    )
    select
      ll.player_id,p.name,p.country,'lucky_loser',ll.ranking_at_seeding,
      coalesce((r.qualifying_points->>ll.loss_round_code)::int,0)
    from public.world_tournament_lucky_losers ll
    join public.players p on p.id=ll.player_id
    where ll.tournament_id=t.id
      and not exists(select 1 from cb_entries_work e where e.player_id=ll.player_id)
      and coalesce(p.injury_status,'Fit')='Fit'
    order by ll.ll_order
    limit v_ll_vacancies;

    get diagnostics v_ll_inserted=row_count;

    update public.world_tournament_lucky_losers ll
    set selected=true
    where ll.tournament_id=t.id
      and exists(
        select 1 from cb_entries_work e
        where e.player_id=ll.player_id and e.entry_method='lucky_loser'
      );

    if v_ll_inserted<v_ll_vacancies then
      insert into cb_entries_work(player_id,name,country,entry_method,ranking_at_entry)
      select c.player_id,c.name,c.country,'alternate',c.effective_rank
      from cb_candidates c
      where not exists(select 1 from cb_entries_work e where e.player_id=c.player_id)
      order by c.effective_rank,c.selection_score desc,c.player_id
      limit greatest(0,v_ll_vacancies-v_ll_inserted);
    end if;
  end if;

  select count(*) into v_participants from cb_entries_work;
  if v_participants<>v_main then
    return jsonb_build_object(
      'skipped','insufficient_participants','tournament_id',t.id,
      'required',v_main,'selected',v_participants,'rule_key',r.rule_key
    );
  end if;

  with ranked as (
    select player_id,row_number() over(
      order by public.player_rank_at_date(
        player_id,coalesce(t.main_draw_start_date,t.start_date)
      ) asc,player_id
    )::int rn
    from cb_entries_work
  )
  update cb_entries_work e
  set seed=ranked.rn
  from ranked
  where e.player_id=ranked.player_id
    and ranked.rn<=v_seed_count;

  create temporary table cb_performance_byes(
    player_id bigint primary key
  ) on commit drop;

  if coalesce(t.performance_bye_slots,0)>0
     and coalesce(t.performance_bye_source_event,'')<>'' then
    insert into cb_performance_byes(player_id)
    select e.player_id
    from cb_entries_work e
    where e.seed is null
      and exists(
        select 1
        from public.world_tournament_entries pe
        join public.tournaments pt on pt.id=pe.tournament_id
        where pe.player_id=e.player_id
          and pe.result_code in ('W','F')
          and pt.start_date<t.start_date
          and extract(year from pt.start_date)=extract(year from t.start_date)
          and pt.name ilike '%'||t.performance_bye_source_event||'%'
      )
    order by e.ranking_at_entry,e.player_id
    limit t.performance_bye_slots;

    select count(*) into v_pb_count from cb_performance_byes;

    if v_pb_count>0 then
      update cb_entries_work e
      set entry_method='performance_bye'
      where exists(select 1 from cb_performance_byes pb where pb.player_id=e.player_id);

      delete from cb_entries_work e
      where e.player_id in (
        select d.player_id
        from cb_entries_work d
        where d.entry_method='direct'
          and not exists(select 1 from cb_performance_byes pb where pb.player_id=d.player_id)
          and d.seed is null
        order by d.ranking_at_entry desc,d.player_id desc
        limit v_pb_count
      );
    end if;
  end if;

  select count(*) into v_participants from cb_entries_work;
  if v_participants<>v_main-v_pb_count then
    return jsonb_build_object(
      'skipped','performance_bye_composition_failed',
      'tournament_id',t.id,'required',v_main-v_pb_count,
      'selected',v_participants,'performance_byes',v_pb_count
    );
  end if;

  update cb_entries_work
  set draw_slot=public.world_tournament_seed_slot_for_event(t.id,v_bracket,seed)
  where seed is not null;

  create temporary table cb_bye_slots(slot integer primary key) on commit drop;
  if v_byes>0 then
    insert into cb_bye_slots(slot)
    select case when draw_slot%2=1 then draw_slot+1 else draw_slot-1 end
    from cb_entries_work
    where seed between 1 and least(v_byes,v_seed_count)
      and draw_slot is not null
    on conflict do nothing;

    update cb_entries_work
    set had_bye=true
    where seed between 1 and least(v_byes,v_seed_count);
  end if;

  if v_pb_count>0 then
    with pb as (
      select player_id,row_number() over(order by player_id)::int rn
      from cb_performance_byes
    ),
    open_pairs as (
      select s as slot,
             row_number() over(order by md5('pb-slot|'||t.id::text||'|'||s::text))::int rn
      from generate_series(1,v_bracket,2) s
      where not exists(select 1 from cb_entries_work e where e.draw_slot in (s,s+1))
        and not exists(select 1 from cb_bye_slots b where b.slot in (s,s+1))
    )
    update cb_entries_work e
    set draw_slot=o.slot,
        had_bye=true
    from pb
    join open_pairs o using(rn)
    where e.player_id=pb.player_id;

    insert into cb_bye_slots(slot)
    select case when e.draw_slot%2=1 then e.draw_slot+1 else e.draw_slot-1 end
    from cb_entries_work e
    where exists(select 1 from cb_performance_byes pb where pb.player_id=e.player_id)
      and e.draw_slot is not null
    on conflict do nothing;

    if exists(
      select 1 from cb_entries_work e
      where exists(select 1 from cb_performance_byes pb where pb.player_id=e.player_id)
        and e.draw_slot is null
    ) then
      return jsonb_build_object(
        'skipped','performance_bye_slot_failed',
        'tournament_id',t.id,'performance_byes',v_pb_count
      );
    end if;
  end if;

  create temporary table cb_available_slots(slot integer primary key) on commit drop;
  insert into cb_available_slots(slot)
  select s
  from generate_series(1,v_bracket) s
  where not exists(select 1 from cb_entries_work e where e.draw_slot=s)
    and not exists(select 1 from cb_bye_slots b where b.slot=s);

  with players_to_place as (
    select player_id,row_number() over(
      order by md5('draw-player|'||t.id::text||'|'||player_id::text)
    ) rn
    from cb_entries_work
    where draw_slot is null
  ),
  slots_to_fill as (
    select slot,row_number() over(
      order by md5('draw-slot|'||t.id::text||'|'||slot::text)
    ) rn
    from cb_available_slots
  )
  update cb_entries_work e
  set draw_slot=s.slot
  from players_to_place p
  join slots_to_fill s using(rn)
  where e.player_id=p.player_id;

  if exists(select 1 from cb_entries_work where draw_slot is null) then
    return jsonb_build_object('skipped','draw_slot_assignment_failed','tournament_id',t.id);
  end if;

  delete from public.world_tournament_matches where tournament_id=t.id and coalesce(is_qualifying,false)=false;
  delete from public.world_tournament_entries where tournament_id=t.id;

  create temporary table cb_round_slots(
    pos integer primary key,
    player_id bigint
  ) on commit drop;
  create temporary table cb_next_slots(
    pos integer primary key,
    player_id bigint
  ) on commit drop;

  insert into cb_round_slots(pos,player_id)
  select s,e.player_id
  from generate_series(1,v_bracket) s
  left join cb_entries_work e on e.draw_slot=s;

  v_current_size:=v_bracket;

  for v_round in 1..v_rounds loop
    v_round_code:=r.rounds[v_round];
    truncate cb_next_slots;
    v_next_pos:=0;

    for v_pos in 1..v_current_size by 2 loop
      v_next_pos:=v_next_pos+1;
      select player_id into v_a from cb_round_slots where pos=v_pos;
      select player_id into v_b from cb_round_slots where pos=v_pos+1;

      if v_a is null and v_b is null then
        insert into cb_next_slots(pos,player_id) values(v_next_pos,null);
        continue;
      elsif v_a is null or v_b is null then
        v_winner:=coalesce(v_a,v_b);
        if v_round=1 then
          update cb_entries_work set had_bye=true where player_id=v_winner;
        end if;
        insert into cb_next_slots(pos,player_id) values(v_next_pos,v_winner);
        continue;
      end if;

      select name into v_a_name from cb_entries_work where player_id=v_a;
      select name into v_b_name from cb_entries_work where player_id=v_b;

      v_match:=public.player_matchup_probability_v4(
        v_a,v_b,t.surface,coalesce(t.end_date,t.start_date),
        coalesce(t.court_speed,
          case
            when t.surface ilike 'Terre%' then .68
            when t.surface ilike 'Gazon%' then 1.15
            when coalesce(t.indoor,false) then 1.18
            else 1.0
          end
        ),
        v_best_of
      );
      v_prob:=greatest(.02,least(.98,coalesce((v_match->>'player_a_probability')::numeric,.5)));
      v_a_won:=random()<v_prob;
      v_winner:=case when v_a_won then v_a else v_b end;
      v_loser:=case when v_a_won then v_b else v_a end;
      v_winner_name:=case when v_a_won then v_a_name else v_b_name end;
      v_loser_name:=case when v_a_won then v_b_name else v_a_name end;
      v_score:=public.world_tournament_score(v_prob,v_a_won,v_best_of);
      v_loser_score:=case when v_loser=v_a then v_score else public.world_invert_tennis_score(v_score) end;

      insert into public.world_tournament_matches(
        tournament_id,round_no,round_code,match_no,
        player_a_id,player_b_id,winner_id,loser_id,score,best_of,
        player_a_win_probability,court_speed,model_version,matchup_components,simulated_on
      ) values(
        t.id,v_round,v_round_code,((v_pos+1)/2),
        v_a,v_b,v_winner,v_loser,v_score,v_best_of,
        round(v_prob,4),
        coalesce(t.court_speed,
          case
            when t.surface ilike 'Terre%' then .68
            when t.surface ilike 'Gazon%' then 1.15
            when coalesce(t.indoor,false) then 1.18
            else 1.0
          end
        ),
        'CB-MATCH-v4-FULLDRAW',
        coalesce(v_match->'components','{}'::jsonb)
          || jsonb_build_object('extended_attributes',coalesce(v_match->'extended_attributes','{}'::jsonb)),
        coalesce(p_simulated_on,t.end_date,t.start_date)
      );
      v_matches:=v_matches+1;

      select matches_won,had_bye,entry_method,qualifying_points
      into v_loser_wins,v_loser_bye,v_loser_method,v_qual_points
      from cb_entries_work where player_id=v_loser;

      v_base_points:=coalesce((r.points_by_result->>v_round_code)::int,0);

      if coalesce(v_loser_bye,false) and coalesce(v_loser_wins,0)=0 then
        v_base_points:=coalesce((r.points_by_result->>r.rounds[1])::int,0);
      end if;

      if v_loser_method='wildcard'
         and coalesce(v_loser_wins,0)=0
         and t.category in ('Grand Chelem','Masters 1000') then
        v_base_points:=0;
      end if;

      update cb_entries_work
      set result_code=v_round_code,
          result_label=public.world_tournament_result_label(v_round_code),
          points_awarded=greatest(0,v_base_points+coalesce(v_qual_points,0)),
          last_opponent_id=v_winner,
          last_opponent_name=v_winner_name,
          last_score=v_loser_score
      where player_id=v_loser;

      update cb_entries_work
      set matches_won=matches_won+1
      where player_id=v_winner;

      insert into cb_next_slots(pos,player_id) values(v_next_pos,v_winner);
    end loop;

    truncate cb_round_slots;
    insert into cb_round_slots select * from cb_next_slots;
    v_current_size:=greatest(1,v_current_size/2);
  end loop;

  select player_id into v_champion
  from cb_round_slots
  order by pos
  limit 1;

  if v_champion is null then
    raise exception 'Full draw simulation produced no champion for tournament %',t.id;
  end if;

  select name,qualifying_points into v_champion_name,v_qual_points
  from cb_entries_work where player_id=v_champion;
  v_champion_points:=coalesce((r.points_by_result->>'W')::int,0)+coalesce(v_qual_points,0);

  select loser_id into v_finalist
  from public.world_tournament_matches
  where tournament_id=t.id and round_code='F'
  order by id desc limit 1;

  select name,points_awarded into v_finalist_name,v_finalist_points
  from cb_entries_work where player_id=v_finalist;

  update cb_entries_work
  set result_code='W',
      result_label='Vainqueur',
      points_awarded=greatest(0,v_champion_points)
  where player_id=v_champion;

  update cb_entries_work e
  set last_opponent_id=wm.loser_id,
      last_opponent_name=l.name,
      last_score=case
        when wm.player_a_id=e.player_id then wm.score
        else public.world_invert_tennis_score(wm.score)
      end
  from public.world_tournament_matches wm
  join public.players l on l.id=wm.loser_id
  where e.player_id=v_champion
    and wm.tournament_id=t.id
    and wm.round_code='F'
    and wm.winner_id=v_champion;

  insert into public.world_tournament_entries(
    tournament_id,player_id,seed,draw_slot,entry_method,ranking_at_entry,had_bye,
    matches_won,result_code,result_label,points_awarded,qualifying_points,
    last_opponent_id,last_opponent_name,last_score,simulated_on,source_label
  )
  select
    t.id,player_id,seed,draw_slot,entry_method,ranking_at_entry,had_bye,
    matches_won,result_code,result_label,points_awarded,qualifying_points,
    last_opponent_id,last_opponent_name,last_score,
    coalesce(p_simulated_on,t.end_date,t.start_date),
    'Court Boss full world draw · '||r.rule_key
  from cb_entries_work;

  update public.world_tournament_entries e
  set prize_awarded=public.tournament_prize_for_result(t.id,e.result_code,'singles'),
      prize_currency=coalesce(t.prize_currency,'USD'),
      prize_is_estimate=coalesce(t.singles_prize_is_estimate,t.prize_breakdown_is_estimate,true)
  where e.tournament_id=t.id;

  insert into public.world_ranking_points(
    player_id,tournament_id,label,earned_date,expiry_date,points,active,source_label
  )
  select
    e.player_id,t.id,
    t.name||' · '||e.result_code,
    coalesce(t.end_date,t.start_date),
    coalesce(t.end_date,t.start_date)+364,
    e.points_awarded,true,
    'Court Boss full draw · '||e.result_code||' · '||r.rule_key
  from cb_entries_work e
  where e.points_awarded>0
  on conflict(player_id,tournament_id) do update set
    label=excluded.label,
    earned_date=excluded.earned_date,
    expiry_date=excluded.expiry_date,
    points=excluded.points,
    active=true,
    source_label=excluded.source_label;

  insert into public.player_tournament_history(
    player_id,season,tournament_id,tournament_name,tournament_date,level,category,surface,
    result_code,result_label,last_opponent,last_score,is_grand_slam,source,event_type
  )
  select
    e.player_id,
    extract(year from coalesce(t.end_date,t.start_date))::int,
    t.id::text,t.name,coalesce(t.end_date,t.start_date),
    coalesce(t.level,t.category,t.circuit),t.category,t.surface,
    e.result_code,e.result_label,e.last_opponent_name,e.last_score,
    t.category='Grand Chelem',
    'Court Boss full world draw · '||r.rule_key,
    'singles'
  from cb_entries_work e
  on conflict(player_id,event_type,tournament_id) do update set
    season=excluded.season,
    tournament_name=excluded.tournament_name,
    tournament_date=excluded.tournament_date,
    level=excluded.level,
    category=excluded.category,
    surface=excluded.surface,
    result_code=excluded.result_code,
    result_label=excluded.result_label,
    last_opponent=excluded.last_opponent,
    last_score=excluded.last_score,
    is_grand_slam=excluded.is_grand_slam,
    source=excluded.source;

  insert into public.player_titles(
    player_id,tournament_name,title_date,level,surface,event_type,verified,source_label,origin
  ) values(
    v_champion,t.name,coalesce(t.end_date,t.start_date),
    coalesce(t.category,t.level,t.circuit),t.surface,'singles',false,
    'Court Boss full world draw · '||r.rule_key,'game'
  )
  on conflict(player_id,tournament_name,title_date,event_type) do update set
    level=excluded.level,surface=excluded.surface,source_label=excluded.source_label,origin=excluded.origin;

  insert into public.player_final_results(
    player_id,tournament_name,final_date,level,surface,result,opponent_name,source,event_type
  ) values
    (v_champion,t.name,coalesce(t.end_date,t.start_date),coalesce(t.category,t.level,t.circuit),t.surface,'Champion',v_finalist_name,'Court Boss full world draw','singles'),
    (v_finalist,t.name,coalesce(t.end_date,t.start_date),coalesce(t.category,t.level,t.circuit),t.surface,'Finaliste',v_champion_name,'Court Boss full world draw','singles')
  on conflict(player_id,tournament_name,final_date,result) do update set
    level=excluded.level,surface=excluded.surface,opponent_name=excluded.opponent_name,source=excluded.source,event_type=excluded.event_type;

  for m in
    select *
    from public.world_tournament_matches
    where tournament_id=t.id
      and winner_id is not null
      and loser_id is not null
    order by round_no,match_no
  loop
    perform public.update_h2h_after_match(
      m.winner_id,m.loser_id,t.surface,coalesce(t.end_date,t.start_date),false,
      'Court Boss full world draw · '||coalesce(m.round_code,'')
    );
    perform public.update_player_elo_after_match(
      m.winner_id,m.loser_id,t.surface,coalesce(t.end_date,t.start_date),false,
      case
        when m.round_code='F' then case when t.category='Grand Chelem' then 1.20 when t.category='Masters 1000' then 1.15 else 1.10 end
        when m.round_code='SF' then 1.08
        when m.round_code='QF' then 1.04
        else 1.0
      end
    );
  end loop;

  with stats as (
    select
      e.player_id,
      e.matches_won,
      e.result_code,
      count(wm.id)::int as matches_played
    from cb_entries_work e
    left join public.world_tournament_matches wm
      on wm.tournament_id=t.id
     and (wm.player_a_id=e.player_id or wm.player_b_id=e.player_id)
    group by e.player_id,e.matches_won,e.result_code
  )
  update public.players p
  set form=greatest(35,least(100,p.form+
        case stats.result_code when 'W' then 4 when 'F' then 3 when 'SF' then 2 when 'QF' then 1 else 0 end
      )),
      morale=greatest(30,least(100,p.morale+
        case stats.result_code when 'W' then 5 when 'F' then 3 when 'SF' then 2 when 'QF' then 1 else 0 end
      ))
  from stats
  where p.id=stats.player_id;

  update public.player_dynamic_ratings d
  set overall_elo=e.overall_elo,
      hard_elo=e.hard_elo,
      clay_elo=e.clay_elo,
      grass_elo=e.grass_elo,
      rating_confidence=greatest(d.rating_confidence,e.confidence),
      last_competitive_match=coalesce(t.end_date,t.start_date),
      source_label='Court Boss live hybrid Elo · full world draw',
      updated_at=now()
  from public.player_elo_ratings e
  where e.player_id=d.player_id
    and d.player_id in (select player_id from cb_entries_work);

  select
    case when wm.winner_id=wm.player_a_id then wm.player_a_win_probability else 1-wm.player_a_win_probability end,
    wm.matchup_components
  into v_final_prob,v_final_components
  from public.world_tournament_matches wm
  where wm.tournament_id=t.id and wm.round_code='F'
  order by wm.id desc limit 1;

  insert into public.world_tournament_simulations(
    tournament_id,winner_id,finalist_id,winner_points,finalist_points,simulated_on,
    final_win_probability,court_speed,model_version,matchup_components,
    rule_key,draw_size,bracket_size,rounds_count,matches_simulated,participants_simulated,format_type
  ) values(
    t.id,v_champion,v_finalist,v_champion_points,coalesce(v_finalist_points,0),
    coalesce(p_simulated_on,t.end_date,t.start_date),
    round(coalesce(v_final_prob,.5),4),
    coalesce(t.court_speed,
      case
        when t.surface ilike 'Terre%' then .68
        when t.surface ilike 'Gazon%' then 1.15
        when coalesce(t.indoor,false) then 1.18
        else 1.0
      end
    ),
    'CB-MATCH-v4-FULLDRAW',coalesce(v_final_components,'{}'::jsonb),
    r.rule_key,v_main,v_bracket,v_rounds,v_matches,v_participants,'knockout'
  );

  return jsonb_build_object(
    'ok',true,
    'tournament_id',t.id,
    'name',t.name,
    'rule_key',r.rule_key,
    'draw_size',v_main,
    'bracket_size',v_bracket,
    'byes',v_byes+v_pb_count,
    'performance_byes',v_pb_count,
    'pathway_entries',(select count(*) from cb_pathway_entries),
    'junior_reserved',(select count(*) from cb_pathway_entries where entry_method='junior_reserved'),
    'junior_accelerator',(select count(*) from cb_pathway_entries where entry_method='junior_accelerator'),
    'college_accelerator',(select count(*) from cb_pathway_entries where entry_method='college_accelerator'),
    'rounds',r.rounds,
    'matches',v_matches,
    'participants',v_participants,
    'champion_id',v_champion,
    'champion',v_champion_name,
    'finalist_id',v_finalist,
    'finalist',v_finalist_name,
    'winner_points',v_champion_points,
    'finalist_points',v_finalist_points,
    'model','CB-MATCH-v4-FULLDRAW'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.simulate_world_round_robin_tournament_full(p_tournament_id bigint, p_simulated_on date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  r public.tournament_format_rules%rowtype;
  v_managed bigint;
  v_managed_rank integer;
  rr record;
  mh record;
  v_a bigint;
  v_b bigint;
  v_a_name text;
  v_b_name text;
  v_match jsonb;
  v_prob numeric;
  v_a_won boolean;
  v_winner bigint;
  v_loser bigint;
  v_winner_name text;
  v_loser_name text;
  v_score text;
  v_match_no integer:=0;
  v_rr_points integer:=0;
  v_sf_points integer:=0;
  v_f_points integer:=0;
  v_champion bigint;
  v_finalist bigint;
  v_champion_name text;
  v_finalist_name text;
  v_champion_points integer:=0;
  v_finalist_points integer:=0;
  v_final_prob numeric:=.5;
  v_final_components jsonb:='{}'::jsonb;
  v_participants integer:=0;
begin
  select * into t from public.tournaments
  where id=p_tournament_id and singles=true and coalesce(is_active,true)=true;

  if t.id is null then
    return jsonb_build_object('skipped','tournament_not_found','tournament_id',p_tournament_id);
  end if;

  if exists(select 1 from public.world_tournament_simulations s where s.tournament_id=t.id) then
    return jsonb_build_object('skipped','already_simulated','tournament_id',t.id);
  end if;

  select * into r
  from public.tournament_format_rules x
  where x.circuit=t.circuit and x.category=t.category
    and x.main_draw_size=coalesce(t.singles_draw_size,t.draw_size)
    and x.format_type='round_robin'
  limit 1;

  if r.rule_key is null then
    return jsonb_build_object('skipped','missing_round_robin_rule','tournament_id',t.id,'category',t.category);
  end if;

  select managed_player_id into v_managed from public.career_state where id='demo';

  if t.category='ATP Finals' then
    select race_ranking into v_managed_rank from public.players where id=v_managed;
  else
    select nextgen_ranking into v_managed_rank from public.players where id=v_managed;
  end if;

  if (
    t.category='ATP Finals' and coalesce(v_managed_rank,999999)<=8
  ) or (
    t.category='Next Gen Finals' and coalesce(v_managed_rank,999999)<=7
  ) then
    return jsonb_build_object(
      'skipped','managed_player_qualified',
      'tournament_id',t.id,'category',t.category,'managed_rank',v_managed_rank
    );
  end if;

  v_rr_points:=coalesce((r.points_by_result->>'RR_WIN')::int,0);
  v_sf_points:=coalesce((r.points_by_result->>'SF_WIN')::int,0);
  v_f_points:=coalesce((r.points_by_result->>'F_WIN')::int,0);

  drop table if exists pg_temp.cb_rr_entries;
  create temporary table cb_rr_entries(
    player_id bigint primary key,
    name text not null,
    seed integer not null,
    group_name text not null,
    entry_method text not null default 'race',
    wins integer not null default 0,
    losses integer not null default 0,
    points_awarded integer not null default 0,
    result_code text default 'RR',
    result_label text default 'Phase de groupes',
    last_opponent_id bigint,
    last_opponent_name text,
    last_score text
  ) on commit drop;

  if t.category='ATP Finals' then
    insert into cb_rr_entries(player_id,name,seed,group_name)
    select id,name,rn,
      case when rn in (1,4,5,8) then 'A' else 'B' end
    from (
      select p.id,p.name,
             row_number() over(order by coalesce(p.race_ranking,999999),coalesce(p.ranking,999999),p.id)::int rn
      from public.players p
      where p.ranking_current=true
        and p.career_status='active'
        and p.id is distinct from v_managed
        and p.injury_status='Fit'
        and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
        and coalesce(p.career_focus,'mixed')<>'doubles_only'
        and p.race_ranking is not null
      order by coalesce(p.race_ranking,999999),coalesce(p.ranking,999999),p.id
      limit 8
    ) s;
  else
    -- ATP 2026 rule: seven direct acceptances from the Next Gen Race,
    -- followed by one ATP wildcard. The wildcard is simulated rather than
    -- pretending its identity is known before the ATP announces it.
    insert into cb_rr_entries(player_id,name,seed,group_name,entry_method)
    select id,name,rn,
      case when rn in (1,4,5,8) then 'A' else 'B' end,
      'race'
    from (
      select p.id,p.name,
             row_number() over(
               order by coalesce(p.nextgen_ranking,999999),
                        coalesce(p.race_ranking,999999),
                        p.id
             )::int rn
      from public.players p
      where p.career_status='active'
        and p.id is distinct from v_managed
        and p.injury_status='Fit'
        and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
        and p.nextgen_ranking between 1 and 7
        and public.nextgen_player_eligible(
              p.id,extract(year from coalesce(t.start_date,p_simulated_on))::int
            )
      order by coalesce(p.nextgen_ranking,999999),coalesce(p.race_ranking,999999),p.id
      limit 7
    ) s;

    insert into cb_rr_entries(player_id,name,seed,group_name,entry_method)
    select p.id,p.name,8,'A','wildcard'
    from public.players p
    where p.career_status='active'
      and p.id is distinct from v_managed
      and p.injury_status='Fit'
      and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
      and p.nextgen_ranking is not null
      and p.nextgen_ranking>7
      and public.nextgen_player_eligible(
            p.id,extract(year from coalesce(t.start_date,p_simulated_on))::int
          )
      and not exists(select 1 from cb_rr_entries e where e.player_id=p.id)
    order by
      (
        coalesce(p.nextgen_ranking,999999)
        - case when upper(coalesce(p.country,''))=upper(coalesce(t.country,'')) then 2 else 0 end
      ),
      coalesce(p.nextgen_ranking,999999),
      p.potential desc,
      p.id
    limit 1;
  end if;

  select count(*) into v_participants from cb_rr_entries;
  if v_participants<>8 then
    return jsonb_build_object('skipped','insufficient_finalists','tournament_id',t.id,'selected',v_participants);
  end if;

  delete from public.world_tournament_matches where tournament_id=t.id;
  delete from public.world_tournament_entries where tournament_id=t.id;

  for rr in
    select a.player_id a_id,b.player_id b_id,a.name a_name,b.name b_name,a.group_name
    from cb_rr_entries a
    join cb_rr_entries b on b.group_name=a.group_name and b.seed>a.seed
    order by a.group_name,a.seed,b.seed
  loop
    v_match_no:=v_match_no+1;
    v_a:=rr.a_id;v_b:=rr.b_id;v_a_name:=rr.a_name;v_b_name:=rr.b_name;

    v_match:=public.player_matchup_probability_v4(
      v_a,v_b,t.surface,coalesce(t.end_date,t.start_date),
      coalesce(t.court_speed,case when coalesce(t.indoor,false) then 1.18 else 1.0 end),3
    );
    v_prob:=greatest(.02,least(.98,coalesce((v_match->>'player_a_probability')::numeric,.5)));
    v_a_won:=random()<v_prob;
    v_winner:=case when v_a_won then v_a else v_b end;
    v_loser:=case when v_a_won then v_b else v_a end;
    v_winner_name:=case when v_a_won then v_a_name else v_b_name end;
    v_loser_name:=case when v_a_won then v_b_name else v_a_name end;
    v_score:=case
      when t.category='Next Gen Finals' then public.nextgen_tournament_score(v_prob,v_a_won)
      else public.world_tournament_score(v_prob,v_a_won,3)
    end;

    insert into public.world_tournament_matches(
      tournament_id,round_no,round_code,group_name,match_no,
      player_a_id,player_b_id,winner_id,loser_id,score,best_of,
      player_a_win_probability,court_speed,model_version,matchup_components,simulated_on
    ) values(
      t.id,1,'RR',rr.group_name,v_match_no,
      v_a,v_b,v_winner,v_loser,v_score,case when t.category='Next Gen Finals' then 5 else 3 end,round(v_prob,4),
      coalesce(t.court_speed,case when coalesce(t.indoor,false) then 1.18 else 1.0 end),
      case when t.category='Next Gen Finals' then 'CB-NEXTGEN-v1-BO5-FIRST4' else 'CB-MATCH-v4-ROUNDROBIN' end,
      coalesce(v_match->'components','{}'::jsonb)
        ||jsonb_build_object('extended_attributes',coalesce(v_match->'extended_attributes','{}'::jsonb)),
      coalesce(p_simulated_on,t.end_date,t.start_date)
    );

    update cb_rr_entries
    set wins=wins+1,points_awarded=points_awarded+v_rr_points,
        last_opponent_id=v_loser,last_opponent_name=v_loser_name,
        last_score=case when v_winner=v_a then v_score else public.world_invert_tennis_score(v_score) end
    where player_id=v_winner;

    update cb_rr_entries
    set losses=losses+1,
        last_opponent_id=v_winner,last_opponent_name=v_winner_name,
        last_score=case when v_loser=v_a then v_score else public.world_invert_tennis_score(v_score) end
    where player_id=v_loser;
  end loop;

  drop table if exists pg_temp.cb_rr_qualifiers;
  create temporary table cb_rr_qualifiers(
    group_name text,
    group_pos integer,
    player_id bigint,
    name text,
    seed integer,
    primary key(group_name,group_pos)
  ) on commit drop;

  insert into cb_rr_qualifiers(group_name,group_pos,player_id,name,seed)
  select group_name,
         row_number() over(partition by group_name order by wins desc,seed asc)::int,
         player_id,name,seed
  from cb_rr_entries
  where true
  order by group_name,wins desc,seed
  limit 8;

  delete from cb_rr_qualifiers where group_pos>2;

  v_match_no:=0;
  for rr in
    select *
    from (
      select 1 ord,a.player_id a_id,a.name a_name,b.player_id b_id,b.name b_name
      from cb_rr_qualifiers a join cb_rr_qualifiers b
        on a.group_name='A' and a.group_pos=1 and b.group_name='B' and b.group_pos=2
      union all
      select 2 ord,a.player_id,a.name,b.player_id,b.name
      from cb_rr_qualifiers a join cb_rr_qualifiers b
        on a.group_name='B' and a.group_pos=1 and b.group_name='A' and b.group_pos=2
    ) s
    order by ord
  loop
    v_match_no:=v_match_no+1;
    v_a:=rr.a_id;v_b:=rr.b_id;v_a_name:=rr.a_name;v_b_name:=rr.b_name;
    v_match:=public.player_matchup_probability_v4(
      v_a,v_b,t.surface,coalesce(t.end_date,t.start_date),
      coalesce(t.court_speed,case when coalesce(t.indoor,false) then 1.18 else 1.0 end),3
    );
    v_prob:=greatest(.02,least(.98,coalesce((v_match->>'player_a_probability')::numeric,.5)));
    v_a_won:=random()<v_prob;
    v_winner:=case when v_a_won then v_a else v_b end;
    v_loser:=case when v_a_won then v_b else v_a end;
    v_winner_name:=case when v_a_won then v_a_name else v_b_name end;
    v_loser_name:=case when v_a_won then v_b_name else v_a_name end;
    v_score:=case
      when t.category='Next Gen Finals' then public.nextgen_tournament_score(v_prob,v_a_won)
      else public.world_tournament_score(v_prob,v_a_won,3)
    end;

    insert into public.world_tournament_matches(
      tournament_id,round_no,round_code,match_no,
      player_a_id,player_b_id,winner_id,loser_id,score,best_of,
      player_a_win_probability,court_speed,model_version,matchup_components,simulated_on
    ) values(
      t.id,2,'SF',v_match_no,v_a,v_b,v_winner,v_loser,v_score,case when t.category='Next Gen Finals' then 5 else 3 end,round(v_prob,4),
      coalesce(t.court_speed,case when coalesce(t.indoor,false) then 1.18 else 1.0 end),
      case when t.category='Next Gen Finals' then 'CB-NEXTGEN-v1-BO5-FIRST4' else 'CB-MATCH-v4-ROUNDROBIN' end,
      coalesce(v_match->'components','{}'::jsonb)
        ||jsonb_build_object('extended_attributes',coalesce(v_match->'extended_attributes','{}'::jsonb)),
      coalesce(p_simulated_on,t.end_date,t.start_date)
    );

    update cb_rr_entries
    set wins=wins+1,points_awarded=points_awarded+v_sf_points,
        last_opponent_id=v_loser,last_opponent_name=v_loser_name,
        last_score=case when v_winner=v_a then v_score else public.world_invert_tennis_score(v_score) end
    where player_id=v_winner;

    update cb_rr_entries
    set losses=losses+1,result_code='SF',result_label='Demi-finale',
        last_opponent_id=v_winner,last_opponent_name=v_winner_name,
        last_score=case when v_loser=v_a then v_score else public.world_invert_tennis_score(v_score) end
    where player_id=v_loser;
  end loop;

  select
    max(winner_id) filter(where match_no=1),
    max(winner_id) filter(where match_no=2)
  into v_a,v_b
  from public.world_tournament_matches
  where tournament_id=t.id and round_code='SF';

  select name into v_a_name from cb_rr_entries where player_id=v_a;
  select name into v_b_name from cb_rr_entries where player_id=v_b;

  v_match:=public.player_matchup_probability_v4(
    v_a,v_b,t.surface,coalesce(t.end_date,t.start_date),
    coalesce(t.court_speed,case when coalesce(t.indoor,false) then 1.18 else 1.0 end),3
  );
  v_prob:=greatest(.02,least(.98,coalesce((v_match->>'player_a_probability')::numeric,.5)));
  v_a_won:=random()<v_prob;
  v_champion:=case when v_a_won then v_a else v_b end;
  v_finalist:=case when v_a_won then v_b else v_a end;
  v_champion_name:=case when v_a_won then v_a_name else v_b_name end;
  v_finalist_name:=case when v_a_won then v_b_name else v_a_name end;
  v_score:=case
      when t.category='Next Gen Finals' then public.nextgen_tournament_score(v_prob,v_a_won)
      else public.world_tournament_score(v_prob,v_a_won,3)
    end;

  insert into public.world_tournament_matches(
    tournament_id,round_no,round_code,match_no,
    player_a_id,player_b_id,winner_id,loser_id,score,best_of,
    player_a_win_probability,court_speed,model_version,matchup_components,simulated_on
  ) values(
    t.id,3,'F',1,v_a,v_b,v_champion,v_finalist,v_score,case when t.category='Next Gen Finals' then 5 else 3 end,round(v_prob,4),
    coalesce(t.court_speed,case when coalesce(t.indoor,false) then 1.18 else 1.0 end),
    case when t.category='Next Gen Finals' then 'CB-NEXTGEN-v1-BO5-FIRST4' else 'CB-MATCH-v4-ROUNDROBIN' end,
    coalesce(v_match->'components','{}'::jsonb)
      ||jsonb_build_object('extended_attributes',coalesce(v_match->'extended_attributes','{}'::jsonb)),
    coalesce(p_simulated_on,t.end_date,t.start_date)
  );

  update cb_rr_entries
  set wins=wins+1,points_awarded=points_awarded+v_f_points,result_code='W',result_label='Vainqueur',
      last_opponent_id=v_finalist,last_opponent_name=v_finalist_name,
      last_score=case when v_champion=v_a then v_score else public.world_invert_tennis_score(v_score) end
  where player_id=v_champion;

  update cb_rr_entries
  set losses=losses+1,result_code='F',result_label='Finaliste',
      last_opponent_id=v_champion,last_opponent_name=v_champion_name,
      last_score=case when v_finalist=v_a then v_score else public.world_invert_tennis_score(v_score) end
  where player_id=v_finalist;

  update cb_rr_entries e
  set result_code='RR',result_label='Phase de groupes'
  where e.result_code='RR';

  select points_awarded into v_champion_points from cb_rr_entries where player_id=v_champion;
  select points_awarded into v_finalist_points from cb_rr_entries where player_id=v_finalist;

  insert into public.world_tournament_entries(
    tournament_id,player_id,seed,draw_slot,entry_method,ranking_at_entry,had_bye,
    matches_won,result_code,result_label,points_awarded,qualifying_points,
    last_opponent_id,last_opponent_name,last_score,simulated_on,source_label
  )
  select
    t.id,e.player_id,e.seed,e.seed,e.entry_method,
    case when t.category='ATP Finals' then p.race_ranking else p.nextgen_ranking end,
    false,e.wins,e.result_code,e.result_label,e.points_awarded,0,
    e.last_opponent_id,e.last_opponent_name,e.last_score,
    coalesce(p_simulated_on,t.end_date,t.start_date),
    'Court Boss round robin · '||r.rule_key
  from cb_rr_entries e
  join public.players p on p.id=e.player_id;

  if t.category='ATP Finals' then
    insert into public.world_ranking_points(
      player_id,tournament_id,label,earned_date,expiry_date,points,active,source_label
    )
    select
      e.player_id,t.id,t.name||' · '||e.result_code,
      coalesce(t.end_date,t.start_date),coalesce(t.end_date,t.start_date)+364,
      e.points_awarded,true,'Court Boss ATP Finals · wins-based scoring'
    from cb_rr_entries e
    where e.points_awarded>0
    on conflict(player_id,tournament_id) do update set
      label=excluded.label,earned_date=excluded.earned_date,expiry_date=excluded.expiry_date,
      points=excluded.points,active=true,source_label=excluded.source_label;
  end if;

  insert into public.player_tournament_history(
    player_id,season,tournament_id,tournament_name,tournament_date,level,category,surface,
    result_code,result_label,last_opponent,last_score,is_grand_slam,source,event_type
  )
  select
    e.player_id,extract(year from coalesce(t.end_date,t.start_date))::int,t.id::text,t.name,
    coalesce(t.end_date,t.start_date),coalesce(t.level,t.category,t.circuit),t.category,t.surface,
    e.result_code,e.result_label,e.last_opponent_name,e.last_score,false,
    'Court Boss round robin · '||r.rule_key,'singles'
  from cb_rr_entries e
  on conflict(player_id,event_type,tournament_id) do update set
    season=excluded.season,tournament_name=excluded.tournament_name,tournament_date=excluded.tournament_date,
    level=excluded.level,category=excluded.category,surface=excluded.surface,
    result_code=excluded.result_code,result_label=excluded.result_label,
    last_opponent=excluded.last_opponent,last_score=excluded.last_score,source=excluded.source;

  insert into public.player_titles(
    player_id,tournament_name,title_date,level,surface,event_type,verified,source_label,origin
  ) values(
    v_champion,t.name,coalesce(t.end_date,t.start_date),coalesce(t.category,t.level,t.circuit),
    t.surface,'singles',false,'Court Boss round robin · '||r.rule_key,'game'
  )
  on conflict(player_id,tournament_name,title_date,event_type) do update set
    source_label=excluded.source_label,origin=excluded.origin;

  insert into public.player_final_results(
    player_id,tournament_name,final_date,level,surface,result,opponent_name,source,event_type
  ) values
    (v_champion,t.name,coalesce(t.end_date,t.start_date),coalesce(t.category,t.level,t.circuit),t.surface,'Champion',v_finalist_name,'Court Boss round robin','singles'),
    (v_finalist,t.name,coalesce(t.end_date,t.start_date),coalesce(t.category,t.level,t.circuit),t.surface,'Finaliste',v_champion_name,'Court Boss round robin','singles')
  on conflict(player_id,tournament_name,final_date,result) do update set
    opponent_name=excluded.opponent_name,source=excluded.source,event_type=excluded.event_type;

  for mh in
    select winner_id,loser_id,round_code
    from public.world_tournament_matches
    where tournament_id=t.id and winner_id is not null and loser_id is not null
    order by round_no,match_no
  loop
    perform public.update_h2h_after_match(
      mh.winner_id,mh.loser_id,t.surface,coalesce(t.end_date,t.start_date),false,
      'Court Boss round robin · '||mh.round_code
    );
    perform public.update_player_elo_after_match(
      mh.winner_id,mh.loser_id,t.surface,coalesce(t.end_date,t.start_date),false,
      case when mh.round_code='F' then 1.15 when mh.round_code='SF' then 1.08 else 1.02 end
    );
  end loop;

  update public.players p
  set form=greatest(35,least(100,p.form+
        case e.result_code when 'W' then 4 when 'F' then 3 when 'SF' then 2 else 0 end
      )),
      morale=greatest(30,least(100,p.morale+
        case e.result_code when 'W' then 5 when 'F' then 3 when 'SF' then 2 else 0 end
      ))
  from cb_rr_entries e
  where p.id=e.player_id;

  update public.player_dynamic_ratings d
  set overall_elo=e.overall_elo,hard_elo=e.hard_elo,clay_elo=e.clay_elo,grass_elo=e.grass_elo,
      rating_confidence=greatest(d.rating_confidence,e.confidence),
      last_competitive_match=coalesce(t.end_date,t.start_date),
      source_label='Court Boss live hybrid Elo · round robin finals',updated_at=now()
  from public.player_elo_ratings e
  where e.player_id=d.player_id and d.player_id in (select player_id from cb_rr_entries);

  select
    case when wm.winner_id=wm.player_a_id then wm.player_a_win_probability else 1-wm.player_a_win_probability end,
    wm.matchup_components
  into v_final_prob,v_final_components
  from public.world_tournament_matches wm
  where wm.tournament_id=t.id and wm.round_code='F'
  limit 1;

  insert into public.world_tournament_simulations(
    tournament_id,winner_id,finalist_id,winner_points,finalist_points,simulated_on,
    final_win_probability,court_speed,model_version,matchup_components,
    rule_key,draw_size,bracket_size,rounds_count,matches_simulated,participants_simulated,format_type
  ) values(
    t.id,v_champion,v_finalist,v_champion_points,v_finalist_points,
    coalesce(p_simulated_on,t.end_date,t.start_date),round(coalesce(v_final_prob,.5),4),
    coalesce(t.court_speed,case when coalesce(t.indoor,false) then 1.18 else 1.0 end),
    case when t.category='Next Gen Finals' then 'CB-NEXTGEN-v1-BO5-FIRST4' else 'CB-MATCH-v4-ROUNDROBIN' end,coalesce(v_final_components,'{}'::jsonb),
    r.rule_key,8,8,3,15,8,'round_robin'
  );

  return jsonb_build_object(
    'ok',true,'tournament_id',t.id,'name',t.name,'rule_key',r.rule_key,
    'format','round_robin','participants',8,'matches',15,
    'champion_id',v_champion,'champion',v_champion_name,
    'finalist_id',v_finalist,'finalist',v_finalist_name,
    'winner_points',v_champion_points,'finalist_points',v_finalist_points
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.apply_world_recovery_week(p_date date, p_week integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  v_count int:=0;
begin
  with active_ids as (
    select player_a_id player_id
    from public.world_tournament_matches
    where simulated_on between p_date-13 and p_date
    union
    select player_b_id
    from public.world_tournament_matches
    where simulated_on between p_date-13 and p_date

    union
    select wp.player_a_id
    from public.world_doubles_tournament_matches m
    join public.world_doubles_partnerships wp on wp.id=m.pair_a_id
    where m.simulated_on between p_date-13 and p_date
    union
    select wp.player_b_id
    from public.world_doubles_tournament_matches m
    join public.world_doubles_partnerships wp on wp.id=m.pair_a_id
    where m.simulated_on between p_date-13 and p_date
    union
    select wp.player_a_id
    from public.world_doubles_tournament_matches m
    join public.world_doubles_partnerships wp on wp.id=m.pair_b_id
    where m.simulated_on between p_date-13 and p_date
    union
    select wp.player_b_id
    from public.world_doubles_tournament_matches m
    join public.world_doubles_partnerships wp on wp.id=m.pair_b_id
    where m.simulated_on between p_date-13 and p_date

    union
    select e.player_a_id
    from public.world_junior_doubles_matches m
    join public.world_junior_doubles_entries e on e.id=m.pair_a_entry_id
    where m.simulated_on between p_date-13 and p_date
    union
    select e.player_b_id
    from public.world_junior_doubles_matches m
    join public.world_junior_doubles_entries e on e.id=m.pair_a_entry_id
    where m.simulated_on between p_date-13 and p_date
    union
    select e.player_a_id
    from public.world_junior_doubles_matches m
    join public.world_junior_doubles_entries e on e.id=m.pair_b_entry_id
    where m.simulated_on between p_date-13 and p_date
    union
    select e.player_b_id
    from public.world_junior_doubles_matches m
    join public.world_junior_doubles_entries e on e.id=m.pair_b_entry_id
    where m.simulated_on between p_date-13 and p_date

    union
    select unnest(coalesce(r.home_player_ids,'{}'::bigint[]))
    from public.davis_rubbers r
    join public.davis_ties t on t.id=r.tie_id
    where t.tie_date between p_date-13 and p_date
    union
    select unnest(coalesce(r.away_player_ids,'{}'::bigint[]))
    from public.davis_rubbers r
    join public.davis_ties t on t.id=r.tie_id
    where t.tie_date between p_date-13 and p_date

    union
    select unnest(r.home_player_ids)
    from public.college_dual_rubbers r
    join public.college_duals d on d.id=r.dual_id
    where d.match_date between p_date-13 and p_date and r.status='completed'
    union
    select unnest(r.away_player_ids)
    from public.college_dual_rubbers r
    join public.college_duals d on d.id=r.dual_id
    where d.match_date between p_date-13 and p_date and r.status='completed'

    union
    select unnest(m.side_a_player_ids)
    from public.ncaa_individual_matches m
    where m.played_on between p_date-13 and p_date
    union
    select unnest(m.side_b_player_ids)
    from public.ncaa_individual_matches m
    where m.played_on between p_date-13 and p_date
  ),
  candidates as (
    select
      p.id,
      coalesce(p.fatigue,20) fatigue,
      coalesce(p.fitness,90) fitness,
      coalesce(p.age,24) age,
      coalesce(pa.recovery,10) recovery,
      coalesce(pa.natural_fitness,10) natural_fitness,
      public.player_recent_match_load(p.id,p_date) recent_matches,
      p.injury_status
    from public.players p
    left join public.player_attributes pa on pa.player_id=p.id
    where p.career_status='active'
      and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
      and (
        p.ranking_current=true
        or p.doubles_ranking is not null
        or p.junior_ranking is not null
        or p.itf_ranking is not null
        or p.ncaa_current=true
      )
      and (
        coalesce(p.fatigue,20)>20
        or coalesce(p.injury_status,'Fit')<>'Fit'
        or exists(select 1 from active_ids a where a.player_id=p.id)
      )
      and not exists(
        select 1
        from public.player_training_load_profiles ail
        where ail.player_id=p.id
          and ail.source_label='Court Boss · world AI intraday V30'
          and ail.last_match_date between p_date-13 and p_date
      )
  ),
  calc as (
    select c.*,
      greatest(3,least(16,round(
        8
        +(c.recovery-10)*.45
        +(c.natural_fitness-10)*.30
        +case
          when c.recent_matches=0 then 4
          when c.recent_matches=1 then 2
          when c.recent_matches=2 then 1
          when c.recent_matches>=6 then -4
          when c.recent_matches>=4 then -2
          else 0 end
        -greatest(0,c.age-31)*.25
        +case when c.injury_status<>'Fit' then 2 else 0 end
      )::int)) recovery_points
    from candidates c
  )
  update public.players p
  set fatigue=greatest(
        8,
        coalesce(p.fatigue,20)-c.recovery_points
      ),
      fitness=case
        when coalesce(p.injury_status,'Fit')='Fit'
          then least(100,coalesce(p.fitness,90)+
            case
              when c.recent_matches=0 then 3
              when c.recent_matches<=2 then 2
              else 1 end
          )
        else coalesce(p.fitness,90)
      end
  from calc c
  where p.id=c.id;

  get diagnostics v_count=row_count;

  return jsonb_build_object(
    'updated_players',v_count,
    'date',p_date,
    'model','activity-aware recovery · recent matches + recovery + natural fitness + age'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.apply_world_recovery_week_v24(p_date date, p_week integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_snapshot jsonb:='[]'::jsonb;
  v_world jsonb;
  v_ai_recovery jsonb:='{}'::jsonb;
  v_row jsonb;
  v_restored int:=0;
begin
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',p.id,'fatigue',p.fatigue,'fitness',p.fitness,'form',p.form,'morale',p.morale,'injury_status',p.injury_status
  )),'[]'::jsonb)
  into v_snapshot
  from public.players p
  where p.id in (
    select managed_player_id from public.career_state where id='demo' and managed_player_id is not null
    union
    select player_id from public.academy_roster where status='active' and player_id is not null and source_youth_id is null
  );

  v_world:=public.apply_world_recovery_week(p_date,p_week);
  v_ai_recovery:=public.apply_world_ai_checkpoint_recovery_v30(p_date);

  for v_row in select value from jsonb_array_elements(v_snapshot)
  loop
    update public.players
    set fatigue=nullif(v_row->>'fatigue','')::int,
        fitness=nullif(v_row->>'fitness','')::int,
        form=nullif(v_row->>'form','')::int,
        morale=nullif(v_row->>'morale','')::int,
        injury_status=coalesce(v_row->>'injury_status','Fit')
    where id=(v_row->>'id')::bigint;
    v_restored:=v_restored+1;
  end loop;

  return coalesce(v_world,'{}'::jsonb)||jsonb_build_object(
    'managed_players_restored',v_restored,
    'managed_recovery_owner','CB-DAILY-RECOVERY-v24',
    'ai_intraday_recovery',v_ai_recovery,
    'ai_recovery_owner','CB-WORLD-AI-CHECKPOINT-RECOVERY-v30'
  );
end
$function$;

drop trigger if exists world_ai_intraday_singles_v30 on public.world_tournament_matches;
create trigger world_ai_intraday_singles_v30
after insert or update of winner_id on public.world_tournament_matches
for each row execute function public.world_ai_intraday_singles_trigger_v30();

drop trigger if exists world_ai_intraday_doubles_v30 on public.world_doubles_tournament_matches;
create trigger world_ai_intraday_doubles_v30
after insert or update of winner_pair_id on public.world_doubles_tournament_matches
for each row execute function public.world_ai_intraday_doubles_trigger_v30();

revoke execute on function public.world_ai_is_managed_v30(bigint) from public,anon,authenticated;
revoke execute on function public.world_ai_match_duration_v30(text,integer,text,text) from public,anon,authenticated;
revoke execute on function public.world_ai_effective_match_date_v30(bigint,integer,text,integer,text,text,boolean,date) from public,anon,authenticated;
revoke execute on function public.world_ai_shared_schedule_v30(bigint,date,text,text,text,bigint,bigint[]) from public,anon,authenticated;
revoke execute on function public.apply_world_ai_player_match_v30(bigint,bigint,date,integer,integer,text,text) from public,anon,authenticated;
revoke execute on function public.apply_world_ai_checkpoint_recovery_v30(date) from public,anon,authenticated;
revoke execute on function public.world_ai_intraday_singles_trigger_v30() from public,anon,authenticated;
revoke execute on function public.world_ai_intraday_doubles_trigger_v30() from public,anon,authenticated;

grant execute on function public.world_ai_is_managed_v30(bigint) to service_role;
grant execute on function public.world_ai_match_duration_v30(text,integer,text,text) to service_role;
grant execute on function public.world_ai_effective_match_date_v30(bigint,integer,text,integer,text,text,boolean,date) to service_role;
grant execute on function public.world_ai_shared_schedule_v30(bigint,date,text,text,text,bigint,bigint[]) to service_role;
grant execute on function public.apply_world_ai_player_match_v30(bigint,bigint,date,integer,integer,text,text) to service_role;
grant execute on function public.apply_world_ai_checkpoint_recovery_v30(date) to service_role;
