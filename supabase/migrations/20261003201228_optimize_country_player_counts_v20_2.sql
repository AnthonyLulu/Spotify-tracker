
create index if not exists players_country_counts_v20_idx
on public.players(country)
include (ranking_current,ranking,itf_ranking,junior_ranking,birth_date,ncaa_current)
where country is not null
  and (data_source is null or data_source not ilike '%hidden duplicate merged into%');

create or replace view public.country_player_counts
with (security_invoker=false)
as
select
  country,
  count(*)::integer as players,
  count(*) filter(where ranking_current=true and ranking is not null)::integer as atp_ranked,
  count(*) filter(where itf_ranking is not null)::integer as itf_players,
  count(*) filter(
    where junior_ranking is not null
      and birth_date is not null
      and birth_date>=date '2007-01-01'
  )::integer as junior_players,
  count(*) filter(where ncaa_current=true)::integer as ncaa_players
from public.players
where country is not null
  and (data_source is null or data_source not ilike '%hidden duplicate merged into%')
group by country;
