-- Per-player cumulative training XP for Court Boss managed squads.
create table if not exists public.managed_player_training_progress (
  player_id bigint not null references public.players(id) on delete cascade,
  attribute text not null,
  xp numeric not null default 0,
  updated_at timestamptz not null default now(),
  primary key(player_id,attribute),
  constraint managed_player_training_progress_xp_check check (xp>=0)
);

create index if not exists managed_player_training_progress_player_idx
  on public.managed_player_training_progress(player_id);
