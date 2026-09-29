create table if not exists public.historical_tournament_round_formats (
  event_key text primary key,
  season integer not null,
  tournament_id text not null,
  first_round_code integer not null check (first_round_code in (16,32,64,128)),
  updated_at timestamptz not null default now()
);

insert into public.historical_tournament_round_formats(event_key,season,tournament_id,first_round_code,updated_at)
select season::text||'|'||tournament_id,
       season,
       tournament_id,
       max(case result_code
             when 'R128' then 128
             when 'R64' then 64
             when 'R32' then 32
             when 'R16' then 16
             else 0
           end) as first_round_code,
       now()
from public.player_tournament_history
where coalesce(event_type,'singles')='singles'
  and result_code in ('R16','R32','R64','R128')
group by season,tournament_id
on conflict (event_key) do update
set first_round_code=excluded.first_round_code,
    updated_at=excluded.updated_at;

create index if not exists historical_tournament_round_formats_tid_idx
  on public.historical_tournament_round_formats(tournament_id);
