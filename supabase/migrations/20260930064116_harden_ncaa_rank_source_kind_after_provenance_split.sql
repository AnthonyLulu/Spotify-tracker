
create or replace function public.sync_ncaa_rank_provenance_fields()
returns trigger
language plpgsql
set search_path to 'public'
as $function$
declare
  v_source text := lower(coalesce(new.source_label,''));
  v_url text := lower(coalesce(new.source_url,''));
  v_is_projection boolean := v_source like '%court boss%';
  v_is_official boolean :=
    (
      (v_source like '%ita division i men%' and v_source like '%national singles rankings%')
      or (v_source like '%ita official%' and v_source like '%singles%')
      or v_url like '%colleges.wearecollegetennis.com/rankings%'
      or v_url like '%wearecollegetennis.com/%rankings%'
      or v_url like '%itatennis%'
    );
begin
  if v_is_projection then
    new.ita_rank_official := null;
    new.projected_rank := coalesce(new.projected_rank,new.ita_rank);
    new.rank_source_kind := 'court_boss_projection';
  elsif v_is_official then
    new.ita_rank_official := coalesce(new.ita_rank_official,new.ita_rank);
    new.projected_rank := null;
    new.rank_source_kind := case
      when new.snapshot_date = date '2025-11-25' then 'official_ita'
      else 'historical_official'
    end;
  elsif new.ita_rank_official is not null then
    new.projected_rank := null;
    new.rank_source_kind := case
      when new.snapshot_date = date '2025-11-25' then 'official_ita'
      else 'historical_official'
    end;
  elsif new.projected_rank is not null then
    new.ita_rank_official := null;
    new.rank_source_kind := case
      when v_is_projection then 'court_boss_projection'
      else coalesce(new.rank_source_kind,'unknown')
    end;
  else
    new.rank_source_kind := coalesce(new.rank_source_kind,'unknown');
  end if;
  return new;
end;
$function$;

drop trigger if exists trg_ncaa_rank_provenance_fields on public.ncaa_player_registry;
create trigger trg_ncaa_rank_provenance_fields
before insert or update of ita_rank,ita_rank_official,projected_rank,source_label,source_url,snapshot_date
on public.ncaa_player_registry
for each row execute function public.sync_ncaa_rank_provenance_fields();

update public.ncaa_player_registry
set rank_source_kind = case
  when ita_rank_official is not null and snapshot_date=date '2025-11-25' then 'official_ita'
  when ita_rank_official is not null then 'historical_official'
  when projected_rank is not null and lower(coalesce(source_label,'')) like '%court boss%' then 'court_boss_projection'
  else 'unknown'
end;

comment on column public.ncaa_player_registry.rank_source_kind is
  'official_ita, historical_official, court_boss_projection, or unknown.';
