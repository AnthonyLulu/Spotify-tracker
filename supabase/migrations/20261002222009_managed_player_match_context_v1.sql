alter table public.live_match_sessions
  add column if not exists managed_player_id bigint references public.players(id);

alter table public.match_history
  add column if not exists managed_player_id bigint references public.players(id);

create index if not exists live_match_sessions_managed_player_idx
  on public.live_match_sessions(managed_player_id,status);

create index if not exists match_history_managed_player_idx
  on public.match_history(managed_player_id,match_date desc);
