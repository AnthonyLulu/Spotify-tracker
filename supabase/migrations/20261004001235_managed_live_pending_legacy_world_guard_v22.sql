CREATE OR REPLACE FUNCTION public.simulate_world_tournaments(p_from_date date, p_to_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t record;
  r public.tournament_format_rules%rowtype;
  v_result jsonb;
  v_simulated integer:=0;
  v_skipped integer:=0;
  v_knockout integer:=0;
  v_round_robin integer:=0;
  v_matches integer:=0;
  v_participants integer:=0;
  v_rank jsonb;
  v_race jsonb;
  v_nextgen jsonb;
begin
  perform pg_advisory_xact_lock(94832021);

  if p_to_date<=date '2025-12-01' then
    return jsonb_build_object('tournaments_simulated',0,'historical_cutoff',true);
  end if;

  for t in
    select x.*
    from public.tournaments x
    where x.singles=true
      and coalesce(x.is_active,true)=true
      and coalesce(x.end_date,x.start_date)>greatest(p_from_date,date '2025-12-01')
      and coalesce(x.end_date,x.start_date)<=p_to_date
      and coalesce(x.circuit,'') in ('ATP','Challenger','ITF')
      and coalesce(x.category,'') not in ('United Cup','Laver Cup','Davis Cup','Junior Davis Cup')
      and not exists(select 1 from public.world_tournament_simulations s where s.tournament_id=x.id)
      -- Progressive daily tournaments own any prepared state. Never let the
      -- legacy full-draw simulator jump over a managed_live_pending match.
      and not exists(
        select 1 from public.world_tournament_states ws
        where ws.tournament_id=x.id
      )
      and not exists(
        select 1 from public.world_qualifying_states wq
        where wq.tournament_id=x.id
      )
      and not exists(
        select 1
        from public.world_tournament_matches wm
        where wm.tournament_id=x.id
          and wm.winner_id is null
          and coalesce(wm.matchup_components->>'status','')='managed_live_pending'
      )
      -- Even before the progressive state is prepared, an entered managed
      -- player reserves the event for the Match Center / daily engine.
      and not exists(
        select 1
        from public.entries me
        where me.tournament_id=x.id
          and coalesce(me.status,'entered') not in ('withdrawn','declined','rejected')
          and me.player_id in (
            select cs.managed_player_id
            from public.career_state cs
            where cs.id='demo' and cs.managed_player_id is not null
            union
            select ar.player_id
            from public.academy_roster ar
            where ar.status='active'
              and ar.player_id is not null
              and ar.source_youth_id is null
          )
      )
      and not exists(
        select 1
        from public.tournament_runs mr
        where mr.tournament_id=x.id
          and mr.managed_player_id in (
            select cs.managed_player_id
            from public.career_state cs
            where cs.id='demo' and cs.managed_player_id is not null
            union
            select ar.player_id
            from public.academy_roster ar
            where ar.status='active'
              and ar.player_id is not null
              and ar.source_youth_id is null
          )
      )
    order by
      date_trunc('week',x.start_date::timestamp),
      case
        when x.category='Grand Chelem' then 100
        when x.category='Masters 1000' then 90
        when x.category='ATP 500' then 80
        when x.category='ATP 250' then 70
        when x.category='Challenger 175' then 60
        when x.category='Challenger 125' then 55
        when x.category='Challenger 100' then 50
        when x.category='Challenger 75' then 45
        when x.category='Challenger 50' then 40
        when x.category='M25' then 30
        when x.category='M15' then 25
        else 10 end desc,
      coalesce(x.end_date,x.start_date),x.id
    limit 160
  loop
    select * into r
    from public.tournament_format_rules fr
    where fr.circuit=t.circuit
      and fr.category=t.category
      and fr.main_draw_size=coalesce(t.singles_draw_size,t.draw_size)
    limit 1;

    if r.rule_key is null then
      v_skipped:=v_skipped+1;
      continue;
    end if;

    if t.category='ATP Finals' then
      perform public.refresh_world_race(coalesce(t.start_date,t.end_date,p_to_date));
    elsif t.category='Next Gen Finals' then
      perform public.refresh_world_nextgen_race(coalesce(t.start_date,t.end_date,p_to_date));
    end if;

    if r.format_type='knockout' then
      perform public.simulate_world_qualifying_full(
        t.id,coalesce(t.qualifying_end_date,t.start_date,p_to_date)
      );
      v_result:=public.simulate_world_knockout_tournament_full(
        t.id,coalesce(t.end_date,t.start_date,p_to_date)
      );
    elsif r.format_type='round_robin' then
      v_result:=public.simulate_world_round_robin_tournament_full(
        t.id,coalesce(t.end_date,t.start_date,p_to_date)
      );
    else
      v_result:=jsonb_build_object('skipped','unsupported_format');
    end if;

    if v_result->>'ok'='true' then
      v_simulated:=v_simulated+1;
      v_matches:=v_matches+coalesce((v_result->>'matches')::int,0);
      v_participants:=v_participants+coalesce((v_result->>'participants')::int,0);
      if r.format_type='knockout' then v_knockout:=v_knockout+1; end if;
      if r.format_type='round_robin' then v_round_robin:=v_round_robin+1; end if;
    else
      v_skipped:=v_skipped+1;
    end if;
  end loop;

  v_rank:=public.refresh_world_rankings(p_to_date);
  v_race:=public.refresh_world_race(p_to_date);
  v_nextgen:=public.refresh_world_nextgen_race(p_to_date);

  return jsonb_build_object(
    'tournaments_simulated',v_simulated,
    'knockout_simulated',v_knockout,
    'round_robin_simulated',v_round_robin,
    'skipped',v_skipped,
    'matches_simulated',v_matches,
    'participants_processed',v_participants,
    'from',p_from_date,'to',p_to_date,
    'ranking_model','52-week ledger full-draw',
    'race_model','calendar-year full-draw',
    'match_model','CB-MATCH-v4-FULLDRAW',
    'ranking_refresh',v_rank,'race_refresh',v_race,'nextgen_refresh',v_nextgen
  );
end;
$function$;
