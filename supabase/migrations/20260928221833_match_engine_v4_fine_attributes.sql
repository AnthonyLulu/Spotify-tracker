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
security definer
set search_path=public
as $$
declare
  base jsonb;
  aa public.player_attributes%rowtype;
  ab public.player_attributes%rowtype;
  p0 numeric;
  lg numeric;
  surf text:=lower(coalesce(p_surface,'hard'));
  serve_edge numeric:=0;
  rally_edge numeric:=0;
  movement_edge numeric:=0;
  transition_edge numeric:=0;
  competitive_edge numeric:=0;
  fine_edge numeric:=0;
  fp numeric;
begin
  base:=public.player_matchup_probability_v3(p_a,p_b,p_surface,p_date,p_court_speed,p_best_of);
  if base->>'error' is not null then return base; end if;

  select * into aa from public.player_attributes where player_id=p_a;
  select * into ab from public.player_attributes where player_id=p_b;

  serve_edge:=(
    (coalesce(aa.serve_power,10)-coalesce(ab.serve_power,10))*.0060+
    (coalesce(aa.serve_variety,10)-coalesce(ab.serve_variety,10))*.0030+
    (coalesce(aa.serve_spin,10)-coalesce(ab.serve_spin,10))*.0025+
    (coalesce(aa.serve_consistency,10)-coalesce(ab.serve_consistency,10))*.0035
  )*case when surf like '%grass%' or surf like '%gazon%' or surf like '%indoor%' then 1.18
         when surf like '%clay%' or surf like '%terre%' then .78 else 1 end;

  rally_edge:=(
    (coalesce(aa.forehand_consistency,10)-coalesce(ab.forehand_consistency,10))*.0033+
    (coalesce(aa.backhand_consistency,10)-coalesce(ab.backhand_consistency,10))*.0033+
    (coalesce(aa.shot_control,10)-coalesce(ab.shot_control,10))*.0030+
    (coalesce(aa.timing,10)-coalesce(ab.timing,10))*.0027+
    (coalesce(aa.topspin,10)-coalesce(ab.topspin,10))*.0018
  )*case when surf like '%clay%' or surf like '%terre%' then 1.17 else 1 end;

  movement_edge:=(
    (coalesce(aa.speed,10)-coalesce(ab.speed,10))*.0020+
    (coalesce(aa.acceleration,10)-coalesce(ab.acceleration,10))*.0026+
    (coalesce(aa.agility,10)-coalesce(ab.agility,10))*.0024+
    (coalesce(aa.balance,10)-coalesce(ab.balance,10))*.0015+
    (coalesce(aa.strength,10)-coalesce(ab.strength,10))*.0012+
    (coalesce(aa.footwork,10)-coalesce(ab.footwork,10))*.0027+
    (coalesce(aa.athleticism,10)-coalesce(ab.athleticism,10))*.0022
  )*case when surf like '%clay%' or surf like '%terre%' then 1.12 else 1 end;

  transition_edge:=(
    (coalesce(aa.transition_game,10)-coalesce(ab.transition_game,10))*.0026+
    (coalesce(aa.half_volley,10)-coalesce(ab.half_volley,10))*.0015+
    (coalesce(aa.smash,10)-coalesce(ab.smash,10))*.0013+
    (coalesce(aa.lob,10)-coalesce(ab.lob,10))*.0010+
    (coalesce(aa.slice,10)-coalesce(ab.slice,10))*.0012+
    (coalesce(aa.court_positioning,10)-coalesce(ab.court_positioning,10))*.0022
  )*case when surf like '%grass%' or surf like '%gazon%' then 1.22 else 1 end;

  competitive_edge:=(
    (coalesce(aa.fighting_spirit,10)-coalesce(ab.fighting_spirit,10))*.0018+
    (coalesce(aa.determination,10)-coalesce(ab.determination,10))*.0016+
    (coalesce(aa.killer_instinct,10)-coalesce(ab.killer_instinct,10))*.0018+
    (coalesce(aa.work_rate,10)-coalesce(ab.work_rate,10))*.0010
  );

  fine_edge:=greatest(-.085,least(.085,
    serve_edge+rally_edge+movement_edge+transition_edge+competitive_edge
  ));

  p0:=coalesce((base->>'player_a_probability')::numeric,.5);
  lg:=ln(greatest(.01,least(.99,p0))/greatest(.01,1-least(.99,p0)));
  fp:=greatest(.035,least(.965,1/(1+exp(-(lg+fine_edge)))));

  return base || jsonb_build_object(
    'model','Court Boss matchup v4 · 74-attribute fine layer',
    'player_a_probability',round(fp,4),
    'player_b_probability',round(1-fp,4),
    'fine_attribute_components',jsonb_build_object(
      'serve_weapon',round(serve_edge,4),
      'rally_quality',round(rally_edge,4),
      'movement_explosiveness',round(movement_edge,4),
      'transition_variety',round(transition_edge,4),
      'competitive_edge',round(competitive_edge,4),
      'total',round(fine_edge,4)
    )
  );
end;
$$;

revoke all on function public.player_matchup_probability_v4(bigint,bigint,text,date,numeric,integer)
from public,anon,authenticated;
grant execute on function public.player_matchup_probability_v4(bigint,bigint,text,date,numeric,integer)
to service_role;

create or replace function public.tennis_abstract_matchup_model_v2(
  p_server_id bigint,
  p_returner_id bigint,
  p_surface text default 'Dur',
  p_pressure numeric default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
declare
  base jsonb;
  sa public.player_attributes%rowtype;
  ra public.player_attributes%rowtype;
  surf text:=lower(coalesce(p_surface,'dur'));
  p_first numeric;
  p_second numeric;
  first_in numeric;
  df numeric;
  first_edge numeric:=0;
  second_edge numeric:=0;
  rally_edge numeric:=0;
  expected numeric;
begin
  base:=public.tennis_abstract_matchup_model(p_server_id,p_returner_id,p_surface,p_pressure);
  if base is null then return jsonb_build_object('error','missing_matchup_data'); end if;

  select * into sa from public.player_attributes where player_id=p_server_id;
  select * into ra from public.player_attributes where player_id=p_returner_id;

  first_edge:=greatest(-.028,least(.028,
    (
      (coalesce(sa.serve_power,10)-coalesce(ra.reaction,10))*.0016+
      (coalesce(sa.serve_spin,10)-coalesce(ra.return_consistency,10))*.0011+
      (coalesce(sa.serve_variety,10)-coalesce(ra.anticipation,10))*.0012+
      (coalesce(sa.serve_consistency,10)-coalesce(ra.counter_skill,10))*.0011+
      (coalesce(sa.timing,10)-coalesce(ra.timing,10))*.0008
    )*case when surf like '%gazon%' or surf like '%grass%' or surf like '%indoor%' then 1.15
           when surf like '%terre%' or surf like '%clay%' then .82 else 1 end
  ));

  second_edge:=greatest(-.024,least(.024,
    (coalesce(sa.second_serve_quality,10)-coalesce(ra.return_aggression,10))*.0013+
    (coalesce(sa.serve_spin,10)-coalesce(ra.counter_skill,10))*.0009+
    (coalesce(sa.serve_consistency,10)-coalesce(ra.return_consistency,10))*.0010+
    (coalesce(sa.serve_plus_one,10)-coalesce(ra.passing_shot,10))*.0008
  ));

  rally_edge:=greatest(-.018,least(.018,
    (coalesce(sa.forehand_consistency,10)-coalesce(ra.forehand_consistency,10))*.0007+
    (coalesce(sa.backhand_consistency,10)-coalesce(ra.backhand_consistency,10))*.0007+
    (coalesce(sa.shot_control,10)-coalesce(ra.shot_control,10))*.0006+
    (coalesce(sa.footwork,10)-coalesce(ra.footwork,10))*.0006+
    (coalesce(sa.tenacity,10)-coalesce(ra.tenacity,10))*.0005+
    (coalesce(sa.transition_game,10)-coalesce(ra.defensive_skill,10))*.0005
  ));

  p_first:=greatest(.40,least(.86,coalesce((base->>'first_serve_point_win_prob')::numeric,.64)+first_edge+rally_edge));
  p_second:=greatest(.30,least(.70,coalesce((base->>'second_serve_point_win_prob')::numeric,.51)+second_edge+rally_edge));
  first_in:=coalesce((base->>'first_serve_in_pct')::numeric,62)/100.0;
  df:=coalesce((base->>'double_fault_pct')::numeric,4)/100.0;
  expected:=greatest(.30,least(.86,first_in*p_first+(1-first_in)*(1-df)*p_second));

  return base || jsonb_build_object(
    'model','Court Boss point model v2 · fine attributes',
    'first_serve_point_win_prob',round(p_first,4),
    'second_serve_point_win_prob',round(p_second,4),
    'expected_server_point_win_prob',round(expected,4),
    'fine_attribute_edges',jsonb_build_object(
      'first_serve',round(first_edge,4),
      'second_serve',round(second_edge,4),
      'rally',round(rally_edge,4)
    )
  );
end;
$$;

revoke all on function public.tennis_abstract_matchup_model_v2(bigint,bigint,text,numeric)
from public,anon,authenticated;
grant execute on function public.tennis_abstract_matchup_model_v2(bigint,bigint,text,numeric)
to service_role;
