-- Court Boss Laver Cup season engine v1
-- Captured from live Supabase after Edge v413 / season model v41.

create table if not exists public.laver_cup_rosters(
  tournament_id bigint not null references public.tournaments(id) on delete cascade,
  team_code text not null check(team_code in ('EUROPE','WORLD')),
  player_id bigint not null references public.players(id) on delete cascade,
  roster_slot integer not null,
  selection_method text not null,
  ranking_at_selection integer,
  selected_on date not null,
  primary key(tournament_id,team_code,player_id),
  unique(tournament_id,team_code,roster_slot)
);
alter table public.laver_cup_rosters enable row level security;
create index if not exists laver_cup_rosters_player_idx
  on public.laver_cup_rosters(player_id,tournament_id);

create table if not exists public.laver_cup_matches(
  id bigint generated always as identity primary key,
  tournament_id bigint not null references public.tournaments(id) on delete cascade,
  match_no integer not null,
  day_no integer not null,
  match_type text not null check(match_type in ('singles','doubles','decider')),
  europe_player_ids bigint[] not null,
  world_player_ids bigint[] not null,
  winner_team text not null check(winner_team in ('EUROPE','WORLD')),
  points_value integer not null,
  score text,
  europe_win_probability numeric,
  played_on date not null,
  model_version text not null default 'CB-LAVER-v1',
  unique(tournament_id,match_no)
);
alter table public.laver_cup_matches enable row level security;
create index if not exists laver_cup_matches_date_idx
  on public.laver_cup_matches(played_on,tournament_id);

create table if not exists public.laver_cup_history(
  tournament_id bigint primary key references public.tournaments(id) on delete cascade,
  season integer not null,
  winner_team text not null,
  europe_points integer not null,
  world_points integer not null,
  decider_played boolean not null default false,
  completed_on date not null,
  source_label text not null
);
alter table public.laver_cup_history enable row level security;

CREATE OR REPLACE FUNCTION public.laver_region(p_country text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  select case
    when upper(coalesce(p_country,''))=any(array[
      'ALB','AND','ARM','AUT','AZE','BLR','BEL','BIH','BUL','CRO','CYP','CZE',
      'DEN','EST','FIN','FRA','GEO','GER','GRE','HUN','ISL','IRL','ITA','KOS',
      'LAT','LIE','LTU','LUX','MLT','MDA','MON','MNE','NED','MKD','NOR','POL',
      'POR','ROU','RUS','SMR','SRB','SVK','SLO','ESP','SWE','SUI','UKR','GBR'
    ]) then 'EUROPE'
    else 'WORLD'
  end;
$function$;

CREATE OR REPLACE FUNCTION public.prepare_laver_cup_roster(p_tournament_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  rg_end date;
  selection_date date;
  team text;
  slot int;
  rec record;
  committed_id bigint;
  v_count int;
begin
  select * into t
  from public.tournaments
  where id=p_tournament_id and category='Laver Cup' and coalesce(is_active,true)=true;

  if t.id is null then return jsonb_build_object('ok',false,'reason','not_laver_cup'); end if;

  if exists(select 1 from public.laver_cup_rosters where tournament_id=t.id) then
    return jsonb_build_object(
      'ok',true,'already',true,
      'europe',(select count(*) from public.laver_cup_rosters where tournament_id=t.id and team_code='EUROPE'),
      'world',(select count(*) from public.laver_cup_rosters where tournament_id=t.id and team_code='WORLD')
    );
  end if;

  select max(end_date) into rg_end
  from public.tournaments
  where category='Grand Chelem'
    and name ilike '%Roland%'
    and extract(year from end_date)::int=extract(year from t.start_date)::int;

  selection_date:=coalesce(rg_end+1,make_date(extract(year from t.start_date)::int,6,8));

  for team in select unnest(array['EUROPE','WORLD']) loop
    slot:=0;

    for rec in
      select p.id,
             coalesce(public.player_rank_at_date(p.id,selection_date),
                      case when p.ranking_current then p.ranking end,
                      p.game_world_rank,p.ranking,999999)::int rankv
      from public.players p
      where p.career_status='active'
        and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
        and public.laver_region(p.country)=team
      order by rankv,p.current_ability desc,p.id
      limit 3
    loop
      slot:=slot+1;
      insert into public.laver_cup_rosters(
        tournament_id,team_code,player_id,roster_slot,
        selection_method,ranking_at_selection,selected_on
      ) values(
        t.id,team,rec.id,slot,'ranking_auto',rec.rankv,selection_date
      );
    end loop;

    committed_id:=null;
    if team='EUROPE' then
      select id into committed_id
      from public.players
      where name='Carlos Alcaraz'
        and career_status='active'
        and coalesce(data_source,'') not ilike 'hidden duplicate merged into %'
      order by ranking_current desc,coalesce(game_world_rank,ranking,999999),id
      limit 1;
    else
      select id into committed_id
      from public.players
      where name='Taylor Fritz'
        and career_status='active'
        and coalesce(data_source,'') not ilike 'hidden duplicate merged into %'
      order by ranking_current desc,coalesce(game_world_rank,ranking,999999),id
      limit 1;
    end if;

    if committed_id is not null
       and not exists(
         select 1 from public.laver_cup_rosters
         where tournament_id=t.id and team_code=team and player_id=committed_id
       )
       and exists(
         select 1 from public.players p
         where p.id=committed_id and p.career_status='active'
           and public.laver_region(p.country)=team
       ) then
      slot:=slot+1;
      insert into public.laver_cup_rosters(
        tournament_id,team_code,player_id,roster_slot,
        selection_method,ranking_at_selection,selected_on
      )
      select t.id,team,p.id,slot,'prebaseline_confirmed_captain_pick',
             coalesce(public.player_rank_at_date(p.id,selection_date),
                      case when p.ranking_current then p.ranking end,
                      p.game_world_rank,p.ranking,999999)::int,
             selection_date
      from public.players p where p.id=committed_id;
    end if;

    for rec in
      select p.id,
             coalesce(public.player_rank_at_date(p.id,selection_date),
                      case when p.ranking_current then p.ranking end,
                      p.game_world_rank,p.ranking,999999)::int rankv,
             (
               coalesce(p.current_ability,50)*1.55+
               coalesce(p.form,70)*.22+
               coalesce(pa.big_points,10)*1.10+
               coalesce(pa.composure,10)*.85+
               coalesce(pa.doubles,10)*.75+
               coalesce(pa.adaptability,10)*.55+
               greatest(0,60-coalesce(public.player_rank_at_date(p.id,selection_date),p.ranking,60))*.25+
               (mod(abs(hashtext('laver-pick|'||t.id||'|'||team||'|'||p.id)),1000)::numeric/1000.0)*4
             ) pick_score
      from public.players p
      left join public.player_attributes pa on pa.player_id=p.id
      where p.career_status='active'
        and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
        and public.laver_region(p.country)=team
        and not exists(
          select 1 from public.laver_cup_rosters r
          where r.tournament_id=t.id and r.team_code=team and r.player_id=p.id
        )
      order by pick_score desc,rankv,p.id
      limit greatest(0,6-slot)
    loop
      slot:=slot+1;
      insert into public.laver_cup_rosters(
        tournament_id,team_code,player_id,roster_slot,
        selection_method,ranking_at_selection,selected_on
      ) values(
        t.id,team,rec.id,slot,'captain_pick',rec.rankv,selection_date
      );
    end loop;

    select count(*) into v_count
    from public.laver_cup_rosters
    where tournament_id=t.id and team_code=team;

    if v_count<>6 then
      delete from public.laver_cup_rosters where tournament_id=t.id;
      return jsonb_build_object('ok',false,'reason','incomplete_roster','team',team,'count',v_count);
    end if;
  end loop;

  return jsonb_build_object(
    'ok',true,'selection_date',selection_date,
    'europe',6,'world',6,
    'model','3 ranking invitations + 3 captain picks; pre-01/12/2025 commitments preserved'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.prepare_laver_cup_window(p_from_date date, p_to_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  rg_end date;
  selection_date date;
  r jsonb;
begin
  select * into t
  from public.tournaments
  where category='Laver Cup'
    and coalesce(is_active,true)=true
    and extract(year from start_date)::int=extract(year from p_to_date)::int
  order by start_date limit 1;

  if t.id is null then return jsonb_build_object('events_prepared',0,'active_event',false); end if;

  select max(end_date) into rg_end
  from public.tournaments
  where category='Grand Chelem' and name ilike '%Roland%'
    and extract(year from end_date)::int=extract(year from t.start_date)::int;

  selection_date:=coalesce(rg_end+1,make_date(extract(year from t.start_date)::int,6,8));

  if (selection_date>p_from_date and selection_date<=p_to_date)
     or (p_to_date>=selection_date and not exists(
       select 1 from public.laver_cup_rosters where tournament_id=t.id
     )) then
    r:=public.prepare_laver_cup_roster(t.id);
    return jsonb_build_object(
      'events_prepared',case when coalesce((r->>'ok')::boolean,false) then 1 else 0 end,
      'tournament_id',t.id,'selection_date',selection_date,'preparation',r
    );
  end if;

  return jsonb_build_object('events_prepared',0,'tournament_id',t.id,'selection_date',selection_date);
end;
$function$;

CREATE OR REPLACE FUNCTION public.laver_singles_match(p_europe_player bigint, p_world_player bigint, p_surface text, p_date date, p_key text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  m jsonb;
  prob numeric;
  roll numeric;
  split_roll numeric;
  ewin boolean;
  score text;
begin
  m:=public.player_matchup_probability_v4(
    p_europe_player,p_world_player,coalesce(p_surface,'Dur'),p_date,1.0,3
  );
  prob:=greatest(.04,least(.96,coalesce((m->>'player_a_probability')::numeric,.5)));
  roll:=mod(abs(hashtext('laver-s|'||p_key||'|'||p_europe_player||'|'||p_world_player)),10000)/10000.0;
  split_roll:=mod(abs(hashtext('laver-s-score|'||p_key||'|'||p_europe_player||'|'||p_world_player)),10000)/10000.0;
  ewin:=roll<prob;

  if abs(prob-.5)<.14 or split_roll<.32 then
    score:=case when ewin then '6-4 3-6 [10-7]' else '4-6 6-3 [7-10]' end;
  elsif ewin then
    score:=case when prob>.68 then '6-3 6-4' else '7-6 6-4' end;
  else
    score:=case when prob<.32 then '3-6 4-6' else '6-7 4-6' end;
  end if;

  return jsonb_build_object(
    'europe_win',ewin,'europe_probability',round(prob,4),'score',score,
    'components',coalesce(m->'components','{}'::jsonb)
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.laver_doubles_match(p_e1 bigint, p_e2 bigint, p_w1 bigint, p_w2 bigint, p_surface text, p_date date, p_key text, p_decider boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  es numeric;
  ws numeric;
  prob numeric;
  roll numeric;
  split_roll numeric;
  ewin boolean;
  score text;
begin
  select sum(
    coalesce(p.current_ability,50)*.42+
    coalesce(pa.doubles,10)*1.45+
    coalesce(pa.volley,10)*.45+
    coalesce(pa.net_positioning,10)*.50+
    coalesce(pa.doubles_communication,10)*.45+
    coalesce(pa.big_points,10)*.35+
    coalesce(p.form,70)*.08+
    coalesce(p.fitness,85)*.04-
    coalesce(p.fatigue,20)*.06
  ) into es
  from public.players p
  left join public.player_attributes pa on pa.player_id=p.id
  where p.id in (p_e1,p_e2);

  select sum(
    coalesce(p.current_ability,50)*.42+
    coalesce(pa.doubles,10)*1.45+
    coalesce(pa.volley,10)*.45+
    coalesce(pa.net_positioning,10)*.50+
    coalesce(pa.doubles_communication,10)*.45+
    coalesce(pa.big_points,10)*.35+
    coalesce(p.form,70)*.08+
    coalesce(p.fitness,85)*.04-
    coalesce(p.fatigue,20)*.06
  ) into ws
  from public.players p
  left join public.player_attributes pa on pa.player_id=p.id
  where p.id in (p_w1,p_w2);

  prob:=greatest(.06,least(.94,1/(1+exp(-(coalesce(es,100)-coalesce(ws,100))/10.5))));
  roll:=mod(abs(hashtext('laver-d|'||p_key||'|'||p_e1||'|'||p_e2||'|'||p_w1||'|'||p_w2)),10000)/10000.0;
  split_roll:=mod(abs(hashtext('laver-d-score|'||p_key||'|'||p_e1||'|'||p_e2||'|'||p_w1||'|'||p_w2)),10000)/10000.0;
  ewin:=roll<prob;

  if p_decider then
    score:=case when ewin then '7-5' else '5-7' end;
  elsif abs(prob-.5)<.15 or split_roll<.36 then
    score:=case when ewin then '6-4 3-6 [10-8]' else '4-6 6-3 [8-10]' end;
  elsif ewin then
    score:='6-4 6-3';
  else
    score:='4-6 3-6';
  end if;

  return jsonb_build_object(
    'europe_win',ewin,'europe_probability',round(prob,4),'score',score
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.refresh_laver_cup_roster_availability(p_tournament_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  rec record;
  repl bigint;
  replaced int:=0;
begin
  select * into t from public.tournaments where id=p_tournament_id and category='Laver Cup';
  if t.id is null then return jsonb_build_object('ok',false,'reason','not_laver_cup'); end if;

  for rec in
    select r.team_code,r.player_id,r.roster_slot
    from public.laver_cup_rosters r
    join public.players p on p.id=r.player_id
    where r.tournament_id=t.id
      and (
        p.career_status<>'active'
        or p.injury_status<>'Fit'
        or coalesce(p.fitness,90)<40
      )
    order by r.team_code,r.roster_slot
  loop
    repl:=null;
    select p.id into repl
    from public.players p
    where p.career_status='active'
      and p.injury_status='Fit'
      and coalesce(p.fitness,90)>=50
      and public.laver_region(p.country)=rec.team_code
      and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
      and not exists(
        select 1 from public.laver_cup_rosters r2
        where r2.tournament_id=t.id and r2.player_id=p.id
      )
    order by
      coalesce(public.player_rank_at_date(p.id,t.start_date),p.game_world_rank,p.ranking,999999),
      p.current_ability desc,p.id
    limit 1;

    if repl is null then
      return jsonb_build_object('ok',false,'reason','replacement_unavailable','team',rec.team_code);
    end if;

    update public.laver_cup_rosters
    set player_id=repl,
        selection_method='injury_replacement',
        ranking_at_selection=coalesce(
          public.player_rank_at_date(repl,t.start_date),
          (select game_world_rank from public.players where id=repl),
          (select ranking from public.players where id=repl),
          999999
        )
    where tournament_id=t.id
      and team_code=rec.team_code
      and roster_slot=rec.roster_slot;

    replaced:=replaced+1;
  end loop;

  return jsonb_build_object('ok',true,'replacements',replaced);
end;
$function$;

CREATE OR REPLACE FUNCTION public.laver_play_singles(p_tournament_id bigint, p_match_no integer, p_day_no integer, p_europe_player bigint, p_world_player bigint, p_points integer, p_played_on date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  r jsonb;
  ewin boolean;
  winner text;
begin
  select * into t from public.tournaments where id=p_tournament_id;
  r:=public.laver_singles_match(
    p_europe_player,p_world_player,t.surface,p_played_on,
    t.id||'|'||p_match_no
  );
  ewin:=coalesce((r->>'europe_win')::boolean,false);
  winner:=case when ewin then 'EUROPE' else 'WORLD' end;

  insert into public.laver_cup_matches(
    tournament_id,match_no,day_no,match_type,
    europe_player_ids,world_player_ids,winner_team,points_value,
    score,europe_win_probability,played_on
  ) values(
    t.id,p_match_no,p_day_no,'singles',
    array[p_europe_player],array[p_world_player],winner,p_points,
    r->>'score',(r->>'europe_probability')::numeric,p_played_on
  );

  update public.players
  set fatigue=least(100,coalesce(fatigue,20)+4),
      fitness=greatest(35,coalesce(fitness,90)-1),
      form=greatest(1,least(100,coalesce(form,70)+
        case
          when id=case when ewin then p_europe_player else p_world_player end then 1
          else -1 end))
  where id in (p_europe_player,p_world_player);

  return jsonb_build_object(
    'winner_team',winner,'points',p_points,'score',r->>'score',
    'europe_probability',r->>'europe_probability'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.laver_play_doubles(p_tournament_id bigint, p_match_no integer, p_day_no integer, p_e1 bigint, p_e2 bigint, p_w1 bigint, p_w2 bigint, p_points integer, p_played_on date, p_decider boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  r jsonb;
  ewin boolean;
  winner text;
begin
  select * into t from public.tournaments where id=p_tournament_id;
  r:=public.laver_doubles_match(
    p_e1,p_e2,p_w1,p_w2,t.surface,p_played_on,
    t.id||'|'||p_match_no,p_decider
  );
  ewin:=coalesce((r->>'europe_win')::boolean,false);
  winner:=case when ewin then 'EUROPE' else 'WORLD' end;

  insert into public.laver_cup_matches(
    tournament_id,match_no,day_no,match_type,
    europe_player_ids,world_player_ids,winner_team,points_value,
    score,europe_win_probability,played_on
  ) values(
    t.id,p_match_no,p_day_no,case when p_decider then 'decider' else 'doubles' end,
    array[p_e1,p_e2],array[p_w1,p_w2],winner,p_points,
    r->>'score',(r->>'europe_probability')::numeric,p_played_on
  );

  update public.players
  set fatigue=least(100,coalesce(fatigue,20)+3),
      fitness=greatest(35,coalesce(fitness,90)-1),
      form=greatest(1,least(100,coalesce(form,70)+
        case
          when (winner='EUROPE' and id in (p_e1,p_e2))
            or (winner='WORLD' and id in (p_w1,p_w2)) then 1
          else -1 end))
  where id in (p_e1,p_e2,p_w1,p_w2);

  return jsonb_build_object(
    'winner_team',winner,'points',p_points,'score',r->>'score',
    'europe_probability',r->>'europe_probability'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.simulate_laver_cup(p_from_date date, p_to_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  prep jsonb;
  availability jsonb;
  e bigint[];
  w bigint[];
  ed bigint[];
  wd bigint[];
  e1 int[]:=array[4,5,6];
  w1 int[]:=array[5,6,4];
  e2 int[]:=array[1,2,3];
  w2 int[]:=array[2,3,1];
  e3 int[]:=array[1,2,3];
  w3 int[]:=array[3,1,2];
  i int;
  mn int:=0;
  ep int:=0;
  wp int:=0;
  r jsonb;
  winner text;
  decider boolean:=false;
  rec record;
begin
  select * into t
  from public.tournaments
  where category='Laver Cup'
    and coalesce(is_active,true)=true
    and coalesce(end_date,start_date)>p_from_date
    and coalesce(end_date,start_date)<=p_to_date
  order by start_date
  limit 1;

  if t.id is null then
    return jsonb_build_object('events_simulated',0,'active_event',false);
  end if;

  if exists(select 1 from public.laver_cup_history where tournament_id=t.id) then
    return jsonb_build_object('events_simulated',0,'already_simulated',true,'tournament_id',t.id);
  end if;

  prep:=public.prepare_laver_cup_roster(t.id);
  if coalesce((prep->>'ok')::boolean,false)=false then
    return jsonb_build_object('events_simulated',0,'preparation',prep);
  end if;

  availability:=public.refresh_laver_cup_roster_availability(t.id);
  if coalesce((availability->>'ok')::boolean,false)=false then
    return jsonb_build_object('events_simulated',0,'availability',availability);
  end if;

  select array_agg(player_id order by roster_slot)
  into e
  from public.laver_cup_rosters
  where tournament_id=t.id and team_code='EUROPE';

  select array_agg(player_id order by roster_slot)
  into w
  from public.laver_cup_rosters
  where tournament_id=t.id and team_code='WORLD';

  if coalesce(array_length(e,1),0)<>6 or coalesce(array_length(w,1),0)<>6 then
    return jsonb_build_object('events_simulated',0,'reason','invalid_roster');
  end if;

  select array_agg(x.player_id order by x.dscore desc,x.player_id)
  into ed
  from (
    select r.player_id,
      coalesce(p.current_ability,50)*.55+
      coalesce(pa.doubles,10)*1.65+
      coalesce(pa.volley,10)*.45+
      coalesce(pa.net_positioning,10)*.55+
      coalesce(pa.doubles_communication,10)*.50+
      coalesce(pa.big_points,10)*.30+
      coalesce(p.form,70)*.08 as dscore
    from public.laver_cup_rosters r
    join public.players p on p.id=r.player_id
    left join public.player_attributes pa on pa.player_id=p.id
    where r.tournament_id=t.id and r.team_code='EUROPE'
  ) x;

  select array_agg(x.player_id order by x.dscore desc,x.player_id)
  into wd
  from (
    select r.player_id,
      coalesce(p.current_ability,50)*.55+
      coalesce(pa.doubles,10)*1.65+
      coalesce(pa.volley,10)*.45+
      coalesce(pa.net_positioning,10)*.55+
      coalesce(pa.doubles_communication,10)*.50+
      coalesce(pa.big_points,10)*.30+
      coalesce(p.form,70)*.08 as dscore
    from public.laver_cup_rosters r
    join public.players p on p.id=r.player_id
    left join public.player_attributes pa on pa.player_id=p.id
    where r.tournament_id=t.id and r.team_code='WORLD'
  ) x;

  delete from public.laver_cup_matches where tournament_id=t.id;

  -- Friday: slots 4-6 each play their mandatory first singles, then doubles.
  for i in 1..3 loop
    mn:=mn+1;
    r:=public.laver_play_singles(
      t.id,mn,1,e[e1[i]],w[w1[i]],1,t.start_date
    );
    if r->>'winner_team'='EUROPE' then ep:=ep+1; else wp:=wp+1; end if;
  end loop;

  mn:=mn+1;
  r:=public.laver_play_doubles(
    t.id,mn,1,ed[1],ed[2],wd[1],wd[2],1,t.start_date,false
  );
  if r->>'winner_team'='EUROPE' then ep:=ep+1; else wp:=wp+1; end if;

  -- Saturday: slots 1-3 complete the mandatory six singles appearances.
  for i in 1..3 loop
    mn:=mn+1;
    r:=public.laver_play_singles(
      t.id,mn,2,e[e2[i]],w[w2[i]],2,t.start_date+1
    );
    if r->>'winner_team'='EUROPE' then ep:=ep+2; else wp:=wp+2; end if;
  end loop;

  -- Second doubles pair uses two players who did not play Friday doubles,
  -- guaranteeing at least four doubles participants per team.
  mn:=mn+1;
  r:=public.laver_play_doubles(
    t.id,mn,2,ed[3],ed[4],wd[3],wd[4],2,t.start_date+1,false
  );
  if r->>'winner_team'='EUROPE' then ep:=ep+2; else wp:=wp+2; end if;

  -- Sunday always starts with doubles. Pair is new, individuals may return.
  mn:=mn+1;
  r:=public.laver_play_doubles(
    t.id,mn,3,ed[1],ed[3],wd[1],wd[3],3,t.start_date+2,false
  );
  if r->>'winner_team'='EUROPE' then ep:=ep+3; else wp:=wp+3; end if;

  -- Singles 10-12 are played only while neither team has reached 13.
  if ep<13 and wp<13 then
    for i in 1..3 loop
      exit when ep>=13 or wp>=13;
      mn:=mn+1;
      r:=public.laver_play_singles(
        t.id,mn,3,e[e3[i]],w[w3[i]],3,t.start_date+2
      );
      if r->>'winner_team'='EUROPE' then ep:=ep+3; else wp:=wp+3; end if;
    end loop;
  end if;

  -- If all twelve scheduled matches leave the contest 12-12, play the Decider.
  if ep=12 and wp=12 then
    decider:=true;
    mn:=13;
    r:=public.laver_play_doubles(
      t.id,mn,3,ed[1],ed[2],wd[1],wd[2],1,t.start_date+2,true
    );
    if r->>'winner_team'='EUROPE' then ep:=ep+1; else wp:=wp+1; end if;
  end if;

  winner:=case when ep>wp then 'EUROPE' else 'WORLD' end;

  insert into public.laver_cup_history(
    tournament_id,season,winner_team,europe_points,world_points,
    decider_played,completed_on,source_label
  ) values(
    t.id,extract(year from t.start_date)::int,winner,ep,wp,
    decider,coalesce(t.end_date,t.start_date+2),
    'Court Boss Laver Cup · official 2026 1/2/3 points + participation constraints'
  );

  -- Team title, no ATP ranking points.
  for rec in
    select r.player_id
    from public.laver_cup_rosters r
    where r.tournament_id=t.id and r.team_code=winner
  loop
    insert into public.player_titles(
      player_id,tournament_name,title_date,level,surface,event_type,
      verified,source_label,origin
    ) values(
      rec.player_id,t.name,coalesce(t.end_date,t.start_date+2),
      'Laver Cup',t.surface,'team_laver',
      false,'Court Boss simulated Laver Cup','game'
    )
    on conflict(player_id,tournament_name,title_date,event_type) do nothing;
  end loop;

  return jsonb_build_object(
    'events_simulated',1,'tournament_id',t.id,
    'winner_team',winner,'europe_points',ep,'world_points',wp,
    'matches_played',mn,'decider_played',decider,
    'preparation',prep,'availability',availability,
    'model','Laver Cup v1 · 6v6 · mandatory singles · 4+ doubles players · first to 13'
  );
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
    from public.junior_doubles_reservations dr
    join public.tournaments t on t.id=dr.tournament_id
    where p_player_id in (dr.player_a_id,dr.player_b_id)
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
    from public.laver_cup_rosters lr
    join public.tournaments lt on lt.id=lr.tournament_id
    where lr.player_id=p_player_id
      and lt.id is distinct from p_exclude_tournament_id
      and daterange(lt.start_date,coalesce(lt.end_date,lt.start_date),'[]')
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
    select ot.id,ot.name,ot.start_date,ot.end_date,'junior_doubles_reserved'
    from public.junior_doubles_reservations dr
    join public.tournaments ot on ot.id=dr.tournament_id
    where p_player_id in (dr.player_a_id,dr.player_b_id)
      and ot.id<>t.id
      and daterange(ot.start_date,coalesce(ot.end_date,ot.start_date),'[]')
          && daterange(commit_start,commit_end,'[]')

    union all
    select lt.id,lt.name,lt.start_date,lt.end_date,'laver_cup'
    from public.laver_cup_rosters lr
    join public.tournaments lt on lt.id=lr.tournament_id
    where lr.player_id=p_player_id
      and lt.id<>t.id
      and daterange(lt.start_date,coalesce(lt.end_date,lt.start_date),'[]')
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
    from public.laver_cup_matches lm
    where lm.played_on between p_date-13 and p_date
      and (
        p_player_id=any(lm.europe_player_ids)
        or p_player_id=any(lm.world_player_ids)
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
        from public.junior_doubles_reservations dr
        join public.tournaments et on et.id=dr.tournament_id
        where p.id in (dr.player_a_id,dr.player_b_id)
          and daterange(et.start_date,coalesce(et.end_date,et.start_date),'[]')
              && daterange(p_date,p_date,'[]')
      )

      and not exists(
        select 1
        from public.laver_cup_rosters lr
        join public.tournaments lt on lt.id=lr.tournament_id
        where lr.player_id=p.id
          and p_date between lt.start_date and coalesce(lt.end_date,lt.start_date)
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
        from public.junior_entry_reservations jr
        join public.tournaments et on et.id=jr.tournament_id
        where jr.player_id=p.id
          and daterange(et.start_date,coalesce(et.end_date,et.start_date),'[]')
              && daterange(p_date,p_date,'[]')
      )

      and not exists(
        select 1
        from public.junior_doubles_reservations dr
        join public.tournaments et on et.id=dr.tournament_id
        where p.id in (dr.player_a_id,dr.player_b_id)
          and daterange(et.start_date,coalesce(et.end_date,et.start_date),'[]')
              && daterange(p_date,p_date,'[]')
      )

      and not exists(
        select 1
        from public.laver_cup_rosters lr
        join public.tournaments lt on lt.id=lr.tournament_id
        where lr.player_id=p.id
          and p_date between lt.start_date and coalesce(lt.end_date,lt.start_date)
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
    from public.players p
    join public.ncaa_team_event_entries te on te.team_id=p.ncaa_team_id
    join public.tournaments et on et.id=te.tournament_id
    where p.id=p_player_id
      and et.id<>t.id
      and daterange(et.start_date,coalesce(et.end_date,et.start_date),'[]')
          && daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
  ) then return false; end if;

  if exists(
    select 1
    from public.junior_entry_reservations jr
    join public.tournaments jt on jt.id=jr.tournament_id
    where jr.player_id=p_player_id
      and jt.id<>t.id
      and daterange(jt.start_date,coalesce(jt.end_date,jt.start_date),'[]')
          && daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
  ) then return false; end if;

  if exists(
    select 1
    from public.junior_doubles_reservations dr
    join public.tournaments dt on dt.id=dr.tournament_id
    where p_player_id in (dr.player_a_id,dr.player_b_id)
      and dt.id<>t.id
      and daterange(dt.start_date,coalesce(dt.end_date,dt.start_date),'[]')
          && daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
  ) then return false; end if;

  if exists(
    select 1
    from public.laver_cup_rosters lr
    join public.tournaments lt on lt.id=lr.tournament_id
    where lr.player_id=p_player_id
      and lt.id<>t.id
      and daterange(lt.start_date,coalesce(lt.end_date,lt.start_date),'[]')
          && daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
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

  return true;
end;
$function$;

