
-- Managed singles ranking source-of-truth v2.
-- Preserve the frozen 2025-12-01 save baseline, then evolve the user's rank
-- from the career points ledger without falling back to stale game_world_rank.

create or replace function public.player_rank_at_date(
  p_player_id bigint,
  p_date date
) returns integer
language sql
stable
set search_path to 'public'
as $function$
  select coalesce(
    (
      select rh.ranking
      from public.ranking_history rh
      where rh.player_id=p_player_id
        and rh.snapshot_date<=coalesce(p_date,current_date)
      order by rh.snapshot_date desc,rh.id desc
      limit 1
    ),
    (
      select mr.singles_rank
      from public.managed_ranking_baseline mr
      join public.career_state cs
        on cs.id=mr.owner_id and cs.managed_player_id=p_player_id
      where mr.snapshot_date<=coalesce(p_date,current_date)
      order by mr.snapshot_date desc
      limit 1
    ),
    (
      select case
        when exists(
          select 1 from public.career_state cs
          where cs.id='demo' and cs.managed_player_id=p_player_id
        ) then coalesce(p.ranking,p.game_world_rank,999999)
        else coalesce(case when p.ranking_current then p.ranking end,p.game_world_rank,p.ranking,999999)
      end::int
      from public.players p
      where p.id=p_player_id
    ),
    999999
  )::int
$function$;

create or replace function public.recalculate_user_ranking(p_date date)
returns jsonb
language plpgsql
set search_path to 'public'
as $function$
declare
  total_points int;
  baseline_points int;
  mandatory_points int;
  optional_points int;
  finals_points int;
  new_rank int;
  managed_id bigint;
  v_base_rank int;
  v_base_points int;
  v_base_date date;
  v_world_ranked int;
begin
  perform pg_advisory_xact_lock(94832021);

  select managed_player_id into managed_id
  from public.career_state
  where id='demo';

  if managed_id is null then
    raise exception 'Managed player missing';
  end if;

  select singles_rank,singles_points,snapshot_date
  into v_base_rank,v_base_points,v_base_date
  from public.managed_ranking_baseline
  where owner_id='demo';

  if p_date<=coalesce(v_base_date,date '2025-12-01') then
    update public.players
    set points=coalesce(v_base_points,points),
        ranking=coalesce(v_base_rank,ranking),
        game_world_rank=coalesce(v_base_rank,game_world_rank),
        ranking_source='Court Boss managed career baseline',
        ranking_snapshot_date=coalesce(v_base_date,date '2025-12-01')
    where id=managed_id;

    update public.career_state
    set points=coalesce(v_base_points,points),
        singles_rank=coalesce(v_base_rank,singles_rank),
        career_date=p_date,
        updated_at=now()
    where id='demo';

    insert into public.ranking_history(player_id,snapshot_date,ranking,points)
    values(managed_id,p_date,coalesce(v_base_rank,999999),coalesce(v_base_points,0))
    on conflict do nothing;

    return jsonb_build_object(
      'points',coalesce(v_base_points,0),
      'rank',v_base_rank,
      'date',p_date,
      'player_id',managed_id,
      'baseline_preserved',true,
      'baseline_rank',v_base_rank,
      'baseline_points',v_base_points
    );
  end if;

  update public.user_ranking_points
  set active=false
  where owner_id='demo'
    and active=true
    and expiry_date<p_date;

  select coalesce(sum(
    case
      when p_date<=urp.earned_date then urp.points
      when p_date>=urp.expiry_date then 0
      else round(
        urp.points::numeric *
        (urp.expiry_date-p_date)::numeric /
        greatest(1,(urp.expiry_date-urp.earned_date)::numeric)
      )::int
    end
  ),0)::int
  into baseline_points
  from public.user_ranking_points urp
  where urp.owner_id='demo'
    and urp.active=true
    and urp.tournament_id is null
    and urp.earned_date<=p_date
    and urp.expiry_date>=p_date;

  select coalesce(sum(urp.points),0)::int
  into mandatory_points
  from public.user_ranking_points urp
  join public.tournaments t on t.id=urp.tournament_id
  where urp.owner_id='demo'
    and urp.active=true
    and urp.earned_date<=p_date
    and urp.expiry_date>=p_date
    and t.category in ('Grand Chelem','Masters 1000');

  select coalesce(sum(points),0)::int
  into optional_points
  from (
    select urp.points,
           row_number() over(
             order by urp.points desc,urp.earned_date desc,urp.id desc
           ) rn
    from public.user_ranking_points urp
    join public.tournaments t on t.id=urp.tournament_id
    where urp.owner_id='demo'
      and urp.active=true
      and urp.earned_date<=p_date
      and urp.expiry_date>=p_date
      and t.category not in ('Grand Chelem','Masters 1000','ATP Finals')
  ) x
  where rn<=6;

  select coalesce(sum(urp.points),0)::int
  into finals_points
  from public.user_ranking_points urp
  join public.tournaments t on t.id=urp.tournament_id
  where urp.owner_id='demo'
    and urp.active=true
    and urp.earned_date<=p_date
    and urp.expiry_date>=p_date
    and t.category='ATP Finals';

  total_points:=coalesce(baseline_points,0)
              +coalesce(mandatory_points,0)
              +coalesce(optional_points,0)
              +coalesce(finals_points,0);

  select count(*)::int into v_world_ranked
  from public.players
  where id<>managed_id
    and ranking_current=true
    and career_status='active'
    and coalesce(data_source,'') not ilike 'hidden duplicate merged into %';

  if v_world_ranked>=5000 then
    select 1+count(*)::int
    into new_rank
    from public.players p
    where p.id<>managed_id
      and p.ranking_current=true
      and p.career_status='active'
      and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
      and (
        coalesce(p.points,0)>total_points
        or (
          coalesce(p.points,0)=total_points
          and coalesce(p.ranking,999999)<coalesce(v_base_rank,999999)
        )
      );

    new_rank:=greatest(1,least(30000,coalesce(new_rank,30000)));
  else
    new_rank:=case
      when total_points<=0 then 30000
      when coalesce(v_base_rank,0)>0 and coalesce(v_base_points,0)>0
        then greatest(
          1,
          least(
            30000,
            round(
              v_base_rank::numeric *
              v_base_points::numeric /
              greatest(1,total_points)
            )::int
          )
        )
      else greatest(
        1,
        least(
          30000,
          round(30000.0/(1.0+total_points/35.0))::int
        )
      )
    end;
  end if;

  update public.players
  set points=total_points,
      ranking=new_rank,
      game_world_rank=new_rank,
      ranking_source='Court Boss managed career · anchored 52-week ledger',
      ranking_snapshot_date=p_date
  where id=managed_id;

  update public.career_state
  set points=total_points,
      singles_rank=new_rank,
      career_date=p_date,
      updated_at=now()
  where id='demo';

  insert into public.ranking_history(player_id,snapshot_date,ranking,points)
  values(managed_id,p_date,new_rank,total_points)
  on conflict do nothing;

  return jsonb_build_object(
    'points',total_points,
    'rank',new_rank,
    'date',p_date,
    'player_id',managed_id,
    'baseline_remaining',baseline_points,
    'mandatory_points',mandatory_points,
    'best_6_optional_points',optional_points,
    'finals_points',finals_points,
    'base_counting_events',18,
    'world_ranked_pool',v_world_ranked,
    'baseline_rank',v_base_rank,
    'baseline_points',v_base_points,
    'ranking_model',
      case when v_world_ranked>=5000
        then 'world_points_order'
        else 'managed_baseline_anchor'
      end
  );
end;
$function$;

update public.players p
set game_world_rank=coalesce(m.singles_rank,p.ranking),
    ranking=coalesce(m.singles_rank,p.ranking),
    points=coalesce(m.singles_points,p.points),
    ranking_source='Court Boss managed career baseline',
    ranking_snapshot_date=m.snapshot_date
from public.career_state c
join public.managed_ranking_baseline m on m.owner_id=c.id
where c.id='demo'
  and p.id=c.managed_player_id
  and c.career_date<=m.snapshot_date;

insert into public.ranking_history(player_id,snapshot_date,ranking,points)
select c.managed_player_id,m.snapshot_date,m.singles_rank,m.singles_points
from public.career_state c
join public.managed_ranking_baseline m on m.owner_id=c.id
where c.id='demo'
on conflict do nothing;
