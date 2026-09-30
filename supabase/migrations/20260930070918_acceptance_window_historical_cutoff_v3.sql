-- Preserve the historical 01/12/2025 cutoff before any future-list mutation.
CREATE OR REPLACE FUNCTION public.advance_world_tournament_window(p_from_date date, p_to_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  t record;
  r public.tournament_format_rules%rowtype;
  v_prepare jsonb;
  v_advance jsonb;
  v_prepared integer:=0;
  v_advanced integer:=0;
  v_completed integer:=0;
  v_matches integer:=0;
  v_skipped integer:=0;
  v_draw_date date;
begin
  perform pg_advisory_xact_lock(94832022);

  if p_to_date<=date '2025-12-01' then
    return jsonb_build_object('prepared',0,'advanced',0,'historical_cutoff',true);
  end if;

  -- Defensive refresh for callers that invoke the progressive main-draw engine directly.
  -- The edge orchestrator also refreshes before qualifying so deadline movements are preserved.
  perform public.refresh_world_acceptance_window(p_from_date,p_to_date);

  for t in
    select x.*
    from public.tournaments x
    where x.singles=true
      and coalesce(x.is_active,true)=true
      and coalesce(x.circuit,'') in ('ATP','Challenger','ITF')
      and coalesce(x.category,'') not in ('United Cup','Laver Cup','Davis Cup','Junior Davis Cup')
      and coalesce(x.end_date,x.start_date)>=greatest(p_from_date,date '2025-12-01')
      and coalesce(x.main_draw_start_date,x.start_date)<=p_to_date
    order by coalesce(x.main_draw_start_date,x.start_date),x.id
    limit 200
  loop
    select * into r from public.tournament_format_rules fr
    where fr.circuit=t.circuit and fr.category=t.category
      and fr.main_draw_size=coalesce(t.singles_draw_size,t.draw_size)
    limit 1;

    if r.rule_key is null or r.format_type<>'knockout' then
      v_skipped:=v_skipped+1;
      continue;
    end if;

    if exists(select 1 from public.world_tournament_simulations s where s.tournament_id=t.id) then
      continue;
    end if;

    v_draw_date:=coalesce(t.qualifying_end_date,
      coalesce(t.main_draw_start_date,t.start_date)-1,
      t.start_date);

    if not exists(select 1 from public.world_tournament_states s where s.tournament_id=t.id)
       and v_draw_date<=p_to_date then
      v_prepare:=public.prepare_world_knockout_tournament(t.id,v_draw_date);
      if coalesce((v_prepare->>'ok')::boolean,false) then
        v_prepared:=v_prepared+1;
      else
        v_skipped:=v_skipped+1;
        continue;
      end if;
    end if;

    if exists(select 1 from public.world_tournament_states s where s.tournament_id=t.id) then
      v_advance:=public.advance_world_knockout_tournament(t.id,p_to_date);
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
    'prepared',v_prepared,'advanced',v_advanced,'completed',v_completed,
    'matches_played',v_matches,'skipped',v_skipped,
    'from',p_from_date,'to',p_to_date,'model','CB-MATCH-v5-PROGRESSIVE'
  );
end;
$function$
;
