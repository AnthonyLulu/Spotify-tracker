-- Court Boss · doubles ranking cleanup
-- Removes every remaining daily linear decay from the ATP doubles baseline.
-- Historical 01/12/2025 doubles data is aggregate-only, so it is preserved
-- intact until its 52-week expiry. New simulated results expire per event.

CREATE OR REPLACE FUNCTION public.recalculate_user_doubles_ranking(p_date date)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path='public'
AS $function$
declare
  baseline_points int;
  result_points int;
  total_points int;
  new_rank int;
  managed_id bigint;
  v_focus text;
  v_public_rank int;
  v_world_ranked int;
  v_base_rank int;
  v_base_points int;
begin
  perform pg_advisory_xact_lock(94832021);

  select managed_player_id,coalesce(career_focus,'mixed')
  into managed_id,v_focus
  from public.career_state
  where id='demo';

  if managed_id is null then raise exception 'Managed player missing'; end if;

  select doubles_rank,doubles_points
  into v_base_rank,v_base_points
  from public.managed_ranking_baseline
  where owner_id='demo';

  if p_date<=date '2025-12-01' then
    update public.career_state
    set doubles_points=coalesce(v_base_points,doubles_points),
        doubles_rank=coalesce(v_base_rank,doubles_rank),
        updated_at=now()
    where id='demo';

    update public.players
    set doubles_points=coalesce(v_base_points,doubles_points),
        doubles_ranking=coalesce(v_base_rank,doubles_ranking),
        doubles_snapshot_date=date '2025-12-01',
        doubles_source='Court Boss frozen 2025-12-01 baseline'
    where id=managed_id;

    return jsonb_build_object(
      'points',coalesce(v_base_points,0),
      'rank',v_base_rank,
      'internal_rank',v_base_rank,
      'active',true,
      'career_focus',v_focus,
      'date',p_date,
      'player_id',managed_id,
      'baseline_preserved',true
    );
  end if;

  update public.user_doubles_points
  set active=false
  where owner_id='demo'
    and player_id=managed_id
    and active=true
    and expiry_date<p_date;

  select coalesce(sum(udp.points),0)::int
  into baseline_points
  from public.user_doubles_points udp
  where udp.owner_id='demo'
    and udp.player_id=managed_id
    and udp.active=true
    and udp.tournament_id is null
    and udp.earned_date<=p_date
    and udp.expiry_date>=p_date;

  select coalesce(sum(points),0)::int
  into result_points
  from (
    select udp.points,
           row_number() over(order by udp.points desc,udp.earned_date desc,udp.id desc) rn
    from public.user_doubles_points udp
    where udp.owner_id='demo'
      and udp.player_id=managed_id
      and udp.active=true
      and udp.tournament_id is not null
      and udp.earned_date<=p_date
      and udp.expiry_date>=p_date
  ) x
  where rn<=18;

  total_points:=coalesce(baseline_points,0)+coalesce(result_points,0);

  update public.players
  set doubles_points=total_points,
      doubles_snapshot_date=p_date,
      doubles_source='Court Boss career save · best 18 + fixed legacy baseline until 52w expiry'
  where id=managed_id;

  select count(*)::int into v_world_ranked
  from public.players
  where id<>managed_id
    and career_status='active'
    and coalesce(doubles_points,0)>0
    and coalesce(data_source,'') not ilike 'hidden duplicate merged into %';

  if v_world_ranked>=500 then
    select 1+count(*)::int
    into new_rank
    from public.players p
    where p.id<>managed_id
      and p.career_status='active'
      and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
      and (
        coalesce(p.doubles_points,0)>total_points
        or (
          coalesce(p.doubles_points,0)=total_points
          and coalesce(p.doubles_ranking,999999)<coalesce(v_base_rank,999999)
        )
      );
    new_rank:=greatest(1,least(3000,coalesce(new_rank,3000)));
  else
    new_rank:=case
      when total_points<=0 then 3000
      when coalesce(v_base_rank,0)>0 and coalesce(v_base_points,0)>0
        then greatest(1,least(3000,round(v_base_rank::numeric*v_base_points::numeric/greatest(1,total_points))::int))
      else greatest(1,least(3000,round(2800.0/(1.0+total_points/45.0))::int))
    end;
  end if;

  update public.career_state
  set doubles_points=total_points,doubles_rank=new_rank,updated_at=now()
  where id='demo';

  if v_focus='singles_only' and total_points<=0 then
    update public.players
    set doubles_ranking=null,doubles_points=0,doubles_snapshot_date=p_date,
        doubles_source='Court Boss · simple exclusivement · non classé double'
    where id=managed_id;
    v_public_rank:=null;
  else
    update public.players set doubles_ranking=new_rank where id=managed_id;
    v_public_rank:=new_rank;
  end if;

  return jsonb_build_object(
    'points',total_points,'rank',v_public_rank,'internal_rank',new_rank,
    'active',not (v_focus='singles_only' and total_points<=0),
    'career_focus',v_focus,'date',p_date,'player_id',managed_id,
    'baseline_remaining',baseline_points,'best_18_results',result_points,
    'counting_results',18,'world_ranked_pool',v_world_ranked,
    'baseline_rank',v_base_rank,'baseline_points',v_base_points,
    'baseline_model','fixed_until_52w_expiry'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.refresh_world_doubles_player_rankings(p_date date default current_date)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path='public'
AS $function$
declare
  v_date date:=coalesce(p_date,current_date);
  v_ranked int:=0;
  v_snapshots int:=0;
begin
  perform pg_advisory_xact_lock(94832021);

  if v_date<=date '2025-12-01' then
    return jsonb_build_object('date',v_date,'ranked',0,'historical_cutoff',true);
  end if;

  update public.world_doubles_ranking_points
  set active=(expiry_date>=v_date)
  where active is distinct from (expiry_date>=v_date);

  with result_rows as (
    select
      w.player_id,w.points,w.earned_date,w.id,w.tournament_id,t.category,
      row_number() over(
        partition by w.player_id
        order by w.points desc,w.earned_date desc,w.id desc
      ) rn
    from public.world_doubles_ranking_points w
    left join public.tournaments t on t.id=w.tournament_id
    where w.active=true
      and w.earned_date<=v_date
      and w.expiry_date>=v_date
  ),
  future_metrics as (
    select
      player_id,
      coalesce(sum(points) filter(where rn<=18),0)::int future_points,
      count(*)::int events_played,
      coalesce(sum(points) filter(
        where category in ('Grand Chelem','Masters 1000','ATP Finals')
      ),0)::int mandatory_points,
      coalesce(
        array_agg(points order by points desc,earned_date desc,id desc)
          filter(where rn<=18),
        array[]::integer[]
      ) result_vector
    from result_rows
    group by player_id
  ),
  scores as (
    select
      p.id,
      p.doubles_ranking as baseline_rank,
      case
        when b.snapshot_date is not null and v_date<=b.snapshot_date+364
          then coalesce(b.points,0)
        else 0
      end::int baseline_points,
      coalesce(f.future_points,0)::int future_points,
      (
        case
          when b.snapshot_date is not null and v_date<=b.snapshot_date+364
            then coalesce(b.points,0)
          else 0
        end
        +coalesce(f.future_points,0)
      )::int total_points,
      coalesce(f.events_played,0)::int events_played,
      coalesce(f.mandatory_points,0)::int mandatory_points,
      coalesce(f.result_vector,array[]::integer[]) result_vector
    from public.players p
    left join public.doubles_baseline_points b on b.player_id=p.id
    left join future_metrics f on f.player_id=p.id
    where p.career_status='active'
      and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
      and (
        (
          b.snapshot_date is not null
          and v_date<=b.snapshot_date+364
          and coalesce(b.points,0)>0
        )
        or coalesce(f.future_points,0)>0
      )
  ),
  ranked as (
    select s.id,s.total_points,
      row_number() over(
        order by
          s.total_points desc,
          case when s.baseline_points>0 then coalesce(s.baseline_rank,999999) else 0 end asc,
          s.events_played asc,
          s.mandatory_points desc,
          s.result_vector desc
      )::int rr
    from scores s
  )
  update public.players p
  set doubles_points=r.total_points,
      doubles_ranking=r.rr,
      doubles_snapshot_date=v_date,
      doubles_source='Court Boss doubles · best 18 rolling + fixed 2025 baseline · ATP tie-breaks',
      career_high_doubles_rank=case
        when p.career_high_doubles_rank is null or r.rr<p.career_high_doubles_rank then r.rr
        else p.career_high_doubles_rank end,
      career_high_doubles_rank_date=case
        when p.career_high_doubles_rank is null or r.rr<p.career_high_doubles_rank then v_date
        else p.career_high_doubles_rank_date end,
      career_high_doubles_source=case
        when p.career_high_doubles_rank is null or r.rr<p.career_high_doubles_rank then 'Court Boss simulation'
        else p.career_high_doubles_source end
  from ranked r
  where p.id=r.id
    and p.id<>coalesce((select managed_player_id from public.career_state where id='demo'),-1);

  get diagnostics v_ranked=row_count;
  v_snapshots:=public.snapshot_doubles_rankings(v_date);

  return jsonb_build_object(
    'date',v_date,
    'ranked',v_ranked,
    'snapshots',v_snapshots,
    'model','best_18_rolling_fixed_baseline_atp_ties'
  );
end;
$function$;

COMMENT ON TABLE public.world_ranking_baseline_decay IS
'DEPRECATED 2026-10-03: legacy linear-decay singles baseline. Canonical singles ranking uses atp_defending_points_ledger + atp_player_breakdown.';
