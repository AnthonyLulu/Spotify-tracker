-- Canonical managed-run world ranking sync v2.
-- Uses exact format-rule points, credits qualifying rounds, and keeps this
-- service-role-only because it mutates the global ranking ledger.

CREATE OR REPLACE FUNCTION public.populate_world_results_from_tournament_run(p_run_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  r public.tournament_runs%rowtype;
  t public.tournaments%rowtype;
  v_managed bigint;
  v_wpts int;
  v_draw int;
  v_finalist bigint;
  v_final_prob numeric;
  v_final_components jsonb:='{}'::jsonb;
  v_rows int:=0;
begin
  select * into r from public.tournament_runs where id=p_run_id;
  if r.id is null then return jsonb_build_object('error','run_not_found'); end if;
  select * into t from public.tournaments where id=r.tournament_id;
  if t.id is null then return jsonb_build_object('error','tournament_not_found'); end if;

  if coalesce(t.circuit,'')='Junior' then
    return jsonb_build_object('run_id',r.id,'skipped','junior_tournament');
  end if;

  select managed_player_id into v_managed from public.career_state where id='demo';

  if coalesce(t.category,t.level,'') ilike '%ATP Finals%' then
    select
      case when m.winner_id=m.player_a_id then m.player_b_id else m.player_a_id end,
      case
        when m.player_a_win_probability is null then null
        when m.winner_id=m.player_a_id then m.player_a_win_probability
        else 1-m.player_a_win_probability
      end,
      coalesce(m.matchup_components,'{}'::jsonb)
    into v_finalist,v_final_prob,v_final_components
    from public.tournament_draw_matches m
    where m.run_id=r.id and m.round_name='F'
    order by m.id desc
    limit 1;

    delete from public.world_tournament_results where tournament_id=t.id;
    delete from public.world_ranking_points
    where tournament_id=t.id and player_id is distinct from v_managed;

    with participants as (
      select player_a_id player_id from public.tournament_draw_matches where run_id=r.id
      union
      select player_b_id from public.tournament_draw_matches where run_id=r.id
    ),
    scored as (
      select
        p.player_id,
        count(*) filter(
          where m.winner_id=p.player_id and m.round_name like 'Groupe %'
        )::int as rr_wins,
        count(*) filter(
          where m.winner_id=p.player_id and m.round_name='SF'
        )::int as sf_wins,
        count(*) filter(
          where m.winner_id=p.player_id and m.round_name='F'
        )::int as final_wins,
        case
          when p.player_id=r.champion_player_id then 'W'
          when p.player_id=v_finalist then 'F'
          when exists(
            select 1 from public.tournament_draw_matches sx
            where sx.run_id=r.id and sx.round_name='SF'
              and p.player_id in (sx.player_a_id,sx.player_b_id)
          ) then 'SF'
          else 'RR'
        end as round_code
      from participants p
      left join public.tournament_draw_matches m
        on m.run_id=r.id
       and p.player_id in (m.player_a_id,m.player_b_id)
      where p.player_id is not null
      group by p.player_id
    )
    insert into public.world_tournament_results(
      tournament_id,player_id,result_round,points,simulated_on,strength_score,model_version
    )
    select
      t.id,s.player_id,s.round_code,
      s.rr_wins*200+s.sf_wins*400+s.final_wins*500,
      coalesce(t.end_date,t.start_date),null,'CB-ATP-FINALS-v1'
    from scored s
    on conflict(tournament_id,player_id) do update set
      result_round=excluded.result_round,points=excluded.points,
      simulated_on=excluded.simulated_on,model_version=excluded.model_version;

    insert into public.world_ranking_points(
      player_id,tournament_id,label,earned_date,expiry_date,points,active,source_label
    )
    select
      wr.player_id,t.id,t.name,coalesce(t.end_date,t.start_date),
      coalesce(t.end_date,t.start_date)+364,wr.points,true,
      'Court Boss ATP Finals · '||wr.result_round
    from public.world_tournament_results wr
    where wr.tournament_id=t.id
      and wr.player_id is distinct from v_managed
      and wr.points>0
    on conflict(player_id,tournament_id) do update set
      label=excluded.label,earned_date=excluded.earned_date,expiry_date=excluded.expiry_date,
      points=excluded.points,active=true,source_label=excluded.source_label;

    get diagnostics v_rows=row_count;

    if r.champion_player_id is not null and v_finalist is not null then
      insert into public.world_tournament_simulations(
        tournament_id,winner_id,finalist_id,winner_points,finalist_points,simulated_on,
        final_win_probability,court_speed,model_version,matchup_components
      )
      select
        t.id,r.champion_player_id,v_finalist,
        coalesce((select points from public.world_tournament_results where tournament_id=t.id and player_id=r.champion_player_id),0),
        coalesce((select points from public.world_tournament_results where tournament_id=t.id and player_id=v_finalist),0),
        coalesce(t.end_date,t.start_date),v_final_prob,
        coalesce(t.court_speed,case when t.indoor then 1.18 else 1.0 end),
        'CB-ATP-FINALS-v1',v_final_components
      on conflict(tournament_id) do update set
        winner_id=excluded.winner_id,finalist_id=excluded.finalist_id,
        winner_points=excluded.winner_points,finalist_points=excluded.finalist_points,
        simulated_on=excluded.simulated_on,final_win_probability=excluded.final_win_probability,
        court_speed=excluded.court_speed,model_version=excluded.model_version,
        matchup_components=excluded.matchup_components;

      if r.champion_player_id is distinct from v_managed then
        insert into public.player_titles(
          player_id,tournament_name,title_date,level,surface,event_type,verified,source_label,origin
        )
        select
          r.champion_player_id,t.name,coalesce(t.end_date,t.start_date),
          coalesce(t.category,t.level,t.circuit),t.surface,'singles',false,
          'Court Boss ATP Finals · AI champion','game'
        where not exists(
          select 1 from public.player_titles pt
          where pt.player_id=r.champion_player_id
            and pt.tournament_name=t.name
            and pt.title_date=coalesce(t.end_date,t.start_date)
            and pt.event_type='singles'
        );
      end if;
    end if;

    perform public.refresh_world_rankings(coalesce(t.end_date,t.start_date));

    return jsonb_build_object(
      'run_id',r.id,'tournament_id',t.id,'ai_point_rows',v_rows,
      'champion_id',r.champion_player_id,'finalist_id',v_finalist,
      'model','CB-ATP-FINALS-v1'
    );
  end if;
  v_draw:=greatest(16,least(128,coalesce(t.singles_draw_size,t.draw_size,32)));
  v_wpts:=coalesce(nullif(t.winner_points,0),
    case
      when coalesce(t.category,t.level,'') ilike '%Grand%Chelem%' or coalesce(t.category,t.level,'') ilike '%Grand Slam%' then 2000
      when coalesce(t.category,t.level,'') ilike '%Masters 1000%' then 1000
      when coalesce(t.category,t.level,'') ilike '%ATP 500%' then 500
      when coalesce(t.category,t.level,'') ilike '%ATP 250%' then 250
      when coalesce(t.category,t.level,'') ilike '%Challenger 175%' then 175
      when coalesce(t.category,t.level,'') ilike '%Challenger 125%' then 125
      when coalesce(t.category,t.level,'') ilike '%Challenger 100%' then 100
      when coalesce(t.category,t.level,'') ilike '%Challenger 75%' then 75
      when coalesce(t.category,t.level,'') ilike '%Challenger 50%' then 50
      when coalesce(t.category,t.level,'') ilike '%M25%' then 25
      when coalesce(t.category,t.level,'') ilike '%M15%' then 15
      else 50
    end
  );

  delete from public.world_tournament_results where tournament_id=t.id;
  delete from public.world_ranking_points
  where tournament_id=t.id and player_id is distinct from v_managed;

  insert into public.world_tournament_results(
    tournament_id,player_id,result_round,points,simulated_on,strength_score,model_version
  )
  select
    t.id,
    loser_id,
    round_name,
    public.tournament_points_for_result(t.id,round_name,false),
    coalesce(t.end_date,t.start_date),
    null,
    'CB-USER-DRAW-v1'
  from (
    select
      case when m.winner_id=m.player_a_id then m.player_b_id else m.player_a_id end as loser_id,
      m.round_name
    from public.tournament_draw_matches m
    where m.run_id=r.id
      and m.player_a_id is not null
      and m.player_b_id is not null
      and m.winner_id is not null
      and m.round_name in ('R128','R64','R32','R16','QF','SF','F')
  ) x
  where loser_id is not null
  on conflict(tournament_id,player_id) do update set
    result_round=excluded.result_round,
    points=excluded.points,
    simulated_on=excluded.simulated_on,
    model_version=excluded.model_version;

  if r.champion_player_id is not null then
    insert into public.world_tournament_results(
      tournament_id,player_id,result_round,points,simulated_on,strength_score,model_version
    )
    values(
      t.id,r.champion_player_id,'W',
      public.tournament_points_for_result(t.id,'W',false),
      coalesce(t.end_date,t.start_date),null,'CB-USER-DRAW-v1'
    )
    on conflict(tournament_id,player_id) do update set
      result_round='W',points=excluded.points,simulated_on=excluded.simulated_on,model_version=excluded.model_version;
  end if;

  select
    case when m.winner_id=m.player_a_id then m.player_b_id else m.player_a_id end,
    case
      when m.player_a_win_probability is null then null
      when m.winner_id=m.player_a_id then m.player_a_win_probability
      else 1-m.player_a_win_probability
    end,
    coalesce(m.matchup_components,'{}'::jsonb)
  into v_finalist,v_final_prob,v_final_components
  from public.tournament_draw_matches m
  where m.run_id=r.id and m.round_name='F'
  order by m.id desc
  limit 1;

  insert into public.world_ranking_points(
    player_id,tournament_id,label,earned_date,expiry_date,points,active,source_label
  )
  select
    wr.player_id,t.id,t.name,coalesce(t.end_date,t.start_date),
    coalesce(t.end_date,t.start_date)+364,wr.points,true,
    'Court Boss user draw · '||wr.result_round
  from public.world_tournament_results wr
  where wr.tournament_id=t.id
    and wr.player_id is distinct from v_managed
    and wr.points>0
  on conflict(player_id,tournament_id) do update set
    label=excluded.label,earned_date=excluded.earned_date,expiry_date=excluded.expiry_date,
    points=excluded.points,active=true,source_label=excluded.source_label;

  get diagnostics v_rows=row_count;

  if r.champion_player_id is not null and v_finalist is not null then
    insert into public.world_tournament_simulations(
      tournament_id,winner_id,finalist_id,winner_points,finalist_points,simulated_on,
      final_win_probability,court_speed,model_version,matchup_components
    )
    values(
      t.id,r.champion_player_id,v_finalist,
      public.tournament_points_for_result(t.id,'W',false),
      public.tournament_points_for_result(t.id,'F',false),
      coalesce(t.end_date,t.start_date),
      v_final_prob,
      coalesce(t.court_speed,case when t.surface ilike 'Terre%' then .68 when t.surface ilike 'Gazon%' then 1.15 when t.indoor then 1.18 else 1.0 end),
      'CB-USER-DRAW-v1',
      v_final_components
    )
    on conflict(tournament_id) do update set
      winner_id=excluded.winner_id,finalist_id=excluded.finalist_id,
      winner_points=excluded.winner_points,finalist_points=excluded.finalist_points,
      simulated_on=excluded.simulated_on,final_win_probability=excluded.final_win_probability,
      court_speed=excluded.court_speed,model_version=excluded.model_version,
      matchup_components=excluded.matchup_components;
  end if;

  if r.champion_player_id is distinct from v_managed and r.champion_player_id is not null then
    insert into public.player_titles(
      player_id,tournament_name,title_date,level,surface,event_type,verified,source_label,origin
    )
    select
      r.champion_player_id,t.name,coalesce(t.end_date,t.start_date),
      coalesce(t.category,t.level,t.circuit),t.surface,'singles',false,
      'Court Boss user draw · AI champion','game'
    where not exists(
      select 1 from public.player_titles pt
      where pt.player_id=r.champion_player_id
        and pt.tournament_name=t.name
        and pt.title_date=coalesce(t.end_date,t.start_date)
        and pt.event_type='singles'
    );
  end if;

  if r.champion_player_id is not null and v_finalist is not null then
    if r.champion_player_id is distinct from v_managed then
      insert into public.player_final_results(
        player_id,tournament_name,final_date,level,surface,result,opponent_name,source,event_type
      )
      select
        r.champion_player_id,t.name,coalesce(t.end_date,t.start_date),
        coalesce(t.category,t.level,t.circuit),t.surface,'Champion',
        pf.name,'Court Boss user draw','singles'
      from public.players pf
      where pf.id=v_finalist
        and not exists(
          select 1 from public.player_final_results z
          where z.player_id=r.champion_player_id and z.tournament_name=t.name
            and z.final_date=coalesce(t.end_date,t.start_date) and z.event_type='singles'
        );
    end if;
    if v_finalist is distinct from v_managed then
      insert into public.player_final_results(
        player_id,tournament_name,final_date,level,surface,result,opponent_name,source,event_type
      )
      select
        v_finalist,t.name,coalesce(t.end_date,t.start_date),
        coalesce(t.category,t.level,t.circuit),t.surface,'Finaliste',
        pw.name,'Court Boss user draw','singles'
      from public.players pw
      where pw.id=r.champion_player_id
        and not exists(
          select 1 from public.player_final_results z
          where z.player_id=v_finalist and z.tournament_name=t.name
            and z.final_date=coalesce(t.end_date,t.start_date) and z.event_type='singles'
        );
    end if;
  end if;

  -- Qualifying is part of the same canonical run. Credit Q losers with
  -- the exact qualifying table, then add the qualifier bonus to players who
  -- reached the main draw. Managed-player points remain owned by user_ranking_points.
  with q_losses as (
    select
      case when m.winner_id=m.player_a_id then m.player_b_id else m.player_a_id end as player_id,
      m.round_name as result_code
    from public.tournament_draw_matches m
    where m.run_id=r.id
      and m.round_name ~ '^Q[0-9]+$'
      and m.player_a_id is not null
      and m.player_b_id is not null
      and m.winner_id is not null
  )
  insert into public.world_tournament_results(
    tournament_id,player_id,result_round,points,simulated_on,strength_score,model_version
  )
  select
    t.id,q.player_id,q.result_code,
    public.tournament_points_for_result(t.id,q.result_code,false),
    coalesce(t.end_date,t.start_date),null,'CB-USER-DRAW-v2'
  from q_losses q
  where q.player_id is not null
    and q.player_id is distinct from v_managed
    and not exists(
      select 1 from public.world_tournament_results wr
      where wr.tournament_id=t.id and wr.player_id=q.player_id
    )
  on conflict(tournament_id,player_id) do update set
    result_round=excluded.result_round,
    points=excluded.points,
    simulated_on=excluded.simulated_on,
    model_version=excluded.model_version;

  with q_rounds as (
    select max(substring(m.round_name from 2)::int) as last_q_round
    from public.tournament_draw_matches m
    where m.run_id=r.id and m.round_name ~ '^Q[0-9]+$'
  ),
  qualifiers as (
    select distinct m.winner_id as player_id
    from public.tournament_draw_matches m
    cross join q_rounds qr
    where m.run_id=r.id
      and m.round_name=('Q'||qr.last_q_round::text)
      and m.winner_id is not null
  )
  update public.world_tournament_results wr
  set points=public.tournament_points_for_result(t.id,wr.result_round,true),
      model_version='CB-USER-DRAW-v2'
  where wr.tournament_id=t.id
    and wr.player_id is distinct from v_managed
    and exists(select 1 from qualifiers q where q.player_id=wr.player_id);

  insert into public.world_ranking_points(
    player_id,tournament_id,label,earned_date,expiry_date,points,active,source_label
  )
  select
    wr.player_id,t.id,t.name,coalesce(t.end_date,t.start_date),
    coalesce(t.end_date,t.start_date)+364,wr.points,true,
    'Court Boss user draw v2 · '||wr.result_round
  from public.world_tournament_results wr
  where wr.tournament_id=t.id
    and wr.player_id is distinct from v_managed
    and wr.points>0
  on conflict(player_id,tournament_id) do update set
    label=excluded.label,
    earned_date=excluded.earned_date,
    expiry_date=excluded.expiry_date,
    points=excluded.points,
    active=true,
    source_label=excluded.source_label;

  if r.champion_player_id is not null and v_finalist is not null then
    update public.world_tournament_simulations s
    set winner_points=coalesce((
          select wr.points from public.world_tournament_results wr
          where wr.tournament_id=t.id and wr.player_id=r.champion_player_id
        ),s.winner_points),
        finalist_points=coalesce((
          select wr.points from public.world_tournament_results wr
          where wr.tournament_id=t.id and wr.player_id=v_finalist
        ),s.finalist_points),
        model_version='CB-USER-DRAW-v2'
    where s.tournament_id=t.id;
  end if;

  perform public.refresh_world_rankings(coalesce(t.end_date,t.start_date));

  return jsonb_build_object(
    'run_id',r.id,'tournament_id',t.id,'ai_point_rows',v_rows,
    'champion_id',r.champion_player_id,'finalist_id',v_finalist,
    'model','CB-USER-DRAW-v1'
  );
end;
$function$
;

revoke all on function public.populate_world_results_from_tournament_run(bigint) from public;
revoke all on function public.populate_world_results_from_tournament_run(bigint) from anon;
revoke all on function public.populate_world_results_from_tournament_run(bigint) from authenticated;
grant execute on function public.populate_world_results_from_tournament_run(bigint) to service_role;
