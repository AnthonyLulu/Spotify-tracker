-- Official ITA Division I men's national singles ranking, Nov. 25, 2025.
-- Court Boss cutoff: 2025-12-01.
-- Ranks 21+ may remain simulated depth, but must never be labelled ITA-official.

with official(ita_rank,player_name,school,team_name) as (
  values
    (1,'Michael Zheng','Columbia Lions','Columbia Lions'),
    (2,'Trevor Svajda','SMU Mustangs','SMU Mustangs'),
    (3,'Matthew Forbes','Michigan State Spartans','Michigan State Spartans'),
    (4,'Jay Friend','Arizona Wildcats','Arizona Wildcats'),
    (5,'Aidan Kim','Ohio State Buckeyes','Ohio State Buckeyes'),
    (6,'Duncan Chan','TCU Horned Frogs','TCU Horned Frogs'),
    (7,'Max Dahlin','Michigan Wolverines','Michigan Wolverines'),
    (8,'Devin Badenhorst','Baylor Bears','Baylor Bears'),
    (9,'Martin Borisiouk','NC State Wolfpack','NC State Wolfpack'),
    (10,'Kenta Miyoshi','Illinois Fighting Illini','Illinois Fighting Illini'),
    (11,'Paul Inchauspe','Princeton Tigers','Princeton Tigers'),
    (12,'DK Suresh','Wake Forest Demon Deacons','Wake Forest Demon Deacons'),
    (13,'Petar Jovanovic','Mississippi State Bulldogs','Mississippi State Bulldogs'),
    (14,'Ozan Baris','Michigan State Spartans','Michigan State Spartans'),
    (15,'Luca Pow','Wake Forest Demon Deacons','Wake Forest Demon Deacons'),
    (16,'Dylan Dietrich','Virginia Cavaliers','Virginia Cavaliers'),
    (17,'Connor Henry Van Schalkwyk','Baylor Bears','Baylor Bears'),
    (18,'Jakub Vrba','Arkansas Razorbacks','Arkansas Razorbacks'),
    (19,'Eli Stephenson','Kentucky Wildcats','Kentucky Wildcats'),
    (20,'Emon Van Loben Sels','UCLA Bruins','UCLA Bruins')
),
resolved as (
  select o.*,p.id player_id,ct.id team_id
  from official o
  cross join lateral (
    select p.id
    from public.players p
    where lower(p.name)=lower(o.player_name)
      and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
    order by p.ncaa_current desc,p.ncaa_verified desc,p.id
    limit 1
  ) p
  left join public.college_teams ct on ct.name=o.team_name
),
upsert_registry as (
  insert into public.ncaa_player_registry(
    player_id,ita_rank,school,division,season,status,snapshot_date,source_url,source_label
  )
  select
    player_id,ita_rank,school,'NCAA DI','2025-26','Active',date '2025-11-25',
    'https://colleges.wearecollegetennis.com/rankings?date=2025-11-25&divisionType=DIV1&gender=M&matchFormat=SINGLES&season=2025-26&type=national',
    'ITA Division I Men''s National Singles Rankings · Nov 25 2025'
  from resolved
  on conflict(player_id,season) do update set
    ita_rank=excluded.ita_rank,
    school=excluded.school,
    division=excluded.division,
    status=excluded.status,
    snapshot_date=excluded.snapshot_date,
    source_url=excluded.source_url,
    source_label=excluded.source_label
  returning player_id
)
update public.players p
set ncaa_rank=r.ita_rank,
    ncaa_school=r.school,
    ncaa_team_id=r.team_id,
    ncaa_division='NCAA Division I',
    ncaa_status='Active',
    ncaa_last_school=r.school,
    ncaa_current=true,
    ncaa_verified=true,
    ncaa_snapshot_date=date '2025-11-25'
from resolved r
where p.id=r.player_id;
