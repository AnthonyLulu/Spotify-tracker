-- Separate verified ITA ranks from Court Boss NCAA depth without breaking legacy engines.
-- Legacy ita_rank stays populated for compatibility; the two provenance fields are authoritative for UI/API.

alter table public.ncaa_player_registry
  add column if not exists ita_rank_official integer,
  add column if not exists projected_rank integer;

create or replace function public.sync_ncaa_rank_provenance_fields()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_source text := lower(coalesce(new.source_label,''));
begin
  if v_source like '%court boss dynamic ncaa supply%' then
    new.ita_rank_official := null;
    new.projected_rank := new.ita_rank;
  elsif (
    (v_source like '%ita division i men%' and v_source like '%national singles rankings%')
    or (v_source like '%ita official%' and v_source like '%singles%')
  ) then
    new.ita_rank_official := new.ita_rank;
    new.projected_rank := null;
  else
    new.ita_rank_official := null;
    new.projected_rank := null;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_ncaa_rank_provenance_fields on public.ncaa_player_registry;
create trigger trg_ncaa_rank_provenance_fields
before insert or update of ita_rank,source_label
on public.ncaa_player_registry
for each row execute function public.sync_ncaa_rank_provenance_fields();

update public.ncaa_player_registry
set ita_rank_official = case
      when (
        (lower(coalesce(source_label,'')) like '%ita division i men%'
          and lower(coalesce(source_label,'')) like '%national singles rankings%')
        or (lower(coalesce(source_label,'')) like '%ita official%'
          and lower(coalesce(source_label,'')) like '%singles%')
      ) then ita_rank
      else null
    end,
    projected_rank = case
      when lower(coalesce(source_label,'')) like '%court boss dynamic ncaa supply%'
        then ita_rank
      else null
    end;

create index if not exists idx_ncaa_registry_official_rank
  on public.ncaa_player_registry(season,ita_rank_official)
  where ita_rank_official is not null;

create index if not exists idx_ncaa_registry_projected_rank
  on public.ncaa_player_registry(season,projected_rank)
  where projected_rank is not null;
