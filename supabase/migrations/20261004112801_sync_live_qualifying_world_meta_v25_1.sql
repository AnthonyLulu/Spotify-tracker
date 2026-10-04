-- Keep qualifying losers/results/ranking history aligned with a managed live world result.
-- Applied to Supabase as migration 20261004112801.
CREATE OR REPLACE FUNCTION public.apply_live_world_meta_once_v25(p_session_id bigint, p_world_match_id bigint, p_tournament_id bigint, p_winner_id bigint, p_loser_id bigint, p_surface text, p_match_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_existing jsonb;
  v_world public.world_tournament_matches%rowtype;
  v_tournament public.tournaments%rowtype;
  v_rule_key text;
  v_rounds text[];
  v_points_by_result jsonb;
  v_qualifying_points_by_result jsonb;
  v_winner_name text;
  v_loser_name text;
  v_winner_wins integer:=0;
  v_loser_wins integer:=0;
  v_loser_had_bye boolean:=false;
  v_loser_entry_method text:='';
  v_qualifying_points integer:=0;
  v_base_points integer:=0;
  v_loss_points integer:=0;
  v_loss_prize numeric:=0;
  v_qround integer:=0;
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
      'ok',true,'already_applied',true,'model','CB-LIVE-WORLD-META-v25.1'
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

  select * into v_tournament
  from public.tournaments
  where id=p_tournament_id;
  if not found then
    raise exception 'world metadata tournament missing';
  end if;

  select name into v_winner_name from public.players where id=p_winner_id;
  select name into v_loser_name from public.players where id=p_loser_id;

  v_loser_score:=case
    when v_world.player_a_id=p_loser_id then coalesce(v_world.score,'')
    else public.world_invert_tennis_score(coalesce(v_world.score,''))
  end;

  if coalesce(v_world.is_qualifying,false) then
    select s.rule_key into v_rule_key
    from public.world_qualifying_states s
    where s.tournament_id=p_tournament_id;

    select r.qualifying_points
    into v_qualifying_points_by_result
    from public.tournament_format_rules r
    where r.rule_key=v_rule_key
    limit 1;

    if v_rule_key is null or v_qualifying_points_by_result is null then
      raise exception 'qualifying metadata format rule missing for tournament %',p_tournament_id;
    end if;

    v_qround:=abs(coalesce(v_world.round_no,0));
    v_loss_points:=coalesce((v_qualifying_points_by_result->>coalesce(v_world.round_code,''))::integer,0);
    v_loss_prize:=public.tournament_prize_for_result(
      p_tournament_id,coalesce(v_world.round_code,''),'qualifying'
    );

    update public.world_tournament_qualifying_entries
    set result_code=v_world.round_code,
        result_label='Qualification · tour '||v_qround,
        qualified=false,
        points_awarded=v_loss_points,
        prize_awarded=v_loss_prize,
        prize_currency=coalesce(v_tournament.prize_currency,'USD'),
        prize_is_estimate=coalesce(
          v_tournament.qualifying_prize_is_estimate,
          v_tournament.prize_breakdown_is_estimate,
          true
        ),
        last_opponent_id=p_winner_id,
        last_opponent_name=v_winner_name,
        last_score=v_loser_score,
        simulated_on=coalesce(v_world.simulated_on,p_match_date),
        source_label='Court Boss managed live qualifying · '||coalesce(v_world.round_code,'Q')
    where tournament_id=p_tournament_id and player_id=p_loser_id;
    if not found then
      raise exception 'qualifying loser entry missing';
    end if;

    if v_loss_points>0 then
      insert into public.world_ranking_points(
        player_id,tournament_id,label,earned_date,expiry_date,points,active,source_label
      ) values(
        p_loser_id,p_tournament_id,
        v_tournament.name||' · '||coalesce(v_world.round_code,'Q'),
        coalesce(v_world.simulated_on,p_match_date),
        coalesce(v_world.simulated_on,p_match_date)+364,
        v_loss_points,true,
        'Court Boss managed live qualifying · '||coalesce(v_world.round_code,'Q')
      )
      on conflict(player_id,tournament_id) do update set
        label=excluded.label,
        earned_date=excluded.earned_date,
        expiry_date=excluded.expiry_date,
        points=excluded.points,
        active=true,
        source_label=excluded.source_label;
    end if;

    insert into public.player_tournament_history(
      player_id,season,tournament_id,tournament_name,tournament_date,level,category,surface,
      result_code,result_label,last_opponent,last_score,is_grand_slam,source,event_type
    ) values(
      p_loser_id,
      extract(year from coalesce(v_tournament.start_date,coalesce(v_world.simulated_on,p_match_date)))::int,
      p_tournament_id::text,
      v_tournament.name,
      coalesce(v_world.simulated_on,p_match_date),
      coalesce(v_tournament.level,v_tournament.category,v_tournament.circuit),
      v_tournament.category,
      v_tournament.surface,
      v_world.round_code,
      'Qualification · tour '||v_qround,
      v_winner_name,
      v_loser_score,
      v_tournament.category='Grand Chelem',
      'Court Boss managed live qualifying',
      'singles'
    )
    on conflict(player_id,event_type,tournament_id) do update set
      result_code=excluded.result_code,
      result_label=excluded.result_label,
      last_opponent=excluded.last_opponent,
      last_score=excluded.last_score,
      tournament_date=excluded.tournament_date,
      source=excluded.source;
  else
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
       and coalesce(v_tournament.category,'') in ('Grand Chelem','Masters 1000') then
      v_base_points:=0;
    end if;

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
      source_label='Court Boss managed live Elo · atomic v25.1',
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
    'loser_points_awarded',case
      when coalesce(v_world.is_qualifying,false) then v_loss_points
      else greatest(0,v_base_points+v_qualifying_points)
    end,
    'qualifying_prize',case when coalesce(v_world.is_qualifying,false) then v_loss_prize else null end,
    'h2h',coalesce(v_h2h,'{}'::jsonb),
    'model','CB-LIVE-WORLD-META-v25.1'
  );

  insert into public.live_match_effect_commits_v23(session_id,effect,payload)
  values(p_session_id,'world_meta_singles_v25',v_payload);

  return v_payload;
end;
$function$;
