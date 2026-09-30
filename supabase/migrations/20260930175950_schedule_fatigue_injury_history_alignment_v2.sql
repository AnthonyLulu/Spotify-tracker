CREATE OR REPLACE FUNCTION public.refresh_player_season_plans(p_date date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_date date:=coalesce(p_date,current_date);
  v_year int:=extract(year from v_date)::int;
  v_count int:=0;
begin
  insert into player_season_plans(
    player_id,season,plan_type,target_events,preferred_surface,secondary_surface,
    rest_bias,travel_tolerance,prestige_bias,development_bias,doubles_bias,reason,updated_at
  )
  select
    p.id,v_year,
    case
      when p.career_focus='doubles_only' then 'doubles_specialist'
      when p.ncaa_current=true then 'ncaa_pathway'
      when p.age<=19 and p.junior_ranking is not null and coalesce(p.ranking,999999)>500 then 'junior_transition'
      when coalesce(p.ranking,999999)<=20 then 'elite_selective'
      when coalesce(p.ranking,999999)<=120 then 'tour_regular'
      when coalesce(p.ranking,999999)<=500 then 'challenger_push'
      else 'itf_build'
    end,
    case
      when p.career_focus='doubles_only' then 24+mod(abs(hashtext('events|'||p.id::text||'|'||v_year::text)),8)
      when p.ncaa_current=true then 22+mod(abs(hashtext('events|'||p.id::text||'|'||v_year::text)),5)
      when coalesce(p.ranking,999999)<=20 then 15+mod(abs(hashtext('events|'||p.id::text||'|'||v_year::text)),6)
      when coalesce(p.ranking,999999)<=120 then 20+mod(abs(hashtext('events|'||p.id::text||'|'||v_year::text)),8)
      when coalesce(p.ranking,999999)<=500 then 24+mod(abs(hashtext('events|'||p.id::text||'|'||v_year::text)),10)
      else 27+mod(abs(hashtext('events|'||p.id::text||'|'||v_year::text)),12)
    end,
    case
      when pa.clay_affinity>=greatest(pa.hard_affinity,pa.grass_affinity) then 'Terre'
      when pa.grass_affinity>=greatest(pa.hard_affinity,pa.clay_affinity) then 'Gazon'
      else 'Dur'
    end,
    case
      when pa.hard_affinity>=least(pa.clay_affinity,pa.grass_affinity)
           and not (pa.hard_affinity>=greatest(pa.clay_affinity,pa.grass_affinity)) then 'Dur'
      when pa.clay_affinity>=pa.grass_affinity then 'Terre'
      else 'Gazon'
    end,
    greatest(1,least(20,
      8+
      case when p.age>=30 then 3 else 0 end+
      case when dp.injury_proneness>=14 then 3 else 0 end+
      case when pa.recovery<=9 then 2 else 0 end-
      case when dp.competitive_drive>=16 then 2 else 0 end
    )),
    greatest(1,least(20,
      8+dp.adaptability/3+
      case when dp.ambition>=15 then 2 else 0 end-
      case when p.age>=32 then 2 else 0 end
    )),
    greatest(1,least(20,
      7+dp.ambition/2+
      case when coalesce(p.ranking,999999)<=50 then 4 else 0 end
    )),
    greatest(1,least(20,
      7+dp.development_rate/2+
      case when p.age<=22 then 4 else 0 end
    )),
    greatest(1,least(20,
      case p.career_focus
        when 'doubles_only' then 20
        when 'mixed' then 14
        when 'singles_priority' then 7
        when 'singles_only' then 1
        else 10
      end
      +case when pa.doubles>=15 then 2 else 0 end
    )),
    case
      when p.career_focus='doubles_only' then 'Calendrier construit autour du classement et de la Race double.'
      when p.ncaa_current=true then 'Parcours NCAA prioritaire : duals, ITA/UTR, puis fenêtres pro compatibles.'
      when coalesce(p.ranking,999999)<=20 then 'Calendrier sélectif : grands rendez-vous, récupération et pics de forme.'
      when p.age<=19 and p.junior_ranking is not null then 'Transition progressive Junior → ITF/Challenger.'
      when coalesce(p.ranking,999999)<=120 then 'Consolider le circuit ATP et cibler les surfaces fortes.'
      when coalesce(p.ranking,999999)<=500 then 'Accumuler des points Challenger et viser les qualifications ATP.'
      else 'Construire le classement via ITF et Challenger adaptés.'
    end,
    now()
  from players p
  join player_attributes pa on pa.player_id=p.id
  join player_development_profiles dp on dp.player_id=p.id
  where p.career_status='active'
    and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
    and (
      p.ranking_current=true
      or p.itf_ranking is not null
      or p.junior_ranking is not null
      or p.doubles_ranking is not null
      or p.ncaa_current=true
    )
  on conflict(player_id,season) do update set
    plan_type=excluded.plan_type,
    target_events=excluded.target_events,
    preferred_surface=excluded.preferred_surface,
    secondary_surface=excluded.secondary_surface,
    rest_bias=excluded.rest_bias,
    travel_tolerance=excluded.travel_tolerance,
    prestige_bias=excluded.prestige_bias,
    development_bias=excluded.development_bias,
    doubles_bias=excluded.doubles_bias,
    reason=excluded.reason,
    updated_at=now();

  get diagnostics v_count=row_count;
  return jsonb_build_object('season',v_year,'plans',v_count);
end;
$function$;

CREATE OR REPLACE FUNCTION public.ai_tournament_commitment_probability(p_rank integer, p_plan_type text, p_target_events integer, p_preferred_surface text, p_tournament_surface text, p_category text, p_player_country text, p_tournament_country text, p_fatigue integer, p_rest_trigger integer)
 RETURNS numeric
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
declare
  v numeric;
  cat text:=coalesce(p_category,'');
  plan text:=coalesce(p_plan_type,'tour_regular');
  pref text:=lower(coalesce(p_preferred_surface,''));
  surf text:=lower(coalesce(p_tournament_surface,''));
  r int:=coalesce(p_rank,999999);
begin
  v:=case
    when cat='Grand Chelem' then 98
    when cat='Masters 1000' then 92
    when cat='ATP 500' then 64
    when cat='ATP 250' then 44
    when cat='Challenger 175' then 70
    when cat='Challenger 125' then 74
    when cat='Challenger 100' then 78
    when cat='Challenger 75' then 82
    when cat='Challenger 50' then 85
    when cat='M25' then 88
    when cat='M15' then 90
    when cat in ('Junior Grand Slam','J500') then 94
    when cat='J300' then 88
    when cat='J200' then 86
    when cat='J100' then 84
    when cat='J60' then 82
    when cat='J30' then 78
    when cat in ('Junior Finals','Junior Double Finals') then 98
    else 60 end;

  if plan='elite_selective' then
    v:=v+case
      when cat='Grand Chelem' then 1
      when cat='Masters 1000' then 5
      when cat='ATP 500' then -9
      when cat='ATP 250' then -22
      when cat like 'J%' or cat='Junior Grand Slam' then -35
      else -42 end;
  elsif plan='tour_regular' then
    v:=v+case when cat='ATP 500' then 5 when cat='ATP 250' then 8 else 0 end;
  elsif plan='challenger_push' then
    v:=v+case when cat like 'Challenger %' then 12 when cat='ATP 250' then 5 when cat in ('M15','M25') then -12 else 0 end;
  elsif plan='itf_build' then
    v:=v+case when cat in ('M15','M25') then 9 when cat='Challenger 50' then 4 when cat like 'ATP %' or cat='Masters 1000' then -25 else 0 end;
  elsif plan='junior_transition' then
    v:=v+case
      when cat='Junior Grand Slam' then 12
      when cat in ('J500','J300','J200','J100','J60','J30') then 10
      when cat in ('M15','M25') then 8
      when cat='Challenger 50' then 3
      when cat like 'ATP %' or cat='Masters 1000' then -25
      else 0 end;
  elsif plan='ncaa_pathway' then
    v:=v+case
      when cat in ('M15','M25') then 7
      when cat in ('Challenger 50','Challenger 75') then -4
      when cat like 'Challenger %' then -10
      when cat in ('ATP 250','ATP 500','Masters 1000','Grand Chelem') then -24
      else -5 end;
  elsif plan='doubles_specialist' then
    v:=v-18;
  end if;

  if r<=10 then
    v:=v+case when cat='ATP 250' then -14 when cat='ATP 500' then -5 when cat='Masters 1000' then 4 when cat='Grand Chelem' then 1 else 0 end;
  elsif r<=20 then
    v:=v+case when cat='ATP 250' then -9 when cat='ATP 500' then -2 else 0 end;
  elsif r between 51 and 120 and cat='ATP 250' then
    v:=v+7;
  end if;

  if p_player_country is not null and p_tournament_country is not null
     and p_player_country=p_tournament_country then
    v:=v+15;
  end if;

  if pref<>'' then
    if (pref like '%terre%' or pref like '%clay%') and (surf like '%terre%' or surf like '%clay%') then v:=v+8;
    elsif (pref like '%gazon%' or pref like '%grass%') and (surf like '%gazon%' or surf like '%grass%') then v:=v+8;
    elsif (pref like '%dur%' or pref like '%hard%') and (surf like '%dur%' or surf like '%hard%') then v:=v+8;
    else v:=v-2;
    end if;
  end if;

  v:=v+greatest(-5,least(8,(coalesce(p_target_events,22)-22)*.55));

  if coalesce(p_fatigue,0)>=coalesce(p_rest_trigger,72) then v:=v-28; end if;
  if coalesce(p_fatigue,0)>=85 then v:=v-18; end if;

  return greatest(3,least(99,v));
end;
$function$;

CREATE OR REPLACE FUNCTION public.ai_player_commits_to_tournament(p_player_id bigint, p_tournament_id bigint)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  p public.players%rowtype;
  t public.tournaments%rowtype;
  sp public.player_season_plans%rowtype;
  prob numeric;
  roll numeric;
  r int;
  v_week date;
  v_year int;
  v_played int:=0;
  v_consecutive int:=0;
  v_i int;
  v_max_consecutive int;
  v_rest_trigger int;
  v_target int;
  v_previous_country text;
  v_commitment_rank int;
  v_atp500_count int:=0;
  v_post_uso_500_count int:=0;
  v_major boolean:=false;
begin
  select * into p from public.players where id=p_player_id;
  select * into t from public.tournaments where id=p_tournament_id;
  if p.id is null or t.id is null then return false; end if;

  if (public.player_tournament_calendar_conflict(p.id,t.id,'candidate')->>'conflict')::boolean then
    return false;
  end if;

  select * into sp
  from public.player_season_plans s
  where s.player_id=p.id and s.season=extract(year from t.start_date)::int;

  r:=coalesce(case when p.ranking_current then p.ranking end,p.game_world_rank,p.ranking,999999);
  v_year:=extract(year from t.start_date)::int;
  v_week:=date_trunc('week',coalesce(t.main_draw_start_date,t.start_date)::timestamp)::date;
  v_max_consecutive:=greatest(1,coalesce(sp.max_consecutive_weeks,case when p.age>=32 then 2 else 3 end));
  v_rest_trigger:=coalesce(sp.rest_trigger_fatigue,72);
  v_target:=coalesce(sp.target_events,22);
  v_major:=coalesce(t.category,'') in ('Grand Chelem','Masters 1000','ATP Finals','Next Gen Finals');

  select count(distinct z.tournament_id)::int
  into v_played
  from (
    select e.tournament_id
    from public.world_tournament_entries e
    join public.tournaments et on et.id=e.tournament_id
    where e.player_id=p.id
      and extract(year from et.start_date)::int=v_year
      and et.start_date<t.start_date
    union
    select e.tournament_id
    from public.world_tournament_qualifying_entries e
    join public.tournaments et on et.id=e.tournament_id
    where e.player_id=p.id
      and extract(year from et.start_date)::int=v_year
      and et.start_date<t.start_date
    union
    select e.tournament_id
    from public.world_doubles_tournament_entries e
    join public.world_doubles_partnerships wp on wp.id=e.pair_id
    join public.tournaments et on et.id=e.tournament_id
    where p.id in (wp.player_a_id,wp.player_b_id)
      and extract(year from et.start_date)::int=v_year
      and et.start_date<t.start_date
    union
    select e.tournament_id
    from public.world_junior_doubles_entries e
    join public.tournaments et on et.id=e.tournament_id
    where p.id in (e.player_a_id,e.player_b_id)
      and extract(year from et.start_date)::int=v_year
      and et.start_date<t.start_date
    union
    select e.tournament_id
    from public.ncaa_individual_entries e
    join public.tournaments et on et.id=e.tournament_id
    where e.player_id=p.id
      and extract(year from et.start_date)::int=v_year
      and et.start_date<t.start_date
    union
    select 1000000000::bigint+extract(doy from cd.match_date)::bigint
    from public.college_teams ct
    join public.college_duals cd on ct.id in (cd.home_team_id,cd.away_team_id)
    where p.ncaa_current=true
      and p.ncaa_school=ct.name
      and cd.status='completed'
      and extract(year from cd.match_date)::int=v_year
      and cd.match_date<t.start_date
    union
    select 2000000000::bigint+dt.id
    from public.davis_squad ds
    join public.davis_ties dt on ds.nation in (dt.home_nation,dt.away_nation)
    where ds.player_id=p.id
      and dt.status='completed'
      and extract(year from dt.tie_date)::int=v_year
      and dt.tie_date<t.start_date
  ) z;

  for v_i in 1..5 loop
    if public.player_has_world_event_in_week(p.id,v_week-(v_i*7),null) then
      v_consecutive:=v_consecutive+1;
    else
      exit;
    end if;
  end loop;

  if v_consecutive>=v_max_consecutive and not v_major then
    return false;
  end if;

  if coalesce(p.fatigue,20)>=v_rest_trigger+10 and not v_major then
    return false;
  end if;

  prob:=public.ai_tournament_commitment_probability(
    r,coalesce(sp.plan_type,'tour_regular'),v_target,
    sp.preferred_surface,t.surface,t.category,p.country,t.country,
    coalesce(p.fatigue,20),v_rest_trigger
  );

  if v_played>=v_target then
    prob:=prob-case
      when v_major then 0
      when coalesce(sp.schedule_risk_tolerance,10)>=15 then 12
      else 28 end;
  end if;
  if v_played>=v_target+4 and not v_major then
    prob:=least(prob,18);
  end if;

  if coalesce(sp.plan_type,'')='ncaa_pathway' then
    if extract(month from t.start_date) between 1 and 5 then
      prob:=prob-case
        when t.circuit='ITF' then 24
        when t.circuit='Challenger' then 34
        else 45 end;
    elsif extract(month from t.start_date) between 6 and 8 then
      prob:=prob+case
        when t.circuit='ITF' then 14
        when t.circuit='Challenger' then 8
        else 0 end;
    else
      prob:=prob-case
        when t.circuit='ITF' then 8
        else 18 end;
    end if;
  end if;

  select x.country into v_previous_country
  from (
    select et.country,coalesce(et.end_date,et.start_date) event_date
    from public.world_tournament_entries e
    join public.tournaments et on et.id=e.tournament_id
    where e.player_id=p.id and et.start_date<t.start_date
    union all
    select et.country,coalesce(et.end_date,et.start_date)
    from public.world_doubles_tournament_entries e
    join public.world_doubles_partnerships wp on wp.id=e.pair_id
    join public.tournaments et on et.id=e.tournament_id
    where p.id in (wp.player_a_id,wp.player_b_id) and et.start_date<t.start_date
    union all
    select et.country,coalesce(et.end_date,et.start_date)
    from public.world_junior_doubles_entries e
    join public.tournaments et on et.id=e.tournament_id
    where p.id in (e.player_a_id,e.player_b_id) and et.start_date<t.start_date
  ) x
  order by x.event_date desc
  limit 1;

  if v_previous_country is not null
     and t.country is not null
     and v_previous_country is distinct from t.country then
    prob:=prob-greatest(2,14-coalesce(sp.travel_tolerance,10)*.55);
  end if;

  if t.circuit='ATP' and v_year>=2026 then
    v_commitment_rank:=public.player_rank_at_date(
      p.id,make_date(v_year-1,11,10)
    );
    v_commitment_rank:=coalesce(v_commitment_rank,r);

    if v_commitment_rank between 1 and 30 then
      if t.category in ('Grand Chelem','Masters 1000') then
        prob:=greatest(prob,97);
      elsif t.category='ATP 500' then
        select count(distinct e.tournament_id)::int
        into v_atp500_count
        from public.world_tournament_entries e
        join public.tournaments et on et.id=e.tournament_id
        where e.player_id=p.id
          and et.circuit='ATP' and et.category='ATP 500'
          and extract(year from et.start_date)::int=v_year
          and et.start_date<t.start_date;

        select count(distinct e.tournament_id)::int
        into v_post_uso_500_count
        from public.world_tournament_entries e
        join public.tournaments et on et.id=e.tournament_id
        where e.player_id=p.id
          and et.circuit='ATP' and et.category='ATP 500'
          and extract(year from et.start_date)::int=v_year
          and extract(month from et.start_date)>=9
          and et.start_date<t.start_date;

        if v_atp500_count<4 then prob:=greatest(prob,78); end if;
        if extract(month from t.start_date)>=9 and v_post_uso_500_count=0 then
          prob:=greatest(prob,91);
        end if;
      end if;
    end if;
  end if;

  prob:=greatest(2,least(99,prob));
  roll:=(mod(abs(hashtext('ai-commit-v2|'||t.id::text||'|'||p.id::text)),10000)::numeric)/100.0;
  return roll<prob;
end;
$function$;

CREATE OR REPLACE FUNCTION public.simulate_injuries_week(p_date date, p_week integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  new_count int:=0;
  rec record;
  typ text;
  sev text;
  days_out int;
  risk_score numeric;
  v_recovery jsonb;
  v_area text;
begin
  update injuries
  set status='recovered'
  where lower(coalesce(status,''))='active' and expected_return <= p_date;

  v_recovery:=public.process_recovered_injury_effects(p_date);

  for rec in
    select
      p.id,p.fatigue,p.ranking,p.age,p.fitness,
      public.player_recent_match_load(p.id,p_date) as recent_matches,
      coalesce(dp.injury_proneness,10) as injury_proneness,
      coalesce(pa.natural_fitness,10) as natural_fitness,
      coalesce(pa.recovery,10) as recovery,
      coalesce(pa.flexibility,10) as flexibility,
      coalesce(v.recurrence_risk,0) as recurrence_risk,
      v.body_area as vulnerable_area,
      coalesce(tl.intensity,10) as training_intensity,
      coalesce(tl.injury_load_modifier,1) as training_risk_modifier,
      coalesce(tl.recovery_days,1) as training_recovery_days
    from players p
    left join player_development_profiles dp on dp.player_id=p.id
    left join player_attributes pa on pa.player_id=p.id
    left join public.player_training_load_profiles tl on tl.player_id=p.id
    left join lateral (
      select iv.body_area,iv.recurrence_risk
      from player_injury_vulnerabilities iv
      where iv.player_id=p.id
      order by iv.recurrence_risk desc,iv.episodes desc
      limit 1
    ) v on true
    where (
        p.ranking_current=true
        or p.doubles_ranking is not null
        or p.junior_ranking is not null
        or p.itf_ranking is not null
        or p.ncaa_current=true
      )
      and p.career_status='active'
      and not exists(
        select 1 from injuries i
        where i.player_id=p.id and lower(coalesce(i.status,''))='active'
      )
      and p.injury_status='Fit'
    order by
      (coalesce(p.fatigue,20)>=55) desc,
      recent_matches desc,
      injury_proneness desc,
      mod(abs(hashtext('inj-candidate|'||p.id::text||'|'||p_week::text)),100000),
      p.id
    limit 3000
  loop
    risk_score:=
      greatest(0,coalesce(rec.fatigue,20)-28)*.55+
      greatest(0,coalesce(rec.recent_matches,0)-2)*3.2+
      rec.injury_proneness*1.35+
      greatest(0,12-rec.natural_fitness)*1.2+
      greatest(0,10-rec.flexibility)*.8+
      greatest(0,coalesce(rec.age,24)-30)*.8+
      greatest(0,78-coalesce(rec.fitness,90))*.20+
      rec.recurrence_risk*.22+
      greatest(0,rec.training_intensity-10)*.75+
      greatest(0,rec.training_risk_modifier-1)*14-
      greatest(0,rec.training_recovery_days-1)*.9;

    if mod(abs(hashtext(rec.id::text||'|'||p_week::text||'|'||p_date::text)),1000)
       >= least(90,round(risk_score)::int) then
      continue;
    end if;

    if rec.vulnerable_area is not null
       and rec.recurrence_risk>=25
       and mod(abs(hashtext('relapse|'||rec.id::text||'|'||p_week::text)),100)
           < least(68,18+rec.recurrence_risk) then
      v_area:=rec.vulnerable_area;
      typ:=case v_area
        when 'ischio' then 'Rechute ischio-jambiers'
        when 'épaule' then 'Rechute épaule'
        when 'cheville' then 'Nouvelle entorse cheville'
        when 'poignet' then 'Rechute poignet'
        when 'dos' then 'Rechute lombaire'
        when 'genou' then 'Rechute genou'
        when 'coude' then 'Rechute coude'
        else 'Rechute musculaire'
      end;
      days_out:=10+round(rec.recurrence_risk*.25)::int+mod(rec.id::int+p_week,10);
    else
      case mod(abs(hashtext('type|'||rec.id::text||'|'||p_week::text)),8)
        when 0 then typ:='Élongation ischio-jambiers'; days_out:=14+mod(rec.id::int+p_week,15);
        when 1 then typ:='Douleur épaule'; days_out:=10+mod(rec.id::int+p_week,12);
        when 2 then typ:='Entorse cheville'; days_out:=18+mod(rec.id::int+p_week,18);
        when 3 then typ:='Inflammation poignet'; days_out:=12+mod(rec.id::int+p_week,13);
        when 4 then typ:='Surcharge lombaire'; days_out:=8+mod(rec.id::int+p_week,12);
        when 5 then typ:='Douleur genou'; days_out:=16+mod(rec.id::int+p_week,17);
        when 6 then typ:='Inflammation coude'; days_out:=10+mod(rec.id::int+p_week,14);
        else typ:='Surcharge musculaire'; days_out:=7+mod(rec.id::int+p_week,9);
      end case;
      v_area:=public.injury_body_area(typ);
    end if;

    days_out:=greatest(5,days_out-greatest(0,rec.recovery-10)/2);
    sev:=case when days_out>=35 then 'Élevée' when days_out>=18 then 'Modérée' else 'Faible' end;

    insert into injuries(player_id,injury_type,severity,started_at,expected_return,aggravation_risk,treatment,status)
    values(
      rec.id,typ,sev,p_date,p_date+days_out,
      least(95,15+round(risk_score*.75)::int+round(rec.recurrence_risk*.15)::int),
      case
        when rec.recurrence_risk>=35 then 'Rééducation + prévention rechute'
        when days_out>=20 then 'Repos + rééducation'
        else 'Repos + soins'
      end,
      'active'
    );

    update players
    set fitness=greatest(35,fitness-case when days_out>=28 then 20 when days_out>=18 then 14 else 8 end),
        fatigue=greatest(0,fatigue-8),
        injury_status=typ
    where id=rec.id;

    new_count:=new_count+1;
    exit when new_count>=14;
  end loop;

  return jsonb_build_object(
    'new_injuries',new_count,
    'recovery_processing',v_recovery,
    'model','fatigue + injury proneness + natural fitness + recovery + age + recurrence history + training load'
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

CREATE OR REPLACE FUNCTION public.simulate_world_week(p_week integer, p_snapshot_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  affected_count int:=0;
  leader_name text;
  leader_rank int;
  protection jsonb;
  recovery jsonb;
begin
  perform pg_advisory_xact_lock(94832021);

  if p_snapshot_date<=date '2025-12-01' then
    return jsonb_build_object('updated_players',0,'historical_cutoff',true);
  end if;

  perform public.refresh_player_simulation_ages(p_snapshot_date);

  recovery:=public.apply_world_recovery_week(p_snapshot_date,p_week);
  affected_count:=coalesce((recovery->>'updated_players')::int,0);

  perform public.refresh_world_rankings(p_snapshot_date);
  protection:=public.refresh_player_entry_protection(p_snapshot_date);

  select name,ranking into leader_name,leader_rank
  from public.players
  where ranking_current=true
    and coalesce(data_source,'') not ilike 'hidden duplicate merged into %'
  order by ranking
  limit 1;

  return jsonb_build_object(
    'updated_players',affected_count,
    'leader',leader_name,
    'leader_rank',leader_rank,
    'snapshot_date',p_snapshot_date,
    'ranking_model','52-week ledger · no random point drift',
    'recovery',recovery,
    'entry_protection',protection
  );
end
$function$;

