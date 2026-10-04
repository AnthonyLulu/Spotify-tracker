-- Serialize concurrent/retried live match analytics finalization.
-- Applied to Supabase as migration 20261004111607.
CREATE OR REPLACE FUNCTION public.finalize_live_match_analytics(p_session_id bigint, p_date date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  s live_match_sessions%rowtype;
  v_managed bigint;
  r record;
  v_players int:=0;
begin
  -- Serialize every finalize/retry for the same live session. The lock is held
  -- until this RPC transaction ends, so a concurrent retry can only continue
  -- after the first caller has written the processed-session marker.
  select * into s
  from live_match_sessions
  where id=p_session_id
  for update;

  if s.id is null or s.status<>'completed' then
    return jsonb_build_object('ok',false,'reason','session_not_completed');
  end if;

  if exists(select 1 from advanced_analytics_processed_sessions where session_id=p_session_id) then
    return jsonb_build_object('ok',true,'already_processed',true);
  end if;

  v_managed:=coalesce(s.managed_player_id,(select managed_player_id from career_state where id='demo'));

  for r in
    with participants as (
      select v_managed::bigint as player_id
      union
      select s.opponent_id::bigint
    )
    select
      pp.player_id,
      count(e.*)::bigint as points_sampled,
      count(*) filter(where e.server_id=pp.player_id)::bigint as service_points,
      count(*) filter(where e.server_id=pp.player_id and e.winner_id=pp.player_id)::bigint as service_points_won,
      count(*) filter(where e.server_id=pp.player_id)::bigint as first_serves,
      count(*) filter(where e.server_id=pp.player_id and e.first_serve_in)::bigint as first_serves_in,
      count(*) filter(where e.server_id=pp.player_id and e.serve_number=1)::bigint as first_serve_points,
      count(*) filter(where e.server_id=pp.player_id and e.serve_number=1 and e.winner_id=pp.player_id)::bigint as first_serve_points_won,
      count(*) filter(where e.server_id=pp.player_id and e.serve_number=2)::bigint as second_serve_points,
      count(*) filter(where e.server_id=pp.player_id and e.serve_number=2 and e.winner_id=pp.player_id)::bigint as second_serve_points_won,
      count(*) filter(where e.server_id=pp.player_id and e.ace)::bigint as aces,
      count(*) filter(where e.server_id=pp.player_id and e.double_fault)::bigint as double_faults,
      count(*) filter(where e.server_id=pp.player_id and e.unreturned_serve)::bigint as unreturned_serves,
      count(*) filter(where e.returner_id=pp.player_id)::bigint as return_points,
      count(*) filter(where e.returner_id=pp.player_id and e.winner_id=pp.player_id)::bigint as return_points_won,
      count(*) filter(where e.returner_id=pp.player_id and not e.ace and not e.double_fault and not e.unreturned_serve)::bigint as returns_in_play,
      count(*) filter(where e.returner_id=pp.player_id and e.return_depth='profond')::bigint as return_depth_deep,
      count(*) filter(where e.returner_id=pp.player_id and e.return_depth='moyen')::bigint as return_depth_medium,
      count(*) filter(where e.returner_id=pp.player_id and e.return_depth='court')::bigint as return_depth_short,
      count(*) filter(where e.winner_id=pp.player_id and e.ending in ('winner','return_winner'))::bigint as winners,
      count(*) filter(where e.winner_id=pp.player_id and e.ending='forced_error')::bigint as forced_errors_induced,
      count(*) filter(where e.winner_id<>pp.player_id and e.ending='unforced_error')::bigint as unforced_errors,
      count(*) filter(where e.net_player_id=pp.player_id)::bigint as net_points,
      count(*) filter(where e.net_player_id=pp.player_id and e.winner_id=pp.player_id)::bigint as net_points_won,
      count(*) filter(where e.rally_band='0-4')::bigint as rally_0_4_points,
      count(*) filter(where e.rally_band='0-4' and e.winner_id=pp.player_id)::bigint as rally_0_4_won,
      count(*) filter(where e.rally_band='5-8')::bigint as rally_5_8_points,
      count(*) filter(where e.rally_band='5-8' and e.winner_id=pp.player_id)::bigint as rally_5_8_won,
      count(*) filter(where e.rally_band='9+')::bigint as rally_9plus_points,
      count(*) filter(where e.rally_band='9+' and e.winner_id=pp.player_id)::bigint as rally_9plus_won,
      count(*) filter(where e.server_id=pp.player_id and e.serve_direction='large')::bigint as serve_wide,
      count(*) filter(where e.server_id=pp.player_id and e.serve_direction='corps')::bigint as serve_body,
      count(*) filter(where e.server_id=pp.player_id and e.serve_direction='T')::bigint as serve_t
    from participants pp
    cross join live_match_point_events e
    where e.session_id=p_session_id
    group by pp.player_id
  loop
    insert into player_observed_analytics(
      player_id,matches_sampled,points_sampled,service_points,service_points_won,
      first_serves,first_serves_in,first_serve_points,first_serve_points_won,
      second_serve_points,second_serve_points_won,aces,double_faults,unreturned_serves,
      return_points,return_points_won,returns_in_play,return_depth_deep,return_depth_medium,return_depth_short,
      winners,forced_errors_induced,unforced_errors,net_points,net_points_won,
      rally_0_4_points,rally_0_4_won,rally_5_8_points,rally_5_8_won,rally_9plus_points,rally_9plus_won,
      serve_wide,serve_body,serve_t,last_sample_date,updated_at
    )
    values(
      r.player_id,1,r.points_sampled,r.service_points,r.service_points_won,
      r.first_serves,r.first_serves_in,r.first_serve_points,r.first_serve_points_won,
      r.second_serve_points,r.second_serve_points_won,r.aces,r.double_faults,r.unreturned_serves,
      r.return_points,r.return_points_won,r.returns_in_play,r.return_depth_deep,r.return_depth_medium,r.return_depth_short,
      r.winners,r.forced_errors_induced,r.unforced_errors,r.net_points,r.net_points_won,
      r.rally_0_4_points,r.rally_0_4_won,r.rally_5_8_points,r.rally_5_8_won,r.rally_9plus_points,r.rally_9plus_won,
      r.serve_wide,r.serve_body,r.serve_t,coalesce(p_date,current_date),now()
    )
    on conflict(player_id) do update set
      matches_sampled=player_observed_analytics.matches_sampled+1,
      points_sampled=player_observed_analytics.points_sampled+excluded.points_sampled,
      service_points=player_observed_analytics.service_points+excluded.service_points,
      service_points_won=player_observed_analytics.service_points_won+excluded.service_points_won,
      first_serves=player_observed_analytics.first_serves+excluded.first_serves,
      first_serves_in=player_observed_analytics.first_serves_in+excluded.first_serves_in,
      first_serve_points=player_observed_analytics.first_serve_points+excluded.first_serve_points,
      first_serve_points_won=player_observed_analytics.first_serve_points_won+excluded.first_serve_points_won,
      second_serve_points=player_observed_analytics.second_serve_points+excluded.second_serve_points,
      second_serve_points_won=player_observed_analytics.second_serve_points_won+excluded.second_serve_points_won,
      aces=player_observed_analytics.aces+excluded.aces,
      double_faults=player_observed_analytics.double_faults+excluded.double_faults,
      unreturned_serves=player_observed_analytics.unreturned_serves+excluded.unreturned_serves,
      return_points=player_observed_analytics.return_points+excluded.return_points,
      return_points_won=player_observed_analytics.return_points_won+excluded.return_points_won,
      returns_in_play=player_observed_analytics.returns_in_play+excluded.returns_in_play,
      return_depth_deep=player_observed_analytics.return_depth_deep+excluded.return_depth_deep,
      return_depth_medium=player_observed_analytics.return_depth_medium+excluded.return_depth_medium,
      return_depth_short=player_observed_analytics.return_depth_short+excluded.return_depth_short,
      winners=player_observed_analytics.winners+excluded.winners,
      forced_errors_induced=player_observed_analytics.forced_errors_induced+excluded.forced_errors_induced,
      unforced_errors=player_observed_analytics.unforced_errors+excluded.unforced_errors,
      net_points=player_observed_analytics.net_points+excluded.net_points,
      net_points_won=player_observed_analytics.net_points_won+excluded.net_points_won,
      rally_0_4_points=player_observed_analytics.rally_0_4_points+excluded.rally_0_4_points,
      rally_0_4_won=player_observed_analytics.rally_0_4_won+excluded.rally_0_4_won,
      rally_5_8_points=player_observed_analytics.rally_5_8_points+excluded.rally_5_8_points,
      rally_5_8_won=player_observed_analytics.rally_5_8_won+excluded.rally_5_8_won,
      rally_9plus_points=player_observed_analytics.rally_9plus_points+excluded.rally_9plus_points,
      rally_9plus_won=player_observed_analytics.rally_9plus_won+excluded.rally_9plus_won,
      serve_wide=player_observed_analytics.serve_wide+excluded.serve_wide,
      serve_body=player_observed_analytics.serve_body+excluded.serve_body,
      serve_t=player_observed_analytics.serve_t+excluded.serve_t,
      last_sample_date=excluded.last_sample_date,
      updated_at=now();

    perform blend_player_observed_analytics(r.player_id,coalesce(p_date,current_date));
    v_players:=v_players+1;
  end loop;

  insert into advanced_analytics_processed_sessions(session_id)
  values(p_session_id)
  on conflict(session_id) do nothing;

  return jsonb_build_object(
    'ok',true,'session_id',p_session_id,'players_updated',v_players,
    'point_events',(select count(*) from live_match_point_events where session_id=p_session_id)
  );
end;
$function$

