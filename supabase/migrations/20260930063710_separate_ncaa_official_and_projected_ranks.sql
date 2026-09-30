
alter table public.ncaa_player_registry
  add column if not exists ita_rank_official integer,
  add column if not exists projected_rank integer,
  add column if not exists rank_source_kind text;

comment on column public.ncaa_player_registry.ita_rank_official is
  'Official ITA singles ranking for the registry snapshot. Null for Court Boss projected depth.';
comment on column public.ncaa_player_registry.projected_rank is
  'Court Boss gameplay depth rank. Kept separate from official ITA ranking.';
comment on column public.ncaa_player_registry.rank_source_kind is
  'official_ita, court_boss_projection, historical_official, or unknown.';

create index if not exists idx_ncaa_registry_official_rank
  on public.ncaa_player_registry (season, ita_rank_official)
  where ita_rank_official is not null;

create index if not exists idx_ncaa_registry_projected_rank
  on public.ncaa_player_registry (season, projected_rank)
  where projected_rank is not null;
