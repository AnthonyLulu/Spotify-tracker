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
    left join player_season_plans plan on plan.player_id=p.id
    left join player_psychology_state ps on ps.player_id=p.id and plan.season=extract(year from t.start_date)::int
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
    left join player_season_plans plan on plan.player_id=p.id
    left join player_psychology_state ps on ps.player_id=p.id and plan.season=extract(year from t.start_date)::int
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

    update players p
    set points=greatest(0,p.points+wpts),
        form=least(100,p.form+4),
        morale=least(100,p.morale+4+
          case when wpts>=1000 then greatest(0,(coalesce(dp.important_matches,10)-10)/4) else 0 end),
        fatigue=least(100,p.fatigue+8)
    from player_development_profiles dp
    where p.id=w.id and dp.player_id=p.id;

    update players p
    set points=greatest(0,p.points+fpts),
        form=least(100,p.form+2),
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

  return jsonb_build_object(
    'tournaments_simulated',simulated,
    'from',p_from_date,
    'to',p_to_date,
    'ai_schedule_model','ranking band + prestige + fatigue + overlap + surface + personality'
  );
end;
$function$
