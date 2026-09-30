-- NCAA ranking provenance integrity.
-- Official ITA ranks remain distinct from Court Boss depth projections.
-- Legacy ita_rank / players.ncaa_rank stay populated for compatibility only.
-- UI/API authority: ita_rank_official + projected_rank + rank_source_kind.

alter table public.ncaa_player_registry
  drop constraint if exists ncaa_player_registry_rank_provenance_check;

alter table public.ncaa_player_registry
  add constraint ncaa_player_registry_rank_provenance_check
  check (
    (ita_rank_official is null or projected_rank is null)
    and (ita_rank_official is null or ita_rank_official > 0)
    and (projected_rank is null or projected_rank > 0)
  ) not valid;

CREATE OR REPLACE FUNCTION public.sync_ncaa_career_row()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  mapped_status text;
  is_all_american boolean;
  is_simulated boolean;
  rank_value integer;
begin
  is_all_american := new.status ilike '%All-American%';
  is_simulated := lower(coalesce(new.source_label,'')) like '%court boss%';
  rank_value := coalesce(new.ita_rank_official,new.projected_rank,new.ita_rank);
  mapped_status := case
    when new.status='Active' then 'Active'
    when new.status='Historical' then 'Alumni'
    else 'Recorded'
  end;

  insert into public.ncaa_career(
    player_id,school,division,start_season,end_season,status,departure_date,verified,
    source_url,source_label,all_american,last_verified_at
  )
  values(
    new.player_id,new.school,new.division,new.season,new.season,mapped_status,
    case when mapped_status='Alumni' then new.snapshot_date else null end,
    not is_simulated,new.source_url,new.source_label,is_all_american,now()
  )
  on conflict(player_id) do update set
    school=excluded.school,
    division=excluded.division,
    start_season=coalesce(public.ncaa_career.start_season,excluded.start_season),
    end_season=case
      when public.ncaa_career.end_season is null then excluded.end_season
      when excluded.end_season is null then public.ncaa_career.end_season
      else greatest(public.ncaa_career.end_season,excluded.end_season)
    end,
    status=case
      when excluded.status='Active' then 'Active'
      when excluded.status='Alumni' then 'Alumni'
      else public.ncaa_career.status
    end,
    departure_date=case
      when excluded.status='Alumni' then coalesce(public.ncaa_career.departure_date,excluded.departure_date)
      else public.ncaa_career.departure_date
    end,
    verified=public.ncaa_career.verified or excluded.verified,
    source_url=coalesce(excluded.source_url,public.ncaa_career.source_url),
    source_label=coalesce(excluded.source_label,public.ncaa_career.source_label),
    all_american=public.ncaa_career.all_american or excluded.all_american,
    last_verified_at=now();

  if mapped_status='Active' then
    update public.players
    set ncaa_current=true,
        ncaa_status='Active',
        ncaa_school=new.school,
        ncaa_team_id=public.resolve_ncaa_team_id(new.school),
        ncaa_last_school=new.school,
        ncaa_division=new.division,
        ncaa_rank=rank_value,
        ncaa_snapshot_date=new.snapshot_date,
        ncaa_source=new.source_label,
        ncaa_verified=not is_simulated
    where id=new.player_id;
  elsif mapped_status='Alumni' then
    update public.players
    set ncaa_current=false,
        ncaa_status='Alumni',
        ncaa_last_school=coalesce(new.school,ncaa_last_school),
        ncaa_school=null,
        ncaa_team_id=null,
        ncaa_rank=null,
        ncaa_verified=not is_simulated
    where id=new.player_id;
  elsif is_all_american then
    update public.players
    set ncaa_verified=true,
        ncaa_last_school=coalesce(ncaa_last_school,new.school)
    where id=new.player_id;
  end if;

  return new;
end
$function$;

CREATE OR REPLACE FUNCTION public.sync_ncaa_rank_provenance_fields()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
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

CREATE OR REPLACE FUNCTION public.sync_ncaa_registry_identity()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  active_row public.ncaa_player_registry%rowtype;
  has_active boolean:=false;
  first_season text;
  last_school text;
  last_division text;
  is_all_american boolean:=false;
  is_simulated boolean:=false;
  rank_value integer;
begin
  select *
    into active_row
  from public.ncaa_player_registry
  where player_id=new.player_id
    and status='Active'
  order by snapshot_date desc nulls last, season desc, id desc
  limit 1;

  has_active := found;
  is_all_american := coalesce(new.status,'') ilike '%All-American%';

  select season
    into first_season
  from public.ncaa_player_registry
  where player_id=new.player_id
  order by snapshot_date asc nulls last, id asc
  limit 1;

  if has_active then
    is_simulated := lower(coalesce(active_row.source_label,'')) like '%court boss%';
    rank_value := coalesce(active_row.ita_rank_official,active_row.projected_rank,active_row.ita_rank);

    insert into public.ncaa_career(
      player_id,school,division,start_season,end_season,status,verified,
      source_url,source_label,last_verified_at
    )
    values(
      new.player_id,
      active_row.school,
      active_row.division,
      coalesce(first_season,active_row.season),
      null,
      'Active',
      not is_simulated,
      active_row.source_url,
      coalesce(active_row.source_label,'NCAA / ITA registry'),
      now()
    )
    on conflict(player_id) do update set
      school=excluded.school,
      division=excluded.division,
      start_season=coalesce(public.ncaa_career.start_season,excluded.start_season),
      end_season=null,
      status='Active',
      departure_date=null,
      verified=public.ncaa_career.verified or excluded.verified,
      source_url=coalesce(excluded.source_url,public.ncaa_career.source_url),
      source_label=coalesce(excluded.source_label,public.ncaa_career.source_label),
      last_verified_at=now();

    update public.players
    set ncaa_current=true,
        ncaa_school=active_row.school,
        ncaa_team_id=public.resolve_ncaa_team_id(active_row.school),
        ncaa_division=active_row.division,
        ncaa_rank=rank_value,
        ncaa_snapshot_date=active_row.snapshot_date,
        ncaa_status='Active',
        ncaa_source=active_row.source_label,
        ncaa_last_school=coalesce(active_row.school,ncaa_last_school),
        ncaa_verified=not is_simulated
    where id=new.player_id;

    return new;
  end if;

  select school,division
    into last_school,last_division
  from public.ncaa_player_registry
  where player_id=new.player_id
  order by snapshot_date desc nulls last, season desc, id desc
  limit 1;

  if old is not null and old.status='Active' and new.status<>'Active' then
    is_simulated := lower(coalesce(new.source_label,'')) like '%court boss%';
    insert into public.ncaa_career(
      player_id,school,division,start_season,end_season,status,departure_date,
      verified,source_url,source_label,last_verified_at
    )
    values(
      new.player_id,
      coalesce(last_school,new.school),
      coalesce(last_division,new.division),
      coalesce(first_season,new.season),
      new.season,
      'Alumni',
      new.snapshot_date,
      not is_simulated,
      new.source_url,
      coalesce(new.source_label,'NCAA / ITA registry · departure'),
      now()
    )
    on conflict(player_id) do update set
      school=coalesce(excluded.school,public.ncaa_career.school),
      division=coalesce(excluded.division,public.ncaa_career.division),
      end_season=excluded.end_season,
      status='Alumni',
      departure_date=excluded.departure_date,
      verified=public.ncaa_career.verified or excluded.verified,
      source_url=coalesce(excluded.source_url,public.ncaa_career.source_url),
      source_label=coalesce(excluded.source_label,public.ncaa_career.source_label),
      last_verified_at=now();

    update public.players
    set ncaa_current=false,
        ncaa_school=null,
        ncaa_team_id=null,
        ncaa_division=null,
        ncaa_rank=null,
        ncaa_status='Alumni',
        ncaa_last_school=coalesce(last_school,new.school,ncaa_last_school),
        ncaa_verified=not is_simulated
    where id=new.player_id;

    return new;
  end if;

  is_simulated := lower(coalesce(new.source_label,'')) like '%court boss%';
  insert into public.ncaa_career(
    player_id,school,division,start_season,end_season,status,verified,
    source_url,source_label,last_verified_at
  )
  values(
    new.player_id,new.school,new.division,coalesce(first_season,new.season),new.season,
    'Recorded',not is_simulated,new.source_url,coalesce(new.source_label,'NCAA / ITA historical record'),now()
  )
  on conflict(player_id) do update set
    school=coalesce(public.ncaa_career.school,excluded.school),
    division=coalesce(public.ncaa_career.division,excluded.division),
    start_season=coalesce(public.ncaa_career.start_season,excluded.start_season),
    verified=public.ncaa_career.verified or excluded.verified,
    source_url=coalesce(public.ncaa_career.source_url,excluded.source_url),
    source_label=coalesce(public.ncaa_career.source_label,excluded.source_label),
    all_american=public.ncaa_career.all_american or is_all_american,
    last_verified_at=now();

  if is_all_american then
    update public.players
    set ncaa_verified=true,
        ncaa_last_school=coalesce(ncaa_last_school,new.school)
    where id=new.player_id;
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
set
  ita_rank_official = case
    when lower(coalesce(source_label,'')) like '%court boss%' then null
    when (
      (lower(coalesce(source_label,'')) like '%ita division i men%' and lower(coalesce(source_label,'')) like '%national singles rankings%')
      or (lower(coalesce(source_label,'')) like '%ita official%' and lower(coalesce(source_label,'')) like '%singles%')
      or lower(coalesce(source_url,'')) like '%colleges.wearecollegetennis.com/rankings%'
      or lower(coalesce(source_url,'')) like '%wearecollegetennis.com/%rankings%'
      or lower(coalesce(source_url,'')) like '%itatennis%'
    ) then coalesce(ita_rank_official,ita_rank)
    else ita_rank_official
  end,
  projected_rank = case
    when lower(coalesce(source_label,'')) like '%court boss%' then coalesce(projected_rank,ita_rank)
    when ita_rank_official is not null then null
    else projected_rank
  end,
  rank_source_kind = case
    when lower(coalesce(source_label,'')) like '%court boss%' then 'court_boss_projection'
    when ita_rank_official is not null and snapshot_date=date '2025-11-25' then 'official_ita'
    when ita_rank_official is not null then 'historical_official'
    else coalesce(rank_source_kind,'unknown')
  end;

with latest as (
  select distinct on (r.player_id)
    r.player_id,r.ita_rank_official,r.projected_rank,r.ita_rank,
    r.school,r.division,r.snapshot_date,r.source_label
  from public.ncaa_player_registry r
  where r.status='Active'
  order by r.player_id,r.snapshot_date desc,r.season desc,r.id desc
)
update public.players p
set ncaa_rank=coalesce(l.ita_rank_official,l.projected_rank,l.ita_rank),
    ncaa_school=l.school,
    ncaa_division=l.division,
    ncaa_snapshot_date=l.snapshot_date,
    ncaa_source=l.source_label,
    ncaa_verified=not (lower(coalesce(l.source_label,'')) like '%court boss%')
from latest l
where p.id=l.player_id;

update public.ncaa_career c
set verified=false,
    last_verified_at=now()
where exists (
  select 1
  from public.ncaa_player_registry r
  where r.player_id=c.player_id
    and r.status='Active'
    and r.rank_source_kind='court_boss_projection'
)
and not exists (
  select 1
  from public.ncaa_player_registry r
  where r.player_id=c.player_id
    and r.status='Active'
    and r.ita_rank_official is not null
);

alter table public.ncaa_player_registry
  validate constraint ncaa_player_registry_rank_provenance_check;

comment on column public.ncaa_player_registry.ita_rank_official is
  'Verified ITA singles rank only. Never populated by Court Boss simulated depth.';
comment on column public.ncaa_player_registry.projected_rank is
  'Court Boss gameplay depth rank. Display with ~ and never label as ITA official.';
comment on column public.ncaa_player_registry.rank_source_kind is
  'official_ita, historical_official, court_boss_projection, or unknown.';
