create index if not exists idx_players_generated_active_age_v36
on public.players (game_generated, career_status, age)
include (data_source)
where game_generated = true and career_status = 'active';
