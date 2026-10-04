CREATE OR REPLACE FUNCTION public.commit_live_world_match_atomic_v23(p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_session public.live_match_sessions%rowtype;
  v_world public.world_tournament_matches%rowtype;
  v_session_id bigint:=nullif(p_payload->>'session_id','')::bigint;
  v_world_match_id bigint:=nullif(p_payload->>'world_match_id','')::bigint;
  v_tournament_id bigint:=nullif(p_payload->>'tournament_id','')::bigint;
  v_managed_id bigint:=nullif(p_payload->>'managed_player_id','')::bigint;
  v_opponent_id bigint:=nullif(p_payload->>'opponent_id','')::bigint;
  v_winner_id bigint:=nullif(p_payload->>'winner_id','')::bigint;
  v_loser_id bigint:=nullif(p_payload->>'loser_id','')::bigint;
  v_round text:=coalesce(p_payload->>'round','');
  v_world_score text:=coalesce(nullif(p_payload->>'world_score',''),'');
  v_match_date date:=coalesce(nullif(p_payload->>'match_date','')::date,current_date);
  v_surface text:=coalesce(nullif(p_payload->>'surface',''),'Dur');
  v_history jsonb:=coalesce(p_payload->'history','{}'::jsonb);
  v_condition jsonb:=coalesce(p_payload->'condition','{}'::jsonb);
  v_components jsonb:=coalesce(p_payload->'world_components','{}'::jsonb);
  v_sync_career boolean:=coalesce((p_payload->>'sync_career')::boolean,false);
  v_elo_weight numeric:=coalesce(nullif(p_payload->>'elo_weight','')::numeric,1);
  v_history_result jsonb;
  v_condition_result jsonb;
  v_elo_result jsonb;
  v_world_already boolean:=false;
  v_effect jsonb;
begin
  if v_session_id is null or v_world_match_id is null
     or v_tournament_id is null or v_managed_id is null
     or v_opponent_id is null or v_winner_id is null or v_loser_id is null then
    raise exception 'live commit payload incomplete';
  end if;

  select * into v_session
  from public.live_match_sessions
  where id=v_session_id
  for update;

  if not found then
    raise exception 'live session % not found',v_session_id;
  end if;

  if v_session.status not in ('finished','completed','committed') then
    raise exception 'live session % is not finishable: %',v_session_id,v_session.status;
  end if;

  if v_session.managed_player_id<>v_managed_id
     or coalesce(v_session.tournament_id,0)<>v_tournament_id
     or coalesce(v_session.opponent_id,0)<>v_opponent_id then
    raise exception 'live session identity mismatch';
  end if;

  if nullif(v_session.stats->'_meta'->>'world_match_id','') is not null
     and (v_session.stats->'_meta'->>'world_match_id')::bigint<>v_world_match_id then
    raise exception 'session world_match_id mismatch';
  end if;

  select * into v_world
  from public.world_tournament_matches
  where id=v_world_match_id
  for update;

  if not found then
    raise exception 'world match % not found',v_world_match_id;
  end if;

  if v_world.tournament_id<>v_tournament_id then
    raise exception 'world tournament mismatch';
  end if;

  if v_round<>'' and coalesce(v_world.round_code,'')<>'' and v_world.round_code<>v_round then
    raise exception 'world round mismatch: expected %, got %',v_round,v_world.round_code;
  end if;

  if not (
    (v_world.player_a_id=v_managed_id and v_world.player_b_id=v_opponent_id)
    or
    (v_world.player_b_id=v_managed_id and v_world.player_a_id=v_opponent_id)
  ) then
    raise exception 'world participants mismatch';
  end if;

  if v_world_score='' then
    v_world_score:=case
      when v_world.player_a_id=v_managed_id then coalesce(p_payload->>'score','')
      else public.world_invert_tennis_score(coalesce(p_payload->>'score',''))
    end;
  end if;

  if v_winner_id not in (v_managed_id,v_opponent_id)
     or v_loser_id not in (v_managed_id,v_opponent_id)
     or v_winner_id=v_loser_id then
    raise exception 'invalid winner/loser identity';
  end if;

  if v_world.winner_id is not null then
    if v_world.winner_id<>v_winner_id or coalesce(v_world.loser_id,0)<>v_loser_id then
      raise exception 'world slot already contains another result';
    end if;
    v_world_already:=true;
  else
    update public.world_tournament_matches
    set winner_id=v_winner_id,
        loser_id=v_loser_id,
        score=v_world_score,
        model_version='CB-MATCH-ENGINE-v6-LIVE-ATOMIC',
        matchup_components=coalesce(matchup_components,'{}'::jsonb)
          ||v_components
          ||jsonb_build_object(
            'status','completed',
            'source','managed_live',
            'live_session_id',v_session_id,
            'managed_player_id',v_managed_id,
            'atomic_commit',true
          ),
        simulated_on=coalesce(simulated_on,v_match_date)
    where id=v_world_match_id;

    insert into public.live_match_effect_commits_v23(session_id,effect,payload)
    values(
      v_session_id,'world',
      jsonb_build_object(
        'world_match_id',v_world_match_id,
        'winner_id',v_winner_id,
        'loser_id',v_loser_id,
        'score',v_world_score
      )
    )
    on conflict(session_id,effect) do nothing;
  end if;

  v_history_result:=public.ensure_live_match_history_v23(
    v_session_id,
    v_managed_id,
    coalesce(v_history->>'tournament_name','Live Match Center'),
    v_match_date,
    v_surface,
    coalesce(v_history->>'round',v_round),
    coalesce(v_history->>'player_a','Joueur'),
    coalesce(v_history->>'player_b','Adversaire'),
    coalesce(v_history->>'winner',''),
    coalesce(v_history->>'score',p_payload->>'score',v_world_score),
    coalesce(v_history->'match_data','{}'::jsonb)
  );

  if coalesce((v_history_result->>'ok')::boolean,false)=false then
    raise exception 'history commit failed: %',coalesce(v_history_result->>'error','unknown');
  end if;

  v_condition_result:=public.apply_live_match_condition_once_v23(
    v_session_id,
    v_managed_id,
    v_condition,
    v_sync_career
  );

  if coalesce((v_condition_result->>'ok')::boolean,false)=false then
    raise exception 'condition commit failed: %',coalesce(v_condition_result->>'error','unknown');
  end if;

  v_elo_result:=public.apply_live_match_elo_once_v23(
    v_session_id,
    v_winner_id,
    v_loser_id,
    v_surface,
    v_match_date,
    false,
    v_elo_weight
  );

  if coalesce((v_elo_result->>'ok')::boolean,false)=false then
    raise exception 'elo commit failed: %',coalesce(v_elo_result->>'error','unknown');
  end if;

  select payload into v_effect
  from public.live_match_effect_commits_v23
  where session_id=v_session_id and effect='world';

  return jsonb_build_object(
    'ok',true,
    'session_id',v_session_id,
    'world_match_id',v_world_match_id,
    'world_already_committed',v_world_already,
    'is_qualifying',coalesce(v_world.is_qualifying,false),
    'simulated_on',v_world.simulated_on,
    'round_code',v_world.round_code,
    'world',coalesce(v_effect,'{}'::jsonb),
    'history',v_history_result,
    'condition',v_condition_result,
    'elo',v_elo_result,
    'model','CB-LIVE-ATOMIC-COMMIT-v23'
  );
end;
$function$;
revoke all on function public.commit_live_world_match_atomic_v23(jsonb) from public,anon,authenticated;
grant execute on function public.commit_live_world_match_atomic_v23(jsonb) to service_role;
