-- Court Boss Record Hub v4
-- Live migration version: 20261002221801

insert into public.record_catalog
(code,category,subcategory,name,description,record_type,unit,baseline_value,baseline_holder,baseline_country,baseline_year,rarity,dynamic_rule,source_label,source_url,as_of_date,display_order,metadata)
values
('grand_slam_titles_career','Grand Chelem','Carrière','Plus de Majeurs en carrière','Record de titres du Grand Chelem en simple messieurs à la date de référence.','numeric','titres',24,'Novak Djokovic','SRB',2023,'mythic','grand_slam_titles_career','ATP Media Guide 2025','https://www.atptour.com/-/media/files/media-guide/2025/2025-atp-media-guide-rankings-stats-results-final.pdf','2025-12-01',4,'{"scope":"career","discipline":"singles"}'::jsonb),
('big_titles_career','Exploits','Big Titles','Big Titles en carrière','Total des Majeurs, Masters 1000, ATP Finals et médailles d’or olympiques en simple. Référence au 01/12/2025 : Djokovic 72.','numeric','Big Titles',72,'Novak Djokovic','SRB',2024,'mythic','big_titles_career','ATP Big Titles definition + Court Boss verified titles','https://www.atptour.com/en/news/djokovic-nitto-atp-finals-2023-big-titles','2025-12-01',44,'{"components":["Grand Slams","Masters 1000","ATP Finals","Olympic singles gold"],"derived":true}'::jsonb),
('major_event_ao','Grand Chelem','Australian Open','Roi de l’Australian Open','Record de titres en simple messieurs à l’Australian Open.','numeric','titres',10,'Novak Djokovic','SRB',2023,'mythic','major_event_ao','ATP Media Guide 2025','https://www.atptour.com/-/media/files/media-guide/2025/2025-atp-media-guide-rankings-stats-results-final.pdf','2025-12-01',131,'{"event":"australian_open"}'::jsonb),
('major_event_rg','Grand Chelem','Roland Garros','Roi de Roland-Garros','Record de titres en simple messieurs à Roland-Garros.','numeric','titres',14,'Rafael Nadal','ESP',2022,'mythic','major_event_rg','ATP Media Guide 2025','https://www.atptour.com/-/media/files/media-guide/2025/2025-atp-media-guide-rankings-stats-results-final.pdf','2025-12-01',132,'{"event":"roland_garros"}'::jsonb),
('major_event_wimbledon','Grand Chelem','Wimbledon','Roi de Wimbledon','Record de titres en simple messieurs à Wimbledon dans l’Open Era.','numeric','titres',8,'Roger Federer','SUI',2017,'mythic','major_event_wimbledon','ATP Media Guide 2025','https://www.atptour.com/-/media/files/media-guide/2025/2025-atp-media-guide-rankings-stats-results-final.pdf','2025-12-01',133,'{"event":"wimbledon","scope":"Open Era"}'::jsonb),
('major_event_us_open_open_era','Grand Chelem','US Open','Rois de l’US Open · Open Era','Record de titres à l’US Open en simple messieurs dans l’Open Era.','numeric','titres',5,'Jimmy Connors / Pete Sampras / Roger Federer',null,2008,'legendary','major_event_us_open_open_era','ATP Media Guide 2025','https://www.atptour.com/-/media/files/media-guide/2025/2025-atp-media-guide-rankings-stats-results-final.pdf','2025-12-01',134,'{"event":"us_open","scope":"Open Era","ties":true}'::jsonb),
('atp_finals_titles_career','ATP Finals','Carrière','Record de titres ATP Finals','Plus grand nombre de titres remportés au tournoi de fin de saison en simple.','numeric','titres',7,'Novak Djokovic','SRB',2023,'mythic','atp_finals_titles_career','ATP Tour','https://www.atptour.com/en/news/federer-nitto-atp-finals-records','2025-12-01',145,'{"event":"atp_finals","scope":"career"}'::jsonb)
on conflict (code) do update set
 category=excluded.category,subcategory=excluded.subcategory,name=excluded.name,description=excluded.description,
 record_type=excluded.record_type,unit=excluded.unit,baseline_value=excluded.baseline_value,baseline_holder=excluded.baseline_holder,
 baseline_country=excluded.baseline_country,baseline_year=excluded.baseline_year,rarity=excluded.rarity,dynamic_rule=excluded.dynamic_rule,
 source_label=excluded.source_label,source_url=excluded.source_url,as_of_date=excluded.as_of_date,
 display_order=excluded.display_order,metadata=excluded.metadata,updated_at=now();


delete from public.record_occurrences
where record_code in ('grand_slam_titles_career','big_titles_career','major_event_ao','major_event_rg','major_event_wimbledon','major_event_us_open_open_era','atp_finals_titles_career');

with facts as (
  select distinct
    pt.player_id,p.name,p.country,
    extract(year from pt.title_date)::int season,
    public.cb_record_event_key(pt.tournament_name) event_key,
    case when (
      coalesce(pt.level,'') ilike '%ATP Finals%'
      or lower(coalesce(pt.tournament_name,'')) like '%tour finals%'
      or lower(coalesce(pt.tournament_name,'')) like '%atp finals%'
      or lower(coalesce(pt.tournament_name,'')) like '%masters cup%'
    ) then true else false end is_finals,
    case when (
      coalesce(pt.level,'') ilike '%1000%'
      and public.cb_record_event_key(pt.tournament_name) in ('indian_wells','miami','monte_carlo','madrid','rome','canada','cincinnati','shanghai','paris')
    ) then true else false end is_masters
  from public.player_titles pt
  join public.players p on p.id=pt.player_id
  where pt.event_type='singles' and pt.title_date<=date '2025-12-01'
    and coalesce(pt.verified,true)=true
    and coalesce(p.data_source,'') not ilike '%hidden duplicate%'
),
agg as (
  select player_id,max(name) name,max(country) country,
    count(distinct (season,event_key)) filter(where event_key in ('australian_open','roland_garros','wimbledon','us_open')) majors,
    count(distinct season) filter(where event_key='australian_open') ao,
    count(distinct season) filter(where event_key='roland_garros') rg,
    count(distinct season) filter(where event_key='wimbledon') wim,
    count(distinct season) filter(where event_key='us_open') uso,
    count(distinct season) filter(where is_finals) finals,
    count(distinct (season,event_key)) filter(where is_masters) masters,
    count(distinct season) filter(where event_key='olympics') olympics
  from facts group by player_id
),
scored as (
  select *, majors+masters+finals+olympics big_titles from agg
),
winners as (
  select 'grand_slam_titles_career' code,player_id,name,country,majors value from scored where majors=(select max(majors) from scored)
  union all select 'major_event_ao',player_id,name,country,ao from scored where ao=(select max(ao) from scored)
  union all select 'major_event_rg',player_id,name,country,rg from scored where rg=(select max(rg) from scored)
  union all select 'major_event_wimbledon',player_id,name,country,wim from scored where wim=(select max(wim) from scored)
  union all select 'major_event_us_open_open_era',player_id,name,country,uso from scored where uso=(select max(uso) from scored)
  union all select 'atp_finals_titles_career',player_id,name,country,finals from scored where finals=(select max(finals) from scored)
  union all select 'big_titles_career',player_id,name,country,big_titles from scored where big_titles=(select max(big_titles) from scored)
)
insert into public.record_occurrences(record_code,player_id,player_name,country,season,achieved_on,value,label,source_type,source_label,source_url,metadata)
select
  w.code,w.player_id,w.name,w.country,null,null,w.value,
  w.value::text||case when w.code='big_titles_career' then ' Big Titles' else ' titres' end,
  'historical',
  case when w.code='atp_finals_titles_career' then 'ATP Tour'
       when w.code='big_titles_career' then 'ATP Big Titles definition + Court Boss verified titles'
       else 'ATP Media Guide 2025' end,
  case when w.code='atp_finals_titles_career' then 'https://www.atptour.com/en/news/federer-nitto-atp-finals-records'
       when w.code='big_titles_career' then 'https://www.atptour.com/en/news/djokovic-nitto-atp-finals-2023-big-titles'
       else 'https://www.atptour.com/-/media/files/media-guide/2025/2025-atp-media-guide-rankings-stats-results-final.pdf' end,
  jsonb_build_object('derived_from','player_titles','cutoff','2025-12-01')
from winners w;

CREATE OR REPLACE FUNCTION public.court_boss_record_hub(p_player_id bigint DEFAULT NULL::bigint, p_date date DEFAULT '2025-12-01'::date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_pid bigint;
  v_name text;
  v_country text;
  v_masters_titles integer := 0;
  v_masters_season integer := 0;
  v_masters_unique integer := 0;
  v_double_golden_events integer := 0;
  v_slam_unique integer := 0;
  v_has_olympic boolean := false;
  v_sunshine boolean := false;
  v_clay boolean := false;
  v_summer boolean := false;
  v_fall boolean := false;
  v_calendar_slam boolean := false;
  v_calendar_golden boolean := false;
  v_career_grand boolean := false;
  v_channel boolean := false;
  v_north_america boolean := false;
  v_sunshine_count integer := 0;
  v_slam_titles integer := 0;
  v_ao_titles integer := 0;
  v_rg_titles integer := 0;
  v_wim_titles integer := 0;
  v_uso_titles integer := 0;
  v_finals_titles integer := 0;
  v_olympic_titles integer := 0;
  v_big_titles integer := 0;
  v_small_slam_best integer := 0;
  v_small_slam_done boolean := false;
  v_three_surface_best integer := 0;
  v_clay_slam_best integer := 0;
  v_spring_triple_best integer := 0;
  v_nole_slam_best integer := 0;
  v_career_aces bigint := 0;
  v_masters_match_aces integer := 0;
  v_masters_edition_aces integer := 0;
  v_progress jsonb := '[]'::jsonb;
  v_catalog jsonb;
  v_occurrences jsonb;
begin
  select coalesce(p_player_id,cs.managed_player_id)
    into v_pid
  from public.career_state cs
  where cs.id='demo';

  if v_pid is null then
    v_pid := p_player_id;
  end if;

  select p.name,p.country into v_name,v_country
  from public.players p where p.id=v_pid;

  if v_pid is not null then
    select count(*) into v_masters_titles
    from (
      select distinct extract(year from pt.title_date)::int as season, public.cb_record_event_key(pt.tournament_name) as event_key
      from public.player_titles pt
      where pt.player_id=v_pid and pt.event_type='singles' and pt.title_date<=p_date
        and coalesce(pt.level,'') ilike '%1000%'
    ) q;

    select coalesce(max(c),0) into v_masters_season
    from (
      select extract(year from pt.title_date)::int as season,
             count(distinct public.cb_record_event_key(pt.tournament_name)) as c
      from public.player_titles pt
      where pt.player_id=v_pid and pt.event_type='singles' and pt.title_date<=p_date
        and coalesce(pt.level,'') ilike '%1000%'
      group by extract(year from pt.title_date)::int
    ) q;

    select count(distinct public.cb_record_event_key(pt.tournament_name)) into v_masters_unique
    from public.player_titles pt
    where pt.player_id=v_pid and pt.event_type='singles' and pt.title_date<=p_date
      and public.cb_record_event_key(pt.tournament_name) in ('indian_wells','miami','monte_carlo','madrid','rome','canada','cincinnati','shanghai','paris');

    select count(*) into v_double_golden_events
    from (
      select public.cb_record_event_key(pt.tournament_name) event_key,
             count(distinct extract(year from pt.title_date)::int) c
      from public.player_titles pt
      where pt.player_id=v_pid and pt.event_type='singles' and pt.title_date<=p_date
        and public.cb_record_event_key(pt.tournament_name) in ('indian_wells','miami','monte_carlo','madrid','rome','canada','cincinnati','shanghai','paris')
      group by public.cb_record_event_key(pt.tournament_name)
      having count(distinct extract(year from pt.title_date)::int)>=2
    ) q;

    select count(distinct public.cb_record_event_key(pt.tournament_name)) into v_slam_unique
    from public.player_titles pt
    where pt.player_id=v_pid and pt.event_type='singles' and pt.title_date<=p_date
      and public.cb_record_event_key(pt.tournament_name) in ('australian_open','roland_garros','wimbledon','us_open');

    select exists(
      select 1 from public.player_titles pt
      where pt.player_id=v_pid and pt.event_type='singles' and pt.title_date<=p_date
        and public.cb_record_event_key(pt.tournament_name)='olympics'
    ) into v_has_olympic;

    select exists(
      select 1 from (
        select extract(year from pt.title_date)::int season,
               count(distinct public.cb_record_event_key(pt.tournament_name)) c
        from public.player_titles pt
        where pt.player_id=v_pid and pt.event_type='singles' and pt.title_date<=p_date
          and public.cb_record_event_key(pt.tournament_name) in ('indian_wells','miami')
        group by extract(year from pt.title_date)::int
      ) s where c=2
    ) into v_sunshine;

    select count(*) into v_sunshine_count
    from (
      select extract(year from pt.title_date)::int season
      from public.player_titles pt
      where pt.player_id=v_pid and pt.event_type='singles' and pt.title_date<=p_date
        and public.cb_record_event_key(pt.tournament_name) in ('indian_wells','miami')
      group by extract(year from pt.title_date)::int
      having count(distinct public.cb_record_event_key(pt.tournament_name))=2
    ) s;

    select exists(
      select 1 from (
        select extract(year from pt.title_date)::int season,
               count(distinct public.cb_record_event_key(pt.tournament_name)) c
        from public.player_titles pt
        where pt.player_id=v_pid and pt.event_type='singles' and pt.title_date<=p_date
          and public.cb_record_event_key(pt.tournament_name) in ('monte_carlo','madrid','rome')
        group by extract(year from pt.title_date)::int
      ) s where c=3
    ) into v_clay;

    select exists(
      select 1 from (
        select extract(year from pt.title_date)::int season,
               count(distinct public.cb_record_event_key(pt.tournament_name)) c
        from public.player_titles pt
        where pt.player_id=v_pid and pt.event_type='singles' and pt.title_date<=p_date
          and public.cb_record_event_key(pt.tournament_name) in ('canada','cincinnati')
        group by extract(year from pt.title_date)::int
      ) s where c=2
    ) into v_summer;

    select exists(
      select 1 from (
        select extract(year from pt.title_date)::int season,
               count(distinct public.cb_record_event_key(pt.tournament_name)) c
        from public.player_titles pt
        where pt.player_id=v_pid and pt.event_type='singles' and pt.title_date<=p_date
          and public.cb_record_event_key(pt.tournament_name) in ('shanghai','paris')
        group by extract(year from pt.title_date)::int
      ) s where c=2
    ) into v_fall;

    select exists(
      select 1 from (
        select extract(year from pt.title_date)::int season,
               count(distinct public.cb_record_event_key(pt.tournament_name)) c
        from public.player_titles pt
        where pt.player_id=v_pid and pt.event_type='singles' and pt.title_date<=p_date
          and public.cb_record_event_key(pt.tournament_name) in ('roland_garros','wimbledon')
        group by extract(year from pt.title_date)::int
      ) s where c=2
    ) into v_channel;

    select exists(
      select 1 from (
        select extract(year from pt.title_date)::int season,
               count(distinct public.cb_record_event_key(pt.tournament_name)) c
        from public.player_titles pt
        where pt.player_id=v_pid and pt.event_type='singles' and pt.title_date<=p_date
          and public.cb_record_event_key(pt.tournament_name) in ('canada','cincinnati','us_open')
        group by extract(year from pt.title_date)::int
      ) s where c=3
    ) into v_north_america;

    select exists(
      select 1 from (
        select extract(year from pt.title_date)::int season,
               count(distinct public.cb_record_event_key(pt.tournament_name)) c
        from public.player_titles pt
        where pt.player_id=v_pid and pt.event_type='singles' and pt.title_date<=p_date
          and public.cb_record_event_key(pt.tournament_name) in ('australian_open','roland_garros','wimbledon','us_open')
        group by extract(year from pt.title_date)::int
      ) s where c=4
    ) into v_calendar_slam;

    select exists(
      select 1 from (
        select extract(year from pt.title_date)::int season,
               count(distinct public.cb_record_event_key(pt.tournament_name)) c
        from public.player_titles pt
        where pt.player_id=v_pid and pt.event_type='singles' and pt.title_date<=p_date
          and public.cb_record_event_key(pt.tournament_name) in ('australian_open','roland_garros','wimbledon','us_open','olympics')
        group by extract(year from pt.title_date)::int
      ) s where c=5
    ) into v_calendar_golden;

    v_career_grand := (v_slam_unique=4);

    select coalesce(max(c),0) into v_small_slam_best
    from (
      select extract(year from pt.title_date)::int season,
             count(distinct public.cb_record_event_key(pt.tournament_name)) c
      from public.player_titles pt
      where pt.player_id=v_pid and pt.event_type='singles' and pt.title_date<=p_date
        and public.cb_record_event_key(pt.tournament_name) in ('australian_open','roland_garros','wimbledon','us_open')
      group by extract(year from pt.title_date)::int
    ) s;

    select exists(
      select 1
      from (
        select extract(year from pt.title_date)::int season,
               count(distinct public.cb_record_event_key(pt.tournament_name)) c
        from public.player_titles pt
        where pt.player_id=v_pid and pt.event_type='singles' and pt.title_date<=p_date
          and public.cb_record_event_key(pt.tournament_name) in ('australian_open','roland_garros','wimbledon','us_open')
        group by extract(year from pt.title_date)::int
      ) s
      where s.c=3
    ) into v_small_slam_done;

    select coalesce(max(c),0) into v_three_surface_best
    from (
      select extract(year from pt.title_date)::int season,
             count(distinct public.cb_record_event_key(pt.tournament_name)) c
      from public.player_titles pt
      where pt.player_id=v_pid and pt.event_type='singles' and pt.title_date<=p_date
        and public.cb_record_event_key(pt.tournament_name) in ('roland_garros','wimbledon','us_open')
      group by extract(year from pt.title_date)::int
    ) s;

    select coalesce(max(c),0) into v_clay_slam_best
    from (
      select extract(year from pt.title_date)::int season,
             count(distinct public.cb_record_event_key(pt.tournament_name)) c
      from public.player_titles pt
      where pt.player_id=v_pid and pt.event_type='singles' and pt.title_date<=p_date
        and public.cb_record_event_key(pt.tournament_name) in ('monte_carlo','madrid','rome','roland_garros')
      group by extract(year from pt.title_date)::int
    ) s;

    select coalesce(max(c),0) into v_spring_triple_best
    from (
      select extract(year from pt.title_date)::int season,
             count(distinct public.cb_record_event_key(pt.tournament_name)) c
      from public.player_titles pt
      where pt.player_id=v_pid and pt.event_type='singles' and pt.title_date<=p_date
        and public.cb_record_event_key(pt.tournament_name) in ('indian_wells','miami','monte_carlo')
      group by extract(year from pt.title_date)::int
    ) s;

    select coalesce(max(c),0) into v_nole_slam_best
    from (
      select a.title_date,
             count(distinct public.cb_record_event_key(b.tournament_name)) c
      from public.player_titles a
      join public.player_titles b
        on b.player_id=a.player_id
       and b.event_type='singles'
       and b.title_date between a.title_date and a.title_date+370
       and b.title_date<=p_date
       and public.cb_record_event_key(b.tournament_name) in ('australian_open','roland_garros','wimbledon','us_open')
      where a.player_id=v_pid and a.event_type='singles' and a.title_date<=p_date
        and public.cb_record_event_key(a.tournament_name) in ('australian_open','roland_garros','wimbledon','us_open')
      group by a.title_date
      having count(distinct public.cb_record_event_key(b.tournament_name))=4
         and extract(year from min(b.title_date))<>extract(year from max(b.title_date))
    ) s;

        select count(*) into v_slam_titles
    from (
      select distinct extract(year from pt.title_date)::int season,
             public.cb_record_event_key(pt.tournament_name) event_key
      from public.player_titles pt
      where pt.player_id=v_pid and pt.event_type='singles' and pt.title_date<=p_date
        and public.cb_record_event_key(pt.tournament_name) in ('australian_open','roland_garros','wimbledon','us_open')
    ) s;

    select count(*) into v_ao_titles from (
      select distinct extract(year from pt.title_date)::int season
      from public.player_titles pt
      where pt.player_id=v_pid and pt.event_type='singles' and pt.title_date<=p_date
        and public.cb_record_event_key(pt.tournament_name)='australian_open'
    ) s;

    select count(*) into v_rg_titles from (
      select distinct extract(year from pt.title_date)::int season
      from public.player_titles pt
      where pt.player_id=v_pid and pt.event_type='singles' and pt.title_date<=p_date
        and public.cb_record_event_key(pt.tournament_name)='roland_garros'
    ) s;

    select count(*) into v_wim_titles from (
      select distinct extract(year from pt.title_date)::int season
      from public.player_titles pt
      where pt.player_id=v_pid and pt.event_type='singles' and pt.title_date<=p_date
        and public.cb_record_event_key(pt.tournament_name)='wimbledon'
    ) s;

    select count(*) into v_uso_titles from (
      select distinct extract(year from pt.title_date)::int season
      from public.player_titles pt
      where pt.player_id=v_pid and pt.event_type='singles' and pt.title_date<=p_date
        and public.cb_record_event_key(pt.tournament_name)='us_open'
    ) s;

    select count(*) into v_finals_titles from (
      select distinct extract(year from pt.title_date)::int season
      from public.player_titles pt
      where pt.player_id=v_pid and pt.event_type='singles' and pt.title_date<=p_date
        and (
          coalesce(pt.level,'') ilike '%ATP Finals%'
          or lower(coalesce(pt.tournament_name,'')) like '%tour finals%'
          or lower(coalesce(pt.tournament_name,'')) like '%atp finals%'
          or lower(coalesce(pt.tournament_name,'')) like '%masters cup%'
        )
    ) s;

    select count(*) into v_olympic_titles from (
      select distinct extract(year from pt.title_date)::int season
      from public.player_titles pt
      where pt.player_id=v_pid and pt.event_type='singles' and pt.title_date<=p_date
        and public.cb_record_event_key(pt.tournament_name)='olympics'
    ) s;

    v_big_titles := v_slam_titles + v_masters_titles + v_finals_titles + v_olympic_titles;

    select coalesce(pcs.aces,0) into v_career_aces
    from public.player_career_stats pcs where pcs.player_id=v_pid;

    v_career_aces := coalesce(v_career_aces,0) + coalesce((
      select sum(coalesce((mh.match_data->>'aces')::numeric,0))::bigint
      from public.match_history mh
      where mh.user_involved=true
        and mh.match_date>date '2025-12-01' and mh.match_date<=p_date
        and (mh.player_a=v_name or mh.player_b=v_name)
        and mh.match_data ? 'aces'
    ),0);

    select coalesce(max((mh.match_data->>'aces')::numeric),0)::int into v_masters_match_aces
    from public.match_history mh
    where mh.user_involved=true and mh.match_date<=p_date
      and (mh.player_a=v_name or mh.player_b=v_name)
      and coalesce(mh.match_data->>'category','') ilike '%Masters 1000%'
      and mh.match_data ? 'aces';

    select coalesce(max(total_aces),0)::int into v_masters_edition_aces
    from (
      select extract(year from mh.match_date)::int season,mh.tournament_name,
             sum(coalesce((mh.match_data->>'aces')::numeric,0)) total_aces
      from public.match_history mh
      where mh.user_involved=true and mh.match_date<=p_date
        and (mh.player_a=v_name or mh.player_b=v_name)
        and coalesce(mh.match_data->>'category','') ilike '%Masters 1000%'
        and mh.match_data ? 'aces'
      group by extract(year from mh.match_date)::int,mh.tournament_name
    ) z;

    v_progress := jsonb_build_array(
      jsonb_build_object('code','grand_slam_titles_career','value',v_slam_titles,'target',24,'achieved',v_slam_titles>=24,'label',v_slam_titles||' Majeurs'),
      jsonb_build_object('code','big_titles_career','value',v_big_titles,'target',72,'achieved',v_big_titles>=72,'label',v_big_titles||' Big Titles'),
      jsonb_build_object('code','major_event_ao','value',v_ao_titles,'target',10,'achieved',v_ao_titles>=10,'label',v_ao_titles||' / 10 titres'),
      jsonb_build_object('code','major_event_rg','value',v_rg_titles,'target',14,'achieved',v_rg_titles>=14,'label',v_rg_titles||' / 14 titres'),
      jsonb_build_object('code','major_event_wimbledon','value',v_wim_titles,'target',8,'achieved',v_wim_titles>=8,'label',v_wim_titles||' / 8 titres'),
      jsonb_build_object('code','major_event_us_open_open_era','value',v_uso_titles,'target',5,'achieved',v_uso_titles>=5,'label',v_uso_titles||' / 5 titres'),
      jsonb_build_object('code','atp_finals_titles_career','value',v_finals_titles,'target',7,'achieved',v_finals_titles>=7,'label',v_finals_titles||' / 7 titres'),
      jsonb_build_object('code','masters_titles_career','value',v_masters_titles,'target',40,'achieved',v_masters_titles>=40,'label',v_masters_titles||' titres'),
      jsonb_build_object('code','masters_titles_season','value',v_masters_season,'target',6,'achieved',v_masters_season>=6,'label','meilleure saison: '||v_masters_season),
      jsonb_build_object('code','career_golden_masters','value',v_masters_unique,'target',9,'achieved',v_masters_unique=9,'label',v_masters_unique||'/9 Masters'),
      jsonb_build_object('code','double_career_golden_masters','value',v_double_golden_events,'target',9,'achieved',v_double_golden_events=9,'label',v_double_golden_events||'/9 gagnés au moins 2 fois'),
      jsonb_build_object('code','sunshine_double','value',case when v_sunshine then 2 else 0 end,'target',2,'achieved',v_sunshine,'label',case when v_sunshine then 'Réalisé' else 'À réaliser' end),
      jsonb_build_object('code','sunshine_double_career_record','value',v_sunshine_count,'target',4,'achieved',v_sunshine_count>=4,'label',v_sunshine_count||' Sunshine Double(s)'),
      jsonb_build_object('code','clay_masters_sweep','value',case when v_clay then 3 else 0 end,'target',3,'achieved',v_clay,'label',case when v_clay then 'Réalisé' else 'À réaliser' end),
      jsonb_build_object('code','summer_masters_sweep','value',case when v_summer then 2 else 0 end,'target',2,'achieved',v_summer,'label',case when v_summer then 'Réalisé' else 'À réaliser' end),
      jsonb_build_object('code','fall_masters_sweep','value',case when v_fall then 2 else 0 end,'target',2,'achieved',v_fall,'label',case when v_fall then 'Réalisé' else 'À réaliser' end),
      jsonb_build_object('code','career_grand_slam','value',v_slam_unique,'target',4,'achieved',v_career_grand,'label',v_slam_unique||'/4 Majeurs'),
      jsonb_build_object('code','career_golden_slam','value',v_slam_unique+(case when v_has_olympic then 1 else 0 end),'target',5,'achieved',v_slam_unique=4 and v_has_olympic,'label',v_slam_unique||'/4 Majeurs'||case when v_has_olympic then ' + or olympique' else '' end),
      jsonb_build_object('code','channel_slam','value',case when v_channel then 2 else 0 end,'target',2,'achieved',v_channel,'label',case when v_channel then 'Réalisé' else 'RG + Wimbledon à faire' end),
      jsonb_build_object('code','north_america_triple','value',case when v_north_america then 3 else 0 end,'target',3,'achieved',v_north_america,'label',case when v_north_america then 'Réalisé' else 'Canada + Cincinnati + US Open' end),
      jsonb_build_object('code','nole_slam','value',v_nole_slam_best,'target',4,'achieved',v_nole_slam_best>=4,'label',v_nole_slam_best||'/4 Majeurs sur 370 jours'),
      jsonb_build_object('code','small_slam','value',case when v_small_slam_done then 3 else least(v_small_slam_best,2) end,'target',3,'achieved',v_small_slam_done,'label',case when v_small_slam_done then '3/3 Majeurs sur la saison' else least(v_small_slam_best,2)||'/3 Majeurs sur la saison' end),
      jsonb_build_object('code','three_surface_majors','value',v_three_surface_best,'target',3,'achieved',v_three_surface_best>=3,'label',v_three_surface_best||'/3 · terre + gazon + dur'),
      jsonb_build_object('code','clay_slam','value',v_clay_slam_best,'target',4,'achieved',v_clay_slam_best>=4,'label',v_clay_slam_best||'/4 · MC + Madrid + Rome + RG'),
      jsonb_build_object('code','spring_masters_triple','value',v_spring_triple_best,'target',3,'achieved',v_spring_triple_best>=3,'label',v_spring_triple_best||'/3 · IW + Miami + Monte-Carlo'),
            jsonb_build_object('code','calendar_grand_slam_men','value',case when v_calendar_slam then 4 else 0 end,'target',4,'achieved',v_calendar_slam,'label',case when v_calendar_slam then 'Réalisé' else 'À réaliser' end),
      jsonb_build_object('code','calendar_golden_slam_men','value',case when v_calendar_golden then 5 else 0 end,'target',5,'achieved',v_calendar_golden,'label',case when v_calendar_golden then 'HISTORIQUE' else 'Jamais réalisé chez les hommes' end),
      jsonb_build_object('code','career_aces_reference','value',v_career_aces,'target',14411,'achieved',v_career_aces>=14411,'label',v_career_aces||' aces'),
      jsonb_build_object('code','masters_aces_edition_reference','value',v_masters_edition_aces,'target',98,'achieved',v_masters_edition_aces>=98,'label',v_masters_edition_aces||' / 98 aces'),
      jsonb_build_object('code','masters_aces_edition_save','value',v_masters_edition_aces,'target',null,'achieved',v_masters_edition_aces>0,'label',v_masters_edition_aces||' aces'),
      jsonb_build_object('code','masters_aces_match_save','value',v_masters_match_aces,'target',null,'achieved',v_masters_match_aces>0,'label',v_masters_match_aces||' aces')
    );

    v_progress := v_progress || coalesce((
      select jsonb_agg(jsonb_build_object(
        'code','masters_event_'||e.code,
        'value',coalesce(x.cnt,0),
        'target',e.target,
        'achieved',coalesce(x.cnt,0)>=e.target,
        'label',coalesce(x.cnt,0)||' / '||e.target||' titres'
      ) order by e.ord)
      from (values
        ('iw','indian_wells',5,1),('miami','miami',6,2),('monte_carlo','monte_carlo',11,3),
        ('madrid','madrid',5,4),('rome','rome',10,5),('canada','canada',6,6),
        ('cincinnati','cincinnati',7,7),('shanghai','shanghai',4,8),('paris','paris',7,9)
      ) as e(code,event_key,target,ord)
      left join lateral (
        select count(distinct extract(year from pt.title_date)::int)::int cnt
        from public.player_titles pt
        where pt.player_id=v_pid and pt.event_type='singles' and pt.title_date<=p_date
          and public.cb_record_event_key(pt.tournament_name)=e.event_key
      ) x on true
    ),'[]'::jsonb);
  end if;

  select coalesce(jsonb_agg(to_jsonb(c) order by c.display_order,c.code),'[]'::jsonb)
    into v_catalog from public.record_catalog c;

  select coalesce(jsonb_agg(to_jsonb(o) order by o.record_code,o.season,o.id),'[]'::jsonb)
    into v_occurrences from public.record_occurrences o;

  return jsonb_build_object(
    'as_of_date',date '2025-12-01',
    'catalog',v_catalog,
    'occurrences',v_occurrences,
    'managed',jsonb_build_object('player_id',v_pid,'name',v_name,'country',v_country,'progress',v_progress)
  );
end;
$function$;
revoke all on function public.court_boss_record_hub(bigint,date) from public;
grant execute on function public.court_boss_record_hub(bigint,date) to service_role;
