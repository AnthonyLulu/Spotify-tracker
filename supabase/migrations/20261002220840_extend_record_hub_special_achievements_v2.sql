-- Court Boss Record Hub v2
-- Live migration version: 20261002220840
-- Extends the canonical record_catalog / record_occurrences model. Historical baseline stays frozen at 2025-12-01.

insert into public.record_catalog
(code,category,subcategory,name,description,record_type,unit,baseline_value,baseline_holder,baseline_country,baseline_year,rarity,dynamic_rule,source_label,source_url,as_of_date,display_order,metadata)
values
('sunshine_double_career_record','Masters 1000','Carrière','Record de Sunshine Doubles','Plus grand nombre de doublés Indian Wells + Miami réussis au cours d’une carrière.','numeric','doublés',4,'Novak Djokovic','SRB',2016,'mythic','sunshine_double_career_record','ATP Tour','https://www.atptour.com/en/news/djokovic-miami-2025-title-record-feature','2025-12-01',75,'{"events":["indian_wells","miami"],"scope":"career"}'::jsonb),
('career_grand_slam','Grand Chelem','Carrière','Career Grand Slam','Remporter chacun des quatre Majeurs au moins une fois en carrière.','achievement','Majeurs',4,'Multiple',null,null,'legendary','career_grand_slam','ATP Tour','https://www.atptour.com/en/news/grand-slams-tournaments-records-stats','2025-12-01',105,'{"events":["australian_open","roland_garros","wimbledon","us_open"],"target":4}'::jsonb),
('channel_slam','Grand Chelem','Enchaînement','Channel Slam','Gagner Roland-Garros puis Wimbledon au cours de la même saison.','achievement','titres',2,'Multiple',null,null,'legendary','channel_slam','ATP Tour','https://www.atptour.com/en/news/alcaraz-borg-wimbledon-2025-history','2025-12-01',115,'{"events":["roland_garros","wimbledon"],"target":2}'::jsonb),
('north_america_triple','Exploits','Enchaînement','North America Triple','Gagner Canada, Cincinnati et l’US Open au cours de la même saison.','achievement','titres',3,'Rafter / Roddick / Nadal',null,2013,'mythic','north_america_triple','ATP Tour','https://www.atptour.com/en/news/canada-cincinnati-masters-1000-double-august-2024','2025-12-01',125,'{"events":["canada","cincinnati","us_open"],"target":3}'::jsonb),
('masters_aces_edition_reference','Service','Masters 1000','Aces sur une édition Masters · benchmark','Marque documentée : John Isner a frappé 98 aces avant la finale du Miami Open 2019. Court Boss l’utilise comme benchmark sourcé, sans prétendre que c’est le record absolu de toute l’histoire des Masters.','numeric','aces',98,'John Isner','USA',2019,'legendary','masters_aces_edition_reference','Miami Open','https://www.miamiopen.com/latest-news/federer-vs-isner-preview-defending-champ-tries-to-fend-off-the-greatest','2025-12-01',155,'{"event":"Miami Open","historical_absolute_claim":false,"scope":"edition"}'::jsonb)
on conflict (code) do update set
 category=excluded.category,subcategory=excluded.subcategory,name=excluded.name,description=excluded.description,
 record_type=excluded.record_type,unit=excluded.unit,baseline_value=excluded.baseline_value,baseline_holder=excluded.baseline_holder,
 baseline_country=excluded.baseline_country,baseline_year=excluded.baseline_year,rarity=excluded.rarity,dynamic_rule=excluded.dynamic_rule,
 source_label=excluded.source_label,source_url=excluded.source_url,as_of_date=excluded.as_of_date,
 display_order=excluded.display_order,metadata=excluded.metadata,updated_at=now();

with facts as (
  select distinct pt.player_id,p.name,p.country,pt.title_date,extract(year from pt.title_date)::int season,
         public.cb_record_event_key(pt.tournament_name) event_key
  from public.player_titles pt join public.players p on p.id=pt.player_id
  where pt.event_type='singles' and pt.title_date<=date '2025-12-01'
    and coalesce(pt.verified,true)=true and coalesce(p.data_source,'') not ilike '%hidden duplicate%'
),
career_grand as (
  select player_id,max(name) player_name,max(country) country,max(title_date) achieved_on
  from facts where event_key in ('australian_open','roland_garros','wimbledon','us_open')
  group by player_id having count(distinct event_key)=4
),
channel as (
  select player_id,max(name) player_name,max(country) country,season,max(title_date) achieved_on
  from facts where event_key in ('roland_garros','wimbledon')
  group by player_id,season having count(distinct event_key)=2
),
na3 as (
  select player_id,max(name) player_name,max(country) country,season,max(title_date) achieved_on
  from facts where event_key in ('canada','cincinnati','us_open')
  group by player_id,season having count(distinct event_key)=3
)
insert into public.record_occurrences(record_code,player_id,player_name,country,season,achieved_on,value,label,source_type,source_label,source_url,metadata)
select 'career_grand_slam',player_id,player_name,country,extract(year from achieved_on)::int,achieved_on,4,'4/4 Majeurs','historical','Court Boss title history','',jsonb_build_object('derived_from','player_titles') from career_grand
union all
select 'channel_slam',player_id,player_name,country,season,achieved_on,2,'Roland-Garros + Wimbledon','historical','ATP Tour','https://www.atptour.com/en/news/alcaraz-borg-wimbledon-2025-history',jsonb_build_object('derived_from','player_titles') from channel
union all
select 'north_america_triple',player_id,player_name,country,season,achieved_on,3,'Canada + Cincinnati + US Open','historical','ATP Tour','https://www.atptour.com/en/news/canada-cincinnati-masters-1000-double-august-2024',jsonb_build_object('derived_from','player_titles') from na3
on conflict (record_code,lower(player_name),coalesce(season,-1),coalesce(label,'')) do nothing;

insert into public.record_occurrences(record_code,player_id,player_name,country,season,achieved_on,value,label,source_type,source_label,source_url,metadata)
select 'sunshine_double_career_record',ro.player_id,ro.player_name,ro.country,max(ro.season),max(ro.achieved_on),count(*)::numeric,count(*)::text||' Sunshine Doubles','historical','ATP Tour','https://www.atptour.com/en/news/djokovic-miami-2025-title-record-feature',jsonb_build_object('derived_from','sunshine_double')
from public.record_occurrences ro where ro.record_code='sunshine_double'
group by ro.player_id,ro.player_name,ro.country
on conflict (record_code,lower(player_name),coalesce(season,-1),coalesce(label,'')) do nothing;

insert into public.record_occurrences(record_code,player_id,player_name,country,season,achieved_on,value,label,source_type,source_label,source_url,metadata)
select 'masters_aces_edition_reference',p.id,p.name,p.country,2019,date '2019-03-31',98,'98 aces · Miami 2019','historical','Miami Open','https://www.miamiopen.com/latest-news/federer-vs-isner-preview-defending-champ-tries-to-fend-off-the-greatest','{"historical_absolute_claim":false,"note":"98 aces documented before the final"}'::jsonb
from public.players p where p.id=52189
on conflict (record_code,lower(player_name),coalesce(season,-1),coalesce(label,'')) do nothing;

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

  select p.name,p.country into v_name,v_country from public.players p where p.id=v_pid;

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

    select count(*) into v_sunshine_count
    from (
      select extract(year from pt.title_date)::int season,
             count(distinct public.cb_record_event_key(pt.tournament_name)) c
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

    select coalesce(pcs.aces,0) into v_career_aces
    from public.player_career_stats pcs where pcs.player_id=v_pid;
    v_career_aces := coalesce(v_career_aces,0) + coalesce((
      select sum(coalesce((mh.match_data->>'aces')::numeric,0))::bigint
      from public.match_history mh
      where mh.user_involved=true and mh.match_date>date '2025-12-01' and mh.match_date<=p_date
        and mh.match_data ? 'aces'
    ),0);

    select coalesce(max((mh.match_data->>'aces')::numeric),0)::int into v_masters_match_aces
    from public.match_history mh
    where mh.user_involved=true and mh.match_date<=p_date
      and coalesce(mh.match_data->>'category','') ilike '%Masters 1000%'
      and mh.match_data ? 'aces';

    select coalesce(max(total_aces),0)::int into v_masters_edition_aces
    from (
      select extract(year from mh.match_date)::int season,mh.tournament_name,
             sum(coalesce((mh.match_data->>'aces')::numeric,0)) total_aces
      from public.match_history mh
      where mh.user_involved=true and mh.match_date<=p_date
        and coalesce(mh.match_data->>'category','') ilike '%Masters 1000%'
        and mh.match_data ? 'aces'
      group by extract(year from mh.match_date)::int,mh.tournament_name
    ) z;

    v_progress := jsonb_build_array(
      jsonb_build_object('code','masters_titles_career','value',v_masters_titles,'target',40,'achieved',v_masters_titles>40,'label',v_masters_titles||' titres'),
      jsonb_build_object('code','masters_titles_season','value',v_masters_season,'target',6,'achieved',v_masters_season>6,'label','meilleure saison: '||v_masters_season),
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
      jsonb_build_object('code','calendar_grand_slam_men','value',case when v_calendar_slam then 4 else 0 end,'target',4,'achieved',v_calendar_slam,'label',case when v_calendar_slam then 'Réalisé' else 'À réaliser' end),
      jsonb_build_object('code','calendar_golden_slam_men','value',case when v_calendar_golden then 5 else 0 end,'target',5,'achieved',v_calendar_golden,'label',case when v_calendar_golden then 'HISTORIQUE' else 'Jamais réalisé chez les hommes' end),
      jsonb_build_object('code','career_aces_reference','value',v_career_aces,'target',14411,'achieved',v_career_aces>14411,'label',v_career_aces||' aces'),
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
        ('iw','indian_wells',5,1),
        ('miami','miami',6,2),
        ('monte_carlo','monte_carlo',11,3),
        ('madrid','madrid',5,4),
        ('rome','rome',10,5),
        ('canada','canada',6,6),
        ('cincinnati','cincinnati',7,7),
        ('shanghai','shanghai',4,8),
        ('paris','paris',7,9)
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

-- Remove the short-lived duplicate experimental tables from migration 20261002220421.
drop table if exists public.player_record_achievements;
drop table if exists public.tennis_record_catalog;
