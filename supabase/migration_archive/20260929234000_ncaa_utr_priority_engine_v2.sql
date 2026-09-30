-- Court Boss NCAA/UTR + priority scheduler v2
-- Live state captured from Supabase on 2026-09-29.
-- Keeps the career baseline at 2025-12-01 while making the NCAA world fully simulated.

alter table public.players
  add column if not exists ncaa_team_id bigint references public.college_teams(id) on delete set null;

create table if not exists public.ncaa_school_team_aliases(
  school_name text primary key,
  team_id bigint not null references public.college_teams(id) on delete cascade,
  source_label text not null default 'Court Boss canonical NCAA school mapping'
);
alter table public.ncaa_school_team_aliases enable row level security;

insert into public.ncaa_school_team_aliases(school_name,team_id,source_label) values
  ('University of Arizona',37,'Canonical school → Arizona Wildcats'),
  ('University of Virginia',2,'Canonical school → Virginia Cavaliers'),
  ('Columbia University',44,'Canonical school → Columbia Lions'),
  ('Florida State University',16,'Canonical school → Florida State Seminoles'),
  ('Michigan State University',57,'Canonical school → Michigan State Spartans'),
  ('Ohio State University',4,'Canonical school → Ohio State Buckeyes'),
  ('Stanford University',5,'Canonical school → Stanford Cardinal'),
  ('TCU',3,'Canonical school → TCU Horned Frogs'),
  ('UCLA',10,'Canonical school → UCLA Bruins'),
  ('University of Illinois at Urbana-Champaign',35,'Canonical school → Illinois Fighting Illini'),
  ('University of Notre Dame',32,'Canonical school → Notre Dame Fighting Irish'),
  ('University of San Diego',21,'Canonical school → San Diego Toreros')
on conflict(school_name) do update
set team_id=excluded.team_id,source_label=excluded.source_label;

update public.players p
set ncaa_team_id=ct.id
from public.college_teams ct
where p.ncaa_current=true
  and p.ncaa_school=ct.name
  and p.ncaa_team_id is distinct from ct.id;

update public.players p
set ncaa_team_id=a.team_id
from public.ncaa_school_team_aliases a
where p.ncaa_current=true
  and p.ncaa_school=a.school_name
  and p.ncaa_team_id is distinct from a.team_id;

create index if not exists players_ncaa_team_current_idx
  on public.players(ncaa_team_id) where ncaa_current=true;

update public.tournaments
set is_active=false
where circuit='NCAA'
  and coalesce(source_note,'') ilike '%legacy simulation hidden%';

alter table public.college_duals
  add column if not exists tournament_id bigint references public.tournaments(id) on delete set null,
  add column if not exists pod_no integer,
  add column if not exists draw_position integer,
  add column if not exists surface text default 'Dur',
  add column if not exists indoor boolean default false;

create index if not exists college_duals_tournament_stage_idx
  on public.college_duals(tournament_id,stage,bracket_slot);

create table if not exists public.player_utr_state(
  player_id bigint primary key references public.players(id) on delete cascade,
  current_rating numeric(5,2) not null,
  match_count integer not null default 0,
  updated_at timestamptz not null default now(),
  source_label text not null default 'Court Boss UTR-like dynamic model'
);
alter table public.player_utr_state enable row level security;

insert into public.player_utr_state(player_id,current_rating,source_label)
select distinct on (r.player_id)
  r.player_id,
  greatest(1.00,least(16.50,coalesce(r.utr_rating,10.00))),
  'Seeded from latest NCAA registry UTR'
from public.ncaa_player_registry r
where r.player_id is not null and r.utr_rating is not null
order by r.player_id,r.season desc,r.snapshot_date desc nulls last,r.id desc
on conflict(player_id) do nothing;

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
alter table public.ncaa_utr_rating_history enable row level security;
create index if not exists ncaa_utr_history_player_date_idx
  on public.ncaa_utr_rating_history(player_id,rating_date desc);

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
alter table public.college_dual_rubbers enable row level security;
create index if not exists college_dual_rubbers_dual_idx
  on public.college_dual_rubbers(dual_id,rubber_no);

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
alter table public.ncaa_individual_entries enable row level security;
create index if not exists ncaa_individual_entries_player_idx
  on public.ncaa_individual_entries(player_id,tournament_id);

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
alter table public.ncaa_individual_doubles_entries enable row level security;

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
alter table public.ncaa_individual_matches enable row level security;

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
alter table public.ncaa_individual_qualifiers enable row level security;

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
alter table public.ncaa_individual_points enable row level security;

create table if not exists public.ncaa_individual_simulations(
  tournament_id bigint primary key references public.tournaments(id) on delete cascade,
  status text not null default 'completed',
  simulated_on date not null,
  singles_entries integer not null default 0,
  doubles_entries integer not null default 0,
  model_version text not null default 'CB-NCAA-IND-v1',
  created_at timestamptz not null default now()
);
alter table public.ncaa_individual_simulations enable row level security;

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
alter table public.ncaa_doubles_pair_points enable row level security;

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
      and daterange(
            coalesce(t.qualifying_start_date,t.main_draw_start_date,t.start_date),
            coalesce(t.end_date,t.start_date),'[]'
          ) && daterange(p_week_start,p_week_start+6,'[]')

    union all
    select 1
    from public.world_tournament_qualifying_entries e
    join public.tournaments t on t.id=e.tournament_id
    where e.player_id=p_player_id
      and t.id is distinct from p_exclude_tournament_id
      and daterange(
            coalesce(t.qualifying_start_date,t.start_date),
            coalesce(t.qualifying_end_date,t.main_draw_start_date,t.end_date,t.start_date),'[]'
          ) && daterange(p_week_start,p_week_start+6,'[]')

    union all
    select 1
    from public.world_doubles_tournament_entries e
    join public.world_doubles_partnerships p on p.id=e.pair_id
    join public.tournaments t on t.id=e.tournament_id
    where p_player_id in (p.player_a_id,p.player_b_id)
      and t.id is distinct from p_exclude_tournament_id
      and daterange(
            coalesce(t.qualifying_start_date,t.main_draw_start_date,t.start_date),
            coalesce(t.end_date,t.start_date),'[]'
          ) && daterange(p_week_start,p_week_start+6,'[]')

    union all
    select 1
    from public.world_junior_doubles_entries e
    join public.tournaments t on t.id=e.tournament_id
    where p_player_id in (e.player_a_id,e.player_b_id)
      and t.id is distinct from p_exclude_tournament_id
      and daterange(coalesce(t.start_date,t.main_draw_start_date),coalesce(t.end_date,t.start_date),'[]')
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
    from public.davis_squad ds
    join public.davis_ties dt on ds.nation in (dt.home_nation,dt.away_nation)
    where ds.player_id=p_player_id
      and dt.status in ('scheduled','completed')
      and dt.tie_date between p_week_start and p_week_start+6

    union all
    select 1
    from public.players pl
    join public.college_duals cd on cd.home_team_id=pl.ncaa_team_id or cd.away_team_id=pl.ncaa_team_id
    where pl.id=p_player_id
      and pl.ncaa_current=true
      and cd.status in ('scheduled','completed')
      and cd.match_date between p_week_start and p_week_start+6
  );
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
      and coalesce(d.competition,'NCAA Division I')='NCAA Division I'
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
    left join public.college_teams ct on ct.id=p.ncaa_team_id
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

CREATE OR REPLACE FUNCTION public.ncaa_doubles_rubber(p_h1 bigint, p_h2 bigint, p_a1 bigint, p_a2 bigint, p_surface text, p_date date, p_key text)
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
  surf text:=lower(coalesce(p_surface,'Dur'));
begin
  if p_h1 is null or p_h2 is null or p_a1 is null or p_a2 is null then
    return jsonb_build_object('ok',false,'reason','missing_player');
  end if;

  select sum(
    coalesce(p.current_ability,50)*.42+
    coalesce(p.form,70)*.09+
    coalesce(p.fitness,85)*.05-
    coalesce(p.fatigue,20)*.07+
    coalesce(pa.doubles,10)*1.45+
    coalesce(us.current_rating,10)*.55+
    case
      when surf like 'terre%' then coalesce(pa.clay_affinity,10)*.25
      when surf like 'gazon%' then coalesce(pa.grass_affinity,10)*.25
      else coalesce(pa.hard_affinity,10)*.25 end
  )
  into hs
  from public.players p
  left join public.player_attributes pa on pa.player_id=p.id
  left join public.player_utr_state us on us.player_id=p.id
  where p.id in (p_h1,p_h2);

  select sum(
    coalesce(p.current_ability,50)*.42+
    coalesce(p.form,70)*.09+
    coalesce(p.fitness,85)*.05-
    coalesce(p.fatigue,20)*.07+
    coalesce(pa.doubles,10)*1.45+
    coalesce(us.current_rating,10)*.55+
    case
      when surf like 'terre%' then coalesce(pa.clay_affinity,10)*.25
      when surf like 'gazon%' then coalesce(pa.grass_affinity,10)*.25
      else coalesce(pa.hard_affinity,10)*.25 end
  )
  into ascore
  from public.players p
  left join public.player_attributes pa on pa.player_id=p.id
  left join public.player_utr_state us on us.player_id=p.id
  where p.id in (p_a1,p_a2);

  prob:=greatest(.05,least(.95,1/(1+exp(-(coalesce(hs,100)-coalesce(ascore,100))/10.5))));
  roll:=mod(abs(hashtext('ncaa-d|'||coalesce(p_key,'')||'|'||p_h1||'|'||p_h2||'|'||p_a1||'|'||p_a2)),10000)/10000.0;
  homewin:=roll<prob;

  return jsonb_build_object(
    'ok',true,'home_win',homewin,
    'home_probability',round(prob,4),
    'score',case
      when abs(prob-.5)<.10 then '7-6'
      when abs(prob-.5)<.22 then '6-4'
      else '6-3' end
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.ncaa_singles_rubber(p_home_player bigint, p_away_player bigint, p_surface text, p_date date, p_key text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  v_match jsonb;
  v_prob numeric;
  v_roll numeric;
  v_home boolean;
  v_score text;
begin
  if p_home_player is null or p_away_player is null then
    return jsonb_build_object('ok',false,'reason','missing_player');
  end if;

  v_match:=public.player_matchup_probability_v4(
    p_home_player,p_away_player,coalesce(p_surface,'Dur'),p_date,
    case
      when coalesce(p_surface,'Dur') ilike 'Terre%' then .70
      when coalesce(p_surface,'Dur') ilike 'Gazon%' then 1.14
      else 1.0 end,
    3
  );
  v_prob:=greatest(.04,least(.96,coalesce((v_match->>'player_a_probability')::numeric,.5)));
  v_roll:=mod(abs(hashtext('ncaa-s|'||coalesce(p_key,'')||'|'||p_home_player||'|'||p_away_player)),10000)/10000.0;
  v_home:=v_roll<v_prob;

  v_score:=case
    when abs(v_prob-.5)<.06 then '7-6 4-6 7-5'
    when abs(v_prob-.5)<.15 then '6-4 3-6 6-3'
    when abs(v_prob-.5)<.28 then '6-4 6-4'
    else '6-2 6-3'
  end;

  return jsonb_build_object(
    'ok',true,'home_win',v_home,
    'winner_id',case when v_home then p_home_player else p_away_player end,
    'loser_id',case when v_home then p_away_player else p_home_player end,
    'home_probability',round(v_prob,4),'score',v_score
  );
end;
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

CREATE OR REPLACE FUNCTION public.ncaa_individual_event_weight(p_category text)
 RETURNS numeric
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  select case
    when p_category='NCAA DI Individual Championship' then 1.35
    when p_category in ('ITA All-American Championships','ITA Sectional Championships','ITA Conference Masters') then 1.20
    when p_category='ITA Division I Regionals' then 1.10
    when p_category='NCAA UTR' then .95
    when p_category='NCAA Finals' then 1.15
    when p_category='NCAA Conference' then 1.05
    else .85
  end;
$function$;

CREATE OR REPLACE FUNCTION public.ncaa_individual_player_available(p_player_id bigint, p_tournament_id bigint)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
begin
  select * into t from public.tournaments where id=p_tournament_id;
  if t.id is null then return false; end if;

  if not exists(
    select 1 from public.players p
    where p.id=p_player_id
      and p.ncaa_current=true
      and p.career_status='active'
      and p.injury_status='Fit'
      and coalesce(p.fitness,90)>=45
  ) then return false; end if;

  if exists(
    select 1
    from public.ncaa_individual_entries e
    join public.tournaments ot on ot.id=e.tournament_id
    where e.player_id=p_player_id
      and ot.id<>t.id
      and daterange(ot.start_date,coalesce(ot.end_date,ot.start_date),'[]')
          && daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
  ) then return false; end if;

  if exists(
    select 1
    from public.ncaa_individual_doubles_entries e
    join public.tournaments ot on ot.id=e.tournament_id
    where p_player_id in (e.player_a_id,e.player_b_id)
      and ot.id<>t.id
      and daterange(ot.start_date,coalesce(ot.end_date,ot.start_date),'[]')
          && daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
  ) then return false; end if;

  if exists(
    select 1
    from public.world_tournament_entries e
    join public.tournaments ot on ot.id=e.tournament_id
    where e.player_id=p_player_id
      and daterange(
            coalesce(ot.qualifying_start_date,ot.main_draw_start_date,ot.start_date),
            coalesce(ot.end_date,ot.start_date),'[]'
          ) && daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
  ) then return false; end if;

  if exists(
    select 1
    from public.world_tournament_qualifying_entries e
    join public.tournaments ot on ot.id=e.tournament_id
    where e.player_id=p_player_id
      and daterange(
            coalesce(ot.qualifying_start_date,ot.start_date),
            coalesce(ot.qualifying_end_date,ot.main_draw_start_date,ot.end_date,ot.start_date),'[]'
          ) && daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
  ) then return false; end if;

  if exists(
    select 1
    from public.world_doubles_tournament_entries e
    join public.world_doubles_partnerships wp on wp.id=e.pair_id
    join public.tournaments ot on ot.id=e.tournament_id
    where p_player_id in (wp.player_a_id,wp.player_b_id)
      and daterange(
            coalesce(ot.qualifying_start_date,ot.main_draw_start_date,ot.start_date),
            coalesce(ot.end_date,ot.start_date),'[]'
          ) && daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
  ) then return false; end if;

  if exists(
    select 1
    from public.davis_squad ds
    join public.davis_ties dt on ds.nation in (dt.home_nation,dt.away_nation)
    where ds.player_id=p_player_id
      and dt.status in ('scheduled','completed')
      and dt.tie_date between t.start_date and coalesce(t.end_date,t.start_date)
  ) then return false; end if;

  if public.player_in_ncaa_team_event(
    p_player_id,t.start_date,coalesce(t.end_date,t.start_date)
  ) then return false; end if;

  return true;
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

CREATE OR REPLACE FUNCTION public.ncaa_round_code(p_size integer)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  select case
    when p_size>=128 then 'R128'
    when p_size>=64 then 'R64'
    when p_size>=32 then 'R32'
    when p_size>=16 then 'R16'
    when p_size>=8 then 'QF'
    when p_size>=4 then 'SF'
    when p_size>=2 then 'F'
    else 'W'
  end;
$function$;

CREATE OR REPLACE FUNCTION public.ncaa_round_win_points(p_category text, p_round_code text)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  select round((
    case
      when p_category='NCAA DI Individual Championship' then 120
      when p_category in ('ITA All-American Championships','ITA Sectional Championships','ITA Conference Masters') then 95
      when p_category='ITA Division I Regionals' then 75
      when p_category='NCAA Finals' then 80
      when p_category='NCAA Conference' then 60
      when p_category='NCAA UTR' then 42
      else 35
    end
    *
    case p_round_code
      when 'R128' then .18
      when 'R64' then .22
      when 'R32' then .30
      when 'R16' then .42
      when 'QF' then .58
      when 'SF' then .78
      when 'F' then 1.00
      else .20
    end
  ))::int;
$function$;

CREATE OR REPLACE FUNCTION public.ncaa_register_individual_qualifiers(p_tournament_id bigint)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  v_season int;
  v_limit int:=0;
  v_count int:=0;
  rec record;
begin
  select * into t from public.tournaments where id=p_tournament_id;
  if t.id is null then return 0; end if;
  v_season:=extract(year from t.start_date)::int;

  v_limit:=case
    when t.category='ITA All-American Championships' then 8
    when t.category='ITA Division I Regionals' then 8
    when t.category='ITA Sectional Championships' then 6
    when t.category='ITA Conference Masters' then 6
    else 0 end;

  if v_limit=0 then return 0; end if;

  for rec in
    select e.player_id,e.result_code,
      case e.result_code when 'W' then 1 when 'F' then 2 when 'SF' then 3 when 'QF' then 4 else 9 end ord
    from public.ncaa_individual_entries e
    where e.tournament_id=t.id and e.discipline='singles'
      and e.result_code in ('W','F','SF','QF')
    order by ord,e.seed nulls last,e.player_id
    limit v_limit
  loop
    insert into public.ncaa_individual_qualifiers(
      season,discipline,player_ids,source_tournament_id,qualification_reason,qualified_on
    ) values(
      v_season,'singles',array[rec.player_id],t.id,
      t.category||' · '||rec.result_code,
      coalesce(t.end_date,t.start_date)
    )
    on conflict do nothing;
    if found then v_count:=v_count+1; end if;
  end loop;

  v_limit:=case
    when t.category='ITA All-American Championships' then 4
    when t.category='ITA Division I Regionals' then 4
    when t.category='ITA Sectional Championships' then 4
    when t.category='ITA Conference Masters' then 4
    else 0 end;

  for rec in
    select e.player_a_id,e.player_b_id,e.result_code,
      case e.result_code when 'W' then 1 when 'F' then 2 when 'SF' then 3 else 9 end ord
    from public.ncaa_individual_doubles_entries e
    where e.tournament_id=t.id
      and e.result_code in ('W','F','SF')
    order by ord,e.seed nulls last,e.id
    limit v_limit
  loop
    insert into public.ncaa_individual_qualifiers(
      season,discipline,player_ids,source_tournament_id,qualification_reason,qualified_on
    ) values(
      v_season,'doubles',array[rec.player_a_id,rec.player_b_id],t.id,
      t.category||' · '||rec.result_code,
      coalesce(t.end_date,t.start_date)
    )
    on conflict do nothing;
    if found then v_count:=v_count+1; end if;
  end loop;

  return v_count;
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

CREATE OR REPLACE FUNCTION public.prepare_ncaa_priority_individual_events(p_from_date date, p_to_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  rec record;
  v_result jsonb;
  prepared int:=0;
begin
  for rec in
    select t.id
    from public.tournaments t
    where t.circuit='NCAA'
      and coalesce(t.is_active,true)=true
      and coalesce(t.is_verified,false)=true
      and t.category in (
        'ITA All-American Championships',
        'ITA Division I Regionals',
        'ITA Sectional Championships',
        'ITA Conference Masters',
        'NCAA DI Individual Championship'
      )
      and t.start_date<=p_to_date
      and coalesce(t.end_date,t.start_date)>=p_from_date
      and not exists(select 1 from public.ncaa_individual_entries e where e.tournament_id=t.id)
      and not exists(select 1 from public.ncaa_individual_doubles_entries e where e.tournament_id=t.id)
    order by t.start_date,t.id
  loop
    v_result:=public.ncaa_prepare_individual_event(rec.id);
    if coalesce((v_result->>'ok')::boolean,false) then
      prepared:=prepared+1;
    end if;
  end loop;

  return jsonb_build_object(
    'events_prepared',prepared,
    'priority','verified_ITA_NCAA_before_pro'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.ensure_ita_kickoff_weekend(p_year integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  teams bigint[];
  smu_id bigint;
  baylor_id bigint;
  p int;
  a bigint;
  b bigint;
  c bigint;
  d bigint;
  created int:=0;
begin
  select * into t
  from public.tournaments
  where circuit='NCAA'
    and category='ITA Kickoff Weekend'
    and extract(year from start_date)::int=p_year
    and coalesce(is_active,true)=true
  order by start_date
  limit 1;

  if t.id is null then
    return jsonb_build_object('created',0,'reason','kickoff_not_found');
  end if;

  if exists(select 1 from public.college_duals where tournament_id=t.id) then
    return jsonb_build_object('created',0,'already',true,'tournament_id',t.id);
  end if;

  select id into smu_id from public.college_teams where lower(name) like 'smu %' order by id limit 1;
  select id into baylor_id from public.college_teams where lower(name) like 'baylor %' order by id limit 1;

  select array_agg(id order by coalesce(preseason_rank,ita_rank,9999),id)
  into teams
  from (
    select id,preseason_rank,ita_rank
    from public.college_teams
    where id is distinct from smu_id
      and id is distinct from baylor_id
    order by coalesce(preseason_rank,ita_rank,9999),id
    limit 56
  ) q;

  if coalesce(array_length(teams,1),0)<>56 then
    return jsonb_build_object('created',0,'reason','need_56_teams','count',coalesce(array_length(teams,1),0));
  end if;

  for p in 1..14 loop
    a:=teams[p];
    b:=teams[29-p];
    c:=teams[28+p];
    d:=teams[57-p];

    insert into public.college_duals(
      tournament_id,match_date,home_team_id,away_team_id,status,
      competition,stage,pod_no,bracket_slot,draw_position,
      surface,indoor,source_label,model_version
    ) values
      (t.id,t.start_date,a,d,'scheduled','ITA Kickoff Weekend','Pod Semi-final',p,p*10+1,p*4-3,
       coalesce(t.surface,'Dur'),true,'ITA 2026 format · Court Boss simulated field','CB-ITA-KO-v1'),
      (t.id,t.start_date,b,c,'scheduled','ITA Kickoff Weekend','Pod Semi-final',p,p*10+2,p*4-2,
       coalesce(t.surface,'Dur'),true,'ITA 2026 format · Court Boss simulated field','CB-ITA-KO-v1');
    created:=created+2;
  end loop;

  return jsonb_build_object(
    'created',created,'tournament_id',t.id,'teams',56,'pods',14,
    'auto_bids',jsonb_build_array(smu_id,baylor_id),
    'model','56 teams · 14 four-team sites · SMU/Baylor auto-bids'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.advance_ita_kickoff_weekend(p_tournament_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  p int;
  w1 bigint;
  w2 bigint;
  created int:=0;
begin
  select * into t from public.tournaments where id=p_tournament_id;
  if t.id is null then return jsonb_build_object('created',0,'reason','not_found'); end if;

  for p in 1..14 loop
    if exists(
      select 1 from public.college_duals
      where tournament_id=t.id and stage='Pod Final' and pod_no=p
    ) then continue; end if;

    select winner_team_id into w1
    from public.college_duals
    where tournament_id=t.id and stage='Pod Semi-final' and pod_no=p
    order by bracket_slot
    limit 1;

    select winner_team_id into w2
    from public.college_duals
    where tournament_id=t.id and stage='Pod Semi-final' and pod_no=p
    order by bracket_slot
    offset 1 limit 1;

    if w1 is not null and w2 is not null then
      insert into public.college_duals(
        tournament_id,match_date,home_team_id,away_team_id,status,
        competition,stage,pod_no,bracket_slot,surface,indoor,source_label,model_version
      ) values(
        t.id,t.start_date+1,w1,w2,'scheduled',
        'ITA Kickoff Weekend','Pod Final',p,p*10+3,
        coalesce(t.surface,'Dur'),true,'ITA 2026 format · Court Boss simulated field','CB-ITA-KO-v1'
      );
      created:=created+1;
    end if;
  end loop;

  return jsonb_build_object('created',created,'tournament_id',t.id);
end;
$function$;

CREATE OR REPLACE FUNCTION public.ensure_ita_team_indoor_field(p_year integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  indoor_t public.tournaments%rowtype;
  kickoff_t public.tournaments%rowtype;
  teams bigint[];
  smu_id bigint;
  baylor_id bigint;
  seeded bigint[];
  i int;
  created int:=0;
begin
  select * into indoor_t
  from public.tournaments
  where circuit='NCAA'
    and category='ITA National Team Indoor Championship'
    and extract(year from start_date)::int=p_year
    and coalesce(is_active,true)=true
  order by start_date limit 1;

  if indoor_t.id is null then
    return jsonb_build_object('created',0,'reason','team_indoor_not_found');
  end if;

  if exists(select 1 from public.college_duals where tournament_id=indoor_t.id) then
    return jsonb_build_object('created',0,'already',true,'tournament_id',indoor_t.id);
  end if;

  select * into kickoff_t
  from public.tournaments
  where circuit='NCAA'
    and category='ITA Kickoff Weekend'
    and extract(year from start_date)::int=p_year
  order by start_date limit 1;

  if kickoff_t.id is null then
    return jsonb_build_object('created',0,'reason','kickoff_not_found');
  end if;

  if (select count(*) from public.college_duals
      where tournament_id=kickoff_t.id and stage='Pod Final' and status='completed')<14 then
    return jsonb_build_object('created',0,'reason','kickoff_not_complete');
  end if;

  select id into smu_id from public.college_teams where lower(name) like 'smu %' order by id limit 1;
  select id into baylor_id from public.college_teams where lower(name) like 'baylor %' order by id limit 1;

  select array_agg(team_id order by rk,id)
  into seeded
  from (
    select x.team_id,coalesce(ct.ita_rank,ct.preseason_rank,9999) rk,ct.id
    from (
      select winner_team_id team_id
      from public.college_duals
      where tournament_id=kickoff_t.id and stage='Pod Final' and status='completed'
      union
      select smu_id
      union
      select baylor_id
    ) x
    join public.college_teams ct on ct.id=x.team_id
  ) q;

  if coalesce(array_length(seeded,1),0)<>16 then
    return jsonb_build_object('created',0,'reason','need_16_teams','count',coalesce(array_length(seeded,1),0));
  end if;

  for i in 1..8 loop
    insert into public.college_duals(
      tournament_id,match_date,home_team_id,away_team_id,status,
      competition,stage,bracket_slot,draw_position,surface,indoor,source_label,model_version
    ) values(
      indoor_t.id,indoor_t.start_date,
      seeded[i],seeded[17-i],'scheduled',
      'ITA National Team Indoor Championship','R16',i,i,
      coalesce(indoor_t.surface,'Dur'),true,
      'ITA 2026 16-team indoor field · Court Boss simulated bracket','CB-ITA-INDOOR-v1'
    );
    created:=created+1;
  end loop;

  return jsonb_build_object(
    'created',created,'tournament_id',indoor_t.id,'teams',16,
    'cohost_auto_bids',jsonb_build_array(smu_id,baylor_id)
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.advance_ita_team_indoor(p_tournament_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  i int;
  a bigint;
  b bigint;
  created int:=0;
begin
  select * into t from public.tournaments where id=p_tournament_id;
  if t.id is null then return jsonb_build_object('created',0,'reason','not_found'); end if;

  -- Main quarter-finals, day two.
  for i in 1..4 loop
    if not exists(select 1 from public.college_duals where tournament_id=t.id and stage='QF' and bracket_slot=i) then
      select winner_team_id into a from public.college_duals
      where tournament_id=t.id and stage='R16' and bracket_slot=i*2-1 and status='completed';
      select winner_team_id into b from public.college_duals
      where tournament_id=t.id and stage='R16' and bracket_slot=i*2 and status='completed';
      if a is not null and b is not null then
        insert into public.college_duals(
          tournament_id,match_date,home_team_id,away_team_id,status,
          competition,stage,bracket_slot,surface,indoor,source_label,model_version
        ) values(
          t.id,t.start_date+1,a,b,'scheduled',
          'ITA National Team Indoor Championship','QF',i,
          coalesce(t.surface,'Dur'),true,'ITA 2026 main draw','CB-ITA-INDOOR-v1'
        );
        created:=created+1;
      end if;
    end if;
  end loop;

  -- First consolation round for R16 losers, day two.
  for i in 1..4 loop
    if not exists(select 1 from public.college_duals where tournament_id=t.id and stage='Back Draw R1' and bracket_slot=i) then
      select case when winner_team_id=home_team_id then away_team_id else home_team_id end into a
      from public.college_duals where tournament_id=t.id and stage='R16' and bracket_slot=i*2-1 and status='completed';
      select case when winner_team_id=home_team_id then away_team_id else home_team_id end into b
      from public.college_duals where tournament_id=t.id and stage='R16' and bracket_slot=i*2 and status='completed';
      if a is not null and b is not null then
        insert into public.college_duals(
          tournament_id,match_date,home_team_id,away_team_id,status,
          competition,stage,bracket_slot,surface,indoor,source_label,model_version
        ) values(
          t.id,t.start_date+1,a,b,'scheduled',
          'ITA National Team Indoor Championship','Back Draw R1',i,
          coalesce(t.surface,'Dur'),true,'ITA 2026 consolation · three-match guarantee','CB-ITA-INDOOR-v1'
        );
        created:=created+1;
      end if;
    end if;
  end loop;

  -- Third matches for R16 losers, day three.
  for i in 1..2 loop
    if not exists(select 1 from public.college_duals where tournament_id=t.id and stage='Back Draw Winners' and bracket_slot=i) then
      select winner_team_id into a from public.college_duals
      where tournament_id=t.id and stage='Back Draw R1' and bracket_slot=i*2-1 and status='completed';
      select winner_team_id into b from public.college_duals
      where tournament_id=t.id and stage='Back Draw R1' and bracket_slot=i*2 and status='completed';
      if a is not null and b is not null then
        insert into public.college_duals(
          tournament_id,match_date,home_team_id,away_team_id,status,
          competition,stage,bracket_slot,surface,indoor,source_label,model_version
        ) values(
          t.id,t.start_date+2,a,b,'scheduled',
          'ITA National Team Indoor Championship','Back Draw Winners',i,
          coalesce(t.surface,'Dur'),true,'ITA 2026 consolation · three-match guarantee','CB-ITA-INDOOR-v1'
        );
        created:=created+1;
      end if;
    end if;

    if not exists(select 1 from public.college_duals where tournament_id=t.id and stage='Back Draw Losers' and bracket_slot=i) then
      select case when winner_team_id=home_team_id then away_team_id else home_team_id end into a
      from public.college_duals
      where tournament_id=t.id and stage='Back Draw R1' and bracket_slot=i*2-1 and status='completed';
      select case when winner_team_id=home_team_id then away_team_id else home_team_id end into b
      from public.college_duals
      where tournament_id=t.id and stage='Back Draw R1' and bracket_slot=i*2 and status='completed';
      if a is not null and b is not null then
        insert into public.college_duals(
          tournament_id,match_date,home_team_id,away_team_id,status,
          competition,stage,bracket_slot,surface,indoor,source_label,model_version
        ) values(
          t.id,t.start_date+2,a,b,'scheduled',
          'ITA National Team Indoor Championship','Back Draw Losers',i,
          coalesce(t.surface,'Dur'),true,'ITA 2026 consolation · three-match guarantee','CB-ITA-INDOOR-v1'
        );
        created:=created+1;
      end if;
    end if;
  end loop;

  -- QF losers get their guaranteed third match on day three.
  for i in 1..2 loop
    if not exists(select 1 from public.college_duals where tournament_id=t.id and stage='QF Placement' and bracket_slot=i) then
      select case when winner_team_id=home_team_id then away_team_id else home_team_id end into a
      from public.college_duals
      where tournament_id=t.id and stage='QF' and bracket_slot=i*2-1 and status='completed';
      select case when winner_team_id=home_team_id then away_team_id else home_team_id end into b
      from public.college_duals
      where tournament_id=t.id and stage='QF' and bracket_slot=i*2 and status='completed';
      if a is not null and b is not null then
        insert into public.college_duals(
          tournament_id,match_date,home_team_id,away_team_id,status,
          competition,stage,bracket_slot,surface,indoor,source_label,model_version
        ) values(
          t.id,t.start_date+2,a,b,'scheduled',
          'ITA National Team Indoor Championship','QF Placement',i,
          coalesce(t.surface,'Dur'),true,'ITA 2026 consolation · three-match guarantee','CB-ITA-INDOOR-v1'
        );
        created:=created+1;
      end if;
    end if;
  end loop;

  -- Semifinals after the official day off.
  for i in 1..2 loop
    if not exists(select 1 from public.college_duals where tournament_id=t.id and stage='SF' and bracket_slot=i) then
      select winner_team_id into a from public.college_duals
      where tournament_id=t.id and stage='QF' and bracket_slot=i*2-1 and status='completed';
      select winner_team_id into b from public.college_duals
      where tournament_id=t.id and stage='QF' and bracket_slot=i*2 and status='completed';
      if a is not null and b is not null then
        insert into public.college_duals(
          tournament_id,match_date,home_team_id,away_team_id,status,
          competition,stage,bracket_slot,surface,indoor,source_label,model_version
        ) values(
          t.id,t.start_date+3,a,b,'scheduled',
          'ITA National Team Indoor Championship','SF',i,
          coalesce(t.surface,'Dur'),true,'ITA 2026 main draw · rest day before SF','CB-ITA-INDOOR-v1'
        );
        created:=created+1;
      end if;
    end if;
  end loop;

  if not exists(select 1 from public.college_duals where tournament_id=t.id and stage='F') then
    select winner_team_id into a from public.college_duals
    where tournament_id=t.id and stage='SF' and bracket_slot=1 and status='completed';
    select winner_team_id into b from public.college_duals
    where tournament_id=t.id and stage='SF' and bracket_slot=2 and status='completed';
    if a is not null and b is not null then
      insert into public.college_duals(
        tournament_id,match_date,home_team_id,away_team_id,status,
        competition,stage,bracket_slot,surface,indoor,source_label,model_version
      ) values(
        t.id,t.start_date+4,a,b,'scheduled',
        'ITA National Team Indoor Championship','F',1,
        coalesce(t.surface,'Dur'),true,'ITA 2026 main draw','CB-ITA-INDOOR-v1'
      );
      created:=created+1;
    end if;
  end if;

  return jsonb_build_object('created',created,'tournament_id',t.id);
end;
$function$;

CREATE OR REPLACE FUNCTION public.prepare_ita_team_events(p_from_date date, p_to_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  yr int:=extract(year from p_to_date)::int;
  ko jsonb;
  indoors jsonb;
begin
  ko:=public.ensure_ita_kickoff_weekend(yr);
  indoors:=public.ensure_ita_team_indoor_field(yr);

  return jsonb_build_object(
    'kickoff',ko,
    'team_indoor',indoors,
    'from',p_from_date,'to',p_to_date,
    'mode','schedule_only'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.simulate_ita_team_event_results(p_from_date date, p_to_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  yr int:=extract(year from p_to_date)::int;
  ko_t bigint;
  indoor_t bigint;
  v_id bigint;
  v_result jsonb;
  v_adv jsonb;
  simulated int:=0;
begin
  select id into ko_t from public.tournaments
  where circuit='NCAA' and category='ITA Kickoff Weekend'
    and extract(year from start_date)::int=yr
  order by start_date limit 1;

  select id into indoor_t from public.tournaments
  where circuit='NCAA' and category='ITA National Team Indoor Championship'
    and extract(year from start_date)::int=yr
  order by start_date limit 1;

  loop
    select d.id into v_id
    from public.college_duals d
    where d.tournament_id in (ko_t,indoor_t)
      and d.status='scheduled'
      and d.match_date>p_from_date
      and d.match_date<=p_to_date
    order by d.match_date,d.id
    limit 1;

    exit when v_id is null;

    v_result:=public.simulate_ncaa_dual_v2(v_id);
    if coalesce((v_result->>'ok')::boolean,false) then
      simulated:=simulated+1;
    end if;

    if exists(select 1 from public.college_duals where id=v_id and tournament_id=ko_t) then
      v_adv:=public.advance_ita_kickoff_weekend(ko_t);
      perform public.ensure_ita_team_indoor_field(yr);
    elsif exists(select 1 from public.college_duals where id=v_id and tournament_id=indoor_t) then
      v_adv:=public.advance_ita_team_indoor(indoor_t);
    end if;
  end loop;

  return jsonb_build_object(
    'team_event_duals_simulated',simulated,
    'kickoff_tournament_id',ko_t,
    'indoor_tournament_id',indoor_t,
    'mode','results_only'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.simulate_ita_team_events(p_from_date date, p_to_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  prep jsonb;
  sim jsonb;
begin
  prep:=public.prepare_ita_team_events(p_from_date,p_to_date);
  sim:=public.simulate_ita_team_event_results(p_from_date,p_to_date);
  return jsonb_build_object(
    'prepared',prep,
    'simulated',sim,
    'model','ITA 2026 · scheduled before pro, lineups resolved after pro'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.simulate_ncaa_team_events(p_from_date date, p_to_date date)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO 'public'
AS $function$
  select public.simulate_ita_team_events(p_from_date,p_to_date);
$function$;


-- Keep the existing weekly NCAA schedule deterministic and non-future-leaking.
select public.ensure_ncaa_regular_schedule(2026);
