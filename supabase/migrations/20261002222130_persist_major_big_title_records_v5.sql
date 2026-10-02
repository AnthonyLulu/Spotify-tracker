-- Court Boss Record persistence v5
-- Live migration version: 20261002222130
CREATE OR REPLACE FUNCTION public.sync_court_boss_player_records(p_player_id bigint, p_date date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_name text;
  v_country text;
  v_inserted integer := 0;
  v_rows integer := 0;
  v_masters_titles integer := 0;
  v_sunshine_count integer := 0;
  v_career_aces bigint := 0;
  v_slam_titles integer := 0;
  v_ao_titles integer := 0;
  v_rg_titles integer := 0;
  v_wim_titles integer := 0;
  v_uso_titles integer := 0;
  v_finals_titles integer := 0;
  v_olympic_titles integer := 0;
  v_big_titles integer := 0;
begin
  select p.name,p.country into v_name,v_country
  from public.players p where p.id=p_player_id;

  if v_name is null then
    return jsonb_build_object('ok',false,'reason','player_not_found','player_id',p_player_id);
  end if;

  -- Same-season achievements. Existing historical rows are protected by the natural unique index.
  with facts as (
    select distinct pt.title_date,extract(year from pt.title_date)::int season,
           public.cb_record_event_key(pt.tournament_name) event_key
    from public.player_titles pt
    where pt.player_id=p_player_id and pt.event_type='singles' and pt.title_date<=p_date
  ),
  achievements as (
    select 'sunshine_double'::text code,season,max(title_date) achieved_on,2::numeric value,'Indian Wells + Miami'::text label
    from facts where event_key in ('indian_wells','miami')
    group by season having count(distinct event_key)=2
    union all
    select 'clay_masters_sweep',season,max(title_date),3,'Monte-Carlo + Madrid + Rome'
    from facts where event_key in ('monte_carlo','madrid','rome')
    group by season having count(distinct event_key)=3
    union all
    select 'summer_masters_sweep',season,max(title_date),2,'Canada + Cincinnati'
    from facts where event_key in ('canada','cincinnati')
    group by season having count(distinct event_key)=2
    union all
    select 'fall_masters_sweep',season,max(title_date),2,'Shanghai + Paris'
    from facts where event_key in ('shanghai','paris')
    group by season having count(distinct event_key)=2
    union all
    select 'channel_slam',season,max(title_date),2,'Roland-Garros + Wimbledon'
    from facts where event_key in ('roland_garros','wimbledon')
    group by season having count(distinct event_key)=2
    union all
    select 'north_america_triple',season,max(title_date),3,'Canada + Cincinnati + US Open'
    from facts where event_key in ('canada','cincinnati','us_open')
    group by season having count(distinct event_key)=3
    union all
    select 'calendar_grand_slam_men',season,max(title_date),4,'Australian Open + Roland-Garros + Wimbledon + US Open'
    from facts where event_key in ('australian_open','roland_garros','wimbledon','us_open')
    group by season having count(distinct event_key)=4
    union all
    select 'calendar_golden_slam_men',season,max(title_date),5,'4 Majeurs + or olympique'
    from facts where event_key in ('australian_open','roland_garros','wimbledon','us_open','olympics')
    group by season having count(distinct event_key)=5
    union all
    select 'small_slam',season,max(title_date),3,'3 Majeurs sur 4'
    from facts where event_key in ('australian_open','roland_garros','wimbledon','us_open')
    group by season having count(distinct event_key)=3
    union all
    select 'three_surface_majors',season,max(title_date),3,'Roland-Garros + Wimbledon + US Open'
    from facts where event_key in ('roland_garros','wimbledon','us_open')
    group by season having count(distinct event_key)=3
    union all
    select 'clay_slam',season,max(title_date),4,'Monte-Carlo + Madrid + Rome + Roland-Garros'
    from facts where event_key in ('monte_carlo','madrid','rome','roland_garros')
    group by season having count(distinct event_key)=4
    union all
    select 'spring_masters_triple',season,max(title_date),3,'Indian Wells + Miami + Monte-Carlo'
    from facts where event_key in ('indian_wells','miami','monte_carlo')
    group by season having count(distinct event_key)=3
  )
  insert into public.record_occurrences
  (record_code,player_id,player_name,country,season,achieved_on,value,label,source_type,source_label,source_url,metadata)
  select a.code,p_player_id,v_name,v_country,a.season,a.achieved_on,a.value,a.label,'career','Court Boss · sauvegarde','',
         jsonb_build_object('game_date',p_date)
  from achievements a
  on conflict (record_code,lower(player_name),coalesce(season,-1),coalesce(label,'')) do nothing;

  get diagnostics v_rows = row_count;
  v_inserted := v_inserted + v_rows;

  -- Career Grand Slam and Career Golden Slam.
  with firsts as (
    select public.cb_record_event_key(pt.tournament_name) event_key,min(pt.title_date) first_date
    from public.player_titles pt
    where pt.player_id=p_player_id and pt.event_type='singles' and pt.title_date<=p_date
      and public.cb_record_event_key(pt.tournament_name) in
          ('australian_open','roland_garros','wimbledon','us_open','olympics')
    group by public.cb_record_event_key(pt.tournament_name)
  ),
  cg as (
    select max(first_date) achieved_on
    from firsts where event_key in ('australian_open','roland_garros','wimbledon','us_open')
    having count(*)=4
  ),
  cgs as (
    select max(first_date) achieved_on
    from firsts where event_key in ('australian_open','roland_garros','wimbledon','us_open','olympics')
    having count(*)=5
  ),
  achievements as (
    select 'career_grand_slam'::text code,achieved_on,4::numeric value,'4/4 Majeurs'::text label from cg where achieved_on is not null
    union all
    select 'career_golden_slam',achieved_on,5,'4 Majeurs + or olympique' from cgs where achieved_on is not null
  )
  insert into public.record_occurrences
  (record_code,player_id,player_name,country,season,achieved_on,value,label,source_type,source_label,source_url,metadata)
  select code,p_player_id,v_name,v_country,extract(year from achieved_on)::int,achieved_on,value,label,'career','Court Boss · sauvegarde','',
         jsonb_build_object('game_date',p_date)
  from achievements
  on conflict (record_code,lower(player_name),coalesce(season,-1),coalesce(label,'')) do nothing;

  get diagnostics v_rows = row_count;
  v_inserted := v_inserted + v_rows;

  -- Career Golden Masters.
  with firsts as (
    select public.cb_record_event_key(pt.tournament_name) event_key,min(pt.title_date) first_date
    from public.player_titles pt
    where pt.player_id=p_player_id and pt.event_type='singles' and pt.title_date<=p_date
      and public.cb_record_event_key(pt.tournament_name) in
          ('indian_wells','miami','monte_carlo','madrid','rome','canada','cincinnati','shanghai','paris')
    group by public.cb_record_event_key(pt.tournament_name)
  ),
  done as (
    select max(first_date) achieved_on from firsts having count(*)=9
  )
  insert into public.record_occurrences
  (record_code,player_id,player_name,country,season,achieved_on,value,label,source_type,source_label,source_url,metadata)
  select 'career_golden_masters',p_player_id,v_name,v_country,extract(year from achieved_on)::int,achieved_on,9,'9 Masters différents',
         'career','Court Boss · sauvegarde','',jsonb_build_object('game_date',p_date)
  from done where achieved_on is not null
  on conflict (record_code,lower(player_name),coalesce(season,-1),coalesce(label,'')) do nothing;

  get diagnostics v_rows = row_count;
  v_inserted := v_inserted + v_rows;

  -- Double Career Golden Masters: second title date for every one of the nine events.
  with ordered as (
    select public.cb_record_event_key(pt.tournament_name) event_key,pt.title_date,
           row_number() over(partition by public.cb_record_event_key(pt.tournament_name) order by pt.title_date) rn
    from public.player_titles pt
    where pt.player_id=p_player_id and pt.event_type='singles' and pt.title_date<=p_date
      and public.cb_record_event_key(pt.tournament_name) in
          ('indian_wells','miami','monte_carlo','madrid','rome','canada','cincinnati','shanghai','paris')
  ),
  seconds as (
    select event_key,title_date second_date from ordered where rn=2
  ),
  done as (
    select max(second_date) achieved_on from seconds having count(*)=9
  )
  insert into public.record_occurrences
  (record_code,player_id,player_name,country,season,achieved_on,value,label,source_type,source_label,source_url,metadata)
  select 'double_career_golden_masters',p_player_id,v_name,v_country,extract(year from achieved_on)::int,achieved_on,2,'Deux fois les 9 Masters',
         'career','Court Boss · sauvegarde','',jsonb_build_object('game_date',p_date)
  from done where achieved_on is not null
  on conflict (record_code,lower(player_name),coalesce(season,-1),coalesce(label,'')) do nothing;

  get diagnostics v_rows = row_count;
  v_inserted := v_inserted + v_rows;

  -- Rolling four-major sweep ("Nole Slam" style).
  with majors as (
    select distinct pt.title_date,public.cb_record_event_key(pt.tournament_name) event_key
    from public.player_titles pt
    where pt.player_id=p_player_id and pt.event_type='singles' and pt.title_date<=p_date
      and public.cb_record_event_key(pt.tournament_name) in ('australian_open','roland_garros','wimbledon','us_open')
  ),
  windows as (
    select a.title_date start_date,max(b.title_date) achieved_on,count(distinct b.event_key) event_count
    from majors a
    join majors b on b.title_date between a.title_date and a.title_date+370
    group by a.title_date
    having count(distinct b.event_key)=4
       and extract(year from min(b.title_date))<>extract(year from max(b.title_date))
  )
  insert into public.record_occurrences
  (record_code,player_id,player_name,country,season,achieved_on,value,label,source_type,source_label,source_url,metadata)
  select 'nole_slam',p_player_id,v_name,v_country,extract(year from achieved_on)::int,achieved_on,4,'4 Majeurs détenus simultanément',
         'career','Court Boss · sauvegarde','',jsonb_build_object('window_start',start_date,'game_date',p_date)
  from windows
  on conflict (record_code,lower(player_name),coalesce(season,-1),coalesce(label,'')) do nothing;

  get diagnostics v_rows = row_count;
  v_inserted := v_inserted + v_rows;

  -- Sunshine Double career record progression.
  select count(*) into v_sunshine_count
  from (
    select extract(year from pt.title_date)::int season
    from public.player_titles pt
    where pt.player_id=p_player_id and pt.event_type='singles' and pt.title_date<=p_date
      and public.cb_record_event_key(pt.tournament_name) in ('indian_wells','miami')
    group by extract(year from pt.title_date)::int
    having count(distinct public.cb_record_event_key(pt.tournament_name))=2
  ) s;

  if v_sunshine_count>=4 and not exists(
    select 1 from public.record_occurrences ro
    where ro.record_code='sunshine_double_career_record' and ro.player_id=p_player_id
      and coalesce(ro.value,0)>=v_sunshine_count
  ) then
    insert into public.record_occurrences
    (record_code,player_id,player_name,country,season,achieved_on,value,label,source_type,source_label,source_url,metadata)
    values
    ('sunshine_double_career_record',p_player_id,v_name,v_country,extract(year from p_date)::int,p_date,v_sunshine_count,
     v_sunshine_count||' Sunshine Doubles','career','Court Boss · sauvegarde','',jsonb_build_object('game_date',p_date));
    v_inserted := v_inserted + 1;
  end if;

  -- Masters career title record progression beyond the 2025 benchmark.
  select count(*) into v_masters_titles
  from (
    select distinct extract(year from pt.title_date)::int season,public.cb_record_event_key(pt.tournament_name) event_key
    from public.player_titles pt
    where pt.player_id=p_player_id and pt.event_type='singles' and pt.title_date<=p_date
      and coalesce(pt.level,'') ilike '%1000%'
  ) x;

  if v_masters_titles>=40 and not exists(
    select 1 from public.record_occurrences ro
    where ro.record_code='masters_titles_career' and ro.player_id=p_player_id
      and coalesce(ro.value,0)>=v_masters_titles
  ) then
    insert into public.record_occurrences
    (record_code,player_id,player_name,country,season,achieved_on,value,label,source_type,source_label,source_url,metadata)
    values
    ('masters_titles_career',p_player_id,v_name,v_country,extract(year from p_date)::int,p_date,v_masters_titles,
     v_masters_titles||' titres Masters 1000','career','Court Boss · sauvegarde','',jsonb_build_object('game_date',p_date));
    v_inserted := v_inserted + 1;
  end if;

  -- Masters single-season record if the simulated world goes beyond Djokovic's six.
  insert into public.record_occurrences
  (record_code,player_id,player_name,country,season,achieved_on,value,label,source_type,source_label,source_url,metadata)
  select 'masters_titles_season',p_player_id,v_name,v_country,s.season,s.achieved_on,s.cnt,
         s.cnt||' Masters 1000 sur la saison','career','Court Boss · sauvegarde','',jsonb_build_object('game_date',p_date)
  from (
    select extract(year from pt.title_date)::int season,max(pt.title_date) achieved_on,
           count(distinct public.cb_record_event_key(pt.tournament_name))::int cnt
    from public.player_titles pt
    where pt.player_id=p_player_id and pt.event_type='singles' and pt.title_date<=p_date
      and coalesce(pt.level,'') ilike '%1000%'
    group by extract(year from pt.title_date)::int
    having count(distinct public.cb_record_event_key(pt.tournament_name))>=6
  ) s
  on conflict (record_code,lower(player_name),coalesce(season,-1),coalesce(label,'')) do nothing;

  get diagnostics v_rows = row_count;
  v_inserted := v_inserted + v_rows;

  -- Aces: career record and sourced Masters-edition benchmark.
  select coalesce(pcs.aces,0) into v_career_aces
  from public.player_career_stats pcs where pcs.player_id=p_player_id;

  v_career_aces := coalesce(v_career_aces,0) + coalesce((
    select sum(coalesce((mh.match_data->>'aces')::numeric,0))::bigint
    from public.match_history mh
    where mh.user_involved=true and mh.match_date>date '2025-12-01' and mh.match_date<=p_date
      and (mh.player_a=v_name or mh.player_b=v_name)
      and mh.match_data ? 'aces'
  ),0);

  if v_career_aces>=14411 and not exists(
    select 1 from public.record_occurrences ro
    where ro.record_code='career_aces_reference' and ro.player_id=p_player_id
      and coalesce(ro.value,0)>=v_career_aces
  ) then
    insert into public.record_occurrences
    (record_code,player_id,player_name,country,season,achieved_on,value,label,source_type,source_label,source_url,metadata)
    values
    ('career_aces_reference',p_player_id,v_name,v_country,extract(year from p_date)::int,p_date,v_career_aces,
     v_career_aces||' aces en carrière','career','Court Boss · sauvegarde','',jsonb_build_object('game_date',p_date));
    v_inserted := v_inserted + 1;
  end if;

  insert into public.record_occurrences
  (record_code,player_id,player_name,country,season,achieved_on,value,label,source_type,source_label,source_url,metadata)
  select 'masters_aces_edition_reference',p_player_id,v_name,v_country,x.season,x.achieved_on,x.total_aces,
         x.total_aces||' aces · '||x.tournament_name,'career','Court Boss · sauvegarde','',
         jsonb_build_object('historical_benchmark',98,'game_date',p_date)
  from (
    select extract(year from mh.match_date)::int season,mh.tournament_name,max(mh.match_date) achieved_on,
           sum(coalesce((mh.match_data->>'aces')::numeric,0))::int total_aces
    from public.match_history mh
    where mh.user_involved=true and mh.match_date<=p_date
      and (mh.player_a=v_name or mh.player_b=v_name)
      and coalesce(mh.match_data->>'category','') ilike '%Masters 1000%'
      and mh.match_data ? 'aces'
    group by extract(year from mh.match_date)::int,mh.tournament_name
    having sum(coalesce((mh.match_data->>'aces')::numeric,0))>=98
  ) x
  on conflict (record_code,lower(player_name),coalesce(season,-1),coalesce(label,'')) do nothing;

  get diagnostics v_rows = row_count;
  v_inserted := v_inserted + v_rows;


  -- Major, ATP Finals and Big Title records.
  select count(*) into v_slam_titles
  from (
    select distinct extract(year from pt.title_date)::int season,
           public.cb_record_event_key(pt.tournament_name) event_key
    from public.player_titles pt
    where pt.player_id=p_player_id and pt.event_type='singles' and pt.title_date<=p_date
      and public.cb_record_event_key(pt.tournament_name) in ('australian_open','roland_garros','wimbledon','us_open')
  ) s;

  select count(*) into v_ao_titles from (
    select distinct extract(year from pt.title_date)::int season
    from public.player_titles pt
    where pt.player_id=p_player_id and pt.event_type='singles' and pt.title_date<=p_date
      and public.cb_record_event_key(pt.tournament_name)='australian_open'
  ) s;

  select count(*) into v_rg_titles from (
    select distinct extract(year from pt.title_date)::int season
    from public.player_titles pt
    where pt.player_id=p_player_id and pt.event_type='singles' and pt.title_date<=p_date
      and public.cb_record_event_key(pt.tournament_name)='roland_garros'
  ) s;

  select count(*) into v_wim_titles from (
    select distinct extract(year from pt.title_date)::int season
    from public.player_titles pt
    where pt.player_id=p_player_id and pt.event_type='singles' and pt.title_date<=p_date
      and public.cb_record_event_key(pt.tournament_name)='wimbledon'
  ) s;

  select count(*) into v_uso_titles from (
    select distinct extract(year from pt.title_date)::int season
    from public.player_titles pt
    where pt.player_id=p_player_id and pt.event_type='singles' and pt.title_date<=p_date
      and public.cb_record_event_key(pt.tournament_name)='us_open'
  ) s;

  select count(*) into v_finals_titles from (
    select distinct extract(year from pt.title_date)::int season
    from public.player_titles pt
    where pt.player_id=p_player_id and pt.event_type='singles' and pt.title_date<=p_date
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
    where pt.player_id=p_player_id and pt.event_type='singles' and pt.title_date<=p_date
      and public.cb_record_event_key(pt.tournament_name)='olympics'
  ) s;

  v_big_titles := v_slam_titles + v_masters_titles + v_finals_titles + v_olympic_titles;

  with values_now(code,value,target,label) as (
    values
      ('grand_slam_titles_career'::text,v_slam_titles::numeric,24::numeric,v_slam_titles||' Majeurs'),
      ('big_titles_career',v_big_titles::numeric,72::numeric,v_big_titles||' Big Titles'),
      ('major_event_ao',v_ao_titles::numeric,10::numeric,v_ao_titles||' titres Australian Open'),
      ('major_event_rg',v_rg_titles::numeric,14::numeric,v_rg_titles||' titres Roland-Garros'),
      ('major_event_wimbledon',v_wim_titles::numeric,8::numeric,v_wim_titles||' titres Wimbledon'),
      ('major_event_us_open_open_era',v_uso_titles::numeric,5::numeric,v_uso_titles||' titres US Open · Open Era'),
      ('atp_finals_titles_career',v_finals_titles::numeric,7::numeric,v_finals_titles||' titres ATP Finals')
  )
  insert into public.record_occurrences
  (record_code,player_id,player_name,country,season,achieved_on,value,label,source_type,source_label,source_url,metadata)
  select
    v.code,p_player_id,v_name,v_country,extract(year from p_date)::int,p_date,v.value,v.label,
    'career','Court Boss · sauvegarde','',
    jsonb_build_object('game_date',p_date,'benchmark',v.target)
  from values_now v
  where v.value>=v.target
    and not exists(
      select 1 from public.record_occurrences ro
      where ro.record_code=v.code and ro.player_id=p_player_id
        and coalesce(ro.value,0)>=v.value
    );

  get diagnostics v_rows = row_count;
  v_inserted := v_inserted + v_rows;

  return jsonb_build_object('ok',true,'player_id',p_player_id,'player_name',v_name,'game_date',p_date,'inserted',v_inserted);
end;
$function$;
revoke all on function public.sync_court_boss_player_records(bigint,date) from public;
grant execute on function public.sync_court_boss_player_records(bigint,date) to service_role;
