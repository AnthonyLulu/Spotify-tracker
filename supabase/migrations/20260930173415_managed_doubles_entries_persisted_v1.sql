
create table if not exists public.managed_doubles_entries(
  id bigint generated always as identity primary key,
  owner_id text not null default 'demo',
  tournament_id bigint not null references public.tournaments(id) on delete cascade,
  player_id bigint not null references public.players(id) on delete cascade,
  partner_id bigint not null references public.players(id) on delete cascade,
  status text not null default 'entered' check(status in ('entered','withdrawn')),
  entry_method text not null default 'direct',
  entry_phase text not null default 'advance',
  combined_rank integer,
  protected_combined_rank integer,
  projected_cut integer,
  requested_on date not null,
  withdrawn_on date,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(owner_id,tournament_id)
);

create index if not exists idx_managed_doubles_entries_active
  on public.managed_doubles_entries(owner_id,status,requested_on,tournament_id);
create index if not exists idx_managed_doubles_entries_pair
  on public.managed_doubles_entries(player_id,partner_id,status);

alter table public.managed_doubles_entries enable row level security;

comment on table public.managed_doubles_entries is
  'Server-side source of truth for the managed pair tournament schedule. Partnership, event registration and played draws remain separate concepts.';
