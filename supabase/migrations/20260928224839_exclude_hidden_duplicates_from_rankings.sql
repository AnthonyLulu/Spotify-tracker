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
      and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
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
      and coalesce(data_source,'') not ilike 'hidden duplicate merged into %'
  )
  update public.players p
  set ranking=r.new_rank
  from ranked r
  where p.id=r.id;

  insert into public.ranking_history(player_id,snapshot_date,ranking,points)
  select id,v_date,ranking,points
  from public.players
  where ranking_current=true
    and coalesce(data_source,'') not ilike 'hidden duplicate merged into %'
  on conflict do nothing;

  select name into v_leader
  from public.players
  where ranking_current=true
    and coalesce(data_source,'') not ilike 'hidden duplicate merged into %'
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
  where ranking_current = true
    and coalesce(data_source,'') not ilike 'hidden duplicate merged into %';

  get diagnostics affected_count = row_count;

  perform public.refresh_world_rankings(p_snapshot_date);

  select name,ranking into leader_name,leader_rank
  from players
  where ranking_current=true
    and coalesce(data_source,'') not ilike 'hidden duplicate merged into %'
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
      and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
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
      and coalesce(p.data_source,'') not ilike 'hidden duplicate merged into %'
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
    FROM players WHERE ranking_current=true AND coalesce(data_source,'') not ilike 'hidden duplicate merged into %'
  ) UPDATE players p SET ranking=r.new_rank FROM ranked r WHERE p.id=r.id;
  SELECT ranking INTO new_rank FROM players WHERE id=managed_id;
  UPDATE career_state SET points=total_points,singles_rank=new_rank,
    career_date=p_date,updated_at=now() WHERE id='demo';
  INSERT INTO ranking_history(player_id,snapshot_date,ranking,points)
    VALUES(managed_id,p_date,new_rank,total_points) ON CONFLICT DO NOTHING;
  RETURN jsonb_build_object('points',total_points,'rank',new_rank,'date',p_date,'player_id',managed_id);
END $function$
;
