-- Court Boss follow-up: persistent United Cup standings + complete recent match load
-- Captured from live Supabase after verification on 2026-09-30.
-- Includes manual managed-player singles/doubles and United Cup rubbers in injury load.

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
    from public.match_history mh
    where mh.user_involved=true
      and mh.match_date between p_date-13 and p_date
      and p_player_id=(
        select cs.managed_player_id
        from public.career_state cs
        where cs.id='demo'
      )

    union all
    select count(*)::int
    from public.doubles_match_history dmh
    join public.doubles_runs dr on dr.id=dmh.run_id
    join public.tournaments dt on dt.id=dr.tournament_id
    where lower(coalesce(dr.status,''))='completed'
      and coalesce(dt.end_date,dt.start_date) between p_date-13 and p_date
      and p_player_id=(
        select cs.managed_player_id
        from public.career_state cs
        where cs.id='demo'
      )

    union all
    select count(*)::int
    from public.united_cup_rubbers ur
    join public.united_cup_ties ut on ut.id=ur.tie_id
    where ur.played_on between p_date-13 and p_date
      and (
        p_player_id=ur.nation_a_male_id
        or p_player_id=ur.nation_b_male_id
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

