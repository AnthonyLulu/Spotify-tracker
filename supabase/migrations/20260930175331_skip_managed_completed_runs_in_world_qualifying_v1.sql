-- A completed managed tournament run is canonical. Never let the autonomous
-- qualifying engine replay the same event after the user has finished it.

CREATE OR REPLACE FUNCTION public.simulate_world_qualifying_window(p_from_date date, p_to_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t record;
  v_prepare jsonb;
  v_advance jsonb;
  v_prepared integer:=0;
  v_advanced integer:=0;
  v_completed integer:=0;
  v_matches integer:=0;
  v_skipped integer:=0;
  v_draw_date date;
begin
  if p_to_date<=date '2025-12-01' then
    return jsonb_build_object('qualifying_prepared',0,'historical_cutoff',true);
  end if;

  perform public.refresh_world_qualifying_acceptance_window(p_from_date,p_to_date);
  perform public.reconcile_world_acceptance_commitments(p_from_date,p_to_date);

  for t in
    select x.*
    from public.tournaments x
    where x.singles=true
      and coalesce(x.is_active,true)=true
      and coalesce(x.circuit,'') in ('ATP','Challenger','ITF')
      and coalesce(x.qualifying_draw_size,0)>0
      and coalesce(x.qualifying_end_date,x.start_date-1)>=greatest(p_from_date,date '2025-12-01')
      and coalesce(x.qualifying_signin_date,x.qualifying_start_date,x.start_date-1)<=p_to_date
    order by coalesce(x.qualifying_start_date,x.start_date-1),x.id
    limit 240
  loop
    if exists(
      select 1 from public.tournament_runs ur
      where ur.tournament_id=t.id and ur.status='completed'
    ) or exists(
      select 1 from public.world_tournament_simulations ws
      where ws.tournament_id=t.id
    ) then
      continue;
    end if;

    v_draw_date:=coalesce(t.qualifying_signin_date,t.qualifying_start_date,t.start_date-1);

    if not exists(select 1 from public.world_qualifying_states s where s.tournament_id=t.id)
       and not exists(select 1 from public.world_tournament_qualifiers q where q.tournament_id=t.id)
       and v_draw_date<=p_to_date then
      v_prepare:=public.prepare_world_qualifying_tournament(t.id,v_draw_date);
      if coalesce((v_prepare->>'ok')::boolean,false) then
        v_prepared:=v_prepared+1;
      else
        v_skipped:=v_skipped+1;
        continue;
      end if;
    end if;

    if exists(select 1 from public.world_qualifying_states s where s.tournament_id=t.id) then
      v_advance:=public.advance_world_qualifying_tournament(t.id,p_to_date);
      if coalesce((v_advance->>'ok')::boolean,false) then
        if coalesce((v_advance->>'rounds_advanced')::int,0)>0 then v_advanced:=v_advanced+1; end if;
        v_matches:=v_matches+coalesce((v_advance->>'matches_played')::int,0);
        if v_advance->>'status'='completed' then v_completed:=v_completed+1; end if;
      else
        v_skipped:=v_skipped+1;
      end if;
    end if;
  end loop;

  return jsonb_build_object(
    'qualifying_prepared',v_prepared,
    'qualifying_advanced',v_advanced,
    'qualifying_completed',v_completed,
    'matches_played',v_matches,
    'skipped',v_skipped,
    'from',p_from_date,'to',p_to_date,
    'model','CB-MATCH-v6-PROGRESSIVE-Q'
  );
end;
$function$
;
