create index if not exists world_doubles_entries_pair_tournament_idx
  on public.world_doubles_tournament_entries(pair_id, tournament_id);

create index if not exists world_doubles_qualifying_pair_tournament_idx
  on public.world_doubles_qualifying_entries(pair_id, tournament_id);

create or replace function public.tournament_busy_player_ids_v20_5(
  p_tournament_id bigint,
  p_entry_method text default 'direct'
)
returns table(player_id bigint)
language plpgsql
stable
set search_path to 'public'
as $function$
declare
  t public.tournaments%rowtype;
  method text:=lower(coalesce(p_entry_method,'direct'));
  calendar_method text;
  commit_start date;
  commit_end date;
  week_monday date;
  managed_id bigint;
begin
  select * into t from public.tournaments where id=p_tournament_id;
  if t.id is null then
    return;
  end if;

  calendar_method:=case
    when method in ('qualifying','qualifying_wildcard','protected_qualifying','doubles_qualifying')
      then method
    else 'direct'
  end;

  commit_start:=case
    when calendar_method in ('qualifying','qualifying_wildcard','protected_qualifying','doubles_qualifying')
      then coalesce(t.qualifying_start_date,t.main_draw_start_date,t.start_date)
    else coalesce(t.main_draw_start_date,t.start_date)
  end;
  commit_end:=coalesce(t.end_date,t.start_date);
  week_monday:=date_trunc('week',coalesce(t.main_draw_start_date,t.start_date)::timestamp)::date;

  select managed_player_id into managed_id
  from public.career_state
  where id='demo';

  return query
  with
  overlap_main as materialized (
    select ot.id
    from public.tournaments ot
    where ot.id<>t.id
      and coalesce(ot.qualifying_start_date,ot.main_draw_start_date,ot.start_date)<=commit_end
      and coalesce(ot.end_date,ot.start_date)>=commit_start
  ),
  overlap_qual as materialized (
    select ot.id
    from public.tournaments ot
    where ot.id<>t.id
      and coalesce(ot.qualifying_start_date,ot.start_date)<=commit_end
      and coalesce(ot.qualifying_end_date,ot.main_draw_start_date,ot.end_date,ot.start_date)>=commit_start
  ),
  overlap_simple as materialized (
    select ot.id
    from public.tournaments ot
    where ot.id<>t.id
      and ot.start_date<=commit_end
      and coalesce(ot.end_date,ot.start_date)>=commit_start
  ),
  busy as materialized (
    select e.player_id
    from public.world_tournament_entries e
    join overlap_main o on o.id=e.tournament_id
    union
    select e.player_id
    from public.world_tournament_qualifying_entries e
    join overlap_qual o on o.id=e.tournament_id
    union
    select p.player_a_id
    from public.world_doubles_tournament_entries e
    join overlap_main o on o.id=e.tournament_id
    join public.world_doubles_partnerships p on p.id=e.pair_id
    union
    select p.player_b_id
    from public.world_doubles_tournament_entries e
    join overlap_main o on o.id=e.tournament_id
    join public.world_doubles_partnerships p on p.id=e.pair_id
    union
    select p.player_a_id
    from public.world_doubles_qualifying_entries e
    join overlap_qual o on o.id=e.tournament_id
    join public.world_doubles_partnerships p on p.id=e.pair_id
    union
    select p.player_b_id
    from public.world_doubles_qualifying_entries e
    join overlap_qual o on o.id=e.tournament_id
    join public.world_doubles_partnerships p on p.id=e.pair_id
    union
    select e.player_id
    from public.junior_tournament_entries e
    join overlap_main o on o.id=e.tournament_id
    join public.tournaments ot on ot.id=e.tournament_id
    where ot.start_date>date '2025-12-01'
    union
    select e.player_a_id
    from public.world_junior_doubles_entries e
    join overlap_simple o on o.id=e.tournament_id
    union
    select e.player_b_id
    from public.world_junior_doubles_entries e
    join overlap_simple o on o.id=e.tournament_id
    union
    select e.player_id
    from public.ncaa_individual_entries e
    join overlap_simple o on o.id=e.tournament_id
    union
    select e.player_a_id
    from public.ncaa_individual_doubles_entries e
    join overlap_simple o on o.id=e.tournament_id
    union
    select e.player_b_id
    from public.ncaa_individual_doubles_entries e
    join overlap_simple o on o.id=e.tournament_id
    union
    select ds.player_id
    from public.davis_squad ds
    join public.davis_ties dt on ds.nation in (dt.home_nation,dt.away_nation)
    where dt.status in ('scheduled','completed')
      and dt.tie_date between commit_start and commit_end
    union
    select pl.id
    from public.players pl
    join public.college_teams ct on ct.name=pl.ncaa_school
    join public.college_duals cd on ct.id in (cd.home_team_id,cd.away_team_id)
    where pl.ncaa_current=true
      and cd.status in ('scheduled','completed')
      and cd.match_date between commit_start and commit_end
    union
    select pl.id
    from public.players pl
    join public.college_teams ct on ct.name=pl.ncaa_school
    join public.college_team_event_entries ce on ce.team_id=ct.id
    join overlap_simple o on o.id=ce.tournament_id
    where pl.ncaa_current=true
    union
    select managed_id
    from public.tournament_runs tr
    join overlap_main o on o.id=tr.tournament_id
    where managed_id is not null
    union
    select managed_id
    from public.doubles_runs dr
    join overlap_main o on o.id=dr.tournament_id
    where managed_id is not null
    union
    select e.player_id
    from public.world_tournament_entries e
    join public.tournaments ot on ot.id=e.tournament_id
    where calendar_method in ('qualifying','qualifying_wildcard','protected_qualifying','doubles_qualifying')
      and ot.id<>t.id
      and coalesce(ot.end_date,ot.start_date)>=commit_start
      and coalesce(ot.main_draw_start_date,ot.start_date)<week_monday
      and coalesce(e.result_code,'') in ('W','F','SF')
    union
    select p.player_a_id
    from public.world_doubles_tournament_entries e
    join public.world_doubles_partnerships p on p.id=e.pair_id
    join public.tournaments ot on ot.id=e.tournament_id
    where calendar_method in ('qualifying','qualifying_wildcard','protected_qualifying','doubles_qualifying')
      and ot.id<>t.id
      and coalesce(ot.end_date,ot.start_date)>=commit_start
      and coalesce(ot.main_draw_start_date,ot.start_date)<week_monday
      and coalesce(e.result_code,'') in ('W','F','SF')
    union
    select p.player_b_id
    from public.world_doubles_tournament_entries e
    join public.world_doubles_partnerships p on p.id=e.pair_id
    join public.tournaments ot on ot.id=e.tournament_id
    where calendar_method in ('qualifying','qualifying_wildcard','protected_qualifying','doubles_qualifying')
      and ot.id<>t.id
      and coalesce(ot.end_date,ot.start_date)>=commit_start
      and coalesce(ot.main_draw_start_date,ot.start_date)<week_monday
      and coalesce(e.result_code,'') in ('W','F','SF')
    union
    select e.player_a_id
    from public.world_junior_doubles_entries e
    join public.tournaments ot on ot.id=e.tournament_id
    where calendar_method in ('qualifying','qualifying_wildcard','protected_qualifying','doubles_qualifying')
      and ot.id<>t.id
      and coalesce(ot.end_date,ot.start_date)>=commit_start
      and coalesce(ot.main_draw_start_date,ot.start_date)<week_monday
      and coalesce(e.result_code,'') in ('W','F','SF')
    union
    select e.player_b_id
    from public.world_junior_doubles_entries e
    join public.tournaments ot on ot.id=e.tournament_id
    where calendar_method in ('qualifying','qualifying_wildcard','protected_qualifying','doubles_qualifying')
      and ot.id<>t.id
      and coalesce(ot.end_date,ot.start_date)>=commit_start
      and coalesce(ot.main_draw_start_date,ot.start_date)<week_monday
      and coalesce(e.result_code,'') in ('W','F','SF')
  )
  select distinct b.player_id
  from busy b
  where b.player_id is not null;
end;
$function$;

revoke all on function public.tournament_busy_player_ids_v20_5(bigint,text) from public;
revoke all on function public.tournament_busy_player_ids_v20_5(bigint,text) from anon;
revoke all on function public.tournament_busy_player_ids_v20_5(bigint,text) from authenticated;
grant execute on function public.tournament_busy_player_ids_v20_5(bigint,text) to service_role;

create or replace function public.tournament_candidate_player_ids_v19(
  p_tournament_id bigint,
  p_entry_method text default 'candidate',
  p_limit integer default 256
)
returns table(player_id bigint, effective_rank integer, merit_tier integer, merit_value numeric)
language plpgsql
stable
set search_path to 'public'
as $function$
declare
  t public.tournaments%rowtype;
  v_min int:=1;
  v_max int:=30000;
  v_prefilter int;
  v_tier_limit int;
begin
  select * into t from public.tournaments where id=p_tournament_id;
  if t.id is null then return; end if;

  if coalesce(t.circuit,'') not in ('ATP','Challenger','ITF') then
    return;
  end if;

  if t.category='Grand Chelem' then v_min:=1;v_max:=500;
  elsif t.category='Masters 1000' then v_min:=1;v_max:=500;
  elsif t.category='ATP 500' then v_min:=1;v_max:=500;
  elsif t.category='ATP 250' then v_min:=1;v_max:=500;
  elsif t.category='Challenger 175' then v_min:=1;v_max:=2200;
  elsif t.category='Challenger 125' then v_min:=11;v_max:=3200;
  elsif t.category='Challenger 100' then v_min:=11;v_max:=5000;
  elsif t.category='Challenger 75' then v_min:=51;v_max:=8000;
  elsif t.category='Challenger 50' then v_min:=51;v_max:=14000;
  end if;

  v_tier_limit:=greatest(96,least(420,coalesce(p_limit,256)+80));

  if t.circuit='ITF' then
    return query
    with busy as materialized (
      select b.player_id
      from public.tournament_busy_player_ids_v20_5(t.id,p_entry_method) b
    ),
    tier1 as (
      select p.id,p.current_ability,p.ranking::int effective_rank,1::int merit_tier,p.ranking::numeric merit_value
      from public.players p
      where p.career_status='active'
        and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
        and p.ranking is not null
        and coalesce(p.ranking_current,true)
        and not exists(select 1 from busy b where b.player_id=p.id)
      order by p.ranking,p.current_ability desc,p.id
      limit v_tier_limit
    ),
    tier2 as (
      select p.id,p.current_ability,null::int effective_rank,2::int merit_tier,p.itf_ranking::numeric merit_value
      from public.players p
      where p.career_status='active'
        and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
        and p.ranking is null
        and p.itf_ranking is not null
        and not exists(select 1 from busy b where b.player_id=p.id)
      order by p.itf_ranking,p.current_ability desc,p.id
      limit v_tier_limit
    ),
    tier3 as (
      select p.id,p.current_ability,null::int effective_rank,3::int merit_tier,
        greatest(1,1000-coalesce(p.current_ability,40)*10-coalesce(p.form,50)*0.5)::numeric merit_value
      from public.players p
      where p.career_status='active'
        and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
        and p.ranking is null
        and p.itf_ranking is null
        and not exists(select 1 from busy b where b.player_id=p.id)
      order by p.current_ability desc,p.form desc,p.id
      limit v_tier_limit
    ),
    pre as (
      select * from tier1
      union all select * from tier2
      union all select * from tier3
    ),
    checked as (
      select pre.*,elig.j
      from pre
      cross join lateral (
        select public.tournament_entry_eligibility(pre.id,t.id,p_entry_method) j
      ) elig
    )
    select c.id,c.effective_rank,c.merit_tier,c.merit_value
    from checked c
    where coalesce((c.j->>'eligible')::boolean,false)
    order by c.merit_tier,c.merit_value,c.current_ability desc,c.id
    limit greatest(16,least(coalesce(p_limit,256),2000));
    return;
  end if;

  v_prefilter:=greatest(
    220,
    least(1200,coalesce(p_limit,256)+greatest(120,least(320,coalesce(p_limit,256))))
  );

  return query
  with busy as materialized (
    select b.player_id
    from public.tournament_busy_player_ids_v20_5(t.id,p_entry_method) b
  ),
  pre as (
    select
      p.id,
      p.current_ability,
      coalesce(case when p.ranking_current then p.ranking end,p.game_world_rank,p.ranking,999999)::int approx_rank
    from public.players p
    where p.career_status='active'
      and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
      and coalesce(case when p.ranking_current then p.ranking end,p.game_world_rank,p.ranking,999999)
          between greatest(1,v_min-250) and v_max+750
      and not exists(select 1 from busy b where b.player_id=p.id)
    order by
      coalesce(case when p.ranking_current then p.ranking end,p.game_world_rank,p.ranking,999999),
      p.current_ability desc,p.id
    limit v_prefilter
  ),
  checked as (
    select pre.id,pre.current_ability,elig.j
    from pre
    cross join lateral (
      select public.tournament_entry_eligibility(pre.id,t.id,p_entry_method) j
    ) elig
  )
  select
    c.id,
    coalesce((c.j->>'ranking')::int,999999)::int,
    1::int,
    coalesce((c.j->>'ranking')::numeric,999999::numeric)
  from checked c
  where coalesce((c.j->>'eligible')::boolean,false)
    and coalesce((c.j->>'ranking')::int,999999) between v_min and v_max
  order by 4,c.current_ability desc,c.id
  limit greatest(16,least(coalesce(p_limit,256),2000));
end;
$function$;
