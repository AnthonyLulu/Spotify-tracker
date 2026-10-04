-- Court Boss Records/Awards V8
-- Seasonal player awards and historical record catalog expansion.
-- Applied to Supabase on 2026-10-04.

create table if not exists public.court_boss_player_awards (
  id bigserial primary key,
  season integer not null,
  award_code text not null,
  award_name text not null,
  award_rank integer not null default 1,
  player_id bigint references public.players(id) on delete set null,
  player_name text not null,
  country text,
  score numeric,
  details jsonb not null default '{}'::jsonb,
  source_type text not null default 'career',
  source_label text not null default 'Court Boss · moteur saison',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(season,award_code,award_rank)
);

create index if not exists cb_player_awards_player_idx
  on public.court_boss_player_awards(player_id,season);
create index if not exists cb_player_awards_season_idx
  on public.court_boss_player_awards(season desc,award_code);

alter table public.court_boss_player_awards enable row level security;
revoke all on public.court_boss_player_awards from public,anon,authenticated;
grant select,insert,update,delete on public.court_boss_player_awards to service_role;
grant usage,select on sequence public.court_boss_player_awards_id_seq to service_role;

create or replace function public.finalize_court_boss_player_awards(p_season integer)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_rows integer := 0;
begin
  if p_season < 2025 or p_season > 2100 then
    return jsonb_build_object('ok',false,'reason','season_out_of_range','season',p_season);
  end if;

  with
  start_ranks as (
    select distinct on (rh.player_id) rh.player_id,rh.ranking
    from public.ranking_history rh
    where rh.snapshot_date between make_date(p_season,1,1) and make_date(p_season,12,31)
      and rh.ranking is not null
    order by rh.player_id,rh.snapshot_date asc
  ),
  end_ranks as (
    select distinct on (rh.player_id) rh.player_id,rh.ranking
    from public.ranking_history rh
    where rh.snapshot_date between make_date(p_season,1,1) and make_date(p_season,12,31)
      and rh.ranking is not null
    order by rh.player_id,rh.snapshot_date desc
  ),
  titles as (
    select pt.player_id,
      count(*) filter(where pt.event_type='singles')::int titles,
      count(*) filter(where pt.event_type='singles' and public.cb_record_event_key(pt.tournament_name) in ('australian_open','roland_garros','wimbledon','us_open'))::int slams,
      count(*) filter(where pt.event_type='singles' and coalesce(pt.level,'') ilike '%1000%')::int masters,
      count(*) filter(where pt.event_type='singles' and (coalesce(pt.level,'') ilike '%ATP Finals%' or lower(coalesce(pt.tournament_name,'')) like '%tour finals%' or lower(coalesce(pt.tournament_name,'')) like '%atp finals%'))::int finals,
      count(*) filter(where pt.event_type='singles' and (lower(coalesce(pt.surface,'')) like '%hard%' or lower(coalesce(pt.surface,'')) like '%dur%'))::int hard_titles,
      count(*) filter(where pt.event_type='singles' and (lower(coalesce(pt.surface,'')) like '%clay%' or lower(coalesce(pt.surface,'')) like '%terre%'))::int clay_titles,
      count(*) filter(where pt.event_type='singles' and (lower(coalesce(pt.surface,'')) like '%grass%' or lower(coalesce(pt.surface,'')) like '%gazon%'))::int grass_titles
    from public.player_titles pt
    where pt.title_date between make_date(p_season,1,1) and make_date(p_season,12,31)
    group by pt.player_id
  ),
  stats as (
    select s.player_id,
      count(*)::int matches,
      count(*) filter(where s.won)::int wins,
      count(*) filter(where s.won and (lower(coalesce(s.surface,'')) like '%hard%' or lower(coalesce(s.surface,'')) like '%dur%'))::int hard_wins,
      count(*) filter(where s.won and (lower(coalesce(s.surface,'')) like '%clay%' or lower(coalesce(s.surface,'')) like '%terre%'))::int clay_wins,
      count(*) filter(where s.won and (lower(coalesce(s.surface,'')) like '%grass%' or lower(coalesce(s.surface,'')) like '%gazon%'))::int grass_wins,
      count(*) filter(where s.won and coalesce(s.opponent_rank,9999)<=10)::int top10_wins,
      sum(s.aces)::numeric aces,
      sum(s.service_points)::numeric service_points,
      sum(s.service_points_won)::numeric service_points_won,
      sum(s.return_points)::numeric return_points,
      sum(s.return_points_won)::numeric return_points_won,
      sum(s.tiebreaks_played)::numeric tiebreaks_played,
      sum(s.tiebreaks_won)::numeric tiebreaks_won
    from public.court_boss_match_stat_lines s
    where s.season=p_season
    group by s.player_id
  ),
  scored as (
    select
      p.id player_id,p.name player_name,p.country,
      coalesce(sr.ranking,p.ranking,9999) start_rank,
      coalesce(er.ranking,p.ranking,9999) end_rank,
      coalesce(t.titles,0) titles,coalesce(t.slams,0) slams,coalesce(t.masters,0) masters,coalesce(t.finals,0) finals,
      coalesce(st.matches,0) matches,coalesce(st.wins,0) wins,
      coalesce(st.hard_wins,0) hard_wins,coalesce(st.clay_wins,0) clay_wins,coalesce(st.grass_wins,0) grass_wins,
      coalesce(t.hard_titles,0) hard_titles,coalesce(t.clay_titles,0) clay_titles,coalesce(t.grass_titles,0) grass_titles,
      coalesce(st.top10_wins,0) top10_wins,coalesce(st.aces,0) aces,
      case when coalesce(st.service_points,0)>=120 then 100*st.service_points_won/nullif(st.service_points,0)
           else (coalesce(pa.serve_power,50)+coalesce(pa.first_serve_quality,50)+coalesce(pa.serve_precision,50)+coalesce(pa.serve_consistency,50))/4.0 end service_score,
      case when coalesce(st.return_points,0)>=120 then 100*st.return_points_won/nullif(st.return_points,0)
           else (coalesce(pa.return_game,50)+coalesce(pa.return_consistency,50)+coalesce(pa.return_aggression,50)+coalesce(pa.anticipation,50))/4.0 end return_score,
      case when coalesce(st.tiebreaks_played,0)>=5 then 100*st.tiebreaks_won/nullif(st.tiebreaks_played,0)
           else coalesce(pa.big_points,50)::numeric end clutch_score,
      case when p.birth_date is not null then extract(year from age(make_date(p_season,12,31),p.birth_date))::int else p.age end age_year,
      p.generated_year,
      (
        greatest(0,201-least(coalesce(er.ranking,p.ranking,9999),201))*3
        +coalesce(t.slams,0)*1200+coalesce(t.masters,0)*500+coalesce(t.finals,0)*700
        +greatest(0,coalesce(t.titles,0)-coalesce(t.slams,0)-coalesce(t.masters,0)-coalesce(t.finals,0))*130
        +coalesce(st.wins,0)*8+coalesce(st.top10_wins,0)*35
      )::numeric poy_score
    from public.players p
    left join start_ranks sr on sr.player_id=p.id
    left join end_ranks er on er.player_id=p.id
    left join titles t on t.player_id=p.id
    left join stats st on st.player_id=p.id
    left join public.player_attributes pa on pa.player_id=p.id
    where coalesce(p.career_status,'active')<>'retired'
       or p.retired_date is null
       or p.retired_date>=make_date(p_season,1,1)
  ),
  candidates as (
    select 'player_of_year'::text award_code,'Joueur de l’année'::text award_name,player_id,player_name,country,poy_score score,
      jsonb_build_object('rank',end_rank,'titles',titles,'slams',slams,'masters',masters,'wins',wins,'top10_wins',top10_wins) details
    from scored where end_rank<=200
    union all
    select 'most_improved','Most Improved',player_id,player_name,country,
      ((start_rank-end_rank)*5+titles*80+slams*400+masters*160+wins*3)::numeric,
      jsonb_build_object('start_rank',start_rank,'end_rank',end_rank,'titles',titles,'wins',wins)
    from scored where start_rank>end_rank and end_rank<=150 and coalesce(generated_year,0)<>p_season
    union all
    select 'breakthrough','Breakthrough',player_id,player_name,country,
      (greatest(0,start_rank-end_rank)*5+titles*120+slams*500+masters*200+wins*4)::numeric,
      jsonb_build_object('start_rank',start_rank,'end_rank',end_rank,'age',age_year,'titles',titles)
    from scored where end_rank<=100 and (start_rank>100 or generated_year=p_season) and coalesce(age_year,99)<=23
    union all
    select 'comeback','Comeback',player_id,player_name,country,
      (greatest(0,start_rank-end_rank)*4+titles*100+wins*4)::numeric,
      jsonb_build_object('start_rank',start_rank,'end_rank',end_rank,'age',age_year,'titles',titles)
    from scored where start_rank>=75 and end_rank<=60 and coalesce(age_year,0)>=24 and coalesce(generated_year,0)<>p_season
    union all
    select 'best_server','Meilleur serveur',player_id,player_name,country,
      (service_score*10+aces/greatest(matches,1))::numeric,
      jsonb_build_object('service_score',round(service_score,2),'aces',aces,'matches',matches)
    from scored where end_rank<=300
    union all
    select 'best_returner','Meilleur retourneur',player_id,player_name,country,
      (return_score*10+top10_wins*3)::numeric,
      jsonb_build_object('return_score',round(return_score,2),'top10_wins',top10_wins,'matches',matches)
    from scored where end_rank<=300
    union all
    select 'best_clutch','Meilleur sous pression',player_id,player_name,country,
      (clutch_score*10+top10_wins*5+slams*100)::numeric,
      jsonb_build_object('clutch_score',round(clutch_score,2),'top10_wins',top10_wins,'slams',slams)
    from scored where end_rank<=300
    union all
    select 'best_u21','Meilleur U21',player_id,player_name,country,
      poy_score,jsonb_build_object('rank',end_rank,'age',age_year,'titles',titles)
    from scored where coalesce(age_year,99)<=21 and end_rank<=300
    union all
    select 'hard_player','Roi du dur',player_id,player_name,country,
      (hard_wins*10+hard_titles*140+slams*80)::numeric,
      jsonb_build_object('wins',hard_wins,'titles',hard_titles)
    from scored where hard_wins+hard_titles>0
    union all
    select 'clay_player','Roi de la terre',player_id,player_name,country,
      (clay_wins*10+clay_titles*140+slams*80)::numeric,
      jsonb_build_object('wins',clay_wins,'titles',clay_titles)
    from scored where clay_wins+clay_titles>0
    union all
    select 'grass_player','Roi du gazon',player_id,player_name,country,
      (grass_wins*10+grass_titles*170+slams*100)::numeric,
      jsonb_build_object('wins',grass_wins,'titles',grass_titles)
    from scored where grass_wins+grass_titles>0
  ),
  ranked as (
    select c.*,row_number() over(partition by award_code order by score desc,player_id) award_rank
    from candidates c
  ),
  team as (
    select p_season season,'team_of_year'::text award_code,'Équipe de l’année'::text award_name,
      row_number() over(order by poy_score desc,player_id)::int award_rank,
      player_id,player_name,country,poy_score score,
      jsonb_build_object('rank',end_rank,'titles',titles,'slams',slams,'masters',masters,'wins',wins) details
    from scored where end_rank<=200
    order by poy_score desc,player_id limit 8
  ),
  winners as (
    select p_season season,award_code,award_name,award_rank::int,player_id,player_name,country,score,details
    from ranked where award_rank=1
    union all
    select season,award_code,award_name,award_rank,player_id,player_name,country,score,details from team
  )
  insert into public.court_boss_player_awards(
    season,award_code,award_name,award_rank,player_id,player_name,country,score,details,source_type,source_label,updated_at
  )
  select season,award_code,award_name,award_rank,player_id,player_name,country,score,details,'career','Court Boss · moteur saison v1',now()
  from winners
  on conflict(season,award_code,award_rank) do update set
    award_name=excluded.award_name,player_id=excluded.player_id,player_name=excluded.player_name,
    country=excluded.country,score=excluded.score,details=excluded.details,source_type=excluded.source_type,
    source_label=excluded.source_label,updated_at=now();

  get diagnostics v_rows=row_count;
  return jsonb_build_object('ok',true,'season',p_season,'awards_upserted',v_rows,'model','CB-SEASON-AWARDS-v1');
end;
$function$;

revoke all on function public.finalize_court_boss_player_awards(integer) from public,anon,authenticated;
grant execute on function public.finalize_court_boss_player_awards(integer) to service_role;

create or replace function public.cb_awards_year_rollover_trigger()
returns trigger language plpgsql security definer set search_path to ''
as $function$
begin
  if old.career_date is not null and new.career_date is not null
     and extract(year from new.career_date)>extract(year from old.career_date) then
    perform public.finalize_court_boss_player_awards(extract(year from old.career_date)::int);
  end if;
  return new;
end;
$function$;

drop trigger if exists trg_cb_awards_year_rollover on public.career_state;
create trigger trg_cb_awards_year_rollover
after update of career_date on public.career_state
for each row execute function public.cb_awards_year_rollover_trigger();

update public.record_catalog
set baseline_value=14450, baseline_year=2023,
    description='Record ATP d’aces en carrière à la retraite de John Isner.',
    source_label='ATP Tour · retraite John Isner',
    source_url='https://www.atptour.com/en/news/isner',
    updated_at=now()
where code='career_aces_reference';

insert into public.record_catalog(
 code,category,subcategory,name,description,record_type,unit,baseline_value,baseline_holder,baseline_country,baseline_year,
 rarity,dynamic_rule,source_label,source_url,as_of_date,display_order,metadata
) values
('aces_match_record','Service','Match','Record d’aces sur un match','Record professionnel masculin documenté : 113 aces en un match.','numeric','aces',113,'John Isner','USA',2010,'mythic','aces_match','Guinness World Records','https://www.guinnessworldrecords.com/world-records/most-aces-served-in-a-professional-tennis-match',date '2025-12-01',151,'{"format":"all"}'),
('aces_bo3_match_record','Service','Match · BO3','Record d’aces sur un match en 2 sets gagnants','Record ATP en deux sets gagnants : 47 aces.','numeric','aces',47,'Milos Raonic','CAN',2024,'legendary','aces_match_bo3','Guinness World Records','https://www.guinnessworldrecords.com/world-records/397291-most-aces-served-in-an-atp-tennis-match-best-of-three-sets',date '2025-12-01',152,'{"format":"best_of_3"}'),
('aces_season_save','Service','Saison','Aces sur une saison','Meilleur total annuel généré dans la sauvegarde.','dynamic','aces',null,null,null,null,'elite','aces_season_save','Court Boss · sauvegarde','',date '2025-12-01',161,'{}'),
('aces_tournament_save','Service','Tournoi','Aces sur un tournoi','Meilleur total sur une édition de tournoi dans la sauvegarde.','dynamic','aces',null,null,null,null,'elite','aces_tournament_save','Court Boss · sauvegarde','',date '2025-12-01',162,'{}'),
('service_points_won_season_save','Service','Saison','% de points gagnés au service','Meilleure saison de la sauvegarde, avec volume minimum de points.','dynamic','%',null,null,null,null,'elite','service_points_won_season_save','Court Boss · sauvegarde','',date '2025-12-01',163,'{}'),
('return_points_won_season_save','Retour','Saison','% de points gagnés en retour','Le meilleur retourneur est calculé sur les points réellement/simulés, pas attribué à la main.','dynamic','%',null,null,null,null,'legendary','return_points_won_season_save','Court Boss · sauvegarde','',date '2025-12-01',180,'{}'),
('top10_wins_season_save','Retour','Top 10','Victoires contre le Top 10 sur une saison','Meilleur total annuel dans la sauvegarde.','dynamic','victoires',null,null,null,null,'elite','top10_wins_season_save','Court Boss · sauvegarde','',date '2025-12-01',181,'{}'),
('win_streak_save','Séries','Carrière','Plus longue série de victoires','Record de sauvegarde calculé match par match.','dynamic','victoires',null,null,null,null,'legendary','win_streak_save','Court Boss · sauvegarde','',date '2025-12-01',190,'{}'),
('hard_win_streak_save','Séries','Dur','Série de victoires sur dur','Record de sauvegarde sur dur.','dynamic','victoires',null,null,null,null,'elite','hard_win_streak_save','Court Boss · sauvegarde','',date '2025-12-01',191,'{}'),
('clay_win_streak_save','Séries','Terre','Série de victoires sur terre','Record de sauvegarde sur terre battue.','dynamic','victoires',null,null,null,null,'elite','clay_win_streak_save','Court Boss · sauvegarde','',date '2025-12-01',192,'{}'),
('grass_win_streak_save','Séries','Gazon','Série de victoires sur gazon','Record de sauvegarde sur gazon.','dynamic','victoires',null,null,null,null,'elite','grass_win_streak_save','Court Boss · sauvegarde','',date '2025-12-01',193,'{}'),
('tiebreak_wins_season_save','Séries','Tie-break','Tie-breaks gagnés sur une saison','Meilleur total annuel de tie-breaks gagnés.','dynamic','tie-breaks',null,null,null,null,'elite','tiebreak_wins_season_save','Court Boss · sauvegarde','',date '2025-12-01',194,'{}'),
('player_of_year_awards','Awards','Carrière','Joueur de l’année · record','Nombre de distinctions de joueur de l’année. Djokovic détient le record historique de huit fins de saison ATP n°1.','numeric','awards',8,'Novak Djokovic','SRB',2023,'mythic','player_of_year_awards','ATP Tour · Year-End No. 1','https://www.atptour.com/en/news/djokovic-year-end-no-1-2023',date '2025-12-01',300,'{}')
on conflict(code) do update set
 category=excluded.category,subcategory=excluded.subcategory,name=excluded.name,description=excluded.description,
 record_type=excluded.record_type,unit=excluded.unit,baseline_value=excluded.baseline_value,baseline_holder=excluded.baseline_holder,
 baseline_country=excluded.baseline_country,baseline_year=excluded.baseline_year,rarity=excluded.rarity,dynamic_rule=excluded.dynamic_rule,
 source_label=excluded.source_label,source_url=excluded.source_url,display_order=excluded.display_order,metadata=excluded.metadata,updated_at=now();
