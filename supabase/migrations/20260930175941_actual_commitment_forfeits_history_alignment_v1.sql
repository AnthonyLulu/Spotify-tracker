-- Court Boss injury/forfeit consistency fix
-- Forfeits are generated only for actual commitments, never every eligible tournament.

CREATE OR REPLACE FUNCTION public.refresh_tournament_forfeits(p_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  nrows int:=0;
begin
  with commitments as (
    select e.tournament_id,e.player_id
    from public.world_tournament_entries e

    union
    select e.tournament_id,e.player_id
    from public.world_tournament_qualifying_entries e

    union
    select e.tournament_id,wp.player_a_id
    from public.world_doubles_tournament_entries e
    join public.world_doubles_partnerships wp on wp.id=e.pair_id

    union
    select e.tournament_id,wp.player_b_id
    from public.world_doubles_tournament_entries e
    join public.world_doubles_partnerships wp on wp.id=e.pair_id

    union
    select e.tournament_id,wp.player_a_id
    from public.world_doubles_qualifying_entries e
    join public.world_doubles_partnerships wp on wp.id=e.pair_id

    union
    select e.tournament_id,wp.player_b_id
    from public.world_doubles_qualifying_entries e
    join public.world_doubles_partnerships wp on wp.id=e.pair_id

    union
    select e.tournament_id,e.player_a_id
    from public.world_junior_doubles_entries e

    union
    select e.tournament_id,e.player_b_id
    from public.world_junior_doubles_entries e

    union
    select e.tournament_id,e.player_id
    from public.ncaa_individual_entries e

    union
    select e.tournament_id,e.player_a_id
    from public.ncaa_individual_doubles_entries e

    union
    select e.tournament_id,e.player_b_id
    from public.ncaa_individual_doubles_entries e

    union
    select e.tournament_id,cs.managed_player_id
    from public.entries e
    cross join public.career_state cs
    where cs.id='demo'
      and lower(coalesce(e.status,'active')) not in ('withdrawn','declined','cancelled')
  )
  insert into public.tournament_forfeits(tournament_id,player_id,reason)
  select distinct
    c.tournament_id,
    c.player_id,
    i.injury_type
  from commitments c
  join public.injuries i on i.player_id=c.player_id
  join public.tournaments t on t.id=c.tournament_id
  where lower(coalesce(i.status,''))='active'
    and t.start_date between p_date and p_date+28
    and i.expected_return>=t.start_date
  on conflict(tournament_id,player_id)
  do update set reason=excluded.reason;

  get diagnostics nrows=row_count;

  delete from public.tournament_forfeits tf
  where not exists(
      select 1
      from public.injuries i
      where i.player_id=tf.player_id
        and lower(coalesce(i.status,''))='active'
        and i.expected_return>=p_date
    )
    and tf.created_at < now()-interval '1 day';

  return jsonb_build_object(
    'forfeits',nrows,
    'model','actual commitments only · singles/qualifying/doubles/junior/NCAA'
  );
end;
$function$;

