CREATE OR REPLACE FUNCTION public.commit_live_doubles_world_match_atomic_v23(p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_session public.live_match_sessions%rowtype;
  v_world public.world_doubles_tournament_matches%rowtype;
  v_user_pair public.world_doubles_partnerships%rowtype;
  v_opp_pair public.world_doubles_partnerships%rowtype;
  v_session_id bigint:=nullif(p_payload->>'session_id','')::bigint;
  v_world_match_id bigint:=nullif(p_payload->>'world_match_id','')::bigint;
  v_tournament_id bigint:=nullif(p_payload->>'tournament_id','')::bigint;
  v_managed_id bigint:=nullif(p_payload->>'managed_player_id','')::bigint;
  v_user_pair_id bigint:=nullif(p_payload->>'user_pair_id','')::bigint;
  v_opp_pair_id bigint:=nullif(p_payload->>'opponent_pair_id','')::bigint;
  v_winner_pair_id bigint:=nullif(p_payload->>'winner_pair_id','')::bigint;
  v_loser_pair_id bigint:=nullif(p_payload->>'loser_pair_id','')::bigint;
  v_round text:=coalesce(p_payload->>'round','');
  v_score text:=coalesce(p_payload->>'score','');
  v_world_score text:=coalesce(nullif(p_payload->>'world_score',''),'');
  v_match_date date:=coalesce(nullif(p_payload->>'match_date','')::date,current_date);
  v_surface text:=coalesce(nullif(p_payload->>'surface',''),'Dur');
  v_user_ids bigint[];
  v_opp_ids bigint[];
  v_winning_ids bigint[];
  v_losing_ids bigint[];
  v_history jsonb:=coalesce(p_payload->'history','{}'::jsonb);
  v_managed_condition jsonb:=coalesce(p_payload->'managed_condition','{}'::jsonb);
  v_partner_condition jsonb:=coalesce(p_payload->'partner_condition','{}'::jsonb);
  v_components jsonb:=coalesce(p_payload->'world_components','{}'::jsonb);
  v_sync_career boolean:=coalesce((p_payload->>'sync_career')::boolean,false);
  v_elo_weight numeric:=coalesce(nullif(p_payload->>'elo_weight','')::numeric,.275);
  v_history_result jsonb;
  v_condition_result jsonb;
  v_elo_result jsonb;
  v_world_already boolean:=false;
  v_existing jsonb;
  v_r jsonb;
  v_elo_rows jsonb:='[]'::jsonb;
  i int;
  j int;
begin
  if v_session_id is null or v_world_match_id is null or v_tournament_id is null
     or v_managed_id is null or v_user_pair_id is null or v_opp_pair_id is null
     or v_winner_pair_id is null or v_loser_pair_id is null then
    raise exception 'live doubles commit payload incomplete';
  end if;

  select array_agg((x)::bigint order by ord)
  into v_user_ids
  from jsonb_array_elements_text(coalesce(p_payload->'user_player_ids','[]'::jsonb))
       with ordinality as z(x,ord);

  select array_agg((x)::bigint order by ord)
  into v_opp_ids
  from jsonb_array_elements_text(coalesce(p_payload->'opponent_player_ids','[]'::jsonb))
       with ordinality as z(x,ord);

  if coalesce(array_length(v_user_ids,1),0)<>2 or coalesce(array_length(v_opp_ids,1),0)<>2 then
    raise exception 'doubles player arrays must contain exactly two players';
  end if;

  select * into v_session
  from public.live_match_sessions
  where id=v_session_id
  for update;

  if not found then raise exception 'live doubles session % not found',v_session_id; end if;
  if v_session.status not in ('finished','completed','committed') then
    raise exception 'live doubles session % is not finishable: %',v_session_id,v_session.status;
  end if;
  if v_session.managed_player_id<>v_managed_id or coalesce(v_session.tournament_id,0)<>v_tournament_id then
    raise exception 'live doubles session identity mismatch';
  end if;

  if nullif(v_session.stats->'_meta'->'doubles'->>'world_match_id','') is not null
     and (v_session.stats->'_meta'->'doubles'->>'world_match_id')::bigint<>v_world_match_id then
    raise exception 'doubles session world_match_id mismatch';
  end if;

  select * into v_world
  from public.world_doubles_tournament_matches
  where id=v_world_match_id
  for update;

  if not found then raise exception 'world doubles match % not found',v_world_match_id; end if;
  if v_world.tournament_id<>v_tournament_id then raise exception 'world doubles tournament mismatch'; end if;
  if v_round<>'' and coalesce(v_world.round_code,'')<>'' and v_world.round_code<>v_round then
    raise exception 'world doubles round mismatch: expected %, got %',v_round,v_world.round_code;
  end if;
  if not (
    (v_world.pair_a_id=v_user_pair_id and v_world.pair_b_id=v_opp_pair_id)
    or
    (v_world.pair_b_id=v_user_pair_id and v_world.pair_a_id=v_opp_pair_id)
  ) then
    raise exception 'world doubles pair mismatch';
  end if;

  select * into v_user_pair from public.world_doubles_partnerships where id=v_user_pair_id;
  select * into v_opp_pair from public.world_doubles_partnerships where id=v_opp_pair_id;
  if v_user_pair.id is null or v_opp_pair.id is null then raise exception 'world doubles partnership missing'; end if;

  if array[least(v_user_ids[1],v_user_ids[2]),greatest(v_user_ids[1],v_user_ids[2])]
     <> array[least(v_user_pair.player_a_id,v_user_pair.player_b_id),greatest(v_user_pair.player_a_id,v_user_pair.player_b_id)] then
    raise exception 'managed doubles players do not match world pair';
  end if;
  if array[least(v_opp_ids[1],v_opp_ids[2]),greatest(v_opp_ids[1],v_opp_ids[2])]
     <> array[least(v_opp_pair.player_a_id,v_opp_pair.player_b_id),greatest(v_opp_pair.player_a_id,v_opp_pair.player_b_id)] then
    raise exception 'opponent doubles players do not match world pair';
  end if;

  if v_winner_pair_id not in (v_user_pair_id,v_opp_pair_id)
     or v_loser_pair_id not in (v_user_pair_id,v_opp_pair_id)
     or v_winner_pair_id=v_loser_pair_id then
    raise exception 'invalid doubles winner/loser pair';
  end if;

  if v_world_score='' then
    v_world_score:=case
      when v_world.pair_a_id=v_user_pair_id then v_score
      else public.world_invert_tennis_score(v_score)
    end;
  end if;

  if v_world.winner_pair_id is not null then
    if v_world.winner_pair_id<>v_winner_pair_id or coalesce(v_world.loser_pair_id,0)<>v_loser_pair_id then
      raise exception 'world doubles slot already contains another result';
    end if;
    v_world_already:=true;
  else
    update public.world_doubles_tournament_matches
    set winner_pair_id=v_winner_pair_id,
        loser_pair_id=v_loser_pair_id,
        score=v_world_score,
        pair_a_win_probability=case
          when p_payload ? 'pair_a_win_probability' then (p_payload->>'pair_a_win_probability')::numeric
          else pair_a_win_probability
        end,
        model_version='CB-LIVE-DOUBLES-v23-ATOMIC',
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
      v_session_id,'world_doubles',
      jsonb_build_object(
        'world_match_id',v_world_match_id,
        'winner_pair_id',v_winner_pair_id,
        'loser_pair_id',v_loser_pair_id,
        'score',v_world_score
      )
    )
    on conflict(session_id,effect) do nothing;
  end if;

  v_history_result:=public.ensure_live_match_history_v23(
    v_session_id,
    v_managed_id,
    coalesce(v_history->>'tournament_name','Double live'),
    v_match_date,
    v_surface,
    coalesce(v_history->>'round',v_round),
    coalesce(v_history->>'player_a','Paire gérée'),
    coalesce(v_history->>'player_b','Paire adverse'),
    coalesce(v_history->>'winner',''),
    coalesce(v_history->>'score',v_score),
    coalesce(v_history->'match_data','{}'::jsonb)
  );
  if coalesce((v_history_result->>'ok')::boolean,false)=false then
    raise exception 'doubles history commit failed: %',coalesce(v_history_result->>'error','unknown');
  end if;

  select payload into v_existing
  from public.live_match_effect_commits_v23
  where session_id=v_session_id and effect='condition_doubles';

  if v_existing is null then
    update public.players
    set fatigue=coalesce((v_managed_condition->>'fatigue')::int,fatigue),
        fitness=coalesce((v_managed_condition->>'fitness')::int,fitness),
        form=coalesce((v_managed_condition->>'form')::int,form),
        morale=coalesce((v_managed_condition->>'morale')::int,morale),
        injury_status=coalesce(nullif(v_managed_condition->>'injury_status',''),injury_status)
    where id=v_user_ids[1];
    if not found then raise exception 'managed doubles player missing'; end if;

    update public.players
    set fatigue=coalesce((v_partner_condition->>'fatigue')::int,fatigue),
        fitness=coalesce((v_partner_condition->>'fitness')::int,fitness),
        form=coalesce((v_partner_condition->>'form')::int,form),
        morale=coalesce((v_partner_condition->>'morale')::int,morale),
        injury_status=coalesce(nullif(v_partner_condition->>'injury_status',''),injury_status)
    where id=v_user_ids[2];
    if not found then raise exception 'managed doubles partner missing'; end if;

    if v_sync_career then
      update public.career_state
      set fatigue=coalesce((v_managed_condition->>'fatigue')::int,fatigue),
          fitness=coalesce((v_managed_condition->>'fitness')::int,fitness),
          form=coalesce((v_managed_condition->>'form')::int,form),
          morale=coalesce((v_managed_condition->>'morale')::int,morale),
          injury_status=coalesce(nullif(v_managed_condition->>'injury_status',''),injury_status),
          updated_at=now()
      where id='demo';
    end if;

    v_condition_result:=jsonb_build_object(
      'managed_player_id',v_user_ids[1],
      'partner_player_id',v_user_ids[2],
      'managed_condition',v_managed_condition,
      'partner_condition',v_partner_condition
    );
    insert into public.live_match_effect_commits_v23(session_id,effect,payload)
    values(v_session_id,'condition_doubles',v_condition_result);
  else
    v_condition_result:=v_existing||jsonb_build_object('already_applied',true);
  end if;

  select payload into v_existing
  from public.live_match_effect_commits_v23
  where session_id=v_session_id and effect='elo_doubles';

  if v_existing is null then
    v_winning_ids:=case when v_winner_pair_id=v_user_pair_id then v_user_ids else v_opp_ids end;
    v_losing_ids:=case when v_winner_pair_id=v_user_pair_id then v_opp_ids else v_user_ids end;

    for i in 1..2 loop
      for j in 1..2 loop
        v_r:=public.update_player_elo_after_match(
          v_winning_ids[i],v_losing_ids[j],v_surface,v_match_date,true,v_elo_weight
        );
        if coalesce((v_r->>'ok')::boolean,false)=false then
          raise exception 'doubles ELO update failed: %',coalesce(v_r->>'error','unknown');
        end if;
        v_elo_rows:=v_elo_rows||jsonb_build_array(v_r);
      end loop;
    end loop;

    v_elo_result:=jsonb_build_object(
      'calls',v_elo_rows,
      'weight',v_elo_weight,
      'winner_pair_id',v_winner_pair_id,
      'loser_pair_id',v_loser_pair_id
    );
    insert into public.live_match_effect_commits_v23(session_id,effect,payload)
    values(v_session_id,'elo_doubles',v_elo_result);
  else
    v_elo_result:=v_existing||jsonb_build_object('already_applied',true);
  end if;

  return jsonb_build_object(
    'ok',true,
    'session_id',v_session_id,
    'world_match_id',v_world_match_id,
    'world_already_committed',v_world_already,
    'simulated_on',v_world.simulated_on,
    'round_code',v_world.round_code,
    'history',v_history_result,
    'condition',v_condition_result,
    'elo',v_elo_result,
    'model','CB-LIVE-DOUBLES-ATOMIC-COMMIT-v23'
  );
end;
$function$;
revoke all on function public.commit_live_doubles_world_match_atomic_v23(jsonb) from public,anon,authenticated;
grant execute on function public.commit_live_doubles_world_match_atomic_v23(jsonb) to service_role;
