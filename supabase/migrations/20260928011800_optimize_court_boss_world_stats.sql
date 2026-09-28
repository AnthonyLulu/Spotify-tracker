create index if not exists players_world_rank_searchable_idx
on public.players (game_world_rank)
where game_world_rank is not null
  and game_world_rank <= 30000
  and (data_source is null or data_source not ilike 'hidden duplicate merged into %');

create or replace function public.court_boss_world_stats()
returns jsonb
language sql
stable
set search_path=''
as $$
with p as (
  select
    count(*) filter (where data_source is null or data_source not ilike 'hidden duplicate merged into %')::bigint as players_total,
    count(*) filter (where ranking_current is true)::bigint as atp_ranked,
    count(*) filter (where itf_ranking is not null)::bigint as itf_players,
    count(*) filter (where junior_ranking is not null and junior_source is not null and age between 13 and 18)::bigint as junior_players,
    count(*) filter (where ncaa_current is true)::bigint as ncaa_players,
    count(*) filter (where game_generated is true)::bigint as game_generated,
    count(*) filter (where is_real is true)::bigint as real_players_total,
    count(*) filter (where is_real is true and (data_source is null or data_source not ilike 'hidden duplicate merged into %'))::bigint as searchable_real_players,
    count(*) filter (where is_real is true and age is not null and (data_source is null or data_source not ilike 'hidden duplicate merged into %'))::bigint as real_players_with_age,
    count(*) filter (where ranking_current is true and age is null)::bigint as current_ranked_missing_age,
    count(*) filter (where ranking_current is true and birth_date is null)::bigint as current_ranked_missing_dob,
    count(*) filter (where is_real is true and circuits_2025 is not null)::bigint as active_real_players_2025,
    count(*) filter (where doubles_source is not null)::bigint as sourced_doubles,
    count(*) filter (where doubles_ranking is not null and (data_source is null or data_source not ilike 'hidden duplicate merged into %'))::bigint as indexed_doubles,
    count(*) filter (where race_source is not null)::bigint as sourced_race,
    count(*) filter (where nextgen_source is not null)::bigint as sourced_next_gen,
    count(*) filter (where junior_source is not null and age between 13 and 18)::bigint as sourced_juniors,
    count(*) filter (where backhand is not null)::bigint as players_with_backhand,
    count(*) filter (where backhand_verified is true)::bigint as verified_backhands,
    count(*) filter (where is_real is true and birth_date is not null and (data_source is null or data_source not ilike 'hidden duplicate merged into %'))::bigint as real_players_with_dob,
    count(*) filter (where is_real is true and birth_date is null and age is not null and (data_source is null or data_source not ilike 'hidden duplicate merged into %'))::bigint as estimated_age_real,
    count(*) filter (where itf_ranking is not null and age is null)::bigint as itf_missing_age,
    count(*) filter (where junior_source is not null and age is null)::bigint as junior_missing_age,
    count(*) filter (where ncaa_current is true and age is null)::bigint as ncaa_missing_age
  from public.players
),
t as (
  select
    count(*) filter (where is_active is true)::bigint as tournaments,
    count(*) filter (where is_active is true and is_verified is true)::bigint as verified_tournaments,
    count(*) filter (where is_active is true and is_verified is true and circuit='ATP')::bigint as official_atp,
    count(*) filter (where is_active is true and is_verified is true and circuit='Challenger')::bigint as official_challenger,
    count(*) filter (where is_active is true and is_verified is true and circuit='ITF')::bigint as official_itf,
    count(*) filter (where is_active is true and is_verified is true and circuit='Federation')::bigint as official_federation,
    count(*) filter (where is_active is true and is_verified is true and circuit='Junior')::bigint as official_junior,
    count(*) filter (where is_active is true and is_verified is true and circuit='NCAA')::bigint as official_ncaa
  from public.tournaments
),
r as (
  select
    count(distinct player_id)::bigint as ncaa_profiles_total,
    count(distinct player_id) filter (where status='Active')::bigint as ncaa_active_profiles
  from public.ncaa_player_registry
),
c as (
  select count(*)::bigint as ncaa_teams from public.college_teams
)
select jsonb_build_object(
  'rankingReferenceDate','2025-12-01',
  'players',p.atp_ranked,
  'playersTotal',p.players_total,
  'realPlayersTotal',p.real_players_total,
  'searchableRealPlayers',p.searchable_real_players,
  'worldRankingCapacity',30000,
  'realPlayersWithAge',p.real_players_with_age,
  'activeRealPlayers2025',p.active_real_players_2025,
  'atpRanked',p.atp_ranked,
  'sourcedDoubles',p.sourced_doubles,
  'indexedDoubles',p.indexed_doubles,
  'sourcedRace',p.sourced_race,
  'sourcedNextGen',p.sourced_next_gen,
  'sourcedJuniors',p.sourced_juniors,
  'itfPlayers',p.itf_players,
  'juniorPlayers',p.junior_players,
  'ncaaTeams',c.ncaa_teams,
  'ncaaPlayers',p.ncaa_players,
  'ncaaProfilesTotal',r.ncaa_profiles_total,
  'ncaaActiveProfiles',r.ncaa_active_profiles,
  'gameGenerated',p.game_generated,
  'tournaments',t.tournaments,
  'verifiedTournaments',t.verified_tournaments,
  'officialATP',t.official_atp,
  'officialChallenger',t.official_challenger,
  'officialITF',t.official_itf,
  'officialFederation',t.official_federation,
  'officialJunior',t.official_junior,
  'officialNCAA',t.official_ncaa,
  'currentRankedMissingAge',p.current_ranked_missing_age,
  'currentRankedMissingDob',p.current_ranked_missing_dob,
  'playersWithBackhand',p.players_with_backhand,
  'verifiedBackhands',p.verified_backhands,
  'realPlayersWithDob',p.real_players_with_dob,
  'estimatedAgeReal',p.estimated_age_real,
  'itfMissingAge',p.itf_missing_age,
  'juniorMissingAge',p.junior_missing_age,
  'ncaaMissingAge',p.ncaa_missing_age
)
from p cross join t cross join r cross join c;

analyze public.players;
