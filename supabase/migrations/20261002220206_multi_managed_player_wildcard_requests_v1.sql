alter table public.wildcard_requests
  add column if not exists player_id bigint references public.players(id) on delete cascade;

update public.wildcard_requests
set player_id=(select managed_player_id from public.career_state where id='demo')
where player_id is null;

alter table public.wildcard_requests
  drop constraint if exists wildcard_requests_tournament_id_key;

drop index if exists public.wildcard_requests_tournament_id_key;

create unique index if not exists wildcard_requests_tournament_player_key
  on public.wildcard_requests(tournament_id,player_id);

create index if not exists wildcard_requests_player_idx
  on public.wildcard_requests(player_id);
