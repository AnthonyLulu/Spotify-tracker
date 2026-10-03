
-- Court Boss V18
-- ATP commitment scheduling + 25-year world integrity guards.
-- 2026 rule baseline:
--   * commitment player = Top 30 on prior-season Nov 10 ranking
--   * 4 ATP 500-category commitments, at least 1 after the US Open
--   * Monte-Carlo may count toward the commitment/ranking minimum
--   * ATP 500 fixed-bonus eligibility uses 4 actual ATP 500 events across 3 swings;
--     Monte-Carlo does not count for the fixed-bonus requirement.
-- Future seasons inherit the latest configured rule until explicitly overridden.

create table if not exists public.atp_commitment_rules_v18(
  season integer primary key,
  commitment_rank_cutoff integer not null default 30 check (commitment_rank_cutoff between 1 and 100),
  minimum_500_credits integer not null default 4 check (minimum_500_credits between 0 and 12),
  minimum_post_us_open_500 integer not null default 1 check (minimum_post_us_open_500 between 0 and 4),
  bonus_required_actual_500 integer not null default 4 check (bonus_required_actual_500 between 0 and 12),
  bonus_required_swings integer not null default 3 check (bonus_required_swings between 0 and 3),
  monte_carlo_counts_for_commitment boolean not null default true,
  monte_carlo_counts_for_bonus boolean not null default false,
  automatic_500_main_draw boolean not null default true,
  source_label text not null,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.atp_commitment_rules_v18 enable row level security;
revoke all on table public.atp_commitment_rules_v18 from anon, authenticated;
grant select on table public.atp_commitment_rules_v18 to service_role;

insert into public.atp_commitment_rules_v18(
  season,commitment_rank_cutoff,minimum_500_credits,minimum_post_us_open_500,
  bonus_required_actual_500,bonus_required_swings,
  monte_carlo_counts_for_commitment,monte_carlo_counts_for_bonus,
  automatic_500_main_draw,source_label,notes
)
values(
  2026,30,4,1,4,3,true,false,true,
  'ATP 2026 Rulebook · commitment + ATP 500 Fixed Bonus Pool',
  'Top 30 at 10 Nov 2025; four ATP 500-category commitments, one after US Open. Monte-Carlo can satisfy the commitment/ranking 500-category minimum but not the ATP 500 fixed-bonus event count. Fixed-bonus full eligibility targets one ATP 500 in each of three swings.'
)
on conflict(season) do update set
  commitment_rank_cutoff=excluded.commitment_rank_cutoff,
  minimum_500_credits=excluded.minimum_500_credits,
  minimum_post_us_open_500=excluded.minimum_post_us_open_500,
  bonus_required_actual_500=excluded.bonus_required_actual_500,
  bonus_required_swings=excluded.bonus_required_swings,
  monte_carlo_counts_for_commitment=excluded.monte_carlo_counts_for_commitment,
  monte_carlo_counts_for_bonus=excluded.monte_carlo_counts_for_bonus,
  automatic_500_main_draw=excluded.automatic_500_main_draw,
  source_label=excluded.source_label,
  notes=excluded.notes;

create or replace function public.atp_commitment_rule_v18(p_season integer)
returns jsonb
language sql
stable
set search_path to 'public'
as $function$
  select coalesce(
    (
      select to_jsonb(r)
      from public.atp_commitment_rules_v18 r
      where r.season<=p_season
      order by r.season desc
      limit 1
    ),
    jsonb_build_object(
      'season',2026,
      'commitment_rank_cutoff',30,
      'minimum_500_credits',4,
      'minimum_post_us_open_500',1,
      'bonus_required_actual_500',4,
      'bonus_required_swings',3,
      'monte_carlo_counts_for_commitment',true,
      'monte_carlo_counts_for_bonus',false,
      'automatic_500_main_draw',true,
      'source_label','ATP 2026 fallback'
    )
  );
$function$;

create or replace function public.atp500_bonus_swing_v18(
  p_start_date date,
  p_us_open_end date
)
returns integer
language sql
immutable
as $function$
  select case
    when p_start_date is null then null
    when p_us_open_end is not null and p_start_date>p_us_open_end then 3
    when extract(month from p_start_date)::int<=4 then 1
    else 2
  end;
$function$;

create or replace function public.atp500_commitment_plan_v18(
  p_player_id bigint,
  p_season integer
)
returns table(
  tournament_id bigint,
  tournament_name text,
  start_date date,
  swing_no integer,
  plan_slot text,
  selection_score numeric
)
language sql
stable
set search_path to 'public'
as $function$
with px as (
  select
    p.id,
    p.country,
    coalesce(a.clay_affinity,10) clay_affinity,
    coalesce(a.hard_affinity,10) hard_affinity,
    coalesce(a.grass_affinity,10) grass_affinity,
    lower(coalesce(sp.preferred_surface,'')) preferred_surface
  from public.players p
  left join public.player_attributes a on a.player_id=p.id
  left join public.player_season_plans sp
    on sp.player_id=p.id and sp.season=p_season
  where p.id=p_player_id
),
uso as (
  select max(coalesce(t.end_date,t.start_date))::date uso_end
  from public.tournaments t
  where extract(year from t.start_date)::int=p_season
    and t.circuit='ATP'
    and t.category='Grand Chelem'
    and t.name ilike '%US Open%'
    and coalesce(t.is_active,true)
),
canonical as (
  select *
  from (
    select
      t.id,t.name,t.start_date,t.country,t.surface,t.main_entry_deadline,
      row_number() over(
        partition by coalesce(nullif(t.competition_key,''),nullif(t.history_group,''),lower(t.name))
        order by (t.main_entry_deadline is not null) desc,t.id desc
      ) rn
    from public.tournaments t
    where extract(year from t.start_date)::int=p_season
      and t.circuit='ATP'
      and t.category='ATP 500'
      and coalesce(t.is_active,true)
  ) x
  where rn=1
),
scored as (
  select
    e.id tournament_id,
    e.name tournament_name,
    e.start_date,
    public.atp500_bonus_swing_v18(e.start_date,u.uso_end) swing_no,
    (
      case when px.country is not null and px.country=e.country then 30 else 0 end
      + case
          when lower(coalesce(e.surface,'')) like '%terre%' or lower(coalesce(e.surface,'')) like '%clay%'
            then px.clay_affinity*1.8
          when lower(coalesce(e.surface,'')) like '%gazon%' or lower(coalesce(e.surface,'')) like '%grass%'
            then px.grass_affinity*1.8
          else px.hard_affinity*1.8
        end
      + case
          when px.preferred_surface<>'' and (
            (px.preferred_surface like '%terre%' or px.preferred_surface like '%clay%')
              and (lower(coalesce(e.surface,'')) like '%terre%' or lower(coalesce(e.surface,'')) like '%clay%')
            or
            (px.preferred_surface like '%gazon%' or px.preferred_surface like '%grass%')
              and (lower(coalesce(e.surface,'')) like '%gazon%' or lower(coalesce(e.surface,'')) like '%grass%')
            or
            (px.preferred_surface like '%dur%' or px.preferred_surface like '%hard%')
              and (lower(coalesce(e.surface,'')) like '%dur%' or lower(coalesce(e.surface,'')) like '%hard%')
          ) then 10 else 0 end
      + (mod(abs(hashtext('atp500-plan-v18|'||p_player_id::text||'|'||e.id::text)),3000)/100.0)
    )::numeric selection_score
  from canonical e
  cross join px
  cross join uso u
),
swing_ranked as (
  select
    s.*,
    row_number() over(
      partition by s.swing_no
      order by s.selection_score desc,s.start_date,s.tournament_id
    ) rn
  from scored s
  where s.swing_no between 1 and 3
),
swing_picks as (
  select
    s.tournament_id,s.tournament_name,s.start_date,s.swing_no,
    ('swing_'||s.swing_no::text)::text plan_slot,s.selection_score
  from swing_ranked s
  where s.rn=1
),
extra_ranked as (
  select
    s.*,
    row_number() over(order by s.selection_score desc,s.start_date,s.tournament_id) rn
  from scored s
  where not exists(
    select 1 from swing_picks p where p.tournament_id=s.tournament_id
  )
  and not exists(
    select 1
    from swing_picks p
    where date_trunc('week',p.start_date::timestamp)=date_trunc('week',s.start_date::timestamp)
  )
),
extra_pick as (
  select
    e.tournament_id,e.tournament_name,e.start_date,e.swing_no,
    'extra'::text plan_slot,e.selection_score
  from extra_ranked e
  where e.rn=1
)
select * from swing_picks
union all
select * from extra_pick
order by start_date,tournament_id;
$function$;

create or replace function public.atp500_commitment_status_v18(
  p_player_id bigint,
  p_season integer,
  p_as_of date default current_date
)
returns jsonb
language sql
stable
set search_path to 'public'
as $function$
with rule as (
  select public.atp_commitment_rule_v18(p_season) j
),
cfg as (
  select
    coalesce((j->>'commitment_rank_cutoff')::int,30) cutoff,
    coalesce((j->>'minimum_500_credits')::int,4) minimum_credits,
    coalesce((j->>'minimum_post_us_open_500')::int,1) minimum_post,
    coalesce((j->>'bonus_required_actual_500')::int,4) bonus_actual,
    coalesce((j->>'bonus_required_swings')::int,3) bonus_swings,
    coalesce((j->>'monte_carlo_counts_for_commitment')::boolean,true) monte_commit,
    coalesce((j->>'monte_carlo_counts_for_bonus')::boolean,false) monte_bonus,
    j->>'source_label' source_label
  from rule
),
base as (
  select
    p.id,p.name,
    public.player_rank_at_date(p.id,make_date(p_season-1,11,10)) commitment_rank
  from public.players p
  where p.id=p_player_id
),
uso as (
  select max(coalesce(t.end_date,t.start_date))::date uso_end
  from public.tournaments t
  where extract(year from t.start_date)::int=p_season
    and t.circuit='ATP'
    and t.category='Grand Chelem'
    and t.name ilike '%US Open%'
    and coalesce(t.is_active,true)
),
played_ids as (
  select distinct w.tournament_id
  from public.world_tournament_entries w
  join public.tournaments t on t.id=w.tournament_id
  where w.player_id=p_player_id
    and extract(year from t.start_date)::int=p_season
    and t.start_date<=p_as_of
    and coalesce(t.is_active,true)
  union
  select distinct e.tournament_id
  from public.entries e
  join public.tournaments t on t.id=e.tournament_id
  where e.player_id=p_player_id
    and extract(year from t.start_date)::int=p_season
    and t.start_date<=p_as_of
    and coalesce(t.is_active,true)
    and lower(coalesce(e.status,'entered')) not in ('withdrawn','cancelled','rejected')
),
played as (
  select t.*
  from played_ids p
  join public.tournaments t on t.id=p.tournament_id
),
metrics as (
  select
    count(*) filter(where t.circuit='ATP' and t.category='ATP 500')::int actual_500,
    count(*) filter(
      where t.circuit='ATP' and t.category='ATP 500'
        and u.uso_end is not null and t.start_date>u.uso_end
    )::int post_uso_500,
    count(distinct public.atp500_bonus_swing_v18(t.start_date,u.uso_end))
      filter(where t.circuit='ATP' and t.category='ATP 500')::int swings_played,
    count(*) filter(
      where t.circuit='ATP' and t.category='Masters 1000'
        and t.name ilike '%Monte-Carlo%'
    )::int monte_carlo
  from played t
  cross join uso u
),
plan as (
  select * from public.atp500_commitment_plan_v18(p_player_id,p_season)
),
plan_metrics as (
  select
    count(*)::int planned_500,
    count(distinct swing_no)::int planned_swings,
    count(*) filter(where u.uso_end is not null and p.start_date>u.uso_end)::int planned_post_uso
  from plan p
  cross join uso u
)
select jsonb_build_object(
  'player_id',b.id,
  'player_name',b.name,
  'season',p_season,
  'as_of',p_as_of,
  'commitment_rank',b.commitment_rank,
  'is_commitment_player',coalesce(b.commitment_rank between 1 and c.cutoff,false),
  'rule_rank_cutoff',c.cutoff,
  'actual_atp500_played',m.actual_500,
  'monte_carlo_played',m.monte_carlo,
  'commitment_500_credits',
    m.actual_500 + case when c.monte_commit and m.monte_carlo>0 then 1 else 0 end,
  'commitment_minimum',c.minimum_credits,
  'post_us_open_atp500',m.post_uso_500,
  'post_us_open_minimum',c.minimum_post,
  'bonus_actual_500_target',c.bonus_actual,
  'bonus_swings_target',c.bonus_swings,
  'bonus_swings_played',m.swings_played,
  'planned_atp500',pm.planned_500,
  'planned_swings',pm.planned_swings,
  'planned_post_us_open',pm.planned_post_uso,
  'plan',coalesce((
    select jsonb_agg(jsonb_build_object(
      'tournament_id',p.tournament_id,
      'tournament_name',p.tournament_name,
      'start_date',p.start_date,
      'swing',p.swing_no,
      'slot',p.plan_slot,
      'selection_score',round(p.selection_score,2)
    ) order by p.start_date,p.tournament_id)
    from plan p
  ),'[]'::jsonb),
  'source_label',c.source_label,
  'model','CB-ATP-COMMITMENT-v18'
)
from base b cross join cfg c cross join metrics m cross join plan_metrics pm;
$function$;

create or replace function public.ai_player_commits_to_tournament(
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
  v_commitment_cutoff int:=30;
  v_min_500 int:=4;
  v_min_post_uso int:=1;
  v_actual_500_count int:=0;
  v_core_500_credits int:=0;
  v_post_uso_500_count int:=0;
  v_swing_count int:=0;
  v_remaining_500 int:=0;
  v_remaining_post_uso_500 int:=0;
  v_current_swing int:=null;
  v_planned_swing_date date:=null;
  v_uso_end date:=null;
  v_is_commitment boolean:=false;
  v_in_atp500_plan boolean:=false;
  v_major boolean:=false;
  v_rule jsonb;
  v_unified_eligibility jsonb;
begin
  v_unified_eligibility:=public.player_event_eligibility(
    p_player_id,p_tournament_id,'singles','candidate'
  );
  if not coalesce((v_unified_eligibility->>'eligible')::boolean,false) then
    return false;
  end if;

  select * into p from public.players where id=p_player_id;
  select * into t from public.tournaments where id=p_tournament_id;
  if p.id is null or t.id is null or not coalesce(t.is_active,true) then
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

  if t.circuit='ATP' and v_year>=2026 then
    v_rule:=public.atp_commitment_rule_v18(v_year);
    v_commitment_cutoff:=coalesce((v_rule->>'commitment_rank_cutoff')::int,30);
    v_min_500:=coalesce((v_rule->>'minimum_500_credits')::int,4);
    v_min_post_uso:=coalesce((v_rule->>'minimum_post_us_open_500')::int,1);
    v_commitment_rank:=public.player_rank_at_date(p.id,make_date(v_year-1,11,10));
    v_commitment_rank:=coalesce(v_commitment_rank,r);
    v_is_commitment:=v_commitment_rank between 1 and v_commitment_cutoff;

    if v_is_commitment and t.category='ATP 500' then
      select exists(
        select 1
        from public.atp500_commitment_plan_v18(p.id,v_year) q
        where q.tournament_id=t.id
      ) into v_in_atp500_plan;
    end if;
  end if;

  v_major:=coalesce(t.category,'') in ('Grand Chelem','Masters 1000','ATP Finals','Next Gen Finals')
           or v_in_atp500_plan;

  select count(distinct z.tournament_id)::int
  into v_played
  from (
    select e.tournament_id
    from public.world_tournament_entries e
    join public.tournaments et on et.id=e.tournament_id
    where e.player_id=p.id
      and extract(year from et.start_date)::int=v_year
      and et.start_date<t.start_date
      and coalesce(et.is_active,true)
    union
    select e.tournament_id
    from public.world_tournament_qualifying_entries e
    join public.tournaments et on et.id=e.tournament_id
    where e.player_id=p.id
      and extract(year from et.start_date)::int=v_year
      and et.start_date<t.start_date
      and coalesce(et.is_active,true)
    union
    select e.tournament_id
    from public.world_doubles_tournament_entries e
    join public.world_doubles_partnerships wp on wp.id=e.pair_id
    join public.tournaments et on et.id=e.tournament_id
    where p.id in (wp.player_a_id,wp.player_b_id)
      and extract(year from et.start_date)::int=v_year
      and et.start_date<t.start_date
      and coalesce(et.is_active,true)
    union
    select e.tournament_id
    from public.world_junior_doubles_entries e
    join public.tournaments et on et.id=e.tournament_id
    where p.id in (e.player_a_id,e.player_b_id)
      and extract(year from et.start_date)::int=v_year
      and et.start_date<t.start_date
      and coalesce(et.is_active,true)
    union
    select e.tournament_id
    from public.ncaa_individual_entries e
    join public.tournaments et on et.id=e.tournament_id
    where e.player_id=p.id
      and extract(year from et.start_date)::int=v_year
      and et.start_date<t.start_date
      and coalesce(et.is_active,true)
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
      prob:=prob-case when t.circuit='ITF' then 8 else 18 end;
    end if;
  end if;

  select x.country into v_previous_country
  from (
    select et.country,coalesce(et.end_date,et.start_date) event_date
    from public.world_tournament_entries e
    join public.tournaments et on et.id=e.tournament_id
    where e.player_id=p.id and et.start_date<t.start_date and coalesce(et.is_active,true)
    union all
    select et.country,coalesce(et.end_date,et.start_date)
    from public.world_doubles_tournament_entries e
    join public.world_doubles_partnerships wp on wp.id=e.pair_id
    join public.tournaments et on et.id=e.tournament_id
    where p.id in (wp.player_a_id,wp.player_b_id)
      and et.start_date<t.start_date and coalesce(et.is_active,true)
    union all
    select et.country,coalesce(et.end_date,et.start_date)
    from public.world_junior_doubles_entries e
    join public.tournaments et on et.id=e.tournament_id
    where p.id in (e.player_a_id,e.player_b_id)
      and et.start_date<t.start_date and coalesce(et.is_active,true)
  ) x
  order by x.event_date desc
  limit 1;

  if v_previous_country is not null
     and t.country is not null
     and v_previous_country is distinct from t.country then
    prob:=prob-greatest(2,14-coalesce(sp.travel_tolerance,10)*.55);
  end if;

  if v_is_commitment then
    if t.category in ('Grand Chelem','Masters 1000') then
      prob:=greatest(prob,97);
    elsif t.category='ATP 500' then
      select max(coalesce(et.end_date,et.start_date))::date
      into v_uso_end
      from public.tournaments et
      where extract(year from et.start_date)::int=v_year
        and et.circuit='ATP' and et.category='Grand Chelem'
        and et.name ilike '%US Open%'
        and coalesce(et.is_active,true);

      v_current_swing:=public.atp500_bonus_swing_v18(t.start_date,v_uso_end);

      select count(distinct e.tournament_id)::int
      into v_actual_500_count
      from public.world_tournament_entries e
      join public.tournaments et on et.id=e.tournament_id
      where e.player_id=p.id
        and et.circuit='ATP' and et.category='ATP 500'
        and extract(year from et.start_date)::int=v_year
        and et.start_date<t.start_date
        and coalesce(et.is_active,true);

      v_core_500_credits:=v_actual_500_count;
      if coalesce((v_rule->>'monte_carlo_counts_for_commitment')::boolean,true)
         and exists(
           select 1
           from public.world_tournament_entries e
           join public.tournaments et on et.id=e.tournament_id
           where e.player_id=p.id
             and et.circuit='ATP' and et.category='Masters 1000'
             and et.name ilike '%Monte-Carlo%'
             and extract(year from et.start_date)::int=v_year
             and et.start_date<t.start_date
             and coalesce(et.is_active,true)
         ) then
        v_core_500_credits:=v_core_500_credits+1;
      end if;

      select count(distinct e.tournament_id)::int
      into v_post_uso_500_count
      from public.world_tournament_entries e
      join public.tournaments et on et.id=e.tournament_id
      where e.player_id=p.id
        and et.circuit='ATP' and et.category='ATP 500'
        and extract(year from et.start_date)::int=v_year
        and v_uso_end is not null
        and et.start_date>v_uso_end
        and et.start_date<t.start_date
        and coalesce(et.is_active,true);

      select count(distinct e.tournament_id)::int
      into v_swing_count
      from public.world_tournament_entries e
      join public.tournaments et on et.id=e.tournament_id
      where e.player_id=p.id
        and et.circuit='ATP' and et.category='ATP 500'
        and extract(year from et.start_date)::int=v_year
        and et.start_date<t.start_date
        and public.atp500_bonus_swing_v18(et.start_date,v_uso_end)=v_current_swing
        and coalesce(et.is_active,true);

      select min(q.start_date)
      into v_planned_swing_date
      from public.atp500_commitment_plan_v18(p.id,v_year) q
      where q.swing_no=v_current_swing;

      select count(*)::int
      into v_remaining_500
      from public.tournaments et
      where et.circuit='ATP' and et.category='ATP 500'
        and extract(year from et.start_date)::int=v_year
        and et.start_date>=t.start_date
        and coalesce(et.is_active,true);

      select count(*)::int
      into v_remaining_post_uso_500
      from public.tournaments et
      where et.circuit='ATP' and et.category='ATP 500'
        and extract(year from et.start_date)::int=v_year
        and v_uso_end is not null and et.start_date>v_uso_end
        and et.start_date>=t.start_date
        and coalesce(et.is_active,true);

      if v_in_atp500_plan then
        prob:=greatest(prob,98);
      else
        prob:=least(
          prob,
          case
            when v_commitment_rank<=10 then 20
            when v_commitment_rank<=20 then 25
            else 32
          end
          + case when p.country=t.country then 12 else 0 end
        );
      end if;

      -- If the planned event for a bonus swing was missed, become aggressive
      -- about the next viable event in the same swing instead of abandoning it.
      if v_swing_count=0
         and v_planned_swing_date is not null
         and t.start_date>v_planned_swing_date then
        prob:=greatest(prob,82);
      end if;

      -- Hard rescue: when opportunities are running out, a healthy commitment
      -- player must enter enough 500-category events to avoid an impossible season.
      if v_core_500_credits<v_min_500
         and v_remaining_500<=greatest(1,v_min_500-v_core_500_credits) then
        prob:=greatest(prob,98);
      end if;

      if v_min_post_uso>0
         and v_uso_end is not null
         and t.start_date>v_uso_end
         and v_post_uso_500_count<v_min_post_uso
         and v_remaining_post_uso_500<=greatest(1,v_min_post_uso-v_post_uso_500_count) then
        prob:=greatest(prob,99);
      end if;
    end if;
  end if;

  prob:=greatest(2,least(99,prob));
  roll:=(mod(abs(hashtext('ai-commit-v18|'||t.id::text||'|'||p.id::text)),10000)::numeric)/100.0;
  return roll<prob;
end;
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
with cfg as (
  select coalesce((public.atp_commitment_rule_v18(p_season)->>'commitment_rank_cutoff')::int,30) cutoff
),
cp as (
  select
    p.id,p.name,
    public.player_rank_at_date(p.id,make_date(p_season-1,11,10)) commitment_rank
  from public.players p,cfg c
  where p.career_status='active'
    and public.player_rank_at_date(p.id,make_date(p_season-1,11,10)) between 1 and c.cutoff
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
  select cp.id player_id,cp.name player_name,q.tournament_id
  from cp
  cross join lateral public.atp500_commitment_plan_v18(cp.id,p_season) q
),
projected as (
  select cp.id player_id,cp.name player_name,e.id tournament_id
  from cp cross join events e
  where public.ai_player_commits_to_tournament(cp.id,e.id)
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
with cfg as (
  select coalesce((public.atp_commitment_rule_v18(p_season)->>'commitment_rank_cutoff')::int,30) cutoff
),
uso as (
  select max(coalesce(t.end_date,t.start_date))::date uso_end
  from public.tournaments t
  where extract(year from t.start_date)::int=p_season
    and t.circuit='ATP' and t.category='Grand Chelem'
    and t.name ilike '%US Open%'
    and coalesce(t.is_active,true)
),
cp as (
  select
    p.id,p.name,
    public.player_rank_at_date(p.id,make_date(p_season-1,11,10)) commitment_rank
  from public.players p,cfg c
  where p.career_status='active'
    and public.player_rank_at_date(p.id,make_date(p_season-1,11,10)) between 1 and c.cutoff
),
plans as (
  select cp.id player_id,cp.name player_name,cp.commitment_rank,q.*
  from cp
  cross join lateral public.atp500_commitment_plan_v18(cp.id,p_season) q
),
per_player as (
  select
    cp.id,
    cp.name,
    cp.commitment_rank,
    count(p.tournament_id)::int plan_count,
    count(distinct p.swing_no)::int swing_count,
    count(p.tournament_id) filter(where u.uso_end is not null and p.start_date>u.uso_end)::int post_uso_count
  from cp
  cross join uso u
  left join plans p on p.player_id=cp.id
  group by cp.id,cp.name,cp.commitment_rank,u.uso_end
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
  'model','CB-ATP-ENTRY-TEST-v18'
)
from checks c;
$function$;

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
      extract(year from t.start_date)::int season,
      coalesce(nullif(t.competition_key,''),nullif(t.history_group,''),lower(t.name)) event_key,
      count(*)
    from public.tournaments t
    where coalesce(t.is_active,true)
      and t.start_date>=date_trunc('year',p_date)::date
    group by 1,2
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
  'active_calendar_duplicate_groups',ad.n,
  'future_same_week_world_entry_conflicts',wc.n,
  'base_integrity',public.living_world_integrity_audit_v16(p_date),
  'model','CB-WORLD-GUARD-v18'
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
        and coalesce((v_entries->>'ok')::boolean,false);

  return jsonb_build_object(
    'ok',v_ok,
    'start_year',p_start_year,
    'end_year',p_end_year,
    'seasons',p_end_year-p_start_year+1,
    'supply_and_retirement_stress',v_stress,
    'calendar_horizon',v_calendar,
    'current_world_guard',v_guard,
    'entry_model_test',v_entries,
    'entry_rule_test_season',v_entry_season,
    'model','CB-WORLD-25Y-VALIDATION-v18'
  );
end;
$function$;

create or replace function public.career_long_term_health_v18(p_date date default current_date)
returns jsonb
language sql
stable
set search_path to 'public'
as $function$
  select jsonb_build_object(
    'ok',
      coalesce((public.world_integrity_guard_v18(p_date)->>'ok')::boolean,false)
      and coalesce((public.world_25y_validation_v18(
        extract(year from p_date)::int,
        extract(year from p_date)::int+25
      )->>'ok')::boolean,false),
    'date',p_date,
    'world_guard',public.world_integrity_guard_v18(p_date),
    'horizon_25y',public.world_25y_validation_v18(
      extract(year from p_date)::int,
      extract(year from p_date)::int+25
    ),
    'economy',public.career_operating_cost_profile_v15(p_date),
    'hall_of_fame_total',(select count(*) from public.hall_of_fame_candidates),
    'active_staff_profiles',(select count(*) from public.staff_profiles where active=true),
    'active_players',(select count(*) from public.players where career_status='active'),
    'model','CB-CAREER-LONG-HORIZON-v18'
  );
$function$;

-- Preserve the RPC name used by the live Edge function while upgrading its payload.
create or replace function public.career_long_term_health_v15(p_date date default current_date)
returns jsonb
language sql
stable
set search_path to 'public'
as $function$
  select public.career_long_term_health_v18(p_date);
$function$;

create or replace function public.career_system_health(p_date date)
returns jsonb
language sql
stable
set search_path to 'public'
as $function$
  select jsonb_build_object(
    'ok',
      exists(select 1 from public.career_state where id='demo')
      and exists(
        select 1 from public.players p
        join public.career_state c on c.managed_player_id=p.id
        where c.id='demo'
      )
      and coalesce((public.world_integrity_guard_v18(p_date)->>'ok')::boolean,false),
    'date',p_date,
    'career_exists',exists(select 1 from public.career_state where id='demo'),
    'managed_player_exists',exists(
      select 1 from public.players p
      join public.career_state c on c.managed_player_id=p.id
      where c.id='demo'
    ),
    'academy_exists',exists(select 1 from public.academies where id='demo'),
    'academy_active_players',(select count(*) from public.academy_roster where status='active'),
    'academy_prospects',(select count(*) from public.academy_youth where status='prospect'),
    'unread_inbox',(select count(*) from public.inbox_items where not is_read),
    'active_injuries',(select count(*) from public.injuries where lower(coalesce(status,''))='active'),
    'active_scouting',(select count(*) from public.scouting_assignments where status='active'),
    'available_sponsors',(select count(*) from public.sponsor_offers where status='available'),
    'managed_staff',(select count(*) from public.staff),
    'world_staff',(select count(*) from public.staff_profiles where active=true),
    'active_contracts',(select count(*) from public.contracts where status='active'),
    'relationships',(select count(*) from public.player_relationships where active),
    'season_plans',(select count(*) from public.player_season_plans where season=extract(year from p_date)::int),
    'living_world',public.living_world_integrity_audit_v16(p_date),
    'world_guard_v18',public.world_integrity_guard_v18(p_date),
    'model','CB-CAREER-OS-v18'
  );
$function$;

revoke all on function public.atp_commitment_rule_v18(integer) from public,anon,authenticated;
revoke all on function public.atp500_bonus_swing_v18(date,date) from public,anon,authenticated;
revoke all on function public.atp500_commitment_plan_v18(bigint,integer) from public,anon,authenticated;
revoke all on function public.atp500_commitment_status_v18(bigint,integer,date) from public,anon,authenticated;
revoke all on function public.atp500_projected_entry_field_v18(integer) from public,anon,authenticated;
revoke all on function public.atp_entry_model_test_v18(integer) from public,anon,authenticated;
revoke all on function public.world_integrity_guard_v18(date) from public,anon,authenticated;
revoke all on function public.world_25y_validation_v18(integer,integer) from public,anon,authenticated;
revoke all on function public.career_long_term_health_v18(date) from public,anon,authenticated;

grant execute on function public.atp_commitment_rule_v18(integer) to service_role;
grant execute on function public.atp500_bonus_swing_v18(date,date) to service_role;
grant execute on function public.atp500_commitment_plan_v18(bigint,integer) to service_role;
grant execute on function public.atp500_commitment_status_v18(bigint,integer,date) to service_role;
grant execute on function public.atp500_projected_entry_field_v18(integer) to service_role;
grant execute on function public.atp_entry_model_test_v18(integer) to service_role;
grant execute on function public.world_integrity_guard_v18(date) to service_role;
grant execute on function public.world_25y_validation_v18(integer,integer) to service_role;
grant execute on function public.career_long_term_health_v18(date) to service_role;

-- Keep existing live RPCs callable by the server role after CREATE OR REPLACE.
revoke all on function public.career_long_term_health_v15(date) from public,anon,authenticated;
grant execute on function public.career_long_term_health_v15(date) to service_role;
revoke all on function public.career_system_health(date) from public,anon,authenticated;
grant execute on function public.career_system_health(date) to service_role;
