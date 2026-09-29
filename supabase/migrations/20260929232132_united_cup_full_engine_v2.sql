-- Court Boss United Cup full season engine v2
-- 2026 format: 18 countries, 3 rubbers per tie, group stage + 8-team knockout.
-- Men singles feeds ATP H2H/Elo/ranking ledger; women remains in external WTA layer.
-- Mixed doubles is always played and uses the strongest available doubles profiles.

create table if not exists public.united_cup_standings(
  tournament_id bigint not null references public.tournaments(id) on delete cascade,
  country text not null,
  group_name text not null,
  city text not null,
  ties_played integer not null default 0,
  tie_wins integer not null default 0,
  tie_losses integer not null default 0,
  matches_played integer not null default 0,
  match_wins integer not null default 0,
  match_losses integer not null default 0,
  match_win_pct numeric not null default 0,
  sets_won integer not null default 0,
  sets_lost integer not null default 0,
  set_win_pct numeric not null default 0,
  games_won integer not null default 0,
  games_lost integer not null default 0,
  game_win_pct numeric not null default 0,
  group_rank integer,
  qualified_as text,
  snapshot_date date,
  source_label text not null default 'Court Boss United Cup standings v1',
  primary key(tournament_id,country)
);

alter table public.united_cup_standings enable row level security;

create index if not exists united_cup_standings_group_idx
  on public.united_cup_standings(tournament_id,city,group_name,group_rank);

create index if not exists united_cup_atp_rosters_initial_player_idx
  on public.united_cup_atp_rosters(initial_player_id,tournament_id)
  where initial_player_id is not null;

create index if not exists united_cup_rubbers_male_a_idx
  on public.united_cup_rubbers(nation_a_male_id,tie_id)
  where nation_a_male_id is not null;

create index if not exists united_cup_rubbers_male_b_idx
  on public.united_cup_rubbers(nation_b_male_id,tie_id)
  where nation_b_male_id is not null;

CREATE OR REPLACE FUNCTION public.united_cup_pick_atp_mixed_player(p_tournament_id bigint, p_country text, p_date date)
 RETURNS bigint
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  v_player bigint;
begin
  select x.player_id
  into v_player
  from (
    select distinct on (r.player_id)
      r.player_id,
      (
        coalesce(pa.doubles,10)*1.85
        + coalesce(p.current_ability,50)*.38
        + greatest(0,260-coalesce(p.doubles_ranking,r.entry_doubles_rank,260))*.075
        + case when r.role='doubles' then 12 else 0 end
        - coalesce(p.fatigue,20)*.32
        + coalesce(p.form,70)*.06
      ) score
    from public.united_cup_atp_rosters r
    join public.players p on p.id=r.player_id
    left join public.player_attributes pa on pa.player_id=p.id
    where r.tournament_id=p_tournament_id
      and r.country=p_country
      and p.career_status='active'
      and p.injury_status='Fit'
      and coalesce(p.fitness,90)>=45
      and coalesce(p.fatigue,20)<=94
      and coalesce(p.career_focus,'mixed')<>'singles_only'
      and not public.player_has_world_event_in_week(
        p.id,date_trunc('week',p_date::timestamp)::date,p_tournament_id
      )
    order by r.player_id,
      (
        coalesce(pa.doubles,10)*1.85
        + coalesce(p.current_ability,50)*.38
        + greatest(0,260-coalesce(p.doubles_ranking,r.entry_doubles_rank,260))*.075
        + case when r.role='doubles' then 12 else 0 end
        - coalesce(p.fatigue,20)*.32
        + coalesce(p.form,70)*.06
      ) desc
  ) x
  order by x.score desc,x.player_id
  limit 1;

  if v_player is not null then
    return v_player;
  end if;

  v_player:=public.united_cup_pick_atp_player(
    p_tournament_id,p_country,'doubles',p_date
  );

  if v_player is null then
    v_player:=public.united_cup_pick_atp_player(
      p_tournament_id,p_country,'singles1',p_date
    );
  end if;

  return v_player;
end;
$function$;

CREATE OR REPLACE FUNCTION public.united_cup_pick_wta_mixed_player(p_tournament_id bigint, p_country text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  with grouped as (
    select
      player_name,
      max(doubles_strength) doubles_strength,
      max(singles_strength) singles_strength,
      max(fatigue) fatigue,
      bool_or(role='doubles') has_doubles_role,
      min(coalesce(entry_doubles_rank,999999)) entry_doubles_rank
    from public.united_cup_wta_rosters
    where tournament_id=p_tournament_id
      and country=p_country
    group by player_name
  ),
  ranked as (
    select *,
      (
        doubles_strength*1.15
        + case when has_doubles_role then 10 else 0 end
        + greatest(0,250-entry_doubles_rank)*.055
        + singles_strength*.08
        - fatigue*.28
      ) selection_score
    from grouped
    where fatigue<=94
    order by selection_score desc,player_name
    limit 1
  )
  select coalesce(
    (
      select jsonb_build_object(
        'player_name',player_name,
        'doubles_strength',doubles_strength,
        'singles_strength',singles_strength,
        'fatigue',fatigue,
        'selection_score',round(selection_score,3),
        'specialist',has_doubles_role
      )
      from ranked
    ),
    '{}'::jsonb
  );
$function$;

CREATE OR REPLACE FUNCTION public.refresh_united_cup_atp_player_stats(p_tournament_id bigint, p_player_id bigint, p_as_of_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  v_singles_wins int:=0;
  v_mixed_wins int:=0;
  v_points int:=0;
  v_managed bigint;
  v_earned date:=coalesce(p_as_of_date,current_date);
  v_label text:='United Cup · ATP singles points';
begin
  select managed_player_id into v_managed
  from public.career_state
  where id='demo';

  select
    count(*) filter(
      where r.rubber_type='men_singles'
        and (
          (r.nation_a_male_id=p_player_id and r.winner_nation=t.nation_a)
          or
          (r.nation_b_male_id=p_player_id and r.winner_nation=t.nation_b)
        )
    )::int,
    count(*) filter(
      where r.rubber_type='mixed_doubles'
        and (
          (r.nation_a_male_id=p_player_id and r.winner_nation=t.nation_a)
          or
          (r.nation_b_male_id=p_player_id and r.winner_nation=t.nation_b)
        )
    )::int,
    coalesce(sum(
      case
        when r.rubber_type='men_singles'
         and (
          (r.nation_a_male_id=p_player_id and r.winner_nation=t.nation_a)
          or
          (r.nation_b_male_id=p_player_id and r.winner_nation=t.nation_b)
         )
        then r.atp_points_awarded
        else 0
      end
    ),0)::int
  into v_singles_wins,v_mixed_wins,v_points
  from public.united_cup_rubbers r
  join public.united_cup_ties t on t.id=r.tie_id
  where t.tournament_id=p_tournament_id;

  update public.united_cup_atp_rosters
  set singles_wins=v_singles_wins,
      mixed_wins=v_mixed_wins,
      atp_points_earned=v_points
  where tournament_id=p_tournament_id
    and player_id=p_player_id;

  if p_player_id=v_managed then
    delete from public.user_ranking_points
    where owner_id='demo'
      and tournament_id=p_tournament_id
      and label=v_label;

    if v_points>0 then
      insert into public.user_ranking_points(
        owner_id,tournament_id,label,earned_date,expiry_date,points,active
      ) values(
        'demo',p_tournament_id,v_label,v_earned,v_earned+364,v_points,true
      );
    end if;
  else
    if v_points>0 then
      insert into public.world_ranking_points(
        player_id,tournament_id,label,earned_date,expiry_date,points,active,source_label
      ) values(
        p_player_id,p_tournament_id,v_label,v_earned,v_earned+364,v_points,true,
        'Court Boss United Cup 2026 · cumulative ATP singles wins'
      )
      on conflict(player_id,tournament_id) do update set
        label=excluded.label,
        earned_date=excluded.earned_date,
        expiry_date=excluded.expiry_date,
        points=excluded.points,
        active=true,
        source_label=excluded.source_label;
    else
      delete from public.world_ranking_points
      where player_id=p_player_id
        and tournament_id=p_tournament_id
        and source_label like 'Court Boss United Cup%';
    end if;
  end if;

  return jsonb_build_object(
    'player_id',p_player_id,
    'singles_wins',v_singles_wins,
    'mixed_wins',v_mixed_wins,
    'atp_points',v_points,
    'ledger',case when p_player_id=v_managed then 'user' else 'world' end
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.refresh_united_cup_wta_player_stats(p_tournament_id bigint, p_player_name text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  v_singles_wins int:=0;
  v_mixed_wins int:=0;
  v_knockout_win boolean:=false;
  v_points int:=0;
begin
  select
    count(*) filter(
      where r.rubber_type='women_singles'
        and (
          (r.nation_a_wta_name=p_player_name and r.winner_nation=t.nation_a)
          or
          (r.nation_b_wta_name=p_player_name and r.winner_nation=t.nation_b)
        )
    )::int,
    count(*) filter(
      where r.rubber_type='mixed_doubles'
        and (
          (r.nation_a_wta_name=p_player_name and r.winner_nation=t.nation_a)
          or
          (r.nation_b_wta_name=p_player_name and r.winner_nation=t.nation_b)
        )
    )::int,
    coalesce(bool_or(
      r.rubber_type='women_singles'
      and upper(t.stage) in ('QF','SF','F')
      and (
        (r.nation_a_wta_name=p_player_name and r.winner_nation=t.nation_a)
        or
        (r.nation_b_wta_name=p_player_name and r.winner_nation=t.nation_b)
      )
    ),false)
  into v_singles_wins,v_mixed_wins,v_knockout_win
  from public.united_cup_rubbers r
  join public.united_cup_ties t on t.id=r.tie_id
  where t.tournament_id=p_tournament_id;

  v_points:=public.united_cup_wta_points(v_singles_wins,v_knockout_win);

  update public.united_cup_wta_rosters
  set singles_wins=v_singles_wins,
      mixed_wins=v_mixed_wins,
      wta_points_earned=v_points
  where tournament_id=p_tournament_id
    and player_name=p_player_name;

  return jsonb_build_object(
    'player_name',p_player_name,
    'singles_wins',v_singles_wins,
    'mixed_wins',v_mixed_wins,
    'knockout_win',v_knockout_win,
    'wta_points',v_points,
    'layer','external_wta'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.simulate_united_cup_tie(p_tie_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.united_cup_ties%rowtype;
  event public.tournaments%rowtype;
  a_men bigint;
  b_men bigint;
  a_mix bigint;
  b_mix bigint;
  a_wta_name text;
  b_wta_name text;
  a_wta_mix text;
  b_wta_mix text;
  a_wta_strength numeric;
  b_wta_strength numeric;
  a_wta_doubles numeric;
  b_wta_doubles numeric;
  a_wta_fatigue int;
  b_wta_fatigue int;
  pa_doubles numeric;
  pb_doubles numeric;
  pa_ca numeric;
  pb_ca numeric;
  matchj jsonb;
  scorej jsonb;
  prob numeric;
  roll numeric;
  a_win boolean;
  pts int;
  opp_rank int;
  a_score int:=0;
  b_score int:=0;
  stage_key text;
  a_sets int;
  b_sets int;
  a_games int;
  b_games int;
  rub_a_sets int;
  rub_b_sets int;
  rub_a_games int;
  rub_b_games int;
begin
  select * into t
  from public.united_cup_ties
  where id=p_tie_id
  for update;

  if t.id is null then
    return jsonb_build_object('ok',false,'reason','tie_not_found');
  end if;

  if t.status='completed' then
    return jsonb_build_object(
      'ok',true,'already',true,'tie_id',t.id,
      'winner_nation',t.winner_nation,
      'score',t.nation_a_score||'-'||t.nation_b_score
    );
  end if;

  if t.nation_a is null or t.nation_b is null
     or t.nation_a ilike 'Winner %' or t.nation_b ilike 'Winner %'
     or t.nation_a ilike 'Best Runner%' or t.nation_b ilike 'Best Runner%' then
    return jsonb_build_object('ok',false,'reason','participants_not_ready','tie_id',t.id);
  end if;

  select * into event from public.tournaments where id=t.tournament_id;
  stage_key:=case
    when upper(t.stage) like 'QF%' then 'QF'
    when upper(t.stage) like 'SF%' then 'SF'
    when upper(t.stage) like 'F%' then 'F'
    else 'GROUP' end;

  a_men:=public.united_cup_pick_atp_player(t.tournament_id,t.nation_a,'singles1',t.tie_date);
  b_men:=public.united_cup_pick_atp_player(t.tournament_id,t.nation_b,'singles1',t.tie_date);

  if a_men is null or b_men is null then
    return jsonb_build_object('ok',false,'reason','missing_atp_singles_player','tie_id',t.id);
  end if;

  select player_name,singles_strength,fatigue
  into a_wta_name,a_wta_strength,a_wta_fatigue
  from public.united_cup_wta_rosters
  where tournament_id=t.tournament_id and country=t.nation_a and role='singles1';

  select player_name,singles_strength,fatigue
  into b_wta_name,b_wta_strength,b_wta_fatigue
  from public.united_cup_wta_rosters
  where tournament_id=t.tournament_id and country=t.nation_b and role='singles1';

  if a_wta_name is null or b_wta_name is null then
    return jsonb_build_object('ok',false,'reason','missing_wta_singles_player','tie_id',t.id);
  end if;

  delete from public.united_cup_rubbers where tie_id=t.id;

  -- Rubber 1: ATP singles.
  matchj:=public.player_matchup_probability_v4(
    a_men,b_men,coalesce(event.surface,'Dur'),t.tie_date,
    coalesce(event.court_speed,1.0),3
  );
  prob:=greatest(.03,least(.97,coalesce((matchj->>'player_a_probability')::numeric,.5)));
  roll:=mod(abs(hashtext('uc-men|'||t.id||'|'||a_men||'|'||b_men)),10000)/10000.0;
  a_win:=roll<prob;
  scorej:=public.united_cup_scoreline(a_win,prob,false);

  if a_win then
    a_score:=a_score+1;
    opp_rank:=coalesce(public.player_rank_at_date(b_men,date '2025-12-22'),(select ranking from public.players where id=b_men),999999);
    pts:=public.united_cup_atp_points(stage_key,opp_rank);
  else
    b_score:=b_score+1;
    opp_rank:=coalesce(public.player_rank_at_date(a_men,date '2025-12-22'),(select ranking from public.players where id=a_men),999999);
    pts:=public.united_cup_atp_points(stage_key,opp_rank);
  end if;

  insert into public.united_cup_rubbers(
    tie_id,rubber_no,rubber_type,
    nation_a_male_id,nation_b_male_id,
    nation_a_wta_name,nation_b_wta_name,
    winner_nation,score,nation_a_win_probability,
    a_sets,b_sets,a_games,b_games,
    atp_points_awarded,played_on,model_version
  ) values(
    t.id,1,'men_singles',
    a_men,b_men,null,null,
    case when a_win then t.nation_a else t.nation_b end,
    scorej->>'score',round(prob,4),
    (scorej->>'a_sets')::int,(scorej->>'b_sets')::int,
    (scorej->>'a_games')::int,(scorej->>'b_games')::int,
    pts,t.tie_date,'CB-UNITED-CUP-v2'
  );

  perform public.update_h2h_after_match(
    case when a_win then a_men else b_men end,
    case when a_win then b_men else a_men end,
    coalesce(event.surface,'Dur'),t.tie_date,false,
    'United Cup · '||stage_key
  );
  perform public.update_player_elo_after_match(
    case when a_win then a_men else b_men end,
    case when a_win then b_men else a_men end,
    coalesce(event.surface,'Dur'),t.tie_date,false,
    case stage_key when 'F' then 1.12 when 'SF' then 1.08 when 'QF' then 1.05 else 1.02 end
  );

  update public.players
  set fatigue=least(100,coalesce(fatigue,20)+3),
      fitness=greatest(35,coalesce(fitness,90)-1),
      form=greatest(1,least(100,coalesce(form,70)+case
        when id=case when a_win then a_men else b_men end then 1
        else -1 end))
  where id in (a_men,b_men);

  -- Rubber 2: WTA singles, using official entry strength snapshot only.
  prob:=greatest(.04,least(.96,
    1/(1+exp(-(
      (coalesce(a_wta_strength,60)-coalesce(b_wta_strength,60))
      -(coalesce(a_wta_fatigue,10)-coalesce(b_wta_fatigue,10))*.10
    )/7.5))
  ));
  roll:=mod(abs(hashtext('uc-wta|'||t.id||'|'||a_wta_name||'|'||b_wta_name)),10000)/10000.0;
  a_win:=roll<prob;
  scorej:=public.united_cup_scoreline(a_win,prob,false);

  if a_win then a_score:=a_score+1; else b_score:=b_score+1; end if;

  insert into public.united_cup_rubbers(
    tie_id,rubber_no,rubber_type,
    nation_a_male_id,nation_b_male_id,
    nation_a_wta_name,nation_b_wta_name,
    winner_nation,score,nation_a_win_probability,
    a_sets,b_sets,a_games,b_games,
    atp_points_awarded,played_on,model_version
  ) values(
    t.id,2,'women_singles',
    null,null,a_wta_name,b_wta_name,
    case when a_win then t.nation_a else t.nation_b end,
    scorej->>'score',round(prob,4),
    (scorej->>'a_sets')::int,(scorej->>'b_sets')::int,
    (scorej->>'a_games')::int,(scorej->>'b_games')::int,
    0,t.tie_date,'CB-UNITED-CUP-v2'
  );

  update public.united_cup_wta_rosters
  set fatigue=least(100,coalesce(fatigue,10)+3)
  where tournament_id=t.tournament_id
    and (
      (country=t.nation_a and player_name=a_wta_name)
      or (country=t.nation_b and player_name=b_wta_name)
    );

  -- Rubber 3: mixed doubles. Pick the strongest available doubles profiles
  -- from the whole submitted team, not only the row labelled "doubles".
  a_mix:=coalesce(
    public.united_cup_pick_atp_mixed_player(t.tournament_id,t.nation_a,t.tie_date),
    a_men
  );
  b_mix:=coalesce(
    public.united_cup_pick_atp_mixed_player(t.tournament_id,t.nation_b,t.tie_date),
    b_men
  );

  matchj:=public.united_cup_pick_wta_mixed_player(t.tournament_id,t.nation_a);
  a_wta_mix:=nullif(matchj->>'player_name','');
  a_wta_doubles:=nullif(matchj->>'doubles_strength','')::numeric;

  matchj:=public.united_cup_pick_wta_mixed_player(t.tournament_id,t.nation_b);
  b_wta_mix:=nullif(matchj->>'player_name','');
  b_wta_doubles:=nullif(matchj->>'doubles_strength','')::numeric;

  a_wta_mix:=coalesce(a_wta_mix,a_wta_name);
  b_wta_mix:=coalesce(b_wta_mix,b_wta_name);
  a_wta_doubles:=coalesce(a_wta_doubles,a_wta_strength*.88);
  b_wta_doubles:=coalesce(b_wta_doubles,b_wta_strength*.88);

  select coalesce(p.current_ability,50),coalesce(pa.doubles,10)
  into pa_ca,pa_doubles
  from public.players p
  left join public.player_attributes pa on pa.player_id=p.id
  where p.id=a_mix;

  select coalesce(p.current_ability,50),coalesce(pa.doubles,10)
  into pb_ca,pb_doubles
  from public.players p
  left join public.player_attributes pa on pa.player_id=p.id
  where p.id=b_mix;

  prob:=greatest(.05,least(.95,
    1/(1+exp(-(
      (
        coalesce(pa_ca,50)*.38+
        coalesce(pa_doubles,10)*1.35+
        coalesce(a_wta_doubles,60)*.80
      )-
      (
        coalesce(pb_ca,50)*.38+
        coalesce(pb_doubles,10)*1.35+
        coalesce(b_wta_doubles,60)*.80
      )
    )/8.5))
  ));

  roll:=mod(abs(hashtext(
    'uc-mixed|'||t.id||'|'||a_mix||'|'||a_wta_mix||'|'||b_mix||'|'||b_wta_mix
  )),10000)/10000.0;
  a_win:=roll<prob;
  scorej:=public.united_cup_scoreline(a_win,prob,true);

  if a_win then a_score:=a_score+1; else b_score:=b_score+1; end if;

  insert into public.united_cup_rubbers(
    tie_id,rubber_no,rubber_type,
    nation_a_male_id,nation_b_male_id,
    nation_a_wta_name,nation_b_wta_name,
    winner_nation,score,nation_a_win_probability,
    a_sets,b_sets,a_games,b_games,
    atp_points_awarded,played_on,model_version
  ) values(
    t.id,3,'mixed_doubles',
    a_mix,b_mix,a_wta_mix,b_wta_mix,
    case when a_win then t.nation_a else t.nation_b end,
    scorej->>'score',round(prob,4),
    (scorej->>'a_sets')::int,(scorej->>'b_sets')::int,
    (scorej->>'a_games')::int,(scorej->>'b_games')::int,
    0,t.tie_date,'CB-UNITED-CUP-v2'
  );

  update public.players
  set fatigue=least(100,coalesce(fatigue,20)+2)
  where id in (a_mix,b_mix);

  update public.united_cup_wta_rosters
  set fatigue=least(100,coalesce(fatigue,10)+2)
  where tournament_id=t.tournament_id
    and (
      (country=t.nation_a and player_name=a_wta_mix)
      or (country=t.nation_b and player_name=b_wta_mix)
    );

  select
    coalesce(sum(case when ur.winner_nation=t.nation_a then 1 else 0 end),0),
    coalesce(sum(case when ur.winner_nation=t.nation_b then 1 else 0 end),0),
    coalesce(sum(ur.a_sets),0),coalesce(sum(ur.b_sets),0),
    coalesce(sum(ur.a_games),0),coalesce(sum(ur.b_games),0)
  into a_score,b_score,a_sets,b_sets,a_games,b_games
  from public.united_cup_rubbers ur
  where ur.tie_id=t.id;

  update public.united_cup_ties
  set nation_a_score=a_score,
      nation_b_score=b_score,
      winner_nation=case when a_score>b_score then nation_a else nation_b end,
      loser_nation=case when a_score>b_score then nation_b else nation_a end,
      status='completed',
      set_pct_a=round(a_sets::numeric/nullif(a_sets+b_sets,0),5),
      set_pct_b=round(b_sets::numeric/nullif(a_sets+b_sets,0),5),
      game_pct_a=round(a_games::numeric/nullif(a_games+b_games,0),5),
      game_pct_b=round(b_games::numeric/nullif(a_games+b_games,0),5),
      model_version='CB-UNITED-CUP-v2'
  where id=t.id;

  -- Rebuild cumulative event stats from rubbers. This is idempotent:
  -- re-evaluating a save never double-counts ranking points or wins.
  perform public.refresh_united_cup_atp_player_stats(
    t.tournament_id,a_men,t.tie_date
  );
  perform public.refresh_united_cup_atp_player_stats(
    t.tournament_id,b_men,t.tie_date
  );
  if a_mix is distinct from a_men then
    perform public.refresh_united_cup_atp_player_stats(
      t.tournament_id,a_mix,t.tie_date
    );
  end if;
  if b_mix is distinct from b_men then
    perform public.refresh_united_cup_atp_player_stats(
      t.tournament_id,b_mix,t.tie_date
    );
  end if;

  perform public.refresh_united_cup_wta_player_stats(
    t.tournament_id,a_wta_name
  );
  perform public.refresh_united_cup_wta_player_stats(
    t.tournament_id,b_wta_name
  );
  if a_wta_mix is distinct from a_wta_name then
    perform public.refresh_united_cup_wta_player_stats(
      t.tournament_id,a_wta_mix
    );
  end if;
  if b_wta_mix is distinct from b_wta_name then
    perform public.refresh_united_cup_wta_player_stats(
      t.tournament_id,b_wta_mix
    );
  end if;

  return jsonb_build_object(
    'ok',true,'tie_id',t.id,'stage',t.stage,
    'nation_a',t.nation_a,'nation_b',t.nation_b,
    'score',a_score||'-'||b_score,
    'winner',case when a_score>b_score then t.nation_a else t.nation_b end,
    'rubbers',3
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.united_cup_group_standings(p_tournament_id bigint)
 RETURNS TABLE(city text, group_name text, country text, ties_played integer, ties_won integer, matches_won integer, matches_lost integer, match_pct numeric, sets_won integer, sets_lost integer, set_pct numeric, games_won integer, games_lost integer, game_pct numeric, group_rank integer)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  with per_team_tie as (
    select
      t.city,t.group_name,t.nation_a as country,
      1::int ties_played,
      (t.winner_nation=t.nation_a)::int ties_won,
      coalesce(t.nation_a_score,0)::int matches_won,
      coalesce(t.nation_b_score,0)::int matches_lost,
      coalesce(sum(r.a_sets),0)::int sets_won,
      coalesce(sum(r.b_sets),0)::int sets_lost,
      coalesce(sum(r.a_games),0)::int games_won,
      coalesce(sum(r.b_games),0)::int games_lost
    from public.united_cup_ties t
    left join public.united_cup_rubbers r on r.tie_id=t.id
    where t.tournament_id=p_tournament_id
      and t.stage='Group'
      and t.status='completed'
    group by t.id

    union all

    select
      t.city,t.group_name,t.nation_b as country,
      1::int,
      (t.winner_nation=t.nation_b)::int,
      coalesce(t.nation_b_score,0)::int,
      coalesce(t.nation_a_score,0)::int,
      coalesce(sum(r.b_sets),0)::int,
      coalesce(sum(r.a_sets),0)::int,
      coalesce(sum(r.b_games),0)::int,
      coalesce(sum(r.a_games),0)::int
    from public.united_cup_ties t
    left join public.united_cup_rubbers r on r.tie_id=t.id
    where t.tournament_id=p_tournament_id
      and t.stage='Group'
      and t.status='completed'
    group by t.id
  ),
  agg as (
    select
      u.city,u.group_name,u.country,
      sum(u.ties_played)::int ties_played,
      sum(u.ties_won)::int ties_won,
      sum(u.matches_won)::int matches_won,
      sum(u.matches_lost)::int matches_lost,
      round(sum(u.matches_won)::numeric/nullif(sum(u.matches_won)+sum(u.matches_lost),0),6) match_pct,
      sum(u.sets_won)::int sets_won,
      sum(u.sets_lost)::int sets_lost,
      round(sum(u.sets_won)::numeric/nullif(sum(u.sets_won)+sum(u.sets_lost),0),6) set_pct,
      sum(u.games_won)::int games_won,
      sum(u.games_lost)::int games_lost,
      round(sum(u.games_won)::numeric/nullif(sum(u.games_won)+sum(u.games_lost),0),6) game_pct
    from per_team_tie u
    group by u.city,u.group_name,u.country
  ),
  all_teams as (
    select
      tm.city,tm.group_name,tm.country,
      coalesce(a.ties_played,0)::int ties_played,
      coalesce(a.ties_won,0)::int ties_won,
      coalesce(a.matches_won,0)::int matches_won,
      coalesce(a.matches_lost,0)::int matches_lost,
      coalesce(a.match_pct,0)::numeric match_pct,
      coalesce(a.sets_won,0)::int sets_won,
      coalesce(a.sets_lost,0)::int sets_lost,
      coalesce(a.set_pct,0)::numeric set_pct,
      coalesce(a.games_won,0)::int games_won,
      coalesce(a.games_lost,0)::int games_lost,
      coalesce(a.game_pct,0)::numeric game_pct
    from public.united_cup_teams tm
    left join agg a
      on a.city=tm.city
     and a.group_name=tm.group_name
     and a.country=tm.country
    where tm.tournament_id=p_tournament_id
  ),
  peers as (
    select a.*,
      count(*) over(
        partition by a.group_name,a.ties_won,a.ties_played
      )::int tied_teams
    from all_teams a
  ),
  h2h as (
    select p.*,
      case
        when p.tied_teams=2 and exists(
          select 1
          from public.united_cup_ties h
          join peers other
            on other.group_name=p.group_name
           and other.country<>p.country
           and other.ties_won=p.ties_won
           and other.ties_played=p.ties_played
          where h.tournament_id=p_tournament_id
            and h.stage='Group'
            and h.status='completed'
            and h.group_name=p.group_name
            and p.country in (h.nation_a,h.nation_b)
            and other.country in (h.nation_a,h.nation_b)
            and h.winner_nation=p.country
        ) then 1
        else 0
      end h2h_bonus
    from peers p
  )
  select
    a.city,a.group_name,a.country,
    a.ties_played,a.ties_won,
    a.matches_won,a.matches_lost,a.match_pct,
    a.sets_won,a.sets_lost,a.set_pct,
    a.games_won,a.games_lost,a.game_pct,
    row_number() over(
      partition by a.group_name
      order by
        a.ties_won desc,
        a.ties_played desc,
        case when a.tied_teams=2 then a.h2h_bonus else 0 end desc,
        a.matches_won desc,
        a.match_pct desc,
        a.set_pct desc,
        a.game_pct desc,
        public.united_cup_team_seed_score(p_tournament_id,a.country),
        a.country
    )::int group_rank
  from h2h a
  order by a.group_name,group_rank;
$function$;

CREATE OR REPLACE FUNCTION public.refresh_united_cup_group_standings(p_tournament_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  v_date date;
  v_count int:=0;
  v_perth_runner text;
  v_sydney_runner text;
begin
  select max(tie_date) into v_date
  from public.united_cup_ties
  where tournament_id=p_tournament_id
    and stage='Group'
    and status='completed';

  with raw as (
    select
      tm.tournament_id,
      tm.country,
      tm.group_name,
      tm.city,
      count(distinct t.id) filter(where t.status='completed')::int ties_played,
      count(distinct t.id) filter(where t.status='completed' and t.winner_nation=tm.country)::int tie_wins,
      count(distinct t.id) filter(where t.status='completed' and t.loser_nation=tm.country)::int tie_losses,
      count(r.id)::int matches_played,
      count(r.id) filter(where r.winner_nation=tm.country)::int match_wins,
      count(r.id) filter(where r.winner_nation<>tm.country)::int match_losses,
      coalesce(sum(
        case when t.nation_a=tm.country then r.a_sets
             when t.nation_b=tm.country then r.b_sets
             else 0 end
      ),0)::int sets_won,
      coalesce(sum(
        case when t.nation_a=tm.country then r.b_sets
             when t.nation_b=tm.country then r.a_sets
             else 0 end
      ),0)::int sets_lost,
      coalesce(sum(
        case when t.nation_a=tm.country then r.a_games
             when t.nation_b=tm.country then r.b_games
             else 0 end
      ),0)::int games_won,
      coalesce(sum(
        case when t.nation_a=tm.country then r.b_games
             when t.nation_b=tm.country then r.a_games
             else 0 end
      ),0)::int games_lost
    from public.united_cup_teams tm
    left join public.united_cup_ties t
      on t.tournament_id=tm.tournament_id
     and t.stage='Group'
     and tm.country in (t.nation_a,t.nation_b)
    left join public.united_cup_rubbers r on r.tie_id=t.id
    where tm.tournament_id=p_tournament_id
    group by tm.tournament_id,tm.country,tm.group_name,tm.city
  ),
  pct as (
    select raw.*,
      case when matches_played>0 then match_wins::numeric/matches_played else 0 end match_win_pct,
      case when sets_won+sets_lost>0 then sets_won::numeric/(sets_won+sets_lost) else 0 end set_win_pct,
      case when games_won+games_lost>0 then games_won::numeric/(games_won+games_lost) else 0 end game_win_pct,
      count(*) over(partition by tournament_id,group_name,tie_wins) peers_at_tie_wins
    from raw
  ),
  ranked as (
    select p.*,
      case
        when peers_at_tie_wins=2 and exists(
          select 1
          from public.united_cup_ties h
          where h.tournament_id=p.tournament_id
            and h.stage='Group'
            and h.status='completed'
            and h.winner_nation=p.country
            and h.group_name=p.group_name
            and exists(
              select 1 from pct p2
              where p2.tournament_id=p.tournament_id
                and p2.group_name=p.group_name
                and p2.country<>p.country
                and p2.tie_wins=p.tie_wins
                and p2.country in (h.nation_a,h.nation_b)
            )
        ) then 1 else 0
      end h2h_bonus
    from pct p
  ),
  final_rank as (
    select ranked.*,
      row_number() over(
        partition by tournament_id,group_name
        order by
          tie_wins desc,
          h2h_bonus desc,
          match_wins desc,
          match_win_pct desc,
          set_win_pct desc,
          game_win_pct desc,
          md5('uc-lot|'||tournament_id||'|'||group_name||'|'||country)
      )::int group_rank
    from ranked
  )
  insert into public.united_cup_standings(
    tournament_id,country,group_name,city,
    ties_played,tie_wins,tie_losses,
    matches_played,match_wins,match_losses,match_win_pct,
    sets_won,sets_lost,set_win_pct,
    games_won,games_lost,game_win_pct,
    group_rank,qualified_as,snapshot_date,source_label
  )
  select
    tournament_id,country,group_name,city,
    ties_played,tie_wins,tie_losses,
    matches_played,match_wins,match_losses,round(match_win_pct,5),
    sets_won,sets_lost,round(set_win_pct,5),
    games_won,games_lost,round(game_win_pct,5),
    group_rank,
    case when group_rank=1 then 'group_winner' else null end,
    v_date,
    'Court Boss United Cup 2026 standings · official tie-break hierarchy'
  from final_rank
  on conflict(tournament_id,country) do update set
    group_name=excluded.group_name,
    city=excluded.city,
    ties_played=excluded.ties_played,
    tie_wins=excluded.tie_wins,
    tie_losses=excluded.tie_losses,
    matches_played=excluded.matches_played,
    match_wins=excluded.match_wins,
    match_losses=excluded.match_losses,
    match_win_pct=excluded.match_win_pct,
    sets_won=excluded.sets_won,
    sets_lost=excluded.sets_lost,
    set_win_pct=excluded.set_win_pct,
    games_won=excluded.games_won,
    games_lost=excluded.games_lost,
    game_win_pct=excluded.game_win_pct,
    group_rank=excluded.group_rank,
    qualified_as=excluded.qualified_as,
    snapshot_date=excluded.snapshot_date,
    source_label=excluded.source_label;

  get diagnostics v_count=row_count;

  select country into v_perth_runner
  from public.united_cup_standings
  where tournament_id=p_tournament_id
    and city='Perth'
    and group_rank=2
  order by
    tie_wins desc,
    ties_played desc,
    match_wins desc,
    match_win_pct desc,
    set_win_pct desc,
    game_win_pct desc,
    md5('uc-runner-perth|'||country)
  limit 1;

  select country into v_sydney_runner
  from public.united_cup_standings
  where tournament_id=p_tournament_id
    and city='Sydney'
    and group_rank=2
  order by
    tie_wins desc,
    ties_played desc,
    match_wins desc,
    match_win_pct desc,
    set_win_pct desc,
    game_win_pct desc,
    md5('uc-runner-sydney|'||country)
  limit 1;

  update public.united_cup_standings
  set qualified_as=case
    when group_rank=1 then 'group_winner'
    when country=v_perth_runner then 'best_runner_up_perth'
    when country=v_sydney_runner then 'best_runner_up_sydney'
    else null end
  where tournament_id=p_tournament_id;

  return jsonb_build_object(
    'ok',true,
    'rows',v_count,
    'perth_best_runner_up',v_perth_runner,
    'sydney_best_runner_up',v_sydney_runner,
    'group_winners',(
      select jsonb_object_agg(group_name,country order by group_name)
      from public.united_cup_standings
      where tournament_id=p_tournament_id and group_rank=1
    )
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.united_cup_group_winner(p_tournament_id bigint, p_group text)
 RETURNS text
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  select country
  from public.united_cup_standings
  where tournament_id=p_tournament_id
    and group_name=p_group
    and group_rank=1
  limit 1;
$function$;

CREATE OR REPLACE FUNCTION public.united_cup_best_runner_up(p_tournament_id bigint, p_city text)
 RETURNS text
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  select country
  from public.united_cup_standings
  where tournament_id=p_tournament_id
    and city=p_city
    and qualified_as='best_runner_up_'||lower(p_city)
  limit 1;
$function$;

CREATE OR REPLACE FUNCTION public.prepare_united_cup_2026(p_tournament_id bigint DEFAULT 2078)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  if not exists(
    select 1 from public.tournaments
    where id=p_tournament_id and category='United Cup'
  ) then
    return jsonb_build_object('ok',false,'reason','united_cup_not_found');
  end if;

  insert into public.united_cup_ties(
    tournament_id,stage,group_name,city,bracket_slot,tie_date,
    nation_a,nation_b,nation_a_score,nation_b_score,
    winner_nation,loser_nation,status,model_version,source_label,event_key
  ) values
    (p_tournament_id,'Group','A','Perth',1,date '2026-01-02','ESP','ARG',null,null,null,null,'scheduled','CB-UNITED-CUP-v2','Official 2026 schedule known before career start','G-A-1'),
    (p_tournament_id,'Group','E','Perth',1,date '2026-01-02','GRE','JPN',null,null,null,null,'scheduled','CB-UNITED-CUP-v2','Official 2026 schedule known before career start','G-E-1'),
    (p_tournament_id,'Group','C','Perth',1,date '2026-01-03','FRA','SUI',null,null,null,null,'scheduled','CB-UNITED-CUP-v2','Official 2026 schedule known before career start','G-C-1'),
    (p_tournament_id,'Group','B','Sydney',1,date '2026-01-03','BEL','CHN',null,null,null,null,'scheduled','CB-UNITED-CUP-v2','Official 2026 schedule known before career start','G-B-1'),
    (p_tournament_id,'Group','A','Perth',2,date '2026-01-03','USA','ARG',null,null,null,null,'scheduled','CB-UNITED-CUP-v2','Official 2026 schedule known before career start','G-A-2'),
    (p_tournament_id,'Group','D','Sydney',1,date '2026-01-03','AUS','NOR',null,null,null,null,'scheduled','CB-UNITED-CUP-v2','Official 2026 schedule known before career start','G-D-1'),
    (p_tournament_id,'Group','E','Perth',2,date '2026-01-04','GBR','JPN',null,null,null,null,'scheduled','CB-UNITED-CUP-v2','Official 2026 schedule known before career start','G-E-2'),
    (p_tournament_id,'Group','F','Sydney',1,date '2026-01-04','GER','NED',null,null,null,null,'scheduled','CB-UNITED-CUP-v2','Official 2026 schedule known before career start','G-F-1'),
    (p_tournament_id,'Group','C','Perth',2,date '2026-01-04','ITA','SUI',null,null,null,null,'scheduled','CB-UNITED-CUP-v2','Official 2026 schedule known before career start','G-C-2'),
    (p_tournament_id,'Group','B','Sydney',2,date '2026-01-04','CAN','CHN',null,null,null,null,'scheduled','CB-UNITED-CUP-v2','Official 2026 schedule known before career start','G-B-2'),
    (p_tournament_id,'Group','A','Perth',3,date '2026-01-05','USA','ESP',null,null,null,null,'scheduled','CB-UNITED-CUP-v2','Official 2026 schedule known before career start','G-A-3'),
    (p_tournament_id,'Group','D','Sydney',2,date '2026-01-05','CZE','NOR',null,null,null,null,'scheduled','CB-UNITED-CUP-v2','Official 2026 schedule known before career start','G-D-2'),
    (p_tournament_id,'Group','E','Perth',3,date '2026-01-05','GBR','GRE',null,null,null,null,'scheduled','CB-UNITED-CUP-v2','Official 2026 schedule known before career start','G-E-3'),
    (p_tournament_id,'Group','F','Sydney',2,date '2026-01-05','GER','POL',null,null,null,null,'scheduled','CB-UNITED-CUP-v2','Official 2026 schedule known before career start','G-F-2'),
    (p_tournament_id,'Group','C','Perth',3,date '2026-01-06','ITA','FRA',null,null,null,null,'scheduled','CB-UNITED-CUP-v2','Official 2026 schedule known before career start','G-C-3'),
    (p_tournament_id,'Group','B','Sydney',3,date '2026-01-06','CAN','BEL',null,null,null,null,'scheduled','CB-UNITED-CUP-v2','Official 2026 schedule known before career start','G-B-3'),
    (p_tournament_id,'Group','D','Sydney',3,date '2026-01-06','AUS','CZE',null,null,null,null,'scheduled','CB-UNITED-CUP-v2','Official 2026 schedule known before career start','G-D-3'),
    (p_tournament_id,'Group','F','Sydney',3,date '2026-01-07','POL','NED',null,null,null,null,'scheduled','CB-UNITED-CUP-v2','Official 2026 schedule known before career start','G-F-3')
  on conflict(tournament_id,event_key) do update set
    stage=excluded.stage,
    group_name=excluded.group_name,
    city=excluded.city,
    bracket_slot=excluded.bracket_slot,
    tie_date=excluded.tie_date,
    nation_a=excluded.nation_a,
    nation_b=excluded.nation_b,
    source_label=excluded.source_label,
    model_version=excluded.model_version;

  return jsonb_build_object(
    'ok',true,
    'group_ties',(select count(*) from public.united_cup_ties where tournament_id=p_tournament_id and stage='Group'),
    'teams',(select count(*) from public.united_cup_teams where tournament_id=p_tournament_id),
    'atp_roster',(select count(*) from public.united_cup_atp_rosters where tournament_id=p_tournament_id),
    'wta_roster',(select count(*) from public.united_cup_wta_rosters where tournament_id=p_tournament_id),
    'completed',(select count(*) from public.united_cup_ties where tournament_id=p_tournament_id and status='completed')
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.prepare_united_cup_quarterfinals(p_tournament_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  a_w text; b_w text; c_w text; d_w text; e_w text; f_w text;
  perth_runner text; perth_runner_group text;
  sydney_runner text; sydney_runner_group text;
  weak_ce text;
  strong_ce text;
  weak_df text;
  strong_df text;
  qf1a text;qf1b text;qf2a text;qf2b text;
  qf3a text;qf3b text;qf4a text;qf4b text;
begin
  if (select count(*) from public.united_cup_ties
      where tournament_id=p_tournament_id and stage='Group' and status='completed')<>18 then
    return jsonb_build_object('ok',false,'reason','group_stage_incomplete');
  end if;

  perform public.refresh_united_cup_group_standings(p_tournament_id);

  a_w:=public.united_cup_group_winner(p_tournament_id,'A');
  b_w:=public.united_cup_group_winner(p_tournament_id,'B');
  c_w:=public.united_cup_group_winner(p_tournament_id,'C');
  d_w:=public.united_cup_group_winner(p_tournament_id,'D');
  e_w:=public.united_cup_group_winner(p_tournament_id,'E');
  f_w:=public.united_cup_group_winner(p_tournament_id,'F');

  perth_runner:=public.united_cup_best_runner_up(p_tournament_id,'Perth');
  select group_name into perth_runner_group
  from public.united_cup_standings
  where tournament_id=p_tournament_id and country=perth_runner;

  sydney_runner:=public.united_cup_best_runner_up(p_tournament_id,'Sydney');
  select group_name into sydney_runner_group
  from public.united_cup_standings
  where tournament_id=p_tournament_id and country=sydney_runner;

  -- Published base bracket:
  -- Perth QF1: Winner A vs best runner-up; QF2: Winner C vs Winner E.
  -- If the runner-up is from A, swap it with the weaker C/E group winner
  -- to prevent a group-stage rematch before the final.
  if public.united_cup_team_seed_score(p_tournament_id,c_w)
     >= public.united_cup_team_seed_score(p_tournament_id,e_w) then
    weak_ce:=c_w; strong_ce:=e_w;
  else
    weak_ce:=e_w; strong_ce:=c_w;
  end if;

  if perth_runner_group='A' then
    qf1a:=a_w; qf1b:=weak_ce;
    qf2a:=strong_ce; qf2b:=perth_runner;
  else
    qf1a:=a_w; qf1b:=perth_runner;
    qf2a:=c_w; qf2b:=e_w;
  end if;

  -- Sydney base bracket: Winner B vs best runner-up; Winner D vs Winner F.
  if public.united_cup_team_seed_score(p_tournament_id,d_w)
     >= public.united_cup_team_seed_score(p_tournament_id,f_w) then
    weak_df:=d_w; strong_df:=f_w;
  else
    weak_df:=f_w; strong_df:=d_w;
  end if;

  if sydney_runner_group='B' then
    qf3a:=b_w; qf3b:=weak_df;
    qf4a:=strong_df; qf4b:=sydney_runner;
  else
    qf3a:=b_w; qf3b:=sydney_runner;
    qf4a:=d_w; qf4b:=f_w;
  end if;

  insert into public.united_cup_ties(
    tournament_id,stage,group_name,city,bracket_slot,tie_date,
    nation_a,nation_b,status,model_version,source_label,event_key
  ) values
    (p_tournament_id,'QF',null,'Perth',1,date '2026-01-07',qf1a,qf1b,'scheduled','CB-UNITED-CUP-v2','Official 2026 bracket + anti-rematch rule','QF1'),
    (p_tournament_id,'QF',null,'Perth',2,date '2026-01-07',qf2a,qf2b,'scheduled','CB-UNITED-CUP-v2','Official 2026 bracket + anti-rematch rule','QF2'),
    (p_tournament_id,'QF',null,'Sydney',3,date '2026-01-08',qf3a,qf3b,'scheduled','CB-UNITED-CUP-v2','Official 2026 bracket + anti-rematch rule','QF3'),
    (p_tournament_id,'QF',null,'Sydney',4,date '2026-01-09',qf4a,qf4b,'scheduled','CB-UNITED-CUP-v2','Official 2026 bracket + anti-rematch rule','QF4')
  on conflict(tournament_id,event_key) do update set
    stage=excluded.stage,city=excluded.city,bracket_slot=excluded.bracket_slot,
    tie_date=excluded.tie_date,nation_a=excluded.nation_a,nation_b=excluded.nation_b,
    status=case when united_cup_ties.status='completed' then united_cup_ties.status else 'scheduled' end,
    model_version=excluded.model_version,source_label=excluded.source_label;

  return jsonb_build_object(
    'ok',true,
    'perth_runner',perth_runner,
    'sydney_runner',sydney_runner,
    'qf1',jsonb_build_array(qf1a,qf1b),
    'qf2',jsonb_build_array(qf2a,qf2b),
    'qf3',jsonb_build_array(qf3a,qf3b),
    'qf4',jsonb_build_array(qf4a,qf4b)
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.advance_united_cup_bracket(p_tournament_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  q1 text;q2 text;q3 text;q4 text;
  s1 text;s2 text;
  created_sf boolean:=false;
  created_f boolean:=false;
begin
  select winner_nation into q1 from public.united_cup_ties where tournament_id=p_tournament_id and event_key='QF1' and status='completed';
  select winner_nation into q2 from public.united_cup_ties where tournament_id=p_tournament_id and event_key='QF2' and status='completed';
  select winner_nation into q3 from public.united_cup_ties where tournament_id=p_tournament_id and event_key='QF3' and status='completed';
  select winner_nation into q4 from public.united_cup_ties where tournament_id=p_tournament_id and event_key='QF4' and status='completed';

  if q1 is not null and q2 is not null and q3 is not null and q4 is not null then
    insert into public.united_cup_ties(
      tournament_id,stage,city,bracket_slot,tie_date,
      nation_a,nation_b,status,model_version,source_label,event_key
    ) values
      (p_tournament_id,'SF','Sydney',1,date '2026-01-10',q2,q3,'scheduled','CB-UNITED-CUP-v2','Official 2026 SF1: Winner QF2 vs Winner QF3','SF1'),
      (p_tournament_id,'SF','Sydney',2,date '2026-01-10',q1,q4,'scheduled','CB-UNITED-CUP-v2','Official 2026 SF2: Winner QF1 vs Winner QF4','SF2')
    on conflict(tournament_id,event_key) do update set
      nation_a=excluded.nation_a,nation_b=excluded.nation_b,
      tie_date=excluded.tie_date,
      status=case when united_cup_ties.status='completed' then united_cup_ties.status else 'scheduled' end,
      source_label=excluded.source_label,model_version=excluded.model_version;
    created_sf:=true;
  end if;

  select winner_nation into s1 from public.united_cup_ties where tournament_id=p_tournament_id and event_key='SF1' and status='completed';
  select winner_nation into s2 from public.united_cup_ties where tournament_id=p_tournament_id and event_key='SF2' and status='completed';

  if s1 is not null and s2 is not null then
    insert into public.united_cup_ties(
      tournament_id,stage,city,bracket_slot,tie_date,
      nation_a,nation_b,status,model_version,source_label,event_key
    ) values(
      p_tournament_id,'F','Sydney',1,date '2026-01-11',
      s1,s2,'scheduled','CB-UNITED-CUP-v2','Official 2026 final','F'
    )
    on conflict(tournament_id,event_key) do update set
      nation_a=excluded.nation_a,nation_b=excluded.nation_b,
      tie_date=excluded.tie_date,
      status=case when united_cup_ties.status='completed' then united_cup_ties.status else 'scheduled' end,
      source_label=excluded.source_label,model_version=excluded.model_version;
    created_f:=true;
  end if;

  return jsonb_build_object('ok',true,'semifinals_ready',created_sf,'final_ready',created_f);
end;
$function$;

CREATE OR REPLACE FUNCTION public.recalculate_united_cup_stats(p_tournament_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  r record;
  v_singles_wins int;
  v_mixed_wins int;
  v_points int;
  v_team_prize numeric;
  v_singles_prize numeric;
  v_mixed_prize numeric;
  v_participation numeric;
  v_prize numeric;
  v_wta_wins int;
  v_wta_mixed int;
  v_wta_points int;
  v_has_knockout boolean;
begin
  for r in
    select *
    from public.united_cup_atp_rosters
    where tournament_id=p_tournament_id
  loop
    select
      count(*) filter(
        where ur.rubber_type='men_singles'
          and ur.winner_nation=r.country
          and (
            (ut.nation_a=r.country and ur.nation_a_male_id=r.player_id)
            or (ut.nation_b=r.country and ur.nation_b_male_id=r.player_id)
          )
      )::int,
      count(*) filter(
        where ur.rubber_type='mixed_doubles'
          and ur.winner_nation=r.country
          and (
            (ut.nation_a=r.country and ur.nation_a_male_id=r.player_id)
            or (ut.nation_b=r.country and ur.nation_b_male_id=r.player_id)
          )
      )::int,
      coalesce(sum(
        case
          when ur.rubber_type='men_singles'
           and ur.winner_nation=r.country
           and (
             (ut.nation_a=r.country and ur.nation_a_male_id=r.player_id)
             or (ut.nation_b=r.country and ur.nation_b_male_id=r.player_id)
           )
          then ur.atp_points_awarded
          else 0
        end
      ),0)::int
    into v_singles_wins,v_mixed_wins,v_points
    from public.united_cup_ties ut
    join public.united_cup_rubbers ur on ur.tie_id=ut.id
    where ut.tournament_id=p_tournament_id
      and ut.status='completed';

    select coalesce(sum(
      public.united_cup_prize_component(
        p_tournament_id,'team_win_per_player',
        case when upper(stage)='GROUP' then 'GROUP' else upper(stage) end
      )
    ),0)
    into v_team_prize
    from public.united_cup_ties
    where tournament_id=p_tournament_id
      and status='completed'
      and winner_nation=r.country;

    select coalesce(sum(
      public.united_cup_prize_component(
        p_tournament_id,'singles_match_win_no1',
        case when upper(ut.stage)='GROUP' then 'GROUP' else upper(ut.stage) end
      )
    ),0)
    into v_singles_prize
    from public.united_cup_ties ut
    join public.united_cup_rubbers ur on ur.tie_id=ut.id
    where ut.tournament_id=p_tournament_id
      and ut.status='completed'
      and ur.rubber_type='men_singles'
      and ur.winner_nation=r.country
      and (
        (ut.nation_a=r.country and ur.nation_a_male_id=r.player_id)
        or (ut.nation_b=r.country and ur.nation_b_male_id=r.player_id)
      );

    select coalesce(sum(
      public.united_cup_prize_component(
        p_tournament_id,'mixed_doubles_match_win',
        case when upper(ut.stage)='GROUP' then 'GROUP' else upper(ut.stage) end
      )
    ),0)
    into v_mixed_prize
    from public.united_cup_ties ut
    join public.united_cup_rubbers ur on ur.tie_id=ut.id
    where ut.tournament_id=p_tournament_id
      and ut.status='completed'
      and ur.rubber_type='mixed_doubles'
      and ur.winner_nation=r.country
      and (
        (ut.nation_a=r.country and ur.nation_a_male_id=r.player_id)
        or (ut.nation_b=r.country and ur.nation_b_male_id=r.player_id)
      );

    v_participation:=public.united_cup_participation_fee(
      coalesce(
        case when r.role='singles1' then r.entry_singles_rank else r.entry_doubles_rank end,
        r.entry_singles_rank,r.entry_doubles_rank,999999
      ),
      r.role
    );

    v_prize:=v_participation+v_team_prize+v_singles_prize+v_mixed_prize;

    update public.united_cup_atp_rosters
    set singles_wins=v_singles_wins,
        mixed_wins=v_mixed_wins,
        atp_points_earned=v_points,
        prize_earned=v_prize
    where tournament_id=p_tournament_id
      and country=r.country
      and role=r.role;
  end loop;

  for r in
    select *
    from public.united_cup_wta_rosters
    where tournament_id=p_tournament_id
  loop
    select
      count(*) filter(
        where ur.rubber_type='women_singles'
          and ur.winner_nation=r.country
          and (
            (ut.nation_a=r.country and ur.nation_a_wta_name=r.player_name)
            or (ut.nation_b=r.country and ur.nation_b_wta_name=r.player_name)
          )
      )::int,
      count(*) filter(
        where ur.rubber_type='mixed_doubles'
          and ur.winner_nation=r.country
          and (
            (ut.nation_a=r.country and ur.nation_a_wta_name=r.player_name)
            or (ut.nation_b=r.country and ur.nation_b_wta_name=r.player_name)
          )
      )::int,
      coalesce(bool_or(
        ur.rubber_type='women_singles'
        and ur.winner_nation=r.country
        and ut.stage<>'Group'
        and (
          (ut.nation_a=r.country and ur.nation_a_wta_name=r.player_name)
          or (ut.nation_b=r.country and ur.nation_b_wta_name=r.player_name)
        )
      ),false)
    into v_wta_wins,v_wta_mixed,v_has_knockout
    from public.united_cup_ties ut
    join public.united_cup_rubbers ur on ur.tie_id=ut.id
    where ut.tournament_id=p_tournament_id
      and ut.status='completed';

    v_wta_points:=case
      when r.role='singles1'
      then public.united_cup_wta_points(v_wta_wins,v_has_knockout)
      else 0
    end;

    select coalesce(sum(
      public.united_cup_prize_component(
        p_tournament_id,'team_win_per_player',
        case when upper(stage)='GROUP' then 'GROUP' else upper(stage) end
      )
    ),0)
    into v_team_prize
    from public.united_cup_ties
    where tournament_id=p_tournament_id
      and status='completed'
      and winner_nation=r.country;

    select coalesce(sum(
      public.united_cup_prize_component(
        p_tournament_id,'singles_match_win_no1',
        case when upper(ut.stage)='GROUP' then 'GROUP' else upper(ut.stage) end
      )
    ),0)
    into v_singles_prize
    from public.united_cup_ties ut
    join public.united_cup_rubbers ur on ur.tie_id=ut.id
    where ut.tournament_id=p_tournament_id
      and ut.status='completed'
      and ur.rubber_type='women_singles'
      and ur.winner_nation=r.country
      and (
        (ut.nation_a=r.country and ur.nation_a_wta_name=r.player_name)
        or (ut.nation_b=r.country and ur.nation_b_wta_name=r.player_name)
      );

    select coalesce(sum(
      public.united_cup_prize_component(
        p_tournament_id,'mixed_doubles_match_win',
        case when upper(ut.stage)='GROUP' then 'GROUP' else upper(ut.stage) end
      )
    ),0)
    into v_mixed_prize
    from public.united_cup_ties ut
    join public.united_cup_rubbers ur on ur.tie_id=ut.id
    where ut.tournament_id=p_tournament_id
      and ut.status='completed'
      and ur.rubber_type='mixed_doubles'
      and ur.winner_nation=r.country
      and (
        (ut.nation_a=r.country and ur.nation_a_wta_name=r.player_name)
        or (ut.nation_b=r.country and ur.nation_b_wta_name=r.player_name)
      );

    v_participation:=public.united_cup_participation_fee(
      coalesce(
        case when r.role='singles1' then r.entry_singles_rank else r.entry_doubles_rank end,
        r.entry_singles_rank,r.entry_doubles_rank,999999
      ),
      r.role
    );

    update public.united_cup_wta_rosters
    set singles_wins=v_wta_wins,
        mixed_wins=v_wta_mixed,
        wta_points_earned=v_wta_points,
        prize_earned=v_participation+v_team_prize+v_singles_prize+v_mixed_prize
    where tournament_id=p_tournament_id
      and country=r.country
      and role=r.role;
  end loop;

  -- ATP ranking points are rebuilt from completed men's singles rubbers.
  delete from public.world_ranking_points
  where tournament_id=p_tournament_id;

  insert into public.world_ranking_points(
    player_id,tournament_id,label,earned_date,expiry_date,points,active,source_label
  )
  select
    roster.player_id,p_tournament_id,
    'United Cup · total',
    t.end_date,t.end_date+364,
    roster.atp_points_earned,true,
    'Court Boss United Cup · official 2026 opponent-rank points table'
  from public.united_cup_atp_rosters roster
  join public.tournaments t on t.id=p_tournament_id
  where roster.tournament_id=p_tournament_id
    and roster.atp_points_earned>0
  on conflict(player_id,tournament_id) do update set
    label=excluded.label,
    earned_date=excluded.earned_date,
    expiry_date=excluded.expiry_date,
    points=excluded.points,
    active=true,
    source_label=excluded.source_label;

  return jsonb_build_object(
    'ok',true,
    'atp_points_total',(
      select coalesce(sum(atp_points_earned),0)
      from public.united_cup_atp_rosters
      where tournament_id=p_tournament_id
    ),
    'atp_max',(
      select coalesce(max(atp_points_earned),0)
      from public.united_cup_atp_rosters
      where tournament_id=p_tournament_id
    ),
    'wta_max',(
      select coalesce(max(wta_points_earned),0)
      from public.united_cup_wta_rosters
      where tournament_id=p_tournament_id
    ),
    'prize_total',(
      select
        coalesce((select sum(prize_earned) from public.united_cup_atp_rosters where tournament_id=p_tournament_id),0)
        +
        coalesce((select sum(prize_earned) from public.united_cup_wta_rosters where tournament_id=p_tournament_id),0)
    )
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.finalize_united_cup(p_tournament_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  champ text;
  runner text;
  final_score text;
  final_date date;
begin
  select
    winner_nation,
    loser_nation,
    case
      when winner_nation=nation_a then nation_a_score||'-'||nation_b_score
      else nation_b_score||'-'||nation_a_score
    end,
    tie_date
  into champ,runner,final_score,final_date
  from public.united_cup_ties
  where tournament_id=p_tournament_id
    and event_key='F'
    and status='completed';

  if champ is null then
    return jsonb_build_object('ok',false,'reason','final_not_complete');
  end if;

  insert into public.united_cup_history(
    tournament_id,season,champion_country,runner_up_country,final_score,completed_on,source_label
  ) values(
    p_tournament_id,extract(year from final_date)::int,
    champ,runner,final_score,final_date,
    'Court Boss simulated United Cup season engine v2'
  )
  on conflict(tournament_id) do update set
    season=excluded.season,
    champion_country=excluded.champion_country,
    runner_up_country=excluded.runner_up_country,
    final_score=excluded.final_score,
    completed_on=excluded.completed_on,
    source_label=excluded.source_label;

  insert into public.world_tournament_simulations(
    tournament_id,winner_id,finalist_id,winner_points,finalist_points,
    simulated_on,final_win_probability,court_speed,model_version,matchup_components,
    rule_key,draw_size,bracket_size,rounds_count,matches_simulated,participants_simulated,format_type
  )
  select
    p_tournament_id,null,null,0,0,t.end_date,null,t.court_speed,
    'CB-UNITED-CUP-v2','{}'::jsonb,
    'UNITED_CUP_2026',18,8,3,
    (select count(*)*3 from public.united_cup_ties where tournament_id=p_tournament_id and status='completed'),
    18,'team_round_robin_knockout'
  from public.tournaments t where t.id=p_tournament_id
  on conflict(tournament_id) do update set
    simulated_on=excluded.simulated_on,
    model_version=excluded.model_version,
    rule_key=excluded.rule_key,
    matches_simulated=excluded.matches_simulated,
    participants_simulated=excluded.participants_simulated,
    format_type=excluded.format_type;

  insert into public.player_tournament_history(
    player_id,season,tournament_id,tournament_name,tournament_date,level,category,surface,
    result_code,result_label,last_opponent,last_score,is_grand_slam,source,event_type
  )
  select
    r.player_id,
    extract(year from t.end_date)::int,
    t.id::text,t.name,t.end_date,
    t.category,t.category,t.surface,
    case
      when r.country=champ then 'W'
      when r.country=runner then 'F'
      when exists(
        select 1 from public.united_cup_ties u
        where u.tournament_id=t.id and u.stage='SF' and u.loser_nation=r.country
      ) then 'SF'
      when exists(
        select 1 from public.united_cup_ties u
        where u.tournament_id=t.id and u.stage='QF' and u.loser_nation=r.country
      ) then 'QF'
      else 'RR' end,
    case
      when r.country=champ then 'Champion · équipe'
      when r.country=runner then 'Finaliste · équipe'
      when exists(select 1 from public.united_cup_ties u where u.tournament_id=t.id and u.stage='SF' and u.loser_nation=r.country) then 'Demi-finale · équipe'
      when exists(select 1 from public.united_cup_ties u where u.tournament_id=t.id and u.stage='QF' and u.loser_nation=r.country) then 'Quart de finale · équipe'
      else 'Phase de groupes · équipe' end,
    null,null,false,
    'Court Boss United Cup 2026','team'
  from public.united_cup_atp_rosters r
  join public.tournaments t on t.id=p_tournament_id
  where r.tournament_id=p_tournament_id
  on conflict(player_id,event_type,tournament_id) do update set
    season=excluded.season,
    tournament_name=excluded.tournament_name,
    tournament_date=excluded.tournament_date,
    level=excluded.level,
    category=excluded.category,
    surface=excluded.surface,
    result_code=excluded.result_code,
    result_label=excluded.result_label,
    source=excluded.source;

  insert into public.player_titles(
    player_id,tournament_name,title_date,level,surface,event_type,verified,source_label,origin
  )
  select
    r.player_id,t.name,t.end_date,t.category,t.surface,
    'team',false,'Court Boss simulated United Cup champion','game'
  from public.united_cup_atp_rosters r
  join public.tournaments t on t.id=p_tournament_id
  where r.tournament_id=p_tournament_id
    and r.country=champ
    and not exists(
      select 1 from public.player_titles pt
      where pt.player_id=r.player_id
        and pt.tournament_name=t.name
        and pt.title_date=t.end_date
        and pt.event_type='team'
    );

  return jsonb_build_object(
    'ok',true,'champion',champ,'runner_up',runner,'final_score',final_score
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.simulate_united_cup_window(p_from_date date, p_to_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  rec record;
  r jsonb;
  v_simulated int:=0;
  v_qf jsonb;
  v_standings jsonb;
  v_advance jsonb;
  v_stats jsonb;
  v_final jsonb:=null;
begin
  if exists(
    select 1 from public.united_cup_history where tournament_id=2078
  ) then
    return jsonb_build_object(
      'ok',true,'already_complete',true,
      'completed_ties',(select count(*) from public.united_cup_ties where tournament_id=2078 and status='completed'),
      'rubbers',(select count(*) from public.united_cup_rubbers r join public.united_cup_ties t on t.id=r.tie_id where t.tournament_id=2078),
      'champion',(select champion_country from public.united_cup_history where tournament_id=2078),
      'model','United Cup 2026 v2'
    );
  end if;

  perform public.prepare_united_cup_2026(2078);

  if p_to_date<=date '2026-01-01' then
    return jsonb_build_object(
      'ok',true,'ties_simulated',0,'prepared',true,
      'future_results',false,'to',p_to_date
    );
  end if;

  -- Group stage.
  for rec in
    select id
    from public.united_cup_ties
    where tournament_id=2078
      and stage='Group'
      and status='scheduled'
      and tie_date<=p_to_date
    order by tie_date,id
  loop
    r:=public.simulate_united_cup_tie(rec.id);
    if coalesce((r->>'ok')::boolean,false) then v_simulated:=v_simulated+1; end if;
  end loop;

  if (select count(*) from public.united_cup_ties
      where tournament_id=2078 and stage='Group' and status='completed')=18 then
    v_standings:=public.refresh_united_cup_group_standings(2078);
    v_qf:=public.prepare_united_cup_quarterfinals(2078);
  end if;

  -- Quarterfinals.
  for rec in
    select id
    from public.united_cup_ties
    where tournament_id=2078
      and stage='QF'
      and status='scheduled'
      and tie_date<=p_to_date
    order by tie_date,bracket_slot,id
  loop
    r:=public.simulate_united_cup_tie(rec.id);
    if coalesce((r->>'ok')::boolean,false) then v_simulated:=v_simulated+1; end if;
  end loop;

  v_advance:=public.advance_united_cup_bracket(2078);

  -- Semifinals.
  for rec in
    select id
    from public.united_cup_ties
    where tournament_id=2078
      and stage='SF'
      and status='scheduled'
      and tie_date<=p_to_date
    order by bracket_slot,id
  loop
    r:=public.simulate_united_cup_tie(rec.id);
    if coalesce((r->>'ok')::boolean,false) then v_simulated:=v_simulated+1; end if;
  end loop;

  v_advance:=public.advance_united_cup_bracket(2078);

  -- Final.
  for rec in
    select id
    from public.united_cup_ties
    where tournament_id=2078
      and stage='F'
      and status='scheduled'
      and tie_date<=p_to_date
    order by id
  loop
    r:=public.simulate_united_cup_tie(rec.id);
    if coalesce((r->>'ok')::boolean,false) then v_simulated:=v_simulated+1; end if;
  end loop;

  v_stats:=public.recalculate_united_cup_stats(2078);

  if exists(
    select 1 from public.united_cup_ties
    where tournament_id=2078 and event_key='F' and status='completed'
  ) then
    v_final:=public.finalize_united_cup(2078);
  end if;

  return jsonb_build_object(
    'ok',true,
    'ties_simulated',v_simulated,
    'completed_ties',(select count(*) from public.united_cup_ties where tournament_id=2078 and status='completed'),
    'rubbers',(select count(*) from public.united_cup_rubbers r join public.united_cup_ties t on t.id=r.tie_id where t.tournament_id=2078),
    'standings',v_standings,
    'quarterfinals',v_qf,
    'advancement',v_advance,
    'stats',v_stats,
    'finalization',v_final,
    'from',p_from_date,'to',p_to_date,
    'model','United Cup 2026 v2 · 18 nations / 3 rubbers per tie'
  );
end;
$function$;

