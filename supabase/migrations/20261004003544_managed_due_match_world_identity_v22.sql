CREATE OR REPLACE FUNCTION public.managed_due_matches_v22(p_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare
  r record;
  v_primary bigint;
  v_wins int;
  v_loss boolean;
  v_draw int;
  v_bracket int;
  v_rounds int;
  v_qdraw int;
  v_qslots int;
  v_qrounds int;
  v_main_wins int;
  v_idx int;
  v_code text;
  v_phase text;
  v_schedule jsonb;
  v_match_date date;
  v_world_match_id bigint;
  v_opponent_id bigint;
  v_user_pair_id bigint;
  v_opponent_pair_id bigint;
  v_matches jsonb:='[]'::jsonb;
begin
  select managed_player_id into v_primary
  from public.career_state where id='demo';

  -- Singles.
  for r in
    select distinct e.player_id,e.tournament_id,e.entry_method,t.name,t.circuit,t.category,
           t.singles_draw_size,t.draw_size,t.qualifying_draw_size,
           t.qualifying_start_date,t.qualifying_end_date,t.main_draw_start_date,t.start_date,t.end_date
    from public.entries e
    join public.tournaments t on t.id=e.tournament_id
    where e.player_id in (
      select v_primary
      union
      select ar.player_id from public.academy_roster ar
      where ar.status='active' and ar.player_id is not null and ar.source_youth_id is null
    )
      and coalesce(e.status,'entered') not in ('withdrawn','declined','rejected','completed')
      and p_date between coalesce(t.qualifying_start_date,t.main_draw_start_date,t.start_date) and t.end_date
      and not exists(
        select 1 from public.tournament_runs tr
        where tr.tournament_id=e.tournament_id and tr.managed_player_id=e.player_id
      )
  loop
    select exists(
      select 1 from public.live_match_sessions s
      where s.tournament_id=r.tournament_id and s.managed_player_id=r.player_id
        and s.status='committed'
        and coalesce(s.stats->'_meta'->>'match_type','singles')<>'doubles'
        and (
          coalesce(s.stats->'_retirement'->>'winner','')='opponent'
          or s.user_sets<s.opponent_sets
        )
    ) into v_loss;
    if v_loss then continue; end if;

    select count(*)::int into v_wins
    from public.live_match_sessions s
    where s.tournament_id=r.tournament_id and s.managed_player_id=r.player_id
      and s.status='committed'
      and coalesce(s.stats->'_meta'->>'match_type','singles')<>'doubles'
      and (
        coalesce(s.stats->'_retirement'->>'winner','')='user'
        or s.user_sets>s.opponent_sets
      );

    v_draw:=greatest(8,coalesce(r.singles_draw_size,r.draw_size,32));
    v_bracket:=case when v_draw<=8 then 8 when v_draw<=16 then 16 when v_draw<=32 then 32
                    when v_draw<=64 then 64 when v_draw<=128 then 128 else 256 end;
    v_rounds:=case v_bracket when 8 then 3 when 16 then 4 when 32 then 5 when 64 then 6 when 128 then 7 else 8 end;

    v_phase:='main';
    v_qrounds:=0;
    if coalesce(r.entry_method,'')='qualifying'
       or coalesce(r.entry_method,'')='protected_qualifying'
       or coalesce(r.entry_method,'') like '%_qualifying'
    then
      select greatest(1,coalesce(fr.qualifier_count,1))
      into v_qslots
      from public.tournament_format_rules fr
      where fr.circuit=r.circuit and fr.category=r.category
        and fr.main_draw_size=v_draw
      limit 1;
      v_qslots:=greatest(1,coalesce(v_qslots,1));
      v_qdraw:=greatest(1,coalesce(r.qualifying_draw_size,v_qslots));
      v_qrounds:=case
        when v_qdraw<=v_qslots*2 then 1
        when v_qdraw<=v_qslots*4 then 2
        when v_qdraw<=v_qslots*8 then 3
        when v_qdraw<=v_qslots*16 then 4
        else 5 end;
    end if;

    if v_qrounds>0 and v_wins<v_qrounds then
      v_phase:='qualifying';
      v_code:='Q'||(v_wins+1)::text;
    else
      v_main_wins:=greatest(0,v_wins-v_qrounds);
      if v_main_wins>=v_rounds then continue; end if;
      v_idx:=v_main_wins+1;
      v_code:=case
        when v_idx=v_rounds then 'F'
        when v_idx=v_rounds-1 then 'SF'
        when v_idx=v_rounds-2 then 'QF'
        when v_idx=v_rounds-3 then 'R16'
        when v_idx=v_rounds-4 then 'R32'
        when v_idx=v_rounds-5 then 'R64'
        when v_idx=v_rounds-6 then 'R128'
        else 'R256' end;
    end if;

    v_schedule:=public.managed_tournament_match_date_v22(
      r.tournament_id,r.player_id,v_code,v_phase,'singles'
    );
    v_match_date:=nullif(v_schedule->>'match_date','')::date;
    if v_match_date is not null and v_match_date<=p_date then
      v_world_match_id:=null;
      v_opponent_id:=null;

      select m.id,
             case when m.player_a_id=r.player_id then m.player_b_id else m.player_a_id end
      into v_world_match_id,v_opponent_id
      from public.world_tournament_matches m
      where m.tournament_id=r.tournament_id
        and m.winner_id is null
        and (
          (v_phase='qualifying' and coalesce(m.is_qualifying,false)=true)
          or
          (v_phase='main' and coalesce(m.is_qualifying,false)=false)
        )
        and r.player_id in (m.player_a_id,m.player_b_id)
        and coalesce(m.matchup_components->>'status','')='managed_live_pending'
        and coalesce(m.simulated_on,v_match_date)<=p_date
      order by
        case when m.round_code=v_code then 0 else 1 end,
        coalesce(m.simulated_on,v_match_date),
        m.round_no,m.match_no,m.id
      limit 1;

      v_matches:=v_matches||jsonb_build_array(jsonb_build_object(
        'discipline','singles','player_id',r.player_id,'tournament_id',r.tournament_id,
        'tournament_name',r.name,'round',v_code,'phase',v_phase,
        'match_date',v_match_date,'overdue',v_match_date<p_date,'schedule',v_schedule,
        'world_match_id',v_world_match_id,'opponent_id',v_opponent_id,
        'world_match_reserved',v_world_match_id is not null
      ));
    end if;
  end loop;

  -- Doubles.
  for r in
    select distinct e.player_id,e.partner_id,e.tournament_id,e.entry_method,t.name,
           t.doubles_draw_size,t.main_draw_start_date,t.start_date,t.end_date
    from public.managed_doubles_entries e
    join public.tournaments t on t.id=e.tournament_id
    where e.player_id in (
      select v_primary
      union
      select ar.player_id from public.academy_roster ar
      where ar.status='active' and ar.player_id is not null and ar.source_youth_id is null
    )
      and coalesce(e.status,'entered') not in ('withdrawn','declined','rejected','completed')
      and p_date between coalesce(t.main_draw_start_date,t.start_date) and t.end_date
      and not exists(
        select 1 from public.doubles_runs dr
        where dr.tournament_id=e.tournament_id and dr.managed_player_id=e.player_id
      )
  loop
    select exists(
      select 1 from public.live_match_sessions s
      where s.tournament_id=r.tournament_id and s.managed_player_id=r.player_id
        and s.status='committed'
        and coalesce(s.stats->'_meta'->>'match_type','')='doubles'
        and s.user_sets<s.opponent_sets
    ) into v_loss;
    if v_loss then continue; end if;

    select count(*)::int into v_wins
    from public.live_match_sessions s
    where s.tournament_id=r.tournament_id and s.managed_player_id=r.player_id
      and s.status='committed'
      and coalesce(s.stats->'_meta'->>'match_type','')='doubles'
      and s.user_sets>s.opponent_sets;

    v_draw:=greatest(4,coalesce(r.doubles_draw_size,16));
    v_bracket:=case when v_draw<=4 then 4 when v_draw<=8 then 8 when v_draw<=16 then 16
                    when v_draw<=32 then 32 else 64 end;
    v_rounds:=case v_bracket when 4 then 2 when 8 then 3 when 16 then 4 when 32 then 5 else 6 end;
    if v_wins>=v_rounds then continue; end if;
    v_idx:=v_wins+1;
    v_code:=case
      when v_idx=v_rounds then 'F'
      when v_idx=v_rounds-1 then 'SF'
      when v_idx=v_rounds-2 then 'QF'
      when v_idx=v_rounds-3 then 'R16'
      when v_idx=v_rounds-4 then 'R32'
      else 'R64' end;

    v_schedule:=public.managed_tournament_match_date_v22(
      r.tournament_id,r.player_id,v_code,'main','doubles'
    );
    v_match_date:=nullif(v_schedule->>'match_date','')::date;
    if v_match_date is not null and v_match_date<=p_date then
      v_world_match_id:=null;
      v_user_pair_id:=null;
      v_opponent_pair_id:=null;

      select w.id
      into v_user_pair_id
      from public.world_doubles_partnerships w
      where w.active=true
        and w.season=extract(year from coalesce(r.start_date,p_date))::int
        and (
          (w.player_a_id=r.player_id and w.player_b_id=r.partner_id)
          or
          (w.player_b_id=r.player_id and w.player_a_id=r.partner_id)
        )
      order by w.id desc
      limit 1;

      if v_user_pair_id is not null then
        select m.id,
               case when m.pair_a_id=v_user_pair_id then m.pair_b_id else m.pair_a_id end
        into v_world_match_id,v_opponent_pair_id
        from public.world_doubles_tournament_matches m
        where m.tournament_id=r.tournament_id
          and m.winner_pair_id is null
          and coalesce(m.is_qualifying,false)=false
          and v_user_pair_id in (m.pair_a_id,m.pair_b_id)
          and coalesce(m.matchup_components->>'status','')='managed_live_pending'
          and coalesce(m.simulated_on,v_match_date)<=p_date
        order by
          case when m.round_code=v_code then 0 else 1 end,
          coalesce(m.simulated_on,v_match_date),
          m.round_no,m.match_no,m.id
        limit 1;
      end if;

      v_matches:=v_matches||jsonb_build_array(jsonb_build_object(
        'discipline','doubles','player_id',r.player_id,'partner_id',r.partner_id,
        'tournament_id',r.tournament_id,'tournament_name',r.name,
        'round',v_code,'phase','main','match_date',v_match_date,
        'overdue',v_match_date<p_date,'schedule',v_schedule,
        'world_match_id',v_world_match_id,'user_pair_id',v_user_pair_id,
        'opponent_pair_id',v_opponent_pair_id,
        'world_match_reserved',v_world_match_id is not null
      ));
    end if;
  end loop;

  return jsonb_build_object(
    'ok',true,'date',p_date,'count',jsonb_array_length(v_matches),
    'matches',v_matches,'model','CB-MANAGED-DUE-MATCHES-v22'
  );
end;
$function$;
