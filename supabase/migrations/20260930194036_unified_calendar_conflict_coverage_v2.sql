-- Court Boss unified calendar conflict coverage v2
-- DB migration version: 20260930194036
-- Adds junior singles and pro doubles qualifying to the cross-circuit calendar guard.

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
    from public.world_doubles_qualifying_entries e
    join public.world_doubles_partnerships p on p.id=e.pair_id
    join public.tournaments t on t.id=e.tournament_id
    where p_player_id in (p.player_a_id,p.player_b_id)
      and t.id is distinct from p_exclude_tournament_id
      and daterange(
            coalesce(t.qualifying_start_date,t.start_date),
            coalesce(t.qualifying_end_date,t.main_draw_start_date,t.end_date,t.start_date),'[]'
          ) && daterange(p_week_start,p_week_start+6,'[]')

    union all
    select 1
    from public.junior_tournament_entries e
    join public.tournaments t on t.id=e.tournament_id
    where e.player_id=p_player_id
      and t.id is distinct from p_exclude_tournament_id
      and t.start_date>date '2025-12-01'
      and daterange(coalesce(t.qualifying_start_date,t.main_draw_start_date,t.start_date),coalesce(t.end_date,t.start_date),'[]')
          && daterange(p_week_start,p_week_start+6,'[]')

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
    select ot.id,ot.name,ot.start_date,ot.end_date,'doubles_qualifying'
    from public.world_doubles_qualifying_entries e
    join public.world_doubles_partnerships p on p.id=e.pair_id
    join public.tournaments ot on ot.id=e.tournament_id
    where p_player_id in (p.player_a_id,p.player_b_id) and ot.id<>t.id
      and daterange(
            coalesce(ot.qualifying_start_date,ot.start_date),
            coalesce(ot.qualifying_end_date,ot.main_draw_start_date,ot.end_date,ot.start_date),'[]'
          ) && daterange(commit_start,commit_end,'[]')

    union all
    select ot.id,ot.name,ot.start_date,ot.end_date,'junior_singles'
    from public.junior_tournament_entries e
    join public.tournaments ot on ot.id=e.tournament_id
    where e.player_id=p_player_id and ot.id<>t.id
      and ot.start_date>date '2025-12-01'
      and daterange(coalesce(ot.qualifying_start_date,ot.main_draw_start_date,ot.start_date),coalesce(ot.end_date,ot.start_date),'[]')
          && daterange(commit_start,commit_end,'[]')

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

CREATE OR REPLACE FUNCTION public.audit_unified_circuit_integrity(p_from_date date, p_to_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  v_overlaps int:=0;
  v_top200_itf int:=0;
  v_doubles_only_singles int:=0;
  v_singles_only_doubles int:=0;
  v_bad_junior_age int:=0;
  v_missing_standard_formats int:=0;
  v_missing_prize_profiles int:=0;
begin
  with raw_commitments as (
    select e.player_id,'T:'||t.id::text event_key,t.id tournament_id,
           coalesce(t.qualifying_start_date,t.main_draw_start_date,t.start_date) start_date,
           coalesce(t.end_date,t.start_date) end_date
    from public.world_tournament_entries e
    join public.tournaments t on t.id=e.tournament_id
    where coalesce(t.end_date,t.start_date)>=p_from_date and t.start_date<=p_to_date
    union all
    select e.player_id,'T:'||t.id::text,t.id,
           coalesce(t.qualifying_start_date,t.start_date),
           coalesce(t.qualifying_end_date,t.main_draw_start_date,t.end_date,t.start_date)
    from public.world_tournament_qualifying_entries e
    join public.tournaments t on t.id=e.tournament_id
    where coalesce(t.qualifying_end_date,t.end_date,t.start_date)>=p_from_date
      and coalesce(t.qualifying_start_date,t.start_date)<=p_to_date
    union all
    select wp.player_a_id,'T:'||t.id::text,t.id,
           coalesce(t.qualifying_start_date,t.main_draw_start_date,t.start_date),
           coalesce(t.end_date,t.start_date)
    from public.world_doubles_tournament_entries e
    join public.world_doubles_partnerships wp on wp.id=e.pair_id
    join public.tournaments t on t.id=e.tournament_id
    where coalesce(t.end_date,t.start_date)>=p_from_date and t.start_date<=p_to_date
    union all
    select wp.player_b_id,'T:'||t.id::text,t.id,
           coalesce(t.qualifying_start_date,t.main_draw_start_date,t.start_date),
           coalesce(t.end_date,t.start_date)
    from public.world_doubles_tournament_entries e
    join public.world_doubles_partnerships wp on wp.id=e.pair_id
    join public.tournaments t on t.id=e.tournament_id
    where coalesce(t.end_date,t.start_date)>=p_from_date and t.start_date<=p_to_date
    union all
    select wp.player_a_id,'T:'||t.id::text,t.id,
           coalesce(t.qualifying_start_date,t.start_date),
           coalesce(t.qualifying_end_date,t.main_draw_start_date,t.end_date,t.start_date)
    from public.world_doubles_qualifying_entries e
    join public.world_doubles_partnerships wp on wp.id=e.pair_id
    join public.tournaments t on t.id=e.tournament_id
    where coalesce(t.qualifying_end_date,t.end_date,t.start_date)>=p_from_date
      and coalesce(t.qualifying_start_date,t.start_date)<=p_to_date
    union all
    select wp.player_b_id,'T:'||t.id::text,t.id,
           coalesce(t.qualifying_start_date,t.start_date),
           coalesce(t.qualifying_end_date,t.main_draw_start_date,t.end_date,t.start_date)
    from public.world_doubles_qualifying_entries e
    join public.world_doubles_partnerships wp on wp.id=e.pair_id
    join public.tournaments t on t.id=e.tournament_id
    where coalesce(t.qualifying_end_date,t.end_date,t.start_date)>=p_from_date
      and coalesce(t.qualifying_start_date,t.start_date)<=p_to_date

    union all
    select e.player_id,'T:'||t.id::text,t.id,t.start_date,coalesce(t.end_date,t.start_date)
    from public.junior_tournament_entries e
    join public.tournaments t on t.id=e.tournament_id
    where t.start_date>date '2025-12-01'
      and coalesce(t.end_date,t.start_date)>=p_from_date and t.start_date<=p_to_date
    union all
    select e.player_a_id,'T:'||t.id::text,t.id,t.start_date,coalesce(t.end_date,t.start_date)
    from public.world_junior_doubles_entries e
    join public.tournaments t on t.id=e.tournament_id
    where coalesce(t.end_date,t.start_date)>=p_from_date and t.start_date<=p_to_date
    union all
    select e.player_b_id,'T:'||t.id::text,t.id,t.start_date,coalesce(t.end_date,t.start_date)
    from public.world_junior_doubles_entries e
    join public.tournaments t on t.id=e.tournament_id
    where coalesce(t.end_date,t.start_date)>=p_from_date and t.start_date<=p_to_date
    union all
    select e.player_id,'T:'||t.id::text,t.id,t.start_date,coalesce(t.end_date,t.start_date)
    from public.ncaa_individual_entries e
    join public.tournaments t on t.id=e.tournament_id
    where coalesce(t.end_date,t.start_date)>=p_from_date and t.start_date<=p_to_date
    union all
    select e.player_a_id,'T:'||t.id::text,t.id,t.start_date,coalesce(t.end_date,t.start_date)
    from public.ncaa_individual_doubles_entries e
    join public.tournaments t on t.id=e.tournament_id
    where coalesce(t.end_date,t.start_date)>=p_from_date and t.start_date<=p_to_date
    union all
    select e.player_b_id,'T:'||t.id::text,t.id,t.start_date,coalesce(t.end_date,t.start_date)
    from public.ncaa_individual_doubles_entries e
    join public.tournaments t on t.id=e.tournament_id
    where coalesce(t.end_date,t.start_date)>=p_from_date and t.start_date<=p_to_date
  ),
  commitments as (
    select player_id,event_key,tournament_id,min(start_date) start_date,max(end_date) end_date
    from raw_commitments
    group by player_id,event_key,tournament_id
  )
  select count(*) into v_overlaps
  from commitments a
  join commitments b
    on a.player_id=b.player_id
   and a.event_key<b.event_key
   and daterange(a.start_date,a.end_date,'[]') && daterange(b.start_date,b.end_date,'[]');

  select count(*) into v_top200_itf
  from (
    select e.player_id,t.id,
           public.player_rank_at_date(e.player_id,coalesce(t.main_entry_deadline,t.start_date-21)) r
    from public.world_tournament_entries e
    join public.tournaments t on t.id=e.tournament_id
    where t.circuit='ITF' and t.category in ('M15','M25')
      and t.start_date between p_from_date and p_to_date
    union all
    select e.player_id,t.id,
           public.player_rank_at_date(e.player_id,coalesce(t.qualifying_entry_deadline,t.start_date-21))
    from public.world_tournament_qualifying_entries e
    join public.tournaments t on t.id=e.tournament_id
    where t.circuit='ITF' and t.category in ('M15','M25')
      and t.start_date between p_from_date and p_to_date
  ) x
  where x.r between 1 and 200;

  select count(*) into v_doubles_only_singles
  from (
    select distinct e.player_id
    from public.world_tournament_entries e
    join public.tournaments t on t.id=e.tournament_id
    join public.players p on p.id=e.player_id
    where t.start_date between p_from_date and p_to_date and p.career_focus='doubles_only'
    union
    select distinct e.player_id
    from public.world_tournament_qualifying_entries e
    join public.tournaments t on t.id=e.tournament_id
    join public.players p on p.id=e.player_id
    where t.start_date between p_from_date and p_to_date and p.career_focus='doubles_only'
  ) x;

  select count(*) into v_singles_only_doubles
  from (
    select wp.player_a_id player_id,t.id
    from public.world_doubles_tournament_entries e
    join public.world_doubles_partnerships wp on wp.id=e.pair_id
    join public.tournaments t on t.id=e.tournament_id
    join public.players p on p.id=wp.player_a_id
    where t.start_date between p_from_date and p_to_date and p.career_focus='singles_only'
    union all
    select wp.player_b_id,t.id
    from public.world_doubles_tournament_entries e
    join public.world_doubles_partnerships wp on wp.id=e.pair_id
    join public.tournaments t on t.id=e.tournament_id
    join public.players p on p.id=wp.player_b_id
    where t.start_date between p_from_date and p_to_date and p.career_focus='singles_only'
  ) x;

  select count(*) into v_bad_junior_age
  from public.junior_tournament_entries e
  join public.tournaments t on t.id=e.tournament_id
  join public.players p on p.id=e.player_id
  where t.circuit='Junior'
    and t.start_date>date '2025-12-01'
    and t.start_date between p_from_date and p_to_date
    and coalesce(
      case when p.birth_date is not null then extract(year from age(t.start_date,p.birth_date))::int end,
      p.age,99
    ) not between 13 and 18;

  select count(*) into v_missing_standard_formats
  from public.tournaments t
  where coalesce(t.is_active,true)=true
    and t.start_date between p_from_date and p_to_date
    and (
      t.circuit in ('ATP','Challenger','ITF')
      or (t.circuit='Junior' and t.category not in ('Junior Davis Cup','Junior Finals','Junior Double Finals'))
    )
    and t.category not in ('United Cup','Laver Cup','Davis Cup')
    and not exists(
      select 1 from public.tournament_format_rules r
      where r.circuit=t.circuit and r.category=t.category
        and r.main_draw_size=coalesce(t.singles_draw_size,t.draw_size)
    );

  select count(*) into v_missing_prize_profiles
  from public.tournaments t
  where coalesce(t.is_active,true)=true
    and t.start_date between p_from_date and p_to_date
    and t.circuit in ('ATP','Challenger','ITF')
    and t.category not in ('ATP Finals','Next Gen Finals','United Cup','Laver Cup')
    and (
      coalesce(t.singles_prize_by_result,'{}'::jsonb)='{}'::jsonb
      or (coalesce(t.doubles_draw_size,0)>0 and coalesce(t.doubles_prize_by_result,'{}'::jsonb)='{}'::jsonb)
    );

  return jsonb_build_object(
    'ok',v_overlaps=0 and v_top200_itf=0 and v_doubles_only_singles=0
         and v_singles_only_doubles=0 and v_bad_junior_age=0
         and v_missing_standard_formats=0 and v_missing_prize_profiles=0,
    'calendar_overlap_pairs',v_overlaps,
    'top200_itf_playdown_violations',v_top200_itf,
    'doubles_only_in_singles',v_doubles_only_singles,
    'singles_only_in_doubles',v_singles_only_doubles,
    'junior_age_violations',v_bad_junior_age,
    'missing_standard_format_rules',v_missing_standard_formats,
    'missing_prize_profiles',v_missing_prize_profiles,
    'historical_identity_debt_excluded_through','2025-12-01',
    'from',p_from_date,'to',p_to_date,
    'model','CB-UNIFIED-INTEGRITY-v3'
  );
end;
$function$;

comment on function public.player_has_world_event_in_week(bigint,date,bigint)
  is 'Cross-circuit weekly commitment guard including pro singles/qualifying, pro doubles/qualifying, junior singles/doubles, NCAA and team duties.';
comment on function public.player_tournament_calendar_conflict(bigint,bigint,text)
  is 'Cross-circuit date-range conflict arbiter; same-tournament singles+doubles remains allowed.';
