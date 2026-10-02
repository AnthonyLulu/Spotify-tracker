update public.user_doubles_points udp
set player_id=c.managed_player_id
from public.career_state c
where c.id='demo'
  and udp.owner_id='demo'
  and udp.player_id is null
  and c.managed_player_id is not null;

CREATE OR REPLACE FUNCTION public.recalculate_user_doubles_ranking(p_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
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
  where owner_id='demo' and player_id=managed_id and active=true and expiry_date<p_date;

  select coalesce(sum(
    case
      when p_date<=udp.earned_date then udp.points
      when p_date>=udp.expiry_date then 0
      else round(
        udp.points::numeric *
        (udp.expiry_date-p_date)::numeric /
        greatest(1,(udp.expiry_date-udp.earned_date)::numeric)
      )::int
    end
  ),0)::int
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
  set doubles_points=total_points,doubles_snapshot_date=p_date,
      doubles_source='Court Boss career save · best 18 + decaying 2025 baseline'
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
    -- Until the world ledger has been populated, keep the frozen ranking as the
    -- calibration anchor instead of using an arbitrary points-to-rank formula.
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
    'baseline_rank',v_base_rank,'baseline_points',v_base_points
  );
end;
$function$
;
