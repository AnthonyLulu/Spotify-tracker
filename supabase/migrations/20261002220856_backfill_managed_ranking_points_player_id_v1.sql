-- Backfill legacy managed ranking points so every row belongs to a concrete player.
update public.user_ranking_points
set player_id=(select managed_player_id from public.career_state where id='demo')
where owner_id='demo'
  and player_id is null
  and (select managed_player_id from public.career_state where id='demo') is not null;
