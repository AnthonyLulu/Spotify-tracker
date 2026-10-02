CREATE OR REPLACE FUNCTION public.recalculate_managed_player_ranking(
  p_player_id bigint,
  p_date date,
  p_sync_career boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path TO 'public'
AS $function$
declare
  v_player public.players%rowtype;
  baseline_points int:=0;
  mandatory_points int:=0;
  optional_points int:=0;
  finals_points int:=0;
  total_points int:=0;
  new_rank int:=30000;
  baseline_rank int;
  baseline_date date:=date '2025-12-01';
  world_ranked int:=0;
begin
  perform pg_advisory_xact_lock(94832021 + (p_player_id % 1000000)::int);

  select * into v_player
  from public.players
  where id=p_player_id;

  if not found then
    raise exception 'Player % missing',p_player_id;
  end if;

  if not exists(
    select 1 from public.user_ranking_points
    where owner_id='demo' and player_id=p_player_id and tournament_id is null
  ) then
    select rh.ranking,rh.points,rh.snapshot_date
      into baseline_rank,baseline_points,baseline_date
    from public.ranking_history rh
    where rh.player_id=p_player_id
      and rh.snapshot_date<=date '2025-12-01'
    order by rh.snapshot_date desc
    limit 1;

    baseline_rank:=coalesce(baseline_rank,v_player.ranking,30000);
    baseline_points:=coalesce(baseline_points,v_player.points,0);
    baseline_date:=coalesce(baseline_date,date '2025-12-01');

    insert into public.user_ranking_points(
      owner_id,player_id,tournament_id,label,earned_date,expiry_date,points,active
    )
    values(
      'demo',p_player_id,null,'Points de départ - '||coalesce(v_player.name,'Joueur'),
      baseline_date,(baseline_date+364),baseline_points,true
    );
  end if;

  update public.user_ranking_points
  set active=false
  where owner_id='demo'
    and player_id=p_player_id
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
    and urp.player_id=p_player_id
    and urp.active=true
    and urp.tournament_id is null
    and urp.earned_date<=p_date
    and urp.expiry_date>=p_date;

  select coalesce(sum(urp.points),0)::int
  into mandatory_points
  from public.user_ranking_points urp
  join public.tournaments t on t.id=urp.tournament_id
  where urp.owner_id='demo'
    and urp.player_id=p_player_id
    and urp.active=true
    and urp.earned_date<=p_date
    and urp.expiry_date>=p_date
    and t.category in ('Grand Chelem','Masters 1000');

  select coalesce(sum(points),0)::int
  into optional_points
  from (
    select urp.points,
           row_number() over(order by urp.points desc,urp.earned_date desc,urp.id desc) rn
    from public.user_ranking_points urp
    join public.tournaments t on t.id=urp.tournament_id
    where urp.owner_id='demo'
      and urp.player_id=p_player_id
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
    and urp.player_id=p_player_id
    and urp.active=true
    and urp.earned_date<=p_date
    and urp.expiry_date>=p_date
    and t.category='ATP Finals';

  total_points:=coalesce(baseline_points,0)
              +coalesce(mandatory_points,0)
              +coalesce(optional_points,0)
              +coalesce(finals_points,0);

  select count(*)::int into world_ranked
  from public.players
  where id<>p_player_id
    and ranking_current=true
    and career_status='active'
    and coalesce(data_source,'') not ilike 'hidden duplicate merged into %';

  select 1+count(*)::int
  into new_rank
  from public.players p
  where p.id<>p_player_id
    and p.ranking_current=true
    and p.career_status='active'
    and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
    and (
      coalesce(p.points,0)>total_points
      or (
        coalesce(p.points,0)=total_points
        and coalesce(p.ranking,999999)<coalesce(v_player.ranking,999999)
      )
    );

  new_rank:=greatest(1,least(30000,coalesce(new_rank,30000)));

  update public.players
  set points=total_points,
      ranking=new_rank,
      game_world_rank=new_rank,
      ranking_current=true,
      ranking_source='Court Boss managed career · player-scoped 52-week ledger',
      ranking_snapshot_date=p_date
  where id=p_player_id;

  if p_sync_career then
    update public.career_state
    set points=total_points,
        singles_rank=new_rank,
        career_date=p_date,
        updated_at=now()
    where id='demo';
  end if;

  insert into public.ranking_history(player_id,snapshot_date,ranking,points)
  values(p_player_id,p_date,new_rank,total_points)
  on conflict do nothing;

  return jsonb_build_object(
    'player_id',p_player_id,
    'points',total_points,
    'rank',new_rank,
    'date',p_date,
    'baseline_remaining',baseline_points,
    'mandatory_points',mandatory_points,
    'best_6_optional_points',optional_points,
    'finals_points',finals_points,
    'world_ranked_pool',world_ranked,
    'ranking_model','managed_player_scoped_world_points_order'
  );
end
$function$;

REVOKE ALL ON FUNCTION public.recalculate_managed_player_ranking(bigint,date,boolean) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.recalculate_managed_player_ranking(bigint,date,boolean) TO service_role;
