-- Court Boss audit reliability v31. Applied live first; this file keeps future migration replay deterministic.
create schema if not exists court_boss_private;
revoke all on schema court_boss_private from public,anon,authenticated;

create table if not exists court_boss_private.settings(key text primary key,value text not null,updated_at timestamptz not null default now());
revoke all on court_boss_private.settings from public,anon,authenticated;
insert into court_boss_private.settings(key,value)
values('write_access_sha256','fe4739a8a86967cd1c1a857675989f78e25822b2984b929b982e38d9dfbeaac3')
on conflict(key) do nothing;

create table if not exists court_boss_private.operation_lock(singleton boolean primary key default true check(singleton),token uuid,expires_at timestamptz);
insert into court_boss_private.operation_lock(singleton) values(true) on conflict do nothing;
revoke all on court_boss_private.operation_lock from public,anon,authenticated;

create or replace function public.cb_write_access_digest_v31() returns text language sql stable security definer set search_path='' as $$select value from court_boss_private.settings where key='write_access_sha256'$$;
revoke all on function public.cb_write_access_digest_v31() from public,anon,authenticated; grant execute on function public.cb_write_access_digest_v31() to service_role;
create or replace function public.cb_acquire_write_lock_v31() returns uuid language plpgsql security definer set search_path='' as $$declare v uuid:=gen_random_uuid(); current_token uuid; current_exp timestamptz; begin perform pg_advisory_xact_lock(731031); select token,expires_at into current_token,current_exp from court_boss_private.operation_lock where singleton=true for update; if current_token is not null and current_exp>now() then raise exception 'Court Boss write busy' using errcode='55P03'; end if; update court_boss_private.operation_lock set token=v,expires_at=now()+interval '3 minutes' where singleton=true; return v; end$$;
revoke all on function public.cb_acquire_write_lock_v31() from public,anon,authenticated; grant execute on function public.cb_acquire_write_lock_v31() to service_role;
create or replace function public.cb_touch_write_lock_v31(p_token uuid) returns boolean language sql security definer set search_path='' as $$update court_boss_private.operation_lock set expires_at=now()+interval '3 minutes' where singleton=true and token=p_token returning true$$;
revoke all on function public.cb_touch_write_lock_v31(uuid) from public,anon,authenticated; grant execute on function public.cb_touch_write_lock_v31(uuid) to service_role;
create or replace function public.cb_release_write_lock_v31(p_token uuid) returns boolean language sql security definer set search_path='' as $$update court_boss_private.operation_lock set token=null,expires_at=null where singleton=true and token=p_token returning true$$;
revoke all on function public.cb_release_write_lock_v31(uuid) from public,anon,authenticated; grant execute on function public.cb_release_write_lock_v31(uuid) to service_role;
create or replace function public.cb_attr100_v31(value numeric) returns numeric language sql immutable parallel safe set search_path='' as $$select greatest(5::numeric,least(100::numeric,coalesce(value,10::numeric)*5::numeric))$$;
revoke all on function public.cb_attr100_v31(numeric) from public,anon,authenticated; grant execute on function public.cb_attr100_v31(numeric) to service_role;

-- Canonical current definitions are deliberately last so legacy replay cannot overwrite recovery, intraday or boxscore logic.
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
  v_story_date date;
  v_legacy_news jsonb:=jsonb_build_object('published',0);
  v_week int;
begin
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
    v_story_date:=coalesce(
      p_expected_from_date,
      nullif(v_result->>'from_date','')::date,
      v_result_date-1
    );

    v_legacy_news:=public.court_boss_publish_daily_legacy_rank_moves(v_story_date);
    v_result:=v_result||jsonb_build_object('legacy_news',v_legacy_news);

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

CREATE OR REPLACE FUNCTION public.cb_record_world_match_stat_lines(p_match_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  w public.world_tournament_matches%rowtype;
  t public.tournaments%rowtype;
  a public.player_attributes%rowtype;
  b public.player_attributes%rowtype;
  pa public.players%rowtype;
  pb public.players%rowtype;
  ss jsonb;
  v_games integer;
  v_points integer;
  v_a_sp integer;
  v_b_sp integer;
  v_a_spw integer;
  v_b_spw integer;
  v_a_fs integer;
  v_b_fs integer;
  v_a_fsin integer;
  v_b_fsin integer;
  v_a_aces integer;
  v_b_aces integer;
  v_a_df integer;
  v_b_df integer;
  v_speed numeric;
  v_a_srv numeric;
  v_b_srv numeric;
  v_a_ret numeric;
  v_b_ret numeric;
  v_a_pct numeric;
  v_b_pct numeric;
  v_a_ace_rate numeric;
  v_b_ace_rate numeric;
  v_a_df_rate numeric;
  v_b_df_rate numeric;
  v_noise_a numeric;
  v_noise_b numeric;
  v_date date;
begin
  select * into w from public.world_tournament_matches where id=p_match_id;
  if w.id is null or w.winner_id is null or w.player_a_id is null or w.player_b_id is null then
    return jsonb_build_object('ok',false,'reason','match_not_completed');
  end if;

  if coalesce(w.matchup_components->>'source','')='managed_live'
     or nullif(w.matchup_components->>'live_session_id','') is not null then
    return jsonb_build_object('ok',true,'skipped','managed_live');
  end if;

  select * into t from public.tournaments where id=w.tournament_id;
  select * into a from public.player_attributes where player_id=w.player_a_id;
  select * into b from public.player_attributes where player_id=w.player_b_id;
  select * into pa from public.players where id=w.player_a_id;
  select * into pb from public.players where id=w.player_b_id;

  ss:=public.cb_score_summary(w.score);
  v_games:=greatest(coalesce((ss->>'games')::int,0),16);
  v_points:=greatest(72,round(v_games*6.2)::int);
  v_noise_a:=(abs(mod(hashtextextended('sp-a:'||w.id::text,0),11))-5)::numeric;
  v_noise_b:=(abs(mod(hashtextextended('sp-b:'||w.id::text,0),11))-5)::numeric;
  v_a_sp:=greatest(25,round(v_points/2.0+v_noise_a)::int);
  v_b_sp:=greatest(25,v_points-v_a_sp);

  v_speed:=coalesce(w.court_speed,t.court_speed,1.0);
  v_a_srv:=(public.cb_attr100_v31(a.serve_power)+public.cb_attr100_v31(a.first_serve_quality)+public.cb_attr100_v31(a.serve_precision)+public.cb_attr100_v31(a.serve_consistency))/4.0;
  v_b_srv:=(public.cb_attr100_v31(b.serve_power)+public.cb_attr100_v31(b.first_serve_quality)+public.cb_attr100_v31(b.serve_precision)+public.cb_attr100_v31(b.serve_consistency))/4.0;
  v_a_ret:=(public.cb_attr100_v31(a.return_game)+public.cb_attr100_v31(a.return_consistency)+public.cb_attr100_v31(a.return_aggression)+public.cb_attr100_v31(a.anticipation))/4.0;
  v_b_ret:=(public.cb_attr100_v31(b.return_game)+public.cb_attr100_v31(b.return_consistency)+public.cb_attr100_v31(b.return_aggression)+public.cb_attr100_v31(b.anticipation))/4.0;

  v_a_pct:=greatest(.46,least(.86,.61+(v_a_srv-50)*.0021-(v_b_ret-50)*.0015+(v_speed-1)*.045
    +case when w.winner_id=w.player_a_id then .018 else -.012 end
    +(abs(mod(hashtextextended('srv-a:'||w.id::text,1),101))-50)/10000.0));
  v_b_pct:=greatest(.46,least(.86,.61+(v_b_srv-50)*.0021-(v_a_ret-50)*.0015+(v_speed-1)*.045
    +case when w.winner_id=w.player_b_id then .018 else -.012 end
    +(abs(mod(hashtextextended('srv-b:'||w.id::text,1),101))-50)/10000.0));

  v_a_spw:=greatest(0,least(v_a_sp,round(v_a_sp*v_a_pct)::int));
  v_b_spw:=greatest(0,least(v_b_sp,round(v_b_sp*v_b_pct)::int));

  v_a_fs:=v_a_sp;
  v_b_fs:=v_b_sp;
  v_a_fsin:=round(v_a_fs*greatest(.48,least(.78,.61+(public.cb_attr100_v31(a.serve_precision)-50)*.0022+(public.cb_attr100_v31(a.serve_consistency)-50)*.0013)))::int;
  v_b_fsin:=round(v_b_fs*greatest(.48,least(.78,.61+(public.cb_attr100_v31(b.serve_precision)-50)*.0022+(public.cb_attr100_v31(b.serve_consistency)-50)*.0013)))::int;

  v_a_ace_rate:=greatest(.004,least(.24,.035+(public.cb_attr100_v31(a.serve_power)-50)*.0015+(public.cb_attr100_v31(a.first_serve_quality)-50)*.0008
    +(v_speed-1)*.08-(public.cb_attr100_v31(b.return_game)-50)*.00035));
  v_b_ace_rate:=greatest(.004,least(.24,.035+(public.cb_attr100_v31(b.serve_power)-50)*.0015+(public.cb_attr100_v31(b.first_serve_quality)-50)*.0008
    +(v_speed-1)*.08-(public.cb_attr100_v31(a.return_game)-50)*.00035));
  v_a_df_rate:=greatest(.012,least(.115,.052-(public.cb_attr100_v31(a.second_serve_quality)-50)*.00065-(public.cb_attr100_v31(a.serve_consistency)-50)*.00045));
  v_b_df_rate:=greatest(.012,least(.115,.052-(public.cb_attr100_v31(b.second_serve_quality)-50)*.00065-(public.cb_attr100_v31(b.serve_consistency)-50)*.00045));

  v_a_aces:=greatest(0,round(v_a_sp*v_a_ace_rate+(abs(mod(hashtextextended('ace-a:'||w.id::text,2),5))-2))::int);
  v_b_aces:=greatest(0,round(v_b_sp*v_b_ace_rate+(abs(mod(hashtextextended('ace-b:'||w.id::text,2),5))-2))::int);
  v_a_df:=greatest(0,round(v_a_sp*v_a_df_rate+(abs(mod(hashtextextended('df-a:'||w.id::text,3),3))-1))::int);
  v_b_df:=greatest(0,round(v_b_sp*v_b_df_rate+(abs(mod(hashtextextended('df-b:'||w.id::text,3),3))-1))::int);

  v_date:=coalesce(w.simulated_on,t.end_date,t.start_date,current_date);

  insert into public.court_boss_match_stat_lines(
    source_kind,source_id,world_match_id,tournament_id,player_id,opponent_id,match_date,season,
    surface,category,round_code,score,won,opponent_rank,
    service_points,service_points_won,first_serves,first_serves_in,aces,double_faults,
    return_points,return_points_won,tiebreaks_played,tiebreaks_won,model_version,metadata
  )
  values
  ('world',w.id,w.id,w.tournament_id,w.player_a_id,w.player_b_id,v_date,extract(year from v_date)::int,
   coalesce(t.surface,'Dur'),coalesce(t.category,t.level),w.round_code,w.score,w.winner_id=w.player_a_id,pb.ranking,
   v_a_sp,v_a_spw,v_a_fs,v_a_fsin,v_a_aces,v_a_df,
   v_b_sp,v_b_sp-v_b_spw,coalesce((ss->>'tiebreaks')::int,0),coalesce((ss->>'a_tiebreaks_won')::int,0),
   'CB-WORLD-BOXSCORE-v2-scale20',jsonb_build_object('derived_from','attributes+score','court_speed',v_speed)),
  ('world',w.id,w.id,w.tournament_id,w.player_b_id,w.player_a_id,v_date,extract(year from v_date)::int,
   coalesce(t.surface,'Dur'),coalesce(t.category,t.level),w.round_code,public.world_invert_tennis_score(coalesce(w.score,'')),w.winner_id=w.player_b_id,pa.ranking,
   v_b_sp,v_b_spw,v_b_fs,v_b_fsin,v_b_aces,v_b_df,
   v_a_sp,v_a_sp-v_a_spw,coalesce((ss->>'tiebreaks')::int,0),coalesce((ss->>'b_tiebreaks_won')::int,0),
   'CB-WORLD-BOXSCORE-v2-scale20',jsonb_build_object('derived_from','attributes+score','court_speed',v_speed))
  on conflict(source_kind,source_id,player_id) do update set
    match_date=excluded.match_date,season=excluded.season,surface=excluded.surface,category=excluded.category,
    round_code=excluded.round_code,score=excluded.score,won=excluded.won,opponent_rank=excluded.opponent_rank,
    service_points=excluded.service_points,service_points_won=excluded.service_points_won,
    first_serves=excluded.first_serves,first_serves_in=excluded.first_serves_in,
    aces=excluded.aces,double_faults=excluded.double_faults,return_points=excluded.return_points,
    return_points_won=excluded.return_points_won,tiebreaks_played=excluded.tiebreaks_played,
    tiebreaks_won=excluded.tiebreaks_won,model_version=excluded.model_version,
    metadata=excluded.metadata,updated_at=now();

  return jsonb_build_object('ok',true,'match_id',w.id,'players',2,'model','CB-WORLD-BOXSCORE-v2-scale20');
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

CREATE OR REPLACE FUNCTION public.managed_post_match_recovery_context_v23(p_date date, p_player_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
