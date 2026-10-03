
update public.players
set junior_ranking=junior_ranking+1
where career_status='active'
  and junior_ranking is not null
  and id<>2566
  and coalesce(data_source,'') not ilike 'hidden duplicate merged into %';

update public.players
set junior_ranking=1,
    junior_points=1000,
    junior_snapshot_date=date '2025-09-08',
    junior_source='ITF 2025 junior No.1 correction · Wimbledon + US Open champion · Court Boss normalized points estimate'
where id=2566
  and name='Ivan Ivanov'
  and country='BUL'
  and birth_date=date '2008-10-30';
