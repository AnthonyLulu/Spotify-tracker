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
  v_orphan_status_cleared boolean:=false;
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
      'fatigue',v_player.fatigue,'fitness',v_player.fitness,'model','CB-DAILY-RECOVERY-v25'
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
    'medical_training_restriction',v_restrict,'injury_recovered',v_recovered,'orphan_status_cleared',v_orphan_status_cleared,'aggravation_risk_drop',v_risk_drop,
    'recommended_session',v_recommendation,'model','CB-DAILY-RECOVERY-v25'
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