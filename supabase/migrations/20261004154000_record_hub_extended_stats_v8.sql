-- Court Boss Records/Awards V8
-- Extend Record Hub progress with service/return/streak/awards stats.
-- Applied to Supabase on 2026-10-04.

create or replace function public.cb_longest_win_streak(
  p_player_id bigint,
  p_surface text default null,
  p_date date default current_date
)
returns integer
language sql
stable
set search_path to ''
as $function$
with ordered as (
  select s.id,s.match_date,s.won,
    row_number() over(order by s.match_date,s.id)
    - row_number() over(partition by s.won order by s.match_date,s.id) grp
  from public.court_boss_match_stat_lines s
  where s.player_id=p_player_id
    and s.match_date<=p_date
    and (
      p_surface is null
      or (p_surface='hard' and (lower(coalesce(s.surface,'')) like '%hard%' or lower(coalesce(s.surface,'')) like '%dur%'))
      or (p_surface='clay' and (lower(coalesce(s.surface,'')) like '%clay%' or lower(coalesce(s.surface,'')) like '%terre%'))
      or (p_surface='grass' and (lower(coalesce(s.surface,'')) like '%grass%' or lower(coalesce(s.surface,'')) like '%gazon%'))
    )
),
runs as (
  select grp,count(*)::int cnt from ordered where won group by grp
)
select coalesce(max(cnt),0) from runs;
$function$;

create or replace function public.cb_extended_record_progress(p_player_id bigint,p_date date)
returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $function$
declare
  v_pid bigint:=p_player_id;
  v_base_aces bigint:=0; v_career_aces bigint:=0;
  v_match_aces integer:=0; v_season_aces integer:=0; v_tournament_aces integer:=0;
  v_service_pct numeric:=0; v_return_pct numeric:=0;
  v_top10 integer:=0; v_tiebreak integer:=0;
  v_streak integer:=0; v_hard integer:=0; v_clay integer:=0; v_grass integer:=0;
  v_poy integer:=0;
begin
  if v_pid is null then
    select cs.managed_player_id into v_pid from public.career_state cs where cs.id='demo';
  end if;
  if v_pid is null then return '[]'::jsonb; end if;

  select coalesce(pcs.aces,0) into v_base_aces
  from public.player_career_stats pcs where pcs.player_id=v_pid;
  v_career_aces:=coalesce(v_base_aces,0)+coalesce((
    select sum(s.aces) from public.court_boss_match_stat_lines s
    where s.player_id=v_pid and s.match_date>date '2025-12-01' and s.match_date<=p_date
  ),0);

  select coalesce(max(s.aces),0) into v_match_aces
  from public.court_boss_match_stat_lines s where s.player_id=v_pid and s.match_date<=p_date;

  select coalesce(max(x.total_aces),0)::int into v_season_aces
  from (
    select s.season,sum(s.aces)::int total_aces
    from public.court_boss_match_stat_lines s
    where s.player_id=v_pid and s.match_date<=p_date group by s.season
  ) x;

  select coalesce(max(x.total_aces),0)::int into v_tournament_aces
  from (
    select s.season,coalesce(s.tournament_id,-s.source_id),sum(s.aces)::int total_aces
    from public.court_boss_match_stat_lines s
    where s.player_id=v_pid and s.match_date<=p_date
    group by s.season,coalesce(s.tournament_id,-s.source_id)
  ) x;

  select coalesce(max(x.pct),0) into v_service_pct
  from (
    select s.season,100.0*sum(s.service_points_won)/nullif(sum(s.service_points),0) pct
    from public.court_boss_match_stat_lines s
    where s.player_id=v_pid and s.match_date<=p_date
    group by s.season having sum(s.service_points)>=80
  ) x;

  select coalesce(max(x.pct),0) into v_return_pct
  from (
    select s.season,100.0*sum(s.return_points_won)/nullif(sum(s.return_points),0) pct
    from public.court_boss_match_stat_lines s
    where s.player_id=v_pid and s.match_date<=p_date
    group by s.season having sum(s.return_points)>=80
  ) x;

  select coalesce(max(x.cnt),0)::int into v_top10
  from (
    select s.season,count(*) filter(where s.won and coalesce(s.opponent_rank,9999)<=10)::int cnt
    from public.court_boss_match_stat_lines s
    where s.player_id=v_pid and s.match_date<=p_date group by s.season
  ) x;

  select coalesce(max(x.cnt),0)::int into v_tiebreak
  from (
    select s.season,sum(s.tiebreaks_won)::int cnt
    from public.court_boss_match_stat_lines s
    where s.player_id=v_pid and s.match_date<=p_date group by s.season
  ) x;

  v_streak:=public.cb_longest_win_streak(v_pid,null,p_date);
  v_hard:=public.cb_longest_win_streak(v_pid,'hard',p_date);
  v_clay:=public.cb_longest_win_streak(v_pid,'clay',p_date);
  v_grass:=public.cb_longest_win_streak(v_pid,'grass',p_date);

  select count(*)::int into v_poy
  from public.court_boss_player_awards a
  where a.player_id=v_pid and a.award_code='player_of_year' and a.award_rank=1;

  return jsonb_build_array(
    jsonb_build_object('code','career_aces_reference','value',v_career_aces,'target',14450,'achieved',v_career_aces>=14450,'label',v_career_aces||' aces'),
    jsonb_build_object('code','aces_match_record','value',v_match_aces,'target',113,'achieved',v_match_aces>=113,'label',v_match_aces||' / 113 aces'),
    jsonb_build_object('code','aces_season_save','value',v_season_aces,'target',null,'achieved',v_season_aces>0,'label',v_season_aces||' aces'),
    jsonb_build_object('code','aces_tournament_save','value',v_tournament_aces,'target',null,'achieved',v_tournament_aces>0,'label',v_tournament_aces||' aces'),
    jsonb_build_object('code','service_points_won_season_save','value',round(v_service_pct,2),'target',null,'achieved',v_service_pct>0,'label',round(v_service_pct,1)||' %'),
    jsonb_build_object('code','return_points_won_season_save','value',round(v_return_pct,2),'target',null,'achieved',v_return_pct>0,'label',round(v_return_pct,1)||' %'),
    jsonb_build_object('code','top10_wins_season_save','value',v_top10,'target',null,'achieved',v_top10>0,'label',v_top10||' victoires'),
    jsonb_build_object('code','win_streak_save','value',v_streak,'target',null,'achieved',v_streak>0,'label',v_streak||' victoires'),
    jsonb_build_object('code','hard_win_streak_save','value',v_hard,'target',null,'achieved',v_hard>0,'label',v_hard||' victoires'),
    jsonb_build_object('code','clay_win_streak_save','value',v_clay,'target',null,'achieved',v_clay>0,'label',v_clay||' victoires'),
    jsonb_build_object('code','grass_win_streak_save','value',v_grass,'target',null,'achieved',v_grass>0,'label',v_grass||' victoires'),
    jsonb_build_object('code','tiebreak_wins_season_save','value',v_tiebreak,'target',null,'achieved',v_tiebreak>0,'label',v_tiebreak||' tie-breaks'),
    jsonb_build_object('code','player_of_year_awards','value',v_poy,'target',8,'achieved',v_poy>=8,'label',v_poy||' awards')
  );
end;
$function$;

revoke all on function public.cb_extended_record_progress(bigint,date) from public,anon,authenticated;
grant execute on function public.cb_extended_record_progress(bigint,date) to service_role;

alter function public.court_boss_record_hub(bigint,date)
  rename to court_boss_record_hub_v7_base;

create or replace function public.court_boss_record_hub(
  p_player_id bigint default null::bigint,
  p_date date default date '2025-12-01'
)
returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $function$
declare
  v_base jsonb;
  v_pid bigint:=p_player_id;
  v_ext jsonb:='[]'::jsonb;
  v_old jsonb:='[]'::jsonb;
  v_filtered jsonb:='[]'::jsonb;
  v_managed jsonb:='{}'::jsonb;
  v_awards jsonb:='[]'::jsonb;
  v_replace text[]:=array[
    'career_aces_reference','aces_match_record','aces_season_save','aces_tournament_save',
    'service_points_won_season_save','return_points_won_season_save','top10_wins_season_save',
    'win_streak_save','hard_win_streak_save','clay_win_streak_save','grass_win_streak_save',
    'tiebreak_wins_season_save','player_of_year_awards'
  ];
begin
  v_base:=public.court_boss_record_hub_v7_base(p_player_id,p_date);
  v_pid:=coalesce(v_pid,nullif(v_base->'managed'->>'player_id','')::bigint);
  v_ext:=public.cb_extended_record_progress(v_pid,p_date);
  v_old:=coalesce(v_base->'managed'->'progress','[]'::jsonb);

  select coalesce(jsonb_agg(x),'[]'::jsonb) into v_filtered
  from jsonb_array_elements(v_old) x
  where not ((x->>'code')=any(v_replace));

  v_managed:=coalesce(v_base->'managed','{}'::jsonb)
    ||jsonb_build_object('progress',coalesce(v_filtered,'[]'::jsonb)||coalesce(v_ext,'[]'::jsonb));

  select coalesce(jsonb_agg(to_jsonb(a) order by a.season desc,a.award_code,a.award_rank),'[]'::jsonb)
  into v_awards
  from (
    select * from public.court_boss_player_awards
    where season<=extract(year from p_date)::int
    order by season desc,award_code,award_rank
    limit 120
  ) a;

  return (v_base-'managed')
    ||jsonb_build_object(
      'managed',v_managed,
      'awards',v_awards,
      'stat_model',jsonb_build_object(
        'live','actual point events',
        'world','deterministic attribute-derived boxscores',
        'version','CB-RECORDS-AWARDS-v8'
      )
    );
end;
$function$;

revoke all on function public.court_boss_record_hub(bigint,date) from public,anon,authenticated;
grant execute on function public.court_boss_record_hub(bigint,date) to service_role;
