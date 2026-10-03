
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
      t.id,t.name,t.start_date,t.country,t.surface,
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
  select cp.player_id,cp.player_name,q.tournament_id,q.selection_score
  from cp
  cross join lateral public.atp500_commitment_plan_v18(cp.player_id,p_season) q
),
matrix as (
  select
    cp.player_id,cp.player_name,cp.commitment_rank,
    e.id tournament_id,e.name tournament_name,e.start_date,e.country,e.surface,
    pl.selection_score plan_score,
    (pl.tournament_id is not null) planned,
    public.ai_tournament_commitment_probability(
      cp.commitment_rank,
      coalesce(sp.plan_type,'tour_regular'),
      coalesce(sp.target_events,22),
      sp.preferred_surface,
      e.surface,
      'ATP 500',
      p.country,
      e.country,
      20,
      coalesce(sp.rest_trigger_fatigue,72)
    ) base_probability
  from cp
  join public.players p on p.id=cp.player_id
  cross join events e
  left join plan pl on pl.player_id=cp.player_id and pl.tournament_id=e.id
  left join public.player_season_plans sp on sp.player_id=cp.player_id and sp.season=p_season
),
interest as (
  select
    m.*,
    case
      when m.planned then 99::numeric
      else least(
        m.base_probability,
        (
          case
            when m.commitment_rank<=10 then 20
            when m.commitment_rank<=20 then 25
            else 32
          end
          + case when p.country=m.country then 12 else 0 end
        )::numeric
      )
    end final_probability,
    (mod(abs(hashtext('ai-commit-v18|'||m.tournament_id::text||'|'||m.player_id::text)),10000)::numeric)/100.0 roll
  from matrix m
  join public.players p on p.id=m.player_id
),
interested as (
  select
    i.*,
    row_number() over(
      partition by i.player_id,date_trunc('week',i.start_date::timestamp)
      order by
        i.planned desc,
        coalesce(i.plan_score,0) desc,
        (i.final_probability-i.roll) desc,
        i.tournament_id
    ) week_choice
  from interest i
  where i.planned or i.roll<i.final_probability
),
projected as (
  select * from interested where week_choice=1
)
select
  e.id,e.name,e.start_date,
  (select count(*)::int from plan p where p.tournament_id=e.id),
  (select count(*)::int from projected p where p.tournament_id=e.id),
  coalesce((
    select array_agg(p.player_name order by p.player_name)
    from plan p where p.tournament_id=e.id
  ),array[]::text[]),
  coalesce((
    select array_agg(p.player_name order by p.player_name)
    from projected p where p.tournament_id=e.id
  ),array[]::text[])
from events e
order by e.start_date,e.id;
$function$;

revoke all on function public.atp500_projected_entry_field_v18(integer) from public,anon,authenticated;
grant execute on function public.atp500_projected_entry_field_v18(integer) to service_role;
