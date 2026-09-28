alter table public.world_doubles_tournament_simulations
  add column if not exists final_win_probability numeric,
  add column if not exists model_version text,
  add column if not exists matchup_components jsonb not null default '{}'::jsonb;

create or replace function public.doubles_pair_matchup_v2(
  p_pair_a bigint,
  p_pair_b bigint,
  p_surface text default 'Hard',
  p_date date default current_date
)
returns jsonb
language plpgsql
stable
security invoker
set search_path=public
as $$
declare
  pa public.world_doubles_partnerships%rowtype;
  pb public.world_doubles_partnerships%rowtype;
  a1 public.players%rowtype; a2 public.players%rowtype;
  b1 public.players%rowtype; b2 public.players%rowtype;
  aa1 public.player_attributes%rowtype; aa2 public.player_attributes%rowtype;
  ab1 public.player_attributes%rowtype; ab2 public.player_attributes%rowtype;
  surf text:=lower(coalesce(p_surface,'hard'));
  surf_a numeric:=10; surf_b numeric:=10;
  serve_a numeric:=10; serve_b numeric:=10;
  return_a numeric:=10; return_b numeric:=10;
  net_a numeric:=10; net_b numeric:=10;
  tactical_a numeric:=10; tactical_b numeric:=10;
  pressure_a numeric:=10; pressure_b numeric:=10;
  chemistry_a numeric:=50; chemistry_b numeric:=50;
  condition_a numeric:=50; condition_b numeric:=50;
  experience_a numeric:=0; experience_b numeric:=0;
  diff numeric:=0;
  prob numeric:=.5;
begin
  select * into pa from public.world_doubles_partnerships where id=p_pair_a;
  select * into pb from public.world_doubles_partnerships where id=p_pair_b;
  if pa.id is null or pb.id is null or pa.id=pb.id then
    return jsonb_build_object('error','invalid_pairs');
  end if;

  select * into a1 from public.players where id=pa.player_a_id;
  select * into a2 from public.players where id=pa.player_b_id;
  select * into b1 from public.players where id=pb.player_a_id;
  select * into b2 from public.players where id=pb.player_b_id;

  select * into aa1 from public.player_attributes where player_id=a1.id;
  select * into aa2 from public.player_attributes where player_id=a2.id;
  select * into ab1 from public.player_attributes where player_id=b1.id;
  select * into ab2 from public.player_attributes where player_id=b2.id;

  serve_a:=(
    coalesce(aa1.first_serve_quality,10)+coalesce(aa1.second_serve_quality,10)+coalesce(aa1.serve_power,10)+coalesce(aa1.serve_variety,10)+
    coalesce(aa2.first_serve_quality,10)+coalesce(aa2.second_serve_quality,10)+coalesce(aa2.serve_power,10)+coalesce(aa2.serve_variety,10)
  )/8.0;
  serve_b:=(
    coalesce(ab1.first_serve_quality,10)+coalesce(ab1.second_serve_quality,10)+coalesce(ab1.serve_power,10)+coalesce(ab1.serve_variety,10)+
    coalesce(ab2.first_serve_quality,10)+coalesce(ab2.second_serve_quality,10)+coalesce(ab2.serve_power,10)+coalesce(ab2.serve_variety,10)
  )/8.0;

  return_a:=(
    coalesce(aa1.return_game,10)+coalesce(aa1.return_consistency,10)+coalesce(aa1.return_aggression,10)+coalesce(aa1.reaction,10)+
    coalesce(aa2.return_game,10)+coalesce(aa2.return_consistency,10)+coalesce(aa2.return_aggression,10)+coalesce(aa2.reaction,10)
  )/8.0;
  return_b:=(
    coalesce(ab1.return_game,10)+coalesce(ab1.return_consistency,10)+coalesce(ab1.return_aggression,10)+coalesce(ab1.reaction,10)+
    coalesce(ab2.return_game,10)+coalesce(ab2.return_consistency,10)+coalesce(ab2.return_aggression,10)+coalesce(ab2.reaction,10)
  )/8.0;

  net_a:=(
    coalesce(aa1.doubles,10)+coalesce(aa1.volley,10)+coalesce(aa1.touch,10)+coalesce(aa1.half_volley,10)+coalesce(aa1.smash,10)+
    coalesce(aa1.net_positioning,10)+coalesce(aa1.poaching,10)+coalesce(aa1.transition_game,10)+
    coalesce(aa2.doubles,10)+coalesce(aa2.volley,10)+coalesce(aa2.touch,10)+coalesce(aa2.half_volley,10)+coalesce(aa2.smash,10)+
    coalesce(aa2.net_positioning,10)+coalesce(aa2.poaching,10)+coalesce(aa2.transition_game,10)
  )/16.0;
  net_b:=(
    coalesce(ab1.doubles,10)+coalesce(ab1.volley,10)+coalesce(ab1.touch,10)+coalesce(ab1.half_volley,10)+coalesce(ab1.smash,10)+
    coalesce(ab1.net_positioning,10)+coalesce(ab1.poaching,10)+coalesce(ab1.transition_game,10)+
    coalesce(ab2.doubles,10)+coalesce(ab2.volley,10)+coalesce(ab2.touch,10)+coalesce(ab2.half_volley,10)+coalesce(ab2.smash,10)+
    coalesce(ab2.net_positioning,10)+coalesce(ab2.poaching,10)+coalesce(ab2.transition_game,10)
  )/16.0;

  tactical_a:=(
    coalesce(aa1.doubles_communication,10)+coalesce(aa1.decision_making,10)+coalesce(aa1.shot_selection,10)+coalesce(aa1.anticipation,10)+coalesce(aa1.adaptability,10)+
    coalesce(aa2.doubles_communication,10)+coalesce(aa2.decision_making,10)+coalesce(aa2.shot_selection,10)+coalesce(aa2.anticipation,10)+coalesce(aa2.adaptability,10)
  )/10.0;
  tactical_b:=(
    coalesce(ab1.doubles_communication,10)+coalesce(ab1.decision_making,10)+coalesce(ab1.shot_selection,10)+coalesce(ab1.anticipation,10)+coalesce(ab1.adaptability,10)+
    coalesce(ab2.doubles_communication,10)+coalesce(ab2.decision_making,10)+coalesce(ab2.shot_selection,10)+coalesce(ab2.anticipation,10)+coalesce(ab2.adaptability,10)
  )/10.0;

  pressure_a:=(
    coalesce(aa1.big_points,10)+coalesce(aa1.composure,10)+coalesce(aa1.killer_instinct,10)+coalesce(aa1.confidence,10)+
    coalesce(aa2.big_points,10)+coalesce(aa2.composure,10)+coalesce(aa2.killer_instinct,10)+coalesce(aa2.confidence,10)
  )/8.0;
  pressure_b:=(
    coalesce(ab1.big_points,10)+coalesce(ab1.composure,10)+coalesce(ab1.killer_instinct,10)+coalesce(ab1.confidence,10)+
    coalesce(ab2.big_points,10)+coalesce(ab2.composure,10)+coalesce(ab2.killer_instinct,10)+coalesce(ab2.confidence,10)
  )/8.0;

  if surf like '%clay%' or surf like '%terre%' then
    surf_a:=(coalesce(aa1.clay_affinity,10)+coalesce(aa2.clay_affinity,10))/2.0;
    surf_b:=(coalesce(ab1.clay_affinity,10)+coalesce(ab2.clay_affinity,10))/2.0;
  elsif surf like '%grass%' or surf like '%gazon%' then
    surf_a:=(coalesce(aa1.grass_affinity,10)+coalesce(aa2.grass_affinity,10))/2.0;
    surf_b:=(coalesce(ab1.grass_affinity,10)+coalesce(ab2.grass_affinity,10))/2.0;
  else
    surf_a:=(coalesce(aa1.hard_affinity,10)+coalesce(aa2.hard_affinity,10))/2.0;
    surf_b:=(coalesce(ab1.hard_affinity,10)+coalesce(ab2.hard_affinity,10))/2.0;
  end if;

  chemistry_a:=coalesce(pa.chemistry,50)*.46+coalesce(pa.compatibility,50)*.34+coalesce(pa.pair_strength,50)*.20;
  chemistry_b:=coalesce(pb.chemistry,50)*.46+coalesce(pb.compatibility,50)*.34+coalesce(pb.pair_strength,50)*.20;

  condition_a:=(
    coalesce(a1.form,70)+coalesce(a2.form,70)+coalesce(a1.fitness,90)+coalesce(a2.fitness,90)
    -coalesce(a1.fatigue,20)*.7-coalesce(a2.fatigue,20)*.7
  )/4.0;
  condition_b:=(
    coalesce(b1.form,70)+coalesce(b2.form,70)+coalesce(b1.fitness,90)+coalesce(b2.fitness,90)
    -coalesce(b1.fatigue,20)*.7-coalesce(b2.fatigue,20)*.7
  )/4.0;

  experience_a:=case when coalesce(pa.matches,0)>0 then (coalesce(pa.wins,0)::numeric/pa.matches)*20 else 10 end;
  experience_b:=case when coalesce(pb.matches,0)>0 then (coalesce(pb.wins,0)::numeric/pb.matches)*20 else 10 end;

  diff:=
      (serve_a-serve_b)*.045
    + (return_a-return_b)*.050
    + (net_a-net_b)*.060
    + (tactical_a-tactical_b)*.050
    + (pressure_a-pressure_b)*.035
    + (surf_a-surf_b)*.028
    + (chemistry_a-chemistry_b)*.012
    + (condition_a-condition_b)*.012
    + (experience_a-experience_b)*.020;

  prob:=greatest(.06,least(.94,1/(1+exp(-diff))));

  return jsonb_build_object(
    'model','Court Boss doubles matchup v2',
    'pair_a_id',p_pair_a,'pair_b_id',p_pair_b,
    'surface',p_surface,
    'pair_a_probability',round(prob,4),
    'pair_b_probability',round(1-prob,4),
    'components',jsonb_build_object(
      'serve_a',round(serve_a,2),'serve_b',round(serve_b,2),
      'return_a',round(return_a,2),'return_b',round(return_b,2),
      'net_a',round(net_a,2),'net_b',round(net_b,2),
      'tactical_a',round(tactical_a,2),'tactical_b',round(tactical_b,2),
      'pressure_a',round(pressure_a,2),'pressure_b',round(pressure_b,2),
      'surface_a',round(surf_a,2),'surface_b',round(surf_b,2),
      'chemistry_a',round(chemistry_a,2),'chemistry_b',round(chemistry_b,2),
      'condition_a',round(condition_a,2),'condition_b',round(condition_b,2),
      'experience_a',round(experience_a,2),'experience_b',round(experience_b,2)
    )
  );
end;
$$;
