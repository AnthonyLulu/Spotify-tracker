CREATE OR REPLACE FUNCTION cb_e2e_reconstruction_20261010.probe_world_draw_verified_v75(p_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare r jsonb:='{}'::jsonb; qualifiers jsonb:='{}'::jsonb; out jsonb:='{}'::jsonb;
failure text; failure_context text; failure_detail text; row_t public.tournaments%rowtype; rows_before int;
v_total int:=0;v_scored int:=0;v_invalid int:=0;v_final_matches int:=0;
v_stored_champion bigint;v_stored_finalist bigint;v_final_winner bigint;
begin
 if p_id not in (65,199,906) then raise exception 'Only the three isolated QA tournament ids are allowed';end if;
 if (select count(*) from public.career_state)<>0 or (select count(*) from public.game_saves)<>0
  or (select count(*) from public.world_tournament_simulations)<>0
 then raise exception 'QA stage has unexpected persisted session, saves or simulated events';end if;
 select * into row_t from public.tournaments where id=p_id and is_active=true;
 if row_t.id is null or row_t.end_date<>date '2026-01-11' then raise exception 'Unexpected QA event metadata';end if;
 begin
  qualifiers:=public.simulate_world_qualifying_full(p_id,coalesce(row_t.qualifying_end_date,row_t.start_date,date '2026-01-11'));
  r:=public.simulate_world_knockout_tournament_full(p_id,date '2026-01-11');
  select count(*)::int,
     count(*) filter (where winner_id is not null and loser_id is not null
       and winner_id<>loser_id
       and winner_id in (player_a_id,player_b_id)
       and loser_id in (player_a_id,player_b_id)
       and coalesce(length(trim(score)),0)>0)::int,
     count(*) filter (where winner_id is null or loser_id is null
       or winner_id=loser_id or winner_id not in (player_a_id,player_b_id)
       or loser_id not in (player_a_id,player_b_id)
       or coalesce(length(trim(score)),0)=0)::int,
     count(*) filter (where round_code='F')::int
   into v_total,v_scored,v_invalid,v_final_matches
   from public.world_tournament_matches
   where tournament_id=p_id and coalesce(is_qualifying,false)=false;
  select s.winner_id,s.finalist_id into v_stored_champion,v_stored_finalist
   from public.world_tournament_simulations s where s.tournament_id=p_id;
  select m.winner_id into v_final_winner
   from public.world_tournament_matches m
   where m.tournament_id=p_id and m.round_code='F'
     and coalesce(m.is_qualifying,false)=false
   order by m.id desc limit 1;
  out:=jsonb_build_object('ok',coalesce((r->>'ok')::boolean,false) AND v_total=coalesce((r->>'matches')::int,0)
     AND v_total>0 AND v_total=v_scored AND v_invalid=0 AND v_final_matches=1
     AND v_stored_champion IS NOT NULL AND v_stored_champion=v_final_winner
     AND v_stored_champion=(r->>'champion_id')::bigint,
   'date','2026-01-11','circuit',row_t.circuit,'category',row_t.category,
   'name',row_t.name,'tournament_id',p_id,'qualifying',qualifiers,
   'matches',r->'matches','participants',r->'participants',
   'champion_id',v_stored_champion,'champion',r->'champion',
   'finalist_id',v_stored_finalist,'final_match_winner',v_final_winner,
   'matches_scored',v_scored,'matches_invalid',v_invalid,
   'final_matches',v_final_matches,'returned_model',r->'model',
   'rolled_back',true);
  raise exception 'EXPECTED_DRAW_TEST_ROLLBACK';
 exception when others then
  get stacked diagnostics failure=message_text, failure_context=pg_exception_context, failure_detail=pg_exception_detail;
  if failure='EXPECTED_DRAW_TEST_ROLLBACK' then return out;end if;
  return jsonb_build_object('ok',false,'rolled_back',true,'tournament_id',p_id,
    'circuit',row_t.circuit,'error',left(failure,800),
    'context',left(coalesce(failure_context,''),2100),
    'detail',left(coalesce(failure_detail,''),750));
 end;
end $function$
;
REVOKE ALL ON FUNCTION cb_e2e_reconstruction_20261010.probe_world_draw_verified_v75(bigint) FROM PUBLIC,anon,authenticated;
