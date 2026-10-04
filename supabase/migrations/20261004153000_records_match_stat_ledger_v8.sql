-- Court Boss Records/Awards V8
-- Match stat ledger: exact live point data + deterministic world boxscores.
-- Applied to Supabase project qrsvliliezbiedmaewml on 2026-10-04.

create table if not exists public.court_boss_match_stat_lines (
  id bigserial primary key,
  source_kind text not null check (source_kind in ('world','live')),
  source_id bigint not null,
  world_match_id bigint,
  tournament_id bigint,
  player_id bigint not null references public.players(id) on delete cascade,
  opponent_id bigint references public.players(id) on delete set null,
  match_date date not null,
  season integer not null,
  surface text,
  category text,
  round_code text,
  score text,
  won boolean not null default false,
  opponent_rank integer,
  service_points integer not null default 0,
  service_points_won integer not null default 0,
  first_serves integer not null default 0,
  first_serves_in integer not null default 0,
  aces integer not null default 0,
  double_faults integer not null default 0,
  return_points integer not null default 0,
  return_points_won integer not null default 0,
  tiebreaks_played integer not null default 0,
  tiebreaks_won integer not null default 0,
  model_version text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (source_kind, source_id, player_id)
);

create index if not exists cb_match_stat_player_season_idx
  on public.court_boss_match_stat_lines(player_id, season, match_date);
create index if not exists cb_match_stat_season_idx
  on public.court_boss_match_stat_lines(season, player_id);
create index if not exists cb_match_stat_world_idx
  on public.court_boss_match_stat_lines(world_match_id) where world_match_id is not null;

alter table public.court_boss_match_stat_lines enable row level security;
revoke all on public.court_boss_match_stat_lines from public, anon, authenticated;
grant select, insert, update, delete on public.court_boss_match_stat_lines to service_role;
grant usage, select on sequence public.court_boss_match_stat_lines_id_seq to service_role;

create or replace function public.cb_score_summary(p_score text)
returns jsonb
language plpgsql
immutable
set search_path to ''
as $function$
declare
  v_clean text := regexp_replace(coalesce(p_score,''), '[(][^)]*[)]|[[][^]]*[]]', '', 'g');
  v_match text[];
  v_games integer := 0;
  v_tb integer := 0;
  v_a_tb integer := 0;
  v_b_tb integer := 0;
begin
  for v_match in select regexp_matches(v_clean, '([0-9]+)-([0-9]+)', 'g')
  loop
    v_games := v_games + coalesce(v_match[1]::int,0) + coalesce(v_match[2]::int,0);
    if v_match[1]::int=7 and v_match[2]::int=6 then
      v_tb:=v_tb+1; v_a_tb:=v_a_tb+1;
    elsif v_match[1]::int=6 and v_match[2]::int=7 then
      v_tb:=v_tb+1; v_b_tb:=v_b_tb+1;
    end if;
  end loop;
  return jsonb_build_object('games',greatest(v_games,0),'tiebreaks',v_tb,'a_tiebreaks_won',v_a_tb,'b_tiebreaks_won',v_b_tb);
end;
$function$;

create or replace function public.cb_record_world_match_stat_lines(p_match_id bigint)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  w public.world_tournament_matches%rowtype;
  t public.tournaments%rowtype;
  a public.player_attributes%rowtype;
  b public.player_attributes%rowtype;
  pa public.players%rowtype;
  pb public.players%rowtype;
  ss jsonb;
  v_games integer;
  v_points integer;
  v_a_sp integer; v_b_sp integer; v_a_spw integer; v_b_spw integer;
  v_a_fs integer; v_b_fs integer; v_a_fsin integer; v_b_fsin integer;
  v_a_aces integer; v_b_aces integer; v_a_df integer; v_b_df integer;
  v_speed numeric; v_a_srv numeric; v_b_srv numeric; v_a_ret numeric; v_b_ret numeric;
  v_a_pct numeric; v_b_pct numeric; v_a_ace_rate numeric; v_b_ace_rate numeric;
  v_a_df_rate numeric; v_b_df_rate numeric; v_noise_a numeric; v_noise_b numeric;
  v_date date;
begin
  select * into w from public.world_tournament_matches where id=p_match_id;
  if w.id is null or w.winner_id is null or w.player_a_id is null or w.player_b_id is null then
    return jsonb_build_object('ok',false,'reason','match_not_completed');
  end if;

  if coalesce(w.matchup_components->>'source','')='managed_live'
     or nullif(w.matchup_components->>'live_session_id','') is not null then
    return jsonb_build_object('ok',true,'skipped','managed_live');
  end if;

  select * into t from public.tournaments where id=w.tournament_id;
  select * into a from public.player_attributes where player_id=w.player_a_id;
  select * into b from public.player_attributes where player_id=w.player_b_id;
  select * into pa from public.players where id=w.player_a_id;
  select * into pb from public.players where id=w.player_b_id;

  ss:=public.cb_score_summary(w.score);
  v_games:=greatest(coalesce((ss->>'games')::int,0),16);
  v_points:=greatest(72,round(v_games*6.2)::int);
  v_noise_a:=(abs(mod(hashtextextended('sp-a:'||w.id::text,0),11))-5)::numeric;
  v_noise_b:=(abs(mod(hashtextextended('sp-b:'||w.id::text,0),11))-5)::numeric;
  v_a_sp:=greatest(25,round(v_points/2.0+v_noise_a)::int);
  v_b_sp:=greatest(25,v_points-v_a_sp);

  v_speed:=coalesce(w.court_speed,t.court_speed,1.0);
  v_a_srv:=(coalesce(a.serve_power,50)+coalesce(a.first_serve_quality,50)+coalesce(a.serve_precision,50)+coalesce(a.serve_consistency,50))/4.0;
  v_b_srv:=(coalesce(b.serve_power,50)+coalesce(b.first_serve_quality,50)+coalesce(b.serve_precision,50)+coalesce(b.serve_consistency,50))/4.0;
  v_a_ret:=(coalesce(a.return_game,50)+coalesce(a.return_consistency,50)+coalesce(a.return_aggression,50)+coalesce(a.anticipation,50))/4.0;
  v_b_ret:=(coalesce(b.return_game,50)+coalesce(b.return_consistency,50)+coalesce(b.return_aggression,50)+coalesce(b.anticipation,50))/4.0;

  v_a_pct:=greatest(.46,least(.86,.61+(v_a_srv-50)*.0021-(v_b_ret-50)*.0015+(v_speed-1)*.045
    +case when w.winner_id=w.player_a_id then .018 else -.012 end
    +(abs(mod(hashtextextended('srv-a:'||w.id::text,1),101))-50)/10000.0));
  v_b_pct:=greatest(.46,least(.86,.61+(v_b_srv-50)*.0021-(v_a_ret-50)*.0015+(v_speed-1)*.045
    +case when w.winner_id=w.player_b_id then .018 else -.012 end
    +(abs(mod(hashtextextended('srv-b:'||w.id::text,1),101))-50)/10000.0));

  v_a_spw:=greatest(0,least(v_a_sp,round(v_a_sp*v_a_pct)::int));
  v_b_spw:=greatest(0,least(v_b_sp,round(v_b_sp*v_b_pct)::int));
  v_a_fs:=v_a_sp; v_b_fs:=v_b_sp;
  v_a_fsin:=round(v_a_fs*greatest(.48,least(.78,.61+(coalesce(a.serve_precision,50)-50)*.0022+(coalesce(a.serve_consistency,50)-50)*.0013)))::int;
  v_b_fsin:=round(v_b_fs*greatest(.48,least(.78,.61+(coalesce(b.serve_precision,50)-50)*.0022+(coalesce(b.serve_consistency,50)-50)*.0013)))::int;

  v_a_ace_rate:=greatest(.004,least(.24,.035+(coalesce(a.serve_power,50)-50)*.0015+(coalesce(a.first_serve_quality,50)-50)*.0008
    +(v_speed-1)*.08-(coalesce(b.return_game,50)-50)*.00035));
  v_b_ace_rate:=greatest(.004,least(.24,.035+(coalesce(b.serve_power,50)-50)*.0015+(coalesce(b.first_serve_quality,50)-50)*.0008
    +(v_speed-1)*.08-(coalesce(a.return_game,50)-50)*.00035));
  v_a_df_rate:=greatest(.012,least(.115,.052-(coalesce(a.second_serve_quality,50)-50)*.00065-(coalesce(a.serve_consistency,50)-50)*.00045));
  v_b_df_rate:=greatest(.012,least(.115,.052-(coalesce(b.second_serve_quality,50)-50)*.00065-(coalesce(b.serve_consistency,50)-50)*.00045));
  v_a_aces:=greatest(0,round(v_a_sp*v_a_ace_rate+(abs(mod(hashtextextended('ace-a:'||w.id::text,2),5))-2))::int);
  v_b_aces:=greatest(0,round(v_b_sp*v_b_ace_rate+(abs(mod(hashtextextended('ace-b:'||w.id::text,2),5))-2))::int);
  v_a_df:=greatest(0,round(v_a_sp*v_a_df_rate+(abs(mod(hashtextextended('df-a:'||w.id::text,3),3))-1))::int);
  v_b_df:=greatest(0,round(v_b_sp*v_b_df_rate+(abs(mod(hashtextextended('df-b:'||w.id::text,3),3))-1))::int);
  v_date:=coalesce(w.simulated_on,t.end_date,t.start_date,current_date);

  insert into public.court_boss_match_stat_lines(
    source_kind,source_id,world_match_id,tournament_id,player_id,opponent_id,match_date,season,
    surface,category,round_code,score,won,opponent_rank,
    service_points,service_points_won,first_serves,first_serves_in,aces,double_faults,
    return_points,return_points_won,tiebreaks_played,tiebreaks_won,model_version,metadata
  )
  values
  ('world',w.id,w.id,w.tournament_id,w.player_a_id,w.player_b_id,v_date,extract(year from v_date)::int,
   coalesce(t.surface,'Dur'),coalesce(t.category,t.level),w.round_code,w.score,w.winner_id=w.player_a_id,pb.ranking,
   v_a_sp,v_a_spw,v_a_fs,v_a_fsin,v_a_aces,v_a_df,v_b_sp,v_b_sp-v_b_spw,
   coalesce((ss->>'tiebreaks')::int,0),coalesce((ss->>'a_tiebreaks_won')::int,0),
   'CB-WORLD-BOXSCORE-v1',jsonb_build_object('derived_from','attributes+score','court_speed',v_speed)),
  ('world',w.id,w.id,w.tournament_id,w.player_b_id,w.player_a_id,v_date,extract(year from v_date)::int,
   coalesce(t.surface,'Dur'),coalesce(t.category,t.level),w.round_code,public.world_invert_tennis_score(coalesce(w.score,'')),w.winner_id=w.player_b_id,pa.ranking,
   v_b_sp,v_b_spw,v_b_fs,v_b_fsin,v_b_aces,v_b_df,v_a_sp,v_a_sp-v_a_spw,
   coalesce((ss->>'tiebreaks')::int,0),coalesce((ss->>'b_tiebreaks_won')::int,0),
   'CB-WORLD-BOXSCORE-v1',jsonb_build_object('derived_from','attributes+score','court_speed',v_speed))
  on conflict(source_kind,source_id,player_id) do update set
    match_date=excluded.match_date,season=excluded.season,surface=excluded.surface,category=excluded.category,
    round_code=excluded.round_code,score=excluded.score,won=excluded.won,opponent_rank=excluded.opponent_rank,
    service_points=excluded.service_points,service_points_won=excluded.service_points_won,
    first_serves=excluded.first_serves,first_serves_in=excluded.first_serves_in,
    aces=excluded.aces,double_faults=excluded.double_faults,return_points=excluded.return_points,
    return_points_won=excluded.return_points_won,tiebreaks_played=excluded.tiebreaks_played,
    tiebreaks_won=excluded.tiebreaks_won,model_version=excluded.model_version,
    metadata=excluded.metadata,updated_at=now();

  return jsonb_build_object('ok',true,'match_id',w.id,'players',2,'model','CB-WORLD-BOXSCORE-v1');
end;
$function$;

revoke all on function public.cb_record_world_match_stat_lines(bigint) from public,anon,authenticated;
grant execute on function public.cb_record_world_match_stat_lines(bigint) to service_role;

create or replace function public.cb_world_match_stat_lines_trigger()
returns trigger language plpgsql security definer set search_path to ''
as $function$
begin
  if new.winner_id is not null and (old.winner_id is null or old.winner_id is distinct from new.winner_id) then
    perform public.cb_record_world_match_stat_lines(new.id);
  end if;
  return new;
end;
$function$;

drop trigger if exists trg_cb_world_match_stat_lines on public.world_tournament_matches;
create trigger trg_cb_world_match_stat_lines
after update of winner_id on public.world_tournament_matches
for each row execute function public.cb_world_match_stat_lines_trigger();

create or replace function public.cb_record_live_match_stat_lines(p_session_id bigint)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  s public.live_match_sessions%rowtype;
  t public.tournaments%rowtype;
  v_world_id bigint;
  v_world public.world_tournament_matches%rowtype;
  v_date date; v_score text; v_round text; v_winner bigint; v_ss jsonb;
  r record;
begin
  select * into s from public.live_match_sessions where id=p_session_id;
  if s.id is null or s.managed_player_id is null or s.opponent_id is null then
    return jsonb_build_object('ok',false,'reason','session_not_found');
  end if;
  v_world_id:=nullif(s.stats->'_meta'->>'world_match_id','')::bigint;
  if v_world_id is not null then select * into v_world from public.world_tournament_matches where id=v_world_id; end if;
  if s.tournament_id is not null then select * into t from public.tournaments where id=s.tournament_id; end if;
  v_date:=coalesce(v_world.simulated_on,(select cs.career_date from public.career_state cs where cs.id='demo'),current_date);
  v_score:=coalesce(v_world.score,'');
  v_round:=coalesce(v_world.round_code,s.stats->'_meta'->>'round','');
  v_winner:=case when s.user_sets>s.opponent_sets then s.managed_player_id else s.opponent_id end;
  v_ss:=public.cb_score_summary(v_score);

  for r in
    with participants as (
      select s.managed_player_id::bigint player_id,s.opponent_id::bigint opponent_id,1 side
      union all select s.opponent_id::bigint,s.managed_player_id::bigint,2
    )
    select pp.player_id,pp.opponent_id,pp.side,
      (select ranking from public.players where id=pp.opponent_id)::int opponent_rank,
      count(e.*) filter(where e.server_id=pp.player_id)::int service_points,
      count(e.*) filter(where e.server_id=pp.player_id and e.winner_id=pp.player_id)::int service_points_won,
      count(e.*) filter(where e.server_id=pp.player_id)::int first_serves,
      count(e.*) filter(where e.server_id=pp.player_id and e.first_serve_in)::int first_serves_in,
      count(e.*) filter(where e.server_id=pp.player_id and e.ace)::int aces,
      count(e.*) filter(where e.server_id=pp.player_id and e.double_fault)::int double_faults,
      count(e.*) filter(where e.returner_id=pp.player_id)::int return_points,
      count(e.*) filter(where e.returner_id=pp.player_id and e.winner_id=pp.player_id)::int return_points_won
    from participants pp
    left join public.live_match_point_events e on e.session_id=p_session_id
    group by pp.player_id,pp.opponent_id,pp.side
  loop
    insert into public.court_boss_match_stat_lines(
      source_kind,source_id,world_match_id,tournament_id,player_id,opponent_id,match_date,season,
      surface,category,round_code,score,won,opponent_rank,service_points,service_points_won,
      first_serves,first_serves_in,aces,double_faults,return_points,return_points_won,
      tiebreaks_played,tiebreaks_won,model_version,metadata
    ) values (
      'live',s.id,v_world_id,s.tournament_id,r.player_id,r.opponent_id,v_date,extract(year from v_date)::int,
      coalesce(t.surface,s.surface,'Dur'),coalesce(t.category,t.level,'Live'),v_round,v_score,r.player_id=v_winner,r.opponent_rank,
      r.service_points,r.service_points_won,r.first_serves,r.first_serves_in,r.aces,r.double_faults,
      r.return_points,r.return_points_won,coalesce((v_ss->>'tiebreaks')::int,0),
      case when r.side=1 then coalesce((v_ss->>'a_tiebreaks_won')::int,0)
           else coalesce((v_ss->>'b_tiebreaks_won')::int,0) end,
      'CB-LIVE-BOXSCORE-v1',jsonb_build_object('actual_point_events',true)
    )
    on conflict(source_kind,source_id,player_id) do update set
      world_match_id=excluded.world_match_id,tournament_id=excluded.tournament_id,match_date=excluded.match_date,
      season=excluded.season,surface=excluded.surface,category=excluded.category,round_code=excluded.round_code,
      score=excluded.score,won=excluded.won,opponent_rank=excluded.opponent_rank,
      service_points=excluded.service_points,service_points_won=excluded.service_points_won,
      first_serves=excluded.first_serves,first_serves_in=excluded.first_serves_in,
      aces=excluded.aces,double_faults=excluded.double_faults,return_points=excluded.return_points,
      return_points_won=excluded.return_points_won,tiebreaks_played=excluded.tiebreaks_played,
      tiebreaks_won=excluded.tiebreaks_won,model_version=excluded.model_version,
      metadata=excluded.metadata,updated_at=now();
  end loop;
  return jsonb_build_object('ok',true,'session_id',p_session_id,'players',2,'model','CB-LIVE-BOXSCORE-v1');
end;
$function$;

revoke all on function public.cb_record_live_match_stat_lines(bigint) from public,anon,authenticated;
grant execute on function public.cb_record_live_match_stat_lines(bigint) to service_role;

create or replace function public.cb_live_match_stat_lines_trigger()
returns trigger language plpgsql security definer set search_path to ''
as $function$
begin
  perform public.cb_record_live_match_stat_lines(new.session_id);
  return new;
end;
$function$;

drop trigger if exists trg_cb_live_match_stat_lines on public.advanced_analytics_processed_sessions;
create trigger trg_cb_live_match_stat_lines
after insert on public.advanced_analytics_processed_sessions
for each row execute function public.cb_live_match_stat_lines_trigger();
