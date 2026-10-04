create or replace function public.commit_live_doubles_terminal_once_v23(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_session_id bigint:=nullif(p_payload->>'session_id','')::bigint;
  v_tournament_id bigint:=nullif(p_payload->>'tournament_id','')::bigint;
  v_player_id bigint:=nullif(p_payload->>'player_id','')::bigint;
  v_partner_id bigint:=nullif(p_payload->>'partner_id','')::bigint;
  v_partnership_id bigint:=nullif(p_payload->>'partnership_id','')::bigint;
  v_entry_id bigint:=nullif(p_payload->>'entry_id','')::bigint;
  v_entry_method text:=coalesce(p_payload->>'entry_method','direct');
  v_entry_meta jsonb:=coalesce(p_payload->'entry_metadata','{}'::jsonb);
  v_user_round text:=coalesce(p_payload->>'user_round','');
  v_points integer:=coalesce(nullif(p_payload->>'user_points','')::integer,0);
  v_prize numeric:=coalesce(nullif(p_payload->>'user_prize','')::numeric,0);
  v_prize_eur numeric:=coalesce(nullif(p_payload->>'user_prize_eur','')::numeric,0);
  v_fx numeric:=coalesce(nullif(p_payload->>'prize_fx_rate_to_eur','')::numeric,1);
  v_tournament_name text:=coalesce(p_payload->>'tournament_name','Tournoi');
  v_earned date:=coalesce(nullif(p_payload->>'earned_date','')::date,current_date);
  v_is_junior boolean:=coalesce((p_payload->>'is_junior')::boolean,false);
  v_champion boolean:=coalesce((p_payload->>'champion')::boolean,false);
  v_title_level text:=coalesce(p_payload->>'title_level','Double');
  v_surface text:=coalesce(p_payload->>'surface','');
  v_history_rows jsonb:=coalesce(p_payload->'history_rows','[]'::jsonb);
  v_existing jsonb;
  v_run_id bigint;
  v_expiry date;
  v_rank jsonb;
  v_pair jsonb;
  v_row jsonb;
  v_result jsonb;
begin
  if v_session_id is null or v_tournament_id is null or v_player_id is null or v_partner_id is null then
    raise exception 'doubles terminal payload incomplete';
  end if;

  perform 1 from public.live_match_sessions where id=v_session_id for update;
  if not found then raise exception 'live session % not found',v_session_id; end if;

  select payload into v_existing
  from public.live_match_effect_commits_v23
  where session_id=v_session_id and effect='doubles_terminal';

  if v_existing is not null then
    return v_existing||jsonb_build_object('ok',true,'already_applied',true,'model','CB-LIVE-DOUBLES-TERMINAL-v23');
  end if;

  select id into v_run_id
  from public.doubles_runs
  where tournament_id=v_tournament_id and managed_player_id=v_player_id
  order by id desc limit 1;

  if v_run_id is null then
    insert into public.doubles_runs(
      tournament_id,managed_player_id,partnership_id,partner_id,entry_method,
      qualifying_points,user_round,user_points,user_prize,user_prize_eur,
      prize_fx_rate_to_eur,status
    ) values(
      v_tournament_id,v_player_id,v_partnership_id,v_partner_id,v_entry_method,
      0,v_user_round,v_points,v_prize,v_prize_eur,v_fx,'completed'
    )
    returning id into v_run_id;
  end if;

  delete from public.doubles_match_history where run_id=v_run_id;
  for v_row in select value from jsonb_array_elements(v_history_rows)
  loop
    insert into public.doubles_match_history(
      run_id,round_name,user_pair,opponent_pair,winner_pair,score
    ) values(
      v_run_id,
      coalesce(v_row->>'round_name','Match'),
      coalesce(v_row->>'user_pair',''),
      coalesce(v_row->>'opponent_pair',''),
      coalesce(v_row->>'winner_pair',''),
      coalesce(v_row->>'score','—')
    );
  end loop;

  if v_is_junior then
    if v_points>0 then
      update public.players
      set junior_doubles_game_points=coalesce(junior_doubles_game_points,0)+v_points
      where id=v_player_id;
      if not found then raise exception 'managed doubles player missing'; end if;
      update public.players
      set junior_doubles_game_points=coalesce(junior_doubles_game_points,0)+round(v_points*.85)
      where id=v_partner_id;
      if not found then raise exception 'doubles partner missing'; end if;
    end if;
    v_rank:=public.refresh_junior_doubles_ranking(v_earned);
    if coalesce((v_rank->>'ok')::boolean,true)=false then
      raise exception 'junior doubles ranking refresh failed: %',coalesce(v_rank->>'error','unknown');
    end if;
  else
    if v_points>0 then
      v_expiry:=v_earned+364;
      insert into public.user_doubles_points(
        owner_id,player_id,tournament_id,partner_id,label,earned_date,expiry_date,points,active
      ) values(
        'demo',v_player_id,v_tournament_id,v_partner_id,v_tournament_name,v_earned,v_expiry,v_points,true
      );
    end if;
    v_rank:=public.recalculate_managed_player_doubles_ranking(v_player_id,v_earned);
    if coalesce((v_rank->>'ok')::boolean,true)=false then
      raise exception 'doubles ranking refresh failed: %',coalesce(v_rank->>'error','unknown');
    end if;
  end if;

  if v_prize_eur<>0 then
    update public.career_state set budget=budget+v_prize_eur,updated_at=now() where id='demo';
    if not found then raise exception 'career missing'; end if;
  end if;

  if v_entry_id is not null then
    update public.managed_doubles_entries
    set status='played',
        metadata=coalesce(metadata,'{}'::jsonb)||v_entry_meta||jsonb_build_object(
          'played_run_id',v_run_id,'played_on',v_earned,'result',v_user_round
        ),
        updated_at=now()
    where id=v_entry_id;
  end if;

  v_pair:=public.apply_managed_doubles_result(v_run_id,v_earned);
  if coalesce((v_pair->>'ok')::boolean,true)=false then
    raise exception 'pair dynamics failed: %',coalesce(v_pair->>'error','unknown');
  end if;

  if v_champion then
    insert into public.player_titles(player_id,tournament_name,title_date,level,surface,event_type,partner_player_id)
    values
      (v_player_id,v_tournament_name,v_earned,v_title_level,v_surface,case when v_is_junior then 'junior_doubles' else 'doubles' end,v_partner_id),
      (v_partner_id,v_tournament_name,v_earned,v_title_level,v_surface,case when v_is_junior then 'junior_doubles' else 'doubles' end,v_player_id);
  end if;

  v_result:=jsonb_build_object(
    'ok',true,'already_applied',false,'run_id',v_run_id,
    'user_round',v_user_round,'user_points',v_points,'user_prize',v_prize,'user_prize_eur',v_prize_eur,
    'ranking',coalesce(v_rank,'{}'::jsonb),'pair_dynamics',coalesce(v_pair,'{}'::jsonb),
    'model','CB-LIVE-DOUBLES-TERMINAL-v23'
  );
  insert into public.live_match_effect_commits_v23(session_id,effect,payload)
  values(v_session_id,'doubles_terminal',v_result);
  return v_result;
end;
$function$;

revoke all on function public.commit_live_doubles_terminal_once_v23(jsonb) from public,anon,authenticated;
grant execute on function public.commit_live_doubles_terminal_once_v23(jsonb) to service_role;
