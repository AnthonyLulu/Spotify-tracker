-- Court Boss NCAA team events engine
-- Kickoff Weekend pods, National Team Indoor, cross-calendar blocking and dual rescheduling.

create table if not exists public.college_team_event_entries(
  tournament_id bigint not null references public.tournaments(id) on delete cascade,
  team_id bigint not null references public.college_teams(id) on delete cascade,
  seed integer,
  entry_type text not null default 'selection',
  pod_no integer,
  result_code text,
  qualified_next_event boolean not null default false,
  primary key(tournament_id,team_id)
);
alter table public.college_team_event_entries enable row level security;
create index if not exists college_team_event_entries_team_idx
  on public.college_team_event_entries(team_id,tournament_id);

create table if not exists public.college_team_event_simulations(
  tournament_id bigint primary key references public.tournaments(id) on delete cascade,
  simulated_on date not null,
  champion_team_id bigint references public.college_teams(id),
  runner_up_team_id bigint references public.college_teams(id),
  model_version text not null,
  created_at timestamptz not null default now()
);
alter table public.college_team_event_simulations enable row level security;

create table if not exists public.college_team_event_history(
  id bigserial primary key,
  season integer not null,
  tournament_name text not null,
  category text not null,
  champion_team_id bigint references public.college_teams(id),
  runner_up_team_id bigint references public.college_teams(id),
  final_score text,
  source_label text not null,
  unique(season,tournament_name)
);
alter table public.college_team_event_history enable row level security;

CREATE OR REPLACE FUNCTION public.player_in_ncaa_team_event(p_player_id bigint, p_start date, p_end date)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  select exists(
    select 1
    from public.players p
    join public.college_teams ct on ct.name=p.ncaa_school
    join public.college_team_event_entries ce on ce.team_id=ct.id
    join public.tournaments t on t.id=ce.tournament_id
    where p.id=p_player_id
      and p.ncaa_current=true
      and daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
          && daterange(p_start,p_end,'[]')
  );
$function$;

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
      and daterange(
            coalesce(t.qualifying_start_date,t.main_draw_start_date,t.start_date),
            coalesce(t.end_date,t.start_date),'[]'
          ) && daterange(p_week_start,p_week_start+6,'[]')

    union all
    select 1
    from public.world_tournament_qualifying_entries e
    join public.tournaments t on t.id=e.tournament_id
    where e.player_id=p_player_id
      and t.id is distinct from p_exclude_tournament_id
      and daterange(
            coalesce(t.qualifying_start_date,t.start_date),
            coalesce(t.qualifying_end_date,t.main_draw_start_date,t.end_date,t.start_date),'[]'
          ) && daterange(p_week_start,p_week_start+6,'[]')

    union all
    select 1
    from public.world_doubles_tournament_entries e
    join public.world_doubles_partnerships p on p.id=e.pair_id
    join public.tournaments t on t.id=e.tournament_id
    where p_player_id in (p.player_a_id,p.player_b_id)
      and t.id is distinct from p_exclude_tournament_id
      and daterange(
            coalesce(t.qualifying_start_date,t.main_draw_start_date,t.start_date),
            coalesce(t.end_date,t.start_date),'[]'
          ) && daterange(p_week_start,p_week_start+6,'[]')

    union all
    select 1
    from public.world_junior_doubles_entries e
    join public.tournaments t on t.id=e.tournament_id
    where p_player_id in (e.player_a_id,e.player_b_id)
      and t.id is distinct from p_exclude_tournament_id
      and daterange(coalesce(t.start_date,t.main_draw_start_date),coalesce(t.end_date,t.start_date),'[]')
          && daterange(p_week_start,p_week_start+6,'[]')

    union all
    select 1
    from public.ncaa_individual_entries e
    join public.tournaments t on t.id=e.tournament_id
    where e.player_id=p_player_id
      and t.id is distinct from p_exclude_tournament_id
      and daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
          && daterange(p_week_start,p_week_start+6,'[]')

    union all
    select 1
    from public.ncaa_individual_doubles_entries e
    join public.tournaments t on t.id=e.tournament_id
    where p_player_id in (e.player_a_id,e.player_b_id)
      and t.id is distinct from p_exclude_tournament_id
      and daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
          && daterange(p_week_start,p_week_start+6,'[]')

    union all
    select 1
    from public.players pl
    join public.college_teams ct on ct.name=pl.ncaa_school
    join public.college_team_event_entries ce on ce.team_id=ct.id
    join public.tournaments et on et.id=ce.tournament_id
    where pl.id=p_player_id
      and pl.ncaa_current=true
      and et.id is distinct from p_exclude_tournament_id
      and daterange(et.start_date,coalesce(et.end_date,et.start_date),'[]')
          && daterange(p_week_start,p_week_start+6,'[]')

    union all
    select 1
    from public.davis_squad ds
    join public.davis_ties dt on ds.nation in (dt.home_nation,dt.away_nation)
    where ds.player_id=p_player_id
      and dt.status in ('scheduled','completed')
      and dt.tie_date between p_week_start and p_week_start+6

    union all
    select 1
    from public.players pl
    join public.college_teams ct on ct.name=pl.ncaa_school
    join public.college_duals cd on ct.id in (cd.home_team_id,cd.away_team_id)
    where pl.id=p_player_id
      and pl.ncaa_current=true
      and cd.status in ('scheduled','completed')
      and cd.match_date between p_week_start and p_week_start+6
  );
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
    and dt.tie_date between commit_start and commit_end
  order by dt.tie_date,dt.id
  limit 1;

  if c.tournament_id is not null then
    return jsonb_build_object(
      'conflict',true,'reason','national_team_commitment',
      'other_davis_tie_id',c.tournament_id,'other_event',c.tournament_name,
      'other_discipline','davis'
    );
  end if;

  c:=null;
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
    and cd.match_date between commit_start and commit_end
  order by cd.match_date,cd.id
  limit 1;

  if c.tournament_id is not null then
    return jsonb_build_object(
      'conflict',true,'reason','college_team_commitment',
      'other_college_dual_id',c.tournament_id,'other_event',c.tournament_name,
      'other_discipline','ncaa'
    );
  end if;

  c:=null;
  select et.id tournament_id,
         et.name tournament_name,
         et.start_date,
         et.end_date,
         'ncaa_team_event'::text discipline
  into c
  from public.players pl
  join public.college_teams ct on ct.name=pl.ncaa_school
  join public.college_team_event_entries ce on ce.team_id=ct.id
  join public.tournaments et on et.id=ce.tournament_id
  where pl.id=p_player_id
    and pl.ncaa_current=true
    and et.id<>t.id
    and daterange(et.start_date,coalesce(et.end_date,et.start_date),'[]')
        && daterange(commit_start,commit_end,'[]')
  order by et.start_date,et.id
  limit 1;

  if c.tournament_id is not null then
    return jsonb_build_object(
      'conflict',true,'reason','college_team_event_commitment',
      'other_tournament_id',c.tournament_id,
      'other_tournament',c.tournament_name,
      'other_discipline','ncaa_team_event'
    );
  end if;

  c:=null;
  select x.tournament_id,x.tournament_name,x.start_date,x.end_date,x.discipline
  into c
  from (
    select ot.id tournament_id,ot.name tournament_name,ot.start_date,ot.end_date,'singles'::text discipline
    from public.world_tournament_entries e
    join public.tournaments ot on ot.id=e.tournament_id
    where e.player_id=p_player_id and ot.id<>t.id
      and daterange(
            coalesce(ot.qualifying_start_date,ot.main_draw_start_date,ot.start_date),
            coalesce(ot.end_date,ot.start_date),'[]'
          ) && daterange(commit_start,commit_end,'[]')

    union all
    select ot.id,ot.name,ot.start_date,ot.end_date,'qualifying'
    from public.world_tournament_qualifying_entries e
    join public.tournaments ot on ot.id=e.tournament_id
    where e.player_id=p_player_id and ot.id<>t.id
      and daterange(
            coalesce(ot.qualifying_start_date,ot.start_date),
            coalesce(ot.qualifying_end_date,ot.main_draw_start_date,ot.end_date,ot.start_date),'[]'
          ) && daterange(commit_start,commit_end,'[]')

    union all
    select ot.id,ot.name,ot.start_date,ot.end_date,'doubles'
    from public.world_doubles_tournament_entries e
    join public.world_doubles_partnerships p on p.id=e.pair_id
    join public.tournaments ot on ot.id=e.tournament_id
    where p_player_id in (p.player_a_id,p.player_b_id) and ot.id<>t.id
      and daterange(
            coalesce(ot.qualifying_start_date,ot.main_draw_start_date,ot.start_date),
            coalesce(ot.end_date,ot.start_date),'[]'
          ) && daterange(commit_start,commit_end,'[]')

    union all
    select ot.id,ot.name,ot.start_date,ot.end_date,'junior_doubles'
    from public.world_junior_doubles_entries e
    join public.tournaments ot on ot.id=e.tournament_id
    where p_player_id in (e.player_a_id,e.player_b_id) and ot.id<>t.id
      and daterange(ot.start_date,coalesce(ot.end_date,ot.start_date),'[]')
          && daterange(commit_start,commit_end,'[]')

    union all
    select ot.id,ot.name,ot.start_date,ot.end_date,'ncaa_individual'
    from public.ncaa_individual_entries e
    join public.tournaments ot on ot.id=e.tournament_id
    where e.player_id=p_player_id and ot.id<>t.id
      and daterange(ot.start_date,coalesce(ot.end_date,ot.start_date),'[]')
          && daterange(commit_start,commit_end,'[]')

    union all
    select ot.id,ot.name,ot.start_date,ot.end_date,'ncaa_doubles'
    from public.ncaa_individual_doubles_entries e
    join public.tournaments ot on ot.id=e.tournament_id
    where p_player_id in (e.player_a_id,e.player_b_id) and ot.id<>t.id
      and daterange(ot.start_date,coalesce(ot.end_date,ot.start_date),'[]')
          && daterange(commit_start,commit_end,'[]')
  ) x
  order by x.start_date,x.tournament_id
  limit 1;

  if c.tournament_id is not null then
    return jsonb_build_object(
      'conflict',true,'reason','calendar_overlap',
      'other_tournament_id',c.tournament_id,'other_tournament',c.tournament_name,
      'other_discipline',c.discipline
    );
  end if;

  if managed_id is not null and p_player_id=managed_id then
    c:=null;
    select x.tournament_id,x.tournament_name,x.start_date,x.end_date,x.discipline
    into c
    from (
      select tr.tournament_id,ot.name tournament_name,ot.start_date,ot.end_date,'singles'::text discipline,
             coalesce(ot.qualifying_start_date,ot.main_draw_start_date,ot.start_date) event_start
      from public.tournament_runs tr
      join public.tournaments ot on ot.id=tr.tournament_id
      where tr.tournament_id<>t.id
      union all
      select dr.tournament_id,ot.name,ot.start_date,ot.end_date,'doubles',
             coalesce(ot.qualifying_start_date,ot.main_draw_start_date,ot.start_date)
      from public.doubles_runs dr
      join public.tournaments ot on ot.id=dr.tournament_id
      where dr.tournament_id<>t.id
    ) x
    where daterange(x.event_start,coalesce(x.end_date,x.start_date),'[]')
          && daterange(commit_start,commit_end,'[]')
    order by x.event_start
    limit 1;

    if c.tournament_id is not null then
      return jsonb_build_object(
        'conflict',true,'reason','calendar_overlap',
        'other_tournament_id',c.tournament_id,'other_tournament',c.tournament_name,
        'other_discipline',c.discipline
      );
    end if;
  end if;

  if method in ('qualifying','qualifying_wildcard','protected_qualifying','doubles_qualifying') then
    c:=null;
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

CREATE OR REPLACE FUNCTION public.ncaa_individual_player_available(p_player_id bigint, p_tournament_id bigint)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
begin
  select * into t from public.tournaments where id=p_tournament_id;
  if t.id is null then return false; end if;

  if not exists(
    select 1 from public.players p
    where p.id=p_player_id
      and p.ncaa_current=true
      and p.career_status='active'
      and p.injury_status='Fit'
      and coalesce(p.fitness,90)>=45
  ) then return false; end if;

  if exists(
    select 1
    from public.ncaa_individual_entries e
    join public.tournaments ot on ot.id=e.tournament_id
    where e.player_id=p_player_id
      and ot.id<>t.id
      and daterange(ot.start_date,coalesce(ot.end_date,ot.start_date),'[]')
          && daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
  ) then return false; end if;

  if exists(
    select 1
    from public.ncaa_individual_doubles_entries e
    join public.tournaments ot on ot.id=e.tournament_id
    where p_player_id in (e.player_a_id,e.player_b_id)
      and ot.id<>t.id
      and daterange(ot.start_date,coalesce(ot.end_date,ot.start_date),'[]')
          && daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
  ) then return false; end if;

  if exists(
    select 1
    from public.world_tournament_entries e
    join public.tournaments ot on ot.id=e.tournament_id
    where e.player_id=p_player_id
      and daterange(
            coalesce(ot.qualifying_start_date,ot.main_draw_start_date,ot.start_date),
            coalesce(ot.end_date,ot.start_date),'[]'
          ) && daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
  ) then return false; end if;

  if exists(
    select 1
    from public.world_tournament_qualifying_entries e
    join public.tournaments ot on ot.id=e.tournament_id
    where e.player_id=p_player_id
      and daterange(
            coalesce(ot.qualifying_start_date,ot.start_date),
            coalesce(ot.qualifying_end_date,ot.main_draw_start_date,ot.end_date,ot.start_date),'[]'
          ) && daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
  ) then return false; end if;

  if exists(
    select 1
    from public.world_doubles_tournament_entries e
    join public.world_doubles_partnerships wp on wp.id=e.pair_id
    join public.tournaments ot on ot.id=e.tournament_id
    where p_player_id in (wp.player_a_id,wp.player_b_id)
      and daterange(
            coalesce(ot.qualifying_start_date,ot.main_draw_start_date,ot.start_date),
            coalesce(ot.end_date,ot.start_date),'[]'
          ) && daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
  ) then return false; end if;

  if exists(
    select 1
    from public.davis_squad ds
    join public.davis_ties dt on ds.nation in (dt.home_nation,dt.away_nation)
    where ds.player_id=p_player_id
      and dt.status in ('scheduled','completed')
      and dt.tie_date between t.start_date and coalesce(t.end_date,t.start_date)
  ) then return false; end if;

  if public.player_in_ncaa_team_event(
    p_player_id,t.start_date,coalesce(t.end_date,t.start_date)
  ) then return false; end if;

  return true;
end;
$function$;

CREATE OR REPLACE FUNCTION public.ensure_ncaa_team_event_entries(p_tournament_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  v_count int:=0;
  v_year int;
  kickoff_id bigint;
begin
  select * into t from public.tournaments where id=p_tournament_id;
  if t.id is null or t.circuit<>'NCAA' then
    return jsonb_build_object('ok',false,'reason','not_ncaa');
  end if;

  if t.category='ITA Kickoff Weekend' then
    if not exists(select 1 from public.college_team_event_entries where tournament_id=t.id) then
      with ranked as (
        select ct.id,
               row_number() over(order by coalesce(ct.ita_rank,ct.preseason_rank,999),ct.id)::int rk
        from public.college_teams ct
      ),
      field as (
        select id,rk,
               row_number() over(order by rk)::int field_seed
        from ranked
        where rk between 3 and 58
        order by rk
        limit 56
      )
      insert into public.college_team_event_entries(
        tournament_id,team_id,seed,entry_type,pod_no
      )
      select t.id,id,field_seed,'kickoff_selection',ceil(field_seed/4.0)::int
      from field;
    end if;

  elsif t.category='ITA National Team Indoor Championship' then
    v_year:=extract(year from t.start_date)::int;
    select id into kickoff_id
    from public.tournaments
    where circuit='NCAA'
      and category='ITA Kickoff Weekend'
      and extract(year from start_date)::int=v_year
    order by start_date
    limit 1;

    if kickoff_id is null then
      return jsonb_build_object('ok',false,'reason','kickoff_missing');
    end if;

    if not exists(
      select 1 from public.college_team_event_simulations where tournament_id=kickoff_id
    ) then
      return jsonb_build_object('ok',false,'reason','kickoff_not_completed');
    end if;

    if not exists(select 1 from public.college_team_event_entries where tournament_id=t.id) then
      -- 14 Kickoff pod winners + two automatic game-world bids (top two ITA teams).
      insert into public.college_team_event_entries(
        tournament_id,team_id,seed,entry_type,pod_no
      )
      select t.id,x.team_id,
             row_number() over(order by x.priority,x.rank_key,x.team_id)::int,
             x.entry_type,null
      from (
        select e.team_id,1 priority,coalesce(ct.ita_rank,999) rank_key,'kickoff_winner'::text entry_type
        from public.college_team_event_entries e
        join public.college_teams ct on ct.id=e.team_id
        where e.tournament_id=kickoff_id and e.qualified_next_event=true

        union all

        select ct.id,0,coalesce(ct.ita_rank,999),'automatic_bid'
        from public.college_teams ct
        where ct.id not in (
          select e.team_id
          from public.college_team_event_entries e
          where e.tournament_id=kickoff_id and e.qualified_next_event=true
        )
        order by 2,3,1
        limit 16
      ) x
      order by x.priority,x.rank_key,x.team_id
      limit 16;
    end if;

  else
    return jsonb_build_object('ok',false,'reason','unsupported_team_event','category',t.category);
  end if;

  select count(*) into v_count
  from public.college_team_event_entries where tournament_id=t.id;

  return jsonb_build_object('ok',true,'tournament_id',t.id,'entries',v_count,'category',t.category);
end;
$function$;

CREATE OR REPLACE FUNCTION public.ncaa_team_event_dual(p_tournament_id bigint, p_home_team_id bigint, p_away_team_id bigint, p_match_date date, p_stage text, p_slot integer)
 RETURNS bigint
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  v_id bigint;
  v_result jsonb;
begin
  select * into t from public.tournaments where id=p_tournament_id;
  if t.id is null then raise exception 'team event tournament % not found',p_tournament_id; end if;

  select id into v_id
  from public.college_duals
  where competition=t.name
    and stage=p_stage
    and bracket_slot=p_slot
    and home_team_id=p_home_team_id
    and away_team_id=p_away_team_id
  order by id
  limit 1;

  if v_id is null then
    insert into public.college_duals(
      match_date,home_team_id,away_team_id,status,competition,stage,bracket_slot,
      source_label,model_version,surface,indoor
    ) values(
      p_match_date,p_home_team_id,p_away_team_id,'scheduled',t.name,p_stage,p_slot,
      'Court Boss NCAA team event v1','CB-NCAA-TEAM-v1',coalesce(t.surface,'Dur'),coalesce(t.indoor,false)
    )
    returning id into v_id;
  end if;

  v_result:=public.simulate_ncaa_dual_v2(v_id);
  if coalesce((v_result->>'ok')::boolean,false)=false then
    raise exception 'NCAA team-event dual % failed: %',v_id,v_result::text;
  end if;

  return v_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.simulate_ita_kickoff_weekend(p_tournament_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  prep jsonb;
  pod int;
  teams bigint[];
  sf1 bigint;
  sf2 bigint;
  f bigint;
  w1 bigint;
  w2 bigint;
  wf bigint;
  lf bigint;
  v_count int:=0;
begin
  select * into t from public.tournaments where id=p_tournament_id;
  if t.id is null or t.category<>'ITA Kickoff Weekend' then
    return jsonb_build_object('ok',false,'reason','not_kickoff');
  end if;

  if exists(select 1 from public.college_team_event_simulations where tournament_id=t.id) then
    return jsonb_build_object('ok',true,'already',true,'tournament_id',t.id);
  end if;

  prep:=public.ensure_ncaa_team_event_entries(t.id);
  if coalesce((prep->>'ok')::boolean,false)=false then return prep; end if;

  for pod in 1..14 loop
    select array_agg(team_id order by seed)
    into teams
    from public.college_team_event_entries
    where tournament_id=t.id and pod_no=pod;

    if coalesce(array_length(teams,1),0)<>4 then
      return jsonb_build_object('ok',false,'reason','bad_pod_size','pod',pod,'size',coalesce(array_length(teams,1),0));
    end if;

    sf1:=public.ncaa_team_event_dual(t.id,teams[1],teams[4],t.start_date,'Pod '||pod||' SF1',pod*10+1);
    sf2:=public.ncaa_team_event_dual(t.id,teams[2],teams[3],t.start_date,'Pod '||pod||' SF2',pod*10+2);

    select winner_team_id into w1 from public.college_duals where id=sf1;
    select winner_team_id into w2 from public.college_duals where id=sf2;

    update public.college_team_event_entries
    set result_code='SF'
    where tournament_id=t.id and team_id in (
      case when w1=teams[1] then teams[4] else teams[1] end,
      case when w2=teams[2] then teams[3] else teams[2] end
    );

    f:=public.ncaa_team_event_dual(
      t.id,w1,w2,least(coalesce(t.end_date,t.start_date),t.start_date+1),
      'Pod '||pod||' Final',pod*10+3
    );
    select winner_team_id into wf from public.college_duals where id=f;
    lf:=case when wf=w1 then w2 else w1 end;

    update public.college_team_event_entries
    set result_code='F'
    where tournament_id=t.id and team_id=lf;

    update public.college_team_event_entries
    set result_code='W',qualified_next_event=true
    where tournament_id=t.id and team_id=wf;

    v_count:=v_count+1;
  end loop;

  insert into public.college_team_event_simulations(
    tournament_id,simulated_on,champion_team_id,runner_up_team_id,model_version
  ) values(
    t.id,coalesce(t.end_date,t.start_date),null,null,'CB-ITA-KICKOFF-v1'
  )
  on conflict(tournament_id) do nothing;

  return jsonb_build_object(
    'ok',true,'tournament_id',t.id,'pods_completed',v_count,
    'qualifiers',(select count(*) from public.college_team_event_entries where tournament_id=t.id and qualified_next_event=true),
    'model','ITA Kickoff Weekend · 14 four-team pods'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.simulate_ita_national_indoor(p_tournament_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  prep jsonb;
  seed_order int[]:=array[1,16,8,9,4,13,5,12,2,15,7,10,3,14,6,11];
  teams bigint[];
  next_teams bigint[];
  n int;
  i int;
  round_no int:=1;
  round_code text;
  match_no int;
  did bigint;
  w bigint;
  loser bigint;
  champion bigint;
  runner bigint;
  final_score text;
  played date;
begin
  select * into t from public.tournaments where id=p_tournament_id;
  if t.id is null or t.category<>'ITA National Team Indoor Championship' then
    return jsonb_build_object('ok',false,'reason','not_indoor');
  end if;

  if exists(select 1 from public.college_team_event_simulations where tournament_id=t.id) then
    return jsonb_build_object('ok',true,'already',true,'tournament_id',t.id);
  end if;

  prep:=public.ensure_ncaa_team_event_entries(t.id);
  if coalesce((prep->>'ok')::boolean,false)=false then return prep; end if;

  select array_agg(e.team_id order by array_position(seed_order,e.seed))
  into teams
  from public.college_team_event_entries e
  where e.tournament_id=t.id;

  if coalesce(array_length(teams,1),0)<>16 then
    return jsonb_build_object('ok',false,'reason','bad_indoor_field','entries',coalesce(array_length(teams,1),0));
  end if;

  while coalesce(array_length(teams,1),0)>1 loop
    n:=array_length(teams,1);
    round_code:=case n when 16 then 'R16' when 8 then 'QF' when 4 then 'SF' else 'F' end;
    next_teams:='{}'::bigint[];
    match_no:=0;
    played:=least(coalesce(t.end_date,t.start_date),t.start_date+(round_no-1));

    i:=1;
    while i<=n loop
      match_no:=match_no+1;
      did:=public.ncaa_team_event_dual(
        t.id,teams[i],teams[i+1],played,round_code,(round_no*100)+match_no
      );
      select winner_team_id into w from public.college_duals where id=did;
      loser:=case when w=teams[i] then teams[i+1] else teams[i] end;

      update public.college_team_event_entries
      set result_code=round_code
      where tournament_id=t.id and team_id=loser;

      if round_code='F' then
        champion:=w;
        runner:=loser;
        select home_score||'-'||away_score into final_score
        from public.college_duals where id=did;
      end if;

      next_teams:=array_append(next_teams,w);
      i:=i+2;
    end loop;

    teams:=next_teams;
    round_no:=round_no+1;
  end loop;

  update public.college_team_event_entries
  set result_code='W'
  where tournament_id=t.id and team_id=champion;

  insert into public.college_team_event_simulations(
    tournament_id,simulated_on,champion_team_id,runner_up_team_id,model_version
  ) values(
    t.id,coalesce(t.end_date,t.start_date),champion,runner,'CB-ITA-INDOOR-v1'
  );

  insert into public.college_team_event_history(
    season,tournament_name,category,champion_team_id,runner_up_team_id,final_score,source_label
  ) values(
    extract(year from t.start_date)::int,t.name,t.category,champion,runner,final_score,
    'Court Boss simulated ITA team event v1'
  )
  on conflict(season,tournament_name) do update set
    champion_team_id=excluded.champion_team_id,
    runner_up_team_id=excluded.runner_up_team_id,
    final_score=excluded.final_score,
    source_label=excluded.source_label;

  return jsonb_build_object(
    'ok',true,'tournament_id',t.id,'champion_team_id',champion,
    'runner_up_team_id',runner,'final_score',final_score,
    'model','ITA National Team Indoor · 16-team knockout'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.simulate_ncaa_team_events(p_from_date date, p_to_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  rec record;
  r jsonb;
  prepared int:=0;
  simulated int:=0;
begin
  for rec in
    select *
    from public.tournaments
    where circuit='NCAA'
      and coalesce(is_active,true)=true
      and category in ('ITA Kickoff Weekend','ITA National Team Indoor Championship')
      and start_date<=p_to_date
      and coalesce(end_date,start_date)>=p_from_date
    order by start_date,id
  loop
    r:=public.ensure_ncaa_team_event_entries(rec.id);
    if coalesce((r->>'ok')::boolean,false) then prepared:=prepared+1; end if;
  end loop;

  for rec in
    select *
    from public.tournaments
    where circuit='NCAA'
      and coalesce(is_active,true)=true
      and category in ('ITA Kickoff Weekend','ITA National Team Indoor Championship')
      and coalesce(end_date,start_date)>p_from_date
      and coalesce(end_date,start_date)<=p_to_date
      and not exists(
        select 1 from public.college_team_event_simulations s where s.tournament_id=tournaments.id
      )
    order by coalesce(end_date,start_date),id
  loop
    if rec.category='ITA Kickoff Weekend' then
      r:=public.simulate_ita_kickoff_weekend(rec.id);
    else
      r:=public.simulate_ita_national_indoor(rec.id);
    end if;

    if coalesce((r->>'ok')::boolean,false) then simulated:=simulated+1; end if;
  end loop;

  perform public.refresh_ncaa_team_rankings(p_to_date);

  return jsonb_build_object(
    'events_prepared',prepared,'events_simulated',simulated,
    'from',p_from_date,'to',p_to_date,
    'model','NCAA team events v1 · Kickoff pods + National Indoor'
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
  d public.college_duals%rowtype;
  v_conflict_end date;
  v_new_date date;
  simulated int:=0;
  postponed int:=0;
  rescheduled int:=0;
begin
  v_schedule:=public.ensure_ncaa_regular_schedule(v_year);
  v_field:=public.ensure_ncaa_championship_field(v_year,p_to_date);

  loop
    select * into d
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

    exit when d.id is null;

    if coalesce(d.competition,'NCAA Division I')='NCAA Division I' then
      select max(coalesce(t.end_date,t.start_date))
      into v_conflict_end
      from public.college_team_event_entries ce
      join public.tournaments t on t.id=ce.tournament_id
      where ce.team_id in (d.home_team_id,d.away_team_id)
        and d.match_date between t.start_date and coalesce(t.end_date,t.start_date);

      if v_conflict_end is not null then
        v_new_date:=v_conflict_end+2;
        update public.college_duals
        set match_date=v_new_date,
            status='scheduled',
            model_version='CB-NCAA-v3 · rescheduled around team event'
        where id=d.id;
        postponed:=postponed+1;
        rescheduled:=rescheduled+1;
        continue;
      end if;
    end if;

    v_result:=public.simulate_ncaa_dual_v2(d.id);

    if coalesce((v_result->>'ok')::boolean,false) then
      simulated:=simulated+1;
    elsif v_result->>'reason'='insufficient_roster' then
      postponed:=postponed+1;
      v_new_date:=d.match_date+3;
      update public.college_duals
      set match_date=v_new_date,
          status='scheduled',
          model_version='CB-NCAA-v3 · roster postponement'
      where id=d.id;
      rescheduled:=rescheduled+1;
    end if;
  end loop;

  perform public.refresh_ncaa_team_rankings(p_to_date);

  return jsonb_build_object(
    'duals_simulated',simulated,
    'duals_postponed',postponed,
    'duals_rescheduled',rescheduled,
    'schedule',v_schedule,
    'championship_field',v_field,
    'from',p_from_date,'to',p_to_date,
    'model','NCAA v3 · full rubbers + team-event aware rescheduling + dynamic championship'
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
      and coalesce(d.competition,'NCAA Division I') in (
        'NCAA Division I',
        'ITA Kickoff Weekend',
        'ITA National Team Indoor Championship'
      )
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
          coalesce(ip.points,0)*.11+
          coalesce(us.current_rating,10)*3.0+
          coalesce(p.current_ability,50)*1.0+
          coalesce(p.form,70)*.12+
          greatest(0,65-coalesce(ct.ita_rank,64))*.16
        ) desc,
        p.id
      )::int new_rank
    from public.players p
    left join public.player_utr_state us on us.player_id=p.id
    left join public.college_teams ct on ct.name=p.ncaa_school
    left join public.ncaa_individual_points ip
      on ip.player_id=p.id and ip.season=extract(year from p_date)::int
    where p.ncaa_current=true and p.career_status='active'
  )
  update public.players p
  set ncaa_rank=pr.new_rank
  from pr where p.id=pr.id;

  return jsonb_build_object('teams_ranked',v_count,'date',p_date);
end;
$function$;

