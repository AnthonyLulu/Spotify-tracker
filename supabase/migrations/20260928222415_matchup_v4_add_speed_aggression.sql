create or replace function public.player_matchup_probability_v4(
  p_a bigint,
  p_b bigint,
  p_surface text default 'Hard',
  p_date date default current_date,
  p_court_speed numeric default null,
  p_best_of integer default 3
)
returns jsonb
language plpgsql
stable
security invoker
set search_path=public
as $$
declare
  base jsonb;
  aa public.player_attributes%rowtype;
  ab public.player_attributes%rowtype;
  pace numeric:=coalesce(
    p_court_speed,
    case
      when lower(coalesce(p_surface,'')) like '%clay%' or lower(coalesce(p_surface,'')) like '%terre%' then .68
      when lower(coalesce(p_surface,'')) like '%grass%' or lower(coalesce(p_surface,'')) like '%gazon%' then 1.15
      when lower(coalesce(p_surface,'')) like '%indoor%' or lower(coalesce(p_surface,'')) like '%int%' then 1.18
      else 1.0
    end
  );
  p0 numeric;
  lg numeric;
  fp numeric;
  a_serve numeric:=10; b_serve numeric:=10;
  a_ground numeric:=10; b_ground numeric:=10;
  a_phys numeric:=10; b_phys numeric:=10;
  a_mental numeric:=10; b_mental numeric:=10;
  a_net numeric:=10; b_net numeric:=10;
  a_combo numeric:=10; b_combo numeric:=10;
  attribute_fit numeric:=0;
begin
  base:=public.player_matchup_probability_v3(
    p_a,p_b,p_surface,p_date,p_court_speed,p_best_of
  );
  if base->>'error' is not null then return base; end if;

  select * into aa from public.player_attributes where player_id=p_a;
  select * into ab from public.player_attributes where player_id=p_b;

  a_serve:=coalesce(aa.serve_power,10)*.58+coalesce(aa.serve_variety,10)*.42;
  b_serve:=coalesce(ab.serve_power,10)*.58+coalesce(ab.serve_variety,10)*.42;

  a_ground:=coalesce(aa.forehand_accuracy,10)*.16+coalesce(aa.backhand_power,10)*.16+
    coalesce(aa.forehand_consistency,10)*.16+coalesce(aa.backhand_consistency,10)*.16+
    coalesce(aa.topspin,10)*.10+coalesce(aa.slice,10)*.07+
    coalesce(aa.patience,10)*.08+coalesce(aa.aggression,10)*.11;
  b_ground:=coalesce(ab.forehand_accuracy,10)*.16+coalesce(ab.backhand_power,10)*.16+
    coalesce(ab.forehand_consistency,10)*.16+coalesce(ab.backhand_consistency,10)*.16+
    coalesce(ab.topspin,10)*.10+coalesce(ab.slice,10)*.07+
    coalesce(ab.patience,10)*.08+coalesce(ab.aggression,10)*.11;

  a_phys:=coalesce(aa.speed,10)*.13+coalesce(aa.strength,10)*.10+
    coalesce(aa.acceleration,10)*.15+coalesce(aa.agility,10)*.15+
    coalesce(aa.balance,10)*.10+coalesce(aa.flexibility,10)*.07+
    coalesce(aa.work_rate,10)*.10+coalesce(aa.defensive_skill,10)*.10+
    coalesce(aa.court_positioning,10)*.10;
  b_phys:=coalesce(ab.speed,10)*.13+coalesce(ab.strength,10)*.10+
    coalesce(ab.acceleration,10)*.15+coalesce(ab.agility,10)*.15+
    coalesce(ab.balance,10)*.10+coalesce(ab.flexibility,10)*.07+
    coalesce(ab.work_rate,10)*.10+coalesce(ab.defensive_skill,10)*.10+
    coalesce(ab.court_positioning,10)*.10;

  a_mental:=coalesce(aa.fighting_spirit,10)*.25+coalesce(aa.killer_instinct,10)*.20+
    coalesce(aa.determination,10)*.21+coalesce(aa.patience,10)*.09+
    coalesce(aa.aggression,10)*.08+coalesce(aa.leadership,10)*.06+
    coalesce(aa.work_rate,10)*.11;
  b_mental:=coalesce(ab.fighting_spirit,10)*.25+coalesce(ab.killer_instinct,10)*.20+
    coalesce(ab.determination,10)*.21+coalesce(ab.patience,10)*.09+
    coalesce(ab.aggression,10)*.08+coalesce(ab.leadership,10)*.06+
    coalesce(ab.work_rate,10)*.11;

  a_net:=coalesce(aa.half_volley,10)*.19+coalesce(aa.smash,10)*.18+coalesce(aa.lob,10)*.12+
    coalesce(aa.slice,10)*.12+coalesce(aa.transition_game,10)*.22+coalesce(aa.court_positioning,10)*.17;
  b_net:=coalesce(ab.half_volley,10)*.19+coalesce(ab.smash,10)*.18+coalesce(ab.lob,10)*.12+
    coalesce(ab.slice,10)*.12+coalesce(ab.transition_game,10)*.22+coalesce(ab.court_positioning,10)*.17;

  if pace>=1.08 then
    a_combo:=a_serve*.27+a_ground*.20+a_phys*.19+a_mental*.17+a_net*.17;
    b_combo:=b_serve*.27+b_ground*.20+b_phys*.19+b_mental*.17+b_net*.17;
  elsif pace<=.82 then
    a_combo:=a_serve*.12+a_ground*.31+a_phys*.24+a_mental*.18+a_net*.15;
    b_combo:=b_serve*.12+b_ground*.31+b_phys*.24+b_mental*.18+b_net*.15;
  else
    a_combo:=a_serve*.20+a_ground*.26+a_phys*.22+a_mental*.17+a_net*.15;
    b_combo:=b_serve*.20+b_ground*.26+b_phys*.22+b_mental*.17+b_net*.15;
  end if;

  attribute_fit:=greatest(-.14,least(.14,(a_combo-b_combo)/65.0));

  p0:=coalesce((base->>'player_a_probability')::numeric,.5);
  lg:=ln(greatest(.01,least(.99,p0))/greatest(.01,1-least(.99,p0)));
  fp:=greatest(.035,least(.965,1/(1+exp(-(lg+attribute_fit)))));

  return base || jsonb_build_object(
    'model','Court Boss matchup v4 · full singles attributes',
    'player_a_probability',round(fp,4),
    'player_b_probability',round(1-fp,4),
    'extended_attributes',jsonb_build_object(
      'serve_a',round(a_serve,2),'serve_b',round(b_serve,2),
      'ground_a',round(a_ground,2),'ground_b',round(b_ground,2),
      'physical_a',round(a_phys,2),'physical_b',round(b_phys,2),
      'mental_a',round(a_mental,2),'mental_b',round(b_mental,2),
      'net_a',round(a_net,2),'net_b',round(b_net,2),
      'combined_a',round(a_combo,2),'combined_b',round(b_combo,2),
      'adjustment',round(attribute_fit,4),
      'court_speed',round(pace,3)
    )
  );
end;
$$;
