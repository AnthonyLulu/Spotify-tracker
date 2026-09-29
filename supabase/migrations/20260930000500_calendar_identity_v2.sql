-- Court Boss calendar identity v2
-- Differentiated season volume, rest thresholds and NCAA/pro scheduling.

CREATE OR REPLACE FUNCTION public.rebalance_player_season_plans(p_season integer, p_reference_date date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_updated int:=0;
begin
  update public.player_season_plans plan
  set
    plan_type=case
      when p.career_focus='doubles_only' then 'doubles_specialist'
      when p.ncaa_current=true then 'ncaa_pathway'
      when p.age<=19 and p.junior_ranking is not null and coalesce(p.ranking,999999)>400 then 'junior_transition'
      when coalesce(p.ranking,999999)<=20 then 'elite_selective'
      when coalesce(p.ranking,999999)<=120 then 'tour_regular'
      when coalesce(p.ranking,999999)<=500 then 'challenger_push'
      else 'itf_build'
    end,

    base_target_events=greatest(8,least(32,
      (
        case
          when p.career_focus='doubles_only'
            then 22+mod(abs(hashtext('base-events|'||p.id||'|'||p_season)),5)
          when p.ncaa_current=true
            then (case when coalesce(p.ranking,999999)<=250 then 12 else 9 end)
                 +mod(abs(hashtext('base-events|'||p.id||'|'||p_season)),4)
          when p.age<=19 and p.junior_ranking is not null and coalesce(p.ranking,999999)>400
            then 20+mod(abs(hashtext('base-events|'||p.id||'|'||p_season)),6)
          when coalesce(p.ranking,999999)<=20
            then 15+mod(abs(hashtext('base-events|'||p.id||'|'||p_season)),4)
          when coalesce(p.ranking,999999)<=120
            then 20+mod(abs(hashtext('base-events|'||p.id||'|'||p_season)),5)
          when coalesce(p.ranking,999999)<=500
            then 23+mod(abs(hashtext('base-events|'||p.id||'|'||p_season)),6)
          else 24+mod(abs(hashtext('base-events|'||p.id||'|'||p_season)),7)
        end
        -case when p.age>=34 then 3 when p.age>=31 then 1 else 0 end
        -case when dp.injury_proneness>=16 then 2 when dp.injury_proneness>=13 then 1 else 0 end
      )
    )),

    target_events=greatest(8,least(32,
      (
        case
          when p.career_focus='doubles_only'
            then 22+mod(abs(hashtext('base-events|'||p.id||'|'||p_season)),5)
          when p.ncaa_current=true
            then (case when coalesce(p.ranking,999999)<=250 then 12 else 9 end)
                 +mod(abs(hashtext('base-events|'||p.id||'|'||p_season)),4)
          when p.age<=19 and p.junior_ranking is not null and coalesce(p.ranking,999999)>400
            then 20+mod(abs(hashtext('base-events|'||p.id||'|'||p_season)),6)
          when coalesce(p.ranking,999999)<=20
            then 15+mod(abs(hashtext('base-events|'||p.id||'|'||p_season)),4)
          when coalesce(p.ranking,999999)<=120
            then 20+mod(abs(hashtext('base-events|'||p.id||'|'||p_season)),5)
          when coalesce(p.ranking,999999)<=500
            then 23+mod(abs(hashtext('base-events|'||p.id||'|'||p_season)),6)
          else 24+mod(abs(hashtext('base-events|'||p.id||'|'||p_season)),7)
        end
        -case when p.age>=34 then 3 when p.age>=31 then 1 else 0 end
        -case when dp.injury_proneness>=16 then 2 when dp.injury_proneness>=13 then 1 else 0 end
        -case when coalesce(ps.burnout,25)>=75 then 5
              when coalesce(ps.burnout,25)>=60 then 3
              when coalesce(ps.burnout,25)>=45 then 1 else 0 end
        -case when coalesce(ps.pressure_load,30)>=80 then 2
              when coalesce(ps.pressure_load,30)>=65 then 1 else 0 end
        +case when coalesce(ps.motivation,65)>=82 and coalesce(ps.burnout,25)<40 then 2
              when coalesce(ps.motivation,65)>=72 and coalesce(ps.burnout,25)<50 then 1 else 0 end
      )
    )),

    max_consecutive_weeks=greatest(1,least(4,
      case
        when p.ncaa_current=true then 2
        when coalesce(p.ranking,999999)<=20 then 2
        when p.career_focus='doubles_only' then 3
        else 3
      end
      +case when p.age<=27
                  and pa.recovery>=16
                  and pa.natural_fitness>=15
                  and dp.injury_proneness<=11
                  and coalesce(ps.burnout,25)<45
             then 1 else 0 end
      -case when p.age>=33 then 1 else 0 end
      -case when dp.injury_proneness>=16 or pa.recovery<=8 then 1 else 0 end
      -case when coalesce(ps.burnout,25)>=65 then 1 else 0 end
    )),

    rest_trigger_fatigue=greatest(50,least(82,
      case
        when p.ncaa_current=true then 62
        when coalesce(p.ranking,999999)<=20 then 64
        when p.career_focus='doubles_only' then 68
        when p.age<=19 and p.junior_ranking is not null then 67
        when coalesce(p.ranking,999999)<=120 then 68
        when coalesce(p.ranking,999999)<=500 then 70
        else 71
      end
      +round((pa.recovery-10)*.8)::int
      +round((pa.natural_fitness-10)*.5)::int
      -round((dp.injury_proneness-10)*.7)::int
      -case when p.age>=34 then 5 when p.age>=31 then 2 else 0 end
      -case when coalesce(ps.burnout,25)>=70 then 8
            when coalesce(ps.burnout,25)>=55 then 4 else 0 end
    )),

    schedule_risk_tolerance=greatest(1,least(20,
      9
      +round((dp.competitive_drive-10)*.45)::int
      +round((dp.ambition-10)*.30)::int
      +case when p.age<=23 then 1 else 0 end
      -round((dp.injury_proneness-10)*.40)::int
      -case when p.age>=32 then 2 else 0 end
      -case when coalesce(ps.burnout,25)>=60 then 3 else 0 end
    )),

    mental_load_target=greatest(35,least(76,
      57
      +round((dp.resilience-10)*.55)::int
      +round((dp.pressure-10)*.35)::int
      -round((dp.confidence_volatility-10)*.30)::int
      -case when coalesce(ps.burnout,25)>=65 then 6 else 0 end
      -case when p.age<=20 then 2 else 0 end
    )),

    reason=case
      when p.career_focus='doubles_only'
        then 'Double prioritaire : volume contrôlé, Race et partenariats avant le simple.'
      when p.ncaa_current=true
        then 'NCAA : saison universitaire prioritaire, pro ciblé, été plus agressif.'
      when coalesce(p.ranking,999999)<=20
        then 'Élite : calendrier sélectif, pics de forme et récupération autour des grands rendez-vous.'
      when p.age<=19 and p.junior_ranking is not null
        then 'Transition Junior : progression graduelle vers ITF/Challenger sans surcharge.'
      when coalesce(p.ranking,999999)<=120
        then 'Tour ATP : consolider le classement et cibler les meilleures surfaces.'
      when coalesce(p.ranking,999999)<=500
        then 'Challenger : volume utile, qualifications ATP et repos après les gros blocs.'
      else 'ITF : construire le classement sans dépasser la charge physique soutenable.'
    end||
    ' Charge cible '||
    greatest(1,least(4,
      case
        when p.ncaa_current=true then 2
        when coalesce(p.ranking,999999)<=20 then 2
        when p.career_focus='doubles_only' then 3
        else 3
      end
      +case when p.age<=27 and pa.recovery>=16 and pa.natural_fitness>=15
                  and dp.injury_proneness<=11 and coalesce(ps.burnout,25)<45
             then 1 else 0 end
      -case when p.age>=33 then 1 else 0 end
      -case when dp.injury_proneness>=16 or pa.recovery<=8 then 1 else 0 end
      -case when coalesce(ps.burnout,25)>=65 then 1 else 0 end
    ))||' semaines max.',

    last_adapted_date=coalesce(p_reference_date,current_date),
    updated_at=now()
  from public.players p
  join public.player_attributes pa on pa.player_id=p.id
  join public.player_development_profiles dp on dp.player_id=p.id
  left join public.player_psychology_state ps on ps.player_id=p.id
  where plan.player_id=p.id
    and plan.season=p_season
    and p.career_status='active';

  get diagnostics v_updated=row_count;

  return jsonb_build_object(
    'season',p_season,
    'reference_date',coalesce(p_reference_date,current_date),
    'updated',v_updated,
    'model','calendar identity v2 · rank + age + NCAA + recovery + injury + burnout + motivation'
  );
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

  v_week:=date_trunc('week',coalesce(t.main_draw_start_date,t.start_date)::timestamp)::date;
  if public.player_has_world_event_in_week(p.id,v_week,t.id) then
    return false;
  end if;

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
    from public.college_duals cd
    where p.ncaa_current=true
      and p.ncaa_team_id in (cd.home_team_id,cd.away_team_id)
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

-- Prepare the upcoming 2026 calendar from the 2025-12-01 pre-season state.
select public.rebalance_player_season_plans(2026,date '2025-12-01');
