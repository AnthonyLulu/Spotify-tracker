
create or replace function public.ai_player_commits_to_doubles_tournament(
  p_player_id bigint,
  p_tournament_id bigint
)
returns boolean
language plpgsql
stable
set search_path to 'public'
as $function$
declare
  p public.players%rowtype;
  t public.tournaments%rowtype;
  sp public.player_season_plans%rowtype;
  prob numeric;
  roll numeric;
  v_week date;
  v_consecutive int:=0;
  v_max_consecutive int;
  v_rest_trigger int;
  v_doubles_bias int;
  v_doubles_events int:=0;
  v_same_event_singles boolean:=false;
  v_unified_eligibility jsonb;
  v_dr int:=999999;
begin
  v_unified_eligibility:=public.player_event_eligibility(
    p_player_id,p_tournament_id,'doubles','direct'
  );
  if not coalesce((v_unified_eligibility->>'eligible')::boolean,false) then
    return false;
  end if;

  select * into p from public.players where id=p_player_id;
  select * into t from public.tournaments where id=p_tournament_id;
  if p.id is null or t.id is null then return false; end if;
  if coalesce(p.career_focus,'mixed')='singles_only' then return false; end if;

  if (public.player_tournament_calendar_conflict(p.id,t.id,'doubles')->>'conflict')::boolean then
    return false;
  end if;

  select * into sp
  from public.player_season_plans s
  where s.player_id=p.id
    and s.season=extract(year from t.start_date)::int;

  v_week:=date_trunc('week',coalesce(t.main_draw_start_date,t.start_date)::timestamp)::date;
  v_max_consecutive:=greatest(
    1,
    coalesce(sp.max_consecutive_weeks,case when p.age>=32 then 2 else 3 end)
  );
  v_rest_trigger:=coalesce(sp.rest_trigger_fatigue,72);
  v_doubles_bias:=coalesce(
    sp.doubles_bias,
    case coalesce(p.career_focus,'mixed')
      when 'doubles_only' then 20
      when 'mixed' then 14
      when 'singles_priority' then 7
      else 10
    end
  );

  with event_weeks as (
    select distinct date_trunc('week',x.event_date::timestamp)::date week_start
    from (
      select et.start_date event_date
      from public.world_tournament_entries e
      join public.tournaments et on et.id=e.tournament_id
      where e.player_id=p.id
        and et.start_date>=v_week-35
        and et.start_date<v_week

      union all

      select et.start_date
      from public.world_tournament_qualifying_entries e
      join public.tournaments et on et.id=e.tournament_id
      where e.player_id=p.id
        and et.start_date>=v_week-35
        and et.start_date<v_week

      union all

      select et.start_date
      from public.world_doubles_tournament_entries e
      join public.world_doubles_partnerships wp on wp.id=e.pair_id
      join public.tournaments et on et.id=e.tournament_id
      where p.id in (wp.player_a_id,wp.player_b_id)
        and et.start_date>=v_week-35
        and et.start_date<v_week
    ) x
  ),
  flags as (
    select
      g.i,
      exists(
        select 1
        from event_weeks ew
        where ew.week_start=v_week-(g.i*7)
      ) has_event
    from generate_series(1,5) g(i)
  )
  select coalesce(min(i) filter(where not has_event)-1,5)
  into v_consecutive
  from flags;

  if v_consecutive>=v_max_consecutive
     and coalesce(t.category,'') not in ('Grand Chelem','Masters 1000','ATP Finals') then
    return false;
  end if;

  select count(distinct e.tournament_id)::int
  into v_doubles_events
  from public.world_doubles_tournament_entries e
  join public.world_doubles_partnerships wp on wp.id=e.pair_id
  join public.tournaments et on et.id=e.tournament_id
  where p.id in (wp.player_a_id,wp.player_b_id)
    and extract(year from et.start_date)=extract(year from t.start_date)
    and et.start_date<t.start_date;

  select exists(
    select 1
    from public.world_tournament_entries e
    where e.tournament_id=t.id and e.player_id=p.id
  )
  into v_same_event_singles;

  v_dr:=coalesce(
    public.player_doubles_seed_rank_at_date(
      p.id,
      coalesce(t.doubles_entry_deadline,t.start_date)
    ),
    999999
  );

  prob:=case
    when t.category='Grand Chelem' then 96
    when t.category='Masters 1000' then 90
    when t.category='ATP 500' then 82
    when t.category='ATP 250' then 72
    when t.circuit='Challenger' then
      case
        when v_dr<=30 then 6
        when v_dr<=75 then 18
        when v_dr<=150 then 42
        when v_dr<=300 then 68
        else 78
      end
    when t.category='M25' then
      case
        when v_dr<=50 then 1
        when v_dr<=150 then 5
        when v_dr<=300 then 20
        when v_dr<=600 then 55
        else 80
      end
    when t.category='M15' then
      case
        when v_dr<=50 then .2
        when v_dr<=150 then 2
        when v_dr<=300 then 10
        when v_dr<=600 then 38
        else 84
      end
    when t.circuit='Junior' then 82
    else 60
  end;

  prob:=prob+(v_doubles_bias-10)*2.1;

  prob:=prob+case coalesce(p.career_focus,'mixed')
    when 'doubles_only' then 18
    when 'mixed' then 5
    when 'singles_priority' then -10
    else 0
  end;

  if v_dr<=50 and t.category in ('Grand Chelem','Masters 1000','ATP 500') then
    prob:=prob+6;
  elsif v_dr<=150 and t.category in ('ATP 500','ATP 250') then
    prob:=prob+4;
  end if;

  if v_same_event_singles then
    prob:=prob+12;
  end if;

  if not v_same_event_singles then
    if t.category='M15' then
      if coalesce(p.ranking,999999)<=100 then prob:=least(prob,.2);
      elsif coalesce(p.ranking,999999)<=200 then prob:=least(prob,1);
      elsif coalesce(p.ranking,999999)<=400 then prob:=least(prob,5);
      end if;
    elsif t.category='M25' then
      if coalesce(p.ranking,999999)<=50 then prob:=least(prob,.5);
      elsif coalesce(p.ranking,999999)<=100 then prob:=least(prob,2);
      elsif coalesce(p.ranking,999999)<=200 then prob:=least(prob,7);
      end if;
    elsif t.circuit='Challenger' then
      if coalesce(p.ranking,999999)<=20 then prob:=least(prob,3);
      elsif coalesce(p.ranking,999999)<=50 then prob:=least(prob,10);
      end if;
    end if;
  end if;

  if coalesce(sp.plan_type,'')='ncaa_pathway' then
    if extract(month from t.start_date) between 1 and 5 then
      prob:=prob-case
        when v_same_event_singles then 4
        when t.category='Grand Chelem' then 12
        when t.circuit='Challenger' then 30
        when t.circuit='ITF' then 22
        else 34
      end;
    elsif extract(month from t.start_date) between 6 and 8 then
      prob:=prob+case
        when v_same_event_singles then 10
        when t.circuit='Challenger' then 8
        when t.circuit='ITF' then 12
        else 2
      end;
    else
      prob:=prob-case
        when v_same_event_singles then 3
        when t.circuit='ITF' then 8
        when t.circuit='Challenger' then 14
        else 18
      end;
    end if;
  end if;

  if v_doubles_events>=coalesce(sp.target_events,24)+3 then
    prob:=prob-22;
  end if;

  if coalesce(p.fatigue,20)>=v_rest_trigger then
    prob:=prob-20;
  end if;

  prob:=greatest(4,least(99,prob));
  roll:=(mod(abs(hashtext(
    'ai-double-commit-v20|'||t.id::text||'|'||p.id::text
  )),10000)::numeric)/100.0;

  return roll<prob;
end;
$function$;

create or replace function public.select_pro_doubles_field_v20(
  p_tournament_id bigint,
  p_managed_player_id bigint default null
)
returns table(
  pair_id bigint,
  entry_method text,
  score numeric,
  merit_tier integer,
  combined_rank bigint,
  source_label text
)
language plpgsql
stable
set search_path to 'public'
as $function$
declare
  t public.tournaments%rowtype;
  v_year int;
  v_draw int;
  v_da int:=0;
  v_wc int:=0;
  v_onsite int:=0;
  v_q_da int:=0;
  v_q_wc int:=0;
begin
  select * into t
  from public.tournaments
  where id=p_tournament_id;

  if t.id is null
     or coalesce(t.circuit,'') not in ('ATP','Challenger')
     or t.category in ('ATP Finals','Next Gen Finals','United Cup','Laver Cup','Davis Cup') then
    return;
  end if;

  v_year:=extract(year from t.start_date)::int;
  v_draw:=greatest(4,least(64,coalesce(t.doubles_draw_size,16)));

  if t.category='Grand Chelem' then
    v_wc:=least(7,v_draw);
    v_da:=v_draw-v_wc;
  elsif t.category='Masters 1000' then
    if v_draw=32 then v_da:=29;v_wc:=3;
    elsif v_draw=28 then v_da:=25;v_wc:=3;
    elsif v_draw=24 then v_da:=22;v_wc:=2;
    else
      v_wc:=least(3,greatest(0,v_draw/10));
      v_da:=v_draw-v_wc;
    end if;
  elsif t.category='ATP 500' then
    v_wc:=2;
    v_da:=greatest(0,v_draw-v_wc-1);
    v_q_da:=3;
    v_q_wc:=1;
  elsif t.category='ATP 250' then
    v_wc:=2;
    v_da:=greatest(0,v_draw-v_wc);
  elsif t.circuit='Challenger' then
    v_da:=least(10,v_draw);
    v_onsite:=least(4,greatest(0,v_draw-v_da));
    v_wc:=greatest(0,v_draw-v_da-v_onsite);
  else
    return;
  end if;

  return query
  with raw as (
    select
      w.id pair_id,
      w.pair_strength,
      w.chemistry,
      w.compatibility,
      w.affinity_score,
      w.race_rank,
      w.race_points,
      a.id a_id,
      a.country a_country,
      a.ranking a_singles,
      a.doubles_ranking a_doubles,
      a.injury_status a_injury,
      a.fitness a_fitness,
      a.fatigue a_fatigue,
      b.id b_id,
      b.country b_country,
      b.ranking b_singles,
      b.doubles_ranking b_doubles,
      b.injury_status b_injury,
      b.fitness b_fitness,
      b.fatigue b_fatigue,
      coalesce(pa.doubles,10) a_attr_doubles,
      coalesce(pb.doubles,10) b_attr_doubles,
      ((a.country is not distinct from t.country)::int+
       (b.country is not distinct from t.country)::int) home_count,
      (
        least(coalesce(a.doubles_ranking,999999),coalesce(a.ranking,999999))
        +least(coalesce(b.doubles_ranking,999999),coalesce(b.ranking,999999))
      ) approx_combined
    from public.world_doubles_partnerships w
    join public.players a on a.id=w.player_a_id
    join public.players b on b.id=w.player_b_id
    left join public.player_attributes pa on pa.player_id=a.id
    left join public.player_attributes pb on pb.player_id=b.id
    where w.season=v_year
      and w.active=true
      and a.career_status='active'
      and b.career_status='active'
      and a.id<>coalesce(p_managed_player_id,-1)
      and b.id<>coalesce(p_managed_player_id,-1)
      and coalesce(a.career_focus,'mixed')<>'singles_only'
      and coalesce(b.career_focus,'mixed')<>'singles_only'
  ),
  ranked_pre as (
    select
      r.*,
      row_number() over(
        order by r.approx_combined,r.pair_strength desc,r.pair_id
      ) rank_ord,
      row_number() over(
        order by r.home_count desc,r.pair_strength desc,r.approx_combined,r.pair_id
      ) home_ord
    from raw r
  ),
  pre as (
    select *
    from ranked_pre
    where rank_ord<=260
       or home_ord<=90
       or coalesce(race_rank,999999)<=30
       or exists(
         select 1
         from public.doubles_race_2025_full d
         where d.is_team=true
           and d.doubles_race_ranking<=13
           and (
             (d.player_one_id=ranked_pre.a_id and d.player_two_id=ranked_pre.b_id)
             or
             (d.player_one_id=ranked_pre.b_id and d.player_two_id=ranked_pre.a_id)
           )
       )
  ),
  evaluated as (
    select
      p.*,
      (
        p.pair_strength*.34+
        p.chemistry*.17+
        p.compatibility*.14+
        p.affinity_score*.05+
        p.a_attr_doubles*.20+
        p.b_attr_doubles*.20+
        coalesce(public.player_psychology_modifier(p.a_id),0)*.30+
        coalesce(public.player_psychology_modifier(p.b_id),0)*.30+
        (mod(abs(hashtext(
          'pro-dentry-v20|'||t.id||'|'||p.pair_id
        )),1000)/1000.0)*3
      )::numeric quality,
      merit.j merit,
      autoj.j auto_m1000
    from pre p
    cross join lateral (
      select public.doubles_team_entry_merit_v20(
        p.pair_id,t.id,'atp'
      ) j
    ) merit
    cross join lateral (
      select public.doubles_m1000_auto_acceptance_v20(
        p.pair_id,t.id
      ) j
    ) autoj
    where coalesce(p.a_injury,'Fit')='Fit'
      and coalesce(p.b_injury,'Fit')='Fit'
      and coalesce(p.a_fitness,90)>=48
      and coalesce(p.b_fitness,90)>=48
      and coalesce(p.a_fatigue,20)<=88
      and coalesce(p.b_fatigue,20)<=88
      and coalesce((merit.j->>'eligible')::boolean,false)
  ),
  accepted_interest as (
    select e.*
    from evaluated e
    where not (
      public.player_tournament_calendar_conflict(
        e.a_id,t.id,'doubles'
      )->>'conflict'
    )::boolean
      and not (
        public.player_tournament_calendar_conflict(
          e.b_id,t.id,'doubles'
        )->>'conflict'
      )::boolean
      and (
        coalesce((e.auto_m1000->>'eligible')::boolean,false)
        or (
          public.ai_player_commits_to_doubles_tournament(e.a_id,t.id)
          and public.ai_player_commits_to_doubles_tournament(e.b_id,t.id)
        )
      )
  ),
  ranked as (
    select
      e.*,
      row_number() over(
        order by
          case
            when coalesce((e.auto_m1000->>'eligible')::boolean,false)
              then 0 else 1
          end,
          (e.merit->>'tier')::int,
          (e.merit->>'combined_rank')::bigint,
          e.quality desc,
          e.pair_id
      ) rn
    from accepted_interest e
  ),
  da as (
    select * from ranked where rn<=v_da
  ),
  q_direct as (
    select
      r.*,
      row_number() over(
        order by
          (r.merit->>'tier')::int,
          (r.merit->>'combined_rank')::bigint,
          r.quality desc,
          r.pair_id
      ) qrn
    from ranked r
    where t.category='ATP 500'
      and not exists(
        select 1 from da d where d.pair_id=r.pair_id
      )
    limit v_q_da
  ),
  main_wc_ranked as (
    select
      r.*,
      row_number() over(
        order by
          r.home_count desc,
          r.quality desc,
          (r.merit->>'combined_rank')::bigint,
          r.pair_id
      ) wrn
    from ranked r
    where not exists(
      select 1 from da d where d.pair_id=r.pair_id
    )
      and not exists(
        select 1 from q_direct q where q.pair_id=r.pair_id
      )
  ),
  main_wc as (
    select *
    from main_wc_ranked
    where wrn<=v_wc
  ),
  q_wc_ranked as (
    select
      r.*,
      row_number() over(
        order by
          r.home_count desc,
          r.quality desc,
          (r.merit->>'combined_rank')::bigint,
          r.pair_id
      ) qwrn
    from ranked r
    where t.category='ATP 500'
      and not exists(
        select 1 from da d where d.pair_id=r.pair_id
      )
      and not exists(
        select 1 from q_direct q where q.pair_id=r.pair_id
      )
      and not exists(
        select 1 from main_wc w where w.pair_id=r.pair_id
      )
  ),
  q_wc as (
    select *
    from q_wc_ranked
    where qwrn<=v_q_wc
  ),
  onsite_ranked as (
    select
      r.*,
      row_number() over(
        order by
          (r.merit->>'tier')::int,
          (r.merit->>'combined_rank')::bigint,
          r.quality desc,
          r.pair_id
      ) orn
    from ranked r
    where t.circuit='Challenger'
      and not exists(
        select 1 from da d where d.pair_id=r.pair_id
      )
      and not exists(
        select 1 from main_wc w where w.pair_id=r.pair_id
      )
  ),
  onsite as (
    select *
    from onsite_ranked
    where orn<=v_onsite
  )
  select
    d.pair_id,
    case
      when coalesce((d.auto_m1000->>'eligible')::boolean,false)
        then 'auto_direct'
      else 'direct'
    end,
    d.quality,
    (d.merit->>'tier')::int,
    (d.merit->>'combined_rank')::bigint,
    case
      when coalesce((d.auto_m1000->>'eligible')::boolean,false)
        then 'ATP 2026 Masters 1000 doubles · automatic direct acceptance'
      when t.category='Grand Chelem'
        then 'Grand Slam 2026 men''s doubles · direct acceptance'
      else 'ATP 2026 doubles · advance direct acceptance'
    end
  from da d

  union all

  select
    w.pair_id,
    'wildcard',
    w.quality,
    99,
    999999999::bigint,
    case
      when t.category='Grand Chelem'
        then 'Grand Slam 2026 men''s doubles · wildcard'
      else 'ATP 2026 doubles · main-draw wildcard'
    end
  from main_wc w

  union all

  select
    o.pair_id,
    'onsite',
    o.quality,
    (o.merit->>'tier')::int,
    (o.merit->>'combined_rank')::bigint,
    'ATP 2026 Challenger doubles · on-site acceptance'
  from onsite o

  union all

  select
    q.pair_id,
    'qualifying',
    q.quality,
    (q.merit->>'tier')::int,
    (q.merit->>'combined_rank')::bigint,
    'ATP 2026 ATP 500 doubles qualifying · direct acceptance'
  from q_direct q

  union all

  select
    q.pair_id,
    'qualifying_wildcard',
    q.quality,
    99,
    999999999::bigint,
    'ATP 2026 ATP 500 doubles qualifying · wildcard'
  from q_wc q;
end;
$function$;
