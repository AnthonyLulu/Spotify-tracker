-- NCAA university presentation/cache layer.
-- Applied in production as migration 20260930194506.

create table if not exists public.ncaa_university_profiles (
  school_key text primary key,
  display_name text not null,
  conference text,
  division text not null default 'NCAA Division I',
  city text,
  state text,
  country text not null default 'USA',
  description text,
  hero_image_url text,
  logo_url text,
  source_url text,
  primary_color text,
  secondary_color text,
  metadata_source text,
  metadata_fetched_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists ncaa_university_profiles_conference_idx
  on public.ncaa_university_profiles(conference);

insert into public.ncaa_university_profiles(
  school_key,display_name,conference,division,source_url,metadata_source
)
select
  public.ncaa_school_alias_key(r.school),
  min(r.school),
  min(r.conference),
  coalesce(min(r.division),'NCAA Division I'),
  min(r.source_url),
  'NCAA roster reference 2025-26'
from public.ncaa_roster_reference r
where r.season='2025-26'
  and nullif(trim(r.school),'') is not null
group by public.ncaa_school_alias_key(r.school)
on conflict(school_key) do update set
  display_name=excluded.display_name,
  conference=coalesce(public.ncaa_university_profiles.conference,excluded.conference),
  division=coalesce(public.ncaa_university_profiles.division,excluded.division),
  source_url=coalesce(public.ncaa_university_profiles.source_url,excluded.source_url),
  updated_at=now();

insert into public.ncaa_university_profiles(
  school_key,display_name,conference,division,metadata_source
)
select
  public.ncaa_school_alias_key(s.school),
  min(s.school),
  min(s.conference),
  'NCAA Division I',
  'ITA Division I Men''s National Singles Rankings · 2025-11-25'
from public.ita_ncaa_singles_staging s
where s.season='2025-26'
  and s.snapshot_date=date '2025-11-25'
  and nullif(trim(s.school),'') is not null
  and not exists (
    select 1 from public.ncaa_university_profiles p
    where p.school_key=public.ncaa_school_alias_key(s.school)
  )
group by public.ncaa_school_alias_key(s.school);
