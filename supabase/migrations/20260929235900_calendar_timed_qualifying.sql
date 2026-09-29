-- Court Boss calendar-timed qualifying engine
-- Singles qualifying is resolved on qualifying_end_date.
-- ATP 500 doubles qualifying is resolved as 4 teams -> 1 qualifier before the main draw.
-- The doubles main draw reuses the pre-resolved qualified pair.

CREATE OR REPLACE FUNCTION public.simulate_world_qualifying_window(p_from_date date, p_to_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t record;
  r jsonb;
  simulated int:=0;
  skipped int:=0;
  already int:=0;
  qualifiers int:=0;
begin
  if p_to_date<=date '2025-12-01' then
    return jsonb_build_object('qualifying_simulated',0,'historical_cutoff',true);
  end if;

  for t in
    select x.*
    from public.tournaments x
    where x.singles=true
      and coalesce(x.is_active,true)=true
      and coalesce(x.circuit,'') in ('ATP','Challenger','ITF')
      and coalesce(x.qualifying_draw_size,0)>0
      and coalesce(x.qualifying_end_date,x.start_date-1)>greatest(p_from_date,date '2025-12-01')
      and coalesce(x.qualifying_end_date,x.start_date-1)<=p_to_date
    order by coalesce(x.qualifying_end_date,x.start_date-1),x.id
    limit 220
  loop
    r:=public.simulate_world_qualifying_full(
      t.id,
      coalesce(t.qualifying_end_date,t.start_date-1,p_to_date)
    );

    if coalesce((r->>'ok')::boolean,false)=false then
      skipped:=skipped+1;
    elsif coalesce((r->>'already_simulated')::boolean,false) then
      already:=already+1;
      qualifiers:=qualifiers+coalesce((r->>'qualifiers')::int,0);
    elsif r->>'skipped'='no_qualifying' then
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
    'model','calendar-timed qualifying window v1'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.simulate_world_doubles_qualifying_full(p_tournament_id bigint, p_simulated_on date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  v_year int;
  v_managed bigint;
  v_draw int;
  v_pool_needed int;
  v_selected int;
  v_a bigint;
  v_b bigint;
  v_w bigint;
  v_l bigint;
  v_qw1 bigint;
  v_qw2 bigint;
  v_qwinner bigint;
  v_match jsonb;
  v_prob numeric;
  v_awon boolean;
  v_score text;
begin
  select * into t
  from public.tournaments
  where id=p_tournament_id
    and doubles=true
    and coalesce(is_active,true)=true;

  if t.id is null then
    return jsonb_build_object('ok',false,'reason','tournament_not_found');
  end if;

  if not (t.circuit='ATP' and t.category='ATP 500') then
    return jsonb_build_object('ok',true,'skipped','no_doubles_qualifying','tournament_id',t.id);
  end if;

  if exists(
    select 1 from public.world_doubles_qualifying_entries
    where tournament_id=t.id and qualified=true
  ) then
    return jsonb_build_object(
      'ok',true,'already_simulated',true,'tournament_id',t.id,
      'qualifiers',1,
      'qualified_pair_id',(
        select pair_id from public.world_doubles_qualifying_entries
        where tournament_id=t.id and qualified=true limit 1
      )
    );
  end if;

  v_year:=extract(year from coalesce(t.end_date,t.start_date))::int;
  select managed_player_id into v_managed from public.career_state where id='demo';

  if not exists(
    select 1 from public.world_doubles_partnerships
    where season=v_year and active=true
  ) then
    perform public.refresh_world_doubles_partnerships_fast(
      coalesce(t.qualifying_start_date,t.start_date,p_simulated_on),2000
    );
  end if;

  v_draw:=greatest(4,least(64,coalesce(t.doubles_draw_size,16)));
  v_pool_needed:=v_draw+3;

  drop table if exists pg_temp.cb_dq_pool;

  create temporary table cb_dq_pool(
    pair_id bigint primary key,
    score numeric,
    rn int,
    entry_method text not null default 'qualifying'
  ) on commit drop;

  insert into cb_dq_pool(pair_id,score,rn)
  select pair_id,score,
         row_number() over(order by score desc,pair_id)::int
  from (
    select w.id pair_id,
      (
        w.pair_strength*.34+w.chemistry*.17+w.compatibility*.14+w.affinity_score*.05+
        greatest(0,2200-coalesce(a.doubles_ranking,2200))*.005+
        greatest(0,2200-coalesce(b.doubles_ranking,2200))*.005+
        coalesce(pa.doubles,10)*.20+coalesce(pb.doubles,10)*.20+
        coalesce(public.player_psychology_modifier(a.id),0)*.30+
        coalesce(public.player_psychology_modifier(b.id),0)*.30+
        (mod(abs(hashtext('dentry|'||t.id::text||'|'||w.id::text)),1000)/1000.0)*3
      )::numeric score
    from public.world_doubles_partnerships w
    join public.players a on a.id=w.player_a_id
    join public.players b on b.id=w.player_b_id
    left join public.player_attributes pa on pa.player_id=a.id
    left join public.player_attributes pb on pb.player_id=b.id
    where w.season=v_year and w.active=true
      and a.career_status='active' and b.career_status='active'
      and a.id<>coalesce(v_managed,-1) and b.id<>coalesce(v_managed,-1)
      and coalesce(a.career_focus,'mixed')<>'singles_only'
      and coalesce(b.career_focus,'mixed')<>'singles_only'
      and a.injury_status='Fit' and b.injury_status='Fit'
      and coalesce(a.fitness,90)>=48 and coalesce(b.fitness,90)>=48
      and coalesce(a.fatigue,20)<=88 and coalesce(b.fatigue,20)<=88
      and not (public.player_tournament_calendar_conflict(a.id,t.id,'doubles_qualifying')->>'conflict')::boolean
      and not (public.player_tournament_calendar_conflict(b.id,t.id,'doubles_qualifying')->>'conflict')::boolean
      and public.ai_player_commits_to_doubles_tournament(a.id,t.id)
      and public.ai_player_commits_to_doubles_tournament(b.id,t.id)
    order by
      case
        when t.category='Grand Chelem' then coalesce(a.doubles_ranking,999999)+coalesce(b.doubles_ranking,999999)
        when t.category='Masters 1000' then coalesce(a.doubles_ranking,999999)+coalesce(b.doubles_ranking,999999)
        else 0
      end asc,
      score desc,w.id
    limit v_pool_needed
  ) s;

  delete from cb_dq_pool where rn<=v_draw-1;

  select count(*) into v_selected from cb_dq_pool;
  if v_selected<>4 then
    return jsonb_build_object(
      'ok',false,'reason','insufficient_doubles_qualifying_pairs',
      'required',4,'selected',v_selected,'tournament_id',t.id
    );
  end if;

  update cb_dq_pool q
  set entry_method='qualifying_wildcard'
  where q.pair_id=(
    select q2.pair_id
    from cb_dq_pool q2
    join public.world_doubles_partnerships w on w.id=q2.pair_id
    join public.players a on a.id=w.player_a_id
    join public.players b on b.id=w.player_b_id
    order by
      ((a.country is not distinct from t.country)::int+
       (b.country is not distinct from t.country)::int) desc,
      q2.score desc,q2.pair_id
    limit 1
  );

  delete from public.world_doubles_qualifying_entries where tournament_id=t.id;
  delete from public.world_doubles_tournament_matches
  where tournament_id=t.id and is_qualifying=true;

  insert into public.world_doubles_qualifying_entries(
    tournament_id,pair_id,seed,entry_method,result_code,qualified,simulated_on,source_label
  )
  select t.id,pair_id,
         row_number() over(order by score desc,pair_id)::int,
         entry_method,null,false,
         coalesce(t.qualifying_end_date,p_simulated_on,t.start_date),
         'ATP 2026 · ATP 500 doubles qualifying · calendar phase'
  from cb_dq_pool;

  select pair_id into v_a from cb_dq_pool order by score desc,pair_id limit 1;
  select pair_id into v_b from cb_dq_pool order by score desc,pair_id offset 3 limit 1;

  v_match:=public.doubles_pair_matchup_v2(v_a,v_b,t.surface,coalesce(t.qualifying_end_date,p_simulated_on,t.start_date));
  v_prob:=greatest(.02,least(.98,coalesce((v_match->>'pair_a_probability')::numeric,.5)));
  v_awon:=random()<v_prob;
  v_qw1:=case when v_awon then v_a else v_b end;
  v_l:=case when v_awon then v_b else v_a end;
  v_score:=public.world_tournament_score(v_prob,v_awon,3);

  insert into public.world_doubles_tournament_matches(
    tournament_id,round_no,round_code,match_no,pair_a_id,pair_b_id,winner_pair_id,loser_pair_id,
    score,pair_a_win_probability,model_version,matchup_components,simulated_on,is_qualifying
  ) values(
    t.id,-2,'DQ1',1,v_a,v_b,v_qw1,v_l,v_score,round(v_prob,4),
    'CB-DOUBLES-v5-QUALIFYING-CALENDAR',coalesce(v_match->'components','{}'::jsonb),
    coalesce(t.qualifying_end_date,p_simulated_on,t.start_date),true
  );

  update public.world_doubles_qualifying_entries
  set result_code='DQ1'
  where tournament_id=t.id and pair_id=v_l;

  select pair_id into v_a from cb_dq_pool order by score desc,pair_id offset 1 limit 1;
  select pair_id into v_b from cb_dq_pool order by score desc,pair_id offset 2 limit 1;

  v_match:=public.doubles_pair_matchup_v2(v_a,v_b,t.surface,coalesce(t.qualifying_end_date,p_simulated_on,t.start_date));
  v_prob:=greatest(.02,least(.98,coalesce((v_match->>'pair_a_probability')::numeric,.5)));
  v_awon:=random()<v_prob;
  v_qw2:=case when v_awon then v_a else v_b end;
  v_l:=case when v_awon then v_b else v_a end;
  v_score:=public.world_tournament_score(v_prob,v_awon,3);

  insert into public.world_doubles_tournament_matches(
    tournament_id,round_no,round_code,match_no,pair_a_id,pair_b_id,winner_pair_id,loser_pair_id,
    score,pair_a_win_probability,model_version,matchup_components,simulated_on,is_qualifying
  ) values(
    t.id,-2,'DQ1',2,v_a,v_b,v_qw2,v_l,v_score,round(v_prob,4),
    'CB-DOUBLES-v5-QUALIFYING-CALENDAR',coalesce(v_match->'components','{}'::jsonb),
    coalesce(t.qualifying_end_date,p_simulated_on,t.start_date),true
  );

  update public.world_doubles_qualifying_entries
  set result_code='DQ1'
  where tournament_id=t.id and pair_id=v_l;

  v_a:=v_qw1;
  v_b:=v_qw2;
  v_match:=public.doubles_pair_matchup_v2(v_a,v_b,t.surface,coalesce(t.qualifying_end_date,p_simulated_on,t.start_date));
  v_prob:=greatest(.02,least(.98,coalesce((v_match->>'pair_a_probability')::numeric,.5)));
  v_awon:=random()<v_prob;
  v_qwinner:=case when v_awon then v_a else v_b end;
  v_l:=case when v_awon then v_b else v_a end;
  v_score:=public.world_tournament_score(v_prob,v_awon,3);

  insert into public.world_doubles_tournament_matches(
    tournament_id,round_no,round_code,match_no,pair_a_id,pair_b_id,winner_pair_id,loser_pair_id,
    score,pair_a_win_probability,model_version,matchup_components,simulated_on,is_qualifying
  ) values(
    t.id,-1,'DQF',1,v_a,v_b,v_qwinner,v_l,v_score,round(v_prob,4),
    'CB-DOUBLES-v5-QUALIFYING-CALENDAR',coalesce(v_match->'components','{}'::jsonb),
    coalesce(t.qualifying_end_date,p_simulated_on,t.start_date),true
  );

  update public.world_doubles_qualifying_entries
  set result_code='DQF',points_awarded=25
  where tournament_id=t.id and pair_id=v_l;

  update public.world_doubles_qualifying_entries
  set result_code='Q',qualified=true,points_awarded=45
  where tournament_id=t.id and pair_id=v_qwinner;

  insert into public.world_doubles_ranking_points(
    player_id,tournament_id,pair_id,label,earned_date,expiry_date,points,active,source_label
  )
  select w.player_a_id,t.id,w.id,t.name||' · DQF',
         coalesce(t.qualifying_end_date,p_simulated_on,t.start_date),
         coalesce(t.qualifying_end_date,p_simulated_on,t.start_date)+364,
         25,true,'ATP 500 doubles qualifying · final round'
  from public.world_doubles_partnerships w
  where w.id=v_l
  on conflict(player_id,tournament_id) do update set
    pair_id=excluded.pair_id,label=excluded.label,earned_date=excluded.earned_date,
    expiry_date=excluded.expiry_date,points=excluded.points,active=true,source_label=excluded.source_label;

  insert into public.world_doubles_ranking_points(
    player_id,tournament_id,pair_id,label,earned_date,expiry_date,points,active,source_label
  )
  select w.player_b_id,t.id,w.id,t.name||' · DQF',
         coalesce(t.qualifying_end_date,p_simulated_on,t.start_date),
         coalesce(t.qualifying_end_date,p_simulated_on,t.start_date)+364,
         25,true,'ATP 500 doubles qualifying · final round'
  from public.world_doubles_partnerships w
  where w.id=v_l
  on conflict(player_id,tournament_id) do update set
    pair_id=excluded.pair_id,label=excluded.label,earned_date=excluded.earned_date,
    expiry_date=excluded.expiry_date,points=excluded.points,active=true,source_label=excluded.source_label;

  update public.world_doubles_partnerships
  set race_points=race_points+25,
      last_refresh_date=greatest(last_refresh_date,coalesce(t.qualifying_end_date,p_simulated_on,t.start_date))
  where id=v_l;

  return jsonb_build_object(
    'ok',true,'tournament_id',t.id,'qualifiers',1,
    'qualified_pair_id',v_qwinner,'draw',4,'matches',3,
    'simulated_on',coalesce(t.qualifying_end_date,p_simulated_on,t.start_date)
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.simulate_world_doubles_qualifying_window(p_from_date date, p_to_date date)
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
begin
  for t in
    select *
    from public.tournaments
    where circuit='ATP'
      and category='ATP 500'
      and doubles=true
      and coalesce(is_active,true)=true
      and coalesce(qualifying_end_date,start_date)>greatest(p_from_date,date '2025-12-01')
      and coalesce(qualifying_end_date,start_date)<=p_to_date
    order by coalesce(qualifying_end_date,start_date),id
  loop
    r:=public.simulate_world_doubles_qualifying_full(
      t.id,coalesce(t.qualifying_end_date,t.start_date,p_to_date)
    );

    if coalesce((r->>'ok')::boolean,false)=false then
      skipped:=skipped+1;
    elsif coalesce((r->>'already_simulated')::boolean,false) then
      already:=already+1;
    else
      simulated:=simulated+1;
    end if;
  end loop;

  return jsonb_build_object(
    'qualifying_simulated',simulated,
    'already_simulated',already,
    'skipped',skipped,
    'from',p_from_date,'to',p_to_date,
    'model','ATP 500 doubles qualifying calendar window v1'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.simulate_world_doubles_tournaments(p_from_date date, p_to_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  t public.tournaments%rowtype;
  v_year int;
  v_managed bigint;
  v_draw int;
  v_bracket int;
  v_byes int;
  v_rounds int;
  v_round int;
  v_size int;
  v_pos int;
  v_next int;
  v_a bigint;
  v_b bigint;
  v_w bigint;
  v_l bigint;
  v_match jsonb;
  v_prob numeric;
  v_awon boolean;
  v_score text;
  v_round_code text;
  v_points int;
  v_prize numeric;
  v_winner bigint;
  v_finalist bigint;
  v_matches int:=0;
  v_simulated int:=0;
  v_selected int;
  v_qdraw int:=0;
  v_qslots int:=0;
  v_wc_count int:=0;
  v_pool_needed int:=0;
  v_seed_limit int:=0;
  v_qw1 bigint;
  v_qw2 bigint;
  v_qwinner bigint;
  entry_rec record;
  match_rec record;
begin
  perform pg_advisory_xact_lock(94832021);
  if p_to_date<=date '2025-12-01' then
    return jsonb_build_object('tournaments_simulated',0,'historical_cutoff',true);
  end if;
  select managed_player_id into v_managed from public.career_state where id='demo';

  for t in
    select *
    from public.tournaments
    where doubles=true and coalesce(is_active,true)=true
      and coalesce(end_date,start_date)>greatest(p_from_date,date '2025-12-01')
      and coalesce(end_date,start_date)<=p_to_date
      and coalesce(circuit,'') not in ('NCAA','Junior','Federation')
      and coalesce(category,'') not in ('United Cup','Laver Cup','ATP Finals')
      and not exists(select 1 from public.world_doubles_tournament_simulations s where s.tournament_id=tournaments.id)
    order by coalesce(end_date,start_date),id
    limit 120
  loop
    v_year:=extract(year from coalesce(t.end_date,t.start_date))::int;
    if not exists(select 1 from public.world_doubles_partnerships where season=v_year and active=true) then
      perform public.refresh_world_doubles_partnerships_fast(coalesce(t.start_date,p_to_date),2000);
    end if;

    v_draw:=greatest(4,least(64,coalesce(t.doubles_draw_size,16)));
    v_bracket:=case
      when v_draw<=8 then 8 when v_draw<=16 then 16 when v_draw<=32 then 32 else 64 end;
    v_byes:=v_bracket-v_draw;
    v_rounds:=ceil(ln(v_bracket::numeric)/ln(2::numeric))::int;
    v_qdraw:=case when t.circuit='ATP' and t.category='ATP 500' then 4 else 0 end;
    v_qslots:=case when v_qdraw=4 then 1 else 0 end;
    v_pool_needed:=v_draw+greatest(0,v_qdraw-v_qslots);
    v_wc_count:=case
      when t.circuit='ATP' and t.category in ('ATP 250','ATP 500') then 2
      when t.circuit='ATP' and t.category='Masters 1000' then
        case when v_draw in (28,32) then 3 when v_draw=24 then 2 else 0 end
      when t.circuit='Challenger' then 2
      else 0 end;
    v_seed_limit:=case when v_draw<=16 then 4 else 8 end;

    drop table if exists pg_temp.cb_d_entries;
    drop table if exists pg_temp.cb_d_current;
    drop table if exists pg_temp.cb_d_next;

    create temporary table cb_d_entries(
      pair_id bigint primary key,
      entry_method text not null default 'direct',
      score numeric,
      seed int,
      draw_slot int,
      had_bye boolean not null default false,
      matches_won int not null default 0,
      result_code text,
      points_awarded int not null default 0,
      prize_awarded numeric not null default 0,
      qualifying_points integer not null default 0,
      last_opponent_pair_id bigint,
      last_score text
    ) on commit drop;

    insert into cb_d_entries(pair_id,score)
    select w.id,
      (
        w.pair_strength*.34+w.chemistry*.17+w.compatibility*.14+w.affinity_score*.05+
        greatest(0,2200-coalesce(a.doubles_ranking,2200))*.005+
        greatest(0,2200-coalesce(b.doubles_ranking,2200))*.005+
        coalesce(pa.doubles,10)*.20+coalesce(pb.doubles,10)*.20+
        coalesce(public.player_psychology_modifier(a.id),0)*.30+
        coalesce(public.player_psychology_modifier(b.id),0)*.30+
        (mod(abs(hashtext('dentry|'||t.id::text||'|'||w.id::text)),1000)/1000.0)*3
      )::numeric
    from public.world_doubles_partnerships w
    join public.players a on a.id=w.player_a_id
    join public.players b on b.id=w.player_b_id
    left join public.player_attributes pa on pa.player_id=a.id
    left join public.player_attributes pb on pb.player_id=b.id
    where w.season=v_year and w.active=true
      and a.career_status='active' and b.career_status='active'
      and a.id<>coalesce(v_managed,-1) and b.id<>coalesce(v_managed,-1)
      and coalesce(a.career_focus,'mixed')<>'singles_only'
      and coalesce(b.career_focus,'mixed')<>'singles_only'
      and a.injury_status='Fit' and b.injury_status='Fit'
      and coalesce(a.fitness,90)>=48 and coalesce(b.fitness,90)>=48
      and coalesce(a.fatigue,20)<=88 and coalesce(b.fatigue,20)<=88
      and not (public.player_tournament_calendar_conflict(a.id,t.id,'doubles')->>'conflict')::boolean
      and not (public.player_tournament_calendar_conflict(b.id,t.id,'doubles')->>'conflict')::boolean
      and public.ai_player_commits_to_doubles_tournament(a.id,t.id)
      and public.ai_player_commits_to_doubles_tournament(b.id,t.id)
    order by
      case
        when t.category='Grand Chelem' then coalesce(a.doubles_ranking,999999)+coalesce(b.doubles_ranking,999999)
        when t.category='Masters 1000' then coalesce(a.doubles_ranking,999999)+coalesce(b.doubles_ranking,999999)
        else 0
      end asc,
      2 desc,w.id
    limit v_pool_needed;

    select count(*) into v_selected from cb_d_entries;
    if v_selected<>v_pool_needed then continue; end if;

    if v_qdraw=4 and exists(
      select 1
      from public.world_doubles_qualifying_entries q
      where q.tournament_id=t.id and q.qualified=true
    ) then
      select q.pair_id into v_qwinner
      from public.world_doubles_qualifying_entries q
      where q.tournament_id=t.id and q.qualified=true
      order by q.id
      limit 1;

      if not exists(select 1 from cb_d_entries where pair_id=v_qwinner) then
        insert into cb_d_entries(pair_id,score,entry_method,qualifying_points)
        values(v_qwinner,-100000,'qualifier',45)
        on conflict(pair_id) do update set
          entry_method='qualifier',
          qualifying_points=greatest(cb_d_entries.qualifying_points,45);
      end if;

      delete from cb_d_entries e
      where e.pair_id in (
        select q.pair_id
        from public.world_doubles_qualifying_entries q
        where q.tournament_id=t.id and q.qualified=false
      );

      update cb_d_entries
      set entry_method='qualifier',qualifying_points=45
      where pair_id=v_qwinner;

      select count(*) into v_selected from cb_d_entries;
      while v_selected>v_draw loop
        delete from cb_d_entries
        where pair_id=(
          select e.pair_id
          from cb_d_entries e
          where e.pair_id<>v_qwinner
          order by e.score asc,e.pair_id desc
          limit 1
        );
        v_selected:=v_selected-1;
      end loop;
    else
    delete from public.world_doubles_qualifying_entries where tournament_id=t.id;
    delete from public.world_doubles_tournament_matches
    where tournament_id=t.id and is_qualifying=true;

    if v_qdraw=4 and v_qslots=1 then
      -- ATP 500 doubles qualifying: 4 teams, 3 direct + 1 WC, one team qualifies.
      with ranked as (
        select pair_id,score,
               row_number() over(order by score desc,pair_id)::int rn
        from cb_d_entries
      )
      update cb_d_entries e
      set entry_method='qualifying'
      from ranked rnk
      where e.pair_id=rnk.pair_id
        and rnk.rn>v_draw-1;

      -- The qualifying WC favours a home team, then pair quality.
      update cb_d_entries e
      set entry_method='qualifying_wildcard'
      where e.pair_id=(
        select q.pair_id
        from cb_d_entries q
        join public.world_doubles_partnerships w on w.id=q.pair_id
        join public.players a on a.id=w.player_a_id
        join public.players b on b.id=w.player_b_id
        where q.entry_method='qualifying'
        order by
          ((a.country is not distinct from t.country)::int+
           (b.country is not distinct from t.country)::int) desc,
          q.score desc,q.pair_id
        limit 1
      );

      insert into public.world_doubles_qualifying_entries(
        tournament_id,pair_id,seed,entry_method,result_code,qualified,simulated_on,source_label
      )
      select t.id,e.pair_id,
             row_number() over(order by e.score desc,e.pair_id)::int,
             e.entry_method,null,false,
             coalesce(t.qualifying_end_date,t.start_date),
             'ATP 2026 · ATP 500 doubles qualifying'
      from cb_d_entries e
      where e.entry_method in ('qualifying','qualifying_wildcard');

      select pair_id into v_a from cb_d_entries
      where entry_method in ('qualifying','qualifying_wildcard')
      order by score desc,pair_id limit 1;
      select pair_id into v_b from cb_d_entries
      where entry_method in ('qualifying','qualifying_wildcard')
      order by score desc,pair_id offset 3 limit 1;

      v_match:=public.doubles_pair_matchup_v2(v_a,v_b,t.surface,coalesce(t.qualifying_end_date,t.start_date));
      v_prob:=greatest(.02,least(.98,coalesce((v_match->>'pair_a_probability')::numeric,.5)));
      v_awon:=random()<v_prob;
      v_qw1:=case when v_awon then v_a else v_b end;
      v_l:=case when v_awon then v_b else v_a end;
      v_score:=public.world_tournament_score(v_prob,v_awon,3);

      insert into public.world_doubles_tournament_matches(
        tournament_id,round_no,round_code,match_no,pair_a_id,pair_b_id,winner_pair_id,loser_pair_id,
        score,pair_a_win_probability,model_version,matchup_components,simulated_on,is_qualifying
      ) values(
        t.id,-2,'DQ1',1,v_a,v_b,v_qw1,v_l,v_score,round(v_prob,4),
        'CB-DOUBLES-v4-QUALIFYING',coalesce(v_match->'components','{}'::jsonb),
        coalesce(t.qualifying_end_date,t.start_date),true
      );
      update public.world_doubles_qualifying_entries set result_code='DQ1'
      where tournament_id=t.id and pair_id=v_l;

      select pair_id into v_a from cb_d_entries
      where entry_method in ('qualifying','qualifying_wildcard')
      order by score desc,pair_id offset 1 limit 1;
      select pair_id into v_b from cb_d_entries
      where entry_method in ('qualifying','qualifying_wildcard')
      order by score desc,pair_id offset 2 limit 1;

      v_match:=public.doubles_pair_matchup_v2(v_a,v_b,t.surface,coalesce(t.qualifying_end_date,t.start_date));
      v_prob:=greatest(.02,least(.98,coalesce((v_match->>'pair_a_probability')::numeric,.5)));
      v_awon:=random()<v_prob;
      v_qw2:=case when v_awon then v_a else v_b end;
      v_l:=case when v_awon then v_b else v_a end;
      v_score:=public.world_tournament_score(v_prob,v_awon,3);

      insert into public.world_doubles_tournament_matches(
        tournament_id,round_no,round_code,match_no,pair_a_id,pair_b_id,winner_pair_id,loser_pair_id,
        score,pair_a_win_probability,model_version,matchup_components,simulated_on,is_qualifying
      ) values(
        t.id,-2,'DQ1',2,v_a,v_b,v_qw2,v_l,v_score,round(v_prob,4),
        'CB-DOUBLES-v4-QUALIFYING',coalesce(v_match->'components','{}'::jsonb),
        coalesce(t.qualifying_end_date,t.start_date),true
      );
      update public.world_doubles_qualifying_entries set result_code='DQ1'
      where tournament_id=t.id and pair_id=v_l;

      v_a:=v_qw1; v_b:=v_qw2;
      v_match:=public.doubles_pair_matchup_v2(v_a,v_b,t.surface,coalesce(t.qualifying_end_date,t.start_date));
      v_prob:=greatest(.02,least(.98,coalesce((v_match->>'pair_a_probability')::numeric,.5)));
      v_awon:=random()<v_prob;
      v_qwinner:=case when v_awon then v_a else v_b end;
      v_l:=case when v_awon then v_b else v_a end;
      v_score:=public.world_tournament_score(v_prob,v_awon,3);

      insert into public.world_doubles_tournament_matches(
        tournament_id,round_no,round_code,match_no,pair_a_id,pair_b_id,winner_pair_id,loser_pair_id,
        score,pair_a_win_probability,model_version,matchup_components,simulated_on,is_qualifying
      ) values(
        t.id,-1,'DQF',1,v_a,v_b,v_qwinner,v_l,v_score,round(v_prob,4),
        'CB-DOUBLES-v4-QUALIFYING',coalesce(v_match->'components','{}'::jsonb),
        coalesce(t.qualifying_end_date,t.start_date),true
      );

      update public.world_doubles_qualifying_entries
      set result_code='DQF',points_awarded=25
      where tournament_id=t.id and pair_id=v_l;

      update public.world_doubles_qualifying_entries
      set result_code='Q',qualified=true,points_awarded=45
      where tournament_id=t.id and pair_id=v_qwinner;

      -- ATP 2026: the team losing the final qualifying round earns 25 points.
      insert into public.world_doubles_ranking_points(
        player_id,tournament_id,pair_id,label,earned_date,expiry_date,points,active,source_label
      )
      select w.player_a_id,t.id,w.id,t.name||' · DQF',
             coalesce(t.qualifying_end_date,t.start_date),
             coalesce(t.qualifying_end_date,t.start_date)+364,
             25,true,'ATP 500 doubles qualifying · final round'
      from public.world_doubles_partnerships w
      where w.id=v_l
      on conflict(player_id,tournament_id) do update set
        pair_id=excluded.pair_id,label=excluded.label,earned_date=excluded.earned_date,
        expiry_date=excluded.expiry_date,points=excluded.points,active=true,source_label=excluded.source_label;

      insert into public.world_doubles_ranking_points(
        player_id,tournament_id,pair_id,label,earned_date,expiry_date,points,active,source_label
      )
      select w.player_b_id,t.id,w.id,t.name||' · DQF',
             coalesce(t.qualifying_end_date,t.start_date),
             coalesce(t.qualifying_end_date,t.start_date)+364,
             25,true,'ATP 500 doubles qualifying · final round'
      from public.world_doubles_partnerships w
      where w.id=v_l
      on conflict(player_id,tournament_id) do update set
        pair_id=excluded.pair_id,label=excluded.label,earned_date=excluded.earned_date,
        expiry_date=excluded.expiry_date,points=excluded.points,active=true,source_label=excluded.source_label;

      update public.world_doubles_partnerships
      set race_points=race_points+25,
          last_refresh_date=greatest(last_refresh_date,coalesce(t.qualifying_end_date,t.start_date))
      where id=v_l;

      delete from cb_d_entries
      where entry_method in ('qualifying','qualifying_wildcard')
        and pair_id<>v_qwinner;

      update cb_d_entries
      set entry_method='qualifier',qualifying_points=45
      where pair_id=v_qwinner;
    end if;

    end if;

    select count(*) into v_selected from cb_d_entries;
    if v_selected<>v_draw then continue; end if;

    if v_wc_count>0 then
      update cb_d_entries e
      set entry_method='wildcard'
      where e.pair_id in (
        select q.pair_id
        from cb_d_entries q
        join public.world_doubles_partnerships w on w.id=q.pair_id
        join public.players a on a.id=w.player_a_id
        join public.players b on b.id=w.player_b_id
        where q.entry_method='direct'
        order by
          ((a.country is not distinct from t.country)::int+
           (b.country is not distinct from t.country)::int) desc,
          q.score desc,q.pair_id
        limit v_wc_count
      );
    end if;

    if t.circuit='Challenger' then
      update cb_d_entries e
      set entry_method='onsite'
      where e.pair_id in (
        select q.pair_id from cb_d_entries q
        where q.entry_method='direct'
        order by q.score asc,q.pair_id
        limit 4
      );
    end if;

    with seed_order as (
      select pair_id,row_number() over(order by score desc,pair_id)::int rn
      from cb_d_entries
    )
    update cb_d_entries e
    set seed=case when seed_order.rn<=v_seed_limit then seed_order.rn else null end
    from seed_order
    where e.pair_id=seed_order.pair_id;

    -- deterministic spread of seeds, with byes assigned to top seeds
    update cb_d_entries
    set draw_slot=public.world_tournament_seed_slot(v_bracket,seed)
    where seed<=least(v_seed_limit,v_draw);

    if v_byes>0 then
      update cb_d_entries
      set had_bye=true
      where seed<=least(v_byes,v_seed_limit);
    end if;

    with used as (
      select draw_slot slot from cb_d_entries where draw_slot is not null
      union all
      select case when draw_slot%2=1 then draw_slot+1 else draw_slot-1 end
      from cb_d_entries where had_bye=true and draw_slot is not null
    ),
    avail as (
      select g slot,row_number() over(order by md5('dslot|'||t.id::text||'|'||g::text)) rn
      from generate_series(1,v_bracket) g
      where not exists(select 1 from used u where u.slot=g)
    ),
    unplaced as (
      select pair_id,row_number() over(order by md5('dpair|'||t.id::text||'|'||pair_id::text)) rn
      from cb_d_entries where draw_slot is null
    )
    update cb_d_entries e set draw_slot=a.slot
    from unplaced u join avail a using(rn)
    where e.pair_id=u.pair_id;

    create temporary table cb_d_current(pos int primary key,pair_id bigint) on commit drop;
    create temporary table cb_d_next(pos int primary key,pair_id bigint) on commit drop;
    insert into cb_d_current(pos,pair_id)
    select g,e.pair_id
    from generate_series(1,v_bracket) g
    left join cb_d_entries e on e.draw_slot=g;

    delete from public.world_doubles_tournament_matches where tournament_id=t.id and is_qualifying=false;
    v_size:=v_bracket;

    for v_round in 1..v_rounds loop
      truncate cb_d_next;
      v_next:=0;
      v_round_code:=case
        when v_round=1 and v_draw<>v_bracket then 'R'||v_draw::text
        when v_size>=64 then 'R64'
        when v_size>=32 then 'R32'
        when v_size>=16 then 'R16'
        when v_size>=8 then 'QF'
        when v_size>=4 then 'SF'
        else 'F' end;

      for v_pos in 1..v_size by 2 loop
        v_next:=v_next+1;
        select pair_id into v_a from cb_d_current where pos=v_pos;
        select pair_id into v_b from cb_d_current where pos=v_pos+1;

        if v_a is null and v_b is null then
          insert into cb_d_next(pos,pair_id) values(v_next,null);
          continue;
        elsif v_a is null or v_b is null then
          v_w:=coalesce(v_a,v_b);
          insert into cb_d_next(pos,pair_id) values(v_next,v_w);
          continue;
        end if;

        v_match:=public.doubles_pair_matchup_v2(v_a,v_b,t.surface,coalesce(t.end_date,t.start_date));
        v_prob:=greatest(.02,least(.98,coalesce((v_match->>'pair_a_probability')::numeric,.5)));
        v_awon:=random()<v_prob;
        v_w:=case when v_awon then v_a else v_b end;
        v_l:=case when v_awon then v_b else v_a end;
        v_score:=public.world_tournament_score(v_prob,v_awon,3);

        insert into public.world_doubles_tournament_matches(
          tournament_id,round_no,round_code,match_no,pair_a_id,pair_b_id,winner_pair_id,loser_pair_id,
          score,pair_a_win_probability,model_version,matchup_components,simulated_on
        ) values(
          t.id,v_round,v_round_code,(v_pos+1)/2,v_a,v_b,v_w,v_l,v_score,round(v_prob,4),
          'CB-DOUBLES-v3-FULLDRAW',coalesce(v_match->'components','{}'::jsonb),
          coalesce(t.end_date,t.start_date)
        );
        v_matches:=v_matches+1;

        v_points:=public.doubles_points_for_result(t.category,v_draw,v_round_code);
        v_prize:=public.tournament_prize_for_result(t.id,v_round_code,'doubles');
        update cb_d_entries
        set result_code=v_round_code,
            points_awarded=v_points+coalesce(qualifying_points,0),
            prize_awarded=v_prize,
            last_opponent_pair_id=v_w,
            last_score=case when v_l=v_a then v_score else public.world_invert_tennis_score(v_score) end
        where pair_id=v_l;
        update cb_d_entries set matches_won=matches_won+1 where pair_id=v_w;

        insert into cb_d_next(pos,pair_id) values(v_next,v_w);
      end loop;

      truncate cb_d_current;
      insert into cb_d_current select * from cb_d_next;
      v_size:=greatest(1,v_size/2);
    end loop;

    select pair_id into v_winner from cb_d_current order by pos limit 1;
    select loser_pair_id into v_finalist
    from public.world_doubles_tournament_matches
    where tournament_id=t.id and round_code='F'
    order by id desc limit 1;

    update cb_d_entries
    set result_code='W',
        points_awarded=public.doubles_points_for_result(t.category,v_draw,'W')+coalesce(qualifying_points,0),
        prize_awarded=public.tournament_prize_for_result(t.id,'W','doubles')
    where pair_id=v_winner;

    insert into public.world_doubles_tournament_entries(
      tournament_id,pair_id,entry_method,seed,draw_slot,had_bye,matches_won,result_code,result_label,
      points_awarded,prize_awarded,last_opponent_pair_id,last_score,simulated_on,source_label
    )
    select t.id,pair_id,entry_method,seed,draw_slot,had_bye,matches_won,result_code,
      case result_code when 'W' then 'Vainqueur' when 'F' then 'Finaliste'
        when 'SF' then 'Demi-finale' when 'QF' then 'Quart de finale'
        when 'R16' then '1/8 finale' when 'R24' then '1er tour · tableau 24'
        when 'R28' then '1er tour · tableau 28'
        when 'R32' then '1/16 finale' else result_code end,
      points_awarded,prize_awarded,last_opponent_pair_id,last_score,
      coalesce(t.end_date,t.start_date),'Court Boss doubles full draw'
    from cb_d_entries;

    insert into public.world_doubles_ranking_points(
      player_id,tournament_id,pair_id,label,earned_date,expiry_date,points,active,source_label
    )
    select w.player_a_id,t.id,e.pair_id,t.name||' · '||e.result_code,
           coalesce(t.end_date,t.start_date),coalesce(t.end_date,t.start_date)+364,
           e.points_awarded,true,'Court Boss doubles full draw'
    from cb_d_entries e join public.world_doubles_partnerships w on w.id=e.pair_id
    where e.points_awarded>0
    on conflict(player_id,tournament_id) do update set
      pair_id=excluded.pair_id,label=excluded.label,earned_date=excluded.earned_date,
      expiry_date=excluded.expiry_date,points=excluded.points,active=true,source_label=excluded.source_label;

    insert into public.world_doubles_ranking_points(
      player_id,tournament_id,pair_id,label,earned_date,expiry_date,points,active,source_label
    )
    select w.player_b_id,t.id,e.pair_id,t.name||' · '||e.result_code,
           coalesce(t.end_date,t.start_date),coalesce(t.end_date,t.start_date)+364,
           e.points_awarded,true,'Court Boss doubles full draw'
    from cb_d_entries e join public.world_doubles_partnerships w on w.id=e.pair_id
    where e.points_awarded>0
    on conflict(player_id,tournament_id) do update set
      pair_id=excluded.pair_id,label=excluded.label,earned_date=excluded.earned_date,
      expiry_date=excluded.expiry_date,points=excluded.points,active=true,source_label=excluded.source_label;

    update public.world_doubles_partnerships w
    set matches=w.matches+e.matches_won+case when e.result_code<>'W' then 1 else 0 end,
        wins=w.wins+e.matches_won,
        race_points=w.race_points+e.points_awarded,
        titles=w.titles+case when e.result_code='W' then 1 else 0 end,
        last_refresh_date=greatest(w.last_refresh_date,coalesce(t.end_date,t.start_date))
    from cb_d_entries e where w.id=e.pair_id;

    for entry_rec in
      select de.*,w.player_a_id,w.player_b_id,
             a.name a_name,b.name b_name
      from cb_d_entries de
      join public.world_doubles_partnerships w on w.id=de.pair_id
      join public.players a on a.id=w.player_a_id
      join public.players b on b.id=w.player_b_id
    loop
      if entry_rec.result_code='W' then
        insert into public.player_titles(player_id,tournament_name,title_date,level,surface,event_type,partner_player_id,partner_name,verified,source_label,origin)
        values
          (entry_rec.player_a_id,t.name,coalesce(t.end_date,t.start_date),t.category,t.surface,'doubles',entry_rec.player_b_id,entry_rec.b_name,false,'Court Boss doubles full draw','game'),
          (entry_rec.player_b_id,t.name,coalesce(t.end_date,t.start_date),t.category,t.surface,'doubles',entry_rec.player_a_id,entry_rec.a_name,false,'Court Boss doubles full draw','game')
        on conflict(player_id,tournament_name,title_date,event_type) do nothing;
      end if;
    end loop;

    insert into public.world_doubles_tournament_simulations(
      tournament_id,season,winner_pair_id,finalist_pair_id,winner_points,finalist_points,
      draw_size,simulated_on,source,final_win_probability,model_version,matchup_components
    )
    select t.id,v_year,v_winner,v_finalist,
      public.doubles_points_for_result(t.category,v_draw,'W'),
      public.doubles_points_for_result(t.category,v_draw,'F'),
      v_draw,coalesce(t.end_date,t.start_date),'Court Boss doubles full draw',
      case when m.winner_pair_id=m.pair_a_id then m.pair_a_win_probability else 1-m.pair_a_win_probability end,
      'CB-DOUBLES-v3-FULLDRAW',m.matchup_components
    from public.world_doubles_tournament_matches m
    where m.tournament_id=t.id and m.round_code='F'
    limit 1;

    v_simulated:=v_simulated+1;
  end loop;

  perform public.refresh_world_doubles_player_rankings(p_to_date);

  with ranked as (
    select id,row_number() over(order by race_points desc,pair_strength desc,affinity_score desc,id)::int rr
    from public.world_doubles_partnerships
    where season=extract(year from p_to_date)::int and active=true
  )
  update public.world_doubles_partnerships w set race_rank=r.rr from ranked r where w.id=r.id;

  return jsonb_build_object(
    'tournaments_simulated',v_simulated,'matches_simulated',v_matches,
    'from',p_from_date,'to',p_to_date,'ranking_model','best-18 rolling results',
    'match_model','CB-DOUBLES-v3-FULLDRAW'
  );
end
$function$;

