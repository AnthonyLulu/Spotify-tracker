create index if not exists idx_players_retired_on_date_v41
  on public.players(retired_date,id)
  where career_status='retired';
