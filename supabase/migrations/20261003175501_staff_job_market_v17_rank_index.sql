create index if not exists idx_players_active_effective_world_rank_v17
on public.players ((coalesce(game_world_rank, ranking, 999999)), id)
where career_status='active';
