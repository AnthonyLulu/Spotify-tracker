-- Make NCAA rank provenance explicit and durable.
-- Legacy ita_rank remains for engines; UI/API must use ita_rank_official or projected_rank.

alter table public.ncaa_player_registry
  add column if not exists rank_source_kind text;

create or replace function public.sync_ncaa_rank_provenance_fields()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_source text := lower(coalesce(new.source_label,''));
  v_url text := lower(coalesce(new.source_url,''));
  v_is_projection boolean := v_source like '%court boss dynamic ncaa supply%';
  v_is_official boolean :=
    (
      (v_source like '%ita division i men%' and v_source like '%national singles rankings%')
      or (v_source like '%ita official%' and v_source like '%singles%')
      or v_url like '%colleges.wearecollegetennis.com/rankings%'
      or v_url like '%itatennis%'
    );
begin
  if v_is_projection then
    new.ita_rank_official := null;
    new.projected_rank := new.ita_rank;
    new.rank_source_kind := 'court_boss_projection';
  elsif v_is_official then
    new.ita_rank_official := new.ita_rank;
    new.projected_rank := null;
    new.rank_source_kind := case
      when new.snapshot_date = date '2025-11-25' then 'official_ita'
      else 'historical_official'
    end;
  else
    new.ita_rank_official := null;
    new.projected_rank := null;
    new.rank_source_kind := 'unknown';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_ncaa_rank_provenance_fields on public.ncaa_player_registry;
create trigger trg_ncaa_rank_provenance_fields
before insert or update of ita_rank,source_label,source_url,snapshot_date
on public.ncaa_player_registry
for each row execute function public.sync_ncaa_rank_provenance_fields();

update public.ncaa_player_registry
set
  ita_rank_official = case
    when lower(coalesce(source_label,'')) like '%court boss dynamic ncaa supply%' then null
    when (
      (lower(coalesce(source_label,'')) like '%ita division i men%' and lower(coalesce(source_label,'')) like '%national singles rankings%')
      or (lower(coalesce(source_label,'')) like '%ita official%' and lower(coalesce(source_label,'')) like '%singles%')
      or lower(coalesce(source_url,'')) like '%colleges.wearecollegetennis.com/rankings%'
      or lower(coalesce(source_url,'')) like '%itatennis%'
    ) then ita_rank
    else null
  end,
  projected_rank = case
    when lower(coalesce(source_label,'')) like '%court boss dynamic ncaa supply%' then ita_rank
    else null
  end,
  rank_source_kind = case
    when lower(coalesce(source_label,'')) like '%court boss dynamic ncaa supply%' then 'court_boss_projection'
    when (
      (lower(coalesce(source_label,'')) like '%ita division i men%' and lower(coalesce(source_label,'')) like '%national singles rankings%')
      or (lower(coalesce(source_label,'')) like '%ita official%' and lower(coalesce(source_label,'')) like '%singles%')
      or lower(coalesce(source_url,'')) like '%colleges.wearecollegetennis.com/rankings%'
      or lower(coalesce(source_url,'')) like '%itatennis%'
    ) then case when snapshot_date=date '2025-11-25' then 'official_ita' else 'historical_official' end
    else 'unknown'
  end
where ita_rank is not null
   or source_label is not null
   or source_url is not null;

comment on column public.ncaa_player_registry.rank_source_kind is
  'official_ita, historical_official, court_boss_projection, or unknown.';
