CREATE OR REPLACE FUNCTION public.reserve_managed_doubles_live_matches_v22(p_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  r record;
  v_tournament public.tournaments%rowtype;
  v_season int;
  v_user_pair bigint;
  v_opp_pair bigint;
  v_wins int;
  v_loss boolean;
  v_draw int;
  v_bracket int;
  v_rounds int;
  v_idx int;
  v_round_code text;
  v_match_date date;
  v_schedule jsonb;
  v_match_no int;
  v_existing bigint;
  v_reserved int:=0;
  v_rows jsonb:='[]'::jsonb;
begin
  for r in
    select distinct
      e.id,e.tournament_id,e.player_id,e.partner_id,e.entry_method,e.status,
      tour.name,tour.circuit,tour.category,tour.start_date,tour.main_draw_start_date,tour.end_date,tour.doubles_draw_size
    from public.managed_doubles_entries e
    join public.tournaments tour on tour.id=e.tournament_id
    where e.owner_id='demo'
      and coalesce(e.status,'entered') not in ('withdrawn','declined','rejected','completed','played')
      and e.player_id in (
        select cs.managed_player_id
        from public.career_state cs
        where cs.id='demo' and cs.managed_player_id is not null
        union
        select ar.player_id
        from public.academy_roster ar
        where ar.status='active' and ar.player_id is not null and ar.source_youth_id is null
      )
      and p_date between coalesce(tour.main_draw_start_date,tour.start_date) and tour.end_date
  loop
    select * into v_tournament from public.tournaments where id=r.tournament_id;
    v_season:=extract(year from coalesce(v_tournament.start_date,p_date))::int;

    v_user_pair:=public.ensure_world_doubles_partnership_team(
      v_season,r.player_id,r.partner_id,p_date,0,null
    );
    if coalesce(v_user_pair,0)=0 then
      continue;
    end if;

    select exists(
      select 1
      from public.live_match_sessions s
      where s.tournament_id=r.tournament_id
        and s.managed_player_id=r.player_id
        and s.status='committed'
        and coalesce(s.stats->'_meta'->>'match_type','')='doubles'
        and s.user_sets<s.opponent_sets
    ) into v_loss;
    if v_loss then
      continue;
    end if;

    select count(*)::int
    into v_wins
    from public.live_match_sessions s
    where s.tournament_id=r.tournament_id
      and s.managed_player_id=r.player_id
      and s.status='committed'
      and coalesce(s.stats->'_meta'->>'match_type','')='doubles'
      and s.user_sets>s.opponent_sets;

    v_draw:=greatest(4,coalesce(v_tournament.doubles_draw_size,16));
    v_bracket:=case when v_draw<=4 then 4 when v_draw<=8 then 8 when v_draw<=16 then 16
                    when v_draw<=32 then 32 else 64 end;
    v_rounds:=case v_bracket when 4 then 2 when 8 then 3 when 16 then 4 when 32 then 5 else 6 end;
    if v_wins>=v_rounds then
      continue;
    end if;

    v_idx:=v_wins+1;
    v_round_code:=case
      when v_idx=v_rounds then 'F'
      when v_idx=v_rounds-1 then 'SF'
      when v_idx=v_rounds-2 then 'QF'
      when v_idx=v_rounds-3 then 'R16'
      when v_idx=v_rounds-4 then 'R32'
      else 'R64'
    end;

    v_schedule:=public.managed_tournament_match_date_v22(
      r.tournament_id,r.player_id,v_round_code,'main','doubles'
    );
    v_match_date:=nullif(v_schedule->>'match_date','')::date;
    if v_match_date is null or v_match_date>p_date then
      continue;
    end if;

    select m.id into v_existing
    from public.world_doubles_tournament_matches m
    where m.tournament_id=r.tournament_id
      and m.winner_pair_id is null
      and (m.pair_a_id=v_user_pair or m.pair_b_id=v_user_pair)
    order by m.round_no,m.match_no
    limit 1;

    if v_existing is not null then
      update public.world_doubles_tournament_matches
      set matchup_components=coalesce(matchup_components,'{}'::jsonb)
            ||jsonb_build_object(
              'status','managed_live_pending',
              'managed_player_id',r.player_id,
              'partner_id',r.partner_id,
              'scheduled_date',v_match_date,
              'source','managed_daily_v22'
            ),
          model_version='CB-LIVE-DOUBLES-v22-PENDING',
          simulated_on=coalesce(simulated_on,v_match_date)
      where id=v_existing;

      v_rows:=v_rows||jsonb_build_array(jsonb_build_object(
        'tournament_id',r.tournament_id,'player_id',r.player_id,
        'world_match_id',v_existing,'existing',true,'round',v_round_code,
        'match_date',v_match_date
      ));
      continue;
    end if;

    if v_tournament.circuit='ITF' and v_tournament.category in ('M15','M25') then
      select f.pair_id into v_opp_pair
      from public.select_itf_doubles_field_v20(v_tournament.id,r.player_id) f
      join public.world_doubles_partnerships w on w.id=f.pair_id
      where f.pair_id<>v_user_pair
        and w.active=true
        and r.player_id not in (w.player_a_id,w.player_b_id)
        and r.partner_id not in (w.player_a_id,w.player_b_id)
        and not exists(
          select 1 from public.world_doubles_tournament_matches old
          where old.tournament_id=r.tournament_id
            and (
              (old.pair_a_id=v_user_pair and old.pair_b_id=f.pair_id)
              or (old.pair_b_id=v_user_pair and old.pair_a_id=f.pair_id)
            )
        )
        and not exists(
          select 1
          from public.academy_roster ar
          where ar.status='active'
            and ar.source_youth_id is null
            and ar.player_id in (w.player_a_id,w.player_b_id)
        )
        and not exists(
          select 1 from public.career_state cs
          where cs.id='demo'
            and cs.managed_player_id in (w.player_a_id,w.player_b_id)
        )
      order by md5(
        'managed-doubles-live-v22|'||r.tournament_id::text||'|'||
        v_user_pair::text||'|'||v_wins::text||'|'||f.pair_id::text
      )
      limit 1;
    else
      select f.pair_id into v_opp_pair
      from public.select_pro_doubles_field_v20(v_tournament.id,r.player_id) f
      join public.world_doubles_partnerships w on w.id=f.pair_id
      where f.pair_id<>v_user_pair
        and w.active=true
        and r.player_id not in (w.player_a_id,w.player_b_id)
        and r.partner_id not in (w.player_a_id,w.player_b_id)
        and not exists(
          select 1 from public.world_doubles_tournament_matches old
          where old.tournament_id=r.tournament_id
            and (
              (old.pair_a_id=v_user_pair and old.pair_b_id=f.pair_id)
              or (old.pair_b_id=v_user_pair and old.pair_a_id=f.pair_id)
            )
        )
        and not exists(
          select 1
          from public.academy_roster ar
          where ar.status='active'
            and ar.source_youth_id is null
            and ar.player_id in (w.player_a_id,w.player_b_id)
        )
        and not exists(
          select 1 from public.career_state cs
          where cs.id='demo'
            and cs.managed_player_id in (w.player_a_id,w.player_b_id)
        )
      order by md5(
        'managed-doubles-live-v22|'||r.tournament_id::text||'|'||
        v_user_pair::text||'|'||v_wins::text||'|'||f.pair_id::text
      )
      limit 1;
    end if;

    if coalesce(v_opp_pair,0)=0 then
      select w.id into v_opp_pair
      from public.world_doubles_partnerships w
      where w.season=v_season
        and w.active=true
        and w.id<>v_user_pair
        and r.player_id not in (w.player_a_id,w.player_b_id)
        and r.partner_id not in (w.player_a_id,w.player_b_id)
        and not exists(
          select 1 from public.world_doubles_tournament_matches old
          where old.tournament_id=r.tournament_id
            and (
              (old.pair_a_id=v_user_pair and old.pair_b_id=w.id)
              or (old.pair_b_id=v_user_pair and old.pair_a_id=w.id)
            )
        )
      order by abs(coalesce(w.race_rank,999999)-coalesce((
        select race_rank from public.world_doubles_partnerships where id=v_user_pair
      ),999999)),
      md5('managed-doubles-fallback-v22|'||r.tournament_id::text||'|'||w.id::text)
      limit 1;
    end if;

    if coalesce(v_opp_pair,0)=0 then
      continue;
    end if;

    select coalesce(min(g),1) into v_match_no
    from generate_series(1,greatest(1,v_bracket/(2^v_idx)::int)) g
    where not exists(
      select 1 from public.world_doubles_tournament_matches m
      where m.tournament_id=r.tournament_id
        and m.round_no=v_idx
        and m.match_no=g
        and coalesce(m.is_qualifying,false)=false
    );

    if v_match_no is null then
      select coalesce(max(match_no),0)+1 into v_match_no
      from public.world_doubles_tournament_matches
      where tournament_id=r.tournament_id and round_no=v_idx;
    end if;

    insert into public.world_doubles_tournament_matches(
      tournament_id,round_no,round_code,match_no,pair_a_id,pair_b_id,
      winner_pair_id,loser_pair_id,score,pair_a_win_probability,
      model_version,matchup_components,simulated_on,is_qualifying
    ) values(
      r.tournament_id,v_idx,v_round_code,v_match_no,v_user_pair,v_opp_pair,
      null,null,null,null,
      'CB-LIVE-DOUBLES-v22-PENDING',
      jsonb_build_object(
        'status','managed_live_pending',
        'managed_player_id',r.player_id,
        'partner_id',r.partner_id,
        'user_pair_id',v_user_pair,
        'opponent_pair_id',v_opp_pair,
        'scheduled_date',v_match_date,
        'source','managed_daily_v22'
      ),
      v_match_date,false
    )
    returning id into v_existing;

    v_reserved:=v_reserved+1;
    v_rows:=v_rows||jsonb_build_array(jsonb_build_object(
      'tournament_id',r.tournament_id,'player_id',r.player_id,
      'world_match_id',v_existing,'existing',false,'round',v_round_code,
      'match_date',v_match_date,'user_pair_id',v_user_pair,'opponent_pair_id',v_opp_pair
    ));
  end loop;

  return jsonb_build_object(
    'ok',true,'date',p_date,'reserved',v_reserved,'matches',v_rows,
    'model','CB-MANAGED-DOUBLES-LIVE-PENDING-v22'
  );
end;
$function$;
