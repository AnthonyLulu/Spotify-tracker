-- Court Boss season engine v2
-- 2026-09-29
-- Additive migration after 20260929210000_full_season_engine_v1.sql.
-- Captures NCAA/UTR, ITF Junior qualifying 2026 and Junior Davis Cup world simulation.

alter table public.college_duals
  add column if not exists surface text default 'Dur',
  add column if not exists indoor boolean default false,
  add column if not exists source_tournament_id bigint references public.tournaments(id) on delete set null,
  add column if not exists event_match_key text;

alter table public.junior_davis_rubbers
  add column if not exists sets_home integer not null default 0,
  add column if not exists sets_away integer not null default 0,
  add column if not exists games_home integer not null default 0,
  add column if not exists games_away integer not null default 0;

create table if not exists public.player_utr_state(
  player_id bigint primary key references public.players(id) on delete cascade,
  current_rating numeric(5,2) not null,
  match_count integer not null default 0,
  updated_at timestamptz not null default now(),
  source_label text not null default 'Court Boss UTR-like dynamic model'
);

create table if not exists public.ncaa_utr_rating_history(
  id bigserial primary key,
  player_id bigint not null references public.players(id) on delete cascade,
  rating_date date not null,
  tournament_id bigint references public.tournaments(id) on delete set null,
  dual_id bigint references public.college_duals(id) on delete set null,
  opponent_id bigint references public.players(id) on delete set null,
  old_rating numeric(5,2) not null,
  new_rating numeric(5,2) not null,
  delta numeric(6,3) not null,
  result text not null,
  model_version text not null default 'CB-UTR-v1',
  created_at timestamptz not null default now()
);

create table if not exists public.college_dual_rubbers(
  id bigserial primary key,
  dual_id bigint not null references public.college_duals(id) on delete cascade,
  rubber_no integer not null,
  rubber_type text not null,
  court_no integer not null,
  home_player_ids bigint[] not null default '{}',
  away_player_ids bigint[] not null default '{}',
  winner_team_id bigint references public.college_teams(id),
  score text,
  status text not null default 'completed',
  home_win_probability numeric,
  model_version text not null default 'CB-NCAA-DUAL-v3',
  unique(dual_id,rubber_type,court_no)
);

create table if not exists public.ncaa_individual_entries(
  tournament_id bigint not null references public.tournaments(id) on delete cascade,
  player_id bigint not null references public.players(id) on delete cascade,
  discipline text not null default 'singles',
  initial_phase text not null default 'main',
  seed integer,
  draw_position integer,
  entry_type text not null default 'selection',
  result_code text,
  wins integer not null default 0,
  losses integer not null default 0,
  points_earned integer not null default 0,
  utr_delta numeric not null default 0,
  selected_at timestamptz not null default now(),
  primary key(tournament_id,discipline,player_id)
);

create table if not exists public.ncaa_individual_doubles_entries(
  id bigserial primary key,
  tournament_id bigint not null references public.tournaments(id) on delete cascade,
  player_a_id bigint not null references public.players(id) on delete cascade,
  player_b_id bigint not null references public.players(id) on delete cascade,
  initial_phase text not null default 'main',
  seed integer,
  result_code text,
  wins integer not null default 0,
  losses integer not null default 0,
  points_earned integer not null default 0,
  selected_at timestamptz not null default now(),
  check(player_a_id<player_b_id),
  unique(tournament_id,player_a_id,player_b_id)
);

create table if not exists public.ncaa_individual_matches(
  id bigserial primary key,
  tournament_id bigint not null references public.tournaments(id) on delete cascade,
  discipline text not null,
  phase text not null default 'main',
  round_index integer not null,
  round_code text not null,
  match_no integer not null,
  side_a_player_ids bigint[] not null,
  side_b_player_ids bigint[] not null,
  winner_player_ids bigint[],
  loser_player_ids bigint[],
  score text,
  home_win_probability numeric,
  played_on date not null,
  model_version text not null default 'CB-NCAA-IND-v1',
  unique(tournament_id,discipline,phase,round_index,match_no)
);

create table if not exists public.ncaa_individual_qualifiers(
  id bigserial primary key,
  season integer not null,
  discipline text not null,
  player_ids bigint[] not null,
  source_tournament_id bigint not null references public.tournaments(id) on delete cascade,
  qualification_reason text not null,
  qualified_on date not null,
  unique(season,discipline,player_ids)
);

create table if not exists public.ncaa_individual_points(
  player_id bigint not null references public.players(id) on delete cascade,
  season integer not null,
  points integer not null default 0,
  wins integer not null default 0,
  losses integer not null default 0,
  titles integer not null default 0,
  updated_at timestamptz not null default now(),
  primary key(player_id,season)
);

create table if not exists public.ncaa_doubles_pair_points(
  player_a_id bigint not null references public.players(id) on delete cascade,
  player_b_id bigint not null references public.players(id) on delete cascade,
  season integer not null,
  points integer not null default 0,
  wins integer not null default 0,
  losses integer not null default 0,
  titles integer not null default 0,
  updated_at timestamptz not null default now(),
  check(player_a_id<player_b_id),
  primary key(player_a_id,player_b_id,season)
);

create table if not exists public.ncaa_individual_simulations(
  tournament_id bigint primary key references public.tournaments(id) on delete cascade,
  status text not null default 'completed',
  simulated_on date not null,
  singles_entries integer not null default 0,
  doubles_entries integer not null default 0,
  model_version text not null default 'CB-NCAA-IND-v1',
  created_at timestamptz not null default now()
);

create table if not exists public.junior_entry_reservations(
  tournament_id bigint not null references public.tournaments(id) on delete cascade,
  player_id bigint not null references public.players(id) on delete cascade,
  entry_method text not null,
  reserved_on date not null,
  model_version text not null default 'CB-JUNIOR-ENTRY-v1',
  primary key(tournament_id,player_id)
);

create table if not exists public.junior_davis_nations(
  season integer not null,
  tournament_id bigint not null references public.tournaments(id) on delete cascade,
  nation text not null,
  seed integer,
  group_name text not null default '',
  qualified_as text not null default 'simulated_regional_qualifier',
  strength numeric,
  created_at timestamptz not null default now(),
  primary key(season,tournament_id,nation)
);

create table if not exists public.junior_davis_squads(
  season integer not null,
  tournament_id bigint not null references public.tournaments(id) on delete cascade,
  nation text not null,
  player_id bigint not null references public.players(id) on delete cascade,
  squad_order integer not null,
  selected_on date not null,
  primary key(season,tournament_id,nation,player_id),
  unique(season,tournament_id,nation,squad_order)
);

create table if not exists public.junior_davis_ties(
  id bigserial primary key,
  tournament_id bigint not null references public.tournaments(id) on delete cascade,
  season integer not null,
  stage text not null,
  group_name text not null default '',
  bracket_slot integer not null,
  tie_date date not null,
  home_nation text not null,
  away_nation text not null,
  status text not null default 'scheduled',
  home_score integer,
  away_score integer,
  winner_nation text,
  loser_nation text,
  source_label text not null default 'Court Boss Junior Davis Cup simulation',
  unique(tournament_id,stage,group_name,bracket_slot)
);

create table if not exists public.junior_davis_rubbers(
  id bigserial primary key,
  tie_id bigint not null references public.junior_davis_ties(id) on delete cascade,
  rubber_no integer not null,
  rubber_type text not null,
  home_player_ids bigint[] not null,
  away_player_ids bigint[] not null,
  winner_nation text,
  score text,
  home_win_probability numeric,
  status text not null default 'completed',
  model_version text not null default 'CB-JDC-v1',
  sets_home integer not null default 0,
  sets_away integer not null default 0,
  games_home integer not null default 0,
  games_away integer not null default 0,
  unique(tie_id,rubber_no)
);

create table if not exists public.junior_davis_history(
  season integer primary key,
  champion_nation text not null,
  runner_up_nation text,
  third_nation text,
  venue text,
  source_label text not null default 'Court Boss simulated Junior Davis Cup',
  created_at timestamptz not null default now()
);

alter table public.player_utr_state enable row level security;
alter table public.ncaa_utr_rating_history enable row level security;
alter table public.college_dual_rubbers enable row level security;
alter table public.ncaa_individual_entries enable row level security;
alter table public.ncaa_individual_doubles_entries enable row level security;
alter table public.ncaa_individual_matches enable row level security;
alter table public.ncaa_individual_qualifiers enable row level security;
alter table public.ncaa_individual_points enable row level security;
alter table public.ncaa_doubles_pair_points enable row level security;
alter table public.ncaa_individual_simulations enable row level security;
alter table public.junior_entry_reservations enable row level security;
alter table public.junior_davis_nations enable row level security;
alter table public.junior_davis_squads enable row level security;
alter table public.junior_davis_ties enable row level security;
alter table public.junior_davis_rubbers enable row level security;
alter table public.junior_davis_history enable row level security;

create index if not exists ncaa_utr_history_player_date_idx
  on public.ncaa_utr_rating_history(player_id,rating_date desc);
create index if not exists college_dual_rubbers_dual_idx
  on public.college_dual_rubbers(dual_id,rubber_no);
create index if not exists ncaa_individual_entries_player_idx
  on public.ncaa_individual_entries(player_id,tournament_id);
create index if not exists ncaa_individual_matches_tournament_idx
  on public.ncaa_individual_matches(tournament_id,discipline,phase,round_index);
create index if not exists junior_entry_reservations_player_idx
  on public.junior_entry_reservations(player_id,tournament_id);
create index if not exists junior_davis_squads_player_idx
  on public.junior_davis_squads(player_id,tournament_id);
create index if not exists junior_davis_ties_due_idx
  on public.junior_davis_ties(status,tie_date);

update public.tournaments
set is_active=false
where circuit='NCAA'
  and coalesce(source_note,'') ilike '%legacy simulation hidden%';


CREATE OR REPLACE FUNCTION public.advance_junior_davis_bracket(p_tournament_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  v_year int;
  a1 text;a2 text;a3 text;a4 text;
  b1 text;b2 text;b3 text;b4 text;
  c1 text;c2 text;c3 text;c4 text;
  d1 text;d2 text;d3 text;d4 text;
  x1 text;x2 text;x3 text;x4 text;
  y1 text;y2 text;y3 text;y4 text;
  created int:=0;
  champ text;
  runner text;
  third text;
begin
  select * into t from public.tournaments where id=p_tournament_id;
  if t.id is null then return jsonb_build_object('created',0,'reason','not_found'); end if;
  v_year:=extract(year from t.start_date)::int;

  if (select count(*) from public.junior_davis_ties
      where tournament_id=t.id and stage='Group' and status='completed')=24
     and not exists(select 1 from public.junior_davis_ties where tournament_id=t.id and stage='QF') then

    drop table if exists pg_temp.cb_jdc_standings;
    create temporary table cb_jdc_standings on commit drop as
    with base as (
      select
        n.group_name,n.nation,n.strength,
        count(j.id) filter(where j.winner_nation=n.nation) tie_wins,
        count(j.id) filter(where j.loser_nation=n.nation) tie_losses,
        coalesce(sum(case when j.home_nation=n.nation then j.home_score else j.away_score end),0)::int match_wins,
        coalesce(sum(case when j.home_nation=n.nation then j.away_score else j.home_score end),0)::int match_losses,
        coalesce(sum(case when j.home_nation=n.nation then r.sets_home else r.sets_away end),0)::int sets_won,
        coalesce(sum(case when j.home_nation=n.nation then r.sets_away else r.sets_home end),0)::int sets_lost,
        coalesce(sum(case when j.home_nation=n.nation then r.games_home else r.games_away end),0)::int games_won,
        coalesce(sum(case when j.home_nation=n.nation then r.games_away else r.games_home end),0)::int games_lost
      from public.junior_davis_nations n
      left join public.junior_davis_ties j
        on j.tournament_id=n.tournament_id
       and j.stage='Group'
       and n.nation in (j.home_nation,j.away_nation)
       and j.status='completed'
      left join public.junior_davis_rubbers r
        on r.tie_id=j.id and r.status='completed'
      where n.tournament_id=t.id
      group by n.group_name,n.nation,n.strength
    ),
    tied as (
      select b.*,
        count(*) over(partition by group_name,tie_wins)::int tied_count
      from base b
    ),
    ranked_inputs as (
      select x.*,
        case
          when x.tied_count=2 then coalesce((
            select case when j.winner_nation=x.nation then 1 else 0 end
            from public.junior_davis_ties j
            join tied o
              on o.group_name=x.group_name
             and o.tie_wins=x.tie_wins
             and o.nation<>x.nation
            where j.tournament_id=t.id
              and j.stage='Group'
              and j.status='completed'
              and x.nation in (j.home_nation,j.away_nation)
              and o.nation in (j.home_nation,j.away_nation)
            limit 1
          ),0)
          else 0
        end h2h_win,
        case when x.sets_won+x.sets_lost>0
             then x.sets_won::numeric/(x.sets_won+x.sets_lost) else 0 end set_pct,
        case when x.games_won+x.games_lost>0
             then x.games_won::numeric/(x.games_won+x.games_lost) else 0 end game_pct
      from tied x
    )
    select *,
      row_number() over(
        partition by group_name
        order by
          tie_wins desc,
          case when tied_count=2 then h2h_win else 0 end desc,
          case when tied_count>=3 then match_wins else 0 end desc,
          case when tied_count>=3 then set_pct else 0 end desc,
          case when tied_count>=3 then game_pct else 0 end desc,
          strength desc,nation
      )::int group_pos
    from ranked_inputs;

    select
      max(nation) filter(where group_name='A' and group_pos=1),
      max(nation) filter(where group_name='A' and group_pos=2),
      max(nation) filter(where group_name='A' and group_pos=3),
      max(nation) filter(where group_name='A' and group_pos=4),
      max(nation) filter(where group_name='B' and group_pos=1),
      max(nation) filter(where group_name='B' and group_pos=2),
      max(nation) filter(where group_name='B' and group_pos=3),
      max(nation) filter(where group_name='B' and group_pos=4),
      max(nation) filter(where group_name='C' and group_pos=1),
      max(nation) filter(where group_name='C' and group_pos=2),
      max(nation) filter(where group_name='C' and group_pos=3),
      max(nation) filter(where group_name='C' and group_pos=4),
      max(nation) filter(where group_name='D' and group_pos=1),
      max(nation) filter(where group_name='D' and group_pos=2),
      max(nation) filter(where group_name='D' and group_pos=3),
      max(nation) filter(where group_name='D' and group_pos=4)
    into a1,a2,a3,a4,b1,b2,b3,b4,c1,c2,c3,c4,d1,d2,d3,d4
    from cb_jdc_standings;

    insert into public.junior_davis_ties(
      tournament_id,season,stage,group_name,bracket_slot,tie_date,home_nation,away_nation
    ) values
      (t.id,v_year,'QF','',1,t.start_date+4,a1,c2),
      (t.id,v_year,'QF','',2,t.start_date+4,b1,d2),
      (t.id,v_year,'QF','',3,t.start_date+4,c1,a2),
      (t.id,v_year,'QF','',4,t.start_date+4,d1,b2),
      (t.id,v_year,'P9-QF','',1,t.start_date+4,a3,c4),
      (t.id,v_year,'P9-QF','',2,t.start_date+4,b3,d4),
      (t.id,v_year,'P9-QF','',3,t.start_date+4,c3,a4),
      (t.id,v_year,'P9-QF','',4,t.start_date+4,d3,b4);
    created:=created+8;
  end if;

  if (select count(*) from public.junior_davis_ties
      where tournament_id=t.id and stage='QF' and status='completed')=4
     and (select count(*) from public.junior_davis_ties
      where tournament_id=t.id and stage='P9-QF' and status='completed')=4
     and not exists(select 1 from public.junior_davis_ties where tournament_id=t.id and stage='SF') then

    select winner_nation,loser_nation into x1,y1
      from public.junior_davis_ties where tournament_id=t.id and stage='QF' and bracket_slot=1;
    select winner_nation,loser_nation into x2,y2
      from public.junior_davis_ties where tournament_id=t.id and stage='QF' and bracket_slot=2;
    select winner_nation,loser_nation into x3,y3
      from public.junior_davis_ties where tournament_id=t.id and stage='QF' and bracket_slot=3;
    select winner_nation,loser_nation into x4,y4
      from public.junior_davis_ties where tournament_id=t.id and stage='QF' and bracket_slot=4;

    insert into public.junior_davis_ties(
      tournament_id,season,stage,group_name,bracket_slot,tie_date,home_nation,away_nation
    ) values
      (t.id,v_year,'SF','',1,t.start_date+5,x1,x2),
      (t.id,v_year,'SF','',2,t.start_date+5,x3,x4),
      (t.id,v_year,'P5-SF','',1,t.start_date+5,y1,y2),
      (t.id,v_year,'P5-SF','',2,t.start_date+5,y3,y4);
    created:=created+4;

    select winner_nation,loser_nation into x1,y1
      from public.junior_davis_ties where tournament_id=t.id and stage='P9-QF' and bracket_slot=1;
    select winner_nation,loser_nation into x2,y2
      from public.junior_davis_ties where tournament_id=t.id and stage='P9-QF' and bracket_slot=2;
    select winner_nation,loser_nation into x3,y3
      from public.junior_davis_ties where tournament_id=t.id and stage='P9-QF' and bracket_slot=3;
    select winner_nation,loser_nation into x4,y4
      from public.junior_davis_ties where tournament_id=t.id and stage='P9-QF' and bracket_slot=4;

    insert into public.junior_davis_ties(
      tournament_id,season,stage,group_name,bracket_slot,tie_date,home_nation,away_nation
    ) values
      (t.id,v_year,'P9-SF','',1,t.start_date+5,x1,x2),
      (t.id,v_year,'P9-SF','',2,t.start_date+5,x3,x4),
      (t.id,v_year,'P13-SF','',1,t.start_date+5,y1,y2),
      (t.id,v_year,'P13-SF','',2,t.start_date+5,y3,y4);
    created:=created+4;
  end if;

  if (select count(*) from public.junior_davis_ties
      where tournament_id=t.id and stage in ('SF','P5-SF','P9-SF','P13-SF')
        and status='completed')=8
     and not exists(select 1 from public.junior_davis_ties where tournament_id=t.id and stage='F') then

    select winner_nation,loser_nation into x1,y1
      from public.junior_davis_ties where tournament_id=t.id and stage='SF' and bracket_slot=1;
    select winner_nation,loser_nation into x2,y2
      from public.junior_davis_ties where tournament_id=t.id and stage='SF' and bracket_slot=2;

    insert into public.junior_davis_ties(
      tournament_id,season,stage,group_name,bracket_slot,tie_date,home_nation,away_nation
    ) values
      (t.id,v_year,'F','',1,t.start_date+6,x1,x2),
      (t.id,v_year,'P3','',1,t.start_date+6,y1,y2);
    created:=created+2;

    select winner_nation,loser_nation into x1,y1
      from public.junior_davis_ties where tournament_id=t.id and stage='P5-SF' and bracket_slot=1;
    select winner_nation,loser_nation into x2,y2
      from public.junior_davis_ties where tournament_id=t.id and stage='P5-SF' and bracket_slot=2;
    insert into public.junior_davis_ties(
      tournament_id,season,stage,group_name,bracket_slot,tie_date,home_nation,away_nation
    ) values
      (t.id,v_year,'P5','',1,t.start_date+6,x1,x2),
      (t.id,v_year,'P7','',1,t.start_date+6,y1,y2);
    created:=created+2;

    select winner_nation,loser_nation into x1,y1
      from public.junior_davis_ties where tournament_id=t.id and stage='P9-SF' and bracket_slot=1;
    select winner_nation,loser_nation into x2,y2
      from public.junior_davis_ties where tournament_id=t.id and stage='P9-SF' and bracket_slot=2;
    insert into public.junior_davis_ties(
      tournament_id,season,stage,group_name,bracket_slot,tie_date,home_nation,away_nation
    ) values
      (t.id,v_year,'P9','',1,t.start_date+6,x1,x2),
      (t.id,v_year,'P11','',1,t.start_date+6,y1,y2);
    created:=created+2;

    select winner_nation,loser_nation into x1,y1
      from public.junior_davis_ties where tournament_id=t.id and stage='P13-SF' and bracket_slot=1;
    select winner_nation,loser_nation into x2,y2
      from public.junior_davis_ties where tournament_id=t.id and stage='P13-SF' and bracket_slot=2;
    insert into public.junior_davis_ties(
      tournament_id,season,stage,group_name,bracket_slot,tie_date,home_nation,away_nation
    ) values
      (t.id,v_year,'P13','',1,t.start_date+6,x1,x2),
      (t.id,v_year,'P15','',1,t.start_date+6,y1,y2);
    created:=created+2;
  end if;

  if exists(
      select 1 from public.junior_davis_ties
      where tournament_id=t.id and stage='F' and status='completed'
    )
     and not exists(select 1 from public.junior_davis_history where season=v_year) then
    select winner_nation,loser_nation into champ,runner
    from public.junior_davis_ties
    where tournament_id=t.id and stage='F';

    select winner_nation into third
    from public.junior_davis_ties
    where tournament_id=t.id and stage='P3';

    insert into public.junior_davis_history(
      season,champion_nation,runner_up_nation,third_nation,venue,source_label
    ) values(
      v_year,champ,runner,third,coalesce(t.venue,t.city),
      'Court Boss simulated from pre-season database · no future-result leakage'
    );
  end if;

  return jsonb_build_object('created',created,'tournament_id',t.id);
end;
$function$;

CREATE OR REPLACE FUNCTION public.ai_player_commits_to_doubles_tournament(p_player_id bigint, p_tournament_id bigint)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  p public.players%rowtype;
  t public.tournaments%rowtype;
  sp public.player_season_plans%rowtype;
  prob numeric;
  roll numeric;
  v_week date;
  v_i int;
  v_consecutive int:=0;
  v_max_consecutive int;
  v_rest_trigger int;
  v_doubles_bias int;
  v_doubles_events int:=0;
  v_same_event_singles boolean:=false;
begin
  select * into p from public.players where id=p_player_id;
  select * into t from public.tournaments where id=p_tournament_id;
  if p.id is null or t.id is null then return false; end if;
  if coalesce(p.career_focus,'mixed')='singles_only' then return false; end if;

  if t.circuit='ITF' and coalesce(p.ranking,999999)<=200 then return false; end if;
  if t.circuit='ITF' and coalesce(p.doubles_ranking,999999)<=150 then return false; end if;
  if t.circuit='Challenger' and coalesce(p.ranking,999999)<=10 then return false; end if;
  if t.category='Challenger 50' and coalesce(p.ranking,999999)<=50 then return false; end if;
  if t.category='Challenger 75' and coalesce(p.ranking,999999)<=30 then return false; end if;

  if (public.player_tournament_calendar_conflict(p.id,t.id,'doubles')->>'conflict')::boolean then return false; end if;

  select * into sp
  from public.player_season_plans s
  where s.player_id=p.id and s.season=extract(year from t.start_date)::int;

  v_week:=date_trunc('week',coalesce(t.main_draw_start_date,t.start_date)::timestamp)::date;
  v_max_consecutive:=greatest(1,coalesce(sp.max_consecutive_weeks,case when p.age>=32 then 2 else 3 end));
  v_rest_trigger:=coalesce(sp.rest_trigger_fatigue,72);
  v_doubles_bias:=coalesce(sp.doubles_bias,
    case coalesce(p.career_focus,'mixed')
      when 'doubles_only' then 20
      when 'mixed' then 14
      when 'singles_priority' then 7
      else 10 end
  );

  for v_i in 1..5 loop
    if public.player_has_world_event_in_week(p.id,v_week-(v_i*7),null) then
      v_consecutive:=v_consecutive+1;
    else
      exit;
    end if;
  end loop;

  if v_consecutive>=v_max_consecutive
     and coalesce(t.category,'') not in ('Grand Chelem','Masters 1000','ATP Finals') then
    return false;
  end if;
  if coalesce(p.fatigue,20)>=v_rest_trigger+10
     and coalesce(t.category,'') not in ('Grand Chelem','Masters 1000','ATP Finals') then
    return false;
  end if;

  select count(distinct e.tournament_id)::int
  into v_doubles_events
  from public.world_doubles_tournament_entries e
  join public.world_doubles_partnerships wp on wp.id=e.pair_id
  join public.tournaments et on et.id=e.tournament_id
  where p.id in (wp.player_a_id,wp.player_b_id)
    and extract(year from et.start_date)=extract(year from t.start_date)
    and et.start_date<t.start_date;

  select exists(
    select 1 from public.world_tournament_entries e
    where e.tournament_id=t.id and e.player_id=p.id
  ) into v_same_event_singles;

  prob:=case
    when t.category='Grand Chelem' then 90
    when t.category='Masters 1000' then 84
    when t.category='ATP 500' then 76
    when t.category='ATP 250' then 74
    when t.circuit='Challenger' then 72
    when t.circuit='ITF' then 70
    when t.circuit='Junior' then 82
    else 68 end;

  prob:=prob+(v_doubles_bias-10)*2.1;

  prob:=prob+case coalesce(p.career_focus,'mixed')
    when 'doubles_only' then 18
    when 'mixed' then 5
    when 'singles_priority' then -10
    else 0 end;

  if coalesce(p.doubles_ranking,999999)<=50 then prob:=prob+10;
  elsif coalesce(p.doubles_ranking,999999)<=200 then prob:=prob+5;
  end if;

  if v_same_event_singles then prob:=prob+12; end if;

  if coalesce(sp.plan_type,'')='ncaa_pathway' then
    if extract(month from t.start_date) between 1 and 5 then
      prob:=prob-case
        when v_same_event_singles then 4
        when t.category='Grand Chelem' then 12
        when t.circuit='Challenger' then 30
        when t.circuit='ITF' then 22
        else 34 end;
    elsif extract(month from t.start_date) between 6 and 8 then
      prob:=prob+case
        when v_same_event_singles then 10
        when t.circuit='Challenger' then 8
        when t.circuit='ITF' then 12
        else 2 end;
    else
      prob:=prob-case
        when v_same_event_singles then 3
        when t.circuit='ITF' then 8
        when t.circuit='Challenger' then 14
        else 18 end;
    end if;
  end if;

  if v_doubles_events>=coalesce(sp.target_events,24)+3 then prob:=prob-22; end if;
  if coalesce(p.fatigue,20)>=v_rest_trigger then prob:=prob-20; end if;

  prob:=greatest(4,least(99,prob));
  roll:=(mod(abs(hashtext('ai-double-commit-v2|'||t.id::text||'|'||p.id::text)),10000)::numeric)/100.0;
  return roll<prob;
end;
$function$;

CREATE OR REPLACE FUNCTION public.ai_player_commits_to_tournament(p_player_id bigint, p_tournament_id bigint)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  p public.players%rowtype;
  t public.tournaments%rowtype;
  sp public.player_season_plans%rowtype;
  prob numeric;
  roll numeric;
  r int;
  v_week date;
  v_year int;
  v_played int:=0;
  v_consecutive int:=0;
  v_i int;
  v_max_consecutive int;
  v_rest_trigger int;
  v_target int;
  v_previous_country text;
  v_commitment_rank int;
  v_atp500_count int:=0;
  v_post_uso_500_count int:=0;
  v_major boolean:=false;
begin
  select * into p from public.players where id=p_player_id;
  select * into t from public.tournaments where id=p_tournament_id;
  if p.id is null or t.id is null then return false; end if;

  if (public.player_tournament_calendar_conflict(p.id,t.id,'candidate')->>'conflict')::boolean then
    return false;
  end if;

  select * into sp
  from public.player_season_plans s
  where s.player_id=p.id and s.season=extract(year from t.start_date)::int;

  r:=coalesce(case when p.ranking_current then p.ranking end,p.game_world_rank,p.ranking,999999);
  v_year:=extract(year from t.start_date)::int;
  v_week:=date_trunc('week',coalesce(t.main_draw_start_date,t.start_date)::timestamp)::date;
  v_max_consecutive:=greatest(1,coalesce(sp.max_consecutive_weeks,case when p.age>=32 then 2 else 3 end));
  v_rest_trigger:=coalesce(sp.rest_trigger_fatigue,72);
  v_target:=coalesce(sp.target_events,22);
  v_major:=coalesce(t.category,'') in ('Grand Chelem','Masters 1000','ATP Finals','Next Gen Finals');

  select count(distinct z.tournament_id)::int
  into v_played
  from (
    select e.tournament_id
    from public.world_tournament_entries e
    join public.tournaments et on et.id=e.tournament_id
    where e.player_id=p.id
      and extract(year from et.start_date)::int=v_year
      and et.start_date<t.start_date
    union
    select e.tournament_id
    from public.world_tournament_qualifying_entries e
    join public.tournaments et on et.id=e.tournament_id
    where e.player_id=p.id
      and extract(year from et.start_date)::int=v_year
      and et.start_date<t.start_date
    union
    select e.tournament_id
    from public.world_doubles_tournament_entries e
    join public.world_doubles_partnerships wp on wp.id=e.pair_id
    join public.tournaments et on et.id=e.tournament_id
    where p.id in (wp.player_a_id,wp.player_b_id)
      and extract(year from et.start_date)::int=v_year
      and et.start_date<t.start_date
    union
    select e.tournament_id
    from public.world_junior_doubles_entries e
    join public.tournaments et on et.id=e.tournament_id
    where p.id in (e.player_a_id,e.player_b_id)
      and extract(year from et.start_date)::int=v_year
      and et.start_date<t.start_date
    union
    select e.tournament_id
    from public.ncaa_individual_entries e
    join public.tournaments et on et.id=e.tournament_id
    where e.player_id=p.id
      and extract(year from et.start_date)::int=v_year
      and et.start_date<t.start_date
    union
    select 1000000000::bigint+extract(doy from cd.match_date)::bigint
    from public.college_duals cd
    where p.ncaa_current=true
      and p.ncaa_team_id in (cd.home_team_id,cd.away_team_id)
      and cd.status='completed'
      and extract(year from cd.match_date)::int=v_year
      and cd.match_date<t.start_date
    union
    select 2000000000::bigint+dt.id
    from public.davis_squad ds
    join public.davis_ties dt on ds.nation in (dt.home_nation,dt.away_nation)
    where ds.player_id=p.id
      and dt.status='completed'
      and extract(year from dt.tie_date)::int=v_year
      and dt.tie_date<t.start_date
  ) z;

  for v_i in 1..5 loop
    if public.player_has_world_event_in_week(p.id,v_week-(v_i*7),null) then
      v_consecutive:=v_consecutive+1;
    else
      exit;
    end if;
  end loop;

  if v_consecutive>=v_max_consecutive and not v_major then
    return false;
  end if;

  if coalesce(p.fatigue,20)>=v_rest_trigger+10 and not v_major then
    return false;
  end if;

  prob:=public.ai_tournament_commitment_probability(
    r,coalesce(sp.plan_type,'tour_regular'),v_target,
    sp.preferred_surface,t.surface,t.category,p.country,t.country,
    coalesce(p.fatigue,20),v_rest_trigger
  );

  if v_played>=v_target then
    prob:=prob-case
      when v_major then 0
      when coalesce(sp.schedule_risk_tolerance,10)>=15 then 12
      else 28 end;
  end if;
  if v_played>=v_target+4 and not v_major then
    prob:=least(prob,18);
  end if;

  if coalesce(sp.plan_type,'')='ncaa_pathway' then
    if extract(month from t.start_date) between 1 and 5 then
      prob:=prob-case
        when t.circuit='ITF' then 24
        when t.circuit='Challenger' then 34
        else 45 end;
    elsif extract(month from t.start_date) between 6 and 8 then
      prob:=prob+case
        when t.circuit='ITF' then 14
        when t.circuit='Challenger' then 8
        else 0 end;
    else
      prob:=prob-case
        when t.circuit='ITF' then 8
        else 18 end;
    end if;
  end if;

  select x.country into v_previous_country
  from (
    select et.country,coalesce(et.end_date,et.start_date) event_date
    from public.world_tournament_entries e
    join public.tournaments et on et.id=e.tournament_id
    where e.player_id=p.id and et.start_date<t.start_date
    union all
    select et.country,coalesce(et.end_date,et.start_date)
    from public.world_doubles_tournament_entries e
    join public.world_doubles_partnerships wp on wp.id=e.pair_id
    join public.tournaments et on et.id=e.tournament_id
    where p.id in (wp.player_a_id,wp.player_b_id) and et.start_date<t.start_date
    union all
    select et.country,coalesce(et.end_date,et.start_date)
    from public.world_junior_doubles_entries e
    join public.tournaments et on et.id=e.tournament_id
    where p.id in (e.player_a_id,e.player_b_id) and et.start_date<t.start_date
  ) x
  order by x.event_date desc
  limit 1;

  if v_previous_country is not null
     and t.country is not null
     and v_previous_country is distinct from t.country then
    prob:=prob-greatest(2,14-coalesce(sp.travel_tolerance,10)*.55);
  end if;

  if t.circuit='ATP' and v_year>=2026 then
    v_commitment_rank:=public.player_rank_at_date(
      p.id,make_date(v_year-1,11,10)
    );
    v_commitment_rank:=coalesce(v_commitment_rank,r);

    if v_commitment_rank between 1 and 30 then
      if t.category in ('Grand Chelem','Masters 1000') then
        prob:=greatest(prob,97);
      elsif t.category='ATP 500' then
        select count(distinct e.tournament_id)::int
        into v_atp500_count
        from public.world_tournament_entries e
        join public.tournaments et on et.id=e.tournament_id
        where e.player_id=p.id
          and et.circuit='ATP' and et.category='ATP 500'
          and extract(year from et.start_date)::int=v_year
          and et.start_date<t.start_date;

        select count(distinct e.tournament_id)::int
        into v_post_uso_500_count
        from public.world_tournament_entries e
        join public.tournaments et on et.id=e.tournament_id
        where e.player_id=p.id
          and et.circuit='ATP' and et.category='ATP 500'
          and extract(year from et.start_date)::int=v_year
          and extract(month from et.start_date)>=9
          and et.start_date<t.start_date;

        if v_atp500_count<4 then prob:=greatest(prob,78); end if;
        if extract(month from t.start_date)>=9 and v_post_uso_500_count=0 then
          prob:=greatest(prob,91);
        end if;
      end if;
    end if;
  end if;

  prob:=greatest(2,least(99,prob));
  roll:=(mod(abs(hashtext('ai-commit-v2|'||t.id::text||'|'||p.id::text)),10000)::numeric)/100.0;
  return roll<prob;
end;
$function$;

CREATE OR REPLACE FUNCTION public.ensure_junior_davis_field(p_tournament_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  v_year int;
  g text;
  nations text[];
  created_ties int:=0;
  v_field_count int;
begin
  select * into t from public.tournaments where id=p_tournament_id;
  if t.id is null or t.category<>'Junior Davis Cup' then
    return jsonb_build_object('ok',false,'reason','not_junior_davis');
  end if;

  v_year:=extract(year from t.start_date)::int;

  if exists(
    select 1 from public.junior_davis_nations
    where tournament_id=t.id and season=v_year
  ) then
    return jsonb_build_object(
      'ok',true,'already',true,
      'nations',(select count(*) from public.junior_davis_nations where tournament_id=t.id and season=v_year),
      'squad_players',(select count(*) from public.junior_davis_squads where tournament_id=t.id and season=v_year),
      'ties',(select count(*) from public.junior_davis_ties where tournament_id=t.id)
    );
  end if;

  drop table if exists pg_temp.cb_jdc_candidates;
  create temporary table cb_jdc_candidates(
    nation text primary key,
    region text not null,
    strength numeric not null
  ) on commit drop;

  insert into cb_jdc_candidates(nation,region,strength)
  with eligible as (
    select p.country nation,
           public.junior_davis_region(p.country) region,
           p.id,
           row_number() over(
             partition by p.country
             order by coalesce(p.junior_ranking,999999),
                      p.current_ability desc,
                      coalesce(p.junior_doubles_ranking,999999),
                      p.id
           ) player_rank,
           (
             greatest(0,2500-coalesce(p.junior_ranking,2500))*.065+
             coalesce(p.current_ability,50)*1.10+
             coalesce(p.potential,70)*.28+
             coalesce(p.form,70)*.12+
             coalesce(pa.concentration,10)*.15+
             coalesce(pa.big_points,10)*.15+
             coalesce(pa.determination,10)*.12+
             coalesce(pa.doubles,10)*.20
           )::numeric player_score
    from public.players p
    left join public.player_attributes pa on pa.player_id=p.id
    where p.country is not null
      and public.junior_davis_region(p.country)<>'Other'
      and public.junior_davis_player_eligible(p.id,t.start_date)
      and (p.junior_ranking is not null or p.junior_doubles_ranking is not null)
      and not (public.player_tournament_calendar_conflict(p.id,t.id,'direct')->>'conflict')::boolean
  ),
  nation_strength as (
    select nation,region,count(*) eligible_players,
           sum(player_score*case player_rank when 1 then 1.0 when 2 then .88 when 3 then .72 else 0 end)
             filter(where player_rank<=3) strength
    from eligible
    group by nation,region
    having count(*)>=3
  )
  select nation,region,strength
  from nation_strength;

  if not exists(select 1 from cb_jdc_candidates where nation='EGY' and region='Africa') then
    return jsonb_build_object('ok',false,'reason','host_has_no_eligible_u16_roster');
  end if;

  drop table if exists pg_temp.cb_jdc_field;
  create temporary table cb_jdc_field(
    nation text primary key,
    region text not null,
    strength numeric not null,
    qualified_as text not null
  ) on commit drop;

  insert into cb_jdc_field
  select nation,region,strength,'regional_qualifier_europe'
  from cb_jdc_candidates
  where region='Europe'
  order by strength desc,nation
  limit 6;

  insert into cb_jdc_field
  select nation,region,strength,'regional_qualifier_asia_oceania'
  from cb_jdc_candidates
  where region='Asia/Oceania'
  order by strength desc,nation
  limit 4;

  insert into cb_jdc_field
  select nation,region,strength,'regional_qualifier_south_america'
  from cb_jdc_candidates
  where region='South America'
  order by strength desc,nation
  limit 2;

  insert into cb_jdc_field
  select nation,region,strength,'regional_qualifier_north_central_caribbean'
  from cb_jdc_candidates
  where region='North/Central America & Caribbean'
  order by strength desc,nation
  limit 2;

  insert into cb_jdc_field
  select nation,region,strength,'host'
  from cb_jdc_candidates where nation='EGY';

  insert into cb_jdc_field
  select nation,region,strength,'regional_qualifier_africa'
  from cb_jdc_candidates
  where region='Africa' and nation<>'EGY'
  order by strength desc,nation
  limit 1;

  select count(*) into v_field_count from cb_jdc_field;
  if v_field_count<>16 then
    return jsonb_build_object(
      'ok',false,'reason','regional_field_incomplete','nations',v_field_count,
      'regional_counts',(select jsonb_object_agg(region,cnt) from (
        select region,count(*) cnt from cb_jdc_field group by region
      ) x)
    );
  end if;

  with seeded as (
    select nation,region,strength,qualified_as,
           row_number() over(order by strength desc,nation)::int seed
    from cb_jdc_field
  )
  insert into public.junior_davis_nations(
    season,tournament_id,nation,seed,group_name,qualified_as,strength
  )
  select
    v_year,t.id,nation,seed,
    case
      when seed in (1,8,9,16) then 'A'
      when seed in (2,7,10,15) then 'B'
      when seed in (3,6,11,14) then 'C'
      else 'D'
    end,
    qualified_as,strength
  from seeded;

  insert into public.junior_davis_squads(
    season,tournament_id,nation,player_id,squad_order,selected_on
  )
  select v_year,t.id,n.nation,x.id,x.rn,t.start_date
  from public.junior_davis_nations n
  cross join lateral (
    select p.id,
           row_number() over(order by
             coalesce(p.junior_ranking,999999),
             p.current_ability desc,
             coalesce(pa.doubles,10) desc,
             coalesce(p.junior_doubles_ranking,999999),
             p.id
           )::int rn
    from public.players p
    left join public.player_attributes pa on pa.player_id=p.id
    where upper(p.country)=upper(n.nation)
      and public.junior_davis_player_eligible(p.id,t.start_date)
      and (p.junior_ranking is not null or p.junior_doubles_ranking is not null)
      and not (public.player_tournament_calendar_conflict(p.id,t.id,'direct')->>'conflict')::boolean
    order by rn
    limit 3
  ) x
  where n.tournament_id=t.id and n.season=v_year;

  if exists(
    select 1
    from public.junior_davis_nations n
    where n.tournament_id=t.id and n.season=v_year
      and (select count(*) from public.junior_davis_squads s
           where s.tournament_id=t.id and s.season=v_year and s.nation=n.nation)<>3
  ) then
    delete from public.junior_davis_squads where tournament_id=t.id and season=v_year;
    delete from public.junior_davis_nations where tournament_id=t.id and season=v_year;
    return jsonb_build_object('ok',false,'reason','incomplete_three_player_squad');
  end if;

  foreach g in array array['A','B','C','D'] loop
    select array_agg(nation order by seed)
    into nations
    from public.junior_davis_nations
    where tournament_id=t.id and season=v_year and group_name=g;

    if coalesce(array_length(nations,1),0)<>4 then
      raise exception 'Junior Davis group % does not contain 4 nations',g;
    end if;

    insert into public.junior_davis_ties(
      tournament_id,season,stage,group_name,bracket_slot,tie_date,home_nation,away_nation
    ) values
      (t.id,v_year,'Group',g,1,t.start_date,nations[1],nations[4]),
      (t.id,v_year,'Group',g,2,t.start_date,nations[2],nations[3]),
      (t.id,v_year,'Group',g,3,t.start_date+1,nations[1],nations[3]),
      (t.id,v_year,'Group',g,4,t.start_date+1,nations[4],nations[2]),
      (t.id,v_year,'Group',g,5,t.start_date+2,nations[1],nations[2]),
      (t.id,v_year,'Group',g,6,t.start_date+2,nations[3],nations[4]);
    created_ties:=created_ties+6;
  end loop;

  return jsonb_build_object(
    'ok',true,'season',v_year,'nations',16,'squad_size',3,
    'groups',4,'group_ties_created',created_ties,
    'host','EGY',
    'regional_allocation',jsonb_build_object(
      'Europe',6,'Asia/Oceania',4,'South America',2,
      'North/Central America & Caribbean',2,'Africa',2
    ),
    'age_rule','2026 birth years 2010-2013; must have reached 13 by first day',
    'model','ITF Junior Davis Cup 2026 regional qualification v2'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.junior_davis_doubles_rubber(p_h1 bigint, p_h2 bigint, p_a1 bigint, p_a2 bigint, p_tie_id bigint, p_date date, p_key text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  hs numeric;
  ascore numeric;
  prob numeric;
  roll numeric;
  homewin boolean;
  surf text:='Dur';
  speed numeric:=1.0;
  score_winner text;
  score_home text;
  sw int;
  sl int;
  gw int;
  gl int;
begin
  if p_h1 is null or p_h2 is null or p_a1 is null or p_a2 is null then
    return jsonb_build_object('ok',false,'reason','missing_player');
  end if;

  select coalesce(t.surface,'Dur'),coalesce(t.court_speed,
    case when t.surface ilike 'Terre%' then .68 when t.surface ilike 'Gazon%' then 1.15 else 1.0 end)
  into surf,speed
  from public.junior_davis_ties j
  join public.tournaments t on t.id=j.tournament_id
  where j.id=p_tie_id;

  select sum(
    coalesce(p.current_ability,50)*.42+
    coalesce(p.form,70)*.08+
    coalesce(p.fitness,85)*.05-
    coalesce(p.fatigue,20)*.07+
    coalesce(pa.doubles,10)*1.35+
    coalesce(pa.doubles_communication,10)*.45+
    coalesce(pa.net_positioning,10)*.25+
    case
      when surf ilike 'Terre%' then coalesce(pa.clay_affinity,10)*.30
      when surf ilike 'Gazon%' then coalesce(pa.grass_affinity,10)*.30
      else coalesce(pa.hard_affinity,10)*.30 end
  ) into hs
  from public.players p
  left join public.player_attributes pa on pa.player_id=p.id
  where p.id in (p_h1,p_h2);

  select sum(
    coalesce(p.current_ability,50)*.42+
    coalesce(p.form,70)*.08+
    coalesce(p.fitness,85)*.05-
    coalesce(p.fatigue,20)*.07+
    coalesce(pa.doubles,10)*1.35+
    coalesce(pa.doubles_communication,10)*.45+
    coalesce(pa.net_positioning,10)*.25+
    case
      when surf ilike 'Terre%' then coalesce(pa.clay_affinity,10)*.30
      when surf ilike 'Gazon%' then coalesce(pa.grass_affinity,10)*.30
      else coalesce(pa.hard_affinity,10)*.30 end
  ) into ascore
  from public.players p
  left join public.player_attributes pa on pa.player_id=p.id
  where p.id in (p_a1,p_a2);

  prob:=greatest(.05,least(.95,1/(1+exp(-(coalesce(hs,100)-coalesce(ascore,100))/10.5))));
  roll:=mod(abs(hashtext('jdc-d-v2|'||coalesce(p_key,'')||'|'||p_h1||'|'||p_h2||'|'||p_a1||'|'||p_a2)),10000)/10000.0;
  homewin:=roll<prob;

  if abs(prob-.5)<.09 then
    score_winner:='7-6 4-6 10-8'; sw:=2;sl:=1;gw:=12;gl:=12;
  elsif abs(prob-.5)<.20 then
    score_winner:='6-4 3-6 10-6'; sw:=2;sl:=1;gw:=10;gl:=10;
  elsif abs(prob-.5)<.34 then
    score_winner:='6-4 6-4'; sw:=2;sl:=0;gw:=12;gl:=8;
  else
    score_winner:='6-3 6-3'; sw:=2;sl:=0;gw:=12;gl:=6;
  end if;

  score_home:=case when homewin then score_winner else public.world_invert_tennis_score(score_winner) end;

  return jsonb_build_object(
    'ok',true,'home_win',homewin,
    'home_probability',round(prob,4),
    'score',score_home,
    'sets_home',case when homewin then sw else sl end,
    'sets_away',case when homewin then sl else sw end,
    'games_home',case when homewin then gw else gl end,
    'games_away',case when homewin then gl else gw end,
    'surface',surf
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.junior_davis_nation_strength(p_nation text, p_date date)
 RETURNS numeric
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  with ranked as (
    select p.id,
      (
        greatest(0,2500-coalesce(p.junior_ranking,2500))*.065+
        coalesce(p.current_ability,50)*1.10+
        coalesce(p.potential,70)*.28+
        coalesce(p.form,70)*.12+
        coalesce(pa.concentration,10)*.15+
        coalesce(pa.big_points,10)*.15+
        coalesce(pa.determination,10)*.12+
        coalesce(pa.doubles,10)*.20
      )::numeric score,
      row_number() over(
        order by coalesce(p.junior_ranking,999999),p.current_ability desc,p.id
      ) rn
    from public.players p
    left join public.player_attributes pa on pa.player_id=p.id
    where upper(p.country)=upper(p_nation)
      and public.junior_davis_player_eligible(p.id,p_date)
  )
  select case when count(*)<3 then null
              else sum(score*case rn when 1 then 1.0 when 2 then .88 else .72 end)
         end
  from ranked
  where rn<=3;
$function$;

CREATE OR REPLACE FUNCTION public.junior_davis_player_eligible(p_player_id bigint, p_date date)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  select exists(
    select 1
    from public.players p
    where p.id=p_player_id
      and p.career_status='active'
      and p.injury_status='Fit'
      and coalesce(p.fitness,90)>=45
      and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
      and p.birth_date is not null
      and extract(year from p.birth_date)::int between extract(year from p_date)::int-16 and extract(year from p_date)::int-13
      and p.birth_date<=p_date-interval '13 years'
  );
$function$;

CREATE OR REPLACE FUNCTION public.junior_davis_region(p_country text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  select case upper(coalesce(p_country,''))
    when 'ARG' then 'South America' when 'BOL' then 'South America'
    when 'BRA' then 'South America' when 'CHI' then 'South America'
    when 'COL' then 'South America' when 'ECU' then 'South America'
    when 'PAR' then 'South America' when 'PER' then 'South America'
    when 'URU' then 'South America' when 'VEN' then 'South America'

    when 'USA' then 'North/Central America & Caribbean'
    when 'CAN' then 'North/Central America & Caribbean'
    when 'MEX' then 'North/Central America & Caribbean'
    when 'CRC' then 'North/Central America & Caribbean'
    when 'DOM' then 'North/Central America & Caribbean'
    when 'PUR' then 'North/Central America & Caribbean'
    when 'JAM' then 'North/Central America & Caribbean'
    when 'BAH' then 'North/Central America & Caribbean'
    when 'BAR' then 'North/Central America & Caribbean'
    when 'BER' then 'North/Central America & Caribbean'
    when 'CUB' then 'North/Central America & Caribbean'
    when 'ESA' then 'North/Central America & Caribbean'
    when 'GUA' then 'North/Central America & Caribbean'
    when 'HON' then 'North/Central America & Caribbean'
    when 'NCA' then 'North/Central America & Caribbean'
    when 'PAN' then 'North/Central America & Caribbean'
    when 'TTO' then 'North/Central America & Caribbean'
    when 'HAI' then 'North/Central America & Caribbean'

    when 'EGY' then 'Africa' when 'MAR' then 'Africa'
    when 'TUN' then 'Africa' when 'ALG' then 'Africa'
    when 'RSA' then 'Africa' when 'ZAF' then 'Africa'
    when 'NGR' then 'Africa' when 'GHA' then 'Africa'
    when 'KEN' then 'Africa' when 'UGA' then 'Africa'
    when 'ZIM' then 'Africa' when 'ZAM' then 'Africa'
    when 'BOT' then 'Africa' when 'NAM' then 'Africa'
    when 'MRI' then 'Africa' when 'MAD' then 'Africa'
    when 'CMR' then 'Africa' when 'CIV' then 'Africa'
    when 'SEN' then 'Africa' when 'TOG' then 'Africa'
    when 'BEN' then 'Africa' when 'BUR' then 'Africa'
    when 'MLI' then 'Africa' when 'RWA' then 'Africa'
    when 'MOZ' then 'Africa' when 'ANG' then 'Africa'

    when 'AUS' then 'Asia/Oceania' when 'NZL' then 'Asia/Oceania'
    when 'JPN' then 'Asia/Oceania' when 'KOR' then 'Asia/Oceania'
    when 'CHN' then 'Asia/Oceania' when 'TPE' then 'Asia/Oceania'
    when 'HKG' then 'Asia/Oceania' when 'IND' then 'Asia/Oceania'
    when 'PAK' then 'Asia/Oceania' when 'SRI' then 'Asia/Oceania'
    when 'THA' then 'Asia/Oceania' when 'VIE' then 'Asia/Oceania'
    when 'INA' then 'Asia/Oceania' when 'MAS' then 'Asia/Oceania'
    when 'PHI' then 'Asia/Oceania' when 'SGP' then 'Asia/Oceania'
    when 'KAZ' then 'Asia/Oceania' when 'UZB' then 'Asia/Oceania'
    when 'KGZ' then 'Asia/Oceania' when 'TJK' then 'Asia/Oceania'
    when 'TKM' then 'Asia/Oceania' when 'MGL' then 'Asia/Oceania'
    when 'NEP' then 'Asia/Oceania' when 'BAN' then 'Asia/Oceania'
    when 'MYA' then 'Asia/Oceania' when 'CAM' then 'Asia/Oceania'
    when 'LAO' then 'Asia/Oceania' when 'IRI' then 'Asia/Oceania'
    when 'IRQ' then 'Asia/Oceania' when 'JOR' then 'Asia/Oceania'
    when 'LBN' then 'Asia/Oceania' when 'KSA' then 'Asia/Oceania'
    when 'KUW' then 'Asia/Oceania' when 'UAE' then 'Asia/Oceania'
    when 'QAT' then 'Asia/Oceania' when 'OMA' then 'Asia/Oceania'
    when 'BRN' then 'Asia/Oceania' when 'SYR' then 'Asia/Oceania'

    when 'ALB' then 'Europe' when 'AND' then 'Europe'
    when 'ARM' then 'Europe' when 'AUT' then 'Europe'
    when 'AZE' then 'Europe' when 'BEL' then 'Europe'
    when 'BIH' then 'Europe' when 'BUL' then 'Europe'
    when 'CRO' then 'Europe' when 'CYP' then 'Europe'
    when 'CZE' then 'Europe' when 'DEN' then 'Europe'
    when 'ESP' then 'Europe' when 'EST' then 'Europe'
    when 'FIN' then 'Europe' when 'FRA' then 'Europe'
    when 'GBR' then 'Europe' when 'GEO' then 'Europe'
    when 'GER' then 'Europe' when 'GRE' then 'Europe'
    when 'HUN' then 'Europe' when 'IRL' then 'Europe'
    when 'ISL' then 'Europe' when 'ISR' then 'Europe'
    when 'ITA' then 'Europe' when 'LAT' then 'Europe'
    when 'LTU' then 'Europe' when 'LUX' then 'Europe'
    when 'MDA' then 'Europe' when 'MKD' then 'Europe'
    when 'MLT' then 'Europe' when 'MNE' then 'Europe'
    when 'NED' then 'Europe' when 'NOR' then 'Europe'
    when 'POL' then 'Europe' when 'POR' then 'Europe'
    when 'ROU' then 'Europe' when 'RUS' then 'Europe'
    when 'SRB' then 'Europe' when 'SLO' then 'Europe'
    when 'SVK' then 'Europe' when 'SWE' then 'Europe'
    when 'SUI' then 'Europe' when 'TUR' then 'Europe'
    when 'UKR' then 'Europe'
    else 'Other'
  end;
$function$;

CREATE OR REPLACE FUNCTION public.junior_davis_singles_rubber(p_home_player bigint, p_away_player bigint, p_date date, p_key text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  m jsonb;
  prob numeric;
  roll numeric;
  homewin boolean;
  surf text:='Dur';
  speed numeric:=1.0;
  score_winner text;
  score_home text;
  sw int;
  sl int;
  gw int;
  gl int;
  tie_id bigint;
begin
  if p_home_player is null or p_away_player is null then
    return jsonb_build_object('ok',false,'reason','missing_player');
  end if;

  begin
    tie_id:=split_part(coalesce(p_key,''),'|',1)::bigint;
    select coalesce(t.surface,'Dur'),coalesce(t.court_speed,
      case when t.surface ilike 'Terre%' then .68 when t.surface ilike 'Gazon%' then 1.15 else 1.0 end)
    into surf,speed
    from public.junior_davis_ties j
    join public.tournaments t on t.id=j.tournament_id
    where j.id=tie_id;
  exception when others then
    surf:='Dur';speed:=1.0;
  end;

  m:=public.player_matchup_probability_v4(
    p_home_player,p_away_player,surf,p_date,speed,3
  );
  prob:=greatest(.04,least(.96,coalesce((m->>'player_a_probability')::numeric,.5)));
  roll:=mod(abs(hashtext('jdc-s-v2|'||coalesce(p_key,'')||'|'||p_home_player||'|'||p_away_player)),10000)/10000.0;
  homewin:=roll<prob;

  if abs(prob-.5)<.07 then
    score_winner:='7-6 4-6 6-4'; sw:=2;sl:=1;gw:=17;gl:=16;
  elsif abs(prob-.5)<.18 then
    score_winner:='6-4 3-6 6-3'; sw:=2;sl:=1;gw:=15;gl:=13;
  elsif abs(prob-.5)<.32 then
    score_winner:='6-4 6-4'; sw:=2;sl:=0;gw:=12;gl:=8;
  else
    score_winner:='6-2 6-3'; sw:=2;sl:=0;gw:=12;gl:=5;
  end if;

  score_home:=case when homewin then score_winner else public.world_invert_tennis_score(score_winner) end;

  return jsonb_build_object(
    'ok',true,'home_win',homewin,
    'winner_id',case when homewin then p_home_player else p_away_player end,
    'loser_id',case when homewin then p_away_player else p_home_player end,
    'home_probability',round(prob,4),
    'score',score_home,
    'sets_home',case when homewin then sw else sl end,
    'sets_away',case when homewin then sl else sw end,
    'games_home',case when homewin then gw else gl end,
    'games_away',case when homewin then gl else gw end,
    'surface',surf
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.junior_main_wildcards(p_main_draw integer)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  select case
    when p_main_draw<=16 then 2
    when p_main_draw<=24 then 2
    when p_main_draw<=32 then 4
    when p_main_draw<=48 then 6
    else 8
  end;
$function$;

CREATE OR REPLACE FUNCTION public.junior_qualifier_slots(p_main_draw integer, p_category text)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  select case
    when p_category in ('J30','J60','J100') and p_main_draw=32 then 8
    when p_main_draw<=16 then 2
    when p_main_draw<=24 then 2
    when p_main_draw<=32 then 4
    when p_main_draw<=48 then 6
    else 8
  end;
$function$;

CREATE OR REPLACE FUNCTION public.junior_qualifying_wildcards(p_qdraw integer)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  select case
    when p_qdraw<=16 then 2
    when p_qdraw<=24 then 4
    when p_qdraw<=32 then 6
    when p_qdraw<=48 then 7
    else 8
  end;
$function$;

CREATE OR REPLACE FUNCTION public.junior_wtn_proxy_score(p_player_id bigint, p_date date)
 RETURNS numeric
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  select (
    coalesce(p.current_ability,50)*2.00+
    coalesce(p.potential,70)*.38+
    coalesce(p.form,70)*.18+
    coalesce(p.fitness,85)*.08-
    coalesce(p.fatigue,20)*.10+
    greatest(0,18-coalesce(
      extract(year from age(p_date,p.birth_date))::int,
      p.age,18
    ))*.45+
    (mod(abs(hashtext('junior-rating-proxy|'||p_player_id||'|'||p_date)),1000)::numeric/1000.0)*2
  )
  from public.players p
  where p.id=p_player_id;
$function$;

CREATE OR REPLACE FUNCTION public.ncaa_apply_utr_result(p_winner_id bigint, p_loser_id bigint, p_date date, p_tournament_id bigint DEFAULT NULL::bigint, p_dual_id bigint DEFAULT NULL::bigint, p_weight numeric DEFAULT 1.0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  rw numeric;
  rl numeric;
  ew numeric;
  k numeric:=.18*greatest(.35,least(1.50,coalesce(p_weight,1.0)));
  dw numeric;
  nw numeric;
  nl numeric;
begin
  insert into public.player_utr_state(player_id,current_rating)
  select p_winner_id,coalesce((
    select r.utr_rating from public.ncaa_player_registry r
    where r.player_id=p_winner_id and r.utr_rating is not null
    order by r.season desc,r.snapshot_date desc nulls last,r.id desc limit 1
  ),10.0)
  on conflict(player_id) do nothing;

  insert into public.player_utr_state(player_id,current_rating)
  select p_loser_id,coalesce((
    select r.utr_rating from public.ncaa_player_registry r
    where r.player_id=p_loser_id and r.utr_rating is not null
    order by r.season desc,r.snapshot_date desc nulls last,r.id desc limit 1
  ),10.0)
  on conflict(player_id) do nothing;

  select current_rating into rw from public.player_utr_state where player_id=p_winner_id for update;
  select current_rating into rl from public.player_utr_state where player_id=p_loser_id for update;

  ew:=1/(1+power(10,(rl-rw)/2.25));
  dw:=greatest(.015,least(.22,k*(1-ew)));
  nw:=greatest(1.00,least(16.50,rw+dw));
  nl:=greatest(1.00,least(16.50,rl-dw));

  update public.player_utr_state
  set current_rating=nw,match_count=match_count+1,updated_at=now()
  where player_id=p_winner_id;
  update public.player_utr_state
  set current_rating=nl,match_count=match_count+1,updated_at=now()
  where player_id=p_loser_id;

  insert into public.ncaa_utr_rating_history(
    player_id,rating_date,tournament_id,dual_id,opponent_id,
    old_rating,new_rating,delta,result
  ) values
    (p_winner_id,p_date,p_tournament_id,p_dual_id,p_loser_id,rw,nw,nw-rw,'W'),
    (p_loser_id,p_date,p_tournament_id,p_dual_id,p_winner_id,rl,nl,nl-rl,'L');

  return jsonb_build_object(
    'winner_old',rw,'winner_new',nw,'loser_old',rl,'loser_new',nl,
    'winner_delta',round(nw-rw,3),'loser_delta',round(nl-rl,3)
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.ncaa_individual_doubles_match_result(p_a1 bigint, p_a2 bigint, p_b1 bigint, p_b2 bigint, p_surface text, p_date date, p_key text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  sa numeric;
  sb numeric;
  prob numeric;
  roll numeric;
  a_win boolean;
  surf text:=lower(coalesce(p_surface,'Dur'));
begin
  select sum(
    coalesce(p.current_ability,50)*.40+
    coalesce(pa.doubles,10)*1.55+
    coalesce(p.form,70)*.08+
    coalesce(p.fitness,85)*.04-
    coalesce(p.fatigue,20)*.06+
    coalesce(us.current_rating,10)*.55+
    case
      when surf like 'terre%' then coalesce(pa.clay_affinity,10)*.24
      when surf like 'gazon%' then coalesce(pa.grass_affinity,10)*.24
      else coalesce(pa.hard_affinity,10)*.24 end
  ) into sa
  from public.players p
  left join public.player_attributes pa on pa.player_id=p.id
  left join public.player_utr_state us on us.player_id=p.id
  where p.id in (p_a1,p_a2);

  select sum(
    coalesce(p.current_ability,50)*.40+
    coalesce(pa.doubles,10)*1.55+
    coalesce(p.form,70)*.08+
    coalesce(p.fitness,85)*.04-
    coalesce(p.fatigue,20)*.06+
    coalesce(us.current_rating,10)*.55+
    case
      when surf like 'terre%' then coalesce(pa.clay_affinity,10)*.24
      when surf like 'gazon%' then coalesce(pa.grass_affinity,10)*.24
      else coalesce(pa.hard_affinity,10)*.24 end
  ) into sb
  from public.players p
  left join public.player_attributes pa on pa.player_id=p.id
  left join public.player_utr_state us on us.player_id=p.id
  where p.id in (p_b1,p_b2);

  prob:=greatest(.05,least(.95,1/(1+exp(-(coalesce(sa,100)-coalesce(sb,100))/10.5))));
  roll:=mod(abs(hashtext('ncaa-ind-d|'||coalesce(p_key,'')||'|'||p_a1||'|'||p_a2||'|'||p_b1||'|'||p_b2)),10000)/10000.0;
  a_win:=roll<prob;

  return jsonb_build_object(
    'a_win',a_win,
    'a_probability',round(prob,4),
    'score',case
      when abs(prob-.5)<.07 then '7-6 4-6 10-8'
      when abs(prob-.5)<.17 then '6-4 3-6 10-6'
      when abs(prob-.5)<.30 then '6-4 6-4'
      else '6-2 6-3' end
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.ncaa_individual_match_result(p_player_a bigint, p_player_b bigint, p_surface text, p_date date, p_key text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  v_match jsonb;
  v_prob numeric;
  v_utr_a numeric;
  v_utr_b numeric;
  v_roll numeric;
  v_a_win boolean;
begin
  select current_rating into v_utr_a from public.player_utr_state where player_id=p_player_a;
  select current_rating into v_utr_b from public.player_utr_state where player_id=p_player_b;

  v_match:=public.player_matchup_probability_v4(
    p_player_a,p_player_b,coalesce(p_surface,'Dur'),p_date,
    case
      when coalesce(p_surface,'Dur') ilike 'Terre%' then .70
      when coalesce(p_surface,'Dur') ilike 'Gazon%' then 1.14
      else 1.0 end,
    3
  );

  v_prob:=coalesce((v_match->>'player_a_probability')::numeric,.5);
  v_prob:=greatest(.04,least(.96,
    v_prob*.76+
    (1/(1+power(10,(coalesce(v_utr_b,10)-coalesce(v_utr_a,10))/2.25)))*.24
  ));

  v_roll:=mod(abs(hashtext('ncaa-ind|'||coalesce(p_key,'')||'|'||p_player_a||'|'||p_player_b)),10000)/10000.0;
  v_a_win:=v_roll<v_prob;

  return jsonb_build_object(
    'a_win',v_a_win,
    'winner_id',case when v_a_win then p_player_a else p_player_b end,
    'loser_id',case when v_a_win then p_player_b else p_player_a end,
    'a_probability',round(v_prob,4),
    'score',case
      when abs(v_prob-.5)<.06 then '7-6 4-6 7-5'
      when abs(v_prob-.5)<.16 then '6-4 3-6 6-3'
      when abs(v_prob-.5)<.30 then '6-4 6-4'
      else '6-2 6-3' end
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.ncaa_prepare_individual_event(p_tournament_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  v_singles_draw int;
  v_doubles_draw int;
  v_singles_count int:=0;
  v_doubles_count int:=0;
  v_school_cap int;
  v_season int;
begin
  select * into t from public.tournaments where id=p_tournament_id;
  if t.id is null or t.circuit<>'NCAA' or not coalesce(t.is_active,true) then
    return jsonb_build_object('ok',false,'reason','not_active_ncaa_event');
  end if;

  if t.category in ('ITA Kickoff Weekend','ITA National Team Indoor Championship','NCAA DI Team Championship') then
    return jsonb_build_object('ok',false,'reason','team_event');
  end if;

  v_season:=extract(year from t.start_date)::int;
  v_singles_draw:=greatest(0,coalesce(t.singles_draw_size,t.draw_size,case when t.singles then 64 else 0 end));
  v_doubles_draw:=greatest(0,coalesce(t.doubles_draw_size,case when t.doubles then 16 else 0 end));

  if t.category='NCAA DI Individual Championship' then
    v_school_cap:=99;
  elsif t.registration_mode in ('school_nomination','conference_selection') then
    v_school_cap:=4;
  else
    v_school_cap:=3;
  end if;

  if coalesce(t.singles,false) and v_singles_draw>0
     and not exists(select 1 from public.ncaa_individual_entries where tournament_id=t.id and discipline='singles') then

    with base as (
      select p.id,p.ncaa_school,p.ncaa_rank,
             coalesce(us.current_rating,10) utr,
             coalesce(ip.points,0) season_points,
             coalesce(p.current_ability,50) ca,
             row_number() over(
               partition by coalesce(p.ncaa_school,'__'||p.id::text)
               order by
                 case when t.category='NCAA UTR' then coalesce(us.current_rating,10) else coalesce(ip.points,0) end desc,
                 coalesce(p.ncaa_rank,9999),
                 p.id
             ) school_rn
      from public.players p
      left join public.player_utr_state us on us.player_id=p.id
      left join public.ncaa_individual_points ip on ip.player_id=p.id and ip.season=v_season
      where p.ncaa_current=true
        and p.career_status='active'
        and p.injury_status='Fit'
        and coalesce(p.fitness,90)>=45
        and public.ncaa_individual_player_available(p.id,t.id)
    ),
    championship_auto as (
      select distinct q.player_ids[1] player_id
      from public.ncaa_individual_qualifiers q
      where q.season=v_season and q.discipline='singles'
        and array_length(q.player_ids,1)=1
    ),
    ranked as (
      select b.*,
        case
          when ca.player_id is not null then -1000000
          else 0 end auto_bias,
        (
          case
            when t.category='NCAA UTR' then b.utr*95+b.ca*.4+b.season_points*.02
            when t.category='NCAA DI Individual Championship' then b.season_points*1.4+b.utr*24+b.ca*.25
            when t.category like 'ITA %' then b.season_points*.8+b.utr*42+b.ca*.30
            else b.season_points*.35+b.utr*62+b.ca*.25
          end
          + (mod(abs(hashtext('ncaa-field|'||t.id||'|'||b.id)),1000)::numeric/1000.0)*6
        ) field_score
      from base b
      left join championship_auto ca on ca.player_id=b.id
      where b.school_rn<=v_school_cap or ca.player_id is not null
    ),
    chosen as (
      select id,
             row_number() over(order by auto_bias asc,field_score desc,coalesce(ncaa_rank,9999),id)::int pos
      from ranked
      order by auto_bias asc,field_score desc,coalesce(ncaa_rank,9999),id
      limit v_singles_draw
    )
    insert into public.ncaa_individual_entries(
      tournament_id,player_id,discipline,initial_phase,seed,draw_position,entry_type
    )
    select t.id,c.id,'singles','main',
           case when c.pos<=16 then c.pos else null end,
           c.pos,
           case when exists(
             select 1 from public.ncaa_individual_qualifiers q
             where q.season=v_season and q.discipline='singles'
               and q.player_ids=array[c.id]::bigint[]
           ) then 'automatic_qualifier'
           when t.registration_mode='conference_selection' then 'conference_selection'
           when t.registration_mode='school_nomination' then 'school_nomination'
           else 'individual_selection' end
    from chosen c
    on conflict do nothing;

    get diagnostics v_singles_count=row_count;
  else
    select count(*) into v_singles_count
    from public.ncaa_individual_entries where tournament_id=t.id and discipline='singles';
  end if;

  if coalesce(t.doubles,false) and v_doubles_draw>0
     and not exists(select 1 from public.ncaa_individual_doubles_entries where tournament_id=t.id) then

    with eligible as (
      select p.id,p.ncaa_school,
             coalesce(pa.doubles,10) doubles_skill,
             coalesce(us.current_rating,10) utr,
             coalesce(p.current_ability,50) ca,
             row_number() over(
               partition by p.ncaa_school
               order by coalesce(pa.doubles,10) desc,coalesce(us.current_rating,10) desc,p.id
             ) rn
      from public.players p
      left join public.player_attributes pa on pa.player_id=p.id
      left join public.player_utr_state us on us.player_id=p.id
      where p.ncaa_current=true
        and p.ncaa_school is not null
        and p.career_status='active'
        and p.injury_status='Fit'
        and coalesce(p.fitness,90)>=45
        and coalesce(p.career_focus,'mixed')<>'singles_only'
        and public.ncaa_individual_player_available(p.id,t.id)
    ),
    pairs as (
      select a.ncaa_school,
             least(a.id,b.id) player_a_id,
             greatest(a.id,b.id) player_b_id,
             a.doubles_skill+b.doubles_skill+(a.utr+b.utr)*.7+(a.ca+b.ca)*.10 pair_score,
             ((a.rn+1)/2)::int pair_no
      from eligible a
      join eligible b
        on b.ncaa_school=a.ncaa_school
       and b.rn=a.rn+1
       and mod(a.rn,2)=1
      where a.rn<=6
    ),
    ranked as (
      select *,
        row_number() over(order by pair_score desc,
          mod(abs(hashtext('ncaa-double-field|'||t.id||'|'||player_a_id||'|'||player_b_id)),1000),
          player_a_id,player_b_id)::int pos
      from pairs
      where pair_no<=3
      order by pair_score desc,pos
      limit v_doubles_draw
    )
    insert into public.ncaa_individual_doubles_entries(
      tournament_id,player_a_id,player_b_id,initial_phase,seed
    )
    select t.id,player_a_id,player_b_id,'main',
           case when pos<=8 then pos else null end
    from ranked
    on conflict do nothing;

    get diagnostics v_doubles_count=row_count;
  else
    select count(*) into v_doubles_count
    from public.ncaa_individual_doubles_entries where tournament_id=t.id;
  end if;

  return jsonb_build_object(
    'ok',true,'tournament_id',t.id,'name',t.name,
    'singles_entries',v_singles_count,'doubles_entries',v_doubles_count,
    'singles_draw',v_singles_draw,'doubles_draw',v_doubles_draw
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.ncaa_team_doubles_lineup(p_team_id bigint, p_date date)
 RETURNS bigint[]
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  select coalesce(array_agg(id order by score desc,id),'{}'::bigint[])
  from (
    select p.id,
      coalesce(p.current_ability,50)*.55
      +coalesce(pa.doubles,10)*1.65
      +coalesce(p.form,70)*.08
      +coalesce(p.fitness,85)*.04
      -coalesce(p.fatigue,20)*.06
      +coalesce(us.current_rating,10)*.8 as score
    from public.players p
    left join public.player_attributes pa on pa.player_id=p.id
    left join public.player_utr_state us on us.player_id=p.id
    where p.ncaa_current=true
      and p.ncaa_team_id=p_team_id
      and p.career_status='active'
      and p.injury_status='Fit'
      and coalesce(p.fitness,90)>=45
      and coalesce(p.career_focus,'mixed')<>'singles_only'

      and not exists(
        select 1
        from public.davis_squad ds
        join public.davis_ties dt on ds.nation in (dt.home_nation,dt.away_nation)
        where ds.player_id=p.id
          and dt.status in ('scheduled','completed')
          and dt.tie_date=p_date
      )

      and not exists(
        select 1
        from public.world_tournament_entries we
        join public.tournaments et on et.id=we.tournament_id
        where we.player_id=p.id
          and daterange(
                coalesce(et.qualifying_start_date,et.main_draw_start_date,et.start_date),
                coalesce(et.end_date,et.start_date),'[]'
              ) && daterange(p_date,p_date,'[]')
      )

      and not exists(
        select 1
        from public.world_tournament_qualifying_entries qe
        join public.tournaments et on et.id=qe.tournament_id
        where qe.player_id=p.id
          and daterange(
                coalesce(et.qualifying_start_date,et.start_date),
                coalesce(et.qualifying_end_date,et.main_draw_start_date,et.end_date,et.start_date),'[]'
              ) && daterange(p_date,p_date,'[]')
      )

      and not exists(
        select 1
        from public.world_doubles_tournament_entries de
        join public.world_doubles_partnerships wp on wp.id=de.pair_id
        join public.tournaments et on et.id=de.tournament_id
        where p.id in (wp.player_a_id,wp.player_b_id)
          and daterange(
                coalesce(et.qualifying_start_date,et.main_draw_start_date,et.start_date),
                coalesce(et.end_date,et.start_date),'[]'
              ) && daterange(p_date,p_date,'[]')
      )

      and not exists(
        select 1
        from public.junior_entry_reservations jr
        join public.tournaments et on et.id=jr.tournament_id
        where jr.player_id=p.id
          and daterange(et.start_date,coalesce(et.end_date,et.start_date),'[]')
              && daterange(p_date,p_date,'[]')
      )

      and not exists(
        select 1
        from public.ncaa_individual_entries ie
        join public.tournaments et on et.id=ie.tournament_id
        where ie.player_id=p.id
          and daterange(et.start_date,coalesce(et.end_date,et.start_date),'[]')
              && daterange(p_date,p_date,'[]')
      )

      and not exists(
        select 1
        from public.ncaa_individual_doubles_entries ide
        join public.tournaments et on et.id=ide.tournament_id
        where p.id in (ide.player_a_id,ide.player_b_id)
          and daterange(et.start_date,coalesce(et.end_date,et.start_date),'[]')
              && daterange(p_date,p_date,'[]')
      )
    order by score desc,p.id
    limit 6
  ) x;
$function$;

CREATE OR REPLACE FUNCTION public.ncaa_team_lineup(p_team_id bigint, p_date date)
 RETURNS bigint[]
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  select coalesce(array_agg(id order by score desc,id),'{}'::bigint[])
  from (
    select p.id,
      coalesce(p.current_ability,50)
      +coalesce(p.form,70)*.11
      +coalesce(p.fitness,85)*.05
      -coalesce(p.fatigue,20)*.07
      +coalesce(us.current_rating,10)*1.8
      -coalesce(p.ncaa_rank,500)*.004 as score
    from public.players p
    left join public.player_utr_state us on us.player_id=p.id
    where p.ncaa_current=true
      and p.ncaa_team_id=p_team_id
      and p.career_status='active'
      and p.injury_status='Fit'
      and coalesce(p.fitness,90)>=45

      and not exists(
        select 1
        from public.davis_squad ds
        join public.davis_ties dt on ds.nation in (dt.home_nation,dt.away_nation)
        where ds.player_id=p.id
          and dt.status in ('scheduled','completed')
          and dt.tie_date=p_date
      )

      and not exists(
        select 1
        from public.world_tournament_entries we
        join public.tournaments et on et.id=we.tournament_id
        where we.player_id=p.id
          and daterange(
                coalesce(et.qualifying_start_date,et.main_draw_start_date,et.start_date),
                coalesce(et.end_date,et.start_date),'[]'
              ) && daterange(p_date,p_date,'[]')
      )

      and not exists(
        select 1
        from public.world_tournament_qualifying_entries qe
        join public.tournaments et on et.id=qe.tournament_id
        where qe.player_id=p.id
          and daterange(
                coalesce(et.qualifying_start_date,et.start_date),
                coalesce(et.qualifying_end_date,et.main_draw_start_date,et.end_date,et.start_date),'[]'
              ) && daterange(p_date,p_date,'[]')
      )

      and not exists(
        select 1
        from public.world_doubles_tournament_entries de
        join public.world_doubles_partnerships wp on wp.id=de.pair_id
        join public.tournaments et on et.id=de.tournament_id
        where p.id in (wp.player_a_id,wp.player_b_id)
          and daterange(
                coalesce(et.qualifying_start_date,et.main_draw_start_date,et.start_date),
                coalesce(et.end_date,et.start_date),'[]'
              ) && daterange(p_date,p_date,'[]')
      )

      and not exists(
        select 1
        from public.junior_entry_reservations jr
        join public.tournaments et on et.id=jr.tournament_id
        where jr.player_id=p.id
          and daterange(et.start_date,coalesce(et.end_date,et.start_date),'[]')
              && daterange(p_date,p_date,'[]')
      )

      and not exists(
        select 1
        from public.ncaa_individual_entries ie
        join public.tournaments et on et.id=ie.tournament_id
        where ie.player_id=p.id
          and daterange(et.start_date,coalesce(et.end_date,et.start_date),'[]')
              && daterange(p_date,p_date,'[]')
      )

      and not exists(
        select 1
        from public.ncaa_individual_doubles_entries ide
        join public.tournaments et on et.id=ide.tournament_id
        where p.id in (ide.player_a_id,ide.player_b_id)
          and daterange(et.start_date,coalesce(et.end_date,et.start_date),'[]')
              && daterange(p_date,p_date,'[]')
      )
    order by score desc,p.id
    limit 6
  ) x;
$function$;

CREATE OR REPLACE FUNCTION public.ncaa_team_power(p_team_id bigint, p_date date)
 RETURNS numeric
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  v_lineup bigint[];
  v_roster numeric:=0;
  v_staff numeric:=0;
  v_rank int:=64;
begin
  v_lineup:=public.ncaa_team_lineup(p_team_id,p_date);

  select coalesce(avg(
    coalesce(p.current_ability,50)
    +coalesce(p.form,70)*.11
    +coalesce(p.fitness,85)*.05
    -coalesce(p.fatigue,20)*.07
    +coalesce(us.current_rating,10)*1.8
    +coalesce(pa.mental_toughness,10)*.18
  ),55)
  into v_roster
  from public.players p
  left join public.player_utr_state us on us.player_id=p.id
  left join public.player_attributes pa on pa.player_id=p.id
  where p.id=any(v_lineup);

  select coalesce(avg(
    coalesce(sp.coach_rating,10)*.28+
    coalesce(sp.tactical_rating,10)*.24+
    coalesce(sp.mental_rating,10)*.18+
    coalesce(sp.youth_rating,10)*.15+
    coalesce(sp.communication_rating,10)*.15
  ),10)
  into v_staff
  from public.college_team_staff cts
  join public.staff_profiles sp on sp.id=cts.profile_id
  where cts.team_id=p_team_id and cts.active=true;

  select coalesce(ita_rank,preseason_rank,64) into v_rank
  from public.college_teams where id=p_team_id;

  return v_roster+v_staff*.55+greatest(0,65-v_rank)*.055;
end;
$function$;

CREATE OR REPLACE FUNCTION public.player_has_world_event_in_week(p_player_id bigint, p_week_start date, p_exclude_tournament_id bigint DEFAULT NULL::bigint)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  select exists(
    select 1
    from public.world_tournament_entries e
    join public.tournaments t on t.id=e.tournament_id
    where e.player_id=p_player_id
      and t.id is distinct from p_exclude_tournament_id
      and daterange(coalesce(t.qualifying_start_date,t.main_draw_start_date,t.start_date),coalesce(t.end_date,t.start_date),'[]')
          && daterange(p_week_start,p_week_start+6,'[]')
    union all
    select 1
    from public.world_tournament_qualifying_entries e
    join public.tournaments t on t.id=e.tournament_id
    where e.player_id=p_player_id
      and t.id is distinct from p_exclude_tournament_id
      and daterange(coalesce(t.qualifying_start_date,t.start_date),coalesce(t.qualifying_end_date,t.main_draw_start_date,t.end_date,t.start_date),'[]')
          && daterange(p_week_start,p_week_start+6,'[]')
    union all
    select 1
    from public.world_doubles_tournament_entries e
    join public.world_doubles_partnerships p on p.id=e.pair_id
    join public.tournaments t on t.id=e.tournament_id
    where p_player_id in (p.player_a_id,p.player_b_id)
      and t.id is distinct from p_exclude_tournament_id
      and daterange(coalesce(t.qualifying_start_date,t.main_draw_start_date,t.start_date),coalesce(t.end_date,t.start_date),'[]')
          && daterange(p_week_start,p_week_start+6,'[]')
    union all
    select 1
    from public.world_junior_doubles_entries e
    join public.tournaments t on t.id=e.tournament_id
    where p_player_id in (e.player_a_id,e.player_b_id)
      and t.id is distinct from p_exclude_tournament_id
      and daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
          && daterange(p_week_start,p_week_start+6,'[]')
    union all
    select 1
    from public.junior_entry_reservations jr
    join public.tournaments t on t.id=jr.tournament_id
    where jr.player_id=p_player_id
      and t.id is distinct from p_exclude_tournament_id
      and daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
          && daterange(p_week_start,p_week_start+6,'[]')
    union all
    select 1
    from public.ncaa_individual_entries e
    join public.tournaments t on t.id=e.tournament_id
    where e.player_id=p_player_id
      and t.id is distinct from p_exclude_tournament_id
      and daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
          && daterange(p_week_start,p_week_start+6,'[]')
    union all
    select 1
    from public.ncaa_individual_doubles_entries e
    join public.tournaments t on t.id=e.tournament_id
    where p_player_id in (e.player_a_id,e.player_b_id)
      and t.id is distinct from p_exclude_tournament_id
      and daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
          && daterange(p_week_start,p_week_start+6,'[]')
    union all
    select 1
    from public.players pl
    join public.ncaa_team_event_entries te on te.team_id=pl.ncaa_team_id
    join public.tournaments t on t.id=te.tournament_id
    where pl.id=p_player_id
      and t.id is distinct from p_exclude_tournament_id
      and daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
          && daterange(p_week_start,p_week_start+6,'[]')
    union all
    select 1
    from public.junior_davis_squads s
    join public.tournaments t on t.id=s.tournament_id
    where s.player_id=p_player_id
      and t.id is distinct from p_exclude_tournament_id
      and daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
          && daterange(p_week_start,p_week_start+6,'[]')

    union all
    select 1
    from public.davis_squad ds
    join public.davis_ties dt on ds.nation in (dt.home_nation,dt.away_nation)
    where ds.player_id=p_player_id
      and dt.status in ('scheduled','completed')
      and dt.tie_date between p_week_start and p_week_start+6
    union all
    select 1
    from public.players pl
    join public.college_duals cd on pl.ncaa_team_id in (cd.home_team_id,cd.away_team_id)
    where pl.id=p_player_id
      and pl.ncaa_current=true
      and cd.status in ('scheduled','completed')
      and cd.match_date between p_week_start and p_week_start+6
  );
$function$;

CREATE OR REPLACE FUNCTION public.player_recent_match_load(p_player_id bigint, p_date date)
 RETURNS integer
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  select coalesce(sum(x.matches),0)::int
  from (
    select count(*)::int matches
    from public.world_tournament_matches m
    where m.simulated_on between p_date-13 and p_date
      and p_player_id in (m.player_a_id,m.player_b_id)

    union all
    select count(*)::int
    from public.world_doubles_tournament_matches m
    join public.world_doubles_partnerships a on a.id=m.pair_a_id
    join public.world_doubles_partnerships b on b.id=m.pair_b_id
    where m.simulated_on between p_date-13 and p_date
      and (
        p_player_id in (a.player_a_id,a.player_b_id)
        or p_player_id in (b.player_a_id,b.player_b_id)
      )

    union all
    select count(*)::int
    from public.world_junior_doubles_matches m
    join public.world_junior_doubles_entries a on a.id=m.pair_a_entry_id
    join public.world_junior_doubles_entries b on b.id=m.pair_b_entry_id
    where m.simulated_on between p_date-13 and p_date
      and (
        p_player_id in (a.player_a_id,a.player_b_id)
        or p_player_id in (b.player_a_id,b.player_b_id)
      )

    union all
    select count(*)::int
    from public.junior_davis_rubbers r
    join public.junior_davis_ties t on t.id=r.tie_id
    where t.tie_date between p_date-13 and p_date
      and r.status='completed'
      and (
        p_player_id=any(coalesce(r.home_player_ids,'{}'::bigint[]))
        or p_player_id=any(coalesce(r.away_player_ids,'{}'::bigint[]))
      )

    union all
    select count(*)::int
    from public.davis_rubbers r
    join public.davis_ties t on t.id=r.tie_id
    where t.tie_date between p_date-13 and p_date
      and (
        p_player_id=any(coalesce(r.home_player_ids,'{}'::bigint[]))
        or p_player_id=any(coalesce(r.away_player_ids,'{}'::bigint[]))
      )

    union all
    select count(*)::int
    from public.college_dual_rubbers r
    join public.college_duals d on d.id=r.dual_id
    where d.match_date between p_date-13 and p_date
      and r.status='completed'
      and (
        p_player_id=any(r.home_player_ids)
        or p_player_id=any(r.away_player_ids)
      )

    union all
    select count(*)::int
    from public.ncaa_individual_matches m
    where m.played_on between p_date-13 and p_date
      and (
        p_player_id=any(m.side_a_player_ids)
        or p_player_id=any(m.side_b_player_ids)
      )
  ) x;
$function$;

CREATE OR REPLACE FUNCTION public.player_tournament_calendar_conflict(p_player_id bigint, p_tournament_id bigint, p_entry_method text DEFAULT 'direct'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  method text:=lower(coalesce(p_entry_method,'direct'));
  commit_start date;
  commit_end date;
  week_monday date;
  managed_id bigint;
  c record;
begin
  select * into t from public.tournaments where id=p_tournament_id;
  if t.id is null then
    return jsonb_build_object('conflict',true,'reason','tournament_not_found');
  end if;

  select managed_player_id into managed_id from public.career_state where id='demo';

  week_monday:=date_trunc('week',coalesce(t.main_draw_start_date,t.start_date)::timestamp)::date;
  commit_start:=case
    when method in ('qualifying','qualifying_wildcard','protected_qualifying','doubles_qualifying')
      then coalesce(t.qualifying_start_date,t.main_draw_start_date,t.start_date)
    else coalesce(t.main_draw_start_date,t.start_date)
  end;
  commit_end:=coalesce(t.end_date,t.start_date);

  select et.id tournament_id,
         'Junior Davis Cup · '||s.nation tournament_name,
         et.start_date start_date,coalesce(et.end_date,et.start_date) end_date,
         'junior_national_team'::text discipline
  into c
  from public.junior_davis_squads s
  join public.tournaments et on et.id=s.tournament_id
  where s.player_id=p_player_id
    and et.id<>t.id
    and daterange(et.start_date,coalesce(et.end_date,et.start_date),'[]')
        && daterange(commit_start,commit_end,'[]')
  order by et.start_date,et.id
  limit 1;

  if c.tournament_id is not null then
    return jsonb_build_object(
      'conflict',true,'reason','junior_national_team_commitment',
      'other_tournament_id',c.tournament_id,'other_event',c.tournament_name,
      'other_discipline','junior_national_team'
    );
  end if;

  c:=null;
  select dt.id tournament_id,
         'Davis Cup · '||dt.home_nation||' v '||dt.away_nation tournament_name,
         dt.tie_date start_date,dt.tie_date end_date,'davis'::text discipline
  into c
  from public.davis_squad ds
  join public.davis_ties dt on ds.nation in (dt.home_nation,dt.away_nation)
  where ds.player_id=p_player_id
    and dt.status in ('scheduled','completed')
    and dt.tie_date between commit_start and commit_end
  order by dt.tie_date,dt.id
  limit 1;

  if c.tournament_id is not null then
    return jsonb_build_object(
      'conflict',true,'reason','national_team_commitment',
      'other_davis_tie_id',c.tournament_id,'other_event',c.tournament_name,
      'other_discipline','davis'
    );
  end if;

  c:=null;
  select cd.id tournament_id,
         'NCAA · '||h.name||' v '||a.name tournament_name,
         cd.match_date start_date,cd.match_date end_date,
         coalesce(cd.competition,'NCAA Division I')::text discipline
  into c
  from public.players pl
  join public.college_duals cd
    on cd.home_team_id=pl.ncaa_team_id or cd.away_team_id=pl.ncaa_team_id
  join public.college_teams h on h.id=cd.home_team_id
  join public.college_teams a on a.id=cd.away_team_id
  where pl.id=p_player_id
    and pl.ncaa_current=true
    and cd.status in ('scheduled','completed')
    and cd.match_date between commit_start and commit_end
    and (
      (
        coalesce(cd.competition,'NCAA Division I')<>'NCAA Division I'
        and not (t.circuit='ATP' and t.category='Grand Chelem')
      )
      or t.circuit not in ('ATP','Challenger','ITF','Junior')
    )
  order by cd.match_date,cd.id
  limit 1;

  if c.tournament_id is not null then
    return jsonb_build_object(
      'conflict',true,'reason','college_priority_commitment',
      'other_college_dual_id',c.tournament_id,'other_event',c.tournament_name,
      'other_discipline',c.discipline
    );
  end if;

  c:=null;
  select x.tournament_id,x.tournament_name,x.start_date,x.end_date,x.discipline
  into c
  from (
    select ot.id tournament_id,ot.name tournament_name,ot.start_date,ot.end_date,'singles'::text discipline
    from public.world_tournament_entries e
    join public.tournaments ot on ot.id=e.tournament_id
    where e.player_id=p_player_id and ot.id<>t.id
      and daterange(
            coalesce(ot.qualifying_start_date,ot.main_draw_start_date,ot.start_date),
            coalesce(ot.end_date,ot.start_date),'[]'
          ) && daterange(commit_start,commit_end,'[]')

    union all
    select ot.id,ot.name,ot.start_date,ot.end_date,'qualifying'
    from public.world_tournament_qualifying_entries e
    join public.tournaments ot on ot.id=e.tournament_id
    where e.player_id=p_player_id and ot.id<>t.id
      and daterange(
            coalesce(ot.qualifying_start_date,ot.start_date),
            coalesce(ot.qualifying_end_date,ot.main_draw_start_date,ot.end_date,ot.start_date),'[]'
          ) && daterange(commit_start,commit_end,'[]')

    union all
    select ot.id,ot.name,ot.start_date,ot.end_date,'doubles'
    from public.world_doubles_tournament_entries e
    join public.world_doubles_partnerships p on p.id=e.pair_id
    join public.tournaments ot on ot.id=e.tournament_id
    where p_player_id in (p.player_a_id,p.player_b_id) and ot.id<>t.id
      and daterange(
            coalesce(ot.qualifying_start_date,ot.main_draw_start_date,ot.start_date),
            coalesce(ot.end_date,ot.start_date),'[]'
          ) && daterange(commit_start,commit_end,'[]')

    union all
    select ot.id,ot.name,ot.start_date,ot.end_date,'junior_doubles'
    from public.world_junior_doubles_entries e
    join public.tournaments ot on ot.id=e.tournament_id
    where p_player_id in (e.player_a_id,e.player_b_id) and ot.id<>t.id
      and daterange(ot.start_date,coalesce(ot.end_date,ot.start_date),'[]')
          && daterange(commit_start,commit_end,'[]')

    union all
    select ot.id,ot.name,ot.start_date,ot.end_date,'junior_reserved'
    from public.junior_entry_reservations jr
    join public.tournaments ot on ot.id=jr.tournament_id
    where jr.player_id=p_player_id and ot.id<>t.id
      and daterange(ot.start_date,coalesce(ot.end_date,ot.start_date),'[]')
          && daterange(commit_start,commit_end,'[]')

    union all
    select ot.id,ot.name,ot.start_date,ot.end_date,'ncaa_individual'
    from public.ncaa_individual_entries e
    join public.tournaments ot on ot.id=e.tournament_id
    where e.player_id=p_player_id and ot.id<>t.id
      and daterange(ot.start_date,coalesce(ot.end_date,ot.start_date),'[]')
          && daterange(commit_start,commit_end,'[]')

    union all
    select ot.id,ot.name,ot.start_date,ot.end_date,'ncaa_doubles'
    from public.ncaa_individual_doubles_entries e
    join public.tournaments ot on ot.id=e.tournament_id
    where p_player_id in (e.player_a_id,e.player_b_id) and ot.id<>t.id
      and daterange(ot.start_date,coalesce(ot.end_date,ot.start_date),'[]')
          && daterange(commit_start,commit_end,'[]')
  ) x
  order by x.start_date,x.tournament_id
  limit 1;

  if c.tournament_id is not null then
    return jsonb_build_object(
      'conflict',true,'reason','calendar_overlap',
      'other_tournament_id',c.tournament_id,'other_tournament',c.tournament_name,
      'other_discipline',c.discipline
    );
  end if;

  if managed_id is not null and p_player_id=managed_id then
    c:=null;
    select x.tournament_id,x.tournament_name,x.start_date,x.end_date,x.discipline
    into c
    from (
      select tr.tournament_id,ot.name tournament_name,ot.start_date,ot.end_date,'singles'::text discipline,
             coalesce(ot.qualifying_start_date,ot.main_draw_start_date,ot.start_date) event_start
      from public.tournament_runs tr
      join public.tournaments ot on ot.id=tr.tournament_id
      where tr.tournament_id<>t.id
      union all
      select dr.tournament_id,ot.name,ot.start_date,ot.end_date,'doubles',
             coalesce(ot.qualifying_start_date,ot.main_draw_start_date,ot.start_date)
      from public.doubles_runs dr
      join public.tournaments ot on ot.id=dr.tournament_id
      where dr.tournament_id<>t.id
    ) x
    where daterange(x.event_start,coalesce(x.end_date,x.start_date),'[]')
          && daterange(commit_start,commit_end,'[]')
    order by x.event_start
    limit 1;

    if c.tournament_id is not null then
      return jsonb_build_object(
        'conflict',true,'reason','calendar_overlap',
        'other_tournament_id',c.tournament_id,'other_tournament',c.tournament_name,
        'other_discipline',c.discipline
      );
    end if;
  end if;

  if method in ('qualifying','qualifying_wildcard','protected_qualifying','doubles_qualifying') then
    c:=null;
    select x.tournament_id,x.tournament_name,x.result_code,x.discipline
    into c
    from (
      select ot.id tournament_id,ot.name tournament_name,e.result_code,'singles'::text discipline,
             coalesce(ot.end_date,ot.start_date) event_end,
             coalesce(ot.main_draw_start_date,ot.start_date) main_start
      from public.world_tournament_entries e
      join public.tournaments ot on ot.id=e.tournament_id
      where e.player_id=p_player_id and ot.id<>t.id

      union all
      select ot.id,ot.name,e.result_code,'doubles',
             coalesce(ot.end_date,ot.start_date),
             coalesce(ot.main_draw_start_date,ot.start_date)
      from public.world_doubles_tournament_entries e
      join public.world_doubles_partnerships p on p.id=e.pair_id
      join public.tournaments ot on ot.id=e.tournament_id
      where p_player_id in (p.player_a_id,p.player_b_id) and ot.id<>t.id

      union all
      select ot.id,ot.name,e.result_code,'junior_doubles',
             coalesce(ot.end_date,ot.start_date),
             coalesce(ot.main_draw_start_date,ot.start_date)
      from public.world_junior_doubles_entries e
      join public.tournaments ot on ot.id=e.tournament_id
      where p_player_id in (e.player_a_id,e.player_b_id) and ot.id<>t.id
    ) x
    where x.event_end>=commit_start
      and x.main_start<week_monday
      and coalesce(x.result_code,'') in ('W','F','SF')
    order by x.event_end desc
    limit 1;

    if c.tournament_id is not null then
      return jsonb_build_object(
        'conflict',true,'reason','still_competing_before_qualifying',
        'other_tournament_id',c.tournament_id,'other_tournament',c.tournament_name,
        'other_result',c.result_code,'other_discipline',c.discipline,
        'qualifying_start',commit_start
      );
    end if;
  end if;

  return jsonb_build_object(
    'conflict',false,'reason','available',
    'commitment_start',commit_start,'commitment_end',commit_end,'week_monday',week_monday
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.prepare_junior_entry_reservations(p_tournament_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  v_main int;
  v_qslots int;
  v_wc int;
  v_rating_slots int:=0;
  v_direct int;
  v_count int:=0;
begin
  select * into t from public.tournaments where id=p_tournament_id;
  if t.id is null or t.circuit<>'Junior' or not coalesce(t.singles,false) then
    return jsonb_build_object('ok',false,'reason','not_junior_singles');
  end if;

  v_main:=greatest(16,least(128,coalesce(t.singles_draw_size,t.draw_size,32)));
  v_qslots:=case
    when coalesce(t.qualifying_draw_size,0)>0 then public.junior_qualifier_slots(v_main,t.category)
    else 0 end;
  v_wc:=public.junior_main_wildcards(v_main);
  if t.category in ('J30','J60') and v_main=32 then
    v_rating_slots:=least(6,greatest(0,v_main-v_qslots-v_wc));
  end if;
  v_direct:=greatest(0,v_main-v_qslots-v_wc-v_rating_slots);

  if exists(select 1 from public.junior_entry_reservations where tournament_id=t.id) then
    return jsonb_build_object(
      'ok',true,'already',true,
      'reserved',(select count(*) from public.junior_entry_reservations where tournament_id=t.id),
      'direct_slots',v_direct,'rating_slots',v_rating_slots,'wildcards',v_wc,'qualifier_slots',v_qslots
    );
  end if;

  insert into public.junior_entry_reservations(
    tournament_id,player_id,entry_method,reserved_on
  )
  select t.id,p.id,'direct',coalesce(t.qualifying_start_date,t.start_date)
  from public.players p
  where p.career_status='active'
    and p.junior_ranking is not null
    and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
    and p.injury_status='Fit'
    and coalesce(p.fitness,90)>=45
    and coalesce(p.fatigue,20)<=90
    and (
      p.birth_date is null
      or (
        p.birth_date<=t.start_date-interval '13 years'
        and extract(year from t.start_date)::int-extract(year from p.birth_date)::int<=18
      )
    )
    and not (public.player_tournament_calendar_conflict(p.id,t.id,'direct')->>'conflict')::boolean
    and public.junior_player_commits_to_event(p.id,t.id,'singles')
  order by p.junior_ranking,p.current_ability desc,p.id
  limit v_direct
  on conflict do nothing;

  if v_rating_slots>0 then
    insert into public.junior_entry_reservations(
      tournament_id,player_id,entry_method,reserved_on
    )
    select t.id,p.id,'rating_acceptance_2026',coalesce(t.qualifying_start_date,t.start_date)
    from public.players p
    where p.career_status='active'
      and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
      and p.injury_status='Fit'
      and coalesce(p.fitness,90)>=45
      and coalesce(p.fatigue,20)<=90
      and (
        p.birth_date is null
        or (
          p.birth_date<=t.start_date-interval '13 years'
          and extract(year from t.start_date)::int-extract(year from p.birth_date)::int<=18
        )
      )
      and not exists(
        select 1 from public.junior_entry_reservations r
        where r.tournament_id=t.id and r.player_id=p.id
      )
      and not (public.player_tournament_calendar_conflict(p.id,t.id,'direct')->>'conflict')::boolean
      and public.junior_player_commits_to_event(p.id,t.id,'singles')
    order by public.junior_wtn_proxy_score(p.id,t.start_date) desc,
             coalesce(p.junior_ranking,999999),p.id
    limit v_rating_slots
    on conflict do nothing;
  end if;

  insert into public.junior_entry_reservations(
    tournament_id,player_id,entry_method,reserved_on
  )
  select t.id,p.id,'wildcard',coalesce(t.qualifying_start_date,t.start_date)
  from public.players p
  where p.career_status='active'
    and upper(coalesce(p.country,''))=upper(coalesce(t.country,''))
    and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
    and p.injury_status='Fit'
    and coalesce(p.fitness,90)>=45
    and coalesce(p.fatigue,20)<=90
    and (
      p.birth_date is null
      or (
        p.birth_date<=t.start_date-interval '13 years'
        and extract(year from t.start_date)::int-extract(year from p.birth_date)::int<=18
      )
    )
    and not exists(
      select 1 from public.junior_entry_reservations r
      where r.tournament_id=t.id and r.player_id=p.id
    )
    and not (public.player_tournament_calendar_conflict(p.id,t.id,'wildcard')->>'conflict')::boolean
    and public.junior_player_commits_to_event(p.id,t.id,'singles')
  order by public.junior_wtn_proxy_score(p.id,t.start_date) desc,
           coalesce(p.junior_ranking,999999),p.id
  limit v_wc
  on conflict do nothing;

  select count(*) into v_count from public.junior_entry_reservations where tournament_id=t.id;

  return jsonb_build_object(
    'ok',true,'reserved',v_count,
    'direct_slots',v_direct,'rating_slots',v_rating_slots,
    'wildcards',v_wc,'qualifier_slots',v_qslots,
    'model','ITF junior 2026 composition · internal rating proxy used only for J30/J60 rating-based slots'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.refresh_ncaa_doubles_rankings(p_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  v_season int:=extract(year from p_date)::int;
  v_count int;
begin
  delete from public.ncaa_doubles_rankings where snapshot_date=p_date;

  with ranked as (
    select dpp.player_a_id,dpp.player_b_id,dpp.points,dpp.wins,dpp.losses,
           row_number() over(order by dpp.points desc,dpp.wins desc,dpp.losses asc,dpp.player_a_id,dpp.player_b_id)::int rk
    from public.ncaa_doubles_pair_points dpp
    where dpp.season=v_season
  )
  insert into public.ncaa_doubles_rankings(
    season,snapshot_date,ita_rank,player_one_id,player_two_id,
    player_one_name,player_two_name,school,conference,source_label
  )
  select
    v_season::text,p_date,r.rk,r.player_a_id,r.player_b_id,
    p1.name,p2.name,
    case when p1.ncaa_school=p2.ncaa_school then p1.ncaa_school else coalesce(p1.ncaa_school,p2.ncaa_school) end,
    null,
    'Court Boss dynamic NCAA doubles ranking v1'
  from ranked r
  join public.players p1 on p1.id=r.player_a_id
  join public.players p2 on p2.id=r.player_b_id
  order by r.rk
  limit 2000;

  get diagnostics v_count=row_count;
  return jsonb_build_object('rows',v_count,'snapshot_date',p_date,'season',v_season);
end;
$function$;

CREATE OR REPLACE FUNCTION public.refresh_ncaa_team_rankings(p_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  v_count int;
begin
  with records as (
    select t.id,
      count(d.id) filter(where d.status='completed') played,
      count(d.id) filter(where d.status='completed' and d.winner_team_id=t.id) wins,
      count(d.id) filter(where d.status='completed' and d.winner_team_id is distinct from t.id) losses
    from public.college_teams t
    left join public.college_duals d
      on t.id in (d.home_team_id,d.away_team_id)
      and d.match_date<=p_date
      and d.status='completed'
      and coalesce(d.competition,'')<>'NCAA Fall Showcase'
    group by t.id
  ),
  scored as (
    select t.id,
      coalesce(r.wins,0) wins,coalesce(r.losses,0) losses,
      (
        coalesce(r.wins,0)*100
        -coalesce(r.losses,0)*35
        -coalesce(t.preseason_rank,t.ita_rank,64)*1.8
      ) score
    from public.college_teams t
    left join records r on r.id=t.id
  ),
  ranked as (
    select id,wins,losses,
      row_number() over(order by score desc,wins desc,losses asc,id)::int new_rank
    from scored
  )
  update public.college_teams t
  set ita_rank=r.new_rank,
      record=r.wins||'-'||r.losses
  from ranked r
  where t.id=r.id;

  get diagnostics v_count=row_count;

  with pr as (
    select p.id,
      row_number() over(order by
        (
          coalesce(ip.points,0)*.11+
          coalesce(us.current_rating,10)*3.0+
          coalesce(p.current_ability,50)*1.0+
          coalesce(p.form,70)*.12+
          greatest(0,65-coalesce(ct.ita_rank,64))*.16
        ) desc,
        p.id
      )::int new_rank
    from public.players p
    left join public.player_utr_state us on us.player_id=p.id
    left join public.college_teams ct on ct.name=p.ncaa_school
    left join public.ncaa_individual_points ip
      on ip.player_id=p.id and ip.season=extract(year from p_date)::int
    where p.ncaa_current=true and p.career_status='active'
  )
  update public.players p
  set ncaa_rank=pr.new_rank
  from pr where p.id=pr.id;

  return jsonb_build_object('teams_ranked',v_count,'date',p_date);
end;
$function$;

CREATE OR REPLACE FUNCTION public.simulate_injuries_week(p_date date, p_week integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  new_count int:=0;
  rec record;
  typ text;
  sev text;
  days_out int;
  risk_score numeric;
  v_recovery jsonb;
  v_area text;
begin
  update injuries
  set status='recovered'
  where lower(coalesce(status,''))='active' and expected_return <= p_date;

  v_recovery:=public.process_recovered_injury_effects(p_date);

  for rec in
    select
      p.id,p.fatigue,p.ranking,p.age,p.fitness,
      public.player_recent_match_load(p.id,p_date) as recent_matches,
      coalesce(dp.injury_proneness,10) as injury_proneness,
      coalesce(pa.natural_fitness,10) as natural_fitness,
      coalesce(pa.recovery,10) as recovery,
      coalesce(pa.flexibility,10) as flexibility,
      coalesce(v.recurrence_risk,0) as recurrence_risk,
      v.body_area as vulnerable_area,
      coalesce(tl.intensity,10) as training_intensity,
      coalesce(tl.injury_load_modifier,1) as training_risk_modifier,
      coalesce(tl.recovery_days,1) as training_recovery_days
    from players p
    left join player_development_profiles dp on dp.player_id=p.id
    left join player_attributes pa on pa.player_id=p.id
    left join public.player_training_load_profiles tl on tl.player_id=p.id
    left join lateral (
      select iv.body_area,iv.recurrence_risk
      from player_injury_vulnerabilities iv
      where iv.player_id=p.id
      order by iv.recurrence_risk desc,iv.episodes desc
      limit 1
    ) v on true
    where (
        p.ranking_current=true
        or p.doubles_ranking is not null
        or p.junior_ranking is not null
        or p.itf_ranking is not null
        or p.ncaa_current=true
      )
      and p.career_status='active'
      and not exists(
        select 1 from injuries i
        where i.player_id=p.id and lower(coalesce(i.status,''))='active'
      )
      and p.injury_status='Fit'
    order by
      (coalesce(p.fatigue,20)>=55) desc,
      recent_matches desc,
      injury_proneness desc,
      mod(abs(hashtext('inj-candidate|'||p.id::text||'|'||p_week::text)),100000),
      p.id
    limit 3000
  loop
    risk_score:=
      greatest(0,coalesce(rec.fatigue,20)-28)*.55+
      greatest(0,coalesce(rec.recent_matches,0)-2)*3.2+
      rec.injury_proneness*1.35+
      greatest(0,12-rec.natural_fitness)*1.2+
      greatest(0,10-rec.flexibility)*.8+
      greatest(0,coalesce(rec.age,24)-30)*.8+
      greatest(0,78-coalesce(rec.fitness,90))*.20+
      rec.recurrence_risk*.22+
      greatest(0,rec.training_intensity-10)*.75+
      greatest(0,rec.training_risk_modifier-1)*14-
      greatest(0,rec.training_recovery_days-1)*.9;

    if mod(abs(hashtext(rec.id::text||'|'||p_week::text||'|'||p_date::text)),1000)
       >= least(90,round(risk_score)::int) then
      continue;
    end if;

    if rec.vulnerable_area is not null
       and rec.recurrence_risk>=25
       and mod(abs(hashtext('relapse|'||rec.id::text||'|'||p_week::text)),100)
           < least(68,18+rec.recurrence_risk) then
      v_area:=rec.vulnerable_area;
      typ:=case v_area
        when 'ischio' then 'Rechute ischio-jambiers'
        when 'épaule' then 'Rechute épaule'
        when 'cheville' then 'Nouvelle entorse cheville'
        when 'poignet' then 'Rechute poignet'
        when 'dos' then 'Rechute lombaire'
        when 'genou' then 'Rechute genou'
        when 'coude' then 'Rechute coude'
        else 'Rechute musculaire'
      end;
      days_out:=10+round(rec.recurrence_risk*.25)::int+mod(rec.id::int+p_week,10);
    else
      case mod(abs(hashtext('type|'||rec.id::text||'|'||p_week::text)),8)
        when 0 then typ:='Élongation ischio-jambiers'; days_out:=14+mod(rec.id::int+p_week,15);
        when 1 then typ:='Douleur épaule'; days_out:=10+mod(rec.id::int+p_week,12);
        when 2 then typ:='Entorse cheville'; days_out:=18+mod(rec.id::int+p_week,18);
        when 3 then typ:='Inflammation poignet'; days_out:=12+mod(rec.id::int+p_week,13);
        when 4 then typ:='Surcharge lombaire'; days_out:=8+mod(rec.id::int+p_week,12);
        when 5 then typ:='Douleur genou'; days_out:=16+mod(rec.id::int+p_week,17);
        when 6 then typ:='Inflammation coude'; days_out:=10+mod(rec.id::int+p_week,14);
        else typ:='Surcharge musculaire'; days_out:=7+mod(rec.id::int+p_week,9);
      end case;
      v_area:=public.injury_body_area(typ);
    end if;

    days_out:=greatest(5,days_out-greatest(0,rec.recovery-10)/2);
    sev:=case when days_out>=35 then 'Élevée' when days_out>=18 then 'Modérée' else 'Faible' end;

    insert into injuries(player_id,injury_type,severity,started_at,expected_return,aggravation_risk,treatment,status)
    values(
      rec.id,typ,sev,p_date,p_date+days_out,
      least(95,15+round(risk_score*.75)::int+round(rec.recurrence_risk*.15)::int),
      case
        when rec.recurrence_risk>=35 then 'Rééducation + prévention rechute'
        when days_out>=20 then 'Repos + rééducation'
        else 'Repos + soins'
      end,
      'active'
    );

    update players
    set fitness=greatest(35,fitness-case when days_out>=28 then 20 when days_out>=18 then 14 else 8 end),
        fatigue=greatest(0,fatigue-8),
        injury_status=typ
    where id=rec.id;

    new_count:=new_count+1;
    exit when new_count>=14;
  end loop;

  return jsonb_build_object(
    'new_injuries',new_count,
    'recovery_processing',v_recovery,
    'model','fatigue + injury proneness + natural fitness + recovery + age + recurrence history + training load'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.simulate_junior_davis_cup(p_from_date date, p_to_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  rec record;
  field jsonb;
  sim jsonb;
  adv jsonb;
  simulated int:=0;
begin
  select * into t
  from public.tournaments
  where category='Junior Davis Cup'
    and circuit='Junior'
    and coalesce(is_active,true)=true
    and start_date<=p_to_date
    and coalesce(end_date,start_date)>=p_from_date
  order by start_date
  limit 1;

  if t.id is null then
    return jsonb_build_object('ties_simulated',0,'active_event',false);
  end if;

  field:=public.ensure_junior_davis_field(t.id);

  loop
    select * into rec
    from public.junior_davis_ties
    where tournament_id=t.id
      and status='scheduled'
      and tie_date>p_from_date
      and tie_date<=p_to_date
    order by tie_date,
      case stage
        when 'Group' then 1
        when 'QF' then 2
        when 'P9-QF' then 3
        when 'SF' then 4
        when 'P5-SF' then 5
        when 'P9-SF' then 6
        when 'P13-SF' then 7
        when 'F' then 8
        else 9 end,
      id
    limit 1;

    exit when rec.id is null;

    sim:=public.simulate_junior_davis_tie(rec.id);
    if coalesce((sim->>'ok')::boolean,false) then
      simulated:=simulated+1;
    end if;

    adv:=public.advance_junior_davis_bracket(t.id);
  end loop;

  adv:=public.advance_junior_davis_bracket(t.id);

  return jsonb_build_object(
    'ties_simulated',simulated,
    'field',field,
    'advancement',adv,
    'tournament_id',t.id,
    'model','ITF Junior Davis Cup 2026 · 16 nations · groups + full placement 1-16'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.simulate_junior_davis_tie(p_tie_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  tie public.junior_davis_ties%rowtype;
  hp bigint[];
  ap bigint[];
  hd bigint[];
  ad bigint[];
  h1 bigint; h2 bigint;
  a1 bigint; a2 bigint;
  r jsonb;
  hs int:=0;
  ascore int:=0;
  homewin boolean;
  winner text;
  loser text;
  is_group boolean;
begin
  select * into tie from public.junior_davis_ties where id=p_tie_id for update;
  if tie.id is null then
    return jsonb_build_object('ok',false,'reason','tie_not_found');
  end if;
  if tie.status='completed' then
    return jsonb_build_object('ok',true,'already',true,'tie_id',tie.id);
  end if;

  select array_agg(s.player_id order by s.squad_order)
  into hp
  from public.junior_davis_squads s
  join public.players p on p.id=s.player_id
  where s.tournament_id=tie.tournament_id
    and s.season=tie.season
    and s.nation=tie.home_nation
    and p.career_status='active'
    and p.injury_status='Fit'
    and coalesce(p.fitness,90)>=35;

  select array_agg(s.player_id order by s.squad_order)
  into ap
  from public.junior_davis_squads s
  join public.players p on p.id=s.player_id
  where s.tournament_id=tie.tournament_id
    and s.season=tie.season
    and s.nation=tie.away_nation
    and p.career_status='active'
    and p.injury_status='Fit'
    and coalesce(p.fitness,90)>=35;

  if coalesce(array_length(hp,1),0)<2 or coalesce(array_length(ap,1),0)<2 then
    homewin:=coalesce(array_length(hp,1),0)>=2;
    hs:=case when homewin then 3 else 0 end;
    ascore:=case when homewin then 0 else 3 end;
    winner:=case when homewin then tie.home_nation else tie.away_nation end;
    loser:=case when homewin then tie.away_nation else tie.home_nation end;

    update public.junior_davis_ties
    set status='completed',home_score=hs,away_score=ascore,
        winner_nation=winner,loser_nation=loser
    where id=tie.id;

    return jsonb_build_object('ok',true,'tie_id',tie.id,'walkover',true,'winner_nation',winner);
  end if;

  h1:=hp[1]; h2:=hp[2];
  a1:=ap[1]; a2:=ap[2];
  is_group:=tie.stage='Group';

  delete from public.junior_davis_rubbers where tie_id=tie.id;

  -- Number 2 vs Number 2.
  r:=public.junior_davis_singles_rubber(h2,a2,tie.tie_date,tie.id||'|S2');
  homewin:=coalesce((r->>'home_win')::boolean,false);
  if homewin then hs:=hs+1; else ascore:=ascore+1; end if;
  insert into public.junior_davis_rubbers(
    tie_id,rubber_no,rubber_type,home_player_ids,away_player_ids,winner_nation,
    score,home_win_probability,status,sets_home,sets_away,games_home,games_away,model_version
  ) values(
    tie.id,1,'Singles 2',array[h2],array[a2],
    case when homewin then tie.home_nation else tie.away_nation end,
    r->>'score',(r->>'home_probability')::numeric,'completed',
    coalesce((r->>'sets_home')::int,0),coalesce((r->>'sets_away')::int,0),
    coalesce((r->>'games_home')::int,0),coalesce((r->>'games_away')::int,0),
    'CB-JDC-v2-ITF2026'
  );

  -- Number 1 vs Number 1.
  r:=public.junior_davis_singles_rubber(h1,a1,tie.tie_date,tie.id||'|S1');
  homewin:=coalesce((r->>'home_win')::boolean,false);
  if homewin then hs:=hs+1; else ascore:=ascore+1; end if;
  insert into public.junior_davis_rubbers(
    tie_id,rubber_no,rubber_type,home_player_ids,away_player_ids,winner_nation,
    score,home_win_probability,status,sets_home,sets_away,games_home,games_away,model_version
  ) values(
    tie.id,2,'Singles 1',array[h1],array[a1],
    case when homewin then tie.home_nation else tie.away_nation end,
    r->>'score',(r->>'home_probability')::numeric,'completed',
    coalesce((r->>'sets_home')::int,0),coalesce((r->>'sets_away')::int,0),
    coalesce((r->>'games_home')::int,0),coalesce((r->>'games_away')::int,0),
    'CB-JDC-v2-ITF2026'
  );

  -- Pick the best two doubles options among the three selected players.
  select array_agg(x.player_id order by x.score desc,x.player_id)
  into hd
  from (
    select s.player_id,
      coalesce(pa.doubles,10)*1.5+
      coalesce(pa.doubles_communication,10)*.55+
      coalesce(p.current_ability,50)*.40+
      coalesce(p.form,70)*.08-
      coalesce(p.fatigue,20)*.05 score
    from public.junior_davis_squads s
    join public.players p on p.id=s.player_id
    left join public.player_attributes pa on pa.player_id=p.id
    where s.tournament_id=tie.tournament_id
      and s.season=tie.season
      and s.nation=tie.home_nation
      and p.injury_status='Fit'
      and coalesce(p.fitness,90)>=35
    order by score desc,p.id
    limit 2
  ) x;

  select array_agg(x.player_id order by x.score desc,x.player_id)
  into ad
  from (
    select s.player_id,
      coalesce(pa.doubles,10)*1.5+
      coalesce(pa.doubles_communication,10)*.55+
      coalesce(p.current_ability,50)*.40+
      coalesce(p.form,70)*.08-
      coalesce(p.fatigue,20)*.05 score
    from public.junior_davis_squads s
    join public.players p on p.id=s.player_id
    left join public.player_attributes pa on pa.player_id=p.id
    where s.tournament_id=tie.tournament_id
      and s.season=tie.season
      and s.nation=tie.away_nation
      and p.injury_status='Fit'
      and coalesce(p.fitness,90)>=35
    order by score desc,p.id
    limit 2
  ) x;

  if is_group or (hs<2 and ascore<2) then
    r:=public.junior_davis_doubles_rubber(
      hd[1],hd[2],ad[1],ad[2],tie.id,tie.tie_date,tie.id||'|D'
    );
    homewin:=coalesce((r->>'home_win')::boolean,false);
    if homewin then hs:=hs+1; else ascore:=ascore+1; end if;
    insert into public.junior_davis_rubbers(
      tie_id,rubber_no,rubber_type,home_player_ids,away_player_ids,winner_nation,
      score,home_win_probability,status,sets_home,sets_away,games_home,games_away,model_version
    ) values(
      tie.id,3,'Doubles',array[hd[1],hd[2]],array[ad[1],ad[2]],
      case when homewin then tie.home_nation else tie.away_nation end,
      r->>'score',(r->>'home_probability')::numeric,'completed',
      coalesce((r->>'sets_home')::int,0),coalesce((r->>'sets_away')::int,0),
      coalesce((r->>'games_home')::int,0),coalesce((r->>'games_away')::int,0),
      'CB-JDC-v2-ITF2026'
    );
  else
    insert into public.junior_davis_rubbers(
      tie_id,rubber_no,rubber_type,home_player_ids,away_player_ids,status
    ) values(
      tie.id,3,'Doubles',array[hd[1],hd[2]],array[ad[1],ad[2]],'not_required'
    );
  end if;

  winner:=case when hs>ascore then tie.home_nation else tie.away_nation end;
  loser:=case when hs>ascore then tie.away_nation else tie.home_nation end;

  update public.junior_davis_ties
  set status='completed',home_score=hs,away_score=ascore,
      winner_nation=winner,loser_nation=loser
  where id=tie.id;

  update public.players
  set fatigue=least(100,coalesce(fatigue,20)+
      case
        when id in (h1,h2,a1,a2) then 3
        else 0 end
      +case
        when id=any(coalesce(hd,'{}'::bigint[]))
          or id=any(coalesce(ad,'{}'::bigint[])) then 2
        else 0 end),
      fitness=greatest(35,coalesce(fitness,90)-1)
  where id=any(coalesce(hp,'{}'::bigint[]))
     or id=any(coalesce(ap,'{}'::bigint[]));

  return jsonb_build_object(
    'ok',true,'tie_id',tie.id,'stage',tie.stage,
    'home',tie.home_nation,'away',tie.away_nation,
    'home_score',hs,'away_score',ascore,'winner_nation',winner
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.simulate_junior_qualifying_full(p_tournament_id bigint, p_simulated_on date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  v_main int;
  v_qdraw int;
  v_qslots int;
  v_qwc int;
  v_selected int;
  v_section int;
  v_section_count int;
  v_size int;
  v_bracket int;
  v_byes int;
  v_round int;
  v_pos int;
  v_next_pos int;
  v_a bigint;
  v_b bigint;
  v_w bigint;
  v_l bigint;
  v_prob numeric;
  v_roll numeric;
  v_awon boolean;
  v_match jsonb;
  v_score text;
  v_match_no int:=0;
  v_total_matches int:=0;
  v_qualifiers int:=0;
  v_played date;
  v_managed bigint;
begin
  select * into t
  from public.tournaments
  where id=p_tournament_id
    and circuit='Junior'
    and singles=true
    and coalesce(is_active,true)=true;

  if t.id is null then
    return jsonb_build_object('ok',false,'reason','tournament_not_found');
  end if;

  if t.category in ('Junior Davis Cup','Junior Finals','Junior Double Finals')
     or coalesce(t.qualifying_draw_size,0)<=0 then
    return jsonb_build_object('ok',true,'skipped','no_junior_qualifying');
  end if;

  if exists(
    select 1 from public.world_tournament_qualifying_entries
    where tournament_id=t.id
      and source_label like 'ITF Junior 2026 qualifying%'
  ) then
    return jsonb_build_object(
      'ok',true,'already_simulated',true,
      'qualifiers',(select count(*) from public.world_tournament_qualifying_entries where tournament_id=t.id and qualified=true)
    );
  end if;

  perform public.prepare_junior_entry_reservations(t.id);
  select managed_player_id into v_managed from public.career_state where id='demo';

  v_main:=greatest(16,least(128,coalesce(t.singles_draw_size,t.draw_size,32)));
  v_qdraw:=greatest(8,least(128,coalesce(t.qualifying_draw_size,32)));
  v_qslots:=public.junior_qualifier_slots(v_main,t.category);
  v_qwc:=least(v_qdraw,public.junior_qualifying_wildcards(v_qdraw));

  delete from public.world_tournament_matches
  where tournament_id=t.id and is_qualifying=true;

  delete from public.world_tournament_qualifying_entries
  where tournament_id=t.id;

  drop table if exists pg_temp.cb_jq_pool;
  create temporary table cb_jq_pool(
    player_id bigint primary key,
    rankv int,
    score numeric,
    entry_method text not null,
    rn int,
    section_no int
  ) on commit drop;

  -- Qualifying wild cards first.
  insert into cb_jq_pool(player_id,rankv,score,entry_method)
  select p.id,coalesce(p.junior_ranking,999999),
         public.junior_wtn_proxy_score(p.id,t.start_date),
         'qualifying_wildcard'
  from public.players p
  where p.id is distinct from v_managed
    and p.career_status='active'
    and upper(coalesce(p.country,''))=upper(coalesce(t.country,''))
    and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
    and p.injury_status='Fit'
    and coalesce(p.fitness,90)>=45
    and coalesce(p.fatigue,20)<=90
    and (
      p.birth_date is null
      or (
        p.birth_date<=t.start_date-interval '13 years'
        and extract(year from t.start_date)::int-extract(year from p.birth_date)::int<=18
      )
    )
    and not exists(
      select 1 from public.junior_entry_reservations r
      where r.tournament_id=t.id and r.player_id=p.id
    )
    and not (public.player_tournament_calendar_conflict(p.id,t.id,'qualifying_wildcard')->>'conflict')::boolean
    and public.junior_player_commits_to_event(p.id,t.id,'singles')
  order by public.junior_wtn_proxy_score(p.id,t.start_date) desc,
           coalesce(p.junior_ranking,999999),p.id
  limit v_qwc;

  insert into cb_jq_pool(player_id,rankv,score,entry_method)
  select p.id,coalesce(p.junior_ranking,999999),
         (
           greatest(0,2500-coalesce(p.junior_ranking,2500))*.055+
           public.junior_wtn_proxy_score(p.id,t.start_date)*.18+
           (mod(abs(hashtext('jq-entry|'||t.id||'|'||p.id)),1000)::numeric/1000.0)*2
         ),
         case when t.category in ('J30','J60') and p.junior_ranking is null
              then 'rating_qualifying_2026' else 'qualifying' end
  from public.players p
  where p.id is distinct from v_managed
    and p.career_status='active'
    and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
    and p.injury_status='Fit'
    and coalesce(p.fitness,90)>=45
    and coalesce(p.fatigue,20)<=90
    and (
      p.birth_date is null
      or (
        p.birth_date<=t.start_date-interval '13 years'
        and extract(year from t.start_date)::int-extract(year from p.birth_date)::int<=18
      )
    )
    and (
      p.junior_ranking is not null
      or t.category in ('J30','J60')
    )
    and not exists(select 1 from cb_jq_pool q where q.player_id=p.id)
    and not exists(
      select 1 from public.junior_entry_reservations r
      where r.tournament_id=t.id and r.player_id=p.id
    )
    and not (public.player_tournament_calendar_conflict(p.id,t.id,'qualifying')->>'conflict')::boolean
    and public.junior_player_commits_to_event(p.id,t.id,'singles')
  order by 3 desc,p.id
  limit greatest(0,v_qdraw-(select count(*) from cb_jq_pool));

  select count(*) into v_selected from cb_jq_pool;
  if v_selected<v_qslots then
    return jsonb_build_object('ok',false,'reason','insufficient_qualifying_field','selected',v_selected,'needed',v_qdraw);
  end if;

  with ranked as (
    select player_id,row_number() over(
      order by case when entry_method='qualifying_wildcard' then 1 else 0 end,
               rankv,score desc,player_id
    )::int rn
    from cb_jq_pool
  )
  update cb_jq_pool q
  set rn=r.rn,
      section_no=((r.rn-1)%v_qslots)+1
  from ranked r where r.player_id=q.player_id;

  insert into public.world_tournament_qualifying_entries(
    tournament_id,player_id,entry_method,ranking_at_entry,result_code,result_label,
    qualified,points_awarded,prize_awarded,prize_currency,prize_is_estimate,
    simulated_on,source_label
  )
  select
    t.id,q.player_id,q.entry_method,q.rankv,
    'Q1','Qualifications junior',false,0,0,null,false,
    coalesce(t.qualifying_end_date,p_simulated_on,t.start_date-1),
    'ITF Junior 2026 qualifying · section knockout'
  from cb_jq_pool q;

  for v_section in 1..v_qslots loop
    drop table if exists pg_temp.cb_jq_current;
    drop table if exists pg_temp.cb_jq_next;
    create temporary table cb_jq_current(pos int primary key,player_id bigint) on commit drop;
    create temporary table cb_jq_next(pos int primary key,player_id bigint) on commit drop;

    insert into cb_jq_current(pos,player_id)
    select row_number() over(order by rankv,score desc,player_id)::int,player_id
    from cb_jq_pool
    where section_no=v_section
    order by rankv,score desc,player_id;

    select count(*) into v_size from cb_jq_current;
    v_round:=1;

    while v_size>1 loop
      v_bracket:=1;
      while v_bracket<v_size loop v_bracket:=v_bracket*2; end loop;
      v_byes:=v_bracket-v_size;
      truncate cb_jq_next;
      v_next_pos:=0;

      if v_byes>0 then
        for v_pos in 1..v_byes loop
          v_next_pos:=v_next_pos+1;
          insert into cb_jq_next(pos,player_id)
          select v_next_pos,player_id from cb_jq_current where pos=v_pos;
        end loop;
      end if;

      v_pos:=v_byes+1;
      while v_pos<=v_size loop
        select player_id into v_a from cb_jq_current where pos=v_pos;
        select player_id into v_b from cb_jq_current where pos=v_pos+1;
        exit when v_a is null or v_b is null;

        v_match:=public.player_matchup_probability_v4(
          v_a,v_b,t.surface,
          least(coalesce(t.qualifying_end_date,t.start_date-1),
                coalesce(t.qualifying_start_date,t.start_date-2)+(v_round-1)),
          coalesce(t.court_speed,case when t.surface ilike 'Terre%' then .68 when t.surface ilike 'Gazon%' then 1.15 else 1.0 end),
          3
        );
        v_prob:=greatest(.02,least(.98,coalesce((v_match->>'player_a_probability')::numeric,.5)));
        v_roll:=mod(abs(hashtext('junior-q|'||t.id||'|'||v_section||'|'||v_round||'|'||v_a||'|'||v_b)),10000)/10000.0;
        v_awon:=v_roll<v_prob;
        v_w:=case when v_awon then v_a else v_b end;
        v_l:=case when v_awon then v_b else v_a end;
        v_score:=public.world_tournament_score(v_prob,v_awon,3);
        v_played:=least(
          coalesce(t.qualifying_end_date,t.start_date-1),
          coalesce(t.qualifying_start_date,t.start_date-2)+(v_round-1)
        );

        v_match_no:=v_match_no+1;
        insert into public.world_tournament_matches(
          tournament_id,round_no,round_code,group_name,match_no,
          player_a_id,player_b_id,winner_id,loser_id,score,best_of,
          player_a_win_probability,court_speed,model_version,matchup_components,
          simulated_on,is_qualifying
        ) values(
          t.id,100+v_round,'Q'||v_round,'Q-Section '||v_section,v_match_no,
          v_a,v_b,v_w,v_l,v_score,3,round(v_prob,4),
          coalesce(t.court_speed,1.0),'CB-JUNIOR-Q-v1',
          coalesce(v_match->'components','{}'::jsonb),
          v_played,true
        );

        update public.world_tournament_qualifying_entries
        set result_code='Q'||v_round,
            result_label='Qualifications · tour '||v_round,
            last_opponent_id=v_w,
            last_opponent_name=(select name from public.players where id=v_w),
            last_score=case when v_l=v_a then v_score else public.world_invert_tennis_score(v_score) end
        where tournament_id=t.id and player_id=v_l;

        update public.players
        set fatigue=least(100,coalesce(fatigue,20)+2),
            fitness=greatest(35,coalesce(fitness,90)-1)
        where id in (v_a,v_b);

        v_next_pos:=v_next_pos+1;
        insert into cb_jq_next(pos,player_id) values(v_next_pos,v_w);
        v_total_matches:=v_total_matches+1;
        v_pos:=v_pos+2;
      end loop;

      truncate cb_jq_current;
      insert into cb_jq_current select * from cb_jq_next order by pos;
      select count(*) into v_size from cb_jq_current;
      v_round:=v_round+1;
    end loop;

    select player_id into v_w from cb_jq_current order by pos limit 1;
    if v_w is not null then
      update public.world_tournament_qualifying_entries
      set result_code='Q',
          result_label='Qualifié',
          qualified=true,
          last_opponent_id=null
      where tournament_id=t.id and player_id=v_w;
      v_qualifiers:=v_qualifiers+1;
    end if;
  end loop;

  return jsonb_build_object(
    'ok',true,'tournament_id',t.id,'qualifying_draw',v_selected,
    'qualifier_slots',v_qslots,'qualifiers',v_qualifiers,
    'matches_simulated',v_total_matches,
    'model','ITF Junior 2026 qualifying v1'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.simulate_junior_qualifying_window(p_from_date date, p_to_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t record;
  r jsonb;
  simulated int:=0;
  already int:=0;
  skipped int:=0;
  qualifiers int:=0;
begin
  for t in
    select *
    from public.tournaments
    where circuit='Junior'
      and singles=true
      and coalesce(is_active,true)=true
      and category not in ('Junior Davis Cup','Junior Finals','Junior Double Finals')
      and coalesce(qualifying_draw_size,0)>0
      and coalesce(qualifying_end_date,start_date-1)>greatest(p_from_date,date '2025-12-01')
      and coalesce(qualifying_end_date,start_date-1)<=p_to_date
    order by coalesce(qualifying_end_date,start_date-1),id
    limit 120
  loop
    r:=public.simulate_junior_qualifying_full(
      t.id,coalesce(t.qualifying_end_date,t.start_date-1,p_to_date)
    );

    if coalesce((r->>'ok')::boolean,false)=false then
      skipped:=skipped+1;
    elsif coalesce((r->>'already_simulated')::boolean,false) then
      already:=already+1;
      qualifiers:=qualifiers+coalesce((r->>'qualifiers')::int,0);
    elsif r ? 'skipped' then
      skipped:=skipped+1;
    else
      simulated:=simulated+1;
      qualifiers:=qualifiers+coalesce((r->>'qualifiers')::int,0);
    end if;
  end loop;

  return jsonb_build_object(
    'qualifying_simulated',simulated,
    'already_simulated',already,
    'skipped',skipped,
    'qualifiers_created',qualifiers,
    'from',p_from_date,'to',p_to_date,
    'model','ITF Junior 2026 qualifying window v1'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.simulate_junior_world_singles_full(p_from_date date, p_to_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  v_managed bigint;
  v_draw int;
  v_bracket int;
  v_rounds int;
  v_size int;
  v_round int;
  v_pos int;
  v_next int;
  v_a bigint;
  v_b bigint;
  v_w bigint;
  v_l bigint;
  v_a_name text;
  v_b_name text;
  v_w_name text;
  v_l_name text;
  v_match jsonb;
  v_prob numeric;
  v_awon boolean;
  v_score text;
  v_code text;
  v_winner bigint;
  v_finalist bigint;
  v_singles int:=0;
  v_matches int:=0;
  v_selected int;
  rr record;
begin
  select managed_player_id into v_managed from public.career_state where id='demo';

  for t in
    select *
    from public.tournaments
    where circuit='Junior'
      and singles=true
      and coalesce(is_active,true)=true
      and coalesce(end_date,start_date)>p_from_date
      and coalesce(end_date,start_date)<=p_to_date
      and category not in ('Junior Davis Cup','Junior Finals','Junior Double Finals')
      and not exists(select 1 from public.world_tournament_simulations s where s.tournament_id=tournaments.id)
    order by
      date_trunc('week',start_date::timestamp),
      case
        when category='Junior Grand Slam' then 100
        when category='J500' then 90
        when category='J300' then 80
        when category='J200' then 70
        when category='J100' then 60
        when category='J60' then 50
        when category='J30' then 40
        else 10 end desc,
      coalesce(end_date,start_date),id
    limit 100
  loop
    v_draw:=greatest(16,least(64,coalesce(t.singles_draw_size,t.draw_size,32)));

    drop table if exists pg_temp.cb_j_entries;
    create temporary table cb_j_entries(
      player_id bigint primary key,
      name text not null,
      rank_at_entry int,
      seed int,
      draw_slot int,
      entry_method text not null default 'direct',
      qualifying_points int not null default 0,
      group_name text,
      wins int not null default 0,
      losses int not null default 0,
      result_code text,
      result_label text,
      points_awarded int not null default 0,
      last_opponent_id bigint,
      last_opponent_name text,
      last_score text
    ) on commit drop;

    perform public.prepare_junior_entry_reservations(t.id);

    -- Qualifiers earned their place in the qualifying window.
    insert into cb_j_entries(
      player_id,name,rank_at_entry,entry_method,qualifying_points
    )
    select p.id,p.name,coalesce(p.junior_ranking,999999)::int,
           'qualifier',coalesce(q.points_awarded,0)
    from public.world_tournament_qualifying_entries q
    join public.players p on p.id=q.player_id
    where q.tournament_id=t.id
      and q.qualified=true
      and p.career_status='active'
      and p.injury_status='Fit'
      and coalesce(p.fitness,90)>=40
    order by coalesce(p.junior_ranking,999999),p.current_ability desc,p.id
    limit public.junior_qualifier_slots(v_draw,t.category)
    on conflict(player_id) do nothing;

    -- Direct acceptances, 2026 rating-based slots and host wild cards were
    -- reserved before qualifying, so they cannot leak into the qualifying draw.
    insert into cb_j_entries(
      player_id,name,rank_at_entry,entry_method,qualifying_points
    )
    select p.id,p.name,coalesce(p.junior_ranking,999999)::int,
           r.entry_method,0
    from public.junior_entry_reservations r
    join public.players p on p.id=r.player_id
    where r.tournament_id=t.id
      and p.career_status='active'
      and p.injury_status='Fit'
      and coalesce(p.fitness,90)>=40
      and not (public.player_tournament_calendar_conflict(p.id,t.id,'direct')->>'conflict')::boolean
    order by
      case r.entry_method
        when 'direct' then 1
        when 'rating_acceptance_2026' then 2
        when 'wildcard' then 3
        else 4 end,
      coalesce(p.junior_ranking,999999),p.current_ability desc,p.id
    on conflict(player_id) do nothing;

    -- Fill any late vacancy with an alternate, never with a player who already
    -- lost in this event's qualifying draw.
    insert into cb_j_entries(
      player_id,name,rank_at_entry,entry_method,qualifying_points
    )
    select p.id,p.name,coalesce(p.junior_ranking,999999)::int,
           'alternate',0
    from public.players p
    where p.career_status='active'
      and p.id is distinct from v_managed
      and p.junior_ranking is not null
      and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
      and p.injury_status='Fit'
      and coalesce(p.fitness,90)>=45
      and coalesce(p.fatigue,20)<=90
      and (
        p.birth_date is null
        or (
          p.birth_date<=t.start_date-interval '13 years'
          and extract(year from t.start_date)::int-extract(year from p.birth_date)::int<=18
        )
      )
      and not exists(select 1 from cb_j_entries e where e.player_id=p.id)
      and not exists(
        select 1 from public.world_tournament_qualifying_entries q
        where q.tournament_id=t.id and q.player_id=p.id
      )
      and not (public.player_tournament_calendar_conflict(p.id,t.id,'direct')->>'conflict')::boolean
      and public.ai_player_commits_to_tournament(p.id,t.id)
      and public.junior_player_commits_to_event(p.id,t.id,'singles')
    order by coalesce(p.junior_ranking,999999),p.current_ability desc,p.id
    limit greatest(0,v_draw-(select count(*) from cb_j_entries))
    on conflict(player_id) do nothing;

    with seeded as (
      select player_id,
             row_number() over(
               order by coalesce(rank_at_entry,999999),
                        (select current_ability from public.players p where p.id=cb_j_entries.player_id) desc,
                        player_id
             )::int rn
      from cb_j_entries
    )
    update cb_j_entries e
    set seed=s.rn
    from seeded s
    where s.player_id=e.player_id;

    select count(*) into v_selected from cb_j_entries;
    if v_selected<>v_draw then
      continue;
    end if;

    delete from public.world_tournament_matches where tournament_id=t.id and is_qualifying=false;
    delete from public.world_tournament_entries where tournament_id=t.id;

    if t.junior_draw_format='round_robin_to_elimination'
       and t.category in ('J30','J60') and v_draw=32 then

      update cb_j_entries
      set group_name=chr(65+((seed-1)%8))
      where seed<=8;

      with rem as (
        select player_id,row_number() over(order by md5('jrr|'||t.id::text||'|'||player_id::text)) rn
        from cb_j_entries where group_name is null
      )
      update cb_j_entries e
      set group_name=chr(65+(((r.rn-1)%8)::int))
      from rem r where e.player_id=r.player_id;

      for rr in
        select a.player_id a_id,b.player_id b_id,a.name a_name,b.name b_name,a.group_name,
               row_number() over(order by a.group_name,a.seed,b.seed)::int match_no
        from cb_j_entries a
        join cb_j_entries b on b.group_name=a.group_name and b.seed>a.seed
        order by a.group_name,a.seed,b.seed
      loop
        v_a:=rr.a_id;v_b:=rr.b_id;v_a_name:=rr.a_name;v_b_name:=rr.b_name;
        v_match:=public.player_matchup_probability_v4(
          v_a,v_b,t.surface,t.start_date,
          coalesce(t.court_speed,case when t.surface ilike 'Terre%' then .68 when t.surface ilike 'Gazon%' then 1.15 else 1.0 end),3
        );
        v_prob:=greatest(.02,least(.98,coalesce((v_match->>'player_a_probability')::numeric,.5)));
        v_awon:=random()<v_prob;
        v_w:=case when v_awon then v_a else v_b end;
        v_l:=case when v_awon then v_b else v_a end;
        v_w_name:=case when v_awon then v_a_name else v_b_name end;
        v_l_name:=case when v_awon then v_b_name else v_a_name end;
        v_score:=public.world_tournament_score(v_prob,v_awon,3);

        insert into public.world_tournament_matches(
          tournament_id,round_no,round_code,group_name,match_no,
          player_a_id,player_b_id,winner_id,loser_id,score,best_of,
          player_a_win_probability,court_speed,model_version,matchup_components,simulated_on
        ) values(
          t.id,1,'RR',rr.group_name,rr.match_no,v_a,v_b,v_w,v_l,v_score,3,round(v_prob,4),
          coalesce(t.court_speed,1.0),'CB-JUNIOR-v4-ROUNDROBIN',
          coalesce(v_match->'components','{}'::jsonb),t.start_date
        );
        v_matches:=v_matches+1;

        update cb_j_entries
        set wins=wins+1,last_opponent_id=v_l,last_opponent_name=v_l_name,
            last_score=case when v_w=v_a then v_score else public.world_invert_tennis_score(v_score) end
        where player_id=v_w;
        update cb_j_entries
        set losses=losses+1,last_opponent_id=v_w,last_opponent_name=v_w_name,
            last_score=case when v_l=v_a then v_score else public.world_invert_tennis_score(v_score) end
        where player_id=v_l;
      end loop;

      drop table if exists pg_temp.cb_j_rr_rank;
      create temporary table cb_j_rr_rank on commit drop as
      select player_id,group_name,wins,
             row_number() over(partition by group_name order by wins desc,seed asc)::int group_pos
      from cb_j_entries;

      update cb_j_entries e
      set result_code='RR'||r.group_pos::text,
          result_label='Groupe · position '||r.group_pos::text,
          points_awarded=case
            when r.group_pos=2 then case when t.category='J60' then 5 else 2 end
            when r.group_pos in (3,4) and e.wins>0 then case when t.category='J60' then 2 else 1 end
            else 0 end
      from cb_j_rr_rank r
      where e.player_id=r.player_id and r.group_pos>1;

      drop table if exists pg_temp.cb_j_current;
      drop table if exists pg_temp.cb_j_next;
      create temporary table cb_j_current(pos int primary key,player_id bigint) on commit drop;
      create temporary table cb_j_next(pos int primary key,player_id bigint) on commit drop;

      insert into cb_j_current(pos,player_id)
      select row_number() over(order by group_name)::int,player_id
      from cb_j_rr_rank where group_pos=1 order by group_name;

      v_size:=8;
      v_round:=2;
      while v_size>1 loop
        truncate cb_j_next;
        v_next:=0;
        v_code:=case when v_size=8 then 'QF' when v_size=4 then 'SF' else 'F' end;

        for v_pos in 1..v_size by 2 loop
          v_next:=v_next+1;
          select player_id into v_a from cb_j_current where pos=v_pos;
          select player_id into v_b from cb_j_current where pos=v_pos+1;
          select name into v_a_name from cb_j_entries where player_id=v_a;
          select name into v_b_name from cb_j_entries where player_id=v_b;

          v_match:=public.player_matchup_probability_v4(v_a,v_b,t.surface,t.end_date,coalesce(t.court_speed,1.0),3);
          v_prob:=greatest(.02,least(.98,coalesce((v_match->>'player_a_probability')::numeric,.5)));
          v_awon:=random()<v_prob;
          v_w:=case when v_awon then v_a else v_b end;
          v_l:=case when v_awon then v_b else v_a end;
          v_w_name:=case when v_awon then v_a_name else v_b_name end;
          v_l_name:=case when v_awon then v_b_name else v_a_name end;
          v_score:=public.world_tournament_score(v_prob,v_awon,3);

          insert into public.world_tournament_matches(
            tournament_id,round_no,round_code,match_no,player_a_id,player_b_id,winner_id,loser_id,
            score,best_of,player_a_win_probability,court_speed,model_version,matchup_components,simulated_on
          ) values(
            t.id,v_round,v_code,v_next,v_a,v_b,v_w,v_l,v_score,3,round(v_prob,4),
            coalesce(t.court_speed,1.0),'CB-JUNIOR-v4-ROUNDROBIN',
            coalesce(v_match->'components','{}'::jsonb),t.end_date
          );
          v_matches:=v_matches+1;

          update cb_j_entries
          set result_code=v_code,
              result_label=case v_code when 'QF' then 'Quart de finale' when 'SF' then 'Demi-finale' else 'Finaliste' end,
              points_awarded=public.junior_points_for('singles',t.category,v_code),
              last_opponent_id=v_w,last_opponent_name=v_w_name,
              last_score=case when v_l=v_a then v_score else public.world_invert_tennis_score(v_score) end
          where player_id=v_l;
          update cb_j_entries set wins=wins+1 where player_id=v_w;
          insert into cb_j_next values(v_next,v_w);
        end loop;

        truncate cb_j_current;
        insert into cb_j_current select * from cb_j_next;
        v_size:=v_size/2;
        v_round:=v_round+1;
      end loop;

      select player_id into v_winner from cb_j_current limit 1;
      update cb_j_entries
      set result_code='W',result_label='Vainqueur',
          points_awarded=public.junior_points_for('singles',t.category,'W')
      where player_id=v_winner;

    else
      v_bracket:=case when v_draw<=16 then 16 when v_draw<=32 then 32 else 64 end;
      v_rounds:=ceil(ln(v_bracket::numeric)/ln(2::numeric))::int;

      update cb_j_entries
      set draw_slot=public.world_tournament_seed_slot(v_bracket,seed)
      where seed<=least(case when v_bracket>=64 then 16 else 8 end,v_draw);

      with bye_slots as (
        select case when draw_slot%2=1 then draw_slot+1 else draw_slot-1 end slot
        from cb_j_entries
        where v_bracket>v_draw and seed<=least(v_bracket-v_draw,v_draw) and draw_slot is not null
      ),
      used as (
        select draw_slot slot from cb_j_entries where draw_slot is not null
        union all select slot from bye_slots
      ),
      avail as (
        select g slot,row_number() over(order by md5('jslot|'||t.id::text||'|'||g::text)) rn
        from generate_series(1,v_bracket) g
        where not exists(select 1 from used u where u.slot=g)
      ),
      unplaced as (
        select player_id,row_number() over(order by md5('jplayer|'||t.id::text||'|'||player_id::text)) rn
        from cb_j_entries where draw_slot is null
      )
      update cb_j_entries e
      set draw_slot=a.slot
      from unplaced u join avail a using(rn)
      where e.player_id=u.player_id;

      drop table if exists pg_temp.cb_j_current;
      drop table if exists pg_temp.cb_j_next;
      create temporary table cb_j_current(pos int primary key,player_id bigint) on commit drop;
      create temporary table cb_j_next(pos int primary key,player_id bigint) on commit drop;

      insert into cb_j_current(pos,player_id)
      select g,e.player_id
      from generate_series(1,v_bracket) g
      left join cb_j_entries e on e.draw_slot=g;

      v_size:=v_bracket;
      for v_round in 1..v_rounds loop
        truncate cb_j_next;
        v_next:=0;
        v_code:=case when v_size>=64 then 'R64' when v_size>=32 then 'R32' when v_size>=16 then 'R16'
                     when v_size>=8 then 'QF' when v_size>=4 then 'SF' else 'F' end;

        for v_pos in 1..v_size by 2 loop
          v_next:=v_next+1;
          select player_id into v_a from cb_j_current where pos=v_pos;
          select player_id into v_b from cb_j_current where pos=v_pos+1;

          if v_a is null and v_b is null then
            insert into cb_j_next(pos,player_id) values(v_next,null);
            continue;
          elsif v_a is null or v_b is null then
            insert into cb_j_next(pos,player_id) values(v_next,coalesce(v_a,v_b));
            continue;
          end if;

          select name into v_a_name from cb_j_entries where player_id=v_a;
          select name into v_b_name from cb_j_entries where player_id=v_b;
          v_match:=public.player_matchup_probability_v4(v_a,v_b,t.surface,t.end_date,coalesce(t.court_speed,1.0),3);
          v_prob:=greatest(.02,least(.98,coalesce((v_match->>'player_a_probability')::numeric,.5)));
          v_awon:=random()<v_prob;
          v_w:=case when v_awon then v_a else v_b end;
          v_l:=case when v_awon then v_b else v_a end;
          v_w_name:=case when v_awon then v_a_name else v_b_name end;
          v_l_name:=case when v_awon then v_b_name else v_a_name end;
          v_score:=public.world_tournament_score(v_prob,v_awon,3);

          insert into public.world_tournament_matches(
            tournament_id,round_no,round_code,match_no,player_a_id,player_b_id,winner_id,loser_id,
            score,best_of,player_a_win_probability,court_speed,model_version,matchup_components,simulated_on
          ) values(
            t.id,v_round,v_code,v_next,v_a,v_b,v_w,v_l,v_score,3,round(v_prob,4),
            coalesce(t.court_speed,1.0),'CB-JUNIOR-v4-FULLDRAW',
            coalesce(v_match->'components','{}'::jsonb),t.end_date
          );
          v_matches:=v_matches+1;

          update cb_j_entries
          set result_code=v_code,
              result_label=public.world_tournament_result_label(v_code),
              points_awarded=public.junior_points_for('singles',t.category,v_code),
              last_opponent_id=v_w,last_opponent_name=v_w_name,
              last_score=case when v_l=v_a then v_score else public.world_invert_tennis_score(v_score) end
          where player_id=v_l;
          update cb_j_entries set wins=wins+1 where player_id=v_w;
          insert into cb_j_next values(v_next,v_w);
        end loop;

        truncate cb_j_current;
        insert into cb_j_current select * from cb_j_next;
        v_size:=greatest(1,v_size/2);
      end loop;

      select player_id into v_winner from cb_j_current order by pos limit 1;
      update cb_j_entries
      set result_code='W',result_label='Vainqueur',
          points_awarded=public.junior_points_for('singles',t.category,'W')
      where player_id=v_winner;
    end if;

    select loser_id into v_finalist
    from public.world_tournament_matches
    where tournament_id=t.id and round_code='F'
    order by id desc limit 1;

    insert into public.world_tournament_entries(
      tournament_id,player_id,seed,draw_slot,entry_method,ranking_at_entry,had_bye,matches_won,
      result_code,result_label,points_awarded,qualifying_points,last_opponent_id,last_opponent_name,
      last_score,simulated_on,source_label
    )
    select t.id,player_id,seed,coalesce(draw_slot,seed),entry_method,rank_at_entry,false,wins,
           result_code,result_label,points_awarded,qualifying_points,last_opponent_id,last_opponent_name,last_score,
           t.end_date,'Court Boss junior full draw + 2026 entry composition · '||t.junior_draw_format
    from cb_j_entries;

    update public.players p
    set junior_game_points=coalesce(p.junior_game_points,0)+e.points_awarded,
        form=greatest(35,least(100,p.form+case e.result_code when 'W' then 4 when 'F' then 3 when 'SF' then 2 else 0 end)),
        morale=greatest(30,least(100,p.morale+case e.result_code when 'W' then 4 when 'F' then 2 else 0 end))
    from cb_j_entries e
    where p.id=e.player_id;

    insert into public.player_tournament_history(
      player_id,season,tournament_id,tournament_name,tournament_date,level,category,surface,
      result_code,result_label,last_opponent,last_score,is_grand_slam,source,event_type
    )
    select player_id,extract(year from t.end_date)::int,t.id::text,t.name,t.end_date,t.category,t.category,t.surface,
           result_code,result_label,last_opponent_name,last_score,t.category='Junior Grand Slam',
           'Court Boss junior full draw','junior_singles'
    from cb_j_entries
    on conflict(player_id,event_type,tournament_id) do update set
      result_code=excluded.result_code,result_label=excluded.result_label,last_opponent=excluded.last_opponent,
      last_score=excluded.last_score,source=excluded.source;

    select name into v_w_name from public.players where id=v_winner;
    select name into v_l_name from public.players where id=v_finalist;

    insert into public.player_titles(
      player_id,tournament_name,title_date,level,surface,event_type,verified,source_label,origin
    )
    values(v_winner,t.name,t.end_date,t.category,t.surface,'junior_singles',false,'Court Boss junior full draw','game')
    on conflict(player_id,tournament_name,title_date,event_type) do nothing;

    insert into public.player_final_results(
      player_id,tournament_name,final_date,level,surface,result,opponent_name,source,event_type
    )
    values
      (v_winner,t.name,t.end_date,t.category,t.surface,'Champion',v_l_name,'Court Boss junior full draw','junior_singles'),
      (v_finalist,t.name,t.end_date,t.category,t.surface,'Finaliste',v_w_name,'Court Boss junior full draw','junior_singles')
    on conflict(player_id,tournament_name,final_date,result) do nothing;

    insert into public.world_tournament_simulations(
      tournament_id,winner_id,finalist_id,winner_points,finalist_points,simulated_on,
      model_version,rule_key,draw_size,bracket_size,rounds_count,matches_simulated,participants_simulated,format_type
    ) values(
      t.id,v_winner,v_finalist,
      public.junior_points_for('singles',t.category,'W'),
      public.junior_points_for('singles',t.category,'F'),t.end_date,
      case when t.junior_draw_format='round_robin_to_elimination' then 'CB-JUNIOR-v4-RR' else 'CB-JUNIOR-v4-FULLDRAW' end,
      'JUNIOR_'||replace(t.category,' ','_')||'_'||v_draw,
      v_draw,
      case when v_draw<=16 then 16 when v_draw<=32 then 32 else 64 end,
      case when t.junior_draw_format='round_robin_to_elimination' then 4
           else ceil(ln((case when v_draw<=16 then 16 when v_draw<=32 then 32 else 64 end)::numeric)/ln(2::numeric))::int end,
      (select count(*) from public.world_tournament_matches where tournament_id=t.id and is_qualifying=false),
      v_draw,t.junior_draw_format
    );

    v_singles:=v_singles+1;
  end loop;

  return jsonb_build_object(
    'singles_simulated',v_singles,'matches_simulated',v_matches,
    'from',p_from_date,'to',p_to_date,'model','CB-JUNIOR-v4 full draw / RR hybrid'
  );
end
$function$;

CREATE OR REPLACE FUNCTION public.simulate_ncaa_dual_v2(p_dual_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  d public.college_duals%rowtype;
  hline bigint[];
  aline bigint[];
  hdline bigint[];
  adline bigint[];
  r jsonb;
  hs int:=0;
  ascore int:=0;
  hdwins int:=0;
  adwins int:=0;
  c int;
  rubber_no int:=0;
  hp bigint;
  ap bigint;
  winner_id bigint;
  loser_id bigint;
  homewin boolean;
  v_winner bigint;
  v_runner bigint;
  v_year int;
  v_advance jsonb;
begin
  select * into d
  from public.college_duals
  where id=p_dual_id
  for update;

  if d.id is null then
    return jsonb_build_object('ok',false,'reason','dual_not_found');
  end if;
  if d.status='completed' then
    return jsonb_build_object(
      'ok',true,'already',true,'dual_id',d.id,
      'home_score',d.home_score,'away_score',d.away_score,
      'winner_team_id',d.winner_team_id
    );
  end if;
  if d.status<>'scheduled' then
    return jsonb_build_object('ok',false,'reason','dual_not_scheduled','status',d.status);
  end if;

  hline:=public.ncaa_team_lineup(d.home_team_id,d.match_date);
  aline:=public.ncaa_team_lineup(d.away_team_id,d.match_date);
  hdline:=public.ncaa_team_doubles_lineup(d.home_team_id,d.match_date);
  adline:=public.ncaa_team_doubles_lineup(d.away_team_id,d.match_date);

  if coalesce(array_length(hline,1),0)<6 or coalesce(array_length(aline,1),0)<6 then
    update public.college_duals
    set status='postponed',model_version='CB-NCAA-DUAL-v3 · insufficient singles roster'
    where id=d.id;
    return jsonb_build_object('ok',false,'reason','insufficient_roster','dual_id',d.id);
  end if;

  if coalesce(array_length(hdline,1),0)<6 then hdline:=hline; end if;
  if coalesce(array_length(adline,1),0)<6 then adline:=aline; end if;

  delete from public.college_dual_rubbers where dual_id=d.id;

  -- NCAA doubles point: best of three doubles courts, one team point.
  for c in 1..3 loop
    if hdwins>=2 or adwins>=2 then
      rubber_no:=rubber_no+1;
      insert into public.college_dual_rubbers(
        dual_id,rubber_no,rubber_type,court_no,home_player_ids,away_player_ids,status,model_version
      ) values(
        d.id,rubber_no,'Doubles',c,
        array[hdline[(c-1)*2+1],hdline[(c-1)*2+2]],
        array[adline[(c-1)*2+1],adline[(c-1)*2+2]],
        'unfinished','CB-NCAA-DUAL-v3'
      );
      continue;
    end if;

    r:=public.ncaa_doubles_rubber(
      hdline[(c-1)*2+1],hdline[(c-1)*2+2],
      adline[(c-1)*2+1],adline[(c-1)*2+2],
      d.surface,d.match_date,d.id||'|D'||c
    );
    homewin:=coalesce((r->>'home_win')::boolean,false);
    if homewin then hdwins:=hdwins+1; else adwins:=adwins+1; end if;
    rubber_no:=rubber_no+1;

    insert into public.college_dual_rubbers(
      dual_id,rubber_no,rubber_type,court_no,home_player_ids,away_player_ids,
      winner_team_id,score,status,home_win_probability,model_version
    ) values(
      d.id,rubber_no,'Doubles',c,
      array[hdline[(c-1)*2+1],hdline[(c-1)*2+2]],
      array[adline[(c-1)*2+1],adline[(c-1)*2+2]],
      case when homewin then d.home_team_id else d.away_team_id end,
      r->>'score','completed',(r->>'home_probability')::numeric,'CB-NCAA-DUAL-v3'
    );

    update public.players
    set fatigue=least(100,coalesce(fatigue,20)+2)
    where id in (
      hdline[(c-1)*2+1],hdline[(c-1)*2+2],
      adline[(c-1)*2+1],adline[(c-1)*2+2]
    );
  end loop;

  if hdwins>adwins then hs:=1; else ascore:=1; end if;

  -- Six singles courts, stop when a team clinches four points.
  for c in 1..6 loop
    hp:=hline[c];
    ap:=aline[c];

    if hs>=4 or ascore>=4 then
      rubber_no:=rubber_no+1;
      insert into public.college_dual_rubbers(
        dual_id,rubber_no,rubber_type,court_no,home_player_ids,away_player_ids,status,model_version
      ) values(
        d.id,rubber_no,'Singles',c,array[hp],array[ap],'unfinished','CB-NCAA-DUAL-v3'
      );
      continue;
    end if;

    r:=public.ncaa_singles_rubber(hp,ap,d.surface,d.match_date,d.id||'|S'||c);
    homewin:=coalesce((r->>'home_win')::boolean,false);
    winner_id:=(r->>'winner_id')::bigint;
    loser_id:=(r->>'loser_id')::bigint;
    if homewin then hs:=hs+1; else ascore:=ascore+1; end if;
    rubber_no:=rubber_no+1;

    insert into public.college_dual_rubbers(
      dual_id,rubber_no,rubber_type,court_no,home_player_ids,away_player_ids,
      winner_team_id,score,status,home_win_probability,model_version
    ) values(
      d.id,rubber_no,'Singles',c,array[hp],array[ap],
      case when homewin then d.home_team_id else d.away_team_id end,
      r->>'score','completed',(r->>'home_probability')::numeric,'CB-NCAA-DUAL-v3'
    );

    perform public.ncaa_apply_utr_result(
      winner_id,loser_id,d.match_date,null,d.id,1.0
    );

    update public.players
    set fatigue=least(100,coalesce(fatigue,20)+3),
        fitness=greatest(35,coalesce(fitness,90)-1),
        form=greatest(1,least(100,coalesce(form,70)+
          case when id=winner_id then 1 else -1 end))
    where id in (winner_id,loser_id);
  end loop;

  v_winner:=case when hs>ascore then d.home_team_id else d.away_team_id end;
  v_runner:=case when hs>ascore then d.away_team_id else d.home_team_id end;

  update public.college_duals
  set home_score=hs,
      away_score=ascore,
      status='completed',
      winner_team_id=v_winner,
      home_win_probability=null,
      home_player_ids=hline,
      away_player_ids=aline,
      model_version=case
        when d.competition='NCAA Division I Championship' then 'CB-NCAA-CHAMP-v3'
        else 'CB-NCAA-DUAL-v3' end
  where id=d.id;

  v_year:=extract(year from d.match_date)::int;
  if d.competition='NCAA Division I Championship' then
    v_advance:=public.advance_ncaa_championship(v_year);
    if d.stage='F' then
      insert into public.college_championship_history(
        season,champion_team_id,runner_up_team_id,final_score,source_label
      ) values(
        v_year,v_winner,v_runner,hs||'-'||ascore,
        'Court Boss simulated NCAA championship v3 · full dual rubbers'
      )
      on conflict(season) do update set
        champion_team_id=excluded.champion_team_id,
        runner_up_team_id=excluded.runner_up_team_id,
        final_score=excluded.final_score,
        source_label=excluded.source_label;
    end if;
  end if;

  return jsonb_build_object(
    'ok',true,'dual_id',d.id,
    'home_score',hs,'away_score',ascore,
    'winner_team_id',v_winner,
    'doubles_point_winner',case when hdwins>adwins then d.home_team_id else d.away_team_id end,
    'rubbers_played',(select count(*) from public.college_dual_rubbers where dual_id=d.id and status='completed'),
    'stage',d.stage,'competition',d.competition,
    'model','CB-NCAA-DUAL-v3'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.simulate_ncaa_duals(p_from_date date, p_to_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  v_year int:=extract(year from p_to_date)::int;
  v_schedule jsonb;
  v_field jsonb;
  v_result jsonb;
  v_id bigint;
  simulated int:=0;
  postponed int:=0;
  superseded int:=0;
begin
  v_schedule:=public.ensure_ncaa_regular_schedule(v_year);
  v_field:=public.ensure_ncaa_championship_field(v_year,p_to_date);

  -- A generated weekly dual is replaced if either school is committed to an
  -- official ITA team event on that date. The ITA event counts as that week's team tennis.
  with conflicted as (
    select d.id
    from public.college_duals d
    where d.match_date>p_from_date
      and d.match_date<=p_to_date
      and d.status='scheduled'
      and d.source_label='Court Boss NCAA generated regular season v1'
      and exists(
        select 1
        from public.ncaa_team_event_entries e
        join public.tournaments t on t.id=e.tournament_id
        where e.team_id in (d.home_team_id,d.away_team_id)
          and d.match_date between t.start_date and coalesce(t.end_date,t.start_date)
      )
  )
  update public.college_duals d
  set status='superseded',
      model_version='CB-NCAA-v3 · replaced by ITA team event'
  from conflicted c
  where d.id=c.id;

  get diagnostics superseded=row_count;

  loop
    select id into v_id
    from public.college_duals
    where match_date>p_from_date
      and match_date<=p_to_date
      and status='scheduled'
      and coalesce(competition,'NCAA Division I')
          in ('NCAA Division I','NCAA Division I Championship')
    order by match_date,
      case when competition='NCAA Division I Championship' then 0 else 1 end,
      id
    limit 1;

    exit when v_id is null;

    v_result:=public.simulate_ncaa_dual_v2(v_id);
    if coalesce((v_result->>'ok')::boolean,false) then
      simulated:=simulated+1;
    elsif v_result->>'reason'='insufficient_roster' then
      postponed:=postponed+1;
    end if;
  end loop;

  perform public.refresh_ncaa_team_rankings(p_to_date);

  return jsonb_build_object(
    'duals_simulated',simulated,
    'duals_postponed',postponed,
    'duals_superseded_by_team_events',superseded,
    'schedule',v_schedule,
    'championship_field',v_field,
    'from',p_from_date,'to',p_to_date,
    'model','NCAA v3 · full rubbers + ITA team-event conflict resolution + 64-team championship'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.simulate_ncaa_individual_doubles(p_tournament_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  v_pairs bigint[];
  v_next bigint[];
  v_n int;
  v_bracket int:=2;
  v_byes int;
  v_round_index int:=1;
  v_round_code text;
  v_match_no int;
  i int;
  ea bigint;
  eb bigint;
  wa bigint;
  la bigint;
  a1 bigint;a2 bigint;b1 bigint;b2 bigint;
  w1 bigint;w2 bigint;l1 bigint;l2 bigint;
  r jsonb;
  pts int;
  played date;
  v_season int;
  v_title bigint;
  v_matches int:=0;
  a_win boolean;
begin
  select * into t from public.tournaments where id=p_tournament_id;
  if t.id is null then return jsonb_build_object('ok',false,'reason','not_found'); end if;

  select array_agg(id order by coalesce(seed,999),id)
  into v_pairs
  from public.ncaa_individual_doubles_entries
  where tournament_id=t.id;

  v_n:=coalesce(array_length(v_pairs,1),0);
  if v_n<2 then return jsonb_build_object('ok',false,'reason','insufficient_field','entries',v_n); end if;

  delete from public.ncaa_individual_matches
  where tournament_id=t.id and discipline='doubles';

  while v_bracket<v_n loop v_bracket:=v_bracket*2; end loop;
  v_byes:=v_bracket-v_n;
  v_round_code:=public.ncaa_round_code(v_bracket);
  played:=least(coalesce(t.end_date,t.start_date),t.start_date);
  v_next:='{}'::bigint[];

  if v_byes>0 then
    for i in 1..v_byes loop
      v_next:=array_append(v_next,v_pairs[i]);
    end loop;
  end if;

  v_match_no:=0;
  i:=v_byes+1;
  while i<=v_n loop
    ea:=v_pairs[i]; eb:=v_pairs[i+1];
    select player_a_id,player_b_id into a1,a2 from public.ncaa_individual_doubles_entries where id=ea;
    select player_a_id,player_b_id into b1,b2 from public.ncaa_individual_doubles_entries where id=eb;

    v_match_no:=v_match_no+1;
    r:=public.ncaa_individual_doubles_match_result(a1,a2,b1,b2,t.surface,played,t.id||'|'||v_round_code||'|'||v_match_no);
    a_win:=coalesce((r->>'a_win')::boolean,false);
    wa:=case when a_win then ea else eb end;
    la:=case when a_win then eb else ea end;
    w1:=case when a_win then a1 else b1 end;
    w2:=case when a_win then a2 else b2 end;
    l1:=case when a_win then b1 else a1 end;
    l2:=case when a_win then b2 else a2 end;
    pts:=round(public.ncaa_round_win_points(t.category,v_round_code)*.80)::int;

    insert into public.ncaa_individual_matches(
      tournament_id,discipline,phase,round_index,round_code,match_no,
      side_a_player_ids,side_b_player_ids,winner_player_ids,loser_player_ids,
      score,home_win_probability,played_on
    ) values(
      t.id,'doubles','main',v_round_index,v_round_code,v_match_no,
      array[a1,a2],array[b1,b2],array[w1,w2],array[l1,l2],
      r->>'score',(r->>'a_probability')::numeric,played
    );

    update public.ncaa_individual_doubles_entries
    set wins=wins+1,points_earned=points_earned+pts
    where id=wa;
    update public.ncaa_individual_doubles_entries
    set losses=losses+1,result_code=v_round_code
    where id=la;

    v_season:=extract(year from t.start_date)::int;
    insert into public.ncaa_doubles_pair_points(player_a_id,player_b_id,season,points,wins,losses,titles)
    values(least(w1,w2),greatest(w1,w2),v_season,pts,1,0,0)
    on conflict(player_a_id,player_b_id,season) do update
      set points=public.ncaa_doubles_pair_points.points+excluded.points,
          wins=public.ncaa_doubles_pair_points.wins+1,
          updated_at=now();

    insert into public.ncaa_doubles_pair_points(player_a_id,player_b_id,season,points,wins,losses,titles)
    values(least(l1,l2),greatest(l1,l2),v_season,0,0,1,0)
    on conflict(player_a_id,player_b_id,season) do update
      set losses=public.ncaa_doubles_pair_points.losses+1,
          updated_at=now();

    update public.players
    set fatigue=least(100,coalesce(fatigue,20)+2),
        form=greatest(1,least(100,coalesce(form,70)+case when id in (w1,w2) then 1 else -1 end))
    where id in (w1,w2,l1,l2);

    v_next:=array_append(v_next,wa);
    v_matches:=v_matches+1;
    i:=i+2;
  end loop;

  v_pairs:=v_next;

  while coalesce(array_length(v_pairs,1),0)>1 loop
    v_n:=array_length(v_pairs,1);
    v_round_index:=v_round_index+1;
    v_round_code:=public.ncaa_round_code(v_n);
    played:=least(coalesce(t.end_date,t.start_date),t.start_date+(v_round_index-1));
    v_next:='{}'::bigint[];
    v_match_no:=0;

    i:=1;
    while i<=v_n loop
      ea:=v_pairs[i]; eb:=v_pairs[i+1];
      select player_a_id,player_b_id into a1,a2 from public.ncaa_individual_doubles_entries where id=ea;
      select player_a_id,player_b_id into b1,b2 from public.ncaa_individual_doubles_entries where id=eb;

      v_match_no:=v_match_no+1;
      r:=public.ncaa_individual_doubles_match_result(a1,a2,b1,b2,t.surface,played,t.id||'|'||v_round_code||'|'||v_match_no);
      a_win:=coalesce((r->>'a_win')::boolean,false);
      wa:=case when a_win then ea else eb end;
      la:=case when a_win then eb else ea end;
      w1:=case when a_win then a1 else b1 end;
      w2:=case when a_win then a2 else b2 end;
      l1:=case when a_win then b1 else a1 end;
      l2:=case when a_win then b2 else a2 end;
      pts:=round(public.ncaa_round_win_points(t.category,v_round_code)*.80)::int;

      insert into public.ncaa_individual_matches(
        tournament_id,discipline,phase,round_index,round_code,match_no,
        side_a_player_ids,side_b_player_ids,winner_player_ids,loser_player_ids,
        score,home_win_probability,played_on
      ) values(
        t.id,'doubles','main',v_round_index,v_round_code,v_match_no,
        array[a1,a2],array[b1,b2],array[w1,w2],array[l1,l2],
        r->>'score',(r->>'a_probability')::numeric,played
      );

      update public.ncaa_individual_doubles_entries
      set wins=wins+1,points_earned=points_earned+pts
      where id=wa;
      update public.ncaa_individual_doubles_entries
      set losses=losses+1,result_code=v_round_code
      where id=la;

      insert into public.ncaa_doubles_pair_points(player_a_id,player_b_id,season,points,wins,losses,titles)
      values(least(w1,w2),greatest(w1,w2),v_season,pts,1,0,0)
      on conflict(player_a_id,player_b_id,season) do update
        set points=public.ncaa_doubles_pair_points.points+excluded.points,
            wins=public.ncaa_doubles_pair_points.wins+1,
            updated_at=now();

      insert into public.ncaa_doubles_pair_points(player_a_id,player_b_id,season,points,wins,losses,titles)
      values(least(l1,l2),greatest(l1,l2),v_season,0,0,1,0)
      on conflict(player_a_id,player_b_id,season) do update
        set losses=public.ncaa_doubles_pair_points.losses+1,
            updated_at=now();

      update public.players
      set fatigue=least(100,coalesce(fatigue,20)+2),
          form=greatest(1,least(100,coalesce(form,70)+case when id in (w1,w2) then 1 else -1 end))
      where id in (w1,w2,l1,l2);

      v_next:=array_append(v_next,wa);
      v_matches:=v_matches+1;
      i:=i+2;
    end loop;

    v_pairs:=v_next;
  end loop;

  v_title:=v_pairs[1];
  update public.ncaa_individual_doubles_entries
  set result_code='W'
  where id=v_title;

  select player_a_id,player_b_id into a1,a2
  from public.ncaa_individual_doubles_entries where id=v_title;

  update public.ncaa_doubles_pair_points
  set titles=titles+1,updated_at=now()
  where player_a_id=least(a1,a2) and player_b_id=greatest(a1,a2) and season=v_season;

  return jsonb_build_object(
    'ok',true,'tournament_id',t.id,
    'entries',(select count(*) from public.ncaa_individual_doubles_entries where tournament_id=t.id),
    'matches',v_matches,'winner_entry_id',v_title,
    'winner_player_ids',array[a1,a2]
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.simulate_ncaa_individual_events(p_from_date date, p_to_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  rec record;
  prep jsonb;
  singles_result jsonb;
  doubles_result jsonb;
  q int;
  prepared int:=0;
  simulated int:=0;
  skipped int:=0;
  v_singles_entries int;
  v_doubles_entries int;
  rankings jsonb;
  doubles_rankings jsonb;
begin
  -- Reserve players as soon as an individual event enters the current window.
  for rec in
    select t.id
    from public.tournaments t
    where t.circuit='NCAA'
      and coalesce(t.is_active,true)=true
      and t.category not in (
        'ITA Kickoff Weekend',
        'ITA National Team Indoor Championship',
        'NCAA DI Team Championship'
      )
      and t.start_date<=p_to_date
      and coalesce(t.end_date,t.start_date)>=p_from_date
      and not exists(
        select 1 from public.ncaa_individual_entries e where e.tournament_id=t.id
      )
      and not exists(
        select 1 from public.ncaa_individual_doubles_entries e where e.tournament_id=t.id
      )
    order by t.start_date,t.id
  loop
    prep:=public.ncaa_prepare_individual_event(rec.id);
    if coalesce((prep->>'ok')::boolean,false) then
      prepared:=prepared+1;
    else
      skipped:=skipped+1;
    end if;
  end loop;

  -- Results become known only when the event has actually ended.
  for rec in
    select t.*
    from public.tournaments t
    where t.circuit='NCAA'
      and coalesce(t.is_active,true)=true
      and t.category not in (
        'ITA Kickoff Weekend',
        'ITA National Team Indoor Championship',
        'NCAA DI Team Championship'
      )
      and coalesce(t.end_date,t.start_date)>p_from_date
      and coalesce(t.end_date,t.start_date)<=p_to_date
      and not exists(
        select 1 from public.ncaa_individual_simulations s where s.tournament_id=t.id
      )
    order by coalesce(t.end_date,t.start_date),t.id
  loop
    prep:=public.ncaa_prepare_individual_event(rec.id);
    select count(*) into v_singles_entries
    from public.ncaa_individual_entries
    where tournament_id=rec.id and discipline='singles';

    select count(*) into v_doubles_entries
    from public.ncaa_individual_doubles_entries
    where tournament_id=rec.id;

    singles_result:=null;
    doubles_result:=null;

    if coalesce(rec.singles,false) and v_singles_entries>=2 then
      singles_result:=public.simulate_ncaa_individual_singles(rec.id);
    end if;

    if coalesce(rec.doubles,false) and v_doubles_entries>=2 then
      doubles_result:=public.simulate_ncaa_individual_doubles(rec.id);
    end if;

    q:=public.ncaa_register_individual_qualifiers(rec.id);

    insert into public.ncaa_individual_simulations(
      tournament_id,status,simulated_on,singles_entries,doubles_entries,model_version
    ) values(
      rec.id,'completed',p_to_date,v_singles_entries,v_doubles_entries,'CB-NCAA-IND-v1'
    )
    on conflict(tournament_id) do update set
      status='completed',
      simulated_on=excluded.simulated_on,
      singles_entries=excluded.singles_entries,
      doubles_entries=excluded.doubles_entries,
      model_version=excluded.model_version;

    simulated:=simulated+1;
  end loop;

  rankings:=public.refresh_ncaa_team_rankings(p_to_date);
  doubles_rankings:=public.refresh_ncaa_doubles_rankings(p_to_date);

  return jsonb_build_object(
    'events_prepared',prepared,
    'events_simulated',simulated,
    'events_skipped',skipped,
    'rankings',rankings,
    'doubles_rankings',doubles_rankings,
    'from',p_from_date,
    'to',p_to_date,
    'model','NCAA individual v1 · entries at start, results at end, dynamic UTR/ITA'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.simulate_ncaa_individual_singles(p_tournament_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  v_players bigint[];
  v_next bigint[];
  v_n int;
  v_bracket int:=2;
  v_byes int;
  v_round_index int:=1;
  v_round_code text;
  v_match_no int;
  i int;
  a bigint;
  b bigint;
  w bigint;
  l bigint;
  r jsonb;
  pts int;
  played date;
  v_season int;
  v_title bigint;
  v_matches int:=0;
begin
  select * into t from public.tournaments where id=p_tournament_id;
  if t.id is null then return jsonb_build_object('ok',false,'reason','not_found'); end if;

  select array_agg(player_id order by coalesce(seed,999),draw_position,player_id)
  into v_players
  from public.ncaa_individual_entries
  where tournament_id=t.id and discipline='singles';

  v_n:=coalesce(array_length(v_players,1),0);
  if v_n<2 then return jsonb_build_object('ok',false,'reason','insufficient_field','entries',v_n); end if;

  delete from public.ncaa_individual_matches
  where tournament_id=t.id and discipline='singles';

  while v_bracket<v_n loop v_bracket:=v_bracket*2; end loop;
  v_byes:=v_bracket-v_n;
  v_round_code:=public.ncaa_round_code(v_bracket);
  played:=least(coalesce(t.end_date,t.start_date),t.start_date);
  v_next:='{}'::bigint[];

  if v_byes>0 then
    for i in 1..v_byes loop
      v_next:=array_append(v_next,v_players[i]);
    end loop;
  end if;

  v_match_no:=0;
  i:=v_byes+1;
  while i<=v_n loop
    a:=v_players[i];
    b:=v_players[i+1];
    v_match_no:=v_match_no+1;
    r:=public.ncaa_individual_match_result(a,b,t.surface,played,t.id||'|'||v_round_code||'|'||v_match_no);
    w:=(r->>'winner_id')::bigint;
    l:=(r->>'loser_id')::bigint;
    pts:=public.ncaa_round_win_points(t.category,v_round_code);

    insert into public.ncaa_individual_matches(
      tournament_id,discipline,phase,round_index,round_code,match_no,
      side_a_player_ids,side_b_player_ids,winner_player_ids,loser_player_ids,
      score,home_win_probability,played_on
    ) values(
      t.id,'singles','main',v_round_index,v_round_code,v_match_no,
      array[a],array[b],array[w],array[l],r->>'score',(r->>'a_probability')::numeric,played
    );

    update public.ncaa_individual_entries
    set wins=wins+1,points_earned=points_earned+pts
    where tournament_id=t.id and discipline='singles' and player_id=w;
    update public.ncaa_individual_entries
    set losses=losses+1,result_code=v_round_code
    where tournament_id=t.id and discipline='singles' and player_id=l;

    v_season:=extract(year from t.start_date)::int;
    insert into public.ncaa_individual_points(player_id,season,points,wins,losses,titles)
    values(w,v_season,pts,1,0,0)
    on conflict(player_id,season) do update
      set points=public.ncaa_individual_points.points+excluded.points,
          wins=public.ncaa_individual_points.wins+1,
          updated_at=now();

    insert into public.ncaa_individual_points(player_id,season,points,wins,losses,titles)
    values(l,v_season,0,0,1,0)
    on conflict(player_id,season) do update
      set losses=public.ncaa_individual_points.losses+1,
          updated_at=now();

    perform public.ncaa_apply_utr_result(
      w,l,played,t.id,null,public.ncaa_individual_event_weight(t.category)
    );

    update public.players
    set fatigue=least(100,coalesce(fatigue,20)+3),
        fitness=greatest(35,coalesce(fitness,90)-1),
        form=greatest(1,least(100,coalesce(form,70)+case when id=w then 1 else -1 end))
    where id in (w,l);

    v_next:=array_append(v_next,w);
    v_matches:=v_matches+1;
    i:=i+2;
  end loop;

  v_players:=v_next;

  while coalesce(array_length(v_players,1),0)>1 loop
    v_n:=array_length(v_players,1);
    v_round_index:=v_round_index+1;
    v_round_code:=public.ncaa_round_code(v_n);
    played:=least(coalesce(t.end_date,t.start_date),t.start_date+(v_round_index-1));
    v_next:='{}'::bigint[];
    v_match_no:=0;

    i:=1;
    while i<=v_n loop
      a:=v_players[i];
      b:=v_players[i+1];
      v_match_no:=v_match_no+1;
      r:=public.ncaa_individual_match_result(a,b,t.surface,played,t.id||'|'||v_round_code||'|'||v_match_no);
      w:=(r->>'winner_id')::bigint;
      l:=(r->>'loser_id')::bigint;
      pts:=public.ncaa_round_win_points(t.category,v_round_code);

      insert into public.ncaa_individual_matches(
        tournament_id,discipline,phase,round_index,round_code,match_no,
        side_a_player_ids,side_b_player_ids,winner_player_ids,loser_player_ids,
        score,home_win_probability,played_on
      ) values(
        t.id,'singles','main',v_round_index,v_round_code,v_match_no,
        array[a],array[b],array[w],array[l],r->>'score',(r->>'a_probability')::numeric,played
      );

      update public.ncaa_individual_entries
      set wins=wins+1,points_earned=points_earned+pts
      where tournament_id=t.id and discipline='singles' and player_id=w;
      update public.ncaa_individual_entries
      set losses=losses+1,result_code=v_round_code
      where tournament_id=t.id and discipline='singles' and player_id=l;

      insert into public.ncaa_individual_points(player_id,season,points,wins,losses,titles)
      values(w,v_season,pts,1,0,0)
      on conflict(player_id,season) do update
        set points=public.ncaa_individual_points.points+excluded.points,
            wins=public.ncaa_individual_points.wins+1,
            updated_at=now();

      insert into public.ncaa_individual_points(player_id,season,points,wins,losses,titles)
      values(l,v_season,0,0,1,0)
      on conflict(player_id,season) do update
        set losses=public.ncaa_individual_points.losses+1,
            updated_at=now();

      perform public.ncaa_apply_utr_result(
        w,l,played,t.id,null,public.ncaa_individual_event_weight(t.category)
      );

      update public.players
      set fatigue=least(100,coalesce(fatigue,20)+3),
          fitness=greatest(35,coalesce(fitness,90)-1),
          form=greatest(1,least(100,coalesce(form,70)+case when id=w then 1 else -1 end))
      where id in (w,l);

      v_next:=array_append(v_next,w);
      v_matches:=v_matches+1;
      i:=i+2;
    end loop;

    v_players:=v_next;
  end loop;

  v_title:=v_players[1];
  update public.ncaa_individual_entries
  set result_code='W'
  where tournament_id=t.id and discipline='singles' and player_id=v_title;

  update public.ncaa_individual_points
  set titles=titles+1,updated_at=now()
  where player_id=v_title and season=v_season;

  return jsonb_build_object(
    'ok',true,'tournament_id',t.id,'entries',
    (select count(*) from public.ncaa_individual_entries where tournament_id=t.id and discipline='singles'),
    'matches',v_matches,'winner_id',v_title
  );
end;
$function$;
