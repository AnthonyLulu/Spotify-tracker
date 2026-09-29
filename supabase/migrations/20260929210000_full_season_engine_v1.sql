-- Court Boss full-season simulation engine v1
-- Captured from the live Supabase project on 2026-09-29.
-- Career baseline: 2025-12-01.

alter table public.davis_rubbers
  add column if not exists home_player_ids bigint[],
  add column if not exists away_player_ids bigint[];

alter table public.college_teams
  add column if not exists preseason_rank integer;

update public.college_teams
set preseason_rank=coalesce(preseason_rank,ita_rank)
where preseason_rank is null;

alter table public.college_duals
  add column if not exists competition text,
  add column if not exists stage text,
  add column if not exists bracket_slot integer,
  add column if not exists winner_team_id bigint,
  add column if not exists home_win_probability numeric,
  add column if not exists source_label text,
  add column if not exists model_version text,
  add column if not exists home_player_ids bigint[],
  add column if not exists away_player_ids bigint[];

create table if not exists public.college_championship_history(
  season integer primary key,
  champion_team_id bigint references public.college_teams(id),
  runner_up_team_id bigint references public.college_teams(id),
  final_score text,
  source_label text,
  created_at timestamptz not null default now()
);

alter table public.college_championship_history enable row level security;

create index if not exists college_duals_due_sim_idx
  on public.college_duals(status,match_date,competition);
create index if not exists college_duals_home_date_idx
  on public.college_duals(home_team_id,match_date);
create index if not exists college_duals_away_date_idx
  on public.college_duals(away_team_id,match_date);
create index if not exists davis_ties_status_date_idx
  on public.davis_ties(status,tie_date);
create index if not exists davis_squad_player_nation_idx
  on public.davis_squad(player_id,nation);

update public.college_duals
set status='exhibition',
    competition='NCAA Fall Showcase',
    stage='Fall Exhibition',
    source_label='Court Boss legacy fall showcase',
    model_version='CB-NCAA-FALL-v1'
where id in (1,2,3)
  and source_label is null;

CREATE OR REPLACE FUNCTION public.player_has_world_event_in_week(p_player_id bigint, p_week_start date, p_exclude_tournament_id bigint DEFAULT NULL::bigint)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  select exists(
    select 1
    from public.world_tournament_entries e
    join public.tournaments t on t.id=e.tournament_id
    where e.player_id=p_player_id
      and t.id is distinct from p_exclude_tournament_id
      and date_trunc('week',coalesce(t.main_draw_start_date,t.start_date)::timestamp)::date=p_week_start
    union all
    select 1
    from public.world_tournament_qualifying_entries e
    join public.tournaments t on t.id=e.tournament_id
    where e.player_id=p_player_id
      and t.id is distinct from p_exclude_tournament_id
      and date_trunc('week',coalesce(t.main_draw_start_date,t.start_date)::timestamp)::date=p_week_start
    union all
    select 1
    from public.world_doubles_tournament_entries e
    join public.world_doubles_partnerships p on p.id=e.pair_id
    join public.tournaments t on t.id=e.tournament_id
    where p_player_id in (p.player_a_id,p.player_b_id)
      and t.id is distinct from p_exclude_tournament_id
      and date_trunc('week',coalesce(t.main_draw_start_date,t.start_date)::timestamp)::date=p_week_start
    union all
    select 1
    from public.world_junior_doubles_entries e
    join public.tournaments t on t.id=e.tournament_id
    where p_player_id in (e.player_a_id,e.player_b_id)
      and t.id is distinct from p_exclude_tournament_id
      and date_trunc('week',coalesce(t.main_draw_start_date,t.start_date)::timestamp)::date=p_week_start
    union all
    select 1
    from public.davis_squad ds
    join public.davis_ties dt on ds.nation in (dt.home_nation,dt.away_nation)
    where ds.player_id=p_player_id
      and dt.status in ('scheduled','completed')
      and date_trunc('week',dt.tie_date::timestamp)::date=p_week_start
    union all
    select 1
    from public.players pl
    join public.college_teams ct on ct.name=pl.ncaa_school
    join public.college_duals cd on ct.id in (cd.home_team_id,cd.away_team_id)
    where pl.id=p_player_id
      and pl.ncaa_current=true
      and cd.status in ('scheduled','completed')
      and date_trunc('week',cd.match_date::timestamp)::date=p_week_start
  );
$function$;

CREATE OR REPLACE FUNCTION public.player_recent_match_load(p_player_id bigint, p_date date)
 RETURNS integer
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  select coalesce(sum(x.matches),0)::int
  from (
    select count(*)::int matches
    from public.world_tournament_matches m
    where m.simulated_on between p_date-13 and p_date
      and p_player_id in (m.player_a_id,m.player_b_id)
    union all
    select count(*)::int
    from public.world_doubles_tournament_matches m
    join public.world_doubles_partnerships a on a.id=m.pair_a_id
    join public.world_doubles_partnerships b on b.id=m.pair_b_id
    where m.simulated_on between p_date-13 and p_date
      and (
        p_player_id in (a.player_a_id,a.player_b_id)
        or p_player_id in (b.player_a_id,b.player_b_id)
      )
    union all
    select count(*)::int
    from public.world_junior_doubles_matches m
    join public.world_junior_doubles_entries a on a.id=m.pair_a_entry_id
    join public.world_junior_doubles_entries b on b.id=m.pair_b_entry_id
    where m.simulated_on between p_date-13 and p_date
      and (
        p_player_id in (a.player_a_id,a.player_b_id)
        or p_player_id in (b.player_a_id,b.player_b_id)
      )
    union all
    select count(*)::int
    from public.davis_rubbers r
    join public.davis_ties t on t.id=r.tie_id
    where t.tie_date between p_date-13 and p_date
      and (
        p_player_id=any(coalesce(r.home_player_ids,'{}'::bigint[]))
        or p_player_id=any(coalesce(r.away_player_ids,'{}'::bigint[]))
      )
    union all
    select count(*)::int
    from public.college_duals d
    where d.match_date between p_date-13 and p_date
      and d.status='completed'
      and (
        p_player_id=any(coalesce(d.home_player_ids,'{}'::bigint[]))
        or p_player_id=any(coalesce(d.away_player_ids,'{}'::bigint[]))
      )
  ) x;
$function$;

CREATE OR REPLACE FUNCTION public.player_tournament_calendar_conflict(p_player_id bigint, p_tournament_id bigint, p_entry_method text DEFAULT 'direct'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  method text:=lower(coalesce(p_entry_method,'direct'));
  commit_start date;
  commit_end date;
  week_monday date;
  managed_id bigint;
  c record;
begin
  select * into t from public.tournaments where id=p_tournament_id;
  if t.id is null then
    return jsonb_build_object('conflict',true,'reason','tournament_not_found');
  end if;

  select managed_player_id into managed_id from public.career_state where id='demo';

  week_monday:=date_trunc('week',coalesce(t.main_draw_start_date,t.start_date)::timestamp)::date;
  commit_start:=case
    when method in ('qualifying','qualifying_wildcard','protected_qualifying','doubles_qualifying')
      then coalesce(t.qualifying_start_date,t.main_draw_start_date,t.start_date)
    else coalesce(t.main_draw_start_date,t.start_date)
  end;
  commit_end:=coalesce(t.end_date,t.start_date);

  select dt.id tournament_id,
         'Davis Cup · '||dt.home_nation||' v '||dt.away_nation tournament_name,
         dt.tie_date start_date,dt.tie_date end_date,'davis'::text discipline
  into c
  from public.davis_squad ds
  join public.davis_ties dt on ds.nation in (dt.home_nation,dt.away_nation)
  where ds.player_id=p_player_id
    and dt.status in ('scheduled','completed')
    and date_trunc('week',dt.tie_date::timestamp)::date=week_monday
  order by dt.tie_date,dt.id
  limit 1;

  if c.tournament_id is not null then
    return jsonb_build_object(
      'conflict',true,'reason','national_team_commitment',
      'other_davis_tie_id',c.tournament_id,'other_event',c.tournament_name,
      'other_discipline','davis'
    );
  end if;

  select cd.id tournament_id,
         'NCAA · '||h.name||' v '||a.name tournament_name,
         cd.match_date start_date,cd.match_date end_date,'ncaa'::text discipline
  into c
  from public.players pl
  join public.college_teams ct on ct.name=pl.ncaa_school
  join public.college_duals cd on ct.id in (cd.home_team_id,cd.away_team_id)
  join public.college_teams h on h.id=cd.home_team_id
  join public.college_teams a on a.id=cd.away_team_id
  where pl.id=p_player_id
    and pl.ncaa_current=true
    and cd.status in ('scheduled','completed')
    and date_trunc('week',cd.match_date::timestamp)::date=week_monday
  order by cd.match_date,cd.id
  limit 1;

  if c.tournament_id is not null then
    return jsonb_build_object(
      'conflict',true,'reason','college_team_commitment',
      'other_college_dual_id',c.tournament_id,'other_event',c.tournament_name,
      'other_discipline','ncaa'
    );
  end if;

  select x.tournament_id,x.tournament_name,x.start_date,x.end_date,x.discipline
  into c
  from (
    select ot.id tournament_id,ot.name tournament_name,ot.start_date,ot.end_date,'singles'::text discipline
    from public.world_tournament_entries e
    join public.tournaments ot on ot.id=e.tournament_id
    where e.player_id=p_player_id and ot.id<>t.id
      and date_trunc('week',coalesce(ot.main_draw_start_date,ot.start_date)::timestamp)::date=week_monday

    union all

    select ot.id,ot.name,ot.start_date,ot.end_date,'qualifying'
    from public.world_tournament_qualifying_entries e
    join public.tournaments ot on ot.id=e.tournament_id
    where e.player_id=p_player_id and ot.id<>t.id
      and date_trunc('week',coalesce(ot.main_draw_start_date,ot.start_date)::timestamp)::date=week_monday

    union all

    select ot.id,ot.name,ot.start_date,ot.end_date,'doubles'
    from public.world_doubles_tournament_entries e
    join public.world_doubles_partnerships p on p.id=e.pair_id
    join public.tournaments ot on ot.id=e.tournament_id
    where p_player_id in (p.player_a_id,p.player_b_id) and ot.id<>t.id
      and date_trunc('week',coalesce(ot.main_draw_start_date,ot.start_date)::timestamp)::date=week_monday

    union all

    select ot.id,ot.name,ot.start_date,ot.end_date,'junior_doubles'
    from public.world_junior_doubles_entries e
    join public.tournaments ot on ot.id=e.tournament_id
    where p_player_id in (e.player_a_id,e.player_b_id) and ot.id<>t.id
      and date_trunc('week',coalesce(ot.main_draw_start_date,ot.start_date)::timestamp)::date=week_monday
  ) x
  order by x.start_date,x.tournament_id
  limit 1;

  if c.tournament_id is not null then
    return jsonb_build_object(
      'conflict',true,'reason','one_tournament_per_week',
      'other_tournament_id',c.tournament_id,'other_tournament',c.tournament_name,
      'other_discipline',c.discipline
    );
  end if;

  if managed_id is not null and p_player_id=managed_id then
    select x.tournament_id,x.tournament_name,x.start_date,x.end_date,x.discipline
    into c
    from (
      select tr.tournament_id,ot.name tournament_name,ot.start_date,ot.end_date,'singles'::text discipline,
             coalesce(ot.main_draw_start_date,ot.start_date) main_start
      from public.tournament_runs tr
      join public.tournaments ot on ot.id=tr.tournament_id
      where tr.tournament_id<>t.id
      union all
      select dr.tournament_id,ot.name,ot.start_date,ot.end_date,'doubles',
             coalesce(ot.main_draw_start_date,ot.start_date) main_start
      from public.doubles_runs dr
      join public.tournaments ot on ot.id=dr.tournament_id
      where dr.tournament_id<>t.id
    ) x
    where date_trunc('week',x.main_start::timestamp)::date=week_monday
    order by x.main_start
    limit 1;

    if c.tournament_id is not null then
      return jsonb_build_object(
        'conflict',true,'reason','one_tournament_per_week',
        'other_tournament_id',c.tournament_id,'other_tournament',c.tournament_name,
        'other_discipline',c.discipline
      );
    end if;
  end if;

  if method in ('qualifying','qualifying_wildcard','protected_qualifying','doubles_qualifying') then
    select x.tournament_id,x.tournament_name,x.result_code,x.discipline
    into c
    from (
      select ot.id tournament_id,ot.name tournament_name,e.result_code,'singles'::text discipline,
             coalesce(ot.end_date,ot.start_date) event_end,
             coalesce(ot.main_draw_start_date,ot.start_date) main_start
      from public.world_tournament_entries e
      join public.tournaments ot on ot.id=e.tournament_id
      where e.player_id=p_player_id and ot.id<>t.id

      union all

      select ot.id,ot.name,e.result_code,'doubles',
             coalesce(ot.end_date,ot.start_date),
             coalesce(ot.main_draw_start_date,ot.start_date)
      from public.world_doubles_tournament_entries e
      join public.world_doubles_partnerships p on p.id=e.pair_id
      join public.tournaments ot on ot.id=e.tournament_id
      where p_player_id in (p.player_a_id,p.player_b_id) and ot.id<>t.id

      union all

      select ot.id,ot.name,e.result_code,'junior_doubles',
             coalesce(ot.end_date,ot.start_date),
             coalesce(ot.main_draw_start_date,ot.start_date)
      from public.world_junior_doubles_entries e
      join public.tournaments ot on ot.id=e.tournament_id
      where p_player_id in (e.player_a_id,e.player_b_id) and ot.id<>t.id
    ) x
    where x.event_end>=commit_start
      and x.main_start<week_monday
      and coalesce(x.result_code,'') in ('W','F','SF')
    order by x.event_end desc
    limit 1;

    if c.tournament_id is not null then
      return jsonb_build_object(
        'conflict',true,'reason','still_competing_before_qualifying',
        'other_tournament_id',c.tournament_id,'other_tournament',c.tournament_name,
        'other_result',c.result_code,'other_discipline',c.discipline,
        'qualifying_start',commit_start
      );
    end if;
  end if;

  return jsonb_build_object(
    'conflict',false,'reason','available',
    'commitment_start',commit_start,'commitment_end',commit_end,'week_monday',week_monday
  );
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

CREATE OR REPLACE FUNCTION public.ai_player_commits_to_doubles_tournament(p_player_id bigint, p_tournament_id bigint)
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
  v_week date;
  v_i int;
  v_consecutive int:=0;
  v_max_consecutive int;
  v_rest_trigger int;
  v_doubles_bias int;
  v_doubles_events int:=0;
  v_same_event_singles boolean:=false;
begin
  select * into p from public.players where id=p_player_id;
  select * into t from public.tournaments where id=p_tournament_id;
  if p.id is null or t.id is null then return false; end if;
  if coalesce(p.career_focus,'mixed')='singles_only' then return false; end if;

  if t.circuit='ITF' and coalesce(p.ranking,999999)<=200 then return false; end if;
  if t.circuit='ITF' and coalesce(p.doubles_ranking,999999)<=150 then return false; end if;
  if t.circuit='Challenger' and coalesce(p.ranking,999999)<=10 then return false; end if;
  if t.category='Challenger 50' and coalesce(p.ranking,999999)<=50 then return false; end if;
  if t.category='Challenger 75' and coalesce(p.ranking,999999)<=30 then return false; end if;

  if (public.player_tournament_calendar_conflict(p.id,t.id,'doubles')->>'conflict')::boolean then return false; end if;

  select * into sp
  from public.player_season_plans s
  where s.player_id=p.id and s.season=extract(year from t.start_date)::int;

  v_week:=date_trunc('week',coalesce(t.main_draw_start_date,t.start_date)::timestamp)::date;
  v_max_consecutive:=greatest(1,coalesce(sp.max_consecutive_weeks,case when p.age>=32 then 2 else 3 end));
  v_rest_trigger:=coalesce(sp.rest_trigger_fatigue,72);
  v_doubles_bias:=coalesce(sp.doubles_bias,
    case coalesce(p.career_focus,'mixed')
      when 'doubles_only' then 20
      when 'mixed' then 14
      when 'singles_priority' then 7
      else 10 end
  );

  for v_i in 1..5 loop
    if public.player_has_world_event_in_week(p.id,v_week-(v_i*7),null) then
      v_consecutive:=v_consecutive+1;
    else
      exit;
    end if;
  end loop;

  if v_consecutive>=v_max_consecutive
     and coalesce(t.category,'') not in ('Grand Chelem','Masters 1000','ATP Finals') then
    return false;
  end if;
  if coalesce(p.fatigue,20)>=v_rest_trigger+10
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
    select 1 from public.world_tournament_entries e
    where e.tournament_id=t.id and e.player_id=p.id
  ) into v_same_event_singles;

  prob:=case
    when t.category='Grand Chelem' then 90
    when t.category='Masters 1000' then 84
    when t.category='ATP 500' then 76
    when t.category='ATP 250' then 74
    when t.circuit='Challenger' then 72
    when t.circuit='ITF' then 70
    when t.circuit='Junior' then 82
    else 68 end;

  prob:=prob+(v_doubles_bias-10)*2.1;

  prob:=prob+case coalesce(p.career_focus,'mixed')
    when 'doubles_only' then 18
    when 'mixed' then 5
    when 'singles_priority' then -10
    else 0 end;

  if coalesce(p.doubles_ranking,999999)<=50 then prob:=prob+10;
  elsif coalesce(p.doubles_ranking,999999)<=200 then prob:=prob+5;
  end if;

  if v_same_event_singles then prob:=prob+12; end if;

  if v_doubles_events>=coalesce(sp.target_events,24)+3 then prob:=prob-22; end if;
  if coalesce(p.fatigue,20)>=v_rest_trigger then prob:=prob-20; end if;

  prob:=greatest(4,least(99,prob));
  roll:=(mod(abs(hashtext('ai-double-commit-v2|'||t.id::text||'|'||p.id::text)),10000)::numeric)/100.0;
  return roll<prob;
end;
$function$;

CREATE OR REPLACE FUNCTION public.simulate_junior_world_singles_full(p_from_date date, p_to_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  v_managed bigint;
  v_draw int;
  v_bracket int;
  v_rounds int;
  v_size int;
  v_round int;
  v_pos int;
  v_next int;
  v_a bigint;
  v_b bigint;
  v_w bigint;
  v_l bigint;
  v_a_name text;
  v_b_name text;
  v_w_name text;
  v_l_name text;
  v_match jsonb;
  v_prob numeric;
  v_awon boolean;
  v_score text;
  v_code text;
  v_winner bigint;
  v_finalist bigint;
  v_singles int:=0;
  v_matches int:=0;
  v_selected int;
  rr record;
begin
  select managed_player_id into v_managed from public.career_state where id='demo';

  for t in
    select *
    from public.tournaments
    where circuit='Junior'
      and singles=true
      and coalesce(is_active,true)=true
      and coalesce(end_date,start_date)>p_from_date
      and coalesce(end_date,start_date)<=p_to_date
      and category not in ('Junior Davis Cup','Junior Finals','Junior Double Finals')
      and not exists(select 1 from public.world_tournament_simulations s where s.tournament_id=tournaments.id)
    order by coalesce(end_date,start_date),id
    limit 100
  loop
    v_draw:=greatest(16,least(64,coalesce(t.singles_draw_size,t.draw_size,32)));

    drop table if exists pg_temp.cb_j_entries;
    create temporary table cb_j_entries(
      player_id bigint primary key,
      name text not null,
      rank_at_entry int,
      seed int,
      draw_slot int,
      group_name text,
      wins int not null default 0,
      losses int not null default 0,
      result_code text,
      result_label text,
      points_awarded int not null default 0,
      last_opponent_id bigint,
      last_opponent_name text,
      last_score text
    ) on commit drop;

    insert into cb_j_entries(player_id,name,rank_at_entry,seed)
    select p.id,p.name,
           coalesce(p.junior_ranking,999999)::int,
           row_number() over(order by coalesce(p.junior_ranking,999999),p.current_ability desc,p.id)::int
    from public.players p
    where p.career_status='active'
      and p.id is distinct from v_managed
      and p.junior_ranking is not null
      and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
      and p.injury_status='Fit'
      and coalesce(p.fitness,90)>=45
      and coalesce(p.fatigue,20)<=90
      and (
        p.birth_date is null
        or (
          p.birth_date<=t.start_date-interval '13 years'
          and extract(year from t.start_date)::int-extract(year from p.birth_date)::int<=18
        )
      )
      and not (public.player_tournament_calendar_conflict(p.id,t.id,'direct')->>'conflict')::boolean
      and public.ai_player_commits_to_tournament(p.id,t.id)
    order by coalesce(p.junior_ranking,999999),p.current_ability desc,p.id
    limit v_draw;

    select count(*) into v_selected from cb_j_entries;
    if v_selected<>v_draw then
      continue;
    end if;

    delete from public.world_tournament_matches where tournament_id=t.id;
    delete from public.world_tournament_entries where tournament_id=t.id;

    if t.junior_draw_format='round_robin_to_elimination'
       and t.category in ('J30','J60') and v_draw=32 then

      update cb_j_entries
      set group_name=chr(65+((seed-1)%8))
      where seed<=8;

      with rem as (
        select player_id,row_number() over(order by md5('jrr|'||t.id::text||'|'||player_id::text)) rn
        from cb_j_entries where group_name is null
      )
      update cb_j_entries e
      set group_name=chr(65+(((r.rn-1)%8)::int))
      from rem r where e.player_id=r.player_id;

      for rr in
        select a.player_id a_id,b.player_id b_id,a.name a_name,b.name b_name,a.group_name,
               row_number() over(order by a.group_name,a.seed,b.seed)::int match_no
        from cb_j_entries a
        join cb_j_entries b on b.group_name=a.group_name and b.seed>a.seed
        order by a.group_name,a.seed,b.seed
      loop
        v_a:=rr.a_id;v_b:=rr.b_id;v_a_name:=rr.a_name;v_b_name:=rr.b_name;
        v_match:=public.player_matchup_probability_v4(
          v_a,v_b,t.surface,t.start_date,
          coalesce(t.court_speed,case when t.surface ilike 'Terre%' then .68 when t.surface ilike 'Gazon%' then 1.15 else 1.0 end),3
        );
        v_prob:=greatest(.02,least(.98,coalesce((v_match->>'player_a_probability')::numeric,.5)));
        v_awon:=random()<v_prob;
        v_w:=case when v_awon then v_a else v_b end;
        v_l:=case when v_awon then v_b else v_a end;
        v_w_name:=case when v_awon then v_a_name else v_b_name end;
        v_l_name:=case when v_awon then v_b_name else v_a_name end;
        v_score:=public.world_tournament_score(v_prob,v_awon,3);

        insert into public.world_tournament_matches(
          tournament_id,round_no,round_code,group_name,match_no,
          player_a_id,player_b_id,winner_id,loser_id,score,best_of,
          player_a_win_probability,court_speed,model_version,matchup_components,simulated_on
        ) values(
          t.id,1,'RR',rr.group_name,rr.match_no,v_a,v_b,v_w,v_l,v_score,3,round(v_prob,4),
          coalesce(t.court_speed,1.0),'CB-JUNIOR-v4-ROUNDROBIN',
          coalesce(v_match->'components','{}'::jsonb),t.start_date
        );
        v_matches:=v_matches+1;

        update cb_j_entries
        set wins=wins+1,last_opponent_id=v_l,last_opponent_name=v_l_name,
            last_score=case when v_w=v_a then v_score else public.world_invert_tennis_score(v_score) end
        where player_id=v_w;
        update cb_j_entries
        set losses=losses+1,last_opponent_id=v_w,last_opponent_name=v_w_name,
            last_score=case when v_l=v_a then v_score else public.world_invert_tennis_score(v_score) end
        where player_id=v_l;
      end loop;

      drop table if exists pg_temp.cb_j_rr_rank;
      create temporary table cb_j_rr_rank on commit drop as
      select player_id,group_name,wins,
             row_number() over(partition by group_name order by wins desc,seed asc)::int group_pos
      from cb_j_entries;

      update cb_j_entries e
      set result_code='RR'||r.group_pos::text,
          result_label='Groupe · position '||r.group_pos::text,
          points_awarded=case
            when r.group_pos=2 then case when t.category='J60' then 5 else 2 end
            when r.group_pos in (3,4) and e.wins>0 then case when t.category='J60' then 2 else 1 end
            else 0 end
      from cb_j_rr_rank r
      where e.player_id=r.player_id and r.group_pos>1;

      drop table if exists pg_temp.cb_j_current;
      drop table if exists pg_temp.cb_j_next;
      create temporary table cb_j_current(pos int primary key,player_id bigint) on commit drop;
      create temporary table cb_j_next(pos int primary key,player_id bigint) on commit drop;

      insert into cb_j_current(pos,player_id)
      select row_number() over(order by group_name)::int,player_id
      from cb_j_rr_rank where group_pos=1 order by group_name;

      v_size:=8;
      v_round:=2;
      while v_size>1 loop
        truncate cb_j_next;
        v_next:=0;
        v_code:=case when v_size=8 then 'QF' when v_size=4 then 'SF' else 'F' end;

        for v_pos in 1..v_size by 2 loop
          v_next:=v_next+1;
          select player_id into v_a from cb_j_current where pos=v_pos;
          select player_id into v_b from cb_j_current where pos=v_pos+1;
          select name into v_a_name from cb_j_entries where player_id=v_a;
          select name into v_b_name from cb_j_entries where player_id=v_b;

          v_match:=public.player_matchup_probability_v4(v_a,v_b,t.surface,t.end_date,coalesce(t.court_speed,1.0),3);
          v_prob:=greatest(.02,least(.98,coalesce((v_match->>'player_a_probability')::numeric,.5)));
          v_awon:=random()<v_prob;
          v_w:=case when v_awon then v_a else v_b end;
          v_l:=case when v_awon then v_b else v_a end;
          v_w_name:=case when v_awon then v_a_name else v_b_name end;
          v_l_name:=case when v_awon then v_b_name else v_a_name end;
          v_score:=public.world_tournament_score(v_prob,v_awon,3);

          insert into public.world_tournament_matches(
            tournament_id,round_no,round_code,match_no,player_a_id,player_b_id,winner_id,loser_id,
            score,best_of,player_a_win_probability,court_speed,model_version,matchup_components,simulated_on
          ) values(
            t.id,v_round,v_code,v_next,v_a,v_b,v_w,v_l,v_score,3,round(v_prob,4),
            coalesce(t.court_speed,1.0),'CB-JUNIOR-v4-ROUNDROBIN',
            coalesce(v_match->'components','{}'::jsonb),t.end_date
          );
          v_matches:=v_matches+1;

          update cb_j_entries
          set result_code=v_code,
              result_label=case v_code when 'QF' then 'Quart de finale' when 'SF' then 'Demi-finale' else 'Finaliste' end,
              points_awarded=public.junior_points_for('singles',t.category,v_code),
              last_opponent_id=v_w,last_opponent_name=v_w_name,
              last_score=case when v_l=v_a then v_score else public.world_invert_tennis_score(v_score) end
          where player_id=v_l;
          update cb_j_entries set wins=wins+1 where player_id=v_w;
          insert into cb_j_next values(v_next,v_w);
        end loop;

        truncate cb_j_current;
        insert into cb_j_current select * from cb_j_next;
        v_size:=v_size/2;
        v_round:=v_round+1;
      end loop;

      select player_id into v_winner from cb_j_current limit 1;
      update cb_j_entries
      set result_code='W',result_label='Vainqueur',
          points_awarded=public.junior_points_for('singles',t.category,'W')
      where player_id=v_winner;

    else
      v_bracket:=case when v_draw<=16 then 16 when v_draw<=32 then 32 else 64 end;
      v_rounds:=ceil(ln(v_bracket::numeric)/ln(2::numeric))::int;

      update cb_j_entries
      set draw_slot=public.world_tournament_seed_slot(v_bracket,seed)
      where seed<=least(case when v_bracket>=64 then 16 else 8 end,v_draw);

      with bye_slots as (
        select case when draw_slot%2=1 then draw_slot+1 else draw_slot-1 end slot
        from cb_j_entries
        where v_bracket>v_draw and seed<=least(v_bracket-v_draw,v_draw) and draw_slot is not null
      ),
      used as (
        select draw_slot slot from cb_j_entries where draw_slot is not null
        union all select slot from bye_slots
      ),
      avail as (
        select g slot,row_number() over(order by md5('jslot|'||t.id::text||'|'||g::text)) rn
        from generate_series(1,v_bracket) g
        where not exists(select 1 from used u where u.slot=g)
      ),
      unplaced as (
        select player_id,row_number() over(order by md5('jplayer|'||t.id::text||'|'||player_id::text)) rn
        from cb_j_entries where draw_slot is null
      )
      update cb_j_entries e
      set draw_slot=a.slot
      from unplaced u join avail a using(rn)
      where e.player_id=u.player_id;

      drop table if exists pg_temp.cb_j_current;
      drop table if exists pg_temp.cb_j_next;
      create temporary table cb_j_current(pos int primary key,player_id bigint) on commit drop;
      create temporary table cb_j_next(pos int primary key,player_id bigint) on commit drop;

      insert into cb_j_current(pos,player_id)
      select g,e.player_id
      from generate_series(1,v_bracket) g
      left join cb_j_entries e on e.draw_slot=g;

      v_size:=v_bracket;
      for v_round in 1..v_rounds loop
        truncate cb_j_next;
        v_next:=0;
        v_code:=case when v_size>=64 then 'R64' when v_size>=32 then 'R32' when v_size>=16 then 'R16'
                     when v_size>=8 then 'QF' when v_size>=4 then 'SF' else 'F' end;

        for v_pos in 1..v_size by 2 loop
          v_next:=v_next+1;
          select player_id into v_a from cb_j_current where pos=v_pos;
          select player_id into v_b from cb_j_current where pos=v_pos+1;

          if v_a is null and v_b is null then
            insert into cb_j_next(pos,player_id) values(v_next,null);
            continue;
          elsif v_a is null or v_b is null then
            insert into cb_j_next(pos,player_id) values(v_next,coalesce(v_a,v_b));
            continue;
          end if;

          select name into v_a_name from cb_j_entries where player_id=v_a;
          select name into v_b_name from cb_j_entries where player_id=v_b;
          v_match:=public.player_matchup_probability_v4(v_a,v_b,t.surface,t.end_date,coalesce(t.court_speed,1.0),3);
          v_prob:=greatest(.02,least(.98,coalesce((v_match->>'player_a_probability')::numeric,.5)));
          v_awon:=random()<v_prob;
          v_w:=case when v_awon then v_a else v_b end;
          v_l:=case when v_awon then v_b else v_a end;
          v_w_name:=case when v_awon then v_a_name else v_b_name end;
          v_l_name:=case when v_awon then v_b_name else v_a_name end;
          v_score:=public.world_tournament_score(v_prob,v_awon,3);

          insert into public.world_tournament_matches(
            tournament_id,round_no,round_code,match_no,player_a_id,player_b_id,winner_id,loser_id,
            score,best_of,player_a_win_probability,court_speed,model_version,matchup_components,simulated_on
          ) values(
            t.id,v_round,v_code,v_next,v_a,v_b,v_w,v_l,v_score,3,round(v_prob,4),
            coalesce(t.court_speed,1.0),'CB-JUNIOR-v4-FULLDRAW',
            coalesce(v_match->'components','{}'::jsonb),t.end_date
          );
          v_matches:=v_matches+1;

          update cb_j_entries
          set result_code=v_code,
              result_label=public.world_tournament_result_label(v_code),
              points_awarded=public.junior_points_for('singles',t.category,v_code),
              last_opponent_id=v_w,last_opponent_name=v_w_name,
              last_score=case when v_l=v_a then v_score else public.world_invert_tennis_score(v_score) end
          where player_id=v_l;
          update cb_j_entries set wins=wins+1 where player_id=v_w;
          insert into cb_j_next values(v_next,v_w);
        end loop;

        truncate cb_j_current;
        insert into cb_j_current select * from cb_j_next;
        v_size:=greatest(1,v_size/2);
      end loop;

      select player_id into v_winner from cb_j_current order by pos limit 1;
      update cb_j_entries
      set result_code='W',result_label='Vainqueur',
          points_awarded=public.junior_points_for('singles',t.category,'W')
      where player_id=v_winner;
    end if;

    select loser_id into v_finalist
    from public.world_tournament_matches
    where tournament_id=t.id and round_code='F'
    order by id desc limit 1;

    insert into public.world_tournament_entries(
      tournament_id,player_id,seed,draw_slot,entry_method,ranking_at_entry,had_bye,matches_won,
      result_code,result_label,points_awarded,qualifying_points,last_opponent_id,last_opponent_name,
      last_score,simulated_on,source_label
    )
    select t.id,player_id,seed,coalesce(draw_slot,seed),'junior',rank_at_entry,false,wins,
           result_code,result_label,points_awarded,0,last_opponent_id,last_opponent_name,last_score,
           t.end_date,'Court Boss junior full draw · '||t.junior_draw_format
    from cb_j_entries;

    update public.players p
    set junior_game_points=coalesce(p.junior_game_points,0)+e.points_awarded,
        form=greatest(35,least(100,p.form+case e.result_code when 'W' then 4 when 'F' then 3 when 'SF' then 2 else 0 end)),
        morale=greatest(30,least(100,p.morale+case e.result_code when 'W' then 4 when 'F' then 2 else 0 end))
    from cb_j_entries e
    where p.id=e.player_id;

    insert into public.player_tournament_history(
      player_id,season,tournament_id,tournament_name,tournament_date,level,category,surface,
      result_code,result_label,last_opponent,last_score,is_grand_slam,source,event_type
    )
    select player_id,extract(year from t.end_date)::int,t.id::text,t.name,t.end_date,t.category,t.category,t.surface,
           result_code,result_label,last_opponent_name,last_score,t.category='Junior Grand Slam',
           'Court Boss junior full draw','junior_singles'
    from cb_j_entries
    on conflict(player_id,event_type,tournament_id) do update set
      result_code=excluded.result_code,result_label=excluded.result_label,last_opponent=excluded.last_opponent,
      last_score=excluded.last_score,source=excluded.source;

    select name into v_w_name from public.players where id=v_winner;
    select name into v_l_name from public.players where id=v_finalist;

    insert into public.player_titles(
      player_id,tournament_name,title_date,level,surface,event_type,verified,source_label,origin
    )
    values(v_winner,t.name,t.end_date,t.category,t.surface,'junior_singles',false,'Court Boss junior full draw','game')
    on conflict(player_id,tournament_name,title_date,event_type) do nothing;

    insert into public.player_final_results(
      player_id,tournament_name,final_date,level,surface,result,opponent_name,source,event_type
    )
    values
      (v_winner,t.name,t.end_date,t.category,t.surface,'Champion',v_l_name,'Court Boss junior full draw','junior_singles'),
      (v_finalist,t.name,t.end_date,t.category,t.surface,'Finaliste',v_w_name,'Court Boss junior full draw','junior_singles')
    on conflict(player_id,tournament_name,final_date,result) do nothing;

    insert into public.world_tournament_simulations(
      tournament_id,winner_id,finalist_id,winner_points,finalist_points,simulated_on,
      model_version,rule_key,draw_size,bracket_size,rounds_count,matches_simulated,participants_simulated,format_type
    ) values(
      t.id,v_winner,v_finalist,
      public.junior_points_for('singles',t.category,'W'),
      public.junior_points_for('singles',t.category,'F'),t.end_date,
      case when t.junior_draw_format='round_robin_to_elimination' then 'CB-JUNIOR-v4-RR' else 'CB-JUNIOR-v4-FULLDRAW' end,
      'JUNIOR_'||replace(t.category,' ','_')||'_'||v_draw,
      v_draw,
      case when v_draw<=16 then 16 when v_draw<=32 then 32 else 64 end,
      case when t.junior_draw_format='round_robin_to_elimination' then 4
           else ceil(ln((case when v_draw<=16 then 16 when v_draw<=32 then 32 else 64 end)::numeric)/ln(2::numeric))::int end,
      (select count(*) from public.world_tournament_matches where tournament_id=t.id),
      v_draw,t.junior_draw_format
    );

    v_singles:=v_singles+1;
  end loop;

  return jsonb_build_object(
    'singles_simulated',v_singles,'matches_simulated',v_matches,
    'from',p_from_date,'to',p_to_date,'model','CB-JUNIOR-v4 full draw / RR hybrid'
  );
end
$function$;

CREATE OR REPLACE FUNCTION public.simulate_world_doubles_tournaments(p_from_date date, p_to_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  v_year int;
  v_managed bigint;
  v_draw int;
  v_bracket int;
  v_byes int;
  v_rounds int;
  v_round int;
  v_size int;
  v_pos int;
  v_next int;
  v_a bigint;
  v_b bigint;
  v_w bigint;
  v_l bigint;
  v_match jsonb;
  v_prob numeric;
  v_awon boolean;
  v_score text;
  v_round_code text;
  v_points int;
  v_prize numeric;
  v_winner bigint;
  v_finalist bigint;
  v_matches int:=0;
  v_simulated int:=0;
  v_selected int;
  v_qdraw int:=0;
  v_qslots int:=0;
  v_wc_count int:=0;
  v_pool_needed int:=0;
  v_seed_limit int:=0;
  v_qw1 bigint;
  v_qw2 bigint;
  v_qwinner bigint;
  entry_rec record;
  match_rec record;
begin
  perform pg_advisory_xact_lock(94832021);
  if p_to_date<=date '2025-12-01' then
    return jsonb_build_object('tournaments_simulated',0,'historical_cutoff',true);
  end if;
  select managed_player_id into v_managed from public.career_state where id='demo';

  for t in
    select *
    from public.tournaments
    where doubles=true and coalesce(is_active,true)=true
      and coalesce(end_date,start_date)>greatest(p_from_date,date '2025-12-01')
      and coalesce(end_date,start_date)<=p_to_date
      and coalesce(circuit,'') not in ('NCAA','Junior','Federation')
      and coalesce(category,'') not in ('United Cup','Laver Cup','ATP Finals')
      and not exists(select 1 from public.world_doubles_tournament_simulations s where s.tournament_id=tournaments.id)
    order by coalesce(end_date,start_date),id
    limit 120
  loop
    v_year:=extract(year from coalesce(t.end_date,t.start_date))::int;
    if not exists(select 1 from public.world_doubles_partnerships where season=v_year and active=true) then
      perform public.refresh_world_doubles_partnerships_fast(coalesce(t.start_date,p_to_date),2000);
    end if;

    v_draw:=greatest(4,least(64,coalesce(t.doubles_draw_size,16)));
    v_bracket:=case
      when v_draw<=8 then 8 when v_draw<=16 then 16 when v_draw<=32 then 32 else 64 end;
    v_byes:=v_bracket-v_draw;
    v_rounds:=ceil(ln(v_bracket::numeric)/ln(2::numeric))::int;
    v_qdraw:=case when t.circuit='ATP' and t.category='ATP 500' then 4 else 0 end;
    v_qslots:=case when v_qdraw=4 then 1 else 0 end;
    v_pool_needed:=v_draw+greatest(0,v_qdraw-v_qslots);
    v_wc_count:=case
      when t.circuit='ATP' and t.category in ('ATP 250','ATP 500') then 2
      when t.circuit='ATP' and t.category='Masters 1000' then
        case when v_draw in (28,32) then 3 when v_draw=24 then 2 else 0 end
      when t.circuit='Challenger' then 2
      else 0 end;
    v_seed_limit:=case when v_draw<=16 then 4 else 8 end;

    drop table if exists pg_temp.cb_d_entries;
    drop table if exists pg_temp.cb_d_current;
    drop table if exists pg_temp.cb_d_next;

    create temporary table cb_d_entries(
      pair_id bigint primary key,
      entry_method text not null default 'direct',
      score numeric,
      seed int,
      draw_slot int,
      had_bye boolean not null default false,
      matches_won int not null default 0,
      result_code text,
      points_awarded int not null default 0,
      prize_awarded numeric not null default 0,
      qualifying_points integer not null default 0,
      last_opponent_pair_id bigint,
      last_score text
    ) on commit drop;

    insert into cb_d_entries(pair_id,score)
    select w.id,
      (
        w.pair_strength*.34+w.chemistry*.17+w.compatibility*.14+w.affinity_score*.05+
        greatest(0,2200-coalesce(a.doubles_ranking,2200))*.005+
        greatest(0,2200-coalesce(b.doubles_ranking,2200))*.005+
        coalesce(pa.doubles,10)*.20+coalesce(pb.doubles,10)*.20+
        coalesce(public.player_psychology_modifier(a.id),0)*.30+
        coalesce(public.player_psychology_modifier(b.id),0)*.30+
        (mod(abs(hashtext('dentry|'||t.id::text||'|'||w.id::text)),1000)/1000.0)*3
      )::numeric
    from public.world_doubles_partnerships w
    join public.players a on a.id=w.player_a_id
    join public.players b on b.id=w.player_b_id
    left join public.player_attributes pa on pa.player_id=a.id
    left join public.player_attributes pb on pb.player_id=b.id
    where w.season=v_year and w.active=true
      and a.career_status='active' and b.career_status='active'
      and a.id<>coalesce(v_managed,-1) and b.id<>coalesce(v_managed,-1)
      and coalesce(a.career_focus,'mixed')<>'singles_only'
      and coalesce(b.career_focus,'mixed')<>'singles_only'
      and a.injury_status='Fit' and b.injury_status='Fit'
      and coalesce(a.fitness,90)>=48 and coalesce(b.fitness,90)>=48
      and coalesce(a.fatigue,20)<=88 and coalesce(b.fatigue,20)<=88
      and not (public.player_tournament_calendar_conflict(a.id,t.id,'doubles')->>'conflict')::boolean
      and not (public.player_tournament_calendar_conflict(b.id,t.id,'doubles')->>'conflict')::boolean
      and public.ai_player_commits_to_doubles_tournament(a.id,t.id)
      and public.ai_player_commits_to_doubles_tournament(b.id,t.id)
    order by
      case
        when t.category='Grand Chelem' then coalesce(a.doubles_ranking,999999)+coalesce(b.doubles_ranking,999999)
        when t.category='Masters 1000' then coalesce(a.doubles_ranking,999999)+coalesce(b.doubles_ranking,999999)
        else 0
      end asc,
      2 desc,w.id
    limit v_pool_needed;

    select count(*) into v_selected from cb_d_entries;
    if v_selected<>v_pool_needed then continue; end if;

    delete from public.world_doubles_qualifying_entries where tournament_id=t.id;
    delete from public.world_doubles_tournament_matches
    where tournament_id=t.id and is_qualifying=true;

    if v_qdraw=4 and v_qslots=1 then
      -- ATP 500 doubles qualifying: 4 teams, 3 direct + 1 WC, one team qualifies.
      with ranked as (
        select pair_id,score,
               row_number() over(order by score desc,pair_id)::int rn
        from cb_d_entries
      )
      update cb_d_entries e
      set entry_method='qualifying'
      from ranked rnk
      where e.pair_id=rnk.pair_id
        and rnk.rn>v_draw-1;

      -- The qualifying WC favours a home team, then pair quality.
      update cb_d_entries e
      set entry_method='qualifying_wildcard'
      where e.pair_id=(
        select q.pair_id
        from cb_d_entries q
        join public.world_doubles_partnerships w on w.id=q.pair_id
        join public.players a on a.id=w.player_a_id
        join public.players b on b.id=w.player_b_id
        where q.entry_method='qualifying'
        order by
          ((a.country is not distinct from t.country)::int+
           (b.country is not distinct from t.country)::int) desc,
          q.score desc,q.pair_id
        limit 1
      );

      insert into public.world_doubles_qualifying_entries(
        tournament_id,pair_id,seed,entry_method,result_code,qualified,simulated_on,source_label
      )
      select t.id,e.pair_id,
             row_number() over(order by e.score desc,e.pair_id)::int,
             e.entry_method,null,false,
             coalesce(t.qualifying_end_date,t.start_date),
             'ATP 2026 · ATP 500 doubles qualifying'
      from cb_d_entries e
      where e.entry_method in ('qualifying','qualifying_wildcard');

      select pair_id into v_a from cb_d_entries
      where entry_method in ('qualifying','qualifying_wildcard')
      order by score desc,pair_id limit 1;
      select pair_id into v_b from cb_d_entries
      where entry_method in ('qualifying','qualifying_wildcard')
      order by score desc,pair_id offset 3 limit 1;

      v_match:=public.doubles_pair_matchup_v2(v_a,v_b,t.surface,coalesce(t.qualifying_end_date,t.start_date));
      v_prob:=greatest(.02,least(.98,coalesce((v_match->>'pair_a_probability')::numeric,.5)));
      v_awon:=random()<v_prob;
      v_qw1:=case when v_awon then v_a else v_b end;
      v_l:=case when v_awon then v_b else v_a end;
      v_score:=public.world_tournament_score(v_prob,v_awon,3);

      insert into public.world_doubles_tournament_matches(
        tournament_id,round_no,round_code,match_no,pair_a_id,pair_b_id,winner_pair_id,loser_pair_id,
        score,pair_a_win_probability,model_version,matchup_components,simulated_on,is_qualifying
      ) values(
        t.id,-2,'DQ1',1,v_a,v_b,v_qw1,v_l,v_score,round(v_prob,4),
        'CB-DOUBLES-v4-QUALIFYING',coalesce(v_match->'components','{}'::jsonb),
        coalesce(t.qualifying_end_date,t.start_date),true
      );
      update public.world_doubles_qualifying_entries set result_code='DQ1'
      where tournament_id=t.id and pair_id=v_l;

      select pair_id into v_a from cb_d_entries
      where entry_method in ('qualifying','qualifying_wildcard')
      order by score desc,pair_id offset 1 limit 1;
      select pair_id into v_b from cb_d_entries
      where entry_method in ('qualifying','qualifying_wildcard')
      order by score desc,pair_id offset 2 limit 1;

      v_match:=public.doubles_pair_matchup_v2(v_a,v_b,t.surface,coalesce(t.qualifying_end_date,t.start_date));
      v_prob:=greatest(.02,least(.98,coalesce((v_match->>'pair_a_probability')::numeric,.5)));
      v_awon:=random()<v_prob;
      v_qw2:=case when v_awon then v_a else v_b end;
      v_l:=case when v_awon then v_b else v_a end;
      v_score:=public.world_tournament_score(v_prob,v_awon,3);

      insert into public.world_doubles_tournament_matches(
        tournament_id,round_no,round_code,match_no,pair_a_id,pair_b_id,winner_pair_id,loser_pair_id,
        score,pair_a_win_probability,model_version,matchup_components,simulated_on,is_qualifying
      ) values(
        t.id,-2,'DQ1',2,v_a,v_b,v_qw2,v_l,v_score,round(v_prob,4),
        'CB-DOUBLES-v4-QUALIFYING',coalesce(v_match->'components','{}'::jsonb),
        coalesce(t.qualifying_end_date,t.start_date),true
      );
      update public.world_doubles_qualifying_entries set result_code='DQ1'
      where tournament_id=t.id and pair_id=v_l;

      v_a:=v_qw1; v_b:=v_qw2;
      v_match:=public.doubles_pair_matchup_v2(v_a,v_b,t.surface,coalesce(t.qualifying_end_date,t.start_date));
      v_prob:=greatest(.02,least(.98,coalesce((v_match->>'pair_a_probability')::numeric,.5)));
      v_awon:=random()<v_prob;
      v_qwinner:=case when v_awon then v_a else v_b end;
      v_l:=case when v_awon then v_b else v_a end;
      v_score:=public.world_tournament_score(v_prob,v_awon,3);

      insert into public.world_doubles_tournament_matches(
        tournament_id,round_no,round_code,match_no,pair_a_id,pair_b_id,winner_pair_id,loser_pair_id,
        score,pair_a_win_probability,model_version,matchup_components,simulated_on,is_qualifying
      ) values(
        t.id,-1,'DQF',1,v_a,v_b,v_qwinner,v_l,v_score,round(v_prob,4),
        'CB-DOUBLES-v4-QUALIFYING',coalesce(v_match->'components','{}'::jsonb),
        coalesce(t.qualifying_end_date,t.start_date),true
      );

      update public.world_doubles_qualifying_entries
      set result_code='DQF',points_awarded=25
      where tournament_id=t.id and pair_id=v_l;

      update public.world_doubles_qualifying_entries
      set result_code='Q',qualified=true,points_awarded=45
      where tournament_id=t.id and pair_id=v_qwinner;

      -- ATP 2026: the team losing the final qualifying round earns 25 points.
      insert into public.world_doubles_ranking_points(
        player_id,tournament_id,pair_id,label,earned_date,expiry_date,points,active,source_label
      )
      select w.player_a_id,t.id,w.id,t.name||' · DQF',
             coalesce(t.qualifying_end_date,t.start_date),
             coalesce(t.qualifying_end_date,t.start_date)+364,
             25,true,'ATP 500 doubles qualifying · final round'
      from public.world_doubles_partnerships w
      where w.id=v_l
      on conflict(player_id,tournament_id) do update set
        pair_id=excluded.pair_id,label=excluded.label,earned_date=excluded.earned_date,
        expiry_date=excluded.expiry_date,points=excluded.points,active=true,source_label=excluded.source_label;

      insert into public.world_doubles_ranking_points(
        player_id,tournament_id,pair_id,label,earned_date,expiry_date,points,active,source_label
      )
      select w.player_b_id,t.id,w.id,t.name||' · DQF',
             coalesce(t.qualifying_end_date,t.start_date),
             coalesce(t.qualifying_end_date,t.start_date)+364,
             25,true,'ATP 500 doubles qualifying · final round'
      from public.world_doubles_partnerships w
      where w.id=v_l
      on conflict(player_id,tournament_id) do update set
        pair_id=excluded.pair_id,label=excluded.label,earned_date=excluded.earned_date,
        expiry_date=excluded.expiry_date,points=excluded.points,active=true,source_label=excluded.source_label;

      update public.world_doubles_partnerships
      set race_points=race_points+25,
          last_refresh_date=greatest(last_refresh_date,coalesce(t.qualifying_end_date,t.start_date))
      where id=v_l;

      delete from cb_d_entries
      where entry_method in ('qualifying','qualifying_wildcard')
        and pair_id<>v_qwinner;

      update cb_d_entries
      set entry_method='qualifier',qualifying_points=45
      where pair_id=v_qwinner;
    end if;

    select count(*) into v_selected from cb_d_entries;
    if v_selected<>v_draw then continue; end if;

    if v_wc_count>0 then
      update cb_d_entries e
      set entry_method='wildcard'
      where e.pair_id in (
        select q.pair_id
        from cb_d_entries q
        join public.world_doubles_partnerships w on w.id=q.pair_id
        join public.players a on a.id=w.player_a_id
        join public.players b on b.id=w.player_b_id
        where q.entry_method='direct'
        order by
          ((a.country is not distinct from t.country)::int+
           (b.country is not distinct from t.country)::int) desc,
          q.score desc,q.pair_id
        limit v_wc_count
      );
    end if;

    if t.circuit='Challenger' then
      update cb_d_entries e
      set entry_method='onsite'
      where e.pair_id in (
        select q.pair_id from cb_d_entries q
        where q.entry_method='direct'
        order by q.score asc,q.pair_id
        limit 4
      );
    end if;

    with seed_order as (
      select pair_id,row_number() over(order by score desc,pair_id)::int rn
      from cb_d_entries
    )
    update cb_d_entries e
    set seed=case when seed_order.rn<=v_seed_limit then seed_order.rn else null end
    from seed_order
    where e.pair_id=seed_order.pair_id;

    -- deterministic spread of seeds, with byes assigned to top seeds
    update cb_d_entries
    set draw_slot=public.world_tournament_seed_slot(v_bracket,seed)
    where seed<=least(v_seed_limit,v_draw);

    if v_byes>0 then
      update cb_d_entries
      set had_bye=true
      where seed<=least(v_byes,v_seed_limit);
    end if;

    with used as (
      select draw_slot slot from cb_d_entries where draw_slot is not null
      union all
      select case when draw_slot%2=1 then draw_slot+1 else draw_slot-1 end
      from cb_d_entries where had_bye=true and draw_slot is not null
    ),
    avail as (
      select g slot,row_number() over(order by md5('dslot|'||t.id::text||'|'||g::text)) rn
      from generate_series(1,v_bracket) g
      where not exists(select 1 from used u where u.slot=g)
    ),
    unplaced as (
      select pair_id,row_number() over(order by md5('dpair|'||t.id::text||'|'||pair_id::text)) rn
      from cb_d_entries where draw_slot is null
    )
    update cb_d_entries e set draw_slot=a.slot
    from unplaced u join avail a using(rn)
    where e.pair_id=u.pair_id;

    create temporary table cb_d_current(pos int primary key,pair_id bigint) on commit drop;
    create temporary table cb_d_next(pos int primary key,pair_id bigint) on commit drop;
    insert into cb_d_current(pos,pair_id)
    select g,e.pair_id
    from generate_series(1,v_bracket) g
    left join cb_d_entries e on e.draw_slot=g;

    delete from public.world_doubles_tournament_matches where tournament_id=t.id and is_qualifying=false;
    v_size:=v_bracket;

    for v_round in 1..v_rounds loop
      truncate cb_d_next;
      v_next:=0;
      v_round_code:=case
        when v_round=1 and v_draw<>v_bracket then 'R'||v_draw::text
        when v_size>=64 then 'R64'
        when v_size>=32 then 'R32'
        when v_size>=16 then 'R16'
        when v_size>=8 then 'QF'
        when v_size>=4 then 'SF'
        else 'F' end;

      for v_pos in 1..v_size by 2 loop
        v_next:=v_next+1;
        select pair_id into v_a from cb_d_current where pos=v_pos;
        select pair_id into v_b from cb_d_current where pos=v_pos+1;

        if v_a is null and v_b is null then
          insert into cb_d_next(pos,pair_id) values(v_next,null);
          continue;
        elsif v_a is null or v_b is null then
          v_w:=coalesce(v_a,v_b);
          insert into cb_d_next(pos,pair_id) values(v_next,v_w);
          continue;
        end if;

        v_match:=public.doubles_pair_matchup_v2(v_a,v_b,t.surface,coalesce(t.end_date,t.start_date));
        v_prob:=greatest(.02,least(.98,coalesce((v_match->>'pair_a_probability')::numeric,.5)));
        v_awon:=random()<v_prob;
        v_w:=case when v_awon then v_a else v_b end;
        v_l:=case when v_awon then v_b else v_a end;
        v_score:=public.world_tournament_score(v_prob,v_awon,3);

        insert into public.world_doubles_tournament_matches(
          tournament_id,round_no,round_code,match_no,pair_a_id,pair_b_id,winner_pair_id,loser_pair_id,
          score,pair_a_win_probability,model_version,matchup_components,simulated_on
        ) values(
          t.id,v_round,v_round_code,(v_pos+1)/2,v_a,v_b,v_w,v_l,v_score,round(v_prob,4),
          'CB-DOUBLES-v3-FULLDRAW',coalesce(v_match->'components','{}'::jsonb),
          coalesce(t.end_date,t.start_date)
        );
        v_matches:=v_matches+1;

        v_points:=public.doubles_points_for_result(t.category,v_draw,v_round_code);
        v_prize:=public.tournament_prize_for_result(t.id,v_round_code,'doubles');
        update cb_d_entries
        set result_code=v_round_code,
            points_awarded=v_points+coalesce(qualifying_points,0),
            prize_awarded=v_prize,
            last_opponent_pair_id=v_w,
            last_score=case when v_l=v_a then v_score else public.world_invert_tennis_score(v_score) end
        where pair_id=v_l;
        update cb_d_entries set matches_won=matches_won+1 where pair_id=v_w;

        insert into cb_d_next(pos,pair_id) values(v_next,v_w);
      end loop;

      truncate cb_d_current;
      insert into cb_d_current select * from cb_d_next;
      v_size:=greatest(1,v_size/2);
    end loop;

    select pair_id into v_winner from cb_d_current order by pos limit 1;
    select loser_pair_id into v_finalist
    from public.world_doubles_tournament_matches
    where tournament_id=t.id and round_code='F'
    order by id desc limit 1;

    update cb_d_entries
    set result_code='W',
        points_awarded=public.doubles_points_for_result(t.category,v_draw,'W')+coalesce(qualifying_points,0),
        prize_awarded=public.tournament_prize_for_result(t.id,'W','doubles')
    where pair_id=v_winner;

    insert into public.world_doubles_tournament_entries(
      tournament_id,pair_id,entry_method,seed,draw_slot,had_bye,matches_won,result_code,result_label,
      points_awarded,prize_awarded,last_opponent_pair_id,last_score,simulated_on,source_label
    )
    select t.id,pair_id,entry_method,seed,draw_slot,had_bye,matches_won,result_code,
      case result_code when 'W' then 'Vainqueur' when 'F' then 'Finaliste'
        when 'SF' then 'Demi-finale' when 'QF' then 'Quart de finale'
        when 'R16' then '1/8 finale' when 'R24' then '1er tour · tableau 24'
        when 'R28' then '1er tour · tableau 28'
        when 'R32' then '1/16 finale' else result_code end,
      points_awarded,prize_awarded,last_opponent_pair_id,last_score,
      coalesce(t.end_date,t.start_date),'Court Boss doubles full draw'
    from cb_d_entries;

    insert into public.world_doubles_ranking_points(
      player_id,tournament_id,pair_id,label,earned_date,expiry_date,points,active,source_label
    )
    select w.player_a_id,t.id,e.pair_id,t.name||' · '||e.result_code,
           coalesce(t.end_date,t.start_date),coalesce(t.end_date,t.start_date)+364,
           e.points_awarded,true,'Court Boss doubles full draw'
    from cb_d_entries e join public.world_doubles_partnerships w on w.id=e.pair_id
    where e.points_awarded>0
    on conflict(player_id,tournament_id) do update set
      pair_id=excluded.pair_id,label=excluded.label,earned_date=excluded.earned_date,
      expiry_date=excluded.expiry_date,points=excluded.points,active=true,source_label=excluded.source_label;

    insert into public.world_doubles_ranking_points(
      player_id,tournament_id,pair_id,label,earned_date,expiry_date,points,active,source_label
    )
    select w.player_b_id,t.id,e.pair_id,t.name||' · '||e.result_code,
           coalesce(t.end_date,t.start_date),coalesce(t.end_date,t.start_date)+364,
           e.points_awarded,true,'Court Boss doubles full draw'
    from cb_d_entries e join public.world_doubles_partnerships w on w.id=e.pair_id
    where e.points_awarded>0
    on conflict(player_id,tournament_id) do update set
      pair_id=excluded.pair_id,label=excluded.label,earned_date=excluded.earned_date,
      expiry_date=excluded.expiry_date,points=excluded.points,active=true,source_label=excluded.source_label;

    update public.world_doubles_partnerships w
    set matches=w.matches+e.matches_won+case when e.result_code<>'W' then 1 else 0 end,
        wins=w.wins+e.matches_won,
        race_points=w.race_points+e.points_awarded,
        titles=w.titles+case when e.result_code='W' then 1 else 0 end,
        last_refresh_date=greatest(w.last_refresh_date,coalesce(t.end_date,t.start_date))
    from cb_d_entries e where w.id=e.pair_id;

    for entry_rec in
      select de.*,w.player_a_id,w.player_b_id,
             a.name a_name,b.name b_name
      from cb_d_entries de
      join public.world_doubles_partnerships w on w.id=de.pair_id
      join public.players a on a.id=w.player_a_id
      join public.players b on b.id=w.player_b_id
    loop
      if entry_rec.result_code='W' then
        insert into public.player_titles(player_id,tournament_name,title_date,level,surface,event_type,partner_player_id,partner_name,verified,source_label,origin)
        values
          (entry_rec.player_a_id,t.name,coalesce(t.end_date,t.start_date),t.category,t.surface,'doubles',entry_rec.player_b_id,entry_rec.b_name,false,'Court Boss doubles full draw','game'),
          (entry_rec.player_b_id,t.name,coalesce(t.end_date,t.start_date),t.category,t.surface,'doubles',entry_rec.player_a_id,entry_rec.a_name,false,'Court Boss doubles full draw','game')
        on conflict(player_id,tournament_name,title_date,event_type) do nothing;
      end if;
    end loop;

    insert into public.world_doubles_tournament_simulations(
      tournament_id,season,winner_pair_id,finalist_pair_id,winner_points,finalist_points,
      draw_size,simulated_on,source,final_win_probability,model_version,matchup_components
    )
    select t.id,v_year,v_winner,v_finalist,
      public.doubles_points_for_result(t.category,v_draw,'W'),
      public.doubles_points_for_result(t.category,v_draw,'F'),
      v_draw,coalesce(t.end_date,t.start_date),'Court Boss doubles full draw',
      case when m.winner_pair_id=m.pair_a_id then m.pair_a_win_probability else 1-m.pair_a_win_probability end,
      'CB-DOUBLES-v3-FULLDRAW',m.matchup_components
    from public.world_doubles_tournament_matches m
    where m.tournament_id=t.id and m.round_code='F'
    limit 1;

    v_simulated:=v_simulated+1;
  end loop;

  perform public.refresh_world_doubles_player_rankings(p_to_date);

  with ranked as (
    select id,row_number() over(order by race_points desc,pair_strength desc,affinity_score desc,id)::int rr
    from public.world_doubles_partnerships
    where season=extract(year from p_to_date)::int and active=true
  )
  update public.world_doubles_partnerships w set race_rank=r.rr from ranked r where w.id=r.id;

  return jsonb_build_object(
    'tournaments_simulated',v_simulated,'matches_simulated',v_matches,
    'from',p_from_date,'to',p_to_date,'ranking_model','best-18 rolling results',
    'match_model','CB-DOUBLES-v3-FULLDRAW'
  );
end
$function$;

CREATE OR REPLACE FUNCTION public.simulate_junior_world_doubles_full(p_from_date date, p_to_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  v_managed bigint;
  v_draw int;
  v_pair_count int;
  v_p1 bigint;
  v_best_partner bigint;
  v_pair_strength int;
  v_best_strength int;
  v_size int;
  v_round int;
  v_pos int;
  v_next int;
  v_a bigint;
  v_b bigint;
  v_w bigint;
  v_l bigint;
  v_sa int;
  v_sb int;
  v_prob numeric;
  v_awon boolean;
  v_score text;
  v_code text;
  v_winner bigint;
  v_count int:=0;
  v_matches int:=0;
  rr record;
begin
  select managed_player_id into v_managed from public.career_state where id='demo';

  for t in
    select *
    from public.tournaments
    where circuit='Junior'
      and doubles=true
      and coalesce(is_active,true)=true
      and coalesce(end_date,start_date)>p_from_date
      and coalesce(end_date,start_date)<=p_to_date
      and category not in ('Junior Davis Cup','Junior Finals','Junior Double Finals')
      and coalesce(doubles_draw_size,0)>=8
      and not exists(select 1 from public.world_junior_doubles_entries e where e.tournament_id=tournaments.id)
    order by coalesce(end_date,start_date),id
    limit 100
  loop
    v_draw:=least(32,coalesce(t.doubles_draw_size,16));

    drop table if exists pg_temp.cb_jd_pool;
    drop table if exists pg_temp.cb_jd;
    create temporary table cb_jd_pool(
      player_id bigint primary key,
      rankv int
    ) on commit drop;
    create temporary table cb_jd(
      entry_no int generated always as identity primary key,
      player_a_id bigint not null,
      player_b_id bigint not null,
      strength int not null,
      seed int,
      draw_slot int
    ) on commit drop;

    insert into cb_jd_pool(player_id,rankv)
    select p.id,coalesce(p.junior_doubles_ranking,999999)
    from public.players p
    where p.career_status='active'
      and p.id is distinct from v_managed
      and p.junior_doubles_ranking is not null
      and p.injury_status='Fit'
      and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
      and coalesce(p.career_focus,'mixed')<>'singles_only'
      and coalesce(p.fitness,90)>=45
      and coalesce(p.fatigue,20)<=90
      and not (public.player_tournament_calendar_conflict(p.id,t.id,'doubles')->>'conflict')::boolean
      and public.ai_player_commits_to_doubles_tournament(p.id,t.id)
      and (
        p.birth_date is null
        or (
          p.birth_date<=t.start_date-interval '13 years'
          and extract(year from t.start_date)::int-extract(year from p.birth_date)::int<=18
        )
      )
    order by p.junior_doubles_ranking,p.id
    limit v_draw*5;

    v_pair_count:=0;
    while v_pair_count<v_draw and (select count(*) from cb_jd_pool)>=2 loop
      select player_id into v_p1 from cb_jd_pool order by rankv,player_id limit 1;
      v_best_partner:=null;
      v_best_strength:=-1;

      for rr in
        select player_id
        from cb_jd_pool
        where player_id<>v_p1
        order by rankv,player_id
        limit 30
      loop
        select pair_strength into v_pair_strength
        from public.doubles_pair_metrics(v_p1,rr.player_id,t.start_date)
        limit 1;

        if coalesce(v_pair_strength,0)>v_best_strength then
          v_best_strength:=coalesce(v_pair_strength,0);
          v_best_partner:=rr.player_id;
        end if;
      end loop;

      if v_best_partner is null then exit; end if;

      insert into cb_jd(player_a_id,player_b_id,strength)
      values(least(v_p1,v_best_partner),greatest(v_p1,v_best_partner),v_best_strength);

      delete from cb_jd_pool where player_id in (v_p1,v_best_partner);
      v_pair_count:=v_pair_count+1;
    end loop;

    if v_pair_count<>v_draw then
      continue;
    end if;

    with s as (
      select entry_no,row_number() over(order by strength desc,entry_no)::int rn
      from cb_jd
    )
    update cb_jd e
    set seed=s.rn,draw_slot=s.rn
    from s
    where e.entry_no=s.entry_no;

    delete from public.world_junior_doubles_matches where tournament_id=t.id;
    delete from public.world_junior_doubles_entries where tournament_id=t.id;

    insert into public.world_junior_doubles_entries(
      tournament_id,player_a_id,player_b_id,seed,draw_slot,simulated_on
    )
    select t.id,player_a_id,player_b_id,seed,draw_slot,t.end_date
    from cb_jd
    order by seed;

    drop table if exists pg_temp.cb_jd_current;
    drop table if exists pg_temp.cb_jd_next;
    create temporary table cb_jd_current(pos int primary key,entry_id bigint) on commit drop;
    create temporary table cb_jd_next(pos int primary key,entry_id bigint) on commit drop;

    insert into cb_jd_current(pos,entry_id)
    select draw_slot,id
    from public.world_junior_doubles_entries
    where tournament_id=t.id;

    v_size:=v_draw;
    v_round:=1;

    while v_size>1 loop
      truncate cb_jd_next;
      v_next:=0;
      v_code:=case
        when v_size>=32 then 'R32'
        when v_size>=16 then 'R16'
        when v_size>=8 then 'QF'
        when v_size>=4 then 'SF'
        else 'F' end;

      for v_pos in 1..v_size by 2 loop
        v_next:=v_next+1;
        select entry_id into v_a from cb_jd_current where pos=v_pos;
        select entry_id into v_b from cb_jd_current where pos=v_pos+1;

        select d.strength into v_sa
        from public.world_junior_doubles_entries e
        join cb_jd d on d.player_a_id=e.player_a_id and d.player_b_id=e.player_b_id
        where e.id=v_a;

        select d.strength into v_sb
        from public.world_junior_doubles_entries e
        join cb_jd d on d.player_a_id=e.player_a_id and d.player_b_id=e.player_b_id
        where e.id=v_b;

        v_prob:=greatest(.08,least(.92,1/(1+exp(-(coalesce(v_sa,50)-coalesce(v_sb,50))/8.0))));
        v_awon:=random()<v_prob;
        v_w:=case when v_awon then v_a else v_b end;
        v_l:=case when v_awon then v_b else v_a end;
        v_score:=public.world_tournament_score(v_prob,v_awon,3);

        insert into public.world_junior_doubles_matches(
          tournament_id,round_no,round_code,match_no,
          pair_a_entry_id,pair_b_entry_id,winner_entry_id,loser_entry_id,
          score,win_probability,simulated_on
        ) values(
          t.id,v_round,v_code,v_next,v_a,v_b,v_w,v_l,
          v_score,round(v_prob,4),t.end_date
        );
        v_matches:=v_matches+1;

        update public.world_junior_doubles_entries
        set result_code=v_code,
            points_awarded=public.junior_points_for('doubles',t.category,v_code),
            last_opponent=(
              select pa.name||' / '||pb.name
              from public.world_junior_doubles_entries oe
              join public.players pa on pa.id=oe.player_a_id
              join public.players pb on pb.id=oe.player_b_id
              where oe.id=v_w
            ),
            last_score=case when v_l=v_a then v_score else public.world_invert_tennis_score(v_score) end
        where id=v_l;

        update public.world_junior_doubles_entries
        set matches_won=matches_won+1
        where id=v_w;

        insert into cb_jd_next values(v_next,v_w);
      end loop;

      truncate cb_jd_current;
      insert into cb_jd_current select * from cb_jd_next;
      v_size:=v_size/2;
      v_round:=v_round+1;
    end loop;

    select entry_id into v_winner from cb_jd_current limit 1;

    update public.world_junior_doubles_entries
    set result_code='W',
        points_awarded=public.junior_points_for('doubles',t.category,'W')
    where id=v_winner;

    update public.players p
    set junior_doubles_game_points=coalesce(p.junior_doubles_game_points,0)+e.points_awarded
    from public.world_junior_doubles_entries e
    where e.tournament_id=t.id
      and p.id in (e.player_a_id,e.player_b_id);

    for rr in
      select e.*,a.name a_name,b.name b_name
      from public.world_junior_doubles_entries e
      join public.players a on a.id=e.player_a_id
      join public.players b on b.id=e.player_b_id
      where e.id=v_winner
    loop
      insert into public.player_titles(
        player_id,tournament_name,title_date,level,surface,event_type,
        partner_player_id,partner_name,verified,source_label,origin
      )
      values
        (rr.player_a_id,t.name,t.end_date,t.category,t.surface,'junior_doubles',rr.player_b_id,rr.b_name,false,'Court Boss junior doubles full draw','game'),
        (rr.player_b_id,t.name,t.end_date,t.category,t.surface,'junior_doubles',rr.player_a_id,rr.a_name,false,'Court Boss junior doubles full draw','game')
      on conflict(player_id,tournament_name,title_date,event_type) do nothing;
    end loop;

    v_count:=v_count+1;
  end loop;

  return jsonb_build_object(
    'doubles_simulated',v_count,'matches_simulated',v_matches,
    'from',p_from_date,'to',p_to_date,'model','CB-JUNIOR-DOUBLES-v2 full draw'
  );
end
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
  where lower(coalesce(status,''))='active' and expected_return < p_date;

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
    order by p.ranking
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

CREATE OR REPLACE FUNCTION public.davis_pick_player(p_nation text, p_role text, p_date date, p_exclude bigint DEFAULT NULL::bigint)
 RETURNS bigint
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  v_id bigint;
  v_double boolean:=lower(coalesce(p_role,'')) like 'double%';
begin
  select ds.player_id into v_id
  from public.davis_squad ds
  join public.players p on p.id=ds.player_id
  where upper(ds.nation)=upper(p_nation)
    and lower(ds.role)=lower(p_role)
    and p.id is distinct from p_exclude
    and p.career_status='active'
    and p.injury_status='Fit'
    and coalesce(p.fitness,90)>=50
    and (
      (v_double and coalesce(p.career_focus,'mixed')<>'singles_only')
      or
      (not v_double and coalesce(p.career_focus,'mixed')<>'doubles_only')
    )
  order by coalesce(case when v_double then p.doubles_ranking else p.ranking end,999999),p.current_ability desc,p.id
  limit 1;

  if v_id is not null then return v_id; end if;

  if v_double then
    select p.id into v_id
    from public.players p
    where upper(p.country)=upper(p_nation)
      and p.id is distinct from p_exclude
      and p.career_status='active'
      and p.injury_status='Fit'
      and coalesce(p.career_focus,'mixed')<>'singles_only'
      and p.doubles_ranking is not null
      and coalesce(p.fitness,90)>=50
    order by
      case when p.career_focus='doubles_only' then 0 else 1 end,
      p.doubles_ranking,p.current_ability desc,p.id
    limit 1;
  else
    select p.id into v_id
    from public.players p
    where upper(p.country)=upper(p_nation)
      and p.id is distinct from p_exclude
      and p.career_status='active'
      and p.injury_status='Fit'
      and coalesce(p.career_focus,'mixed')<>'doubles_only'
      and p.ranking_current=true
      and coalesce(p.fitness,90)>=50
    order by p.ranking,p.current_ability desc,p.id
    limit 1;
  end if;

  return v_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.davis_singles_rubber(p_home_player bigint, p_away_player bigint, p_surface text, p_date date, p_key text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  v_match jsonb;
  v_prob numeric;
  v_roll numeric;
  v_home boolean;
  v_score text;
begin
  if p_home_player is null or p_away_player is null then
    return jsonb_build_object('ok',false,'reason','missing_player');
  end if;

  v_match:=public.player_matchup_probability_v4(
    p_home_player,p_away_player,coalesce(p_surface,'Dur'),p_date,
    case when coalesce(p_surface,'Dur') ilike 'Terre%' then .70
         when coalesce(p_surface,'Dur') ilike 'Gazon%' then 1.14
         else 1.0 end,
    3
  );
  v_prob:=greatest(.04,least(.96,coalesce((v_match->>'player_a_probability')::numeric,.5)));
  v_roll:=mod(abs(hashtext('davis-s|'||coalesce(p_key,'')||'|'||p_home_player||'|'||p_away_player)),10000)/10000.0;
  v_home:=v_roll<v_prob;

  v_score:=case
    when abs(v_prob-.5)<.08 then '7-6 4-6 6-3'
    when abs(v_prob-.5)<.18 then '6-4 3-6 6-3'
    else '6-3 6-4'
  end;

  return jsonb_build_object(
    'ok',true,
    'home_win',v_home,
    'winner_id',case when v_home then p_home_player else p_away_player end,
    'loser_id',case when v_home then p_away_player else p_home_player end,
    'home_probability',round(v_prob,4),
    'score',v_score
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.davis_doubles_rubber(p_h1 bigint, p_h2 bigint, p_a1 bigint, p_a2 bigint, p_surface text, p_date date, p_key text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  hs numeric;
  ascore numeric;
  prob numeric;
  roll numeric;
  homewin boolean;
  surf text:=lower(coalesce(p_surface,'Dur'));
begin
  if p_h1 is null or p_h2 is null or p_a1 is null or p_a2 is null then
    return jsonb_build_object('ok',false,'reason','missing_player');
  end if;

  select
    sum(
      coalesce(p.current_ability,50)*.46+
      coalesce(p.form,70)*.10+
      coalesce(p.fitness,85)*.06-
      coalesce(p.fatigue,20)*.08+
      coalesce(pa.doubles,10)*1.05+
      case
        when surf like 'terre%' then coalesce(pa.clay_affinity,10)*.30
        when surf like 'gazon%' then coalesce(pa.grass_affinity,10)*.30
        else coalesce(pa.hard_affinity,10)*.30 end
    )
  into hs
  from public.players p
  left join public.player_attributes pa on pa.player_id=p.id
  where p.id in (p_h1,p_h2);

  select
    sum(
      coalesce(p.current_ability,50)*.46+
      coalesce(p.form,70)*.10+
      coalesce(p.fitness,85)*.06-
      coalesce(p.fatigue,20)*.08+
      coalesce(pa.doubles,10)*1.05+
      case
        when surf like 'terre%' then coalesce(pa.clay_affinity,10)*.30
        when surf like 'gazon%' then coalesce(pa.grass_affinity,10)*.30
        else coalesce(pa.hard_affinity,10)*.30 end
    )
  into ascore
  from public.players p
  left join public.player_attributes pa on pa.player_id=p.id
  where p.id in (p_a1,p_a2);

  prob:=greatest(.05,least(.95,1/(1+exp(-(coalesce(hs,100)-coalesce(ascore,100))/11.0))));
  roll:=mod(abs(hashtext('davis-d|'||coalesce(p_key,'')||'|'||p_h1||'|'||p_h2||'|'||p_a1||'|'||p_a2)),10000)/10000.0;
  homewin:=roll<prob;

  return jsonb_build_object(
    'ok',true,'home_win',homewin,
    'home_probability',round(prob,4),
    'score',case when abs(prob-.5)<.10 then '7-6 3-6 6-4' else '6-4 6-3' end
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.davis_country_strength(p_nation text)
 RETURNS numeric
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  with s as (
    select coalesce(p.ranking,9999) r
    from public.players p
    where upper(p.country)=upper(p_nation)
      and p.career_status='active'
      and p.ranking_current=true
      and coalesce(p.career_focus,'mixed')<>'doubles_only'
    order by p.ranking
    limit 3
  ),
  d as (
    select coalesce(p.doubles_ranking,9999) r
    from public.players p
    where upper(p.country)=upper(p_nation)
      and p.career_status='active'
      and p.doubles_ranking is not null
      and coalesce(p.career_focus,'mixed')<>'singles_only'
    order by p.doubles_ranking
    limit 2
  )
  select
    coalesce((select sum(greatest(0,700-r)) from s),0)
    +coalesce((select sum(greatest(0,450-r))*.55 from d),0);
$function$;

CREATE OR REPLACE FUNCTION public.simulate_davis_tie_v2(p_tie_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.davis_ties%rowtype;
  home text;
  away text;
  winner text;
  runner text;
  h1 bigint; h2 bigint; hd1 bigint; hd2 bigint;
  a1 bigint; a2 bigint; ad1 bigint; ad2 bigint;
  h1n text; h2n text; hd1n text; hd2n text;
  a1n text; a2n text; ad1n text; ad2n text;
  r jsonb;
  hs int:=0;
  ascore int:=0;
  v_no int:=0;
  v_final8 boolean:=false;
  v_token text;
  v_pos int;
  v_nations text[];
  v_seeds text[];
  v_unseeded text[];
  v_completed int;
  v_year int;
begin
  select * into t from public.davis_ties where id=p_tie_id for update;
  if t.id is null then return jsonb_build_object('ok',false,'reason','tie_not_found'); end if;
  if t.status='completed' then
    return jsonb_build_object('ok',true,'already',true,'tie_id',t.id,'home_score',t.home_score,'away_score',t.away_score);
  end if;

  home:=upper(coalesce(t.home_nation,''));
  away:=upper(coalesce(t.away_nation,''));
  if home='' or away='' or home='TBD' or away='TBD'
     or home like 'WINNER %' or away like 'WINNER %' then
    return jsonb_build_object('ok',false,'reason','participants_not_ready','tie_id',t.id);
  end if;

  h1:=public.davis_pick_player(home,'Simple 1',t.tie_date,null);
  h2:=public.davis_pick_player(home,'Simple 2',t.tie_date,h1);
  a1:=public.davis_pick_player(away,'Simple 1',t.tie_date,null);
  a2:=public.davis_pick_player(away,'Simple 2',t.tie_date,a1);
  hd1:=public.davis_pick_player(home,'Double A',t.tie_date,null);
  hd2:=public.davis_pick_player(home,'Double B',t.tie_date,hd1);
  ad1:=public.davis_pick_player(away,'Double A',t.tie_date,null);
  ad2:=public.davis_pick_player(away,'Double B',t.tie_date,ad1);

  if h1 is null or h2 is null or a1 is null or a2 is null then
    return jsonb_build_object('ok',false,'reason','incomplete_squad','tie_id',t.id,'home',home,'away',away);
  end if;
  hd1:=coalesce(hd1,h1); hd2:=coalesce(hd2,h2);
  ad1:=coalesce(ad1,a1); ad2:=coalesce(ad2,a2);

  select name into h1n from public.players where id=h1;
  select name into h2n from public.players where id=h2;
  select name into hd1n from public.players where id=hd1;
  select name into hd2n from public.players where id=hd2;
  select name into a1n from public.players where id=a1;
  select name into a2n from public.players where id=a2;
  select name into ad1n from public.players where id=ad1;
  select name into ad2n from public.players where id=ad2;

  delete from public.davis_rubbers where tie_id=t.id;
  v_final8:=t.stage like 'Final 8%';

  if v_final8 then
    -- Final 8: two singles followed by the deciding doubles if necessary.
    v_no:=1;
    r:=public.davis_singles_rubber(h2,a2,t.surface,t.tie_date,t.id||'|1');
    if coalesce((r->>'home_win')::boolean,false) then hs:=hs+1; else ascore:=ascore+1; end if;
    insert into public.davis_rubbers(
      tie_id,rubber_no,rubber_type,home_names,away_names,winner_nation,score,home_player_ids,away_player_ids
    ) values(t.id,1,'Simple',h2n,a2n,case when (r->>'home_win')::boolean then home else away end,r->>'score',array[h2],array[a2]);

    v_no:=2;
    r:=public.davis_singles_rubber(h1,a1,t.surface,t.tie_date,t.id||'|2');
    if coalesce((r->>'home_win')::boolean,false) then hs:=hs+1; else ascore:=ascore+1; end if;
    insert into public.davis_rubbers(
      tie_id,rubber_no,rubber_type,home_names,away_names,winner_nation,score,home_player_ids,away_player_ids
    ) values(t.id,2,'Simple',h1n,a1n,case when (r->>'home_win')::boolean then home else away end,r->>'score',array[h1],array[a1]);

    if hs<2 and ascore<2 then
      v_no:=3;
      r:=public.davis_doubles_rubber(hd1,hd2,ad1,ad2,t.surface,t.tie_date,t.id||'|3');
      if coalesce((r->>'home_win')::boolean,false) then hs:=hs+1; else ascore:=ascore+1; end if;
      insert into public.davis_rubbers(
        tie_id,rubber_no,rubber_type,home_names,away_names,winner_nation,score,home_player_ids,away_player_ids
      ) values(t.id,3,'Double',hd1n||' / '||hd2n,ad1n||' / '||ad2n,
        case when (r->>'home_win')::boolean then home else away end,r->>'score',
        array[hd1,hd2],array[ad1,ad2]);
    end if;
  else
    -- Qualifiers: two singles, doubles, then reverse singles if required.
    r:=public.davis_singles_rubber(h1,a2,t.surface,t.tie_date,t.id||'|1');
    if coalesce((r->>'home_win')::boolean,false) then hs:=hs+1; else ascore:=ascore+1; end if;
    insert into public.davis_rubbers(
      tie_id,rubber_no,rubber_type,home_names,away_names,winner_nation,score,home_player_ids,away_player_ids
    ) values(t.id,1,'Simple',h1n,a2n,case when (r->>'home_win')::boolean then home else away end,r->>'score',array[h1],array[a2]);

    r:=public.davis_singles_rubber(h2,a1,t.surface,t.tie_date,t.id||'|2');
    if coalesce((r->>'home_win')::boolean,false) then hs:=hs+1; else ascore:=ascore+1; end if;
    insert into public.davis_rubbers(
      tie_id,rubber_no,rubber_type,home_names,away_names,winner_nation,score,home_player_ids,away_player_ids
    ) values(t.id,2,'Simple',h2n,a1n,case when (r->>'home_win')::boolean then home else away end,r->>'score',array[h2],array[a1]);

    r:=public.davis_doubles_rubber(hd1,hd2,ad1,ad2,t.surface,t.tie_date,t.id||'|3');
    if coalesce((r->>'home_win')::boolean,false) then hs:=hs+1; else ascore:=ascore+1; end if;
    insert into public.davis_rubbers(
      tie_id,rubber_no,rubber_type,home_names,away_names,winner_nation,score,home_player_ids,away_player_ids
    ) values(t.id,3,'Double',hd1n||' / '||hd2n,ad1n||' / '||ad2n,
      case when (r->>'home_win')::boolean then home else away end,r->>'score',
      array[hd1,hd2],array[ad1,ad2]);

    if hs<3 and ascore<3 then
      r:=public.davis_singles_rubber(h1,a1,t.surface,t.tie_date,t.id||'|4');
      if coalesce((r->>'home_win')::boolean,false) then hs:=hs+1; else ascore:=ascore+1; end if;
      insert into public.davis_rubbers(
        tie_id,rubber_no,rubber_type,home_names,away_names,winner_nation,score,home_player_ids,away_player_ids
      ) values(t.id,4,'Simple',h1n,a1n,case when (r->>'home_win')::boolean then home else away end,r->>'score',array[h1],array[a1]);
    end if;

    if hs<3 and ascore<3 then
      r:=public.davis_singles_rubber(h2,a2,t.surface,t.tie_date,t.id||'|5');
      if coalesce((r->>'home_win')::boolean,false) then hs:=hs+1; else ascore:=ascore+1; end if;
      insert into public.davis_rubbers(
        tie_id,rubber_no,rubber_type,home_names,away_names,winner_nation,score,home_player_ids,away_player_ids
      ) values(t.id,5,'Simple',h2n,a2n,case when (r->>'home_win')::boolean then home else away end,r->>'score',array[h2],array[a2]);
    end if;
  end if;

  winner:=case when hs>ascore then home else away end;
  runner:=case when hs>ascore then away else home end;

  update public.davis_ties
  set status='completed',home_score=hs,away_score=ascore
  where id=t.id;

  update public.players
  set fatigue=least(100,coalesce(fatigue,20)+5),
      fitness=greatest(35,coalesce(fitness,90)-1)
  where id=any(array[h1,h2,hd1,hd2,a1,a2,ad1,ad2]);

  if t.stage='Qualifiers 1st Round' then
    v_token:='Winner '||home||'/'||away;
    update public.davis_ties
    set home_nation=winner
    where stage='Qualifiers 2nd Round' and upper(home_nation)=upper(v_token);
    update public.davis_ties
    set away_nation=winner
    where stage='Qualifiers 2nd Round' and upper(away_nation)=upper(v_token);

  elsif t.stage='Qualifiers 2nd Round' then
    select count(*) into v_completed
    from public.davis_ties
    where stage='Qualifiers 2nd Round' and status='completed';

    if v_completed=7 and exists(
      select 1 from public.davis_ties
      where stage like 'Final 8 · Quarter-final%' and (home_nation='TBD' or away_nation='TBD')
    ) then
      select array_agg(nation order by
        case when nation='ITA' then 0 else 1 end,
        public.davis_country_strength(nation) desc,
        nation)
      into v_nations
      from (
        select case when home_score>away_score then home_nation else away_nation end nation
        from public.davis_ties
        where stage='Qualifiers 2nd Round' and status='completed'
        union all
        select 'ITA'
      ) q;

      v_seeds:=v_nations[1:4];
      select array_agg(x order by hashtext('davis-final8-'||extract(year from t.tie_date)::int||'|'||x))
      into v_unseeded
      from unnest(v_nations[5:8]) x;

      with q as (
        select id,row_number() over(order by tie_date,id)::int rn
        from public.davis_ties
        where stage like 'Final 8 · Quarter-final%'
      )
      update public.davis_ties dt
      set home_nation=case q.rn
            when 1 then v_seeds[1]
            when 2 then v_seeds[4]
            when 3 then v_seeds[3]
            else v_seeds[2] end,
          away_nation=case q.rn
            when 1 then v_unseeded[1]
            when 2 then v_unseeded[2]
            when 3 then v_unseeded[3]
            else v_unseeded[4] end
      from q where dt.id=q.id;
    end if;

  elsif t.stage like 'Final 8 · Quarter-final%' then
    select rn into v_pos
    from (
      select id,row_number() over(order by tie_date,id)::int rn
      from public.davis_ties
      where stage like 'Final 8 · Quarter-final%'
    ) q where q.id=t.id;

    if v_pos=1 then
      update public.davis_ties set home_nation=winner where stage='Final 8 · Semi-final 1';
    elsif v_pos=2 then
      update public.davis_ties set away_nation=winner where stage='Final 8 · Semi-final 1';
    elsif v_pos=3 then
      update public.davis_ties set home_nation=winner where stage='Final 8 · Semi-final 2';
    elsif v_pos=4 then
      update public.davis_ties set away_nation=winner where stage='Final 8 · Semi-final 2';
    end if;

  elsif t.stage='Final 8 · Semi-final 1' then
    update public.davis_ties set home_nation=winner where stage='Final 8 · Final';
  elsif t.stage='Final 8 · Semi-final 2' then
    update public.davis_ties set away_nation=winner where stage='Final 8 · Final';
  elsif t.stage='Final 8 · Final' then
    v_year:=extract(year from t.tie_date)::int;
    if not exists(select 1 from public.davis_history where competition='Davis Cup' and season=v_year) then
      insert into public.davis_history(
        competition,season,winner_country,runner_up_country,score,venue,source_label,verified
      ) values(
        'Davis Cup',v_year,winner,runner,hs||'-'||ascore,t.venue,
        'Court Boss simulated season engine v2',false
      );
    end if;
  end if;

  return jsonb_build_object(
    'ok',true,'tie_id',t.id,'stage',t.stage,
    'home',home,'away',away,'home_score',hs,'away_score',ascore,
    'winner_nation',winner,'format',case when v_final8 then 'final8_best_of_3' else 'qualifiers_best_of_5' end
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.simulate_world_davis_ties(p_from_date date, p_to_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  rec record;
  v_result jsonb;
  v_count int:=0;
  v_skipped int:=0;
begin
  for rec in
    select id
    from public.davis_ties
    where tie_date>p_from_date
      and tie_date<=p_to_date
      and status='scheduled'
    order by tie_date,id
  loop
    v_result:=public.simulate_davis_tie_v2(rec.id);
    if coalesce((v_result->>'ok')::boolean,false) then
      v_count:=v_count+1;
    else
      v_skipped:=v_skipped+1;
    end if;
  end loop;

  return jsonb_build_object(
    'ties_simulated',v_count,'ties_skipped',v_skipped,
    'from',p_from_date,'to',p_to_date,
    'model','Davis Cup v2 · Qualifiers BO5 + Final 8 BO3 + dynamic bracket'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.ncaa_team_lineup(p_team_id bigint, p_date date)
 RETURNS bigint[]
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  select coalesce(array_agg(id order by score desc,id),'{}'::bigint[])
  from (
    select p.id,
      coalesce(p.current_ability,50)
      +coalesce(p.form,70)*.11
      +coalesce(p.fitness,85)*.05
      -coalesce(p.fatigue,20)*.07
      +coalesce(nr.utr_rating,10)*1.8
      -coalesce(p.ncaa_rank,500)*.004 as score
    from public.college_teams t
    join public.players p on p.ncaa_current=true and p.ncaa_school=t.name
    left join public.ncaa_player_registry nr on nr.player_id=p.id
    where t.id=p_team_id
      and p.career_status='active'
      and p.injury_status='Fit'
      and coalesce(p.fitness,90)>=45
    order by score desc,p.id
    limit 6
  ) x;
$function$;

CREATE OR REPLACE FUNCTION public.ncaa_team_power(p_team_id bigint, p_date date)
 RETURNS numeric
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  v_lineup bigint[];
  v_roster numeric:=0;
  v_staff numeric:=0;
  v_rank int:=64;
begin
  v_lineup:=public.ncaa_team_lineup(p_team_id,p_date);

  select coalesce(avg(
    coalesce(p.current_ability,50)
    +coalesce(p.form,70)*.11
    +coalesce(p.fitness,85)*.05
    -coalesce(p.fatigue,20)*.07
    +coalesce(nr.utr_rating,10)*1.8
    +coalesce(pa.mental_toughness,10)*.18
  ),55)
  into v_roster
  from public.players p
  left join public.ncaa_player_registry nr on nr.player_id=p.id
  left join public.player_attributes pa on pa.player_id=p.id
  where p.id=any(v_lineup);

  select coalesce(avg(
    coalesce(sp.coach_rating,10)*.28+
    coalesce(sp.tactical_rating,10)*.24+
    coalesce(sp.mental_rating,10)*.18+
    coalesce(sp.youth_rating,10)*.15+
    coalesce(sp.communication_rating,10)*.15
  ),10)
  into v_staff
  from public.college_team_staff cts
  join public.staff_profiles sp on sp.id=cts.profile_id
  where cts.team_id=p_team_id and cts.active=true;

  select coalesce(ita_rank,preseason_rank,64) into v_rank
  from public.college_teams where id=p_team_id;

  return v_roster+v_staff*.55+greatest(0,65-v_rank)*.055;
end;
$function$;

CREATE OR REPLACE FUNCTION public.ensure_ncaa_regular_schedule(p_year integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  teams bigint[];
  n int;
  r int;
  i int;
  a_idx int;
  b_idx int;
  home_id bigint;
  away_id bigint;
  fixed_id bigint;
  d date;
  start_date date;
  inserted int:=0;
begin
  if p_year<2026 then
    return jsonb_build_object('created',0,'reason','historical_year');
  end if;

  if exists(
    select 1 from public.college_duals
    where extract(year from match_date)::int=p_year
      and source_label='Court Boss NCAA generated regular season v1'
  ) then
    return jsonb_build_object('created',0,'already',true);
  end if;

  select array_agg(id order by coalesce(preseason_rank,ita_rank,9999),id)
  into teams
  from public.college_teams;

  n:=coalesce(array_length(teams,1),0);
  if n<4 or mod(n,2)<>0 then
    return jsonb_build_object('created',0,'reason','team_count_must_be_even','teams',n);
  end if;

  start_date:=make_date(p_year,1,17)
    + ((6-extract(dow from make_date(p_year,1,17))::int+7)%7);
  fixed_id:=teams[n];

  for r in 0..13 loop
    d:=start_date+r*7;

    home_id:=fixed_id;
    away_id:=teams[(r%(n-1))+1];
    if mod(r,2)=1 then
      home_id:=teams[(r%(n-1))+1];
      away_id:=fixed_id;
    end if;

    insert into public.college_duals(
      match_date,home_team_id,away_team_id,home_score,away_score,status,
      competition,stage,source_label,model_version
    ) values(
      d,home_id,away_id,null,null,'scheduled',
      'NCAA Division I','Regular Season',
      'Court Boss NCAA generated regular season v1','CB-NCAA-v1'
    );
    inserted:=inserted+1;

    for i in 1..(n/2-1) loop
      a_idx:=mod(r+i,n-1)+1;
      b_idx:=mod(r-i+(n-1)*10,n-1)+1;
      home_id:=teams[a_idx];
      away_id:=teams[b_idx];

      if mod(r+i,2)=1 then
        home_id:=teams[b_idx];
        away_id:=teams[a_idx];
      end if;

      insert into public.college_duals(
        match_date,home_team_id,away_team_id,home_score,away_score,status,
        competition,stage,source_label,model_version
      ) values(
        d,home_id,away_id,null,null,'scheduled',
        'NCAA Division I','Regular Season',
        'Court Boss NCAA generated regular season v1','CB-NCAA-v1'
      );
      inserted:=inserted+1;
    end loop;
  end loop;

  return jsonb_build_object(
    'created',inserted,'teams',n,'rounds',14,
    'start_date',start_date,'end_date',start_date+13*7,
    'label','generated game schedule; not claimed as official school-by-school NCAA schedule'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.refresh_ncaa_team_rankings(p_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  v_count int;
begin
  with records as (
    select t.id,
      count(d.id) filter(where d.status='completed') played,
      count(d.id) filter(where d.status='completed' and d.winner_team_id=t.id) wins,
      count(d.id) filter(where d.status='completed' and d.winner_team_id is distinct from t.id) losses
    from public.college_teams t
    left join public.college_duals d
      on t.id in (d.home_team_id,d.away_team_id)
      and d.match_date<=p_date
      and coalesce(d.competition,'NCAA Division I')='NCAA Division I'
    group by t.id
  ),
  scored as (
    select t.id,
      coalesce(r.wins,0) wins,coalesce(r.losses,0) losses,
      (
        coalesce(r.wins,0)*100
        -coalesce(r.losses,0)*35
        -coalesce(t.preseason_rank,t.ita_rank,64)*1.8
      ) score
    from public.college_teams t
    left join records r on r.id=t.id
  ),
  ranked as (
    select id,wins,losses,
      row_number() over(order by score desc,wins desc,losses asc,id)::int new_rank
    from scored
  )
  update public.college_teams t
  set ita_rank=r.new_rank,
      record=r.wins||'-'||r.losses
  from ranked r
  where t.id=r.id;

  get diagnostics v_count=row_count;

  with pr as (
    select p.id,
      row_number() over(order by
        (
          coalesce(nr.utr_rating,10)*3.0+
          coalesce(p.current_ability,50)*1.0+
          coalesce(p.form,70)*.12+
          greatest(0,65-coalesce(ct.ita_rank,64))*.16
        ) desc,
        p.id
      )::int new_rank
    from public.players p
    left join public.ncaa_player_registry nr on nr.player_id=p.id
    left join public.college_teams ct on ct.name=p.ncaa_school
    where p.ncaa_current=true and p.career_status='active'
  )
  update public.players p
  set ncaa_rank=pr.new_rank
  from pr where p.id=pr.id;

  return jsonb_build_object('teams_ranked',v_count,'date',p_date);
end;
$function$;

CREATE OR REPLACE FUNCTION public.ncaa_first_round_date(p_year integer)
 RETURNS date
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  select make_date(p_year,5,1)
    + ((5-extract(dow from make_date(p_year,5,1))::int+7)%7);
$function$;

CREATE OR REPLACE FUNCTION public.ensure_ncaa_championship_field(p_year integer, p_as_of date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  selection_date date;
  first_round date;
  teams bigint[];
  seed_order int[]:=array[
    1,64,32,33,16,49,17,48,8,57,25,40,9,56,24,41,
    4,61,29,36,13,52,20,45,5,60,28,37,12,53,21,44,
    2,63,31,34,15,50,18,47,7,58,26,39,10,55,23,42,
    3,62,30,35,14,51,19,46,6,59,27,38,11,54,22,43
  ];
  slot int;
  h bigint;
  a bigint;
  inserted int:=0;
begin
  first_round:=public.ncaa_first_round_date(p_year);
  selection_date:=first_round-4;

  if p_as_of<selection_date then
    return jsonb_build_object('created',0,'reason','selection_not_reached','selection_date',selection_date);
  end if;

  if exists(
    select 1 from public.college_duals
    where extract(year from match_date)::int=p_year
      and competition='NCAA Division I Championship'
      and stage='R64'
  ) then
    return jsonb_build_object('created',0,'already',true);
  end if;

  select array_agg(id order by coalesce(ita_rank,preseason_rank,9999),id)
  into teams
  from public.college_teams
  limit 64;

  if coalesce(array_length(teams,1),0)<64 then
    return jsonb_build_object('created',0,'reason','need_64_teams');
  end if;

  for slot in 1..32 loop
    h:=teams[seed_order[(slot-1)*2+1]];
    a:=teams[seed_order[(slot-1)*2+2]];

    insert into public.college_duals(
      match_date,home_team_id,away_team_id,status,
      competition,stage,bracket_slot,source_label,model_version
    ) values(
      first_round,h,a,'scheduled',
      'NCAA Division I Championship','R64',slot,
      'Court Boss NCAA 64-team championship v1','CB-NCAA-CHAMP-v1'
    );
    inserted:=inserted+1;
  end loop;

  return jsonb_build_object(
    'created',inserted,'selection_date',selection_date,'first_round',first_round,
    'format','64-team single elimination'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.advance_ncaa_championship(p_year integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  rec record;
  s int;
  a bigint;
  b bigint;
  created int:=0;
  first_round date:=public.ncaa_first_round_date(p_year);
begin
  for rec in
    select * from (values
      ('R64'::text,'R32'::text,16,first_round+2),
      ('R32','R16',8,first_round+8),
      ('R16','QF',4,first_round+13),
      ('QF','SF',2,first_round+15),
      ('SF','F',1,first_round+16)
    ) v(from_stage,to_stage,next_matches,match_date)
  loop
    for s in 1..rec.next_matches loop
      if exists(
        select 1 from public.college_duals
        where competition='NCAA Division I Championship'
          and extract(year from match_date)::int=p_year
          and stage=rec.to_stage and bracket_slot=s
      ) then
        continue;
      end if;

      select winner_team_id into a
      from public.college_duals
      where competition='NCAA Division I Championship'
        and extract(year from match_date)::int=p_year
        and stage=rec.from_stage and bracket_slot=s*2-1
        and status='completed';

      select winner_team_id into b
      from public.college_duals
      where competition='NCAA Division I Championship'
        and extract(year from match_date)::int=p_year
        and stage=rec.from_stage and bracket_slot=s*2
        and status='completed';

      if a is null or b is null then continue; end if;

      insert into public.college_duals(
        match_date,home_team_id,away_team_id,status,
        competition,stage,bracket_slot,source_label,model_version
      ) values(
        rec.match_date,a,b,'scheduled',
        'NCAA Division I Championship',rec.to_stage,s,
        'Court Boss NCAA 64-team championship v1','CB-NCAA-CHAMP-v1'
      );
      created:=created+1;
    end loop;
  end loop;

  return jsonb_build_object('created',created,'season',p_year);
end;
$function$;

CREATE OR REPLACE FUNCTION public.simulate_ncaa_dual_v2(p_dual_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  d public.college_duals%rowtype;
  hp numeric;
  ap numeric;
  prob numeric;
  roll numeric;
  homewin boolean;
  loser_score int;
  hline bigint[];
  aline bigint[];
  v_winner bigint;
  v_runner bigint;
  v_year int;
  v_advance jsonb;
begin
  select * into d
  from public.college_duals
  where id=p_dual_id
  for update;

  if d.id is null then
    return jsonb_build_object('ok',false,'reason','dual_not_found');
  end if;
  if d.status='completed' then
    return jsonb_build_object(
      'ok',true,'already',true,'dual_id',d.id,
      'home_score',d.home_score,'away_score',d.away_score,
      'winner_team_id',d.winner_team_id
    );
  end if;
  if d.status<>'scheduled' then
    return jsonb_build_object('ok',false,'reason','dual_not_scheduled','status',d.status);
  end if;

  hline:=public.ncaa_team_lineup(d.home_team_id,d.match_date);
  aline:=public.ncaa_team_lineup(d.away_team_id,d.match_date);

  if coalesce(array_length(hline,1),0)<4 or coalesce(array_length(aline,1),0)<4 then
    update public.college_duals
    set status='postponed',
        model_version='CB-NCAA-v2 · insufficient roster'
    where id=d.id;
    return jsonb_build_object('ok',false,'reason','insufficient_roster','dual_id',d.id);
  end if;

  hp:=public.ncaa_team_power(d.home_team_id,d.match_date);
  ap:=public.ncaa_team_power(d.away_team_id,d.match_date);

  prob:=greatest(.06,least(.94,
    1/(1+exp(-((hp-ap)
      +case
        when d.competition='NCAA Division I Championship'
             and d.stage in ('QF','SF','F') then 0
        else 1.6 end
    )/6.8))
  ));

  roll:=mod(abs(hashtext('ncaa-dual-v2|'||d.id||'|'||d.match_date)),10000)/10000.0;
  homewin:=roll<prob;
  loser_score:=case
    when abs(prob-.5)<.06 then 3
    when abs(prob-.5)<.14 then 2
    when abs(prob-.5)<.25 then 1
    else 0 end;

  v_winner:=case when homewin then d.home_team_id else d.away_team_id end;
  v_runner:=case when homewin then d.away_team_id else d.home_team_id end;

  update public.college_duals
  set home_score=case when homewin then 4 else loser_score end,
      away_score=case when homewin then loser_score else 4 end,
      status='completed',
      winner_team_id=v_winner,
      home_win_probability=round(prob,4),
      home_player_ids=hline,
      away_player_ids=aline,
      model_version=case
        when d.competition='NCAA Division I Championship' then 'CB-NCAA-CHAMP-v2'
        else 'CB-NCAA-v2' end
  where id=d.id;

  update public.players
  set fatigue=least(100,coalesce(fatigue,20)+
        case when d.competition='NCAA Division I Championship' then 6 else 4 end),
      fitness=greatest(35,coalesce(fitness,90)-1),
      form=greatest(1,least(100,coalesce(form,70)+
        case
          when id=any(case when homewin then hline else aline end) then 1
          else -1 end))
  where id=any(hline) or id=any(aline);

  v_year:=extract(year from d.match_date)::int;
  if d.competition='NCAA Division I Championship' then
    v_advance:=public.advance_ncaa_championship(v_year);
    if d.stage='F' then
      insert into public.college_championship_history(
        season,champion_team_id,runner_up_team_id,final_score,source_label
      ) values(
        v_year,v_winner,v_runner,
        case when homewin then '4-'||loser_score else loser_score||'-4' end,
        'Court Boss simulated NCAA championship v2'
      )
      on conflict(season) do update set
        champion_team_id=excluded.champion_team_id,
        runner_up_team_id=excluded.runner_up_team_id,
        final_score=excluded.final_score,
        source_label=excluded.source_label;
    end if;
  end if;

  return jsonb_build_object(
    'ok',true,'dual_id',d.id,
    'home_score',case when homewin then 4 else loser_score end,
    'away_score',case when homewin then loser_score else 4 end,
    'winner_team_id',v_winner,
    'home_win_probability',round(prob,4),
    'stage',d.stage,'competition',d.competition
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.simulate_ncaa_duals(p_from_date date, p_to_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  v_year int:=extract(year from p_to_date)::int;
  v_schedule jsonb;
  v_field jsonb;
  v_result jsonb;
  v_id bigint;
  simulated int:=0;
  postponed int:=0;
begin
  v_schedule:=public.ensure_ncaa_regular_schedule(v_year);
  v_field:=public.ensure_ncaa_championship_field(v_year,p_to_date);

  loop
    select id into v_id
    from public.college_duals
    where match_date>p_from_date
      and match_date<=p_to_date
      and status='scheduled'
      and coalesce(competition,'NCAA Division I')
          in ('NCAA Division I','NCAA Division I Championship')
    order by match_date,
      case when competition='NCAA Division I Championship' then 0 else 1 end,
      id
    limit 1;

    exit when v_id is null;

    v_result:=public.simulate_ncaa_dual_v2(v_id);
    if coalesce((v_result->>'ok')::boolean,false) then
      simulated:=simulated+1;
    elsif v_result->>'reason'='insufficient_roster' then
      postponed:=postponed+1;
    end if;
  end loop;

  perform public.refresh_ncaa_team_rankings(p_to_date);

  return jsonb_build_object(
    'duals_simulated',simulated,'duals_postponed',postponed,
    'schedule',v_schedule,'championship_field',v_field,
    'from',p_from_date,'to',p_to_date,
    'model','NCAA v2 · shared dual engine + generated regular season + dynamic 64-team championship'
  );
end;
$function$;


select public.ensure_ncaa_regular_schedule(2026);
