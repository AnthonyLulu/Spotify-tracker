
alter table public.player_training_load_profiles
  add column if not exists current_country text,
  add column if not exists last_match_date date,
  add column if not exists last_match_session_id bigint,
  add column if not exists last_match_minutes integer,
  add column if not exists last_match_load numeric not null default 0,
  add column if not exists post_match_recovery_debt numeric not null default 0,
  add column if not exists travel_recovery_debt numeric not null default 0,
  add column if not exists last_recovery_date date,
  add column if not exists last_travel_date date,
  add column if not exists last_travel_from text,
  add column if not exists last_travel_to text,
  add column if not exists last_match_heat_load numeric not null default 0,
  add column if not exists last_match_wind_load numeric not null default 0;

create or replace function public.country_region_v24(p_country text)
returns text
language sql
immutable
set search_path to ''
as $function$
  select case upper(coalesce(p_country,''))
    when 'FRA' then 'EUR' when 'ESP' then 'EUR' when 'ITA' then 'EUR' when 'GBR' then 'EUR'
    when 'GER' then 'EUR' when 'AUT' then 'EUR' when 'SUI' then 'EUR' when 'BEL' then 'EUR'
    when 'NED' then 'EUR' when 'POR' then 'EUR' when 'SWE' then 'EUR' when 'NOR' then 'EUR'
    when 'DEN' then 'EUR' when 'FIN' then 'EUR' when 'POL' then 'EUR' when 'CZE' then 'EUR'
    when 'SVK' then 'EUR' when 'HUN' then 'EUR' when 'ROU' then 'EUR' when 'BUL' then 'EUR'
    when 'CRO' then 'EUR' when 'SRB' then 'EUR' when 'SLO' then 'EUR' when 'GRE' then 'EUR'
    when 'TUR' then 'EUR' when 'IRL' then 'EUR' when 'LAT' then 'EUR' when 'LTU' then 'EUR'
    when 'EST' then 'EUR' when 'UKR' then 'EUR' when 'RUS' then 'EUR' when 'MON' then 'EUR'
    when 'USA' then 'NAM' when 'CAN' then 'NAM' when 'MEX' then 'NAM' when 'CRC' then 'NAM'
    when 'DOM' then 'NAM' when 'BAH' then 'NAM' when 'PUR' then 'NAM'
    when 'ARG' then 'SAM' when 'BRA' then 'SAM' when 'CHI' then 'SAM' when 'COL' then 'SAM'
    when 'PER' then 'SAM' when 'URU' then 'SAM' when 'ECU' then 'SAM'
    when 'AUS' then 'APAC' when 'NZL' then 'APAC' when 'JPN' then 'APAC' when 'KOR' then 'APAC'
    when 'CHN' then 'APAC' when 'IND' then 'APAC' when 'THA' then 'APAC' when 'SGP' then 'APAC'
    when 'MAS' then 'APAC' when 'INA' then 'APAC' when 'PHI' then 'APAC' when 'NEP' then 'APAC'
    when 'UAE' then 'MEA' when 'QAT' then 'MEA' when 'KSA' then 'MEA' when 'BRN' then 'MEA'
    when 'ISR' then 'MEA' when 'EGY' then 'MEA' when 'MAR' then 'MEA' when 'TUN' then 'MEA'
    when 'ZAF' then 'MEA' when 'TOG' then 'MEA' when 'REU' then 'MEA'
    else 'OTHER' end
$function$;

create or replace function public.seed_live_match_recovery_v24(
  p_session_id bigint,
  p_player_id bigint,
  p_effect text,
  p_match_date date,
  p_tournament_id bigint,
  p_metrics jsonb default '{}'::jsonb,
  p_role_multiplier numeric default 1
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_existing jsonb;
  v_player public.players%rowtype;
  v_country text;
  v_home text;
  v_minutes int:=greatest(30,least(360,coalesce(nullif(p_metrics->>'duration_minutes','')::int,90)));
  v_fatigue_add numeric:=greatest(0,coalesce(nullif(p_metrics->>'fatigue_added','')::numeric,8));
  v_heat numeric:=greatest(0,coalesce(nullif(p_metrics->>'heat_load','')::numeric,0));
  v_wind numeric:=greatest(0,coalesce(nullif(p_metrics->>'wind_load','')::numeric,0));
  v_mult numeric:=greatest(.5,least(1.2,coalesce(p_role_multiplier,1)));
  v_load numeric;
  v_payload jsonb;
begin
  if p_session_id is null or p_player_id is null or coalesce(p_effect,'')='' then
    raise exception 'recovery seed payload incomplete';
  end if;

  perform 1 from public.live_match_sessions where id=p_session_id for update;
  if not found then raise exception 'live session % not found',p_session_id; end if;

  select payload into v_existing
  from public.live_match_effect_commits_v23
  where session_id=p_session_id and effect=p_effect;

  if v_existing is not null then
    return v_existing||jsonb_build_object('ok',true,'already_applied',true,'model','CB-RECOVERY-v24');
  end if;

  select * into v_player from public.players where id=p_player_id;
  if not found then raise exception 'recovery player % not found',p_player_id; end if;
  v_home:=v_player.country;

  if coalesce(p_tournament_id,0)>0 then
    select country into v_country from public.tournaments where id=p_tournament_id;
  end if;
  v_country:=coalesce(v_country,v_home);

  v_load:=round(greatest(4,least(30,
    (v_fatigue_add*1.05 + v_minutes/42.0 + v_heat*.60 + v_wind*.35)*v_mult
  ))::numeric,2);

  insert into public.player_training_load_profiles(
    player_id,as_of_date,phase,intensity,technical_share,tactical_share,physical_share,mental_share,
    recovery_share,recovery_days,injury_load_modifier,development_modifier,reason,source_label,
    current_country,last_match_date,last_match_session_id,last_match_minutes,last_match_load,
    post_match_recovery_debt,last_match_heat_load,last_match_wind_load,updated_at
  )
  values(
    p_player_id,coalesce(p_match_date,current_date),'post_match',10,20,20,20,20,20,1,1,1,
    'Charge post-match live','Court Boss · post-match recovery V24',
    v_country,coalesce(p_match_date,current_date),p_session_id,v_minutes,v_load,
    v_load,v_heat,v_wind,now()
  )
  on conflict(player_id) do update set
    as_of_date=excluded.as_of_date,
    phase='post_match',
    reason='Charge post-match live',
    source_label='Court Boss · post-match recovery V24',
    current_country=coalesce(excluded.current_country,public.player_training_load_profiles.current_country),
    last_match_date=excluded.last_match_date,
    last_match_session_id=excluded.last_match_session_id,
    last_match_minutes=excluded.last_match_minutes,
    last_match_load=excluded.last_match_load,
    post_match_recovery_debt=least(60,coalesce(public.player_training_load_profiles.post_match_recovery_debt,0)+excluded.post_match_recovery_debt),
    last_match_heat_load=excluded.last_match_heat_load,
    last_match_wind_load=excluded.last_match_wind_load,
    updated_at=now();

  v_payload:=jsonb_build_object(
    'ok',true,'already_applied',false,'player_id',p_player_id,'match_date',coalesce(p_match_date,current_date),
    'duration_minutes',v_minutes,'fatigue_added',v_fatigue_add,'recovery_load',v_load,
    'heat_load',v_heat,'wind_load',v_wind,'country',v_country,'role_multiplier',v_mult,
    'model','CB-RECOVERY-v24'
  );

  insert into public.live_match_effect_commits_v23(session_id,effect,payload)
  values(p_session_id,p_effect,v_payload);

  return v_payload;
end
$function$;

revoke all on function public.seed_live_match_recovery_v24(bigint,bigint,text,date,bigint,jsonb,numeric) from public,anon,authenticated;
grant execute on function public.seed_live_match_recovery_v24(bigint,bigint,text,date,bigint,jsonb,numeric) to service_role;

create or replace function public.apply_managed_recovery_day_v24(p_date date, p_player_id bigint)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
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
  v_restrict boolean:=false;
  v_recommendation text:='Normal';
  v_week int:=1;
  v_result jsonb;
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
      'fatigue',v_player.fatigue,'fitness',v_player.fitness,'model','CB-DAILY-RECOVERY-v24'
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
    coalesce(max(sp.medical_rating*coalesce(public.staff_effectiveness_multiplier(sp.id),1)),10),
    coalesce(max(sp.fitness_rating*coalesce(public.staff_effectiveness_multiplier(sp.id),1)),10)
  into v_medical,v_fitness_staff
  from public.player_staff_assignments psa
  join public.staff_profiles sp on sp.id=psa.staff_profile_id
  where psa.player_id=p_player_id and psa.active=true and sp.active=true;

  if coalesce(v_medical,0)<=0 or coalesce(v_fitness_staff,0)<=0 then
    select
      coalesce(max(sp.medical_rating*coalesce(public.staff_effectiveness_multiplier(sp.id),1)),10),
      coalesce(max(sp.fitness_rating*coalesce(public.staff_effectiveness_multiplier(sp.id),1)),10)
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

  select q.country into v_target_country
  from (
    select t.country,coalesce(t.qualifying_start_date,t.main_draw_start_date,t.start_date) event_start
    from public.entries e join public.tournaments t on t.id=e.tournament_id
    where e.player_id=p_player_id
      and coalesce(e.status,'entered') in ('entered','accepted','main','qualifying','alternate')
      and t.end_date>=v_date
      and coalesce(t.qualifying_start_date,t.main_draw_start_date,t.start_date)<=v_date+2
    union all
    select t.country,coalesce(t.main_draw_start_date,t.start_date)
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
     and v_load.last_match_date<=v_date-2
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
  )::int));

  v_fitness_delta:=case
    when coalesce(v_player.injury_status,'Fit')<>'Fit' then 0
    when v_recovery_points>=5 then 2
    else 1 end
    -case when v_travel_load>=6 then 2 when v_travel_load>=3 then 1 else 0 end;

  v_fatigue_after:=greatest(0,least(100,
    v_fatigue_before+round(v_travel_load)::int-v_recovery_points
  ));
  v_fitness_after:=greatest(25,least(100,v_fitness_before+v_fitness_delta));

  v_post_debt_after:=greatest(0,v_post_debt_before-v_recovery_points*.90-1);
  v_travel_debt_after:=greatest(0,v_travel_debt_before+v_travel_load-v_recovery_points*.55);

  select * into v_injury
  from public.injuries
  where player_id=p_player_id and lower(coalesce(status,''))='active'
  order by started_at desc,id desc limit 1;

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
      last_recovery_date=v_date,
      last_travel_date=case when v_travel_load>0 then v_date else last_travel_date end,
      last_travel_from=case when v_travel_load>0 then v_from_country else last_travel_from end,
      last_travel_to=case when v_travel_load>0 then v_target_country else last_travel_to end,
      phase=case when v_restrict then 'medical_recovery' when v_post_debt_after>=10 then 'post_match' when v_travel_debt_after>=5 then 'travel_recovery' else phase end,
      reason=case when v_travel_load>0 then 'Voyage '||coalesce(v_from_country,'?')||' → '||coalesce(v_target_country,'?')
                  when v_restrict then 'Récupération médicale'
                  when v_post_debt_after>0 then 'Récupération post-match'
                  else reason end,
      source_label='Court Boss · daily recovery V24',
      updated_at=now()
  where player_id=p_player_id;

  v_recommendation:=case
    when v_restrict then 'Repos médical'
    when v_fatigue_after>=72 or v_post_debt_after>=16 then 'Repos'
    when v_fatigue_after>=52 or v_post_debt_after>=8 or v_travel_debt_after>=5 then 'Récupération'
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
    'staff_medical_rating',round(v_medical,1),'staff_fitness_rating',round(v_fitness_staff,1),
    'recovery_attribute',v_recovery_attr,'natural_fitness',v_natural,'protocol',v_protocol,
    'medical_training_restriction',v_restrict,'injury_recovered',v_recovered,'aggravation_risk_drop',v_risk_drop,
    'recommended_session',v_recommendation,'model','CB-DAILY-RECOVERY-v24'
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

revoke all on function public.apply_managed_recovery_day_v24(date,bigint) from public,anon,authenticated;
grant execute on function public.apply_managed_recovery_day_v24(date,bigint) to service_role;

create or replace function public.apply_world_recovery_week_v24(p_date date, p_week integer)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_snapshot jsonb:='[]'::jsonb;
  v_world jsonb;
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
    'managed_recovery_owner','CB-DAILY-RECOVERY-v24'
  );
end
$function$;

revoke all on function public.apply_world_recovery_week_v24(date,integer) from public,anon,authenticated;
grant execute on function public.apply_world_recovery_week_v24(date,integer) to service_role;

create or replace function public.simulate_injuries_week_v24(p_date date, p_week integer)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_before bigint[]:='{}'::bigint[];
  v_world jsonb;
  v_removed int:=0;
begin
  select coalesce(array_agg(i.id),'{}'::bigint[])
  into v_before
  from public.injuries i
  where i.player_id in (
    select managed_player_id from public.career_state where id='demo' and managed_player_id is not null
    union
    select player_id from public.academy_roster where status='active' and player_id is not null and source_youth_id is null
  );

  v_world:=public.simulate_injuries_week(p_date,p_week);

  delete from public.injuries i
  where i.player_id in (
    select managed_player_id from public.career_state where id='demo' and managed_player_id is not null
    union
    select player_id from public.academy_roster where status='active' and player_id is not null and source_youth_id is null
  )
    and i.started_at=p_date
    and not (i.id=any(v_before));
  get diagnostics v_removed=row_count;

  update public.players p
  set injury_status='Fit'
  where p.id in (
    select managed_player_id from public.career_state where id='demo' and managed_player_id is not null
    union
    select player_id from public.academy_roster where status='active' and player_id is not null and source_youth_id is null
  )
  and not exists(
    select 1 from public.injuries i where i.player_id=p.id and lower(coalesce(i.status,''))='active'
  );

  return coalesce(v_world,'{}'::jsonb)||jsonb_build_object(
    'managed_injuries_filtered',v_removed,
    'managed_injury_owner','daily_training_and_live_match'
  );
end
$function$;

revoke all on function public.simulate_injuries_week_v24(date,integer) from public,anon,authenticated;
grant execute on function public.simulate_injuries_week_v24(date,integer) to service_role;

create or replace function public.apply_managed_medical_week(p_date date, p_player_id bigint)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_primary bigint;
  v_player public.players%rowtype;
  v_protocol text:='Récupération active';
  v_physio int:=2;
  v_cost numeric:=250;
  v_medical numeric:=10;
  v_fitness numeric:=10;
  v_nutrition numeric:=10;
  v_injury public.injuries%rowtype;
begin
  select managed_player_id into v_primary from public.career_state where id='demo';
  if p_player_id is null then p_player_id:=v_primary; end if;

  if p_player_id is null or not (
    p_player_id=coalesce(v_primary,-1)
    or exists(select 1 from public.academy_roster where player_id=p_player_id and status='active' and source_youth_id is null)
  ) then
    raise exception 'player % is not in managed squad',p_player_id;
  end if;

  select * into v_player from public.players where id=p_player_id;
  if not found then raise exception 'player % not found',p_player_id; end if;

  select protocol,physio_hours,weekly_cost
  into v_protocol,v_physio,v_cost
  from public.player_medical_plans where player_id=p_player_id;

  if not found then
    insert into public.player_medical_plans(player_id,protocol,physio_hours,weekly_cost,notes)
    values(p_player_id,'Récupération active',2,250,'Suivi médical du groupe géré')
    on conflict(player_id) do update set updated_at=now()
    returning protocol,physio_hours,weekly_cost into v_protocol,v_physio,v_cost;
  end if;

  select
    coalesce(max(sp.medical_rating*coalesce(public.staff_effectiveness_multiplier(sp.id),1)),10),
    coalesce(max(sp.fitness_rating*coalesce(public.staff_effectiveness_multiplier(sp.id),1)),10),
    coalesce(max(case when sp.primary_role ilike '%Nutrition%'
      then greatest(sp.fitness_rating,sp.professionalism,sp.communication_rating)*coalesce(public.staff_effectiveness_multiplier(sp.id),1)
      else null end),10)
  into v_medical,v_fitness,v_nutrition
  from public.player_staff_assignments psa
  join public.staff_profiles sp on sp.id=psa.staff_profile_id
  where psa.player_id=p_player_id and psa.active=true and sp.active=true;

  if coalesce(v_medical,0)<=0 then
    select
      coalesce(max(sp.medical_rating*coalesce(public.staff_effectiveness_multiplier(sp.id),1)),10),
      coalesce(max(sp.fitness_rating*coalesce(public.staff_effectiveness_multiplier(sp.id),1)),10),
      coalesce(max(case when sp.primary_role ilike '%Nutrition%'
        then greatest(sp.fitness_rating,sp.professionalism,sp.communication_rating)*coalesce(public.staff_effectiveness_multiplier(sp.id),1)
        else null end),10)
    into v_medical,v_fitness,v_nutrition
    from public.staff s join public.staff_profiles sp on sp.id=s.profile_id where sp.active=true;
  end if;

  select * into v_injury
  from public.injuries where player_id=p_player_id and lower(coalesce(status,''))='active'
  order by started_at desc,id desc limit 1;

  return jsonb_build_object(
    'player_id',p_player_id,'player_name',v_player.name,'is_primary',p_player_id=coalesce(v_primary,-1),
    'protocol',coalesce(v_protocol,'Récupération active'),'physio_hours',coalesce(v_physio,2),
    'weekly_cost',coalesce(v_cost,0),
    'fatigue_delta',0,'fitness_delta',0,'morale_delta',0,'risk_delta',0,'return_days_gained',0,
    'staff_medical_rating',round(coalesce(v_medical,10),1),
    'staff_fitness_rating',round(coalesce(v_fitness,10),1),
    'staff_nutrition_rating',round(coalesce(v_nutrition,10),1),
    'injury_id',v_injury.id,'recovered',false,
    'condition_owner','CB-DAILY-RECOVERY-v24',
    'budget_owner','weekly_checkpoint_finance_ledger',
    'model','CB-MEDICAL-WEEK-v24-NO-DOUBLE-COUNT'
  );
end
$function$;

create or replace function public.apply_managed_medical_week(p_date date)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_player_id bigint;
begin
  select managed_player_id into v_player_id from public.career_state where id='demo';
  if v_player_id is null then raise exception 'Managed player missing'; end if;
  return public.apply_managed_medical_week(p_date,v_player_id);
end
$function$;

revoke all on function public.apply_managed_medical_week(date,bigint) from public,anon,authenticated;
revoke all on function public.apply_managed_medical_week(date) from public,anon,authenticated;
grant execute on function public.apply_managed_medical_week(date,bigint) to service_role;
grant execute on function public.apply_managed_medical_week(date) to service_role;
