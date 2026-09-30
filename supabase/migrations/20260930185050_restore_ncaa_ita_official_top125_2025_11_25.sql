-- Restore the complete official ITA Division I men's singles Top 125
-- snapshot of 2025-11-25 from the archived ITA staging table.
-- Court Boss projected depth is preserved and shifted to begin at ~126.

with aliases(school_name,team_name) as (
  values
    ('Columbia','Columbia Lions'),('SMU','SMU Mustangs'),('Michigan State','Michigan State Spartans'),
    ('University Of Arizona','Arizona Wildcats'),('Ohio State','Ohio State Buckeyes'),('TCU','TCU Horned Frogs'),
    ('University of Michigan','Michigan Wolverines'),('Baylor University','Baylor Bears'),('NC State','NC State Wolfpack'),
    ('University of Illinois at Urbana-Champaign','Illinois Fighting Illini'),('Princeton','Princeton Tigers'),
    ('Wake Forest','Wake Forest Demon Deacons'),('Mississippi State','Mississippi State Bulldogs'),
    ('University of Virginia','Virginia Cavaliers'),('University Of Arkansas, Fayetteville','Arkansas Razorbacks'),
    ('University of Kentucky','Kentucky Wildcats'),('UCLA','UCLA Bruins'),('Clemson','Clemson Tigers'),
    ('University Of Georgia','Georgia Bulldogs'),('University of Notre Dame','Notre Dame Fighting Irish'),
    ('University of Texas at Austin','Texas Longhorns'),('University Of Alabama','Alabama Crimson Tide'),
    ('South Florida','South Florida Bulls'),('Miami (Florida)','Miami Hurricanes'),('University Of Florida','Florida Gators'),
    ('UC Santa Barbara','UC Santa Barbara Gauchos'),('Auburn','Auburn Tigers'),('Yale','Yale Bulldogs'),
    ('University of Oklahoma','Oklahoma Sooners'),('Florida State','Florida State Seminoles'),
    ('University of South Carolina, Columbia','South Carolina Gamecocks'),('UNC Chapel Hill','North Carolina Tar Heels'),
    ('University Of Central Florida','UCF Knights'),('University Of Wisconsin, Madison','Wisconsin Badgers'),
    ('Pepperdine','Pepperdine Waves'),('Vanderbilt','Vanderbilt Commodores'),('Stanford','Stanford Cardinal'),
    ('Louisville','Louisville Cardinals'),('Harvard','Harvard Crimson'),('Georgia Tech','Georgia Tech Yellow Jackets'),
    ('Texas A&M University','Texas A&M Aggies'),('Rice','Rice Owls'),('University of Washington','Washington Huskies'),
    ('Oklahoma State University','Oklahoma State Cowboys'),('Memphis','Memphis Tigers'),('Indiana University','Indiana Hoosiers'),
    ('University Of Tennessee, Knoxville','Tennessee Volunteers')
)
insert into public.ncaa_school_team_aliases(school_name,team_id,source_label,match_priority,is_active)
select a.school_name,ct.id,'ITA 2025-11-25 official singles school alias',100,true
from aliases a
join public.college_teams ct on ct.name=a.team_name
where not exists (
  select 1 from public.ncaa_school_team_aliases x
  where public.ncaa_school_alias_key(x.school_name)=public.ncaa_school_alias_key(a.school_name)
);

with missing(name,name_norm,slug,country,age,current_ability,potential,birth_date,handedness,source_player_id,data_source,age_source,birth_date_source,handedness_source) as (
  values
    ('Julian Alonso Vivanco','julian alonso vivanco','julian-alonso-vivanco-ita-2025','ESP',20,44,54,date '2005-02-19','Droitier',
      'ITA:cfa3ea59-7d4e-43d8-8f1e-f5ed4f589bc5','ITA D1 official singles 2025-11-25 · TCU / Tennis.com',
      'Tennis.com · reference 2025-12-01','Tennis.com','Tennis.com'),
    ('Nicolas Kotzen','nicolas kotzen','nicolas-kotzen-ita-2025','USA',22,43,52,null,'Droitier',
      'ITA:3f325235-e595-4a9e-9bed-900fe5b00eb0','ITA D1 official singles 2025-11-25 · Columbia / ITF',
      'ITF player profile · reference 2025-12-01',null,'ITF'),
    ('Sachin Palta','sachin palta','sachin-palta-ita-2025','USA',21,42,52,null,'Droitier',
      'ITA:312a9060-bab1-4d4b-bc08-3e70802fcee0','ITA D1 official singles 2025-11-25 · Columbia / ITF',
      'ITF player profile · reference 2025-12-01',null,'TennisExplorer'),
    ('Top Nidunjianzan','top nidunjianzan','top-nidunjianzan-ita-2025','USA',21,42,50,null,'Droitier',
      'ITA:6274395f-c63b-4189-8596-a6cdf10f3b22','ITA D1 official singles 2025-11-25 · Princeton',
      'Princeton Athletics · reference 2025-12-01',null,'TennisExplorer'),
    ('Kaua Lopes Cressoni','kaua lopes cressoni','kaua-lopes-cressoni-ita-2025','BRA',19,40,53,null,null,
      'ITA:9baadca5-dc8d-4cee-8963-505d36fc8f45','ITA D1 official singles 2025-11-25 · Gardner-Webb / ITF',
      'ITF player profile · reference 2025-12-01',null,null)
)
insert into public.players(
  slug,name,name_norm,country,is_real,game_generated,career_status,
  age,age_snapshot_date,current_ability,potential,
  birth_date,birth_date_verified,handedness,handedness_verified,
  source_player_id,data_source,age_source,birth_date_source,handedness_source
)
select
  m.slug,m.name,m.name_norm,m.country,true,false,'active',
  m.age,date '2025-12-01',m.current_ability,m.potential,
  m.birth_date,(m.birth_date is not null),m.handedness,(m.handedness is not null),
  m.source_player_id,m.data_source,m.age_source,m.birth_date_source,m.handedness_source
from missing m
where not exists (
  select 1 from public.players p
  where p.name_norm=m.name_norm
    and coalesce(p.game_generated,false)=false
    and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
);

with s as (
  select *,trim(regexp_replace(lower(extensions.unaccent(player_name)),'[^a-z0-9]+',' ','g')) nn
  from public.ita_ncaa_singles_staging
  where season='2025-26' and snapshot_date=date '2025-11-25'
),
top20 as (
  select s.ita_player_id,r.player_id,'existing_official'::text resolution_method,100 resolution_confidence
  from s join public.ncaa_player_registry r
    on r.season=s.season and r.snapshot_date=s.snapshot_date and r.ita_rank_official=s.ita_rank
  where s.ita_rank<=20
),
rr0 as (
  select *,trim(regexp_replace(lower(extensions.unaccent(full_name)),'[^a-z0-9]+',' ','g')) nn
  from public.ncaa_roster_reference
  where season='2025-26' and player_id is not null
),
rr_candidates as (
  select s.ita_player_id,rr.player_id,count(*) over(partition by s.ita_player_id) n
  from s join rr0 rr on rr.nn=s.nn
  where s.ita_rank>20
),
roster_unique as (
  select ita_player_id,player_id,'roster_exact_unique'::text resolution_method,98 resolution_confidence
  from rr_candidates where n=1
),
remaining as (
  select s.* from s
  left join top20 t using(ita_player_id)
  left join roster_unique r using(ita_player_id)
  where t.player_id is null and r.player_id is null
),
player_candidates as (
  select r.ita_player_id,p.id player_id,count(*) over(partition by r.ita_player_id) n
  from remaining r
  join public.players p on p.name_norm=r.nn
  where coalesce(p.game_generated,false)=false
    and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
),
player_unique as (
  select ita_player_id,player_id,'player_exact_unique'::text resolution_method,95 resolution_confidence
  from player_candidates where n=1
),
resolved as (
  select * from top20 union all select * from roster_unique union all select * from player_unique
)
insert into public.ita_ncaa_singles_player_map(
  season,snapshot_date,ita_player_id,player_id,resolution_method,resolution_confidence
)
select '2025-26',date '2025-11-25',ita_player_id,player_id,resolution_method,resolution_confidence
from resolved
on conflict(season,snapshot_date,ita_player_id) do update set
  player_id=excluded.player_id,
  resolution_method=excluded.resolution_method,
  resolution_confidence=excluded.resolution_confidence;

do $$
declare v_staging integer; v_mapped integer; v_players integer;
begin
  select count(*) into v_staging from public.ita_ncaa_singles_staging
   where season='2025-26' and snapshot_date=date '2025-11-25';
  select count(*),count(distinct player_id) into v_mapped,v_players
  from public.ita_ncaa_singles_player_map
  where season='2025-26' and snapshot_date=date '2025-11-25';
  if v_staging<>125 or v_mapped<>125 or v_players<>125 then
    raise exception 'ITA Top 125 resolution failed: staging %, mapped %, distinct players %',v_staging,v_mapped,v_players;
  end if;
end $$;

update public.ncaa_player_registry
set ita_rank=ita_rank+105,
    projected_rank=projected_rank+105,
    source_label='Court Boss dynamic NCAA supply v2 · after official ITA Top 125'
where season='2025-26'
  and rank_source_kind='court_boss_projection'
  and lower(coalesce(source_label,'')) like '%court boss dynamic ncaa supply v1%';

insert into public.ncaa_player_registry(
  player_id,ita_rank,school,division,season,status,snapshot_date,source_url,source_label
)
select
  m.player_id,s.ita_rank,coalesce(ct.name,s.school),'NCAA DI',s.season,'Active',s.snapshot_date,
  'https://colleges.wearecollegetennis.com/rankings?date=2025-11-25&divisionType=DIV1&gender=M&matchFormat=SINGLES&season=2025-26&type=national',
  'ITA Division I Men''s National Singles Rankings · 2025-11-25'
from public.ita_ncaa_singles_staging s
join public.ita_ncaa_singles_player_map m
  on m.season=s.season and m.snapshot_date=s.snapshot_date and m.ita_player_id=s.ita_player_id
left join public.college_teams ct on ct.id=public.resolve_ncaa_team_id(s.school)
where s.season='2025-26' and s.snapshot_date=date '2025-11-25'
on conflict(player_id,season) do update set
  ita_rank=excluded.ita_rank,
  school=excluded.school,
  division=excluded.division,
  status=excluded.status,
  snapshot_date=excluded.snapshot_date,
  source_url=excluded.source_url,
  source_label=excluded.source_label;

do $$
declare v_official integer; v_bad integer; v_min integer; v_gen integer;
begin
  select count(*) into v_official from public.ncaa_player_registry
   where season='2025-26' and snapshot_date=date '2025-11-25' and ita_rank_official is not null;
  select count(*) into v_bad from public.ncaa_player_registry
   where season='2025-26' and projected_rank between 1 and 125;
  select min(projected_rank) into v_min from public.ncaa_player_registry
   where season='2025-26' and rank_source_kind='court_boss_projection';
  select count(*) into v_gen from public.ncaa_player_registry r join public.players p on p.id=r.player_id
   where r.season='2025-26' and r.snapshot_date=date '2025-11-25'
     and r.ita_rank_official is not null and coalesce(p.game_generated,false);
  if v_official<>125 then raise exception 'Expected 125 official ITA players, got %',v_official; end if;
  if v_bad<>0 then raise exception 'Projection collision inside official Top 125: %',v_bad; end if;
  if v_min<>126 then raise exception 'Expected projection depth to begin at 126, got %',v_min; end if;
  if v_gen<>0 then raise exception 'Generated players incorrectly marked official: %',v_gen; end if;
end $$;
