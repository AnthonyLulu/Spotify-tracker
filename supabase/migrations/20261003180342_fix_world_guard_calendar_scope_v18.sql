
create or replace function public.world_integrity_guard_v18(p_date date default current_date)
returns jsonb
language sql
stable
set search_path to 'public'
as $function$
with active_dupes as (
  select count(*)::int n
  from (
    select
      t.circuit,t.category,t.start_date,t.country,lower(t.name) event_name,
      count(*)
    from public.tournaments t
    where coalesce(t.is_active,true)
      and t.start_date>=date_trunc('year',p_date)::date
      and t.start_date<(date_trunc('year',p_date)+interval '2 years')::date
    group by 1,2,3,4,5
    having count(*)>1
  ) x
),
world_week_conflicts as (
  select count(*)::int n
  from (
    select e.player_id,date_trunc('week',t.start_date::timestamp),count(distinct t.id)
    from public.world_tournament_entries e
    join public.tournaments t on t.id=e.tournament_id
    join public.players p on p.id=e.player_id
    where p.career_status='active'
      and coalesce(t.is_active,true)
      and t.start_date>=p_date
      and t.start_date<p_date+interval '18 months'
    group by e.player_id,date_trunc('week',t.start_date::timestamp)
    having count(distinct t.id)>1
  ) x
),
retired_future as (
  select
    (
      select count(*)
      from public.entries e
      join public.players p on p.id=e.player_id
      join public.tournaments t on t.id=e.tournament_id
      where p.career_status='retired'
        and lower(coalesce(e.status,'entered')) not in ('withdrawn','cancelled','rejected')
        and t.start_date>=p_date
        and coalesce(t.is_active,true)
    )
    +
    (
      select count(*)
      from public.world_tournament_entries e
      join public.players p on p.id=e.player_id
      join public.tournaments t on t.id=e.tournament_id
      where p.career_status='retired'
        and t.start_date>=p_date
        and coalesce(t.is_active,true)
    )
    +
    (
      select count(*)
      from public.world_tournament_qualifying_entries e
      join public.players p on p.id=e.player_id
      join public.tournaments t on t.id=e.tournament_id
      where p.career_status='retired'
        and t.start_date>=p_date
        and coalesce(t.is_active,true)
    ) as n
),
counts as (
  select
    count(*) filter(where p.career_status='active')::int active_players,
    count(*) filter(
      where p.career_status='active'
        and coalesce(
          case when p.birth_date is not null then extract(year from age(p_date,p.birth_date))::int end,
          p.age,99
        ) between 18 and 45
    )::int active_adults,
    count(*) filter(
      where p.career_status='retired'
        and (p.ranking_current=true or p.game_world_rank is not null)
    )::int retired_rank_state
  from public.players p
  where coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
),
staff_count as (
  select count(*)::int n from public.staff_profiles where active=true
),
junior_count as (
  select count(*)::int n
  from public.players p
  where p.career_status='active'
    and p.junior_ranking is not null
    and coalesce(
      case when p.birth_date is not null then extract(year from age(p_date,p.birth_date))::int end,
      p.age,99
    )<=19
)
select jsonb_build_object(
  'ok',
    c.active_adults>=24000
    and c.retired_rank_state=0
    and rf.n=0
    and ad.n=0
    and wc.n=0
    and sc.n>=1500
    and jc.n>=500,
  'date',p_date,
  'active_players',c.active_players,
  'active_adults',c.active_adults,
  'adult_floor',24000,
  'junior_pipeline',jc.n,
  'active_staff',sc.n,
  'retired_rank_state',c.retired_rank_state,
  'retired_future_entries',rf.n,
  'near_calendar_duplicate_groups',ad.n,
  'future_same_week_world_entry_conflicts',wc.n,
  'base_integrity',public.living_world_integrity_audit_v16(p_date),
  'model','CB-WORLD-GUARD-v18.1'
)
from counts c
cross join retired_future rf
cross join active_dupes ad
cross join world_week_conflicts wc
cross join staff_count sc
cross join junior_count jc;
$function$;

create or replace function public.world_25y_validation_v18(
  p_start_year integer default 2025,
  p_end_year integer default 2050
)
returns jsonb
language plpgsql
stable
set search_path to 'public'
as $function$
declare
  v_stress jsonb;
  v_calendar jsonb;
  v_entries jsonb;
  v_guard jsonb;
  v_entry_season int;
  v_calendar_duplicate_groups int:=0;
  v_ok boolean;
begin
  if p_end_year<=p_start_year or p_end_year-p_start_year>80 then
    return jsonb_build_object('ok',false,'reason','invalid_horizon');
  end if;

  v_stress:=public.living_world_stress_test_v16(greatest(2026,p_start_year+1),p_end_year,250,2000);
  v_calendar:=public.living_world_horizon_test_v14(p_start_year,p_end_year);
  v_guard:=public.world_integrity_guard_v18(
    case
      when p_start_year=2025 then date '2025-12-01'
      else make_date(p_start_year,1,1)
    end
  );

  select count(*)::int into v_calendar_duplicate_groups
  from (
    select t.circuit,t.category,t.start_date,t.country,lower(t.name),count(*)
    from public.tournaments t
    where extract(year from t.start_date)::int between p_start_year and p_end_year
      and coalesce(t.is_active,true)
    group by 1,2,3,4,5
    having count(*)>1
  ) x;

  select min(y) into v_entry_season
  from generate_series(greatest(2026,p_start_year),p_end_year) y
  where exists(
    select 1
    from public.tournaments t
    where extract(year from t.start_date)::int=y
      and t.circuit='ATP' and t.category='ATP 500'
      and coalesce(t.is_active,true)
  );

  if v_entry_season is not null then
    v_entries:=public.atp_entry_model_test_v18(v_entry_season);
  else
    v_entries:=jsonb_build_object('ok',true,'skipped','no_generated_atp500_season_in_horizon');
  end if;

  v_ok:=coalesce((v_stress->>'ok')::boolean,false)
        and coalesce((v_calendar->>'ok')::boolean,false)
        and coalesce((v_guard->>'ok')::boolean,false)
        and coalesce((v_entries->>'ok')::boolean,false)
        and v_calendar_duplicate_groups=0;

  return jsonb_build_object(
    'ok',v_ok,
    'start_year',p_start_year,
    'end_year',p_end_year,
    'seasons',p_end_year-p_start_year+1,
    'supply_and_retirement_stress',v_stress,
    'calendar_horizon',v_calendar,
    'calendar_duplicate_groups',v_calendar_duplicate_groups,
    'current_world_guard',v_guard,
    'entry_model_test',v_entries,
    'entry_rule_test_season',v_entry_season,
    'model','CB-WORLD-25Y-VALIDATION-v18.1'
  );
end;
$function$;

revoke all on function public.world_integrity_guard_v18(date) from public,anon,authenticated;
grant execute on function public.world_integrity_guard_v18(date) to service_role;
revoke all on function public.world_25y_validation_v18(integer,integer) from public,anon,authenticated;
grant execute on function public.world_25y_validation_v18(integer,integer) to service_role;
