-- Court Boss Record Hub v3
-- Live migration version: 20261002220959
-- Correct Career Grand Slam completion to the date the fourth distinct Major was first won.

delete from public.record_occurrences where record_code='career_grand_slam';

with first_major as (
  select
    pt.player_id,
    p.name as player_name,
    p.country,
    public.cb_record_event_key(pt.tournament_name) as event_key,
    min(pt.title_date) as first_title_date
  from public.player_titles pt
  join public.players p on p.id=pt.player_id
  where pt.event_type='singles'
    and pt.title_date<=date '2025-12-01'
    and coalesce(pt.verified,true)=true
    and coalesce(p.data_source,'') not ilike '%hidden duplicate%'
    and public.cb_record_event_key(pt.tournament_name) in ('australian_open','roland_garros','wimbledon','us_open')
  group by pt.player_id,p.name,p.country,public.cb_record_event_key(pt.tournament_name)
),
completed as (
  select player_id,max(player_name) player_name,max(country) country,max(first_title_date) achieved_on
  from first_major
  group by player_id
  having count(distinct event_key)=4
)
insert into public.record_occurrences(
  record_code,player_id,player_name,country,season,achieved_on,value,label,source_type,source_label,source_url,metadata
)
select
  'career_grand_slam',player_id,player_name,country,
  extract(year from achieved_on)::int,achieved_on,4,'4/4 Majeurs',
  'historical','ATP Tour','https://www.atptour.com/en/news/grand-slams-tournaments-records-stats',
  jsonb_build_object('derived_from','first_title_per_major')
from completed;
