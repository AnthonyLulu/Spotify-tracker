-- Keep managed live world metadata consistent with the committed draw result.
-- Applied to Supabase as migration 20261004112513.
CREATE OR REPLACE FUNCTION public.apply_live_world_meta_once_v25(p_session_id bigint, p_world_match_id bigint, p_tournament_id bigint, p_winner_id bigint, p_loser_id bigint, p_surface text, p_match_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_existing jsonb;
  v_world public.world_tournament_matches%rowtype;
  v_rule_key text;
  v_rounds text[];
  v_points_by_result jsonb;
  v_category text;
  v_winner_name text;
  v_loser_name text;
  v_winner_wins integer:=0;
  v_loser_wins integer:=0;
  v_loser_had_bye boolean:=false;
  v_loser_entry_method text:='';
  v_qualifying_points integer:=0;
  v_base_points integer:=0;
  v_loser_score text:='';
  v_h2h jsonb:='{}'::jsonb;
  v_payload jsonb;
begin
  perform 1
  from public.live_match_sessions
  where id=p_session_id
  for update;
  if not found then
    raise exception 'live session % not found',p_session_id;
  end if;

  select payload into v_existing
  from public.live_match_effect_commits_v23
  where session_id=p_session_id and effect='world_meta_singles_v25';

  if v_existing is not null then
    return v_existing||jsonb_build_object(
      'ok',true,'already_applied',true,'model','CB-LIVE-WORLD-META-v25'
    );
  end if;

  select * into v_world
  from public.world_tournament_matches
  where id=p_world_match_id
  for update;

  if not found then
    raise exception 'world match % not found',p_world_match_id;
  end if;
  if v_world.tournament_id<>p_tournament_id then
    raise exception 'world metadata tournament mismatch';
  end if;
  if coalesce(v_world.winner_id,0)<>p_winner_id
     or coalesce(v_world.loser_id,0)<>p_loser_id then
    raise exception 'world metadata winner/loser mismatch';
  end if;

  select name into v_winner_name from public.players where id=p_winner_id;
  select name into v_loser_name from public.players where id=p_loser_id;

  if coalesce(v_world.is_qualifying,false)=false then
    select s.rule_key into v_rule_key
    from public.world_tournament_states s
    where s.tournament_id=p_tournament_id;

    select r.rounds,r.points_by_result
    into v_rounds,v_points_by_result
    from public.tournament_format_rules r
    where r.rule_key=v_rule_key
    limit 1;

    if v_rule_key is null or v_points_by_result is null then
      raise exception 'world metadata format rule missing for tournament %',p_tournament_id;
    end if;

    select t.category into v_category
    from public.tournaments t
    where t.id=p_tournament_id;

    select count(*)::integer into v_winner_wins
    from public.world_tournament_matches m
    where m.tournament_id=p_tournament_id
      and coalesce(m.is_qualifying,false)=false
      and m.winner_id=p_winner_id
      and m.loser_id is not null
      and upper(coalesce(m.score,'')) not in ('BYE','W/O','DOUBLE W/O')
      and lower(coalesce(m.matchup_components->>'walkover','false'))<>'true';

    select count(*)::integer into v_loser_wins
    from public.world_tournament_matches m
    where m.tournament_id=p_tournament_id
      and coalesce(m.is_qualifying,false)=false
      and m.winner_id=p_loser_id
      and m.loser_id is not null
      and upper(coalesce(m.score,'')) not in ('BYE','W/O','DOUBLE W/O')
      and lower(coalesce(m.matchup_components->>'walkover','false'))<>'true';

    update public.world_tournament_entries
    set matches_won=v_winner_wins,
        simulated_on=coalesce(v_world.simulated_on,p_match_date)
    where tournament_id=p_tournament_id and player_id=p_winner_id;
    if not found then
      raise exception 'world winner entry missing';
    end if;

    select coalesce(had_bye,false),coalesce(entry_method,''),coalesce(qualifying_points,0)
    into v_loser_had_bye,v_loser_entry_method,v_qualifying_points
    from public.world_tournament_entries
    where tournament_id=p_tournament_id and player_id=p_loser_id;
    if not found then
      raise exception 'world loser entry missing';
    end if;

    v_base_points:=coalesce((v_points_by_result->>coalesce(v_world.round_code,''))::integer,0);

    if v_loser_had_bye and v_loser_wins=0 and array_length(v_rounds,1)>0 then
      v_base_points:=coalesce((v_points_by_result->>v_rounds[1])::integer,0);
    end if;

    if v_loser_entry_method like 'wildcard%'
       and v_loser_wins=0
       and coalesce(v_category,'') in ('Grand Chelem','Masters 1000') then
      v_base_points:=0;
    end if;

    v_loser_score:=case
      when v_world.player_a_id=p_loser_id then coalesce(v_world.score,'')
      else public.world_invert_tennis_score(coalesce(v_world.score,''))
    end;

    update public.world_tournament_entries
    set matches_won=v_loser_wins,
        result_code=v_world.round_code,
        result_label=public.world_tournament_result_label(v_world.round_code),
        points_awarded=greatest(0,v_base_points+v_qualifying_points),
        last_opponent_id=p_winner_id,
        last_opponent_name=v_winner_name,
        last_score=v_loser_score,
        simulated_on=coalesce(v_world.simulated_on,p_match_date)
    where tournament_id=p_tournament_id and player_id=p_loser_id;
    if not found then
      raise exception 'world loser entry update failed';
    end if;
  end if;

  v_h2h:=public.update_h2h_after_match(
    p_winner_id,p_loser_id,p_surface,coalesce(p_match_date,current_date),false,
    'Court Boss managed live · '||coalesce(v_world.round_code,'Match')
  );
  if coalesce((v_h2h->>'ok')::boolean,true)=false then
    raise exception 'managed live H2H update failed: %',coalesce(v_h2h->>'error','unknown');
  end if;

  update public.player_dynamic_ratings d
  set overall_elo=e.overall_elo,
      hard_elo=e.hard_elo,
      clay_elo=e.clay_elo,
      grass_elo=e.grass_elo,
      rating_confidence=greatest(d.rating_confidence,e.confidence),
      last_competitive_match=coalesce(p_match_date,current_date),
      source_label='Court Boss managed live Elo · atomic v25',
      updated_at=now()
  from public.player_elo_ratings e
  where e.player_id=d.player_id
    and d.player_id in (p_winner_id,p_loser_id);

  v_payload:=jsonb_build_object(
    'ok',true,
    'already_applied',false,
    'world_match_id',p_world_match_id,
    'phase',case when coalesce(v_world.is_qualifying,false) then 'qualifying' else 'main' end,
    'round',v_world.round_code,
    'winner_id',p_winner_id,
    'loser_id',p_loser_id,
    'winner_matches_won',case when coalesce(v_world.is_qualifying,false) then null else v_winner_wins end,
    'loser_matches_won',case when coalesce(v_world.is_qualifying,false) then null else v_loser_wins end,
    'loser_points_awarded',case when coalesce(v_world.is_qualifying,false) then null else greatest(0,v_base_points+v_qualifying_points) end,
    'h2h',coalesce(v_h2h,'{}'::jsonb),
    'model','CB-LIVE-WORLD-META-v25'
  );

  insert into public.live_match_effect_commits_v23(session_id,effect,payload)
  values(p_session_id,'world_meta_singles_v25',v_payload);

  return v_payload;
end;
$function$;

revoke execute on function public.apply_live_world_meta_once_v25(bigint,bigint,bigint,bigint,bigint,text,date) from public, anon, authenticated;
grant execute on function public.apply_live_world_meta_once_v25(bigint,bigint,bigint,bigint,bigint,text,date) to service_role;

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
  v_world_meta_result jsonb;
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

  v_world_meta_result:=public.apply_live_world_meta_once_v25(
    v_session_id,
    v_world_match_id,
    v_tournament_id,
    v_winner_id,
    v_loser_id,
    v_surface,
    v_match_date
  );

  if coalesce((v_world_meta_result->>'ok')::boolean,false)=false then
    raise exception 'world metadata commit failed: %',coalesce(v_world_meta_result->>'error','unknown');
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
    'world_meta',v_world_meta_result,
    'model','CB-LIVE-ATOMIC-COMMIT-v25'
  );
end;
$function$;
