CREATE OR REPLACE FUNCTION public.refresh_world_rankings(p_date date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_date date:=coalesce(p_date,current_date);
  v_managed bigint;
  v_updated int:=0;
  v_leader text;
begin
  perform pg_advisory_xact_lock(94832021);
  select managed_player_id into v_managed
  from public.career_state
  where id='demo';

  update public.world_ranking_points
  set active=false
  where active=true and expiry_date<v_date;

  with totals as (
    select
      p.id,
      greatest(0,round(
        coalesce(b.baseline_points,0) *
        case
          when b.player_id is null then 0
          when v_date<=b.snapshot_date then 1
          when v_date>=b.expiry_date then 0
          else (b.expiry_date-v_date)::numeric /
               greatest(1,(b.expiry_date-b.snapshot_date)::numeric)
        end
      )::int) as baseline_remaining,
      coalesce(sum(w.points) filter(where w.active=true and w.earned_date<=v_date and w.expiry_date>=v_date),0)::int as game_points
    from public.players p
    left join public.world_ranking_baseline_decay b on b.player_id=p.id
    left join public.world_ranking_points w on w.player_id=p.id
    where p.ranking_current=true
      and p.id is distinct from v_managed
    group by p.id,b.player_id,b.baseline_points,b.snapshot_date,b.expiry_date
  )
  update public.players p
  set points=greatest(0,t.baseline_remaining+t.game_points),
      ranking_source='Court Boss 52-week world ledger'
  from totals t
  where p.id=t.id;

  get diagnostics v_updated=row_count;

  with ranked as (
    select id,row_number() over(
      order by points desc,current_ability desc,form desc,id
    )::int as new_rank
    from public.players
    where ranking_current=true
  )
  update public.players p
  set ranking=r.new_rank
  from ranked r
  where p.id=r.id;

  insert into public.ranking_history(player_id,snapshot_date,ranking,points)
  select id,v_date,ranking,points
  from public.players
  where ranking_current=true
  on conflict do nothing;

  select name into v_leader
  from public.players
  where ranking_current=true
  order by ranking
  limit 1;

  return jsonb_build_object(
    'date',v_date,
    'updated_players',v_updated,
    'leader',v_leader,
    'model','52-week ledger · decaying 2025 baseline + simulated results'
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.simulate_world_tournaments(p_from_date date, p_to_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  t record;
  w players%rowtype;
  f players%rowtype;
  wpts int;
  fpts int;
  simulated int:=0;
  cat text;
  cut_rank int;
  v_match jsonb;
  v_prob numeric;
  v_tmp players%rowtype;
  v_best_of int;
begin
  perform pg_advisory_xact_lock(94832021);
  for t in
    select *
    from tournaments
    where singles=true
      and coalesce(is_active,true)=true
      and coalesce(end_date,start_date)>p_from_date
      and coalesce(end_date,start_date)<=p_to_date
      and coalesce(circuit,'') not in ('NCAA','Junior')
      and coalesce(category,'') not in ('United Cup','Laver Cup')
      and not exists(select 1 from world_tournament_simulations s where s.tournament_id=tournaments.id)
    order by coalesce(end_date,start_date),id
    limit 60
  loop
    cat:=coalesce(t.category,t.level,'');
    wpts:=case
      when cat ilike '%Grand%Chelem%' or cat ilike '%Grand Slam%' then 2000
      when cat ilike '%ATP Finals%' then 1500
      when cat ilike '%Masters 1000%' then 1000
      when cat ilike '%ATP 500%' then 500
      when cat ilike '%ATP 250%' then 250
      when cat ilike '%Challenger 175%' then 175
      when cat ilike '%Challenger 125%' then 125
      when cat ilike '%Challenger 100%' then 100
      when cat ilike '%Challenger 75%' then 75
      when cat ilike '%Challenger 50%' then 50
      when cat ilike '%M25%' then 25
      when cat ilike '%M15%' then 15
      else 50
    end;
    fpts:=greatest(1,round(wpts*.6)::int);
    cut_rank:=case when cat ilike '%ATP Finals%' then 8 else greatest(32,coalesce(t.qual_cut,t.direct_cut,
      case when wpts>=1000 then 180 when wpts>=500 then 260 when wpts>=250 then 360
           when wpts>=125 then 500 when wpts>=75 then 850 else 1600 end)) end;

    select p.* into w
    from players p
    left join player_attributes a on a.player_id=p.id
    left join player_development_profiles dp on dp.player_id=p.id
    left join player_tactical_preferences tp on tp.player_id=p.id
    left join player_season_plans plan on plan.player_id=p.id and plan.season=extract(year from t.start_date)::int
    left join player_psychology_state ps on ps.player_id=p.id
    where p.ranking_current=true
      and p.ranking<=cut_rank
      and p.injury_status='Fit'
      and coalesce(p.fitness,90)>=52
      and coalesce(p.fatigue,20)<=86
      and p.slug<>'anthony-demo'
      and coalesce(p.career_focus,'mixed')<>'doubles_only'
      and (
        wpts>=250
        or (wpts=175 and p.ranking>=22)
        or (wpts=125 and p.ranking>=35)
        or (wpts=100 and p.ranking>=50)
        or (wpts=75 and p.ranking>=70)
        or (wpts=50 and p.ranking>=95)
        or (wpts=25 and p.ranking>=175)
        or (wpts=15 and p.ranking>=250)
      )
      and not (
        wpts<250 and p.ranking<=30
      )
      and not exists(
        select 1
        from world_tournament_simulations s
        join tournaments ot on ot.id=s.tournament_id
        where (s.winner_id=p.id or s.finalist_id=p.id)
          and daterange(ot.start_date,coalesce(ot.end_date,ot.start_date),'[]')
              && daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
      )
      and (
        wpts>=1000
        or coalesce(p.fatigue,20)<=coalesce(plan.rest_trigger_fatigue,70)
        or mod(abs(hashtext('entry|'||p.id::text||'|'||t.id::text)),100)
           < greatest(6,
        48-coalesce(p.fatigue,20)/2
        +coalesce(dp.ambition,10)
        +(coalesce(ps.motivation,60)-60)/4.0
        -(coalesce(ps.burnout,10)-10)/5.0
        -(coalesce(ps.pressure_load,20)-20)/10.0
        +coalesce(ps.hot_streak,0)/12.0
        -coalesce(ps.slump,0)/10.0
        +coalesce(plan.travel_tolerance,10)/3
        -coalesce(plan.rest_bias,10)/2
        +case
           when coalesce(plan.preferred_surface,'')=
             case when t.surface ilike 'Terre%' then 'Terre' when t.surface ilike 'Gazon%' then 'Gazon' else 'Dur' end
             then 9
           when coalesce(plan.secondary_surface,'')=
             case when t.surface ilike 'Terre%' then 'Terre' when t.surface ilike 'Gazon%' then 'Gazon' else 'Dur' end
             then 3
           else 0
         end
        +case when wpts>=500 then (coalesce(plan.prestige_bias,10)-10)/2
              else (coalesce(plan.development_bias,10)-10)/3 end
      )
      )
    order by (
      p.current_ability*.47+
      p.form*.11+
      p.fitness*.055-
      p.fatigue*.065+
      case
        when t.surface ilike 'Terre%' then coalesce(a.clay_affinity,10)*.60 + coalesce(tp.rally_length_preference,10)*.08
        when t.surface ilike 'Gazon%' then coalesce(a.grass_affinity,10)*.60 + coalesce(tp.serve_plus_one_bias,10)*.10 + coalesce(tp.net_frequency,10)*.06
        else coalesce(a.hard_affinity,10)*.60 + coalesce(tp.pace_preference,10)*.06 + coalesce(tp.defense_to_attack_bias,10)*.05
      end+
      coalesce(a.decision_making,a.tactics,10)*.20+
      coalesce(a.shot_selection,a.tactics,10)*.15+
      coalesce(a.consistency,a.concentration,10)*.20+
      coalesce(a.big_points,a.composure,10)*.12+
      coalesce(a.killer_instinct,a.fighting_spirit,10)*.09+
      coalesce(a.court_positioning,a.tactics,10)*.08+
      coalesce(dp.ambition,10)*.035+
      coalesce(dp.competitive_drive,10)*.045+
      case when wpts>=1000 then (coalesce(dp.important_matches,10)-10)*.22 else 0 end+
      case when wpts>=500 then (coalesce(dp.pressure,10)-10)*.08 else 0 end+
      case when p.career_focus in ('singles_priority','singles_only') then 1.3 else 0 end+
      case
        when coalesce(plan.preferred_surface,'')=
          case when t.surface ilike 'Terre%' then 'Terre' when t.surface ilike 'Gazon%' then 'Gazon' else 'Dur' end
          then 1.5
        when coalesce(plan.secondary_surface,'')=
          case when t.surface ilike 'Terre%' then 'Terre' when t.surface ilike 'Gazon%' then 'Gazon' else 'Dur' end
          then .6
        else 0
      end+
      case when wpts>=500 then (coalesce(plan.prestige_bias,10)-10)*.08
           else (coalesce(plan.development_bias,10)-10)*.05 end+
      coalesce(public.player_psychology_modifier(p.id),0)*.75+random()*7
    ) desc
    limit 1;

    if w.id is null then continue; end if;

    select p.* into f
    from players p
    left join player_attributes a on a.player_id=p.id
    left join player_development_profiles dp on dp.player_id=p.id
    left join player_tactical_preferences tp on tp.player_id=p.id
    left join player_season_plans plan on plan.player_id=p.id and plan.season=extract(year from t.start_date)::int
    left join player_psychology_state ps on ps.player_id=p.id
    where p.ranking_current=true
      and p.ranking<=cut_rank
      and p.injury_status='Fit'
      and coalesce(p.fitness,90)>=52
      and coalesce(p.fatigue,20)<=86
      and p.id<>w.id
      and p.slug<>'anthony-demo'
      and coalesce(p.career_focus,'mixed')<>'doubles_only'
      and (
        wpts>=250
        or (wpts=175 and p.ranking>=22)
        or (wpts=125 and p.ranking>=35)
        or (wpts=100 and p.ranking>=50)
        or (wpts=75 and p.ranking>=70)
        or (wpts=50 and p.ranking>=95)
        or (wpts=25 and p.ranking>=175)
        or (wpts=15 and p.ranking>=250)
      )
      and not (wpts<250 and p.ranking<=30)
      and not exists(
        select 1
        from world_tournament_simulations s
        join tournaments ot on ot.id=s.tournament_id
        where (s.winner_id=p.id or s.finalist_id=p.id)
          and daterange(ot.start_date,coalesce(ot.end_date,ot.start_date),'[]')
              && daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
      )
      and (
        wpts>=1000
        or coalesce(p.fatigue,20)<=coalesce(plan.rest_trigger_fatigue,70)
        or mod(abs(hashtext('entry|'||p.id::text||'|'||t.id::text)),100)
           < greatest(6,
        48-coalesce(p.fatigue,20)/2
        +coalesce(dp.ambition,10)
        +(coalesce(ps.motivation,60)-60)/4.0
        -(coalesce(ps.burnout,10)-10)/5.0
        -(coalesce(ps.pressure_load,20)-20)/10.0
        +coalesce(ps.hot_streak,0)/12.0
        -coalesce(ps.slump,0)/10.0
        +coalesce(plan.travel_tolerance,10)/3
        -coalesce(plan.rest_bias,10)/2
        +case
           when coalesce(plan.preferred_surface,'')=
             case when t.surface ilike 'Terre%' then 'Terre' when t.surface ilike 'Gazon%' then 'Gazon' else 'Dur' end
             then 9
           when coalesce(plan.secondary_surface,'')=
             case when t.surface ilike 'Terre%' then 'Terre' when t.surface ilike 'Gazon%' then 'Gazon' else 'Dur' end
             then 3
           else 0
         end
        +case when wpts>=500 then (coalesce(plan.prestige_bias,10)-10)/2
              else (coalesce(plan.development_bias,10)-10)/3 end
      )
      )
    order by (
      p.current_ability*.47+
      p.form*.11+
      p.fitness*.055-
      p.fatigue*.065+
      case
        when t.surface ilike 'Terre%' then coalesce(a.clay_affinity,10)*.60 + coalesce(tp.rally_length_preference,10)*.08
        when t.surface ilike 'Gazon%' then coalesce(a.grass_affinity,10)*.60 + coalesce(tp.serve_plus_one_bias,10)*.10 + coalesce(tp.net_frequency,10)*.06
        else coalesce(a.hard_affinity,10)*.60 + coalesce(tp.pace_preference,10)*.06 + coalesce(tp.defense_to_attack_bias,10)*.05
      end+
      coalesce(a.decision_making,a.tactics,10)*.20+
      coalesce(a.shot_selection,a.tactics,10)*.15+
      coalesce(a.consistency,a.concentration,10)*.20+
      coalesce(a.big_points,a.composure,10)*.12+
      coalesce(a.killer_instinct,a.fighting_spirit,10)*.09+
      coalesce(a.court_positioning,a.tactics,10)*.08+
      coalesce(dp.ambition,10)*.035+
      coalesce(dp.competitive_drive,10)*.045+
      case when wpts>=1000 then (coalesce(dp.important_matches,10)-10)*.22 else 0 end+
      case when wpts>=500 then (coalesce(dp.pressure,10)-10)*.08 else 0 end+
      case when p.career_focus in ('singles_priority','singles_only') then 1.3 else 0 end+
      case
        when coalesce(plan.preferred_surface,'')=
          case when t.surface ilike 'Terre%' then 'Terre' when t.surface ilike 'Gazon%' then 'Gazon' else 'Dur' end
          then 1.5
        when coalesce(plan.secondary_surface,'')=
          case when t.surface ilike 'Terre%' then 'Terre' when t.surface ilike 'Gazon%' then 'Gazon' else 'Dur' end
          then .6
        else 0
      end+
      case when wpts>=500 then (coalesce(plan.prestige_bias,10)-10)*.08
           else (coalesce(plan.development_bias,10)-10)*.05 end+
      coalesce(public.player_psychology_modifier(p.id),0)*.75+random()*7
    ) desc
    limit 1;

    if f.id is null then continue; end if;

    v_best_of:=case
      when coalesce(t.circuit,'')='ATP'
       and (cat ilike '%Grand Chelem%' or cat ilike '%Grand Slam%')
      then 5 else 3 end;

    v_match:=public.player_matchup_probability_v4(
      w.id,f.id,t.surface,coalesce(t.end_date,t.start_date),
      coalesce(t.court_speed,case when t.surface ilike 'Terre%' then .68 when t.surface ilike 'Gazon%' then 1.15 when t.indoor then 1.18 else 1.0 end),
      v_best_of
    );
    v_prob:=coalesce((v_match->>'player_a_probability')::numeric,.5);

    if random()>v_prob then
      v_tmp:=w;
      w:=f;
      f:=v_tmp;
      v_match:=public.player_matchup_probability_v4(
        w.id,f.id,t.surface,coalesce(t.end_date,t.start_date),
        coalesce(t.court_speed,case when t.surface ilike 'Terre%' then .68 when t.surface ilike 'Gazon%' then 1.15 when t.indoor then 1.18 else 1.0 end),
        v_best_of
      );
      v_prob:=coalesce((v_match->>'player_a_probability')::numeric,.5);
    end if;

    perform public.update_h2h_after_match(
      w.id,f.id,t.surface,coalesce(t.end_date,t.start_date),false,
      'Court Boss world tournament final · CB-MATCH-v4'
    );
    perform public.update_player_elo_after_match(
      w.id,f.id,t.surface,coalesce(t.end_date,t.start_date),false,
      case when wpts>=2000 then 1.15 when wpts>=1000 then 1.10 when wpts>=500 then 1.05 else 1.0 end
    );

    update player_dynamic_ratings d
    set overall_elo=e.overall_elo,
        hard_elo=e.hard_elo,
        clay_elo=e.clay_elo,
        grass_elo=e.grass_elo,
        rating_confidence=greatest(d.rating_confidence,e.confidence),
        last_competitive_match=coalesce(t.end_date,t.start_date),
        source_label='Court Boss live hybrid Elo · world tournament learning',
        updated_at=now()
    from player_elo_ratings e
    where e.player_id=d.player_id and d.player_id in (w.id,f.id);

    insert into world_tournament_simulations(
      tournament_id,winner_id,finalist_id,winner_points,finalist_points,simulated_on,
      final_win_probability,court_speed,model_version,matchup_components
    )
    values(
      t.id,w.id,f.id,wpts,fpts,p_to_date,
      v_prob,
      coalesce(t.court_speed,case when t.surface ilike 'Terre%' then .68 when t.surface ilike 'Gazon%' then 1.15 when t.indoor then 1.18 else 1.0 end),
      'CB-MATCH-v4',
      coalesce(v_match->'components','{}'::jsonb)
    );

    insert into public.world_ranking_points(
      player_id,tournament_id,label,earned_date,expiry_date,points,active,source_label
    )
    values(
      w.id,t.id,t.name,coalesce(t.end_date,t.start_date),
      coalesce(t.end_date,t.start_date)+364,wpts,true,'Court Boss world tournament winner'
    )
    on conflict(player_id,tournament_id) do update set
      label=excluded.label,earned_date=excluded.earned_date,expiry_date=excluded.expiry_date,
      points=excluded.points,active=true,source_label=excluded.source_label;

    update players p
    set form=least(100,p.form+4),
        morale=least(100,p.morale+4+
          case when wpts>=1000 then greatest(0,(coalesce(dp.important_matches,10)-10)/4) else 0 end),
        fatigue=least(100,p.fatigue+8)
    from player_development_profiles dp
    where p.id=w.id and dp.player_id=p.id;

    insert into public.world_ranking_points(
      player_id,tournament_id,label,earned_date,expiry_date,points,active,source_label
    )
    values(
      f.id,t.id,t.name,coalesce(t.end_date,t.start_date),
      coalesce(t.end_date,t.start_date)+364,fpts,true,'Court Boss world tournament finalist'
    )
    on conflict(player_id,tournament_id) do update set
      label=excluded.label,earned_date=excluded.earned_date,expiry_date=excluded.expiry_date,
      points=excluded.points,active=true,source_label=excluded.source_label;

    update players p
    set form=least(100,p.form+2),
        morale=greatest(0,least(100,p.morale+2+
          case when coalesce(dp.resilience,10)>=16 then 1 else 0 end)),
        fatigue=least(100,p.fatigue+7)
    from player_development_profiles dp
    where p.id=f.id and dp.player_id=p.id;

    insert into player_titles(player_id,tournament_name,title_date,level,surface,event_type,verified,source_label,origin)
    values(w.id,t.name,coalesce(t.end_date,t.start_date),cat,t.surface,'singles',false,'Court Boss world simulation','game');

    insert into player_final_results(
      player_id,tournament_name,final_date,level,surface,result,opponent_name,source
    )
    values
      (w.id,t.name,coalesce(t.end_date,t.start_date),cat,t.surface,'Champion',f.name,'Court Boss simulation'),
      (f.id,t.name,coalesce(t.end_date,t.start_date),cat,t.surface,'Finaliste',w.name,'Court Boss simulation');

    simulated:=simulated+1;
  end loop;

  perform public.refresh_world_rankings(p_to_date);

  return jsonb_build_object(
    'tournaments_simulated',simulated,
    'from',p_from_date,
    'to',p_to_date,
    'ai_schedule_model','ranking band + prestige + fatigue + overlap + surface + personality',
    'ranking_model','52-week ledger'
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.simulate_world_week(p_week integer, p_snapshot_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  affected_count int;
  leader_name text;
  leader_rank int;
begin
  perform pg_advisory_xact_lock(94832021);
  if p_snapshot_date<=date '2025-12-01' then
    return jsonb_build_object('updated_players',0,'historical_cutoff',true);
  end if;
  perform public.refresh_player_simulation_ages(p_snapshot_date);
  update players
  set
    age = case
      when birth_date is not null then extract(year from age(p_snapshot_date,birth_date))::int
      else age
    end,
    form = greatest(35, least(99, form + (((id + p_week * 7) % 7)::int - 3))),
    fatigue = greatest(0, least(95, fatigue + (((id * 3 + p_week * 5) % 9)::int - 4))),
    morale = greatest(35, least(99, morale + (((id * 5 + p_week * 11) % 7)::int - 3)))
  where ranking_current = true;

  get diagnostics affected_count = row_count;

  perform public.refresh_world_rankings(p_snapshot_date);

  select name,ranking into leader_name,leader_rank
  from players
  where ranking_current=true
  order by ranking
  limit 1;

  return jsonb_build_object(
    'updated_players',affected_count,
    'leader',leader_name,
    'leader_rank',leader_rank,
    'snapshot_date',p_snapshot_date,
    'ranking_model','52-week ledger · no random point drift'
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.recalculate_user_ranking(p_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE total_points int; new_rank int; managed_id bigint;
BEGIN
  perform pg_advisory_xact_lock(94832021);
  SELECT managed_player_id INTO managed_id FROM career_state WHERE id='demo';
  IF managed_id IS NULL THEN RAISE EXCEPTION 'Managed player missing'; END IF;
  UPDATE user_ranking_points SET active=false
    WHERE owner_id='demo' AND active=true AND expiry_date < p_date;
  SELECT coalesce(sum(points),0)::int INTO total_points FROM user_ranking_points
    WHERE owner_id='demo' AND active=true;
  UPDATE players SET points=total_points WHERE id=managed_id;
  WITH ranked AS (
    SELECT id,row_number() OVER(ORDER BY points DESC,current_ability DESC,form DESC,id)::int AS new_rank
    FROM players WHERE ranking_current=true
  ) UPDATE players p SET ranking=r.new_rank FROM ranked r WHERE p.id=r.id;
  SELECT ranking INTO new_rank FROM players WHERE id=managed_id;
  UPDATE career_state SET points=total_points,singles_rank=new_rank,
    career_date=p_date,updated_at=now() WHERE id='demo';
  INSERT INTO ranking_history(player_id,snapshot_date,ranking,points)
    VALUES(managed_id,p_date,new_rank,total_points) ON CONFLICT DO NOTHING;
  RETURN jsonb_build_object('points',total_points,'rank',new_rank,'date',p_date,'player_id',managed_id);
END $function$
;

CREATE OR REPLACE FUNCTION public.recalculate_user_doubles_ranking(p_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  total_points int;
  new_rank int;
  managed_id bigint;
  v_focus text;
  v_public_rank int;
begin
  perform pg_advisory_xact_lock(94832021);
  select managed_player_id,coalesce(career_focus,'mixed')
  into managed_id,v_focus
  from career_state
  where id='demo';

  if managed_id is null then raise exception 'Managed player missing'; end if;

  update user_doubles_points
  set active=false
  where owner_id='demo' and active=true and expiry_date < p_date;

  select coalesce(sum(points),0)::int into total_points
  from user_doubles_points
  where owner_id='demo' and active=true;

  new_rank:=case
    when total_points<=0 then 3000
    else greatest(1,least(3000,round(2800.0/(1.0+total_points/45.0))::int))
  end;

  update career_state
  set doubles_points=total_points,doubles_rank=new_rank,updated_at=now()
  where id='demo';

  if v_focus='singles_only' and total_points<=0 then
    update players
    set doubles_ranking=null,
        doubles_points=0,
        doubles_snapshot_date=p_date,
        doubles_source='Court Boss · simple exclusivement · non classé double'
    where id=managed_id;
    v_public_rank:=null;
  else
    update players
    set doubles_ranking=new_rank,
        doubles_points=total_points,
        doubles_snapshot_date=p_date,
        doubles_source='Court Boss career save'
    where id=managed_id;
    v_public_rank:=new_rank;
  end if;

  return jsonb_build_object(
    'points',total_points,
    'rank',v_public_rank,
    'internal_rank',new_rank,
    'active',not (v_focus='singles_only' and total_points<=0),
    'career_focus',v_focus,
    'date',p_date,
    'player_id',managed_id
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.simulate_world_doubles_tournaments(p_from_date date, p_to_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  t record;
  wp record;
  fp record;
  wa players%rowtype;
  wb players%rowtype;
  fa players%rowtype;
  fb players%rowtype;
  v_year int;
  v_managed bigint;
  v_wpts int;
  v_fpts int;
  v_draw int;
  v_rounds int;
  v_simulated int:=0;
  v_seeded boolean:=false;
  v_title_a bigint;
  v_title_b bigint;
  v_pair_match jsonb;
  v_pair_prob numeric:=.5;
  v_pair_tmp record;
begin
  perform pg_advisory_xact_lock(94832021);
  if p_to_date<=date '2025-12-01' then
    return jsonb_build_object(
      'tournaments_simulated',0,
      'from',p_from_date,
      'to',p_to_date,
      'historical_cutoff',true
    );
  end if;

  select managed_player_id into v_managed
  from career_state
  where id='demo';

  for t in
    select *
    from tournaments
    where doubles=true
      and coalesce(is_active,true)=true
      and coalesce(end_date,start_date)>greatest(p_from_date,date '2025-12-01')
      and coalesce(end_date,start_date)<=p_to_date
      and coalesce(circuit,'') not in ('NCAA','Junior','Federation')
      and coalesce(category,'') not in ('United Cup','Laver Cup')
      and not exists(
        select 1
        from world_doubles_tournament_simulations s
        where s.tournament_id=tournaments.id
      )
    order by coalesce(end_date,start_date),id
    limit 80
  loop
    v_year:=extract(year from coalesce(t.end_date,t.start_date))::int;

    if not exists(
      select 1
      from world_doubles_partnerships
      where season=v_year and active=true
    ) then
      perform refresh_world_doubles_partnerships(coalesce(t.end_date,t.start_date),2000);
      v_seeded:=true;
    end if;

    v_wpts:=coalesce(
      nullif(t.winner_points,0),
      case
        when coalesce(t.category,t.level,'') ilike '%Grand%Chelem%'
          or coalesce(t.category,t.level,'') ilike '%Grand Slam%' then 2000
        when coalesce(t.category,t.level,'') ilike '%ATP Finals%' then 1500
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
    v_fpts:=greatest(1,round(v_wpts*.60)::int);
    v_draw:=greatest(4,least(64,coalesce(t.doubles_draw_size,16)));
    v_rounds:=greatest(2,ceil(ln(v_draw::numeric)/ln(2::numeric))::int);

    select
      w.*,
      (
        w.pair_strength*.30
        +w.chemistry*.16
        +w.compatibility*.14
        +least(20,coalesce(pa.doubles,10))*.18
        +least(20,coalesce(pb.doubles,10))*.18
        +least(20,coalesce(pa.net_positioning,pa.volley,10))*.10
        +least(20,coalesce(pb.net_positioning,pb.volley,10))*.10
        +least(20,coalesce(pa.doubles_communication,pa.doubles,10))*.09
        +least(20,coalesce(pb.doubles_communication,pb.doubles,10))*.09
        +least(20,coalesce(pa.big_points,pa.composure,10))*.06
        +least(20,coalesce(pb.big_points,pb.composure,10))*.06
        +coalesce(ama.serve_rating,50)*.025
        +coalesce(amb.serve_rating,50)*.025
        +coalesce(ama.return_rating,50)*.035
        +coalesce(amb.return_rating,50)*.035
        +(coalesce(era.doubles_elo,1500)+coalesce(erb.doubles_elo,1500)-3000)*.020
        +case when a.career_focus='doubles_only' then 4.0 when a.career_focus='mixed' then 1.0 else 0 end
        +case when b.career_focus='doubles_only' then 4.0 when b.career_focus='mixed' then 1.0 else 0 end
        +(coalesce(plana.doubles_bias,10)+coalesce(planb.doubles_bias,10)-20)*.12
        +case
           when coalesce(plana.preferred_surface,'')=
             case when t.surface ilike 'Terre%' then 'Terre' when t.surface ilike 'Gazon%' then 'Gazon' else 'Dur' end
             then .7 else 0 end
        +case
           when coalesce(planb.preferred_surface,'')=
             case when t.surface ilike 'Terre%' then 'Terre' when t.surface ilike 'Gazon%' then 'Gazon' else 'Dur' end
             then .7 else 0 end
        +coalesce(public.player_psychology_modifier(a.id),0)*.45+
        coalesce(public.player_psychology_modifier(b.id),0)*.45+
        random()*6
      ) as tournament_strength
    into wp
    from world_doubles_partnerships w
    join players a on a.id=w.player_a_id
    join players b on b.id=w.player_b_id
    left join player_attributes pa on pa.player_id=a.id
    left join player_attributes pb on pb.player_id=b.id
    left join player_advanced_metrics ama on ama.player_id=a.id
    left join player_advanced_metrics amb on amb.player_id=b.id
    left join player_elo_ratings era on era.player_id=a.id
    left join player_elo_ratings erb on erb.player_id=b.id
    left join player_season_plans plana on plana.player_id=a.id and plana.season=v_year
    left join player_season_plans planb on planb.player_id=b.id and planb.season=v_year
    where w.season=v_year
      and w.active=true
      and a.career_status='active'
      and b.career_status='active'
      and coalesce(a.career_focus,'mixed')<>'singles_only'
      and coalesce(b.career_focus,'mixed')<>'singles_only'
      and a.injury_status='Fit'
      and b.injury_status='Fit'
      and coalesce(a.fitness,90)>=50
      and coalesce(b.fitness,90)>=50
      and coalesce(a.fatigue,20)<=85
      and coalesce(b.fatigue,20)<=85
      and a.id<>coalesce(v_managed,-1)
      and b.id<>coalesce(v_managed,-1)
      and (
        coalesce(a.doubles_ranking,999999)+coalesce(b.doubles_ranking,999999)
        <=case
          when v_wpts>=1000 then 450
          when v_wpts>=500 then 700
          when v_wpts>=250 then 1100
          when v_wpts>=100 then 1800
          else 3500
        end
        )
      and (
        v_wpts>=250
        or (v_wpts=175 and coalesce(a.doubles_ranking,999999)+coalesce(b.doubles_ranking,999999)>=40)
        or (v_wpts=125 and coalesce(a.doubles_ranking,999999)+coalesce(b.doubles_ranking,999999)>=60)
        or (v_wpts=100 and coalesce(a.doubles_ranking,999999)+coalesce(b.doubles_ranking,999999)>=80)
        or (v_wpts=75 and coalesce(a.doubles_ranking,999999)+coalesce(b.doubles_ranking,999999)>=120)
        or (v_wpts=50 and coalesce(a.doubles_ranking,999999)+coalesce(b.doubles_ranking,999999)>=180)
        or (v_wpts=25 and coalesce(a.doubles_ranking,999999)+coalesce(b.doubles_ranking,999999)>=350)
        or (v_wpts=15 and coalesce(a.doubles_ranking,999999)+coalesce(b.doubles_ranking,999999)>=500)
      )
      and (
        coalesce(t.category,t.level,'') not ilike '%ATP Finals%'
        or coalesce(w.race_rank,999999)<=8
      )
      and not exists(
        select 1
        from world_doubles_tournament_simulations os
        join tournaments ot on ot.id=os.tournament_id
        where (os.winner_pair_id=w.id or os.finalist_pair_id=w.id)
          and daterange(ot.start_date,coalesce(ot.end_date,ot.start_date),'[]')
              && daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
      )
    order by tournament_strength desc,w.id
    limit 1;

    if wp.id is null then continue; end if;

    select
      w.*,
      (
        w.pair_strength*.30
        +w.chemistry*.16
        +w.compatibility*.14
        +least(20,coalesce(pa.doubles,10))*.18
        +least(20,coalesce(pb.doubles,10))*.18
        +least(20,coalesce(pa.net_positioning,pa.volley,10))*.10
        +least(20,coalesce(pb.net_positioning,pb.volley,10))*.10
        +least(20,coalesce(pa.doubles_communication,pa.doubles,10))*.09
        +least(20,coalesce(pb.doubles_communication,pb.doubles,10))*.09
        +least(20,coalesce(pa.big_points,pa.composure,10))*.06
        +least(20,coalesce(pb.big_points,pb.composure,10))*.06
        +coalesce(ama.serve_rating,50)*.025
        +coalesce(amb.serve_rating,50)*.025
        +coalesce(ama.return_rating,50)*.035
        +coalesce(amb.return_rating,50)*.035
        +(coalesce(era.doubles_elo,1500)+coalesce(erb.doubles_elo,1500)-3000)*.020
        +case when a.career_focus='doubles_only' then 4.0 when a.career_focus='mixed' then 1.0 else 0 end
        +case when b.career_focus='doubles_only' then 4.0 when b.career_focus='mixed' then 1.0 else 0 end
        +(coalesce(plana.doubles_bias,10)+coalesce(planb.doubles_bias,10)-20)*.12
        +case
           when coalesce(plana.preferred_surface,'')=
             case when t.surface ilike 'Terre%' then 'Terre' when t.surface ilike 'Gazon%' then 'Gazon' else 'Dur' end
             then .7 else 0 end
        +case
           when coalesce(planb.preferred_surface,'')=
             case when t.surface ilike 'Terre%' then 'Terre' when t.surface ilike 'Gazon%' then 'Gazon' else 'Dur' end
             then .7 else 0 end
        +coalesce(public.player_psychology_modifier(a.id),0)*.45+
        coalesce(public.player_psychology_modifier(b.id),0)*.45+
        random()*6
      ) as tournament_strength
    into fp
    from world_doubles_partnerships w
    join players a on a.id=w.player_a_id
    join players b on b.id=w.player_b_id
    left join player_attributes pa on pa.player_id=a.id
    left join player_attributes pb on pb.player_id=b.id
    left join player_advanced_metrics ama on ama.player_id=a.id
    left join player_advanced_metrics amb on amb.player_id=b.id
    left join player_elo_ratings era on era.player_id=a.id
    left join player_elo_ratings erb on erb.player_id=b.id
    left join player_season_plans plana on plana.player_id=a.id and plana.season=v_year
    left join player_season_plans planb on planb.player_id=b.id and planb.season=v_year
    where w.season=v_year
      and w.active=true
      and w.id<>wp.id
      and a.career_status='active'
      and b.career_status='active'
      and coalesce(a.career_focus,'mixed')<>'singles_only'
      and coalesce(b.career_focus,'mixed')<>'singles_only'
      and a.injury_status='Fit'
      and b.injury_status='Fit'
      and coalesce(a.fitness,90)>=50
      and coalesce(b.fitness,90)>=50
      and coalesce(a.fatigue,20)<=85
      and coalesce(b.fatigue,20)<=85
      and a.id<>coalesce(v_managed,-1)
      and b.id<>coalesce(v_managed,-1)
      and (
        coalesce(a.doubles_ranking,999999)+coalesce(b.doubles_ranking,999999)
        <=case
          when v_wpts>=1000 then 550
          when v_wpts>=500 then 850
          when v_wpts>=250 then 1250
          when v_wpts>=100 then 2000
          else 3800
        end
        )
      and (
        v_wpts>=250
        or (v_wpts=175 and coalesce(a.doubles_ranking,999999)+coalesce(b.doubles_ranking,999999)>=40)
        or (v_wpts=125 and coalesce(a.doubles_ranking,999999)+coalesce(b.doubles_ranking,999999)>=60)
        or (v_wpts=100 and coalesce(a.doubles_ranking,999999)+coalesce(b.doubles_ranking,999999)>=80)
        or (v_wpts=75 and coalesce(a.doubles_ranking,999999)+coalesce(b.doubles_ranking,999999)>=120)
        or (v_wpts=50 and coalesce(a.doubles_ranking,999999)+coalesce(b.doubles_ranking,999999)>=180)
        or (v_wpts=25 and coalesce(a.doubles_ranking,999999)+coalesce(b.doubles_ranking,999999)>=350)
        or (v_wpts=15 and coalesce(a.doubles_ranking,999999)+coalesce(b.doubles_ranking,999999)>=500)
      )
      and (
        coalesce(t.category,t.level,'') not ilike '%ATP Finals%'
        or coalesce(w.race_rank,999999)<=8
      )
      and not exists(
        select 1
        from world_doubles_tournament_simulations os
        join tournaments ot on ot.id=os.tournament_id
        where (os.winner_pair_id=w.id or os.finalist_pair_id=w.id)
          and daterange(ot.start_date,coalesce(ot.end_date,ot.start_date),'[]')
              && daterange(t.start_date,coalesce(t.end_date,t.start_date),'[]')
      )
    order by tournament_strength desc,w.id
    limit 1;

    if fp.id is null then continue; end if;

    v_pair_match:=public.doubles_pair_matchup_v2(
      wp.id,fp.id,t.surface,coalesce(t.end_date,t.start_date)
    );
    v_pair_prob:=coalesce((v_pair_match->>'pair_a_probability')::numeric,.5);

    if random()>v_pair_prob then
      v_pair_tmp:=wp;
      wp:=fp;
      fp:=v_pair_tmp;
      v_pair_prob:=1-v_pair_prob;
    end if;

    select * into wa from players where id=wp.player_a_id;
    select * into wb from players where id=wp.player_b_id;
    select * into fa from players where id=fp.player_a_id;
    select * into fb from players where id=fp.player_b_id;

    insert into world_doubles_tournament_simulations(
      tournament_id,season,winner_pair_id,finalist_pair_id,
      winner_points,finalist_points,draw_size,simulated_on,
      final_win_probability,model_version,matchup_components
    )
    values(
      t.id,v_year,wp.id,fp.id,v_wpts,v_fpts,v_draw,
      coalesce(t.end_date,t.start_date),
      round(v_pair_prob,4),'CB-DOUBLES-v2',coalesce(v_pair_match->'components','{}'::jsonb)
    );

    update world_doubles_partnerships
    set
      matches=matches+v_rounds,
      wins=wins+v_rounds,
      titles=titles+1,
      race_points=race_points+v_wpts,
      last_refresh_date=greatest(last_refresh_date,coalesce(t.end_date,t.start_date))
    where id=wp.id;

    update world_doubles_partnerships
    set
      matches=matches+v_rounds,
      wins=wins+greatest(0,v_rounds-1),
      race_points=race_points+v_fpts,
      last_refresh_date=greatest(last_refresh_date,coalesce(t.end_date,t.start_date))
    where id=fp.id;

    update players
    set
      doubles_points=greatest(0,coalesce(doubles_points,0)+v_wpts),
      doubles_snapshot_date=coalesce(t.end_date,t.start_date),
      doubles_source='Court Boss doubles tournament simulation',
      form=least(100,form+3),
      morale=least(100,morale+4),
      fatigue=least(100,fatigue+6)
    where id in (wp.player_a_id,wp.player_b_id);

    update players
    set
      doubles_points=greatest(0,coalesce(doubles_points,0)+v_fpts),
      doubles_snapshot_date=coalesce(t.end_date,t.start_date),
      doubles_source='Court Boss doubles tournament simulation',
      form=least(100,form+1),
      morale=least(100,morale+2),
      fatigue=least(100,fatigue+5)
    where id in (fp.player_a_id,fp.player_b_id);

    insert into player_titles(
      player_id,tournament_name,title_date,level,surface,event_type,
      partner_player_id,partner_name,verified,source_label,origin,date_precision
    )
    values(
      wa.id,t.name,coalesce(t.end_date,t.start_date),coalesce(t.category,t.level,t.circuit),
      t.surface,'doubles',wb.id,wb.name,false,'Court Boss · double mondial simulé','game','day'
    )
    returning id into v_title_a;
    perform credit_staff_title(v_title_a);

    insert into player_titles(
      player_id,tournament_name,title_date,level,surface,event_type,
      partner_player_id,partner_name,verified,source_label,origin,date_precision
    )
    values(
      wb.id,t.name,coalesce(t.end_date,t.start_date),coalesce(t.category,t.level,t.circuit),
      t.surface,'doubles',wa.id,wa.name,false,'Court Boss · double mondial simulé','game','day'
    )
    returning id into v_title_b;
    perform credit_staff_title(v_title_b);

    insert into player_final_results(
      player_id,tournament_name,final_date,level,surface,result,opponent_name,
      source,event_type,partner_player_id,partner_name
    )
    values
      (
        wa.id,t.name,coalesce(t.end_date,t.start_date),coalesce(t.category,t.level,t.circuit),t.surface,
        'Champion',fa.name||' / '||fb.name,'Court Boss doubles simulation','doubles',wb.id,wb.name
      ),
      (
        wb.id,t.name,coalesce(t.end_date,t.start_date),coalesce(t.category,t.level,t.circuit),t.surface,
        'Champion',fa.name||' / '||fb.name,'Court Boss doubles simulation','doubles',wa.id,wa.name
      ),
      (
        fa.id,t.name,coalesce(t.end_date,t.start_date),coalesce(t.category,t.level,t.circuit),t.surface,
        'Finaliste',wa.name||' / '||wb.name,'Court Boss doubles simulation','doubles',fb.id,fb.name
      ),
      (
        fb.id,t.name,coalesce(t.end_date,t.start_date),coalesce(t.category,t.level,t.circuit),t.surface,
        'Finaliste',wa.name||' / '||wb.name,'Court Boss doubles simulation','doubles',fa.id,fa.name
      );

    perform update_player_elo_after_match(
      wa.id,fa.id,t.surface,coalesce(t.end_date,t.start_date),true,
      case when v_wpts>=2000 then 1.30 when v_wpts>=1000 then 1.15 when v_wpts>=500 then 1.08 else 1 end
    );
    perform update_player_elo_after_match(
      wb.id,fb.id,t.surface,coalesce(t.end_date,t.start_date),true,
      case when v_wpts>=2000 then 1.30 when v_wpts>=1000 then 1.15 when v_wpts>=500 then 1.08 else 1 end
    );

    v_simulated:=v_simulated+1;
  end loop;

  with ranked as (
    select
      p.id,
      row_number() over(
        order by coalesce(p.doubles_points,0) desc,
                 coalesce(pa.doubles,10) desc,
                 coalesce(p.current_ability,50) desc,
                 p.id
      )::int as rr
    from players p
    left join player_attributes pa on pa.player_id=p.id
    where p.career_status='active'
      and coalesce(p.doubles_points,0)>0
      and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
  )
  update players p
  set
    doubles_ranking=r.rr,
    doubles_snapshot_date=p_to_date,
    doubles_source=case
      when p.id=coalesce(v_managed,-1) then p.doubles_source
      else 'Court Boss dynamic doubles season'
    end,
    career_high_doubles_rank=case
      when p.career_high_doubles_rank is null or r.rr<p.career_high_doubles_rank then r.rr
      else p.career_high_doubles_rank
    end,
    career_high_doubles_rank_date=case
      when p.career_high_doubles_rank is null or r.rr<p.career_high_doubles_rank then p_to_date
      else p.career_high_doubles_rank_date
    end,
    career_high_doubles_source=case
      when p.career_high_doubles_rank is null or r.rr<p.career_high_doubles_rank then 'Court Boss simulation'
      else p.career_high_doubles_source
    end
  from ranked r
  where p.id=r.id
    and p.id<>coalesce(v_managed,-1);

  with ranked as (
    select
      id,
      row_number() over(
        order by race_points desc,pair_strength desc,affinity_score desc,id
      )::int as rr
    from world_doubles_partnerships
    where season=extract(year from p_to_date)::int and active=true
  )
  update world_doubles_partnerships w
  set race_rank=r.rr
  from ranked r
  where w.id=r.id;

  return jsonb_build_object(
    'tournaments_simulated',v_simulated,
    'from',p_from_date,
    'to',p_to_date,
    'pairs_seeded',v_seeded,
    'titles_created',v_simulated*2,
    'match_model','CB-DOUBLES-v2'
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.refresh_world_doubles_player_rankings(p_date date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_date date:=coalesce(p_date,current_date);
  v_year int:=extract(year from v_date)::int;
  v_ranked int:=0;
begin
  perform pg_advisory_xact_lock(94832021);
  if v_year<=2025 then
    return jsonb_build_object('date',v_date,'ranked',0,'historical_cutoff',true);
  end if;

  -- Rolling decay of old doubles points so 2025 remains the starting snapshot,
  -- then current-season pair performance gradually takes over.
  update players
  set doubles_points=greatest(0,round(coalesce(doubles_points,0)*.94)::int)
  where career_status='active'
    and doubles_points is not null
    and id<>coalesce((select managed_player_id from career_state where id='demo'),-1)
    and coalesce(data_source,'') not ilike 'hidden duplicate merged into %';

  with members as (
    select w.player_a_id as player_id,w.race_points,w.pair_strength,w.affinity_score
    from world_doubles_partnerships w
    where w.season=v_year and w.active=true
    union all
    select w.player_b_id,w.race_points,w.pair_strength,w.affinity_score
    from world_doubles_partnerships w
    where w.season=v_year and w.active=true
  ),
  ranked_pairs as (
    select m.*,
      row_number() over(
        partition by m.player_id
        order by m.race_points desc,m.pair_strength desc,m.affinity_score desc
      ) as rn
    from members m
  ),
  player_score as (
    select
      rp.player_id,
      round(sum(
        case rp.rn
          when 1 then rp.race_points
          when 2 then rp.race_points*.35
          else rp.race_points*.08
        end
      ))::int as base_points
    from ranked_pairs rp
    where rp.rn<=4
    group by rp.player_id
  )
  update players p
  set
    doubles_points=greatest(
      coalesce(p.doubles_points,0),
      round(
        ps.base_points *
        case p.career_focus
          when 'doubles_only' then 1.12
          when 'singles_priority' then .92
          else 1.00
        end
      )::int
    ),
    doubles_snapshot_date=v_date,
    doubles_source='Court Boss dynamic doubles season'
  from player_score ps
  where p.id=ps.player_id
    and p.career_status='active'
    and p.id<>coalesce((select managed_player_id from career_state where id='demo'),-1);

  with ranked as (
    select
      p.id,
      row_number() over(
        order by coalesce(p.doubles_points,0) desc,
                 coalesce(pa.doubles,10) desc,
                 coalesce(p.current_ability,50) desc,
                 p.id
      )::int as rr
    from players p
    left join player_attributes pa on pa.player_id=p.id
    where p.career_status='active'
      and coalesce(p.doubles_points,0)>0
      and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
  )
  update players p
  set
    doubles_ranking=r.rr,
    doubles_snapshot_date=v_date,
    doubles_source='Court Boss dynamic doubles season',
    career_high_doubles_rank=case
      when p.career_high_doubles_rank is null or r.rr<p.career_high_doubles_rank then r.rr
      else p.career_high_doubles_rank
    end,
    career_high_doubles_rank_date=case
      when p.career_high_doubles_rank is null or r.rr<p.career_high_doubles_rank then v_date
      else p.career_high_doubles_rank_date
    end,
    career_high_doubles_source=case
      when p.career_high_doubles_rank is null or r.rr<p.career_high_doubles_rank then 'Court Boss simulation'
      else p.career_high_doubles_source
    end
  from ranked r
  where p.id=r.id;

  get diagnostics v_ranked=row_count;

  return jsonb_build_object(
    'date',v_date,
    'ranked',v_ranked,
    'doubles_only_ranked',(
      select count(*) from players
      where career_status='active' and career_focus='doubles_only'
        and doubles_ranking is not null
    ),
    'leader',(
      select name from players
      where career_status='active' and doubles_ranking=1
      order by id limit 1
    )
  );
end;
$function$
;
