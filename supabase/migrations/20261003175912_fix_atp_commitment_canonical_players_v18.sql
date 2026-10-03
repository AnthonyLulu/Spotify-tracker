
create or replace function public.atp_commitment_players_v18(p_season integer)
returns table(player_id bigint, player_name text, commitment_rank integer)
language sql
stable
set search_path to 'public'
as $function$
with cfg as (
  select coalesce((public.atp_commitment_rule_v18(p_season)->>'commitment_rank_cutoff')::int,30) cutoff
)
select
  p.id,
  p.name,
  public.player_rank_at_date(p.id,make_date(p_season-1,11,10))::int
from public.players p
cross join cfg c
where p.career_status='active'
  and p.ranking_current=true
  and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
  and public.player_rank_at_date(p.id,make_date(p_season-1,11,10)) between 1 and c.cutoff
order by 3,p.id;
$function$;

create or replace function public.atp500_projected_entry_field_v18(p_season integer default 2026)
returns table(
  tournament_id bigint,
  tournament_name text,
  start_date date,
  planned_top30 integer,
  projected_top30 integer,
  planned_players text[],
  projected_players text[]
)
language sql
stable
set search_path to 'public'
as $function$
with cp as (
  select * from public.atp_commitment_players_v18(p_season)
),
events as (
  select *
  from (
    select
      t.id,t.name,t.start_date,
      row_number() over(
        partition by coalesce(nullif(t.competition_key,''),nullif(t.history_group,''),lower(t.name))
        order by (t.main_entry_deadline is not null) desc,t.id desc
      ) rn
    from public.tournaments t
    where t.circuit='ATP' and t.category='ATP 500'
      and extract(year from t.start_date)::int=p_season
      and coalesce(t.is_active,true)
  ) x
  where rn=1
),
plan as (
  select cp.player_id,cp.player_name,q.tournament_id
  from cp
  cross join lateral public.atp500_commitment_plan_v18(cp.player_id,p_season) q
),
projected as (
  select cp.player_id,cp.player_name,e.id tournament_id
  from cp cross join events e
  where public.ai_player_commits_to_tournament(cp.player_id,e.id)
)
select
  e.id,e.name,e.start_date,
  (select count(*)::int from plan p where p.tournament_id=e.id),
  (select count(*)::int from projected p where p.tournament_id=e.id),
  coalesce((select array_agg(p.player_name order by p.player_name) from plan p where p.tournament_id=e.id),array[]::text[]),
  coalesce((select array_agg(p.player_name order by p.player_name) from projected p where p.tournament_id=e.id),array[]::text[])
from events e
order by e.start_date,e.id;
$function$;

create or replace function public.atp_entry_model_test_v18(p_season integer default 2026)
returns jsonb
language sql
stable
set search_path to 'public'
as $function$
with uso as (
  select max(coalesce(t.end_date,t.start_date))::date uso_end
  from public.tournaments t
  where extract(year from t.start_date)::int=p_season
    and t.circuit='ATP' and t.category='Grand Chelem'
    and t.name ilike '%US Open%'
    and coalesce(t.is_active,true)
),
cp as (
  select * from public.atp_commitment_players_v18(p_season)
),
plans as (
  select cp.player_id,cp.player_name,cp.commitment_rank,q.*
  from cp
  cross join lateral public.atp500_commitment_plan_v18(cp.player_id,p_season) q
),
per_player as (
  select
    cp.player_id,
    cp.player_name,
    cp.commitment_rank,
    count(p.tournament_id)::int plan_count,
    count(distinct p.swing_no)::int swing_count,
    count(p.tournament_id) filter(where u.uso_end is not null and p.start_date>u.uso_end)::int post_uso_count
  from cp
  cross join uso u
  left join plans p on p.player_id=cp.player_id
  group by cp.player_id,cp.player_name,cp.commitment_rank,u.uso_end
),
same_week_conflicts as (
  select count(*)::int n
  from (
    select player_id,date_trunc('week',start_date::timestamp),count(*)
    from plans
    group by player_id,date_trunc('week',start_date::timestamp)
    having count(*)>1
  ) x
),
active_calendar_duplicates as (
  select count(*)::int n
  from (
    select
      extract(year from t.start_date)::int season,
      coalesce(nullif(t.competition_key,''),nullif(t.history_group,''),lower(t.name)) event_key,
      count(*)
    from public.tournaments t
    where extract(year from t.start_date)::int=p_season
      and t.circuit='ATP'
      and coalesce(t.is_active,true)
    group by 1,2
    having count(*)>1
  ) x
),
field as (
  select * from public.atp500_projected_entry_field_v18(p_season)
),
checks as (
  select
    (select count(*) from cp)::int commitment_players,
    (select count(*) from per_player where plan_count=4)::int with_four,
    (select count(*) from per_player where swing_count=3)::int with_three_swings,
    (select count(*) from per_player where post_uso_count>=1)::int with_post_uso,
    (select n from same_week_conflicts)::int same_week_conflicts,
    (select n from active_calendar_duplicates)::int active_calendar_duplicates
)
select jsonb_build_object(
  'ok',
    c.commitment_players>0
    and c.with_four=c.commitment_players
    and c.with_three_swings=c.commitment_players
    and c.with_post_uso=c.commitment_players
    and c.same_week_conflicts=0
    and c.active_calendar_duplicates=0,
  'season',p_season,
  'commitment_players',c.commitment_players,
  'players_with_4_event_plan',c.with_four,
  'players_covering_3_bonus_swings',c.with_three_swings,
  'players_with_post_us_open_500',c.with_post_uso,
  'same_week_plan_conflicts',c.same_week_conflicts,
  'active_calendar_duplicates',c.active_calendar_duplicates,
  'projected_event_loads',coalesce((
    select jsonb_agg(jsonb_build_object(
      'tournament_id',f.tournament_id,
      'tournament_name',f.tournament_name,
      'start_date',f.start_date,
      'planned_top30',f.planned_top30,
      'projected_top30',f.projected_top30
    ) order by f.start_date,f.tournament_id)
    from field f
  ),'[]'::jsonb),
  'model','CB-ATP-ENTRY-TEST-v18.1'
)
from checks c;
$function$;

revoke all on function public.atp_commitment_players_v18(integer) from public,anon,authenticated;
grant execute on function public.atp_commitment_players_v18(integer) to service_role;
revoke all on function public.atp500_projected_entry_field_v18(integer) from public,anon,authenticated;
grant execute on function public.atp500_projected_entry_field_v18(integer) to service_role;
revoke all on function public.atp_entry_model_test_v18(integer) from public,anon,authenticated;
grant execute on function public.atp_entry_model_test_v18(integer) to service_role;
