create table if not exists public.managed_player_doubles_ranking_baselines (
  player_id bigint primary key references public.players(id) on delete cascade,
  snapshot_date date not null,
  doubles_rank integer,
  doubles_points integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.recalculate_managed_player_doubles_ranking(
  p_player_id bigint,
  p_date date
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_primary_id bigint;
  v_focus text;
  v_base_rank int;
  v_base_points int;
  v_base_date date;
  v_baseline_remaining int:=0;
  v_results int:=0;
  v_total int:=0;
  v_rank int:=3000;
begin
  if p_player_id is null then raise exception 'Managed player missing'; end if;

  select managed_player_id into v_primary_id
  from public.career_state where id='demo';

  if p_player_id=v_primary_id then
    return public.recalculate_user_doubles_ranking(p_date);
  end if;

  if not exists(
    select 1 from public.academy_roster ar
    where ar.player_id=p_player_id and ar.status='active'
  ) then
    raise exception 'Player is not in managed squad';
  end if;

  select coalesce(career_focus,'mixed') into v_focus
  from public.players where id=p_player_id;

  insert into public.managed_player_doubles_ranking_baselines(
    player_id,snapshot_date,doubles_rank,doubles_points
  )
  select
    p.id,
    coalesce(p.doubles_snapshot_date,date '2025-12-01'),
    p.doubles_ranking,
    coalesce(p.doubles_points,0)
  from public.players p
  where p.id=p_player_id
  on conflict(player_id) do nothing;

  select doubles_rank,doubles_points,snapshot_date
  into v_base_rank,v_base_points,v_base_date
  from public.managed_player_doubles_ranking_baselines
  where player_id=p_player_id;

  if v_base_date is null then raise exception 'Managed doubles baseline missing for %',p_player_id; end if;

  update public.user_doubles_points
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

  select coalesce(sum(points),0)::int
  into v_results
  from (
    select udp.points,
           row_number() over(order by udp.points desc,udp.earned_date desc,udp.id desc) rn
    from public.user_doubles_points udp
    where udp.player_id=p_player_id
      and udp.active=true
      and udp.tournament_id is not null
      and udp.earned_date<=p_date
      and udp.expiry_date>=p_date
  ) x
  where rn<=18;

  v_total:=coalesce(v_baseline_remaining,0)+coalesce(v_results,0);

  if coalesce(v_focus,'mixed')='singles_only' and v_total<=0 then
    v_rank:=3000;
  else
    select 1+count(*)::int
    into v_rank
    from public.players p
    where p.id<>p_player_id
      and p.career_status='active'
      and coalesce(p.doubles_points,0)>0
      and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
      and (
        coalesce(p.doubles_points,0)>v_total
        or (
          coalesce(p.doubles_points,0)=v_total
          and coalesce(p.doubles_ranking,999999)<coalesce(v_base_rank,999999)
        )
      );
    v_rank:=greatest(1,least(3000,coalesce(v_rank,3000)));
  end if;

  update public.players
  set doubles_points=v_total,
      doubles_ranking=case when coalesce(v_focus,'mixed')='singles_only' and v_total<=0 then null else v_rank end,
      doubles_snapshot_date=p_date,
      doubles_source='Court Boss managed squad · player scoped doubles ledger'
  where id=p_player_id;

  return jsonb_build_object(
    'player_id',p_player_id,
    'points',v_total,
    'rank',case when coalesce(v_focus,'mixed')='singles_only' and v_total<=0 then null else v_rank end,
    'internal_rank',v_rank,
    'date',p_date,
    'baseline_remaining',v_baseline_remaining,
    'best_18_results',v_results,
    'baseline_rank',v_base_rank,
    'baseline_points',v_base_points,
    'ranking_model','managed_squad_player_scoped_doubles_v1'
  );
end
$function$;

revoke all on function public.recalculate_managed_player_doubles_ranking(bigint,date) from public,anon,authenticated;
grant execute on function public.recalculate_managed_player_doubles_ranking(bigint,date) to service_role;
