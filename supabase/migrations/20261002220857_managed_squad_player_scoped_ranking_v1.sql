create table if not exists public.managed_player_ranking_baselines (
  player_id bigint primary key references public.players(id) on delete cascade,
  snapshot_date date not null,
  singles_rank integer,
  singles_points integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

CREATE OR REPLACE FUNCTION public.recalculate_managed_player_ranking(p_player_id bigint, p_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  v_primary_id bigint;
  v_base_rank int;
  v_base_points int;
  v_base_date date;
  v_baseline_remaining int:=0;
  v_mandatory int:=0;
  v_optional int:=0;
  v_finals int:=0;
  v_total int:=0;
  v_rank int:=30000;
begin
  if p_player_id is null then
    raise exception 'Managed player missing';
  end if;

  select managed_player_id into v_primary_id
  from public.career_state
  where id='demo';

  if p_player_id=v_primary_id then
    return public.recalculate_user_ranking(p_date);
  end if;

  insert into public.managed_player_ranking_baselines(player_id,snapshot_date,singles_rank,singles_points)
  select
    p.id,
    coalesce(p.ranking_snapshot_date,date '2025-12-01'),
    p.ranking,
    coalesce(p.points,0)
  from public.players p
  where p.id=p_player_id
  on conflict(player_id) do nothing;

  select singles_rank,singles_points,snapshot_date
  into v_base_rank,v_base_points,v_base_date
  from public.managed_player_ranking_baselines
  where player_id=p_player_id;

  if v_base_date is null then
    raise exception 'Managed player baseline missing for %',p_player_id;
  end if;

  update public.user_ranking_points
  set active=false
  where player_id=p_player_id
    and active=true
    and expiry_date<p_date;

  v_baseline_remaining:=case
    when p_date<=v_base_date then coalesce(v_base_points,0)
    when p_date>=v_base_date+364 then 0
    else round(
      coalesce(v_base_points,0)::numeric
      * greatest(0,(v_base_date+364-p_date))::numeric
      / 364.0
    )::int
  end;

  select coalesce(sum(urp.points),0)::int
  into v_mandatory
  from public.user_ranking_points urp
  join public.tournaments t on t.id=urp.tournament_id
  where urp.player_id=p_player_id
    and urp.active=true
    and urp.earned_date<=p_date
    and urp.expiry_date>=p_date
    and t.category in ('Grand Chelem','Masters 1000');

  select coalesce(sum(points),0)::int
  into v_optional
  from (
    select urp.points,
           row_number() over(order by urp.points desc,urp.earned_date desc,urp.id desc) rn
    from public.user_ranking_points urp
    join public.tournaments t on t.id=urp.tournament_id
    where urp.player_id=p_player_id
      and urp.active=true
      and urp.earned_date<=p_date
      and urp.expiry_date>=p_date
      and t.category not in ('Grand Chelem','Masters 1000','ATP Finals')
  ) x
  where rn<=6;

  select coalesce(sum(urp.points),0)::int
  into v_finals
  from public.user_ranking_points urp
  join public.tournaments t on t.id=urp.tournament_id
  where urp.player_id=p_player_id
    and urp.active=true
    and urp.earned_date<=p_date
    and urp.expiry_date>=p_date
    and t.category='ATP Finals';

  v_total:=coalesce(v_baseline_remaining,0)+coalesce(v_mandatory,0)+coalesce(v_optional,0)+coalesce(v_finals,0);

  select 1+count(*)::int
  into v_rank
  from public.players p
  where p.id<>p_player_id
    and p.ranking_current=true
    and p.career_status='active'
    and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
    and (
      coalesce(p.points,0)>v_total
      or (
        coalesce(p.points,0)=v_total
        and coalesce(p.ranking,999999)<coalesce(v_base_rank,999999)
      )
    );

  v_rank:=greatest(1,least(30000,coalesce(v_rank,30000)));

  update public.players
  set points=v_total,
      ranking=v_rank,
      game_world_rank=v_rank,
      ranking_current=true,
      ranking_source='Court Boss managed squad · player scoped 52-week ledger',
      ranking_snapshot_date=p_date
  where id=p_player_id;

  insert into public.ranking_history(player_id,snapshot_date,ranking,points)
  values(p_player_id,p_date,v_rank,v_total)
  on conflict do nothing;

  return jsonb_build_object(
    'player_id',p_player_id,
    'points',v_total,
    'rank',v_rank,
    'date',p_date,
    'baseline_remaining',v_baseline_remaining,
    'mandatory_points',v_mandatory,
    'best_6_optional_points',v_optional,
    'finals_points',v_finals,
    'baseline_rank',v_base_rank,
    'baseline_points',v_base_points,
    'ranking_model','managed_squad_player_scoped_v1'
  );
end;
$function$;

revoke all on function public.recalculate_managed_player_ranking(bigint,date) from public,anon,authenticated;
grant execute on function public.recalculate_managed_player_ranking(bigint,date) to service_role;
