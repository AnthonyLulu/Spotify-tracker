create or replace function public.commit_live_tournament_terminal_once_v23(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_session_id bigint := nullif(p_payload->>'session_id','')::bigint;
  v_tournament_id bigint := nullif(p_payload->>'tournament_id','')::bigint;
  v_player_id bigint := nullif(p_payload->>'player_id','')::bigint;
  v_entry_id bigint := nullif(p_payload->>'entry_id','')::bigint;
  v_user_points integer := coalesce(nullif(p_payload->>'user_points','')::integer,0);
  v_user_prize numeric := coalesce(nullif(p_payload->>'user_prize','')::numeric,0);
  v_user_prize_eur numeric := coalesce(nullif(p_payload->>'user_prize_eur','')::numeric,0);
  v_fx numeric := coalesce(nullif(p_payload->>'prize_fx_rate_to_eur','')::numeric,1);
  v_entry_method text := coalesce(p_payload->>'entry_method','direct');
  v_user_round text := coalesce(p_payload->>'user_round','');
  v_tournament_name text := coalesce(p_payload->>'tournament_name','Tournoi');
  v_played_on date := coalesce(nullif(p_payload->>'played_on','')::date,current_date);
  v_rank_date date := coalesce(nullif(p_payload->>'rank_date','')::date,v_played_on);
  v_is_junior boolean := coalesce((p_payload->>'is_junior')::boolean,false);
  v_is_primary boolean := coalesce((p_payload->>'is_primary')::boolean,false);
  v_champion_id bigint := nullif(p_payload->>'champion_player_id','')::bigint;
  v_existing jsonb;
  v_run_id bigint;
  v_expiry date;
  v_rank jsonb;
  v_protected jsonb;
  v_entry_meta jsonb := coalesce(p_payload->'entry_metadata','{}'::jsonb);
  v_result jsonb;
begin
  if v_session_id is null or v_tournament_id is null or v_player_id is null then
    raise exception 'terminal payload incomplete';
  end if;

  perform 1 from public.live_match_sessions where id=v_session_id for update;
  if not found then raise exception 'live session % not found',v_session_id; end if;

  select payload into v_existing
  from public.live_match_effect_commits_v23
  where session_id=v_session_id and effect='tournament_terminal';

  if v_existing is not null then
    return v_existing || jsonb_build_object('ok',true,'already_applied',true,'model','CB-LIVE-TERMINAL-v23');
  end if;

  select id into v_run_id
  from public.tournament_runs
  where tournament_id=v_tournament_id and managed_player_id=v_player_id
  order by id desc limit 1;

  if v_run_id is null then
    insert into public.tournament_runs(
      tournament_id,managed_player_id,entry_method,champion_player_id,
      user_round,user_points,user_prize,user_prize_eur,prize_fx_rate_to_eur,status
    ) values(
      v_tournament_id,v_player_id,v_entry_method,v_champion_id,
      v_user_round,v_user_points,v_user_prize,v_user_prize_eur,v_fx,'completed'
    )
    returning id into v_run_id;
  end if;

  if v_is_junior then
    if v_user_points>0 then
      update public.players
      set junior_game_points=coalesce(junior_game_points,0)+v_user_points
      where id=v_player_id;
      if not found then raise exception 'player missing'; end if;
    end if;
    v_rank:=public.refresh_junior_display_pool_v3(2000);
    if coalesce((v_rank->>'ok')::boolean,true)=false then
      raise exception 'junior refresh failed: %',coalesce(v_rank->>'error','unknown');
    end if;
  else
    if v_user_points>0 then
      v_expiry:=v_rank_date+364;
      insert into public.user_ranking_points(
        owner_id,player_id,tournament_id,label,earned_date,expiry_date,points,active
      ) values(
        'demo',v_player_id,v_tournament_id,v_tournament_name,v_rank_date,v_expiry,v_user_points,true
      );
    end if;

    if v_is_primary then
      v_rank:=public.recalculate_user_ranking(v_rank_date);
    else
      v_rank:=public.recalculate_managed_player_ranking(v_player_id,v_rank_date,false);
    end if;

    if coalesce((v_rank->>'ok')::boolean,true)=false then
      raise exception 'ranking refresh failed: %',coalesce(v_rank->>'error','unknown');
    end if;
  end if;

  if v_user_prize_eur<>0 then
    update public.career_state
    set budget=budget+v_user_prize_eur,updated_at=now()
    where id='demo';
    if not found then raise exception 'career missing'; end if;
  end if;

  if v_entry_id is not null then
    update public.entries
    set status='played',
        withdrawn_on=null,
        metadata=coalesce(metadata,'{}'::jsonb)||v_entry_meta||jsonb_build_object(
          'played_run_id',v_run_id,
          'played_on',v_played_on,
          'result',v_user_round,
          'entry_method',v_entry_method
        ),
        updated_at=now()
    where id=v_entry_id;
  end if;

  if v_entry_method in ('protected','protected_qualifying') then
    v_protected:=public.consume_player_entry_protection(v_player_id,'singles',v_tournament_id);
    if coalesce((v_protected->>'ok')::boolean,false)=false then
      raise exception 'protected ranking consume failed: %',coalesce(v_protected->>'error','unknown');
    end if;
  end if;

  v_result:=jsonb_build_object(
    'ok',true,'already_applied',false,'run_id',v_run_id,
    'user_round',v_user_round,'user_points',v_user_points,
    'user_prize',v_user_prize,'user_prize_eur',v_user_prize_eur,
    'ranking',coalesce(v_rank,'{}'::jsonb),
    'protected',coalesce(v_protected,'{}'::jsonb),
    'model','CB-LIVE-TERMINAL-v23'
  );

  insert into public.live_match_effect_commits_v23(session_id,effect,payload)
  values(v_session_id,'tournament_terminal',v_result);

  return v_result;
end;
$function$;

revoke all on function public.commit_live_tournament_terminal_once_v23(jsonb) from public,anon,authenticated;
grant execute on function public.commit_live_tournament_terminal_once_v23(jsonb) to service_role;
