-- Court Boss Player Legacy / Records & Awards V9
-- Personal record/award profile for every player, historical + simulated career.

create table if not exists public.court_boss_year_end_no1_reference (
  season integer primary key,
  player_name text not null,
  country text,
  source_label text not null default 'ATP Tour · Year-End No. 1',
  source_url text not null default 'https://www.atptour.com/en/rankings/former-no-1s'
);

alter table public.court_boss_year_end_no1_reference enable row level security;
revoke all on public.court_boss_year_end_no1_reference from public,anon,authenticated;
grant select,insert,update,delete on public.court_boss_year_end_no1_reference to service_role;

insert into public.court_boss_year_end_no1_reference(season,player_name,country) values
(1973,'Ilie Nastase','ROU'),
(1974,'Jimmy Connors','USA'),(1975,'Jimmy Connors','USA'),(1976,'Jimmy Connors','USA'),(1977,'Jimmy Connors','USA'),(1978,'Jimmy Connors','USA'),
(1979,'Bjorn Borg','SWE'),(1980,'Bjorn Borg','SWE'),
(1981,'John McEnroe','USA'),(1982,'John McEnroe','USA'),(1983,'John McEnroe','USA'),(1984,'John McEnroe','USA'),
(1985,'Ivan Lendl','CZE'),(1986,'Ivan Lendl','CZE'),(1987,'Ivan Lendl','CZE'),
(1988,'Mats Wilander','SWE'),(1989,'Ivan Lendl','CZE'),
(1990,'Stefan Edberg','SWE'),(1991,'Stefan Edberg','SWE'),
(1992,'Jim Courier','USA'),
(1993,'Pete Sampras','USA'),(1994,'Pete Sampras','USA'),(1995,'Pete Sampras','USA'),(1996,'Pete Sampras','USA'),(1997,'Pete Sampras','USA'),(1998,'Pete Sampras','USA'),
(1999,'Andre Agassi','USA'),(2000,'Gustavo Kuerten','BRA'),
(2001,'Lleyton Hewitt','AUS'),(2002,'Lleyton Hewitt','AUS'),(2003,'Andy Roddick','USA'),
(2004,'Roger Federer','SUI'),(2005,'Roger Federer','SUI'),(2006,'Roger Federer','SUI'),(2007,'Roger Federer','SUI'),
(2008,'Rafael Nadal','ESP'),(2009,'Roger Federer','SUI'),(2010,'Rafael Nadal','ESP'),
(2011,'Novak Djokovic','SRB'),(2012,'Novak Djokovic','SRB'),(2013,'Rafael Nadal','ESP'),(2014,'Novak Djokovic','SRB'),(2015,'Novak Djokovic','SRB'),
(2016,'Andy Murray','GBR'),(2017,'Rafael Nadal','ESP'),(2018,'Novak Djokovic','SRB'),(2019,'Rafael Nadal','ESP'),
(2020,'Novak Djokovic','SRB'),(2021,'Novak Djokovic','SRB'),(2022,'Carlos Alcaraz','ESP'),(2023,'Novak Djokovic','SRB'),
(2024,'Jannik Sinner','ITA'),(2025,'Carlos Alcaraz','ESP')
on conflict(season) do update set
  player_name=excluded.player_name,country=excluded.country,
  source_label=excluded.source_label,source_url=excluded.source_url;

create or replace function public.court_boss_all_time_snapshot(p_player_id bigint,p_date date)
returns jsonb
language sql
stable
security invoker
set search_path to ''
as $function$
with future_titles as (
  select pt.player_id,
    count(*)::int titles,
    count(*) filter(where public.cb_record_event_key(pt.tournament_name) in ('australian_open','roland_garros','wimbledon','us_open'))::int slams,
    count(*) filter(where coalesce(pt.level,'') ilike '%1000%')::int masters,
    count(*) filter(where coalesce(pt.level,'') ilike '%ATP Finals%' or lower(coalesce(pt.tournament_name,'')) like '%tour finals%' or lower(coalesce(pt.tournament_name,'')) like '%atp finals%' or lower(coalesce(pt.tournament_name,'')) like '%masters cup%')::int finals
  from public.player_titles pt
  where pt.event_type='singles' and pt.title_date>date '2025-12-01' and pt.title_date<=p_date
  group by pt.player_id
),
future_stats as (
  select s.player_id,count(*) filter(where s.won)::int wins,count(*) filter(where not s.won)::int losses
  from public.court_boss_match_stat_lines s
  where s.match_date>date '2025-12-01' and s.match_date<=p_date
  group by s.player_id
),
future_no1 as (
  select rh.player_id,count(*)::int weeks_no1
  from public.ranking_history rh
  where rh.snapshot_date>date '2025-12-01' and rh.snapshot_date<=p_date and rh.ranking=1
  group by rh.player_id
),
award_counts as (
  select a.player_id,count(*) filter(where a.award_code='player_of_year' and a.award_rank=1)::int poy
  from public.court_boss_player_awards a
  where a.season>2025 and a.season<=extract(year from p_date)::int
  group by a.player_id
),
historical_poy as (
  select p.id player_id,count(y.season)::int poy
  from public.players p
  join public.court_boss_year_end_no1_reference y on lower(y.player_name)=lower(p.name)
  where y.season<=least(2025,extract(year from p_date)::int)
    and coalesce(p.data_source,'') not ilike '%hidden duplicate merged into%'
  group by p.id
),
scored as (
  select p.id,p.name,p.country,
    coalesce(h.titles,0)+coalesce(ft.titles,0) titles,
    coalesce(h.grand_slams,0)+coalesce(ft.slams,0) slams,
    coalesce(h.masters,0)+coalesce(ft.masters,0) masters,
    coalesce(h.tour_finals,0)+coalesce(ft.finals,0) finals,
    greatest(coalesce(h.wins,0),coalesce(pcs.wins,0))+coalesce(fs.wins,0) wins,
    greatest(coalesce(h.losses,0),coalesce(pcs.losses,0))+coalesce(fs.losses,0) losses,
    coalesce(p.weeks_at_no1,0)+coalesce(fn.weeks_no1,0) weeks_no1,
    coalesce(hp.poy,0)+coalesce(ac.poy,0) poy,
    (
      (coalesce(h.grand_slams,0)+coalesce(ft.slams,0))*10000
      +(coalesce(h.tour_finals,0)+coalesce(ft.finals,0))*2200
      +(coalesce(h.masters,0)+coalesce(ft.masters,0))*1200
      +greatest((coalesce(h.titles,0)+coalesce(ft.titles,0))-(coalesce(h.grand_slams,0)+coalesce(ft.slams,0))-(coalesce(h.masters,0)+coalesce(ft.masters,0))-(coalesce(h.tour_finals,0)+coalesce(ft.finals,0)),0)*180
      +(greatest(coalesce(h.wins,0),coalesce(pcs.wins,0))+coalesce(fs.wins,0))*2
      +(coalesce(p.weeks_at_no1,0)+coalesce(fn.weeks_no1,0))*8
      +(coalesce(hp.poy,0)+coalesce(ac.poy,0))*1500
    )::bigint legacy_score
  from public.players p
  left join public.history_player_scores h on h.id=p.id
  left join public.player_career_stats pcs on pcs.player_id=p.id
  left join future_titles ft on ft.player_id=p.id
  left join future_stats fs on fs.player_id=p.id
  left join future_no1 fn on fn.player_id=p.id
  left join award_counts ac on ac.player_id=p.id
  left join historical_poy hp on hp.player_id=p.id
  where coalesce(p.data_source,'') not ilike '%hidden duplicate merged into%'
),
eligible as (select * from scored where legacy_score>0),
ranked as (
  select e.*,rank() over(order by e.legacy_score desc,e.slams desc,e.titles desc,e.wins desc,e.id) all_time_rank,count(*) over() pool_size
  from eligible e
)
select coalesce(
  (select jsonb_build_object(
    'rank',r.all_time_rank,'pool',r.pool_size,'score',r.legacy_score,
    'titles',r.titles,'grand_slams',r.slams,'masters',r.masters,'tour_finals',r.finals,
    'wins',r.wins,'losses',r.losses,'weeks_no1',r.weeks_no1,'player_of_year',r.poy,
    'tier',case when r.all_time_rank<=3 then 'GOAT tier' when r.all_time_rank<=10 then 'Panthéon' when r.all_time_rank<=50 then 'Légende' when r.all_time_rank<=200 then 'Élite historique' else 'Référence historique' end
  ) from ranked r where r.id=p_player_id),
  jsonb_build_object('rank',null,'pool',(select count(*) from eligible),'score',0,'titles',0,'grand_slams',0,'masters',0,'tour_finals',0,'wins',0,'losses',0,'weeks_no1',0,'player_of_year',0,'tier','En construction')
);
$function$;

create or replace function public.court_boss_player_career_stats_snapshot(p_player_id bigint,p_date date)
returns jsonb
language sql
stable
security invoker
set search_path to ''
as $function$
with baseline as (
  select greatest(coalesce(h.wins,0),coalesce(pcs.wins,0))::bigint wins,
    greatest(coalesce(h.losses,0),coalesce(pcs.losses,0))::bigint losses,
    coalesce(h.titles,0)::bigint titles,coalesce(h.grand_slams,0)::bigint slams,
    coalesce(h.masters,0)::bigint masters,coalesce(h.tour_finals,0)::bigint finals,
    coalesce(pcs.aces,0)::bigint aces,coalesce(pcs.double_faults,0)::bigint double_faults
  from public.players p
  left join public.history_player_scores h on h.id=p.id
  left join public.player_career_stats pcs on pcs.player_id=p.id
  where p.id=p_player_id
),
future as (
  select count(*) filter(where s.won)::bigint wins,count(*) filter(where not s.won)::bigint losses,
    coalesce(sum(s.aces),0)::bigint aces,coalesce(sum(s.double_faults),0)::bigint double_faults,
    coalesce(sum(s.service_points),0)::bigint service_points,coalesce(sum(s.service_points_won),0)::bigint service_points_won,
    coalesce(sum(s.return_points),0)::bigint return_points,coalesce(sum(s.return_points_won),0)::bigint return_points_won,
    count(*) filter(where s.won and coalesce(s.opponent_rank,9999)<=10)::bigint top10_wins,
    coalesce(sum(s.tiebreaks_played),0)::bigint tiebreaks_played,coalesce(sum(s.tiebreaks_won),0)::bigint tiebreaks_won,
    count(*)::bigint tracked_matches
  from public.court_boss_match_stat_lines s
  where s.player_id=p_player_id and s.match_date>date '2025-12-01' and s.match_date<=p_date
),
ft as (
  select count(*)::bigint titles,
    count(*) filter(where public.cb_record_event_key(pt.tournament_name) in ('australian_open','roland_garros','wimbledon','us_open'))::bigint slams,
    count(*) filter(where coalesce(pt.level,'') ilike '%1000%')::bigint masters,
    count(*) filter(where coalesce(pt.level,'') ilike '%ATP Finals%' or lower(coalesce(pt.tournament_name,'')) like '%tour finals%' or lower(coalesce(pt.tournament_name,'')) like '%atp finals%' or lower(coalesce(pt.tournament_name,'')) like '%masters cup%')::bigint finals
  from public.player_titles pt
  where pt.player_id=p_player_id and pt.event_type='singles' and pt.title_date>date '2025-12-01' and pt.title_date<=p_date
)
select jsonb_build_object(
  'wins',b.wins+f.wins,'losses',b.losses+f.losses,
  'win_pct',case when b.wins+b.losses+f.wins+f.losses>0 then round(100.0*(b.wins+f.wins)/(b.wins+b.losses+f.wins+f.losses),1) else null end,
  'titles',b.titles+ft.titles,'grand_slams',b.slams+ft.slams,'masters',b.masters+ft.masters,'tour_finals',b.finals+ft.finals,
  'aces',b.aces+f.aces,'double_faults',b.double_faults+f.double_faults,'tracked_matches_since_2025',f.tracked_matches,
  'service_points_won_pct',case when f.service_points>=80 then round(100.0*f.service_points_won/nullif(f.service_points,0),1) else null end,
  'return_points_won_pct',case when f.return_points>=80 then round(100.0*f.return_points_won/nullif(f.return_points,0),1) else null end,
  'top10_wins_since_2025',f.top10_wins,'tiebreaks_won_since_2025',f.tiebreaks_won,'tiebreaks_played_since_2025',f.tiebreaks_played,
  'best_win_streak_since_2025',public.cb_longest_win_streak(p_player_id,null,p_date),
  'best_hard_streak_since_2025',public.cb_longest_win_streak(p_player_id,'hard',p_date),
  'best_clay_streak_since_2025',public.cb_longest_win_streak(p_player_id,'clay',p_date),
  'best_grass_streak_since_2025',public.cb_longest_win_streak(p_player_id,'grass',p_date)
) from baseline b cross join future f cross join ft;
$function$;

create or replace function public.court_boss_player_legacy_profile(p_player_id bigint,p_date date default date '2025-12-01')
returns jsonb
language plpgsql
stable
security invoker
set search_path to ''
as $function$
declare
  v_player public.players%rowtype;
  v_hub jsonb:='{}'::jsonb; v_progress jsonb:='[]'::jsonb;
  v_held jsonb:='[]'::jsonb; v_close jsonb:='[]'::jsonb; v_achievements jsonb:='[]'::jsonb;
  v_awards jsonb:='[]'::jsonb; v_hist_awards jsonb:='[]'::jsonb; v_poy_years jsonb:='[]'::jsonb;
begin
  select * into v_player from public.players where id=p_player_id;
  if v_player.id is null then return jsonb_build_object('ok',false,'reason','player_not_found','player_id',p_player_id); end if;

  v_hub:=public.court_boss_record_hub(p_player_id,p_date);
  v_progress:=coalesce(v_hub->'managed'->'progress','[]'::jsonb);

  with progress as (
    select x->>'code' code,nullif(x->>'value','')::numeric value,nullif(x->>'target','')::numeric target,
      coalesce((x->>'achieved')::boolean,false) achieved,x->>'label' label
    from jsonb_array_elements(v_progress) x
  ), held as (
    select distinct on (c.code)
      c.code,c.category,c.subcategory,c.name,c.rarity,c.unit,c.baseline_value,c.baseline_holder,c.baseline_country,c.baseline_year,
      coalesce(p.value,c.baseline_value) value,
      coalesce(p.label,c.baseline_value::text||case when c.unit is not null then ' '||c.unit else '' end) label,
      case when lower(coalesce(c.baseline_holder,''))=lower(v_player.name) then 'historical_holder' else 'career_record' end holder_kind
    from public.record_catalog c left join progress p on p.code=c.code
    where lower(coalesce(c.baseline_holder,''))=lower(v_player.name)
      or (p.achieved and c.baseline_value is not null and p.value is not null and p.value>=c.baseline_value and c.record_type in ('numeric','dynamic'))
      or exists(select 1 from public.record_occurrences ro where ro.record_code=c.code and ro.player_id=p_player_id and c.baseline_value is not null and coalesce(ro.value,0)>=c.baseline_value)
    order by c.code,case when lower(coalesce(c.baseline_holder,''))=lower(v_player.name) then 0 else 1 end,coalesce(p.value,c.baseline_value) desc nulls last
  )
  select coalesce(jsonb_agg(to_jsonb(held) order by case held.rarity when 'mythic' then 1 when 'legendary' then 2 when 'elite' then 3 else 4 end,held.name),'[]'::jsonb) into v_held from held;

  with progress as (
    select x->>'code' code,nullif(x->>'value','')::numeric value,nullif(x->>'target','')::numeric target,
      coalesce((x->>'achieved')::boolean,false) achieved,x->>'label' label
    from jsonb_array_elements(v_progress) x
  ), close_rows as (
    select c.code,c.category,c.subcategory,c.name,c.rarity,c.unit,c.baseline_holder,c.baseline_value,
      p.value,p.target,p.label,round(100*greatest(0,p.value)/nullif(p.target,0),1) progress_pct,greatest(0,p.target-p.value) distance
    from progress p join public.record_catalog c on c.code=p.code
    where not p.achieved and p.target is not null and p.target>0 and p.value is not null and p.value>0 and p.value/p.target>=0.25
    order by p.value/p.target desc,case c.rarity when 'mythic' then 1 when 'legendary' then 2 when 'elite' then 3 else 4 end,c.display_order limit 8
  )
  select coalesce(jsonb_agg(to_jsonb(close_rows) order by progress_pct desc,name),'[]'::jsonb) into v_close from close_rows;

  with progress as (
    select x->>'code' code,nullif(x->>'value','')::numeric value,nullif(x->>'target','')::numeric target,
      coalesce((x->>'achieved')::boolean,false) achieved,x->>'label' label
    from jsonb_array_elements(v_progress) x
  ), achieved_rows as (
    select c.code,c.category,c.subcategory,c.name,c.rarity,c.unit,p.value,p.target,p.label
    from progress p join public.record_catalog c on c.code=p.code
    where p.achieved and not exists(select 1 from jsonb_array_elements(v_held) h where h->>'code'=c.code)
    order by case c.rarity when 'mythic' then 1 when 'legendary' then 2 when 'elite' then 3 else 4 end,c.display_order limit 16
  )
  select coalesce(jsonb_agg(to_jsonb(achieved_rows)),'[]'::jsonb) into v_achievements from achieved_rows;

  select coalesce(jsonb_agg(to_jsonb(a) order by a.season desc,a.award_code,a.award_rank),'[]'::jsonb) into v_awards
  from public.court_boss_player_awards a where a.player_id=p_player_id and a.season<=extract(year from p_date)::int;

  select coalesce(jsonb_agg(jsonb_build_object(
    'season',y.season,'award_code','player_of_year','award_name','ATP Year-End No. 1','award_rank',1,
    'player_id',p_player_id,'player_name',v_player.name,'country',y.country,'score',null,
    'details',jsonb_build_object('historical',true,'official_label','ATP Year-End No. 1'),
    'source_type','historical','source_label',y.source_label,'source_url',y.source_url
  ) order by y.season desc),'[]'::jsonb) into v_hist_awards
  from public.court_boss_year_end_no1_reference y
  where lower(y.player_name)=lower(v_player.name) and y.season<=least(2025,extract(year from p_date)::int);

  select coalesce(jsonb_agg(distinct x order by x),'[]'::jsonb) into v_poy_years
  from (
    select y.season x from public.court_boss_year_end_no1_reference y
    where lower(y.player_name)=lower(v_player.name) and y.season<=least(2025,extract(year from p_date)::int)
    union all
    select a.season from public.court_boss_player_awards a
    where a.player_id=p_player_id and a.award_code='player_of_year' and a.award_rank=1 and a.season>2025 and a.season<=extract(year from p_date)::int
  ) q;

  return jsonb_build_object(
    'ok',true,'player_id',p_player_id,'player_name',v_player.name,'as_of_date',p_date,
    'held_records',coalesce(v_held,'[]'::jsonb),'near_records',coalesce(v_close,'[]'::jsonb),
    'achievements',coalesce(v_achievements,'[]'::jsonb),'awards',coalesce(v_awards,'[]'::jsonb),
    'historical_awards',coalesce(v_hist_awards,'[]'::jsonb),'player_of_year_years',coalesce(v_poy_years,'[]'::jsonb),
    'all_time',public.court_boss_all_time_snapshot(p_player_id,p_date),
    'career_stats',public.court_boss_player_career_stats_snapshot(p_player_id,p_date),
    'model','CB-PLAYER-LEGACY-v2'
  );
end;
$function$;

revoke all on function public.court_boss_all_time_snapshot(bigint,date) from public,anon,authenticated;
grant execute on function public.court_boss_all_time_snapshot(bigint,date) to service_role;
revoke all on function public.court_boss_player_career_stats_snapshot(bigint,date) from public,anon,authenticated;
grant execute on function public.court_boss_player_career_stats_snapshot(bigint,date) to service_role;
revoke all on function public.court_boss_player_legacy_profile(bigint,date) from public,anon,authenticated;
grant execute on function public.court_boss_player_legacy_profile(bigint,date) to service_role;
