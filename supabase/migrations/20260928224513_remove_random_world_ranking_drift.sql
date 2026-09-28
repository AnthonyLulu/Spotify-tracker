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
