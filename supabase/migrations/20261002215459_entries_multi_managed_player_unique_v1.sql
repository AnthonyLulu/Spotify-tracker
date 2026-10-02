-- Allow multiple managed players to enter the same tournament independently.
alter table public.entries
  drop constraint if exists entries_tournament_id_key;

drop index if exists public.entries_tournament_id_key;

create unique index if not exists entries_tournament_player_key
  on public.entries(tournament_id,player_id);
