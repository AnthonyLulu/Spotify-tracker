-- Court Boss matchup v48: make all five tactical factors symmetrical.
-- Keep the existing v2_core baseline intact except for the three missing
-- mirrored factors. Does not write player history or gameplay saves.
CREATE OR REPLACE FUNCTION public.player_matchup_probability_v2_core(p_a bigint, p_b bigint, p_surface text DEFAULT 'Hard'::text, p_date date DEFAULT CURRENT_DATE, p_court_speed numeric DEFAULT NULL::numeric, p_best_of integer DEFAULT 3)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  a players%rowtype; b players%rowtype;
  aa player_attributes%rowtype; ab player_attributes%rowtype;
  da player_dynamic_ratings%rowtype; dbb player_dynamic_ratings%rowtype;
  ma player_advanced_metrics%rowtype; mb player_advanced_metrics%rowtype;
  sa player_surface_preferences%rowtype; sb player_surface_preferences%rowtype;
  ca player_context_traits%rowtype; cb player_context_traits%rowtype;
  ta player_tactical_preferences%rowtype; tb player_tactical_preferences%rowtype;
  dpa player_development_profiles%rowtype; dpb player_development_profiles%rowtype;
  h player_h2h_records%rowtype;
  surf text:=lower(coalesce(p_surface,'hard'));
  pace numeric:=coalesce(
    p_court_speed,
    case
      when surf like '%clay%' or surf like '%terre%' then .68
      when surf like '%grass%' or surf like '%gazon%' then 1.15
      when surf like '%indoor%' or surf like '%int%' then 1.18
      else 1.0
    end
  );
  aelo numeric; belo numeric; elo_diff numeric; elo_p numeric;
  service_return numeric:=0;
  mental numeric:=0;
  physical numeric:=0;
  surface_fit numeric:=0;
  style_fit numeric:=0;
  tactical_fit numeric:=0;
  context_fit numeric:=0;
  big_match_fit numeric:=0;
  bo5_fit numeric:=0;
  handedness_fit numeric:=0;
  confidence_fit numeric:=0;
  h2h numeric:=0;
  pace_fit numeric:=0;
  logit numeric:=0;
  prob numeric:=.5;
  total_h int:=0; surf_aw int:=0; surf_bw int:=0; surf_n int:=0;
begin
  select * into a from players where id=p_a;
  select * into b from players where id=p_b;
  if a.id is null or b.id is null or a.id=b.id then
    return jsonb_build_object('error','invalid_players');
  end if;

  select * into aa from player_attributes where player_id=p_a;
  select * into ab from player_attributes where player_id=p_b;
  select * into da from player_dynamic_ratings where player_id=p_a;
  select * into dbb from player_dynamic_ratings where player_id=p_b;
  select * into ma from player_advanced_metrics where player_id=p_a;
  select * into mb from player_advanced_metrics where player_id=p_b;
  select * into sa from player_surface_preferences where player_id=p_a;
  select * into sb from player_surface_preferences where player_id=p_b;
  select * into ca from player_context_traits where player_id=p_a;
  select * into cb from player_context_traits where player_id=p_b;
  select * into ta from player_tactical_preferences where player_id=p_a;
  select * into tb from player_tactical_preferences where player_id=p_b;
  select * into dpa from player_development_profiles where player_id=p_a;
  select * into dpb from player_development_profiles where player_id=p_b;
  select * into h
  from player_h2h_records
  where player_a_id=least(p_a,p_b) and player_b_id=greatest(p_a,p_b);

  aelo:=case
    when surf like '%clay%' or surf like '%terre%' then coalesce(da.clay_elo,da.overall_elo,1500)
    when surf like '%grass%' or surf like '%gazon%' then coalesce(da.grass_elo,da.overall_elo,1500)
    else coalesce(da.hard_elo,da.overall_elo,1500)
  end;
  belo:=case
    when surf like '%clay%' or surf like '%terre%' then coalesce(dbb.clay_elo,dbb.overall_elo,1500)
    when surf like '%grass%' or surf like '%gazon%' then coalesce(dbb.grass_elo,dbb.overall_elo,1500)
    else coalesce(dbb.hard_elo,dbb.overall_elo,1500)
  end;

  aelo:=coalesce(da.overall_elo,aelo)*.50+aelo*.50;
  belo:=coalesce(dbb.overall_elo,belo)*.50+belo*.50;
  elo_diff:=aelo-belo;
  elo_p:=1/(1+power(10,(-elo_diff)/400.0));

  service_return:=(
      (coalesce(da.service_rating,50)-coalesce(dbb.return_rating,50))
      -(coalesce(dbb.service_rating,50)-coalesce(da.return_rating,50))
    )/100.0
    +(
      coalesce(aa.first_serve_quality,aa.serve_precision,10)
      +coalesce(aa.second_serve_quality,aa.serve_precision,10)
      +coalesce(aa.serve_plus_one,aa.forehand,10)
      -coalesce(ab.first_serve_quality,ab.serve_precision,10)
      -coalesce(ab.second_serve_quality,ab.serve_precision,10)
      -coalesce(ab.serve_plus_one,ab.forehand,10)
    )/180.0
    +(
      coalesce(aa.return_consistency,aa.return_game,10)
      +coalesce(aa.return_aggression,aa.return_game,10)
      -coalesce(ab.return_consistency,ab.return_game,10)
      -coalesce(ab.return_aggression,ab.return_game,10)
    )/150.0
    +(
      coalesce(aa.serve_spin,10)+coalesce(aa.serve_consistency,10)
      -coalesce(ab.serve_spin,10)-coalesce(ab.serve_consistency,10)
    )/260.0
    +(coalesce(aa.counter_skill,10)-coalesce(ab.counter_skill,10))/150.0;

  mental:=(
      (coalesce(da.pressure_rating,50)+coalesce(da.tactical_rating,50))
      -(coalesce(dbb.pressure_rating,50)+coalesce(dbb.tactical_rating,50))
    )/200.0
    +(
      coalesce(aa.decision_making,aa.tactics,10)
      +coalesce(aa.shot_selection,aa.tactics,10)
      +coalesce(aa.consistency,aa.concentration,10)
      +coalesce(aa.big_points,aa.composure,10)
      -coalesce(ab.decision_making,ab.tactics,10)
      -coalesce(ab.shot_selection,ab.tactics,10)
      -coalesce(ab.consistency,ab.concentration,10)
      -coalesce(ab.big_points,ab.composure,10)
    )/240.0
    +(
      coalesce(aa.shot_control,10)+coalesce(aa.timing,10)+coalesce(aa.tenacity,10)
      -coalesce(ab.shot_control,10)-coalesce(ab.timing,10)-coalesce(ab.tenacity,10)
    )/360.0;

  physical:=(
      (
        coalesce(da.athletic_rating,50)+coalesce(a.fitness,90)-coalesce(a.fatigue,20)*.55
        +coalesce(aa.natural_fitness,aa.stamina,10)*1.4
        +coalesce(aa.recovery,10)*.8
        +coalesce(aa.rally_tolerance,aa.stamina,10)*.8
      )
      -(
        coalesce(dbb.athletic_rating,50)+coalesce(b.fitness,90)-coalesce(b.fatigue,20)*.55
        +coalesce(ab.natural_fitness,ab.stamina,10)*1.4
        +coalesce(ab.recovery,10)*.8
        +coalesce(ab.rally_tolerance,ab.stamina,10)*.8
      )
    )/230.0
    +(
      coalesce(aa.footwork,10)+coalesce(aa.athleticism,10)
      -coalesce(ab.footwork,10)-coalesce(ab.athleticism,10)
    )/220.0;

  surface_fit:=case
    when surf like '%clay%' or surf like '%terre%'
      then (coalesce(aa.clay_affinity,10)-coalesce(ab.clay_affinity,10))/20.0
    when surf like '%grass%' or surf like '%gazon%'
      then (coalesce(aa.grass_affinity,10)-coalesce(ab.grass_affinity,10))/20.0
    else (coalesce(aa.hard_affinity,10)-coalesce(ab.hard_affinity,10))/20.0
  end;

  pace_fit:=(
    -abs(pace-coalesce(sa.preferred_court_speed,1.0))/greatest(.12,coalesce(sa.pace_tolerance,.25))
    +abs(pace-coalesce(sb.preferred_court_speed,1.0))/greatest(.12,coalesce(sb.pace_tolerance,.25))
  )*.11;

  -- Left/right-handed match-up knowledge is explicit instead of hidden in generic adaptability.
  if lower(coalesce(a.handedness,''))<>lower(coalesce(b.handedness,'')) then
    handedness_fit:=(
      coalesce(ca.lefty_handling,10)
      +coalesce(aa.adaptability,10)
      +coalesce(aa.backhand_accuracy,10)
      +coalesce(aa.return_consistency,10)
      -coalesce(cb.lefty_handling,10)
      -coalesce(ab.adaptability,10)
      -coalesce(ab.backhand_accuracy,10)
      -coalesce(ab.return_consistency,10)
    )/360.0;
  end if;

  style_fit:=handedness_fit
    +(coalesce(ma.rally_1_3_win_pct,ma.rally_0_4_win_pct,50)-coalesce(mb.rally_1_3_win_pct,mb.rally_0_4_win_pct,50))*.0035
    +(coalesce(ma.rally_10plus_win_pct,ma.rally_9plus_win_pct,50)-coalesce(mb.rally_10plus_win_pct,mb.rally_9plus_win_pct,50))*.002
    +(coalesce(ma.return_depth_score,60)-coalesce(mb.return_depth_score,60))*.0013
    +(coalesce(ma.serve_impact,0)-coalesce(mb.serve_impact,0))*.0018;

  -- Tennis-specific tactical rock-paper-scissors.
  tactical_fit:=(
      (coalesce(ta.net_frequency,10)-10)
        *(
          coalesce(aa.volley,10)+coalesce(aa.net_positioning,10)
          -coalesce(ab.passing_shot,ab.return_game,10)-coalesce(ab.reaction,ab.anticipation,10)
        )/520.0
      +(coalesce(ta.aggression_bias,10)-coalesce(tb.defense_to_attack_bias,10))
        *(coalesce(aa.forehand_power,aa.forehand,10)+coalesce(aa.serve_plus_one,aa.forehand,10)-20)/600.0
      +(coalesce(ta.rally_length_preference,10)-10)
        *(coalesce(aa.rally_tolerance,aa.stamina,10)+coalesce(aa.consistency,aa.concentration,10)
          -coalesce(ab.rally_tolerance,ab.stamina,10)-coalesce(ab.consistency,ab.concentration,10))/520.0
      +(coalesce(ta.drop_shot_frequency,10)-10)
        *(coalesce(aa.drop_shot,aa.touch,10)+coalesce(aa.decision_making,aa.tactics,10)
          -coalesce(ab.reaction,ab.anticipation,10)-coalesce(ab.movement,10))/650.0
      +(coalesce(ta.defense_to_attack_bias,10)-coalesce(tb.aggression_bias,10))
        *(coalesce(aa.defense_to_attack,aa.tactics,10)+coalesce(aa.passing_shot,aa.return_game,10)-20)/620.0
    )
    -
    (
      (coalesce(tb.net_frequency,10)-10)
        *(
          coalesce(ab.volley,10)+coalesce(ab.net_positioning,10)
          -coalesce(aa.passing_shot,aa.return_game,10)-coalesce(aa.reaction,aa.anticipation,10)
        )/520.0
      +(coalesce(tb.aggression_bias,10)-coalesce(ta.defense_to_attack_bias,10))
        *(coalesce(ab.forehand_power,ab.forehand,10)+coalesce(ab.serve_plus_one,ab.forehand,10)-20)/600.0
      +(coalesce(tb.rally_length_preference,10)-10)
        *(coalesce(ab.rally_tolerance,ab.stamina,10)+coalesce(ab.consistency,ab.concentration,10)
          -coalesce(aa.rally_tolerance,aa.stamina,10)-coalesce(aa.consistency,aa.concentration,10))/520.0
      +(coalesce(tb.drop_shot_frequency,10)-10)
        *(coalesce(ab.drop_shot,ab.touch,10)+coalesce(ab.decision_making,ab.tactics,10)
          -coalesce(aa.reaction,aa.anticipation,10)-coalesce(aa.movement,10))/650.0
      +(coalesce(tb.defense_to_attack_bias,10)-coalesce(ta.aggression_bias,10))
        *(coalesce(ab.defense_to_attack,ab.tactics,10)+coalesce(ab.passing_shot,ab.return_game,10)-20)/620.0
    );

  context_fit:=(
      coalesce(ca.tiebreak_skill,10)
      +coalesce(ca.deciding_set_skill,10)
      +coalesce(ca.comeback_mentality,10)
      +coalesce(ca.front_runner,10)
      -coalesce(cb.tiebreak_skill,10)
      -coalesce(cb.deciding_set_skill,10)
      -coalesce(cb.comeback_mentality,10)
      -coalesce(cb.front_runner,10)
    )/320.0;

  if surf like '%indoor%' or surf like '%int%' then
    context_fit:=context_fit+(coalesce(ca.indoor_affinity,10)-coalesce(cb.indoor_affinity,10))/100.0;
  end if;

  big_match_fit:=(
      coalesce(ca.big_stage,10)
      +coalesce(dpa.important_matches,10)
      +coalesce(dpa.pressure,10)
      -coalesce(cb.big_stage,10)
      -coalesce(dpb.important_matches,10)
      -coalesce(dpb.pressure,10)
    )/220.0;

  if coalesce(p_best_of,3)>=5 then
    bo5_fit:=(
        coalesce(ca.best_of_five,10)
        +coalesce(aa.stamina,10)
        +coalesce(aa.recovery,10)
        +coalesce(dpa.resilience,10)
        +coalesce(dpa.important_matches,10)
        -coalesce(cb.best_of_five,10)
        -coalesce(ab.stamina,10)
        -coalesce(ab.recovery,10)
        -coalesce(dpb.resilience,10)
        -coalesce(dpb.important_matches,10)
      )/360.0;
  end if;

  confidence_fit:=(
      coalesce(a.morale,70)-coalesce(b.morale,70)
    )*.0032
    +(
      coalesce(aa.confidence,10)-coalesce(ab.confidence,10)
    )*.010
    +(
      coalesce(dpa.temperament,10)-coalesce(dpb.temperament,10)
    )*.006;

  if h.player_a_id is not null then
    total_h:=h.a_wins+h.b_wins;
    if surf like '%clay%' or surf like '%terre%' then
      surf_aw:=h.clay_a_wins; surf_bw:=h.clay_b_wins;
    elsif surf like '%grass%' or surf like '%gazon%' then
      surf_aw:=h.grass_a_wins; surf_bw:=h.grass_b_wins;
    elsif surf like '%indoor%' or surf like '%int%' then
      surf_aw:=h.indoor_a_wins; surf_bw:=h.indoor_b_wins;
    else
      surf_aw:=h.hard_a_wins; surf_bw:=h.hard_b_wins;
    end if;
    surf_n:=surf_aw+surf_bw;
    h2h:=
      (case when total_h>0 then ((h.a_wins-h.b_wins)::numeric/total_h)*least(.055,total_h*.007) else 0 end)
      +(case when surf_n>0 then ((surf_aw-surf_bw)::numeric/surf_n)*least(.045,surf_n*.009) else 0 end)
      +(case when h.recent_a_wins+h.recent_b_wins>0
             then ((h.recent_a_wins-h.recent_b_wins)::numeric/(h.recent_a_wins+h.recent_b_wins))*least(.025,(h.recent_a_wins+h.recent_b_wins)*.006)
             else 0 end);
    if p_a<>h.player_a_id then h2h:=-h2h; end if;
  end if;

  logit:=ln(greatest(.01,least(.99,elo_p))/greatest(.01,1-least(.99,elo_p)))
    +service_return*.54
    +mental*.20
    +physical*.16
    +surface_fit*.20
    +style_fit*.38
    +tactical_fit*.42
    +context_fit*.18
    +big_match_fit*.16
    +bo5_fit*.22
    +confidence_fit
    +pace_fit
    +h2h
    +(coalesce(a.form,70)-coalesce(b.form,70))*.0052;

  -- Best-of-five rewards deeper physical/mental superiority without turning every favourite into certainty.
  if coalesce(p_best_of,3)>=5 then
    prob:=1/(1+exp(-(logit*1.10)));
  else
    prob:=1/(1+exp(-logit));
  end if;

  prob:=greatest(.035,least(.965,prob));

  return jsonb_build_object(
    'player_a_id',p_a,
    'player_b_id',p_b,
    'surface',p_surface,
    'court_speed',round(pace,3),
    'best_of',coalesce(p_best_of,3),
    'player_a_probability',round(prob,4),
    'player_b_probability',round(1-prob,4),
    'components',jsonb_build_object(
      'elo_probability',round(elo_p,4),
      'surface_elo_a',round(aelo,1),
      'surface_elo_b',round(belo,1),
      'service_return',round(service_return,4),
      'mental',round(mental,4),
      'physical',round(physical,4),
      'surface_fit',round(surface_fit,4),
      'pace_fit',round(pace_fit,4),
      'style_matchup',round(style_fit,4),
      'tactical_matchup',round(tactical_fit,4),
      'context_skill',round(context_fit,4),
      'big_match',round(big_match_fit,4),
      'best_of_five',round(bo5_fit,4),
      'confidence',round(confidence_fit,4),
      'h2h',round(h2h,4),
      'form_delta',round((coalesce(a.form,70)-coalesce(b.form,70))*.0052,4)
    ),
    'h2h',case when h.player_a_id is null then null else jsonb_build_object(
      'a_wins',case when p_a=h.player_a_id then h.a_wins else h.b_wins end,
      'b_wins',case when p_a=h.player_a_id then h.b_wins else h.a_wins end,
      'matches',total_h,
      'surface_matches',surf_n,
      'last_match_date',h.last_match_date
    ) end
  );
end;
$function$

