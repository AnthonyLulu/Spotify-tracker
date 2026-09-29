-- Court Boss · United Cup 2026 bracket correction v3
-- Official 2026 schedule:
-- QF1: Winner Group C vs Winner Group E
-- QF2: Winner Group A vs best runner-up in Perth
-- QF3: Winner Group B vs best runner-up in Sydney
-- QF4: Winner Group D vs Winner Group F
-- SF1: Winner QF1 vs Winner QF3
-- SF2: Winner QF2 vs Winner QF4
-- Anti-rematch rule preserved when the best runner-up comes from the scheduled group winner's group.

CREATE OR REPLACE FUNCTION public.advance_united_cup_bracket(p_tournament_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  q1 text;q2 text;q3 text;q4 text;
  s1 text;s2 text;
  created_sf boolean:=false;
  created_f boolean:=false;
begin
  select winner_nation into q1 from public.united_cup_ties where tournament_id=p_tournament_id and event_key='QF1' and status='completed';
  select winner_nation into q2 from public.united_cup_ties where tournament_id=p_tournament_id and event_key='QF2' and status='completed';
  select winner_nation into q3 from public.united_cup_ties where tournament_id=p_tournament_id and event_key='QF3' and status='completed';
  select winner_nation into q4 from public.united_cup_ties where tournament_id=p_tournament_id and event_key='QF4' and status='completed';

  if q1 is not null and q2 is not null and q3 is not null and q4 is not null then
    insert into public.united_cup_ties(
      tournament_id,stage,city,bracket_slot,tie_date,
      nation_a,nation_b,status,model_version,source_label,event_key
    ) values
      (p_tournament_id,'SF','Sydney',1,date '2026-01-10',q1,q3,'scheduled','CB-UNITED-CUP-v3','Official 2026 SF1: Winner QF1 vs Winner QF3','SF1'),
      (p_tournament_id,'SF','Sydney',2,date '2026-01-10',q2,q4,'scheduled','CB-UNITED-CUP-v3','Official 2026 SF2: Winner QF2 vs Winner QF4','SF2')
    on conflict(tournament_id,event_key) do update set
      nation_a=excluded.nation_a,nation_b=excluded.nation_b,
      tie_date=excluded.tie_date,
      status=case when united_cup_ties.status='completed' then united_cup_ties.status else 'scheduled' end,
      source_label=excluded.source_label,model_version=excluded.model_version;
    created_sf:=true;
  end if;

  select winner_nation into s1 from public.united_cup_ties where tournament_id=p_tournament_id and event_key='SF1' and status='completed';
  select winner_nation into s2 from public.united_cup_ties where tournament_id=p_tournament_id and event_key='SF2' and status='completed';

  if s1 is not null and s2 is not null then
    insert into public.united_cup_ties(
      tournament_id,stage,city,bracket_slot,tie_date,
      nation_a,nation_b,status,model_version,source_label,event_key
    ) values(
      p_tournament_id,'F','Sydney',1,date '2026-01-11',
      s1,s2,'scheduled','CB-UNITED-CUP-v3','Official 2026 final: Winner SF1 vs Winner SF2','F'
    )
    on conflict(tournament_id,event_key) do update set
      nation_a=excluded.nation_a,nation_b=excluded.nation_b,
      tie_date=excluded.tie_date,
      status=case when united_cup_ties.status='completed' then united_cup_ties.status else 'scheduled' end,
      source_label=excluded.source_label,model_version=excluded.model_version;
    created_f:=true;
  end if;

  return jsonb_build_object(
    'ok',true,
    'semifinals_ready',created_sf,
    'final_ready',created_f,
    'model','United Cup 2026 official bracket v3'
  );
end;
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

  -- Official 2026 Perth base bracket:
  -- QF1: Winner Group C vs Winner Group E
  -- QF2: Winner Group A vs best runner-up.
  -- If the runner-up is from Group A, it swaps with the lower-ranked C/E
  -- winner so no group-stage rematch occurs before the final.
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
    qf1a:=c_w; qf1b:=e_w;
    qf2a:=a_w; qf2b:=perth_runner;
  end if;

  -- Official 2026 Sydney base bracket:
  -- QF3: Winner Group B vs best runner-up
  -- QF4: Winner Group D vs Winner Group F.
  -- The same anti-rematch swap applies if the runner-up is from Group B.
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
    (p_tournament_id,'QF',null,'Perth',1,date '2026-01-07',qf1a,qf1b,'scheduled','CB-UNITED-CUP-v3','Official 2026 QF1 + anti-rematch rule','QF1'),
    (p_tournament_id,'QF',null,'Perth',2,date '2026-01-07',qf2a,qf2b,'scheduled','CB-UNITED-CUP-v3','Official 2026 QF2 + anti-rematch rule','QF2'),
    (p_tournament_id,'QF',null,'Sydney',3,date '2026-01-08',qf3a,qf3b,'scheduled','CB-UNITED-CUP-v3','Official 2026 QF3 + anti-rematch rule','QF3'),
    (p_tournament_id,'QF',null,'Sydney',4,date '2026-01-09',qf4a,qf4b,'scheduled','CB-UNITED-CUP-v3','Official 2026 QF4 + anti-rematch rule','QF4')
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
    'qf4',jsonb_build_array(qf4a,qf4b),
    'model','United Cup 2026 official bracket v3'
  );
end;
$function$;

