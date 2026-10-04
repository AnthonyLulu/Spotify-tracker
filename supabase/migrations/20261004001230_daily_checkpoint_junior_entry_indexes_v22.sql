create index if not exists idx_junior_entries_player_tournament_v22
on public.junior_tournament_entries (player_id,tournament_id);

create index if not exists idx_players_active_junior_rank_v22
on public.players (junior_ranking,current_ability desc,id)
include (birth_date,country,fitness,fatigue,injury_status,career_focus,ranking)
where career_status='active' and junior_ranking is not null;
