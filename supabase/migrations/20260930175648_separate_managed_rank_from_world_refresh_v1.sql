-- Keep the managed career ranking out of the autonomous AI world-ranking writer.
-- The managed rank is owned by recalculate_user_ranking() and its frozen save baseline.

CREATE OR REPLACE FUNCTION public.refresh_world_rankings(p_date date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_date date:=coalesce(p_date,current_date);
  v_managed bigint;
  v_updated int:=0;
  v_leader text;
begin
  perform pg_advisory_xact_lock(94832021);
  select managed_player_id into v_managed
  from public.career_state where id='demo';

  update public.world_ranking_points
  set active=false
  where active=true and expiry_date<v_date;

  with mandatory as (
    select w.player_id,coalesce(sum(w.points),0)::int pts
    from public.world_ranking_points w
    join public.tournaments t on t.id=w.tournament_id
    where w.active=true and w.earned_date<=v_date and w.expiry_date>=v_date
      and t.category in ('Grand Chelem','Masters 1000')
    group by w.player_id
  ),
  optional_ranked as (
    select w.player_id,w.points,
           row_number() over(partition by w.player_id order by w.points desc,w.earned_date desc,w.id desc) rn
    from public.world_ranking_points w
    join public.tournaments t on t.id=w.tournament_id
    where w.active=true and w.earned_date<=v_date and w.expiry_date>=v_date
      and t.category not in ('Grand Chelem','Masters 1000','ATP Finals')
  ),
  optional as (
    select player_id,coalesce(sum(points),0)::int pts
    from optional_ranked where rn<=6 group by player_id
  ),
  finals as (
    select w.player_id,coalesce(sum(w.points),0)::int pts
    from public.world_ranking_points w
    join public.tournaments t on t.id=w.tournament_id
    where w.active=true and w.earned_date<=v_date and w.expiry_date>=v_date
      and t.category='ATP Finals'
    group by w.player_id
  ),
  totals as (
    select p.id,
      greatest(0,round(
        coalesce(b.baseline_points,0) *
        case
          when b.player_id is null then 0
          when v_date<=b.snapshot_date then 1
          when v_date>=b.expiry_date then 0
          else (b.expiry_date-v_date)::numeric/
               greatest(1,(b.expiry_date-b.snapshot_date)::numeric)
        end
      )::int) baseline_remaining,
      coalesce(m.pts,0)+coalesce(o.pts,0)+coalesce(f.pts,0) game_points
    from public.players p
    left join public.world_ranking_baseline_decay b on b.player_id=p.id
    left join mandatory m on m.player_id=p.id
    left join optional o on o.player_id=p.id
    left join finals f on f.player_id=p.id
    where p.ranking_current=true
      and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
      and p.id is distinct from v_managed
  )
  update public.players p
  set points=greatest(0,t.baseline_remaining+t.game_points),
      ranking_source='Court Boss ATP 2026 ledger · mandatory + best 6 optional'
  from totals t
  where p.id=t.id;

  get diagnostics v_updated=row_count;

  with ranked as (
    select id,row_number() over(order by points desc,current_ability desc,form desc,id)::int new_rank
    from public.players
    where ranking_current=true
      and coalesce(data_source,'') not ilike 'hidden duplicate merged into %'
  )
  update public.players p
  set ranking=r.new_rank
  from ranked r
  where p.id=r.id
    and p.id is distinct from v_managed;

  -- Managed-player ranking history is owned exclusively by
  -- recalculate_user_ranking(), which preserves the save's anchored career rank.
  insert into public.ranking_history(player_id,snapshot_date,ranking,points)
  select id,v_date,ranking,points
  from public.players
  where ranking_current=true
    and coalesce(data_source,'') not ilike 'hidden duplicate merged into %'
    and id is distinct from v_managed
  on conflict do nothing;

  select name into v_leader
  from public.players
  where ranking_current=true
    and coalesce(data_source,'') not ilike 'hidden duplicate merged into %'
  order by ranking limit 1;

  return jsonb_build_object(
    'date',v_date,'updated_players',v_updated,'leader',v_leader,
    'model','ATP 2026 · GS/M1000 mandatory + best 6 optional + Finals'
  );
end;
$function$
;

revoke all on function public.refresh_world_rankings(date) from public;
revoke all on function public.refresh_world_rankings(date) from anon;
revoke all on function public.refresh_world_rankings(date) from authenticated;
grant execute on function public.refresh_world_rankings(date) to service_role;
